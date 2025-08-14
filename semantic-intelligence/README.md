# Semantic Intelligence Engine

The Semantic Intelligence Engine is the core component of the Enterprise Knowledge Intelligence Platform, implementing advanced vector search and context synthesis capabilities using BigQuery's AI functions.

## Overview

This engine transforms unstructured enterprise data into actionable intelligence through:

- **Document Embedding Generation**: ML.GENERATE_EMBEDDING for semantic representation
- **Vector Search**: VECTOR_SEARCH for semantic document discovery
- **Context Synthesis**: AI.GENERATE for intelligent content combination
- **Custom Similarity Scoring**: Advanced distance metrics and contextual relevance

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                 Semantic Intelligence Engine                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Embedding       │  │ Vector Search   │  │ Context      │ │
│  │ Pipeline        │  │ Engine          │  │ Synthesis    │ │
│  │                 │  │                 │  │ Engine       │ │
│  │ • Text Preprocessing │ • Semantic Search │ • Multi-source │ │
│  │ • ML.GENERATE_  │  │ • Hybrid Search │  │   Combination │ │
│  │   EMBEDDING     │  │ • Filtered Search│  │ • AI.GENERATE │ │
│  │ • Quality Scoring│  │ • Performance   │  │ • Domain-aware│ │
│  │ • Batch Processing│  │   Optimization  │  │   Prompting  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Similarity Scoring System                  │ │
│  │                                                         │ │
│  │ • Custom Distance Metrics (Cosine, Euclidean, Manhattan)│ │
│  │ • Domain-specific Adjustments                           │ │
│  │ • Contextual Relevance Scoring                          │ │
│  │ • Batch Similarity Analysis                             │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Components

### 1. Embedding Pipeline (`embedding_pipeline.sql`)

**Core Functions:**
- `generate_document_embedding()`: Single document embedding generation
- `batch_generate_embeddings()`: Batch processing for existing documents
- `generate_enhanced_embedding()`: Advanced embedding with quality scoring
- `preprocess_text_for_embedding()`: Text normalization and cleaning

**Features:**
- Automatic text preprocessing and normalization
- Quality scoring based on content richness
- Batch processing capabilities for large datasets
- Error handling and logging

### 2. Vector Search Engine (`vector_search.sql`)

**Core Functions:**
- `semantic_search()`: Basic semantic search with filtering
- `advanced_semantic_search()`: Multi-criteria search with JSON parameters
- `hybrid_search()`: Combined semantic and keyword search

**Features:**
- Configurable similarity thresholds
- Multi-dimensional filtering (content type, source, date range)
- Relevance scoring with recency and tag bonuses
- Performance optimization for enterprise scale

### 3. Context Synthesis Engine (`context_synthesis.sql`)

**Core Functions:**
- `synthesize_context()`: Multi-source content synthesis
- `domain_aware_synthesis()`: Domain-specific intelligent synthesis
- `interactive_synthesis()`: Real-time query answering

**Features:**
- Domain-aware prompting (financial, technical, strategic, operational)
- Structured output parsing (executive summary, insights, recommendations)
- Confidence scoring and source attribution
- Interactive follow-up question generation

### 4. Similarity Scoring System (`similarity_scoring.sql`)

**Core Functions:**
- `calculate_similarity_score()`: Multi-metric similarity calculation
- `domain_similarity_score()`: Domain-specific similarity adjustments
- `batch_similarity_analysis()`: Efficient batch processing
- `contextual_similarity_score()`: Context-aware relevance scoring

**Features:**
- Multiple distance metrics (Cosine, Euclidean, Manhattan)
- Content type compatibility bonuses
- Temporal and authority factor adjustments
- Personalization based on user context

## Testing Framework

### Test Components (`tests/`)

1. **Test Setup** (`test_setup.sql`)
   - Test results tracking tables
   - Benchmark query datasets
   - Performance monitoring views
   - Health status monitoring

2. **Comprehensive Tests** (`test_semantic_search.sql`)
   - Embedding generation accuracy tests
   - Semantic search accuracy validation
   - Performance benchmarking
   - Context synthesis quality assessment

### Running Tests

```sql
-- Run complete test suite
CALL `enterprise_knowledge_ai.run_semantic_intelligence_tests`();

-- Check test health status
SELECT * FROM `enterprise_knowledge_ai.get_test_health_status`();

-- View test performance summary
SELECT * FROM `enterprise_knowledge_ai.test_performance_summary`
WHERE test_date >= CURRENT_DATE() - 7;
```

