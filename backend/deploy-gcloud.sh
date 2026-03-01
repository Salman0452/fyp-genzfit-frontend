#!/bin/bash

# Deploy GenzFit Avatar Backend to Google Cloud Run

set -e

echo "🚀 Deploying GenzFit Avatar Backend to Google Cloud Run..."

# Configuration
PROJECT_ID=${GOOGLE_CLOUD_PROJECT:-"your-project-id"}
SERVICE_NAME="genzfit-avatar-api"
REGION="us-central1"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install: https://cloud.google.com/sdk/install"
    exit 1
fi

# Set project
echo "📦 Setting project to: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Build container image
echo "🔨 Building container image..."
gcloud builds submit --tag $IMAGE_NAME .

# Deploy to Cloud Run
echo "🚢 Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image $IMAGE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --max-instances 10 \
  --set-env-vars FIREBASE_STORAGE_BUCKET=$PROJECT_ID.appspot.com

# Get service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --format 'value(status.url)')

echo "✅ Deployment complete!"
echo "🌐 Service URL: $SERVICE_URL"
echo "📚 API Docs: $SERVICE_URL/docs"
echo ""
echo "Test your API:"
echo "curl $SERVICE_URL/health"
