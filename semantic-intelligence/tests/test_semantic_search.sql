-- Unit Tests for Semantic Intelligence Engine
-- This script contains comprehensive tests for semantic search accuracy and performance

-- Create test dataset for semantic search validation
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.test_documents` (
  test_id STRING NOT NULL,
  content STRING NOT NULL,
  expected_category STRING NOT NULL,
  ground_truth_queries ARRAY<STRING>,
  expected_similarity_threshold FLOAT64
);

-- Insert test data for validation
INSERT INTO `enterprise_knowledge_ai.test_documents` VALUES
('test_001', 'Our quarterly financial results show a 15% increase in revenue driven by strong performance in the cloud services division. Operating margins improved to 22% due to cost optimization initiatives.', 'financial', ['financial results', 'revenue growth', 'quarterly earnings', 'cloud services performance'], 0.7),
('test_002', 'The new microservices architecture implementation has reduced system latency by 40% and improved scalability. We migrated from monolithic to containerized services using Kubernetes orchestration.', 'technical', ['microservices architecture', 'system performance', 'kubernetes deployment', 'scalability improvements'], 0.7),
('test_003', 'Customer satisfaction scores increased to 4.2/5.0 following the launch of our new mobile application. User engagement metrics show 35% higher retention rates compared to the previous quarter.', 'customer_experience', ['customer satisfaction', 'mobile app launch', 'user engagement', 'retention metrics'], 0.7),
('test_004', 'Strategic partnership with TechCorp will expand our market presence in the Asia-Pacific region. The collaboration includes joint product development and shared distribution channels.', 'strategic', ['strategic partnership', 'market expansion', 'Asia-Pacific', 'joint development'], 0.7),
('test_005', 'Employee productivity metrics indicate a 20% improvement following the implementation of flexible work arrangements. Remote work adoption reached 75% across all departments.', 'operational', ['employee productivity', 'flexible work', 'remote work', 'operational efficiency'], 0.7);

-- Test function for embedding generation accuracy
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.test_embedding_generation`()
RETURNS STRUCT<
  test_name STRING,
  total_tests INT64,
  passed_tests INT64,
  failed_tests INT64,
  success_rate FLOAT64,
  test_details ARRAY<STRUCT<test_case STRING, status STRING, details STRING>>
>
LANGUAGE SQL
AS (
  WITH 
  embedding_tests AS (
    SELECT 
      test_id,
      content,
      `enterprise_knowledge_ai.generate_enhanced_embedding`(content, 'document') as embedding_result
    FROM `enterprise_knowledge_ai.test_documents`
  ),
  test_results AS (
    SELECT 
      test_id,
      CASE 
        WHEN embedding_result.embedding IS NOT NULL 
             AND ARRAY_LENGTH(embedding_result.embedding) > 0
             AND embedding_result.embedding_quality_score > 0.5
        THEN 'PASSED'
        ELSE 'FAILED'
      END as test_status,
      CONCAT(
        'Embedding length: ', CAST(COALESCE(ARRAY_LENGTH(embedding_result.embedding), 0) AS STRING),
        ', Quality score: ', CAST(embedding_result.embedding_quality_score AS STRING)
      ) as test_details
    FROM embedding_tests
  )
  SELECT AS STRUCT
    'Embedding Generation Test' as test_name,
    COUNT(*) as total_tests,
    COUNTIF(test_status = 'PASSED') as passed_tests,
    COUNTIF(test_status = 'FAILED') as failed_tests,
    SAFE_DIVIDE(COUNTIF(test_status = 'PASSED'), COUNT(*)) as success_rate,
    ARRAY_AGG(STRUCT(test_id as test_case, test_status as status, test_details as details)) as test_details
  FROM test_results
);

