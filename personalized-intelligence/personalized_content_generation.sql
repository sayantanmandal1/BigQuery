-- Personalized Content Generation using AI.GENERATE
-- Creates customized insights and recommendations tailored to individual users

-- Core personalized content generation function
CREATE OR REPLACE FUNCTION generate_personalized_insight(
  user_id STRING,
  base_insight_id STRING,
  personalization_level STRING DEFAULT 'standard'  -- 'basic', 'standard', 'advanced'
)
RETURNS STRING
LANGUAGE SQL
AS (
  WITH user_profile AS (
    SELECT 
      u.user_id,
      u.department,
      u.seniority_level,
      u.current_projects,
      u.communication_style,
      JSON_EXTRACT_SCALAR(u.metadata, '$.expertise_areas') as expertise_areas,
      JSON_EXTRACT_SCALAR(u.metadata, '$.preferred_detail_level') as detail_preference
    FROM `enterprise_knowledge_ai.users` u
    WHERE u.user_id = user_id
  ),
  base_insight AS (
    SELECT 
      gi.content,
      gi.insight_type,
      gi.confidence_score,
      gi.business_impact_score,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.topic') as topic,
      JSON_EXTRACT_SCALAR(gi.metadata, '$.data_sources') as data_sources
    FROM `enterprise_knowledge_ai.generated_insights` gi
    WHERE gi.insight_id = base_insight_id
  ),
  user_preferences AS (
    SELECT 
      STRING_AGG(
        CONCAT(preference_key, ':', CAST(ROUND(preference_score, 2) AS STRING)), 
        ', '
      ) as preference_summary
    FROM `enterprise_knowledge_ai.user_preferences_${user_id}`
    WHERE confidence >= 0.6
      AND preference_type = 'topic'
    ORDER BY preference_score DESC
    LIMIT 5
  )
  SELECT 
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Personalize this business insight for the target user: ',
        
        -- Base insight content
        'Original Insight: ', bi.content, '. ',
        
        -- User context
        'User Profile: ', up.seniority_level, ' in ', up.department, ' department. ',
        'Communication Style: ', COALESCE(up.communication_style, 'professional'), '. ',
        'Expertise Areas: ', COALESCE(up.expertise_areas, 'general business'), '. ',
        'Current Projects: ', COALESCE(up.current_projects, 'none specified'), '. ',
        'Detail Preference: ', COALESCE(up.detail_preference, 'moderate'), '. ',
        
        -- User preferences
        'User Topic Preferences: ', COALESCE(upr.preference_summary, 'none available'), '. ',
        
        -- Personalization instructions
        'Personalization Level: ', personalization_level, '. ',
        
        CASE personalization_level
          WHEN 'basic' THEN 
            'Adjust tone and terminology for their role. Keep structure similar.'
          WHEN 'standard' THEN 
            'Customize content focus, add role-specific implications, adjust detail level.'
          WHEN 'advanced' THEN 
            'Completely reframe for their context, add personalized recommendations, include relevant examples from their domain.'
        END, ' ',
        
        -- Output requirements
        'Maintain factual accuracy. Include confidence level: ', 
        CAST(bi.confidence_score AS STRING), 
        '. Business impact: ', CAST(bi.business_impact_score AS STRING), 
        '. Return personalized insight only, no meta-commentary.'
      )
    )
  FROM user_profile up
  CROSS JOIN base_insight bi
  CROSS JOIN user_preferences upr
);

