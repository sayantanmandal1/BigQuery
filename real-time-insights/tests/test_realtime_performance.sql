-- Real-time Performance Tests
-- Validates system performance under various load conditions

-- Create test results table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_results` (
  test_id STRING NOT NULL,
  test_name STRING NOT NULL,
  test_category ENUM('performance', 'accuracy', 'integration', 'load'),
  test_status ENUM('passed', 'failed', 'warning'),
  execution_time_ms INT64,
  result_details JSON,
  test_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
) PARTITION BY DATE(test_timestamp)
CLUSTER BY test_category, test_status;

-- Test 1: Stream Processing Latency
CREATE OR REPLACE PROCEDURE test_stream_processing_latency()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_data JSON;
  DECLARE processing_result STRUCT<
    insights ARRAY<STRUCT<
      type STRING,
      content STRING,
      confidence FLOAT64,
      urgency STRING
    >>,
    processing_time_ms INT64
  >;
  DECLARE test_execution_time INT64;
  DECLARE test_status STRING DEFAULT 'passed';
  DECLARE test_details JSON;
  
  -- Create test data
  SET test_data = JSON_OBJECT(
    'raw_content', 'URGENT: System performance degradation detected in production environment. CPU usage at 95%, memory at 87%. Multiple user complaints received.',
    'structured_data', JSON_OBJECT(
      'cpu_usage', 0.95,
      'memory_usage', 0.87,
      'alert_count', 15,
      'severity', 'high'
    ),
    'metadata', JSON_OBJECT(
      'source', 'monitoring_system',
      'timestamp', CURRENT_TIMESTAMP()
    )
  );
  
  -- Process the test data
  SET processing_result = process_realtime_stream(test_data, 24);
  
  -- Calculate total test execution time
  SET test_execution_time = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND);
  
  -- Evaluate performance criteria
  IF processing_result.processing_time_ms > 2000 THEN
    SET test_status = 'failed';
  ELSEIF processing_result.processing_time_ms > 1000 THEN
    SET test_status = 'warning';
  END IF;
  
  -- Prepare test details
  SET test_details = JSON_OBJECT(
    'processing_time_ms', processing_result.processing_time_ms,
    'total_execution_time_ms', test_execution_time,
    'insights_generated', ARRAY_LENGTH(processing_result.insights),
    'performance_threshold_ms', 2000,
    'warning_threshold_ms', 1000,
    'insights_sample', TO_JSON_STRING(processing_result.insights)
  );
  
  -- Record test result
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
    'Stream Processing Latency Test',
    'performance',
    test_status,
    test_execution_time,
    test_details,
    JSON_OBJECT('test_type', 'latency', 'data_size', 'medium')
  );
  
END;

-- Test 2: Alert Generation Accuracy
CREATE OR REPLACE PROCEDURE test_alert_generation_accuracy()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_scenarios ARRAY<STRUCT<scenario STRING, expected_significance BOOL, content TEXT>>;
  DECLARE current_scenario STRUCT<scenario STRING, expected_significance BOOL, content TEXT>;
  DECLARE significance_result STRUCT<
    is_significant BOOL,
    significance_score FLOAT64,
    explanation TEXT,
    recommended_action TEXT
  >;
  DECLARE correct_predictions INT64 DEFAULT 0;
  DECLARE total_scenarios INT64;
  DECLARE accuracy_rate FLOAT64;
  DECLARE test_status STRING DEFAULT 'passed';
  DECLARE test_details JSON;
  
  -- Define test scenarios with expected outcomes
  SET test_scenarios = [
    STRUCT('critical_system_failure', TRUE, 'CRITICAL: Database server crashed, all services down, revenue impact $50K/hour'),
    STRUCT('minor_performance_issue', FALSE, 'INFO: Response time increased by 50ms, within acceptable range'),
    STRUCT('security_breach_attempt', TRUE, 'ALERT: Multiple failed login attempts from suspicious IP addresses, potential security breach'),
    STRUCT('routine_maintenance', FALSE, 'NOTICE: Scheduled maintenance window starting in 2 hours, expected 30-minute downtime'),
    STRUCT('revenue_anomaly', TRUE, 'WARNING: Daily revenue down 40% compared to last week, no obvious cause identified'),
    STRUCT('normal_traffic_spike', FALSE, 'INFO: Traffic increased 20% during lunch hour, consistent with historical patterns')
  ];
  
  SET total_scenarios = ARRAY_LENGTH(test_scenarios);
  
  -- Test each scenario
  FOR scenario_index IN (SELECT * FROM UNNEST(GENERATE_ARRAY(0, total_scenarios - 1))) DO
    SET current_scenario = test_scenarios[OFFSET(scenario_index)];
    
    -- Evaluate significance
    SET significance_result = evaluate_alert_significance(
      current_scenario.content,
      JSON_OBJECT(
        'business_context', 'Test environment evaluation',
        'historical_patterns', 'Standard business operations'
      ),
      0.7
    );
    
    -- Check if prediction matches expected outcome
    IF significance_result.is_significant = current_scenario.expected_significance THEN
      SET correct_predictions = correct_predictions + 1;
    END IF;
    
  END FOR;
  
  -- Calculate accuracy rate
  SET accuracy_rate = correct_predictions / total_scenarios;
  
  -- Determine test status
  IF accuracy_rate < 0.8 THEN
    SET test_status = 'failed';
  ELSEIF accuracy_rate < 0.9 THEN
    SET test_status = 'warning';
  END IF;
  
  -- Prepare test details
  SET test_details = JSON_OBJECT(
    'total_scenarios', total_scenarios,
    'correct_predictions', correct_predictions,
    'accuracy_rate', accuracy_rate,
    'minimum_accuracy_threshold', 0.8,
    'warning_accuracy_threshold', 0.9,
    'test_scenarios', TO_JSON_STRING(test_scenarios)
  );
  
  -- Record test result
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
    'Alert Generation Accuracy Test',
    'accuracy',
    test_status,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
    test_details,
    JSON_OBJECT('test_type', 'accuracy', 'scenario_count', total_scenarios)
  );
  
END;

-- Test 3: Recommendation Engine Performance
CREATE OR REPLACE PROCEDURE test_recommendation_engine_performance()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_user_contexts ARRAY<JSON>;
  DECLARE current_context JSON;
  DECLARE recommendations ARRAY<STRUCT<
    type STRING,
    title STRING,
    content STRING,
    priority FLOAT64,
    confidence FLOAT64,
    supporting_evidence ARRAY<STRING>
  >>;
  DECLARE total_processing_time INT64 DEFAULT 0;
  DECLARE context_count INT64;
  DECLARE average_processing_time FLOAT64;
  DECLARE test_status STRING DEFAULT 'passed';
  DECLARE test_details JSON;
  
  -- Create test user contexts
  SET test_user_contexts = [
    JSON_OBJECT(
      'current_projects', 'Product launch planning',
      'role', 'product_manager',
      'constraints', 'Limited budget, tight timeline'
    ),
    JSON_OBJECT(
      'current_projects', 'Sales performance analysis',
      'role', 'sales_director',
      'constraints', 'Quarterly targets, team motivation'
    ),
    JSON_OBJECT(
      'current_projects', 'System architecture review',
      'role', 'technical_lead',
      'constraints', 'Scalability requirements, security compliance'
    )
  ];
  
  SET context_count = ARRAY_LENGTH(test_user_contexts);
  
  -- Test recommendation generation for each context
  FOR context_index IN (SELECT * FROM UNNEST(GENERATE_ARRAY(0, context_count - 1))) DO
    DECLARE context_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    SET current_context = test_user_contexts[OFFSET(context_index)];
    
    -- Generate recommendations
    SET recommendations = generate_context_recommendations(
      current_context,
      JSON_OBJECT(
        'similar_contexts', 'Historical project data and outcomes',
        'past_decisions', 'Previous successful strategies and lessons learned',
        'evidence_sources', 'Enterprise knowledge base and user interactions'
      ),
      'Team meeting discussing project priorities and resource allocation'
    );
    
    -- Add processing time
    SET total_processing_time = total_processing_time + 
        TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), context_start_time, MILLISECOND);
    
  END FOR;
  
  -- Calculate average processing time
  SET average_processing_time = total_processing_time / context_count;
  
  -- Evaluate performance criteria
  IF average_processing_time > 3000 THEN
    SET test_status = 'failed';
  ELSEIF average_processing_time > 1500 THEN
    SET test_status = 'warning';
  END IF;
  
  -- Prepare test details
  SET test_details = JSON_OBJECT(
    'context_count', context_count,
    'total_processing_time_ms', total_processing_time,
    'average_processing_time_ms', average_processing_time,
    'performance_threshold_ms', 3000,
    'warning_threshold_ms', 1500,
    'recommendations_generated', ARRAY_LENGTH(recommendations)
  );
  
  -- Record test result
  INSERT INTO `enterprise_knowledge_ai.test_results` (
    test_id,
    test_name,
    test_category,
    test_status,
    execution_time_ms,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
    result_details,
    metadata
  )
  VALUES (
    GENERATE_UUID(),
    'Recommendation Engine Performance Test',
    'performance',
    test_status,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
    test_details,
    JSON_OBJECT('test_type', 'performance', 'context_variations', context_count)
  );
  
END;

-- Test 4: Data Pipeline Throughput
CREATE OR REPLACE PROCEDURE test_data_pipeline_throughput()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_data_batch ARRAY<JSON>;
  DECLARE batch_size INT64 DEFAULT 50;
  DECLARE current_data JSON;
  DECLARE processed_count INT64 DEFAULT 0;
  DECLARE failed_count INT64 DEFAULT 0;
  DECLARE throughput_rate FLOAT64;
  DECLARE test_status STRING DEFAULT 'passed';
  DECLARE test_details JSON;
  
  -- Generate test data batch
  SET test_data_batch = (
    SELECT ARRAY_AGG(
      JSON_OBJECT(
        'content', CONCAT('Test data item ', CAST(item_id AS STRING), ': Business metric update with value ', CAST(RAND() * 1000 AS STRING)),
        'timestamp', CURRENT_TIMESTAMP(),
        'source', 'performance_test',
        'type', 'structured',
        'metadata', JSON_OBJECT('test_batch', TRUE, 'item_id', item_id)
      )
    )
    FROM UNNEST(GENERATE_ARRAY(1, batch_size)) AS item_id
  );
  
  -- Process each data item
  FOR data_index IN (SELECT * FROM UNNEST(GENERATE_ARRAY(0, batch_size - 1))) DO
    DECLARE ingestion_result STRING;
    
    SET current_data = test_data_batch[OFFSET(data_index)];
    
    -- Ingest data into pipeline
    SET ingestion_result = ingest_realtime_data(
      'performance_test_system',
      current_data,
      10  -- High priority for testing
    );
    
    IF ingestion_result IS NOT NULL THEN
      SET processed_count = processed_count + 1;
    ELSE
      SET failed_count = failed_count + 1;
    END IF;
    
  END FOR;
  
  -- Wait for processing to complete (simulate real-world delay)
  CALL process_data_pipeline();
  
  -- Calculate throughput rate (items per second)
  SET throughput_rate = processed_count / 
      (TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) / 1000.0);
  
  -- Evaluate performance criteria
  IF throughput_rate < 5.0 THEN  -- Less than 5 items per second
    SET test_status = 'failed';
  ELSEIF throughput_rate < 10.0 THEN  -- Less than 10 items per second
    SET test_status = 'warning';
  END IF;
  
  -- Prepare test details
  SET test_details = JSON_OBJECT(
    'batch_size', batch_size,
    'processed_count', processed_count,
    'failed_count', failed_count,
    'throughput_rate_per_second', throughput_rate,
    'minimum_throughput_threshold', 5.0,
    'warning_throughput_threshold', 10.0,
    'success_rate', processed_count / batch_size
  );
  
  -- Record test result
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
    'Data Pipeline Throughput Test',
    'performance',
    test_status,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
    test_details,
    JSON_OBJECT('test_type', 'throughput', 'batch_size', batch_size)
  );
  
END;

-- Master test execution procedure
CREATE OR REPLACE PROCEDURE run_realtime_performance_tests()
BEGIN
  DECLARE test_suite_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE total_tests INT64 DEFAULT 0;
  DECLARE passed_tests INT64 DEFAULT 0;
  DECLARE failed_tests INT64 DEFAULT 0;
  DECLARE warning_tests INT64 DEFAULT 0;
  
  -- Run all performance tests
  CALL test_stream_processing_latency();
  CALL test_alert_generation_accuracy();
  CALL test_recommendation_engine_performance();
  CALL test_data_pipeline_throughput();
  
  -- Calculate test summary
  SELECT 
    COUNT(*) as total,
    COUNTIF(test_status = 'passed') as passed,
    COUNTIF(test_status = 'failed') as failed,
    COUNTIF(test_status = 'warning') as warnings
  INTO total_tests, passed_tests, failed_tests, warning_tests
  FROM `enterprise_knowledge_ai.test_results`
  WHERE test_timestamp >= test_suite_start;
  
  -- Log test suite summary
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
    'test_suite',
    CONCAT('Real-time performance test suite completed. Total: ', CAST(total_tests AS STRING),
           ', Passed: ', CAST(passed_tests AS STRING),
           ', Failed: ', CAST(failed_tests AS STRING),
           ', Warnings: ', CAST(warning_tests AS STRING)),
    CASE WHEN failed_tests > 0 THEN 'error' WHEN warning_tests > 0 THEN 'warning' ELSE 'info' END,
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'suite_execution_time_ms', TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_suite_start, MILLISECOND),
      'test_summary', JSON_OBJECT(
        'total', total_tests,
        'passed', passed_tests,
        'failed', failed_tests,
        'warnings', warning_tests
      )
    )
  );
  
END;