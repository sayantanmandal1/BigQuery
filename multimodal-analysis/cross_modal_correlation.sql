-- Cross-Modal Correlation Engine
-- Combines insights from images and structured data to identify relationships

-- Create function to correlate product images with sales performance
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.correlate_product_performance`(
  product_id STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH product_data AS (
    SELECT 
      p.product_id,
      p.specifications,
      p.price,
      p.category,
      s.total_sales,
      s.avg_rating,
      s.return_rate,
      r.analysis_result AS image_analysis
    FROM product_catalog_objects p
    LEFT JOIN product_sales_metrics s ON p.product_id = s.product_id
    LEFT JOIN multimodal_analysis_results r 
      ON p.product_id = r.content_id 
      AND r.content_type = 'product_image'
    WHERE p.product_id = product_id
  )
  SELECT TO_JSON(STRUCT(
    product_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Analyze the correlation between product visual features and performance metrics. ',
        'Product specs: ', specifications,
        ', Sales: ', CAST(total_sales AS STRING),
        ', Rating: ', CAST(avg_rating AS STRING),
        ', Return rate: ', CAST(return_rate AS STRING),
        ', Image analysis: ', JSON_EXTRACT_SCALAR(image_analysis, '$.analysis'),
        '. Identify which visual features drive sales and customer satisfaction.'
      )
    ) AS performance_correlation,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Rate the visual appeal impact on sales performance from 0.0 to 1.0 based on: ',
        JSON_EXTRACT_SCALAR(image_analysis, '$.analysis')
      )
    ) AS visual_impact_score,
    CURRENT_TIMESTAMP() AS analyzed_at
  ))
  FROM product_data
);

-- Create function to correlate customer feedback with support images
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.correlate_customer_feedback`(
  ticket_id STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH feedback_data AS (
    SELECT 
      t.ticket_id,
      t.issue_description,
      t.customer_sentiment,
      t.resolution_time,
      f.feedback_text,
      f.satisfaction_score,
      r.analysis_result AS image_analysis
    FROM support_ticket_objects t
    LEFT JOIN customer_feedback f ON t.ticket_id = f.ticket_id
    LEFT JOIN multimodal_analysis_results r 
      ON t.ticket_id = r.content_id 
      AND r.content_type = 'support_image'
    WHERE t.ticket_id = ticket_id
  )
  SELECT TO_JSON(STRUCT(
    ticket_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Correlate customer feedback with visual evidence from support images. ',
        'Issue: ', issue_description,
        ', Customer sentiment: ', customer_sentiment,
        ', Feedback: ', COALESCE(feedback_text, 'No feedback provided'),
        ', Image analysis: ', JSON_EXTRACT_SCALAR(image_analysis, '$.problem_analysis'),
        '. Determine if visual evidence supports customer claims.'
      )
    ) AS feedback_correlation,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Does the visual evidence support the customer complaint? ',
        'Complaint: ', issue_description,
        ', Visual analysis: ', JSON_EXTRACT_SCALAR(image_analysis, '$.problem_analysis')
      )
    ) AS evidence_supports_claim,
    CURRENT_TIMESTAMP() AS analyzed_at
  ))
  FROM feedback_data
);

