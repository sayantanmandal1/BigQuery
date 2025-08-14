-- Comprehensive Test Suite Runner for Personalized Intelligence Engine
-- Executes all personalization tests and generates summary report

-- Create test results table if it doesn't exist
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.test_results` (
  test_name STRING NOT NULL,
  pass_count INT64,
  total_tests INT64,
  success_rate FLOAT64,
  test_timestamp TIMESTAMP,
  additional_metrics JSON,
  execution_time_ms INT64
);

-- Main test execution procedure
CREATE OR REPLACE PROCEDURE run_all_personalization_tests()
BEGIN
  DECLARE start_time TIMESTAMP;
  DECLARE end_time TIMESTAMP;
  DECLARE total_execution_time INT64;
  
  SET start_time = CURRENT_TIMESTAMP();
  
  -- Clear previous test results
  DELETE FROM `enterprise_knowledge_ai.test_results` 
  WHERE test_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY);
  
  SELECT 'Starting Personalized Intelligence Engine Test Suite...' as status;
  
  -- Setup test environment
  SELECT 'Setting up test environment...' as status;
  CALL setup_personalization_tests();
  CALL setup_satisfaction_tests();
  
  -- Execute personalization accuracy tests
  SELECT 'Running personalization accuracy tests...' as status;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_role_based_filtering();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'role_based_filtering' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_preference_learning();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'preference_learning' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_priority_scoring();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'priority_scoring' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_personalized_content_generation();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'personalized_content_generation' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_end_to_end_personalization();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'end_to_end_personalization' 
      AND test_timestamp >= test_start;
  END;
  
  -- Execute user satisfaction tests
  SELECT 'Running user satisfaction tests...' as status;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_relevance_satisfaction();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'relevance_satisfaction' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_timeliness_satisfaction();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'timeliness_satisfaction' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_actionability_satisfaction();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'actionability_satisfaction' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_overall_satisfaction();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'overall_satisfaction' 
      AND test_timestamp >= test_start;
  END;
  
  BEGIN
    DECLARE test_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    CALL test_engagement_metrics();
    UPDATE `enterprise_knowledge_ai.test_results` 
    SET execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start, MILLISECOND)
    WHERE test_name = 'engagement_metrics' 
      AND test_timestamp >= test_start;
  END;
  
  -- Generate comprehensive test report
  SET end_time = CURRENT_TIMESTAMP();
  SET total_execution_time = TIMESTAMP_DIFF(end_time, start_time, MILLISECOND);
  
  SELECT 'Generating test report...' as status;
  
  -- Summary report
  WITH test_summary AS (
    SELECT 
      COUNT(*) as total_test_suites,
      SUM(pass_count) as total_passed,
      SUM(total_tests) as total_executed,
      AVG(success_rate) as avg_success_rate,
      SUM(execution_time_ms) as total_test_time_ms
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_timestamp >= start_time
  ),
  detailed_results AS (
    SELECT 
      test_name,
      CONCAT(CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING)) as pass_ratio,
      ROUND(success_rate * 100, 1) as success_percentage,
      execution_time_ms,
      CASE 
        WHEN success_rate >= 0.9 THEN '✅ EXCELLENT'
        WHEN success_rate >= 0.8 THEN '✅ GOOD'
        WHEN success_rate >= 0.7 THEN '⚠️ ACCEPTABLE'
        ELSE '❌ NEEDS IMPROVEMENT'
      END as status
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_timestamp >= start_time
    ORDER BY success_rate DESC
  )
  SELECT 
    '=== PERSONALIZED INTELLIGENCE ENGINE TEST REPORT ===' as report_header,
    CURRENT_TIMESTAMP() as report_timestamp,
    total_execution_time as total_execution_time_ms,
    ts.total_test_suites,
    ts.total_passed,
    ts.total_executed,
    ROUND(ts.avg_success_rate * 100, 1) as overall_success_percentage,
    CASE 
      WHEN ts.avg_success_rate >= 0.9 THEN '✅ SYSTEM READY FOR PRODUCTION'
      WHEN ts.avg_success_rate >= 0.8 THEN '✅ SYSTEM READY WITH MINOR OPTIMIZATIONS'
      WHEN ts.avg_success_rate >= 0.7 THEN '⚠️ SYSTEM NEEDS IMPROVEMENTS'
      ELSE '❌ SYSTEM NOT READY - MAJOR ISSUES DETECTED'
    END as overall_status
  FROM test_summary ts;
  
  -- Detailed test results
  SELECT 
    test_name,
    pass_ratio,
    success_percentage,
    execution_time_ms,
    status
  FROM detailed_results;
  
  -- Performance metrics
  WITH performance_metrics AS (
    SELECT 
      'Relevance Satisfaction' as metric_name,
      ROUND(CAST(JSON_EXTRACT_SCALAR(additional_metrics, '$.avg_relevance_score') AS FLOAT64), 3) as score,
      'Higher is better (0.0-1.0)' as description
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_name = 'relevance_satisfaction'
      AND test_timestamp >= start_time
    
    UNION ALL
    
    SELECT 
      'Timeliness Satisfaction',
      ROUND(CAST(JSON_EXTRACT_SCALAR(additional_metrics, '$.avg_timeliness_score') AS FLOAT64), 3),
      'Higher is better (0.0-1.0)'
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_name = 'timeliness_satisfaction'
      AND test_timestamp >= start_time
    
    UNION ALL
    
    SELECT 
      'Actionability Satisfaction',
      ROUND(CAST(JSON_EXTRACT_SCALAR(additional_metrics, '$.avg_actionability_score') AS FLOAT64), 3),
      'Higher is better (0.0-1.0)'
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_name = 'actionability_satisfaction'
      AND test_timestamp >= start_time
    
    UNION ALL
    
    SELECT 
      'Overall Satisfaction',
      ROUND(CAST(JSON_EXTRACT_SCALAR(additional_metrics, '$.overall_satisfaction') AS FLOAT64), 3),
      'Higher is better (0.0-1.0)'
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_name = 'overall_satisfaction'
      AND test_timestamp >= start_time
    
    UNION ALL
    
    SELECT 
      'User Engagement',
      ROUND(CAST(JSON_EXTRACT_SCALAR(additional_metrics, '$.avg_engagement_score') AS FLOAT64), 3),
      'Higher is better (0.0-1.0)'
    FROM `enterprise_knowledge_ai.test_results`
    WHERE test_name = 'engagement_metrics'
      AND test_timestamp >= start_time
  )
  SELECT 
    '=== PERFORMANCE METRICS ===' as metrics_header,
    metric_name,
    score,
    description,
    CASE 
      WHEN score >= 0.8 THEN '✅ EXCELLENT'
      WHEN score >= 0.7 THEN '✅ GOOD'
      WHEN score >= 0.6 THEN '⚠️ ACCEPTABLE'
      ELSE '❌ NEEDS IMPROVEMENT'
    END as performance_status
  FROM performance_metrics
  WHERE score IS NOT NULL;
  
  -- Cleanup test data
  SELECT 'Cleaning up test environment...' as status;
  CALL cleanup_personalization_tests();
  CALL cleanup_satisfaction_tests();
  
  SELECT 'Test suite completed successfully!' as final_status;
  
END;

-- Quick test runner for development
CREATE OR REPLACE PROCEDURE run_quick_personalization_tests()
BEGIN
  SELECT 'Running quick personalization tests...' as status;
  
  -- Setup minimal test environment
  CALL setup_personalization_tests();
  
  -- Run core functionality tests only
  CALL test_role_based_filtering();
  CALL test_priority_scoring();
  CALL test_personalized_content_generation();
  
  -- Show quick results
  SELECT 
    test_name,
    CONCAT(CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING)) as results,
    ROUND(success_rate * 100, 1) as success_rate_pct
  FROM `enterprise_knowledge_ai.test_results`
  WHERE test_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
  ORDER BY test_timestamp DESC;
  
  -- Cleanup
  CALL cleanup_personalization_tests();
  
  SELECT 'Quick tests completed!' as status;
  
END;

-- Performance benchmark test
CREATE OR REPLACE PROCEDURE benchmark_personalization_performance()
BEGIN
  DECLARE start_time TIMESTAMP;
  DECLARE end_time TIMESTAMP;
  DECLARE processing_time_ms INT64;
  
  SELECT 'Starting performance benchmark...' as status;
  
  -- Test large-scale personalization performance
  SET start_time = CURRENT_TIMESTAMP();
  
  -- Generate personalized content for multiple users simultaneously
  CALL generate_personalized_content_feed('test_exec_001', 50);
  CALL generate_personalized_content_feed('test_manager_001', 50);
  CALL generate_personalized_content_feed('test_analyst_001', 50);
  
  SET end_time = CURRENT_TIMESTAMP();
  SET processing_time_ms = TIMESTAMP_DIFF(end_time, start_time, MILLISECOND);
  
  -- Record benchmark results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp, additional_metrics)
  VALUES ('performance_benchmark', 1, 1, 1.0, CURRENT_TIMESTAMP(), 
          JSON_OBJECT('processing_time_ms', processing_time_ms, 'users_processed', 3, 'items_per_user', 50));
  
  SELECT 
    'Performance Benchmark Results' as benchmark_type,
    processing_time_ms,
    ROUND(processing_time_ms / 3.0, 2) as avg_time_per_user_ms,
    CASE 
      WHEN processing_time_ms <= 5000 THEN '✅ EXCELLENT (<5s)'
      WHEN processing_time_ms <= 10000 THEN '✅ GOOD (<10s)'
      WHEN processing_time_ms <= 20000 THEN '⚠️ ACCEPTABLE (<20s)'
      ELSE '❌ TOO SLOW (>20s)'
    END as performance_rating;
    
END;