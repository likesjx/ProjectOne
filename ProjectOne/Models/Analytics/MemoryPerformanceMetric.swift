import Foundation
import SwiftData

/// Detailed performance metrics for memory system operations
@Model
final class MemoryPerformanceMetric {
    var id: UUID
    var timestamp: Date
    
    // Metric identification
    var metricType: PerformanceMetricType
    var value: Double
    var unit: String
    
    // Context information
    var context: String? // Additional context about the metric
    var associatedMemoryID: String? // ID of related memory item
    var processingPhase: ProcessingPhase
    var operationType: OperationType
    
    // Performance details
    var duration: TimeInterval // How long the operation took
    var resourceUsage: Double // CPU/Memory usage during operation (0.0-1.0)
    var complexityScore: Double // Complexity of the operation (0.0-1.0)
    var batchSize: Int // Number of items processed in batch operation
    
    // Quality metrics
    var accuracyScore: Double? // Accuracy of the operation (0.0-1.0)
    var confidenceScore: Double? // Confidence in the result (0.0-1.0)
    var userSatisfaction: Double? // User satisfaction rating (0.0-1.0)
    
    init(metricType: PerformanceMetricType, value: Double, unit: String = "") {
        self.id = UUID()
        self.timestamp = Date()
        self.metricType = metricType
        self.value = value
        self.unit = unit
        self.context = nil
        self.associatedMemoryID = nil
        self.processingPhase = .unknown
        self.operationType = .query
        self.duration = 0.0
        self.resourceUsage = 0.0
        self.complexityScore = 0.0
        self.batchSize = 1
        self.accuracyScore = nil
        self.confidenceScore = nil
        self.userSatisfaction = nil
    }
    
    // MARK: - Computed Properties
    
    /// Formatted value with unit
    var formattedValue: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 3
        numberFormatter.minimumFractionDigits = 0
        
        let valueString = numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return unit.isEmpty ? valueString : "\(valueString) \(unit)"
    }
    
    /// Performance efficiency score (higher is better)
    var efficiency: Double {
        guard duration > 0 else { return 0.0 }
        
        let timeEfficiency = min(1.0, 1.0 / duration) // Prefer faster operations
        let resourceEfficiency = 1.0 - resourceUsage // Prefer lower resource usage
        let batchEfficiency = min(1.0, Double(batchSize) / 10.0) // Prefer larger batches
        
        return (timeEfficiency + resourceEfficiency + batchEfficiency) / 3.0
    }
    
    /// Overall quality score combining accuracy, confidence, and user satisfaction
    var qualityScore: Double? {
        let scores = [accuracyScore, confidenceScore, userSatisfaction].compactMap { $0 }
        guard !scores.isEmpty else { return nil }
        
        return scores.reduce(0.0, +) / Double(scores.count)
    }
    
    /// Performance status based on efficiency and quality
    var performanceStatus: PerformanceStatus {
        let efficiencyThreshold: Double = 0.7
        let qualityThreshold: Double = 0.8
        
        let hasGoodEfficiency = efficiency >= efficiencyThreshold
        let hasGoodQuality = qualityScore.map { $0 >= qualityThreshold } ?? true
        
        if hasGoodEfficiency && hasGoodQuality {
            return .optimal
        } else if hasGoodEfficiency || hasGoodQuality {
            return .acceptable
        } else {
            return .needsImprovement
        }
    }
}

// MARK: - Supporting Enums

enum PerformanceMetricType: String, CaseIterable, Codable {
    // Latency metrics
    case retrievalLatency = "Retrieval Latency"
    case storageLatency = "Storage Latency"
    case consolidationLatency = "Consolidation Latency"
    case queryLatency = "Query Latency"
    case indexingLatency = "Indexing Latency"
    
    // Throughput metrics
    case processingThroughput = "Processing Throughput"
    case consolidationThroughput = "Consolidation Throughput"
    case queryThroughput = "Query Throughput"
    
    // Accuracy metrics
    case transcriptionAccuracy = "Transcription Accuracy"
    case entityExtractionAccuracy = "Entity Extraction Accuracy"
    case relationshipAccuracy = "Relationship Accuracy"
    case consolidationAccuracy = "Consolidation Accuracy"
    
    // Efficiency metrics
    case memoryUtilization = "Memory Utilization"
    case storageEfficiency = "Storage Efficiency"
    case cpuUtilization = "CPU Utilization"
    case cacheHitRate = "Cache Hit Rate"
    
    // Quality metrics
    case entityLinkingQuality = "Entity Linking Quality"
    case knowledgeGraphDensity = "Knowledge Graph Density"
    case semanticCoherence = "Semantic Coherence"
    case userEngagement = "User Engagement"
    
    // System health metrics
    case memoryFragmentation = "Memory Fragmentation"
    case queryComplexity = "Query Complexity"
    case systemResponsiveness = "System Responsiveness"
    case errorRate = "Error Rate"
    
    var defaultUnit: String {
        switch self {
        case .retrievalLatency, .storageLatency, .consolidationLatency, .queryLatency, .indexingLatency:
            return "ms"
        case .processingThroughput, .consolidationThroughput, .queryThroughput:
            return "items/sec"
        case .transcriptionAccuracy, .entityExtractionAccuracy, .relationshipAccuracy, .consolidationAccuracy:
            return "%"
        case .memoryUtilization, .storageEfficiency, .cpuUtilization, .cacheHitRate:
            return "%"
        case .entityLinkingQuality, .knowledgeGraphDensity, .semanticCoherence, .userEngagement:
            return "score"
        case .memoryFragmentation, .queryComplexity, .systemResponsiveness, .errorRate:
            return "index"
        }
    }
    
