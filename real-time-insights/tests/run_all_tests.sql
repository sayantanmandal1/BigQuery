-- Comprehensive Test Runner for Real-time Insight Generation System
-- Executes all performance and accuracy tests with detailed reporting

-- Create test execution log table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_execution_log` (
  execution_id STRING NOT NULL,
  test_suite STRING NOT NULL,
  execution_status ENUM('running', 'completed', 'failed'),
  start_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  end_timestamp TIMESTAMP,
  total_tests INT64,
  passed_tests INT64,
  failed_tests INT64,
  warning_tests INT64,
  execution_summary JSON,
  metadata JSON
) PARTITION BY DATE(start_timestamp)
CLUSTER BY test_suite, execution_status;

-- Master test execution procedure
CREATE OR REPLACE PROCEDURE run_comprehensive_realtime_tests()
BEGIN
  DECLARE execution_id STRING DEFAULT GENERATE_UUID();
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_suite_name STRING DEFAULT 'Real-time Insight Generation System';
  DECLARE total_tests INT64 DEFAULT 0;
  DECLARE passed_tests INT64 DEFAULT 0;
  DECLARE failed_tests INT64 DEFAULT 0;
  DECLARE warning_tests INT64 DEFAULT 0;
  DECLARE execution_summary JSON;
  
  -- Log test execution start
  INSERT INTO `enterprise_knowledge_ai.test_execution_log` (
    execution_id,
    test_suite,
    execution_status,
    metadata
  )
  VALUES (
    execution_id,
    test_suite_name,
    'running',
    JSON_OBJECT(
      'test_categories', ['performance', 'accuracy', 'integration'],
      'execution_trigger', 'manual',
      'environment', 'test'
    )
  );

  -- Clear previous test results for clean run
  DELETE FROM `enterprise_knowledge_ai.test_results`
  WHERE test_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);

  BEGIN
    -- Execute Performance Tests
    SELECT 'Running Performance Tests...' as status;
    CALL run_realtime_performance_tests();
    
    -- Execute Accuracy Tests  
    SELECT 'Running Accuracy Tests...' as status;
    CALL run_alert_accuracy_tests();
    
    -- Execute Integration Tests
    SELECT 'Running Integration Tests...' as status;
    CALL test_end_to_end_integration();
    
    -- Calculate test summary
    SELECT 
      COUNT(*) as total,
      COUNTIF(test_status = 'passed') as passed,
      COUNTIF(test_status = 'failed') as failed,
      COUNTIF(test_status = 'warning') as warnings
    INTO total_tests, passed_tests, failed_tests, warning_tests
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_timestamp >= test_start_time;
    
    -- Create detailed execution summary
    WITH test_details AS (
      SELECT 
        test_category,
        COUNT(*) as category_total,
        COUNTIF(test_status = 'passed') as category_passed,
        COUNTIF(test_status = 'failed') as category_failed,
        COUNTIF(test_status = 'warning') as category_warnings,
        AVG(execution_time_ms) as avg_execution_time,
        ARRAY_AGG(
          STRUCT(
            test_name,
            test_status,
            execution_time_ms,
            JSON_EXTRACT_SCALAR(result_details, '$.summary') as summary
          )
          ORDER BY test_status DESC, execution_time_ms DESC
        ) as test_results
      FROM `enterprise_knowledge_ai.test_results`
      WHERE test_timestamp >= test_start_time
      GROUP BY test_category
    )
    
    SELECT TO_JSON(STRUCT(
      total_tests,
      passed_tests,
      failed_tests,
      warning_tests,
      ROUND(passed_tests / total_tests * 100, 2) as success_rate_percent,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) as total_execution_time_ms,
      (SELECT ARRAY_AGG(
        STRUCT(
          test_category,
          category_total,
          category_passed,
          category_failed,
          category_warnings,
          ROUND(category_passed / category_total * 100, 2) as category_success_rate,
          avg_execution_time,
          test_results
        )
      ) FROM test_details) as category_breakdown
    ))
    INTO execution_summary;
    
    -- Update test execution log with completion
    UPDATE `enterprise_knowledge_ai.test_execution_log`
    SET 
      execution_status = 'completed',
      end_timestamp = CURRENT_TIMESTAMP(),
      total_tests = total_tests,
      passed_tests = passed_tests,
      failed_tests = failed_tests,
      warning_tests = warning_tests,
      execution_summary = execution_summary
    WHERE execution_id = execution_id;
    
    -- Generate test report
    SELECT 
      '=== REAL-TIME INSIGHT GENERATION SYSTEM TEST REPORT ===' as report_header,
      execution_id as test_execution_id,
      test_start_time as execution_start,
      CURRENT_TIMESTAMP() as execution_end,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, SECOND) as duration_seconds,
      total_tests,
      passed_tests,
      failed_tests,
      warning_tests,
      ROUND(passed_tests / total_tests * 100, 2) as success_rate_percent,
      CASE 
        WHEN failed_tests = 0 AND warning_tests = 0 THEN 'ALL TESTS PASSED ✓'
        WHEN failed_tests = 0 THEN 'PASSED WITH WARNINGS ⚠'
        ELSE 'SOME TESTS FAILED ✗'
      END as overall_status,
      execution_summary as detailed_results;

  EXCEPTION WHEN ERROR THEN
    -- Handle test execution failure
    UPDATE `enterprise_knowledge_ai.test_execution_log`
    SET 
      execution_status = 'failed',
      end_timestamp = CURRENT_TIMESTAMP(),
      execution_summary = JSON_OBJECT(
        'error_message', @@error.message,
        'failure_timestamp', CURRENT_TIMESTAMP(),
        'partial_results', JSON_OBJECT(
          'tests_completed_before_failure', (
            SELECT COUNT(*) FROM `enterprise_knowledge_ai.test_results`
            WHERE test_timestamp >= test_start_time
          )
        )
      )
    WHERE execution_id = execution_id;
    
    -- Log the error
    INSERT INTO `enterprise_knowledge_ai.system_logs` (
      log_id,
      component,
      message,
      log_level,
      timestamp,
      metadata
    )
    VALUES (
      GENERATE_UUID(),
      'test_runner',
      CONCAT('Test execution failed: ', @@error.message),
      'error',
      CURRENT_TIMESTAMP(),
      JSON_OBJECT('execution_id', execution_id, 'error_details', @@error.message)
    );
    
    RAISE USING MESSAGE = CONCAT('Test execution failed: ', @@error.message);
  END;
  
END;

-- Integration test procedure
CREATE OR REPLACE PROCEDURE test_end_to_end_integration()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_data_id STRING;
  DECLARE insight_generated BOOL DEFAULT FALSE;
  DECLARE alert_triggered BOOL DEFAULT FALSE;
  DECLARE recommendation_created BOOL DEFAULT FALSE;
  DECLARE integration_success BOOL DEFAULT FALSE;
  DECLARE test_details JSON;
  
  -- Test end-to-end data flow
  BEGIN
    -- Step 1: Ingest test data
    SET test_data_id = ingest_realtime_data(
      'integration_test_system',
      JSON_OBJECT(
        'content', 'CRITICAL: Integration test scenario - System performance degraded significantly, customer complaints increasing',
        'timestamp', CURRENT_TIMESTAMP(),
        'type', 'alert',
        'severity', 'high',
        'source_system', 'monitoring'
      ),
      10
    );
    
    -- Step 2: Process through pipeline
    CALL process_data_pipeline();
    
    -- Step 3: Generate insights
    CALL process_pending_streams();
    
    -- Step 4: Process alerts
    CALL process_alert_triggers();
    
    -- Step 5: Generate recommendations
    -- First create user context
    INSERT INTO `enterprise_knowledge_ai.user_context` (
      context_id,
      user_id,
      session_id,
      current_activity,
      active_projects,
      recent_queries,
      context_timestamp,
      expiration_timestamp
    )
    VALUES (
      GENERATE_UUID(),
      'integration_test_user',
      'integration_test_session',
      JSON_OBJECT('discussion_context', 'System performance review meeting'),
      ['system_monitoring', 'performance_optimization'],
      ['system performance', 'alert analysis'],
      CURRENT_TIMESTAMP(),
      TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    );
    
    CALL generate_active_user_recommendations();
    
    -- Verify results
    SET insight_generated = (
      SELECT COUNT(*) > 0
      FROM `enterprise_knowledge_ai.realtime_insights`
      WHERE created_timestamp >= test_start_time
        AND content LIKE '%integration test%'
    );
    
    SET alert_triggered = (
      SELECT COUNT(*) > 0
      FROM `enterprise_knowledge_ai.alert_history`
      WHERE triggered_timestamp >= test_start_time
        AND JSON_EXTRACT_SCALAR(trigger_data, '$.original_content') LIKE '%integration test%'
    );
    
    SET recommendation_created = (
      SELECT COUNT(*) > 0
      FROM `enterprise_knowledge_ai.contextual_recommendations`
      WHERE created_timestamp >= test_start_time
        AND user_id = 'integration_test_user'
    );
    
    SET integration_success = insight_generated AND alert_triggered AND recommendation_created;
    
    -- Prepare test details
    SET test_details = JSON_OBJECT(
      'test_data_id', test_data_id,
      'insight_generated', insight_generated,
      'alert_triggered', alert_triggered,
      'recommendation_created', recommendation_created,
      'integration_success', integration_success,
      'processing_steps_completed', 5,
      'end_to_end_flow_verified', integration_success
    );
    
    -- Record integration test result
    INSERT INTO `enterprise_knowledge_ai.test_results` (
      test_id,
      test_name,
      test_category,
      test_status,
      execution_time_ms,
      result_details,
      metadata
    )
    VALUES (
      GENERATE_UUID(),
      'End-to-End Integration Test',
      'integration',
      CASE WHEN integration_success THEN 'passed' ELSE 'failed' END,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
      test_details,
      JSON_OBJECT(
        'test_type', 'end_to_end_integration',
        'data_flow_validation', TRUE,
        'component_integration', TRUE
      )
    );
    
    -- Clean up test data
    DELETE FROM `enterprise_knowledge_ai.user_context`
    WHERE user_id = 'integration_test_user';
    
    DELETE FROM `enterprise_knowledge_ai.data_ingestion_staging`
    WHERE staging_id = test_data_id;
    
  EXCEPTION WHEN ERROR THEN
    -- Record integration test failure
    INSERT INTO `enterprise_knowledge_ai.test_results` (
      test_id,
      test_name,
      test_category,
      test_status,
      execution_time_ms,
      result_details,
      metadata
    )
    VALUES (
      GENERATE_UUID(),
      'End-to-End Integration Test',
      'integration',
      'failed',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
      JSON_OBJECT(
        'error_message', @@error.message,
        'failure_point', 'integration_test_execution',
        'partial_success', JSON_OBJECT(
          'insight_generated', insight_generated,
          'alert_triggered', alert_triggered,
          'recommendation_created', recommendation_created
        )
      ),
      JSON_OBJECT(
        'test_type', 'end_to_end_integration',
        'execution_failed', TRUE
      )
    );
  END;
  
END;

-- Function to get latest test results summary
CREATE OR REPLACE FUNCTION get_latest_test_summary()
RETURNS JSON
LANGUAGE SQL
AS (
  WITH latest_execution AS (
    SELECT *
    FROM `enterprise_knowledge_ai.test_execution_log`
    ORDER BY start_timestamp DESC
    LIMIT 1
  ),
  
  test_breakdown AS (
    SELECT 
      test_category,
      COUNT(*) as total,
      COUNTIF(test_status = 'passed') as passed,
      COUNTIF(test_status = 'failed') as failed,
      COUNTIF(test_status = 'warning') as warnings,
      AVG(execution_time_ms) as avg_time_ms
    FROM `enterprise_knowledge_ai.test_results` tr
    WHERE tr.test_timestamp >= (SELECT start_timestamp FROM latest_execution)
    GROUP BY test_category
  )
  
  SELECT TO_JSON(STRUCT(
    le.execution_id,
    le.test_suite,
    le.execution_status,
    le.start_timestamp,
    le.end_timestamp,
    le.total_tests,
    le.passed_tests,
    le.failed_tests,
    le.warning_tests,
    ROUND(le.passed_tests / le.total_tests * 100, 2) as success_rate,
    (SELECT ARRAY_AGG(STRUCT(
      test_category,
      total,
      passed,
      failed,
      warnings,
      ROUND(passed / total * 100, 2) as category_success_rate,
      avg_time_ms
    )) FROM test_breakdown) as category_breakdown,
    le.execution_summary
  ))
  FROM latest_execution le
);

-- Quick test status check function
CREATE OR REPLACE FUNCTION quick_test_status_check()
RETURNS STRING
LANGUAGE SQL
AS (
  WITH latest_results AS (
    SELECT 
      COUNT(*) as total_tests,
      COUNTIF(test_status = 'passed') as passed_tests,
      COUNTIF(test_status = 'failed') as failed_tests,
      MAX(test_timestamp) as last_test_time
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  )
  
  SELECT 
    CASE 
      WHEN total_tests = 0 THEN 'NO_RECENT_TESTS'
      WHEN failed_tests = 0 THEN 'ALL_TESTS_PASSING'
      WHEN failed_tests > 0 AND passed_tests > failed_tests THEN 'MOSTLY_PASSING'
      ELSE 'MULTIPLE_FAILURES'
    END
  FROM latest_results
);

-- Display usage instructions
SELECT '''
=== Real-time Insight Generation System Test Suite ===

Usage:
1. Run all tests: CALL run_comprehensive_realtime_tests();
2. Get latest results: SELECT get_latest_test_summary();
3. Quick status check: SELECT quick_test_status_check();
4. View detailed results: SELECT * FROM test_results ORDER BY test_timestamp DESC;
5. View execution history: SELECT * FROM test_execution_log ORDER BY start_timestamp DESC;

Individual Test Suites:
- Performance tests: CALL run_realtime_performance_tests();
- Accuracy tests: CALL run_alert_accuracy_tests();
- Integration tests: CALL test_end_to_end_integration();

Test Categories:
- performance: Latency, throughput, response time tests
- accuracy: Alert significance, recommendation quality tests  
- integration: End-to-end data flow validation tests

Monitoring:
- System health: SELECT get_realtime_system_health();
- Pipeline health: SELECT get_pipeline_health_metrics();
- Test trends: Analyze test_results table over time
''' as usage_instructions;