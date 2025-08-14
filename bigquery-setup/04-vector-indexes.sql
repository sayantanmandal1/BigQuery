-- Enterprise Knowledge Intelligence Platform - Vector Indexes for Semantic Search
-- This script creates optimized vector indexes for enterprise-scale semantic search

-- Primary vector index for enterprise knowledge base
CREATE VECTOR INDEX IF NOT EXISTS `enterprise_knowledge_index`
ON `enterprise_knowledge_ai.enterprise_knowledge_base`(embedding)
OPTIONS (
  index_type = 'IVF',
  distance_type = 'COSINE',
  ivf_options = JSON '{
    "num_lists": 1000,
    "num_probes": 10
  }'
);

-- Specialized vector index for document embeddings (optimized for text similarity)
CREATE VECTOR INDEX IF NOT EXISTS `document_semantic_index`
ON `enterprise_knowledge_ai.enterprise_knowledge_base`(embedding)
WHERE content_type = 'document'
OPTIONS (
  index_type = 'IVF',
  distance_type = 'COSINE',
  ivf_options = JSON '{
    "num_lists": 500,
    "num_probes": 20
  }'
);

-- Vector index for multimodal content (images, videos with extracted features)
CREATE VECTOR INDEX IF NOT EXISTS `multimodal_content_index`
ON `enterprise_knowledge_ai.enterprise_knowledge_base`(embedding)
WHERE content_type IN ('image', 'video', 'multimodal')
OPTIONS (
  index_type = 'IVF',
  distance_type = 'EUCLIDEAN',
  ivf_options = JSON '{
    "num_lists": 200,
    "num_probes": 15
  }'
);

-- Composite index for efficient filtering and vector search combination
CREATE INDEX IF NOT EXISTS `knowledge_base_composite_idx`
ON `enterprise_knowledge_ai.enterprise_knowledge_base`(
  content_type,
  source_system,
  classification_level,
  created_timestamp
)
OPTIONS (
  description = "Composite index for efficient filtering before vector search"
);

-- Index for generated insights to support real-time querying
CREATE INDEX IF NOT EXISTS `insights_performance_idx`
ON `enterprise_knowledge_ai.generated_insights`(
  insight_type,
  business_impact_score DESC,
  confidence_score DESC,
  generated_timestamp DESC
)
OPTIONS (
  description = "Performance index for insight retrieval and ranking"
);

-- Index for user interactions to support personalization queries
CREATE INDEX IF NOT EXISTS `user_interactions_personalization_idx`
ON `enterprise_knowledge_ai.user_interactions`(
  user_id,
  interaction_type,
  interaction_timestamp DESC,
  feedback_score
)
OPTIONS (
  description = "Index for personalization and user behavior analysis"
);