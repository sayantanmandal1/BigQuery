"""
Enterprise Knowledge Intelligence Platform - REST API
Provides programmatic access to insights, forecasts, and analytics
"""

from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import json
import logging
from google.cloud import bigquery
import os

# Initialize FastAPI app
app = FastAPI(
    title="Enterprise Knowledge Intelligence API",
    description="REST API for accessing AI-powered business insights and analytics",
    version="1.0.0"
)

# Configure CORS for web interface access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize BigQuery client
client = bigquery.Client()
security = HTTPBearer()

# Pydantic models for API requests/responses
class InsightRequest(BaseModel):
    query: str = Field(..., description="Natural language query for insights")
    user_role: Optional[str] = Field(None, description="User role for personalization")
    context: Optional[Dict[str, Any]] = Field(None, description="Additional context")

class InsightResponse(BaseModel):
    insight_id: str
    content: str
    confidence_score: float
    business_impact_score: float
    generated_timestamp: datetime
    sources: List[str]

class ForecastRequest(BaseModel):
    metric_name: str = Field(..., description="Business metric to forecast")
    horizon_days: int = Field(30, description="Forecast horizon in days")
    confidence_level: float = Field(0.95, description="Confidence level for intervals")

class ForecastResponse(BaseModel):
    metric_name: str
    forecast_values: List[Dict[str, Any]]
    confidence_intervals: List[Dict[str, Any]]
    strategic_recommendations: str

class UserPreferences(BaseModel):
    user_id: str
    role: str
    departments: List[str]
    notification_preferences: Dict[str, bool]
    priority_topics: List[str]

