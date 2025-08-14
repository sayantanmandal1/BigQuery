-- Deployment Script for Personalized Intelligence Engine
-- Deploys all components of the personalized intelligence system

-- Create deployment log table
CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.deployment_log` (
  deployment_id STRING NOT NULL,
  component_name STRING,
  deployment_status STRING, -- 'started', 'completed', 'failed'
  deployment_timestamp TIMESTAMP,
  error_message STRING,
  deployment_metadata JSON
);

-- Main deployment procedure
CREATE OR REPLACE PROCEDURE deploy_personalized_intelligence_engine()
BEGIN
  DECLARE deployment_id STRING DEFAULT GENERATE_UUID();
  DECLARE start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP();
  
  -- Log deployment start
  INSERT INTO `enterprise_knowledge_ai.deployment_log` 
    (deployment_id, component_name, deployment_status, deployment_timestamp, deployment_metadata)
  VALUES (deployment_id, 'personalized_intelligence_engine', 'started', start_time, 
          JSON_OBJECT('version', '1.0', 'deployer', 'automated_system'));
  
  SELECT CONCAT('Starting deployment of Personalized Intelligence Engine (ID: ', deployment_id, ')') as status;
  
  -- Step 1: Create required tables and schemas
  BEGIN
    SELECT 'Creating core tables and schemas...' as status;
    
    -- User priority weights table
    CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.user_priority_weights` (
      user_id STRING NOT NULL,
      business_impact_weight FLOAT64 DEFAULT 0.4,
      time_sensitivity_weight FLOAT64 DEFAULT 0.3,
      personal_relevance_weight FLOAT64 DEFAULT 0.3,
      last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
      metadata JSON
    );
    
    -- User preference profiles (template - actual tables created per user)
    CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.user_preference_template` (
      user_id STRING NOT NULL,
      preference_type STRING, -- 'topic', 'content_type', 'temporal'
      preference_key STRING,
      preference_score FLOAT64,
      confidence FLOAT64,
      interaction_count INT64,
      last_updated TIMESTAMP
    );
    
    -- Personalized content feeds (template - actual tables created per user)
    CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.personalized_feed_template` (
      knowledge_id STRING,
      content TEXT,
      relevance_score FLOAT64,
      priority_score FLOAT64,
      combined_score FLOAT64,
      access_level STRING,
      generated_at TIMESTAMP
    );
    
    -- Personalized dashboards (template - actual tables created per user)
    CREATE TABLE IF NOT EXISTS `enterprise_knowledge_ai.personalized_dashboard_template` (
      insight_id STRING,
      insight_type STRING,
      priority_score FLOAT64,
      dashboard_title STRING,
      personalized_content TEXT,
      action_items ARRAY<STRING>,
      generated_at TIMESTAMP
    );
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'core_tables', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'core_tables', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Failed to create core tables: ', @@error.message);
  END;
  
  -- Step 2: Deploy role-based filtering functions
  BEGIN
    SELECT 'Deploying role-based filtering system...' as status;
    
    -- Functions are already created in role_based_filtering.sql
    -- Verify they exist and are accessible
    IF NOT EXISTS (
      SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
      WHERE routine_name = 'get_user_role_permissions'
    ) THEN
      RAISE USING MESSAGE = 'Role-based filtering functions not found. Please run role_based_filtering.sql first.';
    END IF;
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'role_based_filtering', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'role_based_filtering', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Failed to deploy role-based filtering: ', @@error.message);
  END;
  
  -- Step 3: Deploy preference learning system
  BEGIN
    SELECT 'Deploying preference learning system...' as status;
    
    -- Verify preference learning functions exist
    IF NOT EXISTS (
      SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
      WHERE routine_name = 'train_user_preference_model'
    ) THEN
      RAISE USING MESSAGE = 'Preference learning functions not found. Please run preference_learning.sql first.';
    END IF;
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'preference_learning', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'preference_learning', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Failed to deploy preference learning: ', @@error.message);
  END;
  
  -- Step 4: Deploy priority scoring system
  BEGIN
    SELECT 'Deploying priority scoring system...' as status;
    
    -- Verify priority scoring functions exist
    IF NOT EXISTS (
      SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
      WHERE routine_name = 'calculate_content_priority'
    ) THEN
      RAISE USING MESSAGE = 'Priority scoring functions not found. Please run priority_scoring.sql first.';
    END IF;
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'priority_scoring', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'priority_scoring', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Failed to deploy priority scoring: ', @@error.message);
  END;
  
  -- Step 5: Deploy personalized content generation
  BEGIN
    SELECT 'Deploying personalized content generation system...' as status;
    
    -- Verify content generation functions exist
    IF NOT EXISTS (
      SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
      WHERE routine_name = 'generate_personalized_insight'
    ) THEN
      RAISE USING MESSAGE = 'Content generation functions not found. Please run personalized_content_generation.sql first.';
    END IF;
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'content_generation', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'content_generation', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Failed to deploy content generation: ', @@error.message);
  END;
  
  -- Step 6: Create automated maintenance procedures
  BEGIN
    SELECT 'Setting up automated maintenance procedures...' as status;
    
    -- Daily preference model retraining
    CREATE OR REPLACE PROCEDURE automated_preference_maintenance()
    BEGIN
      DECLARE user_cursor CURSOR FOR 
        SELECT DISTINCT user_id 
        FROM `enterprise_knowledge_ai.user_interactions`
        WHERE interaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY);
      
      FOR user_record IN user_cursor DO
        CALL train_user_preference_model(user_record.user_id);
        CALL adjust_priorities_based_on_behavior(user_record.user_id);
      END FOR;
      
      INSERT INTO `enterprise_knowledge_ai.deployment_log` 
        (deployment_id, component_name, deployment_status, deployment_timestamp, deployment_metadata)
      VALUES (GENERATE_UUID(), 'automated_maintenance', 'completed', CURRENT_TIMESTAMP(), 
              JSON_OBJECT('maintenance_type', 'preference_retraining'));
    END;
    
    -- Weekly collaborative filtering enhancement
    CREATE OR REPLACE PROCEDURE automated_collaborative_enhancement()
    BEGIN
      DECLARE user_cursor CURSOR FOR 
        SELECT DISTINCT user_id 
        FROM `enterprise_knowledge_ai.users`
        WHERE is_active = TRUE;
      
      FOR user_record IN user_cursor DO
        CALL enhance_preferences_with_collaborative_filtering(user_record.user_id);
      END FOR;
      
      INSERT INTO `enterprise_knowledge_ai.deployment_log` 
        (deployment_id, component_name, deployment_status, deployment_timestamp, deployment_metadata)
      VALUES (GENERATE_UUID(), 'automated_maintenance', 'completed', CURRENT_TIMESTAMP(), 
              JSON_OBJECT('maintenance_type', 'collaborative_filtering'));
    END;
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'automated_maintenance', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'automated_maintenance', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Failed to setup automated maintenance: ', @@error.message);
  END;
  
  -- Step 7: Create monitoring and alerting
  BEGIN
    SELECT 'Setting up monitoring and alerting...' as status;
    
    -- System health monitoring
    CREATE OR REPLACE PROCEDURE monitor_personalization_health()
    BEGIN
      DECLARE avg_satisfaction FLOAT64;
      DECLARE low_satisfaction_users INT64;
      DECLARE system_errors INT64;
      
      -- Check average user satisfaction
      SET avg_satisfaction = (
        SELECT AVG(metric_value)
        FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
        WHERE metric_type = 'overall'
          AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
      );
      
      -- Count users with low satisfaction
      SET low_satisfaction_users = (
        SELECT COUNT(DISTINCT user_id)
        FROM `enterprise_knowledge_ai.user_satisfaction_metrics`
        WHERE metric_type = 'overall'
          AND metric_value < 0.6
          AND measurement_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
      );
      
      -- Count system errors
      SET system_errors = (
        SELECT COUNT(*)
        FROM `enterprise_knowledge_ai.deployment_log`
        WHERE deployment_status = 'failed'
          AND deployment_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
      );
      
      -- Generate alerts if needed
      IF avg_satisfaction < 0.7 OR low_satisfaction_users > 5 OR system_errors > 0 THEN
        INSERT INTO `enterprise_knowledge_ai.system_alerts` 
          (alert_id, alert_type, severity, message, alert_timestamp, metadata)
        VALUES (
          GENERATE_UUID(),
          'personalization_health',
          CASE 
            WHEN avg_satisfaction < 0.5 OR system_errors > 10 THEN 'critical'
            WHEN avg_satisfaction < 0.6 OR system_errors > 5 THEN 'high'
            ELSE 'medium'
          END,
          CONCAT('Personalization system health check: Avg satisfaction: ', 
                 CAST(ROUND(avg_satisfaction, 2) AS STRING),
                 ', Low satisfaction users: ', CAST(low_satisfaction_users AS STRING),
                 ', System errors: ', CAST(system_errors AS STRING)),
          CURRENT_TIMESTAMP(),
          JSON_OBJECT(
            'avg_satisfaction', avg_satisfaction,
            'low_satisfaction_users', low_satisfaction_users,
            'system_errors', system_errors
          )
        );
      END IF;
      
    END;
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'monitoring_alerting', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'monitoring_alerting', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Failed to setup monitoring: ', @@error.message);
  END;
  
  -- Step 8: Run deployment validation tests
  BEGIN
    SELECT 'Running deployment validation tests...' as status;
    
    -- Quick validation test
    CALL run_quick_personalization_tests();
    
    -- Check if tests passed
    IF (
      SELECT AVG(success_rate)
      FROM `enterprise_knowledge_ai.test_results`
      WHERE test_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 MINUTE)
    ) < 0.8 THEN
      RAISE USING MESSAGE = 'Deployment validation failed. System not ready for production.';
    END IF;
    
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp)
    VALUES (deployment_id, 'validation_tests', 'completed', CURRENT_TIMESTAMP());
    
  EXCEPTION WHEN ERROR THEN
    INSERT INTO `enterprise_knowledge_ai.deployment_log` 
      (deployment_id, component_name, deployment_status, deployment_timestamp, error_message)
    VALUES (deployment_id, 'validation_tests', 'failed', CURRENT_TIMESTAMP(), @@error.message);
    RAISE USING MESSAGE = CONCAT('Deployment validation failed: ', @@error.message);
  END;
  
  -- Final deployment completion
  INSERT INTO `enterprise_knowledge_ai.deployment_log` 
    (deployment_id, component_name, deployment_status, deployment_timestamp, deployment_metadata)
  VALUES (deployment_id, 'personalized_intelligence_engine', 'completed', CURRENT_TIMESTAMP(),
          JSON_OBJECT('total_deployment_time_ms', TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, MILLISECOND)));
  
  -- Generate deployment summary
  WITH deployment_summary AS (
    SELECT 
      COUNT(*) as total_components,
      SUM(CASE WHEN deployment_status = 'completed' THEN 1 ELSE 0 END) as successful_components,
      SUM(CASE WHEN deployment_status = 'failed' THEN 1 ELSE 0 END) as failed_components,
      TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), start_time, MILLISECOND) as total_time_ms
    FROM `enterprise_knowledge_ai.deployment_log`
    WHERE deployment_id = deployment_id
      AND component_name != 'personalized_intelligence_engine'
  )
  SELECT 
    '=== PERSONALIZED INTELLIGENCE ENGINE DEPLOYMENT COMPLETE ===' as deployment_header,
    deployment_id,
    total_components,
    successful_components,
    failed_components,
    total_time_ms,
    CASE 
      WHEN failed_components = 0 THEN '✅ DEPLOYMENT SUCCESSFUL'
      WHEN failed_components <= 2 THEN '⚠️ DEPLOYMENT COMPLETED WITH WARNINGS'
      ELSE '❌ DEPLOYMENT FAILED'
    END as deployment_status,
    CURRENT_TIMESTAMP() as completion_timestamp
  FROM deployment_summary;
  
  SELECT 'Personalized Intelligence Engine deployment completed successfully!' as final_status;
  
