# 📊 FIXED Advanced BigQuery Content Analysis - COPY THIS CELL
def analyze_content_patterns():
    """Analyze content patterns using advanced BigQuery - FIXED VERSION"""
    
    print("🔍 Executing Advanced BigQuery Content Analysis...")
    
    content_query = f"""
    SELECT 
      -- Content categorization
      CASE 
        WHEN REGEXP_CONTAINS(LOWER(title), r'\\b(ai|artificial intelligence|machine learning|ml|gpt|chatgpt)\\b') THEN 'AI_TECH'
        WHEN REGEXP_CONTAINS(LOWER(title), r'\\b(startup|funding|investment|vc|venture)\\b') THEN 'STARTUP'
        WHEN REGEXP_CONTAINS(LOWER(title), r'\\b(security|privacy|hack|breach|cyber)\\b') THEN 'SECURITY'
        WHEN REGEXP_CONTAINS(LOWER(title), r'\\b(crypto|bitcoin|blockchain|ethereum)\\b') THEN 'CRYPTO'
        WHEN REGEXP_CONTAINS(LOWER(title), r'\\b(google|apple|microsoft|amazon|meta|tesla)\\b') THEN 'BIG_TECH'
        WHEN REGEXP_CONTAINS(LOWER(title), r'\\b(programming|code|developer|software)\\b') THEN 'PROGRAMMING'
        ELSE 'GENERAL'
      END as content_category,
      
      COUNT(*) as post_count,
      AVG(score) as avg_score,
      STDDEV(score) as score_stddev,
      AVG(descendants) as avg_comments,
      AVG(LENGTH(title)) as avg_title_length,
      AVG(CASE WHEN url IS NOT NULL THEN 1 ELSE 0 END) as url_percentage,
      
      -- Engagement efficiency
      ROUND(AVG(descendants) / NULLIF(AVG(score), 0), 2) as comment_to_score_ratio,
      
      -- Performance classification
      CASE 
        WHEN AVG(score) > 20 THEN 'HIGH_PERFORMANCE'
        WHEN AVG(score) > 10 THEN 'MEDIUM_PERFORMANCE'
        ELSE 'LOW_PERFORMANCE'
      END as performance_tier,
      
      -- Market potential
      CASE 
        WHEN COUNT(*) > 100 AND AVG(score) > 15 THEN 'HIGH_POTENTIAL'
        WHEN COUNT(*) > 50 AND AVG(score) > 8 THEN 'MEDIUM_POTENTIAL'
        ELSE 'LOW_POTENTIAL'
      END as market_potential
      
    FROM `bigquery-public-data.hacker_news.full`
    WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
      AND score IS NOT NULL
      AND score > 0
      AND type = 'story'
      AND title IS NOT NULL
    GROUP BY content_category
    ORDER BY avg_score DESC
    """
    
    print("⚡ Executing Advanced Content Analysis Query...")
    result = client.query(content_query).to_dataframe()
    print(f"✅ Analyzed {len(result)} content categories")
    
    return result

# Execute advanced content analysis
content_data = analyze_content_patterns()

print("\n📊 ADVANCED BIGQUERY CONTENT INSIGHTS:")
print("=" * 60)

# Display top performing categories
print("🏆 TOP PERFORMING CONTENT CATEGORIES:")
for idx, row in content_data.head(5).iterrows():
    print(f"🎯 {row['content_category']}: Score {row['avg_score']:.1f} | {row['post_count']} posts | {row['market_potential']} potential")

print(f"\n📈 Total Posts Analyzed: {content_data['post_count'].sum():,}")
print(f"🚀 Data Source: Real BigQuery Hacker News Dataset")

content_data