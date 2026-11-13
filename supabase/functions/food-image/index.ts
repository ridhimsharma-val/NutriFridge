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

function getIngredientVariants(term: string): string[] {
  const norm = term.toLowerCase().trim();
  const variants = new Set<string>([norm]);

  // Handle common plurals & singulars
  if (norm.endsWith('y')) {
    variants.add(`${norm.slice(0, -1)}ies`);
  }
  if (norm.endsWith('ies')) {
    variants.add(`${norm.slice(0, -3)}y`);
  }
  if (norm.endsWith('ches') || norm.endsWith('shes') || norm.endsWith('xes')) {
    variants.add(norm.slice(0, -2));
  }
  if (norm.endsWith('ch') || norm.endsWith('sh') || norm.endsWith('x')) {
    variants.add(`${norm}es`);
  }
  if (norm.endsWith('oes')) {
    variants.add(norm.slice(0, -2));
  }
  if (norm.endsWith('o')) {
    variants.add(`${norm}es`);
    variants.add(`${norm}s`);
  }
  if (norm.endsWith('s') && !norm.endsWith('ss') && norm.length > 3) {
    variants.add(norm.slice(0, -1));
  }
  if (!norm.endsWith('s')) {
    variants.add(`${norm}s`);
  }

  // Food-specific culinary synonyms
  if (norm === 'peach' || norm === 'peaches') {
    variants.add('peach');
    variants.add('peaches');
    variants.add('nectarine');
  }
  if (norm === 'bell pepper' || norm === 'capsicum' || norm === 'pepper') {
    variants.add('capsicum');
    variants.add('bell pepper');
    variants.add('sweet pepper');
  }
  if (norm === 'curd' || norm === 'yogurt' || norm === 'yoghurt') {
    variants.add('curd');
    variants.add('yogurt');
    variants.add('yoghurt');
  }
  if (norm === 'egg' || norm === 'eggs') {
    variants.add('egg');
    variants.add('eggs');
  }
  if (norm === 'watermelon' || norm === 'watermelons') {
    variants.add('watermelon');
    variants.add('watermelons');
  }
  if (norm === 'brinjal' || norm === 'eggplant' || norm === 'aubergine' || norm === 'indian eggplant') {
    variants.add('brinjal');
    variants.add('eggplant');
    variants.add('aubergine');
    variants.add('indian eggplant');
    variants.add('melanzana');
  }

  return Array.from(variants);
}

