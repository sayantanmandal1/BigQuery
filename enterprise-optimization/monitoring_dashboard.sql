-- Comprehensive System Health Monitoring Dashboard
-- Real-time monitoring and alerting for enterprise-scale operations

-- Create system health metrics table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.system_health_metrics` (
  metric_id STRING NOT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  component_name STRING,
  metric_type ENUM('performance', 'availability', 'accuracy', 'cost', 'security'),
  metric_name STRING,
  metric_value FLOAT64,
  threshold_warning FLOAT64,
  threshold_critical FLOAT64,
  status ENUM('healthy', 'warning', 'critical', 'unknown'),
  alert_sent BOOL DEFAULT FALSE,
  metadata JSON
) PARTITION BY DATE(timestamp)
CLUSTER BY component_name, status;

-- Create system events table for audit trail
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.system_events` (
  event_id STRING NOT NULL,
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  event_type ENUM('SCALE_UP', 'SCALE_DOWN', 'ALERT', 'OPTIMIZATION', 'ERROR', 'RECOVERY'),
  component_name STRING,
  severity ENUM('info', 'warning', 'error', 'critical'),
  event_data JSON,
  resolved BOOL DEFAULT FALSE,
  resolution_time TIMESTAMP
) PARTITION BY DATE(timestamp)
CLUSTER BY event_type, severity;

