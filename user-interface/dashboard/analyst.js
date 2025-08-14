/**
 * Analyst Workbench JavaScript
 * Handles interactive data exploration, query building, and analysis
 */

class AnalystWorkbench {
    constructor() {
        this.apiBaseUrl = 'http://localhost:8000';
        this.currentChart = null;
        this.currentData = null;
        this.queryHistory = [];
        this.savedQueries = [];
        this.currentPage = 1;
        this.pageSize = 20;
        this.init();
    }

    async init() {
        this.setupEventListeners();
        await this.loadSavedQueries();
        await this.loadQueryHistory();
        this.initializeChart();
    }

    setupEventListeners() {
        // Query input auto-suggestions
        document.getElementById('queryInput').addEventListener('input', this.handleQueryInput.bind(this));
        
        // Analysis type change
        document.getElementById('analysisType').addEventListener('change', this.handleAnalysisTypeChange.bind(this));
        
        // Table selection change
        document.getElementById('tableSelect').addEventListener('change', this.loadTableData.bind(this));
        
        // Search filter
        document.getElementById('searchFilter').addEventListener('input', this.filterTableData.bind(this));
    }

    handleQueryInput(event) {
        const query = event.target.value;
        if (query.length > 3) {
            this.showQuerySuggestions(query);
        }
    }

    handleAnalysisTypeChange(event) {
        const analysisType = event.target.value;
        this.updateQueryPlaceholder(analysisType);
    }

    updateQueryPlaceholder(analysisType) {
        const queryInput = document.getElementById('queryInput');
        const placeholders = {
            'semantic': 'e.g., Find documents related to customer satisfaction and revenue impact',
            'predictive': 'e.g., Predict next quarter revenue based on current trends',
            'multimodal': 'e.g., Analyze product images and customer reviews for quality issues',
            'anomaly': 'e.g., Detect unusual patterns in customer acquisition costs'
        };
        
        queryInput.placeholder = placeholders[analysisType] || 'Enter your analysis query...';
    }

    async showQuerySuggestions(query) {
        // Simulate query suggestions based on input
        const suggestions = [
            'revenue trends last quarter',
            'customer churn analysis',
            'product performance metrics',
            'operational efficiency indicators'
        ].filter(s => s.toLowerCase().includes(query.toLowerCase()));

        // In a real implementation, this would show a dropdown with suggestions
        console.log('Query suggestions:', suggestions);
    }

    async executeQuery() {
        const query = document.getElementById('queryInput').value.trim();
        const analysisType = document.getElementById('analysisType').value;
        const timeRange = document.getElementById('timeRange').value;

        if (!query) {
            alert('Please enter a query to execute.');
            return;
        }

        this.showLoading();

        try {
            // Add to query history
            this.addToQueryHistory(query, analysisType, timeRange);

            // Execute based on analysis type
            let results;
            switch (analysisType) {
                case 'semantic':
                    results = await this.executeSemanticSearch(query);
                    break;
                case 'predictive':
                    results = await this.executePredictiveAnalysis(query, timeRange);
                    break;
                case 'multimodal':
                    results = await this.executeMultimodalAnalysis(query);
                    break;
                case 'anomaly':
                    results = await this.executeAnomalyDetection(query, timeRange);
                    break;
                default:
                    results = await this.executeSemanticSearch(query);
            }

            this.displayResults(results, analysisType);
            this.generateInsights(results, query, analysisType);

        } catch (error) {
            console.error('Error executing query:', error);
            this.showError('Failed to execute query. Please try again.');
        } finally {
            this.hideLoading();
        }
    }

