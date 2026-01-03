-- ============================================
-- COMPLETE SCHEMA - Migration 004
-- Adds missing columns, tables, and functions
-- for full AI tagging and outfit generation
-- ============================================

-- ============================================
-- ADD MISSING COLUMNS TO WARDROBE_ITEMS
-- ============================================

ALTER TABLE wardrobe_items
ADD COLUMN IF NOT EXISTS material text,
ADD COLUMN IF NOT EXISTS style_bucket text,
ADD COLUMN IF NOT EXISTS formality text,
ADD COLUMN IF NOT EXISTS seasonality text,
ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS times_worn int DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_worn timestamptz;

-- Index for times_worn (for outfit generation prioritization)
CREATE INDEX IF NOT EXISTS idx_wardrobe_times_worn
ON wardrobe_items(user_id, times_worn);

-- Index for last_worn (for recently worn filtering)
CREATE INDEX IF NOT EXISTS idx_wardrobe_last_worn
ON wardrobe_items(user_id, last_worn DESC NULLS LAST);

-- ============================================
-- DAILY_QUEUE TABLE
-- Pre-generated outfits created at 4 AM
-- ============================================

CREATE TABLE IF NOT EXISTS daily_queue (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL,
    outfits jsonb NOT NULL,
    weather_context jsonb,
    generated_at timestamptz DEFAULT now(),

    UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_queue_user_date
ON daily_queue(user_id, date DESC);

-- ============================================
-- DAILY_LOG TABLE
-- Tracks what outfit user wore each day
-- ============================================

CREATE TABLE IF NOT EXISTS daily_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL,
    outfit_id text,
    top_id uuid REFERENCES wardrobe_items(id) ON DELETE SET NULL,
    bottom_id uuid REFERENCES wardrobe_items(id) ON DELETE SET NULL,
    shoes_id uuid REFERENCES wardrobe_items(id) ON DELETE SET NULL,
    outerwear_id uuid REFERENCES wardrobe_items(id) ON DELETE SET NULL,
    accessory_id uuid REFERENCES wardrobe_items(id) ON DELETE SET NULL,
    wore_suggested boolean DEFAULT false,
    confirmed_at timestamptz,

    UNIQUE(user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_daily_log_user_date
ON daily_log(user_id, date DESC);

-- ============================================
-- SAVED_OUTFITS TABLE
-- User's favorite/saved outfit combinations
-- ============================================

CREATE TABLE IF NOT EXISTS saved_outfits (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    outfit_data jsonb NOT NULL,
    saved_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_saved_outfits_user
ON saved_outfits(user_id, saved_at DESC);

-- ============================================
-- ROW LEVEL SECURITY FOR NEW TABLES
-- ============================================

ALTER TABLE daily_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_outfits ENABLE ROW LEVEL SECURITY;

-- Daily Queue policies
DROP POLICY IF EXISTS "Users access own queue" ON daily_queue;
CREATE POLICY "Users access own queue" ON daily_queue
    FOR ALL USING (auth.uid() = user_id);

-- Daily Log policies
DROP POLICY IF EXISTS "Users access own log" ON daily_log;
CREATE POLICY "Users access own log" ON daily_log
    FOR ALL USING (auth.uid() = user_id);

-- Saved Outfits policies
DROP POLICY IF EXISTS "Users access own saved" ON saved_outfits;
CREATE POLICY "Users access own saved" ON saved_outfits
    FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- INCREMENT_TIMES_WORN FUNCTION
-- Called when user wears an outfit
-- ============================================

CREATE OR REPLACE FUNCTION increment_times_worn(item_id uuid)
RETURNS void AS $$
BEGIN
    UPDATE wardrobe_items
    SET times_worn = COALESCE(times_worn, 0) + 1,
        last_worn = now(),
        updated_at = now()
    WHERE id = item_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- GET_RECENTLY_WORN_IDS FUNCTION
-- Returns item IDs worn in the last N days
-- ============================================

CREATE OR REPLACE FUNCTION get_recently_worn_ids(
    p_user_id uuid,
    p_days int DEFAULT 3
)
RETURNS TABLE (item_id uuid) AS $$
BEGIN
    RETURN QUERY
    SELECT dl.top_id FROM daily_log dl
    WHERE dl.user_id = p_user_id
    AND dl.date >= (CURRENT_DATE - p_days)
    AND dl.top_id IS NOT NULL
    UNION
    SELECT dl.bottom_id FROM daily_log dl
    WHERE dl.user_id = p_user_id
    AND dl.date >= (CURRENT_DATE - p_days)
    AND dl.bottom_id IS NOT NULL
    UNION
    SELECT dl.shoes_id FROM daily_log dl
    WHERE dl.user_id = p_user_id
    AND dl.date >= (CURRENT_DATE - p_days)
    AND dl.shoes_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
