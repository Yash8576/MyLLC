package models

import (
	"fmt"
	"time"
)

// ============================================================================
// ENUMS - Match PostgreSQL ENUM types
// ============================================================================

type AccountType string

const (
	AccountTypeSeller   AccountType = "seller"
	AccountTypeConsumer AccountType = "consumer"
)

type UserRole string

const (
	RoleConsumer UserRole = "consumer"
	RoleSeller   UserRole = "seller"
	RoleAdmin    UserRole = "admin"
)

type AccountStatus string

const (
	StatusActive    AccountStatus = "active"
	StatusInactive  AccountStatus = "inactive"
	StatusSuspended AccountStatus = "suspended"
)

type PrivacyProfile string

const (
	PrivacyPublic  PrivacyProfile = "public"
	PrivacyPrivate PrivacyProfile = "private"
)

type FollowRequestStatus string

const (
	FollowRequestPending  FollowRequestStatus = "pending"
	FollowRequestAccepted FollowRequestStatus = "accepted"
	FollowRequestRejected FollowRequestStatus = "rejected"
)

type ModerationStatus string

const (
	ModerationPending  ModerationStatus = "pending"
	ModerationApproved ModerationStatus = "approved"
	ModerationRejected ModerationStatus = "rejected"
)

// ============================================================================
// USER MODELS
// ============================================================================

type User struct {
	ID                    string          `json:"id" db:"id"`
	Email                 string          `json:"email" db:"email"`
	Password              string          `json:"-" db:"password"`
	Name                  string          `json:"name" db:"name"`
	Avatar                *string         `json:"avatar,omitempty" db:"avatar"`
	Bio                   string          `json:"bio" db:"bio"`
	AccountType           AccountType     `json:"account_type" db:"account_type"`
	Role                  UserRole        `json:"role" db:"role"`
	Status                AccountStatus   `json:"status" db:"status"`
	IsVerified            bool            `json:"is_verified" db:"is_verified"`
	PhoneNumber           *string         `json:"phone_number,omitempty" db:"phone_number"`
	PrivacyProfile        PrivacyProfile  `json:"privacy_profile" db:"privacy_profile"`
	VisibilityMode        string          `json:"visibility_mode" db:"visibility_mode"`
	VisibilityPreferences map[string]bool `json:"visibility_preferences" db:"visibility_preferences"`
	FollowersCount        int             `json:"followers_count" db:"followers_count"`
	FollowingCount        int             `json:"following_count" db:"following_count"`
	IsFollowing           bool            `json:"is_following" db:"-"`
	IsFollowedBy          bool            `json:"is_followed_by" db:"-"`
	IsConnection          bool            `json:"is_connection" db:"-"`
	CanViewConnections    bool            `json:"can_view_connections" db:"-"`
	CreatedAt             time.Time       `json:"created_at" db:"created_at"`
}

type SocialUser struct {
	ID           string  `json:"id"`
	Name         string  `json:"name"`
	Avatar       *string `json:"avatar,omitempty"`
	Bio          string  `json:"bio"`
	IsFollowing  bool    `json:"is_following"`
	IsFollowedBy bool    `json:"is_followed_by"`
	IsConnection bool    `json:"is_connection"`
}

type UserCreate struct {
	Email          string         `json:"email" binding:"required,email"`
	Password       string         `json:"password" binding:"required,min=6"`
	Name           string         `json:"name" binding:"required"`
	AccountType    AccountType    `json:"account_type" binding:"required,oneof=seller consumer"`
	Role           UserRole       `json:"role" binding:"required,oneof=consumer seller admin"`
	PhoneNumber    *string        `json:"phone_number,omitempty"`
	PrivacyProfile PrivacyProfile `json:"privacy_profile" binding:"required_if=AccountType consumer,oneof=public private"`
}

