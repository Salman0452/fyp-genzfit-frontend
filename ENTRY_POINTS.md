# GenZFit Entry Points

This project has two separate entry points:

## 📱 Mobile App (`lib/main.dart`)
For Android and iOS devices with full client and trainer features.

**Run:**
```bash
# Android
flutter run

# iOS  
flutter run -d ios
```

## 🌐 Admin Panel (`lib/main_web.dart`)
Web-only admin interface for platform management.

**Run:**
```bash
flutter run -d chrome -t lib/main_web.dart
```

**Build:**
```bash
flutter build web --release -t lib/main_web.dart
```

## Why Two Entry Points?

- **Mobile app** needs splash screen, role selection, onboarding
- **Admin panel** needs direct access to login screen
- Keeps admin code separate from client/trainer flows
- Optimizes bundle size for web deployment

## Deployment

- **Mobile**: Use regular `main.dart` for Play Store/App Store
- **Web**: Use `main_web.dart` for Firebase Hosting (admin panel only)
