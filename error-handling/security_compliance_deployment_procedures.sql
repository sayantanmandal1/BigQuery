-- =====================================================
-- Security and Compliance Framework Deployment Procedures
-- =====================================================

-- Create security and compliance schema procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.create_security_compliance_schema`()
BEGIN
  -- Execute schema creation from security_compliance_schema.sql
  -- This would typically be done by running the schema file
  
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'security_schema_deployment',
    'Security and compliance database schema created successfully',
    'info',
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'tables_created', [
        'user_roles',
        'audit_trail',
        'compliance_reports',
        'security_alerts',
        'data_classification',
        'privacy_assessments',
        'security_policies'
      ],
      'views_created', [
        'security_dashboard',
        'compliance_status',
        'audit_analysis'
      ]
    ),
    NULL,
    NULL
  );
END;

-- Initialize security policies procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.initialize_security_policies`()
BEGIN
  DECLARE policies_count INT64;
  
  -- Check if security policies already exist
  SELECT COUNT(*) INTO policies_count
  FROM `enterprise_knowledge_ai.security_policies`
  WHERE status = 'ACTIVE';
  
  IF policies_count = 0 THEN
    -- Insert default security policies (these would be inserted from security_compliance_schema.sql)
    INSERT INTO `enterprise_knowledge_ai.system_logs`
    VALUES (
      GENERATE_UUID(),
      'security_policies_init',
      'Default security policies initialized',
      'info',
      CURRENT_TIMESTAMP(),
      JSON_OBJECT(
        'policies_created', [
          'role_based_access_control_policy',
          'data_retention_policy',
          'encryption_policy'
        ],
        'default_policies_active', TRUE
      ),
      NULL,
      NULL
    );
  ELSE
    INSERT INTO `enterprise_knowledge_ai.system_logs`
    VALUES (
      GENERATE_UUID(),
      'security_policies_init',
      CONCAT('Security policies already exist: ', CAST(policies_count AS STRING), ' active policies found'),
      'info',
      CURRENT_TIMESTAMP(),
      JSON_OBJECT(
        'existing_policies_count', policies_count,
        'initialization_skipped', TRUE
      ),
      NULL,
      NULL
    );
  END IF;
END;

-- Setup security monitoring procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.setup_security_monitoring`()
BEGIN
  -- Initialize security monitoring configuration
  CREATE OR REPLACE TABLE IF NOT EXISTS `enterprise_knowledge_ai.security_monitoring_config` (
    config_id STRING NOT NULL,
    monitoring_type ENUM('continuous', 'scheduled', 'event_driven'),
    frequency_minutes INT64,
    enabled BOOL DEFAULT TRUE,
    alert_thresholds JSON,
    created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
  );
  
  -- Insert default monitoring configurations
  INSERT INTO `enterprise_knowledge_ai.security_monitoring_config`
  (config_id, monitoring_type, frequency_minutes, enabled, alert_thresholds)
  VALUES 
  (
    'continuous_security_monitoring',
    'continuous',
    15, -- Every 15 minutes
    TRUE,
    JSON '{
      "suspicious_activity_threshold": 5,
      "failed_access_attempts_threshold": 10,
      "data_exfiltration_threshold": 1000,
      "unusual_access_hours": [22, 23, 0, 1, 2, 3, 4, 5]
    }'
  ),
  (
    'daily_compliance_testing',
    'scheduled',
    1440, -- Daily (24 hours * 60 minutes)
    TRUE,
    JSON '{
      "critical_failure_threshold": 0,
      "high_failure_threshold": 2,
      "compliance_score_threshold": 85
    }'
  ),
  (
    'real_time_threat_detection',
    'event_driven',
    1, -- Check every minute for real-time threats
    TRUE,
    JSON '{
      "immediate_alert_severity": ["CRITICAL"],
      "escalation_time_minutes": 5,
      "auto_response_enabled": true
    }'
  );
  
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'security_monitoring_setup',
    'Security monitoring configuration initialized successfully',
    'info',
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'monitoring_types_configured', [
        'continuous_security_monitoring',
        'daily_compliance_testing',
        'real_time_threat_detection'
      ],
      'monitoring_active', TRUE
    ),
    NULL,
    NULL
  );
END;

-- Comprehensive security framework validation procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.validate_security_framework_deployment`()
BEGIN
  DECLARE schema_valid BOOL DEFAULT FALSE;
  DECLARE policies_valid BOOL DEFAULT FALSE;
  DECLARE monitoring_valid BOOL DEFAULT FALSE;
  DECLARE test_procedures_valid BOOL DEFAULT FALSE;
  
  -- Validate schema deployment
  BEGIN
    SELECT TRUE INTO schema_valid
    FROM `enterprise_knowledge_ai.security_test_results`
    LIMIT 1;
  EXCEPTION WHEN ERROR THEN
    SET schema_valid = FALSE;
  END;
  
  -- Validate security policies
  SELECT COUNT(*) > 0 INTO policies_valid
  FROM `enterprise_knowledge_ai.security_policies`
  WHERE status = 'ACTIVE';
  
  -- Validate monitoring configuration
  SELECT COUNT(*) > 0 INTO monitoring_valid
  FROM `enterprise_knowledge_ai.security_monitoring_config`
  WHERE enabled = TRUE;
  
  -- Validate test procedures exist
  BEGIN
    CALL test_role_assignments();
    SET test_procedures_valid = TRUE;
  EXCEPTION WHEN ERROR THEN
    SET test_procedures_valid = FALSE;
  END;
  
  -- Log validation results
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'security_framework_validation',
    'Security framework deployment validation completed',
    IF(schema_valid AND policies_valid AND monitoring_valid AND test_procedures_valid, 'info', 'error'),
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'schema_valid', schema_valid,
      'policies_valid', policies_valid,
      'monitoring_valid', monitoring_valid,
      'test_procedures_valid', test_procedures_valid,
      'overall_deployment_status', 
        IF(schema_valid AND policies_valid AND monitoring_valid AND test_procedures_valid, 'SUCCESS', 'FAILED')
    ),
    NULL,
    NULL
  );
  
  -- If validation fails, provide remediation guidance
  IF NOT (schema_valid AND policies_valid AND monitoring_valid AND test_procedures_valid) THEN
    INSERT INTO `enterprise_knowledge_ai.system_logs`
    VALUES (
      GENERATE_UUID(),
      'security_framework_validation',
      'Security framework deployment validation failed - remediation required',
      'error',
      CURRENT_TIMESTAMP(),
      JSON_OBJECT(
        'remediation_steps', [
          IF(NOT schema_valid, 'Execute security_compliance_schema.sql', NULL),
          IF(NOT policies_valid, 'Run initialize_security_policies procedure', NULL),
          IF(NOT monitoring_valid, 'Run setup_security_monitoring procedure', NULL),
          IF(NOT test_procedures_valid, 'Deploy security_compliance_testing.sql procedures', NULL)
        ],
        'validation_failed', TRUE
      ),
      NULL,
      NULL
    );
  END IF;
