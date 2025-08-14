-- =====================================================
-- Security and Compliance Schema Setup
-- =====================================================
-- Supporting tables and structures for security testing
-- =====================================================

-- User roles and permissions table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.user_roles` (
  user_id STRING NOT NULL,
  department STRING NOT NULL,
  role_name STRING NOT NULL,
  authorized_roles ARRAY<STRING>,
  security_clearance ENUM('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'),
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY DATE(created_timestamp)
CLUSTER BY department, role_name;

-- Audit trail table for comprehensive logging
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.audit_trail` (
  audit_id STRING NOT NULL,
  interaction_id STRING,
  user_id STRING NOT NULL,
  action_type ENUM('VIEW', 'SHARE', 'DOWNLOAD', 'MODIFY', 'DELETE', 'GENERATE'),
  resource_type ENUM('INSIGHT', 'DOCUMENT', 'REPORT', 'DASHBOARD'),
  resource_id STRING,
  audit_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  ip_address STRING,
  user_agent STRING,
  session_id STRING,
  success BOOL DEFAULT TRUE,
  failure_reason STRING,
  metadata JSON
) PARTITION BY DATE(audit_timestamp)
CLUSTER BY user_id, action_type;

-- Compliance reports table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.compliance_reports` (
  report_id STRING NOT NULL,
  report_type ENUM('security_compliance_assessment', 'gdpr_compliance', 'sox_compliance', 'hipaa_compliance', 'pci_dss_compliance'),
  content TEXT,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON,
  approval_status ENUM('DRAFT', 'PENDING_REVIEW', 'APPROVED', 'REJECTED'),
  approved_by STRING,
  approval_timestamp TIMESTAMP
) PARTITION BY DATE(created_timestamp)
CLUSTER BY report_type, approval_status;

-- Security alerts table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.security_alerts` (
  alert_id STRING NOT NULL,
  alert_type ENUM('CRITICAL_SECURITY_VIOLATION', 'HIGH_SECURITY_VIOLATION', 'UNAUTHORIZED_ACCESS', 'DATA_BREACH', 'COMPLIANCE_VIOLATION'),
  severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'),
  message TEXT,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  requires_immediate_action BOOL DEFAULT FALSE,
  acknowledged BOOL DEFAULT FALSE,
  acknowledged_by STRING,
  acknowledged_timestamp TIMESTAMP,
  resolved BOOL DEFAULT FALSE,
  resolved_by STRING,
  resolved_timestamp TIMESTAMP,
  resolution_notes TEXT
) PARTITION BY DATE(created_timestamp)
CLUSTER BY severity, alert_type;

