-- Achievement definitions (static, seeded)
CREATE TABLE IF NOT EXISTS achievement_definitions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('wardrobe', 'outfits', 'streaks', 'social', 'style')),
  rarity TEXT NOT NULL CHECK (rarity IN ('common', 'uncommon', 'rare', 'epic', 'legendary')),
  target_progress INTEGER NOT NULL DEFAULT 1,
  icon_name TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User progress on each achievement
CREATE TABLE IF NOT EXISTS user_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL REFERENCES achievement_definitions(id) ON DELETE CASCADE,
  current_progress INTEGER NOT NULL DEFAULT 0,
  unlocked_at TIMESTAMPTZ,
  seen_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);

-- RLS policies
ALTER TABLE achievement_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Achievement definitions are viewable by everyone" ON achievement_definitions;
CREATE POLICY "Achievement definitions are viewable by everyone"
  ON achievement_definitions FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can view own achievement progress" ON user_achievements;
CREATE POLICY "Users can view own achievement progress"
  ON user_achievements FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own achievement progress" ON user_achievements;
CREATE POLICY "Users can update own achievement progress"
  ON user_achievements FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own achievement progress" ON user_achievements;
CREATE POLICY "Users can insert own achievement progress"
  ON user_achievements FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Seed achievement definitions
INSERT INTO achievement_definitions (id, title, description, category, rarity, target_progress, icon_name, sort_order) VALUES
-- Wardrobe (5)
('wardrobe_starter', 'Closet Starter', 'Upload your first item', 'wardrobe', 'common', 1, 'checkroom', 1),
('wardrobe_10', 'Building the Collection', 'Add 10 items to your wardrobe', 'wardrobe', 'common', 10, 'layers', 2),
('wardrobe_25', 'Wardrobe Curator', 'Curate a wardrobe of 25 pieces', 'wardrobe', 'uncommon', 25, 'grid_view', 3),
('wardrobe_50', 'Fashion Hoarder', 'Build a collection of 50 items', 'wardrobe', 'rare', 50, 'inventory_2', 4),
('wardrobe_100', 'Closet Royalty', 'Reach 100 items in your wardrobe', 'wardrobe', 'legendary', 100, 'workspace_premium', 5),

-- Outfits (6)
('outfit_first', 'Fit Check!', 'Generate your first outfit', 'outfits', 'common', 1, 'auto_awesome', 1),
('outfit_wore', 'Wore It!', 'Mark an outfit as worn', 'outfits', 'common', 1, 'check_circle', 2),
('outfit_10', 'Outfit Explorer', 'Generate 10 different outfits', 'outfits', 'uncommon', 10, 'explore', 3),
('outfit_wore_10', 'Regular Wearer', 'Mark 10 outfits as worn', 'outfits', 'uncommon', 10, 'event_repeat', 4),
('outfit_50', 'Style Experimenter', 'Generate 50 unique outfits', 'outfits', 'rare', 50, 'science', 5),
('outfit_100', 'Outfit Machine', 'Generate 100 outfits total', 'outfits', 'legendary', 100, 'bolt', 6),

-- Streaks (5)
('streak_3', 'Getting Started', 'Maintain a 3-day streak', 'streaks', 'common', 3, 'local_fire_department', 1),
('streak_7', 'Style Streak', 'Keep your streak alive for 7 days', 'streaks', 'uncommon', 7, 'whatshot', 2),
('streak_14', 'Fashion Dedicated', 'Achieve a 14-day streak', 'streaks', 'rare', 14, 'track_changes', 3),
('streak_30', 'Fashion Devotee', 'Maintain a 30-day streak', 'streaks', 'epic', 30, 'star', 4),
('streak_100', 'Style Legend', 'Achieve an incredible 100-day streak', 'streaks', 'legendary', 100, 'emoji_events', 5),

-- Social (2)
('social_first', 'Influencer Mode', 'Share your first outfit', 'social', 'uncommon', 1, 'share', 1),
('social_10', 'Social Butterfly', 'Share 10 outfits with friends', 'social', 'rare', 10, 'group', 2),

-- Style (4)
('style_40', 'Style Seedling', 'Earn 40 style points', 'style', 'common', 40, 'eco', 1),
('style_60', 'Style Enthusiast', 'Accumulate 60 style points', 'style', 'uncommon', 60, 'park', 2),
('style_80', 'Style Icon', 'Reach 80 style points', 'style', 'rare', 80, 'workspace_premium', 3),
('style_95', 'Style Master', 'Achieve style mastery with 95 points', 'style', 'legendary', 95, 'diamond', 4)
ON CONFLICT (id) DO NOTHING;
