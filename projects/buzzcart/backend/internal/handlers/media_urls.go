package handlers

import (
	"buzzcart/internal/models"
	"buzzcart/internal/storage"
	"strings"
)

func readableMediaURL(raw string) string {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return raw
	}
	return storage.GetStorageClient().GetReadableURL(trimmed)
}

func readableMediaURLPtr(raw *string) *string {
	if raw == nil {
		return nil
	}
	value := readableMediaURL(*raw)
	return &value
}

func readableMediaURLs(raw []string) []string {
	if len(raw) == 0 {
		return raw
	}
	resolved := make([]string, len(raw))
	for i, value := range raw {
		resolved[i] = readableMediaURL(value)
	}
	return resolved
}

func resolvePostMediaURLs(post *models.Post) {
	post.MediaURL = readableMediaURL(post.MediaURL)
	post.ThumbnailURL = readableMediaURLPtr(post.ThumbnailURL)
	post.AuthorAvatar = readableMediaURLPtr(post.AuthorAvatar)
}

func resolveVideoMediaURLs(video *models.Video) {
	video.URL = readableMediaURL(video.URL)
	video.Thumbnail = readableMediaURL(video.Thumbnail)
	video.CreatorAvatar = readableMediaURLPtr(video.CreatorAvatar)
}

func resolveReelMediaURLs(reel *models.Reel) {
	reel.URL = readableMediaURL(reel.URL)
	reel.Thumbnail = readableMediaURL(reel.Thumbnail)
	reel.CreatorAvatar = readableMediaURLPtr(reel.CreatorAvatar)
}

func resolveUserMediaURLs(user *models.User) {
	user.Avatar = readableMediaURLPtr(user.Avatar)
}

func resolveProductMediaURLs(product *models.Product) {
	product.Images = readableMediaURLs(product.Images)
}