-- Data classification and sensitivity tracking
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.data_classification` (
  classification_id STRING NOT NULL,
  resource_id STRING NOT NULL,
  resource_type ENUM('DOCUMENT', 'INSIGHT', 'DATASET', 'REPORT'),
  sensitivity_level ENUM('PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'),
  data_categories ARRAY<STRING>, -- e.g., ['PII', 'FINANCIAL', 'HEALTHCARE', 'LEGAL']
  retention_policy STRING,
  encryption_required BOOL DEFAULT FALSE,
  access_restrictions ARRAY<STRING>,
  classification_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  classified_by STRING,
  review_date DATE,
  metadata JSON
) PARTITION BY DATE(classification_timestamp)
CLUSTER BY sensitivity_level, resource_type;

-- Privacy impact assessments
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.privacy_assessments` (
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

-- =====================================================
-- Security Configuration and Policies
-- =====================================================

-- Create security policies configuration table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.security_policies` (
  policy_id STRING NOT NULL,
  policy_name STRING NOT NULL,
  policy_type ENUM('ACCESS_CONTROL', 'DATA_RETENTION', 'ENCRYPTION', 'AUDIT', 'PRIVACY'),
  policy_rules JSON,
  effective_date DATE,
  expiration_date DATE,
  created_by STRING,
  approved_by STRING,
  status ENUM('ACTIVE', 'INACTIVE', 'PENDING_APPROVAL'),
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) CLUSTER BY policy_type, status;

-- Insert default security policies
INSERT INTO `enterprise_knowledge_ai.security_policies`
(policy_id, policy_name, policy_type, policy_rules, effective_date, created_by, status)
VALUES 
(
  GENERATE_UUID(),
  'Role-Based Access Control Policy',
  'ACCESS_CONTROL',
  JSON '{
    "rules": [
      {
        "role": "executive",
        "access_levels": ["PUBLIC", "INTERNAL", "CONFIDENTIAL"],
        "departments": ["ALL"]
      },
      {
        "role": "manager",
        "access_levels": ["PUBLIC", "INTERNAL"],
        "departments": ["SAME_DEPARTMENT"]
      },
      {
        "role": "analyst",
        "access_levels": ["PUBLIC", "INTERNAL"],
        "departments": ["SAME_DEPARTMENT"],
        "restrictions": ["NO_FINANCIAL_DATA"]
      },
      {
        "role": "viewer",
        "access_levels": ["PUBLIC"],
        "departments": ["SAME_DEPARTMENT"]
      }
    ]
  }',
  CURRENT_DATE(),
  'system',
  'ACTIVE'
),
(
  GENERATE_UUID(),
  'Data Retention Policy',
  'DATA_RETENTION',
  JSON '{
    "rules": [
      {
        "data_type": "user_interactions",
        "retention_period": "3_years",
        "archive_after": "1_year"
      },
      {
        "data_type": "enterprise_knowledge_base",
        "retention_period": "7_years",
        "archive_after": "2_years"
      },
      {
        "data_type": "audit_trail",
        "retention_period": "10_years",
        "archive_after": "3_years"
      },
      {
        "data_type": "compliance_reports",
        "retention_period": "permanent",
        "archive_after": "5_years"
      }
    ]
  }',
  CURRENT_DATE(),
  'system',
  'ACTIVE'
),
(
  GENERATE_UUID(),
  'Encryption Policy',
  'ENCRYPTION',
  JSON '{
    "rules": [
      {
        "sensitivity_level": "CONFIDENTIAL",
        "encryption_required": true,
        "encryption_type": "AES_256"
      },
      {
        "sensitivity_level": "RESTRICTED",
        "encryption_required": true,
        "encryption_type": "AES_256",
        "additional_controls": ["HSM", "KEY_ROTATION"]
      },
      {
        "data_categories": ["PII", "FINANCIAL", "HEALTHCARE"],
        "encryption_required": true,
        "encryption_type": "AES_256"
      }
    ]
  }',
  CURRENT_DATE(),
  'system',
  'ACTIVE'
);

-- =====================================================
-- Security Monitoring Views
-- =====================================================

-- Create view for security dashboard
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.security_dashboard` AS
SELECT 
  DATE(execution_timestamp) AS test_date,
  test_category,
  COUNT(*) AS total_tests,
  COUNTIF(test_status = 'PASS') AS passed_tests,
  COUNTIF(test_status = 'FAIL') AS failed_tests,
  COUNTIF(test_status = 'WARNING') AS warning_tests,
  COUNTIF(severity_level = 'CRITICAL' AND test_status = 'FAIL') AS critical_failures,
  COUNTIF(severity_level = 'HIGH' AND test_status = 'FAIL') AS high_failures,
  ROUND(COUNTIF(test_status = 'PASS') / COUNT(*) * 100, 2) AS pass_rate_percent
FROM `enterprise_knowledge_ai.security_test_results`
WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY 1, 2
ORDER BY test_date DESC, test_category;

-- Create view for compliance status
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.compliance_status` AS
WITH latest_tests AS (
  SELECT 
    test_category,
    test_name,
    test_status,
    severity_level,
    ROW_NUMBER() OVER (PARTITION BY test_name ORDER BY execution_timestamp DESC) AS rn
  FROM `enterprise_knowledge_ai.security_test_results`
  WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
)
SELECT 
  test_category AS compliance_area,
  COUNT(*) AS total_controls,
  COUNTIF(test_status = 'PASS') AS compliant_controls,
  COUNTIF(test_status = 'FAIL') AS non_compliant_controls,
  COUNTIF(test_status = 'WARNING') AS controls_with_warnings,
  ROUND(COUNTIF(test_status = 'PASS') / COUNT(*) * 100, 2) AS compliance_percentage,
  CASE 
    WHEN COUNTIF(severity_level = 'CRITICAL' AND test_status = 'FAIL') > 0 THEN 'CRITICAL'
    WHEN COUNTIF(severity_level = 'HIGH' AND test_status = 'FAIL') > 0 THEN 'HIGH'
    WHEN COUNTIF(test_status = 'FAIL') > 0 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS overall_risk_level
FROM latest_tests
WHERE rn = 1
GROUP BY test_category
ORDER BY compliance_percentage ASC;

-- Create view for audit trail analysis
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.audit_analysis` AS
SELECT 
  DATE(audit_timestamp) AS audit_date,
  action_type,
  resource_type,
  COUNT(*) AS total_actions,
  COUNT(DISTINCT user_id) AS unique_users,
  COUNTIF(NOT success) AS failed_actions,
  ROUND(COUNTIF(NOT success) / COUNT(*) * 100, 2) AS failure_rate_percent,
  COUNT(DISTINCT ip_address) AS unique_ip_addresses
FROM `enterprise_knowledge_ai.audit_trail`
WHERE DATE(audit_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY 1, 2, 3
ORDER BY audit_date DESC, total_actions DESC;