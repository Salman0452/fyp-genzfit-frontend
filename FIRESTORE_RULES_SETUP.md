# Firestore Security Rules Setup

## 🚨 Current Issue
You're getting a "permission denied" error because Firestore security rules are blocking access.

## 🔧 Quick Fix (Development Mode)

### Option 1: Using Firebase Console (Recommended for now)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **genzfit-d36f0**
3. Click on **Firestore Database** in the left menu
4. Click on the **Rules** tab
5. Replace the current rules with the contents of `firestore.rules.dev`
6. Click **Publish**

**Copy and paste this into Firebase Console:**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isSignedIn() {
      return request.auth != null;
    }
    
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && request.auth.uid == userId;
      allow update: if isSignedIn() && request.auth.uid == userId;
      allow delete: if isSignedIn() && request.auth.uid == userId;
    }
    
    match /measurements/{measurementId} {
      allow read, write: if isSignedIn();
    }
    
    match /avatars/{avatarId} {
      allow read, write: if isSignedIn();
    }
    
    match /trainers/{trainerId} {
      allow read: if isSignedIn();
      allow write: if isSignedIn();
    }
    
    match /chats/{chatId} {
      allow read, write: if isSignedIn();
      
      match /messages/{messageId} {
        allow read, write: if isSignedIn();
      }
    }
    
    match /sessions/{sessionId} {
      allow read, write: if isSignedIn();
    }
    
    match /recommendations/{recommendationId} {
      allow read, write: if isSignedIn();
    }
    
    match /chatbot_history/{userId} {
      allow read, write: if isSignedIn();
      
      match /conversations/{messageId} {
        allow read, write: if isSignedIn();
      }
    }
    
    match /platform_analytics/{document=**} {
      allow read, write: if isSignedIn();
    }
    
    match /verification_requests/{requestId} {
      allow read, write: if isSignedIn();
    }
    
    match /reports/{reportId} {
      allow read, write: if isSignedIn();
    }
  }
}
```

### Option 2: Using Firebase CLI

If you have Firebase CLI installed:

```bash
# Login to Firebase
firebase login

# Initialize Firebase in your project (if not already done)
firebase init firestore

# Deploy the development rules
firebase deploy --only firestore:rules
```

## ✅ After Deploying Rules

1. Close your app completely
2. Run it again:
   ```bash
   flutter run
   ```
3. Try signing up and logging in again

## 🔒 Security Levels

### Development Rules (`firestore.rules.dev`) - **CURRENT**
- ✅ Any authenticated user can read/write most data
- ✅ Good for development and testing
- ⚠️ **NOT secure for production**

### Production Rules (`firestore.rules`) - **FOR LATER**
- ✅ Role-based access control
- ✅ Users can only access their own data
- ✅ Trainers have specific permissions
- ✅ Admin-only operations protected
- ✅ Secure for production deployment

## 📝 Next Steps

1. **For FYP Development**: Use `firestore.rules.dev` (development rules)
2. **Before Final Deployment**: Switch to `firestore.rules` (production rules)

## 🐛 Troubleshooting

**Still getting permission denied?**
1. Wait 30 seconds after deploying rules (Firebase needs time to propagate)
2. Clear app data and try again
3. Check Firebase Console → Firestore → Rules to verify deployment
4. Check that you're signed in (Firebase Auth succeeded)

**Error: "The caller does not have permission"**
- Make sure you deployed the new rules
- Verify you're using Firebase Authentication (not just Firestore)
- Check that `request.auth != null` in Firebase Console Rules Playground

## 💡 Why This Happened

The original `firestore.rules` had strict security that prevented reading user documents during the login flow. The development rules allow authenticated users to access data, which is perfect for building and testing your app.

For your FYP demo, development rules are completely fine. You can add stricter production rules later if you deploy the app publicly.