-- Create alert configuration table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.alert_configuration` (
  alert_id STRING NOT NULL,
  alert_name STRING,
  component_name STRING,
  metric_name STRING,
  condition_type ENUM('threshold', 'trend', 'anomaly', 'pattern'),
  warning_threshold FLOAT64,
  critical_threshold FLOAT64,
  evaluation_window_minutes INT64,
  notification_channels ARRAY<STRING>,
  is_active BOOL DEFAULT TRUE,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Initialize default alert configurations
INSERT INTO `enterprise_knowledge_ai.alert_configuration`
(alert_id, alert_name, component_name, metric_name, condition_type, warning_threshold, critical_threshold, evaluation_window_minutes, notification_channels)
VALUES 
('query_latency_alert', 'Query Latency Monitor', 'semantic_engine', 'avg_query_time_ms', 'threshold', 2000.0, 5000.0, 5, ['email', 'slack']),
('ai_accuracy_alert', 'AI Model Accuracy Monitor', 'ai_models', 'accuracy_score', 'threshold', 0.85, 0.75, 15, ['email', 'pager']),
('system_load_alert', 'System Load Monitor', 'infrastructure', 'cpu_utilization_pct', 'threshold', 80.0, 95.0, 5, ['slack']),
('cost_anomaly_alert', 'Cost Anomaly Detection', 'billing', 'hourly_cost_usd', 'anomaly', 100.0, 500.0, 60, ['email', 'slack']),
('vector_index_alert', 'Vector Index Performance', 'vector_search', 'search_latency_ms', 'threshold', 1000.0, 3000.0, 10, ['email']);

-- Real-time system health monitoring function
CREATE OR REPLACE FUNCTION get_system_health_status()
RETURNS STRUCT<
  overall_status STRING,
  component_statuses ARRAY<STRUCT<component STRING, status STRING, last_check TIMESTAMP>>,
  active_alerts INT64,
  performance_score FLOAT64
>
LANGUAGE SQL
AS (
  WITH component_health AS (
    SELECT 
      component_name,
      CASE 
        WHEN COUNT(CASE WHEN status = 'critical' THEN 1 END) > 0 THEN 'critical'
        WHEN COUNT(CASE WHEN status = 'warning' THEN 1 END) > 0 THEN 'warning'
        ELSE 'healthy'
      END as component_status,
      MAX(timestamp) as last_check
    FROM `enterprise_knowledge_ai.system_health_metrics`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
    GROUP BY component_name
  ),
  overall_health AS (
    SELECT 
      CASE 
        WHEN COUNT(CASE WHEN component_status = 'critical' THEN 1 END) > 0 THEN 'critical'
        WHEN COUNT(CASE WHEN component_status = 'warning' THEN 1 END) > 0 THEN 'warning'
        ELSE 'healthy'
      END as overall_status,
      AVG(CASE 
        WHEN component_status = 'healthy' THEN 100
        WHEN component_status = 'warning' THEN 70
        WHEN component_status = 'critical' THEN 30
        ELSE 50
      END) as performance_score
    FROM component_health
  ),
  active_alerts AS (
    SELECT COUNT(*) as alert_count
    FROM `enterprise_knowledge_ai.system_events`
    WHERE event_type = 'ALERT'
      AND resolved = FALSE
      AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  )
  SELECT AS STRUCT
    oh.overall_status,
    ARRAY_AGG(STRUCT(ch.component_name as component, ch.component_status as status, ch.last_check)) as component_statuses,
    aa.alert_count as active_alerts,
    oh.performance_score
  FROM overall_health oh
  CROSS JOIN active_alerts aa
  CROSS JOIN component_health ch
  GROUP BY oh.overall_status, aa.alert_count, oh.performance_score
);

-- Performance metrics collection procedure
CREATE OR REPLACE PROCEDURE collect_performance_metrics()
BEGIN
  -- Collect semantic engine metrics
  INSERT INTO `enterprise_knowledge_ai.system_health_metrics`
  (metric_id, component_name, metric_type, metric_name, metric_value, threshold_warning, threshold_critical, status)
  SELECT 
    GENERATE_UUID(),
    'semantic_engine',
    'performance',
    'avg_query_time_ms',
    AVG(execution_time_ms),
    2000.0,
    5000.0,
    CASE 
      WHEN AVG(execution_time_ms) > 5000 THEN 'critical'
      WHEN AVG(execution_time_ms) > 2000 THEN 'warning'
      ELSE 'healthy'
    END
  FROM `enterprise_knowledge_ai.query_performance_log`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE)
    AND query_type = 'vector_search';
  
  -- Collect AI model accuracy metrics
  INSERT INTO `enterprise_knowledge_ai.system_health_metrics`
  (metric_id, component_name, metric_type, metric_name, metric_value, threshold_warning, threshold_critical, status)
  SELECT 
    GENERATE_UUID(),
    'ai_models',
    'accuracy',
    'model_accuracy_score',
    AVG(confidence_score),
    0.85,
    0.75,
    CASE 
      WHEN AVG(confidence_score) < 0.75 THEN 'critical'
      WHEN AVG(confidence_score) < 0.85 THEN 'warning'
      ELSE 'healthy'
    END
  FROM `enterprise_knowledge_ai.generated_insights`
  WHERE DATE(created_timestamp) = CURRENT_DATE();
  
  -- Collect system resource metrics
  INSERT INTO `enterprise_knowledge_ai.system_health_metrics`
  (metric_id, component_name, metric_type, metric_name, metric_value, threshold_warning, threshold_critical, status)
  SELECT 
    GENERATE_UUID(),
    'infrastructure',
    'performance',
    'system_load_pct',
    system_load_pct,
    80.0,
    95.0,
    CASE 
      WHEN system_load_pct > 95 THEN 'critical'
      WHEN system_load_pct > 80 THEN 'warning'
      ELSE 'healthy'
    END
  FROM `enterprise_knowledge_ai.workload_metrics`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 5 MINUTE)
  ORDER BY timestamp DESC
  LIMIT 1;
  
  -- Collect cost metrics
  INSERT INTO `enterprise_knowledge_ai.system_health_metrics`
  (metric_id, component_name, metric_type, metric_name, metric_value, threshold_warning, threshold_critical, status)
  SELECT 
    GENERATE_UUID(),
    'billing',
    'cost',
    'hourly_cost_usd',
    SUM(cost_estimate),
    100.0,
    500.0,
    CASE 
      WHEN SUM(cost_estimate) > 500 THEN 'critical'
      WHEN SUM(cost_estimate) > 100 THEN 'warning'
      ELSE 'healthy'
    END
  FROM `enterprise_knowledge_ai.query_performance_log`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);
END;

-- Alert evaluation and notification procedure
CREATE OR REPLACE PROCEDURE evaluate_alerts()
BEGIN
  DECLARE alert_triggered BOOL DEFAULT FALSE;
  
  FOR alert_config IN (
    SELECT 
      alert_id,
      alert_name,
      component_name,
      metric_name,
      condition_type,
      warning_threshold,
      critical_threshold,
      evaluation_window_minutes,
      notification_channels
    FROM `enterprise_knowledge_ai.alert_configuration`
    WHERE is_active = TRUE
  ) DO
    
    -- Evaluate threshold-based alerts
    IF alert_config.condition_type = 'threshold' THEN
      
      FOR metric_record IN (
        SELECT 
          metric_value,
          status,
          timestamp
        FROM `enterprise_knowledge_ai.system_health_metrics`
        WHERE component_name = alert_config.component_name
          AND metric_name = alert_config.metric_name
          AND timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL alert_config.evaluation_window_minutes MINUTE)
          AND status IN ('warning', 'critical')
          AND NOT alert_sent
        ORDER BY timestamp DESC
        LIMIT 1
      ) DO
        
        SET alert_triggered = TRUE;
        
        -- Create alert event
        INSERT INTO `enterprise_knowledge_ai.system_events`
        (event_id, event_type, component_name, severity, event_data)
        VALUES (
          GENERATE_UUID(),
          'ALERT',
          alert_config.component_name,
          CASE WHEN metric_record.status = 'critical' THEN 'critical' ELSE 'warning' END,
          JSON_OBJECT(
            'alert_name', alert_config.alert_name,
            'metric_name', alert_config.metric_name,
            'current_value', metric_record.metric_value,
            'threshold', CASE WHEN metric_record.status = 'critical' 
                             THEN alert_config.critical_threshold 
                             ELSE alert_config.warning_threshold END,
            'notification_channels', alert_config.notification_channels,
            'timestamp', metric_record.timestamp
          )
        );
        
        -- Mark alert as sent
        UPDATE `enterprise_knowledge_ai.system_health_metrics`
        SET alert_sent = TRUE
        WHERE component_name = alert_config.component_name
          AND metric_name = alert_config.metric_name
          AND timestamp = metric_record.timestamp;
          
      END FOR;
    END IF;
    
  END FOR;
END;

-- Dashboard data aggregation views
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.dashboard_performance_summary` AS
SELECT 
  DATE(timestamp) as date,
  component_name,
  metric_name,
  AVG(metric_value) as avg_value,
  MIN(metric_value) as min_value,
  MAX(metric_value) as max_value,
  COUNT(CASE WHEN status = 'critical' THEN 1 END) as critical_count,
  COUNT(CASE WHEN status = 'warning' THEN 1 END) as warning_count,
  COUNT(CASE WHEN status = 'healthy' THEN 1 END) as healthy_count
