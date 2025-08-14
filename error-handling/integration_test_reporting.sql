-- =====================================================
-- INTEGRATION TEST REPORTING AND MONITORING
-- =====================================================

-- Master procedure to run all integration tests
CREATE OR REPLACE PROCEDURE `enterprise_ai.run_all_integration_tests`()
BEGIN
  DECLARE test_session_id STRING DEFAULT GENERATE_UUID();
  DECLARE session_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  
  -- Create test session tracking
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
  
  INSERT INTO `enterprise_ai.integration_test_sessions` 
  (session_id, overall_status, total_tests, passed_tests, failed_tests, error_tests)
  VALUES (test_session_id, 'running', 0, 0, 0, 0);
  
  -- Run all integration tests
  CALL `enterprise_ai.test_document_processing_pipeline`();
  CALL `enterprise_ai.test_multi_engine_integration`();
  CALL `enterprise_ai.test_performance_regression`();
  
  -- Calculate session results
  DECLARE total_tests, passed_tests, failed_tests, error_tests INT64;
  
  SELECT 
    COUNT(*) as total,
    COUNTIF(status = 'passed') as passed,
    COUNTIF(status = 'failed') as failed,
    COUNTIF(status = 'error') as errors
  INTO total_tests, passed_tests, failed_tests, error_tests
  FROM `enterprise_ai.integration_test_results`
  WHERE DATE(start_timestamp) = CURRENT_DATE();
  
  -- Update session results
  UPDATE `enterprise_ai.integration_test_sessions`
  SET 
    end_timestamp = CURRENT_TIMESTAMP(),
    total_tests = total_tests,
    passed_tests = passed_tests,
    failed_tests = failed_tests,
    error_tests = error_tests,
    overall_status = CASE 
      WHEN error_tests > 0 THEN 'error'
      WHEN failed_tests > 0 THEN 'failed'
      ELSE 'passed'
    END,
    session_summary = TO_JSON(STRUCT(
      test_session_id,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), session_start, MILLISECOND) as total_execution_time_ms,
      ROUND(passed_tests * 100.0 / total_tests, 2) as success_rate_percentage,
      'Complete end-to-end integration test suite execution' as description
    ))
  WHERE session_id = test_session_id;
  
END;

