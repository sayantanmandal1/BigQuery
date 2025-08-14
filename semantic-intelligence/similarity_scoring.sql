-- Custom Distance Metrics and Similarity Scoring System
-- This script implements advanced similarity scoring with custom distance metrics

-- Custom similarity scoring function with multiple distance metrics
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.calculate_similarity_score`(
  embedding1 ARRAY<FLOAT64>,
  embedding2 ARRAY<FLOAT64>,
  distance_type STRING DEFAULT 'COSINE',
  normalization_method STRING DEFAULT 'STANDARD'
)
RETURNS STRUCT<
  cosine_similarity FLOAT64,
  euclidean_distance FLOAT64,
  manhattan_distance FLOAT64,
  normalized_score FLOAT64,
  confidence_level STRING
>
LANGUAGE SQL
AS (
  WITH 
  vector_stats AS (
    SELECT 
      ARRAY_LENGTH(embedding1) as dim1,
      ARRAY_LENGTH(embedding2) as dim2,
      -- Calculate dot product
      (
        SELECT SUM(e1 * e2)
        FROM UNNEST(embedding1) as e1 WITH OFFSET pos1
        JOIN UNNEST(embedding2) as e2 WITH OFFSET pos2
        ON pos1 = pos2
      ) as dot_product,
      -- Calculate magnitudes
      SQRT((SELECT SUM(e * e) FROM UNNEST(embedding1) as e)) as magnitude1,
      SQRT((SELECT SUM(e * e) FROM UNNEST(embedding2) as e)) as magnitude2
  ),
  distance_calculations AS (
    SELECT 
      vs.*,
      -- Cosine similarity
      CASE 
        WHEN vs.magnitude1 = 0 OR vs.magnitude2 = 0 THEN 0.0
        ELSE vs.dot_product / (vs.magnitude1 * vs.magnitude2)
      END as cosine_sim,
      -- Euclidean distance
      SQRT((
        SELECT SUM(POW(e1 - e2, 2))
        FROM UNNEST(embedding1) as e1 WITH OFFSET pos1
        JOIN UNNEST(embedding2) as e2 WITH OFFSET pos2
        ON pos1 = pos2
      )) as euclidean_dist,
      -- Manhattan distance
      (
        SELECT SUM(ABS(e1 - e2))
        FROM UNNEST(embedding1) as e1 WITH OFFSET pos1
        JOIN UNNEST(embedding2) as e2 WITH OFFSET pos2
        ON pos1 = pos2
      ) as manhattan_dist
  ),
  normalized_scores AS (
    SELECT 
      dc.*,
      -- Normalize based on selected method
      CASE normalization_method
        WHEN 'MINMAX' THEN 
          CASE distance_type
            WHEN 'COSINE' THEN (dc.cosine_sim + 1) / 2  -- Scale from [-1,1] to [0,1]
            WHEN 'EUCLIDEAN' THEN 1 / (1 + dc.euclidean_dist)  -- Inverse distance
            WHEN 'MANHATTAN' THEN 1 / (1 + dc.manhattan_dist)  -- Inverse distance
            ELSE dc.cosine_sim
          END
        WHEN 'SIGMOID' THEN
          1 / (1 + EXP(-5 * (dc.cosine_sim - 0.5)))  -- Sigmoid normalization
        ELSE  -- STANDARD
          CASE distance_type
            WHEN 'COSINE' THEN GREATEST(0, dc.cosine_sim)
            WHEN 'EUCLIDEAN' THEN 1 / (1 + dc.euclidean_dist)
            WHEN 'MANHATTAN' THEN 1 / (1 + dc.manhattan_dist)
            ELSE dc.cosine_sim
          END
      END as normalized_score
  )
  SELECT AS STRUCT
    cosine_sim as cosine_similarity,
    euclidean_dist as euclidean_distance,
    manhattan_dist as manhattan_distance,
    normalized_score,
    CASE 
      WHEN normalized_score >= 0.9 THEN 'VERY_HIGH'
      WHEN normalized_score >= 0.7 THEN 'HIGH'
      WHEN normalized_score >= 0.5 THEN 'MEDIUM'
      WHEN normalized_score >= 0.3 THEN 'LOW'
      ELSE 'VERY_LOW'
    END as confidence_level
  FROM normalized_scores
);

-- Domain-specific similarity scoring for different content types
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.domain_similarity_score`(
  embedding1 ARRAY<FLOAT64>,
  embedding2 ARRAY<FLOAT64>,
  content_type1 STRING,
  content_type2 STRING,
  domain_weights JSON DEFAULT NULL
)
RETURNS STRUCT<
  base_similarity FLOAT64,
  domain_adjusted_similarity FLOAT64,
  content_type_bonus FLOAT64,
  final_score FLOAT64
