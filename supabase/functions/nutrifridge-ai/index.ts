import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

/**
 * CORS headers allowing authenticated Flutter clients (web & mobile)
 */
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const CANONICAL_CATEGORIES = [
  'Dairy Products',
  'Others',
  'Non-Veg',
  'Meals & Leftovers',
  'Packaged Food',
  'Drinks & Juices',
  'Vegetables',
  'Fruits',
  'Ice Cream',
  'Frozen Food',
  'Dry Fruits',
];

function normalizeCategory(cat: unknown): string {
  if (!cat || typeof cat !== 'string') return 'Others';
  const clean = cat.trim();
  for (const c of CANONICAL_CATEGORIES) {
    if (c.toLowerCase() === clean.toLowerCase()) return c;
  }
  const u = clean.toUpperCase();
  if (u.includes('DAIRY')) return 'Dairy Products';
  if (u.includes('ICE CREAM')) return 'Ice Cream';
  if (u.includes('FROZEN')) return 'Frozen Food';
  if (u.includes('DRY FRUIT')) return 'Dry Fruits';
  if (u.includes('NON-VEG') || u.includes('NON VEG')) return 'Non-Veg';
  if (u.includes('LEFTOVER') || u.includes('MEAL')) return 'Meals & Leftovers';
  if (u.includes('PACKAGE')) return 'Packaged Food';
  if (u.includes('DRINK') || u.includes('JUICE')) return 'Drinks & Juices';
  if (u.includes('VEG')) return 'Vegetables';
  if (u.includes('FRUIT')) return 'Fruits';
  return 'Others';
}

