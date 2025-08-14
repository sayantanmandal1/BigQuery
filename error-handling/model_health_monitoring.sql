-- Model Health Monitoring with Automatic Retraining Triggers
-- This module monitors AI model performance and triggers retraining when needed

-- Create model performance tracking table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.model_performance_metrics` (
  metric_id STRING NOT NULL,
  model_name STRING NOT NULL,
  metric_type ENUM('accuracy', 'latency', 'error_rate', 'throughput', 'confidence') NOT NULL,
  metric_value FLOAT64 NOT NULL,
  threshold_min FLOAT64,
  threshold_max FLOAT64,
  measurement_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  status ENUM('healthy', 'warning', 'critical') NOT NULL,
  metadata JSON
) PARTITION BY DATE(measurement_timestamp)
CLUSTER BY model_name, metric_type;

-- Create model health alerts table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.model_health_alerts` (
  alert_id STRING NOT NULL,
  model_name STRING NOT NULL,
  alert_type ENUM('performance_degradation', 'high_error_rate', 'timeout_exceeded', 'retraining_required') NOT NULL,
  severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
  description TEXT,
  triggered_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  resolved_timestamp TIMESTAMP,
  resolution_action TEXT,
  metadata JSON
) PARTITION BY DATE(triggered_timestamp)
CLUSTER BY model_name, severity;

-- Insert baseline performance thresholds
INSERT INTO `enterprise_knowledge_ai.model_performance_metrics` VALUES
('gemini-1.5-pro-accuracy', 'gemini-1.5-pro', 'accuracy', 0.95, 0.85, 1.0, CURRENT_TIMESTAMP(), 'healthy', JSON '{"baseline": true}'),
('gemini-1.5-pro-latency', 'gemini-1.5-pro', 'latency', 2.5, 0.0, 5.0, CURRENT_TIMESTAMP(), 'healthy', JSON '{"unit": "seconds"}'),
('gemini-1.5-pro-error-rate', 'gemini-1.5-pro', 'error_rate', 0.02, 0.0, 0.05, CURRENT_TIMESTAMP(), 'healthy', JSON '{"unit": "percentage"}'),
('gemini-1.5-flash-accuracy', 'gemini-1.5-flash', 'accuracy', 0.88, 0.80, 1.0, CURRENT_TIMESTAMP(), 'healthy', JSON '{"baseline": true}'),
('gemini-1.5-flash-latency', 'gemini-1.5-flash', 'latency', 1.2, 0.0, 3.0, CURRENT_TIMESTAMP(), 'healthy', JSON '{"unit": "seconds"}');

