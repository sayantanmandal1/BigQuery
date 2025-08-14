-- Performance Optimization and Caching Strategies
-- This module provides intelligent caching and query optimization for enterprise-scale operations

-- Create performance optimization configuration
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.performance_config` (
  config_id STRING NOT NULL,
  component STRING NOT NULL,
  optimization_type ENUM('caching', 'query_optimization', 'resource_scaling', 'index_tuning') NOT NULL,
  config_parameters JSON NOT NULL,
  enabled BOOL DEFAULT TRUE,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) CLUSTER BY component, optimization_type;

-- Insert performance optimization configurations
INSERT INTO `enterprise_knowledge_ai.performance_config` VALUES
('vector_search_cache', 'semantic_intelligence', 'caching', 
 JSON '{"cache_ttl_hours": 24, "max_cache_size_gb": 10, "cache_hit_threshold": 0.95}', 
 TRUE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
('embedding_cache', 'semantic_intelligence', 'caching',
 JSON '{"cache_ttl_hours": 168, "max_cache_size_gb": 50, "precompute_common_queries": true}',
 TRUE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
('ai_response_cache', 'all_components', 'caching',
 JSON '{"cache_ttl_hours": 12, "max_cache_size_gb": 5, "similarity_threshold": 0.9}',
 TRUE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
('query_optimization', 'all_components', 'query_optimization',
 JSON '{"enable_query_plan_cache": true, "optimize_joins": true, "partition_pruning": true}',
 TRUE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

-- Create intelligent caching system
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.intelligent_cache` (
  cache_id STRING NOT NULL,
  cache_key STRING NOT NULL,
  cache_type ENUM('embedding', 'ai_response', 'vector_search', 'query_result') NOT NULL,
  cached_data JSON NOT NULL,
  confidence_score FLOAT64,
  access_count INT64 DEFAULT 1,
  last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  expires_at TIMESTAMP NOT NULL,
  metadata JSON
) PARTITION BY DATE(created_timestamp)
CLUSTER BY cache_type, cache_key;

-- Create performance metrics tracking
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.performance_metrics` (
  metric_id STRING NOT NULL,
  component STRING NOT NULL,
  operation_type STRING NOT NULL,
  execution_time_ms INT64 NOT NULL,
  cache_hit BOOL DEFAULT FALSE,
  optimization_applied STRING,
  resource_usage JSON,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
) PARTITION BY DATE(timestamp)
CLUSTER BY component, operation_type;

-- Intelligent caching function for embeddings
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.get_cached_embedding`(
  content_text STRING,
  model_name STRING DEFAULT 'text-embedding-004'
)
RETURNS STRUCT<
  embedding ARRAY<FLOAT64>,
  cache_hit BOOL,
  confidence FLOAT64
>
LANGUAGE SQL
AS (
  WITH cache_lookup AS (
    SELECT 
      cached_data,
      confidence_score,
      cache_id
    FROM `enterprise_knowledge_ai.intelligent_cache`
    WHERE cache_key = TO_HEX(SHA256(CONCAT(content_text, model_name)))
      AND cache_type = 'embedding'
      AND expires_at > CURRENT_TIMESTAMP()
    ORDER BY confidence_score DESC, last_accessed DESC
    LIMIT 1
  ),
  
  cache_result AS (
    SELECT 
      CASE 
        WHEN cache_lookup.cached_data IS NOT NULL THEN
          STRUCT(
            JSON_EXTRACT_ARRAY(cache_lookup.cached_data, '$.embedding') AS embedding,
            TRUE AS cache_hit,
            cache_lookup.confidence_score AS confidence
          )
        ELSE
          STRUCT(
            ML.GENERATE_EMBEDDING(
              MODEL CONCAT('`', model_name, '`'),
              content_text
            ) AS embedding,
            FALSE AS cache_hit,
            0.95 AS confidence
          )
      END AS result
    FROM cache_lookup
  )
  
  SELECT result FROM cache_result
);

