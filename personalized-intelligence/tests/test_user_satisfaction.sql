-- Test Suite for User Satisfaction Metrics
-- Measures and validates user satisfaction with personalized intelligence features

-- Create user satisfaction tracking table
CREATE OR REPLACE TABLE `enterprise_knowledge_ai.user_satisfaction_metrics` (
  metric_id STRING NOT NULL,
  user_id STRING,
  metric_type STRING, -- 'relevance', 'timeliness', 'actionability', 'overall'
  metric_value FLOAT64,
  measurement_timestamp TIMESTAMP,
  context_metadata JSON
);

-- Test setup: Create satisfaction measurement framework
CREATE OR REPLACE PROCEDURE setup_satisfaction_tests()
BEGIN
  -- Create test users with varied profiles for satisfaction testing
  INSERT INTO `enterprise_knowledge_ai.users` (user_id, department, seniority_level, current_projects, communication_style, metadata)
  VALUES 
    ('sat_user_001', 'finance', 'executive', 'quarterly_planning,cost_optimization', 'concise', 
     JSON '{"satisfaction_history": [], "feedback_frequency": "high", "engagement_level": "active"}'),
    ('sat_user_002', 'marketing', 'manager', 'campaign_analysis,customer_segmentation', 'detailed', 
     JSON '{"satisfaction_history": [], "feedback_frequency": "medium", "engagement_level": "moderate"}'),
    ('sat_user_003', 'operations', 'analyst', 'process_analysis,quality_control', 'technical', 
     JSON '{"satisfaction_history": [], "feedback_frequency": "low", "engagement_level": "passive"}'
    );
  
  -- Create diverse test insights for satisfaction measurement
  INSERT INTO `enterprise_knowledge_ai.generated_insights` (insight_id, content, insight_type, confidence_score, business_impact_score, metadata, created_timestamp)
  VALUES 
    ('sat_insight_001', 'Cost reduction opportunities identified in procurement processes could save $2.3M annually', 'prescriptive', 0.89, 85, 
     JSON '{"topic": "cost_optimization", "department": "finance", "urgency": "high", "actionability": "high"}', CURRENT_TIMESTAMP()),
    ('sat_insight_002', 'Customer lifetime value analysis reveals 34% increase potential through retention programs', 'predictive', 0.82, 72, 
     JSON '{"topic": "customer_analytics", "department": "marketing", "urgency": "medium", "actionability": "medium"}', CURRENT_TIMESTAMP()),
    ('sat_insight_003', 'Quality metrics show declining trend in production line 3, requiring immediate attention', 'descriptive', 0.95, 78, 
     JSON '{"topic": "quality_control", "department": "operations", "urgency": "high", "actionability": "high"}', CURRENT_TIMESTAMP());
     
END;

