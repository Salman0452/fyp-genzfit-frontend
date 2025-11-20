# Cloudinary Setup Guide for GenZFit

## Why Cloudinary?
We're using Cloudinary instead of Firebase Storage because:
- Firebase Storage requires a paid plan (Blaze)
- Cloudinary offers a generous **free tier** with 25GB storage and 25GB bandwidth/month
- Perfect for development and testing

## Setup Steps

### 1. Create Cloudinary Account
1. Go to [https://cloudinary.com/users/register/free](https://cloudinary.com/users/register/free)
2. Sign up for a free account
3. Verify your email

### 2. Get Your Credentials
1. Go to your Cloudinary Dashboard
2. You'll see:
   - **Cloud Name** (e.g., `dxxxxxx`)
   - **API Key**
   - **API Secret**

### 3. Create an Upload Preset
1. In Cloudinary Dashboard, go to **Settings** → **Upload**
2. Scroll down to **Upload presets**
3. Click **Add upload preset**
4. Configure:
   - **Preset name**: `genzfit_preset` (or any name you prefer)
   - **Signing mode**: Select **Unsigned** (important!)
   - **Folder**: Leave empty or set a default folder
5. Click **Save**

### 4. Update the Code
Open `lib/services/storage_service.dart` and replace:

```dart
static const String _cloudName = 'YOUR_CLOUD_NAME'; // Replace with your cloud name
static const String _uploadPreset = 'genzfit_preset'; // Replace with your preset name
```

With your actual values:

```dart
static const String _cloudName = 'dxxxxxx'; // Your actual cloud name
static const String _uploadPreset = 'genzfit_preset'; // Your actual preset name
```

### 5. Install Dependencies
Run:
```bash
flutter pub get
```

### 6. Test Upload
Run your app and try:
- Uploading a profile picture
- Taking a body scan
- Uploading a certificate (for trainers)

## Cloudinary Features Used

### Image Upload
- Profile pictures
- Body scan photos
- Certificates
- Chat images

### Video Upload (Future)
- Trainer workout videos
- Tutorial videos

### Folder Structure
Images are organized in folders:
- `profile_pictures/{userId}/`
- `body_scans/{userId}/`
- `certificates/{trainerId}/`
- `chat_images/{chatId}/`
- `trainer_videos/{trainerId}/`

## Cloudinary Free Tier Limits
- **Storage**: 25 GB
- **Bandwidth**: 25 GB/month
- **Transformations**: 25 credits/month
- **Images/Videos**: Unlimited

## Optional: Use Environment Variables (Recommended)

For better security, you can use environment variables:

1. Add to your `.env` file:
```
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_UPLOAD_PRESET=genzfit_preset
```

2. Update `storage_service.dart`:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

static final String _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'YOUR_CLOUD_NAME';
static final String _uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? 'genzfit_preset';
```

## Troubleshooting

### "Upload failed" error
- Check your cloud name and upload preset are correct
- Ensure the preset is set to **Unsigned**
- Check your internet connection

### Images not showing
- Verify the URL returned from upload
- Check Cloudinary dashboard to see if images were uploaded
- Try opening the URL directly in a browser

### Quota exceeded
- Check your Cloudinary dashboard usage
- Free tier: 25GB bandwidth/month
- Consider upgrading if needed

## Migration from Firebase Storage

If you had data in Firebase Storage:
1. Download all images from Firebase
2. Upload them to Cloudinary using their API or dashboard
3. Update Firestore URLs to point to Cloudinary URLs

## Support
- Cloudinary Docs: https://cloudinary.com/documentation
- Cloudinary Support: https://support.cloudinary.com
