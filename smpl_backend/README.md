# GenZFit SMPL Avatar Backend

A Python FastAPI backend that turns ML Kit pose landmarks + biometric measurements into textured 3D `.glb` body avatars using SMPL/SMPL-X.

---

## Architecture Overview

```
Flutter App (ML Kit Pose Detection)
         │
         │  POST /generate-avatar
         │  { height, weight, age, gender, landmarks[33], skin_tone }
         ▼
┌─────────────────────────────────────────┐
│         FastAPI  (main.py)              │
│                                         │
│  landmark_mapper.py                     │
│    ML Kit 33 pts → body proportions     │
│                                         │
│  beta_converter.py                      │
│    proportions + biometrics → 10 betas  │
│    (CAESAR population z-score model)    │
│                                         │
│  mesh_generator.py                      │
│    betas → SMPL-X mesh  (if available)  │
│            or capsule-mesh fallback      │
│    → vertex color (skin tone/muscle)    │
│    → .glb bytes (trimesh / pygltflib)   │
└─────────────────────────────────────────┘
         │
         │  { model_base64, betas[10], body_measurements }
         ▼
Flutter App (model_viewer_plus)
  • Decodes base64 → local .glb file
  • Renders 360° interactive avatar
  • Stores betas per date in Firestore
  • Timeline slider shows shape progress
```

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Python      | ≥ 3.10  |
| pip         | ≥ 22    |

---

## Quick Start

### 1. Install dependencies

```bash
cd smpl_backend
pip install -r requirements.txt
```

### 2. Configure environment

```bash
cp .env.example .env
# Edit .env if needed (defaults work for local dev)
```

### 3. Start the server

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Server starts at **http://0.0.0.0:8000**

Verify with:
```bash
curl http://localhost:8000/health
```

Expected output:
```json
{
  "status": "ok",
  "smplx_available": false,
  "gpu_available": false
}
```

---

## Flutter Integration

### Android Emulator
```
SMPL_BACKEND_URL=http://10.0.2.2:8000
```

### iOS Simulator
```
SMPL_BACKEND_URL=http://localhost:8000
```

### Physical Device
Use your computer's LAN IP address:
```
SMPL_BACKEND_URL=http://192.168.x.x:8000
```

Set this in `lib/services/smpl_avatar_service.dart` or via a `.env` configuration.

---

## Optional: SMPL-X Upgrade (Realistic Mesh)

By default the backend uses a **capsule-mesh fallback** built from trimesh primitives. This works without any registration and produces a functional, beta-driven body shape.

To upgrade to **SMPL-X** (a research-grade skinned human mesh model):

1. Register for free at https://smpl-x.is.tue.mpg.de
2. Download the **SMPL-X model files** (SMPLX_MALE.pkl, SMPLX_FEMALE.pkl, SMPLX_NEUTRAL.pkl)
3. Place them in `smpl_backend/smpl_models/`:
   ```
   smpl_backend/
   └── smpl_models/
       ├── SMPLX_MALE.pkl
       ├── SMPLX_FEMALE.pkl
       └── SMPLX_NEUTRAL.pkl
   ```
4. Install additional dependencies:
   ```bash
   pip install torch smplx
   ```
5. Set the path in `.env`:
   ```
   SMPLX_MODEL_PATH=./smpl_models
   ```
6. Restart the server — `/health` will now return `"smplx_available": true`

---

## API Reference

### `GET /health`

Returns backend status.

**Response:**
```json
{
  "status": "ok",
  "smplx_available": false,
  "gpu_available": false
}
```

---

### `POST /generate-avatar`

Generates a 3D body avatar and returns it as a base64-encoded `.glb` file along with the computed SMPL beta parameters.

