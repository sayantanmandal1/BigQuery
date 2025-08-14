-- Context Synthesis Engine using AI.GENERATE
-- This script implements intelligent context synthesis from multiple sources

-- Create generative AI model for context synthesis
CREATE OR REPLACE MODEL `enterprise_knowledge_ai.context_synthesis_model`
OPTIONS (
  model_type = 'GEMINI_PRO',
  max_iterations = 1,
  temperature = 0.3,
  top_p = 0.8,
  top_k = 40
);

-- Function to synthesize context from multiple document sources
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.synthesize_context`(
  source_documents ARRAY<STRUCT<content STRING, source STRING, confidence FLOAT64>>,
  synthesis_prompt STRING,
  max_output_tokens INT64 DEFAULT 1000
)
RETURNS STRUCT<
  synthesized_content STRING,
  confidence_score FLOAT64,
  source_count INT64,
  processing_timestamp TIMESTAMP
>
LANGUAGE SQL
AS (
  WITH 
  document_context AS (
    SELECT 
      STRING_AGG(
        CONCAT(
          'Source: ', doc.source, 
          ' (Confidence: ', CAST(doc.confidence AS STRING), ')\n',
          'Content: ', doc.content, '\n\n'
        ), 
        '\n---\n'
      ) as combined_context,
      COUNT(*) as source_count,
      AVG(doc.confidence) as avg_confidence
    FROM UNNEST(source_documents) as doc
  ),
  synthesis_result AS (
    SELECT 
      dc.source_count,
      dc.avg_confidence,
      ai_response.content as synthesized_content
    FROM document_context dc
    CROSS JOIN ML.GENERATE_TEXT(
      MODEL `enterprise_knowledge_ai.context_synthesis_model`,
      CONCAT(
        synthesis_prompt, '\n\n',
        'Context from multiple sources:\n',
        dc.combined_context,
        '\n\nPlease provide a comprehensive synthesis that:\n',
        '1. Combines insights from all sources\n',
        '2. Identifies common themes and contradictions\n',
        '3. Provides actionable recommendations\n',
        '4. Maintains factual accuracy\n\n',
        'Synthesis:'
      ),
      STRUCT(max_output_tokens as max_output_tokens, 0.3 as temperature)
    ) ai_response
  )
  SELECT AS STRUCT
    synthesized_content,
    avg_confidence as confidence_score,
    source_count,
    CURRENT_TIMESTAMP() as processing_timestamp
  FROM synthesis_result
);

-- Advanced context synthesis with domain-specific prompting
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.domain_aware_synthesis`(
  query_context STRING,
  source_documents ARRAY<STRUCT<
    content STRING, 
    source STRING, 
    content_type STRING,
    confidence FLOAT64,
    metadata JSON
  >>,
  domain_type STRING DEFAULT 'general',
  synthesis_style STRING DEFAULT 'analytical'
)
RETURNS STRUCT<
  executive_summary STRING,
  detailed_analysis STRING,
  key_insights ARRAY<STRING>,
  recommendations ARRAY<STRING>,
  confidence_score FLOAT64,
  source_breakdown JSON
