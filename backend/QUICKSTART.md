# GenzFit Avatar API - Quick Start Guide 🚀

Get your dynamic 3D avatar system running in 5 minutes!

## ⚡ Quick Setup

### 1. Install Dependencies

```bash
cd backend
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure Firebase

Create `firebase-service-account.json`:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Settings → Service Accounts
4. Click "Generate new private key"
5. Save as `backend/firebase-service-account.json`

### 3. Set Environment Variables

```bash
cp .env.example .env
```

Edit `.env`:
```env
FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
DEBUG=true
```

### 4. Run Server

```bash
uvicorn main:app --reload --port 8000
```

Visit: http://localhost:8000/docs 🎉

## 🧪 Test API

### Health Check
```bash
curl http://localhost:8000/health
```

### Generate Avatar
```bash
curl -X POST http://localhost:8000/api/v1/avatar/generate \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test_user_123",
    "height": 175,
    "weight": 75,
    "measurements": {
      "chest": 100,
      "waist": 85,
      "hips": 95
    },
    "landmarks": {},
    "gender": "male",
    "skinTone": "medium"
  }'
```

## 🔧 Flutter Integration

### 1. Add Service to Flutter

File already created: `lib/services/avatar_generation_service.dart`

### 2. Update API URL

When deploying, set environment variable in Flutter:

```bash
flutter run --dart-define=AVATAR_API_URL=https://your-api-url.com
```

### 3. Use in Your App

```dart
import 'package:genzfit/services/avatar_generation_service.dart';

final avatarService = AvatarGenerationService();

// Generate avatar
final result = await avatarService.generateAvatar(
  measurement: measurementModel,
  mlKitLandmarks: landmarks,
  gender: 'male',
);

print('Avatar URL: ${result['modelUrl']}');
```

## 🐳 Docker (Optional)

```bash
# Build
docker build -t genzfit-avatar-api .

# Run
docker run -p 8000:8000 \
  -e FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com \
  -v $(pwd)/firebase-service-account.json:/app/firebase-service-account.json \
  genzfit-avatar-api
```

Or use Docker Compose:
```bash
docker-compose up
```

## ☁️ Deploy

### Google Cloud Run (Fastest)
```bash
./deploy-gcloud.sh
```

### Railway.app (Easiest)
1. Visit [railway.app](https://railway.app)
2. "New Project" → "Deploy from GitHub"
3. Add environment variables
4. Done! ✨

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed guides.

## 📊 Expected Performance

- **Avatar Generation**: 2-5 seconds
- **Physique Update**: 1-3 seconds
- **Model Size**: 2-5 MB
- **API Latency**: 100-300ms

## 🆘 Troubleshooting

### Firebase Connection Error
```bash
# Verify credentials
cat firebase-service-account.json | python -m json.tool

# Test connection
python -c "from utils.firebase_admin import initialize_firebase; initialize_firebase()"
```

### Import Errors
```bash
pip install --upgrade -r requirements.txt
```

### Port Already in Use
```bash
# Kill process on port 8000
lsof -ti:8000 | xargs kill -9

# Or use different port
uvicorn main:app --port 8080
```

## 📚 Next Steps

1. ✅ API running locally
2. 📱 Test with Flutter app
3. 🚀 Deploy to cloud
4. 📊 Monitor performance
5. 🎨 Customize avatar styles

## 🔗 Useful Links

- **API Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **GitHub**: Your repository
- **Deployment Guide**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **Full README**: [README.md](README.md)

## 💡 Pro Tips

1. **Use staging**: Test on Railway before Google Cloud
2. **Monitor costs**: Set billing alerts
3. **Cache models**: Store frequently accessed avatars
4. **Optimize images**: Compress thumbnails
5. **Rate limiting**: Protect from abuse

---

**Questions?** Check [README.md](README.md) or open an issue!

Happy coding! 🎯
