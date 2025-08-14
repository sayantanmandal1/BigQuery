-- Enterprise Knowledge Intelligence Platform - Core Table Schemas
-- This script creates the main tables for the platform

-- Core enterprise knowledge base table with vector embeddings
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.enterprise_knowledge_base` (
  knowledge_id STRING NOT NULL,
  content_type STRING NOT NULL,
  source_system STRING NOT NULL,
  content TEXT,
  metadata JSON,
  embedding ARRAY<FLOAT64>,
  created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  access_permissions ARRAY<STRING>,
  content_hash STRING,
  file_size_bytes INT64,
  language_code STRING DEFAULT 'en',
  classification_level STRING DEFAULT 'internal',
  tags ARRAY<STRING>
)
PARTITION BY DATE(created_timestamp)
CLUSTER BY content_type, source_system, classification_level
OPTIONS (
  description = "Main knowledge repository with vector embeddings for semantic search",
  labels = [("table-type", "core"), ("data-classification", "mixed")]
);

-- Generated insights table for storing AI-generated business intelligence
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.generated_insights` (
  insight_id STRING NOT NULL,
  source_data_ids ARRAY<STRING> NOT NULL,
  insight_type STRING NOT NULL,
  content TEXT NOT NULL,
  confidence_score FLOAT64,
  business_impact_score FLOAT64,
  target_audience ARRAY<STRING>,
  generated_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  expiration_timestamp TIMESTAMP,
  validation_status STRING DEFAULT 'pending',
  model_version STRING,
  processing_time_ms INT64,
  feedback_score FLOAT64,
  action_taken BOOL DEFAULT FALSE
)
PARTITION BY DATE(generated_timestamp)
CLUSTER BY insight_type, business_impact_score, validation_status
OPTIONS (
  description = "AI-generated insights and recommendations with confidence scoring",
  labels = [("table-type", "core"), ("data-classification", "business-intelligence")]
);

-- User interactions tracking for personalization and analytics
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.user_interactions` (
  interaction_id STRING NOT NULL,
  user_id STRING NOT NULL,
  insight_id STRING,
  knowledge_id STRING,
  interaction_type STRING NOT NULL,
  interaction_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  session_id STRING,
  user_role STRING,
  department STRING,
  feedback_score INT64,
  time_spent_seconds INT64,
  context_metadata JSON,
  device_type STRING,
  location_country STRING
)
PARTITION BY DATE(interaction_timestamp)
CLUSTER BY user_id, interaction_type, user_role
OPTIONS (
  description = "User interaction tracking for personalization and usage analytics",
  labels = [("table-type", "core"), ("data-classification", "user-behavior")]
);