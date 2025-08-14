-- Visual Content Analyzer using ObjectRef for image processing
-- This component analyzes visual content and extracts structured insights

-- Create function to analyze product images against specifications
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.analyze_product_image`(
  product_id STRING,
  image_ref STRING,
  specifications STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  SELECT TO_JSON(STRUCT(
    product_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      CONCAT(
        'Analyze this product image against the following specifications. ',
        'Identify any discrepancies, quality issues, or notable features: ',
        specifications
      ),
      STRUCT(image_ref AS uri)
    ) AS analysis,
    AI.GENERATE_BOOL(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Based on this product analysis, are there any quality concerns? ',
        'Specifications: ', specifications
      )
    ) AS has_quality_issues,
    CURRENT_TIMESTAMP() AS analyzed_at
  ))
);

-- Create function to extract features from document images
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.extract_document_features`(
  document_id STRING,
  image_ref STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  SELECT TO_JSON(STRUCT(
    document_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      'Extract all text, tables, charts, and key information from this document image. Format as structured JSON.',
      STRUCT(image_ref AS uri)
    ) AS extracted_content,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      'Classify the document type and identify the main topics discussed.',
      STRUCT(image_ref AS uri)
    ) AS document_classification,
    CURRENT_TIMESTAMP() AS processed_at
  ))
);

-- Create function to analyze customer support images
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.analyze_support_image`(
  ticket_id STRING,
  image_ref STRING,
  issue_description STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  SELECT TO_JSON(STRUCT(
    ticket_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      CONCAT(
        'Analyze this customer support image. Issue description: ',
        issue_description,
        '. Identify the problem, suggest solutions, and determine severity level.'
      ),
      STRUCT(image_ref AS uri)
    ) AS problem_analysis,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Based on this support image analysis, provide step-by-step resolution instructions: ',
        issue_description
      )
    ) AS resolution_steps,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      'Rate the severity of this issue on a scale of 0.0 to 1.0, where 1.0 is critical.'
    ) AS severity_score,
    CURRENT_TIMESTAMP() AS analyzed_at
  ))
);

-- Create procedure to batch process visual content
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.batch_analyze_visual_content`()
BEGIN
  -- Process unanalyzed product images
  INSERT INTO multimodal_analysis_results (
    content_id,
    content_type,
    analysis_result,
    created_timestamp
  )
  SELECT 
    p.product_id,
    'product_image',
    `enterprise_knowledge_ai.analyze_product_image`(
      p.product_id,
      p.image_ref,
      p.specifications
    ),
    CURRENT_TIMESTAMP()
  FROM product_catalog_objects p
  LEFT JOIN multimodal_analysis_results r 
    ON p.product_id = r.content_id 
    AND r.content_type = 'product_image'
  WHERE r.content_id IS NULL
    AND p.image_ref IS NOT NULL;

  -- Process unanalyzed document images
  INSERT INTO multimodal_analysis_results (
    content_id,
    content_type,
    analysis_result,
    created_timestamp
  )
  SELECT 
    d.document_id,
    'document_image',
    `enterprise_knowledge_ai.extract_document_features`(
      d.document_id,
      d.image_ref
    ),
    CURRENT_TIMESTAMP()
  FROM document_objects d
  LEFT JOIN multimodal_analysis_results r 
    ON d.document_id = r.content_id 
    AND r.content_type = 'document_image'
  WHERE r.content_id IS NULL
    AND d.image_ref IS NOT NULL;

  -- Process unanalyzed support images
  INSERT INTO multimodal_analysis_results (
    content_id,
    content_type,
    analysis_result,
    created_timestamp
  )
  SELECT 
    s.ticket_id,
    'support_image',
    `enterprise_knowledge_ai.analyze_support_image`(
      s.ticket_id,
      s.image_ref,
      s.issue_description
    ),
    CURRENT_TIMESTAMP()
  FROM support_ticket_objects s
  LEFT JOIN multimodal_analysis_results r 
    ON s.ticket_id = r.content_id 
    AND r.content_type = 'support_image'
  WHERE r.content_id IS NULL
    AND s.image_ref IS NOT NULL;
END;