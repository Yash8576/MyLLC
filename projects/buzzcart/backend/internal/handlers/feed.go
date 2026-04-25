package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/lib/pq"
)

func feedTableExists(db *sql.DB, tableName string) bool {
	var exists bool
	if err := db.QueryRow("SELECT to_regclass($1) IS NOT NULL", tableName).Scan(&exists); err != nil {
		return false
	}
	return exists
}

// ============================================================================
// INSTAGRAM-STYLE FEED HANDLERS
// ============================================================================

// GetFollowersFeed returns posts from users that the current user follows
// Uses pre-computed user_feeds table (fan-out on write / push model)
// Supports cursor-based pagination for infinite scroll
func GetFollowersFeed(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication required"})
			return
		}

		// Pagination parameters
		limit := 20
		if l := c.Query("limit"); l != "" {
			if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 50 {
				limit = parsed
			}
		}

		// Cursor-based pagination (decode base64 cursor to get timestamp)
		var cursorTime time.Time
		if cursor := c.Query("cursor"); cursor != "" {
			if decoded, err := base64.StdEncoding.DecodeString(cursor); err == nil {
				if t, err := time.Parse(time.RFC3339Nano, string(decoded)); err == nil {
					cursorTime = t
				}
			}
		}

		// Query pre-computed feed from user_feeds table
		query := `
			SELECT 
				p.id, p.user_id, p.media_id, p.caption, p.media_type, p.media_url, 
				p.thumbnail_url, p.is_private, p.visibility, p.like_count, 
				p.comment_count, p.share_count, p.view_count, p.created_at, p.updated_at,
				u.name as author_name, u.avatar as author_avatar, u.is_verified as author_verified,
				EXISTS(SELECT 1 FROM post_likes WHERE post_id = p.id AND user_id = $1) as is_liked,
				uf.created_at as feed_created_at
			FROM user_feeds uf
			JOIN posts p ON uf.post_id = p.id
			JOIN users u ON p.user_id = u.id
			WHERE uf.user_id = $1
		`
		args := []interface{}{userID}
		argIndex := 2

		if !cursorTime.IsZero() {
			query += fmt.Sprintf(" AND uf.created_at < $%d", argIndex)
			args = append(args, cursorTime)
			argIndex++
		}

		query += " ORDER BY uf.created_at DESC LIMIT $" + strconv.Itoa(argIndex)
		args = append(args, limit+1) // Fetch one extra to check if there are more

		rows, err := db.Query(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch feed"})
			return
		}
		defer rows.Close()

		posts := []models.Post{}
		var lastFeedTime time.Time

		for rows.Next() {
			var post models.Post
			err := rows.Scan(
				&post.ID, &post.UserID, &post.MediaID, &post.Caption, &post.MediaType,
				&post.MediaURL, &post.ThumbnailURL, &post.IsPrivate, &post.Visibility,
				&post.LikeCount, &post.CommentCount, &post.ShareCount, &post.ViewCount,
				&post.CreatedAt, &post.UpdatedAt, &post.AuthorName, &post.AuthorAvatar,
				&post.AuthorVerified, &post.IsLiked, &lastFeedTime,
			)
			if err != nil {
				continue
			}
			post.IsFollowing = true // By definition, in follower feed
			resolvePostMediaURLs(&post)
			posts = append(posts, post)
		}

		// Check if there are more posts
		hasMore := len(posts) > limit
		if hasMore {
			posts = posts[:limit] // Remove the extra item
		}

		// Generate next cursor
		var nextCursor *string
		if hasMore && len(posts) > 0 {
			cursorStr := base64.StdEncoding.EncodeToString([]byte(lastFeedTime.Format(time.RFC3339Nano)))
			nextCursor = &cursorStr
		}

		c.JSON(http.StatusOK, models.FeedResponse{
			Posts:      posts,
			NextCursor: nextCursor,
			HasMore:    hasMore,
		})
	}
}

