-- Migration: Add Review Moderation System
-- Description: Adds moderation status to product reviews for content moderation
-- Date: 2026-02-09

-- ============================================================================
-- PART 1: Create Moderation Status ENUM
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'review_moderation_status') THEN
        CREATE TYPE review_moderation_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
END $$;

COMMENT ON TYPE review_moderation_status IS 'Review moderation status: pending (awaiting review), approved (visible to all), rejected (hidden)';

-- ============================================================================
-- PART 2: Add Moderation Fields to Product Ratings
-- ============================================================================

ALTER TABLE product_ratings
ADD COLUMN IF NOT EXISTS moderation_status review_moderation_status NOT NULL DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS moderation_note TEXT,
ADD COLUMN IF NOT EXISTS moderated_by UUID REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN product_ratings.moderation_status IS 'Review moderation status: pending (default), approved (visible), rejected (hidden)';
COMMENT ON COLUMN product_ratings.moderation_note IS 'Optional note from moderator explaining approval/rejection';
COMMENT ON COLUMN product_ratings.moderated_by IS 'User ID of moderator who approved/rejected the review';
COMMENT ON COLUMN product_ratings.moderated_at IS 'Timestamp when review was moderated';

-- ============================================================================
-- PART 3: Create Index for Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_product_ratings_moderation_status ON product_ratings(moderation_status);
CREATE INDEX IF NOT EXISTS idx_product_ratings_moderated_by ON product_ratings(moderated_by);

-- ============================================================================
-- PART 4: Create View for Approved Reviews
-- ============================================================================

CREATE OR REPLACE VIEW approved_reviews AS
SELECT 
    pr.id,
    pr.product_id,
    pr.user_id,
    pr.rating,
    pr.review_title,
    pr.review_text,
    pr.is_verified_purchase,
    pr.is_private,
    pr.helpful_count,
    pr.moderation_status,
    pr.created_at,
    pr.updated_at,
    u.name as username,
    u.avatar as user_avatar
FROM product_ratings pr
JOIN users u ON pr.user_id = u.id
WHERE pr.moderation_status = 'approved' AND pr.is_private = false;

COMMENT ON VIEW approved_reviews IS 'All approved and public reviews for quick querying';

-- ============================================================================
-- PART 5: Update Existing Reviews (Optional - Set to Approved)
-- ============================================================================

-- Optionally auto-approve all existing reviews created before moderation system
-- Comment out if you want to manually moderate existing reviews

UPDATE product_ratings
SET moderation_status = 'approved',
    moderated_at = CURRENT_TIMESTAMP
WHERE moderation_status = 'pending';

-- ============================================================================
-- ROLLBACK (if needed)
-- ============================================================================

-- To rollback this migration, run the following:
-- DROP VIEW IF EXISTS approved_reviews;
-- DROP INDEX IF EXISTS idx_product_ratings_moderation_status;
-- DROP INDEX IF EXISTS idx_product_ratings_moderated_by;
-- ALTER TABLE product_ratings DROP COLUMN IF EXISTS moderation_status;
-- ALTER TABLE product_ratings DROP COLUMN IF EXISTS moderation_note;
-- ALTER TABLE product_ratings DROP COLUMN IF EXISTS moderated_by;
-- ALTER TABLE product_ratings DROP COLUMN IF EXISTS moderated_at;
-- DROP TYPE IF EXISTS review_moderation_status;