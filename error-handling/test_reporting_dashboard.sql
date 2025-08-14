-- Test Result Aggregation and Reporting Dashboard
-- Provides comprehensive test analytics and visualization

-- Create test metrics aggregation table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_metrics_daily` (
  metric_date DATE NOT NULL,
  test_suite STRING NOT NULL,
  total_tests INT64,
  passed_tests INT64,
  failed_tests INT64,
  warning_tests INT64,
  success_rate FLOAT64,
  avg_execution_time_ms FLOAT64,
  performance_grade STRING,
  trend_direction STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY metric_date
CLUSTER BY test_suite, performance_grade;

-- Create test quality trends table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_quality_trends` (
  trend_id STRING NOT NULL,
  metric_name STRING NOT NULL,
  time_period STRING NOT NULL,
  current_value FLOAT64,
  previous_value FLOAT64,
  change_percentage FLOAT64,
  trend_direction ENUM('improving', 'declining', 'stable'),
  significance_level STRING,
  analysis STRING,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY DATE(created_at)
CLUSTER BY metric_name, trend_direction;

-- Procedure to aggregate daily test metrics
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.aggregate_daily_test_metrics`()
BEGIN
  DECLARE target_date DATE DEFAULT CURRENT_DATE();
  
  -- Aggregate test results by suite for the target date
  INSERT INTO `enterprise_knowledge_ai.test_metrics_daily` (
    metric_date,
    test_suite,
    total_tests,
    passed_tests,
    failed_tests,
    warning_tests,
    success_rate,
    avg_execution_time_ms,
    performance_grade,
    trend_direction
  )
  WITH daily_metrics AS (
    SELECT 
      target_date as metric_date,
      test_suite,
      COUNT(*) as total_tests,
      COUNTIF(test_status = 'PASSED') as passed_tests,
      COUNTIF(test_status = 'FAILED') as failed_tests,
      COUNTIF(test_status = 'WARNING') as warning_tests,
      SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) as success_rate,
      AVG(execution_time_ms) as avg_execution_time_ms
    FROM `enterprise_knowledge_ai.master_test_results`
    WHERE DATE(execution_timestamp) = target_date
    GROUP BY test_suite
  ),
  performance_analysis AS (
    SELECT 
      *,
      CASE 
        WHEN success_rate >= 0.95 AND avg_execution_time_ms < 5000 THEN 'EXCELLENT'
        WHEN success_rate >= 0.90 AND avg_execution_time_ms < 10000 THEN 'GOOD'
        WHEN success_rate >= 0.80 AND avg_execution_time_ms < 15000 THEN 'ACCEPTABLE'
        WHEN success_rate >= 0.70 THEN 'NEEDS_IMPROVEMENT'
        ELSE 'CRITICAL'
      END as performance_grade,
      -- Compare with previous day to determine trend
      CASE 
        WHEN success_rate > COALESCE(
          (SELECT success_rate 
           FROM `enterprise_knowledge_ai.test_metrics_daily` prev
           WHERE prev.test_suite = daily_metrics.test_suite 
             AND prev.metric_date = DATE_SUB(target_date, INTERVAL 1 DAY)), 0) 
        THEN 'improving'
        WHEN success_rate < COALESCE(
          (SELECT success_rate 
           FROM `enterprise_knowledge_ai.test_metrics_daily` prev
           WHERE prev.test_suite = daily_metrics.test_suite 
             AND prev.metric_date = DATE_SUB(target_date, INTERVAL 1 DAY)), 1) 
        THEN 'declining'
        ELSE 'stable'
      END as trend_direction
    FROM daily_metrics
  )
  SELECT * FROM performance_analysis;
  
END;

-- Procedure to analyze test quality trends
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.analyze_test_quality_trends`()
BEGIN
  DECLARE analysis_date DATE DEFAULT CURRENT_DATE();
  
  -- Analyze weekly trends
  INSERT INTO `enterprise_knowledge_ai.test_quality_trends` (
    trend_id,
    metric_name,
    time_period,
    current_value,
    previous_value,
    change_percentage,
    trend_direction,
    significance_level,
    analysis
  )
  WITH weekly_comparison AS (
    SELECT 
      'overall_success_rate' as metric_name,
      'weekly' as time_period,
      AVG(CASE WHEN metric_date >= DATE_SUB(analysis_date, INTERVAL 7 DAY) THEN success_rate END) as current_week_avg,
      AVG(CASE WHEN metric_date >= DATE_SUB(analysis_date, INTERVAL 14 DAY) 
                AND metric_date < DATE_SUB(analysis_date, INTERVAL 7 DAY) THEN success_rate END) as previous_week_avg
    FROM `enterprise_knowledge_ai.test_metrics_daily`
    WHERE metric_date >= DATE_SUB(analysis_date, INTERVAL 14 DAY)
    
    UNION ALL
    
    SELECT 
      'avg_execution_time' as metric_name,
      'weekly' as time_period,
      AVG(CASE WHEN metric_date >= DATE_SUB(analysis_date, INTERVAL 7 DAY) THEN avg_execution_time_ms END) as current_week_avg,
      AVG(CASE WHEN metric_date >= DATE_SUB(analysis_date, INTERVAL 14 DAY) 
                AND metric_date < DATE_SUB(analysis_date, INTERVAL 7 DAY) THEN avg_execution_time_ms END) as previous_week_avg
    FROM `enterprise_knowledge_ai.test_metrics_daily`
    WHERE metric_date >= DATE_SUB(analysis_date, INTERVAL 14 DAY)
  ),
  trend_analysis AS (
    SELECT 
      metric_name,
      time_period,
      current_week_avg as current_value,
      previous_week_avg as previous_value,
      SAFE_DIVIDE((current_week_avg - previous_week_avg), previous_week_avg) * 100 as change_percentage,
      CASE 
        WHEN ABS(SAFE_DIVIDE((current_week_avg - previous_week_avg), previous_week_avg)) < 0.05 THEN 'stable'
        WHEN current_week_avg > previous_week_avg AND metric_name = 'overall_success_rate' THEN 'improving'
        WHEN current_week_avg < previous_week_avg AND metric_name = 'overall_success_rate' THEN 'declining'
        WHEN current_week_avg < previous_week_avg AND metric_name = 'avg_execution_time' THEN 'improving'
        WHEN current_week_avg > previous_week_avg AND metric_name = 'avg_execution_time' THEN 'declining'
        ELSE 'stable'
      END as trend_direction,
      CASE 
        WHEN ABS(SAFE_DIVIDE((current_week_avg - previous_week_avg), previous_week_avg)) > 0.20 THEN 'high'
        WHEN ABS(SAFE_DIVIDE((current_week_avg - previous_week_avg), previous_week_avg)) > 0.10 THEN 'medium'
        ELSE 'low'
      END as significance_level
    FROM weekly_comparison
    WHERE current_week_avg IS NOT NULL AND previous_week_avg IS NOT NULL
  )
  SELECT 
    GENERATE_UUID() as trend_id,
    metric_name,
    time_period,
    current_value,
    previous_value,
    change_percentage,
    trend_direction,
    significance_level,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze this test quality trend: ',
        metric_name, ' changed from ', CAST(previous_value AS STRING),
        ' to ', CAST(current_value AS STRING), ' (', 
        CAST(ROUND(change_percentage, 2) AS STRING), '% change) over the past week. ',
        'Trend direction: ', trend_direction, '. ',
        'Provide insights on what this means for system quality and recommend actions if needed.'
      )
    ) as analysis
  FROM trend_analysis;
  
