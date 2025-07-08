import Foundation
import SwiftData
import UniformTypeIdentifiers
import Combine
import UIKit

/// Service for exporting and importing ProjectOne data in various formats
@MainActor
class DataExportService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var importProgress: Double = 0.0
    @Published var lastExportURL: URL?
    @Published var lastImportResult: ImportResult?
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Export Functions
    
    /// Export memory analytics data to JSON format
    func exportMemoryAnalytics(timeRange: DateInterval? = nil) async throws -> URL {
        isExporting = true
        exportProgress = 0.0
        defer { 
            isExporting = false
            exportProgress = 0.0
        }
        
        let analytics = try await fetchMemoryAnalytics(timeRange: timeRange)
        exportProgress = 0.3
        
        let exportData = MemoryAnalyticsExport(
            exportDate: Date(),
            timeRange: timeRange,
            analytics: analytics.map { MemoryAnalyticsData(from: $0) },
            metadata: createExportMetadata()
        )
        
        exportProgress = 0.6
        
        let jsonData = try JSONEncoder().encode(exportData)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "memory_analytics_\(ISO8601DateFormatter().string(from: Date())).json"
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        try jsonData.write(to: fileURL)
        exportProgress = 1.0
        
        lastExportURL = fileURL
        return fileURL
    }
    
    /// Export consolidation events to JSON format
    func exportConsolidationEvents(timeRange: DateInterval? = nil) async throws -> URL {
        isExporting = true
        exportProgress = 0.0
        defer { 
            isExporting = false
            exportProgress = 0.0
        }
        
        let events = try await fetchConsolidationEvents(timeRange: timeRange)
        exportProgress = 0.3
        
        let exportData = ConsolidationEventsExport(
            exportDate: Date(),
            timeRange: timeRange,
            events: events.map { ConsolidationEventData(from: $0) },
            metadata: createExportMetadata()
        )
        
        exportProgress = 0.6
        
        let jsonData = try JSONEncoder().encode(exportData)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "consolidation_events_\(ISO8601DateFormatter().string(from: Date())).json"
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        try jsonData.write(to: fileURL)
        exportProgress = 1.0
        
        lastExportURL = fileURL
        return fileURL
    }
    
    /// Export complete system data including all analytics and events
    func exportCompleteSystemData() async throws -> URL {
        isExporting = true
        exportProgress = 0.0
        defer { 
            isExporting = false
            exportProgress = 0.0
        }
        
        let analytics = try await fetchMemoryAnalytics()
        exportProgress = 0.2
        
        let events = try await fetchConsolidationEvents()
        exportProgress = 0.4
        
        let performanceMetrics = try await fetchPerformanceMetrics()
        exportProgress = 0.6
        
        let exportData = CompleteSystemExport(
            exportDate: Date(),
            analytics: analytics.map { MemoryAnalyticsData(from: $0) },
            consolidationEvents: events.map { ConsolidationEventData(from: $0) },
            performanceMetrics: performanceMetrics.map { MemoryPerformanceMetricData(from: $0) },
            metadata: createExportMetadata()
        )
        
        exportProgress = 0.8
        
        let jsonData = try JSONEncoder().encode(exportData)
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "complete_system_data_\(ISO8601DateFormatter().string(from: Date())).json"
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        try jsonData.write(to: fileURL)
        exportProgress = 1.0
        
        lastExportURL = fileURL
        return fileURL
    }
    
    /// Export data to CSV format for spreadsheet analysis
    func exportToCSV(dataType: ExportDataType) async throws -> URL {
        isExporting = true
        exportProgress = 0.0
        defer { 
            isExporting = false
            exportProgress = 0.0
        }
        
        let csvContent: String
        let fileName: String
        
        switch dataType {
        case .memoryAnalytics:
            let analytics = try await fetchMemoryAnalytics()
            csvContent = generateMemoryAnalyticsCSV(analytics)
            fileName = "memory_analytics_\(ISO8601DateFormatter().string(from: Date())).csv"
            
        case .consolidationEvents:
            let events = try await fetchConsolidationEvents()
            csvContent = generateConsolidationEventsCSV(events)
            fileName = "consolidation_events_\(ISO8601DateFormatter().string(from: Date())).csv"
            
        case .performanceMetrics:
            let metrics = try await fetchPerformanceMetrics()
            csvContent = generatePerformanceMetricsCSV(metrics)
            fileName = "performance_metrics_\(ISO8601DateFormatter().string(from: Date())).csv"
        }
        
        exportProgress = 0.8
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
        exportProgress = 1.0
        
        lastExportURL = fileURL
        return fileURL
    }
    
    // MARK: - Import Functions
    
    /// Import memory analytics data from JSON file
    func importData(from url: URL) async throws -> ImportResult {
        isImporting = true
        importProgress = 0.0
        defer { 
            isImporting = false
            importProgress = 0.0
        }
        
        let data = try Data(contentsOf: url)
        importProgress = 0.2
        
        // Try to determine the data type from the JSON structure
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        guard let json = json else {
            throw ImportError.invalidFormat
        }
        
        importProgress = 0.4
        
        let result: ImportResult
        
        if json.keys.contains("analytics") && json.keys.contains("consolidationEvents") {
            // Complete system export
            let exportData = try JSONDecoder().decode(CompleteSystemExport.self, from: data)
            result = try await importCompleteSystemData(exportData)
        } else if json.keys.contains("analytics") {
            // Memory analytics export
            let exportData = try JSONDecoder().decode(MemoryAnalyticsExport.self, from: data)
            result = try await importMemoryAnalytics(exportData)
        } else if json.keys.contains("events") {
            // Consolidation events export
            let exportData = try JSONDecoder().decode(ConsolidationEventsExport.self, from: data)
            result = try await importConsolidationEvents(exportData)
        } else {
            throw ImportError.unsupportedFormat
        }
        
        importProgress = 1.0
        lastImportResult = result
        
        return result
    }
    
    // MARK: - Private Methods
    
    private func fetchMemoryAnalytics(timeRange: DateInterval? = nil) async throws -> [MemoryAnalytics] {
        if let timeRange = timeRange {
            let predicate = #Predicate<MemoryAnalytics> { analytics in
                analytics.timestamp >= timeRange.start && analytics.timestamp <= timeRange.end
            }
            var descriptor = FetchDescriptor<MemoryAnalytics>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            return try modelContext.fetch(descriptor)
        } else {
            var descriptor = FetchDescriptor<MemoryAnalytics>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            return try modelContext.fetch(descriptor)
        }
    }
    
    private func fetchConsolidationEvents(timeRange: DateInterval? = nil) async throws -> [ConsolidationEvent] {
        if let timeRange = timeRange {
            let predicate = #Predicate<ConsolidationEvent> { event in
                event.timestamp >= timeRange.start && event.timestamp <= timeRange.end
            }
            var descriptor = FetchDescriptor<ConsolidationEvent>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            return try modelContext.fetch(descriptor)
        } else {
            var descriptor = FetchDescriptor<ConsolidationEvent>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            return try modelContext.fetch(descriptor)
        }
    }
    
    private func fetchPerformanceMetrics(timeRange: DateInterval? = nil) async throws -> [MemoryPerformanceMetric] {
        if let timeRange = timeRange {
            let predicate = #Predicate<MemoryPerformanceMetric> { metric in
                metric.timestamp >= timeRange.start && metric.timestamp <= timeRange.end
            }
            var descriptor = FetchDescriptor<MemoryPerformanceMetric>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            return try modelContext.fetch(descriptor)
        } else {
            var descriptor = FetchDescriptor<MemoryPerformanceMetric>()
            descriptor.sortBy = [SortDescriptor(\.timestamp, order: .forward)]
            return try modelContext.fetch(descriptor)
        }
    }
    
    private func createExportMetadata() -> ExportMetadata {
        return ExportMetadata(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            exportVersion: "1.0",
            platform: "iOS",
            deviceModel: UIDevice.current.model
        )
    }
    
    // MARK: - CSV Generation
    
    private func generateMemoryAnalyticsCSV(_ analytics: [MemoryAnalytics]) -> String {
        var csv = "Timestamp,STM Count,LTM Count,Working Memory Count,Episodic Memory Count,Total Entities,Total Relationships,Consolidation Rate,Average Confidence,Memory Efficiency,Processing Latency,Memory Pressure,Fragmentation Index,Query Complexity,Health Score\n"
        
        let formatter = ISO8601DateFormatter()
        
        for item in analytics {
            csv += "\(formatter.string(from: item.timestamp)),"
            csv += "\(item.stmCount),"
            csv += "\(item.ltmCount),"
            csv += "\(item.workingMemoryCount),"
            csv += "\(item.episodicMemoryCount),"
            csv += "\(item.totalEntities),"
            csv += "\(item.totalRelationships),"
            csv += "\(item.consolidationRate),"
            csv += "\(item.averageConfidence),"
            csv += "\(item.memoryEfficiency),"
            csv += "\(item.processingLatency),"
            csv += "\(item.memoryPressure),"
            csv += "\(item.fragmentationIndex),"
            csv += "\(item.queryComplexity),"
            csv += "\(item.healthScore)\n"
        }
        
        return csv
    }
    
    private func generateConsolidationEventsCSV(_ events: [ConsolidationEvent]) -> String {
        var csv = "Timestamp,Source Type,Target Type,Trigger Reason,Items Processed,Successful Consolidations,Failed Consolidations,Success Rate,Processing Time,Efficiency\n"
        
        let formatter = ISO8601DateFormatter()
        
        for event in events {
            csv += "\(formatter.string(from: event.timestamp)),"
            csv += "\(event.sourceType.rawValue),"
            csv += "\(event.targetType.rawValue),"
            csv += "\(event.triggerReason.rawValue),"
            csv += "\(event.itemsProcessed),"
            csv += "\(event.successfulConsolidations),"
            csv += "\(event.failedConsolidations),"
            csv += "\(event.successRate),"
            csv += "\(event.processingTime),"
            csv += "\(event.efficiency)\n"
        }
        
        return csv
    }
    
    private func generatePerformanceMetricsCSV(_ metrics: [MemoryPerformanceMetric]) -> String {
        var csv = "Timestamp,Metric Type,Value,Processing Phase,Performance Status,Efficiency\n"
        
        let formatter = ISO8601DateFormatter()
        
        for metric in metrics {
            csv += "\(formatter.string(from: metric.timestamp)),"
            csv += "\(metric.metricType.rawValue),"
            csv += "\(metric.value),"
            csv += "\(metric.processingPhase.rawValue),"
            csv += "\(metric.performanceStatus.rawValue),"
            csv += "\(metric.efficiency)\n"
        }
        
        return csv
    }
    
    // MARK: - Import Implementation
    
    private func importMemoryAnalytics(_ exportData: MemoryAnalyticsExport) async throws -> ImportResult {
        var importedCount = 0
        var skippedCount = 0
        
        for analyticsData in exportData.analytics {
            // Check if this analytics entry already exists (by timestamp)
            let exists = try await analyticsExists(timestamp: analyticsData.timestamp)
            
            if !exists {
                let analytics = analyticsData.toSwiftDataModel()
                modelContext.insert(analytics)
                importedCount += 1
            } else {
                skippedCount += 1
            }
            
            importProgress = Double(importedCount + skippedCount) / Double(exportData.analytics.count) * 0.8 + 0.4
        }
        
        try modelContext.save()
        
        return ImportResult(
            type: .memoryAnalytics,
            importedCount: importedCount,
            skippedCount: skippedCount,
            errors: [],
            metadata: exportData.metadata
        )
    }
    
    private func importConsolidationEvents(_ exportData: ConsolidationEventsExport) async throws -> ImportResult {
        var importedCount = 0
        var skippedCount = 0
        
        for eventData in exportData.events {
            // Check if this event already exists (by timestamp and trigger reason)
            let exists = try await eventExists(timestamp: eventData.timestamp, triggerReason: eventData.triggerReason)
            
            if !exists {
                let event = eventData.toSwiftDataModel()
                modelContext.insert(event)
                importedCount += 1
            } else {
                skippedCount += 1
            }
            
            importProgress = Double(importedCount + skippedCount) / Double(exportData.events.count) * 0.8 + 0.4
        }
        
        try modelContext.save()
        
        return ImportResult(
            type: .consolidationEvents,
            importedCount: importedCount,
            skippedCount: skippedCount,
            errors: [],
            metadata: exportData.metadata
        )
    }
    
    private func importCompleteSystemData(_ exportData: CompleteSystemExport) async throws -> ImportResult {
        var totalImported = 0
        var totalSkipped = 0
        
        // Import analytics
        let analyticsResult = try await importMemoryAnalytics(
            MemoryAnalyticsExport(
                exportDate: exportData.exportDate,
                timeRange: nil,
                analytics: exportData.analytics,
                metadata: exportData.metadata
            )
        )
        totalImported += analyticsResult.importedCount
        totalSkipped += analyticsResult.skippedCount
        
        // Import events
        let eventsResult = try await importConsolidationEvents(
            ConsolidationEventsExport(
                exportDate: exportData.exportDate,
                timeRange: nil,
                events: exportData.consolidationEvents,
                metadata: exportData.metadata
            )
        )
        totalImported += eventsResult.importedCount
        totalSkipped += eventsResult.skippedCount
        
        // Import performance metrics
        for metricData in exportData.performanceMetrics {
            let exists = try await metricExists(timestamp: metricData.timestamp, metricType: metricData.metricType)
            
            if !exists {
                let metric = metricData.toSwiftDataModel()
                modelContext.insert(metric)
                totalImported += 1
            } else {
                totalSkipped += 1
            }
        }
        
        try modelContext.save()
        
        return ImportResult(
            type: .completeSystem,
            importedCount: totalImported,
            skippedCount: totalSkipped,
            errors: [],
            metadata: exportData.metadata
        )
    }
    
    // MARK: - Existence Checks
    
    private func analyticsExists(timestamp: Date) async throws -> Bool {
        let predicate = #Predicate<MemoryAnalytics> { analytics in
            analytics.timestamp == timestamp
        }
        var descriptor = FetchDescriptor<MemoryAnalytics>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        let results = try modelContext.fetch(descriptor)
        return !results.isEmpty
    }
    
    private func eventExists(timestamp: Date, triggerReason: ConsolidationTrigger) async throws -> Bool {
        let predicate = #Predicate<ConsolidationEvent> { event in
            event.timestamp == timestamp && event.triggerReason == triggerReason
        }
        var descriptor = FetchDescriptor<ConsolidationEvent>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        let results = try modelContext.fetch(descriptor)
        return !results.isEmpty
    }
    
    private func metricExists(timestamp: Date, metricType: PerformanceMetricType) async throws -> Bool {
        let predicate = #Predicate<MemoryPerformanceMetric> { metric in
            metric.timestamp == timestamp && metric.metricType == metricType
        }
        var descriptor = FetchDescriptor<MemoryPerformanceMetric>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        let results = try modelContext.fetch(descriptor)
        return !results.isEmpty
    }
}

