-- ============================================================================
-- Migration 015: App schema compatibility sweep
-- ============================================================================
-- Purpose:
-- Bring an older or partially-migrated local database up to the schema shape
-- expected by the current Go/Dart application without requiring app code
-- changes. This migration:
-- 1. Restores newer users/profile compatibility columns.
-- 2. Restores feed/privacy tables and functions if they are missing.
-- 3. Adds compatibility columns on products for legacy read paths.
-- 4. Adds missing privacy columns used by orders and product reviews.

BEGIN;

-- ============================================================================
-- PART 1: TYPES REQUIRED BY THE APP
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'follow_request_status') THEN
        CREATE TYPE follow_request_status AS ENUM ('pending', 'accepted', 'rejected');
    END IF;
END $$;

-- ============================================================================
-- PART 2: USERS TABLE COMPATIBILITY
-- ============================================================================

ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar VARCHAR(500);
ALTER TABLE users ADD COLUMN IF NOT EXISTS followers_count INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS following_count INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE;

UPDATE users u
SET
    name = COALESCE(
        NULLIF(u.name, ''),
        (
            SELECT NULLIF(up.display_name, '')
            FROM user_profiles up
            WHERE up.user_id = u.id
        ),
        u.username
    ),
    avatar = COALESCE(
        u.avatar,
        (
            SELECT NULLIF(up.profile_image_url, '')
            FROM user_profiles up
            WHERE up.user_id = u.id
        ),
        u.profile_pic_url
    ),
    followers_count = COALESCE((
        SELECT COUNT(*)::INT
        FROM user_follows uf
        WHERE uf.following_id = u.id
    ), 0),
    following_count = COALESCE((
        SELECT COUNT(*)::INT
        FROM user_follows uf
        WHERE uf.follower_id = u.id
    ), 0),
    is_active = CASE
        WHEN u.status IS NULL THEN TRUE
        WHEN u.status::text = 'active' THEN TRUE
        ELSE FALSE
    END;

CREATE INDEX IF NOT EXISTS idx_users_name ON users(name);
CREATE INDEX IF NOT EXISTS idx_users_name_lower ON users(LOWER(name));
CREATE INDEX IF NOT EXISTS idx_users_followers_count ON users(followers_count);

CREATE OR REPLACE FUNCTION sync_user_compat_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.name IS NULL OR BTRIM(NEW.name) = '' THEN
        NEW.name := NEW.username;
    END IF;

    IF NEW.avatar IS NULL AND NEW.profile_pic_url IS NOT NULL THEN
        NEW.avatar := NEW.profile_pic_url;
    ELSIF NEW.profile_pic_url IS NULL AND NEW.avatar IS NOT NULL THEN
        NEW.profile_pic_url := NEW.avatar;
    END IF;

    IF NEW.status IS NULL OR NEW.status::text = 'active' THEN
        NEW.is_active := TRUE;
    ELSE
        NEW.is_active := FALSE;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS users_sync_compat_fields_trigger ON users;
CREATE TRIGGER users_sync_compat_fields_trigger
BEFORE INSERT OR UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION sync_user_compat_fields();

-- ============================================================================
-- PART 3: PRIVACY / FOLLOW REQUESTS
-- ============================================================================

CREATE TABLE IF NOT EXISTS follow_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    requestee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status follow_request_status NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at TIMESTAMP WITH TIME ZONE,
    UNIQUE (requester_id, requestee_id),
    CONSTRAINT no_self_follow_request CHECK (requester_id <> requestee_id)
);

CREATE INDEX IF NOT EXISTS idx_follow_requests_requester ON follow_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_follow_requests_requestee ON follow_requests(requestee_id);
CREATE INDEX IF NOT EXISTS idx_follow_requests_status ON follow_requests(status);

ALTER TABLE product_ratings ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_product_ratings_privacy ON product_ratings(product_id, is_private);
CREATE INDEX IF NOT EXISTS idx_orders_privacy ON orders(user_id, is_private);

