# Quick Start - Local Testing (No Firebase Required!)

Run your 3D avatar backend locally in **2 minutes** without any cloud setup.

## Option 1: Local-Only Mode (Simplest)

No storage, no cloud accounts needed. Perfect for testing avatar generation.

```bash
# 1. Activate virtual environment
cd backend
source venv/bin/activate  # On macOS/Linux

# 2. Run the server
python main_simple.py

# 3. Open browser
open http://localhost:8000/docs
```

✅ **That's it!** Test the API at http://localhost:8000/docs

Avatar generation works, but URLs will be `local://...` (no actual file storage).

---

## Option 2: With Cloudinary Storage (Recommended)

Get free cloud storage for your 3D avatars. Takes 3 minutes to setup.

### Step 1: Get Free Cloudinary Account

1. Go to https://cloudinary.com/users/register_free
2. Sign up (free forever - no credit card)
3. After login, go to Dashboard
4. Copy these values:
   - **Cloud Name**
   - **API Key** 
   - **API Secret**

### Step 2: Configure

```bash
# Create .env file
cp .env.simple .env

# Edit .env and add your Cloudinary credentials:
CLOUDINARY_CLOUD_NAME=your_cloud_name_here
CLOUDINARY_API_KEY=your_api_key_here
CLOUDINARY_API_SECRET=your_api_secret_here
```

### Step 3: Run

```bash
# Activate venv
source venv/bin/activate

# Run server
python main_simple.py
```

✅ **Done!** Your avatars will now be stored in Cloudinary cloud.

---

## Testing the API

### 1. Health Check
```bash
curl http://localhost:8000/health
```

### 2. Generate Avatar (via Swagger UI)

Open http://localhost:8000/docs and try the `/api/v1/avatar/generate` endpoint with:

```json
{
  "user_id": "test_user_123",
  "height": 175,
  "weight": 70,
  "age": 25,
  "gender": "male",
  "body_fat_percentage": 15
}
```

### 3. Update Avatar Physique

Use `/api/v1/avatar/update-physique` to see body changes:

```json
{
  "user_id": "test_user_123",
  "current_day": 7,
  "current_weight": 72,
  "current_body_fat_percentage": 14,
  "gender": "male",
  "nutrition_data": {
    "calories": 2500,
    "protein": 150,
    "carbs": 250,
    "fats": 70
  },
  "exercise_data": {
    "calories_burned": 300
  }
}
```

---

## What You Get

### Local-Only Mode:
- ✅ Avatar generation works
- ✅ Body morphing calculations
- ✅ Nutrition analysis
- ❌ No file storage (URLs are `local://...`)
- ❌ No progress history

### With Cloudinary:
- ✅ Avatar generation
- ✅ Body morphing calculations
- ✅ Nutrition analysis  
- ✅ Cloud storage for 3D models (.glb files)
- ✅ Thumbnail images
- ✅ Progress tracking history
- ✅ 25GB free storage/month

---

## Cloudinary Free Tier

**Completely free forever:**
- 25 GB storage
- 25 GB bandwidth/month
- 25,000 transformations/month
- More than enough for testing and small apps!

**Pricing for scale:**
- Only pay if you exceed free tier
- ~$0.10/GB for additional storage
- Perfect for startups

---

## Next Steps

### Integrate with Flutter App

Update your Flutter app's API URL:

```dart
// lib/services/avatar_generation_service.dart
final String baseUrl = 'http://localhost:8000/api/v1';  // For local testing
// or
final String baseUrl = 'http://YOUR_COMPUTER_IP:8000/api/v1';  // For phone testing
```

To find your computer's IP:
```bash
# macOS/Linux
ifconfig | grep "inet " | grep -v 127.0.0.1

# Look for something like: inet 192.168.1.X
```

Then run your Flutter app and test!

---

## Troubleshooting

**Server won't start?**
```bash
# Make sure you're in venv
source venv/bin/activate

# Check if packages installed
pip list | grep -E "fastapi|trimesh|numpy"

# Reinstall if needed
pip install -r requirements.txt
```

**Port 8000 already in use?**
```bash
# Kill existing process
lsof -ti:8000 | xargs kill -9

# Or use different port
python main_simple.py --port 8001
```

**Cloudinary not working?**
- Check credentials are correct in .env
- Make sure no spaces in .env file
- Cloud name is NOT a URL (just the name)

---

## Summary

**For quick testing:** Just run `python main_simple.py` - no setup needed!

**For real usage:** Get free Cloudinary account (2 min signup) + add credentials to .env

**No Firebase needed** for local development and testing. Save money, test faster! 🚀