END;

-- Create comprehensive test reporting view
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.comprehensive_test_report` AS
WITH latest_execution AS (
  SELECT 
    execution_id,
    total_tests,
    passed_tests,
    failed_tests,
    warning_tests,
    overall_success_rate,
    total_execution_time_ms,
    execution_timestamp
  FROM `enterprise_knowledge_ai.test_execution_summary`
  ORDER BY execution_timestamp DESC
  LIMIT 1
),
suite_breakdown AS (
  SELECT 
    test_suite,
    COUNT(*) as total_tests,
    COUNTIF(test_status = 'PASSED') as passed_tests,
    COUNTIF(test_status = 'FAILED') as failed_tests,
    COUNTIF(test_status = 'WARNING') as warning_tests,
    SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) as success_rate,
    AVG(execution_time_ms) as avg_execution_time_ms
  FROM `enterprise_knowledge_ai.master_test_results` mtr
  WHERE mtr.execution_id = (SELECT execution_id FROM latest_execution)
  GROUP BY test_suite
),
failed_tests_detail AS (
  SELECT 
    test_suite,
    test_name,
    error_message,
    execution_time_ms
  FROM `enterprise_knowledge_ai.master_test_results` mtr
  WHERE mtr.execution_id = (SELECT execution_id FROM latest_execution)
    AND test_status = 'FAILED'
),
historical_comparison AS (
  SELECT 
    AVG(overall_success_rate) as avg_success_rate_7d,
    AVG(total_execution_time_ms) as avg_execution_time_7d
  FROM `enterprise_knowledge_ai.test_execution_summary`
  WHERE execution_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
)
SELECT 
  'Enterprise Knowledge AI - Test Execution Report' as report_title,
  CURRENT_TIMESTAMP() as report_generated_at,
  (SELECT * FROM latest_execution) as latest_execution_summary,
  ARRAY(SELECT AS STRUCT * FROM suite_breakdown ORDER BY success_rate DESC) as suite_performance,
  ARRAY(SELECT AS STRUCT * FROM failed_tests_detail ORDER BY test_suite, test_name) as failed_tests,
  (SELECT * FROM historical_comparison) as historical_comparison,
  AI.GENERATE(
    MODEL `enterprise_knowledge_ai.gemini_model`,
    CONCAT(
      'Generate an executive summary for this test execution report. ',
      'Latest execution: ', CAST((SELECT passed_tests FROM latest_execution) AS STRING), ' passed, ',
      CAST((SELECT failed_tests FROM latest_execution) AS STRING), ' failed out of ',
      CAST((SELECT total_tests FROM latest_execution) AS STRING), ' total tests. ',
      'Success rate: ', CAST(ROUND((SELECT overall_success_rate FROM latest_execution) * 100, 2) AS STRING), '%. ',
      'Highlight key findings, areas of concern, and recommended actions.'
    )
  ) as executive_summary;

-- Create test performance analytics view
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.test_performance_analytics` AS
WITH performance_metrics AS (
  SELECT 
    test_suite,
    DATE(execution_timestamp) as test_date,
    AVG(execution_time_ms) as avg_execution_time,
    MIN(execution_time_ms) as min_execution_time,
    MAX(execution_time_ms) as max_execution_time,
    STDDEV(execution_time_ms) as execution_time_stddev,
    COUNT(*) as test_count,
    SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) as daily_success_rate
  FROM `enterprise_knowledge_ai.master_test_results`
  WHERE DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  GROUP BY test_suite, DATE(execution_timestamp)
),
performance_trends AS (
  SELECT 
    test_suite,
    test_date,
    avg_execution_time,
    daily_success_rate,
    LAG(avg_execution_time) OVER (PARTITION BY test_suite ORDER BY test_date) as prev_execution_time,
    LAG(daily_success_rate) OVER (PARTITION BY test_suite ORDER BY test_date) as prev_success_rate,
    CASE 
      WHEN avg_execution_time < LAG(avg_execution_time) OVER (PARTITION BY test_suite ORDER BY test_date) THEN 'improving'
      WHEN avg_execution_time > LAG(avg_execution_time) OVER (PARTITION BY test_suite ORDER BY test_date) THEN 'degrading'
      ELSE 'stable'
    END as performance_trend
  FROM performance_metrics
),
anomaly_detection AS (
  SELECT 
    test_suite,
    test_date,
    avg_execution_time,
    daily_success_rate,
    performance_trend,
    CASE 
      WHEN avg_execution_time > (
        SELECT AVG(avg_execution_time) + 2 * STDDEV(avg_execution_time)
        FROM performance_metrics pm2 
        WHERE pm2.test_suite = performance_trends.test_suite
      ) THEN TRUE
      ELSE FALSE
    END as is_performance_anomaly,
    CASE 
      WHEN daily_success_rate < (
        SELECT AVG(daily_success_rate) - 2 * STDDEV(daily_success_rate)
        FROM performance_metrics pm2 
        WHERE pm2.test_suite = performance_trends.test_suite
      ) THEN TRUE
      ELSE FALSE
    END as is_quality_anomaly
  FROM performance_trends
)
SELECT 
  test_suite,
  test_date,
  avg_execution_time,
  daily_success_rate,
  performance_trend,
  is_performance_anomaly,
  is_quality_anomaly,
  CASE 
    WHEN is_performance_anomaly OR is_quality_anomaly THEN 'requires_attention'
    WHEN performance_trend = 'degrading' THEN 'monitor_closely'
    ELSE 'normal'
  END as alert_level
