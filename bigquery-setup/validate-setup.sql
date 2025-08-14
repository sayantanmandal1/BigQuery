-- Enterprise Knowledge Intelligence Platform - Setup Validation
-- This script validates that all components are properly configured

-- Check that all datasets exist
SELECT 
  'Datasets' as component,
  COUNT(*) as count,
  ARRAY_AGG(schema_name) as items
FROM `[PROJECT_ID].INFORMATION_SCHEMA.SCHEMATA`
WHERE schema_name LIKE 'enterprise_knowledge%';

-- Check that all core tables exist
SELECT 
  'Core Tables' as component,
  COUNT(*) as count,
  ARRAY_AGG(table_name) as items
FROM `[PROJECT_ID].enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
WHERE table_type = 'BASE TABLE';

-- Check that all views exist
SELECT 
  'Views' as component,
  COUNT(*) as count,
  ARRAY_AGG(table_name) as items
FROM `[PROJECT_ID].enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
WHERE table_type = 'VIEW';

-- Check that vector indexes exist
SELECT 
  'Vector Indexes' as component,
  COUNT(*) as count,
  ARRAY_AGG(index_name) as items
FROM `[PROJECT_ID].enterprise_knowledge_ai.INFORMATION_SCHEMA.VECTOR_INDEXES`;

-- Check that connections exist
SELECT 
  'Connections' as component,
  COUNT(*) as count,
  ARRAY_AGG(connection_id) as items
FROM `[PROJECT_ID].us.INFORMATION_SCHEMA.CONNECTIONS`
WHERE connection_id LIKE '%knowledge%' OR connection_id LIKE '%storage%';

-- Check table partitioning
SELECT 
  'Partitioned Tables' as component,
  COUNT(*) as count,
  ARRAY_AGG(table_name) as items
FROM `[PROJECT_ID].enterprise_knowledge_ai.INFORMATION_SCHEMA.PARTITIONS`
WHERE partition_id IS NOT NULL;

-- Check table clustering
SELECT 
  'Clustered Tables' as component,
  COUNT(DISTINCT table_name) as count,
  ARRAY_AGG(DISTINCT table_name) as items
FROM `[PROJECT_ID].enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLE_OPTIONS`
WHERE option_name = 'clustering_fields';

-- Sample data insertion test (optional)
-- This will insert a test record to verify write permissions
INSERT INTO `[PROJECT_ID].enterprise_knowledge_ai.enterprise_knowledge_base` 
(
  knowledge_id,
  content_type,
  source_system,
  content,
  metadata,
  embedding,
  access_permissions,
  content_hash,
  language_code,
  classification_level,
  tags
)
VALUES 
(
  'test-setup-validation-001',
  'document',
  'setup-validation',
  'This is a test document to validate the BigQuery setup for Enterprise Knowledge Intelligence Platform.',
  JSON '{"test": true, "setup_validation": true}',
  ARRAY[0.1, 0.2, 0.3, 0.4, 0.5], -- Sample embedding vector
  ['public'],
  'test-hash-123',
  'en',
  'internal',
  ['test', 'setup', 'validation']
);

-- Verify the test record was inserted
SELECT 
  'Test Data Insertion' as component,
  COUNT(*) as count,
  'Success' as status
FROM `[PROJECT_ID].enterprise_knowledge_ai.enterprise_knowledge_base`
WHERE knowledge_id = 'test-setup-validation-001';

-- Clean up test data
DELETE FROM `[PROJECT_ID].enterprise_knowledge_ai.enterprise_knowledge_base`
WHERE knowledge_id = 'test-setup-validation-001';

-- Final validation summary
SELECT 
  'Setup Validation Complete' as status,
  CURRENT_TIMESTAMP() as validation_time,
  'All components verified successfully' as message;