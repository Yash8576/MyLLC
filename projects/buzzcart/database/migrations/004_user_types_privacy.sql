-- ============================================================================
-- Migration 004: User Types and Privacy Settings for BuzzCart
-- ============================================================================
-- This migration adds support for:
-- 1. User Types (Seller, Consumer)
-- 2. Privacy Settings (Public, Private)
-- 3. Follow Requests for Private accounts
-- 4. Privacy flags for Orders and Reviews
-- ============================================================================

-- ============================================================================
-- PART 1: Create ENUMs for User Types and Privacy
-- ============================================================================

-- Account Type: Seller or Consumer
CREATE TYPE account_type AS ENUM ('seller', 'consumer');

-- Privacy Profile: Public or Private
CREATE TYPE privacy_profile AS ENUM ('public', 'private');

-- Follow Request Status
CREATE TYPE follow_request_status AS ENUM ('pending', 'accepted', 'rejected');

-- ============================================================================
-- PART 2: Update Users Table
-- ============================================================================

-- Add account_type column (default to consumer for existing users)
ALTER TABLE users 
ADD COLUMN account_type account_type NOT NULL DEFAULT 'consumer';

-- Add privacy_profile column (default to public for existing users)
ALTER TABLE users 
ADD COLUMN privacy_profile privacy_profile NOT NULL DEFAULT 'public';

-- Add constraint: Sellers MUST always be Public
ALTER TABLE users 
ADD CONSTRAINT seller_must_be_public 
CHECK (
    (account_type = 'seller' AND privacy_profile = 'public') 
    OR 
    (account_type = 'consumer')
);

-- Update the existing role constraint to align with account_type
-- (We keep 'role' for backward compatibility, but account_type is the new primary field)
COMMENT ON COLUMN users.role IS 'Legacy field - use account_type instead';
COMMENT ON COLUMN users.account_type IS 'Primary user type: seller (must be public) or consumer (can be public/private)';
COMMENT ON COLUMN users.privacy_profile IS 'Privacy setting: public (visible to all) or private (visible to followers only)';

-- ============================================================================
-- PART 3: Create Follow Requests Table
-- ============================================================================
-- When a user tries to follow a Private account, a request is created
-- For Public accounts, follows are direct (use user_follows table)

CREATE TABLE follow_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    requestee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status follow_request_status NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP WITH TIME ZONE,
    
    -- Prevent duplicate requests
    UNIQUE (requester_id, requestee_id),
    
    -- Cannot request to follow yourself
    CONSTRAINT no_self_follow_request CHECK (requester_id != requestee_id)
);

-- Index for efficient querying
CREATE INDEX idx_follow_requests_requester ON follow_requests(requester_id);
CREATE INDEX idx_follow_requests_requestee ON follow_requests(requestee_id);
CREATE INDEX idx_follow_requests_status ON follow_requests(status);

COMMENT ON TABLE follow_requests IS 'Stores follow requests for private accounts. Public accounts use direct follows in user_follows table.';

-- ============================================================================
-- PART 4: Update Orders Table - Add Privacy Flag
-- ============================================================================
-- Even Private Consumer accounts have PUBLIC purchases by default
-- Users can explicitly mark individual orders as private

ALTER TABLE orders
ADD COLUMN is_private BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN orders.is_private IS 'Privacy flag for order. FALSE (default) = public, TRUE = private. Even private accounts have public orders by default unless explicitly set.';

CREATE INDEX idx_orders_privacy ON orders(is_private);

-- ============================================================================
-- PART 5: Update/Create Reviews Table - Add Privacy Flag
-- ============================================================================
-- Reviews are stored in product_ratings table
-- Add privacy flag there

ALTER TABLE product_ratings
ADD COLUMN is_private BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN product_ratings.is_private IS 'Privacy flag for review. FALSE (default) = public, TRUE = private. Even private accounts have public reviews by default unless explicitly set.';

CREATE INDEX idx_product_ratings_privacy ON product_ratings(is_private);

-- ============================================================================
-- PART 6: Update User Profiles Privacy Mode
-- ============================================================================
-- The existing user_profiles.privacy_mode should sync with users.privacy_profile
-- Add a trigger or app-level logic to keep them in sync (optional)

COMMENT ON COLUMN user_profiles.privacy_mode IS 'Legacy privacy field - synced with users.privacy_profile. Use users.privacy_profile as primary source.';

-- ============================================================================
-- PART 7: Create Helper Views
-- ============================================================================

-- View for Public Users (Sellers + Public Consumers)
CREATE OR REPLACE VIEW public_users AS
SELECT 
    u.id,
    u.email,
    u.username,
    u.account_type,
    u.privacy_profile,
    up.display_name,
    up.bio,
    up.profile_image_url,
    u.created_at
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.privacy_profile = 'public' AND u.is_active = TRUE;

