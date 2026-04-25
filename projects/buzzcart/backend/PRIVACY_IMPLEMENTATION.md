# BuzzCart User Types & Privacy Implementation Guide

## Overview

This document explains the implementation of User Types and Privacy Settings for the BuzzCart platform.

## Database Schema

### Migration: `004_user_types_privacy.sql`

The migration adds:
- **ENUMs**: `account_type`, `privacy_profile`, `follow_request_status`
- **Tables**: `follow_requests`
- **Columns**: Added to `users`, `orders`, `product_ratings`
- **Constraints**: `seller_must_be_public`
- **Views**: Helper views for querying public/private data
- **Function**: `can_view_user_content(viewer_id, target_id)`

## User Types

### 1. Seller Account (`account_type = 'seller'`)

**Characteristics:**
- MUST always be `privacy_profile = 'public'`
- Database constraint enforces this rule
- All content is visible to everyone:
  - Products
  - Videos/Reels
  - Follower/Following lists
  - Reviews they write (default public)
  - Purchases they make (default public)

**Business Logic:**
```go
// During signup
if userCreate.AccountType == AccountTypeSeller {
    userCreate.PrivacyProfile = PrivacyPublic // Force public
}

// Database constraint prevents:
// - INSERT/UPDATE where account_type='seller' AND privacy_profile='private'
```

### 2. Consumer Account (`account_type = 'consumer'`)

Consumers can choose between `public` or `private` privacy settings.

#### Public Consumer (`privacy_profile = 'public'`)

**Characteristics:**
- Content (Videos/Reels) is visible to everyone
- Follower/Following lists are visible to everyone
- Purchases & Reviews are public by default (user can toggle individual items to private)
- No follow approval needed

**Follow Mechanism:**
- Direct follow (use `user_follows` table)
- No `follow_requests` entry needed

#### Private Consumer (`privacy_profile = 'private'`)

**Characteristics:**
- Content (Videos/Reels) is visible ONLY to approved followers
- Follower/Following lists are visible ONLY to approved followers
- **CRITICAL EXCEPTION**: Purchases & Reviews are STILL PUBLIC by default
  - User must explicitly toggle `is_private = true` on individual orders/reviews

**Follow Mechanism:**
- Requires approval (use `follow_requests` table)
- Flow:
  1. User A sends follow request to Private User B
  2. Creates `follow_requests` entry with `status = 'pending'`
  3. User B accepts or rejects
  4. If accepted: Create entry in `user_follows` + Update `status = 'accepted'`
  5. If rejected: Update `status = 'rejected'`

## Privacy Logic Implementation

### 1. Signup Flow

**Frontend (Flutter):**
```dart
class SignupRequest {
  String email;
  String password;
  String name;
  AccountType accountType;      // Required: 'seller' or 'consumer'
  PrivacyProfile? privacyProfile; // Required if accountType == 'consumer'
}
```

**Backend (Go):**
```go
type UserCreate struct {
    Email          string         `json:"email" binding:"required,email"`
    Password       string         `json:"password" binding:"required,min=6"`
    Name           string         `json:"name" binding:"required"`
    AccountType    AccountType    `json:"account_type" binding:"required,oneof=seller consumer"`
    PrivacyProfile PrivacyProfile `json:"privacy_profile" binding:"required_if=AccountType consumer,oneof=public private"`
}

func (uc *UserCreate) Validate() error {
    // Force sellers to be public
    if uc.AccountType == AccountTypeSeller && uc.PrivacyProfile != PrivacyPublic {
        uc.PrivacyProfile = PrivacyPublic
    }
    
    // Consumers must specify privacy
    if uc.AccountType == AccountTypeConsumer && uc.PrivacyProfile == "" {
        return fmt.Errorf("consumers must specify privacy_profile")
    }
    
    return nil
}
```

### 2. Fetching User Profile

**Endpoint**: `GET /api/users/:userId`

**Logic:**
```go
func GetUserProfile(viewerID, targetUserID string) (*User, error) {
    user, err := db.GetUser(targetUserID)
    if err != nil {
        return nil, err
    }
    
    // If target is public OR target is the viewer themselves
    if user.PrivacyProfile == PrivacyPublic || targetUserID == viewerID {
        return user, nil
    }
    
    // If target is private, check if viewer is following
    isFollowing, err := db.IsFollowing(viewerID, targetUserID)
    if err != nil {
        return nil, err
    }
    
    if !isFollowing {
        // Return limited profile info
        return &User{
            ID:             user.ID,
            Name:           user.Name,
            Avatar:         user.Avatar,
            AccountType:    user.AccountType,
            PrivacyProfile: user.PrivacyProfile,
            // Don't include: Bio, FollowersCount, FollowingCount, etc.
        }, nil
    }
    
    return user, nil
}
```

