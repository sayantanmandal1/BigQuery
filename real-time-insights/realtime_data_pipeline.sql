-- Real-time Data Ingestion and Processing Pipeline
-- Implements continuous data flow and processing infrastructure

-- Create data ingestion staging table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.data_ingestion_staging` (
  staging_id STRING NOT NULL,
  source_system STRING NOT NULL,
  data_type ENUM('structured', 'unstructured', 'multimodal', 'stream'),
  raw_payload JSON,
  ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  processing_priority INT64 DEFAULT 5,
  validation_status ENUM('pending', 'valid', 'invalid', 'needs_review') DEFAULT 'pending',
  error_details TEXT,
  metadata JSON
) PARTITION BY DATE(ingestion_timestamp)
CLUSTER BY source_system, data_type, processing_priority;

-- Create data processing queue table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.processing_queue` (
  queue_id STRING NOT NULL,
  staging_id STRING NOT NULL,
  processing_stage ENUM('validation', 'enrichment', 'embedding', 'analysis', 'distribution'),
  stage_status ENUM('pending', 'processing', 'completed', 'failed', 'retrying'),
  assigned_worker STRING,
  started_timestamp TIMESTAMP,
  completed_timestamp TIMESTAMP,
  retry_count INT64 DEFAULT 0,
  max_retries INT64 DEFAULT 3,
  stage_metadata JSON
) PARTITION BY DATE(_PARTITIONTIME)
CLUSTER BY processing_stage, stage_status;

-- Function to validate incoming data using AI
CREATE OR REPLACE FUNCTION validate_ingested_data(
  raw_data JSON,
  expected_schema JSON,
  data_source STRING
)
RETURNS STRUCT<
  is_valid BOOL,
  validation_score FLOAT64,
  issues ARRAY<STRING>,
  suggested_fixes ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH validation_analysis AS (
    SELECT 
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Validate this data against expected schema. Data: ',
          TO_JSON_STRING(raw_data),
          '. Expected schema: ', TO_JSON_STRING(expected_schema),
          '. Source: ', data_source,
          '. Determine if data is valid and complete.'
        )
      ) as is_valid_bool,
      
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate data quality from 0.0 to 1.0 for: ',
          TO_JSON_STRING(raw_data),
          '. Consider completeness, accuracy, and format compliance.'
        )
      ) as quality_score,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Identify specific data quality issues in: ',
          TO_JSON_STRING(raw_data),
          '. List each issue clearly and concisely.'
        )
      ) as issues_text,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Suggest specific fixes for data quality issues in: ',
          TO_JSON_STRING(raw_data),
          '. Provide actionable remediation steps.'
        )
      ) as fixes_text
  )
  
  SELECT STRUCT(
    va.is_valid_bool as is_valid,
    va.quality_score as validation_score,
    SPLIT(va.issues_text, '\n') as issues,
    SPLIT(va.fixes_text, '\n') as suggested_fixes
  )
  FROM validation_analysis va
);

-- Function to enrich data with contextual information
CREATE OR REPLACE FUNCTION enrich_data_context(
  base_data JSON,
  enrichment_sources ARRAY<STRING>
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH enrichment_analysis AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Enrich this data with relevant context: ',
          TO_JSON_STRING(base_data),
          '. Available enrichment sources: ', ARRAY_TO_STRING(enrichment_sources, ', '),
          '. Add business context, relationships, and derived insights.'
        )
      ) as enriched_content,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Extract key entities and relationships from: ',
          TO_JSON_STRING(base_data),
          '. Identify people, organizations, concepts, and their connections.'
        )
      ) as entity_extraction,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Categorize and tag this data: ',
          TO_JSON_STRING(base_data),
          '. Assign relevant business categories, topics, and metadata tags.'
        )
      ) as categorization
  )
  
  SELECT TO_JSON(STRUCT(
    base_data as original_data,
    ea.enriched_content as enrichment,
    ea.entity_extraction as entities,
    ea.categorization as categories,
    enrichment_sources as sources_used,
    CURRENT_TIMESTAMP() as enrichment_timestamp
  ))
  FROM enrichment_analysis ea
);