    async executeSemanticSearch(query) {
        const response = await fetch(`${this.apiBaseUrl}/insights/generate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.getAuthToken()}`
            },
            body: JSON.stringify({
                query: query,
                user_role: 'analyst'
            })
        });

        if (!response.ok) throw new Error('Semantic search failed');
        
        const result = await response.json();
        
        // Simulate additional data for visualization
        return {
            type: 'semantic',
            insight: result,
            data: this.generateSampleData('semantic'),
            metadata: {
                sources_found: 15,
                confidence_avg: result.confidence_score,
                processing_time: '1.2s'
            }
        };
    }

    async executePredictiveAnalysis(query, timeRange) {
        // Extract metric from query (simplified)
        const metricMap = {
            'revenue': 'revenue',
            'customer': 'customer_acquisition',
            'cost': 'operational_costs',
            'market': 'market_share'
        };
        
        let metric = 'revenue';
        for (const [key, value] of Object.entries(metricMap)) {
            if (query.toLowerCase().includes(key)) {
                metric = value;
                break;
            }
        }

        const response = await fetch(`${this.apiBaseUrl}/forecasts/generate`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${this.getAuthToken()}`
            },
            body: JSON.stringify({
                metric_name: metric,
                horizon_days: this.getHorizonFromTimeRange(timeRange),
                confidence_level: 0.95
            })
        });

        if (!response.ok) throw new Error('Predictive analysis failed');
        
        const result = await response.json();
        
        return {
            type: 'predictive',
            forecast: result,
            data: this.formatForecastData(result),
            metadata: {
                metric: metric,
                horizon: this.getHorizonFromTimeRange(timeRange),
                accuracy: '94.2%'
            }
        };
    }

    async executeMultimodalAnalysis(query) {
        // Simulate multimodal analysis
        return {
            type: 'multimodal',
            data: this.generateSampleData('multimodal'),
            metadata: {
                images_analyzed: 45,
                text_documents: 23,
                correlation_score: 0.87
            }
        };
    }

    async executeAnomalyDetection(query, timeRange) {
        // Simulate anomaly detection
        return {
            type: 'anomaly',
            data: this.generateSampleData('anomaly'),
            anomalies: [
                {
                    timestamp: new Date(Date.now() - 86400000 * 2),
                    value: 15000,
                    expected: 12000,
                    severity: 'high',
                    description: 'Unusual spike in customer acquisition costs'
                },
                {
                    timestamp: new Date(Date.now() - 86400000 * 5),
                    value: 8500,
                    expected: 11000,
                    severity: 'medium',
                    description: 'Lower than expected revenue for the period'
                }
            ],
            metadata: {
                anomalies_detected: 2,
                time_range: timeRange,
                detection_accuracy: '96.8%'
            }
        };
    }

    displayResults(results, analysisType) {
        this.currentData = results;
        
        // Update visualization
        this.updateVisualization(results);
        
        // Show chart by default
        this.changeVisualization('chart');
    }

    updateVisualization(results) {
        if (!this.currentChart) {
            this.initializeChart();
        }

        let chartData;
        let chartOptions = {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'top',
                },
                title: {
                    display: true,
                    text: this.getChartTitle(results.type)
                }
            }
        };

        switch (results.type) {
            case 'semantic':
                chartData = this.createSemanticChart(results.data);
                break;
            case 'predictive':
                chartData = this.createPredictiveChart(results.data);
                chartOptions.scales = {
                    x: {
                        type: 'time',
                        time: {
                            unit: 'day'
                        }
                    },
                    y: {
                        beginAtZero: false
                    }
                };
                break;
            case 'multimodal':
                chartData = this.createMultimodalChart(results.data);
                break;
            case 'anomaly':
                chartData = this.createAnomalyChart(results.data, results.anomalies);
                break;
            default:
                chartData = this.createDefaultChart(results.data);
        }

        this.currentChart.data = chartData;
        this.currentChart.options = chartOptions;
        this.currentChart.update();
    }

    createSemanticChart(data) {
        return {
            labels: data.labels,
            datasets: [{
                label: 'Relevance Score',
                data: data.values,
                backgroundColor: 'rgba(13, 110, 253, 0.2)',
                borderColor: 'rgba(13, 110, 253, 1)',
                borderWidth: 2,
                fill: true
            }]
        };
    }

    createPredictiveChart(data) {
        return {
            labels: data.labels,
            datasets: [
                {
                    label: 'Historical Data',
                    data: data.historical,
                    borderColor: 'rgba(108, 117, 125, 1)',
                    backgroundColor: 'rgba(108, 117, 125, 0.1)',
                    borderWidth: 2
                },
                {
                    label: 'Forecast',
                    data: data.forecast,
                    borderColor: 'rgba(13, 110, 253, 1)',
                    backgroundColor: 'rgba(13, 110, 253, 0.1)',
                    borderWidth: 2,
                    borderDash: [5, 5]
                },
                {
                    label: 'Confidence Interval',
                    data: data.confidence,
                    backgroundColor: 'rgba(13, 110, 253, 0.1)',
                    borderColor: 'transparent',
                    fill: '+1'
                }
            ]
        };
    }

    createMultimodalChart(data) {
        return {
            labels: data.labels,
            datasets: [
                {
                    label: 'Text Analysis',
                    data: data.text,
                    backgroundColor: 'rgba(25, 135, 84, 0.7)',
                    borderColor: 'rgba(25, 135, 84, 1)',
                    borderWidth: 1
                },
                {
                    label: 'Image Analysis',
                    data: data.images,
                    backgroundColor: 'rgba(255, 193, 7, 0.7)',
                    borderColor: 'rgba(255, 193, 7, 1)',
                    borderWidth: 1
                }
            ]
        };
    }

    createAnomalyChart(data, anomalies) {
        const anomalyPoints = anomalies.map(a => ({
            x: a.timestamp,
            y: a.value,
            severity: a.severity
        }));

        return {
            labels: data.labels,
            datasets: [
                {
                    label: 'Normal Data',
                    data: data.values,
                    borderColor: 'rgba(13, 110, 253, 1)',
                    backgroundColor: 'rgba(13, 110, 253, 0.1)',
                    borderWidth: 2,
                    pointRadius: 3
                },
                {
                    label: 'Anomalies',
                    data: anomalyPoints,
                    borderColor: 'rgba(220, 53, 69, 1)',
                    backgroundColor: 'rgba(220, 53, 69, 0.8)',
                    pointRadius: 8,
                    pointHoverRadius: 10,
                    showLine: false
                }
            ]
        };
    }

    generateInsights(results, query, analysisType) {
        const insightsPanel = document.getElementById('insightsPanel');
        
        let insights = [];
        
        switch (analysisType) {
            case 'semantic':
                insights = this.generateSemanticInsights(results);
                break;
            case 'predictive':
                insights = this.generatePredictiveInsights(results);
                break;
            case 'multimodal':
                insights = this.generateMultimodalInsights(results);
                break;
            case 'anomaly':
                insights = this.generateAnomalyInsights(results);
                break;
        }

        const insightsHtml = insights.map(insight => `
            <div class="insight-item fade-in-up">
                <div class="d-flex justify-content-between align-items-start mb-2">
                    <h6 class="mb-0">${insight.title}</h6>
                    <span class="insight-confidence confidence-${insight.confidence_level}">
                        ${(insight.confidence * 100).toFixed(0)}%
                    </span>
                </div>
                <p class="mb-2">${insight.description}</p>
                <div class="d-flex justify-content-between align-items-center">
                    <small class="text-muted">
                        <i class="fas fa-${insight.icon} me-1"></i>
                        ${insight.category}
                    </small>
                    <button class="btn btn-sm btn-outline-primary" onclick="workbench.exploreInsight('${insight.id}')">
                        Explore
                    </button>
                </div>
            </div>
        `).join('');

        insightsPanel.innerHTML = insightsHtml;
    }

    generateSemanticInsights(results) {
        return [
            {
                id: 'semantic_1',
                title: 'High Relevance Documents Found',
                description: `Found ${results.metadata.sources_found} highly relevant documents with average confidence of ${(results.metadata.confidence_avg * 100).toFixed(1)}%.`,
                confidence: results.metadata.confidence_avg,
                confidence_level: results.metadata.confidence_avg > 0.8 ? 'high' : 'medium',
                category: 'Document Discovery',
                icon: 'search'
            },
            {
                id: 'semantic_2',
                title: 'Key Themes Identified',
                description: 'Analysis reveals three main themes: customer satisfaction, operational efficiency, and market positioning.',
                confidence: 0.87,
                confidence_level: 'high',
                category: 'Theme Analysis',
                icon: 'tags'
            }
        ];
    }

    generatePredictiveInsights(results) {
        return [
            {
                id: 'predictive_1',
                title: 'Forecast Trend Analysis',
                description: `The ${results.metadata.metric} forecast shows a positive trend with ${results.metadata.accuracy} accuracy.`,
                confidence: 0.94,
                confidence_level: 'high',
                category: 'Trend Analysis',
                icon: 'chart-line'
            },
            {
                id: 'predictive_2',
                title: 'Risk Assessment',
                description: 'Low risk of significant deviation from forecast. Confidence intervals remain stable.',
                confidence: 0.89,
                confidence_level: 'high',
                category: 'Risk Analysis',
                icon: 'shield-alt'
            }
        ];
    }

    generateMultimodalInsights(results) {
        return [
            {
                id: 'multimodal_1',
                title: 'Cross-Modal Correlation',
                description: `Strong correlation (${(results.metadata.correlation_score * 100).toFixed(1)}%) found between visual content and text analysis.`,
                confidence: results.metadata.correlation_score,
                confidence_level: 'high',
                category: 'Correlation Analysis',
                icon: 'link'
            }
        ];
    }

    generateAnomalyInsights(results) {
        return results.anomalies.map((anomaly, index) => ({
            id: `anomaly_${index}`,
            title: `${anomaly.severity.toUpperCase()} Severity Anomaly`,
            description: anomaly.description,
            confidence: 0.92,
            confidence_level: anomaly.severity === 'high' ? 'high' : 'medium',
            category: 'Anomaly Detection',
            icon: 'exclamation-triangle'
        }));
    }

    initializeChart() {
        const ctx = document.getElementById('analysisChart').getContext('2d');
        
        this.currentChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: [],
                datasets: []
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }

    changeVisualization(type) {
        const container = document.getElementById('visualizationContainer');
        const chart = document.getElementById('analysisChart');
        const table = document.getElementById('analysisTable');

        // Hide all visualizations
        container.style.display = 'none';
        chart.style.display = 'none';
        table.style.display = 'none';

        switch (type) {
            case 'chart':
                chart.style.display = 'block';
                if (this.currentChart) {
                    this.currentChart.resize();
                }
                break;
            case 'table':
                table.style.display = 'block';
                this.renderDataTable();
                break;
            case 'map':
                // Implement map visualization
                container.innerHTML = '<div class="text-center py-5"><i class="fas fa-map fa-4x mb-3 text-muted"></i><p>Map visualization coming soon</p></div>';
                container.style.display = 'block';
                break;
            default:
                container.style.display = 'block';
        }
    }

    renderDataTable() {
        if (!this.currentData) return;

        const table = document.getElementById('analysisTable');
        
        // Generate sample table data based on analysis type
        const tableData = this.generateTableData(this.currentData);
        
        let tableHtml = '<table class="table table-hover"><thead><tr>';
        
        // Add headers
        Object.keys(tableData[0] || {}).forEach(key => {
            tableHtml += `<th>${key.replace('_', ' ').toUpperCase()}</th>`;
        });
        
        tableHtml += '</tr></thead><tbody>';
        
        // Add rows
        tableData.forEach(row => {
            tableHtml += '<tr>';
            Object.values(row).forEach(value => {
                tableHtml += `<td>${value}</td>`;
            });
            tableHtml += '</tr>';
        });
        
        tableHtml += '</tbody></table>';
        
        table.innerHTML = tableHtml;
    }

    generateTableData(results) {
        // Generate sample table data based on analysis type
        const sampleData = [];
        
        for (let i = 0; i < 10; i++) {
            sampleData.push({
                id: i + 1,
                timestamp: new Date(Date.now() - Math.random() * 86400000 * 30).toLocaleDateString(),
                value: Math.round(Math.random() * 10000),
                confidence: (Math.random() * 0.4 + 0.6).toFixed(2),
                category: ['Revenue', 'Costs', 'Customers', 'Products'][Math.floor(Math.random() * 4)]
            });
        }
        
        return sampleData;
    }

    async loadTableData() {
        const tableName = document.getElementById('tableSelect').value;
        if (!tableName) return;

        // Simulate loading table data
        const sampleData = this.generateSampleTableData(tableName);
        this.renderTableExplorer(sampleData);
    }

    generateSampleTableData(tableName) {
        const data = [];
        const rowCount = 50;
        
        for (let i = 0; i < rowCount; i++) {
            switch (tableName) {
                case 'enterprise_knowledge_base':
                    data.push({
                        knowledge_id: `kb_${i + 1}`,
                        content_type: ['document', 'image', 'structured_data'][Math.floor(Math.random() * 3)],
                        source_system: ['CRM', 'ERP', 'DMS'][Math.floor(Math.random() * 3)],
                        created_timestamp: new Date(Date.now() - Math.random() * 86400000 * 365).toISOString(),
                        confidence_score: (Math.random() * 0.4 + 0.6).toFixed(2)
                    });
                    break;
                case 'generated_insights':
                    data.push({
                        insight_id: `insight_${i + 1}`,
                        insight_type: ['predictive', 'descriptive', 'prescriptive'][Math.floor(Math.random() * 3)],
                        confidence_score: (Math.random() * 0.4 + 0.6).toFixed(2),
                        business_impact_score: (Math.random() * 0.5 + 0.5).toFixed(2),
                        created_timestamp: new Date(Date.now() - Math.random() * 86400000 * 30).toISOString()
                    });
                    break;
                default:
                    data.push({
                        id: i + 1,
                        value: Math.round(Math.random() * 10000),
                        timestamp: new Date(Date.now() - Math.random() * 86400000 * 30).toISOString()
                    });
            }
        }
        
        return data;
    }

    renderTableExplorer(data) {
        const table = document.getElementById('dataTable');
        
        if (data.length === 0) {
            table.innerHTML = '<thead><tr><th class="text-center text-muted py-4">No data available</th></tr></thead>';
            return;
        }

        const headers = Object.keys(data[0]);
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        const pageData = data.slice(startIndex, endIndex);

        let tableHtml = '<thead><tr>';
        headers.forEach(header => {
            tableHtml += `<th>${header.replace('_', ' ').toUpperCase()}</th>`;
        });
        tableHtml += '</tr></thead><tbody>';

        pageData.forEach(row => {
            tableHtml += '<tr>';
            headers.forEach(header => {
                let value = row[header];
                if (typeof value === 'string' && value.includes('T')) {
                    // Format timestamp
                    value = new Date(value).toLocaleString();
                }
                tableHtml += `<td>${value}</td>`;
            });
            tableHtml += '</tr>';
        });

        tableHtml += '</tbody>';
        table.innerHTML = tableHtml;

        this.renderPagination(data.length);
    }

    renderPagination(totalItems) {
        const totalPages = Math.ceil(totalItems / this.pageSize);
        const pagination = document.getElementById('tablePagination');
        
        let paginationHtml = '';
        
        // Previous button
        paginationHtml += `
            <li class="page-item ${this.currentPage === 1 ? 'disabled' : ''}">
                <a class="page-link" href="#" onclick="workbench.changePage(${this.currentPage - 1})">Previous</a>
            </li>
        `;
        
        // Page numbers
        for (let i = 1; i <= Math.min(totalPages, 5); i++) {
            paginationHtml += `
                <li class="page-item ${i === this.currentPage ? 'active' : ''}">
                    <a class="page-link" href="#" onclick="workbench.changePage(${i})">${i}</a>
                </li>
            `;
        }
        
        // Next button
        paginationHtml += `
            <li class="page-item ${this.currentPage === totalPages ? 'disabled' : ''}">
                <a class="page-link" href="#" onclick="workbench.changePage(${this.currentPage + 1})">Next</a>
            </li>
        `;
        
        pagination.innerHTML = paginationHtml;
    }

    changePage(page) {
        this.currentPage = page;
        this.loadTableData();
    }

    filterTableData() {
        const filter = document.getElementById('searchFilter').value.toLowerCase();
        // Implement table filtering logic
        console.log('Filtering table data with:', filter);
    }

    async saveQuery() {
        const modal = new bootstrap.Modal(document.getElementById('saveQueryModal'));
        modal.show();
    }

    async submitSaveQuery() {
        const name = document.getElementById('queryName').value;
        const description = document.getElementById('queryDescription').value;
        const tags = document.getElementById('queryTags').value;
        const query = document.getElementById('queryInput').value;

        if (!name || !query) {
            alert('Please provide a name and query to save.');
            return;
        }

        const savedQuery = {
            id: Date.now().toString(),
            name,
            description,
            tags: tags.split(',').map(t => t.trim()).filter(t => t),
            query,
            analysisType: document.getElementById('analysisType').value,
            timeRange: document.getElementById('timeRange').value,
            savedAt: new Date()
        };

        this.savedQueries.push(savedQuery);
        
        // Close modal and clear form
        bootstrap.Modal.getInstance(document.getElementById('saveQueryModal')).hide();
        document.getElementById('saveQueryForm').reset();
        
        // Update saved queries list
        this.updateSavedQueriesList();
        
        alert('Query saved successfully!');
    }

    async loadSavedQueries() {
        // Simulate loading saved queries
        this.savedQueries = [
            {
                id: '1',
                name: 'Revenue Trends Q4',
                description: 'Quarterly revenue analysis with forecasting',
                tags: ['revenue', 'quarterly', 'forecast'],
                query: 'Analyze revenue trends for Q4 and predict next quarter performance',
                analysisType: 'predictive',
                savedAt: new Date(Date.now() - 86400000 * 7)
            },
            {
                id: '2',
                name: 'Customer Churn Analysis',
                description: 'Identify patterns in customer churn',
                tags: ['customer', 'churn', 'analysis'],
                query: 'Find patterns in customer churn and identify at-risk segments',
                analysisType: 'semantic',
                savedAt: new Date(Date.now() - 86400000 * 3)
            }
        ];
        
        this.updateSavedQueriesList();
    }

    updateSavedQueriesList() {
        const container = document.getElementById('savedQueries');
        
        const queriesHtml = this.savedQueries.map(query => `
            <a href="#" class="list-group-item list-group-item-action" onclick="workbench.loadSavedQuery('${query.id}')">
                <i class="fas fa-bookmark me-2"></i>
                ${query.name}
            </a>
        `).join('');
        
        container.innerHTML = queriesHtml;
    }

    loadSavedQuery(queryId) {
        const query = this.savedQueries.find(q => q.id === queryId);
        if (query) {
            document.getElementById('queryInput').value = query.query;
            document.getElementById('analysisType').value = query.analysisType;
            document.getElementById('timeRange').value = query.timeRange || '30d';
        }
    }

    async loadQueryHistory() {
        // Query history is populated when queries are executed
        this.updateQueryHistoryModal();
    }

    addToQueryHistory(query, analysisType, timeRange) {
        const historyItem = {
            id: Date.now().toString(),
            query,
            analysisType,
            timeRange,
            executedAt: new Date(),
            results: 'success'
        };
        
        this.queryHistory.unshift(historyItem);
        
        // Keep only last 50 queries
        if (this.queryHistory.length > 50) {
            this.queryHistory = this.queryHistory.slice(0, 50);
        }
    }

    showQueryHistory() {
        this.updateQueryHistoryModal();
        const modal = new bootstrap.Modal(document.getElementById('queryHistoryModal'));
        modal.show();
    }

    updateQueryHistoryModal() {
        const container = document.getElementById('queryHistoryList');
        
        if (this.queryHistory.length === 0) {
            container.innerHTML = '<div class="text-center py-4 text-muted">No query history available</div>';
            return;
        }
        
        const historyHtml = this.queryHistory.map(item => `
            <div class="query-history-item" onclick="workbench.loadHistoryQuery('${item.id}')">
                <div class="d-flex justify-content-between align-items-start">
                    <div class="flex-grow-1">
                        <h6 class="mb-1">${item.query}</h6>
                        <div class="query-timestamp">
                            <i class="fas fa-clock me-1"></i>
                            ${item.executedAt.toLocaleString()}
                        </div>
                    </div>
                    <span class="analysis-type-indicator analysis-${item.analysisType}"></span>
                </div>
                <div class="query-tags mt-2">
                    <span class="query-tag">${item.analysisType}</span>
                    <span class="query-tag">${item.timeRange}</span>
                </div>
            </div>
        `).join('');
        
        container.innerHTML = historyHtml;
    }

    loadHistoryQuery(historyId) {
        const historyItem = this.queryHistory.find(h => h.id === historyId);
        if (historyItem) {
            document.getElementById('queryInput').value = historyItem.query;
            document.getElementById('analysisType').value = historyItem.analysisType;
            document.getElementById('timeRange').value = historyItem.timeRange;
            
            // Close modal
            bootstrap.Modal.getInstance(document.getElementById('queryHistoryModal')).hide();
        }
    }

    // Utility methods
    getAuthToken() {
        return 'demo-token';
    }

    getHorizonFromTimeRange(timeRange) {
        const horizonMap = {
            '7d': 7,
            '30d': 30,
            '90d': 90,
            '1y': 365,
            'all': 30
        };
        return horizonMap[timeRange] || 30;
    }

    getChartTitle(analysisType) {
        const titles = {
            'semantic': 'Semantic Search Results',
            'predictive': 'Predictive Analysis',
            'multimodal': 'Multimodal Analysis',
            'anomaly': 'Anomaly Detection'
        };
        return titles[analysisType] || 'Analysis Results';
    }

    generateSampleData(type) {
        const labels = [];
        const values = [];
        
        for (let i = 0; i < 30; i++) {
            labels.push(new Date(Date.now() - (29 - i) * 86400000).toLocaleDateString());
            values.push(Math.round(Math.random() * 1000 + 500));
        }
        
        switch (type) {
            case 'semantic':
                return { labels, values };
            case 'predictive':
                return {
                    labels,
                    historical: values.slice(0, 20),
                    forecast: values.slice(20),
                    confidence: values.slice(20).map(v => v * 1.1)
                };
            case 'multimodal':
                return {
                    labels: ['Product A', 'Product B', 'Product C', 'Product D', 'Product E'],
                    text: [85, 92, 78, 88, 95],
                    images: [78, 85, 82, 91, 87]
                };
            case 'anomaly':
                return { labels, values };
            default:
                return { labels, values };
        }
    }

    formatForecastData(forecastResult) {
        return {
            labels: forecastResult.forecast_values.map(f => new Date(f.timestamp).toLocaleDateString()),
            historical: [], // Would be populated with historical data
            forecast: forecastResult.forecast_values.map(f => f.value),
            confidence: forecastResult.confidence_intervals.map(c => c.upper)
        };
    }

    showLoading() {
        const container = document.getElementById('visualizationContainer');
        container.innerHTML = `
            <div class="text-center py-5">
                <div class="spinner-border text-primary mb-3" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
                <p class="text-muted">Executing analysis...</p>
            </div>
        `;
        container.style.display = 'block';
    }

    hideLoading() {
        // Loading state is hidden when results are displayed
    }

    showError(message) {
        const container = document.getElementById('visualizationContainer');
        container.innerHTML = `
            <div class="text-center py-5 text-danger">
                <i class="fas fa-exclamation-triangle fa-3x mb-3"></i>
                <h5>Analysis Error</h5>
                <p>${message}</p>
                <button class="btn btn-outline-primary" onclick="location.reload()">Retry</button>
            </div>
        `;
        container.style.display = 'block';
    }

    // Public methods for HTML onclick handlers
    exploreInsight(insightId) {
        alert(`Exploring insight ${insightId} - detailed view would be implemented here.`);
    }

    exportTableData() {
        alert('Data export functionality would be implemented here.');
    }
}

// Initialize workbench when page loads
let workbench;
document.addEventListener('DOMContentLoaded', () => {
    workbench = new AnalystWorkbench();
});

// Global functions for HTML onclick handlers
function executeQuery() {
    workbench.executeQuery();
}

function saveQuery() {
    workbench.saveQuery();
}

function submitSaveQuery() {
    workbench.submitSaveQuery();
}

function showQueryHistory() {
    workbench.showQueryHistory();
}

function changeVisualization(type) {
    workbench.changeVisualization(type);
}

function loadDataSource(source) {
    console.log('Loading data source:', source);
}

function showSemanticSearch() {
    document.getElementById('analysisType').value = 'semantic';
    workbench.updateQueryPlaceholder('semantic');
}

function showPredictiveAnalysis() {
    document.getElementById('analysisType').value = 'predictive';
    workbench.updateQueryPlaceholder('predictive');
}

function showMultimodalAnalysis() {
    document.getElementById('analysisType').value = 'multimodal';
    workbench.updateQueryPlaceholder('multimodal');
}

function showAnomalyDetection() {
    document.getElementById('analysisType').value = 'anomaly';
    workbench.updateQueryPlaceholder('anomaly');
}

function loadTableData() {
    workbench.loadTableData();
}

function filterTableData() {
    workbench.filterTableData();
}

function exportTableData() {
    workbench.exportTableData();
}

function showSettings() {
    alert('Settings panel would be implemented here.');
}