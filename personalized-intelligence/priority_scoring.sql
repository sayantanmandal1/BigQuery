-- Priority Scoring System using AI.GENERATE_DOUBLE for Importance Ranking
-- Implements intelligent priority scoring for personalized content delivery

-- Core priority scoring function using AI.GENERATE_DOUBLE
CREATE OR REPLACE FUNCTION calculate_content_priority(
  user_id STRING,
  insight_id STRING,
  business_context STRING DEFAULT NULL
)
RETURNS FLOAT64
LANGUAGE SQL
AS (
  WITH insight_context AS (
    SELECT 
      gi.insight_id,
      gi.content,
      gi.insight_type,
      gi.confidence_score,
      gi.business_impact_score,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.urgency') as urgency_level,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.topic') as topic,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.department') as target_department
    FROM `enterprise_knowledge_ai.generated_insights` gi
    WHERE gi.insight_id = insight_id
  ),
  user_context AS (
    SELECT 
      u.user_id,
      u.department,
      u.seniority_level,
      u.current_projects,
      JSON_EXTRACT_SCALAR(u.metadata, '$.priorities') as current_priorities
    FROM `enterprise_knowledge_ai.users` u
    WHERE u.user_id = user_id
  )
  SELECT 
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Calculate priority score (0.0-1.0) for this business insight: ',
        'Content: ', SUBSTR(ic.content, 1, 400), '. ',
        'Insight Type: ', ic.insight_type, '. ',
        'Business Impact: ', CAST(ic.business_impact_score AS STRING), '. ',
        'Confidence: ', CAST(ic.confidence_score AS STRING), '. ',
        'Urgency: ', COALESCE(ic.urgency_level, 'normal'), '. ',
        'User Role: ', uc.seniority_level, ' in ', uc.department, '. ',
        'User Priorities: ', COALESCE(uc.current_priorities, 'general business'), '. ',
        'Current Projects: ', COALESCE(uc.current_projects, 'none specified'), '. ',
        CASE WHEN business_context IS NOT NULL 
          THEN CONCAT('Business Context: ', business_context, '. ')
          ELSE ''
        END,
        'Consider relevance, urgency, business impact, and user role. Return single float 0.0-1.0.'
      )
    )
  FROM insight_context ic
  CROSS JOIN user_context uc
);

-- Multi-dimensional priority scoring with weighted factors
CREATE OR REPLACE FUNCTION calculate_weighted_priority(
  user_id STRING,
  insight_id STRING,
  time_sensitivity_weight FLOAT64 DEFAULT 0.3,
  business_impact_weight FLOAT64 DEFAULT 0.4,
  personal_relevance_weight FLOAT64 DEFAULT 0.3
)
RETURNS STRUCT<
  overall_priority FLOAT64,
  time_sensitivity FLOAT64,
  business_impact FLOAT64,
  personal_relevance FLOAT64,
  explanation STRING
>
LANGUAGE SQL
AS (
  WITH scoring_components AS (
    SELECT 
      -- Time sensitivity scoring
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate time sensitivity (0.0-1.0) for: ',
          SUBSTR(gi.content, 1, 300),
          '. Urgency level: ', COALESCE(JSON_EXTRACT_SCALAR(gi.metadata, '$.urgency'), 'normal'),
          '. Created: ', CAST(gi.created_timestamp AS STRING)
        )
      ) as time_sensitivity,
      
      -- Business impact (normalized from existing score)
      LEAST(gi.business_impact_score / 100.0, 1.0) as business_impact,
      
      -- Personal relevance based on user preferences
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate personal relevance (0.0-1.0) for ', u.seniority_level, ' in ', u.department, ': ',
          SUBSTR(gi.content, 1, 300),
          '. Topic: ', COALESCE(JSON_EXTRACT_SCALAR(gi.metadata, '$.topic'), 'general'),
          '. User projects: ', COALESCE(u.current_projects, 'none')
        )
      ) as personal_relevance,
      
      gi.content,
      gi.insight_type
    FROM `enterprise_knowledge_ai.generated_insights` gi
    CROSS JOIN `enterprise_knowledge_ai.users` u
    WHERE gi.insight_id = insight_id
      AND u.user_id = user_id
  )
  SELECT AS STRUCT
    (sc.time_sensitivity * time_sensitivity_weight + 
     sc.business_impact * business_impact_weight + 
     sc.personal_relevance * personal_relevance_weight) as overall_priority,
    sc.time_sensitivity,
    sc.business_impact,
    sc.personal_relevance,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Explain why this insight has priority score ', 
        CAST(ROUND((sc.time_sensitivity * time_sensitivity_weight + 
                   sc.business_impact * business_impact_weight + 
                   sc.personal_relevance * personal_relevance_weight), 2) AS STRING),
        ': Time sensitivity: ', CAST(ROUND(sc.time_sensitivity, 2) AS STRING),
        ', Business impact: ', CAST(ROUND(sc.business_impact, 2) AS STRING),
        ', Personal relevance: ', CAST(ROUND(sc.personal_relevance, 2) AS STRING),
        '. Content: ', SUBSTR(sc.content, 1, 200)
      )
    ) as explanation
  FROM scoring_components sc
);