// Validate ensures business rules are enforced
func (uc *UserCreate) Validate() error {
	// Seller accounts must always be public
	if uc.AccountType == AccountTypeSeller && uc.PrivacyProfile != PrivacyPublic {
		uc.PrivacyProfile = PrivacyPublic // Force public for sellers
	}

	// Consumer accounts must specify privacy
	if uc.AccountType == AccountTypeConsumer && uc.PrivacyProfile == "" {
		return fmt.Errorf("consumers must specify privacy_profile (public or private)")
	}

	// Sync role with account_type if not explicitly set
	if uc.Role == "" {
		if uc.AccountType == AccountTypeSeller {
			uc.Role = RoleSeller
		} else {
			uc.Role = RoleConsumer
		}
	}

	// Ensure role matches account_type (sellers can't be consumers and vice versa)
	if uc.AccountType == AccountTypeSeller && uc.Role == RoleConsumer {
		return fmt.Errorf("seller account cannot have consumer role")
	}
	if uc.AccountType == AccountTypeConsumer && uc.Role == RoleSeller {
		return fmt.Errorf("consumer account cannot have seller role")
	}

	return nil
}

type UserLogin struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type ProfileUpdate struct {
	Name                  *string         `json:"name,omitempty"`
	Bio                   *string         `json:"bio,omitempty"`
	Avatar                *string         `json:"avatar,omitempty"`
	Status                *AccountStatus  `json:"status,omitempty"`
	PrivacyProfile        *PrivacyProfile `json:"privacy_profile,omitempty"`
	VisibilityMode        *string         `json:"visibility_mode,omitempty"`
	VisibilityPreferences map[string]bool `json:"visibility_preferences,omitempty"`
}

type TokenResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	User        User   `json:"user"`
}

type Product struct {
	ID             string         `json:"id" db:"id"`
	Title          string         `json:"title" db:"title"`
	Description    string         `json:"description" db:"description"`
	Price          float64        `json:"price" db:"price"`
	CompareAtPrice *float64       `json:"compare_at_price,omitempty" db:"compare_at_price"`
	Currency       string         `json:"currency" db:"currency"`
	SKU            *string        `json:"sku,omitempty" db:"sku"`
	StockQuantity  int            `json:"stock_quantity" db:"stock_quantity"`
	Condition      string         `json:"condition" db:"condition"`
	Images         []string       `json:"images" db:"images"`
	Category       string         `json:"category" db:"category"`
	Tags           []string       `json:"tags" db:"tags"`
	SellerID       string         `json:"seller_id" db:"seller_id"`
	SellerName     string         `json:"seller_name" db:"seller_name"`
	Rating         float64        `json:"rating" db:"rating"`
	ReviewsCount   int            `json:"reviews_count" db:"reviews_count"`
	Views          int            `json:"views" db:"views"`
	Buys           int            `json:"buys" db:"buys"`
	Metadata       map[string]any `json:"metadata,omitempty" db:"metadata"`
	CreatedAt      time.Time      `json:"created_at" db:"created_at"`
}

type ProductCreate struct {
	ID             *string        `json:"id,omitempty"`
	Title          string         `json:"title" binding:"required"`
	Description    string         `json:"description" binding:"required"`
	Price          float64        `json:"price" binding:"required,gt=0"`
	CompareAtPrice *float64       `json:"compare_at_price,omitempty"`
	Images         []string       `json:"images"`
	Category       string         `json:"category"`
	Tags           []string       `json:"tags"`
	SKU            *string        `json:"sku,omitempty"`
	StockQuantity  *int           `json:"stock_quantity,omitempty"`
	Condition      string         `json:"condition,omitempty"`
	Metadata       map[string]any `json:"metadata,omitempty"`
}

type ProductBuyer struct {
	BuyerID       string    `json:"buyer_id"`
	BuyerName     string    `json:"buyer_name"`
	BuyerAvatar   *string   `json:"buyer_avatar,omitempty"`
	PurchaseDate  time.Time `json:"purchase_date"`
	TotalQuantity int       `json:"total_quantity"`
	IsConnection  bool      `json:"is_connection"`
}

type ReviewPreview struct {
	UserID      string  `json:"user_id"`
	Username    string  `json:"username"`
	UserAvatar  *string `json:"user_avatar,omitempty"`
	IsFollowing bool    `json:"is_following"`
}

