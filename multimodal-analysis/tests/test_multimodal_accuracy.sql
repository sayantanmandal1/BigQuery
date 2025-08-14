-- Tests for multimodal accuracy and correlation detection
-- Validates the accuracy and effectiveness of multimodal analysis components

-- Test setup: Create test data and validation framework
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.setup_multimodal_tests`()
BEGIN
  -- Create test validation table
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.multimodal_test_results` (
    test_id STRING,
    test_name STRING,
    test_type STRING,
    expected_result JSON,
    actual_result JSON,
    accuracy_score FLOAT64,
    passed BOOL,
    execution_time_ms INT64,
    created_at TIMESTAMP
  );
  
  -- Create sample test data for products
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_product_data` AS
  SELECT 
    'TEST_PROD_001' AS product_id,
    'High-quality wireless headphones with noise cancellation' AS specifications,
    'Premium audio device' AS description,
    299.99 AS price,
    'Electronics' AS category,
    'gs://test-bucket/headphones-premium.jpg' AS image_ref,
    1500 AS total_sales,
    4.5 AS avg_rating,
    0.05 AS return_rate
  UNION ALL
  SELECT 
    'TEST_PROD_002' AS product_id,
    'Budget smartphone with basic camera' AS specifications,
    'Entry-level mobile device' AS description,
    199.99 AS price,
    'Electronics' AS category,
    'gs://test-bucket/phone-budget.jpg' AS image_ref,
    800 AS total_sales,
    3.2 AS avg_rating,
    0.15 AS return_rate;
  
  -- Create sample test data for support tickets
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_support_data` AS
  SELECT 
    'TEST_TICKET_001' AS ticket_id,
    'Product arrived damaged - screen cracked' AS issue_description,
    'negative' AS customer_sentiment,
    'Replacement sent' AS resolution_notes,
    'resolved' AS status,
    'gs://test-bucket/damaged-screen.jpg' AS image_ref
  UNION ALL
  SELECT 
    'TEST_TICKET_002' AS ticket_id,
    'Battery not charging properly' AS issue_description,
    'neutral' AS customer_sentiment,
    'Troubleshooting steps provided' AS resolution_notes,
    'in_progress' AS status,
    'gs://test-bucket/battery-issue.jpg' AS image_ref;
END;

