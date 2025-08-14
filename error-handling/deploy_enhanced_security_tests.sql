-- =====================================================
-- ENHANCED SECURITY AND COMPLIANCE TESTING DEPLOYMENT
-- Deploy comprehensive security testing framework with AI-powered analysis
-- =====================================================

-- Set project and dataset variables
DECLARE project_id STRING DEFAULT 'your-project-id';
DECLARE dataset_id STRING DEFAULT 'enterprise_ai';

-- Create dataset if not exists
CREATE SCHEMA IF NOT EXISTS `enterprise_ai`
OPTIONS (
  description = 'Enterprise Knowledge Intelligence Platform - Enhanced Security Testing',
  location = 'US'
);

-- Verify enhanced security testing prerequisites
CREATE OR REPLACE FUNCTION `enterprise_ai.verify_enhanced_security_prerequisites`()
RETURNS BOOL
LANGUAGE SQL
AS (
  -- Check if required AI models are available
  EXISTS(
    SELECT 1 FROM `enterprise_ai.INFORMATION_SCHEMA.MODELS`
    WHERE model_name IN ('text_embedding_model', 'gemini_model')
  )
  AND
  -- Check if core security tables exist
  EXISTS(
    SELECT 1 FROM `enterprise_ai.INFORMATION_SCHEMA.TABLES`
    WHERE table_name IN ('user_roles', 'audit_trail', 'compliance_reports', 'security_alerts')
  )
  AND
  -- Check if core system tables exist
  EXISTS(
    SELECT 1 FROM `enterprise_ai.INFORMATION_SCHEMA.TABLES`
    WHERE table_name IN ('enterprise_knowledge_base', 'generated_insights', 'user_interactions')
  )
);

