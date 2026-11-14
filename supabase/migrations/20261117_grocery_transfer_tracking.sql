-- ============================================================================
-- Migration: 20261117_grocery_transfer_tracking.sql
-- Feature: One-Tap Grocery to Fridge Inventory Transfer Tracking
-- Description:
--   Adds idempotent transfer tracking and inventory record linking to
--   public.grocery_items. Ensures purchased items can be transferred directly
--   into active fridge inventory while preserving shopping history.
-- ============================================================================

-- 1. Add transfer tracking and inventory linking columns
ALTER TABLE public.grocery_items
    ADD COLUMN IF NOT EXISTS is_transferred BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS transferred_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS inventory_item_id TEXT,
    ADD COLUMN IF NOT EXISTS expiry_date DATE;

-- 2. Partial index for fast querying of untransferred purchased items
CREATE INDEX IF NOT EXISTS idx_grocery_items_untransferred_purchased
    ON public.grocery_items (user_id, is_purchased, is_transferred)
    WHERE is_purchased = true AND is_transferred = false;

-- 3. Index for querying transferred items linked to fridge inventory
CREATE INDEX IF NOT EXISTS idx_grocery_items_transferred_lookup
    ON public.grocery_items (user_id, is_transferred, transferred_at DESC)
    WHERE is_transferred = true;