COMMENT ON VIEW public_users IS 'All users with public profiles (all sellers + public consumers)';

-- View for Private Users
CREATE OR REPLACE VIEW private_users AS
SELECT 
    u.id,
    u.email,
    u.username,
    u.account_type,
    u.privacy_profile,
    up.display_name,
    up.bio,
    up.profile_image_url,
    u.created_at
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.privacy_profile = 'private' AND u.account_type = 'consumer' AND u.is_active = TRUE;

COMMENT ON VIEW private_users IS 'All consumer users with private profiles';

-- View for Public Reviews (regardless of user privacy)
CREATE OR REPLACE VIEW public_reviews AS
SELECT 
    pr.*,
    u.username,
    up.display_name,
    up.profile_image_url
FROM product_ratings pr
JOIN users u ON pr.user_id = u.id
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE pr.is_private = FALSE;

COMMENT ON VIEW public_reviews IS 'All public reviews from all users (default for both public and private accounts)';

-- View for Public Orders (for display on public profiles)
CREATE OR REPLACE VIEW public_orders AS
SELECT 
    o.*,
    u.username,
    u.account_type
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.is_private = FALSE;

COMMENT ON VIEW public_orders IS 'All public orders (default for both public and private accounts)';

-- ============================================================================
-- PART 8: Add Indexes for Performance
-- ============================================================================

CREATE INDEX idx_users_account_type ON users(account_type);
CREATE INDEX idx_users_privacy_profile ON users(privacy_profile);
CREATE INDEX idx_users_account_privacy ON users(account_type, privacy_profile);

-- ============================================================================
-- PART 9: Sample Data Migration
-- ============================================================================
-- Convert existing users based on their role
-- This is a safe default migration

-- Update existing sellers to have account_type = 'seller'
UPDATE users 
SET account_type = 'seller', 
    privacy_profile = 'public'
WHERE role = 'seller';

-- Existing consumers remain as 'consumer' with default 'public' privacy
-- (Already set by DEFAULT values)

-- ============================================================================
-- PART 10: Add Function to Validate Follow Logic
-- ============================================================================

-- Function to check if user can view another user's content
CREATE OR REPLACE FUNCTION can_view_user_content(
    viewer_user_id UUID,
    target_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    target_privacy privacy_profile;
    is_following BOOLEAN;
BEGIN
    -- Get target user's privacy setting
    SELECT privacy_profile INTO target_privacy
    FROM users
    WHERE id = target_user_id;
    
    -- If user is public, everyone can view
    IF target_privacy = 'public' THEN
        RETURN TRUE;
    END IF;
    
    -- If user is private, check if viewer is following
    SELECT EXISTS (
        SELECT 1 FROM user_follows
        WHERE follower_id = viewer_user_id
        AND following_id = target_user_id
    ) INTO is_following;
    
    RETURN is_following;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION can_view_user_content IS 'Returns true if viewer_user can see target_user content based on privacy settings and follow status';

-- ============================================================================
-- ROLLBACK SCRIPT (commented out - for reference)
-- ============================================================================
/*
-- Drop function
DROP FUNCTION IF EXISTS can_view_user_content;

-- Drop views
DROP VIEW IF EXISTS public_orders;
DROP VIEW IF EXISTS public_reviews;
DROP VIEW IF EXISTS private_users;
DROP VIEW IF EXISTS public_users;

-- Drop indexes
DROP INDEX IF EXISTS idx_users_account_privacy;
DROP INDEX IF EXISTS idx_users_privacy_profile;
DROP INDEX IF EXISTS idx_users_account_type;
DROP INDEX IF EXISTS idx_product_ratings_privacy;
DROP INDEX IF EXISTS idx_orders_privacy;
DROP INDEX IF EXISTS idx_follow_requests_status;
DROP INDEX IF EXISTS idx_follow_requests_requestee;
DROP INDEX IF EXISTS idx_follow_requests_requester;

-- Remove columns
ALTER TABLE product_ratings DROP COLUMN IF EXISTS is_private;
ALTER TABLE orders DROP COLUMN IF EXISTS is_private;

-- Drop table
DROP TABLE IF EXISTS follow_requests;

-- Remove constraints and columns
ALTER TABLE users DROP CONSTRAINT IF EXISTS seller_must_be_public;
ALTER TABLE users DROP COLUMN IF EXISTS privacy_profile;
ALTER TABLE users DROP COLUMN IF EXISTS account_type;

-- Drop types
DROP TYPE IF EXISTS follow_request_status;
DROP TYPE IF EXISTS privacy_profile;
DROP TYPE IF EXISTS account_type;
*/
