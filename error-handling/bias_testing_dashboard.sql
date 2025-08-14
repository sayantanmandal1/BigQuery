-- Bias Testing Dashboard and Reporting System
-- Provides comprehensive visualization and monitoring of bias detection results

-- Create bias testing dashboard view
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.bias_testing_dashboard` AS
WITH latest_execution AS (
  SELECT 
    test_execution_id,
    execution_timestamp,
    ROW_NUMBER() OVER (ORDER BY execution_timestamp DESC) as rn
  FROM `enterprise_knowledge_ai.bias_test_results`
  WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
),

current_bias_status AS (
  SELECT 
    btr.protected_attribute,
    COUNT(*) as total_tests,
    COUNTIF(btr.fairness_violation) as violations,
    AVG(btr.bias_score) as avg_bias_score,
    MAX(btr.bias_score) as max_bias_score,
    CASE 
      WHEN SAFE_DIVIDE(COUNTIF(btr.fairness_violation), COUNT(*)) = 0 THEN '🟢 Excellent'
      WHEN SAFE_DIVIDE(COUNTIF(btr.fairness_violation), COUNT(*)) <= 0.1 THEN '🟡 Good'
      WHEN SAFE_DIVIDE(COUNTIF(btr.fairness_violation), COUNT(*)) <= 0.2 THEN '🟠 Needs Attention'
      ELSE '🔴 Critical'
    END as fairness_status,
    ARRAY_AGG(
      CASE WHEN btr.fairness_violation THEN 
        STRUCT(
          btr.group_identifier as group_name,
          btr.metric_name as metric,
          btr.bias_score as score
        )
      END IGNORE NULLS
    ) as violation_details
  FROM `enterprise_knowledge_ai.bias_test_results` btr
  JOIN latest_execution le ON btr.test_execution_id = le.test_execution_id
  WHERE le.rn = 1
  GROUP BY btr.protected_attribute
),

bias_trends AS (
  SELECT 
    protected_attribute,
    DATE(execution_timestamp) as test_date,
    AVG(bias_score) as daily_avg_bias,
    COUNTIF(fairness_violation) as daily_violations,
    COUNT(*) as daily_tests
  FROM `enterprise_knowledge_ai.bias_test_results`
  WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY protected_attribute, DATE(execution_timestamp)
),

recent_alerts AS (
  SELECT 
    alert_type,
    severity,
    title,
    JSON_EXTRACT_SCALAR(metadata, '$.protected_attribute') as protected_attribute,
    JSON_EXTRACT_SCALAR(metadata, '$.daily_violations') as violations,
    created_at
  FROM `enterprise_knowledge_ai.system_alerts`
  WHERE alert_type = 'algorithmic_bias_alert'
    AND DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  ORDER BY created_at DESC
  LIMIT 10
)

SELECT 
  'Enterprise Knowledge AI - Bias Testing Dashboard' as dashboard_title,
  CURRENT_TIMESTAMP() as last_updated,
  (
    SELECT AS STRUCT
      COUNT(DISTINCT protected_attribute) as attributes_monitored,
      SUM(total_tests) as total_tests_run,
      SUM(violations) as total_violations,
      ROUND(AVG(avg_bias_score), 4) as overall_avg_bias_score,
      CASE 
        WHEN SAFE_DIVIDE(SUM(violations), SUM(total_tests)) <= 0.05 THEN 'EXCELLENT'
        WHEN SAFE_DIVIDE(SUM(violations), SUM(total_tests)) <= 0.1 THEN 'GOOD'
        WHEN SAFE_DIVIDE(SUM(violations), SUM(total_tests)) <= 0.2 THEN 'NEEDS_IMPROVEMENT'
        ELSE 'CRITICAL'
      END as overall_fairness_grade
    FROM current_bias_status
  ) as overall_status,
  ARRAY(
    SELECT AS STRUCT 
      protected_attribute,
      total_tests,
      violations,
      ROUND(avg_bias_score, 4) as avg_bias_score,
      ROUND(max_bias_score, 4) as max_bias_score,
      fairness_status,
      violation_details
    FROM current_bias_status
    ORDER BY violations DESC, avg_bias_score DESC
  ) as attribute_status,
  ARRAY(
    SELECT AS STRUCT 
      protected_attribute,
      test_date,
      ROUND(daily_avg_bias, 4) as avg_bias_score,
      daily_violations as violations,
      daily_tests as tests_run
    FROM bias_trends
    WHERE test_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    ORDER BY test_date DESC, protected_attribute
  ) as recent_trends,
  ARRAY(
    SELECT AS STRUCT 
      title,
      severity,
      protected_attribute,
      CAST(violations AS INT64) as violation_count,
      created_at
    FROM recent_alerts
  ) as recent_alerts;

-- Create bias metrics aggregation table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.bias_metrics_daily` (
  metric_date DATE NOT NULL,
  protected_attribute STRING NOT NULL,
  total_tests INT64,
  violations INT64,
  avg_bias_score FLOAT64,
  max_bias_score FLOAT64,
  fairness_grade STRING,
  trend_direction STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY metric_date
CLUSTER BY protected_attribute, fairness_grade;

-- Procedure to aggregate daily bias metrics
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.aggregate_daily_bias_metrics`()
BEGIN
  DECLARE target_date DATE DEFAULT CURRENT_DATE();
  
  -- Aggregate bias test results by protected attribute for the target date
  INSERT INTO `enterprise_knowledge_ai.bias_metrics_daily` (
    metric_date,
    protected_attribute,
    total_tests,
    violations,
    avg_bias_score,
    max_bias_score,
    fairness_grade,
    trend_direction
  )
  WITH daily_metrics AS (
    SELECT 
      target_date as metric_date,
      protected_attribute,
      COUNT(*) as total_tests,
      COUNTIF(fairness_violation) as violations,
      AVG(bias_score) as avg_bias_score,
      MAX(bias_score) as max_bias_score
    FROM `enterprise_knowledge_ai.bias_test_results`
    WHERE DATE(execution_timestamp) = target_date
    GROUP BY protected_attribute
  ),
  
  graded_metrics AS (
    SELECT 
      *,
      CASE 
        WHEN SAFE_DIVIDE(violations, total_tests) = 0 THEN 'EXCELLENT'
        WHEN SAFE_DIVIDE(violations, total_tests) <= 0.1 THEN 'GOOD'
        WHEN SAFE_DIVIDE(violations, total_tests) <= 0.2 THEN 'NEEDS_IMPROVEMENT'
        ELSE 'CRITICAL'
      END as fairness_grade,
      -- Compare with previous day to determine trend
      CASE 
        WHEN avg_bias_score > COALESCE(
          (SELECT avg_bias_score 
           FROM `enterprise_knowledge_ai.bias_metrics_daily` prev
           WHERE prev.protected_attribute = daily_metrics.protected_attribute 
             AND prev.metric_date = DATE_SUB(target_date, INTERVAL 1 DAY)), 0) 
        THEN 'WORSENING'
        WHEN avg_bias_score < COALESCE(
          (SELECT avg_bias_score 
           FROM `enterprise_knowledge_ai.bias_metrics_daily` prev
           WHERE prev.protected_attribute = daily_metrics.protected_attribute 
             AND prev.metric_date = DATE_SUB(target_date, INTERVAL 1 DAY)), 1) 
        THEN 'IMPROVING'
        ELSE 'STABLE'
      END as trend_direction
    FROM daily_metrics
  )
  SELECT * FROM graded_metrics;
  
END;

-- Generate comprehensive bias testing report
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.generate_bias_testing_report`(
  report_period_days INT64 DEFAULT 7
)
BEGIN
  DECLARE report_start_date DATE DEFAULT DATE_SUB(CURRENT_DATE(), INTERVAL report_period_days DAY);
  
  WITH report_data AS (
    SELECT 
      protected_attribute,
      COUNT(*) as total_tests,
      COUNTIF(fairness_violation) as total_violations,
      AVG(bias_score) as avg_bias_score,
      STDDEV(bias_score) as bias_score_stddev,
      MIN(bias_score) as min_bias_score,
      MAX(bias_score) as max_bias_score,
      COUNT(DISTINCT group_identifier) as groups_tested,
      COUNT(DISTINCT metric_name) as metrics_evaluated,
      ARRAY_AGG(DISTINCT test_name IGNORE NULLS) as test_types
    FROM `enterprise_knowledge_ai.bias_test_results`
    WHERE DATE(execution_timestamp) >= report_start_date
    GROUP BY protected_attribute
  ),
  
  violation_analysis AS (
    SELECT 
      protected_attribute,
      group_identifier,
      metric_name,
      COUNT(*) as violation_count,
      AVG(bias_score) as avg_violation_score
    FROM `enterprise_knowledge_ai.bias_test_results`
    WHERE fairness_violation = TRUE
      AND DATE(execution_timestamp) >= report_start_date
    GROUP BY protected_attribute, group_identifier, metric_name
  ),
  
  trend_analysis AS (
    SELECT 
      protected_attribute,
      DATE(execution_timestamp) as test_date,
      AVG(bias_score) as daily_bias_score,
      COUNTIF(fairness_violation) as daily_violations
    FROM `enterprise_knowledge_ai.bias_test_results`
    WHERE DATE(execution_timestamp) >= report_start_date
    GROUP BY protected_attribute, DATE(execution_timestamp)
  )
  
  -- Generate AI-powered bias analysis report
  SELECT 
    'BIAS TESTING COMPREHENSIVE REPORT' as report_title,
    CURRENT_DATE() as report_date,
    report_period_days as analysis_period_days,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Generate a comprehensive bias testing analysis report for the Enterprise Knowledge AI Platform. ',
        'Analysis Period: ', CAST(report_period_days AS STRING), ' days. ',
        'Protected Attributes Tested: ', (SELECT STRING_AGG(protected_attribute, ', ') FROM report_data), '. ',
        'Total Tests: ', CAST((SELECT SUM(total_tests) FROM report_data) AS STRING), '. ',
        'Total Violations: ', CAST((SELECT SUM(total_violations) FROM report_data) AS STRING), '. ',
        'Overall Violation Rate: ', CAST(ROUND((SELECT SAFE_DIVIDE(SUM(total_violations), SUM(total_tests)) FROM report_data) * 100, 2) AS STRING), '%. ',
        'Provide detailed analysis of bias patterns, fairness violations, trends, and specific recommendations for improving algorithmic fairness across all protected attributes.'
      )
    ) as executive_summary,
    ARRAY(
      SELECT AS STRUCT 
        protected_attribute,
        total_tests,
        total_violations,
        ROUND(SAFE_DIVIDE(total_violations, total_tests) * 100, 2) as violation_rate_percent,
        ROUND(avg_bias_score, 4) as avg_bias_score,
        ROUND(bias_score_stddev, 4) as bias_score_stddev,
        ROUND(max_bias_score, 4) as max_bias_score,
        groups_tested,
        metrics_evaluated,
        test_types,
        CASE 
          WHEN SAFE_DIVIDE(total_violations, total_tests) = 0 THEN 'EXCELLENT'
          WHEN SAFE_DIVIDE(total_violations, total_tests) <= 0.1 THEN 'GOOD'
          WHEN SAFE_DIVIDE(total_violations, total_tests) <= 0.2 THEN 'NEEDS_IMPROVEMENT'
          ELSE 'CRITICAL'
        END as fairness_grade
      FROM report_data
      ORDER BY total_violations DESC, avg_bias_score DESC
    ) as attribute_analysis,
    ARRAY(
      SELECT AS STRUCT 
        protected_attribute,
        group_identifier,
        metric_name,
        violation_count,
        ROUND(avg_violation_score, 4) as avg_violation_score
      FROM violation_analysis
      ORDER BY violation_count DESC, avg_violation_score DESC
      LIMIT 20
    ) as top_violations,
    ARRAY(
      SELECT AS STRUCT 
        protected_attribute,
        ARRAY_AGG(
          STRUCT(
            test_date,
            ROUND(daily_bias_score, 4) as bias_score,
            daily_violations as violations
          ) ORDER BY test_date
        ) as daily_metrics
      FROM trend_analysis
      GROUP BY protected_attribute
    ) as trend_analysis;
  
