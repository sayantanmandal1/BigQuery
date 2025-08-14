-- Comprehensive Bias Detection and Fairness Testing Runner
-- Executes all bias detection tests and generates comprehensive reports

-- Quick execution script for bias testing
-- Option 1: Run comprehensive bias tests with default settings
CALL `enterprise_knowledge_ai.run_comprehensive_bias_tests`('development');

-- Option 2: Run specific bias test components
-- CALL `enterprise_knowledge_ai.initialize_bias_testing_configs`();
-- CALL `enterprise_knowledge_ai.generate_bias_test_data`();
-- CALL `enterprise_knowledge_ai.validate_content_fairness`(GENERATE_UUID(), 0.1);

-- Option 3: Run continuous bias monitoring
-- CALL `enterprise_knowledge_ai.monitor_algorithmic_bias`(24);

-- View comprehensive bias testing dashboard
SELECT * FROM `enterprise_knowledge_ai.bias_testing_dashboard`;

-- Check latest bias test results
SELECT 
  protected_attribute,
  COUNT(*) as total_tests,
  COUNTIF(fairness_violation) as violations,
  ROUND(AVG(bias_score), 4) as avg_bias_score,
  ROUND(MAX(bias_score), 4) as max_bias_score,
  CASE 
    WHEN SAFE_DIVIDE(COUNTIF(fairness_violation), COUNT(*)) = 0 THEN 'EXCELLENT'
    WHEN SAFE_DIVIDE(COUNTIF(fairness_violation), COUNT(*)) <= 0.1 THEN 'GOOD'
    WHEN SAFE_DIVIDE(COUNTIF(fairness_violation), COUNT(*)) <= 0.2 THEN 'NEEDS_IMPROVEMENT'
    ELSE 'CRITICAL'
  END as fairness_grade
FROM `enterprise_knowledge_ai.bias_test_results`
WHERE DATE(execution_timestamp) = CURRENT_DATE()
GROUP BY protected_attribute
ORDER BY violations DESC, avg_bias_score DESC;

-- View recent bias violations
SELECT 
  protected_attribute,
  group_identifier,
  metric_name,
  ROUND(bias_score, 4) as bias_score,
  test_name,
  execution_timestamp
FROM `enterprise_knowledge_ai.bias_test_results`
WHERE fairness_violation = TRUE
  AND DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY bias_score DESC, execution_timestamp DESC
LIMIT 20;

-- Generate comprehensive bias testing report
CALL `enterprise_knowledge_ai.generate_bias_testing_report`(7);

-- View bias testing analytics
SELECT 
  protected_attribute,
  test_date,
  avg_bias_score,
  daily_violations,
  bias_trend,
  risk_level
FROM `enterprise_knowledge_ai.bias_testing_analytics`
WHERE test_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY protected_attribute, test_date DESC;

-- Check for recent bias alerts
SELECT 
  alert_type,
  severity,
  title,
  JSON_EXTRACT_SCALAR(metadata, '$.protected_attribute') as protected_attribute,
  JSON_EXTRACT_SCALAR(metadata, '$.violation_count') as violations,
  created_at
FROM `enterprise_knowledge_ai.system_alerts`
WHERE alert_type IN ('algorithmic_bias_alert', 'critical_bias_violation', 'trending_bias_increase')
  AND DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
ORDER BY created_at DESC
LIMIT 10;