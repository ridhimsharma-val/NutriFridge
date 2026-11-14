-- =============================================================================
-- NUTRIFRIDGE CONSOLIDATED MIGRATION
-- Migration: 20261115_saved_recipes_and_expiry_cleanup.sql
-- Description:
--   1. Persistent Saved Recipes: Dedicated snapshot table with user ownership,
--      JSONB fidelity, relational metadata, and strict RLS policies.
--   2. Automatic Expired Inventory Cleanup: Server-side procedure, timezone-aware
--      local date resolution, and idempotent hourly pg_cron scheduling.
-- Source of Truth: Audited schema in 20261106_initial_schema.sql & 20261107_fix_inventory_deduction.sql
-- =============================================================================

-- =============================================================================
-- PART 1: PERSISTENT SAVED RECIPES & FAVOURITES
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.saved_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    catalog_recipe_id UUID REFERENCES public.recipes(id) ON DELETE SET NULL,
    recipe_identifier TEXT NOT NULL,
    title TEXT NOT NULL,
    meal_type TEXT NOT NULL DEFAULT '',
    image_url TEXT NOT NULL DEFAULT '',
    image_key TEXT,
    calories INTEGER NOT NULL DEFAULT 0 CHECK (calories >= 0),
    protein_g NUMERIC(6,1) NOT NULL DEFAULT 0 CHECK (protein_g >= 0),
    carbs_g NUMERIC(6,1) NOT NULL DEFAULT 0 CHECK (carbs_g >= 0),
    fat_g NUMERIC(6,1) NOT NULL DEFAULT 0 CHECK (fat_g >= 0),
    prep_time_minutes INTEGER DEFAULT 0 CHECK (prep_time_minutes >= 0),
    cooking_time_minutes INTEGER CHECK (cooking_time_minutes IS NULL OR cooking_time_minutes >= 0),
    serving_size TEXT NOT NULL DEFAULT '1 serving',
    recipe_snapshot JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Prevent duplicate saves of the same recipe instance
    CONSTRAINT uq_saved_recipes_user_identifier UNIQUE (user_id, recipe_identifier)
);

-- Fast case-insensitive title search index (non-unique: permits genuinely different recipes with same name)
CREATE INDEX IF NOT EXISTS idx_saved_recipes_user_title
    ON public.saved_recipes (user_id, lower(trim(title)));

-- Fast lookups by user sorted by creation timestamp
CREATE INDEX IF NOT EXISTS idx_saved_recipes_user_created
    ON public.saved_recipes (user_id, created_at DESC);

-- Fast meal category filtering (Breakfast, Lunch, Dinner, Snack)
CREATE INDEX IF NOT EXISTS idx_saved_recipes_user_meal_type
    ON public.saved_recipes (user_id, meal_type);

-- Automatic updated_at trigger invoking existing public.handle_updated_at()
DROP TRIGGER IF EXISTS set_saved_recipes_updated_at ON public.saved_recipes;
CREATE TRIGGER set_saved_recipes_updated_at
    BEFORE UPDATE ON public.saved_recipes
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- PART 1.1: ROW LEVEL SECURITY FOR SAVED RECIPES
-- =============================================================================

ALTER TABLE public.saved_recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own saved recipes" ON public.saved_recipes;
CREATE POLICY "Users can view own saved recipes"
    ON public.saved_recipes FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own saved recipes" ON public.saved_recipes;
CREATE POLICY "Users can insert own saved recipes"
    ON public.saved_recipes FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own saved recipes" ON public.saved_recipes;
CREATE POLICY "Users can update own saved recipes"
    ON public.saved_recipes FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own saved recipes" ON public.saved_recipes;
CREATE POLICY "Users can delete own saved recipes"
    ON public.saved_recipes FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.saved_recipes TO authenticated;

-- =============================================================================
-- PART 2: REALTIME PUBLICATION SYNCHRONIZATION
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        -- Add public.fridge_items if not already in publication
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
              AND schemaname = 'public' 
              AND tablename = 'fridge_items'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.fridge_items;
        END IF;

        -- Add public.saved_recipes if not already in publication
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
              AND schemaname = 'public' 
              AND tablename = 'saved_recipes'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.saved_recipes;
        END IF;
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- Publication adjustment is advisory; bypass if permissions are restricted
    RAISE NOTICE 'Realtime publication setup skipped or restricted: %', SQLERRM;