>
LANGUAGE SQL
AS (
  WITH 
  base_calculation AS (
    SELECT 
      result.cosine_similarity as base_sim,
      result.normalized_score as base_normalized
    FROM `enterprise_knowledge_ai.calculate_similarity_score`(
      embedding1, embedding2, 'COSINE', 'STANDARD'
    ) result
  ),
  domain_adjustments AS (
    SELECT 
      bc.*,
      -- Content type compatibility bonus
      CASE 
        WHEN content_type1 = content_type2 THEN 0.1  -- Same type bonus
        WHEN (content_type1 = 'document' AND content_type2 = 'email') OR
             (content_type1 = 'email' AND content_type2 = 'document') THEN 0.05  -- Related types
        WHEN (content_type1 = 'image' AND content_type2 = 'document') OR
             (content_type1 = 'document' AND content_type2 = 'image') THEN 0.02  -- Cross-modal
        ELSE 0.0
      END as type_bonus,
      -- Domain-specific weight adjustments
      COALESCE(
        CAST(JSON_VALUE(domain_weights, CONCAT('$.', content_type1)) AS FLOAT64),
        1.0
      ) as weight1,
      COALESCE(
        CAST(JSON_VALUE(domain_weights, CONCAT('$.', content_type2)) AS FLOAT64),
        1.0
      ) as weight2
  ),
  final_calculation AS (
    SELECT 
      da.*,
      -- Apply domain weights and content type bonus
      da.base_sim * SQRT(da.weight1 * da.weight2) + da.type_bonus as domain_adjusted,
      -- Final score with bounds checking
      LEAST(1.0, GREATEST(0.0, 
        da.base_sim * SQRT(da.weight1 * da.weight2) + da.type_bonus
      )) as final_score
  )
  SELECT AS STRUCT
    base_sim as base_similarity,
    domain_adjusted as domain_adjusted_similarity,
    type_bonus as content_type_bonus,
    final_score
  FROM final_calculation
);

-- Batch similarity scoring for multiple document comparisons
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.batch_similarity_analysis`(
  target_embedding ARRAY<FLOAT64>,
  comparison_documents ARRAY<STRUCT<
    id STRING,
    embedding ARRAY<FLOAT64>,
    content_type STRING,
    metadata JSON
  >>,
  similarity_threshold FLOAT64 DEFAULT 0.5
)
RETURNS ARRAY<STRUCT<
  document_id STRING,
  similarity_score FLOAT64,
  rank_position INT64,
  content_type STRING,
  is_above_threshold BOOL,
  metadata JSON
>>
LANGUAGE SQL
AS (
  WITH 
  similarity_calculations AS (
    SELECT 
      doc.id as document_id,
      doc.content_type,
      doc.metadata,
      sim_result.normalized_score as similarity_score,
      sim_result.confidence_level
    FROM UNNEST(comparison_documents) as doc
    CROSS JOIN `enterprise_knowledge_ai.calculate_similarity_score`(
      target_embedding, 
      doc.embedding, 
      'COSINE', 
      'STANDARD'
    ) sim_result
  ),
  ranked_results AS (
    SELECT 
      *,
      ROW_NUMBER() OVER (ORDER BY similarity_score DESC) as rank_position,
      similarity_score >= similarity_threshold as is_above_threshold
    FROM similarity_calculations
  )
  SELECT ARRAY_AGG(
    STRUCT(
      document_id,
      similarity_score,
      rank_position,
      content_type,
      is_above_threshold,
      metadata
    )
    ORDER BY rank_position
  )
  FROM ranked_results
);

-- Contextual similarity scoring that considers document relationships
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.contextual_similarity_score`(
  query_embedding ARRAY<FLOAT64>,
  document_embedding ARRAY<FLOAT64>,
  document_context STRUCT<
    source_system STRING,
    creation_date TIMESTAMP,
    author STRING,
    tags ARRAY<STRING>,
    related_documents ARRAY<STRING>
  >,
  query_context STRUCT<
    user_role STRING,
    department STRING,
    recent_interactions ARRAY<STRING>,
    preferred_sources ARRAY<STRING>
  >
)
RETURNS STRUCT<
  base_similarity FLOAT64,
  context_boost FLOAT64,
  temporal_factor FLOAT64,
  authority_factor FLOAT64,
  personalization_factor FLOAT64,
  final_contextual_score FLOAT64
>
LANGUAGE SQL
AS (
  WITH 
  base_similarity AS (
    SELECT normalized_score as base_sim
    FROM `enterprise_knowledge_ai.calculate_similarity_score`(
      query_embedding, document_embedding, 'COSINE', 'STANDARD'
    )
  ),
  context_factors AS (
    SELECT 
      bs.base_sim,
      -- Temporal relevance (newer documents get slight boost)
      CASE 
        WHEN document_context.creation_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) THEN 0.1
        WHEN document_context.creation_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY) THEN 0.05
        WHEN document_context.creation_date >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY) THEN 0.02
        ELSE 0.0
      END as temporal_boost,
      -- Authority factor based on source system reliability
      CASE document_context.source_system
        WHEN 'official_documents' THEN 0.15
        WHEN 'executive_communications' THEN 0.12
        WHEN 'technical_documentation' THEN 0.10
        WHEN 'team_communications' THEN 0.05
        ELSE 0.0
      END as authority_boost,
      -- Personalization based on user preferences
      CASE 
        WHEN document_context.source_system IN UNNEST(query_context.preferred_sources) THEN 0.08
        WHEN EXISTS(
          SELECT 1 FROM UNNEST(document_context.related_documents) as related
          WHERE related IN UNNEST(query_context.recent_interactions)
        ) THEN 0.06
        ELSE 0.0
      END as personalization_boost,
      -- Tag relevance boost
      CASE 
        WHEN ARRAY_LENGTH(document_context.tags) > 0 THEN 0.03
        ELSE 0.0
      END as tag_boost
    FROM base_similarity bs
  ),
  final_calculation AS (
    SELECT 
      cf.*,
      cf.temporal_boost + cf.authority_boost + cf.personalization_boost + cf.tag_boost as total_context_boost,
      -- Calculate final score with diminishing returns on boosts
      cf.base_sim + (cf.temporal_boost + cf.authority_boost + cf.personalization_boost + cf.tag_boost) * 
        (1 - cf.base_sim) * 0.5 as final_score
  )
  SELECT AS STRUCT
    base_sim as base_similarity,
    total_context_boost as context_boost,
    temporal_boost as temporal_factor,
    authority_boost as authority_factor,
    personalization_boost as personalization_factor,
    LEAST(1.0, final_score) as final_contextual_score
  FROM final_calculation
);