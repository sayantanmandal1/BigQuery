-- Enterprise Knowledge Intelligence Platform - Dataset Setup
-- This script creates the main dataset and configures basic settings

-- Create the main dataset for the Enterprise Knowledge Intelligence Platform
CREATE SCHEMA IF NOT EXISTS `enterprise_knowledge_ai`
OPTIONS (
  description = "Enterprise Knowledge Intelligence Platform - Main dataset for AI-powered business intelligence",
  location = "US",
  default_table_expiration_days = 365,
  labels = [
    ("environment", "production"),
    ("project", "enterprise-knowledge-ai"),
    ("cost-center", "data-analytics")
  ]
);

-- Create a separate dataset for ML models
CREATE SCHEMA IF NOT EXISTS `enterprise_knowledge_ai_models`
OPTIONS (
  description = "ML models and AI functions for Enterprise Knowledge Intelligence Platform",
  location = "US",
  labels = [
    ("environment", "production"),
    ("project", "enterprise-knowledge-ai"),
    ("component", "ml-models")
  ]
);

-- Create dataset for temporary processing and staging
CREATE SCHEMA IF NOT EXISTS `enterprise_knowledge_ai_staging`
OPTIONS (
  description = "Staging area for data processing and temporary tables",
  location = "US",
  default_table_expiration_days = 7,
  labels = [
    ("environment", "staging"),
    ("project", "enterprise-knowledge-ai"),
    ("component", "staging")
  ]
);