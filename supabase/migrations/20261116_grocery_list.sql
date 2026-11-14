-- =============================================================================
-- NUTRIFRIDGE — GROCERY LIST PERSISTENCE MIGRATION
-- Migration Version: 20261116_grocery_list.sql
-- Description:
--   Dedicated user-scoped table for managing persistent grocery shopping items.
--   Enforces Row Level Security (RLS), updated_at trigger, duplicate indexes,
--   and Realtime publication.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.grocery_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    quantity NUMERIC(10,2) NOT NULL DEFAULT 1.0 CHECK (quantity > 0),
    unit TEXT NOT NULL DEFAULT 'pieces',
    category TEXT NOT NULL DEFAULT 'Others',
    is_purchased BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast user-scoped lookup sorted by creation / status
CREATE INDEX IF NOT EXISTS idx_grocery_items_user_status
    ON public.grocery_items (user_id, is_purchased, created_at DESC);

-- Fast duplicate check index on normalized name, unit and user
CREATE INDEX IF NOT EXISTS idx_grocery_items_user_name_unit
    ON public.grocery_items (user_id, lower(trim(name)), lower(trim(unit)));

-- Automatic updated_at trigger
DROP TRIGGER IF EXISTS set_grocery_items_updated_at ON public.grocery_items;
CREATE TRIGGER set_grocery_items_updated_at
    BEFORE UPDATE ON public.grocery_items
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE public.grocery_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own grocery items" ON public.grocery_items;
CREATE POLICY "Users can view own grocery items"
    ON public.grocery_items FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own grocery items" ON public.grocery_items;
CREATE POLICY "Users can insert own grocery items"
    ON public.grocery_items FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own grocery items" ON public.grocery_items;
CREATE POLICY "Users can update own grocery items"
    ON public.grocery_items FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own grocery items" ON public.grocery_items;
CREATE POLICY "Users can delete own grocery items"
    ON public.grocery_items FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.grocery_items TO authenticated;

-- Realtime synchronization
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime'
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' 
              AND schemaname = 'public' 
              AND tablename = 'grocery_items'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.grocery_items;
        END IF;
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Realtime publication setup skipped or restricted: %', SQLERRM;
END $$;
