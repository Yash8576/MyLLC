package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const videoProductsJSONSelect = `
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

func videoQueryBase(whereClause string) string {
	return `
		SELECT
			ci.id,
			COALESCE(ci.title, '') AS title,
			COALESCE(ci.description, '') AS description,
			COALESCE(ci.video_url, '') AS video_url,
			COALESCE(ci.thumbnail_url, '') AS thumbnail_url,
			COALESCE(ci.duration_seconds, 0) AS duration_seconds,
			COALESCE(ci.view_count, 0) AS view_count,
			COALESCE(ci.like_count, 0) AS like_count,
			COALESCE(ci.comment_count, 0) AS comment_count,
			ci.creator_id,
			COALESCE(u.name, '') AS name,
			u.avatar,
			` + videoProductsJSONSelect + `,
			ci.created_at
		FROM content_items ci
		JOIN users u ON ci.creator_id = u.id
		LEFT JOIN content_products cp ON cp.content_id = ci.id
		LEFT JOIN products p ON p.id = cp.product_id
		` + whereClause + `
		GROUP BY ci.id, u.name, u.avatar
	`
}

func decodeVideo(rows scanner) (models.Video, error) {
	var video models.Video
	var productsJSON []byte
	err := rows.Scan(
		&video.ID,
		&video.Title,
		&video.Description,
		&video.URL,
		&video.Thumbnail,
		&video.Duration,
		&video.Views,
		&video.Likes,
		&video.CommentCount,
		&video.CreatorID,
		&video.CreatorName,
		&video.CreatorAvatar,
		&productsJSON,
		&video.CreatedAt,
	)
	if err != nil {
		return models.Video{}, err
	}

	video.Products = decodeTaggedProducts(productsJSON)
	resolveVideoMediaURLs(&video)
	return video, nil
}

type scanner interface {
	Scan(dest ...any) error
}

func resolveVideoContentID(db *sql.DB, rawID string) (string, error) {
	requestedID := strings.TrimSpace(rawID)
	if requestedID == "" {
		return "", sql.ErrNoRows
	}

	var contentID string
	err := db.QueryRow(
		`SELECT id
		FROM content_items
		WHERE id = $1 AND content_type = 'video'`,
		requestedID,
	).Scan(&contentID)
	if err == nil {
		return contentID, nil
	}
	if err != sql.ErrNoRows {
		return "", err
	}

	err = db.QueryRow(
		`SELECT content_id
		FROM user_media
		WHERE id = $1
		  AND media_type = 'video'
		  AND content_id IS NOT NULL`,
		requestedID,
	).Scan(&contentID)
	if err != nil {
		return "", err
	}

	contentID = strings.TrimSpace(contentID)
	if contentID == "" {
		return "", sql.ErrNoRows
	}

	return contentID, nil
}

func canAccessVideo(db *sql.DB, videoID string, userID string) (bool, error) {
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
		WHERE ci.id = $1 AND ci.content_type = 'video'`,
		videoID,
	).Scan(&creatorID, &creatorStatus, &privacyProfile)
	if err == sql.ErrNoRows {
		return false, nil
	}
	if err != nil {
		log.Printf("[canAccessVideo] Failed to load video %s for viewer %q: %v", videoID, userID, err)
		return false, err
	}

	if creatorStatus != "active" {
		return false, nil
	}
	if viewerUUID != nil && creatorID == *viewerUUID {
		return true, nil
	}
	if privacyProfile == "public" {
		return true, nil
	}
	if viewerUUID == nil {
		return false, nil
	}

	var followsCreator bool
	var creatorFollowsViewer bool
	err = db.QueryRow(
		`SELECT
			EXISTS(
				SELECT 1 FROM user_follows
				WHERE follower_id = $1 AND following_id = $2
			),
			EXISTS(
				SELECT 1 FROM user_follows
				WHERE follower_id = $2 AND following_id = $1
			)`,
		*viewerUUID,
		creatorID,
	).Scan(&followsCreator, &creatorFollowsViewer)
	if err != nil {
		log.Printf("[canAccessVideo] Failed to check follow relationship for video %s viewer %q: %v", videoID, userID, err)
		return false, err
	}

	return followsCreator && creatorFollowsViewer, nil
}

