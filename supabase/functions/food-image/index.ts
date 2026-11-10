import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface PixabayHit {
  id: number;
  pageURL: string;
  type: string;
  tags: string;
  previewURL: string;
  previewWidth: number;
  previewHeight: number;
  webformatURL: string;
  webformatWidth: number;
  webformatHeight: number;
  largeImageURL: string;
  imageWidth: number;
  imageHeight: number;
  imageSize: number;
  views: number;
  downloads: number;
  collections: number;
  likes: number;
  comments: number;
  user_id: number;
  user: string;
  userImageURL: string;
}

interface ScoredCandidate {
  photoId: string;
  imageUrl: string;
  thumbnailUrl: string;
  photographerName: string;
  photographerUrl: string;
  sourcePageUrl: string;
  altDescription: string;
  provider: string;
  score: number;
}

function normalizeKey(str: string): string {
  return str
    .toLowerCase()
    .replace(/\b(\d+[\.\d]*\s*(g|kg|ml|l|oz|lb|cups?|tbsp|tsp|pieces?|items?|slices?))\b/gi, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function calculateMatchScore(query: string, alt: string, urlSlug: string, entityType: string): number {
  const normQuery = normalizeKey(query);
  const normAlt = (alt || '').toLowerCase();
  const normSlug = (urlSlug || '').toLowerCase();
  const text = `${normAlt} ${normSlug}`;

  if (!text.trim()) return 10;

  const queryTokens = normQuery.split(' ').filter((t) => t.length > 2);
  if (queryTokens.length === 0) return 20;

  // Exact phrase match
  if (text.includes(normQuery)) {
    return 100;
  }

  // Token matches
  let matched = 0;
  for (const token of queryTokens) {
    if (text.includes(token)) {
      matched++;
    }
  }

  const matchRatio = matched / queryTokens.length;

  // Specific check for ingredient false-friends (e.g. paneer vs tofu)
  if (normQuery.includes('paneer') && text.includes('tofu') && !text.includes('paneer')) {
    return 0; // Reject tofu when looking for paneer
  }
  if (normQuery.includes('apple') && text.includes('pineapple') && !text.includes('red apple') && !text.includes('fresh apple')) {
    // Pineapple isn't apple
    if (!text.includes('apple fruit') && !text.includes('green apple')) {
      matched = Math.max(0, matched - 1);
    }
  }

  return Math.round(matchRatio * 80);
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ ok: false, error: 'METHOD_NOT_ALLOWED', message: 'Only POST allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  try {
    // 1. Authenticate user
    const authHeader = req.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ ok: false, error: 'UNAUTHORIZED', message: 'Missing Authorization header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const token = authHeader.replace('Bearer ', '').trim();
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    let userId: string | null = null;
    const isServiceRole = Boolean(supabaseServiceKey && token === supabaseServiceKey);
    const isAnon = Boolean(supabaseAnonKey && token === supabaseAnonKey);

    let supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false },
    });

    if (isServiceRole) {
      userId = 'system-service-role';
      supabaseClient = createClient(supabaseUrl, supabaseServiceKey, {
        auth: { persistSession: false },
      });
    } else if (isAnon) {
      userId = null;
    } else {
      const { data: { user }, error: authError } = await supabaseClient.auth.getUser(token);
      if (user && !authError) {
        userId = user.id;
      }
    }

    // 2. Parse request payload
    const body = await req.json().catch(() => ({}));
    const action = String(body.action || 'resolve').toLowerCase(); // 'resolve' or 'search'
    const query = String(body.query || '').trim();
    const entityType = String(body.entityType || 'ingredient').toLowerCase();
    const orientation = String(body.orientation || (entityType === 'ingredient' ? 'square' : 'landscape')).toLowerCase();
    const perPage = Math.min(Math.max(Number(body.perPage || 5), 1), 15);

    if (!query) {
      return new Response(
        JSON.stringify({ ok: false, error: 'MISSING_QUERY', message: 'Query string is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 3. Dedicated Transparent Pan Cutout Resolution Action
    if (action === 'resolve-cutout') {
      const canonicalKey = normalizeKey(query);

      // Check DB mapping for pan_cutout_url
      const { data: dbEntry } = await supabaseClient
        .from('food_image_mappings')
        .select('pan_cutout_url')
        .eq('entity_type', entityType)
        .eq('entity_key', canonicalKey)
        .maybeSingle();

      if (dbEntry?.pan_cutout_url) {
        return new Response(
          JSON.stringify({
            ok: true,
            action,
            query,
            panCutoutUrl: dbEntry.pan_cutout_url,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Check Supabase Storage food-photos/cutouts/${canonicalKey}.png
      const cutoutPath = `cutouts/${canonicalKey}.png`;
      const { data: fileData } = await supabaseClient.storage
        .from('food-photos')
        .list('cutouts', { search: `${canonicalKey}.png`, limit: 1 });

      if (Array.isArray(fileData) && fileData.some((f) => f.name === `${canonicalKey}.png`)) {
        const { data: { publicUrl } } = supabaseClient.storage
          .from('food-photos')
          .getPublicUrl(cutoutPath);

        return new Response(
          JSON.stringify({
            ok: true,
            action,
            query,
            panCutoutUrl: publicUrl,
          }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Optional background removal pipeline (remove.bg or similar)
      const removeBgKey = Deno.env.get('REMOVE_BG_API_KEY');
      const inputImageUrl = body.imageUrl;
      if (removeBgKey && inputImageUrl) {
        try {
          const bgRes = await fetch('https://api.remove.bg/v1.0/removebg', {
            method: 'POST',
            headers: {
              'X-Api-Key': removeBgKey,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              image_url: inputImageUrl,
              size: 'auto',
              format: 'png',
            }),
          });

          if (bgRes.ok) {
            const pngBlob = await bgRes.blob();
            const { error: uploadError } = await supabaseClient.storage
              .from('food-photos')
              .upload(cutoutPath, pngBlob, {
                contentType: 'image/png',
                upsert: true,
              });

            if (!uploadError) {
              const { data: { publicUrl } } = supabaseClient.storage
                .from('food-photos')
                .getPublicUrl(cutoutPath);

              return new Response(
                JSON.stringify({
                  ok: true,
                  action,
                  query,
                  panCutoutUrl: publicUrl,
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
              );
            }
          }
        } catch (bgErr) {
          console.warn('Background removal pipeline error:', bgErr);
        }
      }

      // Return null so client falls back to clean transparent asset/placeholder
      return new Response(
        JSON.stringify({
          ok: true,
          action,
          query,
          panCutoutUrl: null,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Check Pixabay API Key
    const pixabayApiKey = Deno.env.get('PIXABAY_API_KEY');
    if (!pixabayApiKey) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'PIXABAY_API_KEY_NOT_CONFIGURED',
          message: 'Pixabay API key is not configured in Supabase secrets. Please set PIXABAY_API_KEY in Supabase Vault.',
          candidates: [],
          bestMatch: null,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Query official Pixabay API (https://pixabay.com/api/)
    const cleanQuery = query
      .replace(/[^a-zA-Z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();

    async function queryPixabay(searchTerm: string, categoryFilter?: string): Promise<{ status: number; hits: PixabayHit[] }> {
      const pixabayUrl = new URL('https://pixabay.com/api/');
      pixabayUrl.searchParams.set('key', pixabayApiKey!);
      pixabayUrl.searchParams.set('q', searchTerm);
      pixabayUrl.searchParams.set('image_type', 'photo');
      pixabayUrl.searchParams.set('safesearch', 'true');
      pixabayUrl.searchParams.set('per_page', String(Math.max(perPage, 5)));
      if (categoryFilter) {
        pixabayUrl.searchParams.set('category', categoryFilter);
      }
      if (orientation === 'horizontal' || orientation === 'vertical') {
        pixabayUrl.searchParams.set('orientation', orientation);
      }

      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 8000);

      const res = await fetch(pixabayUrl.toString(), {
        method: 'GET',
        headers: {
          'User-Agent': 'NutriFridge-App/1.0',
        },
        signal: controller.signal,
      }).finally(() => clearTimeout(timeoutId));

      if (!res.ok) {
        return { status: res.status, hits: [] };
      }
      const data = await res.json();
      return { status: 200, hits: Array.isArray(data.hits) ? data.hits : [] };
    }

    // First attempt: food category filter
    let { status: pixabayStatus, hits: photos } = await queryPixabay(cleanQuery, 'food');

    // If no hits found under food category, retry without category filter (e.g. regional dishes)
    if (pixabayStatus === 200 && photos.length === 0) {
      const broad = await queryPixabay(cleanQuery);
      if (broad.status === 200) {
        photos = broad.hits;
      }
    }

    if (pixabayStatus === 429) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'RATE_LIMITED',
          message: 'Pixabay API rate limit exceeded. Please try again later.',
          candidates: [],
          bestMatch: null,
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (pixabayStatus !== 200 && photos.length === 0) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'PROVIDER_ERROR',
          message: `Pixabay API responded with status ${pixabayStatus}`,
          candidates: [],
          bestMatch: null,
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 6. Score and normalize candidates
    const candidates: ScoredCandidate[] = [];
    for (const p of photos) {
      const score = calculateMatchScore(query, p.tags, p.pageURL, entityType);

      // Webformat (~640px) is ideal for inventory and cards; largeImageURL (~1280px) for recipe hero
      const primaryUrl = entityType === 'recipe'
        ? (p.largeImageURL || p.webformatURL)
        : (p.webformatURL || p.largeImageURL);

      candidates.push({
        photoId: String(p.id),
        imageUrl: primaryUrl,
        thumbnailUrl: p.previewURL || p.webformatURL,
        photographerName: p.user || 'Pixabay Contributor',
        photographerUrl: p.user ? `https://pixabay.com/users/${p.user}-${p.user_id}/` : 'https://pixabay.com',
        sourcePageUrl: p.pageURL || 'https://pixabay.com',
        altDescription: p.tags || query,
        provider: 'pixabay',
        score,
      });
    }

    // Sort descending by score
    candidates.sort((a, b) => b.score - a.score);

    // Filter acceptable matches for automatic resolution (threshold >= 35)
    const bestMatch = candidates.length > 0 && candidates[0].score >= 35
      ? candidates[0]
      : null;

    // Check existing pan cutout for this entity
    let panCutoutUrl: string | null = null;
    const canonicalKey = normalizeKey(query);
    try {
      const { data: existingEntry } = await supabaseClient
        .from('food_image_mappings')
        .select('pan_cutout_url')
        .eq('entity_type', entityType)
        .eq('entity_key', canonicalKey)
        .maybeSingle();
      if (existingEntry?.pan_cutout_url) {
        panCutoutUrl = existingEntry.pan_cutout_url;
      }
    } catch (_) {}

    // 7. If action is resolve and bestMatch found, optionally persist to shared catalog using service role
    if (action === 'resolve' && bestMatch && supabaseServiceKey) {
      try {
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
          auth: { persistSession: false },
        });

        await supabaseAdmin.from('food_image_mappings').upsert(
          {
            entity_type: entityType,
            entity_key: canonicalKey,
            display_name: query,
            image_url: bestMatch.imageUrl,
            pan_cutout_url: panCutoutUrl,
            provider: 'pixabay',
            provider_photo_id: bestMatch.photoId,
            photographer_name: bestMatch.photographerName,
            photographer_url: bestMatch.photographerUrl,
            source_page_url: bestMatch.sourcePageUrl,
            alt_description: bestMatch.altDescription,
            is_user_override: false,
            user_id: null, // Shared catalog
          },
          {
            onConflict: 'entity_type,entity_key,user_id',
            ignoreDuplicates: false,
          }
        );
      } catch (dbErr) {
        // Non-blocking: even if DB save fails, we still return the candidate
        console.warn('Could not save shared mapping to DB:', dbErr);
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        action,
        query,
        entityType,
        totalFound: photos.length,
        candidates,
        bestMatch,
        panCutoutUrl,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        ok: false,
        error: 'INTERNAL_ERROR',
        message: err.message || 'An unexpected error occurred during image search',
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