-- Stored procedure for continuous data pipeline processing
CREATE OR REPLACE PROCEDURE process_data_pipeline()
BEGIN
  DECLARE done BOOL DEFAULT FALSE;
  DECLARE current_staging_id STRING;
  DECLARE current_data JSON;
  DECLARE current_source STRING;
  DECLARE validation_result STRUCT<
    is_valid BOOL,
    validation_score FLOAT64,
    issues ARRAY<STRING>,
    suggested_fixes ARRAY<STRING>
  >;
  DECLARE enriched_data JSON;
  
  -- Cursor for pending data in staging
  DECLARE staging_cursor CURSOR FOR
    SELECT staging_id, raw_payload, source_system
    FROM `enterprise_knowledge_ai.data_ingestion_staging`
    WHERE validation_status = 'pending'
      AND ingestion_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    ORDER BY processing_priority DESC, ingestion_timestamp ASC
    LIMIT 100;
  
  DECLARE CONTINUE HANDLER FOR NOT_FOUND SET done = TRUE;
  
  OPEN staging_cursor;
  
  pipeline_loop: LOOP
    FETCH staging_cursor INTO current_staging_id, current_data, current_source;
    
    IF done THEN
      LEAVE pipeline_loop;
    END IF;
    
    -- Add to processing queue
    INSERT INTO `enterprise_knowledge_ai.processing_queue` (
      queue_id,
      staging_id,
      processing_stage,
      stage_status,
      stage_metadata
    )
    VALUES (
      GENERATE_UUID(),
      current_staging_id,
      'validation',
      'processing',
      JSON_OBJECT('started_timestamp', CURRENT_TIMESTAMP())
    );
    
    -- Validate the data
    SET validation_result = validate_ingested_data(
      current_data,
      JSON_OBJECT('required_fields', ['content', 'timestamp', 'source']),
      current_source
    );
    
    IF validation_result.is_valid AND validation_result.validation_score > 0.7 THEN
      -- Update staging status to valid
      UPDATE `enterprise_knowledge_ai.data_ingestion_staging`
      SET 
        validation_status = 'valid',
        metadata = JSON_SET(
          COALESCE(metadata, JSON_OBJECT()),
          '$.validation_score', validation_result.validation_score,
          '$.validation_timestamp', CURRENT_TIMESTAMP()
        )
      WHERE staging_id = current_staging_id;
      
      -- Enrich the data
      SET enriched_data = enrich_data_context(
        current_data,
        ['enterprise_knowledge_base', 'user_interactions', 'business_metrics']
      );
      
      -- Generate embeddings and process for insights
      INSERT INTO `enterprise_knowledge_ai.realtime_data_stream` (
        stream_id,
        data_source,
        content_type,
        raw_content,
        structured_data,
        metadata
      )
      VALUES (
        GENERATE_UUID(),
        current_source,
        'document_update',
        JSON_EXTRACT_SCALAR(enriched_data, '$.enrichment'),
        enriched_data,
        JSON_OBJECT(
          'original_staging_id', current_staging_id,
          'validation_score', validation_result.validation_score,
          'processing_timestamp', CURRENT_TIMESTAMP()
        )
      );
      
      -- Update processing queue
      UPDATE `enterprise_knowledge_ai.processing_queue`
      SET 
        stage_status = 'completed',
        completed_timestamp = CURRENT_TIMESTAMP()
      WHERE staging_id = current_staging_id AND processing_stage = 'validation';
      
    ELSE
      -- Mark as invalid with details
      UPDATE `enterprise_knowledge_ai.data_ingestion_staging`
      SET 
        validation_status = 'invalid',
        error_details = ARRAY_TO_STRING(validation_result.issues, '; '),
        metadata = JSON_SET(
          COALESCE(metadata, JSON_OBJECT()),
          '$.validation_score', validation_result.validation_score,
          '$.suggested_fixes', TO_JSON_STRING(validation_result.suggested_fixes),
          '$.validation_timestamp', CURRENT_TIMESTAMP()
        )
      WHERE staging_id = current_staging_id;
      
      -- Update processing queue as failed
      UPDATE `enterprise_knowledge_ai.processing_queue`
      SET 
        stage_status = 'failed',
        completed_timestamp = CURRENT_TIMESTAMP(),
        stage_metadata = JSON_SET(
          COALESCE(stage_metadata, JSON_OBJECT()),
          '$.failure_reason', 'validation_failed',
          '$.validation_issues', TO_JSON_STRING(validation_result.issues)
        )
      WHERE staging_id = current_staging_id AND processing_stage = 'validation';
      
    END IF;
    
  END LOOP;
  
  CLOSE staging_cursor;
  
  -- Clean up old staging data
  DELETE FROM `enterprise_knowledge_ai.data_ingestion_staging`
  WHERE ingestion_timestamp < TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
    AND validation_status IN ('valid', 'invalid');
  
  -- Log pipeline processing summary
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id,
    component,
    message,
    timestamp
  )
  VALUES (
    GENERATE_UUID(),
    'data_pipeline',
    CONCAT('Processed ', 
           (SELECT COUNT(*) FROM `enterprise_knowledge_ai.data_ingestion_staging` 
            WHERE validation_status != 'pending' 
              AND ingestion_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)),
           ' data items in the last hour'),
    CURRENT_TIMESTAMP()
  );
  