**SQL Helper Function** (already created in migration):
```sql
SELECT can_view_user_content('viewer-uuid', 'target-uuid');
-- Returns: true if viewer can see target's content
```

### 3. Fetching User's Content Feed

**Endpoint**: `GET /api/users/:userId/videos` or `GET /api/users/:userId/reels`

**Logic:**
```go
func GetUserContent(viewerID, targetUserID string, contentType string) ([]Content, error) {
    // Check if viewer can see target's content
    canView, err := db.CanViewUserContent(viewerID, targetUserID)
    if err != nil {
        return nil, err
    }
    
    if !canView {
        return nil, fmt.Errorf("user profile is private")
    }
    
    // Fetch content
    return db.GetUserContent(targetUserID, contentType)
}
```

**SQL Query:**
```sql
-- For Videos/Reels feed
SELECT ci.* 
FROM content_items ci
JOIN users u ON ci.creator_id = u.id
WHERE ci.creator_id = $1
  AND (
    -- Content is from public user
    u.privacy_profile = 'public'
    OR
    -- Viewer is following the private user
    EXISTS (
      SELECT 1 FROM user_follows
      WHERE follower_id = $2 AND following_id = $1
    )
    OR
    -- Viewer is the creator themselves
    $2 = $1
  )
  AND ci.is_published = TRUE
ORDER BY ci.created_at DESC;
```

### 4. Fetching Follower/Following Lists

**Endpoint**: `GET /api/users/:userId/followers` or `GET /api/users/:userId/following`

**Logic:**
```go
func GetFollowers(viewerID, targetUserID string) ([]User, error) {
    targetUser, err := db.GetUser(targetUserID)
    if err != nil {
        return nil, err
    }
    
    // If target is private and viewer is not following them
    if targetUser.PrivacyProfile == PrivacyPrivate && 
       targetUserID != viewerID &&
       !db.IsFollowing(viewerID, targetUserID) {
        return nil, fmt.Errorf("follower list is private")
    }
    
    return db.GetFollowers(targetUserID)
}
```

### 5. Fetching Reviews (Always Public by Default)

**Endpoint**: `GET /api/products/:productId/reviews`

**Logic:**
```go
func GetProductReviews(productID string) ([]Review, error) {
    // Reviews are public by default, even from private accounts
    // Only exclude reviews explicitly marked as private
    return db.Query(`
        SELECT pr.*, u.username, up.profile_image_url
        FROM product_ratings pr
        JOIN users u ON pr.user_id = u.id
        LEFT JOIN user_profiles up ON u.id = up.user_id
        WHERE pr.product_id = $1
          AND pr.is_private = FALSE
        ORDER BY pr.created_at DESC
    `, productID)
}
```

### 6. Fetching Purchase History

**Endpoint**: `GET /api/users/:userId/orders`

**Logic:**
```go
func GetUserOrders(viewerID, targetUserID string) ([]Order, error) {
    // User can always see their own orders
    if viewerID == targetUserID {
        return db.GetAllUserOrders(targetUserID)
    }
    
    // Other users can only see public orders
    return db.Query(`
        SELECT * FROM orders
        WHERE user_id = $1
          AND is_private = FALSE
        ORDER BY created_at DESC
    `, targetUserID)
}
```

### 7. Follow Request Flow (Private Accounts)

#### Send Follow Request

**Endpoint**: `POST /api/follow-requests`

**Request Body:**
```json
{
  "requestee_id": "uuid-of-private-user"
}
```

**Logic:**
```go
func SendFollowRequest(requesterID string, req FollowRequestCreate) error {
    targetUser, err := db.GetUser(req.RequesteeID)
    if err != nil {
        return err
    }
    
    // If target is public, create direct follow instead
    if targetUser.PrivacyProfile == PrivacyPublic {
        return db.CreateFollow(requesterID, req.RequesteeID)
    }
    
    // If target is private, create follow request
    return db.CreateFollowRequest(requesterID, req.RequesteeID)
}
```

#### Accept/Reject Follow Request

**Endpoint**: `POST /api/follow-requests/:requestId/respond`

**Request Body:**
```json
{
  "action": "accept" // or "reject"
}
```

**Logic:**
```go
func RespondToFollowRequest(requestID string, action string, requesteeID string) error {
    followReq, err := db.GetFollowRequest(requestID)
    if err != nil {
        return err
    }
    
    // Verify requestee_id matches authenticated user
    if followReq.RequesteeID != requesteeID {
        return fmt.Errorf("unauthorized")
    }
    
    if action == "accept" {
        // Create actual follow relationship
        err = db.CreateFollow(followReq.RequesterID, followReq.RequesteeID)
        if err != nil {
            return err
        }
        
        // Update request status
        return db.UpdateFollowRequest(requestID, FollowRequestAccepted)
    }
    
    // Reject
    return db.UpdateFollowRequest(requestID, FollowRequestRejected)
}
```