-- Generate personalized executive summary
CREATE OR REPLACE FUNCTION generate_executive_summary(
  user_id STRING,
  insight_ids ARRAY<STRING>,
  summary_type STRING DEFAULT 'daily'  -- 'daily', 'weekly', 'monthly', 'ad_hoc'
)
RETURNS STRING
LANGUAGE SQL
AS (
  WITH user_context AS (
    SELECT 
      u.department,
      u.seniority_level,
      JSON_EXTRACT_SCALAR(u.metadata, '$.key_metrics') as key_metrics,
      JSON_EXTRACT_SCALAR(u.metadata, '$.strategic_focus') as strategic_focus
    FROM `enterprise_knowledge_ai.users` u
    WHERE u.user_id = user_id
  ),
  insight_collection AS (
    SELECT 
      STRING_AGG(
        CONCAT(
          'Insight ', ROW_NUMBER() OVER (ORDER BY gi.business_impact_score DESC), ': ',
          gi.content, ' (Impact: ', CAST(gi.business_impact_score AS STRING), 
          ', Confidence: ', CAST(gi.confidence_score AS STRING), ')'
        ), 
        '\n\n'
      ) as all_insights,
      COUNT(*) as insight_count,
      AVG(gi.business_impact_score) as avg_impact,
      AVG(gi.confidence_score) as avg_confidence
    FROM `enterprise_knowledge_ai.generated_insights` gi
    WHERE gi.insight_id IN UNNEST(insight_ids)
  )
  SELECT 
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Create a personalized executive summary for a ', uc.seniority_level, 
        ' in ', uc.department, ' department. ',
        
        'Summary Type: ', summary_type, ' briefing. ',
        'Strategic Focus: ', COALESCE(uc.strategic_focus, 'general business growth'), '. ',
        'Key Metrics of Interest: ', COALESCE(uc.key_metrics, 'revenue, efficiency, customer satisfaction'), '. ',
        
        'Source Insights (', CAST(ic.insight_count AS STRING), ' total): ',
        ic.all_insights, ' ',
        
        'Requirements: ',
        '1. Start with 2-3 sentence executive overview ',
        '2. Highlight top 3 most critical insights for their role ',
        '3. Include specific action recommendations ',
        '4. Note any urgent items requiring immediate attention ',
        '5. End with strategic implications for their department ',
        '6. Use executive-appropriate language and structure ',
        '7. Keep total length under 500 words ',
        
        'Average Impact Score: ', CAST(ROUND(ic.avg_impact, 1) AS STRING),
        ', Average Confidence: ', CAST(ROUND(ic.avg_confidence, 1) AS STRING)
      )
    )
  FROM user_context uc
  CROSS JOIN insight_collection ic
);

-- Generate personalized recommendations based on user context
CREATE OR REPLACE FUNCTION generate_personalized_recommendations(
  user_id STRING,
  context_data STRING,
  recommendation_type STRING DEFAULT 'strategic'  -- 'strategic', 'tactical', 'operational'
)
RETURNS ARRAY<STRING>
LANGUAGE SQL
AS (
  WITH user_profile AS (
    SELECT 
      u.department,
      u.seniority_level,
      u.current_projects,
      JSON_EXTRACT_SCALAR(u.metadata, '$.decision_authority') as decision_authority,
      JSON_EXTRACT_SCALAR(u.metadata, '$.budget_range') as budget_range
    FROM `enterprise_knowledge_ai.users` u
    WHERE u.user_id = user_id
  ),
  recommendation_generation AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Generate ', recommendation_type, ' recommendations for: ',
          'User: ', up.seniority_level, ' in ', up.department, '. ',
          'Decision Authority: ', COALESCE(up.decision_authority, 'departmental'), '. ',
          'Budget Range: ', COALESCE(up.budget_range, 'standard'), '. ',
          'Current Projects: ', COALESCE(up.current_projects, 'none specified'), '. ',
          'Context: ', context_data, '. ',
          
          'Return exactly 5 specific, actionable recommendations as a JSON array of strings. ',
          'Each recommendation should be 1-2 sentences, specific to their role and authority level. ',
          'Format: ["recommendation 1", "recommendation 2", "recommendation 3", "recommendation 4", "recommendation 5"]'
        )
      ) as recommendations_json
    FROM user_profile up
  )
  SELECT 
    ARRAY(
      SELECT JSON_EXTRACT_SCALAR(recommendations_json, CONCAT('$[', CAST(i AS STRING), ']'))
      FROM UNNEST(GENERATE_ARRAY(0, 4)) as i
    )
  FROM recommendation_generation
);

