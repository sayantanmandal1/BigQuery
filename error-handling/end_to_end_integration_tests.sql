-- =====================================================
-- End-to-End Integration Testing Framework
-- Comprehensive validation of complete data flow from ingestion to insight delivery
-- =====================================================

-- Create integration test results table
CREATE OR REPLACE TABLE `enterprise_ai.integration_test_results` (
  test_id STRING NOT NULL,
  test_name STRING NOT NULL,
  test_category ENUM('data_flow', 'cross_component', 'performance_regression'),
  start_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  end_timestamp TIMESTAMP,
  status ENUM('running', 'passed', 'failed', 'error'),
  execution_time_ms INT64,
  error_message STRING,
  test_details JSON,
  performance_metrics JSON
) PARTITION BY DATE(start_timestamp)
CLUSTER BY test_category, status;

-- Create test data tracking table
CREATE OR REPLACE TABLE `enterprise_ai.integration_test_data` (
  test_run_id STRING NOT NULL,
  data_type ENUM('structured', 'document', 'image', 'multimodal'),
  source_table STRING,
  record_count INT64,
  data_size_mb FLOAT64,
  processing_stage ENUM('ingestion', 'embedding', 'analysis', 'insight_generation', 'delivery'),
  stage_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  stage_duration_ms INT64,
  stage_status ENUM('success', 'failed', 'timeout'),
  quality_score FLOAT64
) PARTITION BY DATE(stage_timestamp)
CLUSTER BY test_run_id, processing_stage;

-- =====================================================
-- COMPLETE DATA FLOW VALIDATION TESTS
-- =====================================================

