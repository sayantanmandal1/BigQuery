-- Vector Search Implementation for Semantic Document Discovery
-- This script implements VECTOR_SEARCH functionality with advanced filtering and ranking

-- Core semantic search function with configurable parameters
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.semantic_search`(
  query_text STRING,
  top_k INT64 DEFAULT 10,
  content_type_filter STRING DEFAULT NULL,
  source_system_filter STRING DEFAULT NULL,
  min_confidence FLOAT64 DEFAULT 0.0
)
RETURNS TABLE<
  knowledge_id STRING,
  content STRING,
  content_type STRING,
  source_system STRING,
  similarity_score FLOAT64,
  metadata JSON,
  created_timestamp TIMESTAMP
>
LANGUAGE SQL
AS (
  WITH query_embedding AS (
    SELECT embedding as query_vector
    FROM ML.GENERATE_EMBEDDING(
      MODEL `enterprise_knowledge_ai.text_embedding_model`,
      (SELECT query_text AS content)
    )
  ),
  search_results AS (
    SELECT 
      kb.knowledge_id,
      kb.content,
      kb.content_type,
      kb.source_system,
      kb.metadata,
      kb.created_timestamp,
      vs.distance,
      -- Convert distance to similarity score (1 - cosine_distance)
      (1 - vs.distance) as similarity_score
    FROM VECTOR_SEARCH(
      TABLE `enterprise_knowledge_ai.enterprise_knowledge_base`,
      'embedding',
      (SELECT query_vector FROM query_embedding),
      top_k => top_k,
      distance_type => 'COSINE',
      options => JSON '{"fraction_lists_to_search": 0.1}'
    ) vs
    JOIN `enterprise_knowledge_ai.enterprise_knowledge_base` kb
      ON vs.knowledge_id = kb.knowledge_id
    WHERE 
      (content_type_filter IS NULL OR kb.content_type = content_type_filter)
      AND (source_system_filter IS NULL OR kb.source_system = source_system_filter)
      AND (1 - vs.distance) >= min_confidence
  )
  SELECT 
    knowledge_id,
    content,
    content_type,
    source_system,
    similarity_score,
    metadata,
    created_timestamp
  FROM search_results
  ORDER BY similarity_score DESC
);

-- Advanced semantic search with multi-criteria filtering
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.advanced_semantic_search`(
  query_text STRING,
  search_params JSON
)
RETURNS TABLE<
  knowledge_id STRING,
  content STRING,
  content_type STRING,
  source_system STRING,
  similarity_score FLOAT64,
  relevance_score FLOAT64,
  metadata JSON,
  created_timestamp TIMESTAMP,
  access_permissions ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH 
  search_config AS (
    SELECT 
      COALESCE(JSON_VALUE(search_params, '$.top_k'), '10') as top_k,
      JSON_VALUE(search_params, '$.content_type') as content_type_filter,
      JSON_VALUE(search_params, '$.source_system') as source_system_filter,
      COALESCE(CAST(JSON_VALUE(search_params, '$.min_confidence') AS FLOAT64), 0.0) as min_confidence,
      JSON_VALUE(search_params, '$.date_range_start') as date_start,
      JSON_VALUE(search_params, '$.date_range_end') as date_end,
      JSON_EXTRACT_STRING_ARRAY(search_params, '$.required_tags') as required_tags,
      JSON_VALUE(search_params, '$.classification_level') as classification_filter
  ),
  query_embedding AS (
    SELECT embedding as query_vector
    FROM ML.GENERATE_EMBEDDING(
      MODEL `enterprise_knowledge_ai.text_embedding_model`,
      (SELECT query_text AS content)
    )
  ),
  filtered_search AS (
    SELECT 
      kb.knowledge_id,
      kb.content,
      kb.content_type,
      kb.source_system,
      kb.metadata,
      kb.created_timestamp,
      kb.access_permissions,
      kb.tags,
      vs.distance,
      (1 - vs.distance) as similarity_score,
      -- Calculate relevance score based on multiple factors
      (1 - vs.distance) * 0.7 +  -- Semantic similarity weight
      CASE 
        WHEN kb.created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) THEN 0.2
        WHEN kb.created_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) THEN 0.1
        ELSE 0.0
      END +  -- Recency bonus
      CASE 
        WHEN ARRAY_LENGTH(kb.tags) > 0 THEN 0.1
        ELSE 0.0
      END as relevance_score  -- Tag richness bonus
    FROM VECTOR_SEARCH(
      TABLE `enterprise_knowledge_ai.enterprise_knowledge_base`,
      'embedding',
      (SELECT query_vector FROM query_embedding),
      top_k => CAST((SELECT top_k FROM search_config) AS INT64),
      distance_type => 'COSINE'
    ) vs
    JOIN `enterprise_knowledge_ai.enterprise_knowledge_base` kb
      ON vs.knowledge_id = kb.knowledge_id
    CROSS JOIN search_config sc
    WHERE 
      (sc.content_type_filter IS NULL OR kb.content_type = sc.content_type_filter)
      AND (sc.source_system_filter IS NULL OR kb.source_system = sc.source_system_filter)
      AND (sc.classification_filter IS NULL OR kb.classification_level = sc.classification_filter)
      AND (sc.date_start IS NULL OR kb.created_timestamp >= PARSE_TIMESTAMP('%Y-%m-%d', sc.date_start))
      AND (sc.date_end IS NULL OR kb.created_timestamp <= PARSE_TIMESTAMP('%Y-%m-%d', sc.date_end))
      AND (sc.required_tags IS NULL OR 
           EXISTS(SELECT 1 FROM UNNEST(sc.required_tags) as required_tag 
                  WHERE required_tag IN UNNEST(kb.tags)))
      AND (1 - vs.distance) >= sc.min_confidence
  )
  SELECT 
    knowledge_id,
    content,
    content_type,
    source_system,
    similarity_score,
    relevance_score,
    metadata,
    created_timestamp,
    access_permissions
  FROM filtered_search
  ORDER BY relevance_score DESC, similarity_score DESC
);

