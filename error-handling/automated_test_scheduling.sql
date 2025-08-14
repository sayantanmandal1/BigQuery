-- Automated Test Scheduling and Continuous Validation System
-- Provides scheduled test execution and continuous monitoring

-- Create scheduled jobs table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.scheduled_jobs` (
  job_id STRING NOT NULL,
  job_type ENUM('test_execution', 'validation_check', 'performance_monitoring', 'cleanup'),
  job_name STRING NOT NULL,
  schedule_expression STRING NOT NULL,
  next_execution_time TIMESTAMP NOT NULL,
  last_execution_time TIMESTAMP,
  job_parameters JSON,
  status ENUM('active', 'paused', 'disabled', 'error'),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  execution_count INT64 DEFAULT 0,
  failure_count INT64 DEFAULT 0,
  metadata JSON
) PARTITION BY DATE(created_at)
CLUSTER BY job_type, status;

-- Create job execution history table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.job_execution_history` (
  execution_id STRING NOT NULL,
  job_id STRING NOT NULL,
  execution_start_time TIMESTAMP NOT NULL,
  execution_end_time TIMESTAMP,
  execution_status ENUM('running', 'completed', 'failed', 'timeout'),
  execution_result JSON,
  error_message STRING,
  execution_duration_ms INT64,
  resource_usage JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY DATE(created_at)
CLUSTER BY job_id, execution_status;

-- Procedure to schedule comprehensive test execution
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.schedule_comprehensive_tests`(
  schedule_frequency STRING DEFAULT 'daily',
  execution_time STRING DEFAULT '02:00:00',
  test_environment STRING DEFAULT 'production',
  include_performance_tests BOOL DEFAULT TRUE,
  include_integration_tests BOOL DEFAULT TRUE
)
BEGIN
  DECLARE job_id STRING DEFAULT GENERATE_UUID();
  DECLARE next_execution TIMESTAMP;
  DECLARE schedule_expr STRING;
  
  -- Calculate next execution time based on frequency
  CASE schedule_frequency
    WHEN 'hourly' THEN
      SET next_execution = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);
      SET schedule_expr = '0 * * * *';  -- Every hour
    WHEN 'daily' THEN
      SET next_execution = TIMESTAMP(CONCAT(CAST(DATE_ADD(CURRENT_DATE(), INTERVAL 1 DAY) AS STRING), ' ', execution_time));
      SET schedule_expr = CONCAT('0 ', EXTRACT(HOUR FROM TIME(execution_time)), ' * * *');  -- Daily at specified time
    WHEN 'weekly' THEN
      SET next_execution = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 WEEK);
      SET schedule_expr = CONCAT('0 ', EXTRACT(HOUR FROM TIME(execution_time)), ' * * 1');  -- Weekly on Monday
    WHEN 'monthly' THEN
      SET next_execution = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 MONTH);
      SET schedule_expr = CONCAT('0 ', EXTRACT(HOUR FROM TIME(execution_time)), ' 1 * *');  -- Monthly on 1st
    ELSE
      SET next_execution = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY);
      SET schedule_expr = '0 2 * * *';  -- Default: daily at 2 AM
  END CASE;
  
  -- Insert scheduled job
  INSERT INTO `enterprise_knowledge_ai.scheduled_jobs` (
    job_id,
    job_type,
    job_name,
    schedule_expression,
    next_execution_time,
    job_parameters,
    status,
    metadata
  ) VALUES (
    job_id,
    'test_execution',
    CONCAT('Comprehensive Test Suite - ', schedule_frequency),
    schedule_expr,
    next_execution,
    JSON_OBJECT(
      'schedule_frequency', schedule_frequency,
      'execution_time', execution_time,
      'test_environment', test_environment,
      'include_performance_tests', include_performance_tests,
      'include_integration_tests', include_integration_tests,
      'notification_enabled', TRUE,
      'failure_threshold', 0.85
    ),
    'active',
    JSON_OBJECT(
      'created_by', SESSION_USER(),
      'creation_timestamp', CURRENT_TIMESTAMP(),
      'job_description', 'Automated comprehensive test suite execution'
    )
  );
  
  -- Log job creation
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id, component, message, log_level, timestamp, metadata
  ) VALUES (
    GENERATE_UUID(),
    'test_scheduler',
    CONCAT('Scheduled comprehensive test suite: ', schedule_frequency, ' at ', execution_time),
    'info',
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'job_id', job_id,
      'next_execution', next_execution,
      'schedule_expression', schedule_expr
    )
  );
  
  SELECT 
    job_id,
    'Comprehensive test suite scheduled successfully' as message,
    next_execution as next_execution_time,
    schedule_expr as schedule_expression;
  
END;

-- Procedure to execute scheduled jobs
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.execute_scheduled_job`(job_id STRING)
BEGIN
  DECLARE execution_id STRING DEFAULT GENERATE_UUID();
  DECLARE job_info STRUCT<
    job_type STRING,
    job_name STRING,
    job_parameters JSON,
    status STRING
  >;
  DECLARE execution_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE execution_result JSON;
  DECLARE execution_status STRING DEFAULT 'running';
  DECLARE error_msg STRING;
  
  -- Get job information
  SELECT AS STRUCT 
    job_type,
    job_name,
    job_parameters,
    status
  INTO job_info
  FROM `enterprise_knowledge_ai.scheduled_jobs`
  WHERE scheduled_jobs.job_id = execute_scheduled_job.job_id;
  
  -- Check if job exists and is active
  IF job_info IS NULL THEN
    RAISE USING MESSAGE = CONCAT('Job not found: ', job_id);
  END IF;
  
  IF job_info.status != 'active' THEN
    RAISE USING MESSAGE = CONCAT('Job is not active: ', job_id, ' (status: ', job_info.status, ')');
  END IF;
  
  -- Record execution start
  INSERT INTO `enterprise_knowledge_ai.job_execution_history` (
    execution_id,
    job_id,
    execution_start_time,
    execution_status
  ) VALUES (
    execution_id,
    job_id,
    execution_start,
    'running'
  );
  
  -- Execute job based on type
  BEGIN
    CASE job_info.job_type
      WHEN 'test_execution' THEN
        -- Execute unified comprehensive test suite
        CALL `enterprise_knowledge_ai.run_unified_test_suite`(
          CAST(JSON_EXTRACT_SCALAR(job_info.job_parameters, '$.include_performance_tests') AS BOOL),
          CAST(JSON_EXTRACT_SCALAR(job_info.job_parameters, '$.include_integration_tests') AS BOOL),
          CAST(JSON_EXTRACT_SCALAR(job_info.job_parameters, '$.include_load_tests') AS BOOL),
          JSON_EXTRACT_SCALAR(job_info.job_parameters, '$.test_environment'),
          TRUE  -- parallel_execution enabled
        );
        
        -- Get execution results
        SET execution_result = (
          SELECT JSON_OBJECT(
            'total_tests', total_tests,
            'passed_tests', passed_tests,
            'failed_tests', failed_tests,
            'success_rate', overall_success_rate,
            'execution_time_ms', total_execution_time_ms
          )
          FROM `enterprise_knowledge_ai.test_execution_summary`
          ORDER BY execution_timestamp DESC
          LIMIT 1
        );
        
      WHEN 'validation_check' THEN
        -- Execute continuous validation
        CALL `enterprise_knowledge_ai.continuous_validation`();
        SET execution_result = JSON_OBJECT('validation_completed', TRUE);
        
      WHEN 'performance_monitoring' THEN
        -- Execute performance monitoring
        CALL `enterprise_knowledge_ai.monitor_test_performance`();
        SET execution_result = JSON_OBJECT('monitoring_completed', TRUE);
        
      WHEN 'cleanup' THEN
        -- Execute cleanup tasks
        CALL `enterprise_knowledge_ai.cleanup_old_test_data`();
        SET execution_result = JSON_OBJECT('cleanup_completed', TRUE);
        
      ELSE
        RAISE USING MESSAGE = CONCAT('Unknown job type: ', job_info.job_type);
    END CASE;
    
    SET execution_status = 'completed';
    
  EXCEPTION WHEN ERROR THEN
    SET execution_status = 'failed';
    SET error_msg = @@error.message;
    SET execution_result = JSON_OBJECT('error', error_msg);
  END;
  
  -- Update execution record
  UPDATE `enterprise_knowledge_ai.job_execution_history`
  SET 
    execution_end_time = CURRENT_TIMESTAMP(),
    execution_status = execution_status,
    execution_result = execution_result,
    error_message = error_msg,
    execution_duration_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), execution_start, MILLISECOND)
  WHERE job_execution_history.execution_id = execute_scheduled_job.execution_id;
  
  -- Update job statistics
  UPDATE `enterprise_knowledge_ai.scheduled_jobs`
  SET 
    last_execution_time = execution_start,
    execution_count = execution_count + 1,
    failure_count = CASE WHEN execution_status = 'failed' THEN failure_count + 1 ELSE failure_count END,
    updated_at = CURRENT_TIMESTAMP(),
    -- Calculate next execution time
    next_execution_time = CASE 
      WHEN schedule_expression LIKE '%hourly%' OR schedule_expression = '0 * * * *' THEN 
        TIMESTAMP_ADD(execution_start, INTERVAL 1 HOUR)
      WHEN schedule_expression LIKE '%daily%' OR schedule_expression LIKE '0 _ * * *' THEN 
        TIMESTAMP_ADD(execution_start, INTERVAL 1 DAY)
      WHEN schedule_expression LIKE '%weekly%' OR schedule_expression LIKE '0 _ * * 1' THEN 
        TIMESTAMP_ADD(execution_start, INTERVAL 1 WEEK)
      WHEN schedule_expression LIKE '%monthly%' OR schedule_expression LIKE '0 _ 1 * *' THEN 
        TIMESTAMP_ADD(execution_start, INTERVAL 1 MONTH)
      ELSE TIMESTAMP_ADD(execution_start, INTERVAL 1 DAY)
    END
  WHERE scheduled_jobs.job_id = execute_scheduled_job.job_id;
  
  -- Send notifications if configured and job failed
  IF execution_status = 'failed' AND JSON_EXTRACT_SCALAR(job_info.job_parameters, '$.notification_enabled') = 'true' THEN
    CALL `enterprise_knowledge_ai.send_job_failure_notification`(job_id, execution_id, error_msg);
  END IF;
  
  -- Log execution completion
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id, component, message, log_level, timestamp, metadata
  ) VALUES (
    GENERATE_UUID(),
    'job_executor',
    CONCAT('Job execution ', execution_status, ': ', job_info.job_name),
    CASE WHEN execution_status = 'failed' THEN 'error' ELSE 'info' END,
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'job_id', job_id,
      'execution_id', execution_id,
      'execution_duration_ms', TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), execution_start, MILLISECOND),
      'execution_result', execution_result
    )
  );
  
