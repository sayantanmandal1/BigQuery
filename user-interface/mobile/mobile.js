/**
 * Mobile Interface JavaScript
 * Handles mobile-specific interactions and responsive behavior
 */

class MobileInterface {
    constructor() {
        this.apiBaseUrl = 'http://localhost:8000';
        this.currentSection = 'dashboard';
        this.refreshInterval = 60000; // 1 minute
        this.trendChart = null;
        this.notifications = [];
        this.settings = {
            pushNotifications: true,
            emailNotifications: true,
            refreshInterval: 60,
            defaultView: 'dashboard'
        };
        this.init();
    }

    async init() {
        await this.loadSettings();
        await this.loadDashboardData();
        this.initializeChart();
        this.setupEventListeners();
        this.startAutoRefresh();
        this.loadNotifications();
    }

    setupEventListeners() {
        // Touch events for better mobile interaction
        document.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: true });
        
        // Handle back button
        window.addEventListener('popstate', this.handleBackButton.bind(this));
        
        // Handle orientation change
        window.addEventListener('orientationchange', this.handleOrientationChange.bind(this));
        
        // Handle visibility change (app backgrounding)
        document.addEventListener('visibilitychange', this.handleVisibilityChange.bind(this));
        
        // Search input handling
        document.getElementById('mobileSearchInput').addEventListener('input', 
            this.debounce(this.handleSearchInput.bind(this), 300));
    }

    handleTouchStart(event) {
        // Add touch feedback for interactive elements
        const target = event.target.closest('.touchable, .card, .btn, .list-group-item');
        if (target) {
            target.style.transform = 'scale(0.98)';
            setTimeout(() => {
                target.style.transform = '';
            }, 150);
        }
    }

    handleBackButton(event) {
        // Handle browser back button for single-page navigation
        const section = window.location.hash.replace('#', '') || 'dashboard';
        this.showSection(section);
    }

    handleOrientationChange() {
        // Adjust layout for orientation changes
        setTimeout(() => {
            if (this.trendChart) {
                this.trendChart.resize();
            }
        }, 100);
    }

    handleVisibilityChange() {
        if (document.hidden) {
            // App went to background - pause updates
            this.pauseUpdates();
        } else {
            // App came to foreground - resume updates
            this.resumeUpdates();
        }
    }

    handleSearchInput(event) {
        const query = event.target.value;
        if (query.length > 2) {
            this.showSearchSuggestions(query);
        }
    }

    async loadDashboardData() {
        try {
            // Load key metrics
            await this.loadMobileMetrics();
            
            // Load recent activity
            await this.loadMobileActivity();
            
            // Load trend data
            await this.loadTrendData();
            
        } catch (error) {
            console.error('Error loading dashboard data:', error);
            this.showError('Failed to load dashboard data');
        }
    }

    async loadMobileMetrics() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/analytics/dashboard`, {
                headers: {
                    'Authorization': `Bearer ${this.getAuthToken()}`
                }
            });
            
            if (!response.ok) throw new Error('Failed to fetch metrics');
            
            const data = await response.json();
            
            // Update mobile metric cards
            document.getElementById('mobileInsightsCount').textContent = 
                data.metrics?.find(m => m.metric_name === 'total_insights')?.metric_value || '0';
            
            const avgConfidence = data.metrics?.find(m => m.metric_name === 'avg_confidence')?.metric_value || 0;
            document.getElementById('mobileConfidence').textContent = `${(avgConfidence * 100).toFixed(0)}%`;
            
            document.getElementById('mobileAlerts').textContent = '2';
            document.getElementById('mobileForecast').textContent = '94%';
            
        } catch (error) {
            console.error('Error loading mobile metrics:', error);
            // Set default values
            document.getElementById('mobileInsightsCount').textContent = '0';
            document.getElementById('mobileConfidence').textContent = '0%';
            document.getElementById('mobileAlerts').textContent = '0';
            document.getElementById('mobileForecast').textContent = '0%';
        }
    }

    async loadMobileActivity() {
        const activities = [
            {
                type: 'insight',
                title: 'Revenue forecast updated',
                description: 'Q4 projections show 15% growth',
                time: new Date(Date.now() - 1000 * 60 * 15),
                priority: 'high'
            },
            {
                type: 'alert',
                title: 'Anomaly detected',
                description: 'Customer acquisition costs spike',
                time: new Date(Date.now() - 1000 * 60 * 45),
                priority: 'medium'
            },
            {
                type: 'forecast',
                title: 'Market share prediction',
                description: 'Next quarter forecast generated',
                time: new Date(Date.now() - 1000 * 60 * 120),
                priority: 'low'
            }
        ];

        this.renderMobileActivity(activities);
    }

    renderMobileActivity(activities) {
        const container = document.getElementById('mobileActivityList');
        
        const activitiesHtml = activities.map(activity => `
            <div class="activity-item touchable" onclick="mobileApp.viewActivityDetails('${activity.type}')">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <div class="d-flex align-items-center mb-1">
                            <span class="activity-type ${activity.type}">${activity.type}</span>
                            <span class="activity-time ms-2">${this.formatMobileTime(activity.time)}</span>
                        </div>
                        <div class="fw-semibold mb-1">${activity.title}</div>
                        <div class="text-muted small">${activity.description}</div>
                    </div>
                    <i class="fas fa-chevron-right text-muted"></i>
                </div>
            </div>
        `).join('');

        container.innerHTML = activitiesHtml;
    }

    async loadTrendData() {
        // Generate sample trend data for mobile chart
        const trendData = {
            labels: this.generateMobileDateLabels(7),
            datasets: [{
                label: 'Key Metrics',
                data: this.generateMobileTrendData(7),
                borderColor: '#0d6efd',
                backgroundColor: 'rgba(13, 110, 253, 0.1)',
                tension: 0.4,
                fill: true,
                pointRadius: 3,
                pointHoverRadius: 6
            }]
        };

        this.updateTrendChart(trendData);
    }

    initializeChart() {
        const ctx = document.getElementById('mobileTrendChart').getContext('2d');
        
        this.trendChart = new Chart(ctx, {
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
                        },
                        ticks: {
                            font: {
                                size: 10
                            }
                        }
                    },
                    x: {
                        grid: {
                            display: false
                        },
                        ticks: {
                            font: {
                                size: 10
                            }
                        }
                    }
                },
                elements: {
                    point: {
                        radius: 2,
                        hoverRadius: 4
                    }
                }
            }
        });
    }

    updateTrendChart(data) {
        if (this.trendChart) {
            this.trendChart.data = data;
            this.trendChart.update();
        }
    }

    showSection(sectionName) {
        // Hide all sections
        document.querySelectorAll('.content-section').forEach(section => {
            section.classList.remove('active');
        });
        
        // Show selected section
        const targetSection = document.getElementById(sectionName);
        if (targetSection) {
            targetSection.classList.add('active');
            this.currentSection = sectionName;
            
            // Update URL hash
            window.history.pushState({}, '', `#${sectionName}`);
            
            // Update bottom navigation
            this.updateBottomNavigation(sectionName);
            
            // Load section-specific data
            this.loadSectionData(sectionName);
        }
    }

    updateBottomNavigation(activeSection) {
        document.querySelectorAll('.fixed-bottom .nav-link').forEach(link => {
            link.classList.remove('active');
        });
        
        const activeLink = document.querySelector(`.fixed-bottom a[href="#${activeSection}"]`);
        if (activeLink) {
            activeLink.classList.add('active');
        }
    }

    async loadSectionData(sectionName) {
        switch (sectionName) {
            case 'insights':
                await this.loadMobileInsights();
                break;
            case 'forecasts':
                await this.loadMobileForecasts();
                break;
            case 'alerts':
                await this.loadMobileAlerts();
                break;
            case 'search':
                // Search section doesn't need initial data loading
                break;
        }
    }

    async loadMobileInsights() {
        try {
            const response = await fetch(`${this.apiBaseUrl}/insights/personalized?limit=10`, {
                headers: {
                    'Authorization': `Bearer ${this.getAuthToken()}`
                }
            });
            
            if (!response.ok) throw new Error('Failed to fetch insights');
            
            const data = await response.json();
            this.renderMobileInsights(data.insights || []);
            
        } catch (error) {
            console.error('Error loading mobile insights:', error);
            this.renderMobileInsights([]);
        }
    }

    renderMobileInsights(insights) {
        const container = document.getElementById('mobileInsightsList');
        
        if (insights.length === 0) {
            container.innerHTML = `
                <div class="text-center py-4 text-muted">
                    <i class="fas fa-lightbulb fa-3x mb-3 opacity-25"></i>
                    <p>No insights available</p>
                    <button class="btn btn-primary" onclick="mobileApp.generateMobileInsight()">
                        Generate Insight
                    </button>
                </div>
            `;
            return;
        }

        const insightsHtml = insights.map(insight => `
            <div class="insight-card touchable">
                <div class="insight-header">
                    <div class="d-flex justify-content-between align-items-center">
                        <span class="insight-confidence confidence-${this.getConfidenceLevel(insight.confidence_score)}">
                            ${(insight.confidence_score * 100).toFixed(0)}%
                        </span>
                        <small class="text-muted">${this.formatMobileTime(new Date(insight.generated_timestamp))}</small>
                    </div>
                </div>
                <div class="insight-content">
                    ${insight.content}
                </div>
                <div class="insight-actions">
                    <button class="btn btn-sm btn-outline-primary" onclick="mobileApp.shareInsight('${insight.insight_id}')">
                        <i class="fas fa-share"></i>
                    </button>
                    <button class="btn btn-sm btn-outline-secondary" onclick="mobileApp.viewInsightDetails('${insight.insight_id}')">
                        <i class="fas fa-eye"></i>
                    </button>
                </div>
            </div>
        `).join('');

        container.innerHTML = insightsHtml;
    }

    async loadMobileForecasts() {
        // Simulate forecast data
        const forecasts = [
            {
                id: 'forecast_1',
                metric: 'Revenue',
                value: '$2.4M',
                trend: 'up',
                change: '+15%',
                period: 'Next Quarter',
                confidence: 0.94
            },
            {
                id: 'forecast_2',
                metric: 'Customer Acquisition',
                value: '1,250',
                trend: 'up',
                change: '+8%',
                period: 'Next Month',
                confidence: 0.87
            },
            {
                id: 'forecast_3',
                metric: 'Operational Costs',
                value: '$890K',
                trend: 'down',
                change: '-3%',
                period: 'Next Quarter',
                confidence: 0.91
            }
        ];

        this.renderMobileForecasts(forecasts);
    }

    renderMobileForecasts(forecasts) {
        const container = document.getElementById('mobileForecastsList');
        
        const forecastsHtml = forecasts.map(forecast => `
            <div class="forecast-card touchable" onclick="mobileApp.viewForecastDetails('${forecast.id}')">
                <div class="d-flex justify-content-between align-items-start mb-2">
                    <div class="forecast-metric">${forecast.metric}</div>
                    <span class="insight-confidence confidence-${this.getConfidenceLevel(forecast.confidence)}">
                        ${(forecast.confidence * 100).toFixed(0)}%
                    </span>
                </div>
                <div class="forecast-value mb-2">${forecast.value}</div>
                <div class="d-flex justify-content-between align-items-center">
                    <div class="forecast-trend trend-${forecast.trend}">
                        <i class="fas fa-arrow-${forecast.trend === 'up' ? 'up' : 'down'}"></i>
                        ${forecast.change}
                    </div>
                    <small class="text-muted">${forecast.period}</small>
                </div>
            </div>
        `).join('');

        container.innerHTML = forecastsHtml;
    }

    async loadMobileAlerts() {
        // Simulate alert data
        const alerts = [
            {
                id: 'alert_1',
                title: 'High Customer Acquisition Cost',
                description: 'CAC has increased by 25% over the last week, exceeding the target threshold.',
                severity: 'high',
                time: new Date(Date.now() - 1000 * 60 * 30),
                category: 'Financial'
            },
            {
                id: 'alert_2',
                title: 'Revenue Forecast Deviation',
                description: 'Current revenue tracking 8% below forecast for this month.',
                severity: 'medium',
                time: new Date(Date.now() - 1000 * 60 * 120),
                category: 'Revenue'
            },
            {
                id: 'alert_3',
                title: 'Data Quality Issue',
                description: 'Missing data detected in customer interaction logs.',
                severity: 'low',
                time: new Date(Date.now() - 1000 * 60 * 240),
                category: 'Data Quality'
            }
        ];

        this.renderMobileAlerts(alerts);
    }

    renderMobileAlerts(alerts) {
        const container = document.getElementById('mobileAlertsList');
        
        if (alerts.length === 0) {
            container.innerHTML = `
                <div class="text-center py-4 text-muted">
                    <i class="fas fa-check-circle fa-3x mb-3 text-success opacity-25"></i>
                    <p>No active alerts</p>
                </div>
            `;
            return;
        }

        const alertsHtml = alerts.map(alert => `
            <div class="alert-card ${alert.severity} touchable" onclick="mobileApp.viewAlertDetails('${alert.id}')">
                <div class="alert-title">${alert.title}</div>
                <div class="alert-description">${alert.description}</div>
                <div class="d-flex justify-content-between align-items-center">
                    <span class="badge bg-light text-dark">${alert.category}</span>
                    <span class="alert-time">${this.formatMobileTime(alert.time)}</span>
                </div>
            </div>
        `).join('');

        container.innerHTML = alertsHtml;
    }

    async executeMobileSearch() {
        const query = document.getElementById('mobileSearchInput').value.trim();
        const searchType = document.getElementById('mobileSearchType').value;
        
        if (!query) {
            this.showToast('Please enter a search query');
            return;
        }

        this.showMobileLoading('Searching...');

        try {
            const response = await fetch(`${this.apiBaseUrl}/insights/generate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.getAuthToken()}`
                },
                body: JSON.stringify({
                    query: query,
                    user_role: 'mobile_user'
                })
            });

            if (!response.ok) throw new Error('Search failed');

            const result = await response.json();
            this.renderMobileSearchResults([result]);

        } catch (error) {
            console.error('Error executing mobile search:', error);
            this.showError('Search failed. Please try again.');
        } finally {
            this.hideMobileLoading();
        }
    }

    renderMobileSearchResults(results) {
        const container = document.getElementById('mobileSearchResults');
        
        if (results.length === 0) {
            container.innerHTML = `
                <div class="text-center py-4 text-muted">
                    <i class="fas fa-search fa-3x mb-3 opacity-25"></i>
                    <p>No results found</p>
                </div>
            `;
            return;
        }

        const resultsHtml = results.map(result => `
            <div class="search-result touchable">
                <div class="search-result-title">AI Generated Insight</div>
                <div class="search-result-snippet">${result.content}</div>
                <div class="search-result-meta">
                    <span class="relevance-score">${(result.confidence_score * 100).toFixed(0)}% relevant</span>
                    <small class="text-muted">${this.formatMobileTime(new Date(result.generated_timestamp))}</small>
                </div>
            </div>
        `).join('');

        container.innerHTML = resultsHtml;
    }

    generateMobileInsight() {
        const modal = new bootstrap.Modal(document.getElementById('mobileInsightModal'));
        modal.show();
    }

    async submitMobileInsight() {
        const query = document.getElementById('mobileInsightQuery').value.trim();
        
        if (!query) {
            this.showToast('Please enter a query');
            return;
        }

        this.showMobileLoading('Generating insight...');

        try {
            const response = await fetch(`${this.apiBaseUrl}/insights/generate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${this.getAuthToken()}`
                },
                body: JSON.stringify({
                    query: query,
                    user_role: 'mobile_user'
                })
            });

            if (!response.ok) throw new Error('Failed to generate insight');

            // Close modal and refresh insights
            bootstrap.Modal.getInstance(document.getElementById('mobileInsightModal')).hide();
            document.getElementById('mobileInsightQuery').value = '';
            
            await this.loadMobileInsights();
            this.showToast('Insight generated successfully!');

        } catch (error) {
            console.error('Error generating mobile insight:', error);
            this.showError('Failed to generate insight');
        } finally {
            this.hideMobileLoading();
        }
    }

    createMobileForecast() {
        const modal = new bootstrap.Modal(document.getElementById('mobileForecastModal'));
        modal.show();
    }

    async submitMobileForecast() {
        const metric = document.getElementById('mobileMetricSelect').value;
        const horizon = parseInt(document.getElementById('mobileHorizonSelect').value);

        this.showMobileLoading('Creating forecast...');

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
                    confidence_level: 0.95
                })
            });

            if (!response.ok) throw new Error('Failed to create forecast');

            // Close modal and refresh forecasts
            bootstrap.Modal.getInstance(document.getElementById('mobileForecastModal')).hide();
            
            await this.loadMobileForecasts();
            this.showToast('Forecast created successfully!');

        } catch (error) {
            console.error('Error creating mobile forecast:', error);
            this.showError('Failed to create forecast');
        } finally {
            this.hideMobileLoading();
        }
    }

    showNotifications() {
        this.loadNotifications();
        const modal = new bootstrap.Modal(document.getElementById('notificationsModal'));
        modal.show();
    }

    async loadNotifications() {
        // Simulate notifications
        this.notifications = [
            {
                id: 'notif_1',
                title: 'New Insight Available',
                message: 'Revenue forecast has been updated with latest data',
                time: new Date(Date.now() - 1000 * 60 * 5),
                read: false,
                type: 'insight'
            },
            {
                id: 'notif_2',
                title: 'Alert Resolved',
                message: 'Customer acquisition cost anomaly has been resolved',
                time: new Date(Date.now() - 1000 * 60 * 30),
                read: true,
                type: 'alert'
            },
            {
                id: 'notif_3',
                title: 'Weekly Report Ready',
                message: 'Your weekly intelligence report is ready for review',
                time: new Date(Date.now() - 1000 * 60 * 60 * 2),
                read: true,
                type: 'report'
            }
        ];

        this.renderNotifications();
        this.updateNotificationBadge();
    }

    renderNotifications() {
        const container = document.getElementById('notificationsList');
        
        if (this.notifications.length === 0) {
            container.innerHTML = `
                <div class="text-center py-4 text-muted">
                    <i class="fas fa-bell-slash fa-3x mb-3 opacity-25"></i>
                    <p>No notifications</p>
                </div>
            `;
            return;
        }

        const notificationsHtml = this.notifications.map(notification => `
            <div class="notification-item ${!notification.read ? 'notification-unread' : ''}" 
                 onclick="mobileApp.markNotificationRead('${notification.id}')">
                <div class="notification-title">${notification.title}</div>
                <div class="notification-message">${notification.message}</div>
                <div class="notification-time">${this.formatMobileTime(notification.time)}</div>
            </div>
        `).join('');

        container.innerHTML = notificationsHtml;
    }

    updateNotificationBadge() {
        const unreadCount = this.notifications.filter(n => !n.read).length;
        const badge = document.querySelector('.notification-count');
        
        if (unreadCount > 0) {
            badge.textContent = unreadCount;
            badge.style.display = 'block';
        } else {
            badge.style.display = 'none';
        }
    }

    markNotificationRead(notificationId) {
        const notification = this.notifications.find(n => n.id === notificationId);
        if (notification) {
            notification.read = true;
            this.renderNotifications();
            this.updateNotificationBadge();
        }
    }

    async loadSettings() {
        // Load settings from localStorage or API
        const savedSettings = localStorage.getItem('mobileSettings');
        if (savedSettings) {
            this.settings = { ...this.settings, ...JSON.parse(savedSettings) };
        }
        
        this.applySettings();
    }

    applySettings() {
        document.getElementById('pushNotifications').checked = this.settings.pushNotifications;
        document.getElementById('emailNotifications').checked = this.settings.emailNotifications;
        document.getElementById('refreshInterval').value = this.settings.refreshInterval;
        document.getElementById('defaultView').value = this.settings.defaultView;
        
        // Apply refresh interval
        this.refreshInterval = this.settings.refreshInterval * 1000;
        this.startAutoRefresh();
    }

    saveMobileSettings() {
        this.settings = {
            pushNotifications: document.getElementById('pushNotifications').checked,
            emailNotifications: document.getElementById('emailNotifications').checked,
            refreshInterval: parseInt(document.getElementById('refreshInterval').value),
            defaultView: document.getElementById('defaultView').value
        };
        
        localStorage.setItem('mobileSettings', JSON.stringify(this.settings));
        this.applySettings();
        this.showToast('Settings saved successfully!');
    }

    startAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }
        
        if (this.settings.refreshInterval > 0) {
            this.refreshTimer = setInterval(() => {
                if (!document.hidden) {
                    this.loadDashboardData();
                }
            }, this.refreshInterval);
        }
    }

    pauseUpdates() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }
    }

    resumeUpdates() {
        this.startAutoRefresh();
        this.loadDashboardData();
    }

    // Utility Methods
    getAuthToken() {
        return 'demo-token';
    }

    formatMobileTime(date) {
        const now = new Date();
        const diffMs = now - date;
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMs / 3600000);
        const diffDays = Math.floor(diffMs / 86400000);

        if (diffMins < 1) return 'now';
        if (diffMins < 60) return `${diffMins}m`;
        if (diffHours < 24) return `${diffHours}h`;
        if (diffDays < 7) return `${diffDays}d`;
        
        return date.toLocaleDateString();
    }

    getConfidenceLevel(score) {
        if (score >= 0.8) return 'high';
        if (score >= 0.6) return 'medium';
        return 'low';
    }

    generateMobileDateLabels(days) {
        const labels = [];
        const today = new Date();
        
        for (let i = days - 1; i >= 0; i--) {
            const date = new Date(today);
            date.setDate(today.getDate() - i);
            labels.push(date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));
        }
        
        return labels;
    }

    generateMobileTrendData(days) {
        const data = [];
        let baseValue = 1000;
        
        for (let i = 0; i < days; i++) {
            baseValue += (Math.random() - 0.5) * 200 + 50;
            data.push(Math.round(baseValue));
        }
        
        return data;
    }

    showMobileLoading(message = 'Loading...') {
        const loadingHtml = `
            <div class="loading-overlay">
                <div class="spinner-border text-primary mb-3" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
                <p class="text-muted">${message}</p>
            </div>
        `;
        
        document.body.insertAdjacentHTML('beforeend', loadingHtml);
    }

    hideMobileLoading() {
        const loadingOverlay = document.querySelector('.loading-overlay');
        if (loadingOverlay) {
            loadingOverlay.remove();
        }
    }

    showToast(message, type = 'success') {
        // Simple toast implementation
        const toast = document.createElement('div');
        toast.className = `alert alert-${type} position-fixed top-0 start-50 translate-middle-x mt-3`;
        toast.style.zIndex = '9999';
        toast.textContent = message;
        
        document.body.appendChild(toast);
        
        setTimeout(() => {
            toast.remove();
        }, 3000);
    }

    showError(message) {
        this.showToast(message, 'danger');
    }

    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    // Public methods for HTML onclick handlers
    viewActivityDetails(type) {
        this.showToast(`Viewing ${type} details - feature would be implemented here`);
    }

    shareInsight(insightId) {
        if (navigator.share) {
            navigator.share({
                title: 'Enterprise Intelligence Insight',
                text: 'Check out this insight from our AI system',
                url: window.location.href
            });
        } else {
            this.showToast('Sharing insight - feature would be implemented here');
        }
    }

    viewInsightDetails(insightId) {
        this.showToast(`Viewing insight ${insightId} details`);
    }

    viewForecastDetails(forecastId) {
        this.showToast(`Viewing forecast ${forecastId} details`);
    }

    viewAlertDetails(alertId) {
        this.showToast(`Viewing alert ${alertId} details`);
    }

    showSearchSuggestions(query) {
        // Implement search suggestions
        console.log('Search suggestions for:', query);
    }
}

// Initialize mobile app when page loads
let mobileApp;
document.addEventListener('DOMContentLoaded', () => {
    mobileApp = new MobileInterface();
});

// Global functions for HTML onclick handlers
function showSection(sectionName) {
    mobileApp.showSection(sectionName);
}

function generateMobileInsight() {
    mobileApp.generateMobileInsight();
}

function submitMobileInsight() {
    mobileApp.submitMobileInsight();
}

function createMobileForecast() {
    mobileApp.createMobileForecast();
}

function submitMobileForecast() {
    mobileApp.submitMobileForecast();
}

function executeMobileSearch() {
    mobileApp.executeMobileSearch();
}

function showNotifications() {
    mobileApp.showNotifications();
}

function saveMobileSettings() {
    mobileApp.saveMobileSettings();
}