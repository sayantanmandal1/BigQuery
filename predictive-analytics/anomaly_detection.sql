-- Anomaly Detection System with AI.GENERATE Explanations
-- This module detects anomalies in data streams and generates detailed explanations

-- Create anomaly detection function using statistical methods and AI explanations
CREATE OR REPLACE FUNCTION detect_anomalies_with_explanations(
  metric_name STRING,
  current_value FLOAT64,
  lookback_days INT64
)
RETURNS STRUCT<
  is_anomaly BOOL,
  anomaly_score FLOAT64,
  explanation STRING,
  recommended_actions STRING,
  severity_level STRING
>
LANGUAGE SQL
AS (
  WITH historical_stats AS (
    SELECT 
      AVG(metric_value) as mean_value,
      STDDEV(metric_value) as std_dev,
      MIN(metric_value) as min_value,
      MAX(metric_value) as max_value,
      COUNT(*) as data_points
    FROM `enterprise_knowledge_ai.business_metrics`
    WHERE metric_name = metric_name
      AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL lookback_days DAY)
  ),
  anomaly_calculation AS (
    SELECT 
      current_value,
      mean_value,
      std_dev,
      ABS(current_value - mean_value) / NULLIF(std_dev, 0) as z_score,
      CASE 
        WHEN ABS(current_value - mean_value) / NULLIF(std_dev, 0) > 3 THEN TRUE
        WHEN current_value > max_value * 1.5 OR current_value < min_value * 0.5 THEN TRUE
        ELSE FALSE
      END as is_anomaly,
      ABS(current_value - mean_value) / NULLIF(std_dev, 0) as anomaly_score
    FROM historical_stats
  )
  SELECT AS STRUCT
    is_anomaly,
    anomaly_score,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze this anomaly detection result: ',
        'Metric: ', metric_name,
        ', Current Value: ', CAST(current_value AS STRING),
        ', Historical Mean: ', CAST(mean_value AS STRING),
        ', Standard Deviation: ', CAST(std_dev AS STRING),
        ', Z-Score: ', CAST(z_score AS STRING),
        ', Is Anomaly: ', CAST(is_anomaly AS STRING),
        '. Provide a detailed explanation of what this anomaly might indicate, ',
        'potential root causes, and business implications.'
      )
    ) AS explanation,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Based on this anomaly in ', metric_name, ' with value ', CAST(current_value AS STRING),
        ' (z-score: ', CAST(z_score AS STRING), '), ',
        'provide specific, actionable recommendations for immediate investigation and response. ',
        'Consider both technical and business perspectives.'
      )
    ) AS recommended_actions,
    CASE 
      WHEN anomaly_score > 4 THEN 'CRITICAL'
      WHEN anomaly_score > 3 THEN 'HIGH'
      WHEN anomaly_score > 2 THEN 'MEDIUM'
      ELSE 'LOW'
    END as severity_level
  FROM anomaly_calculation
);

-- Real-time anomaly monitoring procedure
CREATE OR REPLACE PROCEDURE monitor_anomalies()
BEGIN
  DECLARE done BOOL DEFAULT FALSE;
  DECLARE metric STRING;
  DECLARE current_val FLOAT64;
  DECLARE anomaly_result STRUCT<
    is_anomaly BOOL,
    anomaly_score FLOAT64,
    explanation STRING,
    recommended_actions STRING,
    severity_level STRING
  >;
  
  -- Cursor for current metrics
  DECLARE metrics_cursor CURSOR FOR
    SELECT 
      metric_name,
      metric_value
    FROM `enterprise_knowledge_ai.current_metrics`
    WHERE last_updated >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);
  
  DECLARE CONTINUE HANDLER FOR NOT_FOUND SET done = TRUE;
  
  OPEN metrics_cursor;
  
  metrics_loop: LOOP
    FETCH metrics_cursor INTO metric, current_val;
    IF done THEN
      LEAVE metrics_loop;
    END IF;
    
    -- Detect anomalies for each metric
    SET anomaly_result = detect_anomalies_with_explanations(metric, current_val, 30);
    
    -- Store anomaly results if detected
    IF anomaly_result.is_anomaly THEN
      INSERT INTO `enterprise_knowledge_ai.detected_anomalies`
      VALUES (
        GENERATE_UUID(),
        metric,
        current_val,
        anomaly_result.anomaly_score,
        anomaly_result.explanation,
        anomaly_result.recommended_actions,
        anomaly_result.severity_level,
        CURRENT_TIMESTAMP(),
        FALSE -- not_resolved
      );
      
      -- Generate alert for high severity anomalies
      IF anomaly_result.severity_level IN ('CRITICAL', 'HIGH') THEN
        CALL generate_anomaly_alert(metric, anomaly_result);
      END IF;
    END IF;
  END LOOP;
  
  CLOSE metrics_cursor;
