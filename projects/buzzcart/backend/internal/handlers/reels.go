package handlers

import (
	"buzzcart/internal/cache"
	"context"
	"buzzcart/internal/models"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
	"github.com/redis/go-redis/v9"
)

const reelProductsJSONSelect = `
COALESCE(
	jsonb_agg(
		DISTINCT jsonb_build_object(
			'id', p.id,
			'title', p.title,
			'price', p.price,
			'image', COALESCE((
				SELECT pi.image_url
				FROM product_images pi
				WHERE pi.product_id = p.id
				ORDER BY pi.is_primary DESC, pi.display_order ASC, pi.created_at ASC
				LIMIT 1
			), '')
		)
	) FILTER (WHERE p.id IS NOT NULL),
	'[]'::jsonb
) AS products`

const (
	reelListCacheTTL     = 2 * time.Minute
	reelDetailCacheTTL   = 1 * time.Minute
	reelCommentsCacheTTL = 1 * time.Minute
)

var ensureContentCommentsSchemaOnce sync.Once

func ensureContentCommentsSchema(db *sql.DB) error {
	var ensureErr error
	ensureContentCommentsSchemaOnce.Do(func() {
		statements := []string{
			`CREATE TABLE IF NOT EXISTS content_comments (
				id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
				content_id UUID NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
				user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				comment_text TEXT NOT NULL,
				created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
				updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
			)`,
			`CREATE INDEX IF NOT EXISTS idx_content_comments_content_created
				ON content_comments(content_id, created_at DESC)`,
			`CREATE INDEX IF NOT EXISTS idx_content_comments_user
				ON content_comments(user_id)`,
			`CREATE OR REPLACE FUNCTION sync_content_comment_count()
			RETURNS TRIGGER AS $$
			BEGIN
				IF TG_OP = 'INSERT' THEN
					UPDATE content_items
					SET comment_count = comment_count + 1
					WHERE id = NEW.content_id;
					RETURN NEW;
				ELSIF TG_OP = 'DELETE' THEN
					UPDATE content_items
					SET comment_count = GREATEST(comment_count - 1, 0)
					WHERE id = OLD.content_id;
					RETURN OLD;
				END IF;

				RETURN NULL;
			END;
			$$ LANGUAGE plpgsql`,
			`DROP TRIGGER IF EXISTS trigger_sync_content_comment_count ON content_comments`,
			`CREATE TRIGGER trigger_sync_content_comment_count
				AFTER INSERT OR DELETE ON content_comments
				FOR EACH ROW
				EXECUTE FUNCTION sync_content_comment_count()`,
		}

		for _, statement := range statements {
			if _, err := db.Exec(statement); err != nil {
				ensureErr = err
				return
			}
		}
	})

	return ensureErr
}

func validateReelDimensions(width int, height int) error {
	if width <= 0 || height <= 0 {
		return fmt.Errorf("video dimensions are required")
	}
	if height <= width {
		return fmt.Errorf("reels must be vertical")
	}

	const targetRatio = 9.0 / 16.0
	actualRatio := float64(width) / float64(height)
	if math.Abs(actualRatio-targetRatio) > 0.03 {
		return fmt.Errorf("reels must use a 9:16 aspect ratio")
	}

	return nil
}

func uniqueOrderedStrings(values []string) []string {
	if len(values) == 0 {
		return nil
	}

	seen := make(map[string]struct{}, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		trimmed := strings.TrimSpace(value)
		if trimmed == "" {
			continue
		}
		if _, exists := seen[trimmed]; exists {
			continue
		}
		seen[trimmed] = struct{}{}
		result = append(result, trimmed)
	}

	return result
}

func normalizedUUIDString(value string) *string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}

	parsed, err := uuid.Parse(trimmed)
	if err != nil {
		return nil
	}

	normalized := parsed.String()
	return &normalized
}

func reelCacheViewerKey(userID string) string {
	normalized := normalizedUUIDString(userID)
	if normalized == nil {
		return "anon"
	}
	return *normalized
}

func reelListCacheKey(userID string) string {
	return fmt.Sprintf("reels:list:%s", reelCacheViewerKey(userID))
}

func reelDetailCacheKey(reelID string, userID string) string {
	return fmt.Sprintf("reels:detail:%s:%s", reelID, reelCacheViewerKey(userID))
}

