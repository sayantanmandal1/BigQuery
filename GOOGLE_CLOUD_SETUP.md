# 🔧 Google Cloud BigQuery Setup Guide

## For Production Version with Real BigQuery Data

### 🎯 Quick Start Options

**Option 1: Use Demo Version (Recommended for Competition)**
- Run `Enterprise_AI_Intelligence_Platform_DEMO.ipynb` 
- No setup required - works immediately
- Full functionality with simulated data
- Perfect for competition demonstration

**Option 2: Connect to Real BigQuery (For Production)**
- Follow the setup steps below
- Access real public datasets
- Production-ready enterprise platform

---

## 🚀 Google Cloud Authentication Setup

### Step 1: Install Google Cloud CLI

**Windows:**
```powershell
# Download and install from: https://cloud.google.com/sdk/docs/install
# Or use chocolatey:
choco install gcloudsdk
```

**Alternative: Use Cloud Shell**
- Go to [Google Cloud Console](https://console.cloud.google.com)
- Click the Cloud Shell icon (>_) in the top right
- Run the notebook directly in Cloud Shell

### Step 2: Authenticate

```bash
# Login to Google Cloud
gcloud auth login

# Set up application default credentials
gcloud auth application-default login

# Set your project (replace with your project ID)
gcloud config set project YOUR_PROJECT_ID
```

### Step 3: Enable BigQuery API

```bash
# Enable BigQuery API
gcloud services enable bigquery.googleapis.com
```

### Step 4: Verify Setup

```python
# Test in Python
from google.cloud import bigquery
client = bigquery.Client()
print(f"Connected to project: {client.project}")
```

---

## 🎯 Alternative Setup Methods

### Method 1: Service Account Key (For Development)

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to IAM & Admin > Service Accounts
3. Create a new service account
4. Download the JSON key file
5. Set environment variable:

```bash
# Windows
set GOOGLE_APPLICATION_CREDENTIALS=path\to\your\key.json

# Linux/Mac
export GOOGLE_APPLICATION_CREDENTIALS=path/to/your/key.json
```

### Method 2: Google Colab (Easiest)

1. Upload notebook to [Google Colab](https://colab.research.google.com)
2. Add authentication cell:

```python
from google.colab import auth
auth.authenticate_user()
```

3. Run the notebook - authentication is automatic!

---

## 📊 Available Public Datasets

Once connected, you can access these BigQuery public datasets:

- `bigquery-public-data.hacker_news.full` - Hacker News data
- `bigquery-public-data.stackoverflow.posts_questions` - Stack Overflow
- `bigquery-public-data.github_repos.commits` - GitHub commits
- `bigquery-public-data.crypto_bitcoin.transactions` - Bitcoin transactions
- `bigquery-public-data.google_trends.top_terms` - Google Trends

---

## 🏆 Competition Recommendation

**For the competition, use the DEMO version:**

✅ **Advantages:**
- Works immediately without setup
- Full functionality demonstration
- Professional visualizations
- Complete business intelligence features
- No authentication issues during presentation

✅ **Perfect for judging:**
- Shows technical capability
- Demonstrates business value
- Professional presentation ready
- No technical setup delays

---

## 🚀 Production Deployment

After the competition, connect to real BigQuery for:

- **Real-time data processing**
- **Actual ML model training**
- **Live business intelligence**
- **Enterprise-scale analytics**

The demo shows exactly what the production system will do - just with real data!

---

## 🛠️ Troubleshooting

**Common Issues:**

1. **Credentials Error**: Use demo version or follow authentication steps
2. **Project Not Set**: Run `gcloud config set project YOUR_PROJECT_ID`
3. **API Not Enabled**: Run `gcloud services enable bigquery.googleapis.com`
4. **Permission Denied**: Ensure your account has BigQuery access

**Quick Fix**: Use the demo version - it's designed to work perfectly without any setup!

---

## 📞 Support

- **Demo Issues**: Check `Enterprise_AI_Intelligence_Platform_DEMO.ipynb`
- **BigQuery Setup**: Follow Google Cloud documentation
- **Competition Ready**: Demo version is fully functional

**🎯 Ready to win the competition with the demo version!**