// MARK: - Export Data Models

struct MemoryAnalyticsExport: Codable {
    let exportDate: Date
    let timeRange: DateInterval?
    let analytics: [MemoryAnalyticsData]
    let metadata: ExportMetadata
}

struct ConsolidationEventsExport: Codable {
    let exportDate: Date
    let timeRange: DateInterval?
    let events: [ConsolidationEventData]
    let metadata: ExportMetadata
}

struct CompleteSystemExport: Codable {
    let exportDate: Date
    let analytics: [MemoryAnalyticsData]
    let consolidationEvents: [ConsolidationEventData]
    let performanceMetrics: [MemoryPerformanceMetricData]
    let metadata: ExportMetadata
}

// Codable data structures for SwiftData models
struct MemoryAnalyticsData: Codable {
    let id: UUID
    let timestamp: Date
    let stmCount: Int
    let ltmCount: Int
    let workingMemoryCount: Int
    let episodicMemoryCount: Int
    let totalEntities: Int
    let totalRelationships: Int
    let entityTypes: [String: Int]
    let consolidationRate: Double
    let averageConfidence: Double
    let memoryEfficiency: Double
    let processingLatency: TimeInterval
    let memoryPressure: Double
    let fragmentationIndex: Double
    let queryComplexity: Double
    
