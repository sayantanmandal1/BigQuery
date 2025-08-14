-- Comprehensive Multimodal Analysis using AI.GENERATE with multimodal inputs
-- Combines all modalities for holistic business intelligence

-- Create function for comprehensive product analysis
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.comprehensive_product_analysis`(
  product_id STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH product_context AS (
    SELECT 
      p.product_id,
      p.specifications,
      p.description,
      p.price,
      p.category,
      p.image_ref,
      s.total_sales,
      s.avg_rating,
      s.return_rate,
      s.review_sentiment,
      c.competitor_price,
      c.market_position
    FROM product_catalog_objects p
    LEFT JOIN product_sales_metrics s ON p.product_id = s.product_id
    LEFT JOIN competitive_analysis c ON p.product_id = c.product_id
    WHERE p.product_id = product_id
  )
  SELECT TO_JSON(STRUCT(
    product_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      CONCAT(
        'Perform comprehensive product analysis combining visual and business data. ',
        'Product: ', specifications,
        ', Price: $', CAST(price AS STRING),
        ', Category: ', category,
        ', Sales: ', CAST(total_sales AS STRING),
        ', Rating: ', CAST(avg_rating AS STRING),
        ', Return rate: ', CAST(return_rate AS STRING),
        ', Market position: ', COALESCE(market_position, 'Unknown'),
        '. Provide strategic recommendations for optimization.'
      ),
      STRUCT(image_ref AS uri)
    ) AS comprehensive_analysis,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      CONCAT(
        'Based on the product image and performance data, identify specific improvement opportunities: ',
        'Current performance - Sales: ', CAST(total_sales AS STRING),
        ', Rating: ', CAST(avg_rating AS STRING),
        ', Returns: ', CAST(return_rate AS STRING)
      ),
      STRUCT(image_ref AS uri)
    ) AS improvement_recommendations,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Rate overall product success potential from 0.0 to 1.0 based on: ',
        'Visual appeal, specifications: ', specifications,
        ', Current performance: Sales=', CAST(total_sales AS STRING),
        ', Rating=', CAST(avg_rating AS STRING)
      )
    ) AS success_potential_score,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      'Identify the target customer segment most likely to purchase this product based on visual features and specifications.',
      STRUCT(image_ref AS uri)
    ) AS target_customer_analysis,
    CURRENT_TIMESTAMP() AS analyzed_at
  ))
  FROM product_context
);

-- Create function for comprehensive customer journey analysis
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.comprehensive_customer_journey_analysis`(
  customer_id STRING
)
RETURNS JSON
LANGUAGE SQL
AS (
  WITH customer_context AS (
    SELECT 
      c.customer_id,
      c.segment,
      c.lifetime_value,
      c.satisfaction_score,
      ARRAY_AGG(DISTINCT p.category) AS purchased_categories,
      ARRAY_AGG(DISTINCT t.issue_description) AS support_issues,
      ARRAY_AGG(DISTINCT t.image_ref IGNORE NULLS) AS support_images,
      COUNT(DISTINCT o.order_id) AS total_orders,
      AVG(o.order_value) AS avg_order_value
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN product_catalog_objects p ON oi.product_id = p.product_id
    LEFT JOIN support_ticket_objects t ON c.customer_id = t.customer_id
    WHERE c.customer_id = customer_id
    GROUP BY c.customer_id, c.segment, c.lifetime_value, c.satisfaction_score
  )
  SELECT TO_JSON(STRUCT(
    customer_id,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      CONCAT(
        'Analyze complete customer journey combining purchase history, support interactions, and visual evidence. ',
        'Customer segment: ', segment,
        ', Lifetime value: $', CAST(lifetime_value AS STRING),
        ', Satisfaction: ', CAST(satisfaction_score AS STRING),
        ', Categories purchased: ', ARRAY_TO_STRING(purchased_categories, ', '),
        ', Support issues: ', ARRAY_TO_STRING(support_issues, '; '),
        ', Total orders: ', CAST(total_orders AS STRING),
        ', Average order: $', CAST(avg_order_value AS STRING),
        '. Provide personalized retention and upselling strategies.'
      ),
      STRUCT(support_images[SAFE_OFFSET(0)] AS uri)
    ) AS journey_analysis,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Rate customer churn risk from 0.0 (loyal) to 1.0 (high risk) based on: ',
        'Satisfaction: ', CAST(satisfaction_score AS STRING),
        ', Support issues: ', ARRAY_LENGTH(support_issues),
        ', Recent activity: ', CAST(total_orders AS STRING), ' orders'
      )
    ) AS churn_risk_score,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Recommend next best actions for this customer: ',
        'Segment: ', segment,
        ', Value: $', CAST(lifetime_value AS STRING),
        ', Categories: ', ARRAY_TO_STRING(purchased_categories, ', ')
      )
    ) AS next_best_actions,
    CURRENT_TIMESTAMP() AS analyzed_at
  ))
  FROM customer_context
);

