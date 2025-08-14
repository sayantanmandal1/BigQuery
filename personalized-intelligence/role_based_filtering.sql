-- Role-Based Filtering System for Personalized Intelligence
-- Implements intelligent content filtering based on user roles and organizational hierarchy

-- Create role-based access control function
CREATE OR REPLACE FUNCTION get_user_role_permissions(user_id STRING)
RETURNS ARRAY<STRING>
LANGUAGE SQL
AS (
  SELECT ARRAY_AGG(permission)
  FROM (
    SELECT DISTINCT permission
    FROM `enterprise_knowledge_ai.user_roles` ur
    JOIN `enterprise_knowledge_ai.role_permissions` rp ON ur.role_id = rp.role_id
    WHERE ur.user_id = user_id
      AND ur.is_active = TRUE
      AND rp.is_active = TRUE
  )
);

-- Role-based content filtering with AI-powered relevance scoring
CREATE OR REPLACE FUNCTION filter_content_by_role(
  user_id STRING,
  content_type STRING DEFAULT 'all'
)
RETURNS TABLE(
  knowledge_id STRING,
  content TEXT,
  relevance_score FLOAT64,
  access_level STRING
)
LANGUAGE SQL
AS (
  WITH user_context AS (
    SELECT 
      u.user_id,
      u.department,
      u.seniority_level,
      u.current_projects,
      ARRAY_TO_STRING(get_user_role_permissions(u.user_id), ',') as permissions
    FROM `enterprise_knowledge_ai.users` u
    WHERE u.user_id = user_id
  ),
  filtered_content AS (
    SELECT 
      kb.knowledge_id,
      kb.content,
      kb.content_type,
      kb.access_permissions,
      kb.metadata,
      uc.department,
      uc.seniority_level,
      uc.permissions
    FROM `enterprise_knowledge_ai.enterprise_knowledge_base` kb
    CROSS JOIN user_context uc
    WHERE (content_type = 'all' OR kb.content_type = content_type)
      AND EXISTS (
        SELECT 1 
        FROM UNNEST(kb.access_permissions) as perm
        WHERE perm IN UNNEST(SPLIT(uc.permissions, ','))
      )
  )
  SELECT 
    fc.knowledge_id,
    fc.content,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Rate the relevance of this content for a ', fc.seniority_level, 
        ' level employee in ', fc.department, ' department. ',
        'Content: ', SUBSTR(fc.content, 1, 500),
        '. Return a score between 0.0 and 1.0 where 1.0 is highly relevant.'
      )
    ) as relevance_score,
    CASE 
      WHEN fc.seniority_level IN ('executive', 'senior_manager') THEN 'full_access'
      WHEN fc.seniority_level = 'manager' THEN 'standard_access'
      ELSE 'limited_access'
    END as access_level
  FROM filtered_content fc
);

-- Department-specific content prioritization
CREATE OR REPLACE FUNCTION get_department_priorities(department STRING)
RETURNS ARRAY<STRING>
LANGUAGE SQL
AS (
  SELECT 
    CASE department
      WHEN 'finance' THEN ['financial_metrics', 'budget_analysis', 'risk_assessment', 'compliance']
      WHEN 'marketing' THEN ['customer_insights', 'campaign_performance', 'market_trends', 'brand_analysis']
      WHEN 'operations' THEN ['process_optimization', 'supply_chain', 'quality_metrics', 'efficiency']
      WHEN 'hr' THEN ['employee_engagement', 'talent_analytics', 'performance_reviews', 'culture']
      WHEN 'sales' THEN ['sales_performance', 'customer_relationships', 'pipeline_analysis', 'territory']
      WHEN 'product' THEN ['product_metrics', 'user_feedback', 'feature_analysis', 'roadmap']
      WHEN 'engineering' THEN ['technical_metrics', 'system_performance', 'code_quality', 'architecture']
      ELSE ['general_business', 'strategic_insights', 'market_intelligence']
    END as priorities
);

-- Advanced role-based filtering with contextual awareness
CREATE OR REPLACE PROCEDURE generate_personalized_content_feed(
  user_id STRING,
  max_items INT64 DEFAULT 20
)
BEGIN
  DECLARE user_dept STRING;
  DECLARE user_level STRING;
  
  -- Get user context
  SET (user_dept, user_level) = (
    SELECT AS STRUCT department, seniority_level
    FROM `enterprise_knowledge_ai.users`
    WHERE user_id = user_id
  );
  
  -- Create personalized content feed
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.personalized_feeds_${user_id}` AS
  WITH role_filtered_content AS (
    SELECT * FROM filter_content_by_role(user_id)
    WHERE relevance_score >= 0.6
  ),
  priority_scored_content AS (
    SELECT 
      rfc.*,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Given these department priorities: ', 
          ARRAY_TO_STRING(get_department_priorities(user_dept), ', '),
          ', rate the priority of this content: ',
          SUBSTR(rfc.content, 1, 300),
          '. Return a score between 0.0 and 1.0.'
        )
      ) as priority_score,
      CURRENT_TIMESTAMP() as generated_at
    FROM role_filtered_content rfc
  )
  SELECT 
    knowledge_id,
    content,
    relevance_score,
    priority_score,
    (relevance_score * 0.6 + priority_score * 0.4) as combined_score,
    access_level,
    generated_at
  FROM priority_scored_content
  ORDER BY combined_score DESC
  LIMIT max_items;
  
END;

-- Role hierarchy management for escalation and delegation
CREATE OR REPLACE FUNCTION can_access_content(
  user_id STRING,
  content_id STRING,
  required_clearance_level INT64
)
RETURNS BOOL
LANGUAGE SQL
AS (
  WITH user_clearance AS (
    SELECT 
      CASE u.seniority_level
        WHEN 'executive' THEN 5
        WHEN 'senior_manager' THEN 4
        WHEN 'manager' THEN 3
        WHEN 'senior_analyst' THEN 2
        ELSE 1
      END as clearance_level
    FROM `enterprise_knowledge_ai.users` u
    WHERE u.user_id = user_id
  )
  SELECT clearance_level >= required_clearance_level
  FROM user_clearance
);