>
LANGUAGE SQL
AS (
  WITH 
  domain_prompts AS (
    SELECT 
      CASE domain_type
        WHEN 'financial' THEN 'Focus on financial metrics, trends, risks, and opportunities. Provide quantitative analysis where possible.'
        WHEN 'technical' THEN 'Emphasize technical specifications, implementation details, and system architecture considerations.'
        WHEN 'strategic' THEN 'Highlight strategic implications, competitive advantages, and long-term business impact.'
        WHEN 'operational' THEN 'Focus on operational efficiency, process improvements, and resource optimization.'
        ELSE 'Provide a balanced analysis covering all relevant business aspects.'
      END as domain_prompt,
      CASE synthesis_style
        WHEN 'executive' THEN 'Write in executive summary style with bullet points and clear action items.'
        WHEN 'analytical' THEN 'Provide detailed analytical insights with supporting evidence and reasoning.'
        WHEN 'technical' THEN 'Use technical language appropriate for subject matter experts.'
        ELSE 'Use clear, professional language suitable for general business audience.'
      END as style_prompt
  ),
  document_analysis AS (
    SELECT 
      STRING_AGG(
        CONCAT(
          'Document ', ROW_NUMBER() OVER (ORDER BY doc.confidence DESC), ':\n',
          'Source: ', doc.source, '\n',
          'Type: ', doc.content_type, '\n',
          'Confidence: ', CAST(doc.confidence AS STRING), '\n',
          'Content: ', SUBSTR(doc.content, 1, 2000), '\n',
          'Metadata: ', COALESCE(TO_JSON_STRING(doc.metadata), '{}'), '\n\n'
        ), 
        '---\n'
      ) as formatted_context,
      COUNT(*) as total_sources,
      AVG(doc.confidence) as avg_confidence,
      TO_JSON_STRING(ARRAY_AGG(
        STRUCT(doc.source, doc.content_type, doc.confidence)
      )) as source_breakdown_json
    FROM UNNEST(source_documents) as doc
  ),
  synthesis_generation AS (
    SELECT 
      da.total_sources,
      da.avg_confidence,
      da.source_breakdown_json,
      ai_result.content as full_synthesis
    FROM document_analysis da
    CROSS JOIN domain_prompts dp
    CROSS JOIN ML.GENERATE_TEXT(
      MODEL `enterprise_knowledge_ai.context_synthesis_model`,
      CONCAT(
        'Query Context: ', query_context, '\n\n',
        'Domain Focus: ', dp.domain_prompt, '\n',
        'Style Requirements: ', dp.style_prompt, '\n\n',
        'Source Documents:\n', da.formatted_context, '\n\n',
        'Please provide a comprehensive analysis with the following structure:\n',
        '1. EXECUTIVE_SUMMARY: [2-3 sentence overview]\n',
        '2. DETAILED_ANALYSIS: [Comprehensive analysis with evidence]\n',
        '3. KEY_INSIGHTS: [List 3-5 key insights as bullet points]\n',
        '4. RECOMMENDATIONS: [List 3-5 actionable recommendations]\n\n',
        'Analysis:'
      ),
      STRUCT(2000 as max_output_tokens, 0.3 as temperature)
    ) ai_result
  ),
  parsed_synthesis AS (
    SELECT 
      sg.total_sources,
      sg.avg_confidence,
      sg.source_breakdown_json,
      -- Extract sections using regex patterns
      REGEXP_EXTRACT(sg.full_synthesis, r'EXECUTIVE_SUMMARY:\s*([^1-9]*?)(?=DETAILED_ANALYSIS:|$)') as executive_summary,
      REGEXP_EXTRACT(sg.full_synthesis, r'DETAILED_ANALYSIS:\s*([^1-9]*?)(?=KEY_INSIGHTS:|$)') as detailed_analysis,
      ARRAY(
        SELECT TRIM(insight)
        FROM UNNEST(SPLIT(
          REGEXP_EXTRACT(sg.full_synthesis, r'KEY_INSIGHTS:\s*([^1-9]*?)(?=RECOMMENDATIONS:|$)'), 
          '\n'
        )) as insight
        WHERE TRIM(insight) != '' AND TRIM(insight) NOT LIKE '%:%'
      ) as key_insights,
      ARRAY(
        SELECT TRIM(recommendation)
        FROM UNNEST(SPLIT(
          REGEXP_EXTRACT(sg.full_synthesis, r'RECOMMENDATIONS:\s*(.*)'), 
          '\n'
        )) as recommendation
        WHERE TRIM(recommendation) != '' AND TRIM(recommendation) NOT LIKE '%:%'
      ) as recommendations
    FROM synthesis_generation sg
  )
  SELECT AS STRUCT
    COALESCE(TRIM(executive_summary), 'Executive summary not available') as executive_summary,
    COALESCE(TRIM(detailed_analysis), 'Detailed analysis not available') as detailed_analysis,
    key_insights,
    recommendations,
    avg_confidence as confidence_score,
    PARSE_JSON(source_breakdown_json) as source_breakdown
  FROM parsed_synthesis
);

-- Real-time context synthesis for interactive queries
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.interactive_synthesis`(
  user_query STRING,
  user_context JSON DEFAULT NULL,
  max_sources INT64 DEFAULT 5
)
RETURNS STRUCT<
  answer STRING,
  supporting_sources ARRAY<STRUCT<source STRING, relevance FLOAT64>>,
  confidence_level STRING,
  follow_up_questions ARRAY<STRING>
>
LANGUAGE SQL
AS (
  WITH 
  relevant_documents AS (
    SELECT 
      knowledge_id,
      content,
      source_system,
      similarity_score,
      metadata
    FROM `enterprise_knowledge_ai.semantic_search`(
      user_query, 
      max_sources, 
      NULL, 
      NULL, 
      0.3
    )
  ),
  context_synthesis AS (
    SELECT 
      ai_response.content as synthesized_answer
    FROM (
      SELECT STRING_AGG(
        CONCAT('Source: ', source_system, '\nContent: ', SUBSTR(content, 1, 1000)), 
        '\n---\n'
      ) as context_text
      FROM relevant_documents
    ) context
    CROSS JOIN ML.GENERATE_TEXT(
      MODEL `enterprise_knowledge_ai.context_synthesis_model`,
      CONCAT(
        'User Query: ', user_query, '\n\n',
        COALESCE(CONCAT('User Context: ', TO_JSON_STRING(user_context), '\n\n'), ''),
        'Available Information:\n', context.context_text, '\n\n',
        'Please provide:\n',
        '1. A direct, comprehensive answer to the user query\n',
        '2. Three relevant follow-up questions the user might ask\n\n',
        'Format your response as:\n',
        'ANSWER: [your answer]\n',
        'FOLLOW_UP: [question 1] | [question 2] | [question 3]\n\n',
        'Response:'
      ),
      STRUCT(800 as max_output_tokens, 0.2 as temperature)
    ) ai_response
  ),
  parsed_response AS (
    SELECT 
      REGEXP_EXTRACT(synthesized_answer, r'ANSWER:\s*([^F]*?)(?=FOLLOW_UP:|$)') as answer,
      SPLIT(REGEXP_EXTRACT(synthesized_answer, r'FOLLOW_UP:\s*(.*)'), '|') as follow_up_array
    FROM context_synthesis
  )
  SELECT AS STRUCT
    TRIM(answer) as answer,
    ARRAY(
      SELECT AS STRUCT source_system as source, similarity_score as relevance
      FROM relevant_documents
      ORDER BY similarity_score DESC
    ) as supporting_sources,
    CASE 
      WHEN (SELECT AVG(similarity_score) FROM relevant_documents) > 0.8 THEN 'HIGH'
      WHEN (SELECT AVG(similarity_score) FROM relevant_documents) > 0.6 THEN 'MEDIUM'
      ELSE 'LOW'
    END as confidence_level,
    ARRAY(
      SELECT TRIM(question)
      FROM UNNEST(follow_up_array) as question
      WHERE TRIM(question) != ''
    ) as follow_up_questions
  FROM parsed_response
);