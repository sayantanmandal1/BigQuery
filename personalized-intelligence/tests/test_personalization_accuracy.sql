-- Test Suite for Personalization Accuracy
-- Validates the accuracy and effectiveness of personalized intelligence features

-- Test setup: Create test users and sample data
CREATE OR REPLACE PROCEDURE setup_personalization_tests()
BEGIN
  -- Create test users with different profiles
  INSERT INTO `enterprise_knowledge_ai.users` (user_id, department, seniority_level, current_projects, communication_style, metadata)
  VALUES 
    ('test_exec_001', 'finance', 'executive', 'budget_planning,risk_assessment', 'concise', 
     JSON '{"expertise_areas": "financial_analysis,strategic_planning", "preferred_detail_level": "high_level", "key_metrics": "revenue,profit_margin,roi"}'),
    ('test_manager_001', 'marketing', 'manager', 'campaign_optimization,brand_analysis', 'detailed', 
     JSON '{"expertise_areas": "digital_marketing,analytics", "preferred_detail_level": "detailed", "key_metrics": "conversion_rate,customer_acquisition_cost"}'),
    ('test_analyst_001', 'operations', 'senior_analyst', 'process_improvement,efficiency_analysis', 'technical', 
     JSON '{"expertise_areas": "operations_research,data_analysis", "preferred_detail_level": "very_detailed", "key_metrics": "efficiency,throughput,quality"}'
    );
  
  -- Create test insights
  INSERT INTO `enterprise_knowledge_ai.generated_insights` (insight_id, content, insight_type, confidence_score, business_impact_score, metadata)
  VALUES 
    ('test_insight_001', 'Q4 revenue projections show 15% growth potential with increased marketing spend in digital channels', 'predictive', 0.85, 78, 
     JSON '{"topic": "revenue_forecasting", "department": "finance", "urgency": "medium"}'),
    ('test_insight_002', 'Customer acquisition costs have increased 23% due to iOS privacy changes affecting ad targeting', 'descriptive', 0.92, 65, 
     JSON '{"topic": "marketing_efficiency", "department": "marketing", "urgency": "high"}'),
    ('test_insight_003', 'Production line efficiency can be improved by 12% through predictive maintenance scheduling', 'prescriptive', 0.78, 82, 
     JSON '{"topic": "operational_efficiency", "department": "operations", "urgency": "medium"}'
    );
  
  -- Create test interactions
  INSERT INTO `enterprise_knowledge_ai.user_interactions` (interaction_id, user_id, insight_id, interaction_type, feedback_score, interaction_timestamp)
  VALUES 
    ('int_001', 'test_exec_001', 'test_insight_001', 'act_upon', 5, TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)),
    ('int_002', 'test_manager_001', 'test_insight_002', 'share', 4, TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)),
    ('int_003', 'test_analyst_001', 'test_insight_003', 'view', 4, TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY));
    
END;

-- Test 1: Role-based filtering accuracy
CREATE OR REPLACE PROCEDURE test_role_based_filtering()
BEGIN
  DECLARE test_results STRING;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Test executive access to high-level content
  SET total_tests = total_tests + 1;
  IF EXISTS (
    SELECT 1 FROM filter_content_by_role('test_exec_001')
    WHERE knowledge_id = 'test_insight_001' AND relevance_score >= 0.7
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test manager access to department-specific content
  SET total_tests = total_tests + 1;
  IF EXISTS (
    SELECT 1 FROM filter_content_by_role('test_manager_001')
    WHERE knowledge_id = 'test_insight_002' AND relevance_score >= 0.6
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test analyst access to technical content
  SET total_tests = total_tests + 1;
  IF EXISTS (
    SELECT 1 FROM filter_content_by_role('test_analyst_001')
    WHERE knowledge_id = 'test_insight_003' AND relevance_score >= 0.6
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp)
  VALUES ('role_based_filtering', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP());
  
  SELECT CONCAT('Role-based filtering test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed') as result;
  
END;

-- Test 2: Preference learning accuracy
CREATE OR REPLACE PROCEDURE test_preference_learning()
BEGIN
  DECLARE test_results STRING;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Train preferences for test users
  CALL train_user_preference_model('test_exec_001');
  CALL train_user_preference_model('test_manager_001');
  CALL train_user_preference_model('test_analyst_001');
  
  -- Test 1: Executive should have high preference for financial topics
  SET total_tests = total_tests + 1;
  IF (
    SELECT preference_score 
    FROM `enterprise_knowledge_ai.user_preferences_test_exec_001`
    WHERE preference_key = 'revenue_forecasting' AND preference_type = 'topic'
  ) >= 0.7 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: Marketing manager should prefer marketing content
  SET total_tests = total_tests + 1;
  IF (
    SELECT preference_score 
    FROM `enterprise_knowledge_ai.user_preferences_test_manager_001`
    WHERE preference_key = 'marketing_efficiency' AND preference_type = 'topic'
  ) >= 0.6 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 3: Analyst should prefer operational content
  SET total_tests = total_tests + 1;
  IF (
    SELECT preference_score 
    FROM `enterprise_knowledge_ai.user_preferences_test_analyst_001`
    WHERE preference_key = 'operational_efficiency' AND preference_type = 'topic'
  ) >= 0.6 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp)
  VALUES ('preference_learning', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP());
  
  SELECT CONCAT('Preference learning test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed') as result;
  
END;

-- Test 3: Priority scoring accuracy
CREATE OR REPLACE PROCEDURE test_priority_scoring()
BEGIN
  DECLARE exec_priority FLOAT64;
  DECLARE manager_priority FLOAT64;
  DECLARE analyst_priority FLOAT64;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Calculate priorities for different users on same content
  SET exec_priority = calculate_content_priority('test_exec_001', 'test_insight_001');
  SET manager_priority = calculate_content_priority('test_manager_001', 'test_insight_001');
  SET analyst_priority = calculate_content_priority('test_analyst_001', 'test_insight_001');
  
  -- Test 1: Executive should have highest priority for financial insight
  SET total_tests = total_tests + 1;
  IF exec_priority > manager_priority AND exec_priority > analyst_priority THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: Marketing insight should be highest priority for marketing manager
  SET total_tests = total_tests + 1;
  IF calculate_content_priority('test_manager_001', 'test_insight_002') > 
     calculate_content_priority('test_exec_001', 'test_insight_002') THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 3: Operational insight should be highest priority for operations analyst
  SET total_tests = total_tests + 1;
  IF calculate_content_priority('test_analyst_001', 'test_insight_003') > 
     calculate_content_priority('test_manager_001', 'test_insight_003') THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 4: Priority scores should be within valid range (0.0-1.0)
  SET total_tests = total_tests + 1;
  IF exec_priority BETWEEN 0.0 AND 1.0 AND 
     manager_priority BETWEEN 0.0 AND 1.0 AND 
     analyst_priority BETWEEN 0.0 AND 1.0 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp)
  VALUES ('priority_scoring', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP());
  
  SELECT CONCAT('Priority scoring test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed') as result;
  
