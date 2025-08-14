-- Automated Performance Tuning and Index Optimization
-- Continuously optimizes system performance based on usage patterns

-- Create performance tuning configuration table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.performance_tuning_config` (
  config_id STRING NOT NULL,
  tuning_type ENUM('index_optimization', 'query_rewrite', 'caching', 'partitioning'),
  target_component STRING,
  optimization_rules JSON,
  performance_impact_score FLOAT64,
  cost_impact_score FLOAT64,
  last_applied TIMESTAMP,
  success_rate FLOAT64,
  is_active BOOL DEFAULT TRUE
);

-- Create performance baseline table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.performance_baseline` (
  baseline_id STRING NOT NULL,
  component_name STRING,
  metric_name STRING,
  baseline_value FLOAT64,
  measurement_period_days INT64,
  confidence_interval_lower FLOAT64,
  confidence_interval_upper FLOAT64,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY DATE(created_timestamp)
CLUSTER BY component_name, metric_name;

-- Initialize performance tuning configurations
INSERT INTO `enterprise_knowledge_ai.performance_tuning_config`
(config_id, tuning_type, target_component, optimization_rules, performance_impact_score, cost_impact_score)
VALUES 
('vector_index_tuning', 'index_optimization', 'vector_search', 
 JSON '{"strategy": "adaptive_ivf", "rebalance_threshold": 0.3, "rebuild_threshold": 0.5}', 
 8.5, -2.1),
('query_cache_tuning', 'caching', 'semantic_engine', 
 JSON '{"cache_size_mb": 1000, "ttl_minutes": 60, "hit_ratio_target": 0.8}', 
 7.2, -1.5),
('partition_optimization', 'partitioning', 'knowledge_base', 
 JSON '{"partition_strategy": "date_content_type", "retention_days": 365}', 
 6.8, -3.2);

-- Automated index optimization function
CREATE OR REPLACE FUNCTION optimize_vector_index_parameters(
  table_name STRING,
  current_performance_ms FLOAT64,
  query_volume_per_day INT64
)
RETURNS STRUCT<
  recommended_num_lists INT64,
  recommended_distance_type STRING,
  estimated_improvement_pct FLOAT64,
  rebuild_required BOOL
>
LANGUAGE SQL
AS (
  WITH optimization_calculation AS (
    SELECT 
      -- Calculate optimal number of lists based on data size and query patterns
      CASE 
        WHEN query_volume_per_day > 10000 THEN GREATEST(500, CAST(SQRT(query_volume_per_day) AS INT64))
        WHEN query_volume_per_day > 1000 THEN GREATEST(200, CAST(SQRT(query_volume_per_day * 0.8) AS INT64))
        ELSE GREATEST(100, CAST(SQRT(query_volume_per_day * 0.5) AS INT64))
      END as optimal_lists,
      
      -- Determine best distance type based on performance
      CASE 
        WHEN current_performance_ms > 2000 THEN 'COSINE'
        WHEN current_performance_ms > 1000 THEN 'DOT_PRODUCT'
        ELSE 'EUCLIDEAN'
      END as optimal_distance,
      
      -- Estimate performance improvement
      CASE 
        WHEN current_performance_ms > 3000 THEN 40.0
        WHEN current_performance_ms > 1500 THEN 25.0
        WHEN current_performance_ms > 800 THEN 15.0
        ELSE 5.0
      END as improvement_estimate,
      
      -- Determine if rebuild is needed
      current_performance_ms > 1500 as needs_rebuild
  )
  SELECT AS STRUCT
    optimal_lists as recommended_num_lists,
    optimal_distance as recommended_distance_type,
    improvement_estimate as estimated_improvement_pct,
    needs_rebuild as rebuild_required
  FROM optimization_calculation
);

-- Query rewriting optimization function
CREATE OR REPLACE FUNCTION optimize_query_structure(
  original_query STRING,
  query_type STRING,
  avg_execution_time_ms FLOAT64
)
RETURNS STRUCT<
  optimized_query STRING,
  optimization_applied STRING,
  estimated_speedup_pct FLOAT64
>
LANGUAGE SQL
AS (
  CASE query_type
    WHEN 'vector_search' THEN
      STRUCT(
        CASE 
          WHEN CONTAINS_SUBSTR(original_query, 'top_k => 100') AND avg_execution_time_ms > 2000 THEN
            REPLACE(original_query, 'top_k => 100', 'top_k => 50')
          WHEN NOT CONTAINS_SUBSTR(original_query, 'distance_type') THEN
            CONCAT(original_query, ', distance_type => "COSINE"')
          WHEN NOT CONTAINS_SUBSTR(original_query, 'options') AND avg_execution_time_ms > 1000 THEN
            CONCAT(original_query, ', options => JSON\'{"fraction_lists_to_search": 0.1}\'')
          ELSE original_query
        END as optimized_query,
        
        CASE 
          WHEN CONTAINS_SUBSTR(original_query, 'top_k => 100') AND avg_execution_time_ms > 2000 THEN 'reduced_top_k'
          WHEN NOT CONTAINS_SUBSTR(original_query, 'distance_type') THEN 'added_distance_type'
          WHEN NOT CONTAINS_SUBSTR(original_query, 'options') THEN 'added_search_options'
          ELSE 'no_optimization_needed'
        END as optimization_applied,
        
        CASE 
          WHEN avg_execution_time_ms > 2000 THEN 35.0
          WHEN avg_execution_time_ms > 1000 THEN 20.0
          ELSE 10.0
        END as estimated_speedup_pct
      )
      
    WHEN 'ai_generate' THEN
      STRUCT(
        CASE 
          WHEN LENGTH(original_query) > 1000 AND NOT CONTAINS_SUBSTR(original_query, 'ARRAY_AGG') THEN
            CONCAT('WITH batched_inputs AS (', original_query, ') SELECT ARRAY_AGG(result) FROM batched_inputs')
          WHEN NOT CONTAINS_SUBSTR(original_query, 'temperature') THEN
            REPLACE(original_query, 'AI.GENERATE(', 'AI.GENERATE(MODEL `model`, input, JSON\'{"temperature": 0.1}\',')
          ELSE original_query
        END as optimized_query,
        
        CASE 
          WHEN LENGTH(original_query) > 1000 THEN 'batching_optimization'
          WHEN NOT CONTAINS_SUBSTR(original_query, 'temperature') THEN 'added_temperature_control'
          ELSE 'no_optimization_needed'
        END as optimization_applied,
        
        CASE 
          WHEN LENGTH(original_query) > 1000 THEN 45.0
          ELSE 15.0
        END as estimated_speedup_pct
      )
      
    ELSE
      STRUCT(
        original_query as optimized_query,
        'unsupported_query_type' as optimization_applied,
        0.0 as estimated_speedup_pct
      )
  END
);

-- Automated performance baseline establishment
CREATE OR REPLACE PROCEDURE establish_performance_baselines()
BEGIN
  -- Establish baselines for vector search performance
  MERGE `enterprise_knowledge_ai.performance_baseline` as target
  USING (
    SELECT 
      'vector_search_latency' as baseline_id,
      'vector_search' as component_name,
      'avg_latency_ms' as metric_name,
      AVG(execution_time_ms) as baseline_value,
      7 as measurement_period_days,
      PERCENTILE_CONT(execution_time_ms, 0.1) OVER() as confidence_interval_lower,
      PERCENTILE_CONT(execution_time_ms, 0.9) OVER() as confidence_interval_upper
    FROM `enterprise_knowledge_ai.query_performance_log`
    WHERE query_type = 'vector_search'
      AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  ) as source
  ON target.baseline_id = source.baseline_id
  WHEN MATCHED THEN
    UPDATE SET 
      baseline_value = source.baseline_value,
      confidence_interval_lower = source.confidence_interval_lower,
      confidence_interval_upper = source.confidence_interval_upper,
      last_updated = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN
    INSERT (baseline_id, component_name, metric_name, baseline_value, measurement_period_days, 
            confidence_interval_lower, confidence_interval_upper)
    VALUES (source.baseline_id, source.component_name, source.metric_name, source.baseline_value,
            source.measurement_period_days, source.confidence_interval_lower, source.confidence_interval_upper);
  
  -- Establish baselines for AI function performance
  MERGE `enterprise_knowledge_ai.performance_baseline` as target
  USING (
    SELECT 
      'ai_generate_latency' as baseline_id,
      'ai_functions' as component_name,
      'avg_latency_ms' as metric_name,
      AVG(execution_time_ms) as baseline_value,
      7 as measurement_period_days,
      PERCENTILE_CONT(execution_time_ms, 0.1) OVER() as confidence_interval_lower,
      PERCENTILE_CONT(execution_time_ms, 0.9) OVER() as confidence_interval_upper
    FROM `enterprise_knowledge_ai.query_performance_log`
    WHERE query_type IN ('ai_generate', 'ai_forecast')
      AND DATE(timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  ) as source
  ON target.baseline_id = source.baseline_id
  WHEN MATCHED THEN
    UPDATE SET 
      baseline_value = source.baseline_value,
      confidence_interval_lower = source.confidence_interval_lower,
      confidence_interval_upper = source.confidence_interval_upper,
      last_updated = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN
    INSERT (baseline_id, component_name, metric_name, baseline_value, measurement_period_days,
            confidence_interval_lower, confidence_interval_upper)
    VALUES (source.baseline_id, source.component_name, source.metric_name, source.baseline_value,
            source.measurement_period_days, source.confidence_interval_lower, source.confidence_interval_upper);
END;

-- Performance regression detection
CREATE OR REPLACE FUNCTION detect_performance_regression(
  component_name STRING,
  metric_name STRING,
  current_value FLOAT64
)
RETURNS STRUCT<
  regression_detected BOOL,
  severity ENUM('minor', 'moderate', 'severe'),
  baseline_value FLOAT64,
  degradation_pct FLOAT64,
  recommendation STRING
>
LANGUAGE SQL
AS (
  WITH baseline_data AS (
    SELECT 
      baseline_value,
      confidence_interval_upper
    FROM `enterprise_knowledge_ai.performance_baseline`
    WHERE component_name = component_name
      AND metric_name = metric_name
    ORDER BY last_updated DESC
    LIMIT 1
  )
  SELECT AS STRUCT
    current_value > bd.confidence_interval_upper as regression_detected,
    
    CASE 
      WHEN current_value > bd.baseline_value * 2 THEN 'severe'
      WHEN current_value > bd.baseline_value * 1.5 THEN 'moderate'
      WHEN current_value > bd.confidence_interval_upper THEN 'minor'
      ELSE 'minor'
    END as severity,
    
    bd.baseline_value,
    
    ((current_value - bd.baseline_value) / bd.baseline_value) * 100 as degradation_pct,
    
    CASE 
      WHEN current_value > bd.baseline_value * 2 THEN 'IMMEDIATE_OPTIMIZATION_REQUIRED'
      WHEN current_value > bd.baseline_value * 1.5 THEN 'SCHEDULE_OPTIMIZATION'
      WHEN current_value > bd.confidence_interval_upper THEN 'MONITOR_CLOSELY'
      ELSE 'NO_ACTION_NEEDED'
    END as recommendation
    
  FROM baseline_data bd
);

-- Automated performance tuning execution
CREATE OR REPLACE PROCEDURE execute_performance_tuning()
BEGIN
  DECLARE tuning_applied BOOL DEFAULT FALSE;
  
  -- Check for performance regressions and apply optimizations
  FOR performance_issue IN (
    SELECT 
      qpl.query_type,
      AVG(qpl.execution_time_ms) as avg_execution_time,
      COUNT(*) as query_count,
      STRING_AGG(DISTINCT qpl.query_hash) as sample_queries
    FROM `enterprise_knowledge_ai.query_performance_log` qpl
    WHERE DATE(qpl.timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)
    GROUP BY qpl.query_type
    HAVING AVG(qpl.execution_time_ms) > (
      SELECT baseline_value * 1.2
      FROM `enterprise_knowledge_ai.performance_baseline`
      WHERE component_name = CASE qpl.query_type
        WHEN 'vector_search' THEN 'vector_search'
        ELSE 'ai_functions'
      END
      AND metric_name = 'avg_latency_ms'
    )
  ) DO
    
    SET tuning_applied = TRUE;
    
    -- Apply vector search optimizations
    IF performance_issue.query_type = 'vector_search' THEN
      
      -- Optimize vector indexes
      FOR table_record IN (
        SELECT DISTINCT table_name
        FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
        WHERE table_name LIKE '%knowledge%'
      ) DO
        
        EXECUTE IMMEDIATE FORMAT("""
          CREATE OR REPLACE VECTOR INDEX %s_optimized
          ON %s(embedding)
          OPTIONS (
            index_type = 'IVF',
            distance_type = 'COSINE',
            ivf_options = JSON '{"num_lists": %d}'
          )
        """, 
        table_record.table_name,
        table_record.table_name,
        GREATEST(200, CAST(SQRT(performance_issue.query_count) AS INT64))
        );
        
      END FOR;
      
    -- Apply AI function optimizations
    ELSEIF performance_issue.query_type IN ('ai_generate', 'ai_forecast') THEN
      
      -- Log optimization recommendation
      INSERT INTO `enterprise_knowledge_ai.system_events`
      (event_id, event_type, component_name, severity, event_data)
      VALUES (
        GENERATE_UUID(),
        'OPTIMIZATION',
        'ai_functions',
        'info',
        JSON_OBJECT(
          'optimization_type', 'ai_function_tuning',
          'avg_execution_time', performance_issue.avg_execution_time,
          'query_count', performance_issue.query_count,
          'recommendation', 'Consider batching AI function calls or adjusting model parameters'
        )
      );
      
    END IF;
    
  END FOR;
  
  -- Update performance tuning success rates
  IF tuning_applied THEN
    UPDATE `enterprise_knowledge_ai.performance_tuning_config`
    SET 
      last_applied = CURRENT_TIMESTAMP(),
      success_rate = COALESCE(success_rate * 0.9 + 0.1, 0.8) -- Exponential moving average
    WHERE is_active = TRUE;
  END IF;
END;

-- Comprehensive performance optimization scheduler
CREATE OR REPLACE PROCEDURE run_performance_optimization_cycle()
BEGIN
  -- Establish current performance baselines
  CALL establish_performance_baselines();
  
  -- Execute automated performance tuning
  CALL execute_performance_tuning();
  
  -- Clean up old performance data (keep 30 days)
  DELETE FROM `enterprise_knowledge_ai.performance_baseline`
  WHERE DATE(created_timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
END;