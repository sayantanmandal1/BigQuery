-- Real-time Stream Processing Engine
-- Implements continuous data monitoring and processing for enterprise insights

-- Create streaming data ingestion table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.realtime_data_stream` (
  stream_id STRING NOT NULL,
  data_source STRING NOT NULL,
  content_type ENUM('meeting_transcript', 'document_update', 'metric_change', 'user_interaction'),
  raw_content TEXT,
  structured_data JSON,
  ingestion_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  processing_status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending',
  metadata JSON
) PARTITION BY DATE(ingestion_timestamp)
CLUSTER BY data_source, content_type;

-- Create processed insights table for real-time results
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.realtime_insights` (
  insight_id STRING NOT NULL,
  source_stream_id STRING NOT NULL,
  insight_type ENUM('contextual', 'predictive', 'recommendation', 'alert'),
  content TEXT,
  confidence_score FLOAT64,
  urgency_level ENUM('low', 'medium', 'high', 'critical'),
  target_users ARRAY<STRING>,
  expiration_timestamp TIMESTAMP,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
) PARTITION BY DATE(created_timestamp)
CLUSTER BY insight_type, urgency_level;

-- Stream processing function for continuous monitoring
CREATE OR REPLACE FUNCTION process_realtime_stream(
  stream_data JSON,
  context_window_hours INT64 DEFAULT 24
)
RETURNS STRUCT<
  insights ARRAY<STRUCT<
    type STRING,
    content STRING,
    confidence FLOAT64,
    urgency STRING
  >>,
  processing_time_ms INT64
>
LANGUAGE SQL
AS (
  WITH processing_start AS (
    SELECT CURRENT_TIMESTAMP() as start_time
  ),
  
  -- Extract relevant context from recent data
  recent_context AS (
    SELECT 
      content_type,
      raw_content,
      structured_data,
      COUNT(*) as frequency
    FROM `enterprise_knowledge_ai.realtime_data_stream`
    WHERE ingestion_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL context_window_hours HOUR)
      AND processing_status = 'completed'
    GROUP BY content_type, raw_content, structured_data
  ),
  
  -- Generate contextual insights using AI
  contextual_analysis AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Analyze this real-time data in context of recent activity: ',
          JSON_EXTRACT_SCALAR(stream_data, '$.raw_content'),
          '. Recent context: ',
          (SELECT STRING_AGG(raw_content, '; ') FROM recent_context LIMIT 5),
          '. Provide actionable insights and identify any urgent patterns.'
        )
      ) as contextual_insight,
      
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate the business significance of this insight from 0.0 to 1.0: ',
          JSON_EXTRACT_SCALAR(stream_data, '$.raw_content')
        )
      ) as significance_score
  ),
  
  -- Generate recommendations based on historical patterns
  recommendation_analysis AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Based on this real-time data and historical patterns, provide specific actionable recommendations: ',
          JSON_EXTRACT_SCALAR(stream_data, '$.raw_content'),
          '. Consider similar past scenarios and their outcomes.'
        )
      ) as recommendations
  ),
  
  processing_end AS (
    SELECT CURRENT_TIMESTAMP() as end_time
  )
  
  SELECT STRUCT(
    ARRAY[
      STRUCT(
        'contextual' as type,
        ca.contextual_insight as content,
        ca.significance_score as confidence,
        CASE 
          WHEN ca.significance_score > 0.8 THEN 'critical'
          WHEN ca.significance_score > 0.6 THEN 'high'
          WHEN ca.significance_score > 0.4 THEN 'medium'
          ELSE 'low'
        END as urgency
      ),
      STRUCT(
        'recommendation' as type,
        ra.recommendations as content,
        ca.significance_score * 0.9 as confidence,
        CASE 
          WHEN ca.significance_score > 0.7 THEN 'high'
          WHEN ca.significance_score > 0.5 THEN 'medium'
          ELSE 'low'
        END as urgency
      )
    ] as insights,
    
    CAST(TIMESTAMP_DIFF(pe.end_time, ps.start_time, MILLISECOND) AS INT64) as processing_time_ms
  )
  FROM processing_start ps, contextual_analysis ca, recommendation_analysis ra, processing_end pe
);

-- Stored procedure for continuous stream processing
CREATE OR REPLACE PROCEDURE process_pending_streams()
BEGIN
  DECLARE done BOOL DEFAULT FALSE;
  DECLARE current_stream_id STRING;
  DECLARE current_data JSON;
  DECLARE processing_result STRUCT<
    insights ARRAY<STRUCT<
      type STRING,
      content STRING,
      confidence FLOAT64,
      urgency STRING
    >>,
    processing_time_ms INT64
  >;
  
  -- Cursor for pending streams
  DECLARE stream_cursor CURSOR FOR
    SELECT stream_id, TO_JSON(STRUCT(raw_content, structured_data, metadata))
    FROM `enterprise_knowledge_ai.realtime_data_stream`
    WHERE processing_status = 'pending'
      AND ingestion_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    ORDER BY ingestion_timestamp ASC
    LIMIT 100;
  
  DECLARE CONTINUE HANDLER FOR NOT_FOUND SET done = TRUE;
  
  OPEN stream_cursor;
  
  stream_loop: LOOP
    FETCH stream_cursor INTO current_stream_id, current_data;
    
    IF done THEN
      LEAVE stream_loop;
    END IF;
    
    -- Update status to processing
    UPDATE `enterprise_knowledge_ai.realtime_data_stream`
    SET processing_status = 'processing'
    WHERE stream_id = current_stream_id;
    
    -- Process the stream data
    SET processing_result = process_realtime_stream(current_data);
    
    -- Insert generated insights
    INSERT INTO `enterprise_knowledge_ai.realtime_insights` (
      insight_id,
      source_stream_id,
      insight_type,
      content,
      confidence_score,
      urgency_level,
      target_users,
      expiration_timestamp,
      metadata
    )
    SELECT 
      GENERATE_UUID() as insight_id,
      current_stream_id as source_stream_id,
      insight.type as insight_type,
      insight.content,
      insight.confidence as confidence_score,
      insight.urgency as urgency_level,
      ['all_users'] as target_users, -- TODO: Implement user targeting logic
      TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR) as expiration_timestamp,
      TO_JSON(STRUCT(processing_result.processing_time_ms as processing_time_ms)) as metadata
    FROM UNNEST(processing_result.insights) as insight;
    
    -- Update stream status to completed
    UPDATE `enterprise_knowledge_ai.realtime_data_stream`
    SET processing_status = 'completed'
    WHERE stream_id = current_stream_id;
    
  END LOOP;
  
  CLOSE stream_cursor;
  
  -- Log processing summary
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id,
    component,
    message,
    timestamp
  )
  VALUES (
    GENERATE_UUID(),
    'stream_processor',
    CONCAT('Processed ', 
           (SELECT COUNT(*) FROM `enterprise_knowledge_ai.realtime_data_stream` 
            WHERE processing_status = 'completed' 
              AND ingestion_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)),
           ' streams in the last hour'),
    CURRENT_TIMESTAMP()
  );
  
END;

-- Create system logs table if it doesn't exist
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.system_logs` (
  log_id STRING NOT NULL,
  component STRING NOT NULL,
  message TEXT,
  log_level ENUM('info', 'warning', 'error', 'debug') DEFAULT 'info',
  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  metadata JSON
) PARTITION BY DATE(timestamp)
CLUSTER BY component, log_level;