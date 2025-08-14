-- Preference Learning Algorithm for Personalized Intelligence
-- Learns user preferences from interaction patterns and adapts content recommendations

-- Create preference learning model training procedure
CREATE OR REPLACE PROCEDURE train_user_preference_model(user_id STRING)
BEGIN
  DECLARE interaction_count INT64;
  
  -- Check if user has sufficient interaction history
  SET interaction_count = (
    SELECT COUNT(*)
    FROM `enterprise_knowledge_ai.user_interactions`
    WHERE user_id = user_id
      AND interaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  );
  
  IF interaction_count < 10 THEN
    -- Use department-based defaults for new users
    CALL initialize_default_preferences(user_id);
    RETURN;
  END IF;
  
  -- Create user preference profile based on interaction patterns
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.user_preferences_${user_id}` AS
  WITH interaction_analysis AS (
    SELECT 
      ui.insight_id,
      gi.insight_type,
      gi.content,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.topic') as topic,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.department') as content_department,
      ui.interaction_type,
      ui.feedback_score,
      ui.interaction_timestamp,
      -- Weight recent interactions more heavily
      EXP(-DATE_DIFF(CURRENT_DATE(), DATE(ui.interaction_timestamp), DAY) / 30.0) as recency_weight
    FROM `enterprise_knowledge_ai.user_interactions` ui
    JOIN `enterprise_knowledge_ai.generated_insights` gi ON ui.insight_id = gi.insight_id
    WHERE ui.user_id = user_id
      AND ui.interaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
  ),
  topic_preferences AS (
    SELECT 
      topic,
      COUNT(*) as interaction_count,
      AVG(CASE 
        WHEN interaction_type = 'act_upon' THEN 1.0
        WHEN interaction_type = 'share' THEN 0.8
        WHEN interaction_type = 'view' THEN 0.5
        WHEN interaction_type = 'dismiss' THEN 0.1
        ELSE 0.3
      END * recency_weight) as preference_score,
      AVG(COALESCE(feedback_score, 3) * recency_weight) / 5.0 as feedback_score
    FROM interaction_analysis
    WHERE topic IS NOT NULL
    GROUP BY topic
    HAVING interaction_count >= 3
  ),
  content_type_preferences AS (
    SELECT 
      insight_type,
      COUNT(*) as interaction_count,
      AVG(CASE 
        WHEN interaction_type = 'act_upon' THEN 1.0
        WHEN interaction_type = 'share' THEN 0.8
        WHEN interaction_type = 'view' THEN 0.5
        WHEN interaction_type = 'dismiss' THEN 0.1
        ELSE 0.3
      END * recency_weight) as preference_score
    FROM interaction_analysis
    GROUP BY insight_type
  ),
  temporal_preferences AS (
    SELECT 
      EXTRACT(HOUR FROM interaction_timestamp) as preferred_hour,
      EXTRACT(DAYOFWEEK FROM interaction_timestamp) as preferred_day,
      COUNT(*) as interaction_count
    FROM interaction_analysis
    WHERE interaction_type IN ('view', 'act_upon', 'share')
    GROUP BY preferred_hour, preferred_day
  )
  SELECT 
    user_id,
    'topic' as preference_type,
    topic as preference_key,
    preference_score,
    feedback_score as confidence,
    interaction_count,
    CURRENT_TIMESTAMP() as last_updated
  FROM topic_preferences
  
  UNION ALL
  
  SELECT 
    user_id,
    'content_type' as preference_type,
    insight_type as preference_key,
    preference_score,
    preference_score as confidence,
    interaction_count,
    CURRENT_TIMESTAMP() as last_updated
  FROM content_type_preferences
  
  UNION ALL
  
  SELECT 
    user_id,
    'temporal' as preference_type,
    CONCAT('hour_', CAST(preferred_hour AS STRING)) as preference_key,
    interaction_count / (SELECT MAX(interaction_count) FROM temporal_preferences) as preference_score,
    0.8 as confidence,
    interaction_count,
    CURRENT_TIMESTAMP() as last_updated
  FROM temporal_preferences
  WHERE interaction_count >= 5;
  
END;

-- Initialize default preferences for new users
CREATE OR REPLACE PROCEDURE initialize_default_preferences(user_id STRING)
BEGIN
  DECLARE user_dept STRING;
  DECLARE user_level STRING;
  
  SET (user_dept, user_level) = (
    SELECT AS STRUCT department, seniority_level
    FROM `enterprise_knowledge_ai.users`
    WHERE user_id = user_id
  );
  
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.user_preferences_${user_id}` AS
  WITH department_defaults AS (
    SELECT 
      user_id,
      'topic' as preference_type,
      topic as preference_key,
      score as preference_score,
      0.5 as confidence,
      0 as interaction_count,
      CURRENT_TIMESTAMP() as last_updated
    FROM UNNEST([
      STRUCT('financial_metrics' as topic, 0.9 as score),
      STRUCT('budget_analysis', 0.8),
      STRUCT('risk_assessment', 0.7),
      STRUCT('compliance', 0.6)
    ])
    WHERE user_dept = 'finance'
    
    UNION ALL
    
    SELECT 
      user_id,
      'topic',
      topic,
      score,
      0.5,
      0,
      CURRENT_TIMESTAMP()
    FROM UNNEST([
      STRUCT('customer_insights' as topic, 0.9 as score),
      STRUCT('campaign_performance', 0.8),
      STRUCT('market_trends', 0.7),
      STRUCT('brand_analysis', 0.6)
    ])
    WHERE user_dept = 'marketing'
    
    UNION ALL
    
    SELECT 
      user_id,
      'content_type',
      content_type,
      CASE user_level
        WHEN 'executive' THEN 0.9
        WHEN 'senior_manager' THEN 0.8
        WHEN 'manager' THEN 0.7
        ELSE 0.6
      END,
      0.5,
      0,
      CURRENT_TIMESTAMP()
    FROM UNNEST(['predictive', 'prescriptive', 'descriptive']) as content_type
  )
  SELECT * FROM department_defaults;
  
