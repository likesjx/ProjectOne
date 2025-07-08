# Memory Analytics Dashboard Architecture

## Overview

Design specification for implementing a comprehensive memory analytics dashboard in ProjectOne, providing insights into the Titans-inspired memory architecture performance, consolidation patterns, and system health.

## Core Architecture Components

### 1. Analytics Data Models

#### MemoryAnalytics (Primary Metrics)
```swift
@Model
final class MemoryAnalytics {
    var id: UUID
    var timestamp: Date
    var stmCount: Int
    var ltmCount: Int  
    var workingMemoryCount: Int
    var episodicMemoryCount: Int
    var totalEntities: Int
    var totalRelationships: Int
    var consolidationRate: Double // STM→LTM conversion rate
    var averageConfidence: Double
    var memoryEfficiency: Double // Storage efficiency metric
    var processingLatency: TimeInterval
    
    init(timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.stmCount = 0
        self.ltmCount = 0
        self.workingMemoryCount = 0
        self.episodicMemoryCount = 0
        self.totalEntities = 0
        self.totalRelationships = 0
        self.consolidationRate = 0.0
        self.averageConfidence = 0.0
        self.memoryEfficiency = 0.0
        self.processingLatency = 0.0
    }
}
```

#### ConsolidationEvent (Memory Flow Tracking)
```swift
@Model
final class ConsolidationEvent {
    var id: UUID
    var timestamp: Date
    var sourceType: MemoryType
    var targetType: MemoryType
    var itemsProcessed: Int
    var successfulConsolidations: Int
    var failedConsolidations: Int
    var processingTime: TimeInterval
    var triggerReason: ConsolidationTrigger
    var averageImportanceScore: Double
    
    init(sourceType: MemoryType, targetType: MemoryType) {
        self.id = UUID()
        self.timestamp = Date()
        self.sourceType = sourceType
        self.targetType = targetType
        self.itemsProcessed = 0
        self.successfulConsolidations = 0
        self.failedConsolidations = 0
        self.processingTime = 0.0
        self.triggerReason = .automatic
        self.averageImportanceScore = 0.0
    }
}

enum MemoryType: String, CaseIterable, Codable {
    case shortTerm = "STM"
    case longTerm = "LTM"
    case working = "Working"
    case episodic = "Episodic"
}

enum ConsolidationTrigger: String, CaseIterable, Codable {
    case automatic = "Automatic"
    case manual = "Manual"
    case capacityLimit = "Capacity Limit"
    case timeThreshold = "Time Threshold"
    case importanceThreshold = "Importance Threshold"
}
```

#### MemoryPerformanceMetric (Detailed Performance)
```swift
@Model
final class MemoryPerformanceMetric {
    var id: UUID
    var timestamp: Date
    var metricType: PerformanceMetricType
    var value: Double
    var context: String?
    var associatedMemoryID: String?
    var processingPhase: ProcessingPhase
    
    init(metricType: PerformanceMetricType, value: Double) {
        self.id = UUID()
        self.timestamp = Date()
        self.metricType = metricType
        self.value = value
        self.context = nil
        self.associatedMemoryID = nil
        self.processingPhase = .unknown
    }
}

enum PerformanceMetricType: String, CaseIterable, Codable {
    case retrievalLatency = "Retrieval Latency"
    case storageLatency = "Storage Latency"
    case consolidationLatency = "Consolidation Latency"
    case queryComplexity = "Query Complexity"
    case memoryFragmentation = "Memory Fragmentation"
    case entityLinkingEfficiency = "Entity Linking Efficiency"
    case knowledgeGraphDepth = "Knowledge Graph Depth"
    case semanticSimilarity = "Semantic Similarity"
}

enum ProcessingPhase: String, CaseIterable, Codable {
    case transcription = "Transcription"
    case entityExtraction = "Entity Extraction"
    case relationshipBuilding = "Relationship Building"
    case memoryStorage = "Memory Storage"
    case consolidation = "Consolidation"
    case retrieval = "Retrieval"
    case unknown = "Unknown"
}
```

