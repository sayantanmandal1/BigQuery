-- Advanced tests for correlation detection between different modalities
-- Validates the accuracy of cross-modal relationship identification

-- Test correlation detection accuracy with known relationships
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.test_correlation_accuracy`()
BEGIN
  -- Create test scenarios with known correlations
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.correlation_test_scenarios` AS
  SELECT 
    'SCENARIO_001' AS scenario_id,
    'High visual appeal should correlate with high sales' AS scenario_description,
    'TEST_PROD_HIGH_APPEAL' AS product_id,
    'Sleek modern design with premium materials' AS visual_features,
    2500 AS sales_volume,
    4.8 AS customer_rating,
    0.02 AS return_rate,
    'positive' AS expected_correlation
  UNION ALL
  SELECT 
    'SCENARIO_002' AS scenario_id,
    'Poor visual quality should correlate with high returns' AS scenario_description,
    'TEST_PROD_POOR_QUALITY' AS product_id,
    'Cheap plastic construction, visible defects' AS visual_features,
    300 AS sales_volume,
    2.1 AS customer_rating,
    0.35 AS return_rate,
    'negative' AS expected_correlation
  UNION ALL
  SELECT 
    'SCENARIO_003' AS scenario_id,
    'Professional appearance should correlate with business segment sales' AS scenario_description,
    'TEST_PROD_PROFESSIONAL' AS product_id,
    'Clean professional design suitable for office use' AS visual_features,
    1800 AS sales_volume,
    4.2 AS customer_rating,
    0.08 AS return_rate,
    'business_segment' AS expected_correlation;
  
  -- Test each correlation scenario
  WITH correlation_tests AS (
    SELECT 
      s.scenario_id,
      s.scenario_description,
      s.expected_correlation,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Analyze correlation between visual features and performance metrics: ',
          'Visual: ', s.visual_features,
          ', Sales: ', CAST(s.sales_volume AS STRING),
          ', Rating: ', CAST(s.customer_rating AS STRING),
          ', Returns: ', CAST(s.return_rate AS STRING),
          '. Identify the correlation type and strength.'
        )
      ) AS correlation_analysis,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate correlation strength from 0.0 (no correlation) to 1.0 (perfect correlation): ',
          'Visual features: ', s.visual_features,
          ', Performance metrics: Sales=', CAST(s.sales_volume AS STRING),
          ', Rating=', CAST(s.customer_rating AS STRING)
        )
      ) AS correlation_strength,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Is this a positive correlation between visual appeal and performance? ',
          'Features: ', s.visual_features,
          ', Sales: ', CAST(s.sales_volume AS STRING),
          ', Rating: ', CAST(s.customer_rating AS STRING)
        )
      ) AS is_positive_correlation
    FROM correlation_test_scenarios s
  ),
  
  validation_results AS (
    SELECT 
      *,
      CASE 
        WHEN expected_correlation = 'positive' AND is_positive_correlation = true THEN 1.0
        WHEN expected_correlation = 'negative' AND is_positive_correlation = false THEN 1.0
        WHEN expected_correlation = 'business_segment' AND correlation_strength > 0.6 THEN 1.0
        ELSE 0.0
      END AS accuracy_score,
      CASE 
        WHEN expected_correlation = 'positive' AND is_positive_correlation = true THEN true
        WHEN expected_correlation = 'negative' AND is_positive_correlation = false THEN true
        WHEN expected_correlation = 'business_segment' AND correlation_strength > 0.6 THEN true
        ELSE false
      END AS test_passed
    FROM correlation_tests
  )
  
  INSERT INTO multimodal_test_results (
    test_id,
    test_name,
    test_type,
    expected_result,
    actual_result,
    accuracy_score,
    passed,
    execution_time_ms,
    created_at
  )
  SELECT 
    scenario_id AS test_id,
    CONCAT('Correlation Detection - ', scenario_description) AS test_name,
    'correlation_detection' AS test_type,
    TO_JSON(STRUCT(expected_correlation AS expected_type, 0.8 AS expected_strength)) AS expected_result,
    TO_JSON(STRUCT(
      correlation_analysis,
      correlation_strength,
      is_positive_correlation
    )) AS actual_result,
    accuracy_score,
    test_passed AS passed,
    500 AS execution_time_ms,  -- Estimated
    CURRENT_TIMESTAMP() AS created_at
  FROM validation_results;
END;

