package handlers

import (
	"buzzcart/internal/models"
	"database/sql"
	"errors"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

func FollowUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		targetUserID := c.Param("user_id")

		if userID == targetUserID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot follow yourself"})
			return
		}

		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start follow transaction"})
			return
		}
		defer tx.Rollback()

		var exists bool
		err = tx.QueryRow("SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)", targetUserID).Scan(&exists)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify user"})
			return
		}
		if !exists {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		var alreadyFollowing bool
		err = tx.QueryRow(
			`SELECT EXISTS(
				SELECT 1
				FROM user_follows
				WHERE follower_id = $1 AND following_id = $2
			)`,
			userID,
			targetUserID,
		).Scan(&alreadyFollowing)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check follow status"})
			return
		}

		if !alreadyFollowing {
			_, err = tx.Exec(
				"INSERT INTO user_follows (follower_id, following_id, followed_at) VALUES ($1, $2, $3)",
				userID, targetUserID, time.Now().UTC(),
			)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to follow user"})
				return
			}

			_, _ = tx.Exec("UPDATE users SET following_count = following_count + 1 WHERE id = $1", userID)
			_, _ = tx.Exec("UPDATE users SET followers_count = followers_count + 1 WHERE id = $1", targetUserID)
		}

		relationship, err := getRelationshipStatus(tx, userID, targetUserID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load updated relationship"})
			return
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete follow operation"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":      "User followed",
			"relationship": relationship,
		})
	}
}

func UnfollowUser(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID := c.GetString("user_id")
		targetUserID := c.Param("user_id")

		tx, err := db.Begin()
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to start unfollow transaction"})
			return
		}
		defer tx.Rollback()

		result, err := tx.Exec(
			"DELETE FROM user_follows WHERE follower_id = $1 AND following_id = $2",
			userID, targetUserID,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unfollow user"})
			return
		}

		rowsAffected, _ := result.RowsAffected()
		if rowsAffected > 0 {
			_, _ = tx.Exec(
				"UPDATE users SET following_count = GREATEST(0, following_count - 1) WHERE id = $1",
				userID,
			)
			_, _ = tx.Exec(
				"UPDATE users SET followers_count = GREATEST(0, followers_count - 1) WHERE id = $1",
				targetUserID,
			)
		}

		relationship, err := getRelationshipStatus(tx, userID, targetUserID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to load updated relationship"})
			return
		}

		if err := tx.Commit(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to complete unfollow operation"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"message":      "User unfollowed",
			"relationship": relationship,
		})
	}
}

func GetFollowers(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		getFollowList(db, c, true)
	}
}

func GetFollowing(db *sql.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		getFollowList(db, c, false)
	}
}

func getFollowList(db *sql.DB, c *gin.Context, followers bool) {
	targetUserID := c.Param("user_id")
	requestingUserID := c.GetString("user_id")

	canView, err := canViewSocialList(db, targetUserID, requestingUserID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to verify list visibility"})
		return
	}
	if !canView {
		c.JSON(http.StatusForbidden, gin.H{"error": "This list is private"})
		return
	}

	baseQuery := `
		SELECT
			u.id,
			u.name,
			u.avatar,
			COALESCE(u.bio, ''),
			CASE WHEN NULLIF($2, '') IS NULL THEN false ELSE EXISTS(
				SELECT 1 FROM user_follows WHERE follower_id = NULLIF($2, '')::uuid AND following_id = u.id
			) END AS is_following,
			CASE WHEN NULLIF($2, '') IS NULL THEN false ELSE EXISTS(
				SELECT 1 FROM user_follows WHERE follower_id = u.id AND following_id = NULLIF($2, '')::uuid
			) END AS is_followed_by
		FROM user_follows uf
		JOIN users u ON u.id = %s
		WHERE %s = $1
		ORDER BY LOWER(u.name) ASC
	`

	joinField := "uf.follower_id"
	filterField := "uf.following_id"
	if !followers {
		joinField = "uf.following_id"
		filterField = "uf.follower_id"
	}

	rows, err := db.Query(
		fmt.Sprintf(baseQuery, joinField, filterField),
		targetUserID,
		requestingUserID,
	)
	if err != nil {
		log.Printf("[getFollowList] query failed (target=%s viewer=%s followers=%t): %v", targetUserID, requestingUserID, followers, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch list"})
		return
	}
	defer rows.Close()

	users := []models.SocialUser{}
	for rows.Next() {
		var user models.SocialUser
		if err := rows.Scan(
			&user.ID,
			&user.Name,
			&user.Avatar,
			&user.Bio,
			&user.IsFollowing,
			&user.IsFollowedBy,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode list"})
			return
		}
		user.IsConnection = user.IsFollowing && user.IsFollowedBy
		user.Avatar = readableMediaURLPtr(user.Avatar)
		users = append(users, user)
	}

	if users == nil {
		users = []models.SocialUser{}
	}

	c.JSON(http.StatusOK, users)
}

func getRelationshipStatus(q interface {
	QueryRow(query string, args ...any) *sql.Row
}, viewerID, targetUserID string) (gin.H, error) {
	var (
		isFollowing    bool
		isFollowedBy   bool
		followersCount int
		followingCount int
	)

	err := q.QueryRow(
		`SELECT
			EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $1 AND following_id = $2),
			EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $2 AND following_id = $1),
			COALESCE((SELECT followers_count FROM users WHERE id = $2), 0),
			COALESCE((SELECT following_count FROM users WHERE id = $2), 0)`,
		viewerID,
		targetUserID,
	).Scan(&isFollowing, &isFollowedBy, &followersCount, &followingCount)
	if err != nil {
		return nil, err
	}

	return gin.H{
		"is_following":    isFollowing,
		"is_followed_by":  isFollowedBy,
		"is_connection":   isFollowing && isFollowedBy,
		"followers_count": followersCount,
		"following_count": followingCount,
	}, nil
}

func canViewSocialList(db *sql.DB, targetUserID, viewerID string) (bool, error) {
	var privacyProfile string
	err := db.QueryRow(
		"SELECT privacy_profile FROM users WHERE id = $1",
		targetUserID,
	).Scan(&privacyProfile)
	if err != nil {
		return false, err
	}

	if viewerID == targetUserID {
		return true, nil
	}
	if privacyProfile != "private" {
		return true, nil
	}
	if viewerID == "" {
		return false, nil
	}

	var isConnection bool
	err = db.QueryRow(
		`SELECT EXISTS(
			SELECT 1
			FROM user_follows outgoing
			JOIN user_follows incoming
				ON incoming.follower_id = outgoing.following_id
				AND incoming.following_id = outgoing.follower_id
			WHERE outgoing.follower_id = $1
				AND outgoing.following_id = $2
		)`,
		viewerID,
		targetUserID,
	).Scan(&isConnection)
	if err != nil {
		return false, err
	}

	return isConnection, nil
}