END;

-- Create bias testing alerts and notifications
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.create_bias_testing_alerts`()
BEGIN
  -- Check for critical bias violations in the last 24 hours
  WITH critical_violations AS (
    SELECT 
      protected_attribute,
      COUNT(*) as violation_count,
      AVG(bias_score) as avg_bias_score,
      MAX(bias_score) as max_bias_score,
      STRING_AGG(DISTINCT group_identifier, ', ') as affected_groups
    FROM `enterprise_knowledge_ai.bias_test_results`
    WHERE fairness_violation = TRUE
      AND DATE(execution_timestamp) = CURRENT_DATE()
      AND bias_score > 0.2  -- Critical threshold
    GROUP BY protected_attribute
    HAVING COUNT(*) > 2  -- Multiple violations
  ),
  
  trending_bias AS (
    SELECT 
      protected_attribute,
      AVG(CASE WHEN DATE(execution_timestamp) = CURRENT_DATE() THEN bias_score END) as today_avg_bias,
      AVG(CASE WHEN DATE(execution_timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN bias_score END) as yesterday_avg_bias
    FROM `enterprise_knowledge_ai.bias_test_results`
    WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 DAY)
    GROUP BY protected_attribute
    HAVING AVG(CASE WHEN DATE(execution_timestamp) = CURRENT_DATE() THEN bias_score END) > 
           AVG(CASE WHEN DATE(execution_timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY) THEN bias_score END) * 1.5
  )
  
  -- Generate critical bias alerts
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
    'critical_bias_violation',
    'critical',
    CONCAT('CRITICAL: Multiple Bias Violations - ', protected_attribute),
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'CRITICAL BIAS ALERT: Multiple fairness violations detected for ', protected_attribute, '. ',
        'Violation Count: ', CAST(violation_count AS STRING), '. ',
        'Average Bias Score: ', CAST(ROUND(avg_bias_score, 4) AS STRING), '. ',
        'Maximum Bias Score: ', CAST(ROUND(max_bias_score, 4) AS STRING), '. ',
        'Affected Groups: ', affected_groups, '. ',
        'IMMEDIATE ACTION REQUIRED: Review algorithmic fairness, implement bias mitigation strategies, and conduct thorough system audit.'
      )
    ),
    JSON_OBJECT(
      'protected_attribute', protected_attribute,
      'violation_count', violation_count,
      'avg_bias_score', avg_bias_score,
      'max_bias_score', max_bias_score,
      'affected_groups', affected_groups,
      'requires_immediate_action', TRUE,
      'alert_priority', 'P0'
    ),
    CURRENT_TIMESTAMP()
  FROM critical_violations
  
  UNION ALL
  
  -- Generate trending bias alerts
  SELECT 
    GENERATE_UUID(),
    'trending_bias_increase',
    'high',
    CONCAT('Trending Bias Increase - ', protected_attribute),
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'TRENDING BIAS ALERT: Significant increase in bias detected for ', protected_attribute, '. ',
        'Today Average: ', CAST(ROUND(today_avg_bias, 4) AS STRING), '. ',
        'Yesterday Average: ', CAST(ROUND(yesterday_avg_bias, 4) AS STRING), '. ',
        'Increase Factor: ', CAST(ROUND(today_avg_bias / yesterday_avg_bias, 2) AS STRING), 'x. ',
        'Recommend immediate investigation of recent system changes and implementation of bias monitoring protocols.'
      )
    ),
    JSON_OBJECT(
      'protected_attribute', protected_attribute,
      'today_avg_bias', today_avg_bias,
      'yesterday_avg_bias', yesterday_avg_bias,
      'increase_factor', today_avg_bias / yesterday_avg_bias,
      'trend_direction', 'WORSENING',
      'alert_priority', 'P1'
    ),
    CURRENT_TIMESTAMP()
  FROM trending_bias;
  
END;

-- Bias testing performance analytics view
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.bias_testing_analytics` AS
WITH performance_metrics AS (
  SELECT 
    protected_attribute,
    DATE(execution_timestamp) as test_date,
    COUNT(*) as daily_tests,
    COUNTIF(fairness_violation) as daily_violations,
    AVG(bias_score) as avg_bias_score,
    STDDEV(bias_score) as bias_score_stddev,
    MIN(bias_score) as min_bias_score,
    MAX(bias_score) as max_bias_score
  FROM `enterprise_knowledge_ai.bias_test_results`
  WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY protected_attribute, DATE(execution_timestamp)
),