-- Test multimodal consistency detection
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.test_multimodal_consistency`()
BEGIN
  -- Create test cases for consistency checking
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.consistency_test_cases` AS
  SELECT 
    'CONSISTENCY_001' AS test_id,
    'Product specs match visual appearance' AS test_description,
    'Premium leather wallet' AS text_description,
    'High-quality leather construction with fine stitching' AS visual_analysis,
    true AS expected_consistency
  UNION ALL
  SELECT 
    'CONSISTENCY_002' AS test_id,
    'Product specs contradict visual appearance' AS test_description,
    'Premium metal construction' AS text_description,
    'Plastic construction with visible seams' AS visual_analysis,
    false AS expected_consistency
  UNION ALL
  SELECT 
    'CONSISTENCY_003' AS test_id,
    'Support ticket matches visual evidence' AS test_description,
    'Screen is completely black, no display' AS text_description,
    'Device screen shows no illumination, appears damaged' AS visual_analysis,
    true AS expected_consistency;
  
  -- Test consistency detection
  WITH consistency_tests AS (
    SELECT 
      t.test_id,
      t.test_description,
      t.expected_consistency,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Are these descriptions consistent with each other? ',
          'Text description: ', t.text_description,
          ', Visual analysis: ', t.visual_analysis
        )
      ) AS detected_consistency,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate consistency level from 0.0 (completely inconsistent) to 1.0 (perfectly consistent): ',
          'Text: ', t.text_description,
          ', Visual: ', t.visual_analysis
        )
      ) AS consistency_score
    FROM consistency_test_cases t
  ),
  
  consistency_validation AS (
    SELECT 
      *,
      CASE 
        WHEN expected_consistency = detected_consistency THEN 1.0
        ELSE 0.0
      END AS accuracy_score,
      expected_consistency = detected_consistency AS test_passed
    FROM consistency_tests
  )
  
  INSERT INTO multimodal_test_results (
    test_id,
    test_name,
    test_type,
    expected_result,
    actual_result,
    accuracy_score,
    passed,
    execution_time_ms,
    created_at
  )
  SELECT 
    test_id,
    CONCAT('Consistency Detection - ', test_description) AS test_name,
    'consistency_detection' AS test_type,
    TO_JSON(STRUCT(expected_consistency)) AS expected_result,
    TO_JSON(STRUCT(
      detected_consistency,
      consistency_score
    )) AS actual_result,
    accuracy_score,
    test_passed AS passed,
    300 AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM consistency_validation;
END;

