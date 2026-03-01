# GenzFit 3D Avatar Backend API 🎯

Dynamic 3D avatar generation and morphing system for the GenzFit fitness application. This Python backend creates personalized 3D human avatars from body measurements and updates them based on nutrition and exercise progress.

## 🌟 Features

- **3D Avatar Generation**: Create realistic human avatars from body measurements and ML Kit pose landmarks
- **Dynamic Physique Morphing**: Update avatar body based on nutrition tracking (carbs, protein, fats)
- **Progress Tracking**: Historical timeline of body composition changes
- **Realistic Body Composition**: Science-based muscle gain and fat loss calculations
- **Multiple Storage Options**: Firebase Storage or Cloudinary support
- **RESTful API**: FastAPI-based endpoints with automatic documentation

## 🏗️ Architecture

```
backend/
├── main.py                          # FastAPI application & routes
├── services/
│   ├── avatar_generator.py          # 3D mesh generation from measurements
│   ├── body_morpher.py              # Physique transformation logic
│   ├── nutrition_calculator.py      # Body composition calculations
│   └── storage_service.py           # Cloud storage & database operations
├── models/
│   └── avatar_models.py             # Pydantic request/response models
├── utils/
│   └── firebase_admin.py            # Firebase SDK initialization
├── config/
│   └── settings.py                  # Application configuration
├── requirements.txt                 # Python dependencies
├── Dockerfile                       # Docker container configuration
└── .env.example                     # Environment variables template
```

## 🚀 Quick Start

### Prerequisites

- Python 3.11+
- Firebase project with Firestore and Storage enabled
- Firebase service account credentials

### 1. Clone and Install

```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and add your Firebase credentials:

```env
FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
```

### 3. Add Firebase Credentials

Download your Firebase service account JSON from:
Firebase Console → Project Settings → Service Accounts → Generate New Private Key

Save as `firebase-service-account.json` in the backend directory.

### 4. Run Development Server

```bash
uvicorn main:app --reload --port 8000
```

API will be available at: `http://localhost:8000`

Interactive docs: `http://localhost:8000/docs`

## 📡 API Endpoints

### Generate Avatar

**POST** `/api/v1/avatar/generate`

```json
{
  "userId": "user123",
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
}
```

**Response:**
```json
{
  "userId": "user123",
  "modelUrl": "https://storage.googleapis.com/.../avatar.glb",
  "thumbnailUrl": "https://storage.googleapis.com/.../thumbnail.png",
  "status": "success",
  "message": "Avatar generated successfully",
  "metadata": {
    "height": 175,
    "weight": 75,
    "gender": "male"
  }
}
```

### Update Physique

**POST** `/api/v1/avatar/update-physique`

```json
{
  "userId": "user123",
  "baselineWeight": 75,
  "nutrition": {
    "carbs": 6000,
    "protein": 3000,
    "fats": 1400,
    "caloriesBurned": 8000
  },
  "daysElapsed": 30,
  "gender": "male",
  "activityLevel": "moderate"
}
```

**Response:**
```json
{
  "userId": "user123",
  "updatedModelUrl": "https://storage.googleapis.com/.../avatar_day30.glb",
  "thumbnailUrl": "https://storage.googleapis.com/.../thumbnail.png",
  "status": "success",
  "message": "Avatar physique updated successfully",
  "changes": {
    "weightChange": 2.5,
    "muscleGain": 3.2,
    "fatLoss": 0.7,
    "bodyFatPercentage": 15.8,
    "bmi": 22.4
  },
  "daysTracked": 30
}
```

### Get Progress Analysis

**GET** `/api/v1/avatar/progress/{user_id}`

Returns comprehensive progress analysis with timeline and predictions.

### Compare Avatars

**POST** `/api/v1/avatar/compare`

```json
{
  "user_id": "user123",
  "day1": 0,
  "day2": 30
}
```

## 🧪 Body Composition Science

### Muscle Gain Formula

```python
max_muscle_per_week = 0.25  # kg for beginners
protein_efficiency = min(protein_per_day / (body_weight * 2.0), 1.0)
muscle_gain = max_muscle_per_week * protein_efficiency * calorie_factor
```

### Fat Loss/Gain

