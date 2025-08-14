-- Quality Control System for detecting discrepancies between modalities
-- Identifies inconsistencies between visual content and structured data

-- Create function to detect product specification discrepancies
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.detect_product_discrepancies`(
  product_id STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH product_comparison AS (
    SELECT 
      p.product_id,
      p.specifications,
      p.description,
      p.category,
      JSON_EXTRACT_SCALAR(r.analysis_result, '$.analysis') AS visual_analysis,
      JSON_EXTRACT_SCALAR(r.analysis_result, '$.has_quality_issues') AS has_visual_issues
    FROM product_catalog_objects p
    LEFT JOIN multimodal_analysis_results r 
      ON p.product_id = r.content_id 
      AND r.content_type = 'product_image'
    WHERE p.product_id = product_id
  )
  SELECT TO_JSON(STRUCT(
    product_id,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Compare product specifications with visual analysis. Are there discrepancies? ',
        'Specifications: ', specifications,
        ', Description: ', description,
        ', Visual analysis: ', visual_analysis
      )
    ) AS has_discrepancies,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'List specific discrepancies between product specifications and visual appearance: ',
        'Specs: ', specifications,
        ', Visual: ', visual_analysis
      )
    ) AS discrepancy_details,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      'Rate the severity of discrepancies from 0.0 (none) to 1.0 (critical)'
    ) AS severity_score,
    CASE 
      WHEN has_visual_issues = 'true' THEN 'QUALITY_ISSUE_DETECTED'
      ELSE 'QUALITY_OK'
    END AS quality_status,
    CURRENT_TIMESTAMP() AS checked_at
  ))
  FROM product_comparison
);

-- Create function to validate document content accuracy
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.validate_document_accuracy`(
  document_id STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH document_validation AS (
    SELECT 
      d.document_id,
      d.title,
      d.content_summary,
      d.document_type,
      JSON_EXTRACT_SCALAR(r.analysis_result, '$.extracted_content') AS extracted_content,
      JSON_EXTRACT_SCALAR(r.analysis_result, '$.document_classification') AS visual_classification
    FROM document_objects d
    LEFT JOIN multimodal_analysis_results r 
      ON d.document_id = r.content_id 
      AND r.content_type = 'document_image'
    WHERE d.document_id = document_id
  )
  SELECT TO_JSON(STRUCT(
    document_id,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Does the extracted content match the document metadata? ',
        'Title: ', title,
        ', Type: ', document_type,
        ', Summary: ', content_summary,
        ', Extracted: ', extracted_content,
        ', Visual classification: ', visual_classification
      )
    ) AS content_matches_metadata,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Identify any inconsistencies between document metadata and visual content: ',
        'Metadata type: ', document_type,
        ', Visual classification: ', visual_classification,
        ', Content summary: ', content_summary,
        ', Extracted content: ', extracted_content
      )
    ) AS inconsistency_analysis,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      'Rate document accuracy from 0.0 (completely inaccurate) to 1.0 (perfectly accurate)'
    ) AS accuracy_score,
    CURRENT_TIMESTAMP() AS validated_at
  ))
  FROM document_validation
);