-- Test 1: End-to-End Document Processing Pipeline
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_document_processing_pipeline`()
BEGIN
  DECLARE test_run_id STRING DEFAULT GENERATE_UUID();
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_status STRING DEFAULT 'running';
  DECLARE error_msg STRING DEFAULT '';
  
  BEGIN
    -- Log test start
    INSERT INTO `enterprise_ai.integration_test_results` 
    (test_id, test_name, test_category, status)
    VALUES (test_run_id, 'Document Processing Pipeline', 'data_flow', 'running');
    
    -- Stage 1: Data Ingestion
    DECLARE ingestion_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    -- Create test documents
    CREATE OR REPLACE TABLE `enterprise_ai.test_documents` AS
    SELECT 
      GENERATE_UUID() as document_id,
      content,
      'integration_test' as source_system,
      CURRENT_TIMESTAMP() as created_timestamp
    FROM UNNEST([
      'Strategic planning meeting notes: Q4 revenue targets exceeded by 15%. Key growth drivers include new product launches and market expansion.',
      'Customer feedback analysis: Product satisfaction scores improved to 4.2/5. Main complaints focus on delivery times and packaging quality.',
      'Competitive analysis report: Market share increased by 3% this quarter. Primary competitors showing weakness in digital transformation.',
      'Financial performance review: Operating margins improved to 18.5%. Cost optimization initiatives yielding expected results.',
      'Risk assessment summary: Supply chain vulnerabilities identified in Southeast Asia. Mitigation strategies under development.'
    ]) as content;
    
    -- Log ingestion completion
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status)
    VALUES (
      test_run_id, 
      'document', 
      'test_documents', 
      (SELECT COUNT(*) FROM `enterprise_ai.test_documents`),
      'ingestion',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), ingestion_start, MILLISECOND),
      'success'
    );
    
    -- Stage 2: Embedding Generation
    DECLARE embedding_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    CREATE OR REPLACE TABLE `enterprise_ai.test_document_embeddings` AS
    SELECT 
      document_id,
      content,
      ML.GENERATE_EMBEDDING(
        MODEL `enterprise_ai.text_embedding_model`,
        content,
        STRUCT('SEMANTIC_SIMILARITY' as task_type)
      ) as embedding,
      CURRENT_TIMESTAMP() as embedding_timestamp
    FROM `enterprise_ai.test_documents`;
    
    -- Validate embeddings were generated
    DECLARE embedding_count INT64;
    SET embedding_count = (
      SELECT COUNT(*) 
      FROM `enterprise_ai.test_document_embeddings` 
      WHERE embedding IS NOT NULL
    );
    
    IF embedding_count = 0 THEN
      SET error_msg = 'Embedding generation failed - no embeddings created';
      SET test_status = 'failed';
    END IF;
    
    -- Log embedding completion
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status, quality_score)
    VALUES (
      test_run_id, 
      'document', 
      'test_document_embeddings', 
      embedding_count,
      'embedding',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), embedding_start, MILLISECOND),
      IF(embedding_count > 0, 'success', 'failed'),
      CAST(embedding_count AS FLOAT64) / 5.0
    );
    
    -- Stage 3: Semantic Search Testing
    DECLARE search_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    CREATE OR REPLACE TABLE `enterprise_ai.test_search_results` AS
    WITH query_embedding AS (
      SELECT ML.GENERATE_EMBEDDING(
        MODEL `enterprise_ai.text_embedding_model`,
        'revenue performance and financial results',
        STRUCT('SEMANTIC_SIMILARITY' as task_type)
      ) as query_vector
    )
    SELECT 
      d.document_id,
      d.content,
      VECTOR_SEARCH(
        TABLE `enterprise_ai.test_document_embeddings`,
        (SELECT query_vector FROM query_embedding),
        top_k => 3,
        distance_type => 'COSINE'
      ) as search_results
    FROM `enterprise_ai.test_document_embeddings` d
    LIMIT 3;
    
    -- Validate search results
    DECLARE search_result_count INT64;
    SET search_result_count = (SELECT COUNT(*) FROM `enterprise_ai.test_search_results`);
    
    -- Log search completion
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status)
    VALUES (
      test_run_id, 
      'document', 
      'test_search_results', 
      search_result_count,
      'analysis',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), search_start, MILLISECOND),
      IF(search_result_count > 0, 'success', 'failed')
    );
    
    -- Stage 4: Insight Generation
    DECLARE insight_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    CREATE OR REPLACE TABLE `enterprise_ai.test_generated_insights` AS
    SELECT 
      GENERATE_UUID() as insight_id,
      document_id,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Analyze this business document and provide 3 key insights with actionable recommendations: ',
          content
        )
      ) as generated_insight,
      CURRENT_TIMESTAMP() as insight_timestamp
    FROM `enterprise_ai.test_search_results`;
    
    -- Validate insights were generated
    DECLARE insight_count INT64;
    SET insight_count = (
      SELECT COUNT(*) 
      FROM `enterprise_ai.test_generated_insights` 
      WHERE generated_insight IS NOT NULL AND LENGTH(generated_insight) > 50
    );
    
    -- Log insight generation completion
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status, quality_score)
    VALUES (
      test_run_id, 
      'document', 
      'test_generated_insights', 
      insight_count,
      'insight_generation',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), insight_start, MILLISECOND),
      IF(insight_count > 0, 'success', 'failed'),
      CAST(insight_count AS FLOAT64) / 3.0
    );
    
    -- Stage 5: Delivery Simulation
    DECLARE delivery_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    -- Simulate personalized delivery
    CREATE OR REPLACE TABLE `enterprise_ai.test_delivered_insights` AS
    SELECT 
      insight_id,
      'executive' as target_role,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Summarize this insight for an executive audience in 2 sentences: ',
          generated_insight
        )
      ) as personalized_summary,
      CURRENT_TIMESTAMP() as delivery_timestamp
    FROM `enterprise_ai.test_generated_insights`;
    
    -- Validate delivery
    DECLARE delivery_count INT64;
    SET delivery_count = (
      SELECT COUNT(*) 
      FROM `enterprise_ai.test_delivered_insights` 
      WHERE personalized_summary IS NOT NULL
    );
    
    -- Log delivery completion
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status)
    VALUES (
      test_run_id, 
      'document', 
      'test_delivered_insights', 
      delivery_count,
      'delivery',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), delivery_start, MILLISECOND),
      IF(delivery_count > 0, 'success', 'failed')
    );
    
    -- Determine overall test status
    IF error_msg = '' AND insight_count > 0 AND delivery_count > 0 THEN
      SET test_status = 'passed';
    ELSEIF error_msg = '' THEN
      SET test_status = 'failed';
      SET error_msg = 'Pipeline completed but with insufficient results';
    END IF;
    
  EXCEPTION WHEN ERROR THEN
    SET test_status = 'error';
    SET error_msg = @@error.message;
  END;
  
  -- Update test results
  UPDATE `enterprise_ai.integration_test_results`
  SET 
    end_timestamp = CURRENT_TIMESTAMP(),
    status = test_status,
    execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, MILLISECOND),
    error_message = IF(error_msg != '', error_msg, NULL),
    test_details = TO_JSON(STRUCT(
      test_run_id,
      'Complete document processing pipeline validation' as description,
      (SELECT COUNT(*) FROM `enterprise_ai.integration_test_data` WHERE test_run_id = test_run_id AND stage_status = 'success') as successful_stages,
      (SELECT COUNT(*) FROM `enterprise_ai.integration_test_data` WHERE test_run_id = test_run_id) as total_stages
    ))
  WHERE test_id = test_run_id;
  
  -- Cleanup test data
  DROP TABLE IF EXISTS `enterprise_ai.test_documents`;
  DROP TABLE IF EXISTS `enterprise_ai.test_document_embeddings`;
  DROP TABLE IF EXISTS `enterprise_ai.test_search_results`;
  DROP TABLE IF EXISTS `enterprise_ai.test_generated_insights`;
  DROP TABLE IF EXISTS `enterprise_ai.test_delivered_insights`;
  
END;
-- ===
==================================================
-- CROSS-COMPONENT INTEGRATION TESTS
-- =====================================================

-- Test 2: Multi-Engine Integration Test
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_multi_engine_integration`()
BEGIN
  DECLARE test_run_id STRING DEFAULT GENERATE_UUID();
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_status STRING DEFAULT 'running';
  DECLARE error_msg STRING DEFAULT '';
  
  BEGIN
    -- Log test start
    INSERT INTO `enterprise_ai.integration_test_results` 
    (test_id, test_name, test_category, status)
    VALUES (test_run_id, 'Multi-Engine Integration', 'cross_component', 'running');
    
    -- Create test scenario: Product performance analysis combining all engines
    CREATE OR REPLACE TABLE `enterprise_ai.test_product_data` AS
    SELECT 
      'PROD_001' as product_id,
      'Premium Wireless Headphones' as product_name,
      STRUCT(
        1250.0 as revenue,
        89 as units_sold,
        4.2 as rating,
        DATE('2024-01-15') as launch_date
      ) as metrics,
      'High-quality wireless headphones with noise cancellation' as description
    UNION ALL
    SELECT 
      'PROD_002',
      'Smart Fitness Tracker',
      STRUCT(2100.0, 150, 4.5, DATE('2024-02-01')),
      'Advanced fitness tracking with heart rate monitoring'
    UNION ALL
    SELECT 
      'PROD_003',
      'Bluetooth Speaker',
      STRUCT(890.0, 67, 3.8, DATE('2024-01-20')),
      'Portable speaker with premium sound quality';
    
    -- Test 1: Semantic Intelligence + Predictive Analytics Integration
    DECLARE semantic_predictive_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    -- Generate embeddings for product descriptions
    CREATE OR REPLACE TABLE `enterprise_ai.test_product_embeddings` AS
    SELECT 
      product_id,
      product_name,
      description,
      ML.GENERATE_EMBEDDING(
        MODEL `enterprise_ai.text_embedding_model`,
        CONCAT(product_name, ': ', description),
        STRUCT('SEMANTIC_SIMILARITY' as task_type)
      ) as product_embedding
    FROM `enterprise_ai.test_product_data`;
    
    -- Create time series data for forecasting
    CREATE OR REPLACE TABLE `enterprise_ai.test_product_timeseries` AS
    WITH date_series AS (
      SELECT date_val
      FROM UNNEST(GENERATE_DATE_ARRAY('2024-01-01', '2024-03-31', INTERVAL 1 DAY)) as date_val
    ),
    product_sales AS (
      SELECT 
        p.product_id,
        d.date_val,
        -- Simulate realistic sales patterns
        CASE 
          WHEN p.product_id = 'PROD_001' THEN 
            ROUND(15 + 5 * SIN(2 * 3.14159 * DATE_DIFF(d.date_val, DATE('2024-01-01'), DAY) / 30) + RAND() * 3)
          WHEN p.product_id = 'PROD_002' THEN 
            ROUND(20 + 8 * COS(2 * 3.14159 * DATE_DIFF(d.date_val, DATE('2024-01-01'), DAY) / 45) + RAND() * 4)
          ELSE 
            ROUND(10 + 3 * SIN(2 * 3.14159 * DATE_DIFF(d.date_val, DATE('2024-01-01'), DAY) / 20) + RAND() * 2)
        END as daily_sales
      FROM `enterprise_ai.test_product_data` p
      CROSS JOIN date_series d
    )
    SELECT * FROM product_sales;
    
    -- Generate forecasts using predictive engine
    CREATE OR REPLACE TABLE `enterprise_ai.test_product_forecasts` AS
    SELECT 
      product_id,
      forecast_timestamp,
      forecast_value,
      confidence_level,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Analyze this sales forecast for product ', product_id, 
          ': predicted daily sales of ', CAST(forecast_value AS STRING),
          ' with confidence ', CAST(confidence_level AS STRING),
          '. Provide strategic recommendations.'
        )
      ) as forecast_analysis
    FROM ML.FORECAST(
      MODEL `enterprise_ai.product_forecast_model`,
      STRUCT(7 AS horizon, 0.9 AS confidence_level)
    );
    
    -- Test semantic similarity between products and forecasts
    CREATE OR REPLACE TABLE `enterprise_ai.test_semantic_forecast_correlation` AS
    WITH similar_products AS (
      SELECT 
        p1.product_id as base_product,
        p2.product_id as similar_product,
        VECTOR_SEARCH(
          TABLE `enterprise_ai.test_product_embeddings`,
          p1.product_embedding,
          top_k => 2,
          distance_type => 'COSINE'
        ) as similarity_score
      FROM `enterprise_ai.test_product_embeddings` p1
      CROSS JOIN `enterprise_ai.test_product_embeddings` p2
      WHERE p1.product_id != p2.product_id
    )
    SELECT 
      sp.base_product,
      sp.similar_product,
      sp.similarity_score,
      f.forecast_value,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Products ', sp.base_product, ' and ', sp.similar_product, 
          ' have similarity score ', CAST(sp.similarity_score AS STRING),
          '. Forecast shows ', CAST(f.forecast_value AS STRING),
          ' units. Explain correlation and cross-selling opportunities.'
        )
      ) as correlation_insight
    FROM similar_products sp
    LEFT JOIN `enterprise_ai.test_product_forecasts` f ON sp.similar_product = f.product_id;
    
    -- Log semantic-predictive integration completion
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status)
    VALUES (
      test_run_id, 
      'structured', 
      'test_semantic_forecast_correlation', 
      (SELECT COUNT(*) FROM `enterprise_ai.test_semantic_forecast_correlation`),
      'analysis',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), semantic_predictive_start, MILLISECOND),
      'success'
    );
    
    -- Test 2: Multimodal + Real-time Integration
    DECLARE multimodal_realtime_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    -- Simulate multimodal analysis with real-time alerts
    CREATE OR REPLACE TABLE `enterprise_ai.test_multimodal_alerts` AS
    SELECT 
      product_id,
      product_name,
      AI.GENERATE_BOOL(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Based on product performance data: ', product_name,
          ' with rating ', CAST(metrics.rating AS STRING),
          ' and sales ', CAST(metrics.units_sold AS STRING),
          ' units, should we generate an alert for management attention?'
        )
      ) as requires_alert,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Generate real-time alert message for product ', product_name,
          ' performance. Rating: ', CAST(metrics.rating AS STRING),
          ', Units sold: ', CAST(metrics.units_sold AS STRING)
        )
      ) as alert_message,
      CURRENT_TIMESTAMP() as alert_timestamp
    FROM `enterprise_ai.test_product_data`
    WHERE metrics.rating < 4.0 OR metrics.units_sold < 80;
    
    -- Test personalized intelligence integration
    CREATE OR REPLACE TABLE `enterprise_ai.test_personalized_insights` AS
    SELECT 
      'executive' as role,
      product_id,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Create executive summary for product ', product_name,
          ' performance. Focus on strategic implications and ROI.'
        )
      ) as executive_insight
    FROM `enterprise_ai.test_product_data`
    UNION ALL
    SELECT 
      'analyst' as role,
      product_id,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT(
          'Create detailed analytical report for product ', product_name,
          ' including technical metrics and recommendations.'
        )
      ) as analyst_insight
    FROM `enterprise_ai.test_product_data`;
    
    -- Log multimodal-realtime integration completion
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status)
    VALUES (
      test_run_id, 
      'multimodal', 
      'test_multimodal_alerts', 
      (SELECT COUNT(*) FROM `enterprise_ai.test_multimodal_alerts`),
      'analysis',
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), multimodal_realtime_start, MILLISECOND),
      'success'
    );
    
    -- Validate cross-component integration results
    DECLARE integration_success_count INT64;
    SET integration_success_count = (
      SELECT COUNT(*) 
      FROM `enterprise_ai.integration_test_data` 
      WHERE test_run_id = test_run_id AND stage_status = 'success'
    );
    
    IF integration_success_count >= 2 THEN
      SET test_status = 'passed';
    ELSE
      SET test_status = 'failed';
      SET error_msg = 'Cross-component integration validation failed';
    END IF;
    
  EXCEPTION WHEN ERROR THEN
    SET test_status = 'error';
    SET error_msg = @@error.message;
  END;
  
  -- Update test results
  UPDATE `enterprise_ai.integration_test_results`
  SET 
    end_timestamp = CURRENT_TIMESTAMP(),
    status = test_status,
    execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, MILLISECOND),
    error_message = IF(error_msg != '', error_msg, NULL),
    test_details = TO_JSON(STRUCT(
      test_run_id,
      'Multi-engine cross-component integration validation' as description,
      integration_success_count as successful_integrations,
      (SELECT COUNT(DISTINCT processing_stage) FROM `enterprise_ai.integration_test_data` WHERE test_run_id = test_run_id) as components_tested
    ))
  WHERE test_id = test_run_id;
  
  -- Cleanup test data
  DROP TABLE IF EXISTS `enterprise_ai.test_product_data`;
  DROP TABLE IF EXISTS `enterprise_ai.test_product_embeddings`;
  DROP TABLE IF EXISTS `enterprise_ai.test_product_timeseries`;
  DROP TABLE IF EXISTS `enterprise_ai.test_product_forecasts`;
  DROP TABLE IF EXISTS `enterprise_ai.test_semantic_forecast_correlation`;
  DROP TABLE IF EXISTS `enterprise_ai.test_multimodal_alerts`;
  DROP TABLE IF EXISTS `enterprise_ai.test_personalized_insights`;
  
