-- ============================================
-- SCHEMA SYNC - Migration 003
-- Adds columns that Flutter model expects but were missing from DB
-- ============================================

-- Add missing columns that Flutter WardrobeItem model queries
ALTER TABLE wardrobe_items
ADD COLUMN IF NOT EXISTS thumbnail_url text,
ADD COLUMN IF NOT EXISTS subcategory text,
ADD COLUMN IF NOT EXISTS color_hex text;

-- Add index for subcategory filtering (useful for future category breakdowns)
CREATE INDEX IF NOT EXISTS idx_wardrobe_subcategory
ON wardrobe_items(subcategory) WHERE subcategory IS NOT NULL;
