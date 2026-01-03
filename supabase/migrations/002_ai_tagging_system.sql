-- ============================================
-- AI TAGGING SYSTEM - Migration 002
-- Implements Gemini's architecture:
-- - pgvector for embeddings
-- - Vibe anchors for cluster-based classification
-- - User style vectors for personalization
-- - Active learning feedback storage
-- ============================================

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- ENHANCED WARDROBE ITEMS TABLE
-- ============================================
-- Add AI-powered columns to existing table

ALTER TABLE wardrobe_items 
ADD COLUMN IF NOT EXISTS embedding vector(512),           -- Marqo-FashionSigLIP embedding
ADD COLUMN IF NOT EXISTS ai_metadata jsonb DEFAULT '{}', -- Full Florence-2 + Gemini output
ADD COLUMN IF NOT EXISTS dense_caption text,             -- Florence-2 dense caption
ADD COLUMN IF NOT EXISTS ocr_text text,                  -- Text read from tags/labels
ADD COLUMN IF NOT EXISTS vibe_scores jsonb DEFAULT '{}', -- {"cottagecore": 0.85, "minimalist": 0.3}
ADD COLUMN IF NOT EXISTS era_detected text,              -- "1970s", "Y2K", "modern"
ADD COLUMN IF NOT EXISTS era_confidence float,           -- 0.0 - 1.0
ADD COLUMN IF NOT EXISTS is_unorthodox boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS unorthodox_description text,    -- Open vocab description for weird items
ADD COLUMN IF NOT EXISTS construction_notes text,        -- Forensic details (stitching, hardware)
ADD COLUMN IF NOT EXISTS user_verified boolean DEFAULT false, -- User confirmed/edited tags
ADD COLUMN IF NOT EXISTS feedback_log jsonb DEFAULT '[]';     -- History of user corrections

-- Index for vector similarity search
CREATE INDEX IF NOT EXISTS idx_wardrobe_embedding 
ON wardrobe_items USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Index for vibe filtering
CREATE INDEX IF NOT EXISTS idx_wardrobe_vibe_scores 
ON wardrobe_items USING gin (vibe_scores);

-- ============================================
-- VIBE ANCHORS TABLE
-- ============================================
-- Reference images that define each vibe cluster
-- To add a new vibe: insert 20-50 representative images

CREATE TABLE IF NOT EXISTS vibe_anchors (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    vibe_name text NOT NULL,                    -- "cottagecore", "dark_academia", "y2k"
    vibe_display_name text NOT NULL,            -- "Cottagecore", "Dark Academia", "Y2K"
    vibe_description text,                      -- Human-readable description
    embedding vector(512) NOT NULL,             -- Reference image embedding
    reference_image_url text,                   -- Optional: URL to reference image
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    
    -- Metadata for trend tracking
    trend_score float DEFAULT 0.5,              -- How "in" is this vibe right now
    last_trend_update timestamptz
);

-- Index for fast vibe matching
CREATE INDEX IF NOT EXISTS idx_vibe_anchors_embedding 
ON vibe_anchors USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 50);

CREATE INDEX IF NOT EXISTS idx_vibe_anchors_name 
ON vibe_anchors(vibe_name);

-- ============================================
-- VIBE CENTROIDS TABLE  
-- ============================================
-- Pre-computed average embedding for each vibe
-- Updated nightly from vibe_anchors