-- Test 1: Visual Content Analyzer Accuracy
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.test_visual_content_analyzer`()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_execution_time INT64;
  
  -- Test product image analysis
  WITH test_analysis AS (
    SELECT 
      'TEST_VISUAL_001' AS test_id,
      'Visual Content Analyzer - Product Analysis' AS test_name,
      'visual_analysis' AS test_type,
      `enterprise_knowledge_ai.analyze_product_image`(
        'TEST_PROD_001',
        'gs://test-bucket/headphones-premium.jpg',
        'High-quality wireless headphones with noise cancellation'
      ) AS actual_result
  ),
  
  validation AS (
    SELECT 
      *,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Evaluate if this product analysis is accurate and comprehensive: ',
          JSON_EXTRACT_SCALAR(actual_result, '$.analysis'),
          '. Should mention audio quality, design, and noise cancellation features.'
        )
      ) AS is_accurate,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate analysis quality from 0.0 to 1.0: ',
          JSON_EXTRACT_SCALAR(actual_result, '$.analysis')
        )
      ) AS quality_score
    FROM test_analysis
  )
  
  INSERT INTO multimodal_test_results
  SELECT 
    test_id,
    test_name,
    test_type,
    TO_JSON(STRUCT('expected_features' AS ['audio_quality', 'noise_cancellation', 'design_assessment'])),
    actual_result,
    quality_score AS accuracy_score,
    is_accurate AS passed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM validation;
  
  -- Test support image analysis
  SET test_start_time = CURRENT_TIMESTAMP();
  
  WITH support_test AS (
    SELECT 
      'TEST_VISUAL_002' AS test_id,
      'Visual Content Analyzer - Support Analysis' AS test_name,
      'support_analysis' AS test_type,
      `enterprise_knowledge_ai.analyze_support_image`(
        'TEST_TICKET_001',
        'gs://test-bucket/damaged-screen.jpg',
        'Product arrived damaged - screen cracked'
      ) AS actual_result
  ),
  
  support_validation AS (
    SELECT 
      *,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Does this support analysis correctly identify screen damage? ',
          JSON_EXTRACT_SCALAR(actual_result, '$.problem_analysis')
        )
      ) AS is_accurate,
      CAST(JSON_EXTRACT_SCALAR(actual_result, '$.severity_score') AS FLOAT64) AS severity_score
    FROM support_test
  )
  
  INSERT INTO multimodal_test_results
  SELECT 
    test_id,
    test_name,
    test_type,
    TO_JSON(STRUCT('expected_problem' AS 'screen_damage', 'expected_severity' AS 0.8)),
    actual_result,
    CASE WHEN severity_score BETWEEN 0.6 AND 1.0 THEN 1.0 ELSE 0.0 END AS accuracy_score,
    is_accurate AS passed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM support_validation;
END;

-- Test 2: Cross-Modal Correlation Accuracy
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.test_cross_modal_correlation`()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  
  -- Test product performance correlation
  WITH correlation_test AS (
    SELECT 
      'TEST_CORRELATION_001' AS test_id,
      'Cross-Modal Correlation - Product Performance' AS test_name,
      'correlation_analysis' AS test_type,
      `enterprise_knowledge_ai.correlate_product_performance`('TEST_PROD_001') AS actual_result
  ),
  
  correlation_validation AS (
    SELECT 
      *,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Does this correlation analysis properly connect visual features with sales performance? ',
          JSON_EXTRACT_SCALAR(actual_result, '$.performance_correlation')
        )
      ) AS correlation_valid,
      CAST(JSON_EXTRACT_SCALAR(actual_result, '$.visual_impact_score') AS FLOAT64) AS impact_score
    FROM correlation_test
  )
  
  INSERT INTO multimodal_test_results
  SELECT 
    test_id,
    test_name,
    test_type,
    TO_JSON(STRUCT('expected_correlation' AS 'positive', 'expected_impact_range' AS [0.6, 1.0])),
    actual_result,
    CASE WHEN impact_score BETWEEN 0.6 AND 1.0 THEN 1.0 ELSE 0.5 END AS accuracy_score,
    correlation_valid AS passed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM correlation_validation;
  
  -- Test pattern identification
  SET test_start_time = CURRENT_TIMESTAMP();
  
  WITH pattern_test AS (
    SELECT 
      'TEST_CORRELATION_002' AS test_id,
      'Cross-Modal Correlation - Pattern Detection' AS test_name,
      'pattern_detection' AS test_type,
      `enterprise_knowledge_ai.identify_cross_modal_patterns`() AS actual_result
  ),
  
  pattern_validation AS (
    SELECT 
      *,
      ARRAY_LENGTH(actual_result) AS pattern_count,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Do these patterns provide meaningful business insights? ',
          TO_JSON_STRING(actual_result)
        )
      ) AS patterns_meaningful
    FROM pattern_test
  )
  
  INSERT INTO multimodal_test_results
  SELECT 
    test_id,
    test_name,
    test_type,
    TO_JSON(STRUCT('expected_pattern_count' AS 3, 'expected_quality' AS 'high')),
    TO_JSON(STRUCT('patterns' AS actual_result, 'count' AS pattern_count)),
    CASE WHEN pattern_count >= 2 THEN 1.0 ELSE 0.5 END AS accuracy_score,
    patterns_meaningful AS passed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM pattern_validation;
END;