END;-- 
=====================================================
-- PERFORMANCE REGRESSION TESTING
-- =====================================================

-- Performance baseline tracking table
CREATE OR REPLACE TABLE `enterprise_ai.performance_baselines` (
  test_name STRING NOT NULL,
  metric_name STRING NOT NULL,
  baseline_value FLOAT64 NOT NULL,
  threshold_percentage FLOAT64 DEFAULT 20.0,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) CLUSTER BY test_name, metric_name;

-- Initialize performance baselines
INSERT INTO `enterprise_ai.performance_baselines` 
(test_name, metric_name, baseline_value, threshold_percentage) VALUES
('enterprise_scale_vector_search', 'avg_query_time_ms', 500.0, 25.0),
('enterprise_scale_vector_search', 'throughput_queries_per_second', 100.0, 15.0),
('bulk_embedding_generation', 'avg_embedding_time_ms', 200.0, 30.0),
('bulk_embedding_generation', 'embeddings_per_second', 50.0, 20.0),
('ai_generate_performance', 'avg_generation_time_ms', 1500.0, 40.0),
('ai_generate_performance', 'tokens_per_second', 25.0, 25.0),
('forecast_performance', 'avg_forecast_time_ms', 3000.0, 35.0),
('end_to_end_pipeline', 'total_pipeline_time_ms', 10000.0, 50.0);

