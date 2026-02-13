# Backend Integration Guide - Profile Picture Upload

## Overview
This guide explains what the frontend expects from the backend image upload endpoint.

## Required Endpoint

### Profile Picture Upload
```
Endpoint: POST /api/uploads/profile-picture
Method: POST
Content-Type: multipart/form-data
Authentication: Not strictly required (frontend sends userId)
```

## Request Format

### Multipart Form Data
```
Field Name: userId
Type: string (form field)
Description: User ID to associate the image with

Field Name: profilePicture
Type: file (binary)
Description: The image file
Accepted Formats: image/jpeg, image/png, image/gif, image/webp
Max Size: Recommended 5MB (frontend compresses to 800x800)
```

### Example cURL Request
```bash
curl -X POST http://51.20.193.95:3000/api/uploads/profile-picture \
  -F "userId=9CO490IH1UR3JRIKL7V1W8CF" \
  -F "profilePicture=@/path/to/image.jpg"
```

## Expected Response

### Success Response (200/201)
```json
{
  "success": true,
  "message": "Image uploaded successfully",
  "imageUrl": "https://51.20.193.95:3000/uploads/profiles/9CO490IH1UR3JRIKL7V1W8CF/image_1234567890.jpg"
}
```

### Response Fields
- `success`: boolean - Indicates if upload was successful
- `message`: string - Human readable message
- `imageUrl`: string - Full URL to access the uploaded image
  - Must be a complete URL (http/https)
  - Image must be accessible via HTTP GET
  - Should persist after upload

### Error Response (4xx/5xx)
```json
{
  "success": false,
  "message": "Error description",
  "imageUrl": ""
}
```

## Implementation Recommendations

### 1. Storage Location
- Store in `/uploads/profiles/{userId}/` directory
- Generate unique filename: `image_{timestamp}.{extension}`
- Example: `/uploads/profiles/9CO490IH1UR3JRIKL7V1W8CF/image_1707738000.jpg`

### 2. Image Processing
- Validate file is actual image (check magic bytes)
- Resize to reasonable dimensions (recommend: 800x800px max)
- Compress to reduce storage (JPEG quality 85 is good)
- Store original or resized version

### 3. Access & Permissions
- Make uploaded images accessible via HTTP GET
- Optionally: Restrict access to image owner
- Consider: CDN for faster delivery
- Base URL: Should match `ApiConstants.imagebaseUrl` = `http://51.20.193.95:3000`

### 4. Database Update (Optional)
- Optionally update user profile table with image URL
- Not required - frontend calls separate complete-profile endpoint
- If updated: Return latest photoURL in response

## Frontend Integration Flow

1. **Upload**
   ```
   POST /api/uploads/profile-picture
   → Returns imageUrl
   ```

2. **Register Image with Profile**
   ```
   POST /api/users/complete-profile
   {
     "userId": "...",
     "photoURL": "{imageUrl from step 1}"
   }
   → User trust_score.profile_image increases
   ```

## Frontend Expected Behavior

After successful upload:
1. Frontend receives imageUrl
2. Frontend calls `/api/users/complete-profile` with imageUrl
3. User's trust_score increases (profile_image +1)
4. Profile picture displayed in app avatar (network image)
5. Profile completion percentage increases

## Validation Requirements

### Frontend Validates
- File size (< 10MB recommended)
- File type (image only)
- Image dimensions (reasonable bounds)

### Backend Should Validate
- userId exists in system
- File is actual image
- File size reasonable
- Virus scan (if applicable)

## Example Node.js/Express Implementation

```javascript
app.post('/api/uploads/profile-picture', upload.single('profilePicture'), async (req, res) => {
  try {
    const { userId } = req.body;
    
    // Validate userId
    if (!userId) {
      return res.status(400).json({ 
        success: false, 
        message: 'userId is required',
        imageUrl: ''
      });
    }
    
    // Check file uploaded
    if (!req.file) {
      return res.status(400).json({ 
        success: false, 
        message: 'No file uploaded',
        imageUrl: ''
      });
    }
    
    // Process image (resize, compress, etc.)
    const processedImagePath = await processImage(req.file);
    
    // Generate URL
    const imageUrl = `http://51.20.193.95:3000${processedImagePath}`;
    
    // Optionally update database
    // await User.updateOne(
    //   { _id: userId },
    //   { photoURL: imageUrl }
    // );
    
    res.status(200).json({
      success: true,
      message: 'Image uploaded successfully',
      imageUrl: imageUrl
    });
    
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Upload failed',
      imageUrl: ''
    });
  }
});
```

## Testing the Endpoint

### Using Postman
1. Create POST request to `http://51.20.193.95:3000/api/uploads/profile-picture`
2. Go to Body → form-data
3. Add:
   - Key: `userId`, Value: `9CO490IH1UR3JRIKL7V1W8CF`, Type: text
   - Key: `profilePicture`, Value: [select image file], Type: file
4. Send request
5. Verify response has `success: true` and `imageUrl`

### Using cURL
```bash
curl -X POST http://51.20.193.95:3000/api/uploads/profile-picture \
  -F "userId=9CO490IH1UR3JRIKL7V1W8CF" \
  -F "profilePicture=@/Users/username/Downloads/profile.jpg"
```

## Troubleshooting

### Frontend Issue: "Failed to upload profile image"
- **Cause**: Endpoint not responding or wrong format
- **Check**: 
  - Endpoint exists and accessible
  - Response has `success`, `message`, `imageUrl` fields
  - Returns 200 or 201 status code

### Frontend Issue: "Image upload functionality coming soon"
- **Cause**: Old code with placeholder message
- **Solution**: Update ProfileDetailsPage.dart - should be already implemented

### Frontend Issue: "Profile picture displays as placeholder icon"
- **Cause**: photoURL is null or image URL is invalid
- **Check**:
  - Image URL is complete (starts with http://)
  - Image file exists and is accessible
  - CORS headers allow frontend access

### Frontend Issue: Trust score doesn't increase after upload
- **Cause**: complete-profile endpoint not called or failed
- **Check**:
  - POST /api/users/complete-profile is called with imageUrl
  - Backend updates trust_score.profile_image value
  - User profile fetched after to get updated score

## Additional Notes

- Frontend caches image in app after download
- Upload progress is tracked and shown to user
- Uploading same image twice will create duplicate files (consider deduplication)
- Consider implementing image CDN for better performance
- Implement rate limiting on upload endpoint
- Add malware scanning for production

## Support

For issues with image upload integration:
1. Check request/response format matches specification
2. Verify endpoint is accessible from frontend
3. Check backend logs for detailed error messages
4. Ensure CORS is configured if frontend and backend on different domains