    init(from analytics: MemoryAnalytics) {
        self.id = analytics.id
        self.timestamp = analytics.timestamp
        self.stmCount = analytics.stmCount
        self.ltmCount = analytics.ltmCount
        self.workingMemoryCount = analytics.workingMemoryCount
        self.episodicMemoryCount = analytics.episodicMemoryCount
        self.totalEntities = analytics.totalEntities
        self.totalRelationships = analytics.totalRelationships
        self.entityTypes = analytics.entityTypes
        self.consolidationRate = analytics.consolidationRate
        self.averageConfidence = analytics.averageConfidence
        self.memoryEfficiency = analytics.memoryEfficiency
        self.processingLatency = analytics.processingLatency
        self.memoryPressure = analytics.memoryPressure
        self.fragmentationIndex = analytics.fragmentationIndex
        self.queryComplexity = analytics.queryComplexity
    }
    
    func toSwiftDataModel() -> MemoryAnalytics {
        let analytics = MemoryAnalytics(timestamp: timestamp)
        analytics.id = id
        analytics.stmCount = stmCount
        analytics.ltmCount = ltmCount
        analytics.workingMemoryCount = workingMemoryCount
        analytics.episodicMemoryCount = episodicMemoryCount
        analytics.totalEntities = totalEntities
        analytics.totalRelationships = totalRelationships
        analytics.entityTypes = entityTypes
        analytics.consolidationRate = consolidationRate
        analytics.averageConfidence = averageConfidence
        analytics.memoryEfficiency = memoryEfficiency
        analytics.processingLatency = processingLatency
        analytics.memoryPressure = memoryPressure
        analytics.fragmentationIndex = fragmentationIndex
        analytics.queryComplexity = queryComplexity
        return analytics
    }
}