-- Test 1: Relevance satisfaction measurement
CREATE OR REPLACE PROCEDURE test_relevance_satisfaction()
BEGIN
  DECLARE avg_relevance_score FLOAT64;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Generate personalized content for test users
  CALL generate_personalized_content_feed('sat_user_001', 10);
  CALL generate_personalized_content_feed('sat_user_002', 10);
  CALL generate_personalized_content_feed('sat_user_003', 10);
  
  -- Measure relevance satisfaction using AI evaluation
  WITH relevance_evaluation AS (
    SELECT 
      user_id,
      insight_id,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate content relevance satisfaction (0.0-1.0) for user profile: ',
          (SELECT CONCAT(seniority_level, ' in ', department) FROM `enterprise_knowledge_ai.users` WHERE user_id = pf.user_id),
          '. Content: ', SUBSTR(pf.content, 1, 300),
          '. Consider role alignment, topic relevance, and actionability.'
        )
      ) as relevance_satisfaction
    FROM `enterprise_knowledge_ai.personalized_feeds_sat_user_001` pf
    WHERE pf.user_id = 'sat_user_001'
    
    UNION ALL
    
    SELECT 
      'sat_user_002' as user_id,
      insight_id,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate content relevance satisfaction (0.0-1.0) for marketing manager. ',
          'Content: ', SUBSTR(content, 1, 300),
          '. Consider role alignment, topic relevance, and actionability.'
        )
      ) as relevance_satisfaction
    FROM `enterprise_knowledge_ai.personalized_feeds_sat_user_002`
    
    UNION ALL
    
    SELECT 
      'sat_user_003' as user_id,
      insight_id,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate content relevance satisfaction (0.0-1.0) for operations analyst. ',
          'Content: ', SUBSTR(content, 1, 300),
          '. Consider role alignment, topic relevance, and actionability.'
        )
      ) as relevance_satisfaction
    FROM `enterprise_knowledge_ai.personalized_feeds_sat_user_003`
  )
  INSERT INTO `enterprise_knowledge_ai.user_satisfaction_metrics` 
    (metric_id, user_id, metric_type, metric_value, measurement_timestamp, context_metadata)
  SELECT 
    GENERATE_UUID() as metric_id,
    user_id,
    'relevance' as metric_type,
    relevance_satisfaction as metric_value,
    CURRENT_TIMESTAMP() as measurement_timestamp,
    JSON_OBJECT('insight_id', insight_id, 'test_type', 'automated_relevance') as context_metadata
  FROM relevance_evaluation;
  
  -- Calculate average relevance satisfaction
  SET avg_relevance_score = (
    SELECT AVG(metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE metric_type = 'relevance'
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  );
  
  -- Test 1: Average relevance should be above 0.7
  SET total_tests = total_tests + 1;
  IF avg_relevance_score >= 0.7 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: No user should have average relevance below 0.5
  SET total_tests = total_tests + 1;
  IF NOT EXISTS (
    SELECT 1 
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE metric_type = 'relevance'
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    GROUP BY user_id
    HAVING AVG(metric_value) < 0.5
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp, additional_metrics)
  VALUES ('relevance_satisfaction', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP(), 
          JSON_OBJECT('avg_relevance_score', avg_relevance_score));
  
  SELECT CONCAT('Relevance satisfaction test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed. Avg score: ', CAST(ROUND(avg_relevance_score, 3) AS STRING)) as result;
  
END;

-- Test 2: Timeliness satisfaction measurement
CREATE OR REPLACE PROCEDURE test_timeliness_satisfaction()
BEGIN
  DECLARE avg_timeliness_score FLOAT64;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Measure timeliness satisfaction based on content freshness and urgency alignment
  WITH timeliness_evaluation AS (
    SELECT 
      gi.insight_id,
      'sat_user_001' as user_id,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate timeliness satisfaction (0.0-1.0) for executive user. ',
          'Content age: ', CAST(TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), gi.created_timestamp, HOUR) AS STRING), ' hours. ',
          'Urgency level: ', JSON_EXTRACT_SCALAR(gi.metadata, '$.urgency'), '. ',
          'Content: ', SUBSTR(gi.content, 1, 200),
          '. Consider if timing aligns with user needs and urgency.'
        )
      ) as timeliness_satisfaction
    FROM `enterprise_knowledge_ai.generated_insights` gi
    WHERE gi.insight_id IN (
      SELECT insight_id FROM `enterprise_knowledge_ai.personalized_feeds_sat_user_001`
    )
  )
  INSERT INTO `enterprise_knowledge_ai.user_satisfaction_metrics` 
    (metric_id, user_id, metric_type, metric_value, measurement_timestamp, context_metadata)
  SELECT 
    GENERATE_UUID() as metric_id,
    user_id,
    'timeliness' as metric_type,
    timeliness_satisfaction as metric_value,
    CURRENT_TIMESTAMP() as measurement_timestamp,
    JSON_OBJECT('insight_id', insight_id, 'test_type', 'automated_timeliness') as context_metadata
  FROM timeliness_evaluation;
  
  -- Calculate average timeliness satisfaction
  SET avg_timeliness_score = (
    SELECT AVG(metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE metric_type = 'timeliness'
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  );
  
  -- Test 1: Average timeliness should be above 0.6
  SET total_tests = total_tests + 1;
  IF avg_timeliness_score >= 0.6 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: High urgency items should have higher timeliness scores
  SET total_tests = total_tests + 1;
  IF (
    SELECT AVG(usm.metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics` usm
    JOIN `enterprise_knowledge_ai.generated_insights` gi 
      ON JSON_EXTRACT_SCALAR(usm.context_metadata, '$.insight_id') = gi.insight_id
    WHERE usm.metric_type = 'timeliness'
      AND JSON_EXTRACT_SCALAR(gi.metadata, '$.urgency') = 'high'
  ) > (
    SELECT AVG(usm.metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics` usm
    JOIN `enterprise_knowledge_ai.generated_insights` gi 
      ON JSON_EXTRACT_SCALAR(usm.context_metadata, '$.insight_id') = gi.insight_id
    WHERE usm.metric_type = 'timeliness'
      AND JSON_EXTRACT_SCALAR(gi.metadata, '$.urgency') = 'medium'
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp, additional_metrics)
  VALUES ('timeliness_satisfaction', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP(), 
          JSON_OBJECT('avg_timeliness_score', avg_timeliness_score));
  
  SELECT CONCAT('Timeliness satisfaction test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed. Avg score: ', CAST(ROUND(avg_timeliness_score, 3) AS STRING)) as result;
  
END;

-- Test 3: Actionability satisfaction measurement
CREATE OR REPLACE PROCEDURE test_actionability_satisfaction()
BEGIN
  DECLARE avg_actionability_score FLOAT64;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Generate personalized recommendations for test users
  CREATE TEMP TABLE actionability_test AS
  SELECT 
    'sat_user_001' as user_id,
    'sat_insight_001' as insight_id,
    generate_personalized_recommendations(
      'sat_user_001', 
      'Cost reduction opportunities in procurement', 
      'strategic'
    ) as recommendations
  UNION ALL
  SELECT 
    'sat_user_002' as user_id,
    'sat_insight_002' as insight_id,
    generate_personalized_recommendations(
      'sat_user_002', 
      'Customer lifetime value optimization', 
      'tactical'
    ) as recommendations;
  
  -- Measure actionability satisfaction
  WITH actionability_evaluation AS (
    SELECT 
      user_id,
      insight_id,
      AI.GENERATE_DOUBLE(
        MODEL `enterprise_knowledge_ai.gemini_model`,
        CONCAT(
          'Rate actionability satisfaction (0.0-1.0) for recommendations: ',
          ARRAY_TO_STRING(recommendations, '; '), '. ',
          'User: ', (SELECT CONCAT(seniority_level, ' in ', department) 
                    FROM `enterprise_knowledge_ai.users` WHERE user_id = at.user_id), '. ',
          'Consider specificity, feasibility, and clarity of actions.'
        )
      ) as actionability_satisfaction
    FROM actionability_test at
  )
  INSERT INTO `enterprise_knowledge_ai.user_satisfaction_metrics` 
    (metric_id, user_id, metric_type, metric_value, measurement_timestamp, context_metadata)
  SELECT 
    GENERATE_UUID() as metric_id,
    user_id,
    'actionability' as metric_type,
    actionability_satisfaction as metric_value,
    CURRENT_TIMESTAMP() as measurement_timestamp,
    JSON_OBJECT('insight_id', insight_id, 'test_type', 'automated_actionability') as context_metadata
  FROM actionability_evaluation;
  
  -- Calculate average actionability satisfaction
  SET avg_actionability_score = (
    SELECT AVG(metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE metric_type = 'actionability'
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  );
  
  -- Test 1: Average actionability should be above 0.7
  SET total_tests = total_tests + 1;
  IF avg_actionability_score >= 0.7 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: Executive users should have higher actionability scores (more strategic recommendations)
  SET total_tests = total_tests + 1;
  IF (
    SELECT AVG(metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics` usm
    JOIN `enterprise_knowledge_ai.users` u ON usm.user_id = u.user_id
    WHERE usm.metric_type = 'actionability'
      AND u.seniority_level = 'executive'
  ) >= 0.75 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp, additional_metrics)
  VALUES ('actionability_satisfaction', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP(), 
          JSON_OBJECT('avg_actionability_score', avg_actionability_score));
  
  SELECT CONCAT('Actionability satisfaction test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed. Avg score: ', CAST(ROUND(avg_actionability_score, 3) AS STRING)) as result;
  
END;

-- Test 4: Overall user satisfaction measurement
CREATE OR REPLACE PROCEDURE test_overall_satisfaction()
BEGIN
  DECLARE overall_satisfaction FLOAT64;
  DECLARE satisfaction_variance FLOAT64;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Calculate overall satisfaction as weighted average of component metrics
  WITH component_scores AS (
    SELECT 
      user_id,
      AVG(CASE WHEN metric_type = 'relevance' THEN metric_value END) as relevance_score,
      AVG(CASE WHEN metric_type = 'timeliness' THEN metric_value END) as timeliness_score,
      AVG(CASE WHEN metric_type = 'actionability' THEN metric_value END) as actionability_score
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
    GROUP BY user_id
  ),
  overall_scores AS (
    SELECT 
      user_id,
      (relevance_score * 0.4 + timeliness_score * 0.3 + actionability_score * 0.3) as overall_score
    FROM component_scores
    WHERE relevance_score IS NOT NULL 
      AND timeliness_score IS NOT NULL 
      AND actionability_score IS NOT NULL
  )
  INSERT INTO `enterprise_knowledge_ai.user_satisfaction_metrics` 
    (metric_id, user_id, metric_type, metric_value, measurement_timestamp, context_metadata)
  SELECT 
    GENERATE_UUID() as metric_id,
    user_id,
    'overall' as metric_type,
    overall_score as metric_value,
    CURRENT_TIMESTAMP() as measurement_timestamp,
    JSON_OBJECT('test_type', 'calculated_overall', 'components', 'relevance,timeliness,actionability') as context_metadata
  FROM overall_scores;
  
  -- Calculate system-wide satisfaction metrics
  SET (overall_satisfaction, satisfaction_variance) = (
    SELECT AS STRUCT AVG(metric_value), VARIANCE(metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE metric_type = 'overall'
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  );
  
  -- Test 1: Overall satisfaction should be above 0.7
  SET total_tests = total_tests + 1;
  IF overall_satisfaction >= 0.7 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: Satisfaction variance should be low (consistent experience)
  SET total_tests = total_tests + 1;
  IF satisfaction_variance <= 0.05 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 3: No user should have overall satisfaction below 0.5
  SET total_tests = total_tests + 1;
  IF NOT EXISTS (
    SELECT 1 
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE metric_type = 'overall'
      AND metric_value < 0.5
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp, additional_metrics)
  VALUES ('overall_satisfaction', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP(), 
          JSON_OBJECT('overall_satisfaction', overall_satisfaction, 'satisfaction_variance', satisfaction_variance));
  
  SELECT CONCAT('Overall satisfaction test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed. Overall score: ', CAST(ROUND(overall_satisfaction, 3) AS STRING)) as result;
  
END;

-- Test 5: User engagement and retention metrics
CREATE OR REPLACE PROCEDURE test_engagement_metrics()
BEGIN
  DECLARE avg_engagement_score FLOAT64;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Simulate user interactions for engagement measurement
  INSERT INTO `enterprise_knowledge_ai.user_interactions` (interaction_id, user_id, insight_id, interaction_type, feedback_score, interaction_timestamp, context_metadata)
  VALUES 
    (GENERATE_UUID(), 'sat_user_001', 'sat_insight_001', 'act_upon', 5, CURRENT_TIMESTAMP(), JSON '{"test_interaction": true}'),
    (GENERATE_UUID(), 'sat_user_001', 'sat_insight_001', 'share', 4, CURRENT_TIMESTAMP(), JSON '{"test_interaction": true}'),
    (GENERATE_UUID(), 'sat_user_002', 'sat_insight_002', 'view', 4, CURRENT_TIMESTAMP(), JSON '{"test_interaction": true}'),
    (GENERATE_UUID(), 'sat_user_002', 'sat_insight_002', 'act_upon', 5, CURRENT_TIMESTAMP(), JSON '{"test_interaction": true}'),
    (GENERATE_UUID(), 'sat_user_003', 'sat_insight_003', 'view', 3, CURRENT_TIMESTAMP(), JSON '{"test_interaction": true}');
  
  -- Calculate engagement metrics
  WITH engagement_analysis AS (
    SELECT 
      user_id,
      COUNT(*) as interaction_count,
      AVG(feedback_score) as avg_feedback,
      COUNT(CASE WHEN interaction_type = 'act_upon' THEN 1 END) / COUNT(*) as action_rate,
      COUNT(CASE WHEN interaction_type = 'share' THEN 1 END) / COUNT(*) as share_rate
    FROM `enterprise_knowledge_ai.user_interactions`
    WHERE JSON_EXTRACT_SCALAR(context_metadata, '$.test_interaction') = 'true'
    GROUP BY user_id
  ),
  engagement_scores AS (
    SELECT 
      user_id,
      (avg_feedback / 5.0 * 0.4 + action_rate * 0.4 + share_rate * 0.2) as engagement_score
    FROM engagement_analysis
  )
  INSERT INTO `enterprise_knowledge_ai.user_satisfaction_metrics` 
    (metric_id, user_id, metric_type, metric_value, measurement_timestamp, context_metadata)
  SELECT 
    GENERATE_UUID() as metric_id,
    user_id,
    'engagement' as metric_type,
    engagement_score as metric_value,
    CURRENT_TIMESTAMP() as measurement_timestamp,
    JSON_OBJECT('test_type', 'calculated_engagement') as context_metadata
  FROM engagement_scores;
  
  -- Calculate average engagement
  SET avg_engagement_score = (
    SELECT AVG(metric_value)
    FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
    WHERE metric_type = 'engagement'
      AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  );
  
  -- Test 1: Average engagement should be above 0.6
  SET total_tests = total_tests + 1;
  IF avg_engagement_score >= 0.6 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: Users with higher satisfaction should have higher engagement
  SET total_tests = total_tests + 1;
  IF EXISTS (
    SELECT 1
    FROM (
      SELECT 
        os.user_id,
        os.metric_value as overall_satisfaction,
        es.metric_value as engagement_score
      FROM `enterprise_knowledge_ai.user_satisfaction_metrics` os
      JOIN `enterprise_knowledge_ai.user_satisfaction_metrics` es ON os.user_id = es.user_id
      WHERE os.metric_type = 'overall' AND es.metric_type = 'engagement'
        AND os.measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 HOUR)
        AND es.measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    )
    WHERE overall_satisfaction > 0.7 AND engagement_score > 0.6
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp, additional_metrics)
  VALUES ('engagement_metrics', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP(), 
          JSON_OBJECT('avg_engagement_score', avg_engagement_score));
  
  SELECT CONCAT('Engagement metrics test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed. Avg engagement: ', CAST(ROUND(avg_engagement_score, 3) AS STRING)) as result;
  
END;

-- Cleanup satisfaction test data
CREATE OR REPLACE PROCEDURE cleanup_satisfaction_tests()
BEGIN
  DELETE FROM `enterprise_knowledge_ai.users` WHERE user_id LIKE 'sat_user_%';
  DELETE FROM `enterprise_knowledge_ai.generated_insights` WHERE insight_id LIKE 'sat_insight_%';
  DELETE FROM `enterprise_knowledge_ai.user_interactions` WHERE JSON_EXTRACT_SCALAR(context_metadata, '$.test_interaction') = 'true';
  DELETE FROM `enterprise_knowledge_ai.user_satisfaction_metrics` WHERE JSON_EXTRACT_SCALAR(context_metadata, '$.test_type') LIKE 'automated_%';
  
  -- Drop test-specific tables
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.personalized_feeds_sat_user_001`;
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.personalized_feeds_sat_user_002`;
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.personalized_feeds_sat_user_003`;
  
END;