FROM anomaly_detection
ORDER BY test_suite, test_date DESC;

-- Procedure to generate automated test insights
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.generate_test_insights`()
BEGIN
  DECLARE insights_report STRING;
  
  -- Generate comprehensive insights using AI
  SET insights_report = (
    WITH test_summary AS (
      SELECT 
        COUNT(DISTINCT test_suite) as total_suites,
        COUNT(*) as total_tests,
        COUNTIF(test_status = 'PASSED') as passed_tests,
        COUNTIF(test_status = 'FAILED') as failed_tests,
        SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) as overall_success_rate,
        AVG(execution_time_ms) as avg_execution_time
      FROM `enterprise_knowledge_ai.master_test_results`
      WHERE DATE(execution_timestamp) = CURRENT_DATE()
    ),
    failure_patterns AS (
      SELECT 
        test_suite,
        COUNT(*) as failure_count,
        STRING_AGG(DISTINCT COALESCE(error_message, 'Unknown error'), '; ') as common_errors
      FROM `enterprise_knowledge_ai.master_test_results`
      WHERE test_status = 'FAILED'
        AND DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
      GROUP BY test_suite
      HAVING COUNT(*) > 0
    ),
    performance_issues AS (
      SELECT 
        test_suite,
        AVG(execution_time_ms) as avg_time,
        COUNT(*) as slow_test_count
      FROM `enterprise_knowledge_ai.master_test_results`
      WHERE execution_time_ms > 10000  -- Tests taking more than 10 seconds
        AND DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
      GROUP BY test_suite
      HAVING COUNT(*) > 0
    )
    SELECT AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze these test execution patterns and provide actionable insights: ',
        'Overall Statistics: ', (SELECT CAST(total_tests AS STRING) FROM test_summary), ' tests across ',
        (SELECT CAST(total_suites AS STRING) FROM test_summary), ' suites with ',
        (SELECT CAST(ROUND(overall_success_rate * 100, 2) AS STRING) FROM test_summary), '% success rate. ',
        'Average execution time: ', (SELECT CAST(ROUND(avg_execution_time, 0) AS STRING) FROM test_summary), 'ms. ',
        'Failure Patterns: ', COALESCE((SELECT STRING_AGG(CONCAT(test_suite, ' (', CAST(failure_count AS STRING), ' failures): ', common_errors), '; ') FROM failure_patterns), 'No significant failure patterns'), '. ',
        'Performance Issues: ', COALESCE((SELECT STRING_AGG(CONCAT(test_suite, ' avg: ', CAST(ROUND(avg_time, 0) AS STRING), 'ms'), '; ') FROM performance_issues), 'No performance issues detected'), '. ',
        'Provide specific recommendations for improving test reliability, performance, and coverage.'
      )
    )
  );
  
  -- Store insights
  INSERT INTO `enterprise_knowledge_ai.test_insights` (
    insight_id,
    insight_type,
    title,
    content,
    confidence_score,
    generated_at,
    metadata
  ) VALUES (
    GENERATE_UUID(),
    'test_analysis',
    'Daily Test Execution Analysis',
    insights_report,
    0.9,
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'analysis_date', CURRENT_DATE(),
      'data_sources', ['master_test_results', 'test_execution_summary'],
      'analysis_scope', 'comprehensive'
    )
  );
  
  -- Return the insights
  SELECT insights_report as test_insights;
  
END;

-- Create test insights storage table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_insights` (
  insight_id STRING NOT NULL,
  insight_type STRING NOT NULL,
  title STRING NOT NULL,
  content STRING NOT NULL,
  confidence_score FLOAT64,
  generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
) PARTITION BY DATE(generated_at)
CLUSTER BY insight_type;

