-- Scenario Planning Engine with Probability Assessments
-- This module creates multiple future scenarios with probability calculations

-- Create scenario planning function that generates multiple future scenarios
CREATE OR REPLACE FUNCTION generate_scenario_analysis(
  base_metric STRING,
  scenario_horizon_days INT64,
  market_conditions ARRAY<STRING>
)
RETURNS TABLE<
  scenario_id STRING,
  scenario_name STRING,
  probability_score FLOAT64,
  projected_outcome FLOAT64,
  confidence_interval_lower FLOAT64,
  confidence_interval_upper FLOAT64,
  key_assumptions STRING,
  risk_factors STRING,
  success_indicators STRING
>
LANGUAGE SQL
AS (
  WITH base_forecast AS (
    SELECT 
      forecast_value,
      prediction_interval_lower_bound,
      prediction_interval_upper_bound
    FROM generate_business_forecast(base_metric, scenario_horizon_days, 0.95)
    WHERE forecast_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL scenario_horizon_days DAY)
    LIMIT 1
  ),
  scenario_variations AS (
    SELECT 
      'optimistic' as scenario_type,
      1.2 as multiplier,
      0.25 as probability_weight,
      'Strong market growth, successful product launches, favorable economic conditions' as assumptions
    UNION ALL
    SELECT 
      'realistic' as scenario_type,
      1.0 as multiplier,
      0.5 as probability_weight,
      'Current trends continue, moderate market growth, stable competitive position' as assumptions
    UNION ALL
    SELECT 
      'pessimistic' as scenario_type,
      0.8 as multiplier,
      0.2 as probability_weight,
      'Market downturn, increased competition, economic headwinds' as assumptions
    UNION ALL
    SELECT 
      'disruption' as scenario_type,
      0.6 as multiplier,
      0.05 as probability_weight,
      'Major market disruption, technology shifts, regulatory changes' as assumptions
  )
  SELECT 
    GENERATE_UUID() as scenario_id,
    CONCAT(UPPER(SUBSTR(scenario_type, 1, 1)), SUBSTR(scenario_type, 2)) as scenario_name,
    probability_weight as probability_score,
    forecast_value * multiplier as projected_outcome,
    prediction_interval_lower_bound * multiplier * 0.9 as confidence_interval_lower,
    prediction_interval_upper_bound * multiplier * 1.1 as confidence_interval_upper,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Elaborate on these key assumptions for the ', scenario_type, ' scenario: ',
        assumptions,
        '. Provide specific, measurable assumptions for ', base_metric, 
        ' over the next ', CAST(scenario_horizon_days AS STRING), ' days.'
      )
    ) as key_assumptions,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Identify and analyze key risk factors for the ', scenario_type, ' scenario ',
        'affecting ', base_metric, '. Consider internal and external risks, ',
        'their likelihood, and potential impact magnitude.'
      )
    ) as risk_factors,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Define specific, measurable success indicators for the ', scenario_type, ' scenario ',
        'for ', base_metric, '. Include leading indicators, milestone metrics, ',
        'and early warning signals that would confirm this scenario is unfolding.'
      )
    ) as success_indicators
  FROM base_forecast
  CROSS JOIN scenario_variations
);

-- Monte Carlo simulation for probability assessment
CREATE OR REPLACE FUNCTION monte_carlo_scenario_simulation(
  metric_name STRING,
  simulation_runs INT64,
  time_horizon_days INT64
)
RETURNS TABLE<
  outcome_percentile FLOAT64,
  projected_value FLOAT64,
  probability_density FLOAT64,
  scenario_classification STRING
>
LANGUAGE SQL
AS (
  WITH historical_volatility AS (
    SELECT 
      STDDEV(metric_value) / AVG(metric_value) as volatility_ratio,
      AVG(metric_value) as mean_value
    FROM `enterprise_knowledge_ai.business_metrics`
    WHERE metric_name = metric_name
      AND date >= DATE_SUB(CURRENT_DATE(), INTERVAL 365 DAY)
  ),
  simulation_parameters AS (
    SELECT 
      mean_value,
      volatility_ratio,
      mean_value * (1 + RAND() * volatility_ratio * 2 - volatility_ratio) as simulated_outcome,
      ROW_NUMBER() OVER (ORDER BY RAND()) as simulation_id
    FROM historical_volatility
    CROSS JOIN UNNEST(GENERATE_ARRAY(1, simulation_runs)) as run_number
  ),
  percentile_analysis AS (
    SELECT 
      simulated_outcome,
      PERCENT_RANK() OVER (ORDER BY simulated_outcome) as percentile_rank,
      COUNT(*) OVER () as total_simulations
    FROM simulation_parameters
  )
  SELECT 
    ROUND(percentile_rank, 2) as outcome_percentile,
    simulated_outcome as projected_value,
    1.0 / total_simulations as probability_density,
    CASE 
      WHEN percentile_rank >= 0.9 THEN 'Highly Optimistic'
      WHEN percentile_rank >= 0.7 THEN 'Optimistic'
      WHEN percentile_rank >= 0.3 THEN 'Realistic'
      WHEN percentile_rank >= 0.1 THEN 'Pessimistic'
      ELSE 'Highly Pessimistic'
    END as scenario_classification
  FROM percentile_analysis
  WHERE MOD(CAST(percentile_rank * 100 AS INT64), 5) = 0 -- Sample every 5th percentile
);

