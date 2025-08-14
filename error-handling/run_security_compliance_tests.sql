-- =====================================================
-- Security and Compliance Test Runner
-- =====================================================
-- Comprehensive test execution script that runs all
-- security and compliance validation tests
-- =====================================================

-- Main procedure to execute all security and compliance tests
CREATE OR REPLACE PROCEDURE run_all_security_compliance_tests()
BEGIN
  DECLARE execution_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE total_execution_time INT64;
  DECLARE overall_status STRING DEFAULT 'PASS';
  
  -- Log test execution start
  INSERT INTO `enterprise_knowledge_ai.test_execution_log`
  (execution_id, test_suite, status, start_time, metadata)
  VALUES (
    GENERATE_UUID(),
    'security_compliance_suite',
    'RUNNING',
    execution_start_time,
    JSON '{"test_type": "security_compliance", "automated": true}'
  );
  
  BEGIN
    -- Execute security and compliance tests
    CALL run_security_compliance_tests();
    
    -- Execute additional security monitoring
    CALL monitor_security_violations();
    
    -- Generate remediation suggestions
    CALL generate_remediation_suggestions();
    
    -- Validate test results and determine overall status
    SELECT 
      CASE 
        WHEN COUNTIF(test_status = 'FAIL' AND severity_level = 'CRITICAL') > 0 THEN 'CRITICAL_FAILURE'
        WHEN COUNTIF(test_status = 'FAIL' AND severity_level = 'HIGH') > 0 THEN 'HIGH_FAILURE'
        WHEN COUNTIF(test_status = 'FAIL') > 0 THEN 'FAILURE'
        WHEN COUNTIF(test_status = 'WARNING') > 0 THEN 'WARNING'
        ELSE 'PASS'
      END
    INTO overall_status
    FROM `enterprise_knowledge_ai.security_test_results`
    WHERE DATE(execution_timestamp) = CURRENT_DATE();
    
    -- Calculate execution time
    SET total_execution_time = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), execution_start_time, SECOND);
    
    -- Update execution log with completion status
    UPDATE `enterprise_knowledge_ai.test_execution_log`
    SET 
      status = overall_status,
      end_time = CURRENT_TIMESTAMP(),
      execution_time_seconds = total_execution_time,
      metadata = JSON_SET(
        metadata,
        '$.completion_status', overall_status,
        '$.execution_time_seconds', total_execution_time
      )
    WHERE test_suite = 'security_compliance_suite'
    AND DATE(start_time) = CURRENT_DATE()
    AND status = 'RUNNING';
    
  EXCEPTION WHEN ERROR THEN
    -- Handle test execution errors
    UPDATE `enterprise_knowledge_ai.test_execution_log`
    SET 
      status = 'ERROR',
      end_time = CURRENT_TIMESTAMP(),
      error_message = @@error.message,
      metadata = JSON_SET(
        metadata,
        '$.error_details', @@error.message,
        '$.error_code', CAST(@@error.code AS STRING)
      )
    WHERE test_suite = 'security_compliance_suite'
    AND DATE(start_time) = CURRENT_DATE()
    AND status = 'RUNNING';
    
    -- Re-raise the error
    RAISE USING MESSAGE = @@error.message;
  END;
  
  -- Generate executive summary report
  CALL generate_security_executive_summary();
  
END;

-- =====================================================
-- Executive Summary Report Generation
-- =====================================================