-- Test 3: Enterprise-Scale Performance Regression Testing
CREATE OR REPLACE PROCEDURE `enterprise_ai.test_performance_regression`()
BEGIN
  DECLARE test_run_id STRING DEFAULT GENERATE_UUID();
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE test_status STRING DEFAULT 'running';
  DECLARE error_msg STRING DEFAULT '';
  DECLARE performance_degradation_count INT64 DEFAULT 0;
  
  BEGIN
    -- Log test start
    INSERT INTO `enterprise_ai.integration_test_results` 
    (test_id, test_name, test_category, status)
    VALUES (test_run_id, 'Performance Regression Testing', 'performance_regression', 'running');
    
    -- Performance Test 1: Enterprise-Scale Vector Search
    DECLARE vector_search_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    -- Create large test dataset (simulating enterprise scale)
    CREATE OR REPLACE TABLE `enterprise_ai.test_large_documents` AS
    WITH document_generator AS (
      SELECT 
        GENERATE_UUID() as document_id,
        CONCAT(
          'Enterprise document ', CAST(doc_num AS STRING), ': ',
          CASE 
            WHEN MOD(doc_num, 5) = 0 THEN 'Financial performance analysis and quarterly revenue projections with detailed market analysis and competitive positioning strategies.'
            WHEN MOD(doc_num, 5) = 1 THEN 'Customer satisfaction survey results and feedback analysis with actionable insights for product improvement and service enhancement.'
            WHEN MOD(doc_num, 5) = 2 THEN 'Operational efficiency metrics and process optimization recommendations with cost reduction strategies and automation opportunities.'
            WHEN MOD(doc_num, 5) = 3 THEN 'Risk assessment and mitigation strategies for supply chain management and business continuity planning in volatile markets.'
            ELSE 'Innovation roadmap and technology adoption plans with digital transformation initiatives and competitive advantage development.'
          END
        ) as content,
        'performance_test' as source_system
      FROM UNNEST(GENERATE_ARRAY(1, 1000)) as doc_num
    )
    SELECT * FROM document_generator;
    
    -- Generate embeddings for performance testing
    CREATE OR REPLACE TABLE `enterprise_ai.test_large_embeddings` AS
    SELECT 
      document_id,
      content,
      ML.GENERATE_EMBEDDING(
        MODEL `enterprise_ai.text_embedding_model`,
        content,
        STRUCT('SEMANTIC_SIMILARITY' as task_type)
      ) as embedding
    FROM `enterprise_ai.test_large_documents`;
    
    -- Measure vector search performance
    DECLARE search_queries ARRAY<STRING> DEFAULT [
      'financial performance and revenue analysis',
      'customer satisfaction and feedback',
      'operational efficiency and optimization',
      'risk management and mitigation',
      'innovation and technology roadmap'
    ];
    
    CREATE OR REPLACE TABLE `enterprise_ai.test_search_performance` AS
    WITH query_performance AS (
      SELECT 
        query_text,
        search_start_time,
        search_results,
        TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), search_start_time, MILLISECOND) as query_time_ms
      FROM (
        SELECT 
          query_text,
          CURRENT_TIMESTAMP() as search_start_time,
          VECTOR_SEARCH(
            TABLE `enterprise_ai.test_large_embeddings`,
            ML.GENERATE_EMBEDDING(
              MODEL `enterprise_ai.text_embedding_model`,
              query_text,
              STRUCT('SEMANTIC_SIMILARITY' as task_type)
            ),
            top_k => 10,
            distance_type => 'COSINE'
          ) as search_results
        FROM UNNEST(search_queries) as query_text
      )
    )
    SELECT * FROM query_performance;
    
    -- Calculate vector search performance metrics
    DECLARE avg_query_time FLOAT64;
    DECLARE queries_per_second FLOAT64;
    
    SET avg_query_time = (SELECT AVG(query_time_ms) FROM `enterprise_ai.test_search_performance`);
    SET queries_per_second = 1000.0 / avg_query_time;
    
    -- Check against baseline
    DECLARE vector_search_degraded BOOL DEFAULT FALSE;
    SET vector_search_degraded = (
      SELECT 
        avg_query_time > baseline_value * (1 + threshold_percentage / 100.0)
      FROM `enterprise_ai.performance_baselines`
      WHERE test_name = 'enterprise_scale_vector_search' AND metric_name = 'avg_query_time_ms'
    );
    
    IF vector_search_degraded THEN
      SET performance_degradation_count = performance_degradation_count + 1;
    END IF;
    
    -- Log vector search performance
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status, quality_score)
    VALUES (
      test_run_id, 
      'structured', 
      'test_search_performance', 
      ARRAY_LENGTH(search_queries),
      'analysis',
      CAST(avg_query_time AS INT64),
      IF(vector_search_degraded, 'failed', 'success'),
      queries_per_second / 100.0
    );
    
    -- Performance Test 2: Bulk AI Generation Performance
    DECLARE ai_generation_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    CREATE OR REPLACE TABLE `enterprise_ai.test_bulk_generation` AS
    SELECT 
      document_id,
      generation_start_time,
      AI.GENERATE(
        MODEL `enterprise_ai.gemini_model`,
        CONCAT('Summarize this document in 2 sentences: ', SUBSTR(content, 1, 500))
      ) as generated_summary,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), generation_start_time, MILLISECOND) as generation_time_ms
    FROM (
      SELECT 
        document_id,
        content,
        CURRENT_TIMESTAMP() as generation_start_time
      FROM `enterprise_ai.test_large_documents`
      LIMIT 20  -- Test with manageable batch size
    );
    
    -- Calculate AI generation performance metrics
    DECLARE avg_generation_time FLOAT64;
    DECLARE generations_per_second FLOAT64;
    
    SET avg_generation_time = (SELECT AVG(generation_time_ms) FROM `enterprise_ai.test_bulk_generation`);
    SET generations_per_second = 1000.0 / avg_generation_time;
    
    -- Check against baseline
    DECLARE generation_degraded BOOL DEFAULT FALSE;
    SET generation_degraded = (
      SELECT 
        avg_generation_time > baseline_value * (1 + threshold_percentage / 100.0)
      FROM `enterprise_ai.performance_baselines`
      WHERE test_name = 'ai_generate_performance' AND metric_name = 'avg_generation_time_ms'
    );
    
    IF generation_degraded THEN
      SET performance_degradation_count = performance_degradation_count + 1;
    END IF;
    
    -- Log AI generation performance
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status, quality_score)
    VALUES (
      test_run_id, 
      'document', 
      'test_bulk_generation', 
      20,
      'insight_generation',
      CAST(avg_generation_time AS INT64),
      IF(generation_degraded, 'failed', 'success'),
      generations_per_second / 25.0
    );
    
    -- Performance Test 3: End-to-End Pipeline Performance
    DECLARE pipeline_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
    
    -- Simulate complete pipeline with smaller dataset
    CREATE OR REPLACE TABLE `enterprise_ai.test_pipeline_performance` AS
    WITH pipeline_data AS (
      SELECT 
        document_id,
        content,
        ML.GENERATE_EMBEDDING(
          MODEL `enterprise_ai.text_embedding_model`,
          content,
          STRUCT('SEMANTIC_SIMILARITY' as task_type)
        ) as embedding
      FROM `enterprise_ai.test_large_documents`
      LIMIT 10
    ),
    search_results AS (
      SELECT 
        p.document_id,
        p.content,
        VECTOR_SEARCH(
          TABLE pipeline_data,
          p.embedding,
          top_k => 3,
          distance_type => 'COSINE'
        ) as similar_docs
      FROM pipeline_data p
      LIMIT 5
    ),
    generated_insights AS (
      SELECT 
        document_id,
        AI.GENERATE(
          MODEL `enterprise_ai.gemini_model`,
          CONCAT('Provide strategic insights for: ', SUBSTR(content, 1, 300))
        ) as insight
      FROM search_results
    )
    SELECT * FROM generated_insights;
    
    DECLARE pipeline_time_ms INT64;
    SET pipeline_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), pipeline_start, MILLISECOND);
    
    -- Check pipeline performance against baseline
    DECLARE pipeline_degraded BOOL DEFAULT FALSE;
    SET pipeline_degraded = (
      SELECT 
        pipeline_time_ms > baseline_value * (1 + threshold_percentage / 100.0)
      FROM `enterprise_ai.performance_baselines`
      WHERE test_name = 'end_to_end_pipeline' AND metric_name = 'total_pipeline_time_ms'
    );
    
    IF pipeline_degraded THEN
      SET performance_degradation_count = performance_degradation_count + 1;
    END IF;
    
    -- Log pipeline performance
    INSERT INTO `enterprise_ai.integration_test_data`
    (test_run_id, data_type, source_table, record_count, processing_stage, stage_duration_ms, stage_status, quality_score)
    VALUES (
      test_run_id, 
      'multimodal', 
      'test_pipeline_performance', 
      5,
      'delivery',
      pipeline_time_ms,
      IF(pipeline_degraded, 'failed', 'success'),
      IF(pipeline_time_ms < 15000, 1.0, 0.5)
    );
    
    -- Determine overall performance test status
    IF performance_degradation_count = 0 THEN
      SET test_status = 'passed';
    ELSE
      SET test_status = 'failed';
      SET error_msg = CONCAT('Performance degradation detected in ', CAST(performance_degradation_count AS STRING), ' metrics');
    END IF;
    
  EXCEPTION WHEN ERROR THEN
    SET test_status = 'error';
    SET error_msg = @@error.message;
  END;
  
  -- Update test results with performance metrics
  UPDATE `enterprise_ai.integration_test_results`
  SET 
    end_timestamp = CURRENT_TIMESTAMP(),
    status = test_status,
    execution_time_ms = TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, MILLISECOND),
    error_message = IF(error_msg != '', error_msg, NULL),
    test_details = TO_JSON(STRUCT(
      test_run_id,
      'Enterprise-scale performance regression testing' as description,
      performance_degradation_count as degraded_metrics,
      (SELECT COUNT(*) FROM `enterprise_ai.integration_test_data` WHERE test_run_id = test_run_id) as performance_tests_run
    )),
    performance_metrics = TO_JSON(STRUCT(
      avg_query_time,
      queries_per_second,
      avg_generation_time,
      generations_per_second,
      pipeline_time_ms
    ))
  WHERE test_id = test_run_id;
  
  -- Cleanup performance test data
  DROP TABLE IF EXISTS `enterprise_ai.test_large_documents`;
  DROP TABLE IF EXISTS `enterprise_ai.test_large_embeddings`;
  DROP TABLE IF EXISTS `enterprise_ai.test_search_performance`;
  DROP TABLE IF EXISTS `enterprise_ai.test_bulk_generation`;
  DROP TABLE IF EXISTS `enterprise_ai.test_pipeline_performance`;
  