END;

-- Procedure to monitor test performance continuously
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.monitor_test_performance`()
BEGIN
  DECLARE performance_threshold FLOAT64 DEFAULT 15000.0;  -- 15 seconds
  DECLARE success_rate_threshold FLOAT64 DEFAULT 0.85;   -- 85%
  DECLARE alert_count INT64 DEFAULT 0;
  
  -- Check for performance degradation
  WITH performance_issues AS (
    SELECT 
      test_suite,
      AVG(execution_time_ms) as avg_execution_time,
      COUNT(*) as slow_test_count
    FROM `enterprise_knowledge_ai.master_test_results`
    WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      AND execution_time_ms > performance_threshold
    GROUP BY test_suite
    HAVING COUNT(*) > 0
  ),
  quality_issues AS (
    SELECT 
      test_suite,
      SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) as success_rate,
      COUNT(*) as total_tests
    FROM `enterprise_knowledge_ai.master_test_results`
    WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    GROUP BY test_suite
    HAVING SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) < success_rate_threshold
  )
  
  -- Generate performance alerts
  INSERT INTO `enterprise_knowledge_ai.system_alerts` (
    alert_id,
    alert_type,
    severity,
    title,
    message,
    metadata,
    created_at
  )
  SELECT 
    GENERATE_UUID(),
    'performance_degradation',
    'medium',
    CONCAT('Performance Degradation Detected: ', test_suite),
    CONCAT(
      'Test suite "', test_suite, '" has ', CAST(slow_test_count AS STRING), 
      ' tests with average execution time of ', CAST(ROUND(avg_execution_time, 0) AS STRING), 
      'ms, exceeding the threshold of ', CAST(performance_threshold AS STRING), 'ms.'
    ),
    JSON_OBJECT(
      'test_suite', test_suite,
      'avg_execution_time_ms', avg_execution_time,
      'slow_test_count', slow_test_count,
      'threshold_ms', performance_threshold
    ),
    CURRENT_TIMESTAMP()
  FROM performance_issues;
  
  -- Generate quality alerts
  INSERT INTO `enterprise_knowledge_ai.system_alerts` (
    alert_id,
    alert_type,
    severity,
    title,
    message,
    metadata,
    created_at
  )
  SELECT 
    GENERATE_UUID(),
    'quality_degradation',
    'high',
    CONCAT('Quality Degradation Detected: ', test_suite),
    CONCAT(
      'Test suite "', test_suite, '" has success rate of ', 
      CAST(ROUND(success_rate * 100, 2) AS STRING), 
      '%, below the threshold of ', CAST(ROUND(success_rate_threshold * 100, 2) AS STRING), '%.'
    ),
    JSON_OBJECT(
      'test_suite', test_suite,
      'success_rate', success_rate,
      'total_tests', total_tests,
      'threshold', success_rate_threshold
    ),
    CURRENT_TIMESTAMP()
  FROM quality_issues;
  
  -- Count total alerts generated
  SELECT COUNT(*) INTO alert_count
  FROM `enterprise_knowledge_ai.system_alerts`
  WHERE DATE(created_at) = CURRENT_DATE()
    AND alert_type IN ('performance_degradation', 'quality_degradation');
  
  -- Log monitoring completion
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id, component, message, log_level, timestamp, metadata
  ) VALUES (
    GENERATE_UUID(),
    'performance_monitor',
    CONCAT('Performance monitoring completed. Generated ', CAST(alert_count AS STRING), ' alerts.'),
    CASE WHEN alert_count > 0 THEN 'warning' ELSE 'info' END,
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'alerts_generated', alert_count,
      'performance_threshold_ms', performance_threshold,
      'success_rate_threshold', success_rate_threshold
    )
  );
  
END;

-- Procedure to cleanup old test data
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.cleanup_old_test_data`()
BEGIN
  DECLARE retention_days INT64 DEFAULT 90;
  DECLARE cleanup_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL retention_days DAY);
  DECLARE deleted_records INT64 DEFAULT 0;
  
  -- Delete old test results
  DELETE FROM `enterprise_knowledge_ai.master_test_results`
  WHERE DATE(execution_timestamp) < cleanup_date;
  
  SET deleted_records = @@row_count;
  
  -- Delete old execution summaries
  DELETE FROM `enterprise_knowledge_ai.test_execution_summary`
  WHERE DATE(execution_timestamp) < cleanup_date;
  
  SET deleted_records = deleted_records + @@row_count;
  
  -- Delete old job execution history
  DELETE FROM `enterprise_knowledge_ai.job_execution_history`
  WHERE DATE(created_at) < cleanup_date;
  
  SET deleted_records = deleted_records + @@row_count;
  
  -- Delete old test metrics
  DELETE FROM `enterprise_knowledge_ai.test_metrics_daily`
  WHERE metric_date < cleanup_date;
  
  SET deleted_records = deleted_records + @@row_count;
  
  -- Log cleanup completion
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id, component, message, log_level, timestamp, metadata
  ) VALUES (
    GENERATE_UUID(),
    'data_cleanup',
    CONCAT('Test data cleanup completed. Deleted ', CAST(deleted_records AS STRING), ' records older than ', CAST(retention_days AS STRING), ' days.'),
    'info',
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'retention_days', retention_days,
      'cleanup_date', cleanup_date,
      'deleted_records', deleted_records
    )
  );
  
