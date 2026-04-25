package handlers

import (
	"database/sql"
	"fmt"
	"net/http"

	"buzzcart/internal/models"

	"github.com/gin-gonic/gin"
)

// Example handlers showing privacy implementation

// ============================================================================
// USER REGISTRATION WITH ACCOUNT TYPE & PRIVACY
// ============================================================================

func RegisterUser(c *gin.Context) {
	var req models.UserCreate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate business rules
	if err := req.Validate(); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Create user in database
	// The database constraint ensures sellers can't be private
	user, err := createUser(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"user":    user,
		"message": "User registered successfully",
	})
}

// ============================================================================
// GET USER PROFILE (with Privacy Check)
// ============================================================================

func GetUserProfile(c *gin.Context) {
	targetUserID := c.Param("userId")
	viewerID := getUserIDFromContext(c) // From JWT token

	// Query user with privacy check
	query := `
		SELECT 
			u.id, u.email, u.username, u.account_type, u.privacy_profile,
			up.display_name, up.bio, up.profile_image_url,
			(SELECT COUNT(*) FROM user_follows WHERE following_id = u.id) as followers_count,
			(SELECT COUNT(*) FROM user_follows WHERE follower_id = u.id) as following_count
		FROM users u
		LEFT JOIN user_profiles up ON u.id = up.user_id
		WHERE u.id = $1 AND u.is_active = TRUE
	`

	var user models.User
	err := db.QueryRow(query, targetUserID).Scan(
		&user.ID, &user.Email, &user.Name, &user.AccountType, &user.PrivacyProfile,
		&user.Bio, &user.Avatar, &user.FollowersCount, &user.FollowingCount,
	)

	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	// Check privacy
	if user.PrivacyProfile == models.PrivacyPrivate && targetUserID != viewerID {
		// Check if viewer is following
		isFollowing, err := checkIfFollowing(viewerID, targetUserID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}

		if !isFollowing {
			// Return limited profile
			c.JSON(http.StatusOK, gin.H{
				"id":              user.ID,
				"name":            user.Name,
				"avatar":          user.Avatar,
				"account_type":    user.AccountType,
				"privacy_profile": user.PrivacyProfile,
				"is_private":      true,
				"message":         "This account is private. Follow to see their profile.",
			})
			return
		}
	}

	// Return full profile
	c.JSON(http.StatusOK, user)
}

// ============================================================================
// GET USER CONTENT (Videos/Reels) with Privacy Check
// ============================================================================

func GetUserContent(c *gin.Context) {
	targetUserID := c.Param("userId")
	contentType := c.Query("type") // "video" or "reel"
	viewerID := getUserIDFromContext(c)

	// Use the database function to check if viewer can see content
	var canView bool
	err := db.QueryRow(
		"SELECT can_view_user_content($1, $2)",
		viewerID, targetUserID,
	).Scan(&canView)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if !canView {
		c.JSON(http.StatusForbidden, gin.H{
			"error": "This account is private. Follow to see their content.",
		})
		return
	}

	// Fetch content
	query := `
		SELECT id, title, description, video_url, thumbnail_url, 
		       view_count, like_count, created_at
		FROM content_items
		WHERE creator_id = $1 
		  AND content_type = $2 
		  AND is_published = TRUE
		ORDER BY created_at DESC
		LIMIT 50
	`

	rows, err := db.Query(query, targetUserID, contentType)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	defer rows.Close()

	var content []models.Video // or models.Reel
	for rows.Next() {
		var item models.Video
		err := rows.Scan(
			&item.ID, &item.Title, &item.Description, &item.URL, &item.Thumbnail,
			&item.Views, &item.Likes, &item.CreatedAt,
		)
		if err != nil {
			continue
		}
		content = append(content, item)
	}

	c.JSON(http.StatusOK, content)
}

// ============================================================================
// FOLLOW REQUEST FLOW (for Private Accounts)
// ============================================================================

func SendFollowRequest(c *gin.Context) {
	var req models.FollowRequestCreate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	requesterID := getUserIDFromContext(c)

	// Get target user
	var targetUser models.User
	err := db.QueryRow(
		"SELECT id, privacy_profile FROM users WHERE id = $1",
		req.RequesteeID,
	).Scan(&targetUser.ID, &targetUser.PrivacyProfile)

	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	// If target is public, create direct follow
	if targetUser.PrivacyProfile == models.PrivacyPublic {
		err = createDirectFollow(requesterID, req.RequesteeID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to follow"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"message": "Following user"})
		return
	}

	// If target is private, create follow request
	_, err = db.Exec(`
		INSERT INTO follow_requests (requester_id, requestee_id, status)
		VALUES ($1, $2, 'pending')
		ON CONFLICT (requester_id, requestee_id) 
		DO UPDATE SET status = 'pending', requested_at = CURRENT_TIMESTAMP
	`, requesterID, req.RequesteeID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to send request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Follow request sent. Waiting for approval.",
	})
}

