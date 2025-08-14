-- Automated Forecasting Service using AI.FORECAST
-- This module implements automated forecasting for key business metrics with confidence intervals

-- Create forecasting models for different business metrics
CREATE OR REPLACE MODEL `enterprise_knowledge_ai.revenue_forecast_model`
OPTIONS(
  model_type='ARIMA_PLUS',
  time_series_timestamp_col='date',
  time_series_data_col='revenue',
  auto_arima=TRUE,
  data_frequency='DAILY'
) AS
SELECT 
  date,
  revenue
FROM `enterprise_knowledge_ai.business_metrics`
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 2 YEAR);

-- Create forecasting function with confidence intervals
CREATE OR REPLACE FUNCTION generate_business_forecast(
  metric_name STRING,
  forecast_horizon INT64,
  confidence_level FLOAT64
)
RETURNS TABLE<
  forecast_timestamp TIMESTAMP,
  forecast_value FLOAT64,
  prediction_interval_lower_bound FLOAT64,
  prediction_interval_upper_bound FLOAT64,
  confidence_level FLOAT64,
  strategic_recommendations STRING
>
LANGUAGE SQL
AS (
  WITH forecast_results AS (
    SELECT 
      forecast_timestamp,
      forecast_value,
      prediction_interval_lower_bound,
      prediction_interval_upper_bound,
      confidence_level
    FROM ML.FORECAST(
      MODEL CASE 
        WHEN metric_name = 'revenue' THEN `enterprise_knowledge_ai.revenue_forecast_model`
        WHEN metric_name = 'customer_acquisition' THEN `enterprise_knowledge_ai.customer_forecast_model`
        WHEN metric_name = 'operational_costs' THEN `enterprise_knowledge_ai.costs_forecast_model`
        ELSE `enterprise_knowledge_ai.revenue_forecast_model`
      END,
      STRUCT(forecast_horizon AS horizon, confidence_level AS confidence_level)
    )
  )
  SELECT 
    forecast_timestamp,
    forecast_value,
    prediction_interval_lower_bound,
    prediction_interval_upper_bound,
    confidence_level,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze this forecast trend and provide strategic recommendations: ',
        'Metric: ', metric_name,
        ', Predicted Value: ', CAST(forecast_value AS STRING),
        ', Lower Bound: ', CAST(prediction_interval_lower_bound AS STRING),
        ', Upper Bound: ', CAST(prediction_interval_upper_bound AS STRING),
        ', Confidence: ', CAST(confidence_level AS STRING),
        '. Consider market trends, seasonal patterns, and business context.'
      )
    ) AS strategic_recommendations
  FROM forecast_results
);

-- Automated forecasting procedure that runs on schedule
CREATE OR REPLACE PROCEDURE automated_forecast_generation()
BEGIN
  -- Generate forecasts for all key business metrics
  DECLARE metrics ARRAY<STRING> DEFAULT ['revenue', 'customer_acquisition', 'operational_costs', 'market_share'];
  DECLARE metric STRING;
  DECLARE i INT64 DEFAULT 0;
  
  WHILE i < ARRAY_LENGTH(metrics) DO
    SET metric = metrics[OFFSET(i)];
    
    -- Generate 30-day forecast with 95% confidence
    INSERT INTO `enterprise_knowledge_ai.generated_forecasts`
    SELECT 
      GENERATE_UUID() as forecast_id,
      metric as metric_name,
      forecast_timestamp,
      forecast_value,
      prediction_interval_lower_bound,
      prediction_interval_upper_bound,
      confidence_level,
      strategic_recommendations,
      CURRENT_TIMESTAMP() as generated_at
    FROM generate_business_forecast(metric, 30, 0.95);
    
    SET i = i + 1;
  END WHILE;
  
  -- Log successful completion
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'automated_forecasting',
    'SUCCESS',
    'Generated forecasts for all business metrics',
    CURRENT_TIMESTAMP()
  );
END;

-- Create table to store generated forecasts
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.generated_forecasts` (
  forecast_id STRING NOT NULL,
  metric_name STRING NOT NULL,
  forecast_timestamp TIMESTAMP NOT NULL,
  forecast_value FLOAT64,
  prediction_interval_lower_bound FLOAT64,
  prediction_interval_upper_bound FLOAT64,
  confidence_level FLOAT64,
  strategic_recommendations STRING,
  generated_at TIMESTAMP NOT NULL,
  is_active BOOL DEFAULT TRUE
) PARTITION BY DATE(forecast_timestamp)
CLUSTER BY metric_name, generated_at;