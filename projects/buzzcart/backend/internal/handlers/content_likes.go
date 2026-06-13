package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"log"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
)

var (
	contentLikesOnce sync.Once
	contentLikesErr  error
)

// EnsureContentLikesSchema creates the content_likes table and trigger on first call.
// The error is cached — a startup failure is fatal (schema won't be retried).
func EnsureContentLikesSchema(db *sql.DB) error {
	contentLikesOnce.Do(func() {
		statements := []string{
			`CREATE TABLE IF NOT EXISTS content_likes (
				content_id UUID NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
				user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
				PRIMARY KEY (content_id, user_id)
			)`,
			`CREATE INDEX IF NOT EXISTS idx_content_likes_user ON content_likes(user_id)`,
			`CREATE OR REPLACE FUNCTION sync_content_like_count()
			RETURNS TRIGGER AS $$
			BEGIN
				IF TG_OP = 'INSERT' THEN
					UPDATE content_items SET like_count = like_count + 1 WHERE id = NEW.content_id;
					RETURN NEW;
				ELSIF TG_OP = 'DELETE' THEN
					UPDATE content_items SET like_count = GREATEST(like_count - 1, 0) WHERE id = OLD.content_id;
					RETURN OLD;
				END IF;
				RETURN NULL;
			END;
			$$ LANGUAGE plpgsql`,
			`DROP TRIGGER IF EXISTS trigger_sync_content_like_count ON content_likes`,
			`CREATE TRIGGER trigger_sync_content_like_count
				AFTER INSERT OR DELETE ON content_likes
				FOR EACH ROW
				EXECUTE FUNCTION sync_content_like_count()`,
		}
		for _, stmt := range statements {
			if _, err := db.Exec(stmt); err != nil {
				log.Printf("[content_likes] schema init failed: %v", err)
				contentLikesErr = err
				return
			}
		}
		log.Println("[content_likes] schema ready")
	})
	return contentLikesErr
}

func ensureContentLikesSchema(db *sql.DB) error {
	return EnsureContentLikesSchema(db)
}

// toggleLikeContent likes or unlikes content_id for the authenticated user.
// Returns {"is_liked": bool, "likes": int} sourced from content_items.like_count
// (maintained by DB trigger) so the count stays accurate even for likes that
// pre-date the content_likes table.
func toggleLikeContent(db *sql.DB, c *gin.Context, contentID string) {
	if err := ensureContentLikesSchema(db); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare likes"})
		return
	}

	userID := c.GetString("user_id")

	var isLiked bool
	if err := db.QueryRow(
		`SELECT EXISTS(SELECT 1 FROM content_likes WHERE content_id = $1 AND user_id = $2)`,
		contentID, userID,
	).Scan(&isLiked); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check like status"})
		return
	}

	if isLiked {
		if _, err := db.Exec(
			`DELETE FROM content_likes WHERE content_id = $1 AND user_id = $2`,
			contentID, userID,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unlike content"})
			return
		}
		isLiked = false
	} else {
		if _, err := db.Exec(
			`INSERT INTO content_likes (content_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			contentID, userID,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like content"})
			return
		}
		isLiked = true
	}

	var likeCount int
	if err := db.QueryRow(
		`SELECT COALESCE(like_count, 0) FROM content_items WHERE id = $1`,
		contentID,
	).Scan(&likeCount); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load like count"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"is_liked": isLiked, "likes": likeCount})
}

func getConnectionLikes(db *sql.DB, c *gin.Context, contentID string) {
	if err := ensureContentLikesSchema(db); err != nil {
		log.Printf("[content_likes] getConnectionLikes: schema not ready: %v", err)
		c.JSON(http.StatusOK, []models.ContentLikeUser{})
		return
	}

	userID := c.GetString("user_id")

	// Only query connections (mutual follows) who liked this content.
	// Returns [] when nobody liked it or viewer has no connections — not a 500.
	rows, err := db.Query(
		`SELECT
			u.id,
			u.name,
			u.avatar,
			cl.created_at
		FROM content_likes cl
		JOIN users u ON u.id = cl.user_id
		WHERE cl.content_id = $1
		  AND cl.user_id <> NULLIF($2, '')::uuid
		  AND COALESCE(u.status::text, 'active') = 'active'
		  AND EXISTS(
			SELECT 1 FROM user_follows
			WHERE follower_id = NULLIF($2, '')::uuid
			  AND following_id = cl.user_id
		  )
		  AND EXISTS(
			SELECT 1 FROM user_follows
			WHERE follower_id = cl.user_id
			  AND following_id = NULLIF($2, '')::uuid
		  )
		ORDER BY cl.created_at DESC`,
		contentID,
		userID,
	)
	if err != nil {
		log.Printf("[content_likes] getConnectionLikes query failed content=%s user=%s: %v", contentID, userID, err)
		c.JSON(http.StatusOK, []models.ContentLikeUser{})
		return
	}
	defer rows.Close()

	likes := []models.ContentLikeUser{}
	for rows.Next() {
		var like models.ContentLikeUser
		if err := rows.Scan(&like.UserID, &like.Username, &like.UserAvatar, &like.LikedAt); err != nil {
			log.Printf("[content_likes] getConnectionLikes scan failed: %v", err)
			continue
		}
		like.UserAvatar = readableMediaURLPtr(like.UserAvatar)
		likes = append(likes, like)
	}
	if err := rows.Err(); err != nil {
		log.Printf("[content_likes] getConnectionLikes rows error: %v", err)
	}

	c.JSON(http.StatusOK, likes)
}