-- Procedure to create test execution dashboard
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.create_test_dashboard`()
BEGIN
  -- Create or refresh the dashboard view with latest data
  CREATE OR REPLACE VIEW `enterprise_knowledge_ai.live_test_dashboard` AS
  WITH current_status AS (
    SELECT 
      'System Test Status' as dashboard_section,
      COUNT(DISTINCT execution_id) as total_executions_today,
      AVG(overall_success_rate) as avg_success_rate_today,
      MAX(execution_timestamp) as last_execution_time
    FROM `enterprise_knowledge_ai.test_execution_summary`
    WHERE DATE(execution_timestamp) = CURRENT_DATE()
  ),
  suite_status AS (
    SELECT 
      'Test Suite Performance' as dashboard_section,
      test_suite,
      COUNT(*) as tests_run,
      COUNTIF(test_status = 'PASSED') as tests_passed,
      SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) as success_rate,
      AVG(execution_time_ms) as avg_execution_time,
      CASE 
        WHEN SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) >= 0.95 THEN '🟢 Excellent'
        WHEN SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) >= 0.85 THEN '🟡 Good'
        WHEN SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) >= 0.70 THEN '🟠 Needs Attention'
        ELSE '🔴 Critical'
      END as status_indicator
    FROM `enterprise_knowledge_ai.master_test_results`
    WHERE DATE(execution_timestamp) = CURRENT_DATE()
    GROUP BY test_suite
  ),
  recent_failures AS (
    SELECT 
      'Recent Failures' as dashboard_section,
      test_suite,
      test_name,
      error_message,
      execution_timestamp
    FROM `enterprise_knowledge_ai.master_test_results`
    WHERE test_status = 'FAILED'
      AND DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 DAY)
    ORDER BY execution_timestamp DESC
    LIMIT 10
  ),
  performance_alerts AS (
    SELECT 
      'Performance Alerts' as dashboard_section,
      test_suite,
      COUNT(*) as slow_tests,
      AVG(execution_time_ms) as avg_slow_time
    FROM `enterprise_knowledge_ai.master_test_results`
    WHERE execution_time_ms > 15000  -- Tests taking more than 15 seconds
      AND DATE(execution_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    GROUP BY test_suite
    HAVING COUNT(*) > 0
  )
  SELECT 
    CURRENT_TIMESTAMP() as dashboard_updated_at,
    (SELECT AS STRUCT * FROM current_status) as system_status,
    ARRAY(SELECT AS STRUCT * FROM suite_status ORDER BY success_rate DESC) as suite_performance,
    ARRAY(SELECT AS STRUCT * FROM recent_failures) as recent_failures,
    ARRAY(SELECT AS STRUCT * FROM performance_alerts ORDER BY slow_tests DESC) as performance_alerts;
  
  -- Log dashboard creation
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id, component, message, log_level, timestamp
  ) VALUES (
    GENERATE_UUID(),
    'test_dashboard',
    'Test execution dashboard refreshed with latest data',
    'info',
    CURRENT_TIMESTAMP()
  );
  
END;