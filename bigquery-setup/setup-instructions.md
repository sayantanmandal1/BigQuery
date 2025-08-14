# BigQuery Setup Instructions for Enterprise Knowledge Intelligence Platform

This directory contains SQL scripts to set up the complete BigQuery infrastructure for the Enterprise Knowledge Intelligence Platform.

## Prerequisites

1. **Google Cloud Project**: Ensure you have a Google Cloud project with billing enabled
2. **BigQuery API**: Enable the BigQuery API in your project
3. **Cloud Storage**: Create Cloud Storage buckets for multimodal content
4. **Authentication**: Set up appropriate service accounts and permissions

## Setup Order

Execute the SQL scripts in the following order:

### 1. Dataset Creation (`01-dataset-creation.sql`)
Creates the main datasets:
- `enterprise_knowledge_ai` - Main production dataset
- `enterprise_knowledge_ai_models` - ML models and AI functions
- `enterprise_knowledge_ai_staging` - Temporary processing area

### 2. Core Tables (`02-core-tables.sql`)
Creates the fundamental tables:
- `enterprise_knowledge_base` - Main knowledge repository with vector embeddings
- `generated_insights` - AI-generated business intelligence
- `user_interactions` - User behavior tracking for personalization

### 3. Object Tables (`03-object-tables.sql`)
Sets up multimodal content storage:
- External tables for documents, images, and videos
- Content catalog with metadata
- Unified view for easy querying

**Important**: Before running this script, update the placeholders:
- Replace `[PROJECT_ID]` with your actual Google Cloud project ID
- Replace `[BUCKET_NAME]` with your Cloud Storage bucket name
- Ensure Cloud Storage connection is created

### 4. Vector Indexes (`04-vector-indexes.sql`)
Creates optimized indexes for semantic search:
- Primary vector index for all content
- Specialized indexes for different content types
- Composite indexes for efficient filtering

### 5. Authentication Setup (`05-authentication-setup.sql`)
Configures security and access controls:
- Service account permissions
- Row-level security policies
- Column-level security for PII
- Audit logging setup

## Cloud Storage Setup

Before running the Object Tables script, create the required Cloud Storage buckets:

```bash
# Create buckets for multimodal content
gsutil mb gs://[BUCKET_NAME]-documents
gsutil mb gs://[BUCKET_NAME]-images  
gsutil mb gs://[BUCKET_NAME]-videos

# Set appropriate permissions
gsutil iam ch serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com:objectViewer gs://[BUCKET_NAME]-documents
gsutil iam ch serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com:objectViewer gs://[BUCKET_NAME]-images
gsutil iam ch serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com:objectViewer gs://[BUCKET_NAME]-videos
```

## Service Account Setup

Run these gcloud commands before executing the authentication setup:

```bash
# Create service accounts
gcloud iam service-accounts create enterprise-knowledge-ai-app \
  --display-name="Enterprise Knowledge AI Application"

gcloud iam service-accounts create enterprise-knowledge-ai-ingestion \
  --display-name="Enterprise Knowledge AI Data Ingestion"

gcloud iam service-accounts create enterprise-knowledge-ai-ml \
  --display-name="Enterprise Knowledge AI ML Operations"

# Grant BigQuery permissions
gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"
```

## Verification

After setup, verify the installation:

```sql
-- Check datasets
SELECT schema_name, location, creation_time 
FROM `[PROJECT_ID].INFORMATION_SCHEMA.SCHEMATA`
WHERE schema_name LIKE 'enterprise_knowledge%';

-- Check tables
SELECT table_name, table_type, creation_time
FROM `[PROJECT_ID].enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`;

-- Check vector indexes
SELECT index_name, table_name, index_status
FROM `[PROJECT_ID].enterprise_knowledge_ai.INFORMATION_SCHEMA.VECTOR_INDEXES`;
```

## Configuration Variables

Update these placeholders throughout the scripts:
- `[PROJECT_ID]` - Your Google Cloud project ID
- `[BUCKET_NAME]` - Your Cloud Storage bucket prefix
- `company.com` - Your organization's domain for access policies

## Security Considerations

1. **Service Accounts**: Use principle of least privilege
2. **Row-Level Security**: Customize policies based on your organization structure
3. **Audit Logging**: Monitor all access and modifications
4. **Data Classification**: Implement appropriate data classification levels
5. **Network Security**: Consider VPC-native clusters and private endpoints

## Cost Optimization

1. **Partitioning**: All large tables are partitioned by date
2. **Clustering**: Tables are clustered on frequently queried columns
3. **Expiration**: Staging tables have automatic expiration
4. **Slot Reservations**: Consider BigQuery reservations for predictable workloads

## Monitoring and Maintenance

1. **Query Performance**: Monitor vector search performance
2. **Storage Growth**: Track data growth and optimize partitioning
3. **Index Maintenance**: Vector indexes may need periodic optimization
4. **Access Patterns**: Review and adjust security policies based on usage