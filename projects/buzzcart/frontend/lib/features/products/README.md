# Products Feature - Reviews Module

This module provides a comprehensive product review system for the Like2Share application.

## Structure

```
frontend/lib/features/products/
├── screens/
│   └── reviews_page.dart       # Main reviews page
└── widgets/
    ├── review_card.dart         # Individual review display widget
    └── write_review_dialog.dart # Dialog for writing new reviews
```

## Files Created

### 1. ReviewsPage (`screens/reviews_page.dart`)
Main screen that displays all reviews for a product.

**Features:**
- Displays review summary with average rating and rating distribution
- **Trust badge filters**: Filter by "From people you follow" or "Verified Purchases"
- Sort reviews by: Recent, Helpful, Highest Rated, Lowest Rated
- Pull-to-refresh functionality
- Empty state with call-to-action
- Floating action button to write new reviews
- Review analytics with visual rating breakdown
- Smart filter bar that only shows when trust badges are available

**Usage:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ReviewsPage(
      productId: 'product-uuid',
      productTitle: 'Product Name',
    ),
  ),
);
```

### 2. ReviewCard (`widgets/review_card.dart`)
Widget that displays an individual review.

**Features:**
- User avatar and name display
- Star rating visualization
- **Trust badges**:
  - "From people you follow" badge (blue) - Shows when review is from someone the user follows
  - "Verified Purchase" badge (green) - Shows when reviewer actually purchased the product
- Review title and text
- Helpful button with vote count
- Time ago display (e.g., "2 days ago")
- Support for marking reviews as helpful/unhelpful

### 3. WriteReviewDialog (`widgets/write_review_dialog.dart`)
Dialog for creating new product reviews.

**Features:**
- Interactive star rating selector
- Optional review title (max 100 chars)
- Optional review text (max 1000 chars)
- Privacy toggle (public/private reviews)
- Rating feedback text (Poor, Fair, Good, Very Good, Excellent)
- Form validation
- Loading state during submission

## Models Updated

### ReviewModel (`core/models/models.dart`)
```dart
class ReviewModel {
  final String id;
  final String productId;
  final String userId;
  final int rating;              // 1-5 stars
  final String? reviewTitle;
  final String? reviewText;
  final bool isVerifiedPurchase;
  final bool isPrivate;
  final String moderationStatus;
  final int helpfulCount;
  final String createdAt;
  final String updatedAt;
  final String? username;
  final bool isFollowing;        // Whether review is from someone user follows
  final String? userAvatar;
  final bool hasVoted;           // Whether current user voted helpful
}
```

## API Methods Added

The following methods were added to `ApiService` (`core/services/api_service.dart`):

### Get Product Reviews
```dart
Future<List<ReviewModel>> getProductReviews(String productId, {int limit = 50})
```

### Create Review
```dart
Future<ReviewModel> createReview({
  required String productId,
  required int rating,
  String? reviewTitle,
  String? reviewText,
  bool isPrivate = false,
})
```

### Mark Review as Helpful
```dart
Future<void> markReviewHelpful(String reviewId)
```

### Unmark Review as Helpful
```dart
Future<void> unmarkReviewHelpful(String reviewId)
```

### Update Review Privacy
```dart
Future<ReviewModel> updateReviewPrivacy(String reviewId, bool isPrivate)
```

## Backend Endpoints Expected

The following backend endpoints should be implemented to support this feature:

- `GET /products/:productId/reviews` - Get all reviews for a product
  - Should include `is_following` field indicating if reviewer is followed by current user
- `POST /reviews` - Create a new review
- `POST /reviews/:reviewId/helpful` - Mark review as helpful
- `DELETE /reviews/:reviewId/helpful` - Remove helpful vote
- `PATCH /reviews/:reviewId/privacy` - Update review privacy setting

## Dependencies

The following packages are used (already in pubspec.yaml):
- `flutter/material.dart` - UI framework
- `go_router` - Navigation
- `timeago` - Human-readable time formatting
- `provider` (indirectly via ApiService)

## Design Features
Trust Badges**: Build credibility with visual trust indicators
  - "From people you follow" badge helps users find reviews from their network
  - "Verified Purchase" badge ensures authentic product feedback
  - Smart filtering system to show only trusted reviews
- **
- **Responsive Layout**: Adapts to different screen sizes
- **Dark Mode Support**: Automatically adapts to system theme
- **Material Design 3**: Uses modern Material Design components
- **Accessibility**: Proper contrast ratios and semantic widgets
- **Smooth Animations**: FilterChips and transitions
- **Error Handling**: Graceful error states with retry options

## Color Scheme
Following badge: Blue (AppColors.electricBlue)
- Verified purchase
Uses the app's color theme defined in `AppColors`:
- Primary: `AppColors.electricBlue`
- Card backgrounds: `AppColors.darkCard` (dark mode)
- Verified badge: Green accent
- Star ratings: Amber

## Integration with Existing Features

To integrate reviews into existing product pages, add a button/link:

```dart
// In your product detail page
ElevatedButton(
  onPressed: () => context.push('/products/$productId/reviews'),
  child: Text('See ${product.reviewsCount} Reviews'),
),
```

Or with go_router:
```dart
GoRoute(
  path: '/products/:productId/reviews',
  builder: (context, state) {
    final productId = state.pathParameters['productId']!;
    final productTitle = state.extra as String? ?? 'Product';
    return ReviewsPage(
      productId: productId,
      productTitle: productTitle,
    );
  },
),
```

## Future Enhancements

Potential improvements for future versions:
- Image/video uploads in reviews
- Review reply system
- Report inappropriate reviews
- Filter reviews (verified purchases only, rating ranges)
- Share reviews on social media
- Review editing functionality
- Pagination for large review lists
- Review statistics (most mentioned features, sentiment analysis)