-- Test function for semantic search accuracy
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.test_semantic_search_accuracy`()
RETURNS STRUCT<
  test_name STRING,
  total_queries INT64,
  accurate_results INT64,
  accuracy_rate FLOAT64,
  average_top1_similarity FLOAT64,
  test_details ARRAY<STRUCT<
    query STRING,
    expected_category STRING,
    top_result_category STRING,
    similarity_score FLOAT64,
    is_accurate BOOL
  >>
>
LANGUAGE SQL
AS (
  WITH 
  test_queries AS (
    SELECT 
      td.expected_category,
      query,
      td.expected_similarity_threshold
    FROM `enterprise_knowledge_ai.test_documents` td
    CROSS JOIN UNNEST(td.ground_truth_queries) as query
  ),
  search_results AS (
    SELECT 
      tq.query,
      tq.expected_category,
      tq.expected_similarity_threshold,
      sr.content,
      sr.similarity_score,
      -- Extract category from content (simplified classification)
      CASE 
        WHEN UPPER(sr.content) LIKE '%FINANCIAL%' OR UPPER(sr.content) LIKE '%REVENUE%' OR UPPER(sr.content) LIKE '%MARGIN%' THEN 'financial'
        WHEN UPPER(sr.content) LIKE '%TECHNICAL%' OR UPPER(sr.content) LIKE '%ARCHITECTURE%' OR UPPER(sr.content) LIKE '%SYSTEM%' THEN 'technical'
        WHEN UPPER(sr.content) LIKE '%CUSTOMER%' OR UPPER(sr.content) LIKE '%SATISFACTION%' OR UPPER(sr.content) LIKE '%USER%' THEN 'customer_experience'
        WHEN UPPER(sr.content) LIKE '%STRATEGIC%' OR UPPER(sr.content) LIKE '%PARTNERSHIP%' OR UPPER(sr.content) LIKE '%MARKET%' THEN 'strategic'
        WHEN UPPER(sr.content) LIKE '%EMPLOYEE%' OR UPPER(sr.content) LIKE '%PRODUCTIVITY%' OR UPPER(sr.content) LIKE '%OPERATIONAL%' THEN 'operational'
        ELSE 'unknown'
      END as detected_category,
      ROW_NUMBER() OVER (PARTITION BY tq.query ORDER BY sr.similarity_score DESC) as result_rank
    FROM test_queries tq
    CROSS JOIN `enterprise_knowledge_ai.semantic_search`(tq.query, 5, NULL, NULL, 0.0) sr
  ),
  accuracy_analysis AS (
    SELECT 
      query,
      expected_category,
      detected_category as top_result_category,
      similarity_score,
      expected_category = detected_category as is_accurate
    FROM search_results
    WHERE result_rank = 1
  )
  SELECT AS STRUCT
    'Semantic Search Accuracy Test' as test_name,
    COUNT(*) as total_queries,
    COUNTIF(is_accurate) as accurate_results,
    SAFE_DIVIDE(COUNTIF(is_accurate), COUNT(*)) as accuracy_rate,
    AVG(similarity_score) as average_top1_similarity,
    ARRAY_AGG(STRUCT(
      query,
      expected_category,
      top_result_category,
      similarity_score,
      is_accurate
    )) as test_details
  FROM accuracy_analysis
);

-- Performance test for vector search operations
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.test_search_performance`()
RETURNS STRUCT<
  test_name STRING,
  total_queries INT64,
  average_response_time_ms FLOAT64,
  min_response_time_ms FLOAT64,
  max_response_time_ms FLOAT64,
  queries_under_1000ms INT64,
  performance_grade STRING
