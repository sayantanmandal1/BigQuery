-- Enterprise Knowledge Intelligence Platform - Connection Setup
-- This script creates the necessary connections for external data sources and Cloud Storage

-- Create Cloud Storage connection for Object Tables
-- Note: This requires the BigQuery Connection API to be enabled
CREATE OR REPLACE EXTERNAL CONNECTION `projects/[PROJECT_ID]/locations/us/connections/cloud-storage-connection`
OPTIONS (
  connection_type = 'CLOUD_STORAGE',
  description = 'Connection for accessing multimodal content in Cloud Storage'
);

-- Grant the connection service account access to Cloud Storage buckets
-- The service account email will be displayed after creating the connection
-- Run this query to get the service account:
-- SELECT connection_id, creation_time, last_modified_time, 
--        cloud_storage.service_account_id as service_account_email
-- FROM `[PROJECT_ID].us.INFORMATION_SCHEMA.CONNECTIONS`
-- WHERE connection_id = 'cloud-storage-connection';

-- Create connection for external data sources (if needed)
CREATE OR REPLACE EXTERNAL CONNECTION `projects/[PROJECT_ID]/locations/us/connections/external-data-connection`
OPTIONS (
  connection_type = 'CLOUD_SQL',
  description = 'Connection for accessing external enterprise data sources'
);

-- Verify connections are created successfully
SELECT 
  connection_id,
  location,
  connection_type,
  description,
  creation_time,
  last_modified_time,
  cloud_storage.service_account_id as storage_service_account
FROM `[PROJECT_ID].us.INFORMATION_SCHEMA.CONNECTIONS`
WHERE connection_id IN ('cloud-storage-connection', 'external-data-connection');