-- Hybrid search combining semantic and keyword matching
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.hybrid_search`(
  query_text STRING,
  top_k INT64 DEFAULT 10,
  semantic_weight FLOAT64 DEFAULT 0.7,
  keyword_weight FLOAT64 DEFAULT 0.3
)
RETURNS TABLE<
  knowledge_id STRING,
  content STRING,
  content_type STRING,
  source_system STRING,
  semantic_score FLOAT64,
  keyword_score FLOAT64,
  combined_score FLOAT64,
  metadata JSON
>
LANGUAGE SQL
AS (
  WITH 
  query_embedding AS (
    SELECT embedding as query_vector
    FROM ML.GENERATE_EMBEDDING(
      MODEL `enterprise_knowledge_ai.text_embedding_model`,
      (SELECT query_text AS content)
    )
  ),
  semantic_results AS (
    SELECT 
      kb.knowledge_id,
      kb.content,
      kb.content_type,
      kb.source_system,
      kb.metadata,
      (1 - vs.distance) as semantic_score
    FROM VECTOR_SEARCH(
      TABLE `enterprise_knowledge_ai.enterprise_knowledge_base`,
      'embedding',
      (SELECT query_vector FROM query_embedding),
      top_k => top_k * 2,  -- Get more results for hybrid ranking
      distance_type => 'COSINE'
    ) vs
    JOIN `enterprise_knowledge_ai.enterprise_knowledge_base` kb
      ON vs.knowledge_id = kb.knowledge_id
  ),
  keyword_results AS (
    SELECT 
      knowledge_id,
      -- Simple keyword matching score based on term frequency
      (
        LENGTH(UPPER(content)) - LENGTH(REGEXP_REPLACE(UPPER(content), UPPER(query_text), ''))
      ) / LENGTH(UPPER(query_text)) / LENGTH(content) * 1000 as keyword_score
    FROM `enterprise_knowledge_ai.enterprise_knowledge_base`
    WHERE UPPER(content) LIKE CONCAT('%', UPPER(query_text), '%')
  ),
  combined_results AS (
    SELECT 
      sr.knowledge_id,
      sr.content,
      sr.content_type,
      sr.source_system,
      sr.metadata,
      sr.semantic_score,
      COALESCE(kr.keyword_score, 0.0) as keyword_score,
      (sr.semantic_score * semantic_weight + COALESCE(kr.keyword_score, 0.0) * keyword_weight) as combined_score
    FROM semantic_results sr
    LEFT JOIN keyword_results kr ON sr.knowledge_id = kr.knowledge_id
  )
  SELECT 
    knowledge_id,
    content,
    content_type,
    source_system,
    semantic_score,
    keyword_score,
    combined_score,
    metadata
  FROM combined_results
  ORDER BY combined_score DESC
  LIMIT top_k
);