-- Create function to verify support ticket resolution accuracy
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.verify_support_resolution`(
  ticket_id STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH resolution_verification AS (
    SELECT 
      t.ticket_id,
      t.issue_description,
      t.resolution_notes,
      t.status,
      JSON_EXTRACT_SCALAR(r.analysis_result, '$.problem_analysis') AS visual_problem_analysis,
      JSON_EXTRACT_SCALAR(r.analysis_result, '$.resolution_steps') AS suggested_resolution,
      JSON_EXTRACT_SCALAR(r.analysis_result, '$.severity_score') AS visual_severity
    FROM support_ticket_objects t
    LEFT JOIN multimodal_analysis_results r 
      ON t.ticket_id = r.content_id 
      AND r.content_type = 'support_image'
    WHERE t.ticket_id = ticket_id
  )
  SELECT TO_JSON(STRUCT(
    ticket_id,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Does the resolution match the visual problem analysis? ',
        'Issue: ', issue_description,
        ', Resolution: ', COALESCE(resolution_notes, 'No resolution provided'),
        ', Visual analysis: ', visual_problem_analysis,
        ', Suggested resolution: ', suggested_resolution
      )
    ) AS resolution_matches_problem,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Compare actual resolution with AI-suggested resolution: ',
        'Actual: ', COALESCE(resolution_notes, 'No resolution'),
        ', Suggested: ', suggested_resolution,
        ', Problem: ', visual_problem_analysis
      )
    ) AS resolution_comparison,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Is the ticket status appropriate given the visual severity? ',
        'Status: ', status,
        ', Visual severity: ', visual_severity
      )
    ) AS status_appropriate,
    CURRENT_TIMESTAMP() AS verified_at
  ))
  FROM resolution_verification
);

-- Create comprehensive quality control procedure
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.run_quality_control_audit`()
BEGIN
  -- Create quality control results table
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.quality_control_results` AS
  WITH product_quality_checks AS (
    SELECT 
      'product_discrepancy' AS check_type,
      p.product_id AS entity_id,
      `enterprise_knowledge_ai.detect_product_discrepancies`(p.product_id) AS quality_result,
      CURRENT_TIMESTAMP() AS checked_at
    FROM product_catalog_objects p
    WHERE p.image_ref IS NOT NULL
  ),
  
  document_quality_checks AS (
    SELECT 
      'document_accuracy' AS check_type,
      d.document_id AS entity_id,
      `enterprise_knowledge_ai.validate_document_accuracy`(d.document_id) AS quality_result,
      CURRENT_TIMESTAMP() AS checked_at
    FROM document_objects d
    WHERE d.image_ref IS NOT NULL
  ),
  
  support_quality_checks AS (
    SELECT 
      'support_resolution' AS check_type,
      t.ticket_id AS entity_id,
      `enterprise_knowledge_ai.verify_support_resolution`(t.ticket_id) AS quality_result,
      CURRENT_TIMESTAMP() AS checked_at
    FROM support_ticket_objects t
    WHERE t.image_ref IS NOT NULL
  )
  
  SELECT * FROM product_quality_checks
  UNION ALL
  SELECT * FROM document_quality_checks
  UNION ALL
  SELECT * FROM support_quality_checks;
  
  -- Generate quality control summary
  INSERT INTO generated_insights (
    insight_id,
    source_data_ids,
    insight_type,
    content,
    confidence_score,
    business_impact_score,
    target_audience,
    expiration_timestamp
  )
  WITH quality_summary AS (
    SELECT 
      check_type,
      COUNT(*) AS total_checks,
      COUNTIF(JSON_EXTRACT_SCALAR(quality_result, '$.has_discrepancies') = 'true' 
              OR JSON_EXTRACT_SCALAR(quality_result, '$.content_matches_metadata') = 'false'
              OR JSON_EXTRACT_SCALAR(quality_result, '$.resolution_matches_problem') = 'false') AS issues_found,
      AVG(CAST(JSON_EXTRACT_SCALAR(quality_result, '$.severity_score') AS FLOAT64)) AS avg_severity,
      AVG(CAST(JSON_EXTRACT_SCALAR(quality_result, '$.accuracy_score') AS FLOAT64)) AS avg_accuracy
    FROM quality_control_results
    GROUP BY check_type
  )
  SELECT 
    GENERATE_UUID() AS insight_id,
    ['quality_control_audit'] AS source_data_ids,
    'quality_control_summary' AS insight_type,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Generate quality control summary report: ',
        (SELECT STRING_AGG(
          CONCAT(
            'Check type: ', check_type,
            ', Total checks: ', CAST(total_checks AS STRING),
            ', Issues found: ', CAST(issues_found AS STRING),
            ', Average severity: ', CAST(avg_severity AS STRING),
            ', Average accuracy: ', CAST(COALESCE(avg_accuracy, 0.0) AS STRING)
          ), '; '
        ) FROM quality_summary)
      )
    ) AS content,
    0.95 AS confidence_score,
    CASE 
      WHEN (SELECT MAX(issues_found) FROM quality_summary) > 0 THEN 0.8
      ELSE 0.3
    END AS business_impact_score,
    ['quality_managers', 'operations_team'] AS target_audience,
    TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 DAY) AS expiration_timestamp;
  
  -- Create alerts for critical quality issues
  INSERT INTO generated_insights (
    insight_id,
    source_data_ids,
    insight_type,
    content,
    confidence_score,
    business_impact_score,
    target_audience,
    expiration_timestamp
  )
  SELECT 
    GENERATE_UUID() AS insight_id,
    [entity_id] AS source_data_ids,
    'quality_alert' AS insight_type,
    CONCAT(
      'CRITICAL QUALITY ISSUE: ',
      JSON_EXTRACT_SCALAR(quality_result, '$.discrepancy_details'),
      ' Entity: ', entity_id,
      ' Severity: ', JSON_EXTRACT_SCALAR(quality_result, '$.severity_score')
    ) AS content,
    0.9 AS confidence_score,
    1.0 AS business_impact_score,
    ['quality_managers', 'executives'] AS target_audience,
    TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR) AS expiration_timestamp
  FROM quality_control_results
  WHERE CAST(JSON_EXTRACT_SCALAR(quality_result, '$.severity_score') AS FLOAT64) > 0.7
     OR JSON_EXTRACT_SCALAR(quality_result, '$.has_discrepancies') = 'true';
END;