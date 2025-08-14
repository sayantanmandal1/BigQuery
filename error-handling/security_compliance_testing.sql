-- =====================================================
-- Security and Compliance Testing Framework
-- =====================================================
-- This framework validates role-based access controls,
-- data privacy protection, and audit trail compliance
-- for the Enterprise Knowledge Intelligence Platform
-- =====================================================

-- Create security test results table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.security_test_results` (
  test_id STRING NOT NULL,
  test_category ENUM('access_control', 'data_privacy', 'audit_trail', 'compliance'),
  test_name STRING NOT NULL,
  test_status ENUM('PASS', 'FAIL', 'WARNING'),
  test_details JSON,
  execution_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  remediation_required BOOL,
  severity_level ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')
) PARTITION BY DATE(execution_timestamp)
CLUSTER BY test_category, test_status;

-- =====================================================
-- Role-Based Access Control Validation Tests
-- =====================================================

-- Test 1: Validate user role assignments
CREATE OR REPLACE PROCEDURE test_role_assignments()
BEGIN
  DECLARE test_passed BOOL DEFAULT TRUE;
  DECLARE test_details JSON;
  
  -- Check for users without proper role assignments
  SET test_details = (
    SELECT TO_JSON(STRUCT(
      COUNT(*) AS users_without_roles,
      ARRAY_AGG(user_id LIMIT 10) AS sample_users
    ))
    FROM `enterprise_knowledge_ai.user_interactions` ui
    LEFT JOIN `enterprise_knowledge_ai.user_roles` ur ON ui.user_id = ur.user_id
    WHERE ur.user_id IS NULL
    AND DATE(ui.interaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  );
  
  SET test_passed = JSON_VALUE(test_details, '$.users_without_roles') = '0';
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'access_control',
    'Role Assignment Validation',
    IF(test_passed, 'PASS', 'FAIL'),
    test_details,
    NOT test_passed,
    IF(test_passed, 'LOW', 'HIGH')
  );
END;

-- Test 2: Validate access control enforcement
CREATE OR REPLACE PROCEDURE test_access_control_enforcement()
BEGIN
  DECLARE unauthorized_access_count INT64;
  DECLARE test_details JSON;
  
  -- Check for unauthorized access attempts
  SET unauthorized_access_count = (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.user_interactions` ui
    JOIN `enterprise_knowledge_ai.generated_insights` gi ON ui.insight_id = gi.insight_id
    JOIN `enterprise_knowledge_ai.user_roles` ur ON ui.user_id = ur.user_id
    WHERE NOT EXISTS (
      SELECT 1 FROM UNNEST(gi.target_audience) AS audience
      WHERE audience IN UNNEST(ur.authorized_roles)
    )
    AND DATE(ui.interaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  );
  
  SET test_details = TO_JSON(STRUCT(
    unauthorized_access_count AS unauthorized_attempts,
    'Users accessed insights outside their authorized scope' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'access_control',
    'Access Control Enforcement',
    IF(unauthorized_access_count = 0, 'PASS', 'FAIL'),
    test_details,
    unauthorized_access_count > 0,
    IF(unauthorized_access_count = 0, 'LOW', 'CRITICAL')
  );
END;

-- Test 3: Validate data compartmentalization
CREATE OR REPLACE PROCEDURE test_data_compartmentalization()
BEGIN
  DECLARE cross_department_leaks INT64;
  DECLARE test_details JSON;
  
  -- Check for data leaks across department boundaries
  SET cross_department_leaks = (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.generated_insights` gi
    JOIN `enterprise_knowledge_ai.user_interactions` ui ON gi.insight_id = ui.insight_id
    JOIN `enterprise_knowledge_ai.user_roles` ur ON ui.user_id = ur.user_id
    WHERE JSON_VALUE(gi.metadata, '$.department') != ur.department
    AND JSON_VALUE(gi.metadata, '$.sensitivity_level') IN ('CONFIDENTIAL', 'RESTRICTED')
    AND DATE(ui.interaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  );
  
  SET test_details = TO_JSON(STRUCT(
    cross_department_leaks AS potential_leaks,
    'Sensitive data accessed across department boundaries' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'access_control',
    'Data Compartmentalization',
    IF(cross_department_leaks = 0, 'PASS', 'FAIL'),
    test_details,
    cross_department_leaks > 0,
    IF(cross_department_leaks = 0, 'LOW', 'HIGH')
  );
END;

-- =====================================================
-- Data Privacy and PII Protection Testing
-- =====================================================

-- Test 4: PII detection and masking validation
CREATE OR REPLACE PROCEDURE test_pii_protection()
BEGIN
  DECLARE pii_exposure_count INT64;
  DECLARE test_details JSON;
  
  -- Use AI to detect potential PII exposure in generated insights
  CREATE TEMP TABLE pii_scan_results AS
  SELECT 
    insight_id,
    content,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Does this text contain personally identifiable information (PII) ',
        'such as names, email addresses, phone numbers, or social security numbers? ',
        'Text: ', SUBSTR(content, 1, 1000)
      )
    ) AS contains_pii
  FROM `enterprise_knowledge_ai.generated_insights`
  WHERE DATE(created_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
  AND validation_status = 'validated';
  
  SET pii_exposure_count = (
    SELECT COUNT(*) FROM pii_scan_results WHERE contains_pii = TRUE
  );
  
  SET test_details = TO_JSON(STRUCT(
    pii_exposure_count AS insights_with_pii,
    'Generated insights containing potential PII' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'data_privacy',
    'PII Protection Validation',
    IF(pii_exposure_count = 0, 'PASS', 'FAIL'),
    test_details,
    pii_exposure_count > 0,
    IF(pii_exposure_count = 0, 'LOW', 'CRITICAL')
  );
END;

-- Test 5: Data retention policy compliance
CREATE OR REPLACE PROCEDURE test_data_retention_compliance()
BEGIN
  DECLARE expired_data_count INT64;
  DECLARE test_details JSON;
  
  -- Check for data that should have been purged based on retention policies
  SET expired_data_count = (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.enterprise_knowledge_base`
    WHERE DATE(created_timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 2555 DAY) -- 7 years
    AND JSON_VALUE(metadata, '$.retention_policy') = 'standard'
    UNION ALL
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.user_interactions`
    WHERE DATE(interaction_timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 1095 DAY) -- 3 years
  );
  
  SET test_details = TO_JSON(STRUCT(
    expired_data_count AS records_past_retention,
    'Data records that exceed retention policy limits' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'data_privacy',
    'Data Retention Compliance',
    IF(expired_data_count = 0, 'PASS', 'WARNING'),
    test_details,
    expired_data_count > 0,
    IF(expired_data_count = 0, 'LOW', 'MEDIUM')
  );
END;

-- Test 6: Encryption and data protection validation
CREATE OR REPLACE PROCEDURE test_encryption_compliance()
BEGIN
  DECLARE unencrypted_sensitive_data INT64;
  DECLARE test_details JSON;
  
  -- Check for sensitive data that should be encrypted
  SET unencrypted_sensitive_data = (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.enterprise_knowledge_base`
    WHERE JSON_VALUE(metadata, '$.sensitivity_level') IN ('CONFIDENTIAL', 'RESTRICTED')
    AND JSON_VALUE(metadata, '$.encryption_status') != 'encrypted'
    AND DATE(created_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  );
  
  SET test_details = TO_JSON(STRUCT(
    unencrypted_sensitive_data AS unencrypted_records,
    'Sensitive data records without proper encryption' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'data_privacy',
    'Encryption Compliance',
    IF(unencrypted_sensitive_data = 0, 'PASS', 'FAIL'),
    test_details,
    unencrypted_sensitive_data > 0,
    IF(unencrypted_sensitive_data = 0, 'LOW', 'HIGH')
  );
END;-- =========
============================================
-- Audit Trail Validation and Compliance Reporting
-- =====================================================

-- Test 7: Audit trail completeness validation
CREATE OR REPLACE PROCEDURE test_audit_trail_completeness()
BEGIN
  DECLARE missing_audit_records INT64;
  DECLARE test_details JSON;
  
  -- Check for user interactions without corresponding audit records
  SET missing_audit_records = (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.user_interactions` ui
    LEFT JOIN `enterprise_knowledge_ai.audit_trail` at 
      ON ui.interaction_id = at.interaction_id
    WHERE at.interaction_id IS NULL
    AND DATE(ui.interaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  );
  
  SET test_details = TO_JSON(STRUCT(
    missing_audit_records AS missing_records,
    'User interactions without audit trail entries' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'audit_trail',
    'Audit Trail Completeness',
    IF(missing_audit_records = 0, 'PASS', 'FAIL'),
    test_details,
    missing_audit_records > 0,
    IF(missing_audit_records = 0, 'LOW', 'HIGH')
  );
END;

-- Test 8: Audit trail integrity validation
CREATE OR REPLACE PROCEDURE test_audit_trail_integrity()
BEGIN
  DECLARE tampered_records INT64;
  DECLARE test_details JSON;
  
  -- Check for potential audit trail tampering using AI analysis
  CREATE TEMP TABLE audit_integrity_check AS
  SELECT 
    audit_id,
    audit_timestamp,
    LAG(audit_timestamp) OVER (ORDER BY audit_timestamp) AS prev_timestamp,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze this audit sequence for anomalies: ',
        'Current timestamp: ', CAST(audit_timestamp AS STRING),
        ', Previous timestamp: ', CAST(LAG(audit_timestamp) OVER (ORDER BY audit_timestamp) AS STRING),
        ', Action: ', action_type,
        '. Does this sequence suggest potential tampering or unusual patterns?'
      )
    ) AS potential_tampering
  FROM `enterprise_knowledge_ai.audit_trail`
  WHERE DATE(audit_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
  
  SET tampered_records = (
    SELECT COUNT(*) FROM audit_integrity_check WHERE potential_tampering = TRUE
  );
  
  SET test_details = TO_JSON(STRUCT(
    tampered_records AS suspicious_records,
    'Audit records with potential integrity issues' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'audit_trail',
    'Audit Trail Integrity',
    IF(tampered_records = 0, 'PASS', 'WARNING'),
    test_details,
    tampered_records > 0,
    IF(tampered_records = 0, 'LOW', 'MEDIUM')
  );
END;

-- Test 9: Compliance reporting validation
CREATE OR REPLACE PROCEDURE test_compliance_reporting()
BEGIN
  DECLARE compliance_gaps INT64;
  DECLARE test_details JSON;
  
  -- Check for compliance reporting gaps
  WITH compliance_requirements AS (
    SELECT 
      'GDPR' AS regulation,
      'data_processing_consent' AS requirement_type,
      30 AS max_days_without_report
    UNION ALL
    SELECT 'SOX', 'financial_data_access', 1
    UNION ALL
    SELECT 'HIPAA', 'healthcare_data_access', 7
    UNION ALL
    SELECT 'PCI_DSS', 'payment_data_access', 1
  ),
  recent_reports AS (
    SELECT 
      JSON_VALUE(metadata, '$.regulation') AS regulation,
      JSON_VALUE(metadata, '$.requirement_type') AS requirement_type,
      MAX(DATE(created_timestamp)) AS last_report_date
    FROM `enterprise_knowledge_ai.compliance_reports`
    WHERE DATE(created_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    GROUP BY 1, 2
  )
  SELECT COUNT(*) INTO compliance_gaps
  FROM compliance_requirements cr
  LEFT JOIN recent_reports rr 
    ON cr.regulation = rr.regulation 
    AND cr.requirement_type = rr.requirement_type
  WHERE rr.last_report_date IS NULL 
    OR DATE_DIFF(CURRENT_DATE(), rr.last_report_date, DAY) > cr.max_days_without_report;
  
  SET test_details = TO_JSON(STRUCT(
    compliance_gaps AS missing_reports,
    'Compliance requirements without recent reports' AS description
  ));
  
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'compliance',
    'Compliance Reporting Validation',
    IF(compliance_gaps = 0, 'PASS', 'FAIL'),
    test_details,
    compliance_gaps > 0,
    IF(compliance_gaps = 0, 'LOW', 'HIGH')
  );
END;

-- =====================================================
-- Master Security and Compliance Test Runner
-- =====================================================

CREATE OR REPLACE PROCEDURE run_security_compliance_tests()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE total_tests INT64 DEFAULT 9;
  DECLARE passed_tests INT64;
  DECLARE failed_tests INT64;
  DECLARE warning_tests INT64;
  
  -- Clear previous test results for today
  DELETE FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) = CURRENT_DATE();
  
  -- Execute all security and compliance tests
  CALL test_role_assignments();
  CALL test_access_control_enforcement();
  CALL test_data_compartmentalization();
  CALL test_pii_protection();
  CALL test_data_retention_compliance();
  CALL test_encryption_compliance();
  CALL test_audit_trail_completeness();
  CALL test_audit_trail_integrity();
  CALL test_compliance_reporting();
  
  -- Calculate test summary statistics
  SELECT 
    COUNTIF(test_status = 'PASS') AS passed,
    COUNTIF(test_status = 'FAIL') AS failed,
    COUNTIF(test_status = 'WARNING') AS warnings
  INTO passed_tests, failed_tests, warning_tests
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) = CURRENT_DATE();
  
  -- Insert summary record
  INSERT INTO `enterprise_knowledge_ai.security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, severity_level)
  VALUES (
    GENERATE_UUID(),
    'compliance',
    'Security Compliance Test Suite Summary',
    IF(failed_tests = 0, 'PASS', 'FAIL'),
    TO_JSON(STRUCT(
      total_tests,
      passed_tests,
      failed_tests,
      warning_tests,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, SECOND) AS execution_time_seconds
    )),
    failed_tests > 0,
    IF(failed_tests = 0, 'LOW', 'HIGH')
  );
  
  -- Generate compliance report
  CALL generate_compliance_report();
END;

-- =====================================================
-- Compliance Report Generation
-- =====================================================

CREATE OR REPLACE PROCEDURE generate_compliance_report()
BEGIN
  DECLARE report_content STRING;
  
  -- Generate comprehensive compliance report using AI
  SET report_content = (
    SELECT AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Generate a comprehensive security and compliance report based on these test results: ',
        (SELECT STRING_AGG(
          CONCAT(
            'Test: ', test_name, 
            ', Status: ', test_status,
            ', Details: ', CAST(test_details AS STRING),
            ', Severity: ', severity_level
          ), '\n'
        )
        FROM `enterprise_knowledge_ai.security_test_results`
        WHERE DATE(execution_timestamp) = CURRENT_DATE()
        AND test_name != 'Security Compliance Test Suite Summary'),
        '\n\nPlease provide:\n',
        '1. Executive summary of security posture\n',
        '2. Critical issues requiring immediate attention\n',
        '3. Compliance status for major regulations (GDPR, SOX, HIPAA, PCI-DSS)\n',
        '4. Recommended remediation actions\n',
        '5. Risk assessment and mitigation strategies'
      )
    )
  );
  
  -- Store the compliance report
  INSERT INTO `enterprise_knowledge_ai.compliance_reports`
  (report_id, report_type, content, created_timestamp, metadata)
  VALUES (
    GENERATE_UUID(),
    'security_compliance_assessment',
    report_content,
    CURRENT_TIMESTAMP(),
    TO_JSON(STRUCT(
      'automated' AS generation_method,
      'daily' AS frequency,
      CURRENT_DATE() AS report_date
    ))
  );
