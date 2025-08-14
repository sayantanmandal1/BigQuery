-- Quick Execution Script for Unified Test Suite
-- This script demonstrates how to run all test suites with the new unified master test runner

-- Option 1: Run all test suites with default settings
-- This executes semantic, predictive, multimodal, real-time, and personalized intelligence tests
CALL `enterprise_knowledge_ai.run_unified_test_suite`();

-- Option 2: Run comprehensive test suite with full reporting
-- CALL `enterprise_knowledge_ai.execute_comprehensive_test_suite`('production', TRUE, TRUE);

-- Option 3: Run with custom configuration
-- CALL `enterprise_knowledge_ai.run_unified_test_suite`(
--   TRUE,   -- include_performance_tests
--   TRUE,   -- include_integration_tests  
--   TRUE,   -- include_load_tests
--   'staging', -- test_environment
--   TRUE    -- parallel_execution
-- );

-- View the results
SELECT * FROM `enterprise_knowledge_ai.unified_test_monitor`;

-- Check latest execution summary
SELECT 
  execution_id,
  total_suites,
  total_tests,
  passed_tests,
  failed_tests,
  ROUND(overall_success_rate * 100, 2) as success_rate_percent,
  ROUND(total_execution_time_ms / 1000.0, 2) as execution_time_seconds,
  execution_timestamp
FROM `enterprise_knowledge_ai.test_execution_summary`
ORDER BY execution_timestamp DESC
LIMIT 1;

-- View suite breakdown
SELECT 
  test_suite,
  test_category,
  COUNT(*) as total_tests,
  COUNTIF(test_status = 'PASSED') as passed,
  COUNTIF(test_status = 'FAILED') as failed,
  COUNTIF(test_status = 'WARNING') as warnings,
  ROUND(SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) * 100, 2) as success_rate_percent,
  ROUND(AVG(execution_time_ms), 0) as avg_execution_time_ms
FROM `enterprise_knowledge_ai.master_test_results`
WHERE DATE(execution_timestamp) = CURRENT_DATE()
GROUP BY test_suite, test_category
ORDER BY success_rate_percent DESC;