package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
)

var ensureContentLikesSchemaOnce sync.Once

func ensureContentLikesSchema(db *sql.DB) error {
	var ensureErr error
	ensureContentLikesSchemaOnce.Do(func() {
		statements := []string{
			`CREATE TABLE IF NOT EXISTS content_likes (
				content_id UUID NOT NULL REFERENCES content_items(id) ON DELETE CASCADE,
				user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
				created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
				PRIMARY KEY (content_id, user_id)
			)`,
			`CREATE INDEX IF NOT EXISTS idx_content_likes_user
				ON content_likes(user_id)`,
			`CREATE OR REPLACE FUNCTION sync_content_like_count()
			RETURNS TRIGGER AS $$
			BEGIN
				IF TG_OP = 'INSERT' THEN
					UPDATE content_items
					SET like_count = like_count + 1
					WHERE id = NEW.content_id;
					RETURN NEW;
				ELSIF TG_OP = 'DELETE' THEN
					UPDATE content_items
					SET like_count = GREATEST(like_count - 1, 0)
					WHERE id = OLD.content_id;
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
			`UPDATE content_items ci
			SET like_count = (
				SELECT COUNT(*)
				FROM content_likes cl
				WHERE cl.content_id = ci.id
			)
			WHERE ci.content_type IN ('reel', 'video')`,
		}

		for _, statement := range statements {
			if _, err := db.Exec(statement); err != nil {
				ensureErr = err
				return
			}
		}
		invalidateReelListCache()
		invalidateCachePattern("reels:detail:*")
	})

	return ensureErr
}

func likeContent(db *sql.DB, c *gin.Context, contentID string) {
	if err := ensureContentLikesSchema(db); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare likes"})
		return
	}

	userID := c.GetString("user_id")
	if _, err := db.Exec(
		`INSERT INTO content_likes (content_id, user_id)
		 VALUES ($1, $2)
		 ON CONFLICT (content_id, user_id) DO NOTHING`,
		contentID,
		userID,
	); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like content"})
		return
	}

	var likeCount int
	if err := db.QueryRow(
		`SELECT COUNT(*) FROM content_likes WHERE content_id = $1`,
		contentID,
	).Scan(&likeCount); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load like count"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"is_liked": true,
		"likes":    likeCount,
	})
}

func getConnectionLikes(db *sql.DB, c *gin.Context, contentID string) {
	if err := ensureContentLikesSchema(db); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare likes"})
		return
	}

	userID := c.GetString("user_id")
	rows, err := db.Query(
		`SELECT
			u.id,
			u.name,
			u.avatar,
			cl.created_at
		FROM content_likes cl
		JOIN users u ON u.id = cl.user_id
		JOIN user_follows viewer_follows_liker
			ON viewer_follows_liker.follower_id = $2
			AND viewer_follows_liker.following_id = cl.user_id
		JOIN user_follows liker_follows_viewer
			ON liker_follows_viewer.follower_id = cl.user_id
			AND liker_follows_viewer.following_id = $2
		WHERE cl.content_id = $1
		  AND cl.user_id <> $2
		  AND COALESCE(u.status::text, 'active') = 'active'
		ORDER BY cl.created_at DESC`,
		contentID,
		userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch likes"})
		return
	}
	defer rows.Close()

	likes := []models.ContentLikeUser{}
	for rows.Next() {
		var like models.ContentLikeUser
		if err := rows.Scan(
			&like.UserID,
			&like.Username,
			&like.UserAvatar,
			&like.LikedAt,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode likes"})
			return
		}
		like.UserAvatar = readableMediaURLPtr(like.UserAvatar)
		likes = append(likes, like)
	}
	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch likes"})
		return
	}

	c.JSON(http.StatusOK, likes)
}
