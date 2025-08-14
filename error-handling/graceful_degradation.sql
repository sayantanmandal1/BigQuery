-- Graceful Degradation Logic for AI Model Failures
-- This module provides fallback mechanisms when primary AI models fail

-- Create error handling configuration table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.error_handling_config` (
  config_id STRING NOT NULL,
  primary_model STRING NOT NULL,
  fallback_model STRING,
  fallback_strategy ENUM('simple_fallback', 'rule_based', 'cached_response', 'manual_review') NOT NULL,
  max_retries INT64 DEFAULT 3,
  timeout_seconds INT64 DEFAULT 30,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  updated_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) PARTITION BY DATE(created_timestamp);

-- Insert default configurations
INSERT INTO `enterprise_knowledge_ai.error_handling_config` VALUES
('semantic_search', 'gemini-1.5-pro', 'gemini-1.5-flash', 'simple_fallback', 3, 30, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
('content_generation', 'gemini-1.5-pro', 'gemini-1.0-pro', 'simple_fallback', 2, 45, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
('multimodal_analysis', 'gemini-1.5-pro-vision', 'gemini-1.0-pro-vision', 'rule_based', 2, 60, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),
('forecasting', 'vertex-ai-forecast', NULL, 'cached_response', 1, 120, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());

-- Safe AI generation function with fallback logic
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.safe_generate_insight`(
  input_text STRING,
  model_config_id STRING DEFAULT 'content_generation'
)
RETURNS STRUCT<
  content STRING,
  model_used STRING,
  success BOOL,
  error_message STRING,
  confidence_score FLOAT64
>
LANGUAGE SQL
AS (
  WITH config AS (
    SELECT primary_model, fallback_model, fallback_strategy, max_retries
    FROM `enterprise_knowledge_ai.error_handling_config`
    WHERE config_id = model_config_id
  ),
  primary_attempt AS (
    SELECT 
      CASE 
        WHEN LENGTH(input_text) = 0 THEN 
          STRUCT(
            'Invalid input: empty text provided' AS content,
            'none' AS model_used,
            FALSE AS success,
            'Empty input validation failed' AS error_message,
            0.0 AS confidence_score
          )
        WHEN LENGTH(input_text) > 32000 THEN
          STRUCT(
            'Input too long for processing' AS content,
            'none' AS model_used,
            FALSE AS success,
            'Input exceeds maximum length' AS error_message,
            0.0 AS confidence_score
          )
        ELSE
          (
            SELECT 
              STRUCT(
                COALESCE(
                  AI.GENERATE(
                    MODEL CONCAT('`', (SELECT primary_model FROM config), '`'),
                    input_text
                  ),
                  'Primary model generation failed'
                ) AS content,
                (SELECT primary_model FROM config) AS model_used,
                TRUE AS success,
                '' AS error_message,
                0.85 AS confidence_score
              )
          )
      END AS result
  ),
  fallback_attempt AS (
    SELECT 
      CASE 
        WHEN primary_attempt.result.success = FALSE AND (SELECT fallback_model FROM config) IS NOT NULL THEN
          STRUCT(
            COALESCE(
              AI.GENERATE(
                MODEL CONCAT('`', (SELECT fallback_model FROM config), '`'),
                CONCAT('Simplified analysis: ', SUBSTR(input_text, 1, 1000))
              ),
              'Fallback model also failed'
            ) AS content,
            (SELECT fallback_model FROM config) AS model_used,
            TRUE AS success,
            'Used fallback model' AS error_message,
            0.65 AS confidence_score
          )
        WHEN primary_attempt.result.success = FALSE AND (SELECT fallback_strategy FROM config) = 'rule_based' THEN
          STRUCT(
            CONCAT('Rule-based analysis: Key topics identified in input. Manual review recommended for: ', 
                   SUBSTR(input_text, 1, 100), '...') AS content,
            'rule_based_fallback' AS model_used,
            TRUE AS success,
            'Used rule-based fallback' AS error_message,
            0.45 AS confidence_score
          )
        WHEN primary_attempt.result.success = FALSE THEN
          STRUCT(
            'Unable to generate insight - manual review required' AS content,
            'manual_review' AS model_used,
            FALSE AS success,
            'All automated methods failed' AS error_message,
            0.0 AS confidence_score
          )
        ELSE primary_attempt.result
      END AS result
    FROM primary_attempt
  )
  SELECT result FROM fallback_attempt
);

-- Safe boolean generation with fallback
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.safe_generate_bool`(
  input_text STRING,
  question STRING
)
RETURNS STRUCT<
  result BOOL,
  confidence FLOAT64,
  method_used STRING,
  error_message STRING
>
LANGUAGE SQL
AS (
  WITH validation_check AS (
    SELECT 
      CASE 
        WHEN LENGTH(input_text) = 0 OR LENGTH(question) = 0 THEN FALSE
        ELSE TRUE
      END AS is_valid
  ),
  primary_attempt AS (
    SELECT 
      CASE 
        WHEN NOT validation_check.is_valid THEN
          STRUCT(
            FALSE AS result,
            0.0 AS confidence,
            'validation_failed' AS method_used,
            'Invalid input parameters' AS error_message
          )
        ELSE
          STRUCT(
            COALESCE(
              AI.GENERATE_BOOL(
                MODEL `gemini-1.5-pro`,
                CONCAT(question, ': ', input_text)
              ),
              FALSE
            ) AS result,
            0.9 AS confidence,
            'primary_model' AS method_used,
            '' AS error_message
          )
      END AS attempt_result
    FROM validation_check
  ),
  fallback_attempt AS (
    SELECT 
      CASE 
        WHEN primary_attempt.attempt_result.method_used = 'validation_failed' THEN
          primary_attempt.attempt_result
        ELSE
          STRUCT(
            COALESCE(
              AI.GENERATE_BOOL(
                MODEL `gemini-1.5-flash`,
                CONCAT('Simple yes/no: ', question, ' - ', SUBSTR(input_text, 1, 500))
              ),
              -- Rule-based fallback for common patterns
              CASE 
                WHEN LOWER(question) LIKE '%error%' AND LOWER(input_text) LIKE '%error%' THEN TRUE
                WHEN LOWER(question) LIKE '%success%' AND LOWER(input_text) LIKE '%success%' THEN TRUE
                WHEN LOWER(question) LIKE '%quality%' AND LOWER(input_text) LIKE '%good%' THEN TRUE
                ELSE FALSE
              END
            ) AS result,
            0.7 AS confidence,
            'fallback_model' AS method_used,
            'Used fallback due to primary failure' AS error_message
          )
      END AS final_result
    FROM primary_attempt
  )
  SELECT final_result FROM fallback_attempt
);