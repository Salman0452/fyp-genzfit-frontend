# GenzFit Backend Deployment Guide 🚀

Complete guide for deploying the GenzFit Avatar Backend API to various cloud platforms.

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Google Cloud Run](#google-cloud-run)
- [Railway.app](#railwayapp)
- [Heroku](#heroku)
- [AWS Elastic Beanstalk](#aws-elastic-beanstalk)
- [DigitalOcean App Platform](#digitalocean-app-platform)

---

## Prerequisites

Before deployment, ensure you have:

1. ✅ Firebase project set up
2. ✅ Firebase service account credentials JSON
3. ✅ Firebase Storage bucket enabled
4. ✅ Backend code tested locally
5. ✅ Cloud platform account

---

## Google Cloud Run (Recommended)

### Why Cloud Run?
- **Serverless**: Scales to zero when idle
- **Cost-effective**: Pay only for actual usage
- **Fast**: Cold start < 2 seconds
- **Managed**: No server maintenance

### Step-by-Step Deployment

#### 1. Install Google Cloud SDK

```bash
# macOS
brew install google-cloud-sdk

# Or download from: https://cloud.google.com/sdk/install
```

#### 2. Authenticate

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

#### 3. Enable Required APIs

```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable containerregistry.googleapis.com
```

#### 4. Deploy

```bash
cd backend
chmod +x deploy-gcloud.sh
./deploy-gcloud.sh
```

Or manually:

```bash
# Build image
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/avatar-api

# Deploy
gcloud run deploy avatar-api \
  --image gcr.io/YOUR_PROJECT_ID/avatar-api \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --set-env-vars FIREBASE_STORAGE_BUCKET=YOUR_PROJECT_ID.appspot.com
```

#### 5. Set Environment Variables

```bash
gcloud run services update avatar-api \
  --update-env-vars FIREBASE_CREDENTIALS_JSON="$(cat firebase-service-account.json)" \
  --region us-central1
```

#### 6. Get Service URL

```bash
gcloud run services describe avatar-api \
  --platform managed \
  --region us-central1 \
  --format 'value(status.url)'
```

### Cost Estimate
- **Free tier**: 2 million requests/month
- **Estimated**: $5-15/month for moderate usage

---

## Railway.app

### Why Railway?
- **Easiest**: Deploy in 2 minutes
- **GitHub Integration**: Auto-deploy on push
- **Built-in monitoring**: Logs and metrics

### Step-by-Step Deployment

#### 1. Sign Up
Visit [railway.app](https://railway.app) and sign up with GitHub.

#### 2. Create New Project
1. Click "New Project"
2. Select "Deploy from GitHub repo"
3. Choose your repository
4. Railway auto-detects Dockerfile

#### 3. Set Environment Variables
In Railway dashboard:
1. Go to Variables tab
2. Add:
   ```
   FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com
   FIREBASE_CREDENTIALS_JSON=<paste-service-account-json>
   ```

#### 4. Deploy
Railway automatically deploys! 🎉

#### 5. Get URL
Find your service URL in the Settings tab.

### Cost Estimate
- **Free tier**: $5 credit/month
- **Estimated**: $5-10/month

---

## Heroku

### Step-by-Step Deployment

#### 1. Install Heroku CLI

```bash
# macOS
brew tap heroku/brew && brew install heroku

# Or: https://devcenter.heroku.com/articles/heroku-cli
```

#### 2. Login

```bash
heroku login
```

#### 3. Create App

```bash
cd backend
heroku create genzfit-avatar-api
```

#### 4. Set Stack to Container

```bash
heroku stack:set container
```

#### 5. Set Environment Variables

```bash
heroku config:set FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com
heroku config:set FIREBASE_CREDENTIALS_JSON="$(cat firebase-service-account.json)"
```

#### 6. Create heroku.yml

```yaml
build:
  docker:
    web: Dockerfile
run:
  web: uvicorn main:app --host 0.0.0.0 --port $PORT
```

#### 7. Deploy

```bash
git add heroku.yml
git commit -m "Add Heroku config"
git push heroku main
```

#### 8. Open App

```bash
heroku open
```

### Cost Estimate
- **Free tier**: Discontinued
- **Hobby**: $7/month
- **Standard**: $25/month

---

## AWS Elastic Beanstalk

### Step-by-Step Deployment

#### 1. Install EB CLI

```bash
pip install awsebcli
```

#### 2. Initialize

```bash
cd backend
eb init -p docker genzfit-avatar-api --region us-east-1
```

#### 3. Create Environment

```bash
eb create production
```

#### 4. Set Environment Variables

```bash
eb setenv FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com
eb setenv FIREBASE_CREDENTIALS_JSON="$(cat firebase-service-account.json)"
```

#### 5. Deploy

```bash
eb deploy
```

#### 6. Open

```bash
eb open
```

### Cost Estimate
- **t3.small**: $15-30/month

---

## DigitalOcean App Platform

### Step-by-Step Deployment

#### 1. Sign Up
Visit [digitalocean.com](https://www.digitalocean.com/products/app-platform)

#### 2. Create App
1. Click "Create App"
2. Connect GitHub
3. Select repository
4. Choose Dockerfile

#### 3. Configure
1. Set build command: (auto-detected)
2. Set run command: `uvicorn main:app --host 0.0.0.0 --port 8080`

#### 4. Environment Variables
Add in dashboard:
```
FIREBASE_STORAGE_BUCKET=your-bucket.appspot.com
FIREBASE_CREDENTIALS_JSON=<paste-json>
```

#### 5. Deploy
Click "Deploy"

### Cost Estimate
- **Basic**: $5/month
- **Professional**: $12/month

---

## 🔐 Security Best Practices

### 1. Use Secrets Management
Never commit credentials to Git!

**Google Cloud:**
```bash
gcloud secrets create firebase-credentials --data-file=firebase-service-account.json
```

**Railway/Heroku:**
Use environment variables in dashboard.

### 2. Enable CORS Properly

Update `backend/config/settings.py`:
```python
ALLOWED_ORIGINS = [
    "https://your-flutter-app.web.app",
    "https://your-flutter-app.firebaseapp.com"
]
```

### 3. Add Rate Limiting

Install:
```bash
pip install slowapi
```

Add to `main.py`:
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
```

### 4. Enable Authentication

Add Firebase Auth middleware to protect endpoints.

---

## 🧪 Testing Deployment

### 1. Health Check

```bash
curl https://your-api-url.com/health
```

### 2. Generate Avatar Test

```bash
curl -X POST https://your-api-url.com/api/v1/avatar/generate \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test123",
    "height": 175,
    "weight": 75,
    "measurements": {"chest": 100, "waist": 85},
    "landmarks": {},
    "gender": "male"
  }'
```

### 3. Load Testing

```bash
# Install Apache Bench
sudo apt-get install apache2-utils

# Test 100 requests with 10 concurrent
ab -n 100 -c 10 https://your-api-url.com/health
```

---

## 📊 Monitoring

### Google Cloud Run

```bash
# View logs
gcloud run services logs read avatar-api --region us-central1

# View metrics
gcloud run services describe avatar-api --region us-central1
```

### Railway/Heroku

Check dashboard for built-in logs and metrics.

---

## 🔄 CI/CD Setup

### GitHub Actions

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches: [ main ]
    paths:
      - 'backend/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Setup Cloud SDK
      uses: google-github-actions/setup-gcloud@v0
      with:
        project_id: ${{ secrets.GCP_PROJECT_ID }}
        service_account_key: ${{ secrets.GCP_SA_KEY }}
    
    - name: Build and Deploy
      run: |
        cd backend
        gcloud builds submit --tag gcr.io/${{ secrets.GCP_PROJECT_ID }}/avatar-api
        gcloud run deploy avatar-api \
          --image gcr.io/${{ secrets.GCP_PROJECT_ID }}/avatar-api \
          --platform managed \
          --region us-central1 \
          --allow-unauthenticated
```

---

## 🆘 Troubleshooting

### Issue: Cold Start Timeouts

**Solution**: Increase timeout
```bash
gcloud run services update avatar-api --timeout 300
```

### Issue: Out of Memory

**Solution**: Increase memory
```bash
gcloud run services update avatar-api --memory 2Gi
```

### Issue: Firebase Connection Failed

**Solution**: Check credentials
```bash
# Test locally first
python -c "from utils.firebase_admin import initialize_firebase; initialize_firebase()"
```

### Issue: CORS Errors

**Solution**: Update allowed origins in `config/settings.py`

---

## 📝 Post-Deployment Checklist

- [ ] API health check returns 200
- [ ] Can generate avatar successfully
- [ ] Can update physique
- [ ] Logs are accessible
- [ ] Environment variables set correctly
- [ ] CORS configured for Flutter app
- [ ] Rate limiting enabled
- [ ] Monitoring/alerting set up
- [ ] Domain configured (optional)
- [ ] SSL certificate active
- [ ] Backup strategy in place

---

## 💡 Tips

1. **Start with Railway/Cloud Run**: Easiest for beginners
2. **Use staging environment**: Test before production
3. **Monitor costs**: Set up billing alerts
4. **Cache responses**: Add Redis for better performance
5. **Auto-scaling**: Configure based on traffic patterns

---

## 📞 Support

If you encounter issues:
1. Check logs first
2. Test locally with same environment variables
3. Review [GitHub Issues](https://github.com/your-repo/issues)
4. Contact support team

---

**Happy Deploying! 🚀**