-- Dynamic priority adjustment based on user behavior
CREATE OR REPLACE PROCEDURE adjust_priorities_based_on_behavior(user_id STRING)
BEGIN
  -- Analyze recent user interactions to adjust priority weights
  CREATE TEMP TABLE behavior_analysis AS
  WITH recent_interactions AS (
    SELECT 
      ui.insight_id,
      ui.interaction_type,
      ui.feedback_score,
      gi.business_impact_score,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.urgency') as urgency_level,
      TIMESTAMP_DIFF(ui.interaction_timestamp, gi.created_timestamp, HOUR) as response_time_hours
    FROM `enterprise_knowledge_ai.user_interactions` ui
    JOIN `enterprise_knowledge_ai.generated_insights` gi ON ui.insight_id = gi.insight_id
    WHERE ui.user_id = user_id
      AND ui.interaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
      AND ui.interaction_type IN ('act_upon', 'share', 'view')
  ),
  behavior_patterns AS (
    SELECT 
      -- User tends to act on high business impact items
      CORR(business_impact_score, 
           CASE WHEN interaction_type = 'act_upon' THEN 1.0 ELSE 0.0 END) as impact_correlation,
      
      -- User responds quickly to urgent items
      CORR(CASE WHEN urgency_level = 'high' THEN 1.0 ELSE 0.0 END,
           CASE WHEN response_time_hours <= 2 THEN 1.0 ELSE 0.0 END) as urgency_correlation,
      
      -- Average feedback score for different priority levels
      AVG(CASE WHEN business_impact_score >= 80 THEN feedback_score ELSE NULL END) as high_impact_satisfaction,
      AVG(CASE WHEN urgency_level = 'high' THEN feedback_score ELSE NULL END) as urgent_satisfaction
    FROM recent_interactions
  )
  SELECT 
    CASE 
      WHEN impact_correlation > 0.5 THEN 0.5  -- Increase business impact weight
      WHEN impact_correlation < -0.2 THEN 0.2  -- Decrease business impact weight
      ELSE 0.4
    END as recommended_business_weight,
    
    CASE 
      WHEN urgency_correlation > 0.5 THEN 0.4  -- Increase time sensitivity weight
      WHEN urgency_correlation < -0.2 THEN 0.2  -- Decrease time sensitivity weight
      ELSE 0.3
    END as recommended_time_weight,
    
    1.0 - (recommended_business_weight + recommended_time_weight) as recommended_relevance_weight
  FROM behavior_patterns;
  
  -- Store personalized priority weights
  MERGE `enterprise_knowledge_ai.user_priority_weights` as target
  USING behavior_analysis as source
  ON target.user_id = user_id
  WHEN MATCHED THEN
    UPDATE SET 
      business_impact_weight = source.recommended_business_weight,
      time_sensitivity_weight = source.recommended_time_weight,
      personal_relevance_weight = source.recommended_relevance_weight,
      last_updated = CURRENT_TIMESTAMP()
  WHEN NOT MATCHED THEN
    INSERT (user_id, business_impact_weight, time_sensitivity_weight, personal_relevance_weight, last_updated)
    VALUES (user_id, source.recommended_business_weight, source.recommended_time_weight, source.recommended_relevance_weight, CURRENT_TIMESTAMP());
    
END;

-- Context-aware priority scoring for different scenarios
CREATE OR REPLACE FUNCTION get_contextual_priority(
  user_id STRING,
  insight_id STRING,
  context_type STRING  -- 'meeting', 'daily_briefing', 'crisis', 'planning'
)
RETURNS FLOAT64
LANGUAGE SQL
AS (
  WITH context_weights AS (
    SELECT 
      CASE context_type
        WHEN 'meeting' THEN STRUCT(0.5 as time_weight, 0.3 as impact_weight, 0.2 as relevance_weight)
        WHEN 'daily_briefing' THEN STRUCT(0.2 as time_weight, 0.4 as impact_weight, 0.4 as relevance_weight)
        WHEN 'crisis' THEN STRUCT(0.7 as time_weight, 0.2 as impact_weight, 0.1 as relevance_weight)
        WHEN 'planning' THEN STRUCT(0.1 as time_weight, 0.6 as impact_weight, 0.3 as relevance_weight)
        ELSE STRUCT(0.3 as time_weight, 0.4 as impact_weight, 0.3 as relevance_weight)
      END as weights
  ),
  priority_calculation AS (
    SELECT calculate_weighted_priority(
      user_id, 
      insight_id, 
      cw.weights.time_weight,
      cw.weights.impact_weight,
      cw.weights.relevance_weight
    ) as priority_result
    FROM context_weights cw
  )
  SELECT priority_result.overall_priority
  FROM priority_calculation
);

-- Batch priority scoring for efficient processing
CREATE OR REPLACE PROCEDURE batch_calculate_priorities(
  user_id STRING,
  insight_ids ARRAY<STRING>
)
BEGIN
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.priority_scores_${user_id}` AS
  WITH priority_calculations AS (
    SELECT 
      insight_id,
      calculate_content_priority(user_id, insight_id) as base_priority,
      calculate_weighted_priority(user_id, insight_id) as detailed_priority,
      CURRENT_TIMESTAMP() as calculated_at
    FROM UNNEST(insight_ids) as insight_id
  )
  SELECT 
    insight_id,
    base_priority,
    detailed_priority.overall_priority as weighted_priority,
    detailed_priority.time_sensitivity,
    detailed_priority.business_impact,
    detailed_priority.personal_relevance,
    detailed_priority.explanation,
    calculated_at
  FROM priority_calculations
  ORDER BY weighted_priority DESC;
  
END;