END;

-- Procedure to send job failure notifications
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.send_job_failure_notification`(
  job_id STRING,
  execution_id STRING,
  error_message STRING
)
BEGIN
  DECLARE notification_content STRING;
  DECLARE job_name STRING;
  
  -- Get job name
  SELECT scheduled_jobs.job_name INTO job_name
  FROM `enterprise_knowledge_ai.scheduled_jobs`
  WHERE scheduled_jobs.job_id = send_job_failure_notification.job_id;
  
  -- Generate notification content
  SET notification_content = AI.GENERATE(
    MODEL `enterprise_knowledge_ai.gemini_model`,
    CONCAT(
      'Generate a professional notification message for a failed scheduled job. ',
      'Job Name: ', job_name, '. ',
      'Error: ', error_message, '. ',
      'Include recommended next steps and urgency level.'
    )
  );
  
  -- Store notification (in real implementation, this would integrate with email/Slack/etc.)
  INSERT INTO `enterprise_knowledge_ai.notifications` (
    notification_id,
    notification_type,
    recipient_type,
    title,
    content,
    priority,
    metadata,
    created_at
  ) VALUES (
    GENERATE_UUID(),
    'job_failure',
    'admin',
    CONCAT('Scheduled Job Failed: ', job_name),
    notification_content,
    'high',
    JSON_OBJECT(
      'job_id', job_id,
      'execution_id', execution_id,
      'error_message', error_message,
      'failure_timestamp', CURRENT_TIMESTAMP()
    ),
    CURRENT_TIMESTAMP()
  );
  
END;

-- Create notifications table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.notifications` (
  notification_id STRING NOT NULL,
  notification_type STRING NOT NULL,
  recipient_type STRING NOT NULL,
  title STRING NOT NULL,
  content STRING NOT NULL,
  priority ENUM('low', 'medium', 'high', 'critical'),
  status ENUM('pending', 'sent', 'failed') DEFAULT 'pending',
  metadata JSON,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  sent_at TIMESTAMP
) PARTITION BY DATE(created_at)
CLUSTER BY notification_type, priority;

