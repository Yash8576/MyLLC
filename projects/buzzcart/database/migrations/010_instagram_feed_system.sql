-- ============================================================================
-- Migration 010: Instagram-Style Feed System
-- ============================================================================
-- This migration creates the infrastructure for an Instagram-style hybrid feed:
-- 1. Posts table (unified content from user_media)
-- 2. User feeds table (fan-out on write for followers)
-- 3. Engagement tracking (likes, comments, shares)
-- 4. Privacy-aware content distribution
-- ============================================================================

-- ============================================================================
-- PART 1: Posts Table (Main Content Index)
-- ============================================================================
-- This table serves as the primary index for all user posts (photos/videos)
-- It references user_media but adds visibility and engagement tracking

CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    media_id UUID NOT NULL REFERENCES user_media(id) ON DELETE CASCADE,
    
    -- Content metadata
    caption TEXT,
    media_type VARCHAR(20) NOT NULL, -- photo, video, reel
    media_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    
    -- Privacy & Visibility
    is_private BOOLEAN NOT NULL DEFAULT FALSE, -- Derived from user's privacy_profile
    visibility VARCHAR(20) NOT NULL DEFAULT 'followers', -- followers, public, close_friends
    
    -- Engagement metrics (denormalized for performance)
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    share_count INT DEFAULT 0,
    view_count INT DEFAULT 0,
    
    -- Ranking factors
    engagement_score FLOAT DEFAULT 0.0, -- Computed score for ranking
    last_engagement_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Location (optional)
    location_name VARCHAR(255),
    location_lat FLOAT,
    location_lng FLOAT,
    
    -- Metadata
    tagged_users UUID[], -- Array of user IDs tagged in the post
    hashtags TEXT[], -- Array of hashtags
    metadata JSONB DEFAULT '{}'::jsonb,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_visibility CHECK (visibility IN ('followers', 'public', 'close_friends'))
);

-- Indexes for feed queries
CREATE INDEX idx_posts_user_id ON posts(user_id, created_at DESC);
CREATE INDEX idx_posts_visibility ON posts(visibility, created_at DESC);
CREATE INDEX idx_posts_engagement ON posts(engagement_score DESC, created_at DESC);
CREATE INDEX idx_posts_hashtags ON posts USING GIN(hashtags);
CREATE INDEX idx_posts_tagged_users ON posts USING GIN(tagged_users);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);

-- Composite index for discovery feed (public + non-private posts ranked by engagement)
CREATE INDEX idx_posts_discovery ON posts(visibility, is_private, engagement_score DESC, created_at DESC);

COMMENT ON TABLE posts IS 'Primary index for all user posts with engagement tracking and privacy controls';
COMMENT ON COLUMN posts.is_private IS 'If TRUE, only approved followers can see this post (for private accounts)';
COMMENT ON COLUMN posts.visibility IS 'Visibility level: followers (default), public (anyone), close_friends (future)';
COMMENT ON COLUMN posts.engagement_score IS 'Computed ranking score based on likes, comments, shares, and recency';

-- ============================================================================
-- PART 2: User Feeds Table (Fan-out on Write - Push Model)
-- ============================================================================
-- Pre-computed feed for each user's followers
-- When a user posts, their post_id is pushed to all followers' feeds

CREATE TABLE IF NOT EXISTS user_feeds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- The user viewing the feed
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE, -- The post to show
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, -- The post creator
    
    -- Feed ordering
    feed_rank FLOAT DEFAULT 0.0, -- Personalized ranking score
    feed_position INT, -- Position in feed (for pagination)
    
    -- Tracking
    is_seen BOOLEAN DEFAULT FALSE,
    seen_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicates
    UNIQUE (user_id, post_id)
);

-- Indexes for efficient feed retrieval
CREATE INDEX idx_user_feeds_user_created ON user_feeds(user_id, created_at DESC);
CREATE INDEX idx_user_feeds_user_rank ON user_feeds(user_id, feed_rank DESC, created_at DESC);
CREATE INDEX idx_user_feeds_post ON user_feeds(post_id);
CREATE INDEX idx_user_feeds_author ON user_feeds(author_id);

COMMENT ON TABLE user_feeds IS 'Pre-computed feed items for each user (fan-out on write). Posts from followed users are pushed here.';

-- ============================================================================
-- PART 3: Post Likes Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS post_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE (post_id, user_id)
);

CREATE INDEX idx_post_likes_post ON post_likes(post_id);
CREATE INDEX idx_post_likes_user ON post_likes(user_id, created_at DESC);

-- ============================================================================
-- PART 4: Post Comments Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE, -- For replies
    
    comment_text TEXT NOT NULL,
    like_count INT DEFAULT 0,
    
    is_pinned BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_comment CHECK (LENGTH(comment_text) > 0)
);

CREATE INDEX idx_post_comments_post ON post_comments(post_id, created_at DESC);
CREATE INDEX idx_post_comments_user ON post_comments(user_id);
CREATE INDEX idx_post_comments_parent ON post_comments(parent_comment_id);

