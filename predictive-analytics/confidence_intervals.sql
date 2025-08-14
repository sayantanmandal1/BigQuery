-- Confidence Interval Calculations and Trend Analysis
-- This module provides advanced statistical analysis with confidence intervals

-- Advanced confidence interval calculation function
CREATE OR REPLACE FUNCTION calculate_advanced_confidence_intervals(
  metric_name STRING,
  confidence_levels ARRAY<FLOAT64>,
  analysis_window_days INT64
)
RETURNS TABLE<
  confidence_level FLOAT64,
  lower_bound FLOAT64,
  upper_bound FLOAT64,
  margin_of_error FLOAT64,
  sample_size INT64,
  statistical_significance STRING,
  trend_direction STRING,
  trend_strength FLOAT64
>
LANGUAGE SQL
AS (
  WITH statistical_base AS (
    SELECT 
      AVG(metric_value) as mean_value,
      STDDEV(metric_value) as std_dev,
      COUNT(*) as sample_size,
      MIN(metric_value) as min_value,
      MAX(metric_value) as max_value,
      -- Calculate trend using linear regression
      CORR(UNIX_SECONDS(date), metric_value) as trend_correlation,
      -- Slope calculation for trend strength
      (COUNT(*) * SUM(UNIX_SECONDS(date) * metric_value) - SUM(UNIX_SECONDS(date)) * SUM(metric_value)) /
      (COUNT(*) * SUM(UNIX_SECONDS(date) * UNIX_SECONDS(date)) - SUM(UNIX_SECONDS(date)) * SUM(UNIX_SECONDS(date))) as trend_slope
    FROM `enterprise_knowledge_ai.business_metrics`
    WHERE metric_name = metric_name
      AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL analysis_window_days DAY)
  ),
  confidence_calculations AS (
    SELECT 
      confidence_level,
      mean_value,
      std_dev,
      sample_size,
      trend_correlation,
      trend_slope,
      -- T-distribution critical value approximation for different confidence levels
      CASE 
        WHEN confidence_level = 0.90 THEN 1.645
        WHEN confidence_level = 0.95 THEN 1.96
        WHEN confidence_level = 0.99 THEN 2.576
        ELSE 1.96
      END as z_critical,
      std_dev / SQRT(sample_size) as standard_error
    FROM statistical_base
    CROSS JOIN UNNEST(confidence_levels) as confidence_level
  )
  SELECT 
    confidence_level,
    mean_value - (z_critical * standard_error) as lower_bound,
    mean_value + (z_critical * standard_error) as upper_bound,
    z_critical * standard_error as margin_of_error,
    sample_size,
    CASE 
      WHEN sample_size >= 30 AND std_dev > 0 THEN 'STATISTICALLY_SIGNIFICANT'
      WHEN sample_size >= 10 THEN 'MODERATELY_SIGNIFICANT'
      ELSE 'INSUFFICIENT_DATA'
    END as statistical_significance,
    CASE 
      WHEN trend_correlation > 0.1 THEN 'INCREASING'
      WHEN trend_correlation < -0.1 THEN 'DECREASING'
      ELSE 'STABLE'
    END as trend_direction,
    ABS(trend_correlation) as trend_strength
  FROM confidence_calculations
);

-- Comprehensive trend analysis with seasonal decomposition
CREATE OR REPLACE FUNCTION analyze_trends_with_seasonality(
  metric_name STRING,
  analysis_period_days INT64
)
RETURNS STRUCT<
  overall_trend STRING,
  trend_strength FLOAT64,
  seasonal_pattern STRING,
  volatility_level STRING,
  forecast_reliability FLOAT64,
  trend_analysis STRING,
  seasonal_insights STRING
>
LANGUAGE SQL
AS (
  WITH time_series_data AS (
    SELECT 
      date,
      metric_value,
      EXTRACT(DAYOFWEEK FROM date) as day_of_week,
      EXTRACT(MONTH FROM date) as month,
      EXTRACT(QUARTER FROM date) as quarter,
      ROW_NUMBER() OVER (ORDER BY date) as time_index
    FROM `enterprise_knowledge_ai.business_metrics`
    WHERE metric_name = metric_name
      AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL analysis_period_days DAY)
    ORDER BY date
  ),
  trend_calculations AS (
    SELECT 
      CORR(time_index, metric_value) as trend_correlation,
      STDDEV(metric_value) / AVG(metric_value) as coefficient_variation,
      -- Weekly seasonality
      AVG(CASE WHEN day_of_week = 1 THEN metric_value END) as monday_avg,
      AVG(CASE WHEN day_of_week = 7 THEN metric_value END) as sunday_avg,
      -- Monthly seasonality
      STDDEV(AVG(metric_value)) OVER (PARTITION BY month) as monthly_volatility,
      -- Quarterly patterns
      STDDEV(AVG(metric_value)) OVER (PARTITION BY quarter) as quarterly_volatility,
      COUNT(*) as data_points
    FROM time_series_data
    GROUP BY month, quarter
  ),
  seasonality_analysis AS (
    SELECT 
      trend_correlation,
      coefficient_variation,
      data_points,
      CASE 
        WHEN ABS(monday_avg - sunday_avg) / ((monday_avg + sunday_avg) / 2) > 0.1 THEN 'WEEKLY_PATTERN'
        WHEN monthly_volatility > coefficient_variation * 0.5 THEN 'MONTHLY_PATTERN'
        WHEN quarterly_volatility > coefficient_variation * 0.3 THEN 'QUARTERLY_PATTERN'
        ELSE 'NO_CLEAR_PATTERN'
      END as seasonal_pattern,
      CASE 
        WHEN coefficient_variation < 0.1 THEN 'LOW'
        WHEN coefficient_variation < 0.3 THEN 'MODERATE'
        ELSE 'HIGH'
      END as volatility_level
    FROM trend_calculations
    LIMIT 1
  )
  SELECT AS STRUCT
    CASE 
      WHEN trend_correlation > 0.3 THEN 'STRONG_UPWARD'
      WHEN trend_correlation > 0.1 THEN 'MODERATE_UPWARD'
      WHEN trend_correlation < -0.3 THEN 'STRONG_DOWNWARD'
      WHEN trend_correlation < -0.1 THEN 'MODERATE_DOWNWARD'
      ELSE 'STABLE'
    END as overall_trend,
    ABS(trend_correlation) as trend_strength,
    seasonal_pattern,
    volatility_level,
    CASE 
      WHEN data_points >= 90 AND coefficient_variation < 0.2 THEN 0.9
      WHEN data_points >= 30 AND coefficient_variation < 0.3 THEN 0.7
      WHEN data_points >= 10 THEN 0.5
      ELSE 0.3
    END as forecast_reliability,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze this trend pattern for ', metric_name, ': ',
        'Trend Correlation: ', CAST(trend_correlation AS STRING),
        ', Volatility: ', volatility_level,
        ', Data Points: ', CAST(data_points AS STRING),
        '. Provide insights on trend sustainability, potential inflection points, and business implications.'
      )
    ) as trend_analysis,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Interpret seasonal patterns for ', metric_name, ': ',
        'Pattern Type: ', seasonal_pattern,
        ', Volatility: ', volatility_level,
        '. Explain seasonal drivers, business cycle impacts, and planning recommendations.'
      )
    ) as seasonal_insights
  FROM seasonality_analysis
);