END;

-- Rollback procedure for emergency situations
CREATE OR REPLACE PROCEDURE rollback_personalized_intelligence_engine(deployment_id STRING)
BEGIN
  SELECT CONCAT('Rolling back deployment: ', deployment_id) as status;
  
  -- Drop user-specific tables created during deployment
  DECLARE table_cursor CURSOR FOR 
    SELECT table_name
    FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
    WHERE table_name LIKE 'user_preferences_%' 
       OR table_name LIKE 'personalized_feeds_%'
       OR table_name LIKE 'personalized_dashboard_%'
       OR table_name LIKE 'priority_scores_%';
  
  FOR table_record IN table_cursor DO
    EXECUTE IMMEDIATE CONCAT('DROP TABLE IF EXISTS `enterprise_knowledge_ai.', table_record.table_name, '`');
  END FOR;
  
  -- Log rollback
  INSERT INTO `enterprise_knowledge_ai.deployment_log` 
    (deployment_id, component_name, deployment_status, deployment_timestamp, deployment_metadata)
  VALUES (GENERATE_UUID(), 'rollback', 'completed', CURRENT_TIMESTAMP(),
          JSON_OBJECT('original_deployment_id', deployment_id, 'rollback_reason', 'manual_rollback'));
  
  SELECT 'Rollback completed successfully!' as rollback_status;
  
