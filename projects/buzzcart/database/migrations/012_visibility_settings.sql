-- ============================================================================
-- Migration 012: Visibility mode and custom content bucket preferences
-- ============================================================================

ALTER TABLE users
ADD COLUMN IF NOT EXISTS visibility_mode VARCHAR(20) NOT NULL DEFAULT 'public';

ALTER TABLE users
ADD COLUMN IF NOT EXISTS visibility_preferences JSONB NOT NULL DEFAULT '{"photos": true, "videos": true, "reels": true, "purchases": true}'::jsonb;

ALTER TABLE users
DROP CONSTRAINT IF EXISTS seller_must_be_public;

ALTER TABLE users
ADD CONSTRAINT seller_must_be_public
CHECK (
    (account_type = 'seller' AND privacy_profile = 'public' AND visibility_mode = 'public')
    OR
    (account_type = 'consumer')
);

UPDATE users
SET visibility_mode = CASE
        WHEN privacy_profile = 'private' THEN 'private'
        ELSE 'public'
    END,
    visibility_preferences = CASE
        WHEN privacy_profile = 'private' THEN '{"photos": false, "videos": false, "reels": false, "purchases": false}'::jsonb
        ELSE '{"photos": true, "videos": true, "reels": true, "purchases": true}'::jsonb
    END;

COMMENT ON COLUMN users.visibility_mode IS 'Visibility mode: public, private, or custom';
COMMENT ON COLUMN users.visibility_preferences IS 'Custom visibility map for content buckets such as photos, videos, reels, and purchases';