-- Create function for comprehensive market intelligence analysis
CREATE OR REPLACE FUNCTION `enterprise_knowledge_ai.comprehensive_market_analysis`()
RETURNS JSON
LANGUAGE SQL
AS (
  WITH market_context AS (
    SELECT 
      COUNT(DISTINCT p.product_id) AS total_products,
      COUNT(DISTINCT p.category) AS total_categories,
      AVG(p.price) AS avg_price,
      SUM(s.total_sales) AS total_revenue,
      AVG(s.avg_rating) AS overall_rating,
      COUNT(DISTINCT c.customer_id) AS total_customers,
      COUNT(DISTINCT t.ticket_id) AS total_support_tickets,
      ARRAY_AGG(DISTINCT p.image_ref IGNORE NULLS LIMIT 10) AS sample_product_images
    FROM product_catalog_objects p
    LEFT JOIN product_sales_metrics s ON p.product_id = s.product_id
    LEFT JOIN customers c ON TRUE
    LEFT JOIN support_ticket_objects t ON TRUE
  )
  SELECT TO_JSON(STRUCT(
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      CONCAT(
        'Perform comprehensive market analysis combining product portfolio, customer data, and visual trends. ',
        'Portfolio: ', CAST(total_products AS STRING), ' products across ', CAST(total_categories AS STRING), ' categories, ',
        'Average price: $', CAST(avg_price AS STRING),
        ', Total revenue: $', CAST(total_revenue AS STRING),
        ', Overall rating: ', CAST(overall_rating AS STRING),
        ', Customer base: ', CAST(total_customers AS STRING),
        ', Support volume: ', CAST(total_support_tickets AS STRING),
        '. Identify market opportunities and competitive positioning.'
      ),
      STRUCT(sample_product_images[SAFE_OFFSET(0)] AS uri)
    ) AS market_intelligence,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.multimodal_model`,
      CONCAT(
        'Analyze visual trends across product portfolio and recommend design improvements: ',
        'Total products: ', CAST(total_products AS STRING),
        ', Categories: ', CAST(total_categories AS STRING),
        ', Average rating: ', CAST(overall_rating AS STRING)
      ),
      STRUCT(sample_product_images[SAFE_OFFSET(1)] AS uri)
    ) AS visual_trend_analysis,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Rate overall market position strength from 0.0 to 1.0 based on: ',
        'Revenue: $', CAST(total_revenue AS STRING),
        ', Rating: ', CAST(overall_rating AS STRING),
        ', Portfolio size: ', CAST(total_products AS STRING)
      )
    ) AS market_strength_score,
    CURRENT_TIMESTAMP() AS analyzed_at
  ))
  FROM market_context
);

-- Create procedure for comprehensive business intelligence generation
CREATE OR REPLACE PROCEDURE `enterprise_knowledge_ai.generate_comprehensive_intelligence`()
BEGIN
  -- Create comprehensive analysis results table
  CREATE OR REPLACE TABLE `enterprise_knowledge_ai.comprehensive_analysis_results` AS
  WITH product_analyses AS (
    SELECT 
      'product_analysis' AS analysis_type,
      p.product_id AS entity_id,
      `enterprise_knowledge_ai.comprehensive_product_analysis`(p.product_id) AS analysis_result,
      CURRENT_TIMESTAMP() AS created_at
    FROM product_catalog_objects p
    WHERE p.image_ref IS NOT NULL
    LIMIT 100  -- Process top products first
  ),
  
  customer_analyses AS (
    SELECT 
      'customer_journey' AS analysis_type,
      c.customer_id AS entity_id,
      `enterprise_knowledge_ai.comprehensive_customer_journey_analysis`(c.customer_id) AS analysis_result,
      CURRENT_TIMESTAMP() AS created_at
    FROM customers c
    WHERE c.lifetime_value > 1000  -- Focus on high-value customers
    LIMIT 50
  ),
  
  market_analysis AS (
    SELECT 
      'market_intelligence' AS analysis_type,
      'global' AS entity_id,
      `enterprise_knowledge_ai.comprehensive_market_analysis`() AS analysis_result,
      CURRENT_TIMESTAMP() AS created_at
  )
  
  SELECT * FROM product_analyses
  UNION ALL
  SELECT * FROM customer_analyses
  UNION ALL
  SELECT * FROM market_analysis;
  
  -- Generate executive summary insights
  INSERT INTO generated_insights (
    insight_id,
    source_data_ids,
    insight_type,
    content,
    confidence_score,
    business_impact_score,
    target_audience,
    expiration_timestamp
  )
  SELECT 
    GENERATE_UUID() AS insight_id,
    [entity_id] AS source_data_ids,
    'comprehensive_intelligence' AS insight_type,
    AI.GENERATE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Create executive summary from comprehensive analysis: ',
        JSON_EXTRACT_SCALAR(analysis_result, '$.comprehensive_analysis'),
        '. Focus on key strategic recommendations and business impact.'
      )
    ) AS content,
    0.9 AS confidence_score,
    AI.GENERATE_DOUBLE(
      MODEL `enterprise_knowledge_ai.gemini_model`,
      CONCAT(
        'Rate business impact from 0.0 to 1.0: ',
        JSON_EXTRACT_SCALAR(analysis_result, '$.comprehensive_analysis')
      )
    ) AS business_impact_score,
    ['executives', 'strategy_team'] AS target_audience,
    TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 7 DAY) AS expiration_timestamp
  FROM comprehensive_analysis_results
  WHERE analysis_type IN ('product_analysis', 'market_intelligence');
  
  -- Generate personalized customer insights
  INSERT INTO generated_insights (
    insight_id,
    source_data_ids,
    insight_type,
    content,
    confidence_score,
    business_impact_score,
    target_audience,
    expiration_timestamp
  )
  SELECT 
    GENERATE_UUID() AS insight_id,
    [entity_id] AS source_data_ids,
    'customer_intelligence' AS insight_type,
    JSON_EXTRACT_SCALAR(analysis_result, '$.next_best_actions') AS content,
    0.85 AS confidence_score,
    CAST(JSON_EXTRACT_SCALAR(analysis_result, '$.churn_risk_score') AS FLOAT64) AS business_impact_score,
    ['customer_success', 'sales_team'] AS target_audience,
    TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 3 DAY) AS expiration_timestamp
  FROM comprehensive_analysis_results
  WHERE analysis_type = 'customer_journey';
END;