trend_analysis AS (
  SELECT 
    protected_attribute,
    test_date,
    avg_bias_score,
    daily_violations,
    LAG(avg_bias_score) OVER (PARTITION BY protected_attribute ORDER BY test_date) as prev_bias_score,
    LAG(daily_violations) OVER (PARTITION BY protected_attribute ORDER BY test_date) as prev_violations,
    CASE 
      WHEN avg_bias_score > LAG(avg_bias_score) OVER (PARTITION BY protected_attribute ORDER BY test_date) THEN 'WORSENING'
      WHEN avg_bias_score < LAG(avg_bias_score) OVER (PARTITION BY protected_attribute ORDER BY test_date) THEN 'IMPROVING'
      ELSE 'STABLE'
    END as bias_trend
  FROM performance_metrics
),

anomaly_detection AS (
  SELECT 
    protected_attribute,
    test_date,
    avg_bias_score,
    daily_violations,
    bias_trend,
    CASE 
      WHEN avg_bias_score > (
        SELECT AVG(avg_bias_score) + 2 * STDDEV(avg_bias_score)
        FROM performance_metrics pm2 
        WHERE pm2.protected_attribute = trend_analysis.protected_attribute
      ) THEN TRUE
      ELSE FALSE
    END as is_bias_anomaly,
    CASE 
      WHEN daily_violations > (
        SELECT AVG(daily_violations) + 2 * STDDEV(daily_violations)
        FROM performance_metrics pm2 
        WHERE pm2.protected_attribute = trend_analysis.protected_attribute
      ) THEN TRUE
      ELSE FALSE
    END as is_violation_anomaly
  FROM trend_analysis
)

SELECT 
  protected_attribute,
  test_date,
  ROUND(avg_bias_score, 4) as avg_bias_score,
  daily_violations,
  bias_trend,
  is_bias_anomaly,
  is_violation_anomaly,
  CASE 
    WHEN is_bias_anomaly OR is_violation_anomaly THEN 'CRITICAL'
    WHEN bias_trend = 'WORSENING' AND daily_violations > 0 THEN 'HIGH_RISK'
    WHEN bias_trend = 'WORSENING' THEN 'MONITOR_CLOSELY'
    ELSE 'NORMAL'
  END as risk_level
FROM anomaly_detection
ORDER BY protected_attribute, test_date DESC;