END;

-- =====================================================
-- Security Monitoring and Alerting
-- =====================================================

CREATE OR REPLACE PROCEDURE monitor_security_violations()
BEGIN
  DECLARE critical_violations INT64;
  DECLARE high_violations INT64;
  
  -- Count critical and high severity violations
  SELECT 
    COUNTIF(severity_level = 'CRITICAL' AND test_status = 'FAIL'),
    COUNTIF(severity_level = 'HIGH' AND test_status = 'FAIL')
  INTO critical_violations, high_violations
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) = CURRENT_DATE();
  
  -- Generate alerts for critical violations
  IF critical_violations > 0 THEN
    INSERT INTO `enterprise_knowledge_ai.security_alerts`
    (alert_id, alert_type, severity, message, created_timestamp, requires_immediate_action)
    VALUES (
      GENERATE_UUID(),
      'CRITICAL_SECURITY_VIOLATION',
      'CRITICAL',
      CONCAT('Critical security violations detected: ', CAST(critical_violations AS STRING), ' failures'),
      CURRENT_TIMESTAMP(),
      TRUE
    );
  END IF;
  
  -- Generate alerts for high severity violations
  IF high_violations > 0 THEN
    INSERT INTO `enterprise_knowledge_ai.security_alerts`
    (alert_id, alert_type, severity, message, created_timestamp, requires_immediate_action)
    VALUES (
      GENERATE_UUID(),
      'HIGH_SECURITY_VIOLATION',
      'HIGH',
      CONCAT('High severity security violations detected: ', CAST(high_violations AS STRING), ' failures'),
      CURRENT_TIMESTAMP(),
      TRUE
    );
  END IF;
END;

-- =====================================================
-- Automated Remediation Suggestions
-- =====================================================

CREATE OR REPLACE PROCEDURE generate_remediation_suggestions()
BEGIN
  -- Generate AI-powered remediation suggestions for failed tests
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.remediation_suggestions` AS
  SELECT 
    test_id,
    test_name,
    test_category,
    severity_level,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Provide specific remediation steps for this security test failure: ',
        'Test: ', test_name,
        ', Category: ', test_category,
        ', Details: ', CAST(test_details AS STRING),
        ', Severity: ', severity_level,
        '\n\nPlease provide:\n',
        '1. Root cause analysis\n',
        '2. Step-by-step remediation instructions\n',
        '3. Prevention strategies\n',
        '4. Estimated time to resolve\n',
        '5. Required resources and permissions'
      )
    ) AS remediation_plan,
    CURRENT_TIMESTAMP() AS generated_timestamp
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE test_status = 'FAIL'
  AND remediation_required = TRUE
  AND DATE(execution_timestamp) = CURRENT_DATE();
END;