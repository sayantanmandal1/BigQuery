-- Data Quality Validation System
-- This module provides comprehensive data quality validation using AI.GENERATE_BOOL

-- Create data quality validation configuration
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.data_quality_config` (
  validation_id STRING NOT NULL,
  data_type ENUM('text', 'structured', 'image', 'multimodal') NOT NULL,
  validation_rule STRING NOT NULL,
  validation_query STRING NOT NULL,
  severity ENUM('low', 'medium', 'high', 'critical') NOT NULL,
  auto_fix BOOL DEFAULT FALSE,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) CLUSTER BY data_type, severity;

-- Insert validation rules
INSERT INTO `enterprise_knowledge_ai.data_quality_config` VALUES
('text_content_quality', 'text', 'Content should be meaningful and coherent', 
 'Is this text content meaningful and suitable for business analysis?', 'high', FALSE, CURRENT_TIMESTAMP()),
('text_language_detection', 'text', 'Content should be in English or specified language',
 'Is this text primarily in English and professionally written?', 'medium', FALSE, CURRENT_TIMESTAMP()),
('structured_data_completeness', 'structured', 'Required fields should not be null or empty',
 'Does this data record contain all required fields with valid values?', 'critical', TRUE, CURRENT_TIMESTAMP()),
('image_business_relevance', 'image', 'Images should be relevant to business context',
 'Is this image relevant for business analysis and of acceptable quality?', 'medium', FALSE, CURRENT_TIMESTAMP()),
('multimodal_consistency', 'multimodal', 'Text and visual content should be consistent',
 'Are the text description and image content consistent with each other?', 'high', FALSE, CURRENT_TIMESTAMP());

-- Create data quality results table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.data_quality_results` (
  result_id STRING NOT NULL,
  source_data_id STRING NOT NULL,
  validation_id STRING NOT NULL,
  validation_passed BOOL NOT NULL,
  confidence_score FLOAT64,
  validation_details TEXT,
  auto_fixed BOOL DEFAULT FALSE,
  validation_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
) PARTITION BY DATE(validation_timestamp)
CLUSTER BY validation_id, validation_passed;

-- Comprehensive data validation function
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.validate_data_quality`(
  data_content STRING,
  data_type STRING,
  additional_context STRING DEFAULT ''
)
RETURNS STRUCT<
  overall_quality_score FLOAT64,
  validation_results ARRAY<STRUCT<
    validation_id STRING,
    passed BOOL,
    confidence FLOAT64,
    details STRING
  >>,
  recommendations ARRAY<STRING>,
  requires_manual_review BOOL
>
LANGUAGE SQL
AS (
  WITH validation_rules AS (
    SELECT validation_id, validation_rule, validation_query, severity
    FROM `enterprise_knowledge_ai.data_quality_config`
    WHERE data_type = data_type OR data_type = 'multimodal'
  ),
  
  validation_results AS (
    SELECT 
      validation_id,
      validation_rule,
      severity,
      `enterprise_knowledge_ai.safe_generate_bool`(
        CONCAT(data_content, COALESCE(CONCAT(' Context: ', additional_context), '')),
        validation_query
      ) AS validation_result
    FROM validation_rules
  ),
  
  quality_assessment AS (
    SELECT 
      validation_id,
      validation_result.result AS passed,
      validation_result.confidence AS confidence,
      CASE 
        WHEN validation_result.result THEN 'Validation passed'
        ELSE CONCAT('Validation failed: ', validation_rule)
      END AS details,
      CASE severity
        WHEN 'critical' THEN 4
        WHEN 'high' THEN 3
        WHEN 'medium' THEN 2
        ELSE 1
      END AS severity_weight,
      validation_result.result AS passed_bool
    FROM validation_results
  ),
  
  overall_score AS (
    SELECT 
      SUM(CASE WHEN passed_bool THEN severity_weight * confidence ELSE 0 END) / 
      SUM(severity_weight) AS quality_score,
      COUNT(*) AS total_validations,
      COUNTIF(passed_bool) AS passed_validations,
      COUNTIF(NOT passed_bool AND severity_weight >= 3) AS critical_failures
    FROM quality_assessment
  ),
  
  recommendations AS (
    SELECT ARRAY_AGG(
      CASE 
        WHEN NOT passed_bool AND severity_weight = 4 THEN 'CRITICAL: Manual review required immediately'
        WHEN NOT passed_bool AND severity_weight = 3 THEN 'HIGH: Data quality issues detected'
        WHEN NOT passed_bool AND severity_weight = 2 THEN 'MEDIUM: Consider data improvement'
        WHEN quality_score < 0.7 THEN 'Overall data quality below threshold'
        ELSE NULL
      END IGNORE NULLS
    ) AS recommendation_list
    FROM quality_assessment, overall_score
  )
  
  SELECT STRUCT(
    COALESCE(overall_score.quality_score, 0.0) AS overall_quality_score,
    
    ARRAY(
      SELECT STRUCT(
        validation_id,
        passed,
        confidence,
        details
      )
      FROM quality_assessment
    ) AS validation_results,
    
    COALESCE(recommendations.recommendation_list, []) AS recommendations,
    
    (overall_score.critical_failures > 0 OR overall_score.quality_score < 0.6) AS requires_manual_review
  )
  FROM overall_score, recommendations
);

-- Automated data quality monitoring procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.monitor_data_quality`(
  batch_size INT64 DEFAULT 100
)
BEGIN
  DECLARE processed_count INT64 DEFAULT 0;
  DECLARE failed_count INT64 DEFAULT 0;
  DECLARE current_batch ARRAY<STRUCT<id STRING, content STRING, type STRING>>;
  
  -- Process recent data in batches
  FOR batch IN (
    SELECT ARRAY_AGG(
      STRUCT(knowledge_id AS id, content, CAST(content_type AS STRING) AS type)
      LIMIT batch_size
    ) AS batch_data
    FROM `enterprise_knowledge_ai.enterprise_knowledge_base`
    WHERE created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
      AND knowledge_id NOT IN (
        SELECT source_data_id 
        FROM `enterprise_knowledge_ai.data_quality_results`
        WHERE validation_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
      )
  ) DO
    
    SET current_batch = batch.batch_data;
    
    -- Validate each item in the batch
    FOR item_index IN (SELECT * FROM UNNEST(GENERATE_ARRAY(0, ARRAY_LENGTH(current_batch) - 1))) DO
      DECLARE current_item STRUCT<id STRING, content STRING, type STRING>;
      DECLARE validation_result STRUCT<
        overall_quality_score FLOAT64,
        validation_results ARRAY<STRUCT<
          validation_id STRING,
          passed BOOL,
          confidence FLOAT64,
          details STRING
        >>,
        recommendations ARRAY<STRING>,
        requires_manual_review BOOL
      >;
      
      SET current_item = current_batch[OFFSET(item_index)];
      SET validation_result = `enterprise_knowledge_ai.validate_data_quality`(
        current_item.content,
        current_item.type
      );
      
      -- Store validation results
      FOR validation_index IN (
        SELECT * FROM UNNEST(GENERATE_ARRAY(0, ARRAY_LENGTH(validation_result.validation_results) - 1))
      ) DO
        DECLARE current_validation STRUCT<
          validation_id STRING,
          passed BOOL,
          confidence FLOAT64,
          details STRING
        >;
        
        SET current_validation = validation_result.validation_results[OFFSET(validation_index)];
        
        INSERT INTO `enterprise_knowledge_ai.data_quality_results`
        VALUES (
          GENERATE_UUID(),
          current_item.id,
          current_validation.validation_id,
          current_validation.passed,
          current_validation.confidence,
          current_validation.details,
          FALSE,
          CURRENT_TIMESTAMP(),
          JSON_OBJECT(
            'overall_quality_score', validation_result.overall_quality_score,
            'requires_manual_review', validation_result.requires_manual_review,
            'recommendations', TO_JSON_STRING(validation_result.recommendations)
          )
        );
      END FOR;
      
      -- Track processing statistics
      IF validation_result.requires_manual_review THEN
        SET failed_count = failed_count + 1;
      ELSE
        SET processed_count = processed_count + 1;
      END IF;
      
    END FOR;
    
  END FOR;
  
  -- Log monitoring results
  INSERT INTO `enterprise_knowledge_ai.system_logs`
  VALUES (
    GENERATE_UUID(),
    'data_quality_monitor',
    CONCAT('Data quality monitoring completed. Processed: ', CAST(processed_count AS STRING),
           ', Failed: ', CAST(failed_count AS STRING)),
    CASE WHEN failed_count > processed_count * 0.1 THEN 'warning' ELSE 'info' END,
    CURRENT_TIMESTAMP(),
    JSON_OBJECT(
      'processed_count', processed_count,
      'failed_count', failed_count,
      'success_rate', processed_count / (processed_count + failed_count)
    )
  );