-- Comprehensive scenario planning procedure
CREATE OR REPLACE PROCEDURE comprehensive_scenario_planning(
  target_metrics ARRAY<STRING>,
  planning_horizon_days INT64
)
BEGIN
  DECLARE metric STRING;
  DECLARE i INT64 DEFAULT 0;
  
  -- Clear previous scenario analyses
  DELETE FROM `enterprise_knowledge_ai.scenario_analyses`
  WHERE generated_at < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);
  
  WHILE i < ARRAY_LENGTH(target_metrics) DO
    SET metric = target_metrics[OFFSET(i)];
    
    -- Generate scenario analysis for each metric
    INSERT INTO `enterprise_knowledge_ai.scenario_analyses`
    SELECT 
      scenario_id,
      metric as metric_name,
      scenario_name,
      probability_score,
      projected_outcome,
      confidence_interval_lower,
      confidence_interval_upper,
      key_assumptions,
      risk_factors,
      success_indicators,
      CURRENT_TIMESTAMP() as generated_at,
      planning_horizon_days as horizon_days
    FROM generate_scenario_analysis(metric, planning_horizon_days, ['growth', 'stable', 'decline']);
    
    -- Generate Monte Carlo simulation results
    INSERT INTO `enterprise_knowledge_ai.monte_carlo_results`
    SELECT 
      GENERATE_UUID() as simulation_id,
      metric as metric_name,
      outcome_percentile,
      projected_value,
      probability_density,
      scenario_classification,
      CURRENT_TIMESTAMP() as generated_at,
      planning_horizon_days as horizon_days
    FROM monte_carlo_scenario_simulation(metric, 1000, planning_horizon_days);
    
    SET i = i + 1;
  END WHILE;
  
  -- Generate cross-scenario impact analysis
  INSERT INTO `enterprise_knowledge_ai.cross_scenario_impacts`
  SELECT 
    GENERATE_UUID() as analysis_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze cross-scenario impacts across these metrics: ',
        ARRAY_TO_STRING(target_metrics, ', '),
        '. Identify interdependencies, cascade effects, and systemic risks. ',
        'Consider how scenarios in one metric might influence others.'
      )
    ) as impact_analysis,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Provide strategic recommendations for managing portfolio risk across scenarios for: ',
        ARRAY_TO_STRING(target_metrics, ', '),
        '. Include hedging strategies, contingency planning, and resource allocation guidance.'
      )
    ) as strategic_recommendations,
    CURRENT_TIMESTAMP() as generated_at
  FROM (SELECT 1); -- Dummy table for single execution
END;

-- Create tables for scenario planning results
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.scenario_analyses` (
  scenario_id STRING NOT NULL,
  metric_name STRING NOT NULL,
  scenario_name STRING,
  probability_score FLOAT64,
  projected_outcome FLOAT64,
  confidence_interval_lower FLOAT64,
  confidence_interval_upper FLOAT64,
  key_assumptions STRING,
  risk_factors STRING,
  success_indicators STRING,
  generated_at TIMESTAMP NOT NULL,
  horizon_days INT64
) PARTITION BY DATE(generated_at)
CLUSTER BY metric_name, scenario_name;

CREATE OR REPLACE TABLE `enterprise_knowledge_ai.monte_carlo_results` (
  simulation_id STRING NOT NULL,
  metric_name STRING NOT NULL,
  outcome_percentile FLOAT64,
  projected_value FLOAT64,
  probability_density FLOAT64,
  scenario_classification STRING,
  generated_at TIMESTAMP NOT NULL,
  horizon_days INT64
) PARTITION BY DATE(generated_at)
CLUSTER BY metric_name, scenario_classification;

CREATE OR REPLACE TABLE `enterprise_knowledge_ai.cross_scenario_impacts` (
  analysis_id STRING NOT NULL,
  impact_analysis STRING,
  strategic_recommendations STRING,
  generated_at TIMESTAMP NOT NULL
) PARTITION BY DATE(generated_at);