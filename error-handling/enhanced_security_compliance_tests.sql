-- =====================================================
-- ENHANCED SECURITY AND COMPLIANCE TESTING FRAMEWORK
-- Comprehensive role-based access control, data privacy, and audit trail validation
-- =====================================================

-- Enhanced security test results table with additional tracking
CREATE OR REPLACE TABLE `enterprise_ai.enhanced_security_test_results` (
  test_id STRING NOT NULL,
  test_category ENUM('access_control', 'data_privacy', 'audit_trail', 'compliance', 'penetration', 'vulnerability'),
  test_name STRING NOT NULL,
  test_status ENUM('PASS', 'FAIL', 'WARNING', 'SKIP'),
  test_details JSON,
  execution_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  remediation_required BOOL,
  severity_level ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'),
  compliance_frameworks ARRAY<STRING>, -- GDPR, SOX, HIPAA, PCI-DSS, etc.
  test_duration_ms INT64,
  automated BOOL DEFAULT TRUE,
  test_evidence JSON,
  risk_score FLOAT64
) PARTITION BY DATE(execution_timestamp)
CLUSTER BY test_category, severity_level;

-- =====================================================
-- ENHANCED ROLE-BASED ACCESS CONTROL TESTS
-- =====================================================

-- Test 1: Comprehensive Role Assignment Validation
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_comprehensive_role_validation`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_passed BOOL DEFAULT TRUE;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64 DEFAULT 0.0;
  
  -- Check for multiple security violations in role assignments
  WITH role_violations AS (
    -- Users without roles
    SELECT 
      'missing_roles' as violation_type,
      COUNT(*) as violation_count,
      ARRAY_AGG(ui.user_id LIMIT 10) as affected_users
    FROM `enterprise_ai.user_interactions` ui
    LEFT JOIN `enterprise_ai.user_roles` ur ON ui.user_id = ur.user_id
    WHERE ur.user_id IS NULL
    AND DATE(ui.interaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    
    UNION ALL
    
    -- Users with expired role assignments
    SELECT 
      'expired_roles' as violation_type,
      COUNT(*) as violation_count,
      ARRAY_AGG(ur.user_id LIMIT 10) as affected_users
    FROM `enterprise_ai.user_roles` ur
    WHERE DATE(ur.last_updated) < DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    
    UNION ALL
    
    -- Users with excessive privileges (more than 3 authorized roles)
    SELECT 
      'excessive_privileges' as violation_type,
      COUNT(*) as violation_count,
      ARRAY_AGG(ur.user_id LIMIT 10) as affected_users
    FROM `enterprise_ai.user_roles` ur
    WHERE ARRAY_LENGTH(ur.authorized_roles) > 3
    
    UNION ALL
    
    -- Users with conflicting role assignments
    SELECT 
      'conflicting_roles' as violation_type,
      COUNT(*) as violation_count,
      ARRAY_AGG(ur.user_id LIMIT 10) as affected_users
    FROM `enterprise_ai.user_roles` ur
    WHERE 'viewer' IN UNNEST(ur.authorized_roles) 
    AND 'executive' IN UNNEST(ur.authorized_roles)
  )
  SELECT TO_JSON(STRUCT(
    ARRAY_AGG(STRUCT(violation_type, violation_count, affected_users)) as violations,
    SUM(violation_count) as total_violations
  )) INTO test_details
  FROM role_violations;
  
  -- Calculate risk score based on violations
  SET risk_score = (
    SELECT COALESCE(SUM(
      CASE violation_type
        WHEN 'missing_roles' THEN violation_count * 0.8
        WHEN 'expired_roles' THEN violation_count * 0.6
        WHEN 'excessive_privileges' THEN violation_count * 0.9
        WHEN 'conflicting_roles' THEN violation_count * 0.7
        ELSE 0
      END
    ), 0)
    FROM UNNEST(JSON_EXTRACT_ARRAY(test_details, '$.violations')) as violation
  );
  
  SET test_passed = JSON_VALUE(test_details, '$.total_violations') = '0';
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'access_control',
    'Comprehensive Role Assignment Validation',
    IF(test_passed, 'PASS', 'FAIL'),
    test_details,
    NOT test_passed,
    CASE 
      WHEN risk_score >= 10 THEN 'CRITICAL'
      WHEN risk_score >= 5 THEN 'HIGH'
      WHEN risk_score >= 2 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['SOX', 'GDPR', 'HIPAA'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    risk_score,
    TO_JSON(STRUCT(
      'role_assignment_analysis' as evidence_type,
      CURRENT_TIMESTAMP() as collection_timestamp,
      'automated_scan' as collection_method
    ))
  );
END;

-- Test 2: Advanced Access Pattern Analysis
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_access_pattern_analysis`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE anomalous_patterns INT64;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64;
  
  -- Analyze access patterns using AI for anomaly detection
  CREATE TEMP TABLE access_pattern_analysis AS
  WITH user_access_patterns AS (
    SELECT 
      ui.user_id,
      ur.department,
      ur.security_clearance,
      COUNT(*) as total_accesses,
      COUNT(DISTINCT gi.insight_id) as unique_insights_accessed,
      COUNT(DISTINCT DATE(ui.interaction_timestamp)) as active_days,
      ARRAY_AGG(DISTINCT JSON_VALUE(gi.metadata, '$.sensitivity_level') IGNORE NULLS) as accessed_sensitivity_levels,
      ARRAY_AGG(DISTINCT JSON_VALUE(gi.metadata, '$.department') IGNORE NULLS) as accessed_departments,
      AVG(TIMESTAMP_DIFF(ui.interaction_timestamp, LAG(ui.interaction_timestamp) OVER (PARTITION BY ui.user_id ORDER BY ui.interaction_timestamp), MINUTE)) as avg_access_interval_minutes
    FROM `enterprise_ai.user_interactions` ui
    JOIN `enterprise_ai.user_roles` ur ON ui.user_id = ur.user_id
    LEFT JOIN `enterprise_ai.generated_insights` gi ON ui.insight_id = gi.insight_id
    WHERE DATE(ui.interaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    GROUP BY 1, 2, 3
  ),
  anomaly_detection AS (
    SELECT 
      user_id,
      department,
      security_clearance,
      total_accesses,
      AI.GENERATE_BOOL(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Analyze this user access pattern for anomalies: ',
          'User department: ', department,
          ', Security clearance: ', security_clearance,
          ', Total accesses: ', CAST(total_accesses AS STRING),
          ', Unique insights: ', CAST(unique_insights_accessed AS STRING),
          ', Active days: ', CAST(active_days AS STRING),
          ', Accessed sensitivity levels: ', ARRAY_TO_STRING(accessed_sensitivity_levels, ', '),
          ', Accessed departments: ', ARRAY_TO_STRING(accessed_departments, ', '),
          ', Average access interval: ', CAST(COALESCE(avg_access_interval_minutes, 0) AS STRING), ' minutes',
          '. Does this pattern suggest potential security concerns, unauthorized access, or insider threats?'
        )
      ) as is_anomalous,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Explain the security risk assessment for this access pattern: ',
          'Department: ', department, ', Clearance: ', security_clearance,
          ', Pattern details: ', CAST(total_accesses AS STRING), ' accesses across ',
          CAST(active_days AS STRING), ' days. Provide risk level and reasoning.'
        )
      ) as risk_assessment
    FROM user_access_patterns
  )
  SELECT * FROM anomaly_detection;
  
  -- Count anomalous patterns
  SET anomalous_patterns = (
    SELECT COUNT(*) FROM access_pattern_analysis WHERE is_anomalous = TRUE
  );
  
  -- Calculate risk score
  SET risk_score = anomalous_patterns * 2.5;
  
  -- Collect detailed analysis
  SET test_details = (
    SELECT TO_JSON(STRUCT(
      anomalous_patterns as anomalous_users,
      (SELECT COUNT(*) FROM access_pattern_analysis) as total_users_analyzed,
      ARRAY_AGG(
        STRUCT(user_id, department, security_clearance, risk_assessment)
        LIMIT 10
      ) as sample_anomalies
    ))
    FROM access_pattern_analysis
    WHERE is_anomalous = TRUE
  );
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'access_control',
    'Advanced Access Pattern Analysis',
    IF(anomalous_patterns = 0, 'PASS', IF(anomalous_patterns < 5, 'WARNING', 'FAIL')),
    test_details,
    anomalous_patterns > 0,
    CASE 
      WHEN anomalous_patterns >= 10 THEN 'CRITICAL'
      WHEN anomalous_patterns >= 5 THEN 'HIGH'
      WHEN anomalous_patterns >= 2 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['SOX', 'GDPR', 'HIPAA', 'PCI_DSS'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    risk_score,
    TO_JSON(STRUCT(
      'ai_powered_behavioral_analysis' as evidence_type,
      anomalous_patterns as anomaly_count,
      'machine_learning_detection' as detection_method
    ))
  );