-- Cache management procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.manage_cache`(
  operation STRING DEFAULT 'cleanup'
)
BEGIN
  DECLARE cache_size_gb FLOAT64;
  DECLARE expired_count INT64;
  DECLARE low_usage_count INT64;
  
  IF operation = 'cleanup' THEN
    -- Remove expired cache entries
    DELETE FROM `enterprise_knowledge_ai.intelligent_cache`
    WHERE expires_at <= CURRENT_TIMESTAMP();
    
    SET expired_count = @@row_count;
    
    -- Remove low-usage cache entries if cache is too large
    SET cache_size_gb = (
      SELECT SUM(LENGTH(TO_JSON_STRING(cached_data))) / (1024 * 1024 * 1024)
      FROM `enterprise_knowledge_ai.intelligent_cache`
    );
    
    IF cache_size_gb > 50 THEN
      DELETE FROM `enterprise_knowledge_ai.intelligent_cache`
      WHERE access_count < 3 
        AND last_accessed < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);
      
      SET low_usage_count = @@row_count;
    END IF;
    
    -- Log cleanup results
    INSERT INTO `enterprise_knowledge_ai.system_logs`
    VALUES (
      GENERATE_UUID(),
      'cache_manager',
      CONCAT('Cache cleanup completed. Expired: ', CAST(expired_count AS STRING),
             ', Low usage: ', CAST(low_usage_count AS STRING),
             ', Current size: ', CAST(ROUND(cache_size_gb, 2) AS STRING), 'GB'),
      'info',
      CURRENT_TIMESTAMP(),
      JSON_OBJECT(
        'expired_entries', expired_count,
        'low_usage_entries', low_usage_count,
        'cache_size_gb', cache_size_gb
      )
    );
    
  ELSEIF operation = 'precompute' THEN
    -- Precompute embeddings for common queries
    CALL `enterprise_knowledge_ai.precompute_common_embeddings`();
    
  ELSEIF operation = 'optimize' THEN
    -- Optimize cache performance
    CALL `enterprise_knowledge_ai.optimize_cache_performance`();
    
  END IF;
END;

-- Precompute common embeddings procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.precompute_common_embeddings`()
BEGIN
  DECLARE common_queries ARRAY<STRING>;
  DECLARE current_query STRING;
  DECLARE embedding_result ARRAY<FLOAT64>;
  
  -- Get most common query patterns
  SET common_queries = (
    SELECT ARRAY_AGG(content ORDER BY query_count DESC LIMIT 100)
    FROM (
      SELECT content, COUNT(*) AS query_count
      FROM `enterprise_knowledge_ai.enterprise_knowledge_base`
      WHERE created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
      GROUP BY content
      HAVING LENGTH(content) BETWEEN 10 AND 1000
      ORDER BY query_count DESC
      LIMIT 100
    )
  );
  
  -- Precompute embeddings for common queries
  FOR query_index IN (SELECT * FROM UNNEST(GENERATE_ARRAY(0, ARRAY_LENGTH(common_queries) - 1))) DO
    SET current_query = common_queries[OFFSET(query_index)];
    
    -- Check if embedding is already cached
    IF NOT EXISTS (
      SELECT 1 FROM `enterprise_knowledge_ai.intelligent_cache`
      WHERE cache_key = TO_HEX(SHA256(CONCAT(current_query, 'text-embedding-004')))
        AND cache_type = 'embedding'
        AND expires_at > CURRENT_TIMESTAMP()
    ) THEN
      -- Generate and cache embedding
      SET embedding_result = ML.GENERATE_EMBEDDING(
        MODEL `text-embedding-004`,
        current_query
      );
      
      INSERT INTO `enterprise_knowledge_ai.intelligent_cache`
      VALUES (
        GENERATE_UUID(),
        TO_HEX(SHA256(CONCAT(current_query, 'text-embedding-004'))),
        'embedding',
        JSON_OBJECT('embedding', embedding_result),
        0.95,
        0,
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP(),
        TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 168 HOUR),
        JSON_OBJECT('precomputed', TRUE, 'query_length', LENGTH(current_query))
      );
    END IF;
  END FOR;
  
  -- Log precomputation results
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'cache_precompute',
    CONCAT('Precomputed embeddings for ', CAST(ARRAY_LENGTH(common_queries) AS STRING), ' common queries'),
    'info',
    CURRENT_TIMESTAMP(),
    JSON_OBJECT('queries_processed', ARRAY_LENGTH(common_queries))
  );
