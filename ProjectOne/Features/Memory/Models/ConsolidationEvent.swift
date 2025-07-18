import Foundation
import SwiftData

/// Tracks memory consolidation events for analytics and optimization
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class ConsolidationEvent {
    var id: UUID
    var timestamp: Date
    
    // Consolidation flow details
    var sourceType: ConsolidationMemoryType
    var targetType: ConsolidationMemoryType
    var itemsProcessed: Int
    var successfulConsolidations: Int
    var failedConsolidations: Int
    
    // Performance metrics
    var processingTime: TimeInterval // Time taken for consolidation in seconds
    var triggerReason: ConsolidationTrigger
    var averageImportanceScore: Double // Average importance of consolidated items (0.0-1.0)
    var averageConfidenceScore: Double // Average confidence of consolidated items (0.0-1.0)
    
    // Context information
    var contextType: String? // Type of content being consolidated (e.g., "transcription", "entity", "relationship")
    var userInitiated: Bool // Whether user manually triggered consolidation
    var systemLoad: Double // System load at time of consolidation (0.0-1.0)
    
    init(sourceType: ConsolidationMemoryType, targetType: ConsolidationMemoryType, triggerReason: ConsolidationTrigger = .automatic) {
        self.id = UUID()
        self.timestamp = Date()
        self.sourceType = sourceType
        self.targetType = targetType
        self.itemsProcessed = 0
        self.successfulConsolidations = 0
        self.failedConsolidations = 0
        self.processingTime = 0.0
        self.triggerReason = triggerReason
        self.averageImportanceScore = 0.0
        self.averageConfidenceScore = 0.0
        self.contextType = nil
        self.userInitiated = false
        self.systemLoad = 0.0
    }
    
    // MARK: - Computed Properties
    
    /// Success rate of consolidation (0.0-1.0)
    var successRate: Double {
        guard itemsProcessed > 0 else { return 0.0 }
        return Double(successfulConsolidations) / Double(itemsProcessed)
    }
    
    /// Failure rate of consolidation (0.0-1.0)
    var failureRate: Double {
        guard itemsProcessed > 0 else { return 0.0 }
        return Double(failedConsolidations) / Double(itemsProcessed)
    }
    
    /// Items processed per second
    var throughput: Double {
        guard processingTime > 0 else { return 0.0 }
        return Double(itemsProcessed) / processingTime
    }
    
    /// Consolidation efficiency metric (higher is better)
    var efficiency: Double {
        let timeEfficiency = min(1.0, 10.0 / max(processingTime, 0.1)) // Prefer faster consolidation
        let successEfficiency = successRate
        let qualityEfficiency = (averageImportanceScore + averageConfidenceScore) / 2.0
        
        return (timeEfficiency + successEfficiency + qualityEfficiency) / 3.0
    }
    
    /// Human-readable description of the consolidation flow
    var flowDescription: String {
        return "\(sourceType.rawValue) → \(targetType.rawValue)"
    }
}

// MARK: - Supporting Enums

enum ConsolidationMemoryType: String, CaseIterable, Codable {
    case shortTerm = "STM"
    case longTerm = "LTM" 
    case working = "Working"
    case episodic = "Episodic"
    
    var displayName: String {
        switch self {
        case .shortTerm:
            return "Short-Term Memory"
        case .longTerm:
            return "Long-Term Memory"
        case .working:
            return "Working Memory"
        case .episodic:
            return "Episodic Memory"
        }
    }
    
    var iconName: String {
        switch self {
        case .shortTerm:
            return "brain.head.profile"
        case .longTerm:
            return "archivebox"
        case .working:
            return "cpu"
        case .episodic:
            return "timeline.selection"
        }
    }
    
    var primaryColor: String {
        switch self {
        case .shortTerm:
            return "blue"
        case .longTerm:
            return "green"
        case .working:
            return "orange"
        case .episodic:
            return "purple"
        }
    }
}

enum ConsolidationTrigger: String, CaseIterable, Codable {
    case automatic = "Automatic"
    case manual = "Manual"
    case capacityLimit = "Capacity Limit"
    case timeThreshold = "Time Threshold"
    case importanceThreshold = "Importance Threshold"
    case systemOptimization = "System Optimization"
    case userFeedback = "User Feedback"
    case periodicMaintenance = "Periodic Maintenance"
    
    var description: String {
        switch self {
        case .automatic:
            return "Automatically triggered by system"
        case .manual:
            return "Manually triggered by user"
        case .capacityLimit:
            return "Triggered when memory capacity reached"
        case .timeThreshold:
            return "Triggered after time threshold elapsed"
        case .importanceThreshold:
            return "Triggered when importance threshold met"
        case .systemOptimization:
            return "Triggered for system optimization"
        case .userFeedback:
            return "Triggered by user feedback/corrections"
        case .periodicMaintenance:
            return "Triggered by periodic maintenance"
        }
    }
    
    var priority: Int {
        switch self {
        case .manual, .userFeedback:
            return 3 // High priority
        case .importanceThreshold, .systemOptimization:
            return 2 // Medium priority
        case .automatic, .capacityLimit, .timeThreshold, .periodicMaintenance:
            return 1 // Normal priority
        }
    }
}

// MARK: - Extensions

extension ConsolidationEvent {
    /// Check if this consolidation was successful
    var wasSuccessful: Bool {
        return successRate >= 0.8 && failedConsolidations <= Int(Double(itemsProcessed) * 0.2)
    }
    
    /// Check if this consolidation was efficient
    var wasEfficient: Bool {
        return efficiency >= 0.7 && processingTime <= 5.0 // 5 seconds threshold
    }
    
    /// Generate performance summary
    var performanceSummary: String {
        let successPercent = String(format: "%.1f%%", successRate * 100)
        let throughputFormatted = String(format: "%.1f items/sec", throughput)
        let timeFormatted = String(format: "%.2fs", processingTime)
        
        return "Success: \(successPercent), Throughput: \(throughputFormatted), Time: \(timeFormatted)"
    }
    
    /// Create consolidation quality report
    var qualityReport: ConsolidationQualityReport {
        return ConsolidationQualityReport(
            event: self,
            qualityScore: (averageImportanceScore + averageConfidenceScore) / 2.0,
            recommendations: generateRecommendations()
        )
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        if successRate < 0.8 {
            recommendations.append("Consider reviewing consolidation criteria - low success rate")
        }
        
        if processingTime > 5.0 {
            recommendations.append("Optimize consolidation algorithm - high processing time")
        }
        
        if averageImportanceScore < 0.5 {
            recommendations.append("Review importance scoring - consolidating low-value items")
        }
        
        if systemLoad > 0.8 {
            recommendations.append("Consider delaying consolidation during high system load")
        }
        
        return recommendations
    }
}

// MARK: - Quality Report

struct ConsolidationQualityReport {
    let event: ConsolidationEvent
    let qualityScore: Double
    let recommendations: [String]
    
    var qualityLevel: QualityLevel {
        switch qualityScore {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .acceptable
        case 0.2..<0.4:
            return .poor
        default:
            return .unacceptable
        }
    }
}

enum QualityLevel: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case acceptable = "Acceptable"
    case poor = "Poor"
    case unacceptable = "Unacceptable"
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .acceptable:
            return "yellow"
        case .poor:
            return "orange"
        case .unacceptable:
            return "red"
        }
    }
}