type ProductReviewPreview struct {
	ReviewCount int             `json:"review_count"`
	Reviews     []ReviewPreview `json:"reviews"`
}

type Video struct {
	ID            string          `json:"id" db:"id"`
	Title         string          `json:"title" db:"title"`
	Description   string          `json:"description" db:"description"`
	URL           string          `json:"url" db:"url"`
	Thumbnail     string          `json:"thumbnail" db:"thumbnail"`
	Duration      int             `json:"duration" db:"duration"`
	Views         int             `json:"views" db:"views"`
	Likes         int             `json:"likes" db:"likes"`
	CommentCount  int             `json:"comment_count" db:"comment_count"`
	CreatorID     string          `json:"creator_id" db:"creator_id"`
	CreatorName   string          `json:"creator_name" db:"creator_name"`
	CreatorAvatar *string         `json:"creator_avatar,omitempty" db:"creator_avatar"`
	Products      []ProductSimple `json:"products" db:"products"`
	CreatedAt     time.Time       `json:"created_at" db:"created_at"`
}

type VideoCreate struct {
	Title       string   `json:"title" binding:"required"`
	Description string   `json:"description" binding:"required"`
	URL         string   `json:"url" binding:"required"`
	Thumbnail   string   `json:"thumbnail" binding:"required"`
	Duration    int      `json:"duration"`
	ProductIDs  []string `json:"product_ids"`
}

type Reel struct {
	ID            string          `json:"id" db:"id"`
	URL           string          `json:"url" db:"url"`
	Thumbnail     string          `json:"thumbnail" db:"thumbnail"`
	Caption       string          `json:"caption" db:"caption"`
	Views         int             `json:"views" db:"views"`
	Likes         int             `json:"likes" db:"likes"`
	CommentCount  int             `json:"comment_count" db:"comment_count"`
	Width         int             `json:"width" db:"width"`
	Height        int             `json:"height" db:"height"`
	CreatorID     string          `json:"creator_id" db:"creator_id"`
	CreatorName   string          `json:"creator_name" db:"creator_name"`
	CreatorAvatar *string         `json:"creator_avatar,omitempty" db:"creator_avatar"`
	Products      []ProductSimple `json:"products" db:"products"`
	CreatedAt     time.Time       `json:"created_at" db:"created_at"`
}

type ReelCreate struct {
	URL        string   `json:"url" binding:"required"`
	Thumbnail  string   `json:"thumbnail" binding:"required"`
	Caption    string   `json:"caption"`
	ProductIDs []string `json:"product_ids"`
	Width      int      `json:"width" binding:"required,gt=0"`
	Height     int      `json:"height" binding:"required,gt=0"`
}

type ReelComment struct {
	ID            string    `json:"id" db:"id"`
	ReelID        string    `json:"reel_id" db:"reel_id"`
	UserID        string    `json:"user_id" db:"user_id"`
	CommentText   string    `json:"comment_text" db:"comment_text"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
	Username      string    `json:"username,omitempty" db:"username"`
	UserAvatar    *string   `json:"user_avatar,omitempty" db:"user_avatar"`
	IsFollowing   bool      `json:"is_following" db:"-"`
	IsCurrentUser bool      `json:"is_current_user" db:"-"`
}

type ReelCommentCreate struct {
	CommentText string `json:"comment_text" binding:"required,min=1,max=2000"`
}

type ContentComment struct {
	ID            string    `json:"id" db:"id"`
	ContentID     string    `json:"content_id" db:"content_id"`
	UserID        string    `json:"user_id" db:"user_id"`
	CommentText   string    `json:"comment_text" db:"comment_text"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
	Username      string    `json:"username,omitempty" db:"username"`
	UserAvatar    *string   `json:"user_avatar,omitempty" db:"user_avatar"`
	IsFollowing   bool      `json:"is_following" db:"-"`
	IsCurrentUser bool      `json:"is_current_user" db:"-"`
}