CREATE OR REPLACE PROCEDURE generate_security_executive_summary()
BEGIN
  DECLARE summary_content STRING;
  DECLARE critical_issues INT64;
  DECLARE high_issues INT64;
  DECLARE compliance_score FLOAT64;
  
  -- Calculate key metrics
  SELECT 
    COUNTIF(test_status = 'FAIL' AND severity_level = 'CRITICAL'),
    COUNTIF(test_status = 'FAIL' AND severity_level = 'HIGH'),
    ROUND(COUNTIF(test_status = 'PASS') / COUNT(*) * 100, 2)
  INTO critical_issues, high_issues, compliance_score
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) = CURRENT_DATE()
  AND test_name != 'Security Compliance Test Suite Summary';
  
  -- Generate AI-powered executive summary
  SET summary_content = (
    SELECT AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Generate an executive summary for enterprise security and compliance status:\n\n',
        'METRICS:\n',
        '- Overall Compliance Score: ', CAST(compliance_score AS STRING), '%\n',
        '- Critical Security Issues: ', CAST(critical_issues AS STRING), '\n',
        '- High Priority Issues: ', CAST(high_issues AS STRING), '\n\n',
        'DETAILED TEST RESULTS:\n',
        (SELECT STRING_AGG(
          CONCAT(
            '• ', test_name, ': ', test_status,
            CASE WHEN test_status != 'PASS' THEN CONCAT(' (', severity_level, ')') ELSE '' END,
            '\n  Details: ', JSON_VALUE(test_details, '$.description')
          ), '\n'
        )
        FROM `enterprise_knowledge_ai.security_test_results`
        WHERE DATE(execution_timestamp) = CURRENT_DATE()
        AND test_name != 'Security Compliance Test Suite Summary'
        ORDER BY 
          CASE severity_level 
            WHEN 'CRITICAL' THEN 1 
            WHEN 'HIGH' THEN 2 
            WHEN 'MEDIUM' THEN 3 
            ELSE 4 
          END,
          test_status DESC),
        '\n\nPlease provide:\n',
        '1. Executive Summary (2-3 sentences)\n',
        '2. Key Security Posture Assessment\n',
        '3. Critical Actions Required (if any)\n',
        '4. Compliance Status Overview\n',
        '5. Risk Assessment and Recommendations\n',
        '6. Next Steps and Timeline\n\n',
        'Format as a professional executive briefing suitable for C-level presentation.'
      )
    )
  );
  
  -- Store executive summary
  INSERT INTO `enterprise_knowledge_ai.executive_reports`
  (report_id, report_type, title, content, created_timestamp, metadata, priority_level)
  VALUES (
    GENERATE_UUID(),
    'security_executive_summary',
    CONCAT('Security & Compliance Executive Summary - ', FORMAT_DATE('%B %d, %Y', CURRENT_DATE())),
    summary_content,
    CURRENT_TIMESTAMP(),
    TO_JSON(STRUCT(
      compliance_score,
      critical_issues,
      high_issues,
      'automated' AS generation_method,
      CURRENT_DATE() AS report_date
    )),
    CASE 
      WHEN critical_issues > 0 THEN 'URGENT'
      WHEN high_issues > 0 THEN 'HIGH'
      ELSE 'NORMAL'
    END
  );
  
  -- Generate alerts for executives if critical issues exist
  IF critical_issues > 0 OR high_issues > 2 THEN
    INSERT INTO `enterprise_knowledge_ai.executive_alerts`
    (alert_id, alert_type, priority, title, message, created_timestamp, requires_action)
    VALUES (
      GENERATE_UUID(),
      'SECURITY_COMPLIANCE_ALERT',
      IF(critical_issues > 0, 'URGENT', 'HIGH'),
      'Security Compliance Issues Require Attention',
      CONCAT(
        'Security compliance assessment completed with ',
        CAST(critical_issues AS STRING), ' critical and ',
        CAST(high_issues AS STRING), ' high priority issues. ',
        'Overall compliance score: ', CAST(compliance_score AS STRING), '%. ',
        'Executive review and action required.'
      ),
      CURRENT_TIMESTAMP(),
      TRUE
    );
  END IF;
END;

-- =====================================================
-- Automated Scheduling and Continuous Monitoring
-- =====================================================

CREATE OR REPLACE PROCEDURE schedule_security_compliance_tests()
BEGIN
  -- This procedure would be called by a scheduler (Cloud Scheduler, cron, etc.)
  -- to run security and compliance tests on a regular basis
  
  DECLARE should_run_tests BOOL DEFAULT FALSE;
  DECLARE last_execution_date DATE;
  
  -- Check when tests were last run
  SELECT MAX(DATE(start_time))
  INTO last_execution_date
  FROM `enterprise_knowledge_ai.test_execution_log`
  WHERE test_suite = 'security_compliance_suite'
  AND status IN ('PASS', 'WARNING', 'FAILURE', 'CRITICAL_FAILURE', 'HIGH_FAILURE');
  
  -- Determine if tests should run (daily schedule)
  SET should_run_tests = (
    last_execution_date IS NULL 
    OR last_execution_date < CURRENT_DATE()
  );
  
  IF should_run_tests THEN
    CALL run_all_security_compliance_tests();
  END IF;
  
  -- Always run continuous monitoring checks
  CALL continuous_security_monitoring();
END;

-- =====================================================
-- Continuous Security Monitoring
-- =====================================================