// GetDiscoveryFeed returns ranked posts from public accounts and non-private users
// Uses pull model with ranking algorithm: Score = Engagement / (Hours + 2)^Gravity
func GetDiscoveryFeed(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id") // Optional authentication

		// Pagination parameters
		limit := 20
		if l := c.Query("limit"); l != "" {
			if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 50 {
				limit = parsed
			}
		}

		// Cursor-based pagination
		var cursorTime time.Time
		if cursor := c.Query("cursor"); cursor != "" {
			if decoded, err := base64.StdEncoding.DecodeString(cursor); err == nil {
				if t, err := time.Parse(time.RFC3339Nano, string(decoded)); err == nil {
					cursorTime = t
				}
			}
		}

		// Discovery query: globally visible media from active public accounts.
		// This version reads from user_media because the live database uses the
		// legacy posts table shape without the newer feed columns.
		includeInteractionColumns := false
		if userID != "" && feedTableExists(db, "public.post_likes") && feedTableExists(db, "public.user_follows") {
			includeInteractionColumns = true
		}

		query := `
			SELECT 
				um.id::text, um.user_id::text, um.id::text as media_id, COALESCE(um.caption, '') as caption, um.media_type::text, um.media_url, 
				um.thumbnail_url, FALSE as is_private, 'public' as visibility, COALESCE(um.like_count, 0) as like_count, 
				COALESCE(um.comment_count, 0) as comment_count, 0 as share_count, COALESCE(um.view_count, 0) as view_count, um.created_at, um.updated_at,
				u.name as author_name, u.avatar as author_avatar, u.is_verified as author_verified,
				COALESCE(
					(COALESCE(um.like_count, 0) + COALESCE(um.comment_count, 0) * 3) / 
					POWER(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - um.created_at)) / 3600.0 + 2, 1.8),
					0
				) as engagement_score
		`

		if includeInteractionColumns {
			query += `,
				EXISTS(SELECT 1 FROM post_likes WHERE post_id = um.id AND user_id = $1) as is_liked,
				EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $1 AND following_id = um.user_id) as is_following
			`
		}

		query += `
			FROM user_media um
			JOIN users u ON um.user_id = u.id
			WHERE COALESCE(u.status::text, 'active') = 'active'
			  AND COALESCE(u.privacy_profile::text, 'public') = 'public'
			  AND um.is_archived = FALSE
			  AND um.media_type IN ('photo', 'video', 'reel')
			  AND (
				LOWER(COALESCE(u.visibility_mode, 'public')) = 'public'
				OR (
					LOWER(COALESCE(u.visibility_mode, 'public')) = 'custom'
					AND CASE um.media_type::text
						WHEN 'photo' THEN COALESCE((u.visibility_preferences ->> 'photos')::boolean, true)
						WHEN 'video' THEN COALESCE((u.visibility_preferences ->> 'videos')::boolean, true)
						WHEN 'reel' THEN COALESCE((u.visibility_preferences ->> 'reels')::boolean, true)
						ELSE true
					END
				)
			  )
		`

		args := []interface{}{}
		argIndex := 1

		if includeInteractionColumns {
			args = append(args, userID)
			argIndex++
		}

		// Exclude posts from users the current user already follows (optional - for pure discovery)
		if userID != "" && c.Query("exclude_following") == "true" {
			query += fmt.Sprintf(" AND um.user_id NOT IN (SELECT following_id FROM user_follows WHERE follower_id = $%d)", argIndex)
			args = append(args, userID)
			argIndex++
		}

		if !cursorTime.IsZero() {
			query += fmt.Sprintf(" AND um.created_at < $%d", argIndex)
			args = append(args, cursorTime)
			argIndex++
		}

		query += " ORDER BY engagement_score DESC, um.created_at DESC LIMIT $" + strconv.Itoa(argIndex)
		args = append(args, limit+1)

		rows, err := db.Query(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch discovery feed"})
			return
		}
		defer rows.Close()

		posts := []models.Post{}
		var lastCreatedAt time.Time

		for rows.Next() {
			var post models.Post
			var engagementScore float64

			scanArgs := []interface{}{
				&post.ID, &post.UserID, &post.MediaID, &post.Caption, &post.MediaType,
				&post.MediaURL, &post.ThumbnailURL, &post.IsPrivate, &post.Visibility,
				&post.LikeCount, &post.CommentCount, &post.ShareCount, &post.ViewCount,
				&post.CreatedAt, &post.UpdatedAt, &post.AuthorName, &post.AuthorAvatar,
				&post.AuthorVerified, &engagementScore,
			}

			if includeInteractionColumns {
				scanArgs = append(scanArgs, &post.IsLiked, &post.IsFollowing)
			}

			err := rows.Scan(scanArgs...)
			if err != nil {
				continue
			}
			lastCreatedAt = post.CreatedAt
			resolvePostMediaURLs(&post)
			posts = append(posts, post)
		}

		hasMore := len(posts) > limit
		if hasMore {
			posts = posts[:limit]
		}

		var nextCursor *string
		if hasMore && len(posts) > 0 {
			cursorStr := base64.StdEncoding.EncodeToString([]byte(lastCreatedAt.Format(time.RFC3339Nano)))
			nextCursor = &cursorStr
		}

		c.JSON(http.StatusOK, models.FeedResponse{
			Posts:      posts,
			NextCursor: nextCursor,
			HasMore:    hasMore,
		})
	}
}

