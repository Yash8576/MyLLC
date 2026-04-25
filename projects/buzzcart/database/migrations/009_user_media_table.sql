-- Migration 009: Add user_media table for unified media storage
-- This table stores all user-uploaded media (photos, videos, reels) for profile gallery

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'media_type') THEN
        CREATE TYPE media_type AS ENUM ('photo', 'video', 'reel');
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS user_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    media_type media_type NOT NULL,
    media_url VARCHAR(500) NOT NULL,
    thumbnail_url VARCHAR(500),
    caption TEXT,
    width INT,
    height INT,
    duration_seconds INT, -- For videos/reels
    file_size_bytes BIGINT,
    
    -- Link to content_items table if applicable (for videos/reels)
    content_id UUID REFERENCES content_items(id) ON DELETE SET NULL,
    
    -- Engagement metrics
    view_count INT DEFAULT 0,
    like_count INT DEFAULT 0,
    comment_count INT DEFAULT 0,
    
    is_archived BOOLEAN DEFAULT FALSE,
    is_profile_picture BOOLEAN DEFAULT FALSE,
    is_cover_photo BOOLEAN DEFAULT FALSE,
    
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_media_url CHECK (media_url <> '')
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_user_media_user_id ON user_media(user_id);
CREATE INDEX IF NOT EXISTS idx_user_media_user_created ON user_media(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_media_type ON user_media(media_type);
CREATE INDEX IF NOT EXISTS idx_user_media_archived ON user_media(user_id, is_archived) WHERE is_archived = FALSE;

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_media_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_media_updated_at ON user_media;
CREATE TRIGGER trigger_update_user_media_updated_at
BEFORE UPDATE ON user_media
FOR EACH ROW
EXECUTE FUNCTION update_user_media_updated_at();

-- Backward-compatible references expected by older app paths
ALTER TABLE user_media ADD COLUMN IF NOT EXISTS video_id UUID;
ALTER TABLE user_media ADD COLUMN IF NOT EXISTS reel_id UUID;

-- View for user gallery (non-archived media)
CREATE OR REPLACE VIEW user_gallery AS
SELECT 
    um.id,
    um.user_id,
    um.media_type,
    um.media_url,
    um.thumbnail_url,
    um.caption,
    um.view_count,
    um.like_count,
    um.comment_count,
    um.created_at,
    u.username,
    u.name as user_name
FROM user_media um
JOIN users u ON um.user_id = u.id
WHERE um.is_archived = FALSE
ORDER BY um.created_at DESC;

COMMENT ON TABLE user_media IS 'Unified storage for all user-uploaded media (photos, videos, reels)';
COMMENT ON COLUMN user_media.media_type IS 'Type of media: photo, video, or reel';
COMMENT ON COLUMN user_media.video_id IS 'Reference to videos table if this is a video post';
COMMENT ON COLUMN user_media.reel_id IS 'Reference to reels table if this is a reel post';
