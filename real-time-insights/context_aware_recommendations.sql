-- Context-Aware Recommendation Engine
-- Generates intelligent recommendations based on current context and historical patterns

-- Create user context tracking table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.user_context` (
  context_id STRING NOT NULL,
  user_id STRING NOT NULL,
  session_id STRING,
  current_activity JSON,
  active_projects ARRAY<STRING>,
  recent_queries ARRAY<STRING>,
  interaction_patterns JSON,
  context_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  expiration_timestamp TIMESTAMP
) PARTITION BY DATE(context_timestamp)
CLUSTER BY user_id;

-- Create recommendations table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.contextual_recommendations` (
  recommendation_id STRING NOT NULL,
  user_id STRING NOT NULL,
  context_id STRING,
  recommendation_type ENUM('action_item', 'information', 'decision_support', 'process_improvement'),
  title STRING,
  content TEXT,
  priority_score FLOAT64,
  confidence_score FLOAT64,
  supporting_data JSON,
  expiration_timestamp TIMESTAMP,
  created_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
  interaction_status ENUM('pending', 'viewed', 'acted_upon', 'dismissed') DEFAULT 'pending',
  metadata JSON
) PARTITION BY DATE(created_timestamp)
CLUSTER BY user_id, recommendation_type, priority_score;

-- Function to analyze current context and generate recommendations
CREATE OR REPLACE FUNCTION generate_context_recommendations(
  user_context JSON,
  historical_data JSON,
  current_discussion_context TEXT
)
RETURNS ARRAY<STRUCT<
  type STRING,
  title STRING,
  content TEXT,
  priority FLOAT64,
  confidence FLOAT64,
  supporting_evidence ARRAY<STRING>
>>
LANGUAGE SQL
AS (
  WITH context_analysis AS (
    SELECT 
      -- Generate action item recommendations
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Based on this discussion context: "', current_discussion_context, '"',
          ' and user context: ', JSON_EXTRACT_SCALAR(user_context, '$.current_projects'),
          ', generate 3 specific action item recommendations.',
          ' Historical similar situations: ', JSON_EXTRACT_SCALAR(historical_data, '$.similar_contexts'),
          '. Format as numbered list with clear next steps.'
        )
      ) as action_recommendations,
      
      -- Generate information recommendations
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Identify relevant information this user should know given context: "',
          current_discussion_context, '"',
          ' and their role: ', JSON_EXTRACT_SCALAR(user_context, '$.role'),
          '. Historical patterns: ', JSON_EXTRACT_SCALAR(historical_data, '$.information_patterns'),
          '. Suggest specific documents, data, or insights they should review.'
        )
      ) as information_recommendations,
      
      -- Generate decision support recommendations
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Provide decision support recommendations for: "', current_discussion_context, '"',
          '. Consider past decisions: ', JSON_EXTRACT_SCALAR(historical_data, '$.past_decisions'),
          ', current constraints: ', JSON_EXTRACT_SCALAR(user_context, '$.constraints'),
          '. Suggest decision frameworks and key factors to consider.'
        )
      ) as decision_recommendations,
      
      -- Calculate priority scores
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate the urgency of action items from 0.0 to 1.0 for context: "',
          current_discussion_context, '"'
        )
      ) as action_priority,
      
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate the importance of information sharing from 0.0 to 1.0 for context: "',
          current_discussion_context, '"'
        )
      ) as info_priority,
      
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate the criticality of decision support from 0.0 to 1.0 for context: "',
          current_discussion_context, '"'
        )
      ) as decision_priority
  ),
  
  -- Extract supporting evidence from historical data
  evidence_extraction AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Extract 3 key pieces of supporting evidence from historical data: ',
          JSON_EXTRACT_SCALAR(historical_data, '$.evidence_sources'),
          ' that support recommendations for context: "', current_discussion_context, '"'
        )
      ) as evidence_summary
  )
  
  SELECT ARRAY[
    STRUCT(
      'action_item' as type,
      'Recommended Actions' as title,
      ca.action_recommendations as content,
      ca.action_priority as priority,
      0.85 as confidence,
      SPLIT(ee.evidence_summary, '\n') as supporting_evidence
    ),
    STRUCT(
      'information' as type,
      'Relevant Information' as title,
      ca.information_recommendations as content,
      ca.info_priority as priority,
      0.80 as confidence,
      SPLIT(ee.evidence_summary, '\n') as supporting_evidence
    ),
    STRUCT(
      'decision_support' as type,
      'Decision Support' as title,
      ca.decision_recommendations as content,
      ca.decision_priority as priority,
      0.90 as confidence,
      SPLIT(ee.evidence_summary, '\n') as supporting_evidence
    )
  ]
  FROM context_analysis ca, evidence_extraction ee
);