CREATE OR REPLACE FUNCTION can_view_user_content(
    viewer_user_id UUID,
    target_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    target_privacy privacy_profile;
    is_following BOOLEAN;
BEGIN
    SELECT privacy_profile INTO target_privacy
    FROM users
    WHERE id = target_user_id;

    IF target_privacy IS NULL OR target_privacy = 'public' THEN
        RETURN TRUE;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM user_follows
        WHERE follower_id = viewer_user_id
          AND following_id = target_user_id
    ) INTO is_following;

    RETURN COALESCE(is_following, FALSE);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW public_users AS
SELECT
    u.id,
    u.email,
    u.username,
    u.account_type,
    u.privacy_profile,
    COALESCE(up.display_name, u.name, u.username) AS display_name,
    COALESCE(up.bio, u.bio) AS bio,
    COALESCE(up.profile_image_url, u.avatar, u.profile_pic_url) AS profile_image_url,
    u.created_at
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.privacy_profile = 'public' AND COALESCE(u.is_active, TRUE) = TRUE;

CREATE OR REPLACE VIEW private_users AS
SELECT
    u.id,
    u.email,
    u.username,
    u.account_type,
    u.privacy_profile,
    COALESCE(up.display_name, u.name, u.username) AS display_name,
    COALESCE(up.bio, u.bio) AS bio,
    COALESCE(up.profile_image_url, u.avatar, u.profile_pic_url) AS profile_image_url,
    u.created_at
FROM users u
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE u.privacy_profile = 'private'
  AND u.account_type = 'consumer'
  AND COALESCE(u.is_active, TRUE) = TRUE;

CREATE OR REPLACE VIEW public_reviews AS
SELECT
    pr.*,
    COALESCE(u.name, u.username) AS username,
    COALESCE(u.avatar, u.profile_pic_url, up.profile_image_url) AS user_avatar
FROM product_ratings pr
JOIN users u ON pr.user_id = u.id
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE pr.is_private = FALSE;

CREATE OR REPLACE VIEW public_orders AS
SELECT
    o.*,
    u.username,
    u.account_type
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.is_private = FALSE;

-- ============================================================================
-- PART 4: POSTS / FEED INFRASTRUCTURE
-- ============================================================================

ALTER TABLE posts ADD COLUMN IF NOT EXISTS media_id UUID;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS caption TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS thumbnail_url VARCHAR(500);
ALTER TABLE posts ADD COLUMN IF NOT EXISTS is_private BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS visibility VARCHAR(20) NOT NULL DEFAULT 'public';
ALTER TABLE posts ADD COLUMN IF NOT EXISTS comment_count INT NOT NULL DEFAULT 0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS engagement_score DOUBLE PRECISION NOT NULL DEFAULT 0.0;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS last_engagement_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_name VARCHAR(255);
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_lat DOUBLE PRECISION;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS location_lng DOUBLE PRECISION;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS tagged_users UUID[];
ALTER TABLE posts ADD COLUMN IF NOT EXISTS hashtags TEXT[];
ALTER TABLE posts ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}'::jsonb;

UPDATE posts p
SET
    caption = COALESCE(p.caption, p.content, ''),
    thumbnail_url = COALESCE(p.thumbnail_url, um.thumbnail_url),
    media_id = COALESCE(
        p.media_id,
        um.id,
        p.id
    ),
    is_private = COALESCE(p.is_private, FALSE),
    visibility = COALESCE(NULLIF(p.visibility, ''), 'public'),
    updated_at = COALESCE(p.updated_at, p.created_at),
    last_engagement_at = COALESCE(p.last_engagement_at, p.created_at)
FROM user_media um
WHERE um.user_id = p.user_id
  AND um.media_url = p.media_url;