-- View for monitoring scheduled jobs
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.scheduled_jobs_monitor` AS
WITH job_performance AS (
  SELECT 
    j.job_id,
    j.job_name,
    j.job_type,
    j.status,
    j.next_execution_time,
    j.last_execution_time,
    j.execution_count,
    j.failure_count,
    SAFE_DIVIDE(j.failure_count, j.execution_count) as failure_rate,
    AVG(h.execution_duration_ms) as avg_execution_time_ms,
    COUNT(CASE WHEN h.execution_status = 'failed' AND DATE(h.created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) THEN 1 END) as recent_failures
  FROM `enterprise_knowledge_ai.scheduled_jobs` j
  LEFT JOIN `enterprise_knowledge_ai.job_execution_history` h ON j.job_id = h.job_id
  GROUP BY j.job_id, j.job_name, j.job_type, j.status, j.next_execution_time, j.last_execution_time, j.execution_count, j.failure_count
)
SELECT 
  job_id,
  job_name,
  job_type,
  status,
  next_execution_time,
  last_execution_time,
  execution_count,
  failure_count,
  ROUND(failure_rate * 100, 2) as failure_rate_percent,
  ROUND(avg_execution_time_ms / 1000.0, 2) as avg_execution_time_seconds,
  recent_failures,
  CASE 
    WHEN status != 'active' THEN '⚠️ Inactive'
    WHEN recent_failures > 3 THEN '🔴 High Failure Rate'
    WHEN failure_rate > 0.1 THEN '🟡 Moderate Issues'
    WHEN next_execution_time < CURRENT_TIMESTAMP() THEN '⏰ Overdue'
    ELSE '✅ Healthy'
  END as health_status,
  TIMESTAMP_DIFF(next_execution_time, CURRENT_TIMESTAMP(), MINUTE) as minutes_until_next_execution
FROM job_performance
ORDER BY 
  CASE WHEN status = 'active' THEN 0 ELSE 1 END,
  recent_failures DESC,
  failure_rate DESC;