package handlers

import (
	"database/sql"
	"time"

	"github.com/google/uuid"
)

// createFeedPostForMedia publishes uploaded media into the shared posts stream.
// Public accounts default to public visibility so their content can appear globally.
func createFeedPostForMedia(
	db *sql.DB,
	userID string,
	mediaID string,
	caption string,
	mediaType string,
	mediaURL string,
	thumbnailURL *string,
	createdAt time.Time,
) (string, error) {
	bucket := contentBucketForMediaType(mediaType)
	isPrivate, visibility, err := resolvePostVisibilityForBucket(db, userID, bucket)
	if err != nil {
		return "", err
	}

	postID := uuid.New().String()

	var thumbnailValue interface{}
	if thumbnailURL != nil && *thumbnailURL != "" {
		thumbnailValue = *thumbnailURL
	}

	if _, err := db.Exec(
		`INSERT INTO posts (id, user_id, media_id, caption, media_type, media_url, thumbnail_url, is_private, visibility, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		postID, userID, mediaID, caption, mediaType, mediaURL, thumbnailValue, isPrivate, visibility, createdAt,
	); err != nil {
		return "", err
	}

	// Keep follower feeds in sync, but don't fail the publish if fan-out stumbles.
	var followerCount int
	_ = db.QueryRow("SELECT fanout_post_to_followers($1, $2)", postID, userID).Scan(&followerCount)

	return postID, nil
}