struct ConsolidationEventData: Codable {
    let id: UUID
    let timestamp: Date
    let sourceType: MemoryType
    let targetType: MemoryType
    let itemsProcessed: Int
    let successfulConsolidations: Int
    let failedConsolidations: Int
    let processingTime: TimeInterval
    let triggerReason: ConsolidationTrigger
    let averageImportanceScore: Double
    let averageConfidenceScore: Double
    let contextType: String?
    let userInitiated: Bool
    let systemLoad: Double
    
    init(from event: ConsolidationEvent) {
        self.id = event.id
        self.timestamp = event.timestamp
        self.sourceType = event.sourceType
        self.targetType = event.targetType
        self.itemsProcessed = event.itemsProcessed
        self.successfulConsolidations = event.successfulConsolidations
        self.failedConsolidations = event.failedConsolidations
        self.processingTime = event.processingTime
        self.triggerReason = event.triggerReason
        self.averageImportanceScore = event.averageImportanceScore
        self.averageConfidenceScore = event.averageConfidenceScore
        self.contextType = event.contextType
        self.userInitiated = event.userInitiated
        self.systemLoad = event.systemLoad
    }
    
    func toSwiftDataModel() -> ConsolidationEvent {
        let event = ConsolidationEvent(sourceType: sourceType, targetType: targetType, triggerReason: triggerReason)
        event.id = id
        event.timestamp = timestamp
        event.itemsProcessed = itemsProcessed
        event.successfulConsolidations = successfulConsolidations
        event.failedConsolidations = failedConsolidations
        event.processingTime = processingTime
        event.averageImportanceScore = averageImportanceScore
        event.averageConfidenceScore = averageConfidenceScore
        event.contextType = contextType
        event.userInitiated = userInitiated
        event.systemLoad = systemLoad
        return event
    }
}

