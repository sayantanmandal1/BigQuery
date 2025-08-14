-- Enterprise-Scale Query Optimization System
-- Optimizes vector searches and AI function calls for maximum performance

-- Create optimization metadata table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.query_optimization_metadata` (
  optimization_id STRING NOT NULL,
  query_pattern STRING,
  optimization_type ENUM('vector_search', 'ai_function', 'hybrid'),
  original_cost_estimate FLOAT64,
  optimized_cost_estimate FLOAT64,
  performance_improvement_pct FLOAT64,
  optimization_rules JSON,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_applied TIMESTAMP,
  success_rate FLOAT64
) PARTITION BY DATE(created_timestamp)
CLUSTER BY optimization_type, performance_improvement_pct;

-- Create query performance tracking table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.query_performance_log` (
  execution_id STRING NOT NULL,
  query_hash STRING,
  query_type ENUM('vector_search', 'ai_generate', 'ai_forecast', 'multimodal'),
  execution_time_ms INT64,
  bytes_processed INT64,
  slots_used INT64,
  cost_estimate FLOAT64,
  optimization_applied BOOL,
  optimization_id STRING,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY DATE(timestamp)
CLUSTER BY query_type, execution_time_ms;

-- Vector search optimization function
CREATE OR REPLACE FUNCTION optimize_vector_search_query(
  base_query STRING,
  expected_result_count INT64,
  performance_target_ms INT64
)
RETURNS STRING
LANGUAGE SQL
AS (
  CASE 
    WHEN expected_result_count <= 10 THEN
      CONCAT(
        'WITH optimized_search AS (',
        REPLACE(base_query, 'top_k => 100', CONCAT('top_k => ', CAST(expected_result_count AS STRING))),
        ', distance_type => "COSINE", options => JSON\'{"use_brute_force": false, "fraction_lists_to_search": 0.1}\')',
        ' SELECT * FROM optimized_search'
      )
    WHEN expected_result_count <= 50 THEN
      CONCAT(
        'WITH batch_optimized AS (',
        REPLACE(base_query, 'VECTOR_SEARCH(', 'VECTOR_SEARCH('),
        ', options => JSON\'{"fraction_lists_to_search": 0.2}\')',
        ' SELECT * FROM batch_optimized'
      )
    ELSE
      CONCAT(
        'WITH parallel_search AS (',
        base_query,
        ', options => JSON\'{"fraction_lists_to_search": 0.5, "use_approximate": true}\')',
        ' SELECT * FROM parallel_search'
      )
  END
);

-- AI function call optimization
CREATE OR REPLACE FUNCTION optimize_ai_function_batch(
  function_calls ARRAY<STRING>,
  batch_size INT64 DEFAULT 10
)
RETURNS STRING
LANGUAGE SQL
AS (
  CONCAT(
    'WITH batched_calls AS (',
    'SELECT ',
    'ARRAY_AGG(',
    'AI.GENERATE(',
    'MODEL `enterprise_knowledge_ai.optimized_gemini_model`, ',
    'input_text',
    ') IGNORE NULLS',
    ') as batch_results ',
    'FROM (',
    'SELECT input_text, ',
    'ROW_NUMBER() OVER() as rn ',
    'FROM UNNEST([', ARRAY_TO_STRING(function_calls, ','), ']) as input_text',
    ') ',
    'GROUP BY CAST(rn / ', CAST(batch_size AS STRING), ' AS INT64)',
    ') SELECT * FROM batched_calls'
  )
);

-- Automated index optimization procedure
CREATE OR REPLACE PROCEDURE optimize_vector_indexes()
BEGIN
  DECLARE index_name STRING;
  DECLARE optimization_needed BOOL DEFAULT FALSE;
  
  -- Check vector index performance
  FOR record IN (
    SELECT 
      table_name,
      index_name as idx_name,
      AVG(execution_time_ms) as avg_time,
      COUNT(*) as query_count
    FROM `enterprise_knowledge_ai.query_performance_log` qpl
    JOIN `enterprise_knowledge_ai.INFORMATION_SCHEMA.VECTOR_INDEXES` vi
      ON qpl.query_hash LIKE CONCAT('%', vi.table_name, '%')
    WHERE DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
      AND query_type = 'vector_search'
    GROUP BY table_name, idx_name
    HAVING avg_time > 1000 OR query_count > 10000
  ) DO
    
    SET optimization_needed = TRUE;
    SET index_name = record.idx_name;
    
    -- Rebuild index with optimized parameters
    EXECUTE IMMEDIATE FORMAT("""
      DROP VECTOR INDEX IF EXISTS %s ON %s
    """, index_name, record.table_name);
    
    EXECUTE IMMEDIATE FORMAT("""
      CREATE VECTOR INDEX %s_optimized
      ON %s(embedding)
      OPTIONS (
        index_type = 'IVF',
        distance_type = 'COSINE',
        ivf_options = JSON '{"num_lists": %d}'
      )
    """, 
    index_name, 
    record.table_name,
    GREATEST(100, CAST(SQRT(record.query_count) AS INT64))
    );
    
  END FOR;
  
  IF optimization_needed THEN
    INSERT INTO `enterprise_knowledge_ai.query_optimization_metadata`
    (optimization_id, query_pattern, optimization_type, optimization_rules, last_applied)
    VALUES (
      GENERATE_UUID(),
      'vector_index_rebuild',
      'vector_search',
      JSON '{"action": "index_rebuild", "trigger": "performance_degradation"}',
      CURRENT_TIMESTAMP()
    );
  END IF;
END;

-- Query cost optimization function
CREATE OR REPLACE FUNCTION estimate_query_cost_savings(
  original_query STRING,
  optimized_query STRING
)
RETURNS STRUCT<
  original_cost FLOAT64,
  optimized_cost FLOAT64,
  savings_pct FLOAT64
>
LANGUAGE SQL
AS (
  STRUCT(
    -- Simplified cost estimation based on query complexity
    LENGTH(original_query) * 0.001 + 
    (SELECT COUNT(*) FROM UNNEST(SPLIT(original_query, 'AI.')) as ai_calls WHERE ai_calls != '') * 0.1 as original_cost,
    
    LENGTH(optimized_query) * 0.001 + 
    (SELECT COUNT(*) FROM UNNEST(SPLIT(optimized_query, 'AI.')) as ai_calls WHERE ai_calls != '') * 0.08 as optimized_cost,
    
    ((LENGTH(original_query) - LENGTH(optimized_query)) / LENGTH(original_query)) * 100 as savings_pct
  )
);

-- Automated optimization scheduler
CREATE OR REPLACE PROCEDURE run_optimization_cycle()
BEGIN
  -- Optimize vector indexes
  CALL optimize_vector_indexes();
  
  -- Clean up old performance logs (keep 30 days)
  DELETE FROM `enterprise_knowledge_ai.query_performance_log`
  WHERE DATE(timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
  
  -- Update optimization statistics
  MERGE `enterprise_knowledge_ai.query_optimization_metadata` as target
  USING (
    SELECT 
      optimization_id,
      AVG(CASE WHEN optimization_applied THEN execution_time_ms ELSE NULL END) / 
      AVG(CASE WHEN NOT optimization_applied THEN execution_time_ms ELSE NULL END) as success_rate
    FROM `enterprise_knowledge_ai.query_performance_log` qpl
    JOIN `enterprise_knowledge_ai.query_optimization_metadata` qom
      ON qpl.optimization_id = qom.optimization_id
    WHERE DATE(qpl.timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
    GROUP BY optimization_id
  ) as source
  ON target.optimization_id = source.optimization_id
  WHEN MATCHED THEN
    UPDATE SET 
      success_rate = source.success_rate,
      last_applied = CURRENT_TIMESTAMP();
END;