    var category: MetricCategory {
        switch self {
        case .retrievalLatency, .storageLatency, .consolidationLatency, .queryLatency, .indexingLatency:
            return .performance
        case .processingThroughput, .consolidationThroughput, .queryThroughput:
            return .throughput
        case .transcriptionAccuracy, .entityExtractionAccuracy, .relationshipAccuracy, .consolidationAccuracy:
            return .accuracy
        case .memoryUtilization, .storageEfficiency, .cpuUtilization, .cacheHitRate:
            return .efficiency
        case .entityLinkingQuality, .knowledgeGraphDensity, .semanticCoherence, .userEngagement:
            return .quality
        case .memoryFragmentation, .queryComplexity, .systemResponsiveness, .errorRate:
            return .health
        }
    }
}

enum ProcessingPhase: String, CaseIterable, Codable {
    case transcription = "Transcription"
    case entityExtraction = "Entity Extraction"
    case relationshipBuilding = "Relationship Building"
    case memoryStorage = "Memory Storage"
    case consolidation = "Consolidation"
    case retrieval = "Retrieval"
    case querying = "Querying"
    case indexing = "Indexing"
    case optimization = "Optimization"
    case unknown = "Unknown"
    
    var iconName: String {
        switch self {
        case .transcription:
            return "waveform"
        case .entityExtraction:
            return "text.magnifyingglass"
        case .relationshipBuilding:
            return "link"
        case .memoryStorage:
            return "internaldrive"
        case .consolidation:
            return "arrow.triangle.merge"
        case .retrieval:
            return "arrow.up.doc"
        case .querying:
            return "magnifyingglass"
        case .indexing:
            return "list.bullet.indent"
        case .optimization:
            return "speedometer"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

enum OperationType: String, CaseIterable, Codable {
    case create = "Create"
    case read = "Read"
    case update = "Update"
    case delete = "Delete"
    case query = "Query"
    case batch = "Batch"
    case sync = "Sync"
    case backup = "Backup"
    case restore = "Restore"
    case optimize = "Optimize"
    
    var color: String {
        switch self {
        case .create:
            return "green"
        case .read, .query:
            return "blue"
        case .update:
            return "orange"
        case .delete:
            return "red"
        case .batch, .sync:
            return "purple"
        case .backup, .restore:
            return "gray"
        case .optimize:
            return "yellow"
        }
    }
}

enum MetricCategory: String, CaseIterable {
    case performance = "Performance"
    case throughput = "Throughput"
    case accuracy = "Accuracy"
    case efficiency = "Efficiency"
    case quality = "Quality"
    case health = "Health"
    
    var iconName: String {
        switch self {
        case .performance:
            return "speedometer"
        case .throughput:
            return "arrow.right.arrow.left"
        case .accuracy:
            return "target"
        case .efficiency:
            return "leaf"
        case .quality:
            return "star"
        case .health:
            return "heart"
        }
    }
}

enum PerformanceStatus: String, CaseIterable {
    case optimal = "Optimal"
    case acceptable = "Acceptable"
    case needsImprovement = "Needs Improvement"
    
    var color: String {
        switch self {
        case .optimal:
            return "green"
        case .acceptable:
            return "yellow"
        case .needsImprovement:
            return "red"
        }
    }
    
    var iconName: String {
        switch self {
        case .optimal:
            return "checkmark.circle.fill"
        case .acceptable:
            return "exclamationmark.triangle"
        case .needsImprovement:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Extensions

extension MemoryPerformanceMetric {
    /// Create a latency metric
    static func latency(type: PerformanceMetricType, milliseconds: Double, phase: ProcessingPhase = .unknown) -> MemoryPerformanceMetric {
        let metric = MemoryPerformanceMetric(metricType: type, value: milliseconds, unit: "ms")
        metric.processingPhase = phase
        metric.duration = milliseconds / 1000.0 // Convert to seconds
        return metric
    }
    
    /// Create a throughput metric
    static func throughput(type: PerformanceMetricType, itemsPerSecond: Double, batchSize: Int = 1) -> MemoryPerformanceMetric {
        let metric = MemoryPerformanceMetric(metricType: type, value: itemsPerSecond, unit: "items/sec")
        metric.batchSize = batchSize
        return metric
    }
    
    /// Create an accuracy metric
    static func accuracy(type: PerformanceMetricType, percentage: Double, confidence: Double? = nil) -> MemoryPerformanceMetric {
        let metric = MemoryPerformanceMetric(metricType: type, value: percentage, unit: "%")
        metric.accuracyScore = percentage / 100.0
        metric.confidenceScore = confidence
        return metric
    }
    
    /// Check if this metric indicates a performance issue
    var indicatesIssue: Bool {
        switch metricType.category {
        case .performance:
            return value > 1000.0 // Latency > 1 second
        case .throughput:
            return value < 1.0 // Less than 1 item per second
        case .accuracy:
            return value < 80.0 // Less than 80% accuracy
        case .efficiency:
            return value < 60.0 // Less than 60% efficiency
        case .quality:
            return qualityScore.map { $0 < 0.7 } ?? false
        case .health:
            return value > 0.8 // High fragmentation/complexity/error rate
        }
    }
    
    /// Generate improvement suggestions
    var improvementSuggestions: [String] {
        guard indicatesIssue else { return [] }
        
        var suggestions: [String] = []
        
        switch metricType.category {
        case .performance:
            suggestions.append("Consider optimizing query complexity or adding caching")
        case .throughput:
            suggestions.append("Review batch processing and parallel execution")
        case .accuracy:
            suggestions.append("Review training data and model parameters")
        case .efficiency:
            suggestions.append("Optimize resource usage and algorithm efficiency")
        case .quality:
            suggestions.append("Review quality assurance processes and user feedback")
        case .health:
            suggestions.append("Perform system maintenance and optimization")
        }
        
        return suggestions
    }
}