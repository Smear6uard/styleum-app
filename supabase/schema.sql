-- ============================================
-- STYLEUM DATABASE SCHEMA - Source of Truth
-- ============================================
-- This file documents the complete database schema.
-- When modifying the schema:
--   1. Update this file
--   2. Create a new migration in supabase/migrations/
--   3. Update the corresponding Flutter model
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- WARDROBE_ITEMS TABLE
-- ============================================
-- Core table storing user's clothing items

CREATE TABLE IF NOT EXISTS wardrobe_items (
    -- Primary key
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Foreign key to user
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,

    -- Core item fields
    photo_url text,                          -- Main image URL from Supabase storage
    thumbnail_url text,                      -- Smaller thumbnail for grid views
    item_name text,                          -- User-facing name
    category text,                           -- Main category: tops, bottoms, shoes, etc.
    subcategory text,                        -- Sub-category: t-shirt, jeans, sneakers, etc.
    primary_color text,                      -- Human-readable color name
    color_hex text,                          -- Hex color code for UI

    -- Seasonal/occasion metadata
    seasons text[],                          -- ['spring', 'summer', 'fall', 'winter']
    occasions text[],                        -- ['casual', 'work', 'formal', 'athletic']

    -- User preferences
    is_favorite boolean DEFAULT false,

    -- AI Analysis Fields (Florence-2 + Gemini pipeline)
    embedding vector(512),                   -- Marqo-FashionSigLIP embedding
    ai_metadata jsonb DEFAULT '{}',          -- Full AI analysis output
    dense_caption text,                      -- Florence-2 dense caption
    ocr_text text,                           -- Text read from tags/labels
    vibe_scores jsonb DEFAULT '{}',          -- {"cottagecore": 0.85, "minimalist": 0.3}
    era_detected text,                       -- "1970s", "Y2K", "modern"
    era_confidence float,                    -- 0.0 - 1.0
    is_unorthodox boolean DEFAULT false,     -- True for unusual items
    unorthodox_description text,             -- Open vocab description for weird items
    construction_notes text,                 -- Forensic details (stitching, hardware)
    user_verified boolean DEFAULT false,     -- User confirmed/edited tags
    feedback_log jsonb DEFAULT '[]',         -- History of user corrections

    -- Timestamps
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_wardrobe_user_id ON wardrobe_items(user_id);
CREATE INDEX IF NOT EXISTS idx_wardrobe_category ON wardrobe_items(category);
CREATE INDEX IF NOT EXISTS idx_wardrobe_subcategory ON wardrobe_items(subcategory) WHERE subcategory IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_wardrobe_created_at ON wardrobe_items(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wardrobe_embedding ON wardrobe_items USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX IF NOT EXISTS idx_wardrobe_vibe_scores ON wardrobe_items USING gin (vibe_scores);

-- Row Level Security
ALTER TABLE wardrobe_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own wardrobe items" ON wardrobe_items
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wardrobe items" ON wardrobe_items
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wardrobe items" ON wardrobe_items
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own wardrobe items" ON wardrobe_items
    FOR DELETE USING (auth.uid() = user_id);


-- ============================================
-- FLUTTER MODEL MAPPING
-- ============================================
-- WardrobeItem (lib/services/wardrobe_service.dart)
--
-- | Flutter Field        | DB Column              | Type              |
-- |---------------------|------------------------|-------------------|
-- | id                  | id                     | String (uuid)     |
-- | photoUrl            | photo_url              | String?           |
-- | thumbnailUrl        | thumbnail_url          | String?           |
-- | itemName            | item_name              | String?           |
-- | category            | category               | String?           |
-- | subcategory         | subcategory            | String?           |
-- | primaryColor        | primary_color          | String?           |
-- | colorHex            | color_hex              | String?           |
-- | seasons             | seasons                | List<String>?     |
-- | occasions           | occasions              | List<String>?     |
-- | denseCaption        | dense_caption          | String?           |
-- | ocrText             | ocr_text               | String?           |
-- | vibeScores          | vibe_scores            | Map<String,double>|
-- | eraDetected         | era_detected           | String?           |
-- | eraConfidence       | era_confidence         | double?           |
-- | isUnorthodox        | is_unorthodox          | bool              |
-- | unorthodoxDescription| unorthodox_description| String?           |
-- | constructionNotes   | construction_notes     | String?           |
-- | userVerified        | user_verified          | bool              |
-- | embedding           | embedding              | List<double>?     |
