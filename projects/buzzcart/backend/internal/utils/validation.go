package utils

import (
	"fmt"
	"mime/multipart"
	"path/filepath"
	"strings"
)

const (
	// MaxImageSize is 10MB
	MaxImageSize = 10 * 1024 * 1024
	// MaxVideoSize is 120MB
	MaxVideoSize = 120 * 1024 * 1024
	// MaxAvatarSize is 5MB
	MaxAvatarSize = 5 * 1024 * 1024
	// MaxDocumentSize is 25MB
	MaxDocumentSize = 25 * 1024 * 1024
)

var (
	// AllowedImageFormats defines acceptable image MIME types
	AllowedImageFormats = map[string]bool{
		"image/jpeg": true,
		"image/jpg":  true,
		"image/png":  true,
		"image/gif":  true,
		"image/webp": true,
		"image/heic": true,
		"image/heif": true,
	}

	// AllowedVideoFormats defines acceptable video MIME types
	AllowedVideoFormats = map[string]bool{
		"video/mp4":       true,
		"video/mpeg":      true,
		"video/quicktime": true,
		"video/x-msvideo": true,
		"video/webm":      true,
	}

	// AllowedImageExtensions defines acceptable image file extensions
	AllowedImageExtensions = map[string]bool{
		".jpg":  true,
		".jpeg": true,
		".png":  true,
		".gif":  true,
		".webp": true,
		".heic": true,
		".heif": true,
	}

	// AllowedVideoExtensions defines acceptable video file extensions
	AllowedVideoExtensions = map[string]bool{
		".mp4":  true,
		".mpeg": true,
		".mov":  true,
		".avi":  true,
		".webm": true,
	}

	// AllowedDocumentFormats defines acceptable document MIME types.
	AllowedDocumentFormats = map[string]bool{
		"application/pdf": true,
	}

	// AllowedDocumentExtensions defines acceptable document file extensions.
	AllowedDocumentExtensions = map[string]bool{
		".pdf": true,
	}
)

// ValidateImage validates an image file
func ValidateImage(header *multipart.FileHeader) error {
	// Check file size
	if header.Size > MaxImageSize {
		return fmt.Errorf("image size exceeds maximum allowed size of %d MB", MaxImageSize/(1024*1024))
	}

	if header.Size == 0 {
		return fmt.Errorf("image file is empty")
	}

	// Check content type - skip validation for generic octet-stream (Dio/multipart default)
	// when no explicit MIME type is set; rely on extension check instead
	contentType := header.Header.Get("Content-Type")
	if contentType != "" && contentType != "application/octet-stream" && !AllowedImageFormats[contentType] {
		return fmt.Errorf("unsupported image format: %s", contentType)
	}

	// Check file extension
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if ext == "" {
		// No extension - infer from content type if available
		if contentType == "image/jpeg" || contentType == "image/jpg" {
			ext = ".jpg"
		} else if contentType == "image/png" {
			ext = ".png"
		} else if contentType == "image/webp" {
			ext = ".webp"
		} else {
			// Default allow - storage upload will handle actual content
			return nil
		}
	}
	if !AllowedImageExtensions[ext] {
		return fmt.Errorf("unsupported image file extension: %s", ext)
	}

	return nil
}

// ValidateVideo validates a video file
func ValidateVideo(header *multipart.FileHeader) error {
	// Check file size
	if header.Size > MaxVideoSize {
		return fmt.Errorf("video size exceeds maximum allowed size of %d MB", MaxVideoSize/(1024*1024))
	}

	if header.Size == 0 {
		return fmt.Errorf("video file is empty")
	}

	// Check content type - skip validation for generic octet-stream
	contentType := header.Header.Get("Content-Type")
	if contentType != "" && contentType != "application/octet-stream" && !AllowedVideoFormats[contentType] {
		return fmt.Errorf("unsupported video format: %s", contentType)
	}

	// Check file extension
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !AllowedVideoExtensions[ext] {
		return fmt.Errorf("unsupported video file extension: %s", ext)
	}

	return nil
}

// ValidateAvatar validates an avatar image file
func ValidateAvatar(header *multipart.FileHeader) error {
	// Check file size
	if header.Size > MaxAvatarSize {
		return fmt.Errorf("avatar size exceeds maximum allowed size of %d MB", MaxAvatarSize/(1024*1024))
	}

	if header.Size == 0 {
		return fmt.Errorf("avatar file is empty")
	}

	// Check content type - skip validation for generic octet-stream
	contentType := header.Header.Get("Content-Type")
	if contentType != "" && contentType != "application/octet-stream" && !AllowedImageFormats[contentType] {
		return fmt.Errorf("unsupported avatar format: %s", contentType)
	}

	// Check file extension
	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !AllowedImageExtensions[ext] {
		return fmt.Errorf("unsupported avatar file extension: %s", ext)
	}

	return nil
}

// ValidateDocument validates a document upload.
func ValidateDocument(header *multipart.FileHeader) error {
	if header.Size > MaxDocumentSize {
		return fmt.Errorf("document size exceeds maximum allowed size of %d MB", MaxDocumentSize/(1024*1024))
	}

	if header.Size == 0 {
		return fmt.Errorf("document file is empty")
	}

	contentType := header.Header.Get("Content-Type")
	if contentType != "" && contentType != "application/octet-stream" && !AllowedDocumentFormats[contentType] {
		return fmt.Errorf("unsupported document format: %s", contentType)
	}

	ext := strings.ToLower(filepath.Ext(header.Filename))
	if !AllowedDocumentExtensions[ext] {
		return fmt.Errorf("unsupported document file extension: %s", ext)
	}

	return nil
}

// SanitizeFilename removes potentially dangerous characters from filenames
func SanitizeFilename(filename string) string {
	// Remove path separators and other dangerous characters
	filename = strings.ReplaceAll(filename, "../", "")
	filename = strings.ReplaceAll(filename, "..\\", "")
	filename = strings.ReplaceAll(filename, "/", "_")
	filename = strings.ReplaceAll(filename, "\\", "_")
	filename = strings.TrimSpace(filename)

	// Limit filename length
	if len(filename) > 255 {
		ext := filepath.Ext(filename)
		baseName := filename[:255-len(ext)]
		filename = baseName + ext
	}

	return filename
}