>
LANGUAGE SQL
AS (
  WITH 
  performance_queries AS (
    SELECT 
      'financial performance metrics' as query
    UNION ALL SELECT 'technical architecture documentation'
    UNION ALL SELECT 'customer satisfaction analysis'
    UNION ALL SELECT 'strategic business planning'
    UNION ALL SELECT 'operational efficiency improvements'
    UNION ALL SELECT 'market research insights'
    UNION ALL SELECT 'product development roadmap'
    UNION ALL SELECT 'competitive analysis report'
    UNION ALL SELECT 'risk management framework'
    UNION ALL SELECT 'innovation strategy overview'
  ),
  timed_searches AS (
    SELECT 
      pq.query,
      EXTRACT(MILLISECOND FROM CURRENT_TIMESTAMP()) as start_time,
      (
        SELECT COUNT(*)
        FROM `enterprise_knowledge_ai.semantic_search`(pq.query, 10, NULL, NULL, 0.3)
      ) as result_count,
      EXTRACT(MILLISECOND FROM CURRENT_TIMESTAMP()) as end_time
    FROM performance_queries pq
  ),
  performance_metrics AS (
    SELECT 
      query,
      result_count,
      ABS(end_time - start_time) as response_time_ms
    FROM timed_searches
  )
  SELECT AS STRUCT
    'Search Performance Test' as test_name,
    COUNT(*) as total_queries,
    AVG(response_time_ms) as average_response_time_ms,
    MIN(response_time_ms) as min_response_time_ms,
    MAX(response_time_ms) as max_response_time_ms,
    COUNTIF(response_time_ms < 1000) as queries_under_1000ms,
    CASE 
      WHEN AVG(response_time_ms) < 500 THEN 'EXCELLENT'
      WHEN AVG(response_time_ms) < 1000 THEN 'GOOD'
      WHEN AVG(response_time_ms) < 2000 THEN 'ACCEPTABLE'
      ELSE 'NEEDS_IMPROVEMENT'
    END as performance_grade
  FROM performance_metrics
);