function normalizeN8nResponse(decoded: any): Record<string, any> {
  let map: Record<string, any> = {};

  if (Array.isArray(decoded)) {
    if (decoded.length > 0 && typeof decoded[0] === 'object' && decoded[0] !== null) {
      return normalizeN8nResponse(decoded[0]);
    }
    return {
      ok: true,
      action: 'assistant_reply',
      assistantMessage: 'Received empty response from assistant.',
      requiresConfirmation: false,
      needsClarification: false,
      inventoryItems: [],
      meal: null,
    };
  }

  if (typeof decoded === 'string') {
    const trimmed = decoded.trim();
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) || (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        return normalizeN8nResponse(JSON.parse(trimmed));
      } catch (_) {}
    }
    return {
      ok: true,
      action: 'assistant_reply',
      assistantMessage: decoded,
      requiresConfirmation: false,
      needsClarification: false,
      inventoryItems: [],
      meal: null,
    };
  }

  if (typeof decoded === 'object' && decoded !== null) {
    map = { ...decoded };

    // Unwrap nested wrappers
    if (map.responseBody && typeof map.responseBody === 'object') {
      return normalizeN8nResponse(map.responseBody);
    }
    if (map.body && typeof map.body === 'object') {
      return normalizeN8nResponse(map.body);
    }
    if (map.data && typeof map.data === 'object' && !map.action) {
      return normalizeN8nResponse(map.data);
    }
    if (map.output && !map.action) {
      if (typeof map.output === 'object') {
        return normalizeN8nResponse(map.output);
      } else if (typeof map.output === 'string') {
        const trimmed = map.output.trim();
        if ((trimmed.startsWith('{') && trimmed.endsWith('}')) || (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
          try {
            return normalizeN8nResponse(JSON.parse(trimmed));
          } catch (_) {}
        }
        return {
          ...map,
          ok: true,
          action: 'assistant_reply',
          assistantMessage: map.output,
          requiresConfirmation: false,
          needsClarification: false,
          inventoryItems: [],
          meal: null,
        };
      }
    }
  }

  const validActions = [
    'add_inventory_items',
    'remove_inventory_items',
    'remove_inventory_item',
    'log_meal',
    'query_inventory',
    'assistant_reply',
    'update_inventory_item',
    'clarification_needed',
    'meal_recommendation',
    'no_match',
    'cook_recipe',
    'recipe_instructions',
  ];

  let action = typeof map.action === 'string' ? map.action.toLowerCase() : 'assistant_reply';
  if (action === 'remove_inventory_item') action = 'remove_inventory_items';
  if (!validActions.includes(action)) action = 'assistant_reply';

  const assistantMessage =
    typeof map.assistantMessage === 'string' && map.assistantMessage.trim().length > 0
      ? map.assistantMessage.trim()
      : typeof map.message === 'string' && map.message.trim().length > 0
      ? map.message.trim()
      : 'Processed your request successfully.';

  const needsClarification = action === 'clarification_needed' || Boolean(map.needsClarification);
  const clarifyingQuestion = needsClarification
    ? map.clarifyingQuestion || map.assistantMessage || 'Could you please clarify your request?'
    : null;

  const mutationActions = [
    'add_inventory_items',
    'remove_inventory_items',
    'log_meal',
    'update_inventory_item',
  ];
  const requiresConfirmation = mutationActions.includes(action)
    ? true
    : Boolean(map.requiresConfirmation);

  const rawInventoryItems = Array.isArray(map.inventoryItems)
    ? map.inventoryItems
    : Array.isArray(map.items)
    ? map.items
    : [];

  const inventoryItems: Array<Record<string, any>> = [];
  for (const it of rawInventoryItems) {
    if (it && typeof it === 'object' && it.name) {
      const q = typeof it.quantity === 'number' && it.quantity > 0 ? it.quantity : null;
      const isFullRemoval = Boolean(it.isFullRemoval) || (action === 'remove_inventory_items' && q === null);
      inventoryItems.push({
        name: String(it.name).trim(),
        category: normalizeCategory(it.category),
        quantity: q,
        unit: it.unit ? String(it.unit).trim() : (q ? 'pieces' : null),
        isFullRemoval: isFullRemoval,
        matchedInventoryItemId: it.matchedInventoryItemId ?? it.id ?? null,
        expiryDate: it.expiryDate ?? null,
        expiryDaysEstimate: typeof it.expiryDaysEstimate === 'number' ? it.expiryDaysEstimate : null,
        confidence: typeof it.confidence === 'number' ? Math.min(1.0, Math.max(0.0, it.confidence)) : 0.95,
      });
    }
  }

  let meal: Record<string, any> | null = null;
  if ((action === 'log_meal' || action === 'meal_recommendation' || action === 'cook_recipe' || action === 'recipe_instructions') && map.meal && typeof map.meal === 'object') {
    const m = map.meal;
    const ingredients: Array<Record<string, any>> = [];
    if (Array.isArray(m.ingredients)) {
      for (const ing of m.ingredients) {
        if (ing && typeof ing === 'object' && ing.name) {
          ingredients.push({
            name: String(ing.name).trim(),
            quantity: typeof ing.quantity === 'number' ? ing.quantity : null,
            unit: ing.unit ? String(ing.unit).trim() : null,
            matchedInventoryItemId: ing.matchedInventoryItemId ?? null,
            suggestedDeductionQuantity:
              typeof ing.suggestedDeductionQuantity === 'number' ? ing.suggestedDeductionQuantity : null,
            deductionNeedsUserConfirmation: true,
          });
        }
      }
    }

    const rawNutr = m.nutrition && typeof m.nutrition === 'object' ? m.nutrition : {};
    const preparationSteps: Array<Record<string, any>> = [];
    const rawSteps = m.preparationSteps || m.steps || m.instructions;
    if (Array.isArray(rawSteps)) {
      for (let i = 0; i < rawSteps.length; i++) {
        const s = rawSteps[i];
        if (s && typeof s === 'object') {
          preparationSteps.push({
            stepNumber: typeof s.stepNumber === 'number' ? s.stepNumber : i + 1,
            instruction: String(s.instruction || s.text || s.description || '').trim(),
            time: s.time ? String(s.time).trim() : null,
            temperature: s.temperature ? String(s.temperature).trim() : null,
            tip: s.tip ? String(s.tip).trim() : null,
          });
        } else if (typeof s === 'string' && s.trim().length > 0) {
          preparationSteps.push({
            stepNumber: i + 1,
            instruction: s.trim(),
            time: null,
            temperature: null,
            tip: null,
          });
        }
      }
    }

    const cookingTips = Array.isArray(m.cookingTips)
      ? m.cookingTips.map(String)
      : Array.isArray(m.tips)
      ? m.tips.map(String)
      : [];

    const substitutions = Array.isArray(m.substitutions)
      ? m.substitutions.map(String)
      : Array.isArray(m.alternatives)
      ? m.alternatives.map(String)
      : [];

    function parseMinutes(val: any): number | null {
      if (typeof val === 'number' && !isNaN(val) && val >= 0) return Math.round(val);
      if (typeof val === 'string') {
        const match = val.match(/\d+/);
        if (match) {
          const n = parseInt(match[0], 10);
          if (!isNaN(n) && n >= 0) return n;
        }
      }
      return null;
    }

    const resolvedPrepTime = parseMinutes(
      m.preparationTimeMinutes ??
      m.prepTimeMinutes ??
      m.prepTime ??
      m.preparation_time_minutes ??
      m.prep_time_minutes ??
      m.prep_time
    );

    const resolvedCookingTime = parseMinutes(
      m.cookingTimeMinutes ??
      m.cookingTime ??
      m.cookTimeMinutes ??
      m.cookTime ??
      m.cooking_time_minutes ??
      m.cook_time_minutes ??
      m.cook_time
    );

    meal = {
      name: m.name ? String(m.name).trim() : 'Logged Meal',
      mealType: m.mealType ? String(m.mealType).toLowerCase().trim() : 'lunch',
      ingredients: ingredients,
      id: m.id ? String(m.id).trim() : `rec_${Date.now()}`,
      description: m.description
        ? String(m.description).trim()
        : m.reason
        ? String(m.reason).trim()
        : 'A meal prepared with ingredients from your fridge.',
      preparationTimeMinutes: resolvedPrepTime,
      cookingTimeMinutes: resolvedCookingTime,
      servings: m.servings ? String(m.servings).trim() : (m.servingSize ? String(m.servingSize).trim() : '1 serving'),
      missingIngredients: Array.isArray(m.missingIngredients) ? m.missingIngredients.map(String) : [],
      preparationSteps: preparationSteps,
      cookingTips: cookingTips,
      substitutions: substitutions,
      videoSearchQuery: m.videoSearchQuery ? String(m.videoSearchQuery).trim() : `${m.name || 'recipe'} recipe`,
      videoUrl: m.videoUrl ? String(m.videoUrl).trim() : null,
      reason: m.reason ? String(m.reason).trim() : 'Uses ingredients from your fridge.',
      imageKey: m.imageKey ? String(m.imageKey).trim() : null,
      nutritionIsEstimate: true,
      calories:
        typeof m.calories === 'number'
          ? Math.round(m.calories)
          : typeof rawNutr.calories === 'number'
          ? Math.round(rawNutr.calories)
          : 450,
      proteinG:
        typeof m.proteinG === 'number'
          ? Math.round(m.proteinG)
          : typeof rawNutr.proteinG === 'number'
          ? Math.round(rawNutr.proteinG)
          : 20,
      carbsG:
        typeof m.carbsG === 'number'
          ? Math.round(m.carbsG)
          : typeof rawNutr.carbsG === 'number'
          ? Math.round(rawNutr.carbsG)
          : 50,
      fatG:
        typeof m.fatG === 'number'
          ? Math.round(m.fatG)
          : typeof rawNutr.fatG === 'number'
          ? Math.round(rawNutr.fatG)
          : 15,
      nutrition: {
        calories:
          typeof rawNutr.calories === 'number'
            ? Math.round(rawNutr.calories)
            : typeof m.calories === 'number'
            ? Math.round(m.calories)
            : 450,
        proteinG:
          typeof rawNutr.proteinG === 'number'
            ? Math.round(rawNutr.proteinG)
            : typeof m.proteinG === 'number'
            ? Math.round(m.proteinG)
            : 20,
        carbsG:
          typeof rawNutr.carbsG === 'number'
            ? Math.round(rawNutr.carbsG)
            : typeof m.carbsG === 'number'
            ? Math.round(m.carbsG)
            : 50,
        fatG:
          typeof rawNutr.fatG === 'number'
            ? Math.round(rawNutr.fatG)
            : typeof m.fatG === 'number'
            ? Math.round(m.fatG)
            : 15,
        isEstimate: true,
        estimateNote: rawNutr.estimateNote || 'Nutrition and portion values are approximate estimates.',
      },
    };
  }

  return {
    ok: true,
    action: action,
    assistantMessage: assistantMessage,
    requiresConfirmation: requiresConfirmation,
    needsClarification: needsClarification,
    clarifyingQuestion: clarifyingQuestion,
    inventoryItems: inventoryItems,
    meal: meal,
    inventoryQueryResults: Array.isArray(map.inventoryQueryResults) ? map.inventoryQueryResults : [],
    suggestedInventoryDeductions: Array.isArray(map.suggestedInventoryDeductions)
      ? map.suggestedInventoryDeductions
      : [],
    warnings: Array.isArray(map.warnings) ? map.warnings : [],
  };
}