-- Predictive confidence scoring for forecasts
CREATE OR REPLACE FUNCTION calculate_forecast_confidence(
  metric_name STRING,
  forecast_horizon_days INT64,
  historical_accuracy_window_days INT64
)
RETURNS STRUCT<
  confidence_score FLOAT64,
  reliability_grade STRING,
  accuracy_metrics STRUCT<
    mean_absolute_error FLOAT64,
    mean_squared_error FLOAT64,
    mean_absolute_percentage_error FLOAT64
  >,
  confidence_factors STRING,
  improvement_recommendations STRING
>
LANGUAGE SQL
AS (
  WITH historical_forecasts AS (
    SELECT 
      forecast_value,
      actual_value,
      ABS(forecast_value - actual_value) as absolute_error,
      POW(forecast_value - actual_value, 2) as squared_error,
      ABS(forecast_value - actual_value) / NULLIF(actual_value, 0) as percentage_error
    FROM `enterprise_knowledge_ai.forecast_accuracy_tracking`
    WHERE metric_name = metric_name
      AND forecast_date >= DATE_SUB(CURRENT_DATE(), INTERVAL historical_accuracy_window_days DAY)
      AND actual_value IS NOT NULL
  ),
  accuracy_calculations AS (
    SELECT 
      AVG(absolute_error) as mae,
      SQRT(AVG(squared_error)) as rmse,
      AVG(percentage_error) as mape,
      COUNT(*) as forecast_count,
      STDDEV(percentage_error) as error_volatility
    FROM historical_forecasts
  ),
  confidence_assessment AS (
    SELECT 
      mae,
      rmse,
      mape,
      forecast_count,
      error_volatility,
      -- Confidence score based on accuracy and consistency
      GREATEST(0.0, LEAST(1.0, 
        (1 - LEAST(mape, 0.5)) * 
        (1 - LEAST(error_volatility, 0.3)) * 
        LEAST(1.0, forecast_count / 10.0)
      )) as confidence_score
    FROM accuracy_calculations
  )
  SELECT AS STRUCT
    confidence_score,
    CASE 
      WHEN confidence_score >= 0.8 THEN 'EXCELLENT'
      WHEN confidence_score >= 0.6 THEN 'GOOD'
      WHEN confidence_score >= 0.4 THEN 'FAIR'
      ELSE 'POOR'
    END as reliability_grade,
    STRUCT(
      mae as mean_absolute_error,
      rmse as mean_squared_error,
      mape as mean_absolute_percentage_error
    ) as accuracy_metrics,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze forecast confidence factors for ', metric_name, ': ',
        'Confidence Score: ', CAST(confidence_score AS STRING),
        ', MAPE: ', CAST(mape AS STRING),
        ', Error Volatility: ', CAST(error_volatility AS STRING),
        ', Sample Size: ', CAST(forecast_count AS STRING),
        '. Explain key factors affecting forecast reliability.'
      )
    ) as confidence_factors,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Recommend improvements for forecast accuracy of ', metric_name, ': ',
        'Current MAPE: ', CAST(mape AS STRING),
        ', Confidence: ', CAST(confidence_score AS STRING),
        '. Suggest data collection, modeling, and process improvements.'
      )
    ) as improvement_recommendations
  FROM confidence_assessment
);

-- Create table for tracking forecast accuracy
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.forecast_accuracy_tracking` (
  tracking_id STRING NOT NULL,
  metric_name STRING NOT NULL,
  forecast_date DATE NOT NULL,
  forecast_value FLOAT64,
  actual_value FLOAT64,
  forecast_horizon_days INT64,
  model_version STRING,
  created_at TIMESTAMP NOT NULL
) PARTITION BY forecast_date
CLUSTER BY metric_name, forecast_horizon_days;