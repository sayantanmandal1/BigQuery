-- =====================================================
-- INTEGRATION TESTING DEPLOYMENT SCRIPT
-- Deploy comprehensive end-to-end integration testing framework
-- =====================================================

-- Set project and dataset variables
DECLARE project_id STRING DEFAULT 'your-project-id';
DECLARE dataset_id STRING DEFAULT 'enterprise_ai';

-- Create dataset if not exists
CREATE SCHEMA IF NOT EXISTS `enterprise_ai`
OPTIONS (
  description = 'Enterprise Knowledge Intelligence Platform - Integration Testing',
  location = 'US'
);

-- Deploy core integration testing tables and procedures
-- This script should be run after the main system deployment

-- Verify required models exist before deploying tests
CREATE OR REPLACE FUNCTION `enterprise_ai.verify_test_prerequisites`()
RETURNS BOOL
LANGUAGE SQL
AS (
  -- Check if required AI models are available
  EXISTS(
    SELECT 1 FROM `enterprise_ai.INFORMATION_SCHEMA.MODELS`
    WHERE model_name IN ('text_embedding_model', 'gemini_model')
  )
  AND
  -- Check if core tables exist
  EXISTS(
    SELECT 1 FROM `enterprise_ai.INFORMATION_SCHEMA.TABLES`
    WHERE table_name IN ('enterprise_knowledge_base', 'generated_insights', 'user_interactions')
  )
);

-- Deploy integration testing framework only if prerequisites are met
BEGIN
  IF `enterprise_ai.verify_test_prerequisites`() THEN
    
    -- Create integration test result tables
    CREATE OR REPLACE TABLE `enterprise_ai.integration_test_results` (
      test_id STRING NOT NULL,
      test_name STRING NOT NULL,
      test_category ENUM('data_flow', 'cross_component', 'performance_regression'),
      start_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
      end_timestamp TIMESTAMP,
      status ENUM('running', 'passed', 'failed', 'error'),
      execution_time_ms INT64,
      error_message STRING,
      test_details JSON,
      performance_metrics JSON
    ) PARTITION BY DATE(start_timestamp)
    CLUSTER BY test_category, status;

    -- Create test data tracking table
    CREATE OR REPLACE TABLE `enterprise_ai.integration_test_data` (
      test_run_id STRING NOT NULL,
      data_type ENUM('structured', 'document', 'image', 'multimodal'),
      source_table STRING,
      record_count INT64,
      data_size_mb FLOAT64,
      processing_stage ENUM('ingestion', 'embedding', 'analysis', 'insight_generation', 'delivery'),
      stage_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
      stage_duration_ms INT64,
      stage_status ENUM('success', 'failed', 'timeout'),
      quality_score FLOAT64
    ) PARTITION BY DATE(stage_timestamp)
    CLUSTER BY test_run_id, processing_stage;

    -- Create performance baselines table
    CREATE OR REPLACE TABLE `enterprise_ai.performance_baselines` (
      test_name STRING NOT NULL,
      metric_name STRING NOT NULL,
      baseline_value FLOAT64 NOT NULL,
      threshold_percentage FLOAT64 DEFAULT 20.0,
      last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
    ) CLUSTER BY test_name, metric_name;

    -- Initialize performance baselines
    INSERT INTO `enterprise_ai.performance_baselines` 
    (test_name, metric_name, baseline_value, threshold_percentage) VALUES
    ('enterprise_scale_vector_search', 'avg_query_time_ms', 500.0, 25.0),
    ('enterprise_scale_vector_search', 'throughput_queries_per_second', 100.0, 15.0),
    ('bulk_embedding_generation', 'avg_embedding_time_ms', 200.0, 30.0),
    ('bulk_embedding_generation', 'embeddings_per_second', 50.0, 20.0),
    ('ai_generate_performance', 'avg_generation_time_ms', 1500.0, 40.0),
    ('ai_generate_performance', 'tokens_per_second', 25.0, 25.0),
    ('forecast_performance', 'avg_forecast_time_ms', 3000.0, 35.0),
    ('end_to_end_pipeline', 'total_pipeline_time_ms', 10000.0, 50.0);

    -- Create test session tracking table
    CREATE OR REPLACE TABLE `enterprise_ai.integration_test_sessions` (
      session_id STRING NOT NULL,
      start_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
      end_timestamp TIMESTAMP,
      total_tests INT64,
      passed_tests INT64,
      failed_tests INT64,
      error_tests INT64,
      overall_status ENUM('running', 'passed', 'failed', 'error'),
      session_summary JSON
    );

    -- Create alerts table
    CREATE OR REPLACE TABLE `enterprise_ai.integration_alerts` (
      alert_id STRING NOT NULL,
      alert_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
      alert_level ENUM('INFO', 'WARNING', 'CRITICAL'),
      alert_type ENUM('PERFORMANCE', 'FAILURE', 'HEALTH'),
      alert_message STRING,
      alert_details JSON,
      resolved BOOL DEFAULT FALSE
    ) PARTITION BY DATE(alert_timestamp)
    CLUSTER BY alert_level, alert_type;

    SELECT 'Integration testing framework deployed successfully' as deployment_status;
    
  ELSE
    SELECT 'Prerequisites not met - please deploy core system first' as deployment_status;
  END IF;
  
EXCEPTION WHEN ERROR THEN
  SELECT CONCAT('Deployment failed: ', @@error.message) as deployment_status;
END;

-- Create scheduled job for automated integration testing (optional)
-- This would typically be set up through Cloud Scheduler or similar service
/*
CREATE OR REPLACE PROCEDURE `enterprise_ai.schedule_integration_tests`()
BEGIN
  -- Run integration tests daily at 2 AM
  CALL `enterprise_ai.run_all_integration_tests`();
  
  -- Check for alerts after tests complete
  CALL `enterprise_ai.check_integration_alerts`();
  
  -- Cleanup old test data weekly
  IF EXTRACT(DAYOFWEEK FROM CURRENT_DATE()) = 1 THEN -- Sunday
    CALL `enterprise_ai.cleanup_integration_test_data`(30);
  END IF;
END;
*/

-- Grant necessary permissions for integration testing
-- Note: Adjust these based on your security requirements
/*
GRANT `roles/bigquery.dataEditor` ON SCHEMA `enterprise_ai` TO 'serviceAccount:integration-tests@your-project.iam.gserviceaccount.com';
GRANT `roles/bigquery.jobUser` ON PROJECT `your-project-id` TO 'serviceAccount:integration-tests@your-project.iam.gserviceaccount.com';
*/

-- Validation query to confirm deployment
SELECT 
  'Integration Testing Framework' as component,
  COUNT(*) as table_count,
  STRING_AGG(table_name ORDER BY table_name) as deployed_tables
FROM `enterprise_ai.INFORMATION_SCHEMA.TABLES`
WHERE table_name LIKE '%integration%' OR table_name LIKE '%performance%' OR table_name LIKE '%alert%';