END;

-- Function to get data quality summary
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.get_data_quality_summary`(
  time_window_hours INT64 DEFAULT 24
)
RETURNS STRUCT<
  overall_quality_score FLOAT64,
  total_records_validated INT64,
  passed_validations INT64,
  failed_validations INT64,
  critical_issues INT64,
  quality_trend STRING,
  top_issues ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH recent_results AS (
    SELECT 
      r.*,
      c.severity
    FROM `enterprise_knowledge_ai.data_quality_results` r
    JOIN `enterprise_knowledge_ai.data_quality_config` c
      ON r.validation_id = c.validation_id
    WHERE r.validation_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL time_window_hours HOUR)
  ),
  
  quality_metrics AS (
    SELECT 
      AVG(confidence_score) AS avg_quality_score,
      COUNT(*) AS total_validations,
      COUNTIF(validation_passed) AS passed_count,
      COUNTIF(NOT validation_passed) AS failed_count,
      COUNTIF(NOT validation_passed AND severity IN ('critical', 'high')) AS critical_count
    FROM recent_results
  ),
  
  trend_analysis AS (
    SELECT 
      AVG(CASE WHEN validation_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR) 
               THEN confidence_score END) AS recent_score,
      AVG(CASE WHEN validation_timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 12 HOUR) 
               THEN confidence_score END) AS older_score
    FROM recent_results
  ),
  
  top_issues AS (
    SELECT ARRAY_AGG(validation_details ORDER BY issue_count DESC LIMIT 5) AS issue_list
    FROM (
      SELECT validation_details, COUNT(*) AS issue_count
      FROM recent_results
      WHERE NOT validation_passed
      GROUP BY validation_details
      ORDER BY issue_count DESC
      LIMIT 5
    )
  )
  
  SELECT STRUCT(
    COALESCE(quality_metrics.avg_quality_score, 0.0) AS overall_quality_score,
    quality_metrics.total_validations AS total_records_validated,
    quality_metrics.passed_count AS passed_validations,
    quality_metrics.failed_count AS failed_validations,
    quality_metrics.critical_count AS critical_issues,
    
    CASE 
      WHEN trend_analysis.recent_score > trend_analysis.older_score * 1.05 THEN 'improving'
      WHEN trend_analysis.recent_score < trend_analysis.older_score * 0.95 THEN 'declining'
      ELSE 'stable'
    END AS quality_trend,
    
    COALESCE(top_issues.issue_list, []) AS top_issues
  )
  FROM quality_metrics, trend_analysis, top_issues
);