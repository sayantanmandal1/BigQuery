-- Enterprise Knowledge Intelligence Platform - Authentication and Security Setup
-- This script configures authentication, access controls, and security policies

-- Create service accounts and roles for different components
-- Note: These are SQL comments showing the gcloud commands that need to be run
-- The actual service account creation must be done via gcloud CLI or Cloud Console

/*
Required gcloud commands to run before executing this SQL:

# Create service account for the application
gcloud iam service-accounts create enterprise-knowledge-ai-app \
  --display-name="Enterprise Knowledge AI Application" \
  --description="Service account for the Enterprise Knowledge AI Platform"

# Create service account for data ingestion
gcloud iam service-accounts create enterprise-knowledge-ai-ingestion \
  --display-name="Enterprise Knowledge AI Data Ingestion" \
  --description="Service account for data ingestion processes"

# Create service account for ML model operations
gcloud iam service-accounts create enterprise-knowledge-ai-ml \
  --display-name="Enterprise Knowledge AI ML Operations" \
  --description="Service account for ML model training and inference"

# Grant necessary BigQuery permissions
gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:enterprise-knowledge-ai-ingestion@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:enterprise-knowledge-ai-ml@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/bigquery.admin"

# Grant Cloud Storage permissions for Object Tables
gcloud projects add-iam-policy-binding [PROJECT_ID] \
  --member="serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
*/

-- Create dataset-level access controls
-- Grant read access to application service account
GRANT `roles/bigquery.dataViewer`
ON SCHEMA `enterprise_knowledge_ai`
TO "serviceAccount:enterprise-knowledge-ai-app@[PROJECT_ID].iam.gserviceaccount.com";

-- Grant write access to ingestion service account
GRANT `roles/bigquery.dataEditor`
ON SCHEMA `enterprise_knowledge_ai`
TO "serviceAccount:enterprise-knowledge-ai-ingestion@[PROJECT_ID].iam.gserviceaccount.com";

-- Grant ML model access
GRANT `roles/bigquery.admin`
ON SCHEMA `enterprise_knowledge_ai_models`
TO "serviceAccount:enterprise-knowledge-ai-ml@[PROJECT_ID].iam.gserviceaccount.com";

-- Create row-level security policies for sensitive data
CREATE ROW ACCESS POLICY IF NOT EXISTS `classification_level_policy`
ON `enterprise_knowledge_ai.enterprise_knowledge_base`
GRANT TO ("group:executives@company.com", "group:senior-analysts@company.com")
FILTER USING (classification_level IN ('public', 'internal', 'confidential'));

CREATE ROW ACCESS POLICY IF NOT EXISTS `department_access_policy`
ON `enterprise_knowledge_ai.user_interactions`
GRANT TO ("group:hr-team@company.com")
FILTER USING (department = 'HR' OR SESSION_USER() LIKE '%hr-team@company.com');

-- Create column-level security for PII data
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.user_interactions_secure` AS
SELECT 
  interaction_id,
  CASE 
    WHEN SESSION_USER() LIKE '%admin@company.com' THEN user_id
    ELSE CONCAT('user_', FARM_FINGERPRINT(user_id))
  END AS user_id,
  insight_id,
  knowledge_id,
  interaction_type,
  interaction_timestamp,
  session_id,
  user_role,
  department,
  feedback_score,
  time_spent_seconds,
  context_metadata,
  device_type,
  location_country
FROM `enterprise_knowledge_ai.user_interactions`;

-- Audit logging setup
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.audit_log` (
  audit_id STRING NOT NULL DEFAULT GENERATE_UUID(),
  timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  user_email STRING,
  action STRING NOT NULL,
  resource_type STRING NOT NULL,
  resource_id STRING,
  details JSON,
  ip_address STRING,
  user_agent STRING,
  success BOOL NOT NULL
)
PARTITION BY DATE(timestamp)
CLUSTER BY action, resource_type, success
OPTIONS (
  description = "Audit log for all platform activities",
  labels = [("table-type", "audit"), ("data-classification", "security")]
);