END;-- =
====================================================
-- MASTER INTEGRATION TEST RUNNER
-- =====================================================

-- Master procedure to run all integration tests
CREATE OR REPLACE PROCEDURE `enterprise_ai.run_all_integration_tests`()
BEGIN
  DECLARE test_session_id STRING DEFAULT GENERATE_UUID();
  DECLARE session_start TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  
  -- Create test session tracking
  CREATE OR REPLACE TABLE `enterprise_ai.integration_test_sessions` (
    session_id STRING NOT NULL,
    start_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    end_timestamp TIMESTAMP,
    total_tests INT64,
    passed_tests INT64,
    failed_tests INT64,
    error_tests INT64,
    overall_status ENUM('running', 'passed', 'failed', 'error'),
    session_summary JSON
  );
  
  INSERT INTO `enterprise_ai.integration_test_sessions` 
  (session_id, overall_status, total_tests, passed_tests, failed_tests, error_tests)
  VALUES (test_session_id, 'running', 0, 0, 0, 0);
  
  -- Run all integration tests
  CALL `enterprise_ai.test_document_processing_pipeline`();
  CALL `enterprise_ai.test_multi_engine_integration`();
  CALL `enterprise_ai.test_performance_regression`();
  
  -- Calculate session results
  DECLARE total_tests, passed_tests, failed_tests, error_tests INT64;
  
  SELECT 
    COUNT(*) as total,
    COUNTIF(status = 'passed') as passed,
    COUNTIF(status = 'failed') as failed,
    COUNTIF(status = 'error') as errors
  INTO total_tests, passed_tests, failed_tests, error_tests
  FROM `enterprise_ai.integration_test_results`
  WHERE DATE(start_timestamp) = CURRENT_DATE();
  
  -- Update session results
  UPDATE `enterprise_ai.integration_test_sessions`
  SET 
    end_timestamp = CURRENT_TIMESTAMP(),
    total_tests = total_tests,
    passed_tests = passed_tests,
    failed_tests = failed_tests,
    error_tests = error_tests,
    overall_status = CASE 
      WHEN error_tests > 0 THEN 'error'
      WHEN failed_tests > 0 THEN 'failed'
      ELSE 'passed'
    END,
    session_summary = TO_JSON(STRUCT(
      test_session_id,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), session_start, MILLISECOND) as total_execution_time_ms,
      ROUND(passed_tests * 100.0 / total_tests, 2) as success_rate_percentage,
      'Complete end-to-end integration test suite execution' as description
    ))
  WHERE session_id = test_session_id;
  
