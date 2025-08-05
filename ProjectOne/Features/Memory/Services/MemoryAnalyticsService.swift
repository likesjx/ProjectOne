import Foundation
import SwiftData
import Combine

/// Core service for collecting, analyzing, and managing memory system analytics
@MainActor
class MemoryAnalyticsService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentMetrics: MemoryAnalytics?
    @Published var recentEvents: [ConsolidationEvent] = []
    @Published var performanceMetrics: [MemoryPerformanceMetric] = []
    @Published var isCollecting: Bool = false
    @Published var healthStatus: HealthStatus = .fair
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private var analyticsTimer: Timer?
    private let collectionInterval: TimeInterval = 30.0 // Collect metrics every 30 seconds
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        Task {
            await loadRecentData()
            startPeriodicCollection()
        }
    }
    
    deinit {
        // Note: Cannot safely invalidate timer from deinit due to MainActor isolation
        // Timer will be cleaned up automatically when service is deallocated
    }
    
    // MARK: - Public API
    
    /// Collect a comprehensive memory snapshot
    func collectMemorySnapshot() async {
        isCollecting = true
        defer { isCollecting = false }
        
        let analytics = MemoryAnalytics()
        
        do {
            // Collect memory counts by type
            analytics.stmCount = try await getMemoryCount(type: .working) // Working memory = STM
            analytics.ltmCount = try await getMemoryCount(type: .semantic) // Semantic memory = LTM
            analytics.workingMemoryCount = try await getMemoryCount(type: .working)
            analytics.episodicMemoryCount = try await getMemoryCount(type: .episodic)
            
            // Collect knowledge graph metrics
            analytics.totalEntities = try await getEntityCount()
            analytics.totalRelationships = try await getRelationshipCount()
            analytics.entityTypes = try await getEntityTypeCounts()
            
            // Calculate performance metrics
            analytics.consolidationRate = await calculateConsolidationRate()
            analytics.averageConfidence = try await calculateAverageConfidence()
            analytics.memoryEfficiency = await calculateMemoryEfficiency()
            analytics.processingLatency = await getAverageProcessingLatency()
            
            // Calculate health indicators
            analytics.memoryPressure = await calculateMemoryPressure()
            analytics.fragmentationIndex = await calculateFragmentationIndex()
            analytics.queryComplexity = await getAverageQueryComplexity()
            
            // Persist analytics snapshot
            modelContext.insert(analytics)
            try modelContext.save()
            
            // Update published properties
            self.currentMetrics = analytics
            self.healthStatus = analytics.healthStatus
            
        } catch {
            print("Error collecting memory snapshot: \(error)")
        }
    }
    
    /// Track a memory consolidation event
    func trackConsolidationEvent(_ event: ConsolidationEvent) async {
        do {
            modelContext.insert(event)
            try modelContext.save()
            
            // Add to recent events (keep last 50)
            recentEvents.insert(event, at: 0)
            if recentEvents.count > 50 {
                recentEvents = Array(recentEvents.prefix(50))
            }
            
        } catch {
            print("Error tracking consolidation event: \(error)")
        }
    }
    
    /// Record a performance metric
    func recordPerformanceMetric(_ metric: MemoryPerformanceMetric) async {
        do {
            modelContext.insert(metric)
            try modelContext.save()
            
            // Add to recent metrics (keep last 100)
            performanceMetrics.insert(metric, at: 0)
            if performanceMetrics.count > 100 {
                performanceMetrics = Array(performanceMetrics.prefix(100))
            }
            
        } catch {
            print("Error recording performance metric: \(error)")
        }
    }
    
    /// Get memory trends over a time range
    func getMemoryTrends(timeRange: DateInterval) async -> [MemoryAnalytics] {
        do {
            let predicate = #Predicate<MemoryAnalytics> { analytics in
                analytics.timestamp >= timeRange.start && analytics.timestamp <= timeRange.end
            }
            
            var descriptor = FetchDescriptor<MemoryAnalytics>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching memory trends: \(error)")
            return []
        }
    }
    
    /// Get consolidation history
    func getConsolidationHistory(limit: Int = 50) async -> [ConsolidationEvent] {
        do {
            var descriptor = FetchDescriptor<ConsolidationEvent>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching consolidation history: \(error)")
            return []
        }
    }
    
    /// Calculate overall memory health indicators
    func calculateMemoryHealth() async -> MemoryHealthIndicators {
        guard let current = currentMetrics else {
            return MemoryHealthIndicators.defaultHealth()
        }
        
        let previous = await getPreviousSnapshot()
        let recentEvents = await getConsolidationHistory(limit: 10)
        
        return MemoryHealthIndicators(
            overallHealth: current.healthScore,
            stmUtilization: calculateSTMUtilization(),
            ltmGrowthRate: calculateLTMGrowthRate(current: current, previous: previous),
            consolidationEfficiency: current.consolidationRate,
            averageLatency: current.processingLatency,
            errorRate: await calculateErrorRate(),
            recommendations: generateHealthRecommendations(current: current, events: recentEvents)
        )
    }
    
    /// Generate comprehensive memory analytics report
    func generateMemoryReport(timeRange: DateInterval) async -> MemoryAnalyticsReport {
        let trends = await getMemoryTrends(timeRange: timeRange)
        let events = await getConsolidationHistory(limit: 100)
        let metrics = await getPerformanceMetrics(timeRange: timeRange)
        let health = await calculateMemoryHealth()
        
        return MemoryAnalyticsReport(
            timeRange: timeRange,
            memoryTrends: trends,
            consolidationEvents: events,
            performanceMetrics: metrics,
            healthIndicators: health,
            summary: generateReportSummary(trends: trends, events: events),
            recommendations: generateOptimizationRecommendations(trends: trends, events: events, metrics: metrics)
        )
    }
    
    // MARK: - Private Methods
    
    private func loadRecentData() async {
        // Load recent metrics
        currentMetrics = await getLatestSnapshot()
        
        // Load recent events
        recentEvents = await getConsolidationHistory(limit: 50)
        
        // Load recent performance metrics
        performanceMetrics = await getRecentPerformanceMetrics(limit: 100)
        
        // Update health status
        if let current = currentMetrics {
            healthStatus = current.healthStatus
        }
    }
    
    private func startPeriodicCollection() {
        analyticsTimer = Timer.scheduledTimer(withTimeInterval: collectionInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.collectMemorySnapshot()
            }
        }
    }
    
    private func stopPeriodicCollection() {
        analyticsTimer?.invalidate()
        analyticsTimer = nil
    }
    
    // MARK: - Data Collection Methods
    
    public func getMemoryCount(type: MemoryType) async throws -> Int {
        switch type {
        case .working:
            let descriptor = FetchDescriptor<WorkingMemoryEntry>()
            return try modelContext.fetch(descriptor).count
        case .semantic:
            let descriptor = FetchDescriptor<STMEntry>(
                predicate: #Predicate<STMEntry> { $0.memoryTypeRawValue == "semantic" }
            )
            return try modelContext.fetch(descriptor).count
        case .procedural:
            let descriptor = FetchDescriptor<STMEntry>(
                predicate: #Predicate<STMEntry> { $0.memoryTypeRawValue == "procedural" }
            )
            return try modelContext.fetch(descriptor).count
        case .episodic:
            let descriptor = FetchDescriptor<EpisodicMemoryEntry>()
            return try modelContext.fetch(descriptor).count
        }
    }
    
    public func getEntityCount() async throws -> Int {
        let descriptor = FetchDescriptor<Entity>()
        return try modelContext.fetch(descriptor).count
    }
    
    public func getRelationshipCount() async throws -> Int {
        let descriptor = FetchDescriptor<Relationship>()
        return try modelContext.fetch(descriptor).count
    }
    
    public func getEntityTypeCounts() async throws -> [String: Int] {
        let descriptor = FetchDescriptor<Entity>()
        let entities = try modelContext.fetch(descriptor)
        
        var typeCounts: [String: Int] = [:]
        for entity in entities {
            let typeKey = entity.type.rawValue
            typeCounts[typeKey, default: 0] += 1
        }
        
        return typeCounts
    }
    
    // MARK: - Calculation Methods
    
    private func calculateConsolidationRate() async -> Double {
        let last24Hours = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let events = await getConsolidationEvents(timeRange: last24Hours)
        
        guard !events.isEmpty else { return 0.0 }
        
        let totalProcessed = events.reduce(0) { $0 + $1.itemsProcessed }
        let totalSuccessful = events.reduce(0) { $0 + $1.successfulConsolidations }
        
        guard totalProcessed > 0 else { return 0.0 }
        return Double(totalSuccessful) / Double(totalProcessed)
    }
    
    private func calculateAverageConfidence() async throws -> Double {
        // TODO: Calculate average confidence across all memory types
        // Placeholder implementation until memory models are created
        return 0.85 // Default confidence score
    }
    
    private func calculateMemoryEfficiency() async -> Double {
        // Memory efficiency based on consolidation rate and storage optimization
        let consolidationRate = await calculateConsolidationRate()
        let fragmentationIndex = await calculateFragmentationIndex()
        
        return (consolidationRate + (1.0 - fragmentationIndex)) / 2.0
    }
    
    private func getAverageProcessingLatency() async -> TimeInterval {
        let last24Hours = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let metrics = await getPerformanceMetrics(timeRange: last24Hours)
        
        let latencyMetrics = metrics.filter { metric in
            [.retrievalLatency, .storageLatency, .consolidationLatency, .queryLatency].contains(metric.metricType)
        }
        
        guard !latencyMetrics.isEmpty else { return 0.0 }
        
        let totalLatency = latencyMetrics.reduce(0.0) { $0 + $1.value }
        return (totalLatency / Double(latencyMetrics.count)) / 1000.0 // Convert ms to seconds
    }
    
    private func calculateMemoryPressure() async -> Double {
        // Calculate memory pressure based on capacity utilization
        let totalItems = (currentMetrics?.totalMemoryItems ?? 0)
        let estimatedCapacity = 10000 // Configurable capacity limit
        
        return min(1.0, Double(totalItems) / Double(estimatedCapacity))
    }
    
    private func calculateFragmentationIndex() async -> Double {
        // Calculate memory fragmentation based on consolidation patterns
        let events = await getConsolidationHistory(limit: 20)
        
        guard !events.isEmpty else { return 0.0 }
        
        let averageEfficiency = events.reduce(0.0) { $0 + $1.efficiency } / Double(events.count)
        return 1.0 - averageEfficiency
    }
    
    private func getAverageQueryComplexity() async -> Double {
        let last24Hours = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let metrics = await getPerformanceMetrics(timeRange: last24Hours)
        
        let complexityMetrics = metrics.filter { $0.metricType == .queryComplexity }
        
        guard !complexityMetrics.isEmpty else { return 0.0 }
        
        return complexityMetrics.reduce(0.0) { $0 + $1.value } / Double(complexityMetrics.count)
    }
    
    // MARK: - Helper Methods
    
    private func getLatestSnapshot() async -> MemoryAnalytics? {
        do {
            var descriptor = FetchDescriptor<MemoryAnalytics>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            descriptor.fetchLimit = 1
            
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching latest snapshot: \(error)")
            return nil
        }
    }
    
    private func getPreviousSnapshot() async -> MemoryAnalytics? {
        do {
            var descriptor = FetchDescriptor<MemoryAnalytics>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            descriptor.fetchLimit = 2
            
            let snapshots = try modelContext.fetch(descriptor)
            return snapshots.count > 1 ? snapshots[1] : nil
        } catch {
            print("Error fetching previous snapshot: \(error)")
            return nil
        }
    }
    
    private func getConsolidationEvents(timeRange: DateInterval) async -> [ConsolidationEvent] {
        do {
            let predicate = #Predicate<ConsolidationEvent> { event in
                event.timestamp >= timeRange.start && event.timestamp <= timeRange.end
            }
            
            var descriptor = FetchDescriptor<ConsolidationEvent>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching consolidation events: \(error)")
            return []
        }
    }
    
    private func getPerformanceMetrics(timeRange: DateInterval) async -> [MemoryPerformanceMetric] {
        do {
            let predicate = #Predicate<MemoryPerformanceMetric> { metric in
                metric.timestamp >= timeRange.start && metric.timestamp <= timeRange.end
            }
            
            var descriptor = FetchDescriptor<MemoryPerformanceMetric>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching performance metrics: \(error)")
            return []
        }
    }
    
    private func getRecentPerformanceMetrics(limit: Int) async -> [MemoryPerformanceMetric] {
        do {
            var descriptor = FetchDescriptor<MemoryPerformanceMetric>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching recent performance metrics: \(error)")
            return []
        }
    }
    
    private func calculateSTMUtilization() -> Double {
        guard let current = currentMetrics else { return 0.0 }
        let capacity = 1000 // Configurable STM capacity
        return min(1.0, Double(current.stmCount) / Double(capacity))
    }
    
    private func calculateLTMGrowthRate(current: MemoryAnalytics, previous: MemoryAnalytics?) -> Double {
        return current.growthRate(comparedTo: previous)
    }
    
    private func calculateErrorRate() async -> Double {
        let last24Hours = DateInterval(start: Date().addingTimeInterval(-86400), end: Date())
        let metrics = await getPerformanceMetrics(timeRange: last24Hours)
        
        let errorMetrics = metrics.filter { $0.metricType == .errorRate }
        guard !errorMetrics.isEmpty else { return 0.0 }
        
        return errorMetrics.reduce(0.0) { $0 + $1.value } / Double(errorMetrics.count)
    }
    
    private func generateHealthRecommendations(current: MemoryAnalytics, events: [ConsolidationEvent]) -> [String] {
        var recommendations: [String] = []
        
        if current.healthScore < 0.7 {
            recommendations.append("System health is below optimal - consider running optimization")
        }
        
        if current.consolidationRate < 0.8 {
            recommendations.append("Consolidation efficiency is low - review consolidation criteria")
        }
        
        if current.memoryPressure > 0.8 {
            recommendations.append("Memory pressure is high - consider archiving old data")
        }
        
        if current.processingLatency > 2.0 {
            recommendations.append("Processing latency is high - optimize query complexity")
        }
        
        return recommendations
    }
    
    private func generateReportSummary(trends: [MemoryAnalytics], events: [ConsolidationEvent]) -> String {
        let totalSnapshots = trends.count
        let totalEvents = events.count
        let averageHealth = trends.isEmpty ? 0.0 : trends.reduce(0.0) { $0 + $1.healthScore } / Double(trends.count)
        
        return "Report covers \(totalSnapshots) snapshots and \(totalEvents) consolidation events with average health score of \(String(format: "%.2f", averageHealth))"
    }
    
    private func generateOptimizationRecommendations(trends: [MemoryAnalytics], events: [ConsolidationEvent], metrics: [MemoryPerformanceMetric]) -> [String] {
        var recommendations: [String] = []
        
        // Analyze trends
        if trends.count >= 2 {
            let latest = trends.last!
            let earliest = trends.first!
            
            if latest.healthScore < earliest.healthScore {
                recommendations.append("Health score is declining - investigate system performance")
            }
        }
        
        // Analyze consolidation efficiency
        let avgConsolidationEfficiency = events.isEmpty ? 0.0 : events.reduce(0.0) { $0 + $1.efficiency } / Double(events.count)
        if avgConsolidationEfficiency < 0.7 {
            recommendations.append("Consolidation efficiency is below target - review consolidation algorithms")
        }
        
        // Analyze performance metrics
        let slowMetrics = metrics.filter { $0.indicatesIssue }
        if !slowMetrics.isEmpty {
            recommendations.append("Performance issues detected in \(slowMetrics.count) metrics - review system optimization")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

struct MemoryHealthIndicators {
    let overallHealth: Double
    let stmUtilization: Double
    let ltmGrowthRate: Double
    let consolidationEfficiency: Double
    let averageLatency: TimeInterval
    let errorRate: Double
    let recommendations: [String]
    
    static func defaultHealth() -> MemoryHealthIndicators {
        return MemoryHealthIndicators(
            overallHealth: 0.5,
            stmUtilization: 0.0,
            ltmGrowthRate: 0.0,
            consolidationEfficiency: 0.0,
            averageLatency: 0.0,
            errorRate: 0.0,
            recommendations: ["Initialize system to begin collecting health metrics"]
        )
    }
}

struct MemoryAnalyticsReport {
    let timeRange: DateInterval
    let memoryTrends: [MemoryAnalytics]
    let consolidationEvents: [ConsolidationEvent]
    let performanceMetrics: [MemoryPerformanceMetric]
    let healthIndicators: MemoryHealthIndicators
    let summary: String
    let recommendations: [String]
}