type ContentCommentCreate struct {
	CommentText string `json:"comment_text" binding:"required,min=1,max=2000"`
}

type ProductSimple struct {
	ID    string  `json:"id" db:"id"`
	Title string  `json:"title" db:"title"`
	Price float64 `json:"price" db:"price"`
	Image string  `json:"image" db:"image"`
}

type CartItem struct {
	ProductID      string   `json:"product_id" db:"product_id"`
	Title          string   `json:"title" db:"title"`
	Price          float64  `json:"price" db:"price"`
	CompareAtPrice *float64 `json:"compare_at_price,omitempty" db:"compare_at_price"`
	SellerName     string   `json:"seller_name,omitempty" db:"seller_name"`
	Image          string   `json:"image" db:"image"`
	Quantity       int      `json:"quantity" db:"quantity"`
	StockQuantity  int      `json:"stock_quantity,omitempty" db:"stock_quantity"`
}

type Cart struct {
	UserID    string     `json:"user_id" db:"user_id"`
	Items     []CartItem `json:"items" db:"items"`
	UpdatedAt time.Time  `json:"updated_at" db:"updated_at"`
}

type CartResponse struct {
	Items     []CartItem `json:"items"`
	Subtotal  float64    `json:"subtotal"`
	Discount  float64    `json:"discount"`
	Total     float64    `json:"total"`
	ItemCount int        `json:"item_count"`
}

type CartItemAdd struct {
	ProductID string `json:"product_id" binding:"required"`
	Quantity  int    `json:"quantity"`
}

type Message struct {
	ID             string         `json:"id" db:"id"`
	ConversationID string         `json:"conversation_id" db:"conversation_id"`
	SenderID       string         `json:"sender_id" db:"sender_id"`
	ReceiverID     string         `json:"receiver_id,omitempty" db:"-"`
	Content        string         `json:"content" db:"message_text"`
	MessageType    string         `json:"message_type" db:"message_type"`
	ProductID      *string        `json:"product_id,omitempty" db:"product_id"`
	Product        *ProductSimple `json:"product,omitempty" db:"-"`
	Metadata       map[string]any `json:"metadata,omitempty" db:"-"`
	CreatedAt      time.Time      `json:"created_at" db:"created_at"`
	Read           bool           `json:"read" db:"is_read"`
}

type MessageCreate struct {
	ReceiverID  string         `json:"receiver_id" binding:"required"`
	Content     string         `json:"content"`
	MessageType string         `json:"message_type"`
	ProductID   *string        `json:"product_id,omitempty"`
	Metadata    map[string]any `json:"metadata,omitempty"`
}

type ConversationParticipant struct {
	ID     string  `json:"id"`
	Name   string  `json:"name"`
	Avatar *string `json:"avatar,omitempty"`
}

type ConversationSummary struct {
	ID          string                  `json:"id"`
	Participant ConversationParticipant `json:"participant"`
	LastMessage *Message                `json:"last_message,omitempty"`
	UnreadCount int                     `json:"unread_count"`
	UpdatedAt   time.Time               `json:"updated_at"`
}

type ConversationConnection struct {
	ID                      string  `json:"id"`
	Name                    string  `json:"name"`
	Avatar                  *string `json:"avatar,omitempty"`
	ConversationID          *string `json:"conversation_id,omitempty"`
	HasExistingConversation bool    `json:"has_existing_conversation"`
}