### 2. Memory Analytics Service

#### Core Service Interface
```swift
protocol MemoryAnalyticsServiceProtocol {
    func collectMemorySnapshot() async -> MemoryAnalytics
    func trackConsolidationEvent(_ event: ConsolidationEvent) async
    func recordPerformanceMetric(_ metric: MemoryPerformanceMetric) async
    func getMemoryTrends(timeRange: DateInterval) async -> [MemoryAnalytics]
    func getConsolidationHistory(limit: Int) async -> [ConsolidationEvent]
    func calculateMemoryHealth() async -> MemoryHealthIndicators
    func generateMemoryReport(timeRange: DateInterval) async -> MemoryAnalyticsReport
}
```

#### Implementation with SwiftData Integration
```swift
actor MemoryAnalyticsService: MemoryAnalyticsServiceProtocol {
    private let modelContext: ModelContext
    private let memorySystem: MemorySystemProtocol
    
    init(modelContext: ModelContext, memorySystem: MemorySystemProtocol) {
        self.modelContext = modelContext
        self.memorySystem = memorySystem
    }
    
    func collectMemorySnapshot() async -> MemoryAnalytics {
        let analytics = MemoryAnalytics()
        
        // Collect current memory counts
        analytics.stmCount = await getMemoryCount(type: .shortTerm)
        analytics.ltmCount = await getMemoryCount(type: .longTerm)
        analytics.workingMemoryCount = await getMemoryCount(type: .working)
        analytics.episodicMemoryCount = await getMemoryCount(type: .episodic)
        
        // Calculate derived metrics
        analytics.consolidationRate = await calculateConsolidationRate()
        analytics.averageConfidence = await calculateAverageConfidence()
        analytics.memoryEfficiency = await calculateMemoryEfficiency()
        analytics.processingLatency = await getAverageProcessingLatency()
        
        // Persist analytics snapshot
        modelContext.insert(analytics)
        try? modelContext.save()
        
        return analytics
    }
    
    func calculateMemoryHealth() async -> MemoryHealthIndicators {
        let current = await collectMemorySnapshot()
        let previous = await getPreviousSnapshot()
        
        return MemoryHealthIndicators(
            overallHealth: calculateOverallHealth(current: current, previous: previous),
            stmUtilization: Double(current.stmCount) / Double(memorySystem.stmCapacity),
            ltmGrowthRate: calculateGrowthRate(current: current.ltmCount, previous: previous?.ltmCount),
            consolidationEfficiency: current.consolidationRate,
            averageLatency: current.processingLatency,
            recommendations: generateHealthRecommendations(current)
        )
    }
}
```

### 3. Dashboard UI Architecture

#### Main Dashboard View
```swift
struct MemoryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analyticsService: MemoryAnalyticsService
    @State private var currentMetrics: MemoryAnalytics?
    @State private var healthIndicators: MemoryHealthIndicators?
    @State private var selectedTimeRange: TimeRange = .last24Hours
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Real-time Memory Overview
                    MemoryOverviewCard(metrics: currentMetrics)
                    
                    // Memory Health Indicators
                    MemoryHealthCard(health: healthIndicators)
                    
                    // Memory Distribution Chart
                    MemoryDistributionChart(metrics: currentMetrics)
                    
                    // Consolidation Trends
                    ConsolidationTrendsChart(timeRange: selectedTimeRange)
                    
                    // Performance Metrics
                    PerformanceMetricsGrid()
                    
                    // Recent Activity
                    RecentMemoryActivity()
                }
                .padding()
            }
            .navigationTitle("Memory Analytics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    TimeRangePicker(selection: $selectedTimeRange)
                }
            }
        }
        .task {
            await loadAnalytics()
            startRealTimeUpdates()
        }
    }
    
    private func loadAnalytics() async {
        currentMetrics = await analyticsService.collectMemorySnapshot()
        healthIndicators = await analyticsService.calculateMemoryHealth()
    }
}
```