serve(async (req: Request) => {
  const totalRequestStart = performance.now();

  // 1. CORS Preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: 'Method not allowed. Use POST.',
        error: { code: 'METHOD_NOT_ALLOWED', message: 'Only POST requests are supported.' },
      }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // 2. Validate Authenticated Session & Extract JWT Token
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    console.warn('AUTH_HEADER_MISSING');
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        error: 'MISSING_AUTHORIZATION',
        assistantMessage: 'Authentication required. Please sign in to access NutriFridge AI.',
      }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    console.warn('AUTH_HEADER_FORMAT_INVALID');
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        error: 'INVALID_AUTHORIZATION_FORMAT',
        assistantMessage: 'Invalid Authorization header format. Bearer token required.',
      }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const token = match[1].trim();
  console.log('AUTH_TOKEN_EXTRACTED');

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

  if (!supabaseUrl || !supabaseAnonKey) {
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: 'Server configuration error: Supabase environment variables missing.',
        error: { code: 'SERVER_MISCONFIGURED', message: 'SUPABASE_URL or SUPABASE_ANON_KEY not set.' },
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Client scoped strictly to the authenticated user's JWT
  const supabaseUser = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: {
        Authorization: authHeader,
      },
    },
  });

  // Explicitly validate token via auth.getUser(token)
  const {
    data: { user },
    error: authError,
  } = await supabaseUser.auth.getUser(token);

  if (authError || !user) {
    console.error('AUTH_GET_USER_FAILED', {
      message: authError?.message,
      status: authError?.status,
      name: authError?.name,
    });

    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        error: 'USER_AUTHENTICATION_FAILED',
        assistantMessage: 'Unable to verify the current user session. Please sign in again.',
      }),
      { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  console.log('AUTH_USER_VERIFIED');
  const userId = user.id; // Derived strictly from verified auth token, never client-supplied

  // 3. Parse & Validate Incoming Request Body
  let body: any;
  try {
    body = await req.json();
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: 'Malformed request payload. JSON format required.',
        error: { code: 'INVALID_JSON', message: err.message },
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  const message = typeof body.message === 'string' ? body.message.trim() : '';
  const source = typeof body.source === 'string' ? body.source.toLowerCase() : 'text';
  const actionHint = typeof body.actionHint === 'string' ? body.actionHint.toLowerCase() : 'auto';
  const recipeMode = typeof body.recipeMode === 'string' ? body.recipeMode.toLowerCase().trim() : null;
  const selectedInventoryItemIds = Array.isArray(body.selectedInventoryItemIds)
    ? body.selectedInventoryItemIds
    : null;
  const rawDishName = typeof body.preferredDishName === 'string' ? body.preferredDishName.trim() : null;
  const preferredDishName = (rawDishName && rawDishName.length > 0 && rawDishName.length <= 120)
    ? rawDishName
    : null;
  const currentMealPeriod = body.currentMealPeriod ?? body.targetMealSlot ?? null;
  const clientLocalTime = body.clientLocalTime ?? null;
  const imageBase64 = body.imageBase64 ?? null;
  const mimeType = body.mimeType ?? null;
  const clientHistory = Array.isArray(body.conversationHistory) ? body.conversationHistory : [];
  let conversationId = typeof body.conversationId === 'string' && body.conversationId.length > 0
    ? body.conversationId
    : null;

  if (source === 'text' && !message && actionHint !== 'meal_recommendation') {
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: 'Message text cannot be empty.',
        error: { code: 'EMPTY_MESSAGE', message: 'Message text is required when source is text.' },
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  if (message.length > 4000) {
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: 'Message is too long. Please shorten your message (max 4000 characters).',
        error: { code: 'MESSAGE_TOO_LONG', message: 'Character limit of 4000 exceeded.' },
      }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // 4. Fetch User Context with User-Level RLS Access
  console.log('USER_CONTEXT_QUERY_STARTED');
  const contextFetchStart = performance.now();
  const [
    fridgeRes,
    goalsRes,
    profileRes,
    prefRes,
    mealsRes,
    snapshotRes,
  ] = await Promise.all([
    supabaseUser
      .from('fridge_items')
      .select('id, name, category, quantity, unit, expiry_date')
      .order('created_at', { ascending: true }),

    supabaseUser
      .from('nutrition_goals')
      .select('target_calories, protein_target_g, carbs_target_g, fat_target_g')
      .maybeSingle(),

    supabaseUser
      .from('profiles')
      .select('display_name, dietary_preference, nutrition_goal, allergies, avoided_foods, custom_restrictions, timezone')
      .maybeSingle(),

    supabaseUser
      .from('fridge_preferences')
      .select('household_size')
      .maybeSingle(),

    supabaseUser
      .from('meals')
      .select('name, meal_type, calories, protein_g, carbs_g, fat_g')
      .order('logged_at', { ascending: false })
      .limit(3),

    supabaseUser
      .from('daily_nutrition_snapshots')
      .select('total_calories, protein_g, carbs_g, fat_g, meals_logged_count')
      .order('log_date', { ascending: false })
      .limit(1)
      .maybeSingle(),
  ]);
  const contextFetchDurationMs = Math.round(performance.now() - contextFetchStart);

  // If the inventory query fails with a database error, do not silently fall back
  if (fridgeRes.error) {
    console.error('INVENTORY_QUERY_FAILED', fridgeRes.error);
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: 'Unable to retrieve your fridge inventory from the database. Please tap retry.',
        error: {
          code: 'INVENTORY_FETCH_FAILED',
          message: fridgeRes.error.message ?? 'Failed to query fridge_items',
          retryable: true,
        },
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // If query succeeded: use database items if present; if empty (0 rows), allow permitted client fallback
  let inventoryContext = (fridgeRes.data && fridgeRes.data.length > 0)
    ? fridgeRes.data.map((it: any) => ({
        id: it.id,
        name: it.name,
        category: it.category,
        quantity: it.quantity,
        unit: it.unit,
        expiryDate: it.expiry_date,
      }))
    : (Array.isArray(body.inventoryContext) ? body.inventoryContext : []);

  // Server-side validation for selected_ingredients mode
  if (recipeMode === 'selected_ingredients') {
    // 1. Reject an empty selection
    if (!selectedInventoryItemIds || selectedInventoryItemIds.length === 0) {
      return new Response(
        JSON.stringify({
          ok: false,
          action: 'error',
          assistantMessage: 'Please select at least one ingredient from your fridge.',
          error: {
            code: 'EMPTY_SELECTION',
            message: 'selectedInventoryItemIds array must contain at least one item ID.',
          },
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 2. Validate UUID syntax
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    for (const rawId of selectedInventoryItemIds) {
      const idStr = String(rawId).trim();
      if (!uuidRegex.test(idStr)) {
        return new Response(
          JSON.stringify({
            ok: false,
            action: 'error',
            assistantMessage: 'One or more selected ingredient IDs are invalid.',
            error: {
              code: 'INVALID_UUID_SYNTAX',
              message: `Invalid UUID: ${idStr}`,
            },
          }),
          { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }
    }

    // 3. Remove duplicate IDs
    const uniqueItemIds = Array.from(
      new Set(selectedInventoryItemIds.map((id: string) => String(id).trim().toLowerCase()))
    );

    // 4. Query selected records from the authenticated user's fridge_items table using RLS
    const { data: dbSelectedItems, error: selectErr } = await supabaseUser
      .from('fridge_items')
      .select('id, name, category, quantity, unit, expiry_date')
      .in('id', uniqueItemIds);

    if (selectErr) {
      console.error('SELECTED_ITEMS_QUERY_FAILED', selectErr);
      return new Response(
        JSON.stringify({
          ok: false,
          action: 'error',
          assistantMessage: 'Unable to verify selected ingredients from database. Please tap retry.',
          error: {
            code: 'DATABASE_QUERY_ERROR',
            message: selectErr.message,
            retryable: true,
          },
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 5. Verify every requested ID belongs to the authenticated user and exists
    const foundMap = new Map<string, any>(
      (dbSelectedItems ?? []).map((it: any) => [String(it.id).toLowerCase(), it])
    );
    const missingIds = uniqueItemIds.filter((id) => !foundMap.has(id));
    if (missingIds.length > 0) {
      return new Response(
        JSON.stringify({
          ok: false,
          action: 'error',
          assistantMessage: 'One or more selected items could not be found or do not belong to your account.',
          error: {
            code: 'ITEM_NOT_FOUND_OR_UNAUTHORIZED',
            message: `Requested items not found in authenticated inventory: ${missingIds.join(', ')}`,
          },
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // 6. Use database-returned names, quantities, units and expiry information (ignore client-supplied quantities)
    const validatedSelectedContext = uniqueItemIds.map((id) => {
      const it = foundMap.get(id);
      return {
        id: it.id,
        name: it.name,
        category: it.category,
        quantity: it.quantity,
        unit: it.unit,
        expiryDate: it.expiry_date,
      };
    });

    // 7. Only validated selected inventory items become the primary ingredient context
    inventoryContext = validatedSelectedContext;
  } else if (recipeMode === 'named_dish_from_inventory') {
    // Server-side validation for named_dish_from_inventory mode
    if (!preferredDishName || preferredDishName.trim().length === 0) {
      return new Response(
        JSON.stringify({
          ok: false,
          action: 'error',
          assistantMessage: 'Please enter a dish name to generate a recipe.',
          error: {
            code: 'EMPTY_DISH_NAME',
            message: 'preferredDishName is required when recipeMode is named_dish_from_inventory.',
          },
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }
  }

  const userPreferences = {
    displayName: profileRes.data?.display_name ?? 'User',
    dietaryPreference: profileRes.data?.dietary_preference ?? 'None',
    nutritionGoal: profileRes.data?.nutrition_goal ?? 'Maintain Weight',
    allergies: profileRes.data?.allergies ?? [],
    avoidedFoods: profileRes.data?.avoided_foods ?? [],
    customRestrictions: profileRes.data?.custom_restrictions ?? [],
    timezone: profileRes.data?.timezone ?? 'UTC',
    householdSize: prefRes.data?.household_size ?? 1,
  };

  const todayNutrition = {
    consumedCalories: snapshotRes.data?.total_calories ?? 0,
    targetCalories: goalsRes.data?.target_calories ?? 2000,
    proteinGrams: snapshotRes.data?.protein_g ?? 0,
    carbsGrams: snapshotRes.data?.carbs_g ?? 0,
    fatGrams: snapshotRes.data?.fat_g ?? 0,
    mealsLoggedCount: snapshotRes.data?.meals_logged_count ?? 0,
  };

  const recentMeals = (mealsRes.data ?? []).map((m: any) => ({
    name: m.name,
    mealType: m.meal_type,
    calories: m.calories,
    proteinG: m.protein_g,
    carbsG: m.carbs_g,
    fatG: m.fat_g,
    loggedAt: m.logged_at,
  }));

  // 5. Manage Conversation Continuity & Append User Message
  if (!conversationId) {
    const { data: conv } = await supabaseUser
      .from('ai_conversations')
      .select('id')
      .order('last_message_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (conv?.id) {
      conversationId = conv.id;
    } else {
      const { data: newConv } = await supabaseUser
        .from('ai_conversations')
        .insert({ user_id: userId, title: 'Chat Session' })
        .select('id')
        .single();
      if (newConv?.id) {
        conversationId = newConv.id;
      }
    }
  }

  if (conversationId && message && actionHint !== 'meal_recommendation') {
    try {
      await supabaseUser.from('ai_messages').insert({
        conversation_id: conversationId,
        user_id: userId,
        role: 'user',
        content: message,
        action: actionHint,
        metadata: { source },
      });
    } catch (saveErr) {
      console.warn('[nutrifridge-ai] Warning: could not persist user message:', saveErr);
    }
  }

  // 6. Dispatch to n8n Webhook with Server-Side Secret
  const n8nWebhookUrl = Deno.env.get('N8N_WEBHOOK_URL');
  const n8nWebhookSecret = Deno.env.get('N8N_WEBHOOK_SECRET');

  if (!n8nWebhookUrl) {
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage:
          'NutriFridge AI service is currently not configured. Please configure N8N_WEBHOOK_URL.',
        error: { code: 'N8N_NOT_CONFIGURED', message: 'N8N_WEBHOOK_URL environment variable is missing.' },
      }),
      { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // Upstream n8n workflow strictly supports:
  // ['auto', 'add_food_single', 'add_food_multiple', 'receipt_scan', 'log_meal', 'assistant', 'meal_recommendation'].
  // Normalize 'cook_recipe' / 'recipe_instructions' to 'assistant' with mealContext.
  const n8nActionHint = (actionHint === 'cook_recipe' || actionHint === 'recipe_instructions')
    ? 'assistant'
    : actionHint;

  const customMessage = (recipeMode === 'selected_ingredients')
    ? (message.length > 0
        ? message
        : (preferredDishName
            ? `Create a recipe for ${preferredDishName} using these selected ingredients: ${inventoryContext.map((i: any) => i.name).join(', ')}.`
            : `Create a recipe using primarily these selected ingredients: ${inventoryContext.map((i: any) => i.name).join(', ')}.`))
    : (recipeMode === 'named_dish_from_inventory')
        ? (message.length > 0
            ? message
            : `Create a recipe for ${preferredDishName}. Check what ingredients are available in my fridge inventory (${inventoryContext.map((i: any) => i.name).join(', ')}), identify which required ingredients are present and which are missing, and suggest reasonable substitutions for any missing ingredients.`)
        : message;

  const n8nPayload = {
    requestId: `req_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
    userId: userId,
    source: source,
    message: customMessage,
    actionHint: n8nActionHint,
    recipeMode: recipeMode ?? 'ai_suggestion',
    selectedInventoryItemIds: recipeMode === 'selected_ingredients' ? selectedInventoryItemIds : null,
    preferredDishName: preferredDishName,
    currentMealPeriod: currentMealPeriod,
    clientLocalTime: clientLocalTime,
    mealContext: body.mealContext ?? null,
    conversationId: conversationId,
    conversationHistory: clientHistory,
    inventoryContext: inventoryContext,
    userPreferences: userPreferences,
    todayNutrition: todayNutrition,
    recentMeals: recentMeals,
    imageBase64: imageBase64,
    mimeType: mimeType,
    locale: 'en-IN',
  };

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 75000);

  let n8nResponse: Response;
  console.log('N8N_REQUEST_STARTED');
  const n8nStart = performance.now();
  try {
    n8nResponse = await fetch(n8nWebhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...(n8nWebhookSecret ? { 'x-webhook-secret': n8nWebhookSecret } : {}),
        'x-nutrifridge-user-id': userId,
      },
      body: JSON.stringify(n8nPayload),
      signal: controller.signal,
    });
  } catch (fetchErr: any) {
    const isTimeout = fetchErr.name === 'AbortError';
    console.error(`[nutrifridge-ai] n8n fetch error (req: ${n8nPayload.requestId}, timeout: ${isTimeout}):`, fetchErr.message);
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: isTimeout
          ? 'NutriFridge AI took longer than expected to respond. Please tap retry.'
          : 'Unable to connect to the AI Assistant service. Please check your network and tap retry.',
        error: {
          code: isTimeout ? 'GEMINI_REQUEST_TIMEOUT' : 'CONNECTION_FAILED',
          message: fetchErr.message ?? (isTimeout ? 'Request timed out after 75s' : 'Failed to reach n8n webhook'),
          retryable: true,
        },
      }),
      { status: isTimeout ? 504 : 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } finally {
    clearTimeout(timeoutId);
  }
  const n8nDurationMs = Math.round(performance.now() - n8nStart);

  // 7. Validate Upstream n8n Response Status
  if (!n8nResponse.ok) {
    const status = n8nResponse.status;
    let errorDetail: any = null;
    try {
      errorDetail = await n8nResponse.json();
    } catch (_) {}

    const upstreamError = errorDetail?.error;
    const errorCode = upstreamError?.code ?? errorDetail?.code ?? (status === 504 ? 'GEMINI_REQUEST_TIMEOUT' : `N8N_UPSTREAM_${status}`);
    const isRetryable = upstreamError?.retryable ?? (status >= 500 || status === 429);

    console.error(`[nutrifridge-ai] n8n error response (req: ${n8nPayload.requestId}, status: ${status}, code: ${errorCode}):`, upstreamError?.message ?? errorDetail?.message ?? 'No error details');

    let assistantMessage = errorDetail?.assistantMessage ?? upstreamError?.message;
    if (!assistantMessage) {
      if (errorCode === 'GEMINI_REQUEST_TIMEOUT' || status === 504) {
        assistantMessage = 'NutriFridge AI took longer than expected to respond. Please tap retry.';
      } else if (errorCode === 'GEMINI_RATE_LIMIT_EXCEEDED' || status === 429) {
        assistantMessage = 'Google Gemini rate limit exceeded. Please wait a moment and tap retry.';
      } else if (errorCode === 'GEMINI_AUTH_FAILED' || status === 401 || status === 403) {
        assistantMessage = 'Google Gemini authentication failed. Please verify API key configuration in n8n.';
      } else if (errorDetail?.message && typeof errorDetail.message === 'string') {
        assistantMessage = `AI Assistant service error: ${errorDetail.message}`;
      } else if (errorCode === 'GEMINI_INVALID_REQUEST' || status === 400) {
        assistantMessage = 'Google Gemini rejected the request format. Please shorten or simplify your input.';
      } else {
        assistantMessage = status >= 500
          ? 'NutriFridge AI is temporarily experiencing high load. Please tap retry in a moment.'
          : 'AI Assistant could not process this request. Please tap retry.';
      }
    }

    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: assistantMessage,
        error: {
          code: errorCode,
          message: upstreamError?.message ?? `Upstream n8n returned HTTP status ${status}`,
          retryable: isRetryable,
        },
      }),
      { status: status === 504 ? 504 : (status >= 500 ? 502 : status), headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // 8. Parse n8n Response JSON
  let rawN8nData: any;
  try {
    rawN8nData = await n8nResponse.json();
  } catch (parseErr: any) {
    return new Response(
      JSON.stringify({
        ok: false,
        action: 'error',
        assistantMessage: 'Received an invalid response format from NutriFridge AI. Please tap retry.',
        error: { code: 'INVALID_N8N_RESPONSE', message: parseErr.message },
      }),
      { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }

  // 9. Normalize & Validate Response Fields
  const normalized = normalizeN8nResponse(rawN8nData);
  normalized.conversationId = conversationId;

  // 10. Persist Model Reply in `ai_messages`
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (serviceRoleKey && conversationId && normalized.assistantMessage && actionHint !== 'meal_recommendation') {
    try {
      const adminClient = createClient(supabaseUrl, serviceRoleKey);
      await adminClient.from('ai_messages').insert({
        conversation_id: conversationId,
        user_id: userId,
        role: 'model',
        content: normalized.assistantMessage,
        action: normalized.action,
        metadata: {
          meal: normalized.meal,
          inventoryItems: normalized.inventoryItems,
        },
      });
    } catch (saveErr) {
      console.warn('[nutrifridge-ai] Warning: could not persist model message:', saveErr);
    }
  }

  const totalDurationMs = Math.round(performance.now() - totalRequestStart);
  const geminiDurationMs = normalized.timings?.geminiDurationMs ?? null;

  console.log('PERFORMANCE_INSTRUMENTATION', {
    contextFetchDurationMs,
    n8nDurationMs,
    geminiDurationMs,
    totalDurationMs,
  });

  normalized.timings = {
    contextFetchDurationMs,
    n8nDurationMs,
    geminiDurationMs,
    totalDurationMs,
  };

  return new Response(JSON.stringify(normalized), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