**Request body:**
```json
{
  "user_id": "uid_abc123",
  "date": "2024-03-01",
  "height": 175.0,
  "weight": 70.0,
  "age": 22,
  "gender": "male",
  "landmarks": [
    { "x": 0.52, "y": 0.12, "z": -0.01, "likelihood": 0.98 },
    ...
  ],
  "measurements": {
    "chest": 96.0,
    "waist": 80.0,
    "hips": 98.0,
    "shoulderWidth": 44.0,
    "bicepLeft": 32.0,
    "bicepRight": 32.0,
    "thighLeft": 52.0,
    "thighRight": 52.0
  },
  "skin_tone": "medium",
  "show_muscles": false
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `user_id` | string | ✅ | Firebase UID |
| `date` | string | ✅ | YYYY-MM-DD format |
| `height` | float | ✅ | centimetres |
| `weight` | float | ✅ | kilograms |
| `age` | int | ✅ | years |
| `gender` | string | ✅ | `"male"` or `"female"` |
| `landmarks` | array | ❌ | ML Kit 33 pose landmarks. If omitted, biometrics only are used |
| `measurements` | object | ❌ | Tape measurements. If omitted, estimated from height/weight |
| `skin_tone` | string | ❌ | `"light"`, `"medium"`, `"brown"`, `"dark"` (default: `"medium"`) |
| `show_muscles` | bool | ❌ | Adds reddish muscle highlight to arms (default: `false`) |

**Response:**
```json
{
  "user_id": "uid_abc123",
  "date": "2024-03-01",
  "model_base64": "<base64-encoded GLB bytes>",
  "betas": [-0.12, 0.45, 0.08, 0.33, -0.22, 0.15, -0.05, 0.28, 0.11, -0.09],
  "body_measurements": {
    "chest": 96.0,
    "waist": 80.0,
    "hips": 98.0,
    "bmi": 22.9
  },
  "generation_time_ms": 823,
  "message": "Avatar generated using capsule-mesh method"
}
```

---

### `GET /avatar/{user_id}`

Returns the latest avatar snapshot metadata for a user (no GLB data).

**Response:**
```json
{
  "user_id": "uid_abc123",
  "date": "2024-03-01",
  "betas": [-0.12, 0.45, ...],
  "body_measurements": { ... }
}
```

---

### `GET /avatar/{user_id}/history`

Returns all stored snapshots for a user (metadata only, no GLB data).

**Response:**
```json
[
  { "user_id": "uid_abc123", "date": "2024-03-01", "betas": [...], "body_measurements": {...} },
  { "user_id": "uid_abc123", "date": "2024-02-15", "betas": [...], "body_measurements": {...} }
]
```

---

### `GET /avatar/{user_id}/{snap_date}/glb`

Streams the cached `.glb` file for a specific snapshot date.

- `snap_date` format: `YYYY-MM-DD`
- Returns `404` if no GLB is cached for that date

---

## SMPL Beta Parameters

The 10 beta (β) shape parameters encode body shape variation:

| Index | Parameter | Meaning |
|-------|-----------|---------|
| β₀ | Height / overall size | Positive = taller/larger |
| β₁ | Weight / mass | Positive = heavier build |
| β₂ | Leg length proportion | Positive = longer legs |
| β₃ | Upper-body muscle mass | Positive = more muscular torso |
| β₄ | Shoulder breadth | Positive = broader shoulders |
| β₅ | Waist-hip ratio | Positive = wider hips (pear shape) |
| β₆ | Torso length | Positive = longer torso |
| β₇ | Thigh bulk | Positive = larger thighs |
| β₈ | Chest depth (front-to-back) | Positive = deeper chest |
| β₉ | Age-related shape | Positive = older body shape |

All values are clamped to **[-3.0, 3.0]**.

---

## Day-by-Day Progress Tracking

Each time the Flutter app triggers avatar generation (after a body scan), the backend:
1. Generates the `.glb` mesh from current measurements
2. Returns the 10 beta values encoding body shape
3. Caches the `.glb` at `{CACHE_DIR}/{userId}_{date}.glb`

Flutter then:
1. Decodes the base64 GLB and saves it locally at `{appDocDir}/avatars/{userId}/{YYYY-MM-DD}.glb`
2. Writes a document to Firestore `avatar_snapshots` collection with the betas and date
3. The `AvatarViewerScreen` loads all snapshots and renders the `AvatarProgressSlider` timeline
4. Swiping date chips loads the corresponding local `.glb` into `model_viewer_plus`

Over time, changes in β₀ (size), β₁ (mass), β₅ (waist-hip), and β₄ (shoulders) visually represent fitness progress.

---

## Skin Tone Options

| Value | Hex Color | Description |
|-------|-----------|-------------|
| `"light"` | `#FFE0C4` | Fair / light skin |
| `"medium"` | `#D2A078` | Olive / medium skin |
| `"brown"` | `#A5694B` | Brown skin |
| `"dark"` | `#644128` | Deep / dark skin |

Skin tone is applied as vertex colors on the mesh. The muscle highlight overlay adds a reddish tint (`#C85050`) to the arm region vertices when `show_muscles: true`.

---

## File Structure

```
smpl_backend/
├── main.py                  # FastAPI app, all endpoints
├── requirements.txt         # Python dependencies
├── .env.example             # Environment variable template
├── models/
│   ├── __init__.py
│   └── request_models.py    # Pydantic request/response models
├── services/
│   ├── __init__.py
│   ├── landmark_mapper.py   # ML Kit 33 landmarks → body proportions
│   ├── beta_converter.py    # Measurements → SMPL beta values
│   └── mesh_generator.py    # Betas → GLB mesh bytes (SMPL-X or capsule)
├── smpl_models/             # (optional) SMPL-X .pkl model files
└── cache/
    └── glb/                 # Auto-created GLB cache directory
```

---

## Troubleshooting

**Port already in use:**
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8001
```
Then update `SMPL_BACKEND_URL` in your Flutter `.env`.

**trimesh import error:**
```bash
pip install trimesh[all]
```

**Flutter can't reach backend on physical device:**
- Ensure phone and computer are on the same Wi-Fi network
- Use your machine's LAN IP (e.g. `192.168.1.10`)
- Check that your firewall allows port 8000

**`smplx_available: false` even after placing model files:**
- Ensure the files are named exactly `SMPLX_MALE.pkl`, `SMPLX_FEMALE.pkl`, `SMPLX_NEUTRAL.pkl`
- Ensure `SMPLX_MODEL_PATH` in `.env` points to the folder containing those files
- Install `torch` and `smplx`: `pip install torch smplx`

---

## Production Notes

- The in-memory `_avatar_store` in `main.py` is for **development only**. Replace with a real database (PostgreSQL, Firestore, MongoDB) for production.
- The `/generate-avatar` endpoint is CPU-bound. For production, run behind a task queue (Celery + Redis) or use Cloud Run with GPU.
- Serve the `.glb` files from a CDN (Cloudinary, Firebase Storage) instead of streaming from the FastAPI server.
- Add authentication middleware to verify Firebase JWT tokens on all endpoints.
