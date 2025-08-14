#!/bin/bash

# Enterprise Knowledge Intelligence Platform - BigQuery Deployment Script
# This script automates the setup of the BigQuery infrastructure

set -e  # Exit on any error

# Configuration variables
PROJECT_ID="${1:-your-project-id}"
BUCKET_PREFIX="${2:-enterprise-knowledge-ai}"
REGION="${3:-us-central1}"

if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo "Usage: $0 <PROJECT_ID> [BUCKET_PREFIX] [REGION]"
    echo "Example: $0 my-gcp-project enterprise-ai us-central1"
    exit 1
fi

echo "🚀 Starting BigQuery setup for Enterprise Knowledge Intelligence Platform"
echo "Project ID: $PROJECT_ID"
echo "Bucket Prefix: $BUCKET_PREFIX"
echo "Region: $REGION"

# Set the project
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "📡 Enabling required APIs..."
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable bigqueryconnection.googleapis.com
gcloud services enable aiplatform.googleapis.com

# Create Cloud Storage buckets
echo "🪣 Creating Cloud Storage buckets..."
gsutil mb -l $REGION gs://$BUCKET_PREFIX-documents || echo "Bucket already exists"
gsutil mb -l $REGION gs://$BUCKET_PREFIX-images || echo "Bucket already exists"
gsutil mb -l $REGION gs://$BUCKET_PREFIX-videos || echo "Bucket already exists"

# Create service accounts
echo "🔐 Creating service accounts..."
gcloud iam service-accounts create enterprise-knowledge-ai-app \
    --display-name="Enterprise Knowledge AI Application" \
    --description="Service account for the Enterprise Knowledge AI Platform" || echo "Service account already exists"

gcloud iam service-accounts create enterprise-knowledge-ai-ingestion \
    --display-name="Enterprise Knowledge AI Data Ingestion" \
    --description="Service account for data ingestion processes" || echo "Service account already exists"

gcloud iam service-accounts create enterprise-knowledge-ai-ml \
    --display-name="Enterprise Knowledge AI ML Operations" \
    --description="Service account for ML model training and inference" || echo "Service account already exists"

# Grant BigQuery permissions
echo "🔑 Granting BigQuery permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:enterprise-knowledge-ai-app@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:enterprise-knowledge-ai-app@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:enterprise-knowledge-ai-ingestion@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:enterprise-knowledge-ai-ml@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.admin"

# Grant Cloud Storage permissions
echo "🗄️ Granting Cloud Storage permissions..."
gsutil iam ch serviceAccount:enterprise-knowledge-ai-app@$PROJECT_ID.iam.gserviceaccount.com:objectViewer gs://$BUCKET_PREFIX-documents
gsutil iam ch serviceAccount:enterprise-knowledge-ai-app@$PROJECT_ID.iam.gserviceaccount.com:objectViewer gs://$BUCKET_PREFIX-images
gsutil iam ch serviceAccount:enterprise-knowledge-ai-app@$PROJECT_ID.iam.gserviceaccount.com:objectViewer gs://$BUCKET_PREFIX-videos

gsutil iam ch serviceAccount:enterprise-knowledge-ai-ingestion@$PROJECT_ID.iam.gserviceaccount.com:objectAdmin gs://$BUCKET_PREFIX-documents
gsutil iam ch serviceAccount:enterprise-knowledge-ai-ingestion@$PROJECT_ID.iam.gserviceaccount.com:objectAdmin gs://$BUCKET_PREFIX-images
gsutil iam ch serviceAccount:enterprise-knowledge-ai-ingestion@$PROJECT_ID.iam.gserviceaccount.com:objectAdmin gs://$BUCKET_PREFIX-videos

# Function to execute SQL files with variable substitution
execute_sql() {
    local sql_file=$1
    echo "📊 Executing $sql_file..."
    
    # Replace placeholders in SQL file
    sed -e "s/\[PROJECT_ID\]/$PROJECT_ID/g" \
        -e "s/\[BUCKET_NAME\]/$BUCKET_PREFIX/g" \
        -e "s/\[REGION\]/$REGION/g" \
        "$sql_file" > "/tmp/$(basename $sql_file)"
    
    # Execute the SQL
    bq query --use_legacy_sql=false --max_rows=0 < "/tmp/$(basename $sql_file)"
    
    # Clean up temp file
    rm "/tmp/$(basename $sql_file)"
}

# Execute SQL scripts in order
echo "🏗️ Creating BigQuery infrastructure..."

execute_sql "01-dataset-creation.sql"
echo "✅ Datasets created"

execute_sql "02-core-tables.sql"
echo "✅ Core tables created"

execute_sql "connection-setup.sql"
echo "✅ Connections created"

execute_sql "03-object-tables.sql"
echo "✅ Object tables created"

execute_sql "04-vector-indexes.sql"
echo "✅ Vector indexes created"

execute_sql "05-authentication-setup.sql"
echo "✅ Authentication configured"

# Verify setup
echo "🔍 Verifying setup..."
bq query --use_legacy_sql=false --format=table \
    "SELECT schema_name, location, creation_time 
     FROM \`$PROJECT_ID.INFORMATION_SCHEMA.SCHEMATA\`
     WHERE schema_name LIKE 'enterprise_knowledge%'"

echo "🎉 BigQuery setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Upload sample data to Cloud Storage buckets"
echo "2. Test the vector search functionality"
echo "3. Configure AI models for embedding generation"
echo "4. Set up monitoring and alerting"
echo ""
echo "Buckets created:"
echo "- gs://$BUCKET_PREFIX-documents"
echo "- gs://$BUCKET_PREFIX-images"
echo "- gs://$BUCKET_PREFIX-videos"
echo ""
echo "Service accounts created:"
echo "- enterprise-knowledge-ai-app@$PROJECT_ID.iam.gserviceaccount.com"
echo "- enterprise-knowledge-ai-ingestion@$PROJECT_ID.iam.gserviceaccount.com"
echo "- enterprise-knowledge-ai-ml@$PROJECT_ID.iam.gserviceaccount.com"