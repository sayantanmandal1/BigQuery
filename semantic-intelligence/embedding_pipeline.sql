-- Document Embedding Generation Pipeline
-- This script implements the ML.GENERATE_EMBEDDING pipeline for semantic document processing

-- Create embedding model for text content
CREATE OR REPLACE MODEL `enterprise_knowledge_ai.text_embedding_model`
OPTIONS (
  model_type = 'EMBEDDING',
  embedding_type = 'TEXT_EMBEDDING_GECKO_003',
  max_batch_size = 100
);

-- Function to generate embeddings for new documents
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.generate_document_embedding`(
  input_text STRING
)
RETURNS ARRAY<FLOAT64>
LANGUAGE SQL
AS (
  (
    SELECT embedding
    FROM ML.GENERATE_EMBEDDING(
      MODEL `enterprise_knowledge_ai.text_embedding_model`,
      (SELECT input_text AS content)
    )
  )
);

-- Procedure to batch process embeddings for existing documents
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.batch_generate_embeddings`()
BEGIN
  -- Update documents that don't have embeddings yet
  UPDATE `enterprise_knowledge_ai.enterprise_knowledge_base`
  SET 
    embedding = (
      SELECT embedding
      FROM ML.GENERATE_EMBEDDING(
        MODEL `enterprise_knowledge_ai.text_embedding_model`,
        (SELECT content)
      )
    ),
    last_updated = CURRENT_TIMESTAMP()
  WHERE embedding IS NULL 
    AND content IS NOT NULL 
    AND LENGTH(content) > 0;
    
  -- Log the batch processing results
  INSERT INTO `enterprise_knowledge_ai.processing_logs` (
    process_type,
    records_processed,
    processing_timestamp,
    status
  )
  SELECT 
    'embedding_generation' as process_type,
    @@row_count as records_processed,
    CURRENT_TIMESTAMP() as processing_timestamp,
    'completed' as status;
END;

-- Function to preprocess text before embedding generation
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.preprocess_text_for_embedding`(
  raw_text STRING
)
RETURNS STRING
LANGUAGE SQL
AS (
  -- Clean and normalize text for better embedding quality
  REGEXP_REPLACE(
    REGEXP_REPLACE(
      REGEXP_REPLACE(
        TRIM(LOWER(raw_text)),
        r'[^\w\s\.\,\!\?\-]', ' '  -- Remove special characters except basic punctuation
      ),
      r'\s+', ' '  -- Normalize whitespace
    ),
    r'(.{1000}).*', r'\1'  -- Truncate to 1000 characters for optimal embedding
  )
);

-- Enhanced embedding generation with preprocessing
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.generate_enhanced_embedding`(
  input_text STRING,
  content_type STRING DEFAULT 'document'
)
RETURNS STRUCT<
  embedding ARRAY<FLOAT64>,
  processed_text STRING,
  embedding_quality_score FLOAT64
>
LANGUAGE SQL
AS (
  WITH processed_content AS (
    SELECT 
      `enterprise_knowledge_ai.preprocess_text_for_embedding`(input_text) as clean_text
  ),
  embedding_result AS (
    SELECT 
      pc.clean_text,
      emb.embedding,
      -- Calculate quality score based on text length and content richness
      CASE 
        WHEN LENGTH(pc.clean_text) < 50 THEN 0.3
        WHEN LENGTH(pc.clean_text) < 200 THEN 0.7
        WHEN ARRAY_LENGTH(SPLIT(pc.clean_text, ' ')) < 10 THEN 0.5
        ELSE 0.9
      END as quality_score
    FROM processed_content pc
    CROSS JOIN ML.GENERATE_EMBEDDING(
      MODEL `enterprise_knowledge_ai.text_embedding_model`,
      (SELECT pc.clean_text AS content)
    ) emb
  )
  SELECT AS STRUCT
    embedding,
    clean_text as processed_text,
    quality_score as embedding_quality_score
  FROM embedding_result
);