-- ============================================================================
-- Migration 014: Make users.role text-backed for app compatibility
-- ============================================================================
-- The application consistently treats role values as strings. Some handlers
-- query users.role with plain COALESCE(role, 'consumer'), which is not
-- compatible with enum-backed storage in all PostgreSQL contexts.
--
-- This migration keeps the same allowed values and business rules while
-- storing users.role as VARCHAR(20) instead of user_role.

BEGIN;

DROP VIEW IF EXISTS verified_sellers;
DROP VIEW IF EXISTS active_users_by_role;

DROP INDEX IF EXISTS idx_users_verified_seller;
DROP INDEX IF EXISTS idx_users_role_status;
DROP INDEX IF EXISTS idx_users_role;

ALTER TABLE users DROP CONSTRAINT IF EXISTS role_matches_account_type;
ALTER TABLE users DROP CONSTRAINT IF EXISTS valid_role_text;

DO $$
DECLARE
    current_udt_name TEXT;
BEGIN
    SELECT c.udt_name
    INTO current_udt_name
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = 'users'
      AND c.column_name = 'role';

    IF current_udt_name = 'user_role' THEN
        ALTER TABLE users ALTER COLUMN role DROP DEFAULT;
        ALTER TABLE users
            ALTER COLUMN role TYPE VARCHAR(20)
            USING role::text;
    END IF;
END $$;

ALTER TABLE users
    ALTER COLUMN role SET DEFAULT 'consumer',
    ALTER COLUMN role SET NOT NULL;

ALTER TABLE users
    ADD CONSTRAINT valid_role_text
    CHECK (role IN ('consumer', 'seller', 'admin'));

ALTER TABLE users
    ADD CONSTRAINT role_matches_account_type
    CHECK (
        (account_type = 'seller' AND role IN ('seller', 'admin'))
        OR
        (account_type = 'consumer' AND role IN ('consumer', 'admin'))
    );

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_role_status ON users(role, status);
CREATE INDEX idx_users_verified_seller ON users(is_verified, role) WHERE role = 'seller';

CREATE OR REPLACE VIEW verified_sellers AS
SELECT
    u.id,
    u.email,
    u.username,
    COALESCE(up.display_name, u.username) AS name,
    u.role,
    u.status,
    u.is_verified,
    u.phone_number,
    up.display_name,
    COALESCE(up.bio, u.bio) AS bio,
    COALESCE(up.profile_image_url, u.profile_pic_url) AS profile_image_url,
    u.created_at
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.role = 'seller'
  AND u.is_verified = TRUE
  AND u.status = 'active';

COMMENT ON VIEW verified_sellers IS 'All verified and active sellers on the platform.';

CREATE OR REPLACE VIEW active_users_by_role AS
SELECT
    role,
    status,
    COUNT(*) AS user_count,
    COUNT(*) FILTER (WHERE is_verified = TRUE) AS verified_count
FROM users
GROUP BY role, status;

COMMENT ON VIEW active_users_by_role IS 'Summary of users grouped by role and status with verification counts.';

COMMIT;
