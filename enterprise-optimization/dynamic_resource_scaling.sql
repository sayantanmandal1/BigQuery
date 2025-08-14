-- Dynamic Resource Scaling System
-- Automatically scales compute resources based on workload patterns

-- Create workload monitoring table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.workload_metrics` (
  metric_id STRING NOT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  concurrent_queries INT64,
  avg_query_duration_ms INT64,
  total_slots_used INT64,
  bytes_processed_per_sec INT64,
  ai_function_calls_per_min INT64,
  vector_searches_per_min INT64,
  system_load_pct FLOAT64,
  memory_usage_pct FLOAT64,
  predicted_load_next_hour FLOAT64
) PARTITION BY DATE(timestamp)
CLUSTER BY system_load_pct, concurrent_queries;

-- Create scaling configuration table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.scaling_configuration` (
  config_id STRING NOT NULL,
  resource_type ENUM('compute', 'memory', 'storage', 'ai_quota'),
  min_capacity INT64,
  max_capacity INT64,
  scale_up_threshold FLOAT64,
  scale_down_threshold FLOAT64,
  scale_up_increment INT64,
  scale_down_increment INT64,
  cooldown_period_minutes INT64,
  last_scaling_action TIMESTAMP,
  is_active BOOL DEFAULT TRUE
);

-- Initialize default scaling configuration
INSERT INTO `enterprise_knowledge_ai.scaling_configuration`
(config_id, resource_type, min_capacity, max_capacity, scale_up_threshold, scale_down_threshold, 
 scale_up_increment, scale_down_increment, cooldown_period_minutes)
VALUES 
('compute_scaling', 'compute', 100, 2000, 80.0, 30.0, 200, 100, 5),
('memory_scaling', 'memory', 1000, 10000, 85.0, 40.0, 1000, 500, 10),
('ai_quota_scaling', 'ai_quota', 1000, 50000, 90.0, 50.0, 5000, 2000, 15);

-- Workload prediction function using AI.FORECAST
CREATE OR REPLACE FUNCTION predict_workload_demand(
  hours_ahead INT64 DEFAULT 1
)
RETURNS STRUCT<
  predicted_concurrent_queries FLOAT64,
  predicted_ai_calls FLOAT64,
  confidence_level FLOAT64,
  scaling_recommendation STRING
>
LANGUAGE SQL
AS (
  WITH forecast_data AS (
    SELECT 
      forecast_timestamp,
      forecast_value as predicted_queries,
      confidence_level
    FROM ML.FORECAST(
      MODEL `enterprise_knowledge_ai.workload_forecast_model`,
      STRUCT(hours_ahead AS horizon, 0.8 AS confidence_level)
    )
    WHERE forecast_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL hours_ahead HOUR)
  ),
  ai_forecast AS (
    SELECT 
      forecast_value as predicted_ai_calls
    FROM ML.FORECAST(
      MODEL `enterprise_knowledge_ai.ai_usage_forecast_model`,
      STRUCT(hours_ahead AS horizon, 0.8 AS confidence_level)
    )
    WHERE forecast_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL hours_ahead HOUR)
  )
  SELECT AS STRUCT
    fd.predicted_queries,
    af.predicted_ai_calls,
    fd.confidence_level,
    CASE 
      WHEN fd.predicted_queries > 500 OR af.predicted_ai_calls > 1000 THEN 'SCALE_UP'
      WHEN fd.predicted_queries < 100 AND af.predicted_ai_calls < 200 THEN 'SCALE_DOWN'
      ELSE 'MAINTAIN'
    END as scaling_recommendation
  FROM forecast_data fd
  CROSS JOIN ai_forecast af
);

