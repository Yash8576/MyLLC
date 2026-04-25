package handlers

import (
	"buzzcart/internal/database"
	"buzzcart/internal/storage"
	"buzzcart/internal/utils"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

var storagePathSanitizer = regexp.MustCompile(`[^a-zA-Z0-9._-]+`)

func sanitizeStorageSegment(raw string, fallback string) string {
	trimmed := strings.TrimSpace(raw)
	trimmed = strings.ReplaceAll(trimmed, "\\", "/")
	trimmed = strings.Trim(trimmed, "/")
	trimmed = storagePathSanitizer.ReplaceAllString(trimmed, "-")
	trimmed = strings.Trim(trimmed, "-")
	if trimmed == "" {
		return fallback
	}
	return trimmed
}

func productStorageKey(c *gin.Context) string {
	raw := strings.TrimSpace(c.Query("product_id"))
	if raw == "" {
		raw = strings.TrimSpace(c.PostForm("product_id"))
	}
	return sanitizeStorageSegment(raw, "unassigned")
}

func buildUserScopedFolder(userID string, baseFolder string, productKey string) string {
	safeUserID := sanitizeStorageSegment(userID, "anonymous")
	safeBaseFolder := sanitizeStorageSegment(baseFolder, "uploads")

	switch safeBaseFolder {
	case "avatars":
		return fmt.Sprintf("users/%s/avatar", safeUserID)
	case "images", "photos", "user-photos":
		return fmt.Sprintf("users/%s/photos", safeUserID)
	case "videos":
		return fmt.Sprintf("users/%s/videos", safeUserID)
	case "reels":
		return fmt.Sprintf("users/%s/reels", safeUserID)
	case "review-images":
		return fmt.Sprintf("users/%s/reviews/images", safeUserID)
	case "product-images", "products":
		return fmt.Sprintf("users/%s/products/%s/images", safeUserID, sanitizeStorageSegment(productKey, "unassigned"))
	case "product-videos":
		return fmt.Sprintf("users/%s/products/%s/videos", safeUserID, sanitizeStorageSegment(productKey, "unassigned"))
	case "product-documents":
		return fmt.Sprintf("users/%s/products/%s/documents", safeUserID, sanitizeStorageSegment(productKey, "unassigned"))
	default:
		return fmt.Sprintf("users/%s/%s", safeUserID, safeBaseFolder)
	}
}

func UploadImageHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		file, header, err := c.Request.FormFile("image")
		if err != nil {
			log.Printf("[UploadImage] FormFile error for user %s: %v (Content-Type=%q)", userID, err, c.Request.Header.Get("Content-Type"))
			c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded: " + err.Error()})
			return
		}
		defer file.Close()

		// Validate image
		if err := utils.ValidateImage(header); err != nil {
			log.Printf("[UploadImage] Validation failed for user %s: %v", userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		folder := buildUserScopedFolder(
			userID,
			c.DefaultQuery("folder", "images"),
			productStorageKey(c),
		)
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(file, header, folder)
		if err != nil {
			log.Printf("[UploadImage] Storage upload failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload file"})
			return
		}

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		var privacyMode string
		err = db.QueryRowContext(ctx, "SELECT privacy_mode FROM user_profiles WHERE user_id = $1", userID).Scan(&privacyMode)
		if err != nil {
			privacyMode = "public"
		}

		contentID := uuid.New().String()
		_, err = db.ExecContext(ctx,
			`INSERT INTO content_items (id, creator_id, content_type, video_url, is_published, created_at, published_at)
			 VALUES ($1, $2, 'photo', $3, TRUE, $4, $5)`,
			contentID, userID, url, time.Now(), time.Now(),
		)
		if err != nil {
			log.Printf("[UploadImage] Database insert failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save to database"})
			return
		}

		var followerCount int
		if privacyMode == "public" {
			db.QueryRowContext(ctx, "SELECT COUNT(*) FROM user_follows WHERE following_id = $1", userID).Scan(&followerCount)
		}

		log.Printf("[UploadImage] Image uploaded successfully for user %s: %s", userID, contentID)
		c.JSON(http.StatusOK, gin.H{
			"success":        true,
			"url":            url,
			"content_id":     contentID,
			"message":        "File uploaded successfully",
			"follower_count": followerCount,
		})
	}
}