func CreateVideo(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")

		var req models.VideoCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		req.Title = strings.TrimSpace(req.Title)
		req.Description = strings.TrimSpace(req.Description)
		req.URL = strings.TrimSpace(req.URL)
		req.Thumbnail = strings.TrimSpace(req.Thumbnail)
		if req.Title == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Title is required"})
			return
		}
		if req.Description == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Description is required"})
			return
		}
		if req.URL == "" || req.Thumbnail == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Video URL and thumbnail are required"})
			return
		}
		req.ProductIDs = uniqueOrderedStrings(req.ProductIDs)

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
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start video creation"})
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

		video := models.Video{
			ID:            uuid.New().String(),
			Title:         req.Title,
			Description:   req.Description,
			URL:           req.URL,
			Thumbnail:     req.Thumbnail,
			Duration:      req.Duration,
			Views:         0,
			Likes:         0,
			CommentCount:  0,
			CreatorID:     userID,
			CreatorName:   user.Name,
			CreatorAvatar: user.Avatar,
			Products:      products,
			CreatedAt:     time.Now(),
		}

		createdAt := video.CreatedAt
		_, err = tx.Exec(
			`INSERT INTO content_items (
				id, creator_id, content_type, title, description, video_url, thumbnail_url,
				duration_seconds, view_count, like_count, comment_count, created_at
			) VALUES ($1, $2, 'video', $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
			video.ID, video.CreatorID, video.Title, video.Description, video.URL, video.Thumbnail,
			video.Duration, video.Views, video.Likes, video.CommentCount, createdAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create video"})
			return
		}

		if err := insertContentProducts(tx, video.ID, req.ProductIDs); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to tag products on video"})
			return
		}

		var mediaID string
		err = tx.QueryRow(
			`INSERT INTO user_media (user_id, media_type, media_url, thumbnail_url, caption, duration_seconds, content_id) 
			 VALUES ($1, 'video', $2, $3, $4, $5, $6)
			 RETURNING id`,
			userID, video.URL, video.Thumbnail, video.Description, video.Duration, video.ID,
		).Scan(&mediaID)
		if err != nil {
			c.Writer.Header().Add("X-Media-Gallery-Error", "Failed to add to media gallery")
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to finalize video creation"})
			return
		}

		if mediaID != "" {
			thumbnailURL := &video.Thumbnail
			if _, err := createFeedPostForMedia(
				db,
				userID,
				mediaID,
				video.Description,
				"video",
				video.URL,
				thumbnailURL,
				createdAt,
			); err != nil {
				c.Writer.Header().Add("X-Feed-Post-Error", "Failed to publish video to feed")
			}
		}

		resolveVideoMediaURLs(&video)
		c.JSON(http.StatusOK, video)
	}
}

func GetVideos(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		normalizedViewerID := ""
		if normalized := normalizedUUIDString(userID); normalized != nil {
			normalizedViewerID = *normalized
		}

		query := `
			SELECT
				ci.id,
				COALESCE(ci.title, '') AS title,
				COALESCE(ci.description, '') AS description,
				COALESCE(ci.video_url, '') AS video_url,
				COALESCE(ci.thumbnail_url, '') AS thumbnail_url,
				COALESCE(ci.duration_seconds, 0) AS duration_seconds,
				COALESCE(ci.view_count, 0) AS view_count,
				COALESCE(ci.like_count, 0) AS like_count,
				COALESCE(ci.comment_count, 0) AS comment_count,
				ci.creator_id,
				COALESCE(u.name, '') AS name,
				u.avatar,
				` + videoProductsJSONSelect + `,
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
			WHERE ci.content_type = 'video'
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
			log.Printf("[GetVideos] Query failed for viewer %q: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch videos"})
			return
		}
		defer rows.Close()

		videos := []models.Video{}
		for rows.Next() {
			video, err := decodeVideo(rows)
			if err != nil {
				log.Printf("[GetVideos] Failed to decode videos for viewer %q: %v", userID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode videos"})
				return
			}
			videos = append(videos, video)
		}

		if err := rows.Err(); err != nil {
			log.Printf("[GetVideos] Rows iteration failed for viewer %q: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch videos"})
			return
		}

		c.JSON(http.StatusOK, videos)
	}
}

func GetVideo(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		videoID, err := resolveVideoContentID(db, c.Param("video_id"))
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video"})
			return
		}

		canAccess, err := canAccessVideo(db, videoID, userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video"})
			return
		}
		if !canAccess {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}

		row := db.QueryRow(
			videoQueryBase(`
				WHERE ci.id = $1
				  AND ci.content_type = 'video'
			`),
			videoID,
		)

		video, err := decodeVideo(row)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video"})
			return
		}

		_, _ = db.Exec("UPDATE content_items SET view_count = view_count + 1 WHERE id = $1", videoID)
		c.JSON(http.StatusOK, video)
	}
}