-- ============================================================================
-- PART 5: Post Shares Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS post_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    share_type VARCHAR(50) DEFAULT 'external', -- external, story, message
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_post_shares_post ON post_shares(post_id);
CREATE INDEX idx_post_shares_user ON post_shares(user_id, created_at DESC);

-- ============================================================================
-- PART 6: Triggers for Automatic Updates
-- ============================================================================

-- Trigger to update posts.updated_at
CREATE OR REPLACE FUNCTION update_posts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER posts_updated_at_trigger
BEFORE UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION update_posts_updated_at();

-- Trigger to auto-increment post like_count
CREATE OR REPLACE FUNCTION increment_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts SET like_count = like_count + 1, last_engagement_at = CURRENT_TIMESTAMP WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER post_like_added
AFTER INSERT ON post_likes
FOR EACH ROW
EXECUTE FUNCTION increment_post_likes();

-- Trigger to auto-decrement post like_count
CREATE OR REPLACE FUNCTION decrement_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts SET like_count = GREATEST(like_count - 1, 0), last_engagement_at = CURRENT_TIMESTAMP WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER post_like_removed
AFTER DELETE ON post_likes
FOR EACH ROW
EXECUTE FUNCTION decrement_post_likes();

-- Trigger to auto-increment post comment_count
CREATE OR REPLACE FUNCTION increment_post_comments()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_deleted = FALSE THEN
        UPDATE posts SET comment_count = comment_count + 1, last_engagement_at = CURRENT_TIMESTAMP WHERE id = NEW.post_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER post_comment_added
AFTER INSERT ON post_comments
FOR EACH ROW
EXECUTE FUNCTION increment_post_comments();

-- Trigger to auto-increment post share_count
CREATE OR REPLACE FUNCTION increment_post_shares()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts SET share_count = share_count + 1, last_engagement_at = CURRENT_TIMESTAMP WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER post_share_added
AFTER INSERT ON post_shares
FOR EACH ROW
EXECUTE FUNCTION increment_post_shares();

-- ============================================================================
-- PART 7: Function to Calculate Engagement Score
-- ============================================================================
-- This uses a "Hacker News" style ranking algorithm:
-- Score = (Total Engagement) / (Hours Since Post + 2)^Gravity
-- Gravity = 1.8 (higher value = faster score decay)

CREATE OR REPLACE FUNCTION calculate_engagement_score(
    p_like_count INT,
    p_comment_count INT,
    p_share_count INT,
    p_created_at TIMESTAMP WITH TIME ZONE,
    p_gravity FLOAT DEFAULT 1.8
) RETURNS FLOAT AS $$
DECLARE
    total_engagement INT;
    hours_since_post FLOAT;
    score FLOAT;
BEGIN
    -- Weight different engagement types
    total_engagement := (p_like_count * 1) + (p_comment_count * 3) + (p_share_count * 5);
    
    -- Calculate hours since post
    hours_since_post := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - p_created_at)) / 3600.0;
    
    -- Calculate score with gravity
    score := total_engagement / POWER(hours_since_post + 2, p_gravity);
    
    RETURN score;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PART 8: Function to Update Engagement Scores (Run Periodically)
-- ============================================================================

CREATE OR REPLACE FUNCTION update_all_engagement_scores()
RETURNS void AS $$
BEGIN
    UPDATE posts
    SET engagement_score = calculate_engagement_score(
        like_count,
        comment_count,
        share_count,
        created_at,
        1.8
    )
    WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '7 days'; -- Only update recent posts
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_all_engagement_scores IS 'Updates engagement scores for all posts from the last 7 days. Should be run periodically (e.g., every 15 minutes).';

-- ============================================================================
-- PART 9: Helper Views
-- ============================================================================

-- View for public posts (global discovery feed)
CREATE OR REPLACE VIEW public_posts AS
SELECT 
    p.*,
    u.name as author_name,
    u.avatar as author_avatar,
    u.is_verified as author_verified
FROM posts p
JOIN users u ON p.user_id = u.id
WHERE p.visibility = 'public' OR (p.visibility = 'followers' AND p.is_private = FALSE)
ORDER BY p.engagement_score DESC, p.created_at DESC;

COMMENT ON VIEW public_posts IS 'All posts visible in global discovery feed (public posts + non-private follower posts)';

-- ============================================================================
-- PART 10: Sample Data & Testing (Optional)
-- ============================================================================

-- Function to fan out a post to followers (called after post creation)
CREATE OR REPLACE FUNCTION fanout_post_to_followers(p_post_id UUID, p_author_id UUID)
RETURNS INT AS $$
DECLARE
    follower_count INT;
BEGIN
    -- Insert post into all followers' feeds
    INSERT INTO user_feeds (user_id, post_id, author_id, created_at)
    SELECT 
        uf.follower_id,
        p_post_id,
        p_author_id,
        CURRENT_TIMESTAMP
    FROM user_follows uf
    WHERE uf.following_id = p_author_id
    ON CONFLICT (user_id, post_id) DO NOTHING;
    
    GET DIAGNOSTICS follower_count = ROW_COUNT;
    RETURN follower_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fanout_post_to_followers IS 'Fan-out function: pushes a new post to all followers feeds (push model)';