function calculateMatchScore(
  query: string,
  alt: string,
  urlSlug: string,
  entityType: string,
  cuisine?: string,
  ingredients?: string[]
): number {
  const normQuery = normalizeKey(query);
  const normAlt = (alt || '').toLowerCase();
  const normSlug = (urlSlug || '').toLowerCase();
  const text = `${normAlt} ${normSlug}`;

  if (!text.trim()) return 10;

  // 1. Penalize/reject wallpapers, vectors, desktop backgrounds, clipart, and graphics
  const isJunk = text.includes('wallpaper') || text.includes('cool backgrounds') || text.includes('desktop background') || text.includes('vector') || text.includes('illustration') || text.includes('clipart') || text.includes('drawing');
  if (isJunk) return 0;

  // Reject sweets, candies, and non-food items unless explicitly in query
  if (!normQuery.includes('candy') && !normQuery.includes('gummy') && !normQuery.includes('sweet')) {
    if (text.includes('gummy') || text.includes('lollipop') || text.includes('candies') || text.includes('candy')) {
      return 0;
    }
  }

  // Reject drinks, juices, and smoothies when searching for raw ingredients
  if (!normQuery.includes('juice') && !normQuery.includes('drink') && !normQuery.includes('smoothie') && !normQuery.includes('cocktail')) {
    if (text.includes('juice') || text.includes('smoothie') || text.includes('cocktail') || text.includes('beverage')) {
      return 15; // Strongly downrank liquid drinks when searching for whole/raw food
    }
  }

  // Downrank mixed fruit salads/baskets when searching for single fruit
  if (!normQuery.includes('salad') && !normQuery.includes('mix') && !normQuery.includes('basket')) {
    if (text.includes('fruit salad') || text.includes('mixed fruit') || text.includes('fruit basket')) {
      return 25;
    }
  }

  if (entityType === 'recipe') {
    // 2. Strict vegetarian filter: If the dish is vegetarian/paneer/veg/dal, reject any meat/chicken/fish
    const isVegQuery = normQuery.includes('veg') || normQuery.includes('paneer') || normQuery.includes('dal') || normQuery.includes('salad');
    const hasMeat = text.includes('chicken') || text.includes('meat') || text.includes('beef') || text.includes('pork') || text.includes('fish') || text.includes('drumstick') || text.includes('mutton') || text.includes('seafood');
    if (isVegQuery && hasMeat) return 0;

    // 3. Exact phrase match (e.g. "shahi paneer", "vegetable biryani")
    if (text.includes(normQuery)) {
      return 95;
    }

    const queryTokens = normQuery.split(' ').filter((t) => t.length > 2);
    if (queryTokens.length === 0) return 20;

    // Identify primary dish anchor (usually the last word or distinct noun, e.g. "biryani", "paneer", "soup", "curry", "pizza", "salad")
    const mainDishNoun = queryTokens[queryTokens.length - 1];
    const hasMainNoun = text.includes(mainDishNoun);

    if (!hasMainNoun) {
      return 10; // Reject if core dish noun isn't in candidate tags
    }

    let score = 55; // Base score for having the core dish noun

    // Match other query tokens (e.g. "shahi", "vegetable")
    let otherMatches = 0;
    for (let i = 0; i < queryTokens.length - 1; i++) {
      if (text.includes(queryTokens[i])) otherMatches++;
    }
    score += otherMatches * 20;

    // Recipe & culinary context tags
    const hasCulinaryContext = text.includes('dish') || text.includes('recipe') || text.includes('curry') || text.includes('cooked') || text.includes('meal') || text.includes('cuisine') || text.includes('bowl');
    if (hasCulinaryContext) score += 15;

    // Cuisine match (e.g. "indian", "asian")
    if (cuisine && text.includes(cuisine.toLowerCase())) {
      score += 10;
    } else if (text.includes('indian') || text.includes('asian')) {
      score += 10;
    }

    // Ingredients match (e.g. "rice", "spices")
    if (Array.isArray(ingredients)) {
      for (const ing of ingredients) {
        if (typeof ing === 'string' && ing.length > 2 && text.includes(ing.toLowerCase())) {
          score += 5;
        }
      }
    }

    return Math.min(score, 95);
  }

  // Ingredient scoring
  const isBrinjalQuery = normQuery === 'brinjal' || normQuery === 'eggplant' || normQuery === 'aubergine' || normQuery === 'indian eggplant';
  if (isBrinjalQuery) {
    const hasBrinjalWord = text.includes('brinjal') || text.includes('eggplant') || text.includes('aubergine') || text.includes('melanzana');
    if (!hasBrinjalWord) return 0; // Strictly reject unrelated vegetables (carrots, potatoes, etc.)
    if (text.includes('basket') || text.includes('assorted') || text.includes('mixed vegetable')) {
      return 25; // Downrank mixed vegetable baskets
    }
  }

  if (normQuery.includes('paneer') && text.includes('tofu') && !text.includes('paneer')) {
    return 0; // Reject tofu when looking for paneer
  }
  if ((normQuery === 'apple' || normQuery === 'apples') && text.includes('pineapple') && !text.includes('red apple') && !text.includes('fresh apple')) {
    if (!text.includes('apple fruit') && !text.includes('green apple')) {
      return 0;
    }
  }

  // Check ingredient variants (handles peaches <-> peach, blueberries <-> blueberry, etc.)
  const variants = getIngredientVariants(normQuery);
  for (const variant of variants) {
    if (text.includes(variant)) {
      return 100;
    }
  }

  const queryTokens = normQuery.split(' ').filter((t) => t.length > 2);
  if (queryTokens.length === 0) return 20;

  let matched = 0;
  for (const token of queryTokens) {
    const tokenVariants = getIngredientVariants(token);
    if (tokenVariants.some((v) => text.includes(v))) {
      matched++;
    }
  }
  const matchRatio = matched / queryTokens.length;
  return Math.max(10, Math.round(matchRatio * 85));
}

// Configurable confidence thresholds
const INGREDIENT_SCORE_THRESHOLD = 35;
const RECIPE_SCORE_THRESHOLD = 65; // Recipes require high confidence to avoid mismatched dishes

