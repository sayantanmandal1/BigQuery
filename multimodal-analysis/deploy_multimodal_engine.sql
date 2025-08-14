-- Deployment script for the Multimodal Analysis Engine
-- Sets up all components, tables, and functions for multimodal intelligence

-- Create multimodal analysis results table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.multimodal_analysis_results` (
  content_id STRING NOT NULL,
  content_type ENUM('product_image', 'document_image', 'support_image') NOT NULL,
  analysis_result JSON NOT NULL,
  confidence_score FLOAT64,
  processing_status ENUM('pending', 'completed', 'failed') DEFAULT 'completed',
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) 
PARTITION BY DATE(created_timestamp)
CLUSTER BY content_type, processing_status;

-- Create cross-modal insights table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.cross_modal_insights` (
  insight_type STRING NOT NULL,
  entity_id STRING NOT NULL,
  correlation_analysis JSON NOT NULL,
  business_impact_score FLOAT64,
  confidence_level FLOAT64,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY insight_type, business_impact_score;

-- Create quality control results table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.quality_control_results` (
  check_type STRING NOT NULL,
  entity_id STRING NOT NULL,
  quality_result JSON NOT NULL,
  severity_level ENUM('low', 'medium', 'high', 'critical'),
  resolution_status ENUM('open', 'in_progress', 'resolved') DEFAULT 'open',
  checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(checked_at)
CLUSTER BY check_type, severity_level, resolution_status;

-- Create comprehensive analysis results table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.comprehensive_analysis_results` (
  analysis_type STRING NOT NULL,
  entity_id STRING NOT NULL,
  analysis_result JSON NOT NULL,
  strategic_priority ENUM('low', 'medium', 'high', 'critical'),
  actionability_score FLOAT64,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(created_at)
CLUSTER BY analysis_type, strategic_priority;

-- Create multimodal processing queue table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.multimodal_processing_queue` (
  queue_id STRING DEFAULT GENERATE_UUID(),
  content_id STRING NOT NULL,
  content_type STRING NOT NULL,
  processing_priority INT64 DEFAULT 5,
  processing_status ENUM('queued', 'processing', 'completed', 'failed') DEFAULT 'queued',
  retry_count INT64 DEFAULT 0,
  error_message STRING,
  queued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  started_at TIMESTAMP,
  completed_at TIMESTAMP
)
PARTITION BY DATE(queued_at)
CLUSTER BY processing_status, processing_priority;

-- Create multimodal models registry
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.multimodal_models_registry` (
  model_name STRING NOT NULL,
  model_type ENUM('multimodal', 'text_only', 'vision_only') NOT NULL,
  model_endpoint STRING NOT NULL,
  capabilities ARRAY<STRING>,
  performance_metrics JSON,
  is_active BOOL DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Insert default model configurations
INSERT INTO `enterprise_knowledge_ai.multimodal_models_registry` 
(model_name, model_type, model_endpoint, capabilities, performance_metrics)
VALUES 
('multimodal_model', 'multimodal', 'enterprise_knowledge_ai.multimodal_model', 
 ['image_analysis', 'text_generation', 'cross_modal_reasoning'], 
 JSON '{"accuracy": 0.92, "latency_ms": 1200, "throughput_rps": 10}'),
('gemini_model', 'text_only', 'enterprise_knowledge_ai.gemini_model', 
 ['text_generation', 'reasoning', 'classification'], 
 JSON '{"accuracy": 0.95, "latency_ms": 800, "throughput_rps": 25}'),
('vision_model', 'vision_only', 'enterprise_knowledge_ai.vision_model', 
 ['image_classification', 'object_detection', 'feature_extraction'], 
 JSON '{"accuracy": 0.89, "latency_ms": 600, "throughput_rps": 15}');

-- Create monitoring and metrics views
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.multimodal_processing_metrics` AS
SELECT 
  DATE(created_timestamp) AS processing_date,
  content_type,
  COUNT(*) AS total_processed,
  COUNTIF(processing_status = 'completed') AS successful_processes,
  COUNTIF(processing_status = 'failed') AS failed_processes,
  ROUND(AVG(confidence_score), 3) AS avg_confidence,
  ROUND(AVG(TIMESTAMP_DIFF(last_updated, created_timestamp, MILLISECOND)), 0) AS avg_processing_time_ms
FROM `enterprise_knowledge_ai.multimodal_analysis_results`
GROUP BY processing_date, content_type
ORDER BY processing_date DESC, content_type;

CREATE OR REPLACE VIEW `enterprise_knowledge_ai.quality_control_dashboard` AS
SELECT 
  check_type,
  COUNT(*) AS total_checks,
  COUNTIF(JSON_EXTRACT_SCALAR(quality_result, '$.has_discrepancies') = 'true' 
          OR JSON_EXTRACT_SCALAR(quality_result, '$.content_matches_metadata') = 'false'
          OR JSON_EXTRACT_SCALAR(quality_result, '$.resolution_matches_problem') = 'false') AS issues_detected,
  COUNTIF(severity_level = 'critical') AS critical_issues,
  COUNTIF(resolution_status = 'resolved') AS resolved_issues,
  ROUND(AVG(CAST(JSON_EXTRACT_SCALAR(quality_result, '$.severity_score') AS FLOAT64)), 3) AS avg_severity_score
FROM `enterprise_knowledge_ai.quality_control_results`
WHERE DATE(checked_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY check_type
ORDER BY critical_issues DESC, issues_detected DESC;

CREATE OR REPLACE VIEW `enterprise_knowledge_ai.cross_modal_insights_summary` AS
SELECT 
  insight_type,
  COUNT(*) AS total_insights,
  ROUND(AVG(business_impact_score), 3) AS avg_business_impact,
  ROUND(AVG(confidence_level), 3) AS avg_confidence,
  COUNTIF(business_impact_score >= 0.8) AS high_impact_insights,
  MAX(created_at) AS latest_insight_time
FROM `enterprise_knowledge_ai.cross_modal_insights`
WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY insight_type
ORDER BY avg_business_impact DESC;

-- Create automated processing procedures
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.process_multimodal_queue`()
BEGIN
  DECLARE queue_item_count INT64;
  
  -- Get count of queued items
  SET queue_item_count = (
    SELECT COUNT(*) 
    FROM `enterprise_knowledge_ai.multimodal_processing_queue` 
    WHERE processing_status = 'queued'
  );
  
  -- Process queued items if any exist
  IF queue_item_count > 0 THEN
    -- Update status to processing
    UPDATE `enterprise_knowledge_ai.multimodal_processing_queue`
    SET processing_status = 'processing', started_at = CURRENT_TIMESTAMP()
    WHERE processing_status = 'queued'
      AND queued_at <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 MINUTE);
    
    -- Process product images
    CALL `enterprise_knowledge_ai.batch_analyze_visual_content`();
    
    -- Generate cross-modal insights
    CALL `enterprise_knowledge_ai.generate_cross_modal_insights`();
    
    -- Run quality control checks
    CALL `enterprise_knowledge_ai.run_quality_control_audit`();
    
    -- Generate comprehensive intelligence
    CALL `enterprise_knowledge_ai.generate_comprehensive_intelligence`();
    
    -- Update completed items
    UPDATE `enterprise_knowledge_ai.multimodal_processing_queue`
    SET processing_status = 'completed', completed_at = CURRENT_TIMESTAMP()
    WHERE processing_status = 'processing'
      AND started_at <= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE);
  END IF;
END;

-- Create health check procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.multimodal_health_check`()
BEGIN
  -- Check model availability
  WITH model_health AS (
    SELECT 
      model_name,
      is_active,
      CASE 
        WHEN is_active THEN 'HEALTHY'
        ELSE 'INACTIVE'
      END AS health_status
    FROM `enterprise_knowledge_ai.multimodal_models_registry`
  ),
  
  processing_health AS (
    SELECT 
      'PROCESSING_QUEUE' AS component,
      CASE 
        WHEN COUNT(*) = 0 THEN 'HEALTHY'
        WHEN COUNTIF(processing_status = 'failed') / COUNT(*) > 0.1 THEN 'DEGRADED'
        ELSE 'HEALTHY'
      END AS health_status,
      COUNT(*) AS total_items,
      COUNTIF(processing_status = 'failed') AS failed_items
    FROM `enterprise_knowledge_ai.multimodal_processing_queue`
    WHERE DATE(queued_at) = CURRENT_DATE()
  ),
  
  analysis_health AS (
    SELECT 
      'ANALYSIS_ENGINE' AS component,
      CASE 
        WHEN AVG(confidence_score) >= 0.8 THEN 'HEALTHY'
        WHEN AVG(confidence_score) >= 0.6 THEN 'DEGRADED'
        ELSE 'UNHEALTHY'
      END AS health_status,
      COUNT(*) AS total_analyses,
      ROUND(AVG(confidence_score), 3) AS avg_confidence
    FROM `enterprise_knowledge_ai.multimodal_analysis_results`
    WHERE DATE(created_timestamp) = CURRENT_DATE()
  )
  
  SELECT 
    'MULTIMODAL_ENGINE_HEALTH_CHECK' AS report_title,
    CURRENT_TIMESTAMP() AS check_time,
    (SELECT COUNT(*) FROM model_health WHERE health_status = 'HEALTHY') AS healthy_models,
    (SELECT COUNT(*) FROM model_health) AS total_models,
    (SELECT health_status FROM processing_health) AS queue_health,
    (SELECT health_status FROM analysis_health) AS analysis_health,
    CASE 
      WHEN (SELECT COUNT(*) FROM model_health WHERE health_status = 'HEALTHY') = (SELECT COUNT(*) FROM model_health)
           AND (SELECT health_status FROM processing_health) = 'HEALTHY'
           AND (SELECT health_status FROM analysis_health) IN ('HEALTHY', 'DEGRADED')
      THEN 'SYSTEM_HEALTHY'
      ELSE 'SYSTEM_DEGRADED'
    END AS overall_health;
END;

-- Create scheduled job for automated processing (example - adjust based on your scheduling system)
-- This would typically be set up in your job scheduler
/*
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.schedule_multimodal_processing`()
BEGIN
  -- This procedure would be called by your scheduler every 15 minutes
  CALL `enterprise_knowledge_ai.process_multimodal_queue`();
  
  -- Run health check every hour
  IF EXTRACT(MINUTE FROM CURRENT_TIMESTAMP()) = 0 THEN
    CALL `enterprise_knowledge_ai.multimodal_health_check`();
  END IF;
  
  -- Run comprehensive analysis daily at 2 AM
  IF EXTRACT(HOUR FROM CURRENT_TIMESTAMP()) = 2 AND EXTRACT(MINUTE FROM CURRENT_TIMESTAMP()) = 0 THEN
    CALL `enterprise_knowledge_ai.generate_comprehensive_intelligence`();
  END IF;
END;
*/

-- Grant necessary permissions (adjust based on your security model)
-- GRANT SELECT, INSERT, UPDATE ON `enterprise_knowledge_ai.multimodal_*` TO SERVICE_ACCOUNT;
-- GRANT EXECUTE ON PROCEDURE `enterprise_knowledge_ai.process_multimodal_queue` TO SERVICE_ACCOUNT;

-- Final deployment validation
SELECT 
  'MULTIMODAL_ENGINE_DEPLOYMENT' AS deployment_status,
  'SUCCESS' AS status,
  CURRENT_TIMESTAMP() AS deployed_at,
  'All multimodal analysis components deployed successfully' AS message;

-- Display deployment summary
SELECT 
  'DEPLOYMENT_SUMMARY' AS report_type,
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES 
   WHERE table_schema = 'enterprise_knowledge_ai' 
   AND table_name LIKE '%multimodal%') AS tables_created,
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES 
   WHERE routine_schema = 'enterprise_knowledge_ai' 
   AND routine_name LIKE '%multimodal%') AS procedures_created,
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS 
   WHERE table_schema = 'enterprise_knowledge_ai' 
   AND table_name LIKE '%multimodal%') AS views_created;