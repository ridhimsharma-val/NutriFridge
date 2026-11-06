-- =============================================================================
-- NUTRIFRIDGE — INITIAL SUPABASE RELATIONAL DATABASE MIGRATION (PHASE 2.3)
-- Migration Version: 20261106_initial_schema
-- Technology Stack: PostgreSQL 15+ (Supabase) · Flutter Mobile Client · n8n Cloud
-- Architecture: Strictly Normalized Relational Model with Row-Level Security (RLS)
-- Security Standard: Strict Table-Level Least Privilege Matching RLS Operations,
--                    Append-Only AI Messages, Verified Inventory Audit Snapshots,
--                    Zero-Quantity Deduction Rejection, and Concurrency-Safe RPCs.
-- =============================================================================

-- Enable required core extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 0. UTILITY TRIGGERS & FUNCTIONS
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = pg_catalog.now();
    RETURN NEW;
END;
$$;

-- =============================================================================
-- 1. AUTHENTICATION & USER PROFILES
-- =============================================================================

-- Table: profiles (1:1 extension of auth.users)
-- Single source of truth for calorie target is nutrition_goals.target_calories
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL DEFAULT 'Food Explorer',
    dietary_preference TEXT CHECK (
        dietary_preference IS NULL OR 
        dietary_preference IN ('Vegetarian', 'Eggetarian', 'Non-vegetarian', 'Vegan', 'Other / flexible')
    ),
    nutrition_goal TEXT CHECK (
        nutrition_goal IS NULL OR 
        nutrition_goal IN ('Balanced eating', 'Increase protein intake', 'Manage calorie intake', 'Eat more fruits and vegetables', 'Maintain current habits')
    ),
    allergies TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    avoided_foods TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    custom_restrictions TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    timezone TEXT NOT NULL DEFAULT 'UTC',
    onboarding_completed BOOLEAN NOT NULL DEFAULT false,
    meal_reminders_enabled BOOLEAN NOT NULL DEFAULT false,
    expiry_alerts_enabled BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Automatic Profile & Seed Creation Trigger on Supabase Auth Sign-Up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
DECLARE
    v_full_name TEXT;
    v_raw_cals TEXT;
    v_target_cals INTEGER := 2000;
BEGIN
    v_full_name := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.raw_user_meta_data->>'display_name',
        NEW.raw_user_meta_data->>'name',
        'Food Explorer'
    );

    -- Robust validation of target_calories metadata (handles missing, malformed, out-of-range)
    BEGIN
        v_raw_cals := NEW.raw_user_meta_data->>'target_calories';
        IF v_raw_cals IS NOT NULL AND v_raw_cals ~ '^[0-9]+$' THEN
            v_target_cals := v_raw_cals::INTEGER;
            IF v_target_cals < 500 OR v_target_cals > 10000 THEN
                v_target_cals := 2000;
            END IF;
        ELSE
            v_target_cals := 2000;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_target_cals := 2000;
    END;

    -- 1. Seed user profile
    INSERT INTO public.profiles (
        id,
        display_name,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        v_full_name,
        pg_catalog.now(),
        pg_catalog.now()
    )
    ON CONFLICT (id) DO NOTHING;

    -- 2. Seed canonical nutrition goals (Single source of truth)
    INSERT INTO public.nutrition_goals (
        user_id,
        target_calories,
        protein_target_g,
        carbs_target_g,
        fat_target_g,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        v_target_cals,
        90,
        260,
        70,
        pg_catalog.now(),
        pg_catalog.now()
    )
    ON CONFLICT (user_id) DO NOTHING;

    -- 3. Seed default fridge preferences
    INSERT INTO public.fridge_preferences (
        user_id,
        exterior_color,
        freezer_position,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        'midnightNavy',
        'top',
        pg_catalog.now(),
        pg_catalog.now()
    )
    ON CONFLICT (user_id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- 2. CANONICAL SHARED RECIPES (Precedes meals table for FK reference)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    suitable_slots TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    calories INTEGER CHECK (calories IS NULL OR calories >= 0),
    protein_g INTEGER CHECK (protein_g IS NULL OR protein_g >= 0),
    carbs_g INTEGER CHECK (carbs_g IS NULL OR carbs_g >= 0),
    fat_g INTEGER CHECK (fat_g IS NULL OR fat_g >= 0),
    fiber_g INTEGER CHECK (fiber_g IS NULL OR fiber_g >= 0),
    prep_time_minutes INTEGER CHECK (prep_time_minutes IS NULL OR prep_time_minutes >= 0),
    serving_size TEXT DEFAULT '1 serving',
    is_vegetarian BOOLEAN NOT NULL DEFAULT true,
    is_vegan BOOLEAN NOT NULL DEFAULT false,
    allergens TEXT[] NOT NULL DEFAULT '{}'::TEXT[],
    image_asset TEXT,
    storage_image_path TEXT,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS set_recipes_updated_at ON public.recipes;
CREATE TRIGGER set_recipes_updated_at
    BEFORE UPDATE ON public.recipes
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.recipe_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    required_quantity NUMERIC(10,2) CHECK (required_quantity IS NULL OR required_quantity > 0),
    required_unit TEXT,
    is_optional BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.recipe_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    step_number INTEGER NOT NULL CHECK (step_number > 0),
    instruction TEXT NOT NULL,
    time_minutes INTEGER CHECK (time_minutes IS NULL OR time_minutes >= 0),
    temperature TEXT,
    tip TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(recipe_id, step_number)
);

CREATE TABLE IF NOT EXISTS public.recipe_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    video_id TEXT NOT NULL,
    title TEXT NOT NULL,
    channel_name TEXT NOT NULL,
    duration TEXT,
    thumbnail_url TEXT,
    thumbnail_asset TEXT,
    video_url TEXT NOT NULL,
    view_count TEXT,
    published_at DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_saved_recipes (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipe_id UUID NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    saved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, recipe_id)
);