-- Create personalized dashboard content
CREATE OR REPLACE PROCEDURE generate_personalized_dashboard(
  user_id STRING,
  dashboard_type STRING DEFAULT 'executive'  -- 'executive', 'analyst', 'manager'
)
BEGIN
  DECLARE user_dept STRING;
  DECLARE user_level STRING;
  
  SET (user_dept, user_level) = (
    SELECT AS STRUCT department, seniority_level
    FROM `enterprise_knowledge_ai.users`
    WHERE user_id = user_id
  );
  
  -- Generate personalized dashboard content
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.personalized_dashboard_${user_id}` AS
  WITH top_insights AS (
    SELECT 
      gi.insight_id,
      gi.content,
      gi.insight_type,
      gi.business_impact_score,
      calculate_content_priority(user_id, gi.insight_id) as priority_score
    FROM `enterprise_knowledge_ai.generated_insights` gi
    WHERE gi.created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
      AND (
        JSON_EXTRACT_SCALAR(gi.metadata, '$.department') = user_dept
        OR JSON_EXTRACT_SCALAR(gi.metadata, '$.department') IS NULL
      )
    ORDER BY priority_score DESC
    LIMIT 10
  ),
  personalized_content AS (
    SELECT 
      ti.insight_id,
      ti.insight_type,
      ti.priority_score,
      generate_personalized_insight(user_id, ti.insight_id, 'standard') as personalized_content,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Create a compelling dashboard title for this insight for a ', user_level, ': ',
          SUBSTR(ti.content, 1, 200), 
          '. Make it action-oriented and specific to their role. Max 10 words.'
        )
      ) as dashboard_title,
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Suggest 2-3 specific next actions for a ', user_level, ' in ', user_dept, 
          ' based on this insight: ', SUBSTR(ti.content, 1, 300),
          '. Return as comma-separated list.'
        )
      ) as suggested_actions
    FROM top_insights ti
  )
  SELECT 
    insight_id,
    insight_type,
    priority_score,
    dashboard_title,
    personalized_content,
    SPLIT(suggested_actions, ',') as action_items,
    CURRENT_TIMESTAMP() as generated_at
  FROM personalized_content
  ORDER BY priority_score DESC;
  
END;

-- Generate personalized alerts and notifications
CREATE OR REPLACE FUNCTION generate_personalized_alert(
  user_id STRING,
  alert_trigger STRING,
  severity_level STRING DEFAULT 'medium'  -- 'low', 'medium', 'high', 'critical'
)
RETURNS STRUCT<
  alert_message STRING,
  recommended_actions ARRAY<STRING>,
  urgency_score FLOAT64
>
LANGUAGE SQL
AS (
  WITH user_context AS (
    SELECT 
      u.department,
      u.seniority_level,
      u.notification_preferences,
      JSON_EXTRACT_SCALAR(u.metadata, '$.escalation_contacts') as escalation_contacts
    FROM `enterprise_knowledge_ai.users` u
    WHERE u.user_id = user_id
  ),
  alert_generation AS (
    SELECT 
      AI.GENERATE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Generate a personalized alert message for: ',
          'User: ', uc.seniority_level, ' in ', uc.department, '. ',
          'Alert Trigger: ', alert_trigger, '. ',
          'Severity: ', severity_level, '. ',
          'Notification Style: ', COALESCE(uc.notification_preferences, 'professional'), '. ',
          
          'Create a clear, actionable alert message appropriate for their role. ',
          'Include specific context and implications for their department. ',
          'Keep it concise but informative. Max 200 words.'
        )
      ) as alert_message,
      
      generate_personalized_recommendations(
        user_id, 
        CONCAT('Alert: ', alert_trigger, '. Severity: ', severity_level), 
        'tactical'
      ) as recommended_actions,
      
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate urgency (0.0-1.0) for ', uc.seniority_level, ' in ', uc.department, ': ',
          alert_trigger, '. Severity: ', severity_level, 
          '. Consider their role responsibilities and decision authority.'
        )
      ) as urgency_score
    FROM user_context uc
  )
  SELECT AS STRUCT
    ag.alert_message,
    ag.recommended_actions,
    ag.urgency_score
  FROM alert_generation ag
);