func GetVideoComments(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rawVideoID := c.Param("video_id")
		videoID, err := resolveVideoContentID(db, rawVideoID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}
		if err != nil {
			log.Printf("[GetVideoComments] Failed to resolve video id %q: %v", c.Param("video_id"), err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video comments"})
			return
		}
		userID := strings.TrimSpace(c.GetString("user_id"))

		canAccess, err := canAccessVideo(db, videoID, userID)
		if err != nil {
			log.Printf("[GetVideoComments] Failed to authorize video id %q: %v", rawVideoID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video comments"})
			return
		}
		if !canAccess {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}

		if err := ensureContentCommentsSchema(db); err != nil {
			log.Printf("[GetVideoComments] Failed to ensure content_comments schema: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video comments"})
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
			videoID, userID,
		)
		if err != nil {
			log.Printf("[GetVideoComments] Query failed for video %s viewer %q: %v", videoID, userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video comments"})
			return
		}
		defer rows.Close()

		comments := []models.ContentComment{}
		for rows.Next() {
			var comment models.ContentComment
			if err := rows.Scan(
				&comment.ID,
				&comment.ContentID,
				&comment.UserID,
				&comment.CommentText,
				&comment.CreatedAt,
				&comment.UpdatedAt,
				&comment.Username,
				&comment.UserAvatar,
			); err != nil {
				log.Printf("[GetVideoComments] Scan failed for video %s viewer %q: %v", videoID, userID, err)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode video comments"})
				return
			}
			comment.IsCurrentUser = userID != "" && comment.UserID == userID
			comment.UserAvatar = readableMediaURLPtr(comment.UserAvatar)
			comments = append(comments, comment)
		}
		if err := rows.Err(); err != nil {
			log.Printf("[GetVideoComments] Rows iteration failed for video %s viewer %q: %v", videoID, userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch video comments"})
			return
		}

		c.JSON(http.StatusOK, comments)
	}
}

func CreateVideoComment(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		rawVideoID := c.Param("video_id")
		videoID, err := resolveVideoContentID(db, rawVideoID)
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}
		if err != nil {
			log.Printf("[CreateVideoComment] Failed to resolve video id %q: %v", c.Param("video_id"), err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to validate video"})
			return
		}
		userID := c.GetString("user_id")
		viewerUUID := normalizedUUIDString(userID)

		canAccess, err := canAccessVideo(db, videoID, userID)
		if err != nil {
			log.Printf("[CreateVideoComment] Failed to authorize video id %q: %v", rawVideoID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to validate video"})
			return
		}
		if !canAccess {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}

		if err := ensureContentCommentsSchema(db); err != nil {
			log.Printf("[CreateVideoComment] Failed to ensure content_comments schema: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create comment"})
			return
		}
		if viewerUUID == nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Not authenticated"})
			return
		}

		var req models.ContentCommentCreate
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		commentText := strings.TrimSpace(req.CommentText)
		if commentText == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Comment text is required"})
			return
		}

		commentID := uuid.New().String()
		createdAt := time.Now()
		if _, err := db.Exec(
			`INSERT INTO content_comments (id, content_id, user_id, comment_text, created_at, updated_at)
			 VALUES ($1, $2, $3, $4, $5, $6)`,
			commentID, videoID, *viewerUUID, commentText, createdAt, createdAt,
		); err != nil {
			log.Printf(
				"[CreateVideoComment] Failed to create comment %s for video %s by user %s: %v",
				commentID, videoID, *viewerUUID, err,
			)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create comment"})
			return
		}

		var comment models.ContentComment
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
			&comment.ContentID,
			&comment.UserID,
			&comment.CommentText,
			&comment.CreatedAt,
			&comment.UpdatedAt,
			&comment.Username,
			&comment.UserAvatar,
		)
		if err != nil {
			log.Printf("[CreateVideoComment] Failed to fetch created comment %s for video %s: %v", commentID, videoID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch created comment"})
			return
		}

		comment.IsCurrentUser = true
		comment.UserAvatar = readableMediaURLPtr(comment.UserAvatar)
		c.JSON(http.StatusOK, comment)
	}
}

func LikeVideo(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		videoID, err := resolveVideoContentID(db, c.Param("video_id"))
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like video"})
			return
		}

		canAccess, err := canAccessVideo(db, videoID, userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like video"})
			return
		}
		if !canAccess {
			c.JSON(http.StatusNotFound, gin.H{"error": "Video not found"})
			return
		}

		_, err = db.Exec("UPDATE content_items SET like_count = like_count + 1 WHERE id = $1 AND content_type = 'video'", videoID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like video"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Video liked"})
	}
}
