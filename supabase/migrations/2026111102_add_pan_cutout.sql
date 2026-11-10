-- =============================================================================
-- NUTRIFRIDGE — ADD PAN CUTOUT SUPPORT MIGRATION
-- Migration Version: 20261111_add_pan_cutout
-- Technology Stack: PostgreSQL 15+ (Supabase) · Flutter Mobile Client · Supabase Storage
-- Architecture: Adds dedicated background-free transparent PNG/WebP cutout URL
--                and pan override flag for Interactive Cooking Pan synchronization.
-- =============================================================================

ALTER TABLE public.food_image_mappings
ADD COLUMN IF NOT EXISTS pan_cutout_url TEXT;

ALTER TABLE public.food_image_mappings
ADD COLUMN IF NOT EXISTS is_pan_override BOOLEAN NOT NULL DEFAULT false;

-- Index for querying mapped transparent cutouts
CREATE INDEX IF NOT EXISTS idx_food_image_mappings_pan_cutout
    ON public.food_image_mappings (entity_type, entity_key, pan_cutout_url)
    WHERE pan_cutout_url IS NOT NULL;
