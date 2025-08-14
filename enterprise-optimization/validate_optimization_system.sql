-- Comprehensive Validation Script for Enterprise Optimization System
-- Validates deployment, functionality, and performance of all optimization components

-- Validation Step 1: Check System Deployment
SELECT 'STEP 1: Validating System Deployment' as validation_step;

-- Check required tables exist
WITH required_tables AS (
  SELECT table_name, 'REQUIRED' as status FROM UNNEST([
    'query_optimization_metadata',
    'query_performance_log', 
    'workload_metrics',
    'scaling_configuration',
    'system_health_metrics',
    'system_events',
    'alert_configuration',
    'performance_tuning_config',
    'performance_baseline',
    'load_test_scenarios',
    'load_test_results'
  ]) as table_name
),
existing_tables AS (
  SELECT table_name
  FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
  WHERE table_schema = 'enterprise_knowledge_ai'
)
SELECT 
  rt.table_name,
  CASE WHEN et.table_name IS NOT NULL THEN '✓ EXISTS' ELSE '✗ MISSING' END as deployment_status
FROM required_tables rt
LEFT JOIN existing_tables et ON rt.table_name = et.table_name
ORDER BY rt.table_name;

-- Check required procedures exist
WITH required_procedures AS (
  SELECT routine_name FROM UNNEST([
    'run_enterprise_optimization_cycle',
    'run_optimization_cycle',
    'run_scaling_cycle', 
    'run_monitoring_cycle',
    'run_performance_optimization_cycle',
    'execute_load_test_scenario',
    'optimize_vector_indexes',
    'monitor_current_workload',
    'execute_scaling_decisions',
    'collect_performance_metrics',
    'evaluate_alerts',
    'establish_performance_baselines',
    'execute_performance_tuning'
  ]) as routine_name
),
existing_procedures AS (
  SELECT routine_name
  FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
  WHERE routine_type = 'PROCEDURE'
    AND routine_schema = 'enterprise_knowledge_ai'
)
SELECT 
  rp.routine_name,
  CASE WHEN ep.routine_name IS NOT NULL THEN '✓ EXISTS' ELSE '✗ MISSING' END as deployment_status
FROM required_procedures rp
LEFT JOIN existing_procedures ep ON rp.routine_name = ep.routine_name
ORDER BY rp.routine_name;

-- Validation Step 2: Test Core Functions
SELECT 'STEP 2: Testing Core Functions' as validation_step;

-- Test query optimization functions
SELECT 
  'Query Optimization Functions' as test_category,
  CASE 
    WHEN optimize_vector_search_query('SELECT * FROM test', 10, 1000) IS NOT NULL 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as vector_search_optimization,
  CASE 
    WHEN optimize_ai_function_batch(['test1', 'test2'], 5) IS NOT NULL 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as ai_function_batching,
  CASE 
    WHEN estimate_query_cost_savings('query1', 'query2').original_cost >= 0 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as cost_estimation;

-- Test scaling functions
SELECT 
  'Resource Scaling Functions' as test_category,
  CASE 
    WHEN calculate_scaling_cost_benefit(100, 200, 'compute').roi_score IS NOT NULL 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as cost_benefit_analysis,
  CASE 
    WHEN optimize_vector_index_parameters('test_table', 1500.0, 1000).recommended_num_lists > 0 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as index_optimization;

-- Test performance functions
SELECT 
  'Performance Tuning Functions' as test_category,
  CASE 
    WHEN optimize_query_structure('SELECT * FROM test', 'vector_search', 1500.0).optimized_query IS NOT NULL 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as query_optimization,
  CASE 
    WHEN detect_performance_regression('test_component', 'test_metric', 100.0).regression_detected IS NOT NULL 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as regression_detection;

-- Validation Step 3: Initialize System Configuration
SELECT 'STEP 3: Initializing System Configuration' as validation_step;

-- Initialize scaling configuration if not exists
INSERT INTO `enterprise_knowledge_ai.scaling_configuration`
(config_id, resource_type, min_capacity, max_capacity, scale_up_threshold, scale_down_threshold, 
 scale_up_increment, scale_down_increment, cooldown_period_minutes)