-- Deploy enhanced security testing framework
BEGIN
  IF `enterprise_ai.verify_enhanced_security_prerequisites`() THEN
    
    -- Create enhanced security test results table
    CREATE OR REPLACE TABLE `enterprise_ai.enhanced_security_test_results` (
      test_id STRING NOT NULL,
      test_category ENUM('access_control', 'data_privacy', 'audit_trail', 'compliance', 'penetration', 'vulnerability'),
      test_name STRING NOT NULL,
      test_status ENUM('PASS', 'FAIL', 'WARNING', 'SKIP'),
      test_details JSON,
      execution_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
      remediation_required BOOL,
      severity_level ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'),
      compliance_frameworks ARRAY<STRING>,
      test_duration_ms INT64,
      automated BOOL DEFAULT TRUE,
      test_evidence JSON,
      risk_score FLOAT64
    ) PARTITION BY DATE(execution_timestamp)
    CLUSTER BY test_category, severity_level;

    -- Create security test sessions table
    CREATE OR REPLACE TABLE `enterprise_ai.security_test_sessions` (
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

    -- Create enhanced security alerts table
    CREATE OR REPLACE TABLE `enterprise_ai.enhanced_security_alerts` (
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

    -- Create enhanced remediation suggestions table
    CREATE OR REPLACE TABLE `enterprise_ai.enhanced_remediation_suggestions` (
      test_id STRING NOT NULL,
      test_name STRING NOT NULL,
      test_category STRING NOT NULL,
      severity_level STRING NOT NULL,
      compliance_frameworks ARRAY<STRING>,
      risk_score FLOAT64,
      comprehensive_remediation_plan TEXT,
      implementation_timeline TEXT,
      implementation_complexity FLOAT64,
      generated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
    );

    -- Create data classification table if not exists
    CREATE TABLE IF NOT EXISTS `enterprise_ai.data_classification` (
      classification_id STRING NOT NULL,
      resource_id STRING NOT NULL,
      resource_type ENUM('DOCUMENT', 'INSIGHT', 'DATASET', 'REPORT'),
      sensitivity_level ENUM('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'),
      data_categories ARRAY<STRING>,
      retention_policy STRING,
      encryption_required BOOL DEFAULT FALSE,
      access_restrictions ARRAY<STRING>,
      classification_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
      classified_by STRING,
      review_date DATE,
      metadata JSON
    ) PARTITION BY DATE(classification_timestamp)
    CLUSTER BY sensitivity_level, resource_type;

    -- Create privacy assessments table if not exists
    CREATE TABLE IF NOT EXISTS `enterprise_ai.privacy_assessments` (
      assessment_id STRING NOT NULL,
      data_processing_activity STRING NOT NULL,
      legal_basis STRING,
      data_subjects ARRAY<STRING>,
      data_categories ARRAY<STRING>,
      processing_purposes ARRAY<STRING>,
      retention_period STRING,
      third_party_sharing BOOL DEFAULT FALSE,
      risk_level ENUM('LOW', 'MEDIUM', 'HIGH'),
      mitigation_measures ARRAY<STRING>,
      assessment_date DATE,
      next_review_date DATE,
      assessor STRING,
      approval_status ENUM('DRAFT', 'APPROVED', 'REQUIRES_UPDATE'),
      metadata JSON
    ) PARTITION BY assessment_date
    CLUSTER BY risk_level, approval_status;

    -- Insert sample data classifications for testing
    INSERT INTO `enterprise_ai.data_classification`
    (classification_id, resource_id, resource_type, sensitivity_level, data_categories, 
     retention_policy, encryption_required, classified_by, review_date)
    SELECT 
      GENERATE_UUID(),
      knowledge_id,
      'DOCUMENT',
      CASE 
        WHEN REGEXP_CONTAINS(UPPER(content), r'\b(SSN|SOCIAL SECURITY|CONFIDENTIAL|RESTRICTED)\b') THEN 'CONFIDENTIAL'
        WHEN REGEXP_CONTAINS(UPPER(content), r'\b(INTERNAL|PROPRIETARY|PRIVATE)\b') THEN 'INTERNAL'
        ELSE 'PUBLIC'
      END,
      CASE 
        WHEN REGEXP_CONTAINS(UPPER(content), r'\b(SSN|SOCIAL SECURITY|CREDIT CARD|PHONE|EMAIL)\b') THEN ['PII']
        WHEN REGEXP_CONTAINS(UPPER(content), r'\b(REVENUE|PROFIT|FINANCIAL|BUDGET)\b') THEN ['FINANCIAL']
        ELSE ['GENERAL']
      END,
      'standard_7_years',
      REGEXP_CONTAINS(UPPER(content), r'\b(SSN|SOCIAL SECURITY|CONFIDENTIAL|RESTRICTED)\b'),
      'automated_classification',
      DATE_ADD(CURRENT_DATE(), INTERVAL 90 DAY)
    FROM `enterprise_ai.enterprise_knowledge_base`
    WHERE DATE(created_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
    LIMIT 100;

    -- Create enhanced security monitoring views
    CREATE OR REPLACE VIEW `enterprise_ai.enhanced_security_dashboard` AS
    WITH daily_test_summary AS (
      SELECT 
        DATE(execution_timestamp) AS test_date,
        test_category,
        COUNT(*) AS total_tests,
        COUNTIF(test_status = 'PASS') AS passed_tests,
        COUNTIF(test_status = 'FAIL') AS failed_tests,
        COUNTIF(test_status = 'WARNING') AS warning_tests,
        COUNTIF(severity_level = 'CRITICAL' AND test_status = 'FAIL') AS critical_failures,
        COUNTIF(severity_level = 'HIGH' AND test_status = 'FAIL') AS high_failures,
        AVG(COALESCE(risk_score, 0)) AS avg_risk_score,
        SUM(COALESCE(risk_score, 0)) AS total_risk_score
      FROM `enterprise_ai.enhanced_security_test_results`
      WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      GROUP BY 1, 2
    ),
    compliance_framework_summary AS (
      SELECT 
        DATE(execution_timestamp) AS test_date,
        framework,
        COUNT(*) AS framework_tests,
        COUNTIF(test_status = 'PASS') AS framework_passed,
        COUNTIF(test_status = 'FAIL') AS framework_failed,
        AVG(COALESCE(risk_score, 0)) AS framework_risk_score
      FROM `enterprise_ai.enhanced_security_test_results`,
      UNNEST(compliance_frameworks) AS framework
      WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
      GROUP BY 1, 2
    )
    SELECT 
      dts.test_date,
      dts.test_category,
      dts.total_tests,
      dts.passed_tests,
      dts.failed_tests,
      dts.warning_tests,
      dts.critical_failures,
      dts.high_failures,
      ROUND(dts.passed_tests * 100.0 / dts.total_tests, 2) AS pass_rate_percent,
      ROUND(dts.avg_risk_score, 2) AS avg_risk_score,
      dts.total_risk_score,
      CASE 
        WHEN dts.critical_failures > 0 THEN 'CRITICAL'
        WHEN dts.high_failures > 0 THEN 'HIGH'
        WHEN dts.failed_tests > 0 THEN 'MEDIUM'
        ELSE 'LOW'
      END AS overall_risk_level
    FROM daily_test_summary dts
    ORDER BY dts.test_date DESC, dts.total_risk_score DESC;

    -- Create compliance framework status view
    CREATE OR REPLACE VIEW `enterprise_ai.compliance_framework_status` AS
    WITH latest_framework_tests AS (
      SELECT 
        framework,
        COUNT(*) AS total_controls,
        COUNTIF(test_status = 'PASS') AS compliant_controls,
        COUNTIF(test_status = 'FAIL') AS non_compliant_controls,
        COUNTIF(test_status = 'WARNING') AS controls_with_warnings,
        AVG(COALESCE(risk_score, 0)) AS avg_risk_score,
        MAX(execution_timestamp) AS last_test_timestamp
      FROM `enterprise_ai.enhanced_security_test_results`,
      UNNEST(compliance_frameworks) AS framework
      WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
      GROUP BY framework
    )
    SELECT 
      framework AS compliance_framework,
      total_controls,
      compliant_controls,
      non_compliant_controls,
      controls_with_warnings,
      ROUND(compliant_controls * 100.0 / total_controls, 2) AS compliance_percentage,
      ROUND(avg_risk_score, 2) AS framework_risk_score,
      CASE 
        WHEN non_compliant_controls = 0 THEN 'COMPLIANT'
        WHEN non_compliant_controls <= 2 THEN 'MOSTLY_COMPLIANT'
        WHEN non_compliant_controls <= 5 THEN 'PARTIALLY_COMPLIANT'
        ELSE 'NON_COMPLIANT'
      END AS compliance_status,
      last_test_timestamp
    FROM latest_framework_tests
    ORDER BY compliance_percentage ASC, framework_risk_score DESC;

    -- Create security risk assessment view
    CREATE OR REPLACE VIEW `enterprise_ai.security_risk_assessment` AS
    WITH risk_categories AS (
      SELECT 
        test_category,
        severity_level,
        COUNT(*) AS test_count,
        AVG(COALESCE(risk_score, 0)) AS avg_risk_score,
        SUM(COALESCE(risk_score, 0)) AS total_risk_score,
        COUNTIF(test_status = 'FAIL') AS failed_tests
      FROM `enterprise_ai.enhanced_security_test_results`
      WHERE DATE(execution_timestamp) = CURRENT_DATE()
      GROUP BY 1, 2
    ),
    overall_risk AS (
      SELECT 
        SUM(total_risk_score) AS enterprise_risk_score,
        SUM(failed_tests) AS total_failures,
        COUNT(DISTINCT test_category) AS risk_categories_assessed
      FROM risk_categories
    )
    SELECT 
      rc.test_category AS risk_category,
      rc.severity_level,
      rc.test_count,
      rc.failed_tests,
      ROUND(rc.avg_risk_score, 2) AS avg_risk_score,
      rc.total_risk_score,
      ROUND(rc.total_risk_score * 100.0 / or.enterprise_risk_score, 2) AS risk_contribution_percent,
      CASE 
        WHEN rc.total_risk_score >= 20 THEN 'CRITICAL'
        WHEN rc.total_risk_score >= 10 THEN 'HIGH'
        WHEN rc.total_risk_score >= 5 THEN 'MEDIUM'
        ELSE 'LOW'
      END AS risk_level,
      or.enterprise_risk_score,
      CASE 
        WHEN or.enterprise_risk_score >= 50 THEN 'CRITICAL'
        WHEN or.enterprise_risk_score >= 25 THEN 'HIGH'
        WHEN or.enterprise_risk_score >= 10 THEN 'MEDIUM'
        ELSE 'LOW'
      END AS enterprise_risk_level
    FROM risk_categories rc
    CROSS JOIN overall_risk or
    ORDER BY rc.total_risk_score DESC;

    SELECT 'Enhanced security and compliance testing framework deployed successfully' AS deployment_status;
    
  ELSE
    SELECT 'Prerequisites not met - please deploy core system and basic security framework first' AS deployment_status;
  END IF;
  
EXCEPTION WHEN ERROR THEN
  SELECT CONCAT('Enhanced security deployment failed: ', @@error.message) AS deployment_status;
END;

-- Create validation query for enhanced security framework
SELECT 
  'Enhanced Security Testing Framework' AS component,
  COUNT(*) AS table_count,
  STRING_AGG(table_name ORDER BY table_name) AS deployed_tables
FROM `enterprise_ai.INFORMATION_SCHEMA.TABLES`
WHERE table_name LIKE '%enhanced_security%' 
   OR table_name LIKE '%security_test%' 
   OR table_name LIKE '%remediation%'
   OR table_name LIKE '%data_classification%'
   OR table_name LIKE '%privacy_assessment%';

-- Create validation query for enhanced security procedures
SELECT 
  'Enhanced Security Test Procedures' AS component,
  COUNT(*) AS procedure_count,
  STRING_AGG(routine_name ORDER BY routine_name) AS deployed_procedures
FROM `enterprise_ai.INFORMATION_SCHEMA.ROUTINES`
WHERE routine_name LIKE '%enhanced%' 
   OR routine_name LIKE '%comprehensive%'
   OR routine_name LIKE '%test_%'
   AND routine_type = 'PROCEDURE';

-- Create validation query for enhanced security views
SELECT 
  'Enhanced Security Monitoring Views' AS component,
  COUNT(*) AS view_count,
  STRING_AGG(table_name ORDER BY table_name) AS deployed_views
FROM `enterprise_ai.INFORMATION_SCHEMA.VIEWS`
WHERE table_name LIKE '%enhanced_security%' 
   OR table_name LIKE '%compliance_framework%'
   OR table_name LIKE '%security_risk%';