UPDATE posts
SET
    caption = COALESCE(caption, content, ''),
    media_id = COALESCE(media_id, id),
    is_private = COALESCE(is_private, FALSE),
    visibility = COALESCE(NULLIF(visibility, ''), 'public'),
    updated_at = COALESCE(updated_at, created_at),
    last_engagement_at = COALESCE(last_engagement_at, created_at);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'valid_posts_visibility'
          AND conrelid = 'posts'::regclass
    ) THEN
        ALTER TABLE posts
        ADD CONSTRAINT valid_posts_visibility
        CHECK (visibility IN ('followers', 'public', 'close_friends', 'private', 'custom'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_media_id ON posts(media_id);
CREATE INDEX IF NOT EXISTS idx_posts_visibility ON posts(visibility, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_engagement ON posts(engagement_score DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_discovery ON posts(visibility, is_private, engagement_score DESC, created_at DESC);

CREATE TABLE IF NOT EXISTS user_feeds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    feed_rank DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    feed_position INT,
    is_seen BOOLEAN NOT NULL DEFAULT FALSE,
    seen_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_user_feeds_user_created ON user_feeds(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_feeds_user_rank ON user_feeds(user_id, feed_rank DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_feeds_post ON user_feeds(post_id);
CREATE INDEX IF NOT EXISTS idx_user_feeds_author ON user_feeds(author_id);

CREATE TABLE IF NOT EXISTS post_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_post_likes_post ON post_likes(post_id);
CREATE INDEX IF NOT EXISTS idx_post_likes_user ON post_likes(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS post_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    like_count INT NOT NULL DEFAULT 0,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post ON post_comments(post_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_comments_user ON post_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_post_comments_parent ON post_comments(parent_comment_id);

CREATE TABLE IF NOT EXISTS post_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    share_type VARCHAR(50) NOT NULL DEFAULT 'external',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_post_shares_post ON post_shares(post_id);
CREATE INDEX IF NOT EXISTS idx_post_shares_user ON post_shares(user_id, created_at DESC);

DO $$
BEGIN
    IF to_regclass('public.likes') IS NOT NULL THEN
        INSERT INTO post_likes (id, post_id, user_id, created_at)
        SELECT l.id, l.post_id, l.user_id, l.created_at
        FROM likes l
        ON CONFLICT (post_id, user_id) DO NOTHING;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION update_posts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS posts_updated_at_trigger ON posts;
CREATE TRIGGER posts_updated_at_trigger
BEFORE UPDATE ON posts
FOR EACH ROW
EXECUTE FUNCTION update_posts_updated_at();

CREATE OR REPLACE FUNCTION increment_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts
    SET like_count = COALESCE(like_count, 0) + 1,
        last_engagement_at = CURRENT_TIMESTAMP
    WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION decrement_post_likes()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts
    SET like_count = GREATEST(COALESCE(like_count, 0) - 1, 0),
        last_engagement_at = CURRENT_TIMESTAMP
    WHERE id = OLD.post_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS post_like_added ON post_likes;
CREATE TRIGGER post_like_added
AFTER INSERT ON post_likes
FOR EACH ROW
EXECUTE FUNCTION increment_post_likes();

DROP TRIGGER IF EXISTS post_like_removed ON post_likes;
CREATE TRIGGER post_like_removed
AFTER DELETE ON post_likes
FOR EACH ROW
EXECUTE FUNCTION decrement_post_likes();

CREATE OR REPLACE FUNCTION increment_post_comments()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_deleted = FALSE THEN
        UPDATE posts
        SET comment_count = COALESCE(comment_count, 0) + 1,
            last_engagement_at = CURRENT_TIMESTAMP
        WHERE id = NEW.post_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS post_comment_added ON post_comments;
CREATE TRIGGER post_comment_added
AFTER INSERT ON post_comments
FOR EACH ROW
EXECUTE FUNCTION increment_post_comments();

CREATE OR REPLACE FUNCTION increment_post_shares()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE posts
    SET share_count = COALESCE(share_count, 0) + 1,
        last_engagement_at = CURRENT_TIMESTAMP
    WHERE id = NEW.post_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS post_share_added ON post_shares;
CREATE TRIGGER post_share_added
AFTER INSERT ON post_shares
FOR EACH ROW
EXECUTE FUNCTION increment_post_shares();

CREATE OR REPLACE FUNCTION calculate_engagement_score(
    p_like_count INT,
    p_comment_count INT,
    p_share_count INT,
    p_created_at TIMESTAMP WITH TIME ZONE,
    p_gravity DOUBLE PRECISION DEFAULT 1.8
) RETURNS DOUBLE PRECISION AS $$
DECLARE
    total_engagement INT;
    hours_since_post DOUBLE PRECISION;
BEGIN
    total_engagement := (COALESCE(p_like_count, 0) * 1)
        + (COALESCE(p_comment_count, 0) * 3)
        + (COALESCE(p_share_count, 0) * 5);
    hours_since_post := EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - p_created_at)) / 3600.0;
    RETURN total_engagement / POWER(hours_since_post + 2, p_gravity);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_all_engagement_scores()
RETURNS void AS $$
BEGIN
    UPDATE posts
    SET engagement_score = calculate_engagement_score(
        COALESCE(like_count, 0),
        COALESCE(comment_count, 0),
        COALESCE(share_count, 0),
        created_at,
        1.8
    )
    WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fanout_post_to_followers(p_post_id UUID, p_author_id UUID)
RETURNS INT AS $$
DECLARE
    follower_count INT;
BEGIN
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

INSERT INTO user_feeds (user_id, post_id, author_id, created_at)
SELECT
    uf.follower_id,
    p.id,
    p.user_id,
    p.created_at
FROM posts p
JOIN user_follows uf ON uf.following_id = p.user_id
WHERE COALESCE(p.is_private, FALSE) = FALSE
ON CONFLICT (user_id, post_id) DO NOTHING;

SELECT update_all_engagement_scores();

CREATE OR REPLACE VIEW public_posts AS
SELECT
    p.*,
    COALESCE(u.name, u.username, '') AS author_name,
    COALESCE(u.avatar, u.profile_pic_url) AS author_avatar,
    COALESCE(u.is_verified, FALSE) AS author_verified
FROM posts p
JOIN users u ON p.user_id = u.id
WHERE p.visibility = 'public'
   OR (p.visibility = 'followers' AND p.is_private = FALSE)
ORDER BY p.engagement_score DESC, p.created_at DESC;

-- ============================================================================
-- PART 5: PRODUCT COMPATIBILITY SNAPSHOTS FOR LEGACY READ PATHS
-- ============================================================================

ALTER TABLE products ADD COLUMN IF NOT EXISTS images TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
ALTER TABLE products ADD COLUMN IF NOT EXISTS category VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS seller_name VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS reviews_count INT NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS views INT NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION sync_product_compat_snapshot(p_product_id UUID)
RETURNS void AS $$
BEGIN
    UPDATE products p
    SET
        images = COALESCE((
            SELECT ARRAY_AGG(pi.image_url ORDER BY pi.display_order)
            FROM product_images pi
            WHERE pi.product_id = p.id
        ), ARRAY[]::TEXT[]),
        category = (
            SELECT c.name
            FROM categories c
            WHERE c.id = p.category_id
        ),
        seller_name = (
            SELECT COALESCE(u.name, u.username, '')
            FROM users u
            WHERE u.id = p.seller_id
        ),
        rating = COALESCE((
            SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::DOUBLE PRECISION
            FROM product_ratings pr
            WHERE pr.product_id = p.id
              AND COALESCE(pr.is_private, FALSE) = FALSE
              AND (
                  NOT EXISTS (
                      SELECT 1
                      FROM information_schema.columns
                      WHERE table_schema = 'public'
                        AND table_name = 'product_ratings'
                        AND column_name = 'moderation_status'
                  )
                  OR pr.moderation_status = 'approved'
              )
        ), 0),
        reviews_count = COALESCE((
            SELECT COUNT(*)
            FROM product_ratings pr
            WHERE pr.product_id = p.id
              AND COALESCE(pr.is_private, FALSE) = FALSE
              AND (
                  NOT EXISTS (
                      SELECT 1
                      FROM information_schema.columns
                      WHERE table_schema = 'public'
                        AND table_name = 'product_ratings'
                        AND column_name = 'moderation_status'
                  )
                  OR pr.moderation_status = 'approved'
              )
        ), 0),
        views = COALESCE((
            SELECT SUM(pa.view_count)::INT
            FROM product_analytics pa
            WHERE pa.product_id = p.id
        ), 0)
    WHERE p.id = p_product_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_product_compat_from_row()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM sync_product_compat_snapshot(COALESCE(NEW.id, OLD.id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_product_compat_from_product_fk()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM sync_product_compat_snapshot(COALESCE(NEW.product_id, OLD.product_id));
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_products_for_updated_user()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET seller_name = COALESCE(NEW.name, NEW.username, '')
    WHERE seller_id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_products_for_updated_category()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE products
    SET category = NEW.name
    WHERE category_id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS products_sync_compat_trigger ON products;
CREATE TRIGGER products_sync_compat_trigger
AFTER INSERT OR UPDATE OF seller_id, category_id ON products
FOR EACH ROW
EXECUTE FUNCTION sync_product_compat_from_row();

DROP TRIGGER IF EXISTS product_images_sync_compat_trigger ON product_images;
CREATE TRIGGER product_images_sync_compat_trigger
AFTER INSERT OR UPDATE OR DELETE ON product_images
FOR EACH ROW
EXECUTE FUNCTION sync_product_compat_from_product_fk();

DROP TRIGGER IF EXISTS product_ratings_sync_compat_trigger ON product_ratings;
CREATE TRIGGER product_ratings_sync_compat_trigger
AFTER INSERT OR UPDATE OR DELETE ON product_ratings
FOR EACH ROW
EXECUTE FUNCTION sync_product_compat_from_product_fk();

DROP TRIGGER IF EXISTS product_analytics_sync_compat_trigger ON product_analytics;
CREATE TRIGGER product_analytics_sync_compat_trigger
AFTER INSERT OR UPDATE OR DELETE ON product_analytics
FOR EACH ROW
EXECUTE FUNCTION sync_product_compat_from_product_fk();

DROP TRIGGER IF EXISTS users_sync_products_compat_trigger ON users;
CREATE TRIGGER users_sync_products_compat_trigger
AFTER UPDATE OF name, username ON users
FOR EACH ROW
EXECUTE FUNCTION sync_products_for_updated_user();

DROP TRIGGER IF EXISTS categories_sync_products_compat_trigger ON categories;
CREATE TRIGGER categories_sync_products_compat_trigger
AFTER UPDATE OF name ON categories
FOR EACH ROW
EXECUTE FUNCTION sync_products_for_updated_category();

UPDATE products p
SET
    images = COALESCE((
        SELECT ARRAY_AGG(pi.image_url ORDER BY pi.display_order)
        FROM product_images pi
        WHERE pi.product_id = p.id
    ), ARRAY[]::TEXT[]),
    category = (
        SELECT c.name
        FROM categories c
        WHERE c.id = p.category_id
    ),
    seller_name = (
        SELECT COALESCE(u.name, u.username, '')
        FROM users u
        WHERE u.id = p.seller_id
    ),
    rating = COALESCE((
        SELECT ROUND(AVG(pr.rating)::NUMERIC, 1)::DOUBLE PRECISION
        FROM product_ratings pr
        WHERE pr.product_id = p.id
          AND COALESCE(pr.is_private, FALSE) = FALSE
          AND pr.moderation_status = 'approved'
    ), 0),
    reviews_count = COALESCE((
        SELECT COUNT(*)
        FROM product_ratings pr
        WHERE pr.product_id = p.id
          AND COALESCE(pr.is_private, FALSE) = FALSE
          AND pr.moderation_status = 'approved'
    ), 0),
    views = COALESCE((
        SELECT SUM(pa.view_count)::INT
        FROM product_analytics pa
        WHERE pa.product_id = p.id
    ), 0);

COMMIT;