func reelCommentsCacheKey(reelID string, userID string) string {
	return fmt.Sprintf("reels:comments:%s:%s", reelID, reelCacheViewerKey(userID))
}

func readCachedJSON[T any](key string, dest *T) bool {
	cached, err := cache.Get(key)
	if err != nil {
		if err != redis.Nil {
			log.Printf("[reels-cache] Redis get failed for %s: %v", key, err)
		}
		return false
	}
	if err := json.Unmarshal([]byte(cached), dest); err != nil {
		log.Printf("[reels-cache] Failed to decode cached JSON for %s: %v", key, err)
		_ = cache.Delete(key)
		return false
	}
	return true
}

func writeCachedJSON(key string, value any, ttl time.Duration) {
	payload, err := json.Marshal(value)
	if err != nil {
		log.Printf("[reels-cache] Failed to encode JSON for %s: %v", key, err)
		return
	}
	if err := cache.Set(key, string(payload), ttl); err != nil {
		log.Printf("[reels-cache] Redis set failed for %s: %v", key, err)
	}
}

func invalidateCachePattern(pattern string) {
	rdb := cache.GetClient()
	if rdb == nil {
		return
	}

	ctx := context.Background()
	iter := rdb.Scan(ctx, 0, pattern, 0).Iterator()
	for iter.Next(ctx) {
		if err := rdb.Del(ctx, iter.Val()).Err(); err != nil {
			log.Printf("[reels-cache] Failed to delete cache key %s: %v", iter.Val(), err)
		}
	}
	if err := iter.Err(); err != nil {
		log.Printf("[reels-cache] Failed to scan pattern %s: %v", pattern, err)
	}
}

func invalidateReelListCache() {
	invalidateCachePattern("reels:list:*")
}

func invalidateReelDetailCache(reelID string) {
	invalidateCachePattern(fmt.Sprintf("reels:detail:%s:*", reelID))
}

func invalidateReelCommentsCache(reelID string) {
	invalidateCachePattern(fmt.Sprintf("reels:comments:%s:*", reelID))
}

func fetchTaggedProducts(tx *sql.Tx, userID string, role models.UserRole, productIDs []string) ([]models.ProductSimple, error) {
	if len(productIDs) == 0 {
		return []models.ProductSimple{}, nil
	}

	rows, err := tx.Query(
		`WITH requested_products AS (
			SELECT product_id, MIN(ord) AS ord
			FROM unnest($1::text[]) WITH ORDINALITY AS requested(product_id, ord)
			GROUP BY product_id
		)
		SELECT
			p.id,
			p.title,
			p.price,
			COALESCE((
				SELECT pi.image_url
				FROM product_images pi
				WHERE pi.product_id = p.id
				ORDER BY pi.is_primary DESC, pi.display_order ASC, pi.created_at ASC
				LIMIT 1
			), '') AS image
		FROM requested_products rp
		JOIN products p ON p.id::text = rp.product_id
		WHERE p.id::text = rp.product_id
		  AND (
			($2 = 'seller' AND p.seller_id = $3::uuid)
			OR (
				$2 <> 'seller'
				AND EXISTS (
					SELECT 1
					FROM order_items oi
					JOIN orders o ON o.id = oi.order_id
					WHERE oi.product_id = p.id
					  AND o.user_id = $3::uuid
					  AND o.status IN ('delivered', 'completed')
				)
			)
		  )
		ORDER BY rp.ord`,
		pq.Array(productIDs),
		string(role),
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	products := make([]models.ProductSimple, 0, len(productIDs))
	for rows.Next() {
		var product models.ProductSimple
		if err := rows.Scan(&product.ID, &product.Title, &product.Price, &product.Image); err != nil {
			return nil, err
		}
		product.Image = readableMediaURL(product.Image)
		products = append(products, product)
	}

	if products == nil {
		products = []models.ProductSimple{}
	}

	return products, rows.Err()
}

func canAccessReel(db *sql.DB, reelID string, userID string) (bool, error) {
	viewerUUID := normalizedUUIDString(userID)
	var creatorID string
	var creatorStatus string
	var privacyProfile string

	err := db.QueryRow(
		`SELECT
			ci.creator_id,
			COALESCE(u.status::text, 'active'),
			LOWER(COALESCE(u.privacy_profile::text, 'public'))
		FROM content_items ci
		JOIN users u ON ci.creator_id = u.id
		WHERE ci.id = $1 AND ci.content_type = 'reel'`,
		reelID,
	).Scan(&creatorID, &creatorStatus, &privacyProfile)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		log.Printf("[canAccessReel] Failed to load reel %s for viewer %q: %v", reelID, userID, err)
		return false, err
	}

	if creatorStatus != "active" {
		return false, nil
	}
	if privacyProfile == "public" {
		return true, nil
	}
	if viewerUUID == nil {
		return false, nil
	}
	if creatorID == *viewerUUID {
		return true, nil
	}

	var followsCreator bool
	err = db.QueryRow(
		`SELECT EXISTS(
			SELECT 1 FROM user_follows
			WHERE follower_id = $1 AND following_id = $2
		)`,
		*viewerUUID,
		creatorID,
	).Scan(&followsCreator)
	if err != nil {
		log.Printf("[canAccessReel] Failed to check follow relationship for reel %s viewer %q: %v", reelID, userID, err)
		return false, err
	}
	return followsCreator, nil
}

