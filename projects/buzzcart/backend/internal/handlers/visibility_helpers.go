package handlers

import (
	"database/sql"
	"encoding/json"
	"strings"
)

const (
	contentBucketPhotos    = "photos"
	contentBucketVideos    = "videos"
	contentBucketReels     = "reels"
	contentBucketPurchases = "purchases"
)

func defaultVisibilityPreferences(mode string) map[string]bool {
	preferences := map[string]bool{
		contentBucketPhotos:    true,
		contentBucketVideos:    true,
		contentBucketReels:     true,
		contentBucketPurchases: true,
	}

	if strings.ToLower(mode) == "private" {
		preferences[contentBucketPhotos] = false
		preferences[contentBucketVideos] = false
		preferences[contentBucketReels] = false
		preferences[contentBucketPurchases] = false
	}

	return preferences
}

func normalizeVisibilityPreferences(mode string, preferences map[string]bool) map[string]bool {
	normalized := defaultVisibilityPreferences(mode)
	for key, value := range preferences {
		normalized[strings.ToLower(key)] = value
	}

	switch strings.ToLower(mode) {
	case "public":
		normalized[contentBucketPhotos] = true
		normalized[contentBucketVideos] = true
		normalized[contentBucketReels] = true
		normalized[contentBucketPurchases] = true
	case "private":
		normalized[contentBucketPhotos] = false
		normalized[contentBucketVideos] = false
		normalized[contentBucketReels] = false
		normalized[contentBucketPurchases] = false
	}

	return normalized
}

func parseVisibilityPreferences(raw string, mode string) map[string]bool {
	if strings.TrimSpace(raw) == "" {
		return defaultVisibilityPreferences(mode)
	}

	var preferences map[string]bool
	if err := json.Unmarshal([]byte(raw), &preferences); err != nil {
		return defaultVisibilityPreferences(mode)
	}

	return normalizeVisibilityPreferences(mode, preferences)
}

func visibilityBucketAllowed(mode string, rawPreferences string, bucket string, isOwnProfile bool) bool {
	if isOwnProfile {
		return true
	}

	switch strings.ToLower(mode) {
	case "private":
		return false
	case "custom":
		preferences := parseVisibilityPreferences(rawPreferences, mode)
		allowed, ok := preferences[strings.ToLower(bucket)]
		if !ok {
			return true
		}
		return allowed
	default:
		return true
	}
}

func contentBucketForMediaType(mediaType string) string {
	switch strings.ToLower(mediaType) {
	case "photo":
		return contentBucketPhotos
	case "video":
		return contentBucketVideos
	case "reel":
		return contentBucketReels
	default:
		return contentBucketPhotos
	}
}

func resolvePostVisibilityForBucket(db *sql.DB, userID string, bucket string) (bool, string, error) {
	var status string
	var privacyProfile string
	var visibilityMode string
	var visibilityPreferencesRaw string

	err := db.QueryRow(
		`SELECT
			COALESCE(status::text, 'active'),
			COALESCE(privacy_profile::text, 'public'),
			COALESCE(visibility_mode, 'public'),
			COALESCE(visibility_preferences::text, '{"photos": true, "videos": true, "reels": true, "purchases": true}')
		 FROM users
		 WHERE id = $1`,
		userID,
	).Scan(&status, &privacyProfile, &visibilityMode, &visibilityPreferencesRaw)
	if err != nil {
		return false, "", err
	}

	if !strings.EqualFold(status, "active") {
		return true, "followers", nil
	}

	if strings.EqualFold(privacyProfile, "private") {
		return true, "followers", nil
	}

	mode := strings.ToLower(visibilityMode)
	if mode == "private" {
		return true, "followers", nil
	}

	if mode == "custom" {
		preferences := parseVisibilityPreferences(visibilityPreferencesRaw, mode)
		if preferences[strings.ToLower(bucket)] {
			return false, "public", nil
		}
		return false, "followers", nil
	}

	return false, "public", nil
}
