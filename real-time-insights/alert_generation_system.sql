-- Alert Generation System
-- Implements AI-powered significance detection and intelligent alerting

-- Create alerts configuration table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.alert_configurations` (
  config_id STRING NOT NULL,
  alert_type ENUM('threshold', 'anomaly', 'pattern', 'business_rule'),
  name STRING NOT NULL,
  description TEXT,
  conditions JSON,
  target_users ARRAY<STRING>,
  notification_channels ARRAY<STRING>,
  is_active BOOL DEFAULT TRUE,
  created_by STRING,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
) CLUSTER BY alert_type, is_active;

-- Create alerts history table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.alert_history` (
  alert_id STRING NOT NULL,
  config_id STRING NOT NULL,
  trigger_data JSON,
  alert_content TEXT,
  significance_score FLOAT64,
  urgency_level ENUM('low', 'medium', 'high', 'critical'),
  target_users ARRAY<STRING>,
  notification_status ENUM('pending', 'sent', 'acknowledged', 'resolved'),
  triggered_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  acknowledged_timestamp TIMESTAMP,
  resolved_timestamp TIMESTAMP,
  metadata JSON
) PARTITION BY DATE(triggered_timestamp)
CLUSTER BY urgency_level, notification_status;

-- Function to evaluate alert significance using AI.GENERATE_BOOL
CREATE OR REPLACE FUNCTION evaluate_alert_significance(
  data_content TEXT,
  alert_context JSON,
  significance_threshold FLOAT64 DEFAULT 0.7
)
RETURNS STRUCT<
  is_significant BOOL,
  significance_score FLOAT64,
  explanation TEXT,
  recommended_action TEXT
>
LANGUAGE SQL
AS (
  WITH significance_analysis AS (
    SELECT 
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Determine if this data represents a significant business event requiring immediate attention: ',
          data_content,
          '. Context: ', JSON_EXTRACT_SCALAR(alert_context, '$.business_context'),
          '. Historical patterns: ', JSON_EXTRACT_SCALAR(alert_context, '$.historical_patterns'),
          '. Significance threshold: ', CAST(significance_threshold AS STRING)
        )
      ) as is_significant_bool,
      
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate the business significance of this event from 0.0 to 1.0: ',
          data_content,
          '. Consider impact, urgency, and business context.'
        )
      ) as significance_double,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Explain why this event is or is not significant for business operations: ',
          data_content,
          '. Provide specific reasoning and context.'
        )
      ) as explanation_text,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Recommend specific actions to take in response to this event: ',
          data_content,
          '. Provide actionable, prioritized recommendations.'
        )
      ) as recommended_action_text
  )
  
  SELECT STRUCT(
    sa.is_significant_bool AND sa.significance_double >= significance_threshold as is_significant,
    sa.significance_double as significance_score,
    sa.explanation_text as explanation,
    sa.recommended_action_text as recommended_action
  )
  FROM significance_analysis sa
);

-- Function to generate contextual alerts
CREATE OR REPLACE FUNCTION generate_contextual_alert(
  trigger_data JSON,
  user_context JSON
)
RETURNS STRUCT<
  alert_content TEXT,
  urgency_level STRING,
  personalized_message TEXT
>
LANGUAGE SQL
AS (
  WITH alert_generation AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Generate a clear, actionable alert message for this business event: ',
          JSON_EXTRACT_SCALAR(trigger_data, '$.event_description'),
          '. Data: ', JSON_EXTRACT_SCALAR(trigger_data, '$.data_summary'),
          '. Make it concise but informative.'
        )
      ) as base_alert_content,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Personalize this alert for a user with role "', 
          JSON_EXTRACT_SCALAR(user_context, '$.role'),
          '" and current projects: ',
          JSON_EXTRACT_SCALAR(user_context, '$.current_projects'),
          '. Alert: ', JSON_EXTRACT_SCALAR(trigger_data, '$.event_description'),
          '. Focus on what matters most to this user.'
        )
      ) as personalized_content,
      
      CASE 
        WHEN CAST(JSON_EXTRACT_SCALAR(trigger_data, '$.significance_score') AS FLOAT64) > 0.9 THEN 'critical'
        WHEN CAST(JSON_EXTRACT_SCALAR(trigger_data, '$.significance_score') AS FLOAT64) > 0.7 THEN 'high'
        WHEN CAST(JSON_EXTRACT_SCALAR(trigger_data, '$.significance_score') AS FLOAT64) > 0.5 THEN 'medium'
        ELSE 'low'
      END as urgency_determination
  )
  
  SELECT STRUCT(
    ag.base_alert_content as alert_content,
    ag.urgency_determination as urgency_level,
    ag.personalized_content as personalized_message
  )
  FROM alert_generation ag
);