func resolveReelContentID(db *sql.DB, reelID string) (string, error) {
	var contentID string
	err := db.QueryRow(
		`SELECT ci.id
		FROM content_items ci
		WHERE ci.id = $1 AND ci.content_type = 'reel'`,
		reelID,
	).Scan(&contentID)
	if err == nil {
		return contentID, nil
	}
	if err != sql.ErrNoRows {
		return "", err
	}

	err = db.QueryRow(
		`SELECT um.content_id
		FROM user_media um
		WHERE um.id = $1
		  AND um.media_type = 'reel'
		  AND um.content_id IS NOT NULL`,
		reelID,
	).Scan(&contentID)
	if err != nil {
		return "", err
	}
	return contentID, nil
}

func insertContentProducts(tx *sql.Tx, contentID string, productIDs []string) error {
	for index, productID := range productIDs {
		if _, err := tx.Exec(
			`INSERT INTO content_products (content_id, product_id, display_order, created_at)
			 VALUES ($1, $2, $3, $4)
			 ON CONFLICT (content_id, product_id) DO UPDATE
			 SET display_order = EXCLUDED.display_order`,
			contentID, productID, index, time.Now(),
		); err != nil {
			return err
		}
	}
	return nil
}

func reelQueryBase(whereClause string) string {
	return `
		SELECT
			ci.id,
			ci.video_url,
			ci.thumbnail_url,
			ci.description,
			ci.view_count,
			ci.like_count,
			ci.comment_count,
			COALESCE(ci.width, 0) AS width,
			COALESCE(ci.height, 0) AS height,
			ci.creator_id,
			u.name,
			u.avatar,
			` + reelProductsJSONSelect + `,
			ci.created_at
		FROM content_items ci
		JOIN users u ON ci.creator_id = u.id
		LEFT JOIN content_products cp ON cp.content_id = ci.id
		LEFT JOIN products p ON p.id = cp.product_id
		` + whereClause + `
		GROUP BY ci.id, u.name, u.avatar
	`
}

func decodeTaggedProducts(productsJSON []byte) []models.ProductSimple {
	products := []models.ProductSimple{}
	_ = json.Unmarshal(productsJSON, &products)
	for i := range products {
		products[i].Image = readableMediaURL(products[i].Image)
	}
	return products
}

