package middleware

import (
	"log"
	"net/http"
	"runtime/debug"
	"time"

	"github.com/gin-gonic/gin"
)

// Recovery is a custom recovery middleware with better error handling
func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				// Log the panic with stack trace
				log.Printf("PANIC RECOVERED: %v\n%s", err, debug.Stack())

				// Return a generic error to the client without exposing internals
				c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
					"error": "Internal server error occurred",
					"time":  time.Now().Format(time.RFC3339),
				})
			}
		}()
		c.Next()
	}
}

// RequestLogger logs all incoming requests with structured format
func RequestLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		// Process request
		c.Next()

		// Log after request is processed
		latency := time.Since(start)
		statusCode := c.Writer.Status()
		clientIP := c.ClientIP()
		method := c.Request.Method
		userAgent := c.Request.UserAgent()

		// Get user ID if authenticated
		userID, _ := c.Get("user_id")

		// Structured log format
		log.Printf("[%s] %s %s | Status: %d | Latency: %v | IP: %s | User: %v | UA: %s | Query: %s",
			method,
			path,
			time.Now().Format(time.RFC3339),
			statusCode,
			latency,
			clientIP,
			userID,
			userAgent,
			query,
		)
	}
}

// ErrorHandler handles errors from handlers more gracefully
func ErrorHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()

		// Check if there were any errors
		if len(c.Errors) > 0 {
			// Log all errors
			for _, err := range c.Errors {
				log.Printf("[ERROR] %s | Path: %s | Error: %v", c.Request.Method, c.Request.URL.Path, err.Err)
			}

			// Return the last error as JSON
			c.JSON(-1, gin.H{
				"error": c.Errors.Last().Error(),
			})
		}
	}
}

// RateLimitByIP implements basic rate limiting
// This is a simple in-memory implementation - use Redis in production
func RateLimitByIP(requestsPerMinute int) gin.HandlerFunc {
	// This is a placeholder - implement with Redis or a proper rate limiting library
	return func(c *gin.Context) {
		// TODO: Implement proper rate limiting with Redis
		c.Next()
	}
}

// SecurityHeaders adds security headers to all responses
func SecurityHeaders() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("X-Content-Type-Options", "nosniff")
		c.Header("X-Frame-Options", "DENY")
		c.Header("X-XSS-Protection", "1; mode=block")
		c.Header("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Header("Content-Security-Policy", "default-src 'self'")

		// Only set HSTS in production with HTTPS
		// c.Header("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		c.Next()
	}
}
