-- =====================================================
-- INTEGRATION TESTING VALIDATION SCRIPT
-- Quick validation of the integration testing framework
-- =====================================================

-- Validate that all required procedures exist
SELECT 
  'Integration Test Procedures' as validation_category,
  routine_name,
  routine_type,
  'EXISTS' as status
FROM `enterprise_ai.INFORMATION_SCHEMA.ROUTINES`
WHERE routine_name IN (
  'test_document_processing_pipeline',
  'test_multi_engine_integration', 
  'test_performance_regression',
  'run_all_integration_tests',
  'check_integration_alerts',
  'cleanup_integration_test_data',
  'get_integration_health_status',
  'verify_test_prerequisites'
)
ORDER BY routine_name;

-- Validate that all required tables exist
SELECT 
  'Integration Test Tables' as validation_category,
  table_name,
  table_type,
  'EXISTS' as status
FROM `enterprise_ai.INFORMATION_SCHEMA.TABLES`
WHERE table_name IN (
  'integration_test_results',
  'integration_test_data',
  'integration_test_sessions',
  'performance_baselines',
  'integration_alerts'
)
ORDER BY table_name;

-- Validate that all required views exist
SELECT 
  'Integration Test Views' as validation_category,
  table_name as view_name,
  'VIEW' as table_type,
  'EXISTS' as status
FROM `enterprise_ai.INFORMATION_SCHEMA.VIEWS`
WHERE table_name IN (
  'integration_test_report',
  'performance_monitoring_dashboard'
)
ORDER BY table_name;

-- Check performance baselines are initialized
SELECT 
  'Performance Baselines' as validation_category,
  test_name,
  metric_name,
  baseline_value,
  threshold_percentage,
  'INITIALIZED' as status
FROM `enterprise_ai.performance_baselines`
ORDER BY test_name, metric_name;

-- Validate prerequisites for running tests
SELECT 
  'Prerequisites Check' as validation_category,
  CASE 
    WHEN `enterprise_ai.verify_test_prerequisites`() THEN 'READY'
    ELSE 'NOT_READY'
  END as status,
  'All required models and tables available' as description;

-- Test the health status function
SELECT 
  'Health Status Function' as validation_category,
  'FUNCTIONAL' as status,
  JSON_EXTRACT_SCALAR(`enterprise_ai.get_integration_health_status`(), '$.overall_health_status') as current_health_status;

-- Summary validation report
WITH validation_summary AS (
  SELECT 
    COUNT(*) as total_procedures
  FROM `enterprise_ai.INFORMATION_SCHEMA.ROUTINES`
  WHERE routine_name LIKE '%test%' OR routine_name LIKE '%integration%'
),
table_summary AS (
  SELECT 
    COUNT(*) as total_tables
  FROM `enterprise_ai.INFORMATION_SCHEMA.TABLES`
  WHERE table_name LIKE '%integration%' OR table_name LIKE '%performance%' OR table_name LIKE '%alert%'
),
baseline_summary AS (
  SELECT 
    COUNT(*) as total_baselines
  FROM `enterprise_ai.performance_baselines`
)
SELECT 
  'Integration Testing Framework Validation Summary' as summary,
  vs.total_procedures,
  ts.total_tables,
  bs.total_baselines,
  CASE 
    WHEN vs.total_procedures >= 8 AND ts.total_tables >= 5 AND bs.total_baselines >= 8 THEN 'VALIDATION_PASSED'
    ELSE 'VALIDATION_FAILED'
  END as overall_validation_status
FROM validation_summary vs
CROSS JOIN table_summary ts  
CROSS JOIN baseline_summary bs;