END $$;

-- =============================================================================
-- PART 3: AUTOMATIC EXPIRED INVENTORY CLEANUP
-- =============================================================================

-- Note on Indexing:
-- The existing index idx_fridge_items_expiry ON public.fridge_items(user_id, expiry_date)
-- was verified in 20261106_initial_schema.sql line 285. It completely satisfies the
-- cleanup lookup requirements without creating a redundant partial index.

-- 3.1 Timezone-safe local calendar date resolver
CREATE OR REPLACE FUNCTION public.safe_user_local_date(p_timezone TEXT)
RETURNS DATE
STABLE
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_timezone IS NOT NULL AND p_timezone <> '' THEN
        RETURN (pg_catalog.now() AT TIME ZONE p_timezone)::DATE;
    END IF;
    RETURN (pg_catalog.now() AT TIME ZONE 'UTC')::DATE;
EXCEPTION WHEN OTHERS THEN
    RETURN (pg_catalog.now() AT TIME ZONE 'UTC')::DATE;
END;
$$;

-- 3.2 Scheduled server-side cleanup procedure
CREATE OR REPLACE FUNCTION public.cleanup_expired_fridge_items()
RETURNS TABLE (
    deleted_count BIGINT,
    affected_users_count BIGINT
)
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted_count BIGINT := 0;
    v_affected_users_count BIGINT := 0;
BEGIN
    WITH expired_items AS (
        SELECT fi.id, fi.user_id
        FROM public.fridge_items fi
        LEFT JOIN public.profiles p ON fi.user_id = p.id
        WHERE fi.expiry_date IS NOT NULL
          AND fi.expiry_date < public.safe_user_local_date(p.timezone)
    ),
    deleted_rows AS (
        DELETE FROM public.fridge_items fi
        WHERE fi.id IN (SELECT id FROM expired_items)
        RETURNING fi.id, fi.user_id
    )
    SELECT COUNT(*), COUNT(DISTINCT user_id)
    INTO v_deleted_count, v_affected_users_count
    FROM deleted_rows;

    deleted_count := v_deleted_count;
    affected_users_count := v_affected_users_count;
    RETURN NEXT;
END;
$$;

-- 3.3 User-scoped cleanup function (invoked on app open / resume by authenticated user)
CREATE OR REPLACE FUNCTION public.cleanup_my_expired_fridge_items()
RETURNS INTEGER
SECURITY DEFINER
SET search_path = public, pg_catalog, pg_temp
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_timezone TEXT;
    v_local_date DATE;
    v_deleted INTEGER := 0;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT timezone INTO v_user_timezone
    FROM public.profiles
    WHERE id = v_user_id;

    v_local_date := public.safe_user_local_date(v_user_timezone);

    WITH deleted AS (
        DELETE FROM public.fridge_items
        WHERE user_id = v_user_id
          AND expiry_date IS NOT NULL
          AND expiry_date < v_local_date
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted FROM deleted;

    RETURN v_deleted;
END;
$$;

-- Security Settings
REVOKE EXECUTE ON FUNCTION public.cleanup_expired_fridge_items() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_fridge_items() TO postgres, service_role;

GRANT EXECUTE ON FUNCTION public.cleanup_my_expired_fridge_items() TO authenticated;

-- =============================================================================
-- PART 4: IDEMPOTENT HOURLY PG_CRON SCHEDULING
-- =============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
        -- Remove existing schedule if already registered to prevent duplicates
        PERFORM cron.unschedule('nutrifridge-hourly-expiry-cleanup')
        WHERE EXISTS (
            SELECT 1 FROM cron.job WHERE jobname = 'nutrifridge-hourly-expiry-cleanup'
        );

        -- Schedule hourly cleanup at the top of every hour
        PERFORM cron.schedule(
            'nutrifridge-hourly-expiry-cleanup',
            '0 * * * *',
            $$SELECT public.cleanup_expired_fridge_items();$$
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron schedule configuration bypassed or not permitted in this environment: %', SQLERRM;
END $$;