type Follow struct {
	FollowerID  string    `json:"follower_id" db:"follower_id"`
	FollowingID string    `json:"following_id" db:"following_id"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

// ============================================================================
// FOLLOW REQUEST MODEL (for Private accounts)
// ============================================================================

type FollowRequest struct {
	ID          string              `json:"id" db:"id"`
	RequesterID string              `json:"requester_id" db:"requester_id"`
	RequesteeID string              `json:"requestee_id" db:"requestee_id"`
	Status      FollowRequestStatus `json:"status" db:"status"`
	RequestedAt time.Time           `json:"requested_at" db:"requested_at"`
	RespondedAt *time.Time          `json:"responded_at,omitempty" db:"responded_at"`
}

type FollowRequestCreate struct {
	RequesteeID string `json:"requestee_id" binding:"required"`
}

type FollowRequestRespond struct {
	Action string `json:"action" binding:"required,oneof=accept reject"`
}

// ============================================================================
// ORDER MODEL (with Privacy flag)
// ============================================================================

type Order struct {
	ID          string      `json:"id" db:"id"`
	UserID      string      `json:"user_id" db:"user_id"`
	OrderNumber string      `json:"order_number" db:"order_number"`
	Status      string      `json:"status" db:"status"`
	Subtotal    float64     `json:"subtotal" db:"subtotal"`
	Tax         float64     `json:"tax" db:"tax"`
	Shipping    float64     `json:"shipping" db:"shipping"`
	Discount    float64     `json:"discount" db:"discount"`
	Total       float64     `json:"total" db:"total"`
	IsPrivate   bool        `json:"is_private" db:"is_private"` // Privacy flag - defaults to false (public)
	Items       []OrderItem `json:"items,omitempty" db:"items"`
	CreatedAt   time.Time   `json:"created_at" db:"created_at"`
	CompletedAt *time.Time  `json:"completed_at,omitempty" db:"completed_at"`
}

type OrderItem struct {
	ID           string  `json:"id" db:"id"`
	ProductID    string  `json:"product_id" db:"product_id"`
	ProductTitle string  `json:"product_title" db:"product_title"`
	Quantity     int     `json:"quantity" db:"quantity"`
	UnitPrice    float64 `json:"unit_price" db:"unit_price"`
	Subtotal     float64 `json:"subtotal" db:"subtotal"`
}

type OrderCreate struct {
	Items     []OrderItemCreate `json:"items" binding:"required,min=1"`
	IsPrivate bool              `json:"is_private"` // Optional: user can mark order as private, defaults to false
	// Shipping and payment details would go here
}

type OrderItemCreate struct {
	ProductID string `json:"product_id" binding:"required"`
	Quantity  int    `json:"quantity" binding:"required,min=1"`
}

type OrderUpdatePrivacy struct {
	IsPrivate bool `json:"is_private" binding:"required"`
}

// ============================================================================
// REVIEW MODEL (with Privacy flag)
// ============================================================================

type Review struct {
	ID                 string           `json:"id" db:"id"`
	ProductID          string           `json:"product_id" db:"product_id"`
	UserID             string           `json:"user_id" db:"user_id"`
	Rating             int              `json:"rating" db:"rating"`
	ReviewTitle        string           `json:"review_title,omitempty" db:"review_title"`
	ReviewText         string           `json:"review_text,omitempty" db:"review_text"`
	IsVerifiedPurchase bool             `json:"is_verified_purchase" db:"is_verified_purchase"`
	IsPrivate          bool             `json:"is_private" db:"is_private"` // Privacy flag - defaults to false (public)
	ModerationStatus   ModerationStatus `json:"moderation_status" db:"moderation_status"`
	ModerationNote     *string          `json:"moderation_note,omitempty" db:"moderation_note"`
	ModeratedBy        *string          `json:"moderated_by,omitempty" db:"moderated_by"`
	ModeratedAt        *time.Time       `json:"moderated_at,omitempty" db:"moderated_at"`
	HelpfulCount       int              `json:"helpful_count" db:"helpful_count"`
	CreatedAt          time.Time        `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time        `json:"updated_at" db:"updated_at"`

	// Populated fields (not stored in DB)
	Username    string  `json:"username,omitempty" db:"-"`
	UserAvatar  *string `json:"user_avatar,omitempty" db:"-"`
	HasVoted    bool    `json:"has_voted" db:"-"`    // Whether current user voted this review as helpful
	IsFollowing bool    `json:"is_following" db:"-"` // Whether reviewer is in the current user's network
}