// UploadUserPhotoHandler handles user photo uploads with database persistence
// Example endpoint: POST /api/upload/user-photo
func UploadUserPhotoHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		// Debug: log incoming request details
		incomingCT := c.Request.Header.Get("Content-Type")
		log.Printf("[UploadUserPhoto] user=%s Content-Type=%q ContentLength=%d",
			userID, incomingCT, c.Request.ContentLength)

		// Get the file from the form
		file, header, err := c.Request.FormFile("image")
		if err != nil {
			log.Printf("[UploadUserPhoto] FormFile error for user %s: %v (Content-Type was %q)", userID, err, incomingCT)
			c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded: " + err.Error()})
			return
		}
		defer file.Close()

		log.Printf("[UploadUserPhoto] Got file: name=%q size=%d header-ct=%q",
			header.Filename, header.Size, header.Header.Get("Content-Type"))

		// Validate image
		if err := utils.ValidateImage(header); err != nil {
			log.Printf("[UploadUserPhoto] Validation failed for user %s: %v", userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get caption and create_post flag from form data
		caption := c.PostForm("caption")
		createPost := c.DefaultPostForm("create_post", "false") == "true"

		// Upload to cloud storage
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(
			file,
			header,
			buildUserScopedFolder(userID, "user-photos", ""),
		)
		if err != nil {
			log.Printf("[UploadUserPhoto] Storage upload failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload file"})
			return
		}

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		// Save to user_media table
		mediaID := uuid.New().String()
		_, err = db.ExecContext(ctx,
			`INSERT INTO user_media (id, user_id, media_type, media_url, caption) 
			 VALUES ($1, $2, 'photo', $3, $4)`,
			mediaID, userID, url, caption,
		)
		if err != nil {
			log.Printf("[UploadUserPhoto] Database insert failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save photo to database"})
			return
		}

		// Optionally create a post and fan out to followers
		var postID *string
		var followerCount int
		if createPost {
			isPrivate, visibility, visibilityErr := resolvePostVisibilityForBucket(db, userID, contentBucketPhotos)
			if visibilityErr == nil {
				pID := uuid.New().String()
				postID = &pID

				// Create post
				_, err = db.ExecContext(ctx,
					`INSERT INTO posts (id, user_id, media_id, caption, media_type, media_url, is_private, visibility, created_at)
					 VALUES ($1, $2, $3, $4, 'photo', $5, $6, $7, $8)`,
					*postID, userID, mediaID, caption, url, isPrivate, visibility, time.Now(),
				)
				if err == nil {
					// Fan out to followers
					db.QueryRowContext(ctx, "SELECT fanout_post_to_followers($1, $2)", *postID, userID).Scan(&followerCount)
				}
			}
		}

		response := gin.H{
			"success":  true,
			"url":      url,
			"media_id": mediaID,
			"message":  "Photo uploaded successfully",
		}

		if postID != nil {
			response["post_id"] = *postID
			response["follower_count"] = followerCount
			response["post_created"] = true
		}

		c.JSON(http.StatusOK, response)
	}
}

// UploadVideoHandler handles video uploads to cloud storage
// Example endpoint: POST /api/upload/video
func UploadVideoHandler(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Get the file from the form
	file, header, err := c.Request.FormFile("video")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	// Validate video
	if err := utils.ValidateVideo(header); err != nil {
		log.Printf("[UploadVideo] Validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get folder from query param (optional)
	folder := buildUserScopedFolder(
		userID,
		c.DefaultQuery("folder", "videos"),
		productStorageKey(c),
	)

	// Upload to cloud storage
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(file, header, folder)
	if err != nil {
		log.Printf("[UploadVideo] Storage upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload video"})
		return
	}

	log.Printf("[UploadVideo] Video uploaded successfully: %s", url)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "Video uploaded successfully",
	})
}

// UploadProductImageHandler handles product image uploads
// Example endpoint: POST /api/upload/product-image
func UploadProductImageHandler(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	// Get the file from the form
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	// Validate image
	if err := utils.ValidateImage(header); err != nil {
		log.Printf("[UploadProductImage] Validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Upload to cloud storage in products folder
	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(
		file,
		header,
		buildUserScopedFolder(userID, "products", productStorageKey(c)),
	)
	if err != nil {
		log.Printf("[UploadProductImage] Storage upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload product image"})
		return
	}

	log.Printf("[UploadProductImage] Product image uploaded successfully: %s", url)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "Product image uploaded successfully",
	})
}

