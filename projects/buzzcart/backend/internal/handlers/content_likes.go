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

// EnsureContentLikesSchema creates and normalizes the content_likes table on first call.
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
			`ALTER TABLE content_likes
				ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE
				NOT NULL DEFAULT CURRENT_TIMESTAMP`,
			`CREATE INDEX IF NOT EXISTS idx_content_likes_user ON content_likes(user_id)`,
			`DO $$
			BEGIN
				IF EXISTS (
					SELECT 1
					FROM information_schema.columns
					WHERE table_schema = 'public'
					  AND table_name = 'content_likes'
					  AND column_name = 'liked_at'
				) THEN
					UPDATE content_likes
					SET created_at = liked_at
					WHERE liked_at IS NOT NULL;
				END IF;
			END $$`,
			`DROP TRIGGER IF EXISTS trigger_sync_content_like_count ON content_likes`,
			`DROP TRIGGER IF EXISTS update_content_like_count_trigger ON content_likes`,
			`UPDATE content_items ci
			 SET like_count = (
				SELECT COUNT(*)
				FROM content_likes cl
				WHERE cl.content_id = ci.id
			 )
			 WHERE EXISTS (
				SELECT 1
				FROM content_likes cl
				WHERE cl.content_id = ci.id
			 )
			    OR ci.content_type IN ('reel', 'video')`,
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
// Returns {"is_liked": bool, "likes": int}; the count is sourced from actual
// content_likes rows and mirrored to content_items.like_count in the same transaction.
func toggleLikeContent(db *sql.DB, c *gin.Context, contentID string) {
	if err := ensureContentLikesSchema(db); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare likes"})
		return
	}

	userID := c.GetString("user_id")

	tx, err := db.Begin()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update like"})
		return
	}
	defer tx.Rollback()

	if _, err := tx.Exec(
		`SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2))`,
		contentID,
		userID,
	); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update like"})
		return
	}

	deleteResult, err := tx.Exec(
		`DELETE FROM content_likes WHERE content_id = $1 AND user_id = $2`,
		contentID,
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update like"})
		return
	}
	deleted, err := deleteResult.RowsAffected()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update like"})
		return
	}

	isLiked := deleted == 0
	if isLiked {
		insertResult, err := tx.Exec(
			`INSERT INTO content_likes (content_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			contentID,
			userID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like content"})
			return
		}
		inserted, err := insertResult.RowsAffected()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update like"})
			return
		}
		isLiked = inserted == 1
	}

	var likeCount int
	if err := tx.QueryRow(
		`SELECT COUNT(*) FROM content_likes WHERE content_id = $1`,
		contentID,
	).Scan(&likeCount); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load like count"})
		return
	}

	if _, err := tx.Exec(
		`UPDATE content_items SET like_count = $2 WHERE id = $1`,
		contentID,
		likeCount,
	); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update like count"})
		return
	}

	if err := tx.Commit(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update like"})
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