#### Memory Overview Card Component
```swift
struct MemoryOverviewCard: View {
    let metrics: MemoryAnalytics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Memory Overview")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                if let metrics = metrics {
                    Text(metrics.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let metrics = metrics {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    MemoryTypeCard(
                        title: "Short-Term Memory",
                        count: metrics.stmCount,
                        color: .blue,
                        icon: "brain.head.profile"
                    )
                    
                    MemoryTypeCard(
                        title: "Long-Term Memory", 
                        count: metrics.ltmCount,
                        color: .green,
                        icon: "archivebox"
                    )
                    
                    MemoryTypeCard(
                        title: "Working Memory",
                        count: metrics.workingMemoryCount,
                        color: .orange,
                        icon: "cpu"
                    )
                    
                    MemoryTypeCard(
                        title: "Episodic Memory",
                        count: metrics.episodicMemoryCount,
                        color: .purple,
                        icon: "timeline.selection"
                    )
                }
            } else {
                ProgressView("Loading memory analytics...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
```

### 4. Analytics Integration Points

#### Gemma3nCore Integration
```swift
extension Gemma3nCore {
    func processWithAnalytics(_ input: ProcessingInput) async -> ProcessingResult {
        let startTime = Date()
        
        // Record processing start
        let metric = MemoryPerformanceMetric(
            metricType: .storageLatency,
            value: 0
        )
        metric.processingPhase = .transcription
        
        // Existing processing logic...
        let result = await process(input)
        
        // Record completion metrics
        metric.value = Date().timeIntervalSince(startTime)
        await analyticsService.recordPerformanceMetric(metric)
        
        // Track memory changes
        if result.memoryUpdates.count > 0 {
            await analyticsService.collectMemorySnapshot()
        }
        
        return result
    }
}
```

#### Memory Consolidation Hook
```swift
extension MemoryConsolidationService {
    func consolidateWithAnalytics() async {
        let event = ConsolidationEvent(
            sourceType: .shortTerm,
            targetType: .longTerm
        )
        
        let startTime = Date()
        
        // Existing consolidation logic...
        let results = await performConsolidation()
        
        // Record consolidation metrics
        event.itemsProcessed = results.totalProcessed
        event.successfulConsolidations = results.successful
        event.failedConsolidations = results.failed
        event.processingTime = Date().timeIntervalSince(startTime)
        
        await analyticsService.trackConsolidationEvent(event)
    }
}
```

## Implementation Priority

### Phase 1: Foundation (Week 1-2)
1. Create analytics data models (MemoryAnalytics, ConsolidationEvent, MemoryPerformanceMetric)
2. Implement MemoryAnalyticsService core functionality
3. Add basic data collection hooks to existing memory operations
4. Create simple dashboard view structure

### Phase 2: Core Dashboard (Week 3-4)
1. Implement MemoryDashboardView with real-time updates
2. Create memory overview and health indicator cards
3. Add basic charts for memory distribution and trends
4. Implement time range selection and filtering

### Phase 3: Advanced Analytics (Week 5-6)
1. Add consolidation pattern analysis
2. Implement performance trend analysis
3. Create memory health scoring system
4. Add predictive analytics for memory usage

### Phase 4: Integration & Polish (Week 7)
1. Integrate dashboard into main app navigation
2. Add export capabilities for analytics data
3. Performance optimization and testing
4. Documentation and user guide creation

## Success Metrics

- **User Value**: Insights into memory system performance and optimization opportunities
- **System Health**: Real-time monitoring of memory consolidation efficiency
- **Performance**: Analytics system adds <5% overhead to core operations
- **Usability**: Dashboard loads in <2 seconds with real-time updates
- **Reliability**: 99.9% uptime for analytics data collection

This architecture provides a comprehensive foundation for implementing memory analytics in ProjectOne while maintaining performance and providing valuable insights into the sophisticated memory system.