-- Create function to find cross-modal patterns across all content
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.identify_cross_modal_patterns`()
RETURNS ARRAY<JSON>
LANGUAGE SQL
AS (
  WITH pattern_analysis AS (
    SELECT 
      'product_quality_patterns' AS pattern_type,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Analyze patterns between product visual quality and business metrics: ',
          (SELECT STRING_AGG(
            CONCAT(
              'Product: ', content_id,
              ', Visual quality: ', JSON_EXTRACT_SCALAR(analysis_result, '$.has_quality_issues'),
              ', Sales performance: ', COALESCE(CAST(s.total_sales AS STRING), 'N/A')
            ), '; '
          )
          FROM multimodal_analysis_results r
          LEFT JOIN product_sales_metrics s ON r.content_id = s.product_id
          WHERE r.content_type = 'product_image'
          LIMIT 50)
        )
      ) AS pattern_insights
    
    UNION ALL
    
    SELECT 
      'support_resolution_patterns' AS pattern_type,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Identify patterns in support ticket resolution based on visual evidence: ',
          (SELECT STRING_AGG(
            CONCAT(
              'Ticket: ', content_id,
              ', Severity: ', JSON_EXTRACT_SCALAR(analysis_result, '$.severity_score'),
              ', Resolution provided: ', JSON_EXTRACT_SCALAR(analysis_result, '$.resolution_steps')
            ), '; '
          )
          FROM multimodal_analysis_results
          WHERE content_type = 'support_image'
          LIMIT 50)
        )
      ) AS pattern_insights
    
    UNION ALL
    
    SELECT 
      'document_content_patterns' AS pattern_type,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Analyze document content patterns and classification accuracy: ',
          (SELECT STRING_AGG(
            CONCAT(
              'Document: ', content_id,
              ', Type: ', JSON_EXTRACT_SCALAR(analysis_result, '$.document_classification'),
              ', Content quality: ', JSON_EXTRACT_SCALAR(analysis_result, '$.extracted_content')
            ), '; '
          )
          FROM multimodal_analysis_results
          WHERE content_type = 'document_image'
          LIMIT 50)
        )
      ) AS pattern_insights
  )
  SELECT ARRAY_AGG(
    JSON_OBJECT(
      'pattern_type', pattern_type,
      'insights', pattern_insights,
      'analyzed_at', CURRENT_TIMESTAMP()
    )
  )
  FROM pattern_analysis
);

-- Create procedure to generate comprehensive cross-modal insights
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.generate_cross_modal_insights`()
BEGIN
  -- Create comprehensive correlation analysis
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.cross_modal_insights` AS
  WITH correlation_data AS (
    -- Product performance correlations
    SELECT 
      'product_performance' AS insight_type,
      p.product_id AS entity_id,
      `enterprise_knowledge_ai.correlate_product_performance`(p.product_id) AS correlation_analysis,
      CURRENT_TIMESTAMP() AS created_at
    FROM product_catalog_objects p
    WHERE p.image_ref IS NOT NULL
    
    UNION ALL
    
    -- Customer feedback correlations
    SELECT 
      'customer_feedback' AS insight_type,
      t.ticket_id AS entity_id,
      `enterprise_knowledge_ai.correlate_customer_feedback`(t.ticket_id) AS correlation_analysis,
      CURRENT_TIMESTAMP() AS created_at
    FROM support_ticket_objects t
    WHERE t.image_ref IS NOT NULL
  ),
  
  pattern_insights AS (
    SELECT 
      'cross_modal_patterns' AS insight_type,
      'global' AS entity_id,
      TO_JSON(STRUCT(
        patterns,
        CURRENT_TIMESTAMP() AS analyzed_at
      )) AS correlation_analysis,
      CURRENT_TIMESTAMP() AS created_at
    FROM (
      SELECT `enterprise_knowledge_ai.identify_cross_modal_patterns`() AS patterns
    )
  )
  
  SELECT * FROM correlation_data
  UNION ALL
  SELECT * FROM pattern_insights;
  
  -- Generate summary insights
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
    'cross_modal_correlation' AS insight_type,
    JSON_EXTRACT_SCALAR(correlation_analysis, '$.performance_correlation') AS content,
    0.85 AS confidence_score,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Rate business impact from 0.0 to 1.0: ',
        JSON_EXTRACT_SCALAR(correlation_analysis, '$.performance_correlation')
      )
    ) AS business_impact_score,
    ['product_managers', 'executives'] AS target_audience,
    TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) AS expiration_timestamp
  FROM cross_modal_insights
  WHERE insight_type = 'product_performance';
END;