func RespondToFollowRequest(c *gin.Context) {
	requestID := c.Param("requestId")
	var req models.FollowRequestRespond
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	requesteeID := getUserIDFromContext(c)

	// Get follow request
	var followReq models.FollowRequest
	err := db.QueryRow(
		"SELECT id, requester_id, requestee_id FROM follow_requests WHERE id = $1",
		requestID,
	).Scan(&followReq.ID, &followReq.RequesterID, &followReq.RequesteeID)

	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Request not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	// Verify requestee
	if followReq.RequesteeID != requesteeID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	if req.Action == "accept" {
		// Begin transaction
		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
			return
		}
		defer tx.Rollback()

		// Create follow relationship
		_, err = tx.Exec(`
			INSERT INTO user_follows (follower_id, following_id)
			VALUES ($1, $2)
			ON CONFLICT DO NOTHING
		`, followReq.RequesterID, followReq.RequesteeID)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create follow"})
			return
		}

		// Update request status
		_, err = tx.Exec(`
			UPDATE follow_requests
			SET status = 'accepted', responded_at = CURRENT_TIMESTAMP
			WHERE id = $1
		`, requestID)

		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update request"})
			return
		}

		if err = tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Follow request accepted"})
		return
	}

	// Reject
	_, err = db.Exec(`
		UPDATE follow_requests
		SET status = 'rejected', responded_at = CURRENT_TIMESTAMP
		WHERE id = $1
	`, requestID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update request"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Follow request rejected"})
}

func GetPendingFollowRequests(c *gin.Context) {
	userID := getUserIDFromContext(c)

	rows, err := db.Query(`
		SELECT 
			fr.id, fr.requester_id, fr.requestee_id, fr.status, fr.requested_at,
			u.username, up.profile_image_url
		FROM follow_requests fr
		JOIN users u ON fr.requester_id = u.id
		LEFT JOIN user_profiles up ON u.id = up.user_id
		WHERE fr.requestee_id = $1 AND fr.status = 'pending'
		ORDER BY fr.requested_at DESC
	`, userID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	defer rows.Close()

	var requests []map[string]interface{}
	for rows.Next() {
		var fr models.FollowRequest
		var username string
		var avatar *string
		err := rows.Scan(
			&fr.ID, &fr.RequesterID, &fr.RequesteeID, &fr.Status, &fr.RequestedAt,
			&username, &avatar,
		)
		if err != nil {
			continue
		}

		requests = append(requests, map[string]interface{}{
			"id":                 fr.ID,
			"requester_id":       fr.RequesterID,
			"requester_username": username,
			"requester_avatar":   avatar,
			"requested_at":       fr.RequestedAt,
		})
	}

	c.JSON(http.StatusOK, requests)
}

// ============================================================================
// GET PRODUCT REVIEWS (Always Public by Default) - Example
// ============================================================================

func GetProductReviewsExample(c *gin.Context) {
	productID := c.Param("productId")

	// Reviews are public by default, even from private accounts
	// Only exclude explicitly private reviews
	query := `
		SELECT 
			pr.id, pr.product_id, pr.user_id, pr.rating, 
			pr.review_title, pr.review_text, pr.is_private, 
			pr.helpful_count, pr.created_at,
			u.username, up.profile_image_url
		FROM product_ratings pr
		JOIN users u ON pr.user_id = u.id
		LEFT JOIN user_profiles up ON u.id = up.user_id
		WHERE pr.product_id = $1 
		  AND pr.is_private = FALSE
		ORDER BY pr.created_at DESC
		LIMIT 100
	`

	rows, err := db.Query(query, productID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}
	defer rows.Close()

	var reviews []models.Review
	for rows.Next() {
		var review models.Review
		err := rows.Scan(
			&review.ID, &review.ProductID, &review.UserID, &review.Rating,
			&review.ReviewTitle, &review.ReviewText, &review.IsPrivate,
			&review.HelpfulCount, &review.CreatedAt,
			&review.Username, &review.UserAvatar,
		)
		if err != nil {
			continue
		}
		reviews = append(reviews, review)
	}

	c.JSON(http.StatusOK, reviews)
}

// ============================================================================
// TOGGLE ORDER PRIVACY
// ============================================================================

func UpdateOrderPrivacy(c *gin.Context) {
	orderID := c.Param("orderId")
	userID := getUserIDFromContext(c)

	var req models.OrderUpdatePrivacy
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Verify order belongs to user
	var ownerID string
	err := db.QueryRow("SELECT user_id FROM orders WHERE id = $1", orderID).Scan(&ownerID)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "Order not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error"})
		return
	}

	if ownerID != userID {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	// Update privacy
	_, err = db.Exec(
		"UPDATE orders SET is_private = $1 WHERE id = $2",
		req.IsPrivate, orderID,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": fmt.Sprintf("Order is now %s", map[bool]string{true: "private", false: "public"}[req.IsPrivate]),
	})
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

func getUserIDFromContext(c *gin.Context) string {
	// Extract from JWT token in middleware
	userID, exists := c.Get("user_id")
	if !exists {
		return ""
	}
	return userID.(string)
}

func checkIfFollowing(followerID, followingID string) (bool, error) {
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM user_follows 
			WHERE follower_id = $1 AND following_id = $2
		)
	`, followerID, followingID).Scan(&exists)
	return exists, err
}

func createDirectFollow(followerID, followingID string) error {
	_, err := db.Exec(`
		INSERT INTO user_follows (follower_id, following_id)
		VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`, followerID, followingID)
	return err
}

func createUser(req models.UserCreate) (*models.User, error) {
	// Hash password, insert user, etc.
	// Implementation depends on your auth system
	return nil, nil
}

// Global db connection (use your actual DB connection)
var db *sql.DB