async function mirrorImageToStorage(
  supabaseAdmin: any,
  photoId: string,
  sourceImageUrl: string,
  entityType: string
): Promise<string | null> {
  const bucketName = 'food-photos';
  const targetPath = `${entityType}s/${photoId}.jpg`;

  // 1. Check if already stored in Supabase Storage
  try {
    const { data: existingList } = await supabaseAdmin.storage
      .from(bucketName)
      .list(`${entityType}s`, { search: `${photoId}.jpg`, limit: 1 });

    if (Array.isArray(existingList) && existingList.some((f: any) => f.name === `${photoId}.jpg`)) {
      const { data: { publicUrl } } = supabaseAdmin.storage
        .from(bucketName)
        .getPublicUrl(targetPath);
      if (publicUrl) return publicUrl;
    }
  } catch (_) {}

  // 2. Fetch from Pixabay server-side
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    const imgRes = await fetch(sourceImageUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
      },
      signal: controller.signal,
    }).finally(() => clearTimeout(timeout));
    if (!imgRes.ok) {
      console.warn(`Failed to fetch image from Pixabay: status ${imgRes.status}`);
      return null;
    }

    const arrayBuffer = await imgRes.arrayBuffer();
    const contentType = imgRes.headers.get('content-type') || 'image/jpeg';

    // 3. Ensure bucket exists
    try {
      await supabaseAdmin.storage.createBucket(bucketName, { public: true });
    } catch (_) {}

    // 4. Upload to bucket
    const { error: uploadError } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(targetPath, arrayBuffer, {
        contentType,
        upsert: true,
      });

    if (uploadError) {
      console.warn(`Storage upload warning for ${targetPath}:`, uploadError);
      return null;
    }

    const { data: { publicUrl } } = supabaseAdmin.storage
      .from(bucketName)
      .getPublicUrl(targetPath);

    return publicUrl || null;
  } catch (err) {
    console.warn(`Storage mirroring warning for photo ${photoId}:`, err);
    return null;
  }
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

    // 4. Dedicated Image Mirror Action for User Overrides or Client Caching
    if (action === 'mirror') {
      const photoId = String(body.photoId || '').trim();
      const sourceUrl = String(body.imageUrl || '').trim();
      if (!photoId || !sourceUrl) {
        return new Response(
          JSON.stringify({ ok: false, error: 'MISSING_PARAMS', message: 'photoId and imageUrl are required' }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (supabaseServiceKey) {
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, { auth: { persistSession: false } });
        const persistentUrl = await mirrorImageToStorage(supabaseAdmin, photoId, sourceUrl, entityType);
        return new Response(
          JSON.stringify({ ok: true, action, photoId, originalUrl: sourceUrl, persistentUrl }),
          { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ ok: true, action, photoId, persistentUrl: sourceUrl }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Check Pixabay API Key
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

    const canonicalKey = normalizeKey(query);

    // Check existing mapping in database first to avoid redundant external API calls and downloads
    if (action === 'resolve' && supabaseServiceKey) {
      try {
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, { auth: { persistSession: false } });
        const { data: existingMapping } = await supabaseAdmin
          .from('food_image_mappings')
          .select('*')
          .eq('entity_type', entityType)
          .eq('entity_key', canonicalKey)
          .or(userId ? `user_id.is.null,user_id.eq.${userId}` : 'user_id.is.null')
          .order('is_user_override', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (existingMapping && existingMapping.image_url) {
          return new Response(
            JSON.stringify({
              ok: true,
              action,
              query,
              entityType,
              totalFound: 1,
              candidates: [],
              bestMatch: {
                photoId: existingMapping.provider_photo_id || 'stored',
                imageUrl: existingMapping.image_url,
                thumbnailUrl: existingMapping.image_url,
                photographerName: existingMapping.photographer_name || 'Pixabay Contributor',
                photographerUrl: existingMapping.photographer_url || 'https://pixabay.com',
                sourcePageUrl: existingMapping.source_page_url || 'https://pixabay.com',
                altDescription: existingMapping.alt_description || query,
                provider: existingMapping.provider || 'pixabay',
                score: 100,
              },
              panCutoutUrl: existingMapping.pan_cutout_url,
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      } catch (err) {
        console.warn('Error checking existing mapping:', err);
      }
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
      pixabayUrl.searchParams.set('order', 'popular');
      pixabayUrl.searchParams.set('per_page', String(Math.max(perPage, 15)));
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

    // Smart synonym expansion for brinjal / eggplant to retrieve rich purple aubergine photographs
    if (canonicalKey === 'brinjal' || canonicalKey === 'eggplant' || canonicalKey === 'aubergine' || canonicalKey === 'indian eggplant') {
      const eggplantHits = await queryPixabay('purple eggplant', 'food');
      if (eggplantHits.status === 200 && eggplantHits.hits.length > 0) {
        photos = [...photos, ...eggplantHits.hits];
      }
    }

    // Smart culinary fallback for recipes when exact query returns no or weak hits
    if (entityType === 'recipe') {
      const queryTokens = cleanQuery.toLowerCase().split(' ').filter((t) => t.length > 2);
      const mainDishNoun = queryTokens.length > 0 ? queryTokens[queryTokens.length - 1] : '';

      const preScores = photos.map((p) => calculateMatchScore(cleanQuery, p.tags, p.pageURL, entityType, body.cuisine, body.ingredients));
      const hasAcceptableMatch = preScores.some((s) => s >= RECIPE_SCORE_THRESHOLD);

      if (!hasAcceptableMatch && mainDishNoun) {
        let fallbackTerm = '';
        if (cleanQuery.includes('biryani')) {
          fallbackTerm = 'biryani';
        } else if (cleanQuery.includes('paneer')) {
          fallbackTerm = 'paneer dish';
        } else if (body.cuisine) {
          fallbackTerm = `${body.cuisine} ${mainDishNoun}`;
        } else {
          fallbackTerm = `${mainDishNoun} dish`;
        }

        if (fallbackTerm && fallbackTerm.toLowerCase() !== cleanQuery.toLowerCase()) {
          const fallbackRes = await queryPixabay(fallbackTerm, 'food');
          if (fallbackRes.status === 200 && fallbackRes.hits.length > 0) {
            photos = [...photos, ...fallbackRes.hits];
          }
        }
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
    const seenPhotoIds = new Set<string>();
    for (const p of photos) {
      const pid = String(p.id);
      if (seenPhotoIds.has(pid)) continue;
      seenPhotoIds.add(pid);

      let score = calculateMatchScore(query, p.tags, p.pageURL, entityType, body.cuisine, body.ingredients);

      // Quality & popularity bonuses
      if (score > 0) {
        if (p.likes > 100) score += 5;
        if (p.downloads > 500) score += 5;
        if (p.imageWidth >= 640 && p.imageHeight >= 480) score += 5;
      }

      // Webformat (~640px) is ideal for inventory and cards; largeImageURL (~1280px) for recipe hero
      let primaryUrl = entityType === 'recipe'
        ? (p.largeImageURL || p.webformatURL)
        : (p.webformatURL || p.largeImageURL);

      if (primaryUrl && primaryUrl.includes('pixabay.com/get/') && p.previewURL && p.previewURL.includes('cdn.pixabay.com/photo/')) {
        primaryUrl = p.previewURL.replace(/_(150|60)\./, entityType === 'recipe' ? '_1280.' : '_640.');
      }

      candidates.push({
        photoId: pid,
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

    // Sort descending by score, tie-breaking by popularity
    candidates.sort((a, b) => b.score - a.score);

    // Filter acceptable matches for automatic resolution (threshold is entity-specific)
    const threshold = entityType === 'recipe' ? RECIPE_SCORE_THRESHOLD : INGREDIENT_SCORE_THRESHOLD;
    const bestMatch = candidates.length > 0 && candidates[0].score >= threshold
      ? candidates[0]
      : null;

    // Check existing pan cutout for this entity
    let panCutoutUrl: string | null = null;
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

    // 7. If action is resolve and high-confidence bestMatch found, mirror to Supabase Storage and persist to shared catalog
    if (action === 'resolve' && bestMatch && supabaseServiceKey) {
      try {
        const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
          auth: { persistSession: false },
        });

        // Download server-side and mirror to Supabase Storage to comply with Pixabay hotlinking policies
        const persistentUrl = await mirrorImageToStorage(
          supabaseAdmin,
          bestMatch.photoId,
          bestMatch.imageUrl,
          entityType
        );

        if (persistentUrl) {
          bestMatch.imageUrl = persistentUrl;
          await supabaseAdmin.from('food_image_mappings').upsert(
            {
              entity_type: entityType,
              entity_key: canonicalKey,
              display_name: query,
              image_url: persistentUrl,
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
        } else {
          // Hotlinking compliance: do NOT persist Pixabay CDN URL to DB if storage mirroring is unavailable
          console.warn(`Storage mirror unavailable for photo ${bestMatch.photoId}. Skipping database persistence to prevent permanent hotlinking.`);
        }
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