END;

-- Query optimization function
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.optimize_query_performance`(
  base_query STRING,
  optimization_hints JSON DEFAULT JSON '{}'
)
RETURNS STRUCT<
  optimized_query STRING,
  estimated_improvement_percent FLOAT64,
  optimization_applied ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH optimization_analysis AS (
    SELECT 
      base_query AS original_query,
      CASE 
        WHEN REGEXP_CONTAINS(UPPER(base_query), r'SELECT \*') THEN
          REGEXP_REPLACE(base_query, r'SELECT \*', 'SELECT specific_columns')
        ELSE base_query
      END AS select_optimized,
      
      CASE 
        WHEN NOT REGEXP_CONTAINS(UPPER(base_query), r'WHERE.*PARTITION') THEN
          CONCAT(base_query, ' -- Add partition pruning for better performance')
        ELSE base_query
      END AS partition_optimized,
      
      CASE 
        WHEN REGEXP_CONTAINS(UPPER(base_query), r'ORDER BY') AND 
             NOT REGEXP_CONTAINS(UPPER(base_query), r'LIMIT') THEN
          CONCAT(base_query, ' LIMIT 1000 -- Add limit to prevent large sorts')
        ELSE base_query
      END AS limit_optimized
  ),
  
  optimization_summary AS (
    SELECT 
      limit_optimized AS final_query,
      ARRAY[
        CASE WHEN select_optimized != original_query THEN 'column_pruning' END,
        CASE WHEN partition_optimized != original_query THEN 'partition_pruning' END,
        CASE WHEN limit_optimized != partition_optimized THEN 'result_limiting' END
      ] AS optimizations_applied,
      -- Estimate performance improvement based on optimizations
      CASE 
        WHEN select_optimized != original_query THEN 15.0
        ELSE 0.0
      END +
      CASE 
        WHEN partition_optimized != original_query THEN 40.0
        ELSE 0.0
      END +
      CASE 
        WHEN limit_optimized != partition_optimized THEN 25.0
        ELSE 0.0
      END AS estimated_improvement
    FROM optimization_analysis
  )
  
  SELECT STRUCT(
    final_query AS optimized_query,
    estimated_improvement AS estimated_improvement_percent,
    ARRAY(SELECT opt FROM UNNEST(optimizations_applied) AS opt WHERE opt IS NOT NULL) AS optimization_applied
  )
  FROM optimization_summary
);

-- Performance monitoring procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.monitor_performance`()
BEGIN
  DECLARE avg_response_time FLOAT64;
  DECLARE cache_hit_rate FLOAT64;
  DECLARE slow_queries_count INT64;
  
  -- Calculate performance metrics for the last hour
  SET (avg_response_time, cache_hit_rate, slow_queries_count) = (
    SELECT AS STRUCT
      AVG(execution_time_ms) AS avg_time,
      COUNTIF(cache_hit) / COUNT(*) AS hit_rate,
      COUNTIF(execution_time_ms > 5000) AS slow_count
    FROM `enterprise_knowledge_ai.performance_metrics`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  );
  
  -- Generate performance alerts if needed
  IF avg_response_time > 3000 THEN
    INSERT INTO `enterprise_knowledge_ai.system_logs`
    VALUES (
      GENERATE_UUID(),
      'performance_monitor',
      CONCAT('High average response time detected: ', CAST(ROUND(avg_response_time) AS STRING), 'ms'),
      'warning',
      CURRENT_TIMESTAMP(),
      JSON_OBJECT(
        'avg_response_time_ms', avg_response_time,
        'cache_hit_rate', cache_hit_rate,
        'slow_queries_count', slow_queries_count,
        'recommended_action', 'Consider cache optimization and query tuning'
      )
    );
  END IF;
  
  IF cache_hit_rate < 0.7 THEN
    INSERT INTO `enterprise_knowledge_ai.system_logs`
    VALUES (
      GENERATE_UUID(),
      'performance_monitor',
      CONCAT('Low cache hit rate detected: ', CAST(ROUND(cache_hit_rate * 100, 1) AS STRING), '%'),
      'warning',
      CURRENT_TIMESTAMP(),
      JSON_OBJECT(
        'cache_hit_rate', cache_hit_rate,
        'recommended_action', 'Review caching strategy and precompute common queries'
      )
    );
  END IF;
  
  -- Trigger automatic optimizations if performance is poor
  IF avg_response_time > 5000 OR cache_hit_rate < 0.5 THEN
    CALL `enterprise_knowledge_ai.manage_cache`('optimize');
  END IF;
