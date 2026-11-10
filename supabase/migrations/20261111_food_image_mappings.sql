-- =============================================================================
-- NUTRIFRIDGE — CENTRALIZED FOOD IMAGE MAPPINGS MIGRATION
-- Migration Version: 20261111_food_image_mappings
-- Technology Stack: PostgreSQL 15+ (Supabase) · Flutter Mobile Client · Pexels API
-- Architecture: Normalized image mappings supporting shared catalog entries and
--                isolated user overrides with strict Row-Level Security (RLS).
-- =============================================================================

-- Table: food_image_mappings
CREATE TABLE IF NOT EXISTS public.food_image_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('ingredient', 'recipe')),
    entity_key TEXT NOT NULL, -- Canonical normalized search key (e.g., 'paneer', 'shahi paneer')
    display_name TEXT NOT NULL,
    image_url TEXT NOT NULL,
    provider TEXT NOT NULL DEFAULT 'pexels',
    provider_photo_id TEXT,
    photographer_name TEXT,
    photographer_url TEXT,
    source_page_url TEXT,
    alt_description TEXT,
    is_user_override BOOLEAN NOT NULL DEFAULT false,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL for shared catalog entries, populated for user overrides
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique constraint ensuring exactly one shared mapping per entity, and at most one override per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_food_image_mappings_unique_entity
    ON public.food_image_mappings (entity_type, entity_key, COALESCE(user_id, '00000000-0000-0000-0000-000000000000'::UUID));

CREATE INDEX IF NOT EXISTS idx_food_image_mappings_lookup
    ON public.food_image_mappings (entity_type, entity_key);

CREATE INDEX IF NOT EXISTS idx_food_image_mappings_user
    ON public.food_image_mappings (user_id);

-- Updated_at trigger
DROP TRIGGER IF EXISTS set_food_image_mappings_updated_at ON public.food_image_mappings;
CREATE TRIGGER set_food_image_mappings_updated_at
    BEFORE UPDATE ON public.food_image_mappings
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable RLS
ALTER TABLE public.food_image_mappings ENABLE ROW LEVEL SECURITY;

-- 1. SELECT: Authenticated users can read shared mappings (user_id IS NULL) and their own overrides (user_id = auth.uid())
CREATE POLICY "Users can view shared mappings and their own overrides"
    ON public.food_image_mappings
    FOR SELECT
    TO authenticated
    USING (user_id IS NULL OR user_id = auth.uid());

-- 2. INSERT: Authenticated users can only insert their own overrides
CREATE POLICY "Users can insert their own overrides"
    ON public.food_image_mappings
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid() AND is_user_override = true);

-- 3. UPDATE: Authenticated users can only update their own overrides
CREATE POLICY "Users can update their own overrides"
    ON public.food_image_mappings
    FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid() AND is_user_override = true);

-- 4. DELETE: Authenticated users can only delete their own overrides (revert to automatic)
CREATE POLICY "Users can delete their own overrides"
    ON public.food_image_mappings
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());