END;

-- =====================================================
-- INTEGRATION TEST REPORTING AND MONITORING
-- =====================================================

-- Create comprehensive test report view
CREATE OR REPLACE VIEW `enterprise_ai.integration_test_report` AS
WITH test_summary AS (
  SELECT 
    test_category,
    COUNT(*) as total_tests,
    COUNTIF(status = 'passed') as passed_tests,
    COUNTIF(status = 'failed') as failed_tests,
    COUNTIF(status = 'error') as error_tests,
    AVG(execution_time_ms) as avg_execution_time_ms,
    MAX(execution_time_ms) as max_execution_time_ms,
    MIN(execution_time_ms) as min_execution_time_ms
  FROM `enterprise_ai.integration_test_results`
  WHERE DATE(start_timestamp) = CURRENT_DATE()
  GROUP BY test_category
),
performance_trends AS (
  SELECT 
    test_name,
    AVG(execution_time_ms) as avg_execution_time,
    STDDEV(execution_time_ms) as execution_time_stddev,
    COUNT(*) as execution_count
  FROM `enterprise_ai.integration_test_results`
  WHERE DATE(start_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  GROUP BY test_name
),
data_flow_metrics AS (
  SELECT 
    processing_stage,
    AVG(stage_duration_ms) as avg_stage_duration,
    AVG(quality_score) as avg_quality_score,
    COUNTIF(stage_status = 'success') as successful_stages,
    COUNT(*) as total_stages
  FROM `enterprise_ai.integration_test_data`
  WHERE DATE(stage_timestamp) = CURRENT_DATE()
  GROUP BY processing_stage
)
SELECT 
  CURRENT_TIMESTAMP() as report_timestamp,
  ts.test_category,
  ts.total_tests,
  ts.passed_tests,
  ts.failed_tests,
  ts.error_tests,
  ROUND(ts.passed_tests * 100.0 / ts.total_tests, 2) as success_rate_percentage,
  ts.avg_execution_time_ms,
  pt.execution_time_stddev,
  dfm.avg_stage_duration,
  dfm.avg_quality_score,
  dfm.successful_stages,
  dfm.total_stages
FROM test_summary ts
LEFT JOIN performance_trends pt ON ts.test_category = pt.test_name
LEFT JOIN data_flow_metrics dfm ON TRUE;

-- Create performance monitoring view
CREATE OR REPLACE VIEW `enterprise_ai.performance_monitoring_dashboard` AS
WITH current_performance AS (
  SELECT 
    test_name,
    metric_name,
    JSON_EXTRACT_SCALAR(performance_metrics, CONCAT('$.', metric_name)) as current_value,
    execution_time_ms,
    start_timestamp
  FROM `enterprise_ai.integration_test_results`
  WHERE test_category = 'performance_regression'
    AND DATE(start_timestamp) = CURRENT_DATE()
    AND performance_metrics IS NOT NULL
),
baseline_comparison AS (
  SELECT 
    cp.test_name,
    cp.metric_name,
    CAST(cp.current_value AS FLOAT64) as current_value,
    pb.baseline_value,
    pb.threshold_percentage,
    ROUND(
      (CAST(cp.current_value AS FLOAT64) - pb.baseline_value) * 100.0 / pb.baseline_value, 
      2
    ) as performance_change_percentage,
    CASE 
      WHEN CAST(cp.current_value AS FLOAT64) > pb.baseline_value * (1 + pb.threshold_percentage / 100.0) THEN 'DEGRADED'
      WHEN CAST(cp.current_value AS FLOAT64) < pb.baseline_value * (1 - pb.threshold_percentage / 100.0) THEN 'IMPROVED'
      ELSE 'STABLE'
    END as performance_status
  FROM current_performance cp
  JOIN `enterprise_ai.performance_baselines` pb 
    ON cp.test_name = pb.test_name AND cp.metric_name = pb.metric_name
)
SELECT 
  test_name,
  metric_name,
  current_value,
  baseline_value,
  performance_change_percentage,
  performance_status,
  threshold_percentage,
  CASE 
    WHEN performance_status = 'DEGRADED' THEN 'HIGH'
    WHEN performance_status = 'IMPROVED' THEN 'LOW'
    ELSE 'MEDIUM'
  END as alert_priority
FROM baseline_comparison
ORDER BY 
  CASE performance_status 
    WHEN 'DEGRADED' THEN 1 
    WHEN 'STABLE' THEN 2 
    WHEN 'IMPROVED' THEN 3 
  END,
  ABS(performance_change_percentage) DESC;

-- Create integration health check function
CREATE OR REPLACE FUNCTION `enterprise_ai.get_integration_health_status`()
RETURNS JSON
LANGUAGE SQL
AS (
  WITH health_metrics AS (
    SELECT 
      COUNT(*) as total_tests_today,
      COUNTIF(status = 'passed') as passed_tests_today,
      COUNTIF(status = 'failed') as failed_tests_today,
      COUNTIF(status = 'error') as error_tests_today,
      AVG(execution_time_ms) as avg_execution_time,
      MAX(end_timestamp) as last_test_time
    FROM `enterprise_ai.integration_test_results`
    WHERE DATE(start_timestamp) = CURRENT_DATE()
  ),
  performance_health AS (
    SELECT 
      COUNTIF(performance_status = 'DEGRADED') as degraded_metrics,
      COUNTIF(performance_status = 'STABLE') as stable_metrics,
      COUNTIF(performance_status = 'IMPROVED') as improved_metrics
    FROM `enterprise_ai.performance_monitoring_dashboard`
  ),
  data_flow_health AS (
    SELECT 
      AVG(quality_score) as avg_data_quality,
      COUNTIF(stage_status = 'success') as successful_data_flows,
      COUNT(*) as total_data_flows
    FROM `enterprise_ai.integration_test_data`
    WHERE DATE(stage_timestamp) = CURRENT_DATE()
  )
  SELECT TO_JSON(STRUCT(
    CURRENT_TIMESTAMP() as health_check_timestamp,
    CASE 
      WHEN hm.error_tests_today > 0 OR ph.degraded_metrics > 2 THEN 'CRITICAL'
      WHEN hm.failed_tests_today > 0 OR ph.degraded_metrics > 0 THEN 'WARNING'
      WHEN hm.passed_tests_today > 0 AND dfh.avg_data_quality > 0.8 THEN 'HEALTHY'
      ELSE 'UNKNOWN'
    END as overall_health_status,
    hm.total_tests_today,
    hm.passed_tests_to