-- Real-time workload monitoring procedure
CREATE OR REPLACE PROCEDURE monitor_current_workload()
BEGIN
  DECLARE current_load FLOAT64;
  DECLARE concurrent_queries INT64;
  DECLARE ai_calls_per_min INT64;
  
  -- Calculate current system metrics
  SET current_load = (
    SELECT AVG(execution_time_ms) / 1000.0 -- Convert to load percentage
    FROM `enterprise_knowledge_ai.query_performance_log`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE)
  );
  
  SET concurrent_queries = (
    SELECT COUNT(DISTINCT execution_id)
    FROM `enterprise_knowledge_ai.query_performance_log`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 MINUTE)
  );
  
  SET ai_calls_per_min = (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.query_performance_log`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 MINUTE)
      AND query_type IN ('ai_generate', 'ai_forecast')
  );
  
  -- Insert current metrics
  INSERT INTO `enterprise_knowledge_ai.workload_metrics`
  (metric_id, concurrent_queries, system_load_pct, ai_function_calls_per_min, predicted_load_next_hour)
  VALUES (
    GENERATE_UUID(),
    concurrent_queries,
    COALESCE(current_load, 0),
    ai_calls_per_min,
    (SELECT predicted_concurrent_queries FROM UNNEST([predict_workload_demand(1)]))
  );
END;

-- Automatic scaling decision engine
CREATE OR REPLACE PROCEDURE execute_scaling_decisions()
BEGIN
  DECLARE scaling_needed BOOL DEFAULT FALSE;
  DECLARE resource_type STRING;
  DECLARE current_capacity INT64;
  DECLARE recommended_capacity INT64;
  
  FOR scaling_config IN (
    SELECT 
      sc.config_id,
      sc.resource_type as res_type,
      sc.min_capacity,
      sc.max_capacity,
      sc.scale_up_threshold,
      sc.scale_down_threshold,
      sc.scale_up_increment,
      sc.scale_down_increment,
      sc.cooldown_period_minutes,
      sc.last_scaling_action,
      wm.system_load_pct,
      wm.predicted_load_next_hour
    FROM `enterprise_knowledge_ai.scaling_configuration` sc
    CROSS JOIN (
      SELECT 
        system_load_pct,
        predicted_load_next_hour
      FROM `enterprise_knowledge_ai.workload_metrics`
      WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 MINUTE)
      ORDER BY timestamp DESC
      LIMIT 1
    ) wm
    WHERE sc.is_active = TRUE
      AND (sc.last_scaling_action IS NULL 
           OR TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), sc.last_scaling_action, MINUTE) >= sc.cooldown_period_minutes)
  ) DO
    
    SET resource_type = scaling_config.res_type;
    SET scaling_needed = FALSE;
    
    -- Determine if scaling is needed
    IF scaling_config.system_load_pct > scaling_config.scale_up_threshold 
       OR scaling_config.predicted_load_next_hour > scaling_config.scale_up_threshold THEN
      
      SET scaling_needed = TRUE;
      SET recommended_capacity = LEAST(
        scaling_config.max_capacity,
        CAST(scaling_config.system_load_pct * scaling_config.scale_up_increment / 100 AS INT64)
      );
      
      -- Log scaling action
      INSERT INTO `enterprise_knowledge_ai.system_events`
      (event_id, event_type, event_data, timestamp)
      VALUES (
        GENERATE_UUID(),
        'SCALE_UP',
        JSON_OBJECT(
          'resource_type', resource_type,
          'current_load', scaling_config.system_load_pct,
          'recommended_capacity', recommended_capacity,
          'trigger', 'load_threshold_exceeded'
        ),
        CURRENT_TIMESTAMP()
      );
      
    ELSEIF scaling_config.system_load_pct < scaling_config.scale_down_threshold 
           AND scaling_config.predicted_load_next_hour < scaling_config.scale_down_threshold THEN
      
      SET scaling_needed = TRUE;
      SET recommended_capacity = GREATEST(
        scaling_config.min_capacity,
        CAST(scaling_config.system_load_pct * scaling_config.scale_down_increment / 100 AS INT64)
      );
      
      -- Log scaling action
      INSERT INTO `enterprise_knowledge_ai.system_events`
      (event_id, event_type, event_data, timestamp)
      VALUES (
        GENERATE_UUID(),
        'SCALE_DOWN',
        JSON_OBJECT(
          'resource_type', resource_type,
          'current_load', scaling_config.system_load_pct,
          'recommended_capacity', recommended_capacity,
          'trigger', 'load_threshold_low'
        ),
        CURRENT_TIMESTAMP()
      );
    END IF;
    
    -- Update last scaling action timestamp
    IF scaling_needed THEN
      UPDATE `enterprise_knowledge_ai.scaling_configuration`
      SET last_scaling_action = CURRENT_TIMESTAMP()
      WHERE config_id = scaling_config.config_id;
    END IF;
    
  END FOR;
END;

-- Cost-aware scaling optimization
CREATE OR REPLACE FUNCTION calculate_scaling_cost_benefit(
  current_capacity INT64,
  proposed_capacity INT64,
  resource_type STRING
)
RETURNS STRUCT<
  cost_increase FLOAT64,
  performance_benefit FLOAT64,
  roi_score FLOAT64,
  recommendation STRING
>
LANGUAGE SQL
AS (
  WITH cost_calculation AS (
    SELECT 
      CASE resource_type
        WHEN 'compute' THEN (proposed_capacity - current_capacity) * 0.01 -- $0.01 per slot-hour
        WHEN 'memory' THEN (proposed_capacity - current_capacity) * 0.005 -- $0.005 per GB-hour
        WHEN 'ai_quota' THEN (proposed_capacity - current_capacity) * 0.001 -- $0.001 per call
        ELSE 0
      END as cost_delta,
      
      CASE 
        WHEN proposed_capacity > current_capacity THEN 
          LEAST(50.0, (proposed_capacity - current_capacity) / current_capacity * 100)
        ELSE 
          -GREATEST(-20.0, (current_capacity - proposed_capacity) / current_capacity * 100)
      END as perf_benefit
  )
  SELECT AS STRUCT
    cost_delta as cost_increase,
    perf_benefit as performance_benefit,
    CASE 
      WHEN cost_delta > 0 THEN perf_benefit / cost_delta
      ELSE perf_benefit
    END as roi_score,
    CASE 
      WHEN cost_delta > 0 AND (perf_benefit / cost_delta) > 10 THEN 'HIGHLY_RECOMMENDED'
      WHEN cost_delta > 0 AND (perf_benefit / cost_delta) > 5 THEN 'RECOMMENDED'
      WHEN cost_delta > 0 AND (perf_benefit / cost_delta) > 2 THEN 'CONSIDER'
      WHEN cost_delta <= 0 THEN 'COST_SAVING'
      ELSE 'NOT_RECOMMENDED'
    END as recommendation
  FROM cost_calculation
);

-- Automated scaling scheduler (runs every 5 minutes)
CREATE OR REPLACE PROCEDURE run_scaling_cycle()
BEGIN
  -- Monitor current workload
  CALL monitor_current_workload();
  
  -- Execute scaling decisions
  CALL execute_scaling_decisions();
  
  -- Clean up old metrics (keep 7 days)
  DELETE FROM `enterprise_knowledge_ai.workload_metrics`
  WHERE DATE(timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY);
END;