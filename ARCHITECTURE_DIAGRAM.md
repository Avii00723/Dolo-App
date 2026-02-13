# Architecture & Integration Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        DOLO APP - PROFILE MODULE                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────┐
│   USER INTERFACE LAYER  │
├─────────────────────────┤
│  ProfilePage (Main)     │ ← Shows profile overview
│      ├── Avatar         │ ← Displays user picture
│      ├── Stats Row      │ ← Shows "X/7" trust score
│      ├── TrustScoreWidget│ ← Full breakdown
│      └── Completion Bar │ ← Progress + cards
│                         │
│  ProfileDetailsPage     │ ← Edit profile page
│      ├── Image Picker   │ ← Camera/Gallery
│      ├── Upload Flow    │ ← Progress display
│      └── Save Button    │ ← Call APIs
└─────────────────────────┘
         ↓
┌─────────────────────────┐
│  WIDGET LAYER (NEW)     │
├─────────────────────────┤
│  TrustScoreWidget       │ ← Reusable component
│      ├── Compact View   │ ← Inline display
│      └── Detailed View  │ ← Full breakdown
└─────────────────────────┘
         ↓
┌─────────────────────────┐
│  SERVICE LAYER (NEW)    │
├─────────────────────────┤
│ ImageUploadService      │ ← File upload
│   └─ uploadProfile()    │ ← Multipart POST
│                         │
│ ProfileService (exists) │ ← User data
│   ├─ getProfile()       │
│   ├─ getTrustScore()    │
│   └─ updateProfile()    │
│                         │
│ LoginService (exists)   │ ← Auth
│   └─ completeProfile()  │
└─────────────────────────┘
         ↓
┌─────────────────────────┐
│   MODEL LAYER           │
├─────────────────────────┤
│ TrustScore (UPDATED)    │ ← Enhanced with helpers
│   ├─ phoneVerification  │
│   ├─ emailVerification  │
│   ├─ profileImage       │
│   ├─ kycVerification    │
│   ├─ isPhoneVerified    │
│   ├─ isEmailVerified    │
│   ├─ isProfileImageUp   │
│   ├─ isKycVerified      │
│   └─ completionPercentage│
│                         │
│ UserProfile (exists)    │
│   └─ photoURL           │
└─────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│      API/NETWORK LAYER               │
├──────────────────────────────────────┤
│ GET  /users/profile/{userId}         │
│ POST /uploads/profile-picture ⭐     │
│ POST /users/complete-profile         │
│ GET  /users/trust-score/{userId}     │
│ PUT  /users/profile/{userId}         │
└──────────────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│      BACKEND SERVER                  │
├──────────────────────────────────────┤
│  http://51.20.193.95:3000/api        │
└──────────────────────────────────────┘
```

## Data Flow Diagram

### User Upload Flow
```
┌─────────┐
│  User   │
└────┬────┘
     │ "Edit Profile"
     ↓
┌──────────────────────┐
│ ProfileDetailsPage   │
├──────────────────────┤
│ - Show current info  │
│ - Tap to change pic  │
└────┬────────────────┘
     │ "Select Image"
     ↓
┌──────────────────────┐
│  ImagePicker        │
├──────────────────────┤
│ - Camera option     │
│ - Gallery option    │
└────┬────────────────┘
     │ Image selected
     ↓
┌──────────────────────────────────────┐
│  ImageUploadService                  │
├──────────────────────────────────────┤
│ uploadProfilePicture()               │
│ - Create multipart request           │
│ - Add userId field                   │
│ - Add file with MIME type            │
│ - Track progress (0.0 → 1.0)         │
└────┬──────────────────────────────────┘
     │ Progress: 0-100%
     ↓ (shown in UI)
┌──────────────────────────────────────┐
│  POST /api/uploads/profile-picture   │
├──────────────────────────────────────┤
│ Request: userId, profilePicture file │
│ Response: imageUrl                   │
└────┬──────────────────────────────────┘
     │ Image URL received
     ↓