func CreateReel(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.ReelCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		req.ProductIDs = uniqueOrderedStrings(req.ProductIDs)

		if err := validateReelDimensions(req.Width, req.Height); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "Reels must use a vertical 9:16 video format",
			})
			return
		}

		var user models.User
		err := db.QueryRow("SELECT id, name, avatar, role FROM users WHERE id = $1", userID).Scan(
			&user.ID, &user.Name, &user.Avatar, &user.Role,
		)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start reel creation"})
			return
		}
		defer tx.Rollback()

		products, err := fetchTaggedProducts(tx, userID, user.Role, req.ProductIDs)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch tagged products"})
			return
		}
		if len(products) != len(req.ProductIDs) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error": "One or more tagged products are not eligible for this account",
			})
			return
		}

		reel := models.Reel{
			ID:            uuid.New().String(),
			URL:           req.URL,
			Thumbnail:     req.Thumbnail,
			Caption:       req.Caption,
			Views:         0,
			Likes:         0,
			CommentCount:  0,
			Width:         req.Width,
			Height:        req.Height,
			CreatorID:     userID,
			CreatorName:   user.Name,
			CreatorAvatar: user.Avatar,
			Products:      products,
			CreatedAt:     time.Now(),
		}

		createdAt := reel.CreatedAt

		_, err = tx.Exec(
			`INSERT INTO content_items (
				id, creator_id, content_type, title, description, video_url, thumbnail_url,
				width, height, view_count, like_count, comment_count, created_at
			) VALUES ($1, $2, 'reel', $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
			reel.ID, reel.CreatorID, reel.Caption, reel.Caption, reel.URL, reel.Thumbnail,
			reel.Width, reel.Height, reel.Views, reel.Likes, reel.CommentCount, createdAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create reel"})
			return
		}

		if err := insertContentProducts(tx, reel.ID, req.ProductIDs); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to tag products on reel"})
			return
		}

		var mediaID string
		err = tx.QueryRow(
			`INSERT INTO user_media (user_id, media_type, media_url, thumbnail_url, caption, content_id)
			 VALUES ($1, 'reel', $2, $3, $4, $5)
			 RETURNING id`,
			userID, reel.URL, reel.Thumbnail, reel.Caption, reel.ID,
		).Scan(&mediaID)
		if err != nil {
			c.Writer.Header().Add("X-Media-Gallery-Error", "Failed to add to media gallery")
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to finalize reel creation"})
			return
		}

		if mediaID != "" {
			thumbnailURL := &reel.Thumbnail
			if _, err := createFeedPostForMedia(
				db,
				userID,
				mediaID,
				reel.Caption,
				"reel",
				reel.URL,
				thumbnailURL,
				createdAt,
			); err != nil {
				c.Writer.Header().Add("X-Feed-Post-Error", "Failed to publish reel to feed")
			}
		}

		invalidateReelListCache()
		invalidateReelDetailCache(reel.ID)
		invalidateReelCommentsCache(reel.ID)

		resolveReelMediaURLs(&reel)
		c.JSON(http.StatusOK, reel)
	}
}

func GetReels(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		cacheKey := reelListCacheKey(userID)

		var cachedReels []models.Reel
		if readCachedJSON(cacheKey, &cachedReels) {
			c.JSON(http.StatusOK, cachedReels)
			return
		}

		normalizedViewerID := ""
		if normalized := normalizedUUIDString(userID); normalized != nil {
			normalizedViewerID = *normalized
		}

		query := `
			SELECT
				ci.id,
				ci.video_url,
				ci.thumbnail_url,
				ci.description,
				ci.view_count,
				ci.like_count,
				ci.comment_count,
				COALESCE(ci.width, 0) AS width,
				COALESCE(ci.height, 0) AS height,
				ci.creator_id,
				u.name,
				u.avatar,
				` + reelProductsJSONSelect + `,
				ci.created_at
			FROM content_items ci
			JOIN users u ON ci.creator_id = u.id
			LEFT JOIN content_products cp ON cp.content_id = ci.id
			LEFT JOIN products p ON p.id = cp.product_id
			LEFT JOIN user_follows viewer_follows_creator
				ON viewer_follows_creator.follower_id = NULLIF($1, '')::uuid
				AND viewer_follows_creator.following_id = ci.creator_id
			LEFT JOIN user_follows creator_follows_viewer
				ON creator_follows_viewer.follower_id = ci.creator_id
				AND creator_follows_viewer.following_id = NULLIF($1, '')::uuid
			WHERE ci.content_type = 'reel'
			  AND COALESCE(u.status::text, 'active') = 'active'
			  AND ($1 = '' OR ci.creator_id <> NULLIF($1, '')::uuid)
			  AND (
				COALESCE(u.privacy_profile::text, 'public') = 'public'
				OR (
					$1 <> ''
					AND viewer_follows_creator.follower_id IS NOT NULL
					AND creator_follows_viewer.follower_id IS NOT NULL
				)
			  )
			GROUP BY ci.id, u.name, u.avatar
			ORDER BY ci.created_at DESC
			LIMIT 20
		`

		rows, err := db.Query(query, normalizedViewerID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reels"})
			return
		}
		defer rows.Close()

		reels := []models.Reel{}
		for rows.Next() {
			var reel models.Reel
			var productsJSON []byte
			err := rows.Scan(
				&reel.ID,
				&reel.URL,
				&reel.Thumbnail,
				&reel.Caption,
				&reel.Views,
				&reel.Likes,
				&reel.CommentCount,
				&reel.Width,
				&reel.Height,
				&reel.CreatorID,
				&reel.CreatorName,
				&reel.CreatorAvatar,
				&productsJSON,
				&reel.CreatedAt,
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reels"})
				return
			}

			reel.Products = decodeTaggedProducts(productsJSON)
			resolveReelMediaURLs(&reel)
			reels = append(reels, reel)
		}

		if err := rows.Err(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reels"})
			return
		}

		writeCachedJSON(cacheKey, reels, reelListCacheTTL)
		c.JSON(http.StatusOK, reels)
	}
}

func GetReel(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")
		userID := c.GetString("user_id")
		resolvedReelID, err := resolveReelContentID(db, reelID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel"})
			return
		}

		canAccess, err := canAccessReel(db, resolvedReelID, userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel"})
			return
		}
		if !canAccess {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		}

		cacheKey := reelDetailCacheKey(resolvedReelID, userID)
		var cachedReel models.Reel
		if readCachedJSON(cacheKey, &cachedReel) {
			_, _ = db.Exec("UPDATE content_items SET view_count = view_count + 1 WHERE id = $1", resolvedReelID)
			c.JSON(http.StatusOK, cachedReel)
			return
		}

		var reel models.Reel
		var productsJSON []byte
		err = db.QueryRow(
			reelQueryBase(`
				WHERE ci.id = $1
				  AND ci.content_type = 'reel'
			`),
			resolvedReelID,
		).Scan(
			&reel.ID,
			&reel.URL,
			&reel.Thumbnail,
			&reel.Caption,
			&reel.Views,
			&reel.Likes,
			&reel.CommentCount,
			&reel.Width,
			&reel.Height,
			&reel.CreatorID,
			&reel.CreatorName,
			&reel.CreatorAvatar,
			&productsJSON,
			&reel.CreatedAt,
		)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel"})
			return
		}

		reel.Products = decodeTaggedProducts(productsJSON)
		resolveReelMediaURLs(&reel)
		writeCachedJSON(cacheKey, reel, reelDetailCacheTTL)

		_, _ = db.Exec("UPDATE content_items SET view_count = view_count + 1 WHERE id = $1", resolvedReelID)

		c.JSON(http.StatusOK, reel)
	}
}

func GetReelComments(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")
		userID := c.GetString("user_id")
		cacheKey := reelCommentsCacheKey(reelID, userID)

		if err := ensureContentCommentsSchema(db); err != nil {
			log.Printf("[GetReelComments] Failed to ensure content_comments schema: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel comments"})
			return
		}
		var reelExists bool
		err := db.QueryRow(
			`SELECT EXISTS(
				SELECT 1 FROM content_items
				WHERE id = $1 AND content_type = 'reel'
			)`,
			reelID,
		).Scan(&reelExists)
		if err != nil {
			log.Printf("[GetReelComments] Reel existence check failed for reel %s: %v", reelID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel comments"})
			return
		}
		if !reelExists {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		}

		var cachedComments []models.ReelComment
		if readCachedJSON(cacheKey, &cachedComments) {
			c.JSON(http.StatusOK, cachedComments)
			return
		}

		rows, err := db.Query(
			`SELECT
				cc.id,
				cc.content_id,
				cc.user_id,
				cc.comment_text,
				cc.created_at,
				cc.updated_at,
				COALESCE(u.name, ''),
				u.avatar
			FROM content_comments cc
			JOIN users u ON u.id = cc.user_id
			WHERE cc.content_id = $1
			ORDER BY
				CASE WHEN $2 <> '' AND cc.user_id::text = $2 THEN 0 ELSE 1 END,
				cc.created_at DESC`,
			reelID, strings.TrimSpace(userID),
		)
		if err != nil {
			log.Printf("[GetReelComments] Query failed for reel %s viewer %q: %v", reelID, userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel comments"})
			return
		}
		defer rows.Close()

		comments := []models.ReelComment{}
		for rows.Next() {
			var comment models.ReelComment
			if err := rows.Scan(
				&comment.ID,
				&comment.ReelID,
				&comment.UserID,
				&comment.CommentText,
				&comment.CreatedAt,
				&comment.UpdatedAt,
				&comment.Username,
				&comment.UserAvatar,
			); err != nil {
				log.Printf("[GetReelComments] Scan failed for reel %s viewer %q: %v", reelID, userID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode reel comments"})
				return
			}
			comment.IsFollowing = false
			comment.IsCurrentUser = strings.TrimSpace(userID) != "" && comment.UserID == strings.TrimSpace(userID)
			comment.UserAvatar = readableMediaURLPtr(comment.UserAvatar)
			comments = append(comments, comment)
		}
		if err := rows.Err(); err != nil {
			log.Printf("[GetReelComments] Rows iteration failed for reel %s viewer %q: %v", reelID, userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch reel comments"})
			return
		}

		writeCachedJSON(cacheKey, comments, reelCommentsCacheTTL)
		c.JSON(http.StatusOK, comments)
	}
}

func CreateReelComment(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")
		userID := c.GetString("user_id")
		viewerUUID := normalizedUUIDString(userID)

		if err := ensureContentCommentsSchema(db); err != nil {
			log.Printf("[CreateReelComment] Failed to ensure content_comments schema: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create comment"})
			return
		}

		if viewerUUID == nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Not authenticated"})
			return
		}

		var req models.ReelCommentCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		commentText := strings.TrimSpace(req.CommentText)
		if commentText == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Comment text is required"})
			return
		}

		var reelExists bool
		err := db.QueryRow(
			`SELECT EXISTS(
				SELECT 1 FROM content_items
				WHERE id = $1 AND content_type = 'reel'
			)`,
			reelID,
		).Scan(&reelExists)
		if err != nil {
			log.Printf("[CreateReelComment] Reel existence check failed for reel %s: %v", reelID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to validate reel"})
			return
		}
		if !reelExists {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		}

		var userExists bool
		if err := db.QueryRow(
			`SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)`,
			*viewerUUID,
		).Scan(&userExists); err != nil {
			log.Printf("[CreateReelComment] Failed to verify user %s: %v", *viewerUUID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to validate comment author"})
			return
		}
		if !userExists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Comment author not found"})
			return
		}

		commentID := uuid.New().String()
		createdAt := time.Now()

		if _, err := db.Exec(
			`INSERT INTO content_comments (id, content_id, user_id, comment_text, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6)`,
			commentID, reelID, *viewerUUID, commentText, createdAt, createdAt,
		); err != nil {
			log.Printf(
				"[CreateReelComment] Failed to create comment %s for reel %s by user %s: %v",
				commentID, reelID, *viewerUUID, err,
			)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create comment"})
			return
		}

		var comment models.ReelComment
		err = db.QueryRow(
			`SELECT
				cc.id,
				cc.content_id,
				cc.user_id,
				cc.comment_text,
				cc.created_at,
				cc.updated_at,
				COALESCE(u.name, ''),
				u.avatar
			FROM content_comments cc
			JOIN users u ON u.id = cc.user_id
			WHERE cc.id = $1`,
			commentID,
		).Scan(
			&comment.ID,
			&comment.ReelID,
			&comment.UserID,
			&comment.CommentText,
			&comment.CreatedAt,
			&comment.UpdatedAt,
			&comment.Username,
			&comment.UserAvatar,
		)
		if err != nil {
			log.Printf("[CreateReelComment] Failed to fetch created comment %s for reel %s: %v", commentID, reelID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch created comment"})
			return
		}

		comment.IsCurrentUser = true
		comment.UserAvatar = readableMediaURLPtr(comment.UserAvatar)

		invalidateReelCommentsCache(reelID)
		invalidateReelListCache()
		invalidateReelDetailCache(reelID)

		c.JSON(http.StatusOK, comment)
	}
}

func LikeReel(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		reelID := c.Param("reel_id")
		userID := c.GetString("user_id")

		canAccess, err := canAccessReel(db, reelID, userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like reel"})
			return
		}
		if !canAccess {
			c.JSON(http.StatusNotFound, gin.H{"error": "Reel not found"})
			return
		}

		_, err = db.Exec("UPDATE content_items SET like_count = like_count + 1 WHERE id = $1 AND content_type = 'reel'", reelID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like reel"})
			return
		}

		invalidateReelListCache()
		invalidateReelDetailCache(reelID)

		c.JSON(http.StatusOK, gin.H{"message": "Reel liked"})
	}
}