#### Get Pending Follow Requests

**Endpoint**: `GET /api/follow-requests/pending`

**Logic:**
```go
func GetPendingFollowRequests(userID string) ([]FollowRequest, error) {
    return db.Query(`
        SELECT fr.*, 
               u.username as requester_username,
               up.profile_image_url as requester_avatar
        FROM follow_requests fr
        JOIN users u ON fr.requester_id = u.id
        LEFT JOIN user_profiles up ON u.id = up.user_id
        WHERE fr.requestee_id = $1
          AND fr.status = 'pending'
        ORDER BY fr.requested_at DESC
    `, userID)
}
```

## Privacy Check Summary Table

| Resource                 | Seller (Public) | Consumer (Public) | Consumer (Private) |
|--------------------------|-----------------|-------------------|---------------------|
| Products                 | Public          | N/A               | N/A                 |
| Videos/Reels             | Public          | Public            | Followers Only      |
| Follower/Following Lists | Public          | Public            | Followers Only      |
| Reviews (Default)        | Public          | Public            | Public              |
| Orders (Default)         | Public          | Public            | Public              |
| Reviews (if toggled)     | N/A             | Private           | Private             |
| Orders (if toggled)      | N/A             | Private           | Private             |

## Key Implementation Points

### 1. Database Level
- ✅ Constraint prevents Sellers from being Private
- ✅ Orders and Reviews default to `is_private = FALSE`
- ✅ Follow requests table for Private accounts

### 2. Application Level
- ✅ Validate `UserCreate.Validate()` on signup
- ✅ Check `can_view_user_content()` before returning content
- ✅ Filter by `is_private = FALSE` for public reviews/orders
- ✅ Handle follow requests vs direct follows based on privacy

### 3. API Level
- Return HTTP 403 for unauthorized content access
- Return limited profile for private accounts when not following
- Clear error messages: "This account is private. Follow to see their content."

## Testing Scenarios

### Scenario 1: Seller Signup
```
User selects: account_type = 'seller', privacy_profile = 'private'
Expected: Backend forces privacy_profile = 'public'
Result: User created with public profile
```

### Scenario 2: Private Consumer Content Access
```
User A (private consumer) posts video
User B (not following) tries to view
Expected: GET /api/users/{A}/videos returns 403
User B sends follow request
User A accepts
Expected: GET /api/users/{A}/videos returns videos
```

### Scenario 3: Private Consumer Reviews
```
User A (private consumer) buys product
User A writes review (is_private defaults to FALSE)
Expected: Review appears in GET /api/products/{id}/reviews (PUBLIC)
User A toggles review to private
Expected: Review hidden from public view
```

### Scenario 4: Follow Request Flow
```
User B tries to follow User A (private)
Expected: Creates follow_request (status='pending')
User A receives notification of pending request
User A accepts
Expected: Creates entry in user_follows, updates follow_request (status='accepted')
User B can now see User A's content
```

## Migration & Deployment

### Running the Migration

```bash
# Apply migration
psql -U postgres -d buzzcart -f database/migrations/004_user_types_privacy.sql

# Verify
psql -U postgres -d buzzcart -c "SELECT account_type, privacy_profile FROM users LIMIT 5;"
```

### Data Migration Strategy

Existing users will be migrated as follows:
- Users with `role = 'seller'` → `account_type = 'seller'`, `privacy_profile = 'public'`
- Users with `role = 'consumer'` → `account_type = 'consumer'`, `privacy_profile = 'public'` (default)

**Note**: Existing users default to `public`. They can update their privacy setting later via:
```
PUT /api/profile/privacy
{
  "privacy_profile": "private"
}
```

## API Endpoints Summary

### New/Updated Endpoints

```
POST   /api/auth/signup              - Include account_type and privacy_profile
GET    /api/users/:id                - Respects privacy settings
GET    /api/users/:id/videos         - Requires follow for private users
GET    /api/users/:id/reels          - Requires follow for private users
GET    /api/users/:id/followers      - Requires follow for private users
GET    /api/users/:id/following      - Requires follow for private users
GET    /api/users/:id/orders         - Shows only public orders (or own)
PUT    /api/orders/:id/privacy       - Toggle order privacy
PUT    /api/reviews/:id/privacy      - Toggle review privacy
POST   /api/follow-requests          - Send follow request
GET    /api/follow-requests/pending  - Get pending requests
POST   /api/follow-requests/:id/respond - Accept/reject request
```

---

## Questions?

For technical questions or clarifications, refer to:
- Migration file: `database/migrations/004_user_types_privacy.sql`
- Models file: `backend/internal/models/models.go`
- Database constraints and helper functions in the migration
