package handlers

import (
	"buzzcart/internal/cache"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	_ "image/gif"
	_ "image/jpeg"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

const proxiedImageCacheTTL = 24 * time.Hour

type proxiedImagePayload struct {
	ContentType string `json:"content_type"`
	BodyBase64  string `json:"body_base64"`
	ETag        string `json:"etag"`
}

func validateAllowedRemoteMediaURL(rawURL string) (*url.URL, error) {
	parsedURL, err := url.Parse(rawURL)
	if err != nil || parsedURL.Scheme != "https" {
		return nil, err
	}

	host := strings.ToLower(parsedURL.Hostname())
	if host != "firebasestorage.googleapis.com" && host != "storage.googleapis.com" {
		return nil, http.ErrNotSupported
	}

	return parsedURL, nil
}

func proxiedImageCacheKey(rawURL string) string {
	sum := sha256.Sum256([]byte(strings.TrimSpace(rawURL)))
	return "media_proxy:image:" + hex.EncodeToString(sum[:])
}

func writeImageResponse(c *gin.Context, status int, contentType string, body []byte, etag string) {
	cacheControl := "public, max-age=86400, stale-while-revalidate=604800"
	c.Header("Cache-Control", cacheControl)
	c.Header("ETag", etag)
	c.Header("Vary", "Accept")

	if ifNoneMatch := strings.TrimSpace(c.GetHeader("If-None-Match")); ifNoneMatch != "" && ifNoneMatch == etag {
		c.Status(http.StatusNotModified)
		return
	}

	c.Data(status, contentType, body)
}

func readCachedProxyImage(rawURL string) (proxiedImagePayload, bool) {
	key := proxiedImageCacheKey(rawURL)
	cached, err := cache.Get(key)
	if err != nil {
		if err != redis.Nil {
			log.Printf("[ProxyMedia] Redis get failed for %q: %v", rawURL, err)
		}
		return proxiedImagePayload{}, false
	}

	var payload proxiedImagePayload
	if err := json.Unmarshal([]byte(cached), &payload); err != nil {
		log.Printf("[ProxyMedia] Failed to decode cached image for %q: %v", rawURL, err)
		_ = cache.Delete(key)
		return proxiedImagePayload{}, false
	}

	return payload, true
}

func cacheProxyImage(rawURL, contentType string, body []byte, etag string) {
	payload := proxiedImagePayload{
		ContentType: contentType,
		BodyBase64:  base64.StdEncoding.EncodeToString(body),
		ETag:        etag,
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		log.Printf("[ProxyMedia] Failed to encode cache payload for %q: %v", rawURL, err)
		return
	}

	if err := cache.Set(proxiedImageCacheKey(rawURL), string(encoded), proxiedImageCacheTTL); err != nil {
		log.Printf("[ProxyMedia] Redis set failed for %q: %v", rawURL, err)
	}
}

func ProxyMediaHandler(c *gin.Context) {
	rawURL := strings.TrimSpace(c.Query("url"))
	if rawURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "url is required"})
		return
	}

	if _, err := validateAllowedRemoteMediaURL(rawURL); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid media url"})
		return
	}

	if cached, ok := readCachedProxyImage(rawURL); ok {
		body, err := base64.StdEncoding.DecodeString(cached.BodyBase64)
		if err == nil {
			writeImageResponse(c, http.StatusOK, cached.ContentType, body, cached.ETag)
			return
		}
		log.Printf("[ProxyMedia] Failed to decode cached body for %q: %v", rawURL, err)
		_ = cache.Delete(proxiedImageCacheKey(rawURL))
	}

	client := &http.Client{Timeout: 20 * time.Second}
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, rawURL, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid media url"})
		return
	}

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[ProxyMedia] fetch failed for %q: %v", rawURL, err)
		c.JSON(http.StatusBadGateway, gin.H{"error": "failed to fetch media"})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		c.JSON(resp.StatusCode, gin.H{"error": "media fetch failed"})
		return
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 12*1024*1024))
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"error": "failed to read media"})
		return
	}

	contentType := http.DetectContentType(body)
	if !strings.HasPrefix(contentType, "image/") {
		c.JSON(http.StatusUnsupportedMediaType, gin.H{"error": "media is not an image"})
		return
	}

	sum := sha256.Sum256(body)
	etag := `"` + hex.EncodeToString(sum[:]) + `"`
	cacheProxyImage(rawURL, contentType, body, etag)
	writeImageResponse(c, http.StatusOK, contentType, body, etag)
}

func StreamMediaHandler(c *gin.Context) {
	rawURL := strings.TrimSpace(c.Query("url"))
	if rawURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "url is required"})
		return
	}

	if _, err := validateAllowedRemoteMediaURL(rawURL); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid media url"})
		return
	}

	client := &http.Client{Timeout: 0}
	req, err := http.NewRequestWithContext(c.Request.Context(), http.MethodGet, rawURL, nil)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid media url"})
		return
	}

	if rangeHeader := strings.TrimSpace(c.GetHeader("Range")); rangeHeader != "" {
		req.Header.Set("Range", rangeHeader)
	}
	if ifRange := strings.TrimSpace(c.GetHeader("If-Range")); ifRange != "" {
		req.Header.Set("If-Range", ifRange)
	}

	resp, err := client.Do(req)
	if err != nil {
		log.Printf("[StreamMedia] fetch failed for %q: %v", rawURL, err)
		c.JSON(http.StatusBadGateway, gin.H{"error": "failed to fetch media"})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 400 {
		c.JSON(resp.StatusCode, gin.H{"error": "media fetch failed"})
		return
	}

	for _, key := range []string{
		"Accept-Ranges",
		"Cache-Control",
		"Content-Length",
		"Content-Range",
		"Content-Type",
		"ETag",
		"Last-Modified",
	} {
		if value := strings.TrimSpace(resp.Header.Get(key)); value != "" {
			c.Header(key, value)
		}
	}
	c.Status(resp.StatusCode)

	if _, err := io.Copy(c.Writer, resp.Body); err != nil {
		log.Printf("[StreamMedia] stream failed for %q: %v", rawURL, err)
	}
}