┌──────────────────────────────────────┐
│  Profile Update                      │
├──────────────────────────────────────┤
│ 1. PUT /users/profile/{id} (name)    │
│ 2. POST /complete-profile (imageUrl) │
└────┬──────────────────────────────────┘
     │ Success
     ↓
┌──────────────────────────────────────┐
│  ProfilePage Refresh                 │
├──────────────────────────────────────┤
│ 1. GET /users/profile/{id}           │
│ 2. GET /users/trust-score/{id}       │
│ 3. Display new picture               │
│ 4. Update completion bar             │
└──────────────────────────────────────┘
     │
     ↓
┌──────────────────────────────────────┐
│  ✓ Profile Picture Uploaded          │
│  ✓ Trust Score Updated               │
│  ✓ Avatar Shows Picture              │
│  ✓ Profile Completion Increased      │
└──────────────────────────────────────┘
```

### Trust Score Display Flow
```
┌──────────────────────────────────────┐
│  ProfilePage.initState()             │
├──────────────────────────────────────┤
│ Load user data on page load          │
└────┬──────────────────────────────────┘
     │
     ↓
┌──────────────────────────────────────┐
│  ProfileService.getTrustScore()      │
├──────────────────────────────────────┤
│ GET /api/users/trust-score/{userId}  │
└────┬──────────────────────────────────┘
     │
     ↓
┌──────────────────────────────────────┐
│  API Response (snake_case)           │
├──────────────────────────────────────┤
│ {                                    │
│   "trust_score": 6,                  │
│   "max_score": 7,                    │
│   "breakdown": {                     │
│     "phone": 2,                      │
│     "email": 1,                      │
│     "profile_image": 0,              │
│     "kyc": 3                         │
│   }                                  │
│ }                                    │
└────┬──────────────────────────────────┘
     │
     ↓
┌──────────────────────────────────────┐
│  TrustScore.fromJson()               │
├──────────────────────────────────────┤
│ Parse response                       │
│ Extract breakdown values             │
│ Calculate completion percentage      │
│ Set verification flags               │
└────┬──────────────────────────────────┘
     │ TrustScore object created
     ↓
