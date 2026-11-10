import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface PexelsPhoto {
  id: number;
  width: number;
  height: number;
  url: string;
  photographer: string;
  photographer_url: string;
  photographer_id: number;
  avg_color: string;
  src: {
    original: string;
    large2x: string;
    large: string;
    medium: string;
    small: string;
    portrait: string;
    landscape: string;
    tiny: string;
  };
  liked: boolean;
  alt: string;
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

    const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false },
    });

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser(token);
    if (authError || !user) {
      return new Response(
        JSON.stringify({ ok: false, error: 'UNAUTHORIZED', message: 'Invalid or expired session token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
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
      const { data: dbEntry } = await supabaseUser
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
      const { data: fileData } = await supabaseUser.storage
        .from('food-photos')
        .list('cutouts', { search: `${canonicalKey}.png`, limit: 1 });

      if (Array.isArray(fileData) && fileData.some((f) => f.name === `${canonicalKey}.png`)) {
        const { data: { publicUrl } } = supabaseUser.storage
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
            const { error: uploadError } = await supabaseUser.storage
              .from('food-photos')
              .upload(cutoutPath, pngBlob, {
                contentType: 'image/png',
                upsert: true,
              });

            if (!uploadError) {
              const { data: { publicUrl } } = supabaseUser.storage
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

    // 4. Check Pexels API Key
    const pexelsApiKey = Deno.env.get('PEXELS_API_KEY');
    if (!pexelsApiKey) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'PEXELS_API_KEY_NOT_CONFIGURED',
          message: 'Pexels API key is not configured in Supabase secrets. Please set PEXELS_API_KEY in Supabase Vault.',
          candidates: [],
          bestMatch: null,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 4. Request Pexels Search Photos API
    const pexelsUrl = new URL('https://api.pexels.com/v1/search');
    pexelsUrl.searchParams.set('query', query);
    pexelsUrl.searchParams.set('per_page', String(perPage));
    if (orientation === 'square' || orientation === 'landscape' || orientation === 'portrait') {
      pexelsUrl.searchParams.set('orientation', orientation);
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);

    const pexelsRes = await fetch(pexelsUrl.toString(), {
      method: 'GET',
      headers: {
        Authorization: pexelsApiKey,
        'User-Agent': 'NutriFridge-App/1.0',
      },
      signal: controller.signal,
    }).finally(() => clearTimeout(timeoutId));

    if (pexelsRes.status === 429) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'RATE_LIMITED',
          message: 'Pexels API rate limit exceeded. Please try again later.',
          candidates: [],
          bestMatch: null,
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    if (!pexelsRes.ok) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'PROVIDER_ERROR',
          message: `Pexels API responded with status ${pexelsRes.status}`,
          candidates: [],
          bestMatch: null,
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const pexelsData = await pexelsRes.json();
    const photos: PexelsPhoto[] = Array.isArray(pexelsData.photos) ? pexelsData.photos : [];

    // 5. Score and normalize candidates
    const candidates: ScoredCandidate[] = [];
    for (const p of photos) {
      const slug = p.url.split('/photo/')[1] || '';
      const score = calculateMatchScore(query, p.alt, slug, entityType);

      // Choose image sizes:
      // For recipes/meal hero: 'large' (approx 940px wide) or 'medium'
      // For ingredients: 'medium' (approx 350px)
      const primaryUrl = entityType === 'recipe'
        ? (p.src.large || p.src.medium || p.src.original)
        : (p.src.medium || p.src.small || p.src.original);

      candidates.push({
        photoId: String(p.id),
        imageUrl: primaryUrl,
        thumbnailUrl: p.src.tiny || p.src.small,
        photographerName: p.photographer || 'Pexels Photographer',
        photographerUrl: p.photographer_url || 'https://www.pexels.com',
        sourcePageUrl: p.url || 'https://www.pexels.com',
        altDescription: p.alt || query,
        provider: 'pexels',
        score,
      });
    }

    // Sort descending by score
    candidates.sort((a, b) => b.score - a.score);

    // Filter acceptable matches for automatic resolution (threshold >= 40)
    const bestMatch = candidates.length > 0 && candidates[0].score >= 40
      ? candidates[0]
      : null;

    // Check existing pan cutout for this entity
    let panCutoutUrl: string | null = null;
    const canonicalKey = normalizeKey(query);
    try {
      const { data: existingEntry } = await supabaseUser
        .from('food_image_mappings')
        .select('pan_cutout_url')
        .eq('entity_type', entityType)
        .eq('entity_key', canonicalKey)
        .maybeSingle();
      if (existingEntry?.pan_cutout_url) {
        panCutoutUrl = existingEntry.pan_cutout_url;
      }
    } catch (_) {}

    // 6. If action is resolve and bestMatch found, optionally persist to shared catalog using service role
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
            provider: 'pexels',
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