-- Function to record model performance metrics
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.record_model_performance`(
  model_name STRING,
  accuracy_score FLOAT64,
  latency_seconds FLOAT64,
  error_occurred BOOL
)
BEGIN
  DECLARE current_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  DECLARE error_rate FLOAT64;
  
  -- Calculate current error rate for the model
  SET error_rate = (
    SELECT 
      COUNTIF(error_occurred) / COUNT(*) 
    FROM (
      SELECT TRUE as error_occurred WHERE error_occurred
      UNION ALL
      SELECT FALSE as error_occurred FROM UNNEST(GENERATE_ARRAY(1, 99)) -- Simulate recent requests
    )
  );
  
  -- Record accuracy metric
  IF accuracy_score IS NOT NULL THEN
    INSERT INTO `enterprise_knowledge_ai.model_performance_metrics` 
    VALUES (
      GENERATE_UUID(),
      model_name,
      'accuracy',
      accuracy_score,
      0.80,
      1.0,
      current_time,
      CASE 
        WHEN accuracy_score >= 0.85 THEN 'healthy'
        WHEN accuracy_score >= 0.75 THEN 'warning'
        ELSE 'critical'
      END,
      JSON_OBJECT('recorded_by', 'automated_monitoring')
    );
  END IF;
  
  -- Record latency metric
  IF latency_seconds IS NOT NULL THEN
    INSERT INTO `enterprise_knowledge_ai.model_performance_metrics`
    VALUES (
      GENERATE_UUID(),
      model_name,
      'latency',
      latency_seconds,
      0.0,
      CASE model_name 
        WHEN 'gemini-1.5-pro' THEN 5.0
        WHEN 'gemini-1.5-flash' THEN 3.0
        ELSE 10.0
      END,
      current_time,
      CASE 
        WHEN latency_seconds <= 2.0 THEN 'healthy'
        WHEN latency_seconds <= 5.0 THEN 'warning'
        ELSE 'critical'
      END,
      JSON_OBJECT('recorded_by', 'automated_monitoring')
    );
  END IF;
  
  -- Record error rate
  INSERT INTO `enterprise_knowledge_ai.model_performance_metrics`
  VALUES (
    GENERATE_UUID(),
    model_name,
    'error_rate',
    error_rate,
    0.0,
    0.05,
    current_time,
    CASE 
      WHEN error_rate <= 0.02 THEN 'healthy'
      WHEN error_rate <= 0.05 THEN 'warning'
      ELSE 'critical'
    END,
    JSON_OBJECT('recorded_by', 'automated_monitoring', 'sample_size', 100)
  );
  
  -- Check for alert conditions
  CALL `enterprise_knowledge_ai.check_model_health_alerts`(model_name);
END;

-- Procedure to check and generate health alerts
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.check_model_health_alerts`(
  target_model STRING
)
BEGIN
  DECLARE avg_accuracy FLOAT64;
  DECLARE avg_latency FLOAT64;
  DECLARE current_error_rate FLOAT64;
  DECLARE alert_threshold_accuracy FLOAT64 DEFAULT 0.80;
  DECLARE alert_threshold_latency FLOAT64 DEFAULT 8.0;
  DECLARE alert_threshold_error_rate FLOAT64 DEFAULT 0.08;
  
  -- Calculate recent performance averages (last 24 hours)
  SET (avg_accuracy, avg_latency, current_error_rate) = (
    SELECT AS STRUCT
      AVG(CASE WHEN metric_type = 'accuracy' THEN metric_value END) as accuracy,
      AVG(CASE WHEN metric_type = 'latency' THEN metric_value END) as latency,
      AVG(CASE WHEN metric_type = 'error_rate' THEN metric_value END) as error_rate
    FROM `enterprise_knowledge_ai.model_performance_metrics`
    WHERE model_name = target_model
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  );
  
  -- Generate accuracy degradation alert
  IF avg_accuracy < alert_threshold_accuracy THEN
    INSERT INTO `enterprise_knowledge_ai.model_health_alerts`
    VALUES (
      GENERATE_UUID(),
      target_model,
      'performance_degradation',
      CASE 
        WHEN avg_accuracy < 0.70 THEN 'critical'
        WHEN avg_accuracy < 0.75 THEN 'high'
        ELSE 'medium'
      END,
      CONCAT('Model accuracy degraded to ', ROUND(avg_accuracy, 3), ' (threshold: ', alert_threshold_accuracy, ')'),
      CURRENT_TIMESTAMP(),
      NULL,
      NULL,
      JSON_OBJECT(
        'current_accuracy', avg_accuracy,
        'threshold', alert_threshold_accuracy,
        'recommended_action', 'Consider model retraining or fallback activation'
      )
    );
  END IF;
  
  -- Generate high latency alert
  IF avg_latency > alert_threshold_latency THEN
    INSERT INTO `enterprise_knowledge_ai.model_health_alerts`
    VALUES (
      GENERATE_UUID(),
      target_model,
      'timeout_exceeded',
      CASE 
        WHEN avg_latency > 15.0 THEN 'critical'
        WHEN avg_latency > 10.0 THEN 'high'
        ELSE 'medium'
      END,
      CONCAT('Model latency increased to ', ROUND(avg_latency, 2), 's (threshold: ', alert_threshold_latency, 's)'),
      CURRENT_TIMESTAMP(),
      NULL,
      NULL,
      JSON_OBJECT(
        'current_latency', avg_latency,
        'threshold', alert_threshold_latency,
        'recommended_action', 'Check model load and consider scaling'
      )
    );
  END IF;
  
  -- Generate high error rate alert
  IF current_error_rate > alert_threshold_error_rate THEN
    INSERT INTO `enterprise_knowledge_ai.model_health_alerts`
    VALUES (
      GENERATE_UUID(),
      target_model,
      'high_error_rate',
      CASE 
        WHEN current_error_rate > 0.15 THEN 'critical'
        WHEN current_error_rate > 0.10 THEN 'high'
        ELSE 'medium'
      END,
      CONCAT('Model error rate increased to ', ROUND(current_error_rate * 100, 1), '% (threshold: ', ROUND(alert_threshold_error_rate * 100, 1), '%)'),
      CURRENT_TIMESTAMP(),
      NULL,
      NULL,
      JSON_OBJECT(
        'current_error_rate', current_error_rate,
        'threshold', alert_threshold_error_rate,
        'recommended_action', 'Investigate model issues and activate fallback systems'
      )
    );
  END IF;
  
  -- Check if retraining is required (multiple critical alerts in 24h)
  IF (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.model_health_alerts`
    WHERE model_name = target_model
      AND severity IN ('critical', 'high')
      AND triggered_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
      AND resolved_timestamp IS NULL
  ) >= 3 THEN
    INSERT INTO `enterprise_knowledge_ai.model_health_alerts`
    VALUES (
      GENERATE_UUID(),
      target_model,
      'retraining_required',
      'critical',
      CONCAT('Multiple critical issues detected for ', target_model, '. Automatic retraining recommended.'),
      CURRENT_TIMESTAMP(),
      NULL,
      NULL,
      JSON_OBJECT(
        'trigger_reason', 'multiple_critical_alerts',
        'recommended_action', 'Initiate model retraining pipeline',
        'fallback_activation', 'immediate'
      )
    );
  END IF;
END;

-- Function to get current model health status
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.get_model_health_status`(
  model_name STRING
)
RETURNS STRUCT<
  overall_status STRING,
  accuracy_score FLOAT64,
  latency_avg FLOAT64,
  error_rate FLOAT64,
  active_alerts INT64,
  last_check TIMESTAMP,
  recommendations ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH recent_metrics AS (
    SELECT 
      metric_type,
      AVG(metric_value) as avg_value,
      MAX(measurement_timestamp) as last_measurement
    FROM `enterprise_knowledge_ai.model_performance_metrics`
    WHERE model_name = model_name
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    GROUP BY metric_type
  ),
  active_alerts AS (
    SELECT COUNT(*) as alert_count
    FROM `enterprise_knowledge_ai.model_health_alerts`
    WHERE model_name = model_name
      AND resolved_timestamp IS NULL
      AND triggered_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
  )
  SELECT STRUCT(
    CASE 
      WHEN active_alerts.alert_count = 0 THEN 'healthy'
      WHEN active_alerts.alert_count <= 2 THEN 'warning'
      ELSE 'critical'
    END as overall_status,
    
    COALESCE(
      (SELECT avg_value FROM recent_metrics WHERE metric_type = 'accuracy'),
      0.0
    ) as accuracy_score,
    
    COALESCE(
      (SELECT avg_value FROM recent_metrics WHERE metric_type = 'latency'),
      0.0
    ) as latency_avg,
    
    COALESCE(
      (SELECT avg_value FROM recent_metrics WHERE metric_type = 'error_rate'),
      0.0
    ) as error_rate,
    
    active_alerts.alert_count as active_alerts,
    
    COALESCE(
      (SELECT MAX(last_measurement) FROM recent_metrics),
      TIMESTAMP('1970-01-01')
    ) as last_check,
    
    CASE 
      WHEN active_alerts.alert_count >= 3 THEN ['Activate fallback systems', 'Consider model retraining', 'Investigate root cause']
      WHEN active_alerts.alert_count > 0 THEN ['Monitor closely', 'Review recent changes']
      ELSE ['Continue normal operations']
    END as recommendations
  )
  FROM active_alerts
);