┌──────────────────────────────────────┐
│  Display in Multiple Places          │
├──────────────────────────────────────┤
│ 1. Stats Row                         │
│    └─ "6/7"                          │
│                                      │
│ 2. TrustScoreWidget (Detailed)       │
│    ├─ Score badge: 6/7               │
│    ├─ Progress: 86%                  │
│    └─ Breakdown:                     │
│        ├─ Phone: ✓ +2                │
│        ├─ Email: ✓ +1                │
│        ├─ Picture: ✗ +0              │
│        └─ KYC: ✓ +3                  │
│                                      │
│ 3. Completion Bar                    │
│    ├─ Progress bar: ████████░░░░░░   │
│    └─ Percentage: 86%                │
│                                      │
│ 4. Completion Cards                  │
│    ├─ Picture: [Upload] (pending)    │
│    ├─ Email: [Continue] (pending)    │
│    └─ KYC: [Completed] ✓             │
└──────────────────────────────────────┘
```

## Component Integration Map

```
┌────────────────────────────────────────────────────────────────┐
│                       ProfilePage                              │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐  ┌──────────────────┐                   │
│  │  Avatar Display  │  │  Stats Row       │                   │
│  ├──────────────────┤  ├──────────────────┤                   │
│  │ Shows picture if │  │ Trust: "X/7"     │                   │
│  │ available        │  │ Delivered, etc.  │                   │
│  │ Fallback to icon │  │                  │                   │
│  └────────┬─────────┘  └──────────────────┘                   │
│           │                                                   │
│           └─────────────────┬──────────────────────           │
│                             ↓                                 │
│              ┌──────────────────────────┐                     │
│              │ TrustScoreWidget         │                     │
│              ├──────────────────────────┤                     │
│              │ Score: 6/7, 86%          │                     │
│              │ Breakdown:               │                     │
│              │ - Phone ✓ +2             │                     │
│              │ - Email ✓ +1             │                     │
│              │ - Picture ✗ +0           │                     │
│              │ - KYC ✓ +3               │                     │
│              └──────────────────────────┘                     │
│                             │                                 │
│                             ↓                                 │
│              ┌──────────────────────────┐                     │
│              │ Completion Bar           │                     │
│              ├──────────────────────────┤                     │
│              │ 86% Complete             │                     │
│              │ ████████░░░░░░           │                     │
│              └──────────────────────────┘                     │
│                             │                                 │
│                             ↓                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                        │
│  │ Picture │  │ Email   │  │ KYC     │                        │
│  │[Upload] │  │[Cont]   │  │[Complete│                       │
│  │ Pending │  │ Pending │  │ Done ✓  │                       │
│  └─────────┘  └─────────┘  └─────────┘                        │
└────────────────────────────────────────────────────────────────┘
```

## File Dependency Graph

```
profilescreen.dart (UI)
    ├─ imports: TrustScoreWidget
    ├─ imports: ProfileService
    ├─ imports: AuthService
    ├─ uses: UserProfile model
    └─ uses: TrustScore model

ProfileDetailsPage.dart (UI)
    ├─ imports: ImageUploadService (NEW)
    ├─ imports: ProfileService
    ├─ imports: LoginService
    ├─ uses: UserProfile model
    └─ calls: completeProfile()

TrustScoreWidget.dart (NEW WIDGET)
    └─ imports: TrustScore model
       └─ displays: breakdown data

ImageUploadService.dart (NEW SERVICE)
    └─ returns: ImageUploadResponse

TrustScoreModel.dart (ENHANCED MODEL)
    ├─ added: helper getters
    ├─ added: verification checkers
    ├─ added: percentage calculator
    └─ improved: JSON parsing

ProfileService.dart (SERVICE - existing)
    ├─ has: getUserProfile()
    ├─ has: getUserTrustScore()
    └─ has: updateUserProfile()

LoginService.dart (SERVICE - existing)
    └─ has: completeProfile()
```

## API Request/Response Cycle

```
CLIENT                          SERVER
  │                               │
  │ 1. Upload Image               │
  ├──────────────────────────────>│
  │    POST /uploads/profile-pic  │
  │    FormData: userId, file     │
  │                               │
  │                    ✓ Process  │
  │                    ✓ Store    │
  │                    ✓ Generate │
  │                               │
  │<─ Response imageUrl ───────────│
  │    { success, message, url }  │
  │                               │
  │ 2. Update Profile             │
  ├──────────────────────────────>│
  │    PUT /users/profile/{id}    │
  │    { name: "..." }            │
  │                               │
  │                    ✓ Update   │
  │                               │
  │<─ Success response ────────────│
  │                               │
  │ 3. Complete Profile           │
  ├──────────────────────────────>│
  │    POST /complete-profile     │
  │    { userId, photoURL }       │
  │                               │
  │                    ✓ Register │
  │                    ✓ +1 score │
  │                               │
  │<─ Success response ────────────│
  │                               │
  │ 4. Fetch Profile              │
  ├──────────────────────────────>│
  │    GET /users/profile/{id}    │
  │                               │
  │<─ User data with photoURL ────│
  │                               │
  │ 5. Fetch Trust Score          │
  ├──────────────────────────────>│
  │    GET /users/trust-score/id  │
  │                               │
  │<─ { trust_score, breakdown }──│
  │    Profile picture now in UI  │
  └──────────────────────────────┘
```

## State Management Flow

```
ProfilePage State
├─ isLoading: bool
├─ userProfile: UserProfile?
├─ trustScoreData: TrustScore?
└─ refresh trigger on:
   ├─ initState()
   ├─ User returns from Edit
   └─ Pull to refresh

ProfileDetailsPage State
├─ _newProfileImage: File?
├─ _isUpdating: bool
├─ _isUploadingImage: bool
├─ _uploadProgress: double
└─ triggers:
   ├─ Image picker
   ├─ Save button
   ├─ Upload progress
   └─ Return to parent
```

---

This architecture ensures:
- ✅ Clean separation of concerns
- ✅ Reusable components
- ✅ Scalable data flow
- ✅ Error handling at each layer
- ✅ Real-time UI updates
- ✅ Efficient API usage