-- Test 3: Quality Control System Accuracy
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.test_quality_control_system`()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  
  -- Test product discrepancy detection
  WITH discrepancy_test AS (
    SELECT 
      'TEST_QUALITY_001' AS test_id,
      'Quality Control - Discrepancy Detection' AS test_name,
      'quality_control' AS test_type,
      `enterprise_knowledge_ai.detect_product_discrepancies`('TEST_PROD_001') AS actual_result
  ),
  
  quality_validation AS (
    SELECT 
      *,
      JSON_EXTRACT_SCALAR(actual_result, '$.has_discrepancies') AS has_discrepancies,
      CAST(JSON_EXTRACT_SCALAR(actual_result, '$.severity_score') AS FLOAT64) AS severity_score,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Is this quality assessment reasonable? ',
          JSON_EXTRACT_SCALAR(actual_result, '$.discrepancy_details')
        )
      ) AS assessment_reasonable
    FROM discrepancy_test
  )
  
  INSERT INTO multimodal_test_results
  SELECT 
    test_id,
    test_name,
    test_type,
    TO_JSON(STRUCT('expected_discrepancies' AS false, 'expected_severity_range' AS [0.0, 0.3])),
    actual_result,
    CASE 
      WHEN severity_score <= 0.3 THEN 1.0 
      WHEN severity_score <= 0.5 THEN 0.7
      ELSE 0.4 
    END AS accuracy_score,
    assessment_reasonable AS passed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM quality_validation;
END;

-- Test 4: Comprehensive Analysis Integration
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.test_comprehensive_analysis`()
BEGIN
  DECLARE test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  
  -- Test comprehensive product analysis
  WITH comprehensive_test AS (
    SELECT 
      'TEST_COMPREHENSIVE_001' AS test_id,
      'Comprehensive Analysis - Product Integration' AS test_name,
      'comprehensive_analysis' AS test_type,
      `enterprise_knowledge_ai.comprehensive_product_analysis`('TEST_PROD_001') AS actual_result
  ),
  
  comprehensive_validation AS (
    SELECT 
      *,
      CAST(JSON_EXTRACT_SCALAR(actual_result, '$.success_potential_score') AS FLOAT64) AS success_score,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Does this comprehensive analysis integrate visual, sales, and market data effectively? ',
          JSON_EXTRACT_SCALAR(actual_result, '$.comprehensive_analysis')
        )
      ) AS integration_effective,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate the actionability of these recommendations from 0.0 to 1.0: ',
          JSON_EXTRACT_SCALAR(actual_result, '$.improvement_recommendations')
        )
      ) AS actionability_score
    FROM comprehensive_test
  )
  
  INSERT INTO multimodal_test_results
  SELECT 
    test_id,
    test_name,
    test_type,
    TO_JSON(STRUCT('expected_integration' AS true, 'expected_actionability' AS 0.7)),
    actual_result,
    (success_score + actionability_score) / 2 AS accuracy_score,
    integration_effective AS passed,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), test_start_time, MILLISECOND) AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM comprehensive_validation;
END;

-- Master test runner procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.run_multimodal_tests`()
BEGIN
  -- Setup test environment
  CALL `enterprise_knowledge_ai.setup_multimodal_tests`();
  
  -- Run all test suites
  CALL `enterprise_knowledge_ai.test_visual_content_analyzer`();
  CALL `enterprise_knowledge_ai.test_cross_modal_correlation`();
  CALL `enterprise_knowledge_ai.test_quality_control_system`();
  CALL `enterprise_knowledge_ai.test_comprehensive_analysis`();
  
  -- Generate test summary report
  WITH test_summary AS (
    SELECT 
      test_type,
      COUNT(*) AS total_tests,
      COUNTIF(passed) AS passed_tests,
      AVG(accuracy_score) AS avg_accuracy,
      AVG(execution_time_ms) AS avg_execution_time
    FROM multimodal_test_results
    WHERE DATE(created_at) = CURRENT_DATE()
    GROUP BY test_type
  )
  SELECT 
    'MULTIMODAL TEST SUMMARY' AS report_title,
    test_type,
    total_tests,
    passed_tests,
    ROUND(passed_tests / total_tests * 100, 2) AS pass_rate_percent,
    ROUND(avg_accuracy, 3) AS average_accuracy,
    ROUND(avg_execution_time, 0) AS avg_time_ms
  FROM test_summary
  ORDER BY pass_rate_percent DESC;
  
  -- Generate detailed test report
  SELECT 
    test_name,
    test_type,
    CASE WHEN passed THEN 'PASS' ELSE 'FAIL' END AS status,
    ROUND(accuracy_score, 3) AS accuracy,
    execution_time_ms AS time_ms,
    created_at
  FROM multimodal_test_results
  WHERE DATE(created_at) = CURRENT_DATE()
  ORDER BY test_type, test_name;
END;