// GetUserPosts returns all posts from a specific user (for profile gallery)
func GetUserPosts(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		currentUserID := c.GetString("user_id") // May be empty if not authenticated
		profileUserID := c.Param("user_id")

		if profileUserID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "User ID required"})
			return
		}

		// Pagination
		limit := 20
		if l := c.Query("limit"); l != "" {
			if parsed, err := strconv.Atoi(l); err == nil && parsed > 0 && parsed <= 100 {
				limit = parsed
			}
		}

		var cursorTime time.Time
		if cursor := c.Query("cursor"); cursor != "" {
			if decoded, err := base64.StdEncoding.DecodeString(cursor); err == nil {
				if t, err := time.Parse(time.RFC3339Nano, string(decoded)); err == nil {
					cursorTime = t
				}
			}
		}

		// Check privacy: can the current user see this profile's posts?
		var targetPrivacy string
		var targetStatus string
		var isFollowing bool
		err := db.QueryRow("SELECT COALESCE(privacy_profile::text, 'public'), COALESCE(status::text, 'active') FROM users WHERE id = $1", profileUserID).Scan(&targetPrivacy, &targetStatus)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		if currentUserID != "" && currentUserID != profileUserID {
			db.QueryRow(
				"SELECT EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $1 AND following_id = $2)",
				currentUserID, profileUserID,
			).Scan(&isFollowing)
		}

		// Privacy check: if private account and not following, return empty
		if targetStatus != "active" && currentUserID != profileUserID {
			c.JSON(http.StatusForbidden, gin.H{"error": "This account is hibernated"})
			return
		}

		if targetPrivacy == "private" && currentUserID != profileUserID && !isFollowing {
			c.JSON(http.StatusForbidden, gin.H{"error": "This account is private"})
			return
		}

		// Fetch user's posts
		query := `
			SELECT 
				p.id, p.user_id, p.media_id, p.caption, p.media_type, p.media_url, 
				p.thumbnail_url, p.is_private, p.visibility, p.like_count, 
				p.comment_count, p.share_count, p.view_count, p.created_at, p.updated_at,
				u.name as author_name, u.avatar as author_avatar, u.is_verified as author_verified
		`

		if currentUserID != "" {
			query += `,
				EXISTS(SELECT 1 FROM post_likes WHERE post_id = p.id AND user_id = $2) as is_liked
			`
		}

		query += `
			FROM posts p
			JOIN users u ON p.user_id = u.id
			WHERE p.user_id = $1
		`

		args := []interface{}{profileUserID}
		argIndex := 2

		if currentUserID != "" {
			args = append(args, currentUserID)
			argIndex++
		}

		if !cursorTime.IsZero() {
			query += fmt.Sprintf(" AND p.created_at < $%d", argIndex)
			args = append(args, cursorTime)
			argIndex++
		}

		query += " ORDER BY p.created_at DESC LIMIT $" + strconv.Itoa(argIndex)
		args = append(args, limit+1)

		rows, err := db.Query(query, args...)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user posts"})
			return
		}
		defer rows.Close()

		posts := []models.Post{}
		var lastCreatedAt time.Time

		for rows.Next() {
			var post models.Post
			scanArgs := []interface{}{
				&post.ID, &post.UserID, &post.MediaID, &post.Caption, &post.MediaType,
				&post.MediaURL, &post.ThumbnailURL, &post.IsPrivate, &post.Visibility,
				&post.LikeCount, &post.CommentCount, &post.ShareCount, &post.ViewCount,
				&post.CreatedAt, &post.UpdatedAt, &post.AuthorName, &post.AuthorAvatar,
				&post.AuthorVerified,
			}

			if currentUserID != "" {
				scanArgs = append(scanArgs, &post.IsLiked)
			}

			err := rows.Scan(scanArgs...)
			if err != nil {
				continue
			}
			lastCreatedAt = post.CreatedAt
			post.IsFollowing = isFollowing || (currentUserID == profileUserID)
			resolvePostMediaURLs(&post)
			posts = append(posts, post)
		}

		hasMore := len(posts) > limit
		if hasMore {
			posts = posts[:limit]
		}

		var nextCursor *string
		if hasMore && len(posts) > 0 {
			cursorStr := base64.StdEncoding.EncodeToString([]byte(lastCreatedAt.Format(time.RFC3339Nano)))
			nextCursor = &cursorStr
		}

		c.JSON(http.StatusOK, models.FeedResponse{
			Posts:      posts,
			NextCursor: nextCursor,
			HasMore:    hasMore,
		})
	}
}