END;

-- Function to ingest new data into the pipeline
CREATE OR REPLACE FUNCTION ingest_realtime_data(
  source_system STRING,
  data_payload JSON,
  priority_level INT64 DEFAULT 5
)
RETURNS STRING
LANGUAGE SQL
AS (
  (
    INSERT INTO `enterprise_knowledge_ai.data_ingestion_staging` (
      staging_id,
      source_system,
      data_type,
      raw_payload,
      processing_priority,
      metadata
    )
    VALUES (
      GENERATE_UUID(),
      source_system,
      CASE 
        WHEN JSON_EXTRACT_SCALAR(data_payload, '$.type') = 'image' THEN 'multimodal'
        WHEN JSON_EXTRACT_SCALAR(data_payload, '$.type') = 'stream' THEN 'stream'
        WHEN JSON_EXTRACT_SCALAR(data_payload, '$.structured') = 'true' THEN 'structured'
        ELSE 'unstructured'
      END,
      data_payload,
      priority_level,
      JSON_OBJECT(
        'ingestion_method', 'api_call',
        'ingestion_timestamp', CURRENT_TIMESTAMP()
      )
    );
    
    SELECT staging_id FROM `enterprise_knowledge_ai.data_ingestion_staging`
    WHERE source_system = source_system 
      AND raw_payload = data_payload
    ORDER BY ingestion_timestamp DESC
    LIMIT 1
  )
);

-- Function to monitor pipeline health
CREATE OR REPLACE FUNCTION get_pipeline_health_metrics()
RETURNS STRUCT<
  total_pending INT64,
  processing_rate_per_hour FLOAT64,
  error_rate FLOAT64,
  average_processing_time_seconds FLOAT64,
  queue_backlog INT64
>
LANGUAGE SQL
AS (
  WITH pipeline_metrics AS (
    SELECT 
      COUNT(*) as total_pending_count,
      
      (SELECT COUNT(*) 
       FROM `enterprise_knowledge_ai.data_ingestion_staging` 
       WHERE validation_status = 'valid' 
         AND ingestion_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
      ) as processed_last_hour,
      
      (SELECT COUNT(*) 
       FROM `enterprise_knowledge_ai.data_ingestion_staging` 
       WHERE validation_status = 'invalid' 
         AND ingestion_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
      ) as errors_last_hour,
      
      (SELECT AVG(TIMESTAMP_DIFF(completed_timestamp, started_timestamp, SECOND))
       FROM `enterprise_knowledge_ai.processing_queue`
       WHERE stage_status = 'completed'
         AND completed_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
      ) as avg_processing_seconds,
      
      (SELECT COUNT(*)
       FROM `enterprise_knowledge_ai.processing_queue`
       WHERE stage_status IN ('pending', 'processing')
      ) as queue_backlog_count
      
    FROM `enterprise_knowledge_ai.data_ingestion_staging`
    WHERE validation_status = 'pending'
  )
  
  SELECT STRUCT(
    pm.total_pending_count as total_pending,
    CAST(pm.processed_last_hour AS FLOAT64) as processing_rate_per_hour,
    CASE 
      WHEN (pm.processed_last_hour + pm.errors_last_hour) > 0 
      THEN CAST(pm.errors_last_hour AS FLOAT64) / (pm.processed_last_hour + pm.errors_last_hour)
      ELSE 0.0 
    END as error_rate,
    COALESCE(pm.avg_processing_seconds, 0.0) as average_processing_time_seconds,
    pm.queue_backlog_count as queue_backlog
  )
  FROM pipeline_metrics pm
);