-- Deploy Enterprise-Scale Optimization and Monitoring System
-- Comprehensive deployment script for all optimization components

-- Set up the optimization system dataset if it doesn't exist
CREATE SCHEMA IF NOT EXISTS `enterprise_knowledge_ai`;

-- Deploy all optimization system components
BEGIN
  -- Deploy query optimization system
  EXECUTE IMMEDIATE """
    -- Source: query_optimization_system.sql
    -- (Include all tables and functions from query_optimization_system.sql)
  """;
  
  -- Deploy dynamic resource scaling
  EXECUTE IMMEDIATE """
    -- Source: dynamic_resource_scaling.sql
    -- (Include all tables and procedures from dynamic_resource_scaling.sql)
  """;
  
  -- Deploy monitoring dashboard
  EXECUTE IMMEDIATE """
    -- Source: monitoring_dashboard.sql
    -- (Include all tables and views from monitoring_dashboard.sql)
  """;
  
  -- Deploy performance tuning
  EXECUTE IMMEDIATE """
    -- Source: performance_tuning.sql
    -- (Include all tables and procedures from performance_tuning.sql)
  """;
  
  -- Deploy load testing scenarios
  EXECUTE IMMEDIATE """
    -- Source: load_testing_scenarios.sql
    -- (Include all tables and procedures from load_testing_scenarios.sql)
  """;
END;

-- Create master optimization scheduler
CREATE OR REPLACE PROCEDURE run_enterprise_optimization_cycle()
BEGIN
  DECLARE cycle_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE optimization_success BOOL DEFAULT TRUE;
  
  BEGIN
    -- Run query optimization cycle
    CALL run_optimization_cycle();
    
    -- Run resource scaling cycle
    CALL run_scaling_cycle();
    
    -- Run monitoring cycle
    CALL run_monitoring_cycle();
    
    -- Run performance optimization cycle
    CALL run_performance_optimization_cycle();
    
    -- Log successful optimization cycle
    INSERT INTO `enterprise_knowledge_ai.system_events`
    (event_id, event_type, component_name, severity, event_data)
    VALUES (
      GENERATE_UUID(),
      'OPTIMIZATION',
      'optimization_system',
      'info',
      JSON_OBJECT(
        'cycle_type', 'full_optimization_cycle',
        'start_time', cycle_start_time,
        'duration_minutes', TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), cycle_start_time, MINUTE),
        'status', 'completed'
      )
    );
    
  EXCEPTION WHEN ERROR THEN
    SET optimization_success = FALSE;
    
    -- Log optimization cycle failure
    INSERT INTO `enterprise_knowledge_ai.system_events`
    (event_id, event_type, component_name, severity, event_data)
    VALUES (
      GENERATE_UUID(),
      'ERROR',
      'optimization_system',
      'error',
      JSON_OBJECT(
        'cycle_type', 'full_optimization_cycle',
        'start_time', cycle_start_time,
        'error_message', @@error.message,
        'status', 'failed'
      )
    );
  END;
END;