CREATE OR REPLACE PROCEDURE continuous_security_monitoring()
BEGIN
  -- Monitor for real-time security events
  DECLARE suspicious_activity_count INT64;
  DECLARE failed_access_attempts INT64;
  DECLARE unusual_data_access INT64;
  
  -- Check for suspicious activity in the last hour
  SELECT 
    COUNT(*) AS suspicious_count
  INTO suspicious_activity_count
  FROM `enterprise_knowledge_ai.user_interactions` ui
  JOIN `enterprise_knowledge_ai.user_roles` ur ON ui.user_id = ur.user_id
  WHERE TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), ui.interaction_timestamp, HOUR) <= 1
  AND (
    -- Multiple failed access attempts
    JSON_VALUE(ui.context_metadata, '$.access_denied') = 'true'
    -- Unusual time access
    OR EXTRACT(HOUR FROM ui.interaction_timestamp) NOT BETWEEN 6 AND 22
    -- Cross-department access
    OR JSON_VALUE(ui.context_metadata, '$.accessed_department') != ur.department
  );
  
  -- Generate real-time alerts for suspicious activity
  IF suspicious_activity_count > 5 THEN
    INSERT INTO `enterprise_knowledge_ai.security_alerts`
    (alert_id, alert_type, severity, message, created_timestamp, requires_immediate_action)
    VALUES (
      GENERATE_UUID(),
      'SUSPICIOUS_ACTIVITY_DETECTED',
      'HIGH',
      CONCAT('Suspicious activity detected: ', CAST(suspicious_activity_count AS STRING), ' unusual access patterns in the last hour'),
      CURRENT_TIMESTAMP(),
      TRUE
    );
  END IF;
  
  -- Monitor for data exfiltration patterns
  WITH data_access_patterns AS (
    SELECT 
      user_id,
      COUNT(*) AS access_count,
      COUNT(DISTINCT JSON_VALUE(context_metadata, '$.insight_id')) AS unique_insights,
      SUM(CAST(JSON_VALUE(context_metadata, '$.data_size_mb') AS INT64)) AS total_data_mb
    FROM `enterprise_knowledge_ai.user_interactions`
    WHERE TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), interaction_timestamp, HOUR) <= 1
    AND interaction_type IN ('VIEW', 'DOWNLOAD', 'SHARE')
    GROUP BY user_id
  )
  SELECT COUNT(*)
  INTO unusual_data_access
  FROM data_access_patterns
  WHERE access_count > 50 OR total_data_mb > 1000;
  
  IF unusual_data_access > 0 THEN
    INSERT INTO `enterprise_knowledge_ai.security_alerts`
    (alert_id, alert_type, severity, message, created_timestamp, requires_immediate_action)
    VALUES (
      GENERATE_UUID(),
      'POTENTIAL_DATA_EXFILTRATION',
      'CRITICAL',
      CONCAT('Potential data exfiltration detected: ', CAST(unusual_data_access AS STRING), ' users with unusual data access patterns'),
      CURRENT_TIMESTAMP(),
      TRUE
    );
  END IF;
END;

-- =====================================================
-- Test Execution Log Table
-- =====================================================

CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_execution_log` (
  execution_id STRING NOT NULL,
  test_suite STRING NOT NULL,
  status ENUM('RUNNING', 'PASS', 'WARNING', 'FAILURE', 'CRITICAL_FAILURE', 'HIGH_FAILURE', 'ERROR'),
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  execution_time_seconds INT64,
  error_message STRING,
  metadata JSON
) PARTITION BY DATE(start_time)
CLUSTER BY test_suite, status;

-- Executive reports table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.executive_reports` (
  report_id STRING NOT NULL,
  report_type STRING NOT NULL,
  title STRING NOT NULL,
  content TEXT,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON,
  priority_level ENUM('NORMAL', 'HIGH', 'URGENT'),
  reviewed BOOL DEFAULT FALSE,
  reviewed_by STRING,
  reviewed_timestamp TIMESTAMP
) PARTITION BY DATE(created_timestamp)
CLUSTER BY report_type, priority_level;

-- Executive alerts table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.executive_alerts` (
  alert_id STRING NOT NULL,
  alert_type STRING NOT NULL,
  priority ENUM('NORMAL', 'HIGH', 'URGENT'),
  title STRING NOT NULL,
  message TEXT,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  requires_action BOOL DEFAULT FALSE,
  acknowledged BOOL DEFAULT FALSE,
  acknowledged_by STRING,
  acknowledged_timestamp TIMESTAMP,
  action_taken STRING,
  resolved BOOL DEFAULT FALSE
) PARTITION BY DATE(created_timestamp)
CLUSTER BY priority, alert_type;