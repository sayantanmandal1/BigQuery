-- Alert Accuracy Tests
-- Validates the accuracy and reliability of AI-generated alerts

-- Create alert accuracy test scenarios table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.alert_test_scenarios` (
  scenario_id STRING NOT NULL,
  scenario_name STRING NOT NULL,
  scenario_category ENUM('business_critical', 'operational', 'informational', 'false_positive'),
  input_data JSON,
  expected_outcome STRUCT<
    should_alert BOOL,
    expected_urgency STRING,
    expected_confidence_min FLOAT64,
    expected_confidence_max FLOAT64
  >,
  business_context TEXT,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) CLUSTER BY scenario_category;

-- Insert test scenarios for alert accuracy validation
INSERT INTO `enterprise_knowledge_ai.alert_test_scenarios` (
  scenario_id,
  scenario_name,
  scenario_category,
  input_data,
  expected_outcome,
  business_context
)
VALUES
  -- Business Critical Scenarios
  (
    GENERATE_UUID(),
    'Revenue Drop Critical',
    'business_critical',
    JSON_OBJECT(
      'event_type', 'revenue_anomaly',
      'description', 'Daily revenue dropped 60% compared to same day last week with no scheduled maintenance or known issues',
      'metrics', JSON_OBJECT('revenue_drop_percent', 60, 'duration_hours', 8, 'affected_regions', ['US', 'EU']),
      'context', 'No planned outages, marketing campaigns running normally, competitor analysis shows no major launches'
    ),
    STRUCT(TRUE, 'critical', 0.85, 1.0),
    'Significant revenue impact requiring immediate executive attention and investigation'
  ),
  (
    GENERATE_UUID(),
    'Security Breach Detection',
    'business_critical',
    JSON_OBJECT(
      'event_type', 'security_incident',
      'description', 'Multiple failed admin login attempts from foreign IP addresses, followed by successful login and unusual data access patterns',
      'metrics', JSON_OBJECT('failed_attempts', 47, 'success_after_failures', TRUE, 'data_accessed_gb', 15.7, 'unusual_hours', TRUE),
      'context', 'Access occurred at 3 AM local time, data downloaded includes customer PII and financial records'
    ),
    STRUCT(TRUE, 'critical', 0.90, 1.0),
    'Potential security breach with customer data exposure requiring immediate incident response'
  ),
  (
    GENERATE_UUID(),
    'System Outage Critical',
    'business_critical',
    JSON_OBJECT(
      'event_type', 'system_failure',
      'description', 'Primary database cluster is down, all customer-facing services unavailable, error rate at 100%',
      'metrics', JSON_OBJECT('uptime_percent', 0, 'error_rate_percent', 100, 'affected_users', 50000, 'revenue_impact_per_hour', 25000),
      'context', 'No scheduled maintenance, backup systems also showing issues, customer complaints flooding support channels'
    ),
    STRUCT(TRUE, 'critical', 0.95, 1.0),
    'Complete service outage with significant revenue and reputation impact'
  ),
  
  -- Operational Scenarios
  (
    GENERATE_UUID(),
    'Performance Degradation',
    'operational',
    JSON_OBJECT(
      'event_type', 'performance_issue',
      'description', 'API response times increased from 200ms to 800ms over the past 2 hours, affecting user experience',
      'metrics', JSON_OBJECT('response_time_ms', 800, 'baseline_ms', 200, 'duration_hours', 2, 'affected_endpoints', 12),
      'context', 'Database CPU usage at 85%, memory usage normal, no recent deployments'
    ),
    STRUCT(TRUE, 'high', 0.70, 0.90),
    'Performance degradation affecting user experience but services still functional'
  ),
  (
    GENERATE_UUID(),
    'Capacity Warning',
    'operational',
    JSON_OBJECT(
      'event_type', 'capacity_warning',
      'description', 'Storage utilization reached 85% on primary data partition, trending toward 95% within 48 hours',
      'metrics', JSON_OBJECT('storage_percent', 85, 'growth_rate_gb_per_day', 50, 'estimated_full_hours', 48),
      'context', 'Regular data cleanup scheduled for next week, no immediate business impact but requires planning'
    ),
    STRUCT(TRUE, 'medium', 0.60, 0.85),
    'Proactive capacity management requiring planning but not immediate action'
  ),
  
  -- Informational Scenarios
  (
    GENERATE_UUID(),
    'Scheduled Maintenance Reminder',
    'informational',
    JSON_OBJECT(
      'event_type', 'maintenance_reminder',
      'description', 'Scheduled maintenance window begins in 4 hours, expected 30-minute downtime for database updates',
      'metrics', JSON_OBJECT('hours_until_maintenance', 4, 'expected_downtime_minutes', 30, 'affected_services', ['api', 'web']),
      'context', 'Pre-planned maintenance, stakeholders notified, backup systems ready'
    ),
    STRUCT(FALSE, 'low', 0.30, 0.60),
    'Routine scheduled maintenance with proper planning and communication'
  ),
  (
    GENERATE_UUID(),
    'Normal Traffic Spike',
    'informational',
    JSON_OBJECT(
      'event_type', 'traffic_increase',
      'description', 'Website traffic increased 40% during lunch hour, consistent with historical patterns for this time of year',
      'metrics', JSON_OBJECT('traffic_increase_percent', 40, 'historical_average_percent', 35, 'system_performance', 'normal'),
      'context', 'Seasonal pattern observed in previous years, systems handling load well, no performance issues'
    ),
    STRUCT(FALSE, 'low', 0.20, 0.50),
    'Expected traffic pattern with adequate system capacity'
  ),
  
  -- False Positive Scenarios
  (
    GENERATE_UUID(),
    'Minor Metric Fluctuation',
    'false_positive',
    JSON_OBJECT(
      'event_type', 'metric_change',
      'description', 'CPU usage briefly spiked to 70% for 5 minutes during automated backup process, now back to normal 45%',
      'metrics', JSON_OBJECT('peak_cpu_percent', 70, 'duration_minutes', 5, 'current_cpu_percent', 45, 'cause', 'scheduled_backup'),
      'context', 'Daily automated backup process, occurs same time every day, no impact on user experience'
    ),
    STRUCT(FALSE, 'low', 0.10, 0.40),
    'Normal operational process with expected temporary resource usage'
  ),
  (
    GENERATE_UUID(),
    'Test Environment Activity',
    'false_positive',
    JSON_OBJECT(
      'event_type', 'unusual_activity',
      'description', 'High database activity detected in test environment during load testing exercise',
      'metrics', JSON_OBJECT('db_connections', 500, 'query_rate_per_second', 1000, 'environment', 'test'),
      'context', 'Scheduled load testing by QA team, test environment isolated from production, expected high activity'
    ),
    STRUCT(FALSE, 'low', 0.05, 0.30),
    'Planned testing activity in isolated environment with no production impact'
  );

-- Test procedure for alert accuracy validation
CREATE OR REPLACE PROCEDURE test_alert_accuracy_comprehensive()
BEGIN
  DECLARE done BOOL DEFAULT FALSE;
  DECLARE current_scenario_id STRING;
  DECLARE current_scenario_name STRING;
  DECLARE current_input_data JSON;
  DECLARE current_expected STRUCT<
    should_alert BOOL,
    expected_urgency STRING,
    expected_confidence_min FLOAT64,
    expected_confidence_max FLOAT64
  >;
  DECLARE current_context TEXT;
  DECLARE significance_result STRUCT<
    is_significant BOOL,
    significance_score FLOAT64,
    explanation TEXT,
    recommended_action TEXT
  >;
  DECLARE alert_result STRUCT<
    alert_content TEXT,
    urgency_level STRING,
    personalized_message TEXT
  >;
  DECLARE test_results ARRAY<STRUCT<
    scenario_id STRING,
    scenario_name STRING,
    expected_alert BOOL,
    actual_alert BOOL,
    expected_urgency STRING,
    actual_urgency STRING,
    confidence_score FLOAT64,
    confidence_in_range BOOL,
    overall_correct BOOL
  >>;
  DECLARE current_result STRUCT<
    scenario_id STRING,
    scenario_name STRING,
    expected_alert BOOL,
    actual_alert BOOL,
    expected_urgency STRING,
    actual_urgency STRING,
    confidence_score FLOAT64,
    confidence_in_range BOOL,
    overall_correct BOOL
  >;
  
  -- Cursor for test scenarios
  DECLARE scenario_cursor CURSOR FOR
    SELECT 
      scenario_id,
      scenario_name,
      input_data,
      expected_outcome,
      business_context
    FROM `enterprise_knowledge_ai.alert_test_scenarios`
    ORDER BY scenario_category, scenario_name;
  
  DECLARE CONTINUE HANDLER FOR NOT_FOUND SET done = TRUE;
  
  SET test_results = [];
  
  OPEN scenario_cursor;
  
  test_loop: LOOP
    FETCH scenario_cursor INTO 
      current_scenario_id, 
      current_scenario_name, 
      current_input_data, 
      current_expected, 
      current_context;
    
    IF done THEN
      LEAVE test_loop;
    END IF;
    
    -- Evaluate alert significance
    SET significance_result = evaluate_alert_significance(
      JSON_EXTRACT_SCALAR(current_input_data, '$.description'),
      JSON_OBJECT(
        'business_context', current_context,
        'historical_patterns', 'Enterprise operational patterns and thresholds'
      ),
      0.7
    );
    
    -- Generate alert if significant
    IF significance_result.is_significant THEN
      SET alert_result = generate_contextual_alert(
        JSON_OBJECT(
          'event_description', JSON_EXTRACT_SCALAR(current_input_data, '$.description'),
          'data_summary', TO_JSON_STRING(current_input_data),
          'significance_score', CAST(significance_result.significance_score AS STRING)
        ),
        JSON_OBJECT(
          'role', 'system_administrator',
          'current_projects', 'system_monitoring'
        )
      );
    ELSE
      SET alert_result = STRUCT('' as alert_content, 'low' as urgency_level, '' as personalized_message);
    END IF;
    
    -- Evaluate test results
    SET current_result = STRUCT(
      current_scenario_id as scenario_id,
      current_scenario_name as scenario_name,
      current_expected.should_alert as expected_alert,
      significance_result.is_significant as actual_alert,
      current_expected.expected_urgency as expected_urgency,
      COALESCE(alert_result.urgency_level, 'low') as actual_urgency,
      significance_result.significance_score as confidence_score,
      (significance_result.significance_score >= current_expected.expected_confidence_min 
       AND significance_result.significance_score <= current_expected.expected_confidence_max) as confidence_in_range,
      (significance_result.is_significant = current_expected.should_alert 
       AND (NOT current_expected.should_alert OR alert_result.urgency_level = current_expected.expected_urgency)
       AND significance_result.significance_score >= current_expected.expected_confidence_min 
       AND significance_result.significance_score <= current_expected.expected_confidence_max) as overall_correct
    );
    
    SET test_results = ARRAY_CONCAT(test_results, [current_result]);
    
  END LOOP;
  
  CLOSE scenario_cursor;
  
  -- Calculate accuracy metrics
  WITH accuracy_metrics AS (
    SELECT 
      COUNT(*) as total_scenarios,
      COUNTIF(result.overall_correct) as correct_predictions,
      COUNTIF(result.expected_alert = result.actual_alert) as alert_decision_correct,
      COUNTIF(result.confidence_in_range) as confidence_in_range_count,
      COUNTIF(result.expected_alert AND result.actual_alert AND result.expected_urgency = result.actual_urgency) as urgency_correct,
      AVG(result.confidence_score) as avg_confidence_score
    FROM UNNEST(test_results) as result
  )
  
  -- Record comprehensive test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (
    test_id,
    test_name,
    test_category,
    test_status,
    execution_time_ms,
    result_details,
    metadata
  )
  SELECT 
    GENERATE_UUID(),
    'Comprehensive Alert Accuracy Test',
    'accuracy',
    CASE 
      WHEN (correct_predictions / total_scenarios) >= 0.90 THEN 'passed'
      WHEN (correct_predictions / total_scenarios) >= 0.80 THEN 'warning'
      ELSE 'failed'
    END,
    0, -- Execution time not critical for this test
    JSON_OBJECT(
      'total_scenarios', total_scenarios,
      'correct_predictions', correct_predictions,
      'overall_accuracy', correct_predictions / total_scenarios,
      'alert_decision_accuracy', alert_decision_correct / total_scenarios,
      'confidence_range_accuracy', confidence_in_range_count / total_scenarios,
      'urgency_classification_accuracy', urgency_correct / GREATEST(COUNTIF(result.expected_alert AND result.actual_alert), 1),
      'average_confidence_score', avg_confidence_score,
      'detailed_results', TO_JSON_STRING(test_results)
    ),
    JSON_OBJECT(
      'test_type', 'comprehensive_accuracy',
      'scenario_count', total_scenarios
    )
  FROM accuracy_metrics, UNNEST(test_results) as result;
  
END;

-- Test procedure for alert response time validation
CREATE OR REPLACE PROCEDURE test_alert_response_time()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE response_times ARRAY<INT64> DEFAULT [];
  DECLARE test_scenarios ARRAY<STRING>;
  DECLARE current_scenario STRING;
  DECLARE scenario_start_time TIMESTAMP;
  DECLARE scenario_response_time INT64;
  DECLARE avg_response_time FLOAT64;
  DECLARE max_response_time INT64;
  DECLARE test_status STRING DEFAULT 'passed';
  
  -- Define test scenarios for response time measurement
  SET test_scenarios = [
    'Critical system failure requiring immediate escalation and automated response procedures',
    'Security incident with potential data breach requiring forensic analysis and containment',
    'Performance degradation affecting multiple services with cascading impact analysis',
    'Capacity threshold breach requiring resource scaling and impact assessment',
    'Revenue anomaly detection requiring business impact analysis and stakeholder notification'
  ];
  
  -- Test response time for each scenario
  FOR scenario_index IN (SELECT * FROM UNNEST(GENERATE_ARRAY(0, ARRAY_LENGTH(test_scenarios) - 1))) DO
    SET current_scenario = test_scenarios[OFFSET(scenario_index)];
    SET scenario_start_time = CURRENT_TIMESTAMP();
    
    -- Process alert significance evaluation
    DECLARE significance_result STRUCT<
      is_significant BOOL,
      significance_score FLOAT64,
      explanation TEXT,
      recommended_action TEXT
    >;
    
    SET significance_result = evaluate_alert_significance(
      current_scenario,
      JSON_OBJECT(
        'business_context', 'Production environment monitoring',
        'historical_patterns', 'Enterprise operational baseline'
      ),
      0.7
    );
    
    -- If significant, generate alert
    IF significance_result.is_significant THEN
      DECLARE alert_result STRUCT<
        alert_content TEXT,
        urgency_level STRING,
        personalized_message TEXT
      >;
      
      SET alert_result = generate_contextual_alert(
        JSON_OBJECT(
          'event_description', current_scenario,
          'significance_score', CAST(significance_result.significance_score AS STRING)
        ),
        JSON_OBJECT(
          'role', 'incident_responder',
          'current_projects', 'system_monitoring'
        )
      );
    END IF;
    
    -- Calculate response time
    SET scenario_response_time = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), scenario_start_time, MILLISECOND);
    SET response_times = ARRAY_CONCAT(response_times, [scenario_response_time]);
    
  END FOR;
  
  -- Calculate performance metrics
  SELECT 
    AVG(response_time),
    MAX(response_time)
  INTO avg_response_time, max_response_time
  FROM UNNEST(response_times) as response_time;
  
  -- Evaluate performance criteria
  IF avg_response_time > 5000 OR max_response_time > 10000 THEN
    SET test_status = 'failed';
  ELSEIF avg_response_time > 3000 OR max_response_time > 7000 THEN
    SET test_status = 'warning';
  END IF;
  
  -- Record test results
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
    'Alert Response Time Test',
    'performance',
    test_status,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
    JSON_OBJECT(
      'scenario_count', ARRAY_LENGTH(test_scenarios),
      'average_response_time_ms', avg_response_time,
      'max_response_time_ms', max_response_time,
      'response_times', TO_JSON_STRING(response_times),
      'performance_threshold_avg_ms', 5000,
      'performance_threshold_max_ms', 10000,
      'warning_threshold_avg_ms', 3000,
      'warning_threshold_max_ms', 7000
    ),
    JSON_OBJECT(
      'test_type', 'response_time',
      'scenario_complexity', 'high'
    )
  );
  
END;

-- Master test execution for alert accuracy
CREATE OR REPLACE PROCEDURE run_alert_accuracy_tests()
BEGIN
  DECLARE test_suite_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  
  -- Run all alert accuracy tests
  CALL test_alert_accuracy_comprehensive();
  CALL test_alert_response_time();
  
  -- Generate test summary report
  WITH test_summary AS (
    SELECT 
      COUNT(*) as total_tests,
      COUNTIF(test_status = 'passed') as passed_tests,
      COUNTIF(test_status = 'failed') as failed_tests,
      COUNTIF(test_status = 'warning') as warning_tests,
      AVG(execution_time_ms) as avg_execution_time
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_timestamp >= test_suite_start
      AND test_category IN ('accuracy', 'performance')
  )
  
  -- Log comprehensive test suite results
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id,
    component,
    message,
    log_level,
    timestamp,
    metadata
  )
  SELECT 
    GENERATE_UUID(),
    'alert_accuracy_test_suite',
    CONCAT('Alert accuracy test suite completed. Total: ', CAST(total_tests AS STRING),
           ', Passed: ', CAST(passed_tests AS STRING),
           ', Failed: ', CAST(failed_tests AS STRING),
           ', Warnings: ', CAST(warning_tests AS STRING),
           ', Avg execution time: ', CAST(ROUND(avg_execution_time, 2) AS STRING), 'ms'),
    CASE 
      WHEN failed_tests > 0 THEN 'error' 
      WHEN warning_tests > 0 THEN 'warning' 
      ELSE 'info' 
    END,
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'suite_execution_time_ms', TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_suite_start, MILLISECOND),
      'test_summary', JSON_OBJECT(
        'total', total_tests,
        'passed', passed_tests,
        'failed', failed_tests,
        'warnings', warning_tests,
        'average_execution_time_ms', avg_execution_time
      )
    )
  FROM test_summary;
  
END;