SELECT * FROM UNNEST([
  STRUCT('default_compute' as config_id, 'compute' as resource_type, 100 as min_capacity, 2000 as max_capacity, 
         80.0 as scale_up_threshold, 30.0 as scale_down_threshold, 200 as scale_up_increment, 
         100 as scale_down_increment, 5 as cooldown_period_minutes),
  STRUCT('default_memory', 'memory', 1000, 10000, 85.0, 40.0, 1000, 500, 10),
  STRUCT('default_ai_quota', 'ai_quota', 1000, 50000, 90.0, 50.0, 5000, 2000, 15)
])
WHERE NOT EXISTS (
  SELECT 1 FROM `enterprise_knowledge_ai.scaling_configuration` 
  WHERE config_id IN ('default_compute', 'default_memory', 'default_ai_quota')
);

-- Initialize alert configuration if not exists
INSERT INTO `enterprise_knowledge_ai.alert_configuration`
(alert_id, alert_name, component_name, metric_name, condition_type, warning_threshold, 
 critical_threshold, evaluation_window_minutes, notification_channels)
SELECT * FROM UNNEST([
  STRUCT('default_latency_alert' as alert_id, 'Query Latency Monitor' as alert_name, 
         'semantic_engine' as component_name, 'avg_query_time_ms' as metric_name, 
         'threshold' as condition_type, 2000.0 as warning_threshold, 5000.0 as critical_threshold, 
         5 as evaluation_window_minutes, ['email'] as notification_channels),
  STRUCT('default_load_alert', 'System Load Monitor', 'infrastructure', 'cpu_utilization_pct', 
         'threshold', 80.0, 95.0, 5, ['email']),
  STRUCT('default_cost_alert', 'Cost Monitor', 'billing', 'hourly_cost_usd', 
         'threshold', 100.0, 500.0, 60, ['email'])
])
WHERE NOT EXISTS (
  SELECT 1 FROM `enterprise_knowledge_ai.alert_configuration` 
  WHERE alert_id IN ('default_latency_alert', 'default_load_alert', 'default_cost_alert')
);

-- Validation Step 4: Test System Health Check
SELECT 'STEP 4: Testing System Health Check' as validation_step;

-- Insert sample health metrics for testing
INSERT INTO `enterprise_knowledge_ai.system_health_metrics`
(metric_id, component_name, metric_type, metric_name, metric_value, threshold_warning, threshold_critical, status)
VALUES 
(GENERATE_UUID(), 'semantic_engine', 'performance', 'avg_query_time_ms', 1500.0, 2000.0, 5000.0, 'healthy'),
(GENERATE_UUID(), 'ai_functions', 'accuracy', 'model_accuracy_score', 0.92, 0.85, 0.75, 'healthy'),
(GENERATE_UUID(), 'infrastructure', 'performance', 'system_load_pct', 65.0, 80.0, 95.0, 'healthy');

-- Test system health function
SELECT 
  'System Health Check' as test_category,
  CASE 
    WHEN check_optimization_system_health().system_status IS NOT NULL 
    THEN '✓ WORKING' 
    ELSE '✗ FAILED' 
  END as health_check_function;

-- Validation Step 5: Run Comprehensive Test Suite
SELECT 'STEP 5: Running Comprehensive Test Suite' as validation_step;

-- Execute the full test suite
CALL run_optimization_system_tests();

-- Validation Step 6: Performance Baseline Establishment
SELECT 'STEP 6: Establishing Performance Baselines' as validation_step;

-- Insert sample performance data for baseline calculation
INSERT INTO `enterprise_knowledge_ai.query_performance_log`
(execution_id, query_hash, query_type, execution_time_ms, bytes_processed, slots_used, cost_estimate, optimization_applied, timestamp)
SELECT 
  GENERATE_UUID(),
  'baseline_query_' || CAST(ROW_NUMBER() OVER() AS STRING),
  'vector_search',
  CAST(800 + RAND() * 400 AS INT64), -- 800-1200ms range
  CAST(1000000 + RAND() * 2000000 AS INT64),
  CAST(10 + RAND() * 20 AS INT64),
  RAND() * 5,
  FALSE,
  TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL CAST(RAND() * 10080 AS INT64) MINUTE) -- Last 7 days
FROM UNNEST(GENERATE_ARRAY(1, 100));