-- =============================================================================
-- 3. FRIDGE INVENTORY & PREFERENCES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.fridge_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    exterior_color TEXT NOT NULL DEFAULT 'midnightNavy' CHECK (
        exterior_color IN ('midnightNavy', 'matteBlack', 'pearlWhite', 'sageGreen')
    ),
    freezer_position TEXT NOT NULL DEFAULT 'top' CHECK (
        freezer_position IN ('top', 'bottom')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS set_fridge_preferences_updated_at ON public.fridge_preferences;
CREATE TRIGGER set_fridge_preferences_updated_at
    BEFORE UPDATE ON public.fridge_preferences
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.fridge_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (
        category IN (
            'Dairy Products',
            'Vegetables',
            'Fruits',
            'Non-Veg',
            'Meals & Leftovers',
            'Packaged Food',
            'Drinks & Juices',
            'Ice Cream',
            'Frozen Food',
            'Dry Fruits',
            'Others'
        )
    ),
    quantity NUMERIC(10,2) NOT NULL DEFAULT 1.0 CHECK (quantity >= 0),
    unit TEXT NOT NULL DEFAULT 'pieces',
    expiry_date DATE,
    image_asset TEXT,
    storage_image_path TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fridge_items_user ON public.fridge_items(user_id);
CREATE INDEX IF NOT EXISTS idx_fridge_items_category ON public.fridge_items(user_id, category);
CREATE INDEX IF NOT EXISTS idx_fridge_items_expiry ON public.fridge_items(user_id, expiry_date);

DROP TRIGGER IF EXISTS set_fridge_items_updated_at ON public.fridge_items;
CREATE TRIGGER set_fridge_items_updated_at
    BEFORE UPDATE ON public.fridge_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- 4. NUTRITION GOALS, MEALS & CONSUMPTION
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.nutrition_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    target_calories INTEGER NOT NULL DEFAULT 2000 CHECK (target_calories BETWEEN 500 AND 10000),
    protein_target_g INTEGER NOT NULL DEFAULT 90 CHECK (protein_target_g >= 0),
    carbs_target_g INTEGER NOT NULL DEFAULT 260 CHECK (carbs_target_g >= 0),
    fat_target_g INTEGER NOT NULL DEFAULT 70 CHECK (fat_target_g >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS set_nutrition_goals_updated_at ON public.nutrition_goals;
CREATE TRIGGER set_nutrition_goals_updated_at
    BEFORE UPDATE ON public.nutrition_goals
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Table: meals
-- Direct client inserts/updates/deletes are strictly denied.
-- Only log_meal_transaction creates records to ensure transactional integrity.
CREATE TABLE IF NOT EXISTS public.meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    meal_type TEXT NOT NULL CHECK (
        meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')
    ),
    logged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    local_date DATE NOT NULL,
    serving_size TEXT DEFAULT '1 serving',
    calories INTEGER CHECK (calories IS NULL OR calories >= 0),
    protein_g INTEGER CHECK (protein_g IS NULL OR protein_g >= 0),
    carbs_g INTEGER CHECK (carbs_g IS NULL OR carbs_g >= 0),
    fat_g INTEGER CHECK (fat_g IS NULL OR fat_g >= 0),
    fiber_g INTEGER CHECK (fiber_g IS NULL OR fiber_g >= 0),
    is_estimate BOOLEAN NOT NULL DEFAULT true,
    nutrition_source TEXT NOT NULL DEFAULT 'ai_estimate' CHECK (
        nutrition_source IN ('ai_estimate', 'verified_catalog', 'user_custom', 'nutrition_label')
    ),
    recipe_id UUID REFERENCES public.recipes(id) ON DELETE SET NULL,
    image_url TEXT,
    idempotency_key TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_meals_user_idempotency UNIQUE(user_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_meals_user_date ON public.meals(user_id, local_date DESC);
CREATE INDEX IF NOT EXISTS idx_meals_user_logged ON public.meals(user_id, logged_at DESC);

-- Table: meal_ingredients
-- Design: fridge_item_id_snapshot preserves the verified historical audit link even if inventory is deleted.
-- matched_fridge_item_id holds the live foreign key, set to NULL if the inventory record was fully depleted.
CREATE TABLE IF NOT EXISTS public.meal_ingredients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id UUID NOT NULL REFERENCES public.meals(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    required_quantity NUMERIC(10,2) CHECK (required_quantity IS NULL OR required_quantity >= 0),
    required_unit TEXT,
    matched_fridge_item_id UUID REFERENCES public.fridge_items(id) ON DELETE SET NULL,
    fridge_item_id_snapshot UUID,
    deducted_quantity NUMERIC(10,2) DEFAULT 0 CHECK (deducted_quantity >= 0),
    deducted_unit TEXT,
    was_deducted BOOLEAN NOT NULL DEFAULT false,
    deduction_status TEXT NOT NULL DEFAULT 'none' CHECK (
        deduction_status IN ('full', 'partial', 'depleted_and_deleted', 'incompatible_unit', 'no_stock', 'not_found', 'none')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_meal_ingredients_meal ON public.meal_ingredients(meal_id);
CREATE INDEX IF NOT EXISTS idx_meal_ingredients_snapshot ON public.meal_ingredients(fridge_item_id_snapshot);

-- Table: daily_nutrition_snapshots
-- Design: Nullable nutrition fields distinguish known sums from uncalculated values.
-- meals_with_unknown_nutrition and is_complete track whether displayed aggregates are complete or partial.
CREATE TABLE IF NOT EXISTS public.daily_nutrition_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    log_date DATE NOT NULL,
    total_calories INTEGER CHECK (total_calories IS NULL OR total_calories >= 0),
    target_calories INTEGER NOT NULL DEFAULT 2000 CHECK (target_calories >= 0),
    protein_g INTEGER CHECK (protein_g IS NULL OR protein_g >= 0),
    carbs_g INTEGER CHECK (carbs_g IS NULL OR carbs_g >= 0),
    fat_g INTEGER CHECK (fat_g IS NULL OR fat_g >= 0),
    fiber_g INTEGER CHECK (fiber_g IS NULL OR fiber_g >= 0),
    meals_logged_count INTEGER NOT NULL DEFAULT 0 CHECK (meals_logged_count >= 0),
    meals_with_unknown_nutrition INTEGER NOT NULL DEFAULT 0 CHECK (meals_with_unknown_nutrition >= 0),
    is_complete BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_log_date UNIQUE (user_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_nutrition_user_date ON public.daily_nutrition_snapshots(user_id, log_date DESC);

-- =============================================================================
-- 5. DAILY MEAL SLOT PROGRESSION TRACKING
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.daily_meal_slots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    log_date DATE NOT NULL,
    meal_slot TEXT NOT NULL CHECK (
        meal_slot IN ('breakfast', 'lunch', 'snack', 'dinner')
    ),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (
        status IN ('pending', 'completed', 'skipped')
    ),
    completed_at TIMESTAMPTZ,
    primary_meal_id UUID REFERENCES public.meals(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_daily_meal_slot UNIQUE (user_id, log_date, meal_slot)
);

CREATE INDEX IF NOT EXISTS idx_daily_meal_slots_user_date ON public.daily_meal_slots(user_id, log_date, status);

DROP TRIGGER IF EXISTS set_daily_meal_slots_updated_at ON public.daily_meal_slots;
CREATE TRIGGER set_daily_meal_slots_updated_at
    BEFORE UPDATE ON public.daily_meal_slots
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- 6. AI RECOMMENDATIONS & EXCLUSION LOGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.recipe_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipe_id UUID REFERENCES public.recipes(id) ON DELETE SET NULL,
    generated_recipe_data JSONB,
    target_meal_slot TEXT NOT NULL CHECK (
        target_meal_slot IN ('breakfast', 'lunch', 'snack', 'dinner')
    ),
    inventory_fingerprint TEXT,
    recommendation_reasons TEXT[] DEFAULT '{}'::TEXT[],
    status TEXT NOT NULL DEFAULT 'active' CHECK (
        status IN ('active', 'consumed', 'rejected', 'expired')
    ),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_recipe_recommendations_user ON public.recipe_recommendations(user_id, status, expires_at);

CREATE TABLE IF NOT EXISTS public.user_rejected_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipe_id UUID REFERENCES public.recipes(id) ON DELETE CASCADE,
    recipe_identifier TEXT NOT NULL,
    rejected_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_rejected_recipes ON public.user_rejected_recipes(user_id, rejected_at DESC);

-- =============================================================================
-- 7. WELLNESS LOGS & IN-APP NOTIFICATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.wellness_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    log_date DATE NOT NULL,
    score INTEGER NOT NULL CHECK (score >= 0 AND score <= 100),
    score_diff INTEGER NOT NULL DEFAULT 0,
    status_text TEXT NOT NULL,
    contributing_factors JSONB NOT NULL DEFAULT '{}'::JSONB,
    is_medical_disclaimer_acknowledged BOOLEAN NOT NULL DEFAULT false,
    notes TEXT DEFAULT 'NutriFridge wellness indicator · Not a medical assessment',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_wellness_user_date UNIQUE (user_id, log_date)
);

CREATE INDEX IF NOT EXISTS idx_wellness_user_date ON public.wellness_logs(user_id, log_date DESC);

CREATE TABLE IF NOT EXISTS public.app_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL CHECK (
        type IN ('foodExpiring', 'mealLogged', 'inventoryUpdate', 'nutritionSummary')
    ),
    is_read BOOLEAN NOT NULL DEFAULT false,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.app_notifications(user_id, is_read, created_at DESC);

-- =============================================================================
-- 8. AI CONVERSATIONS & PERSISTENT MEMORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'New Conversation',
    last_message_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_ai_conversations_id_user UNIQUE (id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_ai_conversations_user ON public.ai_conversations(user_id, last_message_at DESC);

-- Composite foreign key guarantees that a message belongs strictly to a conversation owned by the same user.
CREATE TABLE IF NOT EXISTS public.ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL,
    user_id UUID NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'model', 'system')),
    content TEXT NOT NULL,
    action TEXT,
    metadata JSONB DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_ai_messages_conv_user FOREIGN KEY (conversation_id, user_id)
        REFERENCES public.ai_conversations(id, user_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_conv ON public.ai_messages(conversation_id, created_at ASC, id ASC);
CREATE INDEX IF NOT EXISTS idx_ai_messages_user_recent ON public.ai_messages(user_id, created_at DESC, id DESC);

-- Trigger: Automatically update ai_conversations.last_message_at without moving backwards
CREATE OR REPLACE FUNCTION public.handle_ai_message_created()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.ai_conversations
    SET last_message_at = GREATEST(COALESCE(ai_conversations.last_message_at, NEW.created_at), NEW.created_at)
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ai_message_created ON public.ai_messages;
CREATE TRIGGER trg_ai_message_created
    AFTER INSERT ON public.ai_messages
    FOR EACH ROW EXECUTE FUNCTION public.handle_ai_message_created();

-- =============================================================================
-- 9. UNIT COMPATIBILITY & CANONICAL NORMALIZATION HELPER
-- =============================================================================

CREATE OR REPLACE FUNCTION public.calculate_unit_deduction(
    p_inventory_unit TEXT,
    p_deduct_qty NUMERIC,
    p_deduct_unit TEXT,
    OUT is_compatible BOOLEAN,
    OUT normalized_deduction NUMERIC
)
RETURNS RECORD
IMMUTABLE
LANGUAGE plpgsql
AS $$
DECLARE
    v_inv_u TEXT;
    v_ded_u TEXT;
    v_inv_family TEXT;
    v_ded_family TEXT;
    v_ded_in_base NUMERIC;
BEGIN
    -- Explicitly reject non-positive deduction quantities
    IF p_deduct_qty <= 0 THEN
        is_compatible := false;
        normalized_deduction := 0;
        RETURN;
    END IF;

    v_inv_u := pg_catalog.lower(pg_catalog.btrim(p_inventory_unit));
    v_ded_u := pg_catalog.lower(pg_catalog.btrim(p_deduct_unit));

    -- Classify Inventory Unit Family (Separating piece, item, serving, unit)
    IF v_inv_u IN ('g', 'gram', 'grams', 'kg', 'kilogram', 'kilograms') THEN
        v_inv_family := 'mass';
    ELSIF v_inv_u IN ('ml', 'milliliter', 'milliliters', 'l', 'liter', 'liters', 'litre', 'litres') THEN
        v_inv_family := 'volume';
    ELSIF v_inv_u IN ('piece', 'pieces', 'pc', 'pcs') THEN
        v_inv_family := 'piece';
    ELSIF v_inv_u IN ('item', 'items') THEN
        v_inv_family := 'item';
    ELSIF v_inv_u IN ('serving', 'servings') THEN
        v_inv_family := 'serving';
    ELSIF v_inv_u IN ('unit', 'units') THEN
        v_inv_family := 'unit';
    ELSE
        -- Custom / unrecognized unit: compatible only if exact string match
        IF v_inv_u = v_ded_u THEN
            is_compatible := true;
            normalized_deduction := p_deduct_qty;
            RETURN;
        ELSE
            is_compatible := false;
            normalized_deduction := 0;
            RETURN;
        END IF;
    END IF;

    -- Classify Deduction Unit Family
    IF v_ded_u IN ('g', 'gram', 'grams', 'kg', 'kilogram', 'kilograms') THEN
        v_ded_family := 'mass';
    ELSIF v_ded_u IN ('ml', 'milliliter', 'milliliters', 'l', 'liter', 'liters', 'litre', 'litres') THEN
        v_ded_family := 'volume';
    ELSIF v_ded_u IN ('piece', 'pieces', 'pc', 'pcs') THEN
        v_ded_family := 'piece';
    ELSIF v_ded_u IN ('item', 'items') THEN
        v_ded_family := 'item';
    ELSIF v_ded_u IN ('serving', 'servings') THEN
        v_ded_family := 'serving';
    ELSIF v_ded_u IN ('unit', 'units') THEN
        v_ded_family := 'unit';
    ELSE
        v_ded_family := 'unknown';
    END IF;

    -- Strict Family Compatibility Verification
    IF v_inv_family <> v_ded_family THEN
        is_compatible := false;
        normalized_deduction := 0;
        RETURN;
    END IF;

    is_compatible := true;

    -- Mass family conversion (base unit: grams)
    IF v_inv_family = 'mass' THEN
        IF v_ded_u IN ('kg', 'kilogram', 'kilograms') THEN
            v_ded_in_base := p_deduct_qty * 1000.0;
        ELSE
            v_ded_in_base := p_deduct_qty;
        END IF;

        IF v_inv_u IN ('kg', 'kilogram', 'kilograms') THEN
            normalized_deduction := v_ded_in_base / 1000.0;
        ELSE
            normalized_deduction := v_ded_in_base;
        END IF;
        RETURN;
    END IF;

    -- Volume family conversion (base unit: milliliters)
    IF v_inv_family = 'volume' THEN
        IF v_ded_u IN ('l', 'liter', 'liters', 'litre', 'litres') THEN
            v_ded_in_base := p_deduct_qty * 1000.0;
        ELSE
            v_ded_in_base := p_deduct_qty;
        END IF;

        IF v_inv_u IN ('l', 'liter', 'liters', 'litre', 'litres') THEN
            normalized_deduction := v_ded_in_base / 1000.0;
        ELSE
            normalized_deduction := v_ded_in_base;
        END IF;
        RETURN;
    END IF;

    -- Discrete count families: piece, item, serving, unit (1:1 within genuine aliases)
    IF v_inv_family IN ('piece', 'item', 'serving', 'unit') THEN
        normalized_deduction := p_deduct_qty;
        RETURN;
    END IF;

    is_compatible := false;
    normalized_deduction := 0;
END;
$$;

-- =============================================================================
-- 10. TRANSACTIONAL RPC: LOG MEAL & DEDUCT INVENTORY ATOMICALLY
-- =============================================================================

CREATE OR REPLACE FUNCTION public.log_meal_transaction(
    p_idempotency_key TEXT,
    p_meal_name TEXT,
    p_meal_type TEXT,
    p_serving_size TEXT DEFAULT '1 serving',
    p_calories INTEGER DEFAULT NULL,
    p_protein_g INTEGER DEFAULT NULL,
    p_carbs_g INTEGER DEFAULT NULL,
    p_fat_g INTEGER DEFAULT NULL,
    p_fiber_g INTEGER DEFAULT NULL,
    p_is_estimate BOOLEAN DEFAULT true,
    p_nutrition_source TEXT DEFAULT 'ai_estimate',
    p_recipe_id UUID DEFAULT NULL,
    p_image_url TEXT DEFAULT NULL,
    p_ingredients JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id UUID;
    v_timezone TEXT;
    v_local_date DATE;
    v_target_calories INTEGER;
    v_meal_id UUID;
    v_existing_meal_id UUID;
    v_existing_slot TEXT;
    v_existing_date DATE;
    v_clean_slot TEXT;
    v_has_unknown BOOLEAN;
    v_ing RECORD;
    v_fridge_item RECORD;
    v_unit_calc RECORD;
    v_requested_deduct_qty NUMERIC(10,2);
    v_requested_deduct_unit TEXT;
    v_actual_deduct_qty NUMERIC(10,2);
    v_actual_deduct_unit TEXT;
    v_existing_amount NUMERIC(10,2);
    v_new_quantity NUMERIC(10,2);
    v_matched_fk_id UUID;
    v_snapshot_id UUID;
    v_was_deducted BOOLEAN;
    v_deduction_status TEXT;
    v_deducted_count INTEGER := 0;
    v_deduction_details JSONB := '[]'::JSONB;
BEGIN
    -- 1. Validate Authenticated Caller
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: Caller must be an authenticated user.';
    END IF;

    -- 2. Validate Idempotency Key (Mandatory for transactional safety)
    IF p_idempotency_key IS NULL OR pg_catalog.btrim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'idempotency_key is required for meal logging';
    END IF;

    -- 3. Strict Meal Slot Validation (Null check and no silent fallbacks)
    IF p_meal_type IS NULL OR pg_catalog.btrim(p_meal_type) = '' THEN
        RAISE EXCEPTION 'meal_type is required and cannot be empty.';
    END IF;

    v_clean_slot := pg_catalog.lower(pg_catalog.btrim(p_meal_type));
    IF v_clean_slot NOT IN ('breakfast', 'lunch', 'dinner', 'snack') THEN
        RAISE EXCEPTION 'Invalid meal_type: %. Allowed values are: breakfast, lunch, snack, dinner.', p_meal_type;
    END IF;

    -- 4. Resolve User Timezone & Derive Local Date
    SELECT COALESCE(timezone, 'UTC') INTO v_timezone
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_timezone IS NULL THEN
        v_timezone := 'UTC';
    END IF;

    BEGIN
        v_local_date := (pg_catalog.now() AT TIME ZONE v_timezone)::DATE;
    EXCEPTION WHEN OTHERS THEN
        v_local_date := (pg_catalog.now() AT TIME ZONE 'UTC')::DATE;
    END;

    -- 5. Concurrency-Safe Idempotent Insert using UNIQUE(user_id, idempotency_key)
    -- If a concurrent or previous request already committed this key, DO NOTHING triggers.
    INSERT INTO public.meals (
        user_id,
        name,
        meal_type,
        logged_at,
        local_date,
        serving_size,
        calories,
        protein_g,
        carbs_g,
        fat_g,
        fiber_g,
        is_estimate,
        nutrition_source,
        recipe_id,
        image_url,
        idempotency_key,
        created_at
    )
    VALUES (
        v_user_id,
        p_meal_name,
        v_clean_slot,
        pg_catalog.now(),
        v_local_date,
        COALESCE(p_serving_size, '1 serving'),
        p_calories,
        p_protein_g,
        p_carbs_g,
        p_fat_g,
        p_fiber_g,
        COALESCE(p_is_estimate, true),
        COALESCE(p_nutrition_source, 'ai_estimate'),
        p_recipe_id,
        p_image_url,
        p_idempotency_key,
        pg_catalog.now()
    )
    ON CONFLICT (user_id, idempotency_key) DO NOTHING
    RETURNING id INTO v_meal_id;

    -- If no row was inserted, a duplicate concurrent/prior request was detected.
    IF v_meal_id IS NULL THEN
        SELECT m.id, m.meal_type, m.local_date INTO v_existing_meal_id, v_existing_slot, v_existing_date
        FROM public.meals m
        WHERE m.user_id = v_user_id AND m.idempotency_key = p_idempotency_key;

        RETURN pg_catalog.jsonb_build_object(
            'status', 'idempotent_duplicate',
            'already_processed', true,
            'message', 'Meal was already successfully logged with this idempotency key.',
            'meal_id', v_existing_meal_id,
            'local_date', v_existing_date,
            'meal_type', v_existing_slot
        );
    END IF;

    -- 6. Process Ingredients & Execute Inventory Deductions (Only executed once per key)
    IF p_ingredients IS NOT NULL AND pg_catalog.jsonb_array_length(p_ingredients) > 0 THEN
        FOR v_ing IN SELECT * FROM pg_catalog.jsonb_to_recordset(p_ingredients) AS x(
            name TEXT,
            required_quantity NUMERIC,
            required_unit TEXT,
            matched_fridge_item_id UUID,
            deduct_quantity NUMERIC,
            deduct_unit TEXT,
            do_deduct BOOLEAN
        )
        LOOP
            v_requested_deduct_qty := COALESCE(v_ing.deduct_quantity, v_ing.required_quantity, 0);
            v_requested_deduct_unit := COALESCE(v_ing.deduct_unit, v_ing.required_unit, 'pieces');
            v_matched_fk_id := NULL;
            v_snapshot_id := NULL; -- Initialized strictly to NULL; never trust unverified client UUID
            v_actual_deduct_qty := 0;
            v_actual_deduct_unit := v_requested_deduct_unit;
            v_was_deducted := false;
            v_deduction_status := 'none';

            IF COALESCE(v_ing.do_deduct, false) = true THEN
                -- Explicitly reject non-positive deduction quantities when deduction is requested
                IF v_requested_deduct_qty <= 0 THEN
                    RAISE EXCEPTION 'Requested deduction quantity for ingredient "%" must be strictly positive when do_deduct is true (received: %)', v_ing.name, v_requested_deduct_qty;
                END IF;

                IF v_ing.matched_fridge_item_id IS NOT NULL THEN
                    -- Select with row-lock and strictly verify ownership
                    SELECT id, quantity, unit INTO v_fridge_item
                    FROM public.fridge_items
                    WHERE id = v_ing.matched_fridge_item_id AND user_id = v_user_id
                    FOR UPDATE;

                    IF FOUND THEN
                        -- Ownership verified: assign verified ID to audit snapshot
                        v_snapshot_id := v_fridge_item.id;
                        v_existing_amount := v_fridge_item.quantity;
                        v_actual_deduct_unit := v_fridge_item.unit;

                        -- Safe handling for zero available stock
                        IF v_existing_amount <= 0.0001 THEN
                            v_was_deducted := false;
                            v_deduction_status := 'no_stock';
                            v_matched_fk_id := v_fridge_item.id;
                            v_actual_deduct_qty := 0;
                        ELSE
                            -- Validate unit compatibility & calculate normalized deduction
                            SELECT * INTO v_unit_calc FROM public.calculate_unit_deduction(
                                v_fridge_item.unit,
                                v_requested_deduct_qty,
                                v_requested_deduct_unit
                            );

                            IF NOT v_unit_calc.is_compatible THEN
                                -- Incompatible units: prevent corruption, record status
                                v_was_deducted := false;
                                v_deduction_status := 'incompatible_unit';
                                v_matched_fk_id := v_fridge_item.id;
                                v_actual_deduct_qty := 0;
                            ELSE
                                v_actual_deduct_qty := v_unit_calc.normalized_deduction;

                                -- Clamp deduction so it never exceeds available stock
                                IF v_actual_deduct_qty > v_existing_amount THEN
                                    v_actual_deduct_qty := v_existing_amount;
                                    v_deduction_status := 'partial';
                                ELSE
                                    v_deduction_status := 'full';
                                END IF;

                                v_new_quantity := v_existing_amount - v_actual_deduct_qty;

                                IF v_new_quantity <= 0.0001 THEN
                                    -- Complete consumption: Remove zero-quantity inventory record
                                    DELETE FROM public.fridge_items
                                    WHERE id = v_fridge_item.id;

                                    -- Set matched FK to NULL to satisfy foreign key constraint on deleted row
                                    -- Verified audit reference is preserved in fridge_item_id_snapshot
                                    v_matched_fk_id := NULL;
                                    v_deduction_status := 'depleted_and_deleted';
                                ELSE
                                    -- Partial consumption: Update remaining quantity
                                    UPDATE public.fridge_items
                                    SET quantity = v_new_quantity,
                                        updated_at = pg_catalog.now()
                                    WHERE id = v_fridge_item.id;

                                    v_matched_fk_id := v_fridge_item.id;
                                END IF;

                                v_was_deducted := (v_actual_deduct_qty > 0);
                                IF v_was_deducted THEN
                                    v_deducted_count := v_deducted_count + 1;
                                END IF;
                            END IF;
                        END IF;
                    ELSE
                        -- Not found or belongs to another user: keep snapshot NULL to avoid leaking unverified IDs
                        v_deduction_status := 'not_found';
                        v_snapshot_id := NULL;
                        v_matched_fk_id := NULL;
                        v_actual_deduct_qty := 0;
                        v_was_deducted := false;
                    END IF;
                ELSE
                    -- do_deduct is true but no fridge item specified
                    v_deduction_status := 'not_found';
                    v_snapshot_id := NULL;
                    v_matched_fk_id := NULL;
                    v_actual_deduct_qty := 0;
                    v_was_deducted := false;
                END IF;
            ELSE
                -- do_deduct is false: requirement is recorded without inventory modification
                v_deduction_status := 'none';
                v_snapshot_id := NULL;
                v_matched_fk_id := NULL;
                v_actual_deduct_qty := 0;
                v_was_deducted := false;
            END IF;

            -- Insert audit record into meal_ingredients
            INSERT INTO public.meal_ingredients (
                meal_id,
                name,
                required_quantity,
                required_unit,
                matched_fridge_item_id,
                fridge_item_id_snapshot,
                deducted_quantity,
                deducted_unit,
                was_deducted,
                deduction_status,
                created_at
            )
            VALUES (
                v_meal_id,
                v_ing.name,
                v_ing.required_quantity,
                v_ing.required_unit,
                v_matched_fk_id,
                v_snapshot_id,
                v_actual_deduct_qty,
                v_actual_deduct_unit,
                v_was_deducted,
                v_deduction_status,
                pg_catalog.now()
            );

            v_deduction_details := v_deduction_details || pg_catalog.jsonb_build_object(
                'ingredient', v_ing.name,
                'requested_qty', v_requested_deduct_qty,
                'requested_unit', v_requested_deduct_unit,
                'deducted_qty', v_actual_deduct_qty,
                'deducted_unit', v_actual_deduct_unit,
                'status', v_deduction_status,
                'was_deducted', v_was_deducted
            );
        END LOOP;
    END IF;

    -- 7. Update Daily Nutrition Snapshot
    SELECT COALESCE(target_calories, 2000) INTO v_target_calories
    FROM public.nutrition_goals
    WHERE user_id = v_user_id;

    IF v_target_calories IS NULL THEN
        v_target_calories := 2000;
    END IF;

    -- Include calories, protein, carbs, fat AND fiber in unknown check
    v_has_unknown := (
        p_calories IS NULL OR 
        p_protein_g IS NULL OR 
        p_carbs_g IS NULL OR 
        p_fat_g IS NULL OR 
        p_fiber_g IS NULL
    );

    INSERT INTO public.daily_nutrition_snapshots (
        user_id,
        log_date,
        total_calories,
        target_calories,
        protein_g,
        carbs_g,
        fat_g,
        fiber_g,
        meals_logged_count,
        meals_with_unknown_nutrition,
        is_complete,
        updated_at
    )
    VALUES (
        v_user_id,
        v_local_date,
        p_calories,
        v_target_calories,
        p_protein_g,
        p_carbs_g,
        p_fat_g,
        p_fiber_g,
        1,
        CASE WHEN v_has_unknown THEN 1 ELSE 0 END,
        NOT v_has_unknown,
        pg_catalog.now()
    )
    ON CONFLICT (user_id, log_date)
    DO UPDATE SET
        total_calories = CASE 
            WHEN EXCLUDED.total_calories IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.total_calories, 0) + EXCLUDED.total_calories
            ELSE daily_nutrition_snapshots.total_calories
        END,
        protein_g = CASE 
            WHEN EXCLUDED.protein_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.protein_g, 0) + EXCLUDED.protein_g
            ELSE daily_nutrition_snapshots.protein_g
        END,
        carbs_g = CASE 
            WHEN EXCLUDED.carbs_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.carbs_g, 0) + EXCLUDED.carbs_g
            ELSE daily_nutrition_snapshots.carbs_g
        END,
        fat_g = CASE 
            WHEN EXCLUDED.fat_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.fat_g, 0) + EXCLUDED.fat_g
            ELSE daily_nutrition_snapshots.fat_g
        END,
        fiber_g = CASE 
            WHEN EXCLUDED.fiber_g IS NOT NULL THEN
                COALESCE(daily_nutrition_snapshots.fiber_g, 0) + EXCLUDED.fiber_g
            ELSE daily_nutrition_snapshots.fiber_g
        END,
        meals_logged_count = daily_nutrition_snapshots.meals_logged_count + 1,
        meals_with_unknown_nutrition = daily_nutrition_snapshots.meals_with_unknown_nutrition + (CASE WHEN v_has_unknown THEN 1 ELSE 0 END),
        is_complete = (daily_nutrition_snapshots.is_complete AND NOT v_has_unknown),
        updated_at = pg_catalog.now();

    -- 8. Update Daily Meal Slot Progression
    INSERT INTO public.daily_meal_slots (
        user_id,
        log_date,
        meal_slot,
        status,
        completed_at,
        primary_meal_id,
        created_at,
        updated_at
    )
    VALUES (
        v_user_id,
        v_local_date,
        v_clean_slot,
        'completed',
        pg_catalog.now(),
        v_meal_id,
        pg_catalog.now(),
        pg_catalog.now()
    )
    ON CONFLICT (user_id, log_date, meal_slot)
    DO UPDATE SET
        status = 'completed',
        completed_at = pg_catalog.now(),
        primary_meal_id = COALESCE(daily_meal_slots.primary_meal_id, v_meal_id),
        updated_at = pg_catalog.now();

    -- 9. Post Synchronized In-App Notification
    INSERT INTO public.app_notifications (
        user_id,
        title,
        description,
        type,
        metadata,
        created_at
    )
    VALUES (
        v_user_id,
        'Meal logged',
        'Your ' || v_clean_slot || ' (' || p_meal_name || ') has been added to today''s nutrition.',
        'mealLogged',
        pg_catalog.jsonb_build_object('meal_id', v_meal_id, 'meal_type', v_clean_slot),
        pg_catalog.now()
    );

    RETURN pg_catalog.jsonb_build_object(
        'status', 'success',
        'already_processed', false,
        'meal_id', v_meal_id,
        'local_date', v_local_date,
        'meal_type', v_clean_slot,
        'deductions_applied', v_deducted_count,
        'deduction_details', v_deduction_details
    );
END;
$$;

-- Function: Retrieve latest messages of a conversation securely in chronological order
CREATE OR REPLACE FUNCTION public.get_latest_ai_messages(
    p_conversation_id UUID,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    id UUID,
    conversation_id UUID,
    user_id UUID,
    role TEXT,
    content TEXT,
    action TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ
)
SECURITY DEFINER
SET search_path = ''
LANGUAGE plpgsql
AS $$
DECLARE
    v_caller_id UUID;
    v_safe_limit INTEGER;
BEGIN
    -- Validate authenticated caller
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Unauthorized: authentication required';
    END IF;

    -- Verify that the conversation belongs to the caller
    IF NOT EXISTS (
        SELECT 1 FROM public.ai_conversations c
        WHERE c.id = p_conversation_id AND c.user_id = v_caller_id
    ) THEN
        RAISE EXCEPTION 'Conversation not found or access denied';
    END IF;

    -- Safely clamp limit between 1 and 50 using standard LEAST and GREATEST
    v_safe_limit := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 50);

    -- Deterministic subquery: select the newest N messages (tie-broken by id DESC),
    -- then order the returned records chronologically (oldest first, tie-broken by id ASC)
    RETURN QUERY
    SELECT sub.id, sub.conversation_id, sub.user_id, sub.role, sub.content, sub.action, sub.metadata, sub.created_at
    FROM (
        SELECT m.id, m.conversation_id, m.user_id, m.role, m.content, m.action, m.metadata, m.created_at
        FROM public.ai_messages m
        WHERE m.conversation_id = p_conversation_id
          AND m.user_id = v_caller_id
        ORDER BY m.created_at DESC, m.id DESC
        LIMIT v_safe_limit
    ) sub
    ORDER BY sub.created_at ASC, sub.id ASC;
END;
$$;

-- =============================================================================
-- 11. SECURITY DEFINER PRIVILEGE HARDENING
-- =============================================================================

-- Revoke all function permissions from public/anon
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM anon;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated;

REVOKE ALL ON FUNCTION public.handle_ai_message_created() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.handle_ai_message_created() FROM anon;
REVOKE ALL ON FUNCTION public.handle_ai_message_created() FROM authenticated;

REVOKE ALL ON FUNCTION public.calculate_unit_deduction(TEXT, NUMERIC, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.calculate_unit_deduction(TEXT, NUMERIC, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.calculate_unit_deduction(TEXT, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_unit_deduction(TEXT, NUMERIC, TEXT) TO service_role;

-- log_meal_transaction requires auth.uid().
-- Granted strictly to authenticated callers.
-- Not granted to anon or service_role (service_role without auth context yields NULL auth.uid()).
REVOKE ALL ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) FROM anon;
REVOKE ALL ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) FROM service_role;
GRANT EXECUTE ON FUNCTION public.log_meal_transaction(TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, TEXT, UUID, TEXT, JSONB) TO authenticated;

-- get_latest_ai_messages requires auth.uid().
-- Granted strictly to authenticated callers.
REVOKE ALL ON FUNCTION public.get_latest_ai_messages(UUID, INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_latest_ai_messages(UUID, INTEGER) FROM anon;
REVOKE ALL ON FUNCTION public.get_latest_ai_messages(UUID, INTEGER) FROM service_role;
GRANT EXECUTE ON FUNCTION public.get_latest_ai_messages(UUID, INTEGER) TO authenticated;

-- =============================================================================
-- 12. EXPLICIT TABLE PRIVILEGES (EXACT LEAST-PRIVILEGE ALIGNMENT WITH RLS)
-- =============================================================================

-- Revoke indiscriminate default permissions
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;

-- 12.1 Canonical shared catalog: Read-only for authenticated clients
GRANT SELECT ON 
    public.recipes, 
    public.recipe_ingredients, 
    public.recipe_steps, 
    public.recipe_videos 
TO authenticated;

-- 12.2 Transactional meal & nutrition records:
-- MUST be modified exclusively through the trusted log_meal_transaction RPC.
-- Direct INSERT, UPDATE, DELETE are forbidden to prevent state desynchronization.
GRANT SELECT ON
    public.meals,
    public.meal_ingredients,
    public.daily_nutrition_snapshots,
    public.daily_meal_slots
TO authenticated;

-- 12.3 User Data Tables matching RLS policies exactly:
-- profiles: SELECT, UPDATE (Creation handled by auth trigger)
GRANT SELECT, UPDATE ON public.profiles TO authenticated;

-- fridge_preferences: SELECT, INSERT, UPDATE
GRANT SELECT, INSERT, UPDATE ON public.fridge_preferences TO authenticated;

-- fridge_items: SELECT, INSERT, UPDATE, DELETE
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fridge_items TO authenticated;

-- nutrition_goals: SELECT, INSERT, UPDATE
GRANT SELECT, INSERT, UPDATE ON public.nutrition_goals TO authenticated;

-- recipe_recommendations: SELECT, INSERT, UPDATE, DELETE
GRANT SELECT, INSERT, UPDATE, DELETE ON public.recipe_recommendations TO authenticated;

-- user_rejected_recipes: SELECT, INSERT
GRANT SELECT, INSERT ON public.user_rejected_recipes TO authenticated;

-- user_saved_recipes: SELECT, INSERT, DELETE
GRANT SELECT, INSERT, DELETE ON public.user_saved_recipes TO authenticated;

-- wellness_logs: SELECT, INSERT, UPDATE
GRANT SELECT, INSERT, UPDATE ON public.wellness_logs TO authenticated;

-- app_notifications: SELECT, UPDATE, DELETE
GRANT SELECT, UPDATE, DELETE ON public.app_notifications TO authenticated;

-- ai_conversations: SELECT, INSERT, DELETE
GRANT SELECT, INSERT, DELETE ON public.ai_conversations TO authenticated;

-- ai_messages: Append-only for authenticated clients (SELECT, INSERT; NO UPDATE, NO DELETE)
GRANT SELECT, INSERT ON public.ai_messages TO authenticated;

-- 12.4 Service role retains full administrative privileges for server-side automations and migrations
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- =============================================================================
-- 13. ROW-LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

-- Enable RLS on all 19 public tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fridge_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fridge_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_nutrition_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_meal_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_steps ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_saved_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_rejected_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wellness_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.app_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;

-- 13.1 PROFILES (SELECT, UPDATE)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 13.2 FRIDGE PREFERENCES (SELECT, INSERT, UPDATE)
DROP POLICY IF EXISTS "Users can view own fridge preferences" ON public.fridge_preferences;
CREATE POLICY "Users can view own fridge preferences"
    ON public.fridge_preferences FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own fridge preferences" ON public.fridge_preferences;
CREATE POLICY "Users can insert own fridge preferences"
    ON public.fridge_preferences FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own fridge preferences" ON public.fridge_preferences;
CREATE POLICY "Users can update own fridge preferences"
    ON public.fridge_preferences FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 13.3 FRIDGE ITEMS (SELECT, INSERT, UPDATE, DELETE)
DROP POLICY IF EXISTS "Users can view own fridge items" ON public.fridge_items;
CREATE POLICY "Users can view own fridge items"
    ON public.fridge_items FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own fridge items" ON public.fridge_items;
CREATE POLICY "Users can insert own fridge items"
    ON public.fridge_items FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own fridge items" ON public.fridge_items;
CREATE POLICY "Users can update own fridge items"
    ON public.fridge_items FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own fridge items" ON public.fridge_items;
CREATE POLICY "Users can delete own fridge items"
    ON public.fridge_items FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 13.4 NUTRITION GOALS (SELECT, INSERT, UPDATE)
DROP POLICY IF EXISTS "Users can view own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can view own nutrition goals"
    ON public.nutrition_goals FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can insert own nutrition goals"
    ON public.nutrition_goals FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own nutrition goals" ON public.nutrition_goals;
CREATE POLICY "Users can update own nutrition goals"
    ON public.nutrition_goals FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 13.5 MEALS (SELECT ONLY for authenticated clients — modifications handled via log_meal_transaction)
DROP POLICY IF EXISTS "Users can view own meals" ON public.meals;
CREATE POLICY "Users can view own meals"
    ON public.meals FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own meals" ON public.meals;
DROP POLICY IF EXISTS "Users can update own meals" ON public.meals;
DROP POLICY IF EXISTS "Users can delete own meals" ON public.meals;

-- 13.6 MEAL INGREDIENTS (SELECT ONLY for authenticated clients)
DROP POLICY IF EXISTS "Users can view own meal ingredients" ON public.meal_ingredients;
CREATE POLICY "Users can view own meal ingredients"
    ON public.meal_ingredients FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.meals m 
            WHERE m.id = meal_ingredients.meal_id 
              AND m.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can insert own meal ingredients" ON public.meal_ingredients;
DROP POLICY IF EXISTS "Users can delete own meal ingredients" ON public.meal_ingredients;

-- 13.7 DAILY NUTRITION SNAPSHOTS (SELECT ONLY for authenticated clients)
DROP POLICY IF EXISTS "Users can view own daily nutrition snapshots" ON public.daily_nutrition_snapshots;
CREATE POLICY "Users can view own daily nutrition snapshots"
    ON public.daily_nutrition_snapshots FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own daily nutrition snapshots" ON public.daily_nutrition_snapshots;
DROP POLICY IF EXISTS "Users can update own daily nutrition snapshots" ON public.daily_nutrition_snapshots;

-- 13.8 DAILY MEAL SLOTS (SELECT ONLY for authenticated clients)
DROP POLICY IF EXISTS "Users can view own meal slots" ON public.daily_meal_slots;
CREATE POLICY "Users can view own meal slots"
    ON public.daily_meal_slots FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own meal slots" ON public.daily_meal_slots;
DROP POLICY IF EXISTS "Users can update own meal slots" ON public.daily_meal_slots;

-- 13.9 CANONICAL RECIPES & RELATED CATALOG (Read-only for all authenticated users)
DROP POLICY IF EXISTS "Authenticated users can read recipes" ON public.recipes;
CREATE POLICY "Authenticated users can read recipes"
    ON public.recipes FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can read recipe ingredients" ON public.recipe_ingredients;
CREATE POLICY "Authenticated users can read recipe ingredients"
    ON public.recipe_ingredients FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can read recipe steps" ON public.recipe_steps;
CREATE POLICY "Authenticated users can read recipe steps"
    ON public.recipe_steps FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Authenticated users can read recipe videos" ON public.recipe_videos;
CREATE POLICY "Authenticated users can read recipe videos"
    ON public.recipe_videos FOR SELECT
    TO authenticated
    USING (true);

-- 13.10 USER SAVED RECIPES (SELECT, INSERT, DELETE)
DROP POLICY IF EXISTS "Users can view own saved recipes" ON public.user_saved_recipes;
CREATE POLICY "Users can view own saved recipes"
    ON public.user_saved_recipes FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can save recipes" ON public.user_saved_recipes;
CREATE POLICY "Users can save recipes"
    ON public.user_saved_recipes FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can unsave recipes" ON public.user_saved_recipes;
CREATE POLICY "Users can unsave recipes"
    ON public.user_saved_recipes FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 13.11 RECIPE RECOMMENDATIONS (SELECT, INSERT, UPDATE, DELETE)
DROP POLICY IF EXISTS "Users can view own recommendations" ON public.recipe_recommendations;
CREATE POLICY "Users can view own recommendations"
    ON public.recipe_recommendations FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own recommendations" ON public.recipe_recommendations;
CREATE POLICY "Users can insert own recommendations"
    ON public.recipe_recommendations FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own recommendations" ON public.recipe_recommendations;
CREATE POLICY "Users can update own recommendations"
    ON public.recipe_recommendations FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own recommendations" ON public.recipe_recommendations;
CREATE POLICY "Users can delete own recommendations"
    ON public.recipe_recommendations FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 13.12 USER REJECTED RECIPES (SELECT, INSERT)
DROP POLICY IF EXISTS "Users can view own rejected recipes" ON public.user_rejected_recipes;
CREATE POLICY "Users can view own rejected recipes"
    ON public.user_rejected_recipes FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can record rejected recipes" ON public.user_rejected_recipes;
CREATE POLICY "Users can record rejected recipes"
    ON public.user_rejected_recipes FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

-- 13.13 WELLNESS LOGS (SELECT, INSERT, UPDATE)
DROP POLICY IF EXISTS "Users can view own wellness logs" ON public.wellness_logs;
CREATE POLICY "Users can view own wellness logs"
    ON public.wellness_logs FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own wellness logs" ON public.wellness_logs;
CREATE POLICY "Users can insert own wellness logs"
    ON public.wellness_logs FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own wellness logs" ON public.wellness_logs;
CREATE POLICY "Users can update own wellness logs"
    ON public.wellness_logs FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 13.14 APP NOTIFICATIONS (SELECT, UPDATE, DELETE)
DROP POLICY IF EXISTS "Users can view own notifications" ON public.app_notifications;
CREATE POLICY "Users can view own notifications"
    ON public.app_notifications FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.app_notifications;
CREATE POLICY "Users can update own notifications"
    ON public.app_notifications FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.app_notifications;
CREATE POLICY "Users can delete own notifications"
    ON public.app_notifications FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- 13.15 AI CONVERSATIONS & MESSAGES (HARDENED RLS, APPEND-ONLY MESSAGES)
DROP POLICY IF EXISTS "Users can view own conversations" ON public.ai_conversations;
CREATE POLICY "Users can view own conversations"
    ON public.ai_conversations FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own conversations" ON public.ai_conversations;
CREATE POLICY "Users can insert own conversations"
    ON public.ai_conversations FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own conversations" ON public.ai_conversations;
CREATE POLICY "Users can delete own conversations"
    ON public.ai_conversations FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- AI Messages: Authenticated users can ONLY SELECT and INSERT (role = 'user').
-- Direct UPDATE and DELETE by authenticated users are prohibited (append-only audit stream).
-- Deleting an entire ai_conversation cascades safely to its messages via foreign key.
DROP POLICY IF EXISTS "Users can view own messages" ON public.ai_messages;
CREATE POLICY "Users can view own messages"
    ON public.ai_messages FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own user messages" ON public.ai_messages;
CREATE POLICY "Users can insert own user messages"
    ON public.ai_messages FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = user_id AND
        role = 'user' AND
        EXISTS (
            SELECT 1 FROM public.ai_conversations c 
            WHERE c.id = conversation_id AND c.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can delete own messages" ON public.ai_messages;

-- =============================================================================
-- 14. SUPABASE STORAGE BUCKETS & ACCESS POLICIES
-- =============================================================================

-- Seed Storage Buckets (Safe upsert into storage.buckets if available)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('food-photos', 'food-photos', false, 8388608, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
    ('meal-logs', 'meal-logs', false, 8388608, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
    ('avatars', 'avatars', true, 2097152, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage RLS: food-photos bucket (Private, isolated to user folder: <user_id>/filename)
DROP POLICY IF EXISTS "Users can view own food photos" ON storage.objects;
CREATE POLICY "Users can view own food photos"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'food-photos' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can upload own food photos" ON storage.objects;
CREATE POLICY "Users can upload own food photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'food-photos' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can update own food photos" ON storage.objects;
CREATE POLICY "Users can update own food photos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'food-photos' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'food-photos' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can delete own food photos" ON storage.objects;
CREATE POLICY "Users can delete own food photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'food-photos' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Storage RLS: meal-logs bucket (Private, isolated to user folder: <user_id>/filename)
DROP POLICY IF EXISTS "Users can view own meal log photos" ON storage.objects;
CREATE POLICY "Users can view own meal log photos"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'meal-logs' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can upload own meal log photos" ON storage.objects;
CREATE POLICY "Users can upload own meal log photos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'meal-logs' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can update own meal log photos" ON storage.objects;
CREATE POLICY "Users can update own meal log photos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'meal-logs' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'meal-logs' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can delete own meal log photos" ON storage.objects;
CREATE POLICY "Users can delete own meal log photos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'meal-logs' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

-- Storage RLS: avatars bucket (Public read, authenticated user-scoped management)
DROP POLICY IF EXISTS "Public read for user avatars" ON storage.objects;
CREATE POLICY "Public read for user avatars"
    ON storage.objects FOR SELECT
    TO PUBLIC
    USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    )
    WITH CHECK (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );

DROP POLICY IF EXISTS "Users can delete own avatar" ON storage.objects;
CREATE POLICY "Users can delete own avatar"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'avatars' AND 
        auth.uid()::text = (storage.foldername(name))[1]
    );