-- Stored procedure to process and generate alerts
CREATE OR REPLACE PROCEDURE process_alert_triggers()
BEGIN
  DECLARE done BOOL DEFAULT FALSE;
  DECLARE current_insight_id STRING;
  DECLARE current_content TEXT;
  DECLARE current_confidence FLOAT64;
  DECLARE significance_result STRUCT<
    is_significant BOOL,
    significance_score FLOAT64,
    explanation TEXT,
    recommended_action TEXT
  >;
  DECLARE alert_result STRUCT<
    alert_content TEXT,
    urgency_level STRING,
    personalized_message TEXT
  >;
  
  -- Cursor for recent high-confidence insights that haven't been processed for alerts
  DECLARE insight_cursor CURSOR FOR
    SELECT 
      ri.insight_id,
      ri.content,
      ri.confidence_score
    FROM `enterprise_knowledge_ai.realtime_insights` ri
    LEFT JOIN `enterprise_knowledge_ai.alert_history` ah 
      ON ri.insight_id = JSON_EXTRACT_SCALAR(ah.trigger_data, '$.source_insight_id')
    WHERE ri.created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE)
      AND ri.confidence_score > 0.6
      AND ah.alert_id IS NULL  -- Not already processed
    ORDER BY ri.confidence_score DESC, ri.created_timestamp DESC
    LIMIT 50;
  
  DECLARE CONTINUE HANDLER FOR NOT_FOUND SET done = TRUE;
  
  OPEN insight_cursor;
  
  alert_loop: LOOP
    FETCH insight_cursor INTO current_insight_id, current_content, current_confidence;
    
    IF done THEN
      LEAVE alert_loop;
    END IF;
    
    -- Evaluate significance using AI
    SET significance_result = evaluate_alert_significance(
      current_content,
      JSON_OBJECT(
        'business_context', 'Enterprise knowledge platform monitoring',
        'historical_patterns', 'Based on recent system activity and user interactions'
      ),
      0.7
    );
    
    -- Only proceed if the insight is deemed significant
    IF significance_result.is_significant THEN
      
      -- Generate contextual alert
      SET alert_result = generate_contextual_alert(
        JSON_OBJECT(
          'source_insight_id', current_insight_id,
          'event_description', current_content,
          'data_summary', CONCAT('Confidence: ', CAST(current_confidence AS STRING)),
          'significance_score', CAST(significance_result.significance_score AS STRING)
        ),
        JSON_OBJECT(
          'role', 'business_analyst',  -- TODO: Get actual user context
          'current_projects', 'enterprise_intelligence'
        )
      );
      
      -- Insert alert into history
      INSERT INTO `enterprise_knowledge_ai.alert_history` (
        alert_id,
        config_id,
        trigger_data,
        alert_content,
        significance_score,
        urgency_level,
        target_users,
        notification_status,
        metadata
      )
      VALUES (
        GENERATE_UUID(),
        'auto_generated_significance',
        JSON_OBJECT(
          'source_insight_id', current_insight_id,
          'original_content', current_content,
          'confidence_score', current_confidence,
          'significance_explanation', significance_result.explanation,
          'recommended_action', significance_result.recommended_action
        ),
        alert_result.alert_content,
        significance_result.significance_score,
        alert_result.urgency_level,
        ['all_stakeholders'],  -- TODO: Implement proper user targeting
        'pending',
        JSON_OBJECT(
          'personalized_message', alert_result.personalized_message,
          'processing_timestamp', CURRENT_TIMESTAMP()
        )
      );
      
    END IF;
    
  END LOOP;
  
  CLOSE insight_cursor;
  
  -- Log alert processing summary
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id,
    component,
    message,
    timestamp
  )
  VALUES (
    GENERATE_UUID(),
    'alert_generator',
    CONCAT('Processed ', 
           (SELECT COUNT(*) FROM `enterprise_knowledge_ai.alert_history` 
            WHERE triggered_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 15 MINUTE)),
           ' alerts in the last 15 minutes'),
    CURRENT_TIMESTAMP()
  );
  
END;

-- Function to check for anomaly patterns using AI analysis
CREATE OR REPLACE FUNCTION detect_anomaly_patterns(
  metric_data ARRAY<STRUCT<timestamp TIMESTAMP, value FLOAT64>>,
  context_info JSON
)
RETURNS STRUCT<
  has_anomaly BOOL,
  anomaly_description TEXT,
  confidence_level FLOAT64,
  suggested_investigation TEXT
>
LANGUAGE SQL
AS (
  WITH anomaly_analysis AS (
    SELECT 
      AI.GENERATE_BOOL(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Analyze this time series data for anomalies: ',
          TO_JSON_STRING(metric_data),
          '. Context: ', JSON_EXTRACT_SCALAR(context_info, '$.metric_context'),
          '. Determine if there are significant anomalies requiring attention.'
        )
      ) as has_anomaly_bool,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Describe any anomalies found in this data: ',
          TO_JSON_STRING(metric_data),
          '. Explain the nature, timing, and potential causes of anomalies.'
        )
      ) as anomaly_description_text,
      
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate confidence in anomaly detection from 0.0 to 1.0 for this data: ',
          TO_JSON_STRING(metric_data)
        )
      ) as confidence_double,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Suggest specific investigation steps for these anomalies: ',
          TO_JSON_STRING(metric_data),
          '. Provide actionable next steps for analysis.'
        )
      ) as investigation_suggestions
  )
  
  SELECT STRUCT(
    aa.has_anomaly_bool as has_anomaly,
    aa.anomaly_description_text as anomaly_description,
    aa.confidence_double as confidence_level,
    aa.investigation_suggestions as suggested_investigation
  )
  FROM anomaly_analysis aa
);