CREATE TABLE IF NOT EXISTS vibe_centroids (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    vibe_name text UNIQUE NOT NULL,
    centroid vector(512) NOT NULL,              -- Average of all anchors for this vibe
    anchor_count int DEFAULT 0,
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vibe_centroids_embedding
ON vibe_centroids USING ivfflat (centroid vector_cosine_ops)
WITH (lists = 50);

-- ============================================
-- USER STYLE VECTORS TABLE
-- ============================================
-- The personalization engine - learns from every interaction

CREATE TABLE IF NOT EXISTS user_style_vectors (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    
    -- The main style vector (512-dim, same space as items)
    style_vector vector(512),
    
    -- Interaction counts for weighting
    total_interactions int DEFAULT 0,
    wears_count int DEFAULT 0,
    likes_count int DEFAULT 0,
    rejects_count int DEFAULT 0,
    edits_count int DEFAULT 0,
    
    -- Learned preferences (derived from vector + explicit signals)
    dominant_vibes jsonb DEFAULT '{}',          -- {"minimalist": 0.65, "vintage": 0.2}
    avoided_vibes jsonb DEFAULT '{}',           -- Vibes user consistently rejects
    color_preferences jsonb DEFAULT '{}',
    era_preferences jsonb DEFAULT '{}',
    
    -- Metadata
    vector_version int DEFAULT 1,               -- Increment on major recalculations
    last_interaction_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- ============================================
-- STYLE INTERACTIONS TABLE
-- ============================================
-- Raw log of every interaction for replay/analysis

CREATE TABLE IF NOT EXISTS style_interactions (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    item_id uuid REFERENCES wardrobe_items(id) ON DELETE SET NULL,
    outfit_id text,                             -- Reference to generated outfit
    
    interaction_type text NOT NULL CHECK (interaction_type IN (
        'wear', 'like', 'save', 'reject', 'skip', 
        'tag_edit', 'vibe_confirm', 'vibe_reject'
    )),
    
    -- Context
    item_embedding vector(512),                 -- Snapshot of item embedding at interaction time
    context jsonb DEFAULT '{}',                 -- Additional context (occasion, weather, etc.)
    
    -- For tag edits
    old_value text,
    new_value text,
    
    -- Weight for style vector update
    weight float DEFAULT 1.0,
    
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_style_interactions_user 
ON style_interactions(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_style_interactions_type
ON style_interactions(user_id, interaction_type);

-- ============================================
-- TAG CORRECTIONS TABLE
-- ============================================
-- High-value labeled data from user corrections
-- Used for model fine-tuning

CREATE TABLE IF NOT EXISTS tag_corrections (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    item_id uuid REFERENCES wardrobe_items(id) ON DELETE CASCADE NOT NULL,
    
    field_corrected text NOT NULL,              -- 'era', 'vibe', 'material', etc.
    ai_value text,                              -- What the AI predicted
    user_value text NOT NULL,                   -- What the user corrected to
    
    -- For fine-tuning
    item_embedding vector(512),
    dense_caption text,
    
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tag_corrections_field
ON tag_corrections(field_corrected);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Match item to vibes using cosine similarity
CREATE OR REPLACE FUNCTION match_item_to_vibes(
    item_embedding vector(512),
    match_threshold float DEFAULT 0.7,
    max_vibes int DEFAULT 5
)
RETURNS TABLE (
    vibe_name text,
    similarity float
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        vc.vibe_name,
        1 - (item_embedding <=> vc.centroid) as similarity
    FROM vibe_centroids vc
    WHERE 1 - (item_embedding <=> vc.centroid) >= match_threshold
    ORDER BY item_embedding <=> vc.centroid
    LIMIT max_vibes;
END;
$$ LANGUAGE plpgsql;

-- Update user style vector with new interaction
CREATE OR REPLACE FUNCTION update_user_style_vector(
    p_user_id uuid,
    p_item_embedding vector(512),
    p_interaction_type text,
    p_weight float DEFAULT 1.0
)
RETURNS void AS $$
DECLARE
    current_vector vector(512);
    interaction_weight float;
    decay_factor float := 0.95;
    blend_factor float;
BEGIN
    -- Determine weight based on interaction type
    interaction_weight := CASE p_interaction_type
        WHEN 'wear' THEN 1.0 * p_weight
        WHEN 'like' THEN 0.5 * p_weight
        WHEN 'save' THEN 0.5 * p_weight
        WHEN 'reject' THEN -0.5 * p_weight
        WHEN 'skip' THEN -0.1 * p_weight
        WHEN 'tag_edit' THEN 2.0 * p_weight
        WHEN 'vibe_confirm' THEN 1.5 * p_weight
        WHEN 'vibe_reject' THEN -1.0 * p_weight
        ELSE 0.5 * p_weight
    END;
    
    -- Get current vector
    SELECT style_vector INTO current_vector
    FROM user_style_vectors
    WHERE user_id = p_user_id;
    
    -- Calculate blend factor (less influence as interactions accumulate)
    SELECT 1.0 / (1 + total_interactions * 0.01) INTO blend_factor
    FROM user_style_vectors
    WHERE user_id = p_user_id;
    
    IF blend_factor IS NULL THEN
        blend_factor := 0.5;
    END IF;
    
    -- If positive interaction, pull toward item; if negative, push away
    IF interaction_weight > 0 THEN
        -- Weighted average toward item
        IF current_vector IS NULL THEN
            -- First interaction, just use item embedding
            INSERT INTO user_style_vectors (user_id, style_vector, total_interactions, last_interaction_at)
            VALUES (p_user_id, p_item_embedding, 1, now())
            ON CONFLICT (user_id) DO UPDATE SET
                style_vector = p_item_embedding,
                total_interactions = 1,
                last_interaction_at = now();
        ELSE
            UPDATE user_style_vectors
            SET 
                style_vector = (
                    SELECT array_agg(
                        decay_factor * c + (1 - decay_factor) * blend_factor * interaction_weight * i
                    )::vector(512)
                    FROM unnest(current_vector::float[], p_item_embedding::float[]) AS t(c, i)
                ),
                total_interactions = total_interactions + 1,
                last_interaction_at = now(),
                updated_at = now()
            WHERE user_id = p_user_id;
        END IF;
    ELSE
        -- Negative: push away (subtract weighted item vector)
        IF current_vector IS NOT NULL THEN
            UPDATE user_style_vectors
            SET 
                style_vector = (
                    SELECT array_agg(
                        decay_factor * c - (1 - decay_factor) * blend_factor * ABS(interaction_weight) * i
                    )::vector(512)
                    FROM unnest(current_vector::float[], p_item_embedding::float[]) AS t(c, i)
                ),
                total_interactions = total_interactions + 1,
                last_interaction_at = now(),
                updated_at = now()
            WHERE user_id = p_user_id;
        END IF;
    END IF;
    
    -- Update interaction counts
    UPDATE user_style_vectors
    SET
        wears_count = wears_count + CASE WHEN p_interaction_type = 'wear' THEN 1 ELSE 0 END,
        likes_count = likes_count + CASE WHEN p_interaction_type IN ('like', 'save') THEN 1 ELSE 0 END,
        rejects_count = rejects_count + CASE WHEN p_interaction_type = 'reject' THEN 1 ELSE 0 END,
        edits_count = edits_count + CASE WHEN p_interaction_type = 'tag_edit' THEN 1 ELSE 0 END
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Recalculate vibe centroids from anchors
CREATE OR REPLACE FUNCTION recalculate_vibe_centroids()
RETURNS void AS $$
BEGIN
    -- Clear and rebuild centroids
    TRUNCATE vibe_centroids;
    
    INSERT INTO vibe_centroids (vibe_name, centroid, anchor_count, updated_at)
    SELECT 
        vibe_name,
        avg(embedding) as centroid,
        count(*) as anchor_count,
        now() as updated_at
    FROM vibe_anchors
    WHERE is_active = true
    GROUP BY vibe_name;
END;
$$ LANGUAGE plpgsql;

-- Find items similar to user's style
CREATE OR REPLACE FUNCTION get_items_matching_style(
    p_user_id uuid,
    p_limit int DEFAULT 20
)
RETURNS TABLE (
    item_id uuid,
    similarity float
) AS $$
DECLARE
    user_vector vector(512);
BEGIN
    SELECT style_vector INTO user_vector
    FROM user_style_vectors
    WHERE user_id = p_user_id;
    
    IF user_vector IS NULL THEN
        -- No style vector yet, return recent items
        RETURN QUERY
        SELECT wi.id, 0.5::float
        FROM wardrobe_items wi
        WHERE wi.user_id = p_user_id
        ORDER BY wi.created_at DESC
        LIMIT p_limit;
    ELSE
        RETURN QUERY
        SELECT 
            wi.id,
            1 - (wi.embedding <=> user_vector) as similarity
        FROM wardrobe_items wi
        WHERE wi.user_id = p_user_id
          AND wi.embedding IS NOT NULL
        ORDER BY wi.embedding <=> user_vector
        LIMIT p_limit;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

ALTER TABLE vibe_anchors ENABLE ROW LEVEL SECURITY;
ALTER TABLE vibe_centroids ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_style_vectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE style_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE tag_corrections ENABLE ROW LEVEL SECURITY;

-- Vibe anchors are public read
DROP POLICY IF EXISTS "Vibe anchors are public" ON vibe_anchors;
CREATE POLICY "Vibe anchors are public" ON vibe_anchors
    FOR SELECT USING (true);

-- Vibe centroids are public read
DROP POLICY IF EXISTS "Vibe centroids are public" ON vibe_centroids;
CREATE POLICY "Vibe centroids are public" ON vibe_centroids
    FOR SELECT USING (true);

-- Users can only access their own style data
DROP POLICY IF EXISTS "Users access own style vectors" ON user_style_vectors;
CREATE POLICY "Users access own style vectors" ON user_style_vectors
    FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users access own interactions" ON style_interactions;
CREATE POLICY "Users access own interactions" ON style_interactions
    FOR ALL USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users access own corrections" ON tag_corrections;
CREATE POLICY "Users access own corrections" ON tag_corrections
    FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- SEED INITIAL VIBE DEFINITIONS
-- ============================================
-- These are placeholder names - actual embeddings come from reference images

INSERT INTO vibe_centroids (vibe_name, centroid, anchor_count) VALUES
    ('minimalist', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('maximalist', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('cottagecore', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('dark_academia', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('y2k', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('grunge', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('quiet_luxury', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('streetwear', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('bohemian', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('preppy', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('punk', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('vintage_americana', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('avant_garde', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('athleisure', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('coastal_grandmother', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('gorpcore', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('ballet_core', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('indie_sleaze', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('old_money', array_fill(0::float, ARRAY[512])::vector(512), 0),
    ('eclectic_grandpa', array_fill(0::float, ARRAY[512])::vector(512), 0)
ON CONFLICT DO NOTHING;
