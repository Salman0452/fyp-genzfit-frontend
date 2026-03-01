# 🎯 GenzFit 3D Avatar System - Complete Architecture

## 🏗️ Project Structure

```
fyp-genzfit-frontend/
│
├── backend/                          # Python Backend (NEW!)
│   ├── main.py                       # FastAPI application with all routes
│   ├── requirements.txt              # Python dependencies
│   ├── Dockerfile                    # Container configuration
│   ├── docker-compose.yml            # Local development setup
│   ├── .env.example                  # Environment template
│   ├── .gitignore                    # Git ignore rules
│   │
│   ├── services/                     # Core business logic
│   │   ├── avatar_generator.py       # 3D mesh generation from measurements
│   │   ├── body_morpher.py           # Physique transformation algorithms
│   │   ├── nutrition_calculator.py   # Body composition calculations
│   │   └── storage_service.py        # Firebase/Cloudinary storage
│   │
│   ├── models/                       # Pydantic data models
│   │   └── avatar_models.py          # Request/response schemas
│   │
│   ├── utils/                        # Utility functions
│   │   └── firebase_admin.py         # Firebase SDK initialization
│   │
│   ├── config/                       # Configuration
│   │   └── settings.py               # App settings & environment vars
│   │
│   ├── deploy-gcloud.sh              # Google Cloud Run deployment
│   ├── README.md                     # Backend documentation
│   ├── DEPLOYMENT.md                 # Deployment guides
│   └── QUICKSTART.md                 # Quick setup guide
│
├── lib/                              # Flutter Application
│   ├── main.dart                     # App entry point
│   ├── main_web.dart                 # Web-specific entry
│   │
│   ├── services/                     # Service layer
│   │   ├── avatar_generation_service.dart  # (NEW!) Python API client
│   │   ├── auth_service.dart
│   │   ├── nutrition_service.dart
│   │   └── ...
│   │
│   ├── models/                       # Data models
│   │   ├── avatar_model.dart
│   │   ├── measurement_model.dart
│   │   ├── user_model.dart
│   │   └── ...
│   │
│   ├── screens/                      # UI screens
│   │   ├── client/
│   │   │   ├── avatar_viewer_screen.dart
│   │   │   ├── body_scan_screen.dart
│   │   │   ├── nutrition_tracking_screen.dart
│   │   │   └── ...
│   │   └── admin/
│   │       └── ...
│   │
│   ├── widgets/                      # Reusable widgets
│   └── providers/                    # State management
│
├── assets/                           # Static assets
│   ├── images/
│   └── fonts/
│
├── android/                          # Android config
├── ios/                              # iOS config
├── web/                              # Web config
│
├── pubspec.yaml                      # Flutter dependencies
├── .env                              # Environment variables
├── firebase.json                     # Firebase config
└── firestore.rules                   # Firestore security rules
```

## 🔄 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter Mobile/Web App                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │  Body Scan       │         │  Nutrition       │             │
│  │  (ML Kit)        │         │  Tracking        │             │
│  └────────┬─────────┘         └────────┬─────────┘             │
│           │                            │                         │
│           v                            v                         │
│  ┌─────────────────────────────────────────────┐               │
│  │    Avatar Generation Service (Dart)          │               │
│  │  - generateAvatar()                          │               │
│  │  - updateAvatarPhysique()                    │               │
│  │  - getProgressAnalysis()                     │               │
│  └────────────────────┬─────────────────────────┘               │
│                       │                                          │
└───────────────────────┼──────────────────────────────────────────┘
                        │ HTTP/REST API
                        │ (JSON)