type ReviewCreate struct {
	ProductID   string `json:"product_id" binding:"required"`
	Rating      int    `json:"rating" binding:"required,min=1,max=5"`
	ReviewTitle string `json:"review_title,omitempty"`
	ReviewText  string `json:"review_text,omitempty"`
	IsPrivate   bool   `json:"is_private"` // Optional: user can mark review as private, defaults to false
}

type ReviewUpdatePrivacy struct {
	IsPrivate bool `json:"is_private" binding:"required"`
}

type ReviewModerate struct {
	Status ModerationStatus `json:"status" binding:"required,oneof=approved rejected"`
	Note   string           `json:"note,omitempty"`
}

type SearchResponse struct {
	Products []Product `json:"products"`
	Videos   []Video   `json:"videos"`
	Reels    []Reel    `json:"reels"`
	Users    []User    `json:"users"`
}

// ============================================================================
// FEED & POST MODELS (Instagram-Style Feed System)
// ============================================================================

type Post struct {
	ID           string    `json:"id" db:"id"`
	UserID       string    `json:"user_id" db:"user_id"`
	MediaID      string    `json:"media_id" db:"media_id"`
	Caption      string    `json:"caption" db:"caption"`
	MediaType    string    `json:"media_type" db:"media_type"` // photo, video, reel
	MediaURL     string    `json:"media_url" db:"media_url"`
	ThumbnailURL *string   `json:"thumbnail_url,omitempty" db:"thumbnail_url"`
	IsPrivate    bool      `json:"is_private" db:"is_private"`
	Visibility   string    `json:"visibility" db:"visibility"` // followers, public, close_friends
	LikeCount    int       `json:"like_count" db:"like_count"`
	CommentCount int       `json:"comment_count" db:"comment_count"`
	ShareCount   int       `json:"share_count" db:"share_count"`
	ViewCount    int       `json:"view_count" db:"view_count"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time `json:"updated_at" db:"updated_at"`

	// Populated fields (joined from users table, not stored in posts)
	AuthorName     string  `json:"author_name" db:"author_name"`
	AuthorAvatar   *string `json:"author_avatar,omitempty" db:"author_avatar"`
	AuthorVerified bool    `json:"author_verified" db:"author_verified"`
	IsLiked        bool    `json:"is_liked" db:"-"`     // Whether current user liked this post
	IsFollowing    bool    `json:"is_following" db:"-"` // Whether current user follows the author
}

type PostCreate struct {
	MediaID     string   `json:"media_id" binding:"required"`
	Caption     string   `json:"caption,omitempty"`
	Visibility  string   `json:"visibility" binding:"omitempty,oneof=followers public close_friends"`
	TaggedUsers []string `json:"tagged_users,omitempty"`
	Hashtags    []string `json:"hashtags,omitempty"`
}

type FeedResponse struct {
	Posts      []Post  `json:"posts"`
	NextCursor *string `json:"next_cursor,omitempty"` // For cursor-based pagination
	HasMore    bool    `json:"has_more"`
}

type PostLike struct {
	ID        string    `json:"id" db:"id"`
	PostID    string    `json:"post_id" db:"post_id"`
	UserID    string    `json:"user_id" db:"user_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type PostComment struct {
	ID              string    `json:"id" db:"id"`
	PostID          string    `json:"post_id" db:"post_id"`
	UserID          string    `json:"user_id" db:"user_id"`
	ParentCommentID *string   `json:"parent_comment_id,omitempty" db:"parent_comment_id"`
	CommentText     string    `json:"comment_text" db:"comment_text"`
	LikeCount       int       `json:"like_count" db:"like_count"`
	IsPinned        bool      `json:"is_pinned" db:"is_pinned"`
	IsDeleted       bool      `json:"is_deleted" db:"is_deleted"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`

	// Populated fields
	Username   string  `json:"username,omitempty" db:"username"`
	UserAvatar *string `json:"user_avatar,omitempty" db:"user_avatar"`
}

type PostCommentCreate struct {
	PostID          string  `json:"post_id" binding:"required"`
	ParentCommentID *string `json:"parent_comment_id,omitempty"`
	CommentText     string  `json:"comment_text" binding:"required,min=1"`
}