-- Establish baselines
CALL establish_performance_baselines();

-- Verify baselines were created
SELECT 
  'Performance Baselines' as validation_category,
  COUNT(*) as baselines_created,
  CASE WHEN COUNT(*) > 0 THEN '✓ SUCCESS' ELSE '✗ FAILED' END as baseline_status
FROM `enterprise_knowledge_ai.performance_baseline`
WHERE DATE(created_timestamp) = CURRENT_DATE();

-- Validation Step 7: Load Testing Validation
SELECT 'STEP 7: Validating Load Testing Framework' as validation_step;

-- Check load test scenarios are configured
SELECT 
  'Load Testing Configuration' as validation_category,
  COUNT(*) as scenarios_configured,
  CASE WHEN COUNT(*) >= 5 THEN '✓ SUFFICIENT' ELSE '✗ INSUFFICIENT' END as scenario_status
FROM `enterprise_knowledge_ai.load_test_scenarios`
WHERE is_active = TRUE;

-- Validation Step 8: Integration Test
SELECT 'STEP 8: Running Integration Test' as validation_step;

-- Test full optimization cycle integration
CALL test_full_optimization_integration();

-- Validation Step 9: Final System Status
SELECT 'STEP 9: Final System Status Report' as validation_step;

-- Generate comprehensive system status
WITH deployment_status AS (
  SELECT 
    COUNT(*) as total_tables,
    COUNT(CASE WHEN table_name IN (
      'query_optimization_metadata', 'workload_metrics', 'system_health_metrics',
      'performance_baseline', 'load_test_scenarios'
    ) THEN 1 END) as critical_tables
  FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
  WHERE table_schema = 'enterprise_knowledge_ai'
),
configuration_status AS (
  SELECT 
    (SELECT COUNT(*) FROM `enterprise_knowledge_ai.scaling_configuration` WHERE is_active = TRUE) as scaling_configs,
    (SELECT COUNT(*) FROM `enterprise_knowledge_ai.alert_configuration` WHERE is_active = TRUE) as alert_configs,
    (SELECT COUNT(*) FROM `enterprise_knowledge_ai.load_test_scenarios` WHERE is_active = TRUE) as test_scenarios
),
test_results AS (
  SELECT 
    COUNT(*) as total_tests,
    COUNT(CASE WHEN test_status = 'PASSED' THEN 1 END) as passed_tests
  FROM `enterprise_knowledge_ai.test_results`
  WHERE DATE(timestamp) = CURRENT_DATE()
)
SELECT 
  'ENTERPRISE OPTIMIZATION SYSTEM VALIDATION COMPLETE' as validation_summary,
  CURRENT_TIMESTAMP() as validation_timestamp,
  ds.total_tables as tables_deployed,
  ds.critical_tables as critical_tables_deployed,
  cs.scaling_configs as scaling_configurations,
  cs.alert_configs as alert_configurations, 
  cs.test_scenarios as load_test_scenarios,
  tr.total_tests as tests_executed,
  tr.passed_tests as tests_passed,
  CASE 
    WHEN ds.critical_tables >= 5 AND cs.scaling_configs >= 3 AND cs.alert_configs >= 3 
         AND tr.passed_tests = tr.total_tests AND tr.total_tests > 0
    THEN '✅ SYSTEM FULLY OPERATIONAL'
    WHEN ds.critical_tables >= 5 AND cs.scaling_configs >= 1 AND cs.alert_configs >= 1
    THEN '⚠️ SYSTEM PARTIALLY OPERATIONAL'
    ELSE '❌ SYSTEM DEPLOYMENT ISSUES'
  END as overall_status,
  CASE 
    WHEN ds.critical_tables >= 5 AND cs.scaling_configs >= 3 AND cs.alert_configs >= 3 
         AND tr.passed_tests = tr.total_tests AND tr.total_tests > 0
    THEN 'System is ready for production use. All components deployed and tested successfully.'
    ELSE 'Review deployment issues and re-run validation. Check logs for specific errors.'
  END as recommendations
FROM deployment_status ds
CROSS JOIN configuration_status cs  
CROSS JOIN test_results tr;

-- Display final optimization system health
SELECT check_optimization_system_health() as final_system_health;