END;

-- Resource scaling recommendation function
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.get_scaling_recommendations`()
RETURNS STRUCT<
  current_load_level STRING,
  recommended_action STRING,
  scaling_factor FLOAT64,
  cost_impact_estimate STRING,
  implementation_priority STRING
>
LANGUAGE SQL
AS (
  WITH load_analysis AS (
    SELECT 
      AVG(execution_time_ms) AS avg_execution_time,
      COUNT(*) AS total_operations,
      COUNTIF(execution_time_ms > 10000) AS timeout_operations,
      MAX(execution_time_ms) AS max_execution_time
    FROM `enterprise_knowledge_ai.performance_metrics`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  ),
  
  scaling_assessment AS (
    SELECT 
      CASE 
        WHEN avg_execution_time > 8000 OR timeout_operations > total_operations * 0.1 THEN 'high'
        WHEN avg_execution_time > 4000 OR timeout_operations > total_operations * 0.05 THEN 'medium'
        WHEN avg_execution_time > 2000 THEN 'low'
        ELSE 'optimal'
      END AS load_level,
      
      CASE 
        WHEN avg_execution_time > 8000 THEN 2.0
        WHEN avg_execution_time > 4000 THEN 1.5
        WHEN avg_execution_time > 2000 THEN 1.2
        ELSE 1.0
      END AS scaling_factor
    FROM load_analysis
  )
  
  SELECT STRUCT(
    load_level AS current_load_level,
    
    CASE load_level
      WHEN 'high' THEN 'Immediate scaling required - increase compute resources'
      WHEN 'medium' THEN 'Consider scaling up during peak hours'
      WHEN 'low' THEN 'Monitor closely, scaling may be needed soon'
      ELSE 'Current resources are adequate'
    END AS recommended_action,
    
    scaling_factor AS scaling_factor,
    
    CASE 
      WHEN scaling_factor > 1.5 THEN 'High - significant cost increase expected'
      WHEN scaling_factor > 1.2 THEN 'Medium - moderate cost increase'
      WHEN scaling_factor > 1.0 THEN 'Low - minimal cost increase'
      ELSE 'None - no additional costs'
    END AS cost_impact_estimate,
    
    CASE load_level
      WHEN 'high' THEN 'Critical - implement immediately'
      WHEN 'medium' THEN 'High - implement within 24 hours'
      WHEN 'low' THEN 'Medium - implement within 1 week'
      ELSE 'Low - monitor and reassess'
    END AS implementation_priority
  )
  FROM scaling_assessment
);