-- Function to find similar historical contexts
CREATE OR REPLACE FUNCTION find_similar_contexts(
  current_context TEXT,
  user_id STRING,
  lookback_days INT64 DEFAULT 30
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH historical_contexts AS (
    SELECT 
      content,
      confidence_score,
      created_timestamp,
      metadata
    FROM `enterprise_knowledge_ai.realtime_insights`
    WHERE target_users = [user_id] OR 'all_users' IN UNNEST(target_users)
      AND created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL lookback_days DAY)
      AND insight_type IN ('contextual', 'recommendation')
  ),
  
  similarity_analysis AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Find patterns and similarities between current context: "', current_context, '"',
          ' and these historical contexts: ',
          (SELECT STRING_AGG(content, '; ') FROM historical_contexts LIMIT 10),
          '. Identify recurring themes, successful approaches, and lessons learned.'
        )
      ) as pattern_analysis,
      
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Extract key decision points and outcomes from historical contexts: ',
          (SELECT STRING_AGG(CONCAT(content, ' (confidence: ', CAST(confidence_score AS STRING), ')'), '; ') 
           FROM historical_contexts LIMIT 5),
          '. Focus on actionable insights and successful strategies.'
        )
      ) as decision_insights
  )
  
  SELECT TO_JSON(STRUCT(
    sa.pattern_analysis as similar_contexts,
    sa.decision_insights as past_decisions,
    (SELECT ARRAY_AGG(content) FROM historical_contexts LIMIT 5) as evidence_sources,
    (SELECT STRING_AGG(
      CONCAT('Pattern from ', FORMAT_TIMESTAMP('%Y-%m-%d', created_timestamp), ': ', 
             SUBSTR(content, 1, 100), '...'), 
      ' | ') 
     FROM historical_contexts 
     WHERE confidence_score > 0.7 
     LIMIT 3) as information_patterns
  ))
  FROM similarity_analysis sa
);

