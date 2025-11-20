# Getting Your Gemini API Key

## Quick Setup Guide

### Step 1: Visit Google AI Studio
Go to: https://makersuite.google.com/app/apikey

### Step 2: Sign In
- Use your Google account
- Accept terms and conditions

### Step 3: Create API Key
1. Click "Create API Key" button
2. Select "Create API key in new project" (or use existing project)
3. Copy the generated API key

### Step 4: Add to Your Project
1. Open `.env` file in the project root
2. Replace `YOUR_GEMINI_API_KEY_HERE` with your actual key:
   ```
   GEMINI_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
   ```
3. Save the file

### Step 5: Restart Your App
```bash
flutter run
```

## Important Notes

⚠️ **Security:**
- Never commit your API key to version control
- The `.env` file is already in `.gitignore`
- For production, use Cloud Functions or backend API

⚠️ **Free Tier Limits:**
- Gemini API has free tier with rate limits
- Check current limits at: https://ai.google.dev/pricing

⚠️ **API Key Restrictions:**
- Consider adding API key restrictions in Google Cloud Console
- Restrict by app package name for Android
- Restrict by bundle ID for iOS

## Testing Your API Key

Run the app and:
1. Navigate to "AI Recommendations"
2. If you see meal and exercise recommendations → ✅ Working!
3. If you see default recommendations → ⚠️ Check your API key

## Troubleshooting

### "GEMINI_API_KEY not found in .env file"
- Make sure `.env` file exists in project root
- Check spelling: `GEMINI_API_KEY` (exact case)
- Restart the app after adding the key

### "API key not valid"
- Verify you copied the complete key
- No extra spaces or quotes
- Key should start with `AIza`

### "Quota exceeded"
- You've hit the free tier limit
- Wait for quota reset or upgrade to paid tier

## Alternative: Use Backend (Recommended for Production)

Instead of storing the API key in the app:

1. Create a Cloud Function or Express backend
2. Store API key securely on server
3. App makes request to your backend
4. Backend calls Gemini API and returns results

This approach:
- ✅ Keeps API key secure
- ✅ Allows better rate limiting
- ✅ Enables caching
- ✅ Provides usage analytics

## Resources

- **Google AI Studio:** https://makersuite.google.com
- **Gemini API Docs:** https://ai.google.dev/docs
- **Pricing:** https://ai.google.dev/pricing
- **Flutter Package:** https://pub.dev/packages/google_generative_ai
