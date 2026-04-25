-- ============================================================================
-- Migration 005: Enhanced User Fields for BuzzCart
-- ============================================================================
-- This migration adds:
-- 1. User Role field with enum ['consumer', 'seller', 'admin']
-- 2. Account Status field ['active', 'inactive', 'suspended']
-- 3. IsVerified boolean field for seller authentication
-- 4. PhoneNumber optional field
-- ============================================================================

-- ============================================================================
-- PART 1: Create New ENUMs
-- ============================================================================

-- User Role: Consumer, Seller, or Admin
CREATE TYPE user_role AS ENUM ('consumer', 'seller', 'admin');

-- Account Status: Active, Inactive, or Suspended
CREATE TYPE account_status AS ENUM ('active', 'inactive', 'suspended');

-- ============================================================================
-- PART 2: Update Users Table
-- ============================================================================

-- Add role column (syncs with account_type, defaults to consumer)
ALTER TABLE users 
ADD COLUMN role user_role NOT NULL DEFAULT 'consumer';

-- Add status column (defaults to active for new users)
ALTER TABLE users 
ADD COLUMN status account_status NOT NULL DEFAULT 'active';

-- Add is_verified column (defaults to false, used for seller verification)
ALTER TABLE users 
ADD COLUMN is_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- Add phone_number column (optional)
ALTER TABLE users 
ADD COLUMN phone_number VARCHAR(20);

-- ============================================================================
-- PART 3: Add Constraints
-- ============================================================================

-- Ensure role matches account_type
ALTER TABLE users 
ADD CONSTRAINT role_matches_account_type 
CHECK (
    (account_type = 'seller' AND (role = 'seller' OR role = 'admin')) 
    OR 
    (account_type = 'consumer' AND (role = 'consumer' OR role = 'admin'))
);

-- Only admin role can bypass account_type restrictions
COMMENT ON CONSTRAINT role_matches_account_type ON users IS 
'Ensures role aligns with account_type. Admins can have any account_type.';

-- ============================================================================
-- PART 4: Add Indexes for Performance
-- ============================================================================

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_verified ON users(is_verified);
CREATE INDEX idx_users_phone ON users(phone_number) WHERE phone_number IS NOT NULL;

-- Composite index for common queries
CREATE INDEX idx_users_role_status ON users(role, status);
CREATE INDEX idx_users_verified_seller ON users(is_verified, role) WHERE role = 'seller';

-- ============================================================================
-- PART 5: Update Existing Data
-- ============================================================================

-- Sync role with account_type for existing users
UPDATE users 
SET role = 'seller'
WHERE account_type = 'seller';

UPDATE users 
SET role = 'consumer'
WHERE account_type = 'consumer';

-- Set all existing users as active
UPDATE users 
SET status = 'active'
WHERE status IS NULL;

-- ============================================================================
-- PART 6: Add Comments for Documentation
-- ============================================================================

COMMENT ON COLUMN users.role IS 'User role: consumer (default), seller, or admin. Must align with account_type unless admin.';
COMMENT ON COLUMN users.status IS 'Account status: active (can use platform), inactive (disabled by user), suspended (disabled by admin).';
COMMENT ON COLUMN users.is_verified IS 'Verification status. For sellers, indicates business/identity verification. For consumers, email verification.';
COMMENT ON COLUMN users.phone_number IS 'Optional phone number for user contact and verification.';

-- ============================================================================
-- PART 7: Create Helper Views
-- ============================================================================

-- View for verified sellers
CREATE OR REPLACE VIEW verified_sellers AS
SELECT 
    u.id,
    u.email,
    u.username,
    u.name,
    u.role,
    u.status,
    u.is_verified,
    u.phone_number,
    up.display_name,
    up.bio,
    up.profile_image_url,
    u.created_at
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.role = 'seller' 
  AND u.is_verified = TRUE 
  AND u.status = 'active';

COMMENT ON VIEW verified_sellers IS 'All verified and active sellers on the platform.';

-- View for active users by role
CREATE OR REPLACE VIEW active_users_by_role AS
SELECT 
    role,
    status,
    COUNT(*) as user_count,
    COUNT(*) FILTER (WHERE is_verified = TRUE) as verified_count
FROM users
GROUP BY role, status;

COMMENT ON VIEW active_users_by_role IS 'Summary of users grouped by role and status with verification counts.';

-- ============================================================================
-- PART 8: Add Trigger for Role Sync (Optional)
-- ============================================================================

-- Function to keep role and account_type in sync
CREATE OR REPLACE FUNCTION sync_role_with_account_type()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-set role based on account_type if not admin
    IF NEW.role != 'admin' THEN
        IF NEW.account_type = 'seller' THEN
            NEW.role := 'seller';
        ELSIF NEW.account_type = 'consumer' THEN
            NEW.role := 'consumer';
        END IF;
    END IF;
    
    -- Ensure sellers are always public
    IF NEW.account_type = 'seller' THEN
        NEW.privacy_profile := 'public';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to sync role on INSERT or UPDATE
CREATE TRIGGER ensure_role_account_type_sync
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION sync_role_with_account_type();

COMMENT ON TRIGGER ensure_role_account_type_sync ON users IS 
'Automatically syncs role with account_type and enforces seller privacy rules.';

-- ============================================================================
-- PART 9: Sample Queries and Usage Examples
-- ============================================================================

/*
-- Query all verified sellers
SELECT * FROM verified_sellers;

-- Get user summary by role
SELECT * FROM active_users_by_role;

-- Find all suspended users
SELECT id, email, username, role, status 
FROM users 
WHERE status = 'suspended';

-- Find unverified sellers
SELECT id, email, username, phone_number, created_at
FROM users
WHERE role = 'seller' AND is_verified = FALSE
ORDER BY created_at DESC;

-- Verify a seller
UPDATE users 
SET is_verified = TRUE 
WHERE id = 'user-id-here' AND role = 'seller';

-- Suspend a user
UPDATE users 
SET status = 'suspended' 
WHERE id = 'user-id-here';

-- Reactivate a user
UPDATE users 
SET status = 'active' 
WHERE id = 'user-id-here';
*/
