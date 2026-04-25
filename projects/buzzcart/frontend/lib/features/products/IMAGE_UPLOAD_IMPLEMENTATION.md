# Review Image Upload Implementation

## Overview
This document describes the implementation of image upload functionality for product reviews in the Like2Share application.

## Features Implemented

### 1. Data Model Enhancement
**File**: `lib/core/models/models.dart`

Added `images` field to `ReviewModel`:
```dart
final List<String> images; // List of image URLs
```

- Handles JSON serialization/deserialization
- Defaults to empty list if not present
- Stores image URLs returned from the backend

### 2. API Service Updates
**File**: `lib/core/services/api_service.dart`

#### Updated Method: `createReview`
- Added optional `imageUrls` parameter
- Conditionally includes images in the POST request

#### New Method: `uploadReviewImage`
```dart
Future<String> uploadReviewImage(XFile image)
```

- Uploads images using multipart form data
- Endpoint: `POST /upload/review-image`
- Returns the uploaded image URL
- Handles file upload with proper content type

### 3. Review Submission Form
**File**: `lib/features/products/widgets/write_review_dialog.dart`

#### New Features:
- **Image Picker Integration**: 
  - Camera capture
  - Gallery selection
  - Maximum 5 images per review
  
- **Image Preview**:
  - 80x80 thumbnail grid
  - Remove button on each image
  - Image count display (e.g., "3/5 images")
  
- **Image Upload Flow**:
  1. User selects images from camera or gallery
  2. Images are previewed locally
  3. On submit, images are uploaded first
  4. Image URLs are passed to `createReview` API
  5. Review is created with image references

#### Technical Details:
- Uses `image_picker` package (v1.0.7)
- Images are compressed (maxWidth: 1920, maxHeight: 1920, quality: 85%)
- Sequential upload with error handling
- Upload failures don't block the entire submission

#### UI Components:
- Two-button layout: Camera | Gallery
- Responsive image grid with remove buttons
- Loading state during submission
- Error handling with user feedback

### 4. Review Display
**File**: `lib/features/products/widgets/review_card.dart`

#### Image Gallery:
- **Horizontal scrollable list** of review images
- 100x100 thumbnails with rounded corners
- Tap to view full-screen
- Error handling for failed image loads

#### Full-Screen Image Viewer:
- Dedicated `_ImageViewerPage` widget
- Features:
  - Swipe navigation between images
  - Pinch-to-zoom (0.5x to 4x)
  - Image counter (e.g., "2 of 5")
  - Black background for focus
  - Error state for failed loads

## User Flow

### Submitting a Review with Images:

1. User opens "Write a Review" dialog
2. User selects star rating
3. User enters title and/or review text (optional)
4. User taps "Camera" or "Gallery" button
5. User selects an image
6. Image appears as a thumbnail below the buttons
7. User can:
   - Add more images (up to 5 total)
   - Remove any image by tapping the X button
   - See the count "3/5 images"
8. User submits review
9. System uploads images sequentially
10. System creates review with image URLs
11. Success message displayed

### Viewing Review Images:

1. User sees review with image thumbnails in horizontal scroll
2. User taps any thumbnail
3. Full-screen viewer opens showing the image
4. User can:
   - Swipe left/right to navigate images
   - Pinch to zoom (0.5x to 4x scale)
   - See current position "2 of 5"
5. User taps back button to return to reviews

## Technical Specifications

### Image Constraints:
- Maximum images per review: 5
- Maximum dimensions: 1920x1920 pixels
- Image quality: 85%
- Supported sources: Camera, Gallery

### Image Storage:
- Images uploaded to backend storage
- URLs stored in database
- Backend endpoint: `/upload/review-image`

### Error Handling:
- Image picker errors: User-facing snackbar
- Upload failures: Continue with remaining images
- Network image load errors: Fallback broken image icon
- Missing images: Gracefully hide gallery section

## Dependencies

Required packages in `pubspec.yaml`:
```yaml
image_picker: ^1.0.7  # Already installed
```

## Backend Requirements

The backend must provide:

1. **POST /upload/review-image** endpoint
   - Accepts multipart form data with `image` field
   - Returns JSON: `{ "url": "https://..." }`
   - Handles image storage (cloud storage, CDN, etc.)

2. **POST /products/:id/reviews** endpoint
   - Accepts `images` array in request body
   - Stores image URLs in database

3. **GET /products/:id/reviews** endpoint
   - Returns reviews with `images` array
   - Each image is a full URL string

## Database Schema

The reviews table should include:

```sql
CREATE TABLE reviews (
    -- ... other fields ...
    images TEXT[], -- Array of image URLs
);
```

## Future Enhancements

Potential improvements:
1. Image compression on device before upload
2. Multiple image selection at once
3. Image editing (crop, rotate, filters)
4. Progress indicator during upload
5. Retry failed uploads
6. Image caching for better performance
7. Share review images
8. Report inappropriate images
9. Image alt text for accessibility
10. Video support

## Testing Checklist

- [ ] Select image from camera
- [ ] Select image from gallery
- [ ] Add multiple images (up to 5)
- [ ] Remove individual images
- [ ] Attempt to add 6th image (should show error)
- [ ] Submit review with images
- [ ] Submit review without images
- [ ] View review with images
- [ ] Tap image to view full-screen
- [ ] Navigate between images in viewer
- [ ] Zoom in/out on images
- [ ] Handle failed image uploads
- [ ] Handle failed image loads in UI
- [ ] Test on different screen sizes
- [ ] Test in dark mode
- [ ] Test with poor network connection

## Files Modified

1. `lib/core/models/models.dart` - Added images field to ReviewModel
2. `lib/core/services/api_service.dart` - Added uploadReviewImage method, updated createReview
3. `lib/features/products/widgets/write_review_dialog.dart` - Added image picker and upload
4. `lib/features/products/widgets/review_card.dart` - Added image gallery and viewer

## Summary

The image upload feature is fully integrated into the review system with a user-friendly interface for capturing, selecting, previewing, uploading, and viewing review images. The implementation follows Flutter best practices with proper error handling, loading states, and responsive design that works in both light and dark modes.