-- Stored procedure to generate recommendations for active users
CREATE OR REPLACE PROCEDURE generate_active_user_recommendations()
BEGIN
  DECLARE done BOOL DEFAULT FALSE;
  DECLARE current_user_id STRING;
  DECLARE current_context_data JSON;
  DECLARE current_discussion TEXT;
  DECLARE historical_context JSON;
  DECLARE recommendations ARRAY<STRUCT<
    type STRING,
    title STRING,
    content TEXT,
    priority FLOAT64,
    confidence FLOAT64,
    supporting_evidence ARRAY<STRING>
  >>;
  
  -- Cursor for users with recent activity
  DECLARE user_cursor CURSOR FOR
    SELECT DISTINCT
      uc.user_id,
      TO_JSON(STRUCT(
        uc.current_activity,
        uc.active_projects,
        uc.recent_queries,
        uc.interaction_patterns
      )) as context_data,
      COALESCE(
        JSON_EXTRACT_SCALAR(uc.current_activity, '$.discussion_context'),
        'General business context'
      ) as discussion_context
    FROM `enterprise_knowledge_ai.user_context` uc
    WHERE uc.context_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
      AND uc.expiration_timestamp > CURRENT_TIMESTAMP()
    LIMIT 20;
  
  DECLARE CONTINUE HANDLER FOR NOT_FOUND SET done = TRUE;
  
  OPEN user_cursor;
  
  recommendation_loop: LOOP
    FETCH user_cursor INTO current_user_id, current_context_data, current_discussion;
    
    IF done THEN
      LEAVE recommendation_loop;
    END IF;
    
    -- Find similar historical contexts
    SET historical_context = find_similar_contexts(current_discussion, current_user_id, 30);
    
    -- Generate context-aware recommendations
    SET recommendations = generate_context_recommendations(
      current_context_data,
      historical_context,
      current_discussion
    );
    
    -- Insert recommendations into the table
    INSERT INTO `enterprise_knowledge_ai.contextual_recommendations` (
      recommendation_id,
      user_id,
      context_id,
      recommendation_type,
      title,
      content,
      priority_score,
      confidence_score,
      supporting_data,
      expiration_timestamp,
      metadata
    )
    SELECT 
      GENERATE_UUID() as recommendation_id,
      current_user_id as user_id,
      GENERATE_UUID() as context_id,
      rec.type as recommendation_type,
      rec.title,
      rec.content,
      rec.priority as priority_score,
      rec.confidence as confidence_score,
      TO_JSON(STRUCT(
        rec.supporting_evidence as evidence,
        current_discussion as original_context,
        historical_context as historical_reference
      )) as supporting_data,
      TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 4 HOUR) as expiration_timestamp,
      TO_JSON(STRUCT(
        'generation_method', 'context_aware_ai',
        'processing_timestamp', CURRENT_TIMESTAMP()
      )) as metadata
    FROM UNNEST(recommendations) as rec;
    
  END LOOP;
  
  CLOSE user_cursor;
  
  -- Clean up expired recommendations
  DELETE FROM `enterprise_knowledge_ai.contextual_recommendations`
  WHERE expiration_timestamp < CURRENT_TIMESTAMP();
  
  -- Log recommendation generation summary
  INSERT INTO `enterprise_knowledge_ai.system_logs` (
    log_id,
    component,
    message,
    timestamp
  )
  VALUES (
    GENERATE_UUID(),
    'recommendation_engine',
    CONCAT('Generated recommendations for ', 
           (SELECT COUNT(DISTINCT user_id) 
            FROM `enterprise_knowledge_ai.contextual_recommendations` 
            WHERE created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)),
           ' active users'),
    CURRENT_TIMESTAMP()
  );
  
END;

-- Function to get personalized recommendations for a specific user
CREATE OR REPLACE FUNCTION get_user_recommendations(
  target_user_id STRING,
  recommendation_types ARRAY<STRING> DEFAULT ['action_item', 'information', 'decision_support'],
  max_results INT64 DEFAULT 10
)
RETURNS ARRAY<STRUCT<
  id STRING,
  type STRING,
  title STRING,
  content STRING,
  priority FLOAT64,
  confidence FLOAT64,
  created_time TIMESTAMP
>>
LANGUAGE SQL
AS (
  SELECT ARRAY_AGG(
    STRUCT(
      recommendation_id as id,
      recommendation_type as type,
      title,
      content,
      priority_score as priority,
      confidence_score as confidence,
      created_timestamp as created_time
    )
    ORDER BY priority_score DESC, confidence_score DESC
    LIMIT max_results
  )
  FROM `enterprise_knowledge_ai.contextual_recommendations`
  WHERE user_id = target_user_id
    AND recommendation_type IN UNNEST(recommendation_types)
    AND expiration_timestamp > CURRENT_TIMESTAMP()
    AND interaction_status = 'pending'
);

-- Function to update recommendation interaction status
CREATE OR REPLACE FUNCTION update_recommendation_status(
  recommendation_id STRING,
  new_status STRING,
  user_feedback JSON DEFAULT NULL
)
RETURNS BOOL
LANGUAGE SQL
AS (
  (
    UPDATE `enterprise_knowledge_ai.contextual_recommendations`
    SET 
      interaction_status = new_status,
      metadata = JSON_SET(
        COALESCE(metadata, JSON_OBJECT()),
        '$.user_feedback', user_feedback,
        '$.status_updated_timestamp', CURRENT_TIMESTAMP()
      )
    WHERE recommendation_id = recommendation_id;
    
    SELECT TRUE
  )
);