FROM `enterprise_knowledge_ai.system_health_metrics`
WHERE timestamp >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
GROUP BY DATE(timestamp), component_name, metric_name
ORDER BY date DESC, component_name, metric_name;

CREATE OR REPLACE VIEW `enterprise_knowledge_ai.dashboard_alert_summary` AS
SELECT 
  DATE(timestamp) as date,
  event_type,
  component_name,
  severity,
  COUNT(*) as event_count,
  COUNT(CASE WHEN resolved THEN 1 END) as resolved_count,
  AVG(TIMESTAMP_DIFF(resolution_time, timestamp, MINUTE)) as avg_resolution_time_minutes
FROM `enterprise_knowledge_ai.system_events`
WHERE timestamp >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY DATE(timestamp), event_type, component_name, severity
ORDER BY date DESC, severity DESC;

-- Real-time monitoring dashboard query
CREATE OR REPLACE VIEW `enterprise_knowledge_ai.realtime_dashboard` AS
WITH current_metrics AS (
  SELECT 
    component_name,
    metric_name,
    metric_value,
    status,
    timestamp,
    ROW_NUMBER() OVER (PARTITION BY component_name, metric_name ORDER BY timestamp DESC) as rn
  FROM `enterprise_knowledge_ai.system_health_metrics`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE)
),
recent_events AS (
  SELECT 
    event_type,
    component_name,
    severity,
    event_data,
    timestamp,
    resolved
  FROM `enterprise_knowledge_ai.system_events`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  ORDER BY timestamp DESC
  LIMIT 10
)
SELECT 
  'current_metrics' as data_type,
  JSON_OBJECT(
    'component', cm.component_name,
    'metric', cm.metric_name,
    'value', cm.metric_value,
    'status', cm.status,
    'timestamp', cm.timestamp
  ) as data
FROM current_metrics cm
WHERE cm.rn = 1

UNION ALL

SELECT 
  'recent_events' as data_type,
  JSON_OBJECT(
    'event_type', re.event_type,
    'component', re.component_name,
    'severity', re.severity,
    'data', re.event_data,
    'timestamp', re.timestamp,
    'resolved', re.resolved
  ) as data
FROM recent_events re;

-- Automated monitoring cycle procedure
CREATE OR REPLACE PROCEDURE run_monitoring_cycle()
BEGIN
  -- Collect current performance metrics
  CALL collect_performance_metrics();
  
  -- Evaluate alerts
  CALL evaluate_alerts();
  
  -- Clean up old metrics (keep 30 days)
  DELETE FROM `enterprise_knowledge_ai.system_health_metrics`
  WHERE DATE(timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY);
  
  -- Clean up resolved events (keep 90 days)
  DELETE FROM `enterprise_knowledge_ai.system_events`
  WHERE DATE(timestamp) < DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
    AND resolved = TRUE;
END;