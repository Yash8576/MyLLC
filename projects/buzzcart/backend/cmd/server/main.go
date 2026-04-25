package main

import (
	"buzzcart/internal/cache"
	"buzzcart/internal/config"
	"buzzcart/internal/database"
	"buzzcart/internal/handlers"
	"buzzcart/internal/middleware"
	"buzzcart/internal/storage"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load environment variables
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	// Initialize configuration
	cfg := config.Load()

	// Initialize database connection
	db, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Disconnect()

	// Initialize Redis connection
	if cfg.RedisURL == "" {
		log.Println("Redis disabled: REDIS_URL is not set")
	} else if err := cache.InitRedis(cfg.RedisURL); err != nil {
		log.Printf("Warning: Failed to connect to Redis: %v (caching disabled)", err)
	} else {
		log.Println("Successfully connected to Redis")
		defer cache.Close()
	}

	// Initialize Firebase Storage
	if err := storage.InitializeStorage(cfg); err != nil {
		log.Fatalf("Failed to initialize storage: %v", err)
	}
	log.Println("✓ Storage initialized successfully")

	// Set Gin mode
	if os.Getenv("GIN_MODE") == "release" {
		gin.SetMode(gin.ReleaseMode)
	}

	// Create router with custom recovery
	router := gin.New()
	messageHub := handlers.NewMessageHub()

	// Add middleware
	router.Use(middleware.Recovery())               // Custom panic recovery
	router.Use(middleware.RequestLogger())          // Structured request logging
	router.Use(middleware.SecurityHeaders())        // Security headers
	router.Use(middleware.CORS(cfg.AllowedOrigins)) // CORS support

	// Enhanced health check endpoint
	router.GET("/health", func(c *gin.Context) {
		// Check database connectivity
		dbStatus := "ok"
		if err := db.Ping(); err != nil {
			dbStatus = "error"
			log.Printf("[Health] Database ping failed: %v", err)
		}

		// Check storage connectivity
		storageStatus := "ok"
		if !storage.IsInitialized() {
			storageStatus = "error"
		}

		// Check cache connectivity
		cacheStatus := "ok"
		if cache.GetClient() != nil {
			if err := cache.GetClient().Ping(c.Request.Context()).Err(); err != nil {
				cacheStatus = "degraded"
			}
		} else {
			cacheStatus = "disabled"
		}

		overallStatus := "healthy"
		httpStatus := http.StatusOK
		if dbStatus == "error" || storageStatus == "error" {
			overallStatus = "unhealthy"
			httpStatus = http.StatusServiceUnavailable
		} else if cacheStatus == "degraded" {
			overallStatus = "degraded"
		}

		c.JSON(httpStatus, gin.H{
			"status":    overallStatus,
			"timestamp": time.Now().Format(time.RFC3339),
			"services": gin.H{
				"database": dbStatus,
				"storage":  storageStatus,
				"cache":    cacheStatus,
			},
		})
	})

	router.GET("/ws/messages", handlers.MessagesSocket(db, cfg.JWTSecret, messageHub))

	// API routes
	api := router.Group("/api")
	{
		// Auth routes
		auth := api.Group("/auth")
		{
			auth.POST("/register", handlers.Register(db))
			auth.POST("/login", handlers.Login(db))
			auth.GET("/me", middleware.Auth(cfg.JWTSecret), handlers.GetMe(db))
			auth.PUT("/profile", middleware.Auth(cfg.JWTSecret), handlers.UpdateProfile(db))
		}

		// User routes
		api.GET("/users/:user_id", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetUser(db))
		api.GET("/users/:user_id/followers", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetFollowers(db))
		api.GET("/users/:user_id/following", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetFollowing(db))

		// Product routes
		products := api.Group("/products")
		{
			products.POST("", middleware.Auth(cfg.JWTSecret), handlers.CreateProduct(db))
			products.GET("", handlers.GetProducts(db))
			products.GET("/:product_id", handlers.GetProduct(db))
			products.PUT("/:product_id", middleware.Auth(cfg.JWTSecret), handlers.UpdateProduct(db))
			products.DELETE("/:product_id", middleware.Auth(cfg.JWTSecret), handlers.DeleteProduct(db))
			products.GET("/seller/:seller_id", handlers.GetSellerProducts(db))

			// Product review routes
			products.POST("/:product_id/reviews", middleware.Auth(cfg.JWTSecret), handlers.CreateReview(db))
			products.GET("/:product_id/buyers", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetProductBuyers(db))
			products.GET("/:product_id/reviews/preview", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetProductReviewPreview(db))
			products.GET("/:product_id/reviews/ranked", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetProductReviewsRanked(db))
			products.GET("/:product_id/reviews", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetProductReviews(db))
		}

		// Review routes
		reviews := api.Group("/reviews")
		{
			reviews.GET("/:review_id", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetReview(db))
			reviews.PUT("/:review_id", middleware.Auth(cfg.JWTSecret), handlers.UpdateReview(db))
			reviews.DELETE("/:review_id", middleware.Auth(cfg.JWTSecret), handlers.DeleteReview(db))
			reviews.PATCH("/:review_id/privacy", middleware.Auth(cfg.JWTSecret), handlers.UpdateReviewPrivacy(db))
			reviews.POST("/:review_id/helpful", middleware.Auth(cfg.JWTSecret), handlers.MarkReviewHelpful(db))

			// Moderation routes (admin only)
			reviews.POST("/:review_id/moderate", middleware.Auth(cfg.JWTSecret), handlers.ModerateReview(db))
			reviews.GET("/pending", middleware.Auth(cfg.JWTSecret), handlers.GetPendingReviews(db))
		}

		// User review routes
		api.GET("/users/:user_id/reviews", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetUserReviews(db))

		// Video routes
		videos := api.Group("/videos")
		{
			videos.POST("", middleware.Auth(cfg.JWTSecret), handlers.CreateVideo(db))
			videos.GET("", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetVideos(db))
			videos.GET("/:video_id", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetVideo(db))
			videos.GET("/:video_id/comments", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetVideoComments(db))
			videos.POST("/:video_id/comments", middleware.Auth(cfg.JWTSecret), handlers.CreateVideoComment(db))
			videos.DELETE("/:video_id", middleware.Auth(cfg.JWTSecret), handlers.DeleteVideo(db))
			videos.POST("/:video_id/like", middleware.Auth(cfg.JWTSecret), handlers.LikeVideo(db))
		}

		// Reel routes
		reels := api.Group("/reels")
		{
			reels.POST("", middleware.Auth(cfg.JWTSecret), handlers.CreateReel(db))
			reels.GET("", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetReels(db))
			reels.GET("/:reel_id", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetReel(db))
			reels.GET("/:reel_id/comments", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetReelComments(db))
			reels.POST("/:reel_id/comments", middleware.Auth(cfg.JWTSecret), handlers.CreateReelComment(db))
			reels.DELETE("/:reel_id", middleware.Auth(cfg.JWTSecret), handlers.DeleteReel(db))
			reels.POST("/:reel_id/like", middleware.Auth(cfg.JWTSecret), handlers.LikeReel(db))
		}

		// Cart routes
		cart := api.Group("/cart")
		cart.Use(middleware.Auth(cfg.JWTSecret))
		{
			cart.GET("", handlers.GetCart(db))
			cart.POST("/add", handlers.AddToCart(db))
			cart.POST("/checkout", handlers.CheckoutCart(db))
			cart.POST("/remove", handlers.RemoveFromCart(db))
			cart.POST("/update", handlers.UpdateCartItem(db))
			cart.DELETE("/clear", handlers.ClearCart(db))
		}

		// Upload routes
		upload := api.Group("/upload")
		{
			upload.POST("/image", middleware.Auth(cfg.JWTSecret), handlers.UploadImageHandler(db))
			upload.POST("/video", middleware.Auth(cfg.JWTSecret), handlers.UploadVideoHandler)
			upload.POST("/product-image", middleware.Auth(cfg.JWTSecret), handlers.UploadProductImageHandler)
			upload.POST("/product-document", middleware.Auth(cfg.JWTSecret), handlers.UploadProductDocumentHandler)

			upload.POST("/user-photo", middleware.Auth(cfg.JWTSecret), handlers.UploadUserPhotoHandler(db))
			upload.POST("/avatar", middleware.Auth(cfg.JWTSecret), handlers.UploadAvatarHandler(db))
			upload.DELETE("/avatar", middleware.Auth(cfg.JWTSecret), handlers.DeleteAvatarHandler(db))
			upload.DELETE("/:objectName", middleware.Auth(cfg.JWTSecret), handlers.DeleteFileHandler)
		}

		// User media routes
		api.GET("/media/proxy", handlers.ProxyMediaHandler)
		api.GET("/media/stream", handlers.StreamMediaHandler)
		api.GET("/users/:user_id/media", handlers.GetUserMedia(db))
		api.GET("/users/:user_id/purchases", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetUserPurchases(db))
		api.DELETE("/users/media/:media_id", middleware.Auth(cfg.JWTSecret), handlers.DeleteUserMedia(db))

		// Follow routes
		api.POST("/follow/:user_id", middleware.Auth(cfg.JWTSecret), handlers.FollowUser(db))
		api.POST("/unfollow/:user_id", middleware.Auth(cfg.JWTSecret), handlers.UnfollowUser(db))

		// Feed routes (Instagram-style)
		feed := api.Group("/feed")
		{
			// Followers feed (requires auth) - pre-computed feed from user_feeds table
			feed.GET("/followers", middleware.Auth(cfg.JWTSecret), handlers.GetFollowersFeed(db))

			// Discovery feed (optional auth) - ranked public posts
			feed.GET("/discovery", middleware.OptionalAuth(cfg.JWTSecret), handlers.GetDiscoveryFeed(db))

			// User profile feed - specific user's posts
			feed.GET("/user/:user_id", handlers.GetUserPosts(db))
		}

		// Post routes (Instagram-style posts)
		posts := api.Group("/posts")
		{
			// Create a post (requires auth)
			posts.POST("", middleware.Auth(cfg.JWTSecret), handlers.CreatePost(db))

			// Like/Unlike a post
			posts.DELETE("/:post_id", middleware.Auth(cfg.JWTSecret), handlers.DeletePost(db))
			posts.POST("/:post_id/like", middleware.Auth(cfg.JWTSecret), handlers.LikePost(db))
			posts.DELETE("/:post_id/like", middleware.Auth(cfg.JWTSecret), handlers.UnlikePost(db))
		}

		// Legacy feed routes (backward compatibility)
		api.GET("/feed", handlers.GetFeed(db))
		api.GET("/discover", handlers.GetDiscover(db))

		// Search route (with optional auth to exclude current user from results)
		api.GET("/search", middleware.OptionalAuth(cfg.JWTSecret), handlers.Search(db))

		// Message routes
		messages := api.Group("/messages")
		messages.Use(middleware.Auth(cfg.JWTSecret))
		{
			messages.POST("", handlers.SendMessage(db, messageHub))
			messages.GET("/connections", handlers.GetConnections(db))
			messages.GET("/conversations", handlers.GetConversations(db))
			messages.GET("/conversations/:conversation_id", handlers.GetMessages(db))
		}
	}

	// Start server
	port := cfg.Port
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := router.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