END;

-- =====================================================
-- ENHANCED DATA PRIVACY AND PII PROTECTION TESTS
-- =====================================================

-- Test 3: Comprehensive PII Detection and Classification
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_comprehensive_pii_detection`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE pii_violations INT64;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64;
  
  -- Advanced PII detection across all content types
  CREATE TEMP TABLE comprehensive_pii_scan AS
  WITH content_analysis AS (
    -- Scan generated insights
    SELECT 
      'generated_insights' as content_type,
      insight_id as content_id,
      content,
      JSON_VALUE(metadata, '$.sensitivity_level') as declared_sensitivity,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Perform comprehensive PII detection on this text. Identify and classify any: ',
          '1. Names (first, last, full names) ',
          '2. Email addresses ',
          '3. Phone numbers ',
          '4. Social Security Numbers ',
          '5. Credit card numbers ',
          '6. Addresses (street, city, postal codes) ',
          '7. Date of birth ',
          '8. Government ID numbers ',
          '9. Medical record numbers ',
          '10. Financial account numbers ',
          'Text to analyze: ', SUBSTR(content, 1, 2000),
          '. Return JSON with detected PII types and confidence levels.'
        )
      ) as pii_analysis
    FROM `enterprise_ai.generated_insights`
    WHERE DATE(created_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    
    UNION ALL
    
    -- Scan knowledge base documents
    SELECT 
      'knowledge_base' as content_type,
      knowledge_id as content_id,
      content,
      JSON_VALUE(metadata, '$.sensitivity_level') as declared_sensitivity,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Detect PII in this document content: ', SUBSTR(content, 1, 2000),
          '. Focus on personally identifiable information that could violate privacy regulations.'
        )
      ) as pii_analysis
    FROM `enterprise_ai.enterprise_knowledge_base`
    WHERE DATE(created_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    LIMIT 100 -- Limit for performance
  ),
  pii_violations_detected AS (
    SELECT 
      content_type,
      content_id,
      declared_sensitivity,
      pii_analysis,
      AI.GENERATE_BOOL(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Based on this PII analysis: ', pii_analysis,
          ', and declared sensitivity level: ', COALESCE(declared_sensitivity, 'NONE'),
          ', is there a privacy violation? Consider: ',
          '1. PII present but not properly classified ',
          '2. High-risk PII in low-security content ',
          '3. Unmasked sensitive identifiers ',
          '4. GDPR/CCPA compliance violations'
        )
      ) as has_violation,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Rate the privacy risk of this content on a scale of 0-10: ',
          pii_analysis, '. Consider severity and potential impact.'
        )
      ) as privacy_risk_score
    FROM content_analysis
  )
  SELECT * FROM pii_violations_detected;
  
  -- Count violations and calculate risk
  SELECT 
    COUNT(*) as violations,
    AVG(privacy_risk_score) as avg_risk_score
  INTO pii_violations, risk_score
  FROM comprehensive_pii_scan
  WHERE has_violation = TRUE;
  
  -- Collect detailed results
  SET test_details = (
    SELECT TO_JSON(STRUCT(
      pii_violations as total_violations,
      (SELECT COUNT(*) FROM comprehensive_pii_scan) as total_content_scanned,
      ROUND(risk_score, 2) as average_risk_score,
      ARRAY_AGG(
        STRUCT(content_type, content_id, declared_sensitivity, privacy_risk_score)
        ORDER BY privacy_risk_score DESC
        LIMIT 10
      ) as highest_risk_content
    ))
    FROM comprehensive_pii_scan
    WHERE has_violation = TRUE
  );
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'data_privacy',
    'Comprehensive PII Detection and Classification',
    IF(pii_violations = 0, 'PASS', IF(pii_violations < 5, 'WARNING', 'FAIL')),
    test_details,
    pii_violations > 0,
    CASE 
      WHEN risk_score >= 8 THEN 'CRITICAL'
      WHEN risk_score >= 6 THEN 'HIGH'
      WHEN risk_score >= 4 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['GDPR', 'CCPA', 'HIPAA', 'PIPEDA'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    risk_score,
    TO_JSON(STRUCT(
      'ai_powered_pii_detection' as evidence_type,
      pii_violations as violation_count,
      'comprehensive_content_scan' as scan_scope
    ))
  );
END;-- T
est 4: Data Governance and Classification Validation
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_data_governance_compliance`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE governance_violations INT64;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64;
  
  -- Check data governance compliance
  WITH governance_analysis AS (
    -- Check for unclassified sensitive data
    SELECT 
      'unclassified_data' as violation_type,
      COUNT(*) as violation_count
    FROM `enterprise_ai.enterprise_knowledge_base` ekb
    LEFT JOIN `enterprise_ai.data_classification` dc ON ekb.knowledge_id = dc.resource_id
    WHERE dc.resource_id IS NULL
    AND (
      REGEXP_CONTAINS(UPPER(ekb.content), r'\b(SSN|SOCIAL SECURITY|CREDIT CARD|BANK ACCOUNT)\b')
      OR REGEXP_CONTAINS(ekb.content, r'\b\d{3}-\d{2}-\d{4}\b') -- SSN pattern
      OR REGEXP_CONTAINS(ekb.content, r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b') -- Credit card pattern
    )
    
    UNION ALL
    
    -- Check for misclassified data
    SELECT 
      'misclassified_data' as violation_type,
      COUNT(*) as violation_count
    FROM `enterprise_ai.data_classification` dc
    JOIN `enterprise_ai.enterprise_knowledge_base` ekb ON dc.resource_id = ekb.knowledge_id
    WHERE dc.sensitivity_level = 'PUBLIC'
    AND (
      REGEXP_CONTAINS(UPPER(ekb.content), r'\b(CONFIDENTIAL|RESTRICTED|PROPRIETARY)\b')
      OR 'PII' IN UNNEST(dc.data_categories)
    )
    
    UNION ALL
    
    -- Check for expired classifications
    SELECT 
      'expired_classifications' as violation_type,
      COUNT(*) as violation_count
    FROM `enterprise_ai.data_classification`
    WHERE review_date < CURRENT_DATE()
    
    UNION ALL
    
    -- Check for missing encryption on sensitive data
    SELECT 
      'unencrypted_sensitive_data' as violation_type,
      COUNT(*) as violation_count
    FROM `enterprise_ai.data_classification` dc
    JOIN `enterprise_ai.enterprise_knowledge_base` ekb ON dc.resource_id = ekb.knowledge_id
    WHERE dc.sensitivity_level IN ('CONFIDENTIAL', 'RESTRICTED')
    AND (dc.encryption_required = FALSE OR JSON_VALUE(ekb.metadata, '$.encryption_status') != 'encrypted')
  )
  SELECT 
    SUM(violation_count) as total_violations,
    TO_JSON(ARRAY_AGG(STRUCT(violation_type, violation_count))) as violation_details
  INTO governance_violations, test_details
  FROM governance_analysis;
  
  SET risk_score = governance_violations * 1.5;
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'data_privacy',
    'Data Governance and Classification Validation',
    IF(governance_violations = 0, 'PASS', 'FAIL'),
    test_details,
    governance_violations > 0,
    CASE 
      WHEN governance_violations >= 20 THEN 'CRITICAL'
      WHEN governance_violations >= 10 THEN 'HIGH'
      WHEN governance_violations >= 5 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['GDPR', 'SOX', 'HIPAA', 'ISO27001'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    risk_score,
    TO_JSON(STRUCT(
      'data_governance_audit' as evidence_type,
      governance_violations as total_violations,
      'automated_classification_check' as audit_method
    ))
  );
END;

-- =====================================================
-- ENHANCED AUDIT TRAIL VALIDATION TESTS
-- =====================================================

-- Test 5: Comprehensive Audit Trail Integrity Validation
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_comprehensive_audit_integrity`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE integrity_issues INT64;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64;
  
  -- Comprehensive audit trail integrity analysis
  WITH audit_integrity_analysis AS (
    -- Check for missing audit records
    SELECT 
      'missing_audit_records' as issue_type,
      COUNT(*) as issue_count,
      'User interactions without corresponding audit entries' as description
    FROM `enterprise_ai.user_interactions` ui
    LEFT JOIN `enterprise_ai.audit_trail` at ON ui.interaction_id = at.interaction_id
    WHERE at.interaction_id IS NULL
    AND DATE(ui.interaction_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    
    UNION ALL
    
    -- Check for audit record gaps (time-based analysis)
    SELECT 
      'temporal_gaps' as issue_type,
      COUNT(*) as issue_count,
      'Suspicious gaps in audit trail timeline' as description
    FROM (
      SELECT 
        audit_id,
        audit_timestamp,
        LAG(audit_timestamp) OVER (PARTITION BY user_id ORDER BY audit_timestamp) as prev_timestamp,
        TIMESTAMP_DIFF(
          audit_timestamp, 
          LAG(audit_timestamp) OVER (PARTITION BY user_id ORDER BY audit_timestamp), 
          MINUTE
        ) as time_gap_minutes
      FROM `enterprise_ai.audit_trail`
      WHERE DATE(audit_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    )
    WHERE time_gap_minutes > 480 -- 8 hours gap during business hours
    
    UNION ALL
    
    -- Check for duplicate audit records
    SELECT 
      'duplicate_records' as issue_type,
      COUNT(*) - COUNT(DISTINCT CONCAT(user_id, interaction_id, action_type, CAST(audit_timestamp AS STRING))) as issue_count,
      'Duplicate audit entries detected' as description
    FROM `enterprise_ai.audit_trail`
    WHERE DATE(audit_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    
    UNION ALL
    
    -- Check for failed actions without proper logging
    SELECT 
      'incomplete_failure_logging' as issue_type,
      COUNT(*) as issue_count,
      'Failed actions without detailed failure reasons' as description
    FROM `enterprise_ai.audit_trail`
    WHERE success = FALSE
    AND (failure_reason IS NULL OR LENGTH(failure_reason) < 10)
    AND DATE(audit_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    
    UNION ALL
    
    -- Check for suspicious activity patterns using AI
    SELECT 
      'suspicious_patterns' as issue_type,
      COUNT(*) as issue_count,
      'AI-detected suspicious audit patterns' as description
    FROM (
      SELECT 
        user_id,
        COUNT(*) as action_count,
        COUNT(DISTINCT action_type) as unique_actions,
        COUNT(DISTINCT resource_id) as unique_resources,
        AI.GENERATE_BOOL(
          MODEL `enterprise_ai.gemini_model`,
          CONCAT(
            'Analyze this user activity pattern for suspicious behavior: ',
            'User performed ', CAST(COUNT(*) AS STRING), ' actions ',
            'across ', CAST(COUNT(DISTINCT action_type) AS STRING), ' different action types ',
            'on ', CAST(COUNT(DISTINCT resource_id) AS STRING), ' different resources ',
            'in the last 24 hours. Actions include: ',
            STRING_AGG(DISTINCT action_type, ', '),
            '. Is this pattern suspicious or indicative of potential security threats?'
          )
        ) as is_suspicious
      FROM `enterprise_ai.audit_trail`
      WHERE DATE(audit_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
      GROUP BY user_id
      HAVING COUNT(*) > 100 -- High activity threshold
    )
    WHERE is_suspicious = TRUE
  )
  SELECT 
    SUM(issue_count) as total_issues,
    TO_JSON(ARRAY_AGG(STRUCT(issue_type, issue_count, description))) as issue_details
  INTO integrity_issues, test_details
  FROM audit_integrity_analysis;
  
  SET risk_score = integrity_issues * 2.0;
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'audit_trail',
    'Comprehensive Audit Trail Integrity Validation',
    IF(integrity_issues = 0, 'PASS', IF(integrity_issues < 10, 'WARNING', 'FAIL')),
    test_details,
    integrity_issues > 0,
    CASE 
      WHEN integrity_issues >= 50 THEN 'CRITICAL'
      WHEN integrity_issues >= 20 THEN 'HIGH'
      WHEN integrity_issues >= 10 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['SOX', 'GDPR', 'HIPAA', 'PCI_DSS', 'ISO27001'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    risk_score,
    TO_JSON(STRUCT(
      'comprehensive_audit_analysis' as evidence_type,
      integrity_issues as total_issues,
      'ai_powered_pattern_detection' as analysis_method
    ))
  );
END;

-- Test 6: Audit Trail Forensic Analysis
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_audit_forensic_analysis`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE forensic_alerts INT64;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64;
  
  -- Advanced forensic analysis of audit trails
  CREATE TEMP TABLE forensic_analysis AS
  WITH user_behavior_analysis AS (
    SELECT 
      user_id,
      DATE(audit_timestamp) as activity_date,
      COUNT(*) as daily_actions,
      COUNT(DISTINCT action_type) as action_variety,
      COUNT(DISTINCT resource_id) as resource_variety,
      COUNT(DISTINCT ip_address) as ip_variety,
      MIN(audit_timestamp) as first_action,
      MAX(audit_timestamp) as last_action,
      TIMESTAMP_DIFF(MAX(audit_timestamp), MIN(audit_timestamp), HOUR) as session_duration_hours,
      COUNTIF(NOT success) as failed_actions,
      ARRAY_AGG(DISTINCT action_type ORDER BY action_type) as action_types,
      ARRAY_AGG(DISTINCT ip_address ORDER BY ip_address) as ip_addresses
    FROM `enterprise_ai.audit_trail`
    WHERE DATE(audit_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    GROUP BY 1, 2
  ),
  anomaly_detection AS (
    SELECT 
      user_id,
      activity_date,
      daily_actions,
      session_duration_hours,
      failed_actions,
      AI.GENERATE_BOOL(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Analyze this user behavior for security anomalies: ',
          'User performed ', CAST(daily_actions AS STRING), ' actions ',
          'over ', CAST(session_duration_hours AS STRING), ' hours ',
          'with ', CAST(failed_actions AS STRING), ' failures. ',
          'Action types: ', ARRAY_TO_STRING(action_types, ', '), '. ',
          'IP addresses: ', ARRAY_TO_STRING(ip_addresses, ', '), '. ',
          'Is this behavior anomalous or potentially malicious?'
        )
      ) as is_anomalous,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Provide forensic analysis of this user activity: ',
          CAST(daily_actions AS STRING), ' actions, ',
          CAST(session_duration_hours AS STRING), ' hour session, ',
          CAST(ip_variety AS STRING), ' different IPs. ',
          'Assess security risk and potential threat indicators.'
        )
      ) as forensic_assessment,
      CASE 
        WHEN daily_actions > 500 THEN 3
        WHEN session_duration_hours > 12 THEN 2
        WHEN failed_actions > 20 THEN 2
        WHEN ip_variety > 3 THEN 2
        ELSE 1
      END as risk_multiplier
    FROM user_behavior_analysis
  )
  SELECT * FROM anomaly_detection;
  
  -- Count forensic alerts
  SET forensic_alerts = (
    SELECT COUNT(*) FROM forensic_analysis WHERE is_anomalous = TRUE
  );
  
  -- Calculate risk score
  SET risk_score = (
    SELECT SUM(risk_multiplier) FROM forensic_analysis WHERE is_anomalous = TRUE
  );
  
  -- Collect detailed results
  SET test_details = (
    SELECT TO_JSON(STRUCT(
      forensic_alerts as anomalous_behaviors,
      (SELECT COUNT(*) FROM forensic_analysis) as total_user_sessions_analyzed,
      ROUND(risk_score, 2) as total_risk_score,
      ARRAY_AGG(
        STRUCT(user_id, activity_date, daily_actions, session_duration_hours, forensic_assessment)
        ORDER BY risk_multiplier DESC
        LIMIT 5
      ) as highest_risk_sessions
    ))
    FROM forensic_analysis
    WHERE is_anomalous = TRUE
  );
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'audit_trail',
    'Audit Trail Forensic Analysis',
    IF(forensic_alerts = 0, 'PASS', IF(forensic_alerts < 3, 'WARNING', 'FAIL')),
    test_details,
    forensic_alerts > 0,
    CASE 
      WHEN risk_score >= 15 THEN 'CRITICAL'
      WHEN risk_score >= 10 THEN 'HIGH'
      WHEN risk_score >= 5 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['SOX', 'GDPR', 'HIPAA', 'PCI_DSS'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    COALESCE(risk_score, 0),
    TO_JSON(STRUCT(
      'forensic_behavioral_analysis' as evidence_type,
      forensic_alerts as alert_count,
      'ai_powered_threat_detection' as detection_method
    ))
  );
