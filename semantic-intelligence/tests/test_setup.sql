-- Test Setup and Results Tables
-- This script creates the necessary tables for storing test results and configurations

-- Create test results table for tracking all test executions
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.test_results` (
  test_id STRING NOT NULL DEFAULT GENERATE_UUID(),
  test_suite STRING NOT NULL,
  test_name STRING NOT NULL,
  status STRING NOT NULL,
  details TEXT,
  execution_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  execution_duration_ms INT64,
  test_data_snapshot JSON,
  environment STRING DEFAULT 'development'
)
PARTITION BY DATE(execution_timestamp)
CLUSTER BY test_suite, status
OPTIONS (
  description = "Test execution results and performance metrics",
  labels = [("table-type", "testing"), ("data-classification", "internal")]
);

-- Create processing logs table for monitoring batch operations
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.processing_logs` (
  log_id STRING NOT NULL DEFAULT GENERATE_UUID(),
  process_type STRING NOT NULL,
  records_processed INT64,
  processing_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  status STRING NOT NULL,
  error_message STRING,
  processing_duration_ms INT64,
  additional_metadata JSON
)
PARTITION BY DATE(processing_timestamp)
CLUSTER BY process_type, status
OPTIONS (
  description = "Processing logs for batch operations and monitoring",
  labels = [("table-type", "logging"), ("data-classification", "operational")]
);

-- Create benchmark datasets for consistent testing
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.benchmark_queries` (
  benchmark_id STRING NOT NULL,
  query_text STRING NOT NULL,
  expected_results ARRAY<STRUCT<
    document_id STRING,
    expected_rank INT64,
    minimum_similarity FLOAT64
  >>,
  query_category STRING,
  difficulty_level STRING,
  created_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP(),
  is_active BOOL DEFAULT TRUE
)
CLUSTER BY query_category, difficulty_level
OPTIONS (
  description = "Benchmark queries for consistent semantic search testing",
  labels = [("table-type", "testing"), ("data-classification", "benchmark")]
);

-- Insert benchmark queries for testing
INSERT INTO `enterprise_knowledge_ai.benchmark_queries` VALUES
(
  'bench_001',
  'quarterly financial performance and revenue growth analysis',
  [
    STRUCT('test_001' as document_id, 1 as expected_rank, 0.8 as minimum_similarity)
  ],
  'financial',
  'medium',
  CURRENT_TIMESTAMP(),
  TRUE
),
(
  'bench_002', 
  'microservices architecture implementation and system scalability',
  [
    STRUCT('test_002' as document_id, 1 as expected_rank, 0.8 as minimum_similarity)
  ],
  'technical',
  'medium',
  CURRENT_TIMESTAMP(),
  TRUE
),
(
  'bench_003',
  'customer satisfaction metrics and mobile application user engagement',
  [
    STRUCT('test_003' as document_id, 1 as expected_rank, 0.8 as minimum_similarity)
  ],
  'customer_experience',
  'medium',
  CURRENT_TIMESTAMP(),
  TRUE
),
(
  'bench_004',
  'strategic partnerships and Asia-Pacific market expansion opportunities',
  [
    STRUCT('test_004' as document_id, 1 as expected_rank, 0.8 as minimum_similarity)
  ],
  'strategic',
  'hard',
  CURRENT_TIMESTAMP(),
  TRUE
),
(
  'bench_005',
  'employee productivity improvements through flexible work arrangements',
  [
    STRUCT('test_005' as document_id, 1 as expected_rank, 0.8 as minimum_similarity)
  ],
  'operational',
  'medium',
  CURRENT_TIMESTAMP(),
  TRUE
);

-- Create performance monitoring view
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.test_performance_summary` AS
SELECT 
  test_suite,
  test_name,
  DATE(execution_timestamp) as test_date,
  COUNT(*) as execution_count,
  COUNTIF(status = 'PASSED') as passed_count,
  COUNTIF(status = 'FAILED') as failed_count,
  SAFE_DIVIDE(COUNTIF(status = 'PASSED'), COUNT(*)) as success_rate,
  AVG(execution_duration_ms) as avg_duration_ms,
  MAX(execution_timestamp) as last_execution
FROM `enterprise_knowledge_ai.test_results`
WHERE execution_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY test_suite, test_name, DATE(execution_timestamp)
ORDER BY test_date DESC, test_suite, test_name;

-- Create automated test quality monitoring
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.get_test_health_status`()
RETURNS STRUCT<
  overall_health STRING,
  total_test_suites INT64,
  passing_suites INT64,
  failing_suites INT64,
  last_test_run TIMESTAMP,
  critical_failures ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH 
  recent_results AS (
    SELECT 
      test_suite,
      test_name,
      status,
      execution_timestamp,
      ROW_NUMBER() OVER (PARTITION BY test_suite, test_name ORDER BY execution_timestamp DESC) as rn
    FROM `enterprise_knowledge_ai.test_results`
    WHERE execution_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  ),
  latest_results AS (
    SELECT 
      test_suite,
      test_name,
      status
    FROM recent_results
    WHERE rn = 1
  ),
  suite_health AS (
    SELECT 
      test_suite,
      COUNT(*) as total_tests,
      COUNTIF(status = 'PASSED') as passed_tests,
      COUNTIF(status = 'FAILED') as failed_tests,
      SAFE_DIVIDE(COUNTIF(status = 'PASSED'), COUNT(*)) as suite_success_rate
    FROM latest_results
    GROUP BY test_suite
  ),
  critical_failures AS (
    SELECT 
      ARRAY_AGG(CONCAT(test_suite, ': ', test_name)) as failing_tests
    FROM latest_results
    WHERE status = 'FAILED'
  )
  SELECT AS STRUCT
    CASE 
      WHEN (SELECT COUNT(*) FROM suite_health WHERE suite_success_rate < 0.8) = 0 THEN 'HEALTHY'
      WHEN (SELECT COUNT(*) FROM suite_health WHERE suite_success_rate < 0.5) = 0 THEN 'WARNING'
      ELSE 'CRITICAL'
    END as overall_health,
    (SELECT COUNT(*) FROM suite_health) as total_test_suites,
    (SELECT COUNTIF(suite_success_rate >= 0.8) FROM suite_health) as passing_suites,
    (SELECT COUNTIF(suite_success_rate < 0.8) FROM suite_health) as failing_suites,
    (SELECT MAX(execution_timestamp) FROM `enterprise_knowledge_ai.test_results`) as last_test_run,
    (SELECT failing_tests FROM critical_failures) as critical_failures
);