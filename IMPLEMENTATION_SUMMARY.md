# Profile Picture Upload & Trust Score Implementation Guide

## Overview
This document describes the implementation of profile picture uploading, complete profile bar, and trust score widgets functionality for the Dolo app.

## Changes Made

### 1. **ImageUploadService** (`lib/Controllers/ImageUploadService.dart`)
**New File Created**
- Handles multipart file uploads for profile pictures
- Uploads to endpoint: `POST /api/uploads/profile-picture`
- Returns image URL for use with complete-profile endpoint
- Includes progress tracking capability
- Supports: JPEG, PNG, GIF, WebP formats

**Key Features:**
```dart
uploadProfilePicture({
  required String userId,
  required File imageFile,
  Function(double)? onProgress,
}) → ImageUploadResponse?
```

### 2. **ProfileDetailsPage** (`lib/screens/ProfileSection/ProfileDetailPage.dart`)
**Updated to Support Image Upload**

#### Changes:
- Added `ImageUploadService` import and instance
- Added `_isUploadingImage` and `_uploadProgress` state variables
- Updated `_updateProfile()` to:
  1. Upload profile picture first (if selected)
  2. Update user profile with name
  3. Call complete-profile API with image URL
  4. Return true on success for profile refresh
- Created `_uploadProfileImage()` that:
  1. Uploads image using ImageUploadService
  2. Tracks upload progress
  3. Returns image URL on success
- Updated Save button to:
  1. Show upload progress percentage
  2. Disable while uploading
  3. Display spinning loader during upload

#### User Flow:
1. User taps edit button on profile
2. Opens ProfileDetailsPage
3. User can change name and select new profile picture
4. Taps Save
5. Image uploads first with progress indicator
6. Profile data updates with name
7. complete-profile API called with image URL
8. Returns to profile page with refreshed data

### 3. **TrustScoreModel** (`lib/Models/TrustScoreModel.dart`)
**Enhanced with Helper Methods**

#### Updates:
- Fixed JSON parsing to handle both snake_case and camelCase keys:
  - `trust_score` / `trustScore`
  - `max_score` / `maxScore`
- Added helper getters:
  - `phoneVerification` - int value from breakdown['phone']
  - `emailVerification` - int value from breakdown['email']
  - `profileImage` - int value from breakdown['profile_image']
  - `kycVerification` - int value from breakdown['kyc']
- Added boolean checkers:
  - `isPhoneVerified` - returns true if phoneVerification > 0
  - `isEmailVerified` - returns true if emailVerification > 0
  - `isProfileImageUploaded` - returns true if profileImage > 0
  - `isKycVerified` - returns true if kycVerification > 0
- Added `completionPercentage` - calculated as (trustScore / maxScore) * 100

#### API Response Parsing:
```dart
// Now handles both response formats
{
  "trust_score": 6,
  "max_score": 7,
  "breakdown": {
    "phone": 2,
    "email": 1,
    "profile_image": 0,
    "kyc": 3
  }
}
```

### 4. **TrustScoreWidget** (`lib/widgets/TrustScoreWidget.dart`)
**New Reusable Widget Component**

#### Features:
- **Two View Modes:**
  - **Compact Mode**: Minimal display with score and progress bar
  - **Detailed Mode**: Full breakdown with verification status

- **Compact View Display:**
  - Score badge: "X/7"
  - Linear progress bar
  - Space-efficient for inline use

- **Detailed View Display:**
  - Score badge with percentage
  - Progress bar with completion percentage
  - Verification breakdown section with:
    - Phone Verification status and points
    - Email Verification status and points
    - Profile Picture status and points
    - KYC Verification status and points
  - Each item shows:
    - Icon and status label
    - "Verified" or "Not verified" text
    - Points awarded (+X)
    - Color-coded (green for verified, gray for pending)

#### Usage:
```dart
// Compact version for inline display
TrustScoreWidget(
  trustScore: trustScoreData,
  isCompact: true,
)

// Detailed version for profile section
TrustScoreWidget(
  trustScore: trustScoreData,
  showBreakdown: true,
  isCompact: false,
)
```

### 5. **ProfilePage** (`lib/screens/ProfileSection/profilescreen.dart`)
**Major Updates for Trust Score Integration**

#### Imports Added:
- `TrustScoreWidget` for rendering trust score UI

#### Profile Completion Methods Updated:
```dart
_isProfilePictureUploaded() → uses trustScoreData.isProfileImageUploaded
_isEmailVerified() → uses trustScoreData.isEmailVerified
_isKycCompleted() → uses _isKycVerified()
```

#### UI Enhancements:

1. **Profile Avatar Section:**
   - Now displays user's profile picture if available
   - Falls back to default person icon if no picture
   - Shows loading indicator while loading image
   - Shows error handling with fallback icon
   - Displays KYC verified badge or "Unverified" label

2. **Stats Row:**
   - Trust Score now displays: "X/7" from trustScoreData
   - Updates dynamically when profile is refreshed

3. **Trust Score Widget Display:**
   - Added full TrustScoreWidget in detailed mode
   - Shows between stats and completion section
   - Displays breakdown of all verification components

4. **Profile Completion Bar:**
   - Now uses real trustScoreData instead of hardcoded values
   - Progress bar reflects actual trust score percentage
   - Completion percentage matches API data
   - Shows only if completion < 100%
   - Cards show correct completion status:
     - Profile Picture: checks isProfileImageUploaded
     - Email: checks isEmailVerified
     - KYC: checks isKycVerified

#### Profile Picture Display Logic:
```dart
// In CircleAvatar
if (userProfile?.photoURL != null && userProfile!.photoURL.isNotEmpty)
  // Display network image with error handling
else
  // Display default person icon
```

## API Endpoints Used

### 1. Profile Picture Upload
```
POST /api/uploads/profile-picture
Content-Type: multipart/form-data

Fields:
- userId (string)
- profilePicture (file)

Response:
{
  "message": "Image uploaded successfully",
  "imageUrl": "https://...",
  "success": true
}
```

### 2. Complete Profile
```
POST /api/users/complete-profile
Content-Type: application/json

Body:
{
  "userId": "...",
  "photoURL": "https://..."
}

Response:
{
  "message": "Profile completed successfully",
  "profileCompleted": true
}
```

### 3. Get User Trust Score
```
GET /api/users/trust-score/{userId}

Response:
{
  "trust_score": 6,
  "max_score": 7,
  "breakdown": {
    "phone": 2,
    "email": 1,
    "profile_image": 0,
    "kyc": 3
  }
}
```

## Implementation Details

### File Upload Flow
1. User selects image from camera/gallery in ProfileDetailsPage
2. Image stored in `_newProfileImage` File variable
3. On Save click:
   - Image uploaded via ImageUploadService
   - Progress tracked and displayed
   - Returns image URL
   - Profile data updated
   - complete-profile API called with URL
   - Profile page refreshed

### Trust Score Display Flow
1. ProfilePage loads user data on init
2. Fetches trustScoreData from API
3. Displays in multiple places:
   - Stats box: "X/7" format
   - TrustScoreWidget: Full breakdown
   - Completion cards: Shows individual status
4. Updates when user refreshes profile

### Profile Picture Display
1. Checks userProfile.photoURL on render
2. If URL exists and valid:
   - Loads network image
   - Shows loading indicator
   - Falls back to icon on error
3. If no URL:
   - Shows default person icon
4. Always displays in circular format

## User Experience Improvements

### 1. **Clear Progress Feedback**
- Image upload shows real-time progress percentage
- Upload button becomes disabled during process
- Spinner with percentage text displayed

### 2. **Visual Trust Score**
- Color-coded verification items (green = verified, gray = pending)
- Clear breakdown of which steps are complete
- Progress bar shows overall completion
- Icons help identify each verification type

### 3. **Profile Picture Integration**
- Profile avatar updates when picture is uploaded
- Network image handles errors gracefully
- Loading state visible to user
- Real photo increases user trust score for profile_image

### 4. **Responsive UI**
- All widgets responsive to screen size
- Scrollable breakdown on narrow screens
- Touch-friendly buttons and controls

## Testing Checklist

- [ ] Upload profile picture via camera
- [ ] Upload profile picture via gallery
- [ ] Verify upload progress indicator shows
- [ ] Verify profile picture displays in avatar
- [ ] Verify trust score updates after upload
- [ ] Verify profile_image breakdown shows as completed
- [ ] Verify profile completion percentage increases
- [ ] Verify trust score widget shows all breakdowns
- [ ] Verify KYC verified badge displays
- [ ] Verify profile refresh pulls latest data
- [ ] Test image error handling (invalid URL)
- [ ] Test image loading state
- [ ] Verify stats box shows correct trust score

## Notes

- Image upload endpoint must exist and return imageUrl
- Trust score API returns snake_case keys (trust_score, profile_image)
- Profile pictures must be 100x100px minimum
- Supported formats: JPEG, PNG, GIF, WebP
- Maximum image size should be enforced on upload

## Future Enhancements

1. Add image compression before upload
2. Add image crop functionality
3. Add email verification UI
4. Add KYC verification deep integration
5. Add trust score animations
6. Add share profile feature
7. Add profile statistics dashboard