END;

-- Adaptive preference learning with AI-powered pattern recognition
CREATE OR REPLACE FUNCTION get_preference_score(
  user_id STRING,
  content_topic STRING,
  content_type STRING
)
RETURNS FLOAT64
LANGUAGE SQL
AS (
  WITH user_prefs AS (
    SELECT 
      preference_key,
      preference_score,
      confidence
    FROM `enterprise_knowledge_ai.user_preferences_${user_id}`
    WHERE preference_type IN ('topic', 'content_type')
  ),
  topic_score AS (
    SELECT COALESCE(preference_score * confidence, 0.5) as score
    FROM user_prefs
    WHERE preference_key = content_topic
  ),
  type_score AS (
    SELECT COALESCE(preference_score * confidence, 0.5) as score
    FROM user_prefs
    WHERE preference_key = content_type
  )
  SELECT 
    (COALESCE((SELECT score FROM topic_score), 0.5) * 0.7 + 
     COALESCE((SELECT score FROM type_score), 0.5) * 0.3) as combined_score
);

-- Collaborative filtering for preference enhancement
CREATE OR REPLACE PROCEDURE enhance_preferences_with_collaborative_filtering(user_id STRING)
BEGIN
  DECLARE user_dept STRING;
  
  SET user_dept = (
    SELECT department
    FROM `enterprise_knowledge_ai.users`
    WHERE user_id = user_id
  );
  
  -- Find similar users in the same department
  CREATE TEMP TABLE similar_users AS
  WITH user_similarity AS (
    SELECT 
      u2.user_id as similar_user_id,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Calculate similarity between user interaction patterns. ',
          'User 1 interactions: ', 
          (SELECT STRING_AGG(CONCAT(insight_type, ':', interaction_type), ', ')
           FROM `enterprise_knowledge_ai.user_interactions` ui1
           JOIN `enterprise_knowledge_ai.generated_insights` gi1 ON ui1.insight_id = gi1.insight_id
           WHERE ui1.user_id = user_id
           LIMIT 20),
          '. User 2 interactions: ',
          (SELECT STRING_AGG(CONCAT(insight_type, ':', interaction_type), ', ')
           FROM `enterprise_knowledge_ai.user_interactions` ui2
           JOIN `enterprise_knowledge_ai.generated_insights` gi2 ON ui2.insight_id = gi2.insight_id
           WHERE ui2.user_id = u2.user_id
           LIMIT 20),
          '. Return similarity score 0.0-1.0.'
        )
      ) as similarity_score
    FROM `enterprise_knowledge_ai.users` u2
    WHERE u2.department = user_dept
      AND u2.user_id != user_id
  )
  SELECT similar_user_id, similarity_score
  FROM user_similarity
  WHERE similarity_score >= 0.7
  ORDER BY similarity_score DESC
  LIMIT 5;
  
  -- Update preferences based on similar users
  MERGE `enterprise_knowledge_ai.user_preferences_${user_id}` as target
  USING (
    SELECT 
      preference_type,
      preference_key,
      AVG(up.preference_score * su.similarity_score) as collaborative_score
    FROM similar_users su
    JOIN `enterprise_knowledge_ai.user_preferences_${su.similar_user_id}` up
      ON TRUE
    GROUP BY preference_type, preference_key
  ) as source
  ON target.preference_type = source.preference_type 
     AND target.preference_key = source.preference_key
  WHEN MATCHED THEN
    UPDATE SET 
      preference_score = (target.preference_score * 0.7 + source.collaborative_score * 0.3),
      confidence = LEAST(target.confidence + 0.1, 1.0),
      last_updated = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN
    INSERT (user_id, preference_type, preference_key, preference_score, confidence, interaction_count, last_updated)
    VALUES (user_id, source.preference_type, source.preference_key, source.collaborative_score, 0.6, 0, CURRENT_TIMESTAMP());
    
END;