-- Create comprehensive test report view
CREATE OR REPLACE VIEW `enterprise_ai.integration_test_report` AS
WITH test_summary AS (
  SELECT 
    test_category,
    COUNT(*) as total_tests,
    COUNTIF(status = 'passed') as passed_tests,
    COUNTIF(status = 'failed') as failed_tests,
    COUNTIF(status = 'error') as error_tests,
    AVG(execution_time_ms) as avg_execution_time_ms,
    MAX(execution_time_ms) as max_execution_time_ms,
    MIN(execution_time_ms) as min_execution_time_ms
  FROM `enterprise_ai.integration_test_results`
  WHERE DATE(start_timestamp) = CURRENT_DATE()
  GROUP BY test_category
),
performance_trends AS (
  SELECT 
    test_name,
    AVG(execution_time_ms) as avg_execution_time,
    STDDEV(execution_time_ms) as execution_time_stddev,
    COUNT(*) as execution_count
  FROM `enterprise_ai.integration_test_results`
  WHERE DATE(start_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  GROUP BY test_name
),
data_flow_metrics AS (
  SELECT 
    processing_stage,
    AVG(stage_duration_ms) as avg_stage_duration,
    AVG(quality_score) as avg_quality_score,
    COUNTIF(stage_status = 'success') as successful_stages,
    COUNT(*) as total_stages
  FROM `enterprise_ai.integration_test_data`
  WHERE DATE(stage_timestamp) = CURRENT_DATE()
  GROUP BY processing_stage
)
SELECT 
  CURRENT_TIMESTAMP() as report_timestamp,
  ts.test_category,
  ts.total_tests,
  ts.passed_tests,
  ts.failed_tests,
  ts.error_tests,
  ROUND(ts.passed_tests * 100.0 / ts.total_tests, 2) as success_rate_percentage,
  ts.avg_execution_time_ms,
  pt.execution_time_stddev,
  dfm.avg_stage_duration,
  dfm.avg_quality_score,
  dfm.successful_stages,
  dfm.total_stages
FROM test_summary ts
LEFT JOIN performance_trends pt ON ts.test_category = pt.test_name
LEFT JOIN data_flow_metrics dfm ON TRUE;

-- Create performance monitoring view
CREATE OR REPLACE VIEW `enterprise_ai.performance_monitoring_dashboard` AS
WITH current_performance AS (
  SELECT 
    test_name,
    JSON_EXTRACT_SCALAR(performance_metrics, '$.avg_query_time') as avg_query_time,
    JSON_EXTRACT_SCALAR(performance_metrics, '$.queries_per_second') as queries_per_second,
    JSON_EXTRACT_SCALAR(performance_metrics, '$.avg_generation_time') as avg_generation_time,
    JSON_EXTRACT_SCALAR(performance_metrics, '$.pipeline_time_ms') as pipeline_time_ms,
    execution_time_ms,
    start_timestamp
  FROM `enterprise_ai.integration_test_results`
  WHERE test_category = 'performance_regression'
    AND DATE(start_timestamp) = CURRENT_DATE()
    AND performance_metrics IS NOT NULL
),
baseline_comparison AS (
  SELECT 
    'avg_query_time_ms' as metric_name,
    CAST(cp.avg_query_time AS FLOAT64) as current_value,
    pb.baseline_value,
    pb.threshold_percentage,
    ROUND(
      (CAST(cp.avg_query_time AS FLOAT64) - pb.baseline_value) * 100.0 / pb.baseline_value, 
      2
    ) as performance_change_percentage,
    CASE 
      WHEN CAST(cp.avg_query_time AS FLOAT64) > pb.baseline_value * (1 + pb.threshold_percentage / 100.0) THEN 'DEGRADED'
      WHEN CAST(cp.avg_query_time AS FLOAT64) < pb.baseline_value * (1 - pb.threshold_percentage / 100.0) THEN 'IMPROVED'
      ELSE 'STABLE'
    END as performance_status
  FROM current_performance cp
  JOIN `enterprise_ai.performance_baselines` pb 
    ON pb.test_name = 'enterprise_scale_vector_search' AND pb.metric_name = 'avg_query_time_ms'
  
  UNION ALL
  
  SELECT 
    'queries_per_second' as metric_name,
    CAST(cp.queries_per_second AS FLOAT64) as current_value,
    pb.baseline_value,
    pb.threshold_percentage,
    ROUND(
      (CAST(cp.queries_per_second AS FLOAT64) - pb.baseline_value) * 100.0 / pb.baseline_value, 
      2
    ) as performance_change_percentage,
    CASE 
      WHEN CAST(cp.queries_per_second AS FLOAT64) < pb.baseline_value * (1 - pb.threshold_percentage / 100.0) THEN 'DEGRADED'
      WHEN CAST(cp.queries_per_second AS FLOAT64) > pb.baseline_value * (1 + pb.threshold_percentage / 100.0) THEN 'IMPROVED'
      ELSE 'STABLE'
    END as performance_status
  FROM current_performance cp
  JOIN `enterprise_ai.performance_baselines` pb 
    ON pb.test_name = 'enterprise_scale_vector_search' AND pb.metric_name = 'throughput_queries_per_second'
)
SELECT 
  metric_name,
  current_value,
  baseline_value,
  performance_change_percentage,
  performance_status,
  threshold_percentage,
  CASE 
    WHEN performance_status = 'DEGRADED' THEN 'HIGH'
    WHEN performance_status = 'IMPROVED' THEN 'LOW'
    ELSE 'MEDIUM'
  END as alert_priority
FROM baseline_comparison
ORDER BY 
  CASE performance_status 
    WHEN 'DEGRADED' THEN 1 
    WHEN 'STABLE' THEN 2 
    WHEN 'IMPROVED' THEN 3 
  END,
  ABS(performance_change_percentage) DESC;

-- Create integration health check function
CREATE OR REPLACE FUNCTION `enterprise_ai.get_integration_health_status`()
RETURNS JSON
LANGUAGE SQL
AS (
  WITH health_metrics AS (
    SELECT 
      COUNT(*) as total_tests_today,
      COUNTIF(status = 'passed') as passed_tests_today,
      COUNTIF(status = 'failed') as failed_tests_today,
      COUNTIF(status = 'error') as error_tests_today,
      AVG(execution_time_ms) as avg_execution_time,
      MAX(end_timestamp) as last_test_time
    FROM `enterprise_ai.integration_test_results`
    WHERE DATE(start_timestamp) = CURRENT_DATE()
  ),
  performance_health AS (
    SELECT 
      COUNTIF(performance_status = 'DEGRADED') as degraded_metrics,
      COUNTIF(performance_status = 'STABLE') as stable_metrics,
      COUNTIF(performance_status = 'IMPROVED') as improved_metrics
    FROM `enterprise_ai.performance_monitoring_dashboard`
  ),
  data_flow_health AS (
    SELECT 
      AVG(quality_score) as avg_data_quality,
      COUNTIF(stage_status = 'success') as successful_data_flows,
      COUNT(*) as total_data_flows
    FROM `enterprise_ai.integration_test_data`
    WHERE DATE(stage_timestamp) = CURRENT_DATE()
  )
  SELECT TO_JSON(STRUCT(
    CURRENT_TIMESTAMP() as health_check_timestamp,
    CASE 
      WHEN hm.error_tests_today > 0 OR ph.degraded_metrics > 2 THEN 'CRITICAL'
      WHEN hm.failed_tests_today > 0 OR ph.degraded_metrics > 0 THEN 'WARNING'
      WHEN hm.passed_tests_today > 0 AND dfh.avg_data_quality > 0.8 THEN 'HEALTHY'
      ELSE 'UNKNOWN'
    END as overall_health_status,
    hm.total_tests_today,
    hm.passed_tests_today,
    hm.failed_tests_today,
    hm.error_tests_today,
    ROUND(hm.passed_tests_today * 100.0 / NULLIF(hm.total_tests_today, 0), 2) as success_rate_percentage,
    hm.avg_execution_time,
    hm.last_test_time,
    ph.degraded_metrics,
    ph.stable_metrics,
    ph.improved_metrics,
    ROUND(dfh.avg_data_quality, 3) as avg_data_quality,
    dfh.successful_data_flows,
    dfh.total_data_flows
  ))
  FROM health_metrics hm
  CROSS JOIN performance_health ph
  CROSS JOIN data_flow_health dfh
);

-- Create automated alerting procedure
CREATE OR REPLACE PROCEDURE `enterprise_ai.check_integration_alerts`()
BEGIN
  DECLARE health_status JSON;
  DECLARE overall_status STRING;
  
  SET health_status = `enterprise_ai.get_integration_health_status`();
  SET overall_status = JSON_EXTRACT_SCALAR(health_status, '$.overall_health_status');
  
  -- Create alerts table if not exists
  CREATE TABLE IF NOT EXISTS `enterprise_ai.integration_alerts` (
    alert_id STRING NOT NULL,
    alert_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    alert_level ENUM('INFO', 'WARNING', 'CRITICAL'),
    alert_type ENUM('PERFORMANCE', 'FAILURE', 'HEALTH'),
    alert_message STRING,
    alert_details JSON,
    resolved BOOL DEFAULT FALSE
  ) PARTITION BY DATE(alert_timestamp)
  CLUSTER BY alert_level, alert_type;
  
  -- Generate alerts based on health status
  IF overall_status = 'CRITICAL' THEN
    INSERT INTO `enterprise_ai.integration_alerts`
    (alert_id, alert_level, alert_type, alert_message, alert_details)
    VALUES (
      GENERATE_UUID(),
      'CRITICAL',
      'HEALTH',
      'Integration system health is CRITICAL - immediate attention required',
      health_status
    );
  ELSEIF overall_status = 'WARNING' THEN
    INSERT INTO `enterprise_ai.integration_alerts`
    (alert_id, alert_level, alert_type, alert_message, alert_details)
    VALUES (
      GENERATE_UUID(),
      'WARNING',
      'HEALTH',
      'Integration system health shows WARNING status - investigation recommended',
      health_status
    );
  END IF;
  
  -- Check for performance degradation alerts
  INSERT INTO `enterprise_ai.integration_alerts`
  (alert_id, alert_level, alert_type, alert_message, alert_details)
  SELECT 
    GENERATE_UUID(),
    'WARNING',
    'PERFORMANCE',
    CONCAT('Performance degradation detected in metric: ', metric_name),
    TO_JSON(STRUCT(
      metric_name,
      current_value,
      baseline_value,
      performance_change_percentage,
      performance_status
    ))
  FROM `enterprise_ai.performance_monitoring_dashboard`
  WHERE performance_status = 'DEGRADED'
    AND alert_priority = 'HIGH';
    
END;

-- Create integration test cleanup procedure
CREATE OR REPLACE PROCEDURE `enterprise_ai.cleanup_integration_test_data`(
  retention_days INT64 DEFAULT 30
)
BEGIN
  DECLARE cleanup_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL retention_days DAY);
  
  -- Clean up old test results
  DELETE FROM `enterprise_ai.integration_test_results`
  WHERE DATE(start_timestamp) < cleanup_date;
  
  -- Clean up old test data
  DELETE FROM `enterprise_ai.integration_test_data`
  WHERE DATE(stage_timestamp) < cleanup_date;
  
  -- Clean up old test sessions
  DELETE FROM `enterprise_ai.integration_test_sessions`
  WHERE DATE(start_timestamp) < cleanup_date;
  
  -- Clean up resolved alerts older than retention period
  DELETE FROM `enterprise_ai.integration_alerts`
  WHERE DATE(alert_timestamp) < cleanup_date AND resolved = TRUE;
  
END;