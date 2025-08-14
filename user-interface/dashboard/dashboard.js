/**
 * Executive Dashboard JavaScript
 * Handles data fetching, UI interactions, and real-time updates
 */

class ExecutiveDashboard {
    constructor() {
        this.apiBaseUrl = 'http://localhost:8000';
        this.refreshInterval = 30000; // 30 seconds
        this.forecastChart = null;
        this.init();
    }

    async init() {
        await this.loadDashboardData();
        this.initializeCharts();
        this.setupEventListeners();
        this.startAutoRefresh();
    }

    async loadDashboardData() {
        try {
            // Load key metrics
            await this.loadKeyMetrics();
            
            // Load personalized insights
            await this.loadPersonalizedInsights();
            
            // Load recent activity
            await this.loadRecentActivity();
            
            // Load forecast data
            await this.loadForecastData();
            
        } catch (error) {
            console.error('Error loading dashboard data:', error);
            this.showError('Failed to load dashboard data. Please refresh the page.');
        }
    }

    async loadKeyMetrics() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/analytics/dashboard`, {
                headers: {
                    'Authorization': `Bearer ${this.getAuthToken()}`
                }
            });
            
            if (!response.ok) throw new Error('Failed to fetch metrics');
            
            const data = await response.json();
            
            // Update metric cards
            if (data.metrics) {
                data.metrics.forEach(metric => {
                    this.updateMetricCard(metric.metric_name, metric.metric_value);
                });
            }
            
        } catch (error) {
            console.error('Error loading metrics:', error);
            // Set default values
            this.updateMetricCard('total_insights', 0);
            this.updateMetricCard('avg_confidence', 0);
        }
    }

    updateMetricCard(metricName, value) {
        const formatValue = (name, val) => {
            switch (name) {
                case 'total_insights':
                    document.getElementById('totalInsights').textContent = val.toLocaleString();
                    break;
                case 'avg_confidence':
                    document.getElementById('avgConfidence').textContent = `${(val * 100).toFixed(1)}%`;
                    break;
                case 'active_alerts':
                    document.getElementById('activeAlerts').textContent = val.toLocaleString();
                    break;
                case 'forecast_accuracy':
                    document.getElementById('forecastAccuracy').textContent = `${(val * 100).toFixed(1)}%`;
                    break;
            }
        };
        
        formatValue(metricName, value);
    }

    async loadPersonalizedInsights() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/insights/personalized?limit=5`, {
                headers: {
                    'Authorization': `Bearer ${this.getAuthToken()}`
                }
            });
            
            if (!response.ok) throw new Error('Failed to fetch insights');
            
            const data = await response.json();
            this.renderInsights(data.insights || []);
            
        } catch (error) {
            console.error('Error loading insights:', error);
            this.renderInsights([]);
        }
    }

    renderInsights(insights) {
        const container = document.getElementById('insightsContainer');
        
        if (insights.length === 0) {
            container.innerHTML = `
                <div class="text-center py-4 text-muted">
                    <i class="fas fa-lightbulb fa-3x mb-3 opacity-50"></i>
                    <p>No insights available. Generate new insights to get started.</p>
                    <button class="btn btn-primary" onclick="dashboard.generateInsight()">
                        <i class="fas fa-magic me-2"></i>Generate Insight
                    </button>
                </div>
            `;
            return;
        }

        const insightsHtml = insights.map(insight => `
            <div class="insight-item fade-in">
                <div class="insight-header">
                    <div class="insight-meta">
                        <small class="text-muted">
                            <i class="fas fa-clock me-1"></i>
                            ${this.formatTimestamp(insight.generated_timestamp)}
                        </small>
                    </div>
                    <div class="d-flex gap-2">
                        <span class="badge confidence-badge ${this.getConfidenceBadgeClass(insight.confidence_score)}">
                            ${(insight.confidence_score * 100).toFixed(0)}% confidence
                        </span>
                        <div class="impact-score">
                            <span class="impact-stars">
                                ${this.renderStars(insight.business_impact_score)}
                            </span>
                        </div>
                    </div>
                </div>
                <div class="insight-content">
                    <p class="mb-2">${insight.content}</p>
                </div>
                <div class="insight-actions">
                    <button class="btn btn-sm btn-outline-primary me-2" onclick="dashboard.shareInsight('${insight.insight_id}')">
                        <i class="fas fa-share me-1"></i>Share
                    </button>
                    <button class="btn btn-sm btn-outline-secondary" onclick="dashboard.viewInsightDetails('${insight.insight_id}')">
                        <i class="fas fa-eye me-1"></i>Details
                    </button>
                </div>
            </div>
        `).join('');

        container.innerHTML = insightsHtml;
    }

    async loadRecentActivity() {
        // Simulate recent activity data
        const activities = [
            {
                time: new Date(Date.now() - 1000 * 60 * 15),
                type: 'Insight',
                description: 'Revenue forecast updated with Q4 projections',
                impact: 'High',
                status: 'completed'
            },
            {
                time: new Date(Date.now() - 1000 * 60 * 45),
                type: 'Alert',
                description: 'Anomaly detected in customer acquisition metrics',
                impact: 'Medium',
                status: 'pending'
            },
            {
                time: new Date(Date.now() - 1000 * 60 * 120),
                type: 'Forecast',
                description: 'Market share prediction generated for next quarter',
                impact: 'High',
                status: 'completed'
            }
        ];

        this.renderRecentActivity(activities);
    }

    renderRecentActivity(activities) {
        const tbody = document.getElementById('activityTable');
        
        const activitiesHtml = activities.map(activity => `
            <tr class="slide-in">
                <td>${this.formatTimestamp(activity.time)}</td>
                <td>
                    <span class="badge bg-light text-dark">
                        <i class="fas fa-${this.getActivityIcon(activity.type)} me-1"></i>
                        ${activity.type}
                    </span>
                </td>
                <td>${activity.description}</td>
                <td>
                    <span class="badge ${this.getImpactBadgeClass(activity.impact)}">
                        ${activity.impact}
                    </span>
                </td>
                <td>
                    <span class="status-badge status-${activity.status}">
                        ${activity.status.charAt(0).toUpperCase() + activity.status.slice(1)}
                    </span>
                </td>
                <td>
                    <button class="btn btn-sm btn-outline-primary">
                        <i class="fas fa-eye"></i>
                    </button>
                </td>
            </tr>
        `).join('');

        tbody.innerHTML = activitiesHtml;
    }

    async loadForecastData() {
        // Simulate forecast data for chart
        const forecastData = {
            labels: this.generateDateLabels(30),
            datasets: [{
                label: 'Revenue Forecast',
                data: this.generateForecastData(30),
                borderColor: 'rgb(13, 110, 253)',
                backgroundColor: 'rgba(13, 110, 253, 0.1)',
                tension: 0.4,
                fill: true
            }]
        };

        this.updateForecastChart(forecastData);
    }

    initializeCharts() {
        const ctx = document.getElementById('forecastChart').getContext('2d');
        
        this.forecastChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: []
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: false,
                        grid: {
                            color: 'rgba(0, 0, 0, 0.1)'
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        }
                    }
                },
                elements: {
                    point: {
                        radius: 3,
                        hoverRadius: 6
                    }
                }
            }
        });
    }

    updateForecastChart(data) {
        if (this.forecastChart) {
            this.forecastChart.data = data;
            this.forecastChart.update();
        }
    }

    setupEventListeners() {
        // Set up modal event listeners
        document.addEventListener('DOMContentLoaded', () => {
            // Any additional setup after DOM is loaded
        });
    }

    startAutoRefresh() {
        setInterval(() => {
            this.loadDashboardData();
        }, this.refreshInterval);
    }

    // Utility Methods
    getAuthToken() {
        // In production, implement proper token management
        return 'demo-token';
    }

    formatTimestamp(timestamp) {
        const date = new Date(timestamp);
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'Just now';
        if (diffMins < 60) return `${diffMins}m ago`;
        if (diffHours < 24) return `${diffHours}h ago`;
        if (diffDays < 7) return `${diffDays}d ago`;
        
        return date.toLocaleDateString();
    }

    getConfidenceBadgeClass(score) {
        if (score >= 0.8) return 'bg-success';
        if (score >= 0.6) return 'bg-warning';
        return 'bg-danger';
    }

    renderStars(score) {
        const stars = Math.round(score * 5);
        return '★'.repeat(stars) + '☆'.repeat(5 - stars);
    }

    getActivityIcon(type) {
        const icons = {
            'Insight': 'lightbulb',
            'Alert': 'exclamation-triangle',
            'Forecast': 'chart-line',
            'Report': 'file-alt'
        };
        return icons[type] || 'circle';
    }

    getImpactBadgeClass(impact) {
        const classes = {
            'High': 'bg-danger',
            'Medium': 'bg-warning',
            'Low': 'bg-success'
        };
        return classes[impact] || 'bg-secondary';
    }

    generateDateLabels(days) {
        const labels = [];
        const today = new Date();
        
        for (let i = 0; i < days; i++) {
            const date = new Date(today);
            date.setDate(today.getDate() + i);
            labels.push(date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));
        }
        
        return labels;
    }

    generateForecastData(days) {
        const data = [];
        let baseValue = 100000;
        
        for (let i = 0; i < days; i++) {
            baseValue += (Math.random() - 0.5) * 10000 + 1000;
            data.push(Math.round(baseValue));
        }
        
        return data;
    }

    showError(message) {
        // Simple error display - in production, use a proper notification system
        console.error(message);
        alert(message);
    }

    // Public Methods for UI Interactions
    async refreshInsights() {
        const button = event.target.closest('button');
        const originalHtml = button.innerHTML;
        
        button.innerHTML = '<i class="fas fa-spinner fa-spin me-1"></i>Refreshing...';
        button.disabled = true;
        
        try {
            await this.loadPersonalizedInsights();
        } finally {
            button.innerHTML = originalHtml;
            button.disabled = false;
        }
    }

    generateInsight() {
        const modal = new bootstrap.Modal(document.getElementById('insightModal'));
        modal.show();
    }

    async submitInsightRequest() {
        const query = document.getElementById('insightQuery').value;
        const context = document.getElementById('contextSelect').value;
        
        if (!query.trim()) {
            alert('Please enter a query for insight generation.');
            return;
        }

        try {
            const response = await fetch(`${this.apiBaseUrl}/insights/generate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.getAuthToken()}`
                },
                body: JSON.stringify({
                    query: query,
                    user_role: 'executive',
                    context: { type: context }
                })
            });

            if (!response.ok) throw new Error('Failed to generate insight');

            const insight = await response.json();
            
            // Close modal and refresh insights
            bootstrap.Modal.getInstance(document.getElementById('insightModal')).hide();
            document.getElementById('insightQuery').value = '';
            
            await this.loadPersonalizedInsights();
            
        } catch (error) {
            console.error('Error generating insight:', error);
            alert('Failed to generate insight. Please try again.');
        }
    }

    showForecastModal() {
        const modal = new bootstrap.Modal(document.getElementById('forecastModal'));
        modal.show();
    }

    async submitForecastRequest() {
        const metric = document.getElementById('metricSelect').value;
        const horizon = parseInt(document.getElementById('horizonInput').value);
        const confidence = parseFloat(document.getElementById('confidenceInput').value);

        try {
            const response = await fetch(`${this.apiBaseUrl}/forecasts/generate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.getAuthToken()}`
                },
                body: JSON.stringify({
                    metric_name: metric,
                    horizon_days: horizon,
                    confidence_level: confidence
                })
            });

            if (!response.ok) throw new Error('Failed to generate forecast');

            const forecast = await response.json();
            
            // Update chart with new forecast data
            const chartData = {
                labels: forecast.forecast_values.map(f => new Date(f.timestamp).toLocaleDateString()),
                datasets: [{
                    label: `${metric} Forecast`,
                    data: forecast.forecast_values.map(f => f.value),
                    borderColor: 'rgb(13, 110, 253)',
                    backgroundColor: 'rgba(13, 110, 253, 0.1)',
                    tension: 0.4,
                    fill: true
                }]
            };
            
            this.updateForecastChart(chartData);
            
            // Close modal
            bootstrap.Modal.getInstance(document.getElementById('forecastModal')).hide();
            
        } catch (error) {
            console.error('Error generating forecast:', error);
            alert('Failed to generate forecast. Please try again.');
        }
    }

    exportReport() {
        // Simulate report export
        alert('Report export functionality would be implemented here.');
    }

    shareInsight(insightId) {
        // Simulate insight sharing
        alert(`Sharing insight ${insightId} - functionality would be implemented here.`);
    }

    viewInsightDetails(insightId) {
        // Simulate viewing insight details
        alert(`Viewing details for insight ${insightId} - functionality would be implemented here.`);
    }

    showSettings() {
        alert('Settings panel would be implemented here.');
    }
}

// Initialize dashboard when page loads
let dashboard;
document.addEventListener('DOMContentLoaded', () => {
    dashboard = new ExecutiveDashboard();
});

// Global functions for HTML onclick handlers
function refreshInsights() {
    dashboard.refreshInsights();
}

function generateInsight() {
    dashboard.generateInsight();
}

function submitInsightRequest() {
    dashboard.submitInsightRequest();
}

function showForecastModal() {
    dashboard.showForecastModal();
}

function submitForecastRequest() {
    dashboard.submitForecastRequest();
}

function exportReport() {
    dashboard.exportReport();
}

function showSettings() {
    dashboard.showSettings();
}