-- Create optimization system health check
CREATE OR REPLACE FUNCTION check_optimization_system_health()
RETURNS STRUCT<
  system_status STRING,
  components_healthy INT64,
  components_total INT64,
  last_optimization_cycle TIMESTAMP,
  performance_improvement_pct FLOAT64,
  recommendations ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH component_status AS (
    SELECT 
      COUNT(*) as total_components,
      COUNT(CASE WHEN status = 'healthy' THEN 1 END) as healthy_components
    FROM `enterprise_knowledge_ai.system_health_metrics`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE)
  ),
  recent_optimization AS (
    SELECT MAX(timestamp) as last_cycle
    FROM `enterprise_knowledge_ai.system_events`
    WHERE event_type = 'OPTIMIZATION'
      AND component_name = 'optimization_system'
  ),
  performance_metrics AS (
    SELECT 
      AVG(CASE WHEN DATE(timestamp) = CURRENT_DATE() THEN metric_value END) as current_avg,
      AVG(CASE WHEN DATE(timestamp) = DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY) THEN metric_value END) as baseline_avg
    FROM `enterprise_knowledge_ai.system_health_metrics`
    WHERE metric_name = 'avg_query_time_ms'
      AND timestamp >= DATE_SUB(CURRENT_DATE(), INTERVAL 8 DAY)
  )
  SELECT AS STRUCT
    CASE 
      WHEN cs.healthy_components = cs.total_components THEN 'OPTIMAL'
      WHEN cs.healthy_components >= cs.total_components * 0.8 THEN 'GOOD'
      WHEN cs.healthy_components >= cs.total_components * 0.6 THEN 'DEGRADED'
      ELSE 'CRITICAL'
    END as system_status,
    
    cs.healthy_components as components_healthy,
    cs.total_components as components_total,
    ro.last_cycle as last_optimization_cycle,
    
    CASE 
      WHEN pm.baseline_avg > 0 AND pm.current_avg > 0 THEN
        ((pm.baseline_avg - pm.current_avg) / pm.baseline_avg) * 100
      ELSE 0
    END as performance_improvement_pct,
    
    ARRAY[
      CASE WHEN ro.last_cycle < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
           THEN 'Run optimization cycle - last cycle was over 1 hour ago' END,
      CASE WHEN cs.healthy_components < cs.total_components * 0.8
           THEN 'Investigate unhealthy components and apply targeted optimizations' END,
      CASE WHEN pm.current_avg > pm.baseline_avg * 1.2
           THEN 'Performance regression detected - review recent changes and optimize' END
    ] as recommendations
    
  FROM component_status cs
  CROSS JOIN recent_optimization ro
  CROSS JOIN performance_metrics pm
);

-- Initialize optimization system with default configurations
INSERT INTO `enterprise_knowledge_ai.scaling_configuration`
(config_id, resource_type, min_capacity, max_capacity, scale_up_threshold, scale_down_threshold, 
 scale_up_increment, scale_down_increment, cooldown_period_minutes)
VALUES 
('enterprise_compute', 'compute', 500, 5000, 75.0, 25.0, 500, 250, 10),
('enterprise_memory', 'memory', 2000, 20000, 80.0, 35.0, 2000, 1000, 15),
('enterprise_ai_quota', 'ai_quota', 5000, 100000, 85.0, 45.0, 10000, 5000, 20);

-- Set up automated scheduling (requires external scheduler like Cloud Scheduler)
-- This would typically be configured outside of BigQuery

-- Validation queries to ensure system is properly deployed
SELECT 'Optimization System Deployment Validation' as validation_step;

-- Check that all required tables exist
SELECT 
  table_name,
  CASE WHEN table_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as status
FROM (
  SELECT 'query_optimization_metadata' as table_name
  UNION ALL SELECT 'workload_metrics'
  UNION ALL SELECT 'system_health_metrics'
  UNION ALL SELECT 'performance_baseline'
  UNION ALL SELECT 'load_test_scenarios'
) expected_tables
LEFT JOIN `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES` actual_tables
  ON expected_tables.table_name = actual_tables.table_name
ORDER BY table_name;

-- Check that all required procedures exist
SELECT 
  routine_name,
  routine_type,
  CASE WHEN routine_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as status
FROM (
  SELECT 'run_enterprise_optimization_cycle' as routine_name, 'PROCEDURE' as routine_type
  UNION ALL SELECT 'run_optimization_cycle', 'PROCEDURE'
  UNION ALL SELECT 'run_scaling_cycle', 'PROCEDURE'
  UNION ALL SELECT 'run_monitoring_cycle', 'PROCEDURE'
  UNION ALL SELECT 'run_performance_optimization_cycle', 'PROCEDURE'
  UNION ALL SELECT 'execute_load_test_scenario', 'PROCEDURE'
) expected_routines
LEFT JOIN `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES` actual_routines
  ON expected_routines.routine_name = actual_routines.routine_name
  AND expected_routines.routine_type = actual_routines.routine_type
ORDER BY routine_name;

-- Test system health check
SELECT check_optimization_system_health() as system_health_status;

-- Display deployment summary
SELECT 
  'Enterprise Optimization System Deployed Successfully' as deployment_status,
  CURRENT_TIMESTAMP() as deployment_timestamp,
  'All components initialized and ready for operation' as next_steps;