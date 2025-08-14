-- Implementation Validation Script
-- This script validates that all components of the semantic intelligence engine are properly implemented

-- Check if all required functions exist
WITH function_checks AS (
  SELECT 
    'generate_document_embedding' as function_name,
    EXISTS(
      SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
      WHERE routine_name = 'generate_document_embedding'
    ) as exists_check
  UNION ALL
  SELECT 'semantic_search', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
    WHERE routine_name = 'semantic_search'
  )
  UNION ALL
  SELECT 'synthesize_context', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
    WHERE routine_name = 'synthesize_context'
  )
  UNION ALL
  SELECT 'calculate_similarity_score', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
    WHERE routine_name = 'calculate_similarity_score'
  )
  UNION ALL
  SELECT 'advanced_semantic_search', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
    WHERE routine_name = 'advanced_semantic_search'
  )
  UNION ALL
  SELECT 'domain_aware_synthesis', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.ROUTINES`
    WHERE routine_name = 'domain_aware_synthesis'
  )
),
model_checks AS (
  SELECT 
    'text_embedding_model' as model_name,
    EXISTS(
      SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.MODELS`
      WHERE model_name = 'text_embedding_model'
    ) as exists_check
  UNION ALL
  SELECT 'context_synthesis_model', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.MODELS`
    WHERE model_name = 'context_synthesis_model'
  )
),
table_checks AS (
  SELECT 
    'test_documents' as table_name,
    EXISTS(
      SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
      WHERE table_name = 'test_documents'
    ) as exists_check
  UNION ALL
  SELECT 'test_results', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
    WHERE table_name = 'test_results'
  )
  UNION ALL
  SELECT 'processing_logs', EXISTS(
    SELECT 1 FROM `enterprise_knowledge_ai.INFORMATION_SCHEMA.TABLES`
    WHERE table_name = 'processing_logs'
  )
)

-- Validation Summary
SELECT 
  'SEMANTIC INTELLIGENCE ENGINE VALIDATION' as validation_report,
  (SELECT COUNT(*) FROM function_checks WHERE exists_check = TRUE) as functions_implemented,
  (SELECT COUNT(*) FROM function_checks) as total_functions_required,
  (SELECT COUNT(*) FROM model_checks WHERE exists_check = TRUE) as models_created,
  (SELECT COUNT(*) FROM model_checks) as total_models_required,
  (SELECT COUNT(*) FROM table_checks WHERE exists_check = TRUE) as tables_created,
  (SELECT COUNT(*) FROM table_checks) as total_tables_required,
  CASE 
    WHEN (SELECT COUNT(*) FROM function_checks WHERE exists_check = FALSE) = 0
         AND (SELECT COUNT(*) FROM model_checks WHERE exists_check = FALSE) = 0
         AND (SELECT COUNT(*) FROM table_checks WHERE exists_check = FALSE) = 0
    THEN 'IMPLEMENTATION_COMPLETE'
    ELSE 'IMPLEMENTATION_INCOMPLETE'
  END as validation_status;

-- Detailed component status
SELECT 'FUNCTIONS' as component_type, function_name as component_name, exists_check as is_implemented
FROM function_checks
UNION ALL
SELECT 'MODELS', model_name, exists_check
FROM model_checks
UNION ALL
SELECT 'TABLES', table_name, exists_check
FROM table_checks
ORDER BY component_type, component_name;