-- Test cross-modal insight generation quality
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.test_insight_generation_quality`()
BEGIN
  -- Test insight quality across different modalities
  WITH insight_quality_tests AS (
    SELECT 
      'INSIGHT_QUALITY_001' AS test_id,
      'Product recommendation insight quality' AS test_name,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Generate product improvement recommendations based on: ',
          'Visual analysis: Modern design but poor material quality, ',
          'Sales data: 1200 units sold, 3.2 rating, 18% return rate, ',
          'Customer feedback: Complaints about durability'
        )
      ) AS generated_insight
    UNION ALL
    SELECT 
      'INSIGHT_QUALITY_002' AS test_id,
      'Customer journey insight quality' AS test_name,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Generate customer retention strategy based on: ',
          'Purchase history: 5 orders, electronics category, ',
          'Support interactions: 2 tickets with product images showing wear, ',
          'Satisfaction: 3.8/5 average rating'
        )
      ) AS generated_insight
    UNION ALL
    SELECT 
      'INSIGHT_QUALITY_003' AS test_id,
      'Market trend insight quality' AS test_name,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Generate market trend analysis based on: ',
          'Visual trends: Shift toward minimalist design, ',
          'Sales patterns: 25% increase in premium segment, ',
          'Customer preferences: Higher ratings for sustainable materials'
        )
      ) AS generated_insight
  ),
  
  insight_evaluation AS (
    SELECT 
      *,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate insight quality from 0.0 to 1.0 based on actionability, specificity, and business value: ',
          generated_insight
        )
      ) AS quality_score,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Does this insight provide specific, actionable recommendations? ',
          generated_insight
        )
      ) AS is_actionable,
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Does this insight integrate multiple data sources effectively? ',
          generated_insight
        )
      ) AS integrates_sources
    FROM insight_quality_tests
  )
  
  INSERT INTO multimodal_test_results (
    test_id,
    test_name,
    test_type,
    expected_result,
    actual_result,
    accuracy_score,
    passed,
    execution_time_ms,
    created_at
  )
  SELECT 
    test_id,
    test_name,
    'insight_quality' AS test_type,
    TO_JSON(STRUCT(
      'expected_quality_threshold' AS 0.7,
      'expected_actionable' AS true,
      'expected_integration' AS true
    )) AS expected_result,
    TO_JSON(STRUCT(
      generated_insight,
      quality_score,
      is_actionable,
      integrates_sources
    )) AS actual_result,
    quality_score AS accuracy_score,
    (quality_score >= 0.7 AND is_actionable AND integrates_sources) AS passed,
    800 AS execution_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM insight_evaluation;
END;

-- Performance benchmarking for correlation detection
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.benchmark_correlation_performance`()
BEGIN
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE batch_size INT64 DEFAULT 100;
  DECLARE total_processed INT64 DEFAULT 0;
  
  -- Benchmark batch processing performance
  WITH performance_test AS (
    SELECT 
      'PERFORMANCE_001' AS test_id,
      'Batch Correlation Processing' AS test_name,
      COUNT(*) AS items_processed,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, MILLISECOND) AS processing_time_ms
    FROM (
      SELECT 
        p.product_id,
        `enterprise_knowledge_ai.correlate_product_performance`(p.product_id) AS correlation_result
      FROM product_catalog_objects p
      LIMIT batch_size
    )
  ),
  
  performance_metrics AS (
    SELECT 
      *,
      ROUND(items_processed / (processing_time_ms / 1000.0), 2) AS items_per_second,
      ROUND(processing_time_ms / items_processed, 2) AS avg_time_per_item_ms
    FROM performance_test
  )
  
  INSERT INTO multimodal_test_results (
    test_id,
    test_name,
    test_type,
    expected_result,
    actual_result,
    accuracy_score,
    passed,
    execution_time_ms,
    created_at
  )
  SELECT 
    test_id,
    test_name,
    'performance_benchmark' AS test_type,
    TO_JSON(STRUCT(
      'expected_min_throughput' AS 10.0,
      'expected_max_time_per_item' AS 1000
    )) AS expected_result,
    TO_JSON(STRUCT(
      items_processed,
      processing_time_ms,
      items_per_second,
      avg_time_per_item_ms
    )) AS actual_result,
    CASE 
      WHEN items_per_second >= 10.0 THEN 1.0
      WHEN items_per_second >= 5.0 THEN 0.7
      ELSE 0.4
    END AS accuracy_score,
    (items_per_second >= 10.0 AND avg_time_per_item_ms <= 1000) AS passed,
    processing_time_ms,
    CURRENT_TIMESTAMP() AS created_at
  FROM performance_metrics;
END;

-- Master correlation detection test runner
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.run_correlation_detection_tests`()
BEGIN
  -- Run all correlation detection tests
  CALL `enterprise_knowledge_ai.test_correlation_accuracy`();
  CALL `enterprise_knowledge_ai.test_multimodal_consistency`();
  CALL `enterprise_knowledge_ai.test_insight_generation_quality`();
  CALL `enterprise_knowledge_ai.benchmark_correlation_performance`();
  
  -- Generate correlation detection test summary
  WITH correlation_test_summary AS (
    SELECT 
      'CORRELATION_DETECTION_SUMMARY' AS report_type,
      COUNT(*) AS total_tests,
      COUNTIF(passed) AS passed_tests,
      ROUND(AVG(accuracy_score), 3) AS avg_accuracy,
      ROUND(AVG(execution_time_ms), 0) AS avg_execution_time,
      MIN(accuracy_score) AS min_accuracy,
      MAX(accuracy_score) AS max_accuracy
    FROM multimodal_test_results
    WHERE test_type IN ('correlation_detection', 'consistency_detection', 'insight_quality', 'performance_benchmark')
      AND DATE(created_at) = CURRENT_DATE()
  )
  SELECT 
    report_type,
    total_tests,
    passed_tests,
    ROUND(passed_tests / total_tests * 100, 1) AS pass_rate_percent,
    avg_accuracy,
    avg_execution_time,
    min_accuracy,
    max_accuracy
  FROM correlation_test_summary;
  
  -- Detailed results by test type
  SELECT 
    test_type,
    COUNT(*) AS test_count,
    COUNTIF(passed) AS passed_count,
    ROUND(AVG(accuracy_score), 3) AS avg_accuracy,
    ROUND(STDDEV(accuracy_score), 3) AS accuracy_stddev
  FROM multimodal_test_results
  WHERE test_type IN ('correlation_detection', 'consistency_detection', 'insight_quality', 'performance_benchmark')
    AND DATE(created_at) = CURRENT_DATE()
  GROUP BY test_type
  ORDER BY avg_accuracy DESC;
END;