-- Test function for context synthesis quality
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.test_context_synthesis`()
RETURNS STRUCT<
  test_name STRING,
  synthesis_tests INT64,
  successful_syntheses INT64,
  average_confidence FLOAT64,
  average_source_count FLOAT64,
  quality_grade STRING
>
LANGUAGE SQL
AS (
  WITH 
  test_scenarios AS (
    SELECT 
      'Analyze quarterly business performance across all departments' as synthesis_prompt,
      ARRAY[
        STRUCT('Q3 revenue increased 15% with strong cloud services growth' as content, 'financial_report' as source, 0.9 as confidence),
        STRUCT('Customer satisfaction improved to 4.2/5 following mobile app launch' as content, 'customer_survey' as source, 0.8 as confidence),
        STRUCT('Technical infrastructure migration completed successfully' as content, 'engineering_update' as source, 0.85 as confidence)
      ] as source_docs
    UNION ALL
    SELECT 
      'Evaluate strategic market opportunities and competitive positioning',
      ARRAY[
        STRUCT('Partnership with TechCorp expands Asia-Pacific presence' as content, 'strategic_memo' as source, 0.9 as confidence),
        STRUCT('Market research shows 25% growth potential in emerging markets' as content, 'market_analysis' as source, 0.8 as confidence),
        STRUCT('Competitive analysis reveals technology leadership position' as content, 'competitive_intel' as source, 0.75 as confidence)
      ]
  ),
  synthesis_results AS (
    SELECT 
      synthesis_prompt,
      `enterprise_knowledge_ai.synthesize_context`(source_docs, synthesis_prompt, 500) as synthesis_result
    FROM test_scenarios
  ),
  quality_assessment AS (
    SELECT 
      synthesis_prompt,
      synthesis_result.confidence_score,
      synthesis_result.source_count,
      LENGTH(synthesis_result.synthesized_content) as content_length,
      CASE 
        WHEN synthesis_result.synthesized_content IS NOT NULL 
             AND LENGTH(synthesis_result.synthesized_content) > 100
             AND synthesis_result.confidence_score > 0.6
        THEN TRUE
        ELSE FALSE
      END as is_successful
    FROM synthesis_results
  )
  SELECT AS STRUCT
    'Context Synthesis Quality Test' as test_name,
    COUNT(*) as synthesis_tests,
    COUNTIF(is_successful) as successful_syntheses,
    AVG(confidence_score) as average_confidence,
    AVG(source_count) as average_source_count,
    CASE 
      WHEN AVG(confidence_score) > 0.8 AND COUNTIF(is_successful) = COUNT(*) THEN 'EXCELLENT'
      WHEN AVG(confidence_score) > 0.6 AND COUNTIF(is_successful) >= COUNT(*) * 0.8 THEN 'GOOD'
      WHEN AVG(confidence_score) > 0.4 THEN 'ACCEPTABLE'
      ELSE 'NEEDS_IMPROVEMENT'
    END as quality_grade
  FROM quality_assessment
);

-- Comprehensive test suite runner
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.run_semantic_intelligence_tests`()
BEGIN
  DECLARE test_results ARRAY<STRUCT<
    test_suite STRING,
    status STRING,
    details STRING,
    timestamp TIMESTAMP
  >>;
  
  -- Run embedding generation tests
  INSERT INTO `enterprise_knowledge_ai.test_results` (
    test_suite,
    test_name,
    status,
    details,
    execution_timestamp
  )
  SELECT 
    'semantic_intelligence' as test_suite,
    result.test_name,
    CASE WHEN result.success_rate >= 0.8 THEN 'PASSED' ELSE 'FAILED' END as status,
    CONCAT(
      'Success Rate: ', CAST(result.success_rate AS STRING),
      ', Passed: ', CAST(result.passed_tests AS STRING),
      '/', CAST(result.total_tests AS STRING)
    ) as details,
    CURRENT_TIMESTAMP() as execution_timestamp
  FROM `enterprise_knowledge_ai.test_embedding_generation`() result;
  
  -- Run semantic search accuracy tests
  INSERT INTO `enterprise_knowledge_ai.test_results` (
    test_suite,
    test_name,
    status,
    details,
    execution_timestamp
  )
  SELECT 
    'semantic_intelligence' as test_suite,
    result.test_name,
    CASE WHEN result.accuracy_rate >= 0.7 THEN 'PASSED' ELSE 'FAILED' END as status,
    CONCAT(
      'Accuracy Rate: ', CAST(result.accuracy_rate AS STRING),
      ', Avg Similarity: ', CAST(result.average_top1_similarity AS STRING)
    ) as details,
    CURRENT_TIMESTAMP() as execution_timestamp
  FROM `enterprise_knowledge_ai.test_semantic_search_accuracy`() result;
  
  -- Run performance tests
  INSERT INTO `enterprise_knowledge_ai.test_results` (
    test_suite,
    test_name,
    status,
    details,
    execution_timestamp
  )
  SELECT 
    'semantic_intelligence' as test_suite,
    result.test_name,
    CASE WHEN result.performance_grade IN ('EXCELLENT', 'GOOD') THEN 'PASSED' ELSE 'FAILED' END as status,
    CONCAT(
      'Performance Grade: ', result.performance_grade,
      ', Avg Response Time: ', CAST(result.average_response_time_ms AS STRING), 'ms'
    ) as details,
    CURRENT_TIMESTAMP() as execution_timestamp
  FROM `enterprise_knowledge_ai.test_search_performance`() result;
  
  -- Run context synthesis tests
  INSERT INTO `enterprise_knowledge_ai.test_results` (
    test_suite,
    test_name,
    status,
    details,
    execution_timestamp
  )
  SELECT 
    'semantic_intelligence' as test_suite,
    result.test_name,
    CASE WHEN result.quality_grade IN ('EXCELLENT', 'GOOD') THEN 'PASSED' ELSE 'FAILED' END as status,
    CONCAT(
      'Quality Grade: ', result.quality_grade,
      ', Success Rate: ', CAST(SAFE_DIVIDE(result.successful_syntheses, result.synthesis_tests) AS STRING)
    ) as details,
    CURRENT_TIMESTAMP() as execution_timestamp
  FROM `enterprise_knowledge_ai.test_context_synthesis`() result;
  
  -- Display test summary
  SELECT 
    test_suite,
    COUNT(*) as total_tests,
    COUNTIF(status = 'PASSED') as passed_tests,
    COUNTIF(status = 'FAILED') as failed_tests,
    SAFE_DIVIDE(COUNTIF(status = 'PASSED'), COUNT(*)) as overall_success_rate
  FROM `enterprise_knowledge_ai.test_results`
  WHERE test_suite = 'semantic_intelligence'
    AND DATE(execution_timestamp) = CURRENT_DATE()
  GROUP BY test_suite;
END;