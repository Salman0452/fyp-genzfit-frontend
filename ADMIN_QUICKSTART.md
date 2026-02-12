# 🎉 GenZFit Admin Panel - Quick Start Guide

## ✅ What's Been Created

A fully functional **Flutter Web** admin panel with:

### Core Features
1. ✅ **Admin Dashboard** - Real-time stats and overview
2. ✅ **Trainer Verification** - Approve/reject trainers with certificate review
3. ✅ **User Management** - Search, suspend, delete users
4. ✅ **Session Monitoring** - Track and manage all training sessions

---

## 🚀 Quick Start (3 Steps)

### Step 1: Create Admin User in Firestore

**Using Firebase Console:**
1. Go to: https://console.firebase.google.com/project/genzfit-d36f0/firestore
2. Click on `users` collection
3. Click **Add document**
4. Use your user ID from Firebase Auth (or create new one)
5. Add these fields:

```
Document ID: <your-firebase-auth-uid>

Fields:
- email: "admin@genzfit.com"  (string)
- name: "Admin"  (string)
- role: "admin"  (string)
- status: "active"  (string)
- createdAt: [Click "Add field" → Timestamp → Set to now]
```

### Step 2: Run the Web App

```bash
cd /Users/salmanahmad/FYP/fyp-genzfit-frontend

# Run admin panel (web-only)
flutter run -d chrome -t lib/main_web.dart
```

**Note:** The `-t lib/main_web.dart` flag ensures the web app launches directly to the admin panel instead of the mobile app UI.

### Step 3: Access Admin Panel

The admin login screen will open automatically in Chrome!

**No need to navigate manually** - the web app now starts directly at the admin login page.

---

## 📋 Features Overview

### 1. Dashboard (`/admin-dashboard`)
- **Stats Cards:**
  - Total Users (clients + trainers)
  - Pending Verifications
  - Active Sessions
  - Platform Revenue

- **Quick Actions:**
  - Navigate to Trainer Verification
  - Navigate to User Management
  - Navigate to Session Monitoring

- **Recent Activity:**
  - Live feed of session updates

### 2. Trainer Verification
- **Filter Options:**
  - Pending (unverified trainers)
  - Verified (approved trainers)
  - All trainers

- **Actions Available:**
  - ✅ Approve verification
  - ❌ Reject verification
  - 🔄 Revoke verification (for verified trainers)
  - 🚫 Suspend trainer

- **Review:**
  - View certificates (click to zoom)
  - Watch video introductions
  - Check trainer stats (clients, rating, hourly rate)

### 3. User Management
- **Search:** By name or email
- **Filter:** All users, Clients only, Trainers only

- **Actions:**
  - 🚫 Suspend account
  - ✅ Activate account
  - 🗑️ Delete account (permanent)

- **View Details:**
  - For Clients: Goals, measurements, BMI
  - For Trainers: Clients, earnings, verification status

### 4. Session Monitoring
- **Filter by Status:**
  - All sessions
  - Requested
  - Active
  - Completed
  - Cancelled

- **Admin Actions:**
  - ▶️ Force activate session
  - ❌ Force reject session
  - ✅ Force complete session
  - 🛑 Force cancel session

- **View:**
  - Client and trainer details
  - Session dates and amounts
  - Full session information

---

## 🎨 UI/UX Features

- **Dark Theme** - Matches mobile app design
- **Responsive** - Works on desktop and tablet
- **Real-time Updates** - Live data with StreamBuilder
- **Color-Coded Status:**
  - 🔵 Active (Green)
  - 🟠 Pending (Orange)
  - 🔴 Cancelled/Rejected (Red)
  - 🟢 Completed (Blue)

---

## 🔐 Security

- **Role-Based Access:** Only users with `role: "admin"` can access
- **Firestore Rules:** Admin-specific permissions enforced
- **Authentication:** Firebase Auth required

---

## 🛠️ Building for Production

```bash
# Build web app with admin-specific entry point
flutter build web --release -t lib/main_web.dart

# Output location
build/web/
```

---

## 🚀 Deploy to Firebase Hosting (Optional)

### Prerequisites
```bash
npm install -g firebase-tools
firebase login
```

### Initialize (First Time)
```bash
firebase init hosting
```
- Public directory: `build/web`
- Single-page app: `Yes`
- Overwrite index.html: `No`

### Deploy
```bash
# Make script executable (first time)
chmod +x deploy-admin.sh

# Run deployment script
./deploy-admin.sh
```

Your admin panel will be live at: `https://genzfit-d36f0.web.app`

---

## 📁 File Structure

```
lib/screens/admin/
├── admin_login_screen.dart           # Login page
├── admin_dashboard_screen.dart       # Main dashboard
├── trainer_verification_screen.dart  # Trainer approval
├── user_management_screen.dart       # User CRUD
└── session_monitoring_screen.dart    # Session tracking

web/
├── index.html                        # Web entry point
├── manifest.json                     # PWA manifest
└── icons/                            # App icons

ADMIN_PANEL_SETUP.md                  # Detailed documentation
deploy-admin.sh                       # Deployment script
```

---

## 🧪 Testing Checklist

- [ ] Admin login works
- [ ] Dashboard stats display correctly
- [ ] Can view pending trainers
- [ ] Can approve/reject trainers
- [ ] Can search users
- [ ] Can suspend/activate users
- [ ] Can view sessions
- [ ] Can filter sessions by status
- [ ] Logout works
- [ ] Responsive design on different screen sizes

---

## ❓ Troubleshooting

### Issue: "Admin privileges required"
**Solution:** Make sure your user document has `role: "admin"` in Firestore

### Issue: Can't see trainers/users
**Solution:** 
1. Check Firestore rules are deployed
2. Verify admin user exists with correct role
3. Check browser console for errors

### Issue: Sessions not loading
**Solution:** Deploy Firestore indexes:
```bash
firebase deploy --only firestore:indexes
```

### Issue: 404 on routes
**Solution:** Use hash routing. URLs should have `#` like:
- `http://localhost:port/#/admin-login`
- Not: `http://localhost:port/admin-login`

---

## 🎯 Next Steps

1. ✅ Create admin user in Firestore
2. ✅ Run `flutter run -d chrome`
3. ✅ Test all features
4. ⏳ Deploy to production (optional)
5. ⏳ Add Phase 2 features (analytics, reports)

---

## 📞 Support

For issues or questions, check:
- `ADMIN_PANEL_SETUP.md` - Detailed documentation
- Code comments in each screen file
- Firebase Console logs

---

**Made with ❤️ for GenZFit**

Happy managing! 🎊