# Authentication dependency
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Validate user authentication token"""
    # In production, implement proper JWT validation
    if not credentials.credentials:
        raise HTTPException(status_code=401, detail="Invalid authentication")
    return {"user_id": "demo_user", "role": "analyst"}

@app.get("/")
async def root():
    """API health check endpoint"""
    return {"message": "Enterprise Knowledge Intelligence API", "status": "active"}

@app.post("/insights/generate", response_model=InsightResponse)
async def generate_insight(
    request: InsightRequest,
    current_user: dict = Depends(get_current_user)
):
    """Generate AI-powered insights based on natural language query"""
    try:
        # Execute semantic search and insight generation
        query = f"""
        WITH semantic_search AS (
          SELECT 
            knowledge_id,
            content,
            VECTOR_SEARCH(
              TABLE `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.enterprise_knowledge_base`,
              (SELECT ML.GENERATE_EMBEDDING(
                MODEL `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.text_embedding_model`,
                @query_text
              )),
              top_k => 5,
              distance_type => 'COSINE'
            ) AS similarity_score
          FROM `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.enterprise_knowledge_base`
          WHERE access_permissions IS NULL OR @user_role IN UNNEST(access_permissions)
        ),
        insight_generation AS (
          SELECT 
            GENERATE_UUID() as insight_id,
            AI.GENERATE(
              MODEL `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.gemini_model`,
              CONCAT(
                'Generate actionable business insight for: ', @query_text,
                ' Based on context: ', STRING_AGG(content, ' | ')
              )
            ) AS generated_insight,
            0.85 AS confidence_score,
            0.75 AS business_impact_score,
            CURRENT_TIMESTAMP() AS generated_timestamp,
            ARRAY_AGG(knowledge_id) AS source_ids
          FROM semantic_search
          WHERE similarity_score > 0.7
        )
        SELECT * FROM insight_generation
        """
        
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("query_text", "STRING", request.query),
                bigquery.ScalarQueryParameter("user_role", "STRING", request.user_role or current_user["role"])
            ]
        )
        
        query_job = client.query(query, job_config=job_config)
        results = query_job.result()
        
        for row in results:
            return InsightResponse(
                insight_id=row.insight_id,
                content=row.generated_insight,
                confidence_score=row.confidence_score,
                business_impact_score=row.business_impact_score,
                generated_timestamp=row.generated_timestamp,
                sources=row.source_ids
            )
            
        raise HTTPException(status_code=404, detail="No relevant insights found")
        
    except Exception as e:
        logging.error(f"Error generating insight: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to generate insight")

@app.post("/forecasts/generate", response_model=ForecastResponse)
async def generate_forecast(
    request: ForecastRequest,
    current_user: dict = Depends(get_current_user)
):
    """Generate predictive forecasts for business metrics"""
    try:
        query = f"""
        WITH forecast_data AS (
          SELECT 
            forecast_timestamp,
            forecast_value,
            confidence_level_lower,
            confidence_level_upper
          FROM ML.FORECAST(
            MODEL `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.forecast_model_{request.metric_name}`,
            STRUCT({request.horizon_days} AS horizon, {request.confidence_level} AS confidence_level)
          )
        ),
        strategic_analysis AS (
          SELECT 
            AI.GENERATE(
              MODEL `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.gemini_model`,
              CONCAT(
                'Analyze forecast trends and provide strategic recommendations for metric: ',
                @metric_name,
                ' Forecast data: ', 
                STRING_AGG(
                  CONCAT('Date: ', CAST(forecast_timestamp AS STRING), 
                         ', Value: ', CAST(forecast_value AS STRING)), 
                  ' | '
                )
              )
            ) AS recommendations
          FROM forecast_data
        )
        SELECT 
          f.*,
          s.recommendations
        FROM forecast_data f
        CROSS JOIN strategic_analysis s
        """
        
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("metric_name", "STRING", request.metric_name)
            ]
        )
        
        query_job = client.query(query, job_config=job_config)
        results = query_job.result()
        
        forecast_values = []
        confidence_intervals = []
        recommendations = ""
        
        for row in results:
            forecast_values.append({
                "timestamp": row.forecast_timestamp.isoformat(),
                "value": float(row.forecast_value)
            })
            confidence_intervals.append({
                "timestamp": row.forecast_timestamp.isoformat(),
                "lower": float(row.confidence_level_lower),
                "upper": float(row.confidence_level_upper)
            })
            recommendations = row.recommendations
        
        return ForecastResponse(
            metric_name=request.metric_name,
            forecast_values=forecast_values,
            confidence_intervals=confidence_intervals,
            strategic_recommendations=recommendations
        )
        
    except Exception as e:
        logging.error(f"Error generating forecast: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to generate forecast")

@app.get("/insights/personalized")
async def get_personalized_insights(
    limit: int = Query(10, description="Number of insights to return"),
    current_user: dict = Depends(get_current_user)
):
    """Get personalized insights based on user role and preferences"""
    try:
        query = f"""
        WITH personalized_insights AS (
          SELECT 
            insight_id,
            content,
            confidence_score,
            business_impact_score,
            generated_timestamp,
            AI.GENERATE_DOUBLE(
              MODEL `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.gemini_model`,
              CONCAT('Rate relevance for role ', @user_role, ': ', content)
            ) AS relevance_score
          FROM `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.generated_insights`
          WHERE @user_role IN UNNEST(target_audience)
            AND generated_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
        )
        SELECT *
        FROM personalized_insights
        ORDER BY relevance_score DESC, business_impact_score DESC
        LIMIT @limit_count
        """
        
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("user_role", "STRING", current_user["role"]),
                bigquery.ScalarQueryParameter("limit_count", "INT64", limit)
            ]
        )
        
        query_job = client.query(query, job_config=job_config)
        results = query_job.result()
        
        insights = []
        for row in results:
            insights.append({
                "insight_id": row.insight_id,
                "content": row.content,
                "confidence_score": row.confidence_score,
                "business_impact_score": row.business_impact_score,
                "relevance_score": row.relevance_score,
                "generated_timestamp": row.generated_timestamp.isoformat()
            })
        
        return {"insights": insights, "total_count": len(insights)}
        
    except Exception as e:
        logging.error(f"Error fetching personalized insights: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to fetch personalized insights")

@app.get("/analytics/dashboard")
async def get_dashboard_data(current_user: dict = Depends(get_current_user)):
    """Get comprehensive dashboard data for executive view"""
    try:
        # Fetch key metrics, recent insights, and trend data
        query = f"""
        WITH key_metrics AS (
          SELECT 
            'total_insights' as metric_name,
            COUNT(*) as metric_value
          FROM `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.generated_insights`
          WHERE DATE(generated_timestamp) = CURRENT_DATE()
          
          UNION ALL
          
          SELECT 
            'avg_confidence' as metric_name,
            AVG(confidence_score) as metric_value
          FROM `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.generated_insights`
          WHERE DATE(generated_timestamp) = CURRENT_DATE()
        ),
        recent_insights AS (
          SELECT 
            insight_id,
            content,
            business_impact_score,
            generated_timestamp
          FROM `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.generated_insights`
          WHERE generated_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
          ORDER BY business_impact_score DESC
          LIMIT 5
        )
        SELECT 
          'metrics' as data_type,
          TO_JSON_STRING(ARRAY_AGG(STRUCT(metric_name, metric_value))) as data
        FROM key_metrics
        
        UNION ALL
        
        SELECT 
          'recent_insights' as data_type,
          TO_JSON_STRING(ARRAY_AGG(STRUCT(insight_id, content, business_impact_score, generated_timestamp))) as data
        FROM recent_insights
        """
        
        query_job = client.query(query)
        results = query_job.result()
        
        dashboard_data = {}
        for row in results:
            dashboard_data[row.data_type] = json.loads(row.data)
        
        return dashboard_data
        
    except Exception as e:
        logging.error(f"Error fetching dashboard data: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to fetch dashboard data")

@app.post("/users/preferences")
async def update_user_preferences(
    preferences: UserPreferences,
    current_user: dict = Depends(get_current_user)
):
    """Update user preferences for personalized content delivery"""
    try:
        # Store user preferences in BigQuery
        query = f"""
        INSERT INTO `{os.getenv('BIGQUERY_PROJECT')}.enterprise_ai.user_preferences`
        (user_id, role, departments, notification_preferences, priority_topics, updated_timestamp)
        VALUES (
          @user_id,
          @role,
          @departments,
          @notification_preferences,
          @priority_topics,
          CURRENT_TIMESTAMP()
        )
        """
        
        job_config = bigquery.QueryJobConfig(
            query_parameters=[
                bigquery.ScalarQueryParameter("user_id", "STRING", preferences.user_id),
                bigquery.ScalarQueryParameter("role", "STRING", preferences.role),
                bigquery.ArrayQueryParameter("departments", "STRING", preferences.departments),
                bigquery.ScalarQueryParameter("notification_preferences", "JSON", json.dumps(preferences.notification_preferences)),
                bigquery.ArrayQueryParameter("priority_topics", "STRING", preferences.priority_topics)
            ]
        )
        
        query_job = client.query(query, job_config=job_config)
        query_job.result()
        
        return {"message": "User preferences updated successfully"}
        
    except Exception as e:
        logging.error(f"Error updating user preferences: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to update user preferences")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)