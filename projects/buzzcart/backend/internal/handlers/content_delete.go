package handlers

import (
	"buzzcart/internal/database"
	"buzzcart/internal/storage"
	"context"
	"database/sql"
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func tableExists(ctx context.Context, tx *sql.Tx, tableName string) (bool, error) {
	var exists bool
	err := tx.QueryRowContext(ctx, "SELECT to_regclass($1) IS NOT NULL", tableName).Scan(&exists)
	return exists, err
}

func columnExists(ctx context.Context, tx *sql.Tx, tableName, columnName string) (bool, error) {
	var exists bool
	err := tx.QueryRowContext(
		ctx,
		`SELECT EXISTS(
			SELECT 1
			FROM information_schema.columns
			WHERE table_schema = 'public' AND table_name = $1 AND column_name = $2
		)`,
		tableName,
		columnName,
	).Scan(&exists)
	return exists, err
}

func deletePostsByMediaID(ctx context.Context, tx *sql.Tx, mediaID string) error {
	postsExists, err := tableExists(ctx, tx, "public.posts")
	if err != nil {
		return err
	}
	if !postsExists {
		return nil
	}

	hasMediaIDColumn, err := columnExists(ctx, tx, "posts", "media_id")
	if err != nil {
		return err
	}
	if !hasMediaIDColumn {
		return nil
	}

	userFeedsExists, err := tableExists(ctx, tx, "public.user_feeds")
	if err != nil {
		return err
	}
	if userFeedsExists {
		if _, err := tx.ExecContext(ctx, "DELETE FROM user_feeds WHERE post_id IN (SELECT id FROM posts WHERE media_id = $1)", mediaID); err != nil {
			return err
		}
	}

	postLikesExists, err := tableExists(ctx, tx, "public.post_likes")
	if err != nil {
		return err
	}
	if postLikesExists {
		if _, err := tx.ExecContext(ctx, "DELETE FROM post_likes WHERE post_id IN (SELECT id FROM posts WHERE media_id = $1)", mediaID); err != nil {
			return err
		}
	}

	if _, err := tx.ExecContext(ctx, "DELETE FROM posts WHERE media_id = $1", mediaID); err != nil {
		return err
	}
	return nil
}

func addStorageObject(targets map[string]struct{}, raw string) {
	objectName := extractObjectNameFromMediaURL(raw)
	if strings.TrimSpace(objectName) == "" {
		return
	}
	targets[objectName] = struct{}{}
}

func loadUserMediaCleanupTargets(ctx context.Context, tx *sql.Tx, mediaID, userID string, targets map[string]struct{}) (sql.NullString, error) {
	var contentID sql.NullString
	var mediaURL string
	var thumbnailURL sql.NullString

	err := tx.QueryRowContext(
		ctx,
		`SELECT media_url, thumbnail_url, content_id
		 FROM user_media
		 WHERE id = $1 AND user_id = $2`,
		mediaID,
		userID,
	).Scan(&mediaURL, &thumbnailURL, &contentID)
	if err != nil {
		return sql.NullString{}, err
	}

	addStorageObject(targets, mediaURL)
	if thumbnailURL.Valid {
		addStorageObject(targets, thumbnailURL.String)
	}

	return contentID, nil
}

func loadContentCleanupTargets(ctx context.Context, tx *sql.Tx, contentID, userID string, targets map[string]struct{}) error {
	var videoURL string
	var thumbnailURL sql.NullString

	err := tx.QueryRowContext(
		ctx,
		`SELECT video_url, thumbnail_url
		 FROM content_items
		 WHERE id = $1 AND creator_id = $2`,
		contentID,
		userID,
	).Scan(&videoURL, &thumbnailURL)
	if err != nil {
		return err
	}

	addStorageObject(targets, videoURL)
	if thumbnailURL.Valid {
		addStorageObject(targets, thumbnailURL.String)
	}

	return nil
}

func loadContentLinkedMediaIDs(ctx context.Context, tx *sql.Tx, contentID, userID string) ([]string, error) {
	rows, err := tx.QueryContext(
		ctx,
		`SELECT id
		 FROM user_media
		 WHERE content_id = $1 AND user_id = $2`,
		contentID,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	mediaIDs := []string{}
	for rows.Next() {
		var mediaID string
		if err := rows.Scan(&mediaID); err != nil {
			return nil, err
		}
		mediaIDs = append(mediaIDs, mediaID)
	}
	return mediaIDs, rows.Err()
}

func deleteStorageObjects(targets map[string]struct{}) {
	if len(targets) == 0 {
		return
	}

	storageClient := storage.GetStorageClient()
	for objectName := range targets {
		if err := storageClient.DeleteFile(objectName); err != nil {
			log.Printf("[StorageCleanup] Failed to delete object %q: %v", objectName, err)
		}
	}
}

func DeleteUserMedia(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		mediaID := c.Param("media_id")
		if userID == "" || mediaID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid delete request"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		var ownerID string
		var mediaType string
		var contentID sql.NullString
		var mediaURL string
		var thumbnailURL sql.NullString
		err := db.QueryRowContext(
			ctx,
			"SELECT user_id, media_type, content_id, media_url, thumbnail_url FROM user_media WHERE id = $1",
			mediaID,
		).Scan(&ownerID, &mediaType, &contentID, &mediaURL, &thumbnailURL)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Media not found"})
			return
		}
		if err != nil {
			log.Printf("[DeleteUserMedia] Failed to load media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch media"})
			return
		}
		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		storageTargets := map[string]struct{}{}
		addStorageObject(storageTargets, mediaURL)
		if thumbnailURL.Valid {
			addStorageObject(storageTargets, thumbnailURL.String)
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		if err := deletePostsByMediaID(ctx, tx, mediaID); err != nil {
			log.Printf("[DeleteUserMedia] Failed to remove linked posts for media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
			return
		}

		if contentID.Valid && contentID.String != "" {
			if err := loadContentCleanupTargets(ctx, tx, contentID.String, userID, storageTargets); err != nil && err != sql.ErrNoRows {
				log.Printf("[DeleteUserMedia] Failed to load linked content cleanup targets for %s: %v", contentID.String, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
				return
			}
			if _, err := tx.ExecContext(
				ctx,
				"DELETE FROM content_items WHERE id = $1 AND creator_id = $2",
				contentID.String,
				userID,
			); err != nil {
				log.Printf("[DeleteUserMedia] Failed to remove linked content item %s: %v", contentID.String, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
				return
			}
		}

		result, err := tx.ExecContext(ctx, "DELETE FROM user_media WHERE id = $1 AND user_id = $2", mediaID, userID)
		if err != nil {
			log.Printf("[DeleteUserMedia] Failed to delete media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
			return
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Media not found"})
			return
		}

		if err := tx.Commit(); err != nil {
			log.Printf("[DeleteUserMedia] Failed to commit delete for media %s: %v", mediaID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete media"})
			return
		}

		deleteStorageObjects(storageTargets)

		c.JSON(http.StatusOK, gin.H{
			"message":    "Media deleted",
			"media_id":   mediaID,
			"media_type": mediaType,
		})
	}
}

func DeletePost(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		postID := c.Param("post_id")
		if userID == "" || postID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid delete request"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		var ownerID string
		var mediaID sql.NullString
		var mediaURL sql.NullString
		var thumbnailURL sql.NullString
		err := db.QueryRowContext(
			ctx,
			"SELECT user_id, media_id, media_url, thumbnail_url FROM posts WHERE id = $1",
			postID,
		).Scan(&ownerID, &mediaID, &mediaURL, &thumbnailURL)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
			return
		}
		if err != nil {
			log.Printf("[DeletePost] Failed to fetch post %s: %v", postID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch post"})
			return
		}
		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		storageTargets := map[string]struct{}{}
		if mediaURL.Valid {
			addStorageObject(storageTargets, mediaURL.String)
		}
		if thumbnailURL.Valid {
			addStorageObject(storageTargets, thumbnailURL.String)
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		if mediaID.Valid && mediaID.String != "" {
			contentID, err := loadUserMediaCleanupTargets(ctx, tx, mediaID.String, userID, storageTargets)
			if err != nil && err != sql.ErrNoRows {
				log.Printf("[DeletePost] Failed to load media cleanup targets for post %s: %v", postID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
				return
			}

			if err := deletePostsByMediaID(ctx, tx, mediaID.String); err != nil {
				log.Printf("[DeletePost] Failed to remove linked posts for media %s: %v", mediaID.String, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
				return
			}

			if contentID.Valid && contentID.String != "" {
				if err := loadContentCleanupTargets(ctx, tx, contentID.String, userID, storageTargets); err != nil && err != sql.ErrNoRows {
					log.Printf("[DeletePost] Failed to load content cleanup targets for %s: %v", contentID.String, err)
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
					return
				}
				if _, err := tx.ExecContext(ctx, "DELETE FROM content_items WHERE id = $1 AND creator_id = $2", contentID.String, userID); err != nil {
					log.Printf("[DeletePost] Failed to delete linked content %s: %v", contentID.String, err)
					c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
					return
				}
			}

			if _, err := tx.ExecContext(ctx, "DELETE FROM user_media WHERE id = $1 AND user_id = $2", mediaID.String, userID); err != nil {
				log.Printf("[DeletePost] Failed to delete linked media %s: %v", mediaID.String, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
				return
			}
		} else {
			if _, err := tx.ExecContext(ctx, "DELETE FROM user_feeds WHERE post_id = $1", postID); err != nil {
				log.Printf("[DeletePost] Failed to remove feed rows for post %s: %v", postID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
				return
			}
			if _, err := tx.ExecContext(ctx, "DELETE FROM post_likes WHERE post_id = $1", postID); err != nil {
				log.Printf("[DeletePost] Failed to remove likes for post %s: %v", postID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
				return
			}

			result, err := tx.ExecContext(ctx, "DELETE FROM posts WHERE id = $1 AND user_id = $2", postID, userID)
			if err != nil {
				log.Printf("[DeletePost] Failed to delete post %s: %v", postID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
				return
			}
			rowsAffected, _ := result.RowsAffected()
			if rowsAffected == 0 {
				c.JSON(http.StatusNotFound, gin.H{"error": "Post not found"})
				return
			}
		}

		if err := tx.Commit(); err != nil {
			log.Printf("[DeletePost] Failed to commit delete for post %s: %v", postID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete post"})
			return
		}

		deleteStorageObjects(storageTargets)

		c.JSON(http.StatusOK, gin.H{"message": "Post deleted", "post_id": postID})
	}
}

func DeleteVideo(db *sql.DB) gin.HandlerFunc {
	return deleteContentItemByType(db, "video")
}

func DeleteReel(db *sql.DB) gin.HandlerFunc {
	return deleteContentItemByType(db, "reel")
}

func deleteContentItemByType(db *sql.DB, contentType string) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		contentID := c.Param(contentType + "_id")
		if userID == "" || contentID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid delete request"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		var ownerID string
		storageTargets := map[string]struct{}{}
		err := db.QueryRowContext(
			ctx,
			"SELECT creator_id FROM content_items WHERE id = $1 AND content_type = $2",
			contentID,
			contentType,
		).Scan(&ownerID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Content not found"})
			return
		}
		if err != nil {
			log.Printf("[Delete%s] Failed to fetch content %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch content"})
			return
		}
		if ownerID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Not authorized"})
			return
		}

		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start transaction"})
			return
		}
		defer tx.Rollback()

		if err := loadContentCleanupTargets(ctx, tx, contentID, userID, storageTargets); err != nil && err != sql.ErrNoRows {
			log.Printf("[Delete%s] Failed to load storage cleanup targets for %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}

		linkedMediaIDs, err := loadContentLinkedMediaIDs(ctx, tx, contentID, userID)
		if err != nil {
			log.Printf("[Delete%s] Failed to load linked media IDs for %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}
		for _, mediaID := range linkedMediaIDs {
			if err := deletePostsByMediaID(ctx, tx, mediaID); err != nil {
				log.Printf("[Delete%s] Failed to delete linked posts for media %s: %v", contentType, mediaID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
				return
			}
		}

		if _, err := tx.ExecContext(ctx, "DELETE FROM user_media WHERE content_id = $1 AND user_id = $2", contentID, userID); err != nil {
			log.Printf("[Delete%s] Failed to remove gallery media for %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}

		result, err := tx.ExecContext(
			ctx,
			"DELETE FROM content_items WHERE id = $1 AND creator_id = $2 AND content_type = $3",
			contentID,
			userID,
			contentType,
		)
		if err != nil {
			log.Printf("[Delete%s] Failed to delete content %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}
		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Content not found"})
			return
		}

		if err := tx.Commit(); err != nil {
			log.Printf("[Delete%s] Failed to commit delete for %s: %v", contentType, contentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete content"})
			return
		}

		if contentType == "reel" {
			invalidateReelListCache()
			invalidateReelDetailCache(contentID)
			invalidateReelCommentsCache(contentID)
		}

		deleteStorageObjects(storageTargets)

		c.JSON(http.StatusOK, gin.H{
			"message":    "Content deleted",
			"content_id": contentID,
			"type":       contentType,
		})
	}
}