```python
# 1 kg fat = 7700 calories
# 1 kg muscle = 1000 calories (with protein)
net_calories = consumed - maintenance - burned
fat_change = (net_calories - muscle_calories) / 7700
```

### Body Fat Distribution

Different patterns for male/female:
- **Male**: 40% abdomen, 15% chest/back, 10% arms/legs
- **Female**: 30% hips, 25% thighs, 20% abdomen

## 🐳 Docker Deployment

### Build Image

```bash
docker build -t genzfit-avatar-api .
```

### Run Container

```bash
docker run -p 8000:8000 \
  -e FIREBASE_CREDENTIALS_JSON='{"type":"service_account",...}' \
  -e FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com \
  genzfit-avatar-api
```

### Docker Compose

```bash
docker-compose up -d
```

## ☁️ Cloud Deployment

### Google Cloud Run

```bash
# Build and push
gcloud builds submit --tag gcr.io/your-project/avatar-api

# Deploy
gcloud run deploy avatar-api \
  --image gcr.io/your-project/avatar-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com
```

### Railway.app

1. Connect GitHub repository
2. Add environment variables in Railway dashboard
3. Railway auto-deploys from `main` branch

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `FIREBASE_CREDENTIALS_PATH` | Path to service account JSON | Yes* |
| `FIREBASE_CREDENTIALS_JSON` | Service account JSON string | Yes* |
| `FIREBASE_STORAGE_BUCKET` | Firebase storage bucket name | Yes |
| `ALLOWED_ORIGINS` | CORS allowed origins | No |
| `DEBUG` | Debug mode | No |

*Either `CREDENTIALS_PATH` or `CREDENTIALS_JSON` required

## 🧪 Testing

### Run Tests

```bash
pytest
```

### Test Individual Services

```bash
# Test avatar generation
python services/avatar_generator.py

# Test body morphing
python services/body_morpher.py

# Test nutrition calculations
python services/nutrition_calculator.py
```

## 📊 Performance

- **Avatar Generation**: ~2-5 seconds
- **Physique Update**: ~1-3 seconds
- **Model Size**: 2-5 MB (GLB format)
- **Concurrent Users**: 100+ (with proper scaling)

## 🔐 Security

- Firebase Authentication integration
- Rate limiting: 60 requests/minute
- Input validation with Pydantic
- Secure credential handling
- CORS configuration

## 🐛 Troubleshooting

### Firebase Connection Issues

```bash
# Test Firebase credentials
python -c "from utils.firebase_admin import initialize_firebase; initialize_firebase()"
```

### 3D Rendering Issues

```bash
# Install OpenGL dependencies (Linux)
sudo apt-get install libgl1-mesa-glx libglib2.0-0
```

### Memory Issues

Increase container memory:
```bash
docker run --memory=2g genzfit-avatar-api
```

## 📝 API Documentation

Visit `/docs` for interactive Swagger UI documentation.

Visit `/redoc` for ReDoc documentation.

## 🤝 Integration with Flutter

See Flutter service implementation in:
- `lib/services/avatar_generation_service.dart`

Example usage:
```dart
final service = AvatarGenerationService();
final avatarUrl = await service.generateAvatar(
  measurement: measurementModel,
  mlKitLandmarks: landmarks,
);
```

## 📈 Roadmap

- [ ] Advanced SMPL model integration
- [ ] Real-time avatar animations
- [ ] AR/VR avatar export
- [ ] Social comparison features
- [ ] AI-powered pose recommendations
- [ ] Custom avatar accessories
- [ ] Multi-language support

## 💰 Cost Estimate

- **Google Cloud Run**: $5-20/month
- **Firebase Storage**: $1-5/month
- **Firestore**: $1-10/month

**Total**: ~$7-35/month for moderate usage

## 📄 License

This project is part of GenzFit application.

## 👥 Support

For issues or questions:
- Open a GitHub issue
- Contact: support@genzfit.com

## 🙏 Credits

- **SMPL Model**: Body shape representation
- **Trimesh**: 3D mesh processing
- **FastAPI**: High-performance API framework
- **Firebase**: Backend infrastructure

---

Built with ❤️ for GenzFit - Making fitness visual and motivating!
