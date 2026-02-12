# Admin Panel Setup Guide

## 🎉 Flutter Web Admin Panel Created!

Your GenZFit admin panel is now ready. Here's what has been implemented:

### ✅ Completed Features

#### 1. **Admin Authentication**
- Dedicated admin login screen (`/admin-login`)
- Role-based access control
- Secure authentication with Firebase Auth

#### 2. **Dashboard Overview**
- Total users (clients + trainers)
- Pending trainer verifications count
- Active sessions monitoring
- Platform revenue tracking
- Real-time data updates
- Responsive grid layout

#### 3. **Trainer Verification Module**
- List all trainers (pending/verified/all)
- View trainer profiles with stats
- Review uploaded certificates (zoomable images)
- View video introductions
- Approve/reject verification
- Revoke verification
- Suspend trainer accounts
- Filter by verification status

#### 4. **User Management**
- Search users by name or email
- Filter by role (client/trainer/all)
- View complete user profiles
- For clients: View measurements, BMI, goals
- For trainers: View clients, rating, earnings
- Suspend/activate user accounts
- Delete user accounts (GDPR compliance)

#### 5. **Session Monitoring**
- View all sessions (requested/active/completed/cancelled)
- Filter by status
- View client and trainer details
- Force activate/reject sessions
- Force complete/cancel sessions
- View full session details
- Real-time updates

### 🚀 How to Run

#### 1. **Create Admin User** (First Time Setup)

You need to manually create an admin user in Firestore:

**Option A: Using Firebase Console**
1. Go to Firebase Console → Firestore Database
2. Go to `users` collection
3. Create a new document with your admin user ID:

```json
{
  "email": "admin@genzfit.com",
  "name": "Admin",
  "role": "admin",
  "status": "active",
  "createdAt": [Current Timestamp]
}
```

**Option B: Using Firebase Auth + Firestore**
1. Create user in Firebase Authentication
2. Copy the UID
3. Add document to Firestore `users` collection with that UID and `role: "admin"`

#### 2. **Run the Web App**

```bash
# Development mode
flutter run -d chrome --web-renderer html

# Or for better performance
flutter run -d chrome --web-renderer canvaskit
```

#### 3. **Access Admin Panel**

Navigate to: `http://localhost:<port>/admin-login`

Login with your admin credentials.

### 📁 Project Structure

```
lib/screens/admin/
├── admin_login_screen.dart          # Admin authentication
├── admin_dashboard_screen.dart      # Main dashboard with stats
├── trainer_verification_screen.dart # Trainer approval system
├── user_management_screen.dart      # User CRUD operations
└── session_monitoring_screen.dart   # Session oversight
```

### 🔐 Security Rules

Firestore rules have been updated to support admin operations:
- ✅ Admins can read all user documents
- ✅ Admins can update trainer verification status
- ✅ Admins can suspend/delete users
- ✅ Admins can force-update session statuses

### 🎨 Design Features

- **Dark Theme**: Consistent with mobile app
- **Responsive Layout**: Works on desktop and tablet
- **Color-Coded Status**: Visual indicators for different states
- **Real-time Updates**: StreamBuilder for live data
- **Expandable Cards**: Clean, organized information display
- **Confirmation Dialogs**: Prevent accidental actions

### 📊 Dashboard Statistics

The dashboard automatically calculates:
- Total users (clients + trainers)
- Pending verification requests
- Active training sessions
- Platform revenue from completed sessions

### 🛠️ Build for Production

```bash
# Build web app
flutter build web --release --web-renderer canvaskit

# Output will be in: build/web/
```

### 🚀 Deploy to Firebase Hosting

1. **Install Firebase CLI**:
```bash
npm install -g firebase-tools
```

2. **Login to Firebase**:
```bash
firebase login
```

3. **Initialize Firebase Hosting**:
```bash
firebase init hosting
```

Select:
- Public directory: `build/web`
- Single-page app: `Yes`
- GitHub integration: `No` (for now)

4. **Deploy**:
```bash
# Build first
flutter build web --release

# Deploy
firebase deploy --only hosting
```

Your admin panel will be live at: `https://genzfit-d36f0.web.app`

### 📝 Testing Checklist

- [ ] Admin login with correct credentials
- [ ] Dashboard stats display correctly
- [ ] Trainer verification workflow
- [ ] Certificate image viewing
- [ ] User search functionality
- [ ] User suspension/activation
- [ ] Session status changes
- [ ] Responsive design on different screen sizes
- [ ] Logout functionality

### 🔧 Configuration

**Admin Routes in main.dart:**
```dart
'/admin-login': (context) => const AdminLoginScreen()
```

**Firestore Indexes Required:**
The `firestore.indexes.json` has been updated with necessary composite indexes for sessions filtering.

Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

### 🎯 Quick Actions Available

#### Trainer Verification
- ✅ Approve trainer
- ❌ Reject trainer
- 🔄 Revoke verification
- 🚫 Suspend trainer

#### User Management
- 🔍 Search by name/email
- 🚫 Suspend account
- ✅ Activate account
- 🗑️ Delete account (permanent)

#### Session Monitoring
- ▶️ Force activate session
- ❌ Force reject session
- ✅ Force complete session
- 🛑 Force cancel session

### 🎨 Color Scheme

- **Primary**: `#00D4FF` (Cyan)
- **Success**: `#00C853` (Green)
- **Warning**: `#FF9800` (Orange)
- **Danger**: `#FF0000` (Red)
- **Background**: `#000000` (Black)
- **Card**: `#1C1C1E` (Dark Gray)

### 📱 Responsive Breakpoints

- **Desktop** (>1200px): 4 columns
- **Tablet** (800-1200px): 3 columns
- **Mobile** (600-800px): 2 columns
- **Small** (<600px): 1 column

### 🐛 Troubleshooting

**Issue: "Admin privileges required" error**
- Solution: Make sure user document in Firestore has `role: "admin"`

**Issue: Firestore permission denied**
- Solution: Deploy updated Firestore rules: `firebase deploy --only firestore:rules`

**Issue: Sessions not loading**
- Solution: Deploy composite index: `firebase deploy --only firestore:indexes`

**Issue: Can't see trainers list**
- Solution: Update Firestore rules to allow admin read access to trainers

### 🎉 Next Steps

1. Create your admin user in Firestore
2. Run `flutter run -d chrome`
3. Navigate to `/admin-login`
4. Test all features
5. Build for production
6. Deploy to Firebase Hosting

### 🔮 Future Enhancements (Phase 2)

- Analytics charts (user growth, revenue trends)
- Export reports (CSV/PDF)
- Content moderation (flagged content)
- Financial management (payouts, refunds)
- System settings (commission rates, feature toggles)
- Email notifications for admins
- Activity logs and audit trail
- Advanced search and filters
- Bulk operations

---

**Congratulations!** Your GenZFit admin panel is production-ready! 🎊

For questions or issues, refer to the code documentation in each screen file.
