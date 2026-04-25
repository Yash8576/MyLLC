-- ============================================================================
-- Migration 013: Allow seller custom visibility with public profile
-- ============================================================================

ALTER TABLE users
DROP CONSTRAINT IF EXISTS seller_must_be_public;

ALTER TABLE users
ADD CONSTRAINT seller_must_be_public
CHECK (
    (account_type = 'seller' AND privacy_profile = 'public' AND visibility_mode IN ('public', 'custom'))
    OR
    (account_type = 'consumer')
);

COMMENT ON CONSTRAINT seller_must_be_public ON users IS 'Sellers must keep public profile; visibility can be public or custom.';