END;

-- =====================================================
-- ENHANCED COMPLIANCE REPORTING TESTS
-- =====================================================

-- Test 7: Multi-Framework Compliance Validation
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_multi_framework_compliance`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE compliance_gaps INT64;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64;
  
  -- Comprehensive compliance framework analysis
  WITH compliance_requirements AS (
    SELECT 'GDPR' as framework, 'data_processing_consent' as requirement, 'CRITICAL' as priority, 1 as max_days_gap
    UNION ALL SELECT 'GDPR', 'right_to_be_forgotten', 'HIGH', 30
    UNION ALL SELECT 'GDPR', 'data_breach_notification', 'CRITICAL', 3
    UNION ALL SELECT 'GDPR', 'privacy_impact_assessment', 'MEDIUM', 90
    UNION ALL SELECT 'SOX', 'financial_data_access_control', 'CRITICAL', 1
    UNION ALL SELECT 'SOX', 'change_management_audit', 'HIGH', 7
    UNION ALL SELECT 'SOX', 'segregation_of_duties', 'CRITICAL', 1
    UNION ALL SELECT 'HIPAA', 'healthcare_data_encryption', 'CRITICAL', 1
    UNION ALL SELECT 'HIPAA', 'access_control_validation', 'HIGH', 7
    UNION ALL SELECT 'HIPAA', 'audit_trail_completeness', 'HIGH', 1
    UNION ALL SELECT 'PCI_DSS', 'payment_data_protection', 'CRITICAL', 1
    UNION ALL SELECT 'PCI_DSS', 'network_security_testing', 'HIGH', 30
    UNION ALL SELECT 'ISO27001', 'information_security_policy', 'MEDIUM', 90
    UNION ALL SELECT 'ISO27001', 'risk_assessment', 'HIGH', 30
  ),
  compliance_status AS (
    SELECT 
      cr.framework,
      cr.requirement,
      cr.priority,
      cr.max_days_gap,
      COALESCE(MAX(DATE(cp.created_timestamp)), DATE('1900-01-01')) as last_evidence_date,
      DATE_DIFF(CURRENT_DATE(), COALESCE(MAX(DATE(cp.created_timestamp)), DATE('1900-01-01')), DAY) as days_since_evidence,
      COUNT(cp.report_id) as evidence_count
    FROM compliance_requirements cr
    LEFT JOIN `enterprise_ai.compliance_reports` cp 
      ON cr.framework = JSON_VALUE(cp.metadata, '$.framework')
      AND cr.requirement = JSON_VALUE(cp.metadata, '$.requirement_type')
      AND DATE(cp.created_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
    GROUP BY 1, 2, 3, 4
  ),
  compliance_gaps AS (
    SELECT 
      framework,
      requirement,
      priority,
      days_since_evidence,
      max_days_gap,
      CASE 
        WHEN days_since_evidence > max_days_gap THEN TRUE
        WHEN evidence_count = 0 THEN TRUE
        ELSE FALSE
      END as has_gap,
      CASE priority
        WHEN 'CRITICAL' THEN 5
        WHEN 'HIGH' THEN 3
        WHEN 'MEDIUM' THEN 2
        ELSE 1
      END as gap_weight
    FROM compliance_status
  )
  SELECT 
    COUNT(*) as total_gaps,
    SUM(gap_weight) as weighted_risk_score,
    TO_JSON(STRUCT(
      COUNTIF(priority = 'CRITICAL' AND has_gap) as critical_gaps,
      COUNTIF(priority = 'HIGH' AND has_gap) as high_gaps,
      COUNTIF(priority = 'MEDIUM' AND has_gap) as medium_gaps,
      ARRAY_AGG(
        STRUCT(framework, requirement, priority, days_since_evidence)
        ORDER BY gap_weight DESC, days_since_evidence DESC
        LIMIT 10
      ) as top_compliance_gaps
    )) as gap_details
  INTO compliance_gaps, risk_score, test_details
  FROM compliance_gaps
  WHERE has_gap = TRUE;
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'compliance',
    'Multi-Framework Compliance Validation',
    IF(compliance_gaps = 0, 'PASS', 'FAIL'),
    test_details,
    compliance_gaps > 0,
    CASE 
      WHEN risk_score >= 20 THEN 'CRITICAL'
      WHEN risk_score >= 10 THEN 'HIGH'
      WHEN risk_score >= 5 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['GDPR', 'SOX', 'HIPAA', 'PCI_DSS', 'ISO27001'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    risk_score,
    TO_JSON(STRUCT(
      'multi_framework_compliance_audit' as evidence_type,
      compliance_gaps as total_gaps,
      'comprehensive_regulatory_assessment' as audit_scope
    ))
  );
END;-
- Test 8: Automated Compliance Report Generation and Validation
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_compliance_report_generation`()
BEGIN
  DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE report_issues INT64;
  DECLARE test_details JSON;
  DECLARE risk_score FLOAT64;
  
  -- Generate comprehensive compliance report using AI
  DECLARE compliance_report_content STRING;
  
  SET compliance_report_content = (
    SELECT AI.GENERATE(
      MODEL `enterprise_ai.gemini_model`,
      CONCAT(
        'Generate a comprehensive enterprise security and compliance report based on these test results from the last 24 hours: ',
        (SELECT STRING_AGG(
          CONCAT(
            'Test: ', test_name, 
            ', Category: ', test_category,
            ', Status: ', test_status,
            ', Severity: ', severity_level,
            ', Risk Score: ', CAST(risk_score AS STRING),
            ', Frameworks: ', ARRAY_TO_STRING(compliance_frameworks, ', '),
            ', Details: ', CAST(test_details AS STRING)
          ), '\n'
        )
        FROM `enterprise_ai.enhanced_security_test_results`
        WHERE DATE(execution_timestamp) = CURRENT_DATE()
        AND test_name != 'Enhanced Security Compliance Test Suite Summary'),
        '\n\nReport Requirements:\n',
        '1. Executive Summary with overall security posture assessment\n',
        '2. Critical findings requiring immediate attention\n',
        '3. Compliance status for each framework (GDPR, SOX, HIPAA, PCI-DSS, ISO27001)\n',
        '4. Risk assessment with quantified risk scores\n',
        '5. Detailed remediation roadmap with priorities and timelines\n',
        '6. Trend analysis and recommendations for security improvements\n',
        '7. Regulatory compliance gaps and mitigation strategies\n',
        '8. Data privacy and protection status assessment'
      )
    )
  );
  
  -- Validate report quality and completeness
  CREATE TEMP TABLE report_validation AS
  SELECT 
    AI.GENERATE_BOOL(
      MODEL `enterprise_ai.gemini_model`,
      CONCAT(
        'Evaluate this compliance report for completeness and quality: ',
        SUBSTR(compliance_report_content, 1, 3000),
        '. Does it adequately address: executive summary, critical findings, ',
        'compliance status, risk assessment, remediation plans, and regulatory gaps?'
      )
    ) as is_complete,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_ai.gemini_model`,
      CONCAT(
        'Rate the quality of this compliance report on a scale of 0-10: ',
        SUBSTR(compliance_report_content, 1, 2000),
        '. Consider comprehensiveness, clarity, actionability, and regulatory alignment.'
      )
    ) as quality_score,
    LENGTH(compliance_report_content) as report_length;
  
  -- Check report issues
  SELECT 
    CASE 
      WHEN NOT is_complete THEN 1
      WHEN quality_score < 7.0 THEN 1
      WHEN report_length < 1000 THEN 1
      ELSE 0
    END as issues,
    quality_score as score
  INTO report_issues, risk_score
  FROM report_validation;
  
  -- Store the generated compliance report
  INSERT INTO `enterprise_ai.compliance_reports`
  (report_id, report_type, content, created_timestamp, metadata, approval_status)
  VALUES (
    GENERATE_UUID(),
    'security_compliance_assessment',
    compliance_report_content,
    CURRENT_TIMESTAMP(),
    TO_JSON(STRUCT(
      'automated_ai_generation' as generation_method,
      'enhanced_security_testing' as source,
      CURRENT_DATE() as report_date,
      risk_score as quality_score,
      'comprehensive_multi_framework_analysis' as scope
    )),
    'PENDING_REVIEW'
  );
  
  SET test_details = TO_JSON(STRUCT(
    report_issues as validation_issues,
    risk_score as report_quality_score,
    LENGTH(compliance_report_content) as report_length_chars,
    'Automated compliance report generated and validated' as description
  ));
  
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'compliance',
    'Automated Compliance Report Generation and Validation',
    IF(report_issues = 0, 'PASS', 'WARNING'),
    test_details,
    report_issues > 0,
    IF(report_issues = 0, 'LOW', 'MEDIUM'),
    ['GDPR', 'SOX', 'HIPAA', 'PCI_DSS', 'ISO27001'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND),
    10 - risk_score, -- Invert quality score to risk score
    TO_JSON(STRUCT(
      'ai_generated_compliance_report' as evidence_type,
      'automated_quality_validation' as validation_method,
      'comprehensive_regulatory_coverage' as report_scope
    ))
  );
END;

-- =====================================================
-- ENHANCED MASTER TEST RUNNER
-- =====================================================

CREATE OR REPLACE PROCEDURE `enterprise_ai.run_enhanced_security_compliance_tests`()
BEGIN
  DECLARE test_session_id STRING DEFAULT GENERATE_UUID();
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE total_tests INT64 DEFAULT 8;
  DECLARE passed_tests, failed_tests, warning_tests INT64;
  DECLARE total_risk_score FLOAT64;
  
  -- Create test session tracking
  CREATE TABLE IF NOT EXISTS `enterprise_ai.security_test_sessions` (
    session_id STRING NOT NULL,
    start_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    end_timestamp TIMESTAMP,
    total_tests INT64,
    passed_tests INT64,
    failed_tests INT64,
    warning_tests INT64,
    total_risk_score FLOAT64,
    overall_status ENUM('PASS', 'FAIL', 'WARNING'),
    session_summary JSON
  );
  
  -- Clear previous test results for today
  DELETE FROM `enterprise_ai.enhanced_security_test_results`
  WHERE DATE(execution_timestamp) = CURRENT_DATE()
  AND test_name != 'Enhanced Security Compliance Test Suite Summary';
  
  -- Execute all enhanced security and compliance tests
  CALL `enterprise_ai.test_comprehensive_role_validation`();
  CALL `enterprise_ai.test_access_pattern_analysis`();
  CALL `enterprise_ai.test_comprehensive_pii_detection`();
  CALL `enterprise_ai.test_data_governance_compliance`();
  CALL `enterprise_ai.test_comprehensive_audit_integrity`();
  CALL `enterprise_ai.test_audit_forensic_analysis`();
  CALL `enterprise_ai.test_multi_framework_compliance`();
  CALL `enterprise_ai.test_compliance_report_generation`();
  
  -- Calculate test summary statistics
  SELECT 
    COUNTIF(test_status = 'PASS') AS passed,
    COUNTIF(test_status = 'FAIL') AS failed,
    COUNTIF(test_status = 'WARNING') AS warnings,
    SUM(COALESCE(risk_score, 0)) AS total_risk
  INTO passed_tests, failed_tests, warning_tests, total_risk_score
  FROM `enterprise_ai.enhanced_security_test_results`
  WHERE DATE(execution_timestamp) = CURRENT_DATE()
  AND test_name != 'Enhanced Security Compliance Test Suite Summary';
  
  -- Insert session summary
  INSERT INTO `enterprise_ai.security_test_sessions`
  (session_id, end_timestamp, total_tests, passed_tests, failed_tests, warning_tests, 
   total_risk_score, overall_status, session_summary)
  VALUES (
    test_session_id,
    CURRENT_TIMESTAMP(),
    total_tests,
    passed_tests,
    failed_tests,
    warning_tests,
    total_risk_score,
    CASE 
      WHEN failed_tests > 0 THEN 'FAIL'
      WHEN warning_tests > 0 THEN 'WARNING'
      ELSE 'PASS'
    END,
    TO_JSON(STRUCT(
      test_session_id,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, SECOND) AS execution_time_seconds,
      ROUND(passed_tests * 100.0 / total_tests, 2) AS success_rate_percentage,
      total_risk_score,
      'Enhanced comprehensive security and compliance testing' AS description,
      ARRAY['GDPR', 'SOX', 'HIPAA', 'PCI_DSS', 'ISO27001'] AS frameworks_tested
    ))
  );
  
  -- Insert master summary record
  INSERT INTO `enterprise_ai.enhanced_security_test_results`
  (test_id, test_category, test_name, test_status, test_details, remediation_required, 
   severity_level, compliance_frameworks, test_duration_ms, risk_score, test_evidence)
  VALUES (
    GENERATE_UUID(),
    'compliance',
    'Enhanced Security Compliance Test Suite Summary',
    CASE 
      WHEN failed_tests > 0 THEN 'FAIL'
      WHEN warning_tests > 0 THEN 'WARNING'
      ELSE 'PASS'
    END,
    TO_JSON(STRUCT(
      total_tests,
      passed_tests,
      failed_tests,
      warning_tests,
      total_risk_score,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, SECOND) AS execution_time_seconds,
      ROUND(passed_tests * 100.0 / total_tests, 2) AS success_rate_percentage
    )),
    failed_tests > 0 OR warning_tests > 0,
    CASE 
      WHEN total_risk_score >= 50 THEN 'CRITICAL'
      WHEN total_risk_score >= 25 THEN 'HIGH'
      WHEN total_risk_score >= 10 THEN 'MEDIUM'
      ELSE 'LOW'
    END,
    ['GDPR', 'SOX', 'HIPAA', 'PCI_DSS', 'ISO27001'],
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND),
    total_risk_score,
    TO_JSON(STRUCT(
      'comprehensive_security_test_suite' AS evidence_type,
      test_session_id AS session_id,
      'enhanced_ai_powered_testing' AS testing_methodology
    ))
  );
  
  -- Generate security alerts for critical findings
  CALL `enterprise_ai.generate_enhanced_security_alerts`();
  
  -- Generate remediation suggestions
  CALL `enterprise_ai.generate_enhanced_remediation_suggestions`();
  
END;

-- =====================================================
-- ENHANCED SECURITY MONITORING AND ALERTING
-- =====================================================

CREATE OR REPLACE PROCEDURE `enterprise_ai.generate_enhanced_security_alerts`()
BEGIN
  DECLARE critical_violations, high_violations, total_risk_score INT64;
  
  -- Count violations by severity
  SELECT 
    COUNTIF(severity_level = 'CRITICAL' AND test_status = 'FAIL'),
    COUNTIF(severity_level = 'HIGH' AND test_status = 'FAIL'),
    CAST(SUM(COALESCE(risk_score, 0)) AS INT64)
  INTO critical_violations, high_violations, total_risk_score
  FROM `enterprise_ai.enhanced_security_test_results`
  WHERE DATE(execution_timestamp) = CURRENT_DATE();
  
  -- Create enhanced security alerts table if not exists
  CREATE TABLE IF NOT EXISTS `enterprise_ai.enhanced_security_alerts` (
    alert_id STRING NOT NULL,
    alert_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    alert_type ENUM('CRITICAL_SECURITY_VIOLATION', 'HIGH_SECURITY_VIOLATION', 'COMPLIANCE_GAP', 'DATA_PRIVACY_BREACH', 'AUDIT_INTEGRITY_ISSUE'),
    severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'),
    message TEXT,
    affected_frameworks ARRAY<STRING>,
    risk_score FLOAT64,
    requires_immediate_action BOOL DEFAULT FALSE,
    estimated_resolution_time STRING,
    responsible_team STRING,
    alert_details JSON,
    acknowledged BOOL DEFAULT FALSE,
    resolved BOOL DEFAULT FALSE
  ) PARTITION BY DATE(alert_timestamp)
  CLUSTER BY severity, alert_type;
  
  -- Generate critical security alerts
  IF critical_violations > 0 THEN
    INSERT INTO `enterprise_ai.enhanced_security_alerts`
    (alert_id, alert_type, severity, message, affected_frameworks, risk_score, 
     requires_immediate_action, estimated_resolution_time, responsible_team, alert_details)
    SELECT 
      GENERATE_UUID(),
      'CRITICAL_SECURITY_VIOLATION',
      'CRITICAL',
      CONCAT('CRITICAL: ', CAST(critical_violations AS STRING), ' critical security violations detected requiring immediate attention'),
      compliance_frameworks,
      risk_score,
      TRUE,
      '< 4 hours',
      'Security Team',
      TO_JSON(STRUCT(
        test_name,
        test_category,
        test_details,
        'immediate_escalation_required' AS priority
      ))
    FROM `enterprise_ai.enhanced_security_test_results`
    WHERE severity_level = 'CRITICAL' 
    AND test_status = 'FAIL'
    AND DATE(execution_timestamp) = CURRENT_DATE();
  END IF;
  
  -- Generate high severity alerts
  IF high_violations > 0 THEN
    INSERT INTO `enterprise_ai.enhanced_security_alerts`
    (alert_id, alert_type, severity, message, affected_frameworks, risk_score,
     requires_immediate_action, estimated_resolution_time, responsible_team, alert_details)
    SELECT 
      GENERATE_UUID(),
      'HIGH_SECURITY_VIOLATION',
      'HIGH',
      CONCAT('HIGH: ', CAST(high_violations AS STRING), ' high-severity security violations require prompt attention'),
      compliance_frameworks,
      risk_score,
      TRUE,
      '< 24 hours',
      'Security Team',
      TO_JSON(STRUCT(
        test_name,
        test_category,
        test_details,
        'prompt_attention_required' AS priority
      ))
    FROM `enterprise_ai.enhanced_security_test_results`
    WHERE severity_level = 'HIGH' 
    AND test_status = 'FAIL'
    AND DATE(execution_timestamp) = CURRENT_DATE();
  END IF;
  
  -- Generate overall risk assessment alert
  IF total_risk_score >= 25 THEN
    INSERT INTO `enterprise_ai.enhanced_security_alerts`
    (alert_id, alert_type, severity, message, affected_frameworks, risk_score,
     requires_immediate_action, estimated_resolution_time, responsible_team, alert_details)
    VALUES (
      GENERATE_UUID(),
      'CRITICAL_SECURITY_VIOLATION',
      'CRITICAL',
      CONCAT('ENTERPRISE RISK ALERT: Total security risk score of ', CAST(total_risk_score AS STRING), ' exceeds acceptable threshold'),
      ['GDPR', 'SOX', 'HIPAA', 'PCI_DSS', 'ISO27001'],
      total_risk_score,
      TRUE,
      '< 2 hours',
      'CISO Office',
      TO_JSON(STRUCT(
        'enterprise_wide_risk_assessment' AS alert_source,
        total_risk_score AS risk_score,
        critical_violations AS critical_count,
        high_violations AS high_count,
        'executive_escalation_required' AS priority
      ))
    );
  END IF;
END;

-- =====================================================
-- ENHANCED REMEDIATION SUGGESTIONS
-- =====================================================

CREATE OR REPLACE PROCEDURE `enterprise_ai.generate_enhanced_remediation_suggestions`()
BEGIN
  -- Generate comprehensive AI-powered remediation suggestions
  CREATE OR REPLACE TABLE `enterprise_ai.enhanced_remediation_suggestions` AS
  SELECT 
    test_id,
    test_name,
    test_category,
    severity_level,
    compliance_frameworks,
    risk_score,
    AI.GENERATE(
      MODEL `enterprise_ai.gemini_model`,
      CONCAT(
        'Provide comprehensive remediation guidance for this security test failure:\n',
        'Test: ', test_name, '\n',
        'Category: ', test_category, '\n',
        'Severity: ', severity_level, '\n',
        'Risk Score: ', CAST(risk_score AS STRING), '\n',
        'Compliance Frameworks: ', ARRAY_TO_STRING(compliance_frameworks, ', '), '\n',
        'Test Details: ', CAST(test_details AS STRING), '\n\n',
        'Please provide:\n',
        '1. ROOT CAUSE ANALYSIS: Detailed analysis of underlying security issues\n',
        '2. IMMEDIATE ACTIONS: Critical steps to take within 24 hours\n',
        '3. SHORT-TERM REMEDIATION: Actions to complete within 1 week\n',
        '4. LONG-TERM IMPROVEMENTS: Strategic improvements for 1-3 months\n',
        '5. COMPLIANCE ALIGNMENT: Specific regulatory requirements addressed\n',
        '6. RESOURCE REQUIREMENTS: Personnel, tools, and budget needed\n',
        '7. SUCCESS METRICS: How to measure remediation effectiveness\n',
        '8. PREVENTION STRATEGIES: How to prevent recurrence\n',
        '9. RISK MITIGATION: Interim controls while implementing fixes\n',
        '10. STAKEHOLDER COMMUNICATION: Who needs to be informed and when'
      )
    ) AS comprehensive_remediation_plan,
    AI.GENERATE(
      MODEL `enterprise_ai.gemini_model`,
      CONCAT(
        'Estimate the time and effort required to remediate this security issue: ',
        test_name, ' with severity ', severity_level, ' and risk score ', CAST(risk_score AS STRING),
        '. Provide realistic timeline estimates for immediate, short-term, and long-term actions.'
      )
    ) AS implementation_timeline,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_ai.gemini_model`,
      CONCAT(
        'Rate the complexity of implementing remediation for this security issue on a scale of 1-10: ',
        test_name, ' (', test_category, ', severity: ', severity_level, ')'
      )
    ) AS implementation_complexity,
    CURRENT_TIMESTAMP() AS generated_timestamp
  FROM `enterprise_ai.enhanced_security_test_results`
  WHERE test_status = 'FAIL'
  AND remediation_required = TRUE
  AND DATE(execution_timestamp) = CURRENT_DATE()
  AND test_name != 'Enhanced Security Compliance Test Suite Summary';
END;