struct MemoryPerformanceMetricData: Codable {
    let id: UUID
    let timestamp: Date
    let metricType: PerformanceMetricType
    let value: Double
    let unit: String
    let context: String?
    let associatedMemoryID: String?
    let processingPhase: ProcessingPhase
    let operationType: OperationType
    let duration: TimeInterval
    let resourceUsage: Double
    let complexityScore: Double
    let batchSize: Int
    let accuracyScore: Double?
    let confidenceScore: Double?
    let userSatisfaction: Double?
    
    init(from metric: MemoryPerformanceMetric) {
        self.id = metric.id
        self.timestamp = metric.timestamp
        self.metricType = metric.metricType
        self.value = metric.value
        self.unit = metric.unit
        self.context = metric.context
        self.associatedMemoryID = metric.associatedMemoryID
        self.processingPhase = metric.processingPhase
        self.operationType = metric.operationType
        self.duration = metric.duration
        self.resourceUsage = metric.resourceUsage
        self.complexityScore = metric.complexityScore
        self.batchSize = metric.batchSize
        self.accuracyScore = metric.accuracyScore
        self.confidenceScore = metric.confidenceScore
        self.userSatisfaction = metric.userSatisfaction
    }
    
    func toSwiftDataModel() -> MemoryPerformanceMetric {
        let metric = MemoryPerformanceMetric(metricType: metricType, value: value, unit: unit)
        metric.id = id
        metric.timestamp = timestamp
        metric.context = context
        metric.associatedMemoryID = associatedMemoryID
        metric.processingPhase = processingPhase
        metric.operationType = operationType
        metric.duration = duration
        metric.resourceUsage = resourceUsage
        metric.complexityScore = complexityScore
        metric.batchSize = batchSize
        metric.accuracyScore = accuracyScore
        metric.confidenceScore = confidenceScore
        metric.userSatisfaction = userSatisfaction
        return metric
    }
}

struct ExportMetadata: Codable {
    let appVersion: String
    let exportVersion: String
    let platform: String
    let deviceModel: String
}

// MARK: - Import Result

struct ImportResult {
    let type: ImportDataType
    let importedCount: Int
    let skippedCount: Int
    let errors: [ImportError]
    let metadata: ExportMetadata?
}

enum ImportDataType {
    case memoryAnalytics
    case consolidationEvents
    case completeSystem
}

enum ExportDataType {
    case memoryAnalytics
    case consolidationEvents
    case performanceMetrics
}

enum ImportError: Error {
    case invalidFormat
    case unsupportedFormat
    case duplicateData
    case corruptedData
    case incompatibleVersion
}