END;

-- Health check procedure
CREATE OR REPLACE PROCEDURE check_personalized_intelligence_health()
BEGIN
  WITH health_metrics AS (
    SELECT 
      'Role-based Filtering' as component,
      CASE WHEN EXISTS (
        SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
        WHERE routine_name = 'filter_content_by_role'
      ) THEN '✅ HEALTHY' ELSE '❌ MISSING' END as status
    
    UNION ALL
    
    SELECT 
      'Preference Learning',
      CASE WHEN EXISTS (
        SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
        WHERE routine_name = 'train_user_preference_model'
      ) THEN '✅ HEALTHY' ELSE '❌ MISSING' END
    
    UNION ALL
    
    SELECT 
      'Priority Scoring',
      CASE WHEN EXISTS (
        SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
        WHERE routine_name = 'calculate_content_priority'
      ) THEN '✅ HEALTHY' ELSE '❌ MISSING' END
    
    UNION ALL
    
    SELECT 
      'Content Generation',
      CASE WHEN EXISTS (
        SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
        WHERE routine_name = 'generate_personalized_insight'
      ) THEN '✅ HEALTHY' ELSE '❌ MISSING' END
  )
  SELECT 
    '=== PERSONALIZED INTELLIGENCE ENGINE HEALTH CHECK ===' as health_header,
    component,
    status
  FROM health_metrics;
  
END;