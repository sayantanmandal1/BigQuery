-- Enterprise Knowledge Intelligence Platform - Object Tables for Multimodal Content
-- This script creates Object Tables for handling multimodal content (images, documents, videos)

-- Object table for document storage and analysis
CREATE OR REPLACE EXTERNAL TABLE `enterprise_knowledge_ai.document_objects`
WITH CONNECTION `projects/[PROJECT_ID]/locations/us/connections/cloud-storage-connection`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://[BUCKET_NAME]/documents/*'],
  max_staleness = INTERVAL 1 HOUR,
  metadata_cache_mode = 'AUTOMATIC'
);

-- Object table for image content storage
CREATE OR REPLACE EXTERNAL TABLE `enterprise_knowledge_ai.image_objects`
WITH CONNECTION `projects/[PROJECT_ID]/locations/us/connections/cloud-storage-connection`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://[BUCKET_NAME]/images/*'],
  max_staleness = INTERVAL 1 HOUR,
  metadata_cache_mode = 'AUTOMATIC'
);

-- Object table for video content storage
CREATE OR REPLACE EXTERNAL TABLE `enterprise_knowledge_ai.video_objects`
WITH CONNECTION `projects/[PROJECT_ID]/locations/us/connections/cloud-storage-connection`
OPTIONS (
  object_metadata = 'SIMPLE',
  uris = ['gs://[BUCKET_NAME]/videos/*'],
  max_staleness = INTERVAL 1 HOUR,
  metadata_cache_mode = 'AUTOMATIC'
);

-- Multimodal content catalog linking objects to structured metadata
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.multimodal_content_catalog` (
  content_id STRING NOT NULL,
  object_uri STRING NOT NULL,
  content_type STRING NOT NULL, -- 'document', 'image', 'video', 'audio'
  file_format STRING NOT NULL, -- 'pdf', 'jpg', 'mp4', etc.
  title STRING,
  description TEXT,
  tags ARRAY<STRING>,
  created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  last_modified TIMESTAMP,
  file_size_bytes INT64,
  duration_seconds FLOAT64, -- for video/audio content
  dimensions_width INT64, -- for images/videos
  dimensions_height INT64, -- for images/videos
  extracted_text TEXT, -- OCR/transcript results
  ai_analysis_results JSON, -- Results from multimodal AI analysis
  access_permissions ARRAY<STRING>,
  source_system STRING,
  business_context JSON -- Links to related business entities
)
PARTITION BY DATE(created_timestamp)
CLUSTER BY content_type, file_format, source_system
OPTIONS (
  description = "Catalog of multimodal content with metadata and AI analysis results",
  labels = [("table-type", "multimodal"), ("data-classification", "content-catalog")]
);

-- View combining object tables with catalog metadata for easy querying
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.unified_multimodal_content` AS
SELECT 
  c.content_id,
  c.object_uri,
  c.content_type,
  c.file_format,
  c.title,
  c.description,
  c.tags,
  c.created_timestamp,
  c.file_size_bytes,
  c.extracted_text,
  c.ai_analysis_results,
  c.business_context,
  -- Add object references based on content type
  CASE 
    WHEN c.content_type = 'document' THEN 
      (SELECT uri FROM `enterprise_knowledge_ai.document_objects` WHERE uri = c.object_uri LIMIT 1)
    WHEN c.content_type = 'image' THEN 
      (SELECT uri FROM `enterprise_knowledge_ai.image_objects` WHERE uri = c.object_uri LIMIT 1)
    WHEN c.content_type = 'video' THEN 
      (SELECT uri FROM `enterprise_knowledge_ai.video_objects` WHERE uri = c.object_uri LIMIT 1)
  END AS object_reference
FROM `enterprise_knowledge_ai.multimodal_content_catalog` c;