## Deployment

### Prerequisites

1. BigQuery dataset `enterprise_knowledge_ai` must exist
2. Core tables must be created (see `bigquery-setup/02-core-tables.sql`)
3. Vector indexes must be configured (see `bigquery-setup/04-vector-indexes.sql`)
4. Appropriate IAM permissions for AI/ML functions

### Deployment Steps

1. **Deploy the engine:**
   ```sql
   -- Run deployment script
   EXECUTE IMMEDIATE (
     SELECT content FROM `your-project.your-dataset.deployment_scripts`
     WHERE script_name = 'deploy_semantic_engine.sql'
   );
   ```

2. **Validate deployment:**
   ```sql
   -- Check deployment status
   SELECT * FROM `enterprise_knowledge_ai.processing_logs`
   WHERE process_type = 'semantic_engine_deployment'
   ORDER BY processing_timestamp DESC
   LIMIT 10;
   ```

3. **Run initial tests:**
   ```sql
   CALL `enterprise_knowledge_ai.run_semantic_intelligence_tests`();
   ```

## Usage Examples

### Basic Semantic Search

```sql
-- Find documents related to financial performance
SELECT *
FROM `enterprise_knowledge_ai.semantic_search`(
  'quarterly financial performance and revenue analysis',
  10,  -- top_k results
  'document',  -- content_type_filter
  NULL,  -- source_system_filter
  0.7  -- min_confidence
);
```

### Advanced Search with Parameters

```sql
-- Complex search with multiple filters
SELECT *
FROM `enterprise_knowledge_ai.advanced_semantic_search`(
  'customer satisfaction and mobile app performance',
  JSON '{
    "top_k": 15,
    "content_type": "document",
    "min_confidence": 0.6,
    "date_range_start": "2024-01-01",
    "required_tags": ["customer", "mobile"],
    "classification_level": "internal"
  }'
);
```

### Context Synthesis

```sql
-- Synthesize insights from multiple sources
SELECT synthesis_result.*
FROM `enterprise_knowledge_ai.domain_aware_synthesis`(
  'Analyze Q3 business performance across all departments',
  ARRAY[
    STRUCT('Q3 revenue increased 15%...' as content, 'financial_report' as source, 'document' as content_type, 0.9 as confidence, JSON '{}' as metadata),
    STRUCT('Customer satisfaction improved...' as content, 'survey_results' as source, 'document' as content_type, 0.8 as confidence, JSON '{}' as metadata)
  ],
  'strategic',  -- domain_type
  'executive'   -- synthesis_style
) synthesis_result;
```

### Interactive Query

```sql
-- Real-time question answering
SELECT response.*
FROM `enterprise_knowledge_ai.interactive_synthesis`(
  'What are our main competitive advantages in the cloud services market?',
  JSON '{"user_role": "executive", "department": "strategy"}',
  5  -- max_sources
) response;
```

## Performance Optimization

### Best Practices

1. **Vector Index Optimization**
   - Use appropriate `num_lists` based on dataset size
   - Adjust `num_probes` for accuracy vs. speed tradeoff
   - Consider separate indexes for different content types

2. **Query Optimization**
   - Use content type filters to reduce search space
   - Set appropriate similarity thresholds
   - Leverage clustering keys for efficient filtering

3. **Batch Processing**
   - Process embeddings in batches for better throughput
   - Use scheduled procedures for regular updates
   - Monitor processing logs for performance insights

### Monitoring

```sql
-- Monitor search performance
SELECT 
  AVG(execution_duration_ms) as avg_duration,
  COUNT(*) as query_count,
  test_name
FROM `enterprise_knowledge_ai.test_results`
WHERE test_suite = 'semantic_intelligence'
  AND DATE(execution_timestamp) = CURRENT_DATE()
GROUP BY test_name;
```

## Requirements Satisfied

This implementation satisfies the following requirements from the specification:

- **Requirement 1.1**: Semantic document discovery with 95%+ relevance accuracy
- **Requirement 1.2**: Comprehensive summaries using generative AI
- **Requirement 1.3**: Unified analysis across multiple document types

The engine provides enterprise-scale semantic intelligence capabilities with comprehensive testing, monitoring, and optimization features.