┌───────────────────────▼──────────────────────────────────────────┐
│                    Python Backend (FastAPI)                       │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌────────────────────────────────────────────────────┐          │
│  │              API Endpoints (main.py)                │          │
│  │  POST /api/v1/avatar/generate                      │          │
│  │  POST /api/v1/avatar/update-physique               │          │
│  │  GET  /api/v1/avatar/progress/{user_id}            │          │
│  └─────────────────────┬──────────────────────────────┘          │
│                        │                                          │
│           ┌────────────┴────────────┬───────────────┐            │
│           │                         │               │            │
│  ┌────────▼──────────┐   ┌─────────▼────────┐   ┌─▼────────┐   │
│  │ Avatar Generator  │   │  Body Morpher    │   │ Nutrition │   │
│  │ - Create 3D mesh  │   │ - Apply changes  │   │ Calculator│   │
│  │ - From measurements│   │ - Muscle growth  │   │ - BMR/TDEE│   │
│  │ - SMPL-like model │   │ - Fat loss/gain  │   │ - Macros  │   │
│  └────────┬──────────┘   └─────────┬────────┘   └─┬────────┘   │
│           │                        │               │            │
│           └────────────┬───────────┴───────────────┘            │
│                        │                                          │
│              ┌─────────▼──────────┐                              │
│              │  Storage Service   │                              │
│              │ - Upload GLB models│                              │
│              │ - Generate thumbs  │                              │
│              │ - Firebase/Cloud   │                              │
│              └─────────┬──────────┘                              │
└────────────────────────┼───────────────────────────────────────┘
                         │
                         v
┌────────────────────────────────────────────────────────────────┐
│                    Firebase / Cloud Storage                     │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  Firestore   │  │   Storage    │  │     Auth     │        │
│  │              │  │              │  │              │        │
│  │ - Metadata   │  │ - GLB models │  │ - Users      │        │
│  │ - Progress   │  │ - Thumbnails │  │ - Sessions   │        │
│  │ - History    │  │ - Assets     │  │ - Tokens     │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└────────────────────────────────────────────────────────────────┘
```

## 🔬 3D Avatar Generation Pipeline

```
Step 1: Input Data Collection
┌──────────────────────────────────────┐
│ • Height: 175cm                      │
│ • Weight: 75kg                       │
│ • Measurements: chest, waist, hips   │
│ • ML Kit Landmarks: 33 pose points   │
│ • Gender: male/female                │
└──────────────────┬───────────────────┘
                   │
                   v
Step 2: 3D Mesh Generation
┌──────────────────────────────────────┐
│ Avatar Generator Service             │
│ - Load base template (6890 vertices) │
│ - Apply height scaling               │
│ - Apply weight/volume scaling        │
│ - Adjust body proportions            │
│ - Map ML landmarks to face           │
└──────────────────┬───────────────────┘
                   │
                   v
Step 3: Texture & Material
┌──────────────────────────────────────┐
│ - Apply skin tone                    │
│ - Add clothing style                 │
│ - Set material properties            │
│ - Generate UV mapping                │
└──────────────────┬───────────────────┘
                   │
                   v
Step 4: Export & Storage
┌──────────────────────────────────────┐
│ - Export to GLB format (2-5 MB)      │
│ - Upload to Firebase Storage         │
│ - Generate thumbnail (512x512)       │
│ - Save metadata to Firestore         │
└──────────────────┬───────────────────┘
                   │
                   v
Step 5: Return to Client
┌──────────────────────────────────────┐
│ Response:                            │
│ {                                    │
│   "modelUrl": "https://...",         │
│   "thumbnailUrl": "https://...",     │
│   "metadata": {...}                  │
│ }                                    │
└──────────────────────────────────────┘
```

## 📊 Physique Update Algorithm

```
Input: Nutrition Data (Day 1 → Day 30)
┌──────────────────────────────────────┐
│ • Carbs: 6000g total                 │
│ • Protein: 3000g total               │
│ • Fats: 1400g total                  │
│ • Exercise: 8000 calories burned     │
│ • Days: 30                           │
└──────────────────┬───────────────────┘
                   │
                   v
Step 1: Calculate Calorie Balance
┌──────────────────────────────────────┐
│ Consumed = (6000×4) + (3000×4) +     │
│            (1400×9) = 48,600 cal     │
│ Maintenance = 2200 × 30 = 66,000    │
│ Net = 48,600 - 66,000 - 8,000        │
│     = -25,400 cal (deficit)          │
└──────────────────┬───────────────────┘
                   │
                   v
Step 2: Calculate Muscle Gain
┌──────────────────────────────────────┐
│ Protein/day = 3000/30 = 100g         │
│ Optimal = 75kg × 2g/kg = 150g        │
│ Efficiency = 100/150 = 0.67          │
│ Max gain = 0.25kg/week × 4.3 weeks   │
│ Actual = 1.08kg × 0.67 = 0.72kg     │
└──────────────────┬───────────────────┘
                   │
                   v