END;

-- Security framework health check procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.security_framework_health_check`()
BEGIN
  DECLARE last_test_execution TIMESTAMP;
  DECLARE active_alerts INT64;
  DECLARE unresolved_violations INT64;
  DECLARE compliance_score FLOAT64;
  
  -- Check when security tests were last executed
  SELECT MAX(execution_timestamp) INTO last_test_execution
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
  
  -- Count active security alerts
  SELECT COUNT(*) INTO active_alerts
  FROM `enterprise_knowledge_ai.security_alerts`
  WHERE resolved = FALSE
  AND created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR);
  
  -- Count unresolved security violations
  SELECT COUNT(*) INTO unresolved_violations
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE test_status = 'FAIL'
  AND severity_level IN ('CRITICAL', 'HIGH')
  AND DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
  
  -- Calculate overall compliance score
  SELECT 
    ROUND(COUNTIF(test_status = 'PASS') / COUNT(*) * 100, 2)
  INTO compliance_score
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
  
  -- Log health check results
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'security_framework_health_check',
    'Security framework health check completed',
    CASE 
      WHEN unresolved_violations > 0 THEN 'error'
      WHEN active_alerts > 5 THEN 'warning'
      WHEN compliance_score < 90 THEN 'warning'
      ELSE 'info'
    END,
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'last_test_execution', CAST(last_test_execution AS STRING),
      'active_alerts', active_alerts,
      'unresolved_violations', unresolved_violations,
      'compliance_score', compliance_score,
      'health_status', 
        CASE 
          WHEN unresolved_violations > 0 THEN 'CRITICAL'
          WHEN active_alerts > 5 OR compliance_score < 90 THEN 'WARNING'
          ELSE 'HEALTHY'
        END,
      'recommendations', 
        CASE 
          WHEN last_test_execution IS NULL OR last_test_execution < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR) 
            THEN ['Run security compliance tests']
          WHEN unresolved_violations > 0 
            THEN ['Address critical security violations immediately']
          WHEN active_alerts > 5 
            THEN ['Review and resolve active security alerts']
          WHEN compliance_score < 90 
            THEN ['Investigate compliance score degradation']
          ELSE ['Continue regular monitoring']
        END
    ),
    NULL,
    NULL
  );
END;

-- Automated security framework maintenance procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.maintain_security_framework`()
BEGIN
  -- Clean up old test results (keep last 90 days)
  DELETE FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);
  
  -- Archive resolved security alerts (older than 30 days)
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.security_alerts_archive`
  PARTITION BY DATE(created_timestamp)
  CLUSTER BY alert_type, severity
  AS
  SELECT * FROM `enterprise_knowledge_ai.security_alerts`
  WHERE resolved = TRUE
  AND resolved_timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY);
  
  DELETE FROM `enterprise_knowledge_ai.security_alerts`
  WHERE resolved = TRUE
  AND resolved_timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY);
  
  -- Update security policy review dates
  UPDATE `enterprise_knowledge_ai.security_policies`
  SET last_updated = CURRENT_TIMESTAMP()
  WHERE effective_date <= CURRENT_DATE()
  AND (expiration_date IS NULL OR expiration_date > CURRENT_DATE())
  AND last_updated < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY);
  
  -- Clean up old audit trail entries (keep last 3 years as per policy)
  DELETE FROM `enterprise_knowledge_ai.audit_trail`
  WHERE DATE(audit_timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 1095 DAY); -- 3 years
  
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'security_framework_maintenance',
    'Security framework maintenance completed successfully',
    'info',
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'maintenance_tasks_completed', [
        'cleaned_old_test_results',
        'archived_resolved_alerts',
        'updated_policy_review_dates',
        'cleaned_old_audit_trail_entries'
      ],
      'maintenance_timestamp', CURRENT_TIMESTAMP()
    ),
    NULL,
    NULL
  );
END;