END;

-- Test 4: Personalized content generation quality
CREATE OR REPLACE PROCEDURE test_personalized_content_generation()
BEGIN
  DECLARE exec_content STRING;
  DECLARE manager_content STRING;
  DECLARE analyst_content STRING;
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Generate personalized content for different users
  SET exec_content = generate_personalized_insight('test_exec_001', 'test_insight_001', 'standard');
  SET manager_content = generate_personalized_insight('test_manager_001', 'test_insight_002', 'standard');
  SET analyst_content = generate_personalized_insight('test_analyst_001', 'test_insight_003', 'standard');
  
  -- Test 1: Content should be generated (not null/empty)
  SET total_tests = total_tests + 1;
  IF exec_content IS NOT NULL AND LENGTH(exec_content) > 50 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  SET total_tests = total_tests + 1;
  IF manager_content IS NOT NULL AND LENGTH(manager_content) > 50 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  SET total_tests = total_tests + 1;
  IF analyst_content IS NOT NULL AND LENGTH(analyst_content) > 50 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: Content should be different for different users (personalization working)
  SET total_tests = total_tests + 1;
  IF exec_content != manager_content AND manager_content != analyst_content THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 3: Executive content should contain role-appropriate language
  SET total_tests = total_tests + 1;
  IF (REGEXP_CONTAINS(LOWER(exec_content), r'strategic|executive|leadership|decision') OR
      REGEXP_CONTAINS(LOWER(exec_content), r'revenue|profit|roi|growth')) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp)
  VALUES ('personalized_content_generation', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP());
  
  SELECT CONCAT('Personalized content generation test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed') as result;
  
END;

-- Test 5: End-to-end personalization workflow
CREATE OR REPLACE PROCEDURE test_end_to_end_personalization()
BEGIN
  DECLARE pass_count INT64 DEFAULT 0;
  DECLARE total_tests INT64 DEFAULT 0;
  
  -- Test complete personalization workflow for executive user
  CALL generate_personalized_content_feed('test_exec_001', 5);
  CALL generate_personalized_dashboard('test_exec_001', 'executive');
  
  -- Test 1: Personalized feed should be generated
  SET total_tests = total_tests + 1;
  IF EXISTS (
    SELECT 1 FROM `enterprise_knowledge_ai.personalized_feeds_test_exec_001`
    WHERE combined_score > 0
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 2: Dashboard should be generated with appropriate content
  SET total_tests = total_tests + 1;
  IF EXISTS (
    SELECT 1 FROM `enterprise_knowledge_ai.personalized_dashboard_test_exec_001`
    WHERE priority_score > 0 AND dashboard_title IS NOT NULL
  ) THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Test 3: Content should be prioritized correctly
  SET total_tests = total_tests + 1;
  IF (
    SELECT COUNT(*) 
    FROM `enterprise_knowledge_ai.personalized_feeds_test_exec_001`
    WHERE combined_score >= 0.6
  ) > 0 THEN
    SET pass_count = pass_count + 1;
  END IF;
  
  -- Record test results
  INSERT INTO `enterprise_knowledge_ai.test_results` (test_name, pass_count, total_tests, success_rate, test_timestamp)
  VALUES ('end_to_end_personalization', pass_count, total_tests, pass_count / total_tests, CURRENT_TIMESTAMP());
  
  SELECT CONCAT('End-to-end personalization test: ', CAST(pass_count AS STRING), '/', CAST(total_tests AS STRING), ' passed') as result;
  
END;

-- Cleanup test data
CREATE OR REPLACE PROCEDURE cleanup_personalization_tests()
BEGIN
  DELETE FROM `enterprise_knowledge_ai.users` WHERE user_id LIKE 'test_%';
  DELETE FROM `enterprise_knowledge_ai.generated_insights` WHERE insight_id LIKE 'test_%';
  DELETE FROM `enterprise_knowledge_ai.user_interactions` WHERE interaction_id LIKE 'int_%';
  
  -- Drop test-specific tables
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.personalized_feeds_test_exec_001`;
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.personalized_dashboard_test_exec_001`;
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.user_preferences_test_exec_001`;
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.user_preferences_test_manager_001`;
  DROP TABLE IF EXISTS `enterprise_knowledge_ai.user_preferences_test_analyst_001`;
  
END;