END;

-- Generate early warning reports for emerging risks
CREATE OR REPLACE FUNCTION generate_risk_assessment(
  analysis_period_days INT64
)
RETURNS TABLE<
  risk_category STRING,
  risk_level STRING,
  probability_score FLOAT64,
  impact_assessment STRING,
  mitigation_strategies STRING,
  timeline_urgency STRING
>
LANGUAGE SQL
AS (
  WITH risk_patterns AS (
    SELECT 
      metric_name,
      COUNT(*) as anomaly_count,
      AVG(anomaly_score) as avg_severity,
      MAX(anomaly_score) as max_severity,
      STRING_AGG(DISTINCT severity_level) as severity_levels
    FROM `enterprise_knowledge_ai.detected_anomalies`
    WHERE detected_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL analysis_period_days DAY)
    GROUP BY metric_name
    HAVING COUNT(*) >= 3 -- Pattern of repeated anomalies
  ),
  risk_analysis AS (
    SELECT 
      CASE 
        WHEN metric_name LIKE '%revenue%' THEN 'Financial Performance'
        WHEN metric_name LIKE '%customer%' THEN 'Customer Satisfaction'
        WHEN metric_name LIKE '%operational%' THEN 'Operational Efficiency'
        ELSE 'General Business'
      END as risk_category,
      CASE 
        WHEN max_severity > 4 AND anomaly_count > 5 THEN 'CRITICAL'
        WHEN max_severity > 3 AND anomaly_count > 3 THEN 'HIGH'
        WHEN avg_severity > 2 THEN 'MEDIUM'
        ELSE 'LOW'
      END as risk_level,
      LEAST(1.0, (anomaly_count * avg_severity) / 20.0) as probability_score,
      metric_name,
      anomaly_count,
      avg_severity
    FROM risk_patterns
  )
  SELECT 
    risk_category,
    risk_level,
    probability_score,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Assess the business impact of this emerging risk pattern: ',
        'Category: ', risk_category,
        ', Risk Level: ', risk_level,
        ', Probability: ', CAST(probability_score AS STRING),
        ', Anomaly Count: ', CAST(anomaly_count AS STRING),
        ', Average Severity: ', CAST(avg_severity AS STRING),
        '. Provide detailed impact assessment considering financial, operational, and strategic implications.'
      )
    ) AS impact_assessment,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Develop specific mitigation strategies for this risk: ',
        'Category: ', risk_category,
        ', Risk Level: ', risk_level,
        ', Probability: ', CAST(probability_score AS STRING),
        '. Provide actionable, prioritized mitigation strategies with implementation steps.'
      )
    ) AS mitigation_strategies,
    CASE 
      WHEN risk_level = 'CRITICAL' THEN 'IMMEDIATE (24 hours)'
      WHEN risk_level = 'HIGH' THEN 'URGENT (72 hours)'
      WHEN risk_level = 'MEDIUM' THEN 'PLANNED (1 week)'
      ELSE 'MONITORED (1 month)'
    END as timeline_urgency
  FROM risk_analysis
);

-- Create tables for anomaly tracking
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.detected_anomalies` (
  anomaly_id STRING NOT NULL,
  metric_name STRING NOT NULL,
  metric_value FLOAT64,
  anomaly_score FLOAT64,
  explanation STRING,
  recommended_actions STRING,
  severity_level STRING,
  detected_at TIMESTAMP NOT NULL,
  resolved BOOL DEFAULT FALSE
) PARTITION BY DATE(detected_at)
CLUSTER BY metric_name, severity_level;

CREATE OR REPLACE TABLE `enterprise_knowledge_ai.current_metrics` (
  metric_name STRING NOT NULL,
  metric_value FLOAT64,
  last_updated TIMESTAMP NOT NULL
) CLUSTER BY metric_name;