// UploadProductDocumentHandler handles product PDF uploads.
// Example endpoint: POST /api/upload/product-document
func UploadProductDocumentHandler(c *gin.Context) {
	userID := c.GetString("user_id")
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	file, header, err := c.Request.FormFile("document")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}
	defer file.Close()

	if err := utils.ValidateDocument(header); err != nil {
		log.Printf("[UploadProductDocument] Validation failed: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	storageClient := storage.GetStorageClient()
	url, err := storageClient.UploadFile(
		file,
		header,
		buildUserScopedFolder(userID, "product-documents", productStorageKey(c)),
	)
	if err != nil {
		log.Printf("[UploadProductDocument] Storage upload failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload product document"})
		return
	}

	log.Printf("[UploadProductDocument] Product document uploaded successfully: %s", url)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     url,
		"message": "Product document uploaded successfully",
	})
}

// UploadAvatarHandler handles user avatar uploads
// Example endpoint: POST /api/upload/avatar
func UploadAvatarHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get the file from the form
		file, header, err := c.Request.FormFile("avatar")
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
			return
		}
		defer file.Close()

		// Get user ID from context (set by auth middleware)
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		// Validate avatar
		if err := utils.ValidateAvatar(header); err != nil {
			log.Printf("[UploadAvatar] Validation failed for user %s: %v", userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Upload to cloud storage in avatars folder
		storageClient := storage.GetStorageClient()
		url, err := storageClient.UploadFile(
			file,
			header,
			buildUserScopedFolder(userID, "avatars", ""),
		)
		if err != nil {
			log.Printf("[UploadAvatar] Storage upload failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload avatar"})
			return
		}

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		// Update user avatar URL in database
		_, err = db.ExecContext(ctx, "UPDATE users SET avatar = $1, updated_at = $2 WHERE id = $3", url, time.Now(), userID)
		if err != nil {
			// Try to delete the uploaded file on database error
			_ = storageClient.DeleteFile(url)
			log.Printf("[UploadAvatar] Database update failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user profile"})
			return
		}

		log.Printf("[UploadAvatar] Avatar updated successfully for user %s", userID)
		c.JSON(http.StatusOK, gin.H{
			"success":    true,
			"avatar_url": url,
			"message":    "Avatar updated successfully",
		})
	}
}

// DeleteAvatarHandler removes the current user's avatar from both database and cloud storage.
// Example endpoint: DELETE /api/upload/avatar
func DeleteAvatarHandler(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			return
		}

		ctx, cancel := database.NewContext()
		defer cancel()

		var avatarURL sql.NullString
		err := db.QueryRowContext(ctx, "SELECT avatar FROM users WHERE id = $1", userID).Scan(&avatarURL)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		if err != nil {
			log.Printf("[DeleteAvatar] Failed to fetch avatar for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch current avatar"})
			return
		}

		if avatarURL.Valid && avatarURL.String != "" {
			storageClient := storage.GetStorageClient()
			objectName := extractObjectNameFromMediaURL(avatarURL.String)
			if objectName != "" {
				if err := storageClient.DeleteFile(objectName); err != nil {
					// Keep deletion resilient: if file is already gone, profile image still gets cleared.
					log.Printf("[DeleteAvatar] Failed deleting storage object %q for user %s: %v", objectName, userID, err)
				}
			}
		}

		_, err = db.ExecContext(ctx, "UPDATE users SET avatar = NULL, updated_at = $1 WHERE id = $2", time.Now(), userID)
		if err != nil {
			log.Printf("[DeleteAvatar] Failed to clear avatar in DB for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to clear avatar"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"message": "Avatar deleted successfully",
		})
	}
}

func extractObjectNameFromMediaURL(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return ""
	}

	if !strings.Contains(raw, "://") {
		return strings.TrimPrefix(raw, "/")
	}

	parsedURL, err := url.Parse(raw)
	if err != nil {
		return ""
	}

	trimmedPath := strings.TrimPrefix(parsedURL.Path, "/")
	if trimmedPath == "" {
		return ""
	}

	pathParts := strings.Split(trimmedPath, "/")

	// Firebase URL format: /v0/b/<bucket>/o/<url-encoded-object>
	if len(pathParts) >= 5 && pathParts[0] == "v0" && pathParts[1] == "b" && pathParts[3] == "o" {
		decoded, err := url.QueryUnescape(strings.Join(pathParts[4:], "/"))
		if err == nil {
			return decoded
		}
		return strings.Join(pathParts[4:], "/")
	}

	if len(pathParts) > 1 {
		// Public GCS URL format: /<bucket>/<objectName>
		return strings.Join(pathParts[1:], "/")
	}

	return strings.TrimPrefix(raw, "/")
}

// DeleteFileHandler handles file deletion from cloud storage
// Example endpoint: DELETE /api/upload/:objectName
func DeleteFileHandler(c *gin.Context) {
	objectName := c.Param("objectName")
	if objectName == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Object name is required",
		})
		return
	}

	storageClient := storage.GetStorageClient()
	err := storageClient.DeleteFile(objectName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to delete file: %v", err),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "File deleted successfully",
	})
}

// GetUserMedia retrieves all media for a user's profile gallery
// Example endpoint: GET /api/users/:user_id/media
func GetUserMedia(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.Param("user_id")
		if userID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
			return
		}

		requestingUserID := c.GetString("user_id")
		mediaType := c.Query("type")
		limit := c.DefaultQuery("limit", "50")

		// Create context with timeout
		ctx, cancel := database.NewContext()
		defer cancel()

		var status string
		var visibilityMode string
		var visibilityPreferencesJSON string
		var privacyProfile string
		var err error
		err = db.QueryRowContext(ctx,
			"SELECT COALESCE(status::text, 'active'), COALESCE(privacy_profile::text, 'public'), COALESCE(visibility_mode, 'public'), COALESCE(visibility_preferences::text, '{\"photos\": true, \"videos\": true, \"reels\": true, \"purchases\": true}') FROM users WHERE id = $1",
			userID,
		).Scan(&status, &privacyProfile, &visibilityMode, &visibilityPreferencesJSON)
		if err != nil {
			status = "active"
			privacyProfile = "public"
			visibilityMode = "public"
			visibilityPreferencesJSON = ""
		}

		if requestingUserID != userID {
			if strings.ToLower(status) != "active" {
				c.JSON(http.StatusOK, []gin.H{})
				return
			}
			if strings.ToLower(privacyProfile) == "private" {
				var isFollowing bool
				err = db.QueryRowContext(ctx,
					"SELECT EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $1 AND following_id = $2)",
					requestingUserID, userID,
				).Scan(&isFollowing)
				if err != nil || !isFollowing {
					c.JSON(http.StatusOK, []gin.H{})
					return
				}
			}
		}

		bucket := ""
		switch strings.ToLower(mediaType) {
		case "photo":
			bucket = contentBucketPhotos
		case "video":
			bucket = contentBucketVideos
		case "reel":
			bucket = contentBucketReels
		}

		if bucket != "" && !visibilityBucketAllowed(visibilityMode, visibilityPreferencesJSON, bucket, requestingUserID == userID) {
			c.JSON(http.StatusOK, []gin.H{})
			return
		}
		// Query from user_media table
		query := `
			SELECT um.id, um.content_id, um.media_type, um.media_url, um.thumbnail_url, um.caption, 
			       COALESCE(um.view_count, 0), COALESCE(um.like_count, 0), COALESCE(um.comment_count, 0), um.created_at
			FROM user_media um
			WHERE um.user_id = $1
		`

		args := []interface{}{userID}

		argIndex := len(args) + 1
		if mediaType != "" {
			query += fmt.Sprintf(" AND um.media_type = $%d", argIndex)
			args = append(args, mediaType)
			argIndex++
		}

		query += " ORDER BY um.created_at DESC LIMIT $" + fmt.Sprint(argIndex)
		args = append(args, limit)

		rows, err := db.QueryContext(ctx, query, args...)
		if err != nil {
			log.Printf("[GetUserMedia] Database query failed for user %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch media"})
			return
		}
		defer rows.Close()

		type MediaItem struct {
			ID           string  `json:"id"`
			ContentID    *string `json:"content_id"`
			MediaType    string  `json:"media_type"`
			MediaURL     string  `json:"media_url"`
			ThumbnailURL *string `json:"thumbnail_url"`
			Caption      *string `json:"caption"`
			ViewCount    int     `json:"view_count"`
			LikeCount    int     `json:"like_count"`
			CommentCount int     `json:"comment_count"`
			CreatedAt    string  `json:"created_at"`
		}

		var media []MediaItem
		for rows.Next() {
			var item MediaItem
			var createdAt time.Time
			err := rows.Scan(
				&item.ID, &item.ContentID, &item.MediaType, &item.MediaURL, &item.ThumbnailURL,
				&item.Caption, &item.ViewCount, &item.LikeCount, &item.CommentCount,
				&createdAt,
			)
			if err != nil {
				continue
			}
			item.CreatedAt = createdAt.Format(time.RFC3339)
			media = append(media, item)
		}

		if media == nil {
			media = []MediaItem{}
		}

		log.Printf("[GetUserMedia] Retrieved %d media items for user %s", len(media), userID)
		c.JSON(http.StatusOK, media)
	}
}