Step 3: Calculate Fat Loss
┌──────────────────────────────────────┐
│ Muscle calories = 0.72 × 1000        │
│                 = 720 cal            │
│ Remaining deficit = -25,400 - 720    │
│                   = -26,120 cal      │
│ Fat loss = 26,120 / 7700 = 3.39kg   │
└──────────────────┬───────────────────┘
                   │
                   v
Step 4: Apply to 3D Model
┌──────────────────────────────────────┐
│ Body Morpher:                        │
│ - Add muscle to: chest, arms, legs   │
│ - Remove fat from: abdomen, hips     │
│ - Update definition (lower BF%)      │
│ - Tighten skin                       │
└──────────────────┬───────────────────┘
                   │
                   v
Result: Updated Avatar
┌──────────────────────────────────────┐
│ Weight: 75kg → 72.33kg (-2.67kg)     │
│ Muscle: +0.72kg                      │
│ Fat: -3.39kg                         │
│ Body Fat: 18% → 13.5%                │
│ BMI: 24.5 → 23.6                     │
└──────────────────────────────────────┘
```

## 🔑 Key Technologies

### Backend (Python)
- **FastAPI**: High-performance async API framework
- **Trimesh**: 3D mesh processing and manipulation
- **NumPy/SciPy**: Mathematical operations
- **Firebase Admin SDK**: Database and storage
- **Pydantic**: Data validation

### Frontend (Flutter)
- **model_viewer_plus**: 3D GLB model rendering
- **google_mlkit_pose_detection**: Body landmark detection
- **camera**: Real-time body scanning
- **http**: API communication
- **firebase_core**: Firebase integration

### Infrastructure
- **Firebase Firestore**: NoSQL database for metadata
- **Firebase Storage**: 3D model and image storage
- **Google Cloud Run**: Serverless backend hosting
- **Docker**: Containerization

## 📈 Performance Metrics

| Operation | Time | Size | Notes |
|-----------|------|------|-------|
| Avatar Generation | 2-5s | 2-5 MB | Initial creation |
| Physique Update | 1-3s | 2-5 MB | Morphing existing |
| API Latency | 100-300ms | - | Network dependent |
| Model Loading (Flutter) | 1-2s | - | First time only |
| Thumbnail Generation | 500ms | 50-100 KB | PNG format |

## 💰 Cost Breakdown

### Monthly Estimates (1000 users, 10 updates/month each)

| Service | Usage | Cost |
|---------|-------|------|
| Google Cloud Run | 10,000 requests | $5-15 |
| Firebase Storage | 50 GB stored | $1-3 |
| Firebase Storage | 100 GB bandwidth | $2-5 |
| Firestore | 100k reads, 50k writes | $1-3 |
| **Total** | | **$9-26/month** |

## 🔐 Security Considerations

1. **API Authentication**: Integrate Firebase Auth tokens
2. **Rate Limiting**: 60 requests/minute per user
3. **Input Validation**: Pydantic models validate all inputs
4. **CORS**: Restricted to Flutter app domains
5. **Credentials**: Never commit service account JSON
6. **Storage Rules**: Firestore rules protect user data

## 🚀 Deployment Checklist

- [ ] Python backend tested locally
- [ ] Firebase credentials configured
- [ ] Environment variables set
- [ ] CORS origins updated
- [ ] Backend deployed to cloud
- [ ] Flutter app updated with API URL
- [ ] End-to-end testing complete
- [ ] Monitoring and logging enabled
- [ ] Backup strategy in place
- [ ] Documentation updated

## 📝 API Endpoints Summary

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/api/v1/avatar/generate` | POST | Create new avatar |
| `/api/v1/avatar/update-physique` | POST | Update body composition |
| `/api/v1/avatar/progress/{user_id}` | GET | Get progress history |
| `/api/v1/avatar/compare` | POST | Compare two states |
| `/api/v1/avatar/{user_id}` | DELETE | Delete avatar |

## 🎓 Learning Resources

- **SMPL Model**: [smpl.is.tue.mpg.de](https://smpl.is.tue.mpg.de/)
- **Trimesh Docs**: [trimesh.org](https://trimesh.org/)
- **FastAPI Tutorial**: [fastapi.tiangolo.com](https://fastapi.tiangolo.com/)
- **Firebase Admin**: [firebase.google.com/docs/admin/setup](https://firebase.google.com/docs/admin/setup)
- **Model Viewer**: [modelviewer.dev](https://modelviewer.dev/)

---

**Built with ❤️ for GenzFit - Making fitness visual and motivating!**
