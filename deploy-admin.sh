#!/bin/bash

# GenZFit Admin Panel Deployment Script

echo "🚀 GenZFit Admin Panel Deployment"
echo "=================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null
then
    echo "❌ Firebase CLI not found. Installing..."
    echo ""
    echo "Please run: npm install -g firebase-tools"
    echo "Then run this script again."
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""

# Login check
echo "📝 Checking Firebase login status..."
firebase projects:list > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "🔐 Please login to Firebase..."
    firebase login
fi

echo ""
echo "📋 Deploying Firestore Rules..."
firebase deploy --only firestore:rules --project genzfit-d36f0

echo ""
echo "📊 Deploying Firestore Indexes..."
firebase deploy --only firestore:indexes --project genzfit-d36f0

echo ""
echo "🏗️  Building Flutter Web App..."
flutter build web --release -t lib/main_web.dart

echo ""
echo "🌐 Deploying to Firebase Hosting..."
firebase deploy --only hosting --project genzfit-d36f0

echo ""
echo "✅ Deployment Complete!"
echo ""
echo "🎉 Your admin panel is now live at:"
echo "   https://genzfit-d36f0.web.app"
echo ""
echo "📱 Mobile app is still available on Android/iOS"
echo "   Admin panel is web-only"
echo ""