// CreatePost creates a new post and fans it out to followers
func CreatePost(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication required"})
			return
		}

		var input models.PostCreate
		if err := c.ShouldBindJSON(&input); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Get media details from user_media
		var mediaType, mediaURL string
		var thumbnailURL sql.NullString
		err := db.QueryRow(
			"SELECT media_type, media_url, thumbnail_url FROM user_media WHERE id = $1 AND user_id = $2",
			input.MediaID, userID,
		).Scan(&mediaType, &mediaURL, &thumbnailURL)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Media not found or does not belong to you"})
			return
		}

		isPrivate, visibility, err := resolvePostVisibilityForBucket(db, userID, contentBucketForMediaType(mediaType))
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to resolve account visibility"})
			return
		}

		// Create post
		postID := uuid.New().String()
		_, err = db.Exec(
			`INSERT INTO posts (id, user_id, media_id, caption, media_type, media_url, thumbnail_url, is_private, visibility, created_at)
			 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			postID, userID, input.MediaID, input.Caption, mediaType, mediaURL, thumbnailURL, isPrivate, visibility, time.Now(),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create post"})
			return
		}

		// Fan out to followers (asynchronously in production, but sync here for simplicity)
		// This calls the database function fanout_post_to_followers
		var followerCount int
		err = db.QueryRow("SELECT fanout_post_to_followers($1, $2)", postID, userID).Scan(&followerCount)
		if err != nil {
			// Log error but don't fail the request
			fmt.Printf("Fan-out error: %v\n", err)
		}

		c.JSON(http.StatusCreated, gin.H{
			"success":        true,
			"post_id":        postID,
			"follower_count": followerCount,
			"message":        "Post created successfully",
		})
	}
}

// LikePost allows a user to like a post
func LikePost(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication required"})
			return
		}

		postID := c.Param("post_id")
		if postID == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Post ID required"})
			return
		}

		// Check if already liked
		var exists bool
		db.QueryRow("SELECT EXISTS(SELECT 1 FROM post_likes WHERE post_id = $1 AND user_id = $2)", postID, userID).Scan(&exists)

		if exists {
			c.JSON(http.StatusOK, gin.H{"message": "Already liked"})
			return
		}

		// Insert like (trigger will auto-increment post like_count)
		likeID := uuid.New().String()
		_, err := db.Exec(
			"INSERT INTO post_likes (id, post_id, user_id, created_at) VALUES ($1, $2, $3, $4)",
			likeID, postID, userID, time.Now(),
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to like post"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"success": true, "message": "Post liked"})
	}
}

// UnlikePost allows a user to unlike a post
func UnlikePost(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		if userID == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authentication required"})
			return
		}

		postID := c.Param("post_id")

		// Delete like (trigger will auto-decrement post like_count)
		result, err := db.Exec("DELETE FROM post_likes WHERE post_id = $1 AND user_id = $2", postID, userID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unlike post"})
			return
		}

		rowsAffected, _ := result.RowsAffected()
		if rowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Like not found"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"success": true, "message": "Post unliked"})
	}
}

// ============================================================================
// LEGACY FEED HANDLERS (Keep for backward compatibility)
// ============================================================================

func GetFeed(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get videos from content_items
		videoRows, _ := db.Query(
			`SELECT ci.id, ci.title, ci.description, ci.video_url, ci.thumbnail_url, ci.duration_seconds, 
			        ci.view_count, ci.like_count, ci.creator_id, u.name, u.avatar, '[]'::jsonb as products, ci.created_at 
			 FROM content_items ci
			 JOIN users u ON ci.creator_id = u.id
			 WHERE ci.content_type = 'video'
			 ORDER BY ci.created_at DESC LIMIT 20`,
		)
		var videos []models.Video
		if videoRows != nil {
			defer videoRows.Close()
			for videoRows.Next() {
				var video models.Video
				var productsJSON []byte
				videoRows.Scan(
					&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
					&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
					&productsJSON, &video.CreatedAt,
				)
				json.Unmarshal(productsJSON, &video.Products)
				if video.Products == nil {
					video.Products = []models.ProductSimple{}
				}
				resolveVideoMediaURLs(&video)
				videos = append(videos, video)
			}
		}

		// Get reels from content_items
		reelRows, _ := db.Query(
			`SELECT ci.id, ci.video_url, ci.thumbnail_url, ci.description, ci.view_count, ci.like_count, 
			        ci.creator_id, u.name, u.avatar, '[]'::jsonb as products, ci.created_at 
			 FROM content_items ci
			 JOIN users u ON ci.creator_id = u.id
			 WHERE ci.content_type = 'reel'
			 ORDER BY ci.created_at DESC LIMIT 20`,
		)
		var reels []models.Reel
		if reelRows != nil {
			defer reelRows.Close()
			for reelRows.Next() {
				var reel models.Reel
				var productsJSON []byte
				reelRows.Scan(
					&reel.ID, &reel.URL, &reel.Thumbnail, &reel.Caption, &reel.Views, &reel.Likes,
					&reel.CreatorID, &reel.CreatorName, &reel.CreatorAvatar, &productsJSON, &reel.CreatedAt,
				)
				json.Unmarshal(productsJSON, &reel.Products)
				if reel.Products == nil {
					reel.Products = []models.ProductSimple{}
				}
				resolveReelMediaURLs(&reel)
				reels = append(reels, reel)
			}
		}

		if videos == nil {
			videos = []models.Video{}
		}
		if reels == nil {
			reels = []models.Reel{}
		}

		c.JSON(http.StatusOK, gin.H{
			"videos": videos,
			"reels":  reels,
		})
	}
}

func GetDiscover(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get trending videos from content_items
		videoRows, _ := db.Query(
			`SELECT ci.id, ci.title, ci.description, ci.video_url, ci.thumbnail_url, ci.duration_seconds, 
			        ci.view_count, ci.like_count, ci.creator_id, u.name, u.avatar, '[]'::jsonb as products, ci.created_at 
			 FROM content_items ci
			 JOIN users u ON ci.creator_id = u.id
			 WHERE ci.content_type = 'video'
			 ORDER BY ci.view_count DESC LIMIT 20`,
		)
		var videos []models.Video
		if videoRows != nil {
			defer videoRows.Close()
			for videoRows.Next() {
				var video models.Video
				var productsJSON []byte
				videoRows.Scan(
					&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
					&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
					&productsJSON, &video.CreatedAt,
				)
				json.Unmarshal(productsJSON, &video.Products)
				if video.Products == nil {
					video.Products = []models.ProductSimple{}
				}
				resolveVideoMediaURLs(&video)
				videos = append(videos, video)
			}
		}

		// Get trending products
		productRows, _ := db.Query(
			`SELECT id, title, description, price, images, category, tags, seller_id, seller_name, rating, reviews_count, views, created_at 
			 FROM products ORDER BY views DESC LIMIT 20`,
		)
		var products []models.Product
		if productRows != nil {
			defer productRows.Close()
			for productRows.Next() {
				var product models.Product
				productRows.Scan(
					&product.ID, &product.Title, &product.Description, &product.Price, pq.Array(&product.Images),
					&product.Category, pq.Array(&product.Tags), &product.SellerID, &product.SellerName,
					&product.Rating, &product.ReviewsCount, &product.Views, &product.CreatedAt,
				)
				resolveProductMediaURLs(&product)
				products = append(products, product)
			}
		}

		if videos == nil {
			videos = []models.Video{}
		}
		if products == nil {
			products = []models.Product{}
		}

		c.JSON(http.StatusOK, gin.H{
			"videos":   videos,
			"products": products,
		})
	}
}

func Search(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		query := c.Query("q")
		if query == "" {
			c.JSON(http.StatusOK, models.SearchResponse{
				Products: []models.Product{},
				Videos:   []models.Video{},
				Reels:    []models.Reel{},
				Users:    []models.User{},
			})
			return
		}

		// Get current user ID to exclude from search results
		currentUserID := c.GetString("user_id")

		searchPattern := "%" + query + "%"

		// Search products by product name only, using the same projection as the
		// product listing endpoints so search stays compatible with both schemas.
		productQuery := productSelectBase + `
		 AND (
			p.title ILIKE $1
			OR regexp_replace(lower(p.title), '[^a-z0-9]+', '', 'g')
			   LIKE '%' || regexp_replace(lower($1), '[^a-z0-9%]+', '', 'g') || '%'
		 )
		 ORDER BY p.created_at DESC LIMIT 10`
		productRows, productErr := db.Query(productQuery, searchPattern)
		useLegacyProductScan := false
		var products []models.Product
		if productErr != nil {
			legacyQuery := productSelectLegacy + `
			 WHERE (
				p.title ILIKE $1
				OR regexp_replace(lower(p.title), '[^a-z0-9]+', '', 'g')
				   LIKE '%' || regexp_replace(lower($1), '[^a-z0-9%]+', '', 'g') || '%'
			 )
			 ORDER BY p.created_at DESC LIMIT 10`
			productRows, productErr = db.Query(legacyQuery, searchPattern)
			useLegacyProductScan = productErr == nil
		}
		if productRows != nil && productErr == nil {
			defer productRows.Close()
			for productRows.Next() {
				var (
					product models.Product
					scanErr error
				)
				if useLegacyProductScan {
					product, scanErr = scanProductLegacy(productRows)
				} else {
					product, scanErr = scanProduct(productRows)
				}
				if scanErr != nil {
					continue
				}
				products = append(products, product)
			}
		}

		// Search videos from user_media table (case-insensitive caption search)
		videoRows, _ := db.Query(
			`SELECT um.id, COALESCE(um.caption, '') as title, COALESCE(um.caption, '') as description, 
			        um.media_url, COALESCE(um.thumbnail_url, um.media_url) as thumbnail, 
			        COALESCE(um.duration_seconds, 0) as duration, 
			        COALESCE(um.view_count, 0) as views, COALESCE(um.like_count, 0) as likes,
			        um.user_id, u.name as creator_name, u.avatar as creator_avatar,
			        '[]'::jsonb as products, um.created_at
			 FROM user_media um
			 JOIN users u ON um.user_id = u.id
			 WHERE um.media_type = 'video' AND (um.caption ILIKE $1)
			 ORDER BY um.created_at DESC LIMIT 10`,
			searchPattern,
		)
		var videos []models.Video
		if videoRows != nil {
			defer videoRows.Close()
			for videoRows.Next() {
				var video models.Video
				var productsJSON []byte
				videoRows.Scan(
					&video.ID, &video.Title, &video.Description, &video.URL, &video.Thumbnail, &video.Duration,
					&video.Views, &video.Likes, &video.CreatorID, &video.CreatorName, &video.CreatorAvatar,
					&productsJSON, &video.CreatedAt,
				)
				json.Unmarshal(productsJSON, &video.Products)
				if video.Products == nil {
					video.Products = []models.ProductSimple{}
				}
				resolveVideoMediaURLs(&video)
				videos = append(videos, video)
			}
		}

		// Search reels from user_media table (case-insensitive caption search)
		reelRows, _ := db.Query(
			`SELECT um.id, um.media_url, COALESCE(um.thumbnail_url, um.media_url) as thumbnail, 
			        COALESCE(um.caption, '') as caption, 
			        COALESCE(um.view_count, 0) as views, COALESCE(um.like_count, 0) as likes,
			        um.user_id, u.name as creator_name, u.avatar as creator_avatar,
			        '[]'::jsonb as products, um.created_at
			 FROM user_media um
			 JOIN users u ON um.user_id = u.id
			 WHERE um.media_type = 'reel' AND (um.caption ILIKE $1)
			 ORDER BY um.created_at DESC LIMIT 10`,
			searchPattern,
		)
		var reels []models.Reel
		if reelRows != nil {
			defer reelRows.Close()
			for reelRows.Next() {
				var reel models.Reel
				var productsJSON []byte
				reelRows.Scan(
					&reel.ID, &reel.URL, &reel.Thumbnail, &reel.Caption, &reel.Views, &reel.Likes,
					&reel.CreatorID, &reel.CreatorName, &reel.CreatorAvatar, &productsJSON, &reel.CreatedAt,
				)
				json.Unmarshal(productsJSON, &reel.Products)
				if reel.Products == nil {
					reel.Products = []models.ProductSimple{}
				}
				resolveReelMediaURLs(&reel)
				reels = append(reels, reel)
			}
		}

		// Search users by display name only.
		// Exclude the current logged-in user from results (if authenticated)
		var userRows *sql.Rows
		var err error
		if currentUserID != "" {
			userRows, err = db.Query(
				`SELECT id, name, email, avatar, bio, followers_count, following_count, created_at 
				 FROM users 
				 WHERE name ILIKE $1
				    AND id != $2
				 LIMIT 10`,
				searchPattern, currentUserID,
			)
		} else {
			userRows, err = db.Query(
				`SELECT id, name, email, avatar, bio, followers_count, following_count, created_at 
				 FROM users 
				 WHERE name ILIKE $1
				 LIMIT 10`,
				searchPattern,
			)
		}

		var users []models.User
		if userRows != nil && err == nil {
			defer userRows.Close()
			for userRows.Next() {
				var user models.User
				userRows.Scan(
					&user.ID, &user.Name, &user.Email, &user.Avatar, &user.Bio,
					&user.FollowersCount, &user.FollowingCount, &user.CreatedAt,
				)
				resolveUserMediaURLs(&user)
				users = append(users, user)
			}
		}

		if products == nil {
			products = []models.Product{}
		}
		if videos == nil {
			videos = []models.Video{}
		}
		if reels == nil {
			reels = []models.Reel{}
		}
		if users == nil {
			users = []models.User{}
		}

		c.JSON(http.StatusOK, models.SearchResponse{
			Products: products,
			Videos:   videos,
			Reels:    reels,
			Users:    users,
		})
	}
}
