import Foundation
import SwiftData

/// Primary analytics data model tracking memory system performance and metrics
@Model
final class MemoryAnalytics {
    var id: UUID
    var timestamp: Date
    
    // Memory counts by type
    var stmCount: Int
    var ltmCount: Int
    var workingMemoryCount: Int
    var episodicMemoryCount: Int
    
    // Knowledge graph metrics
    var totalEntities: Int
    var totalRelationships: Int
    var entityTypes: [String: Int] // Entity type counts as JSON
    
    // Performance metrics
    var consolidationRate: Double // STM→LTM conversion rate (0.0-1.0)
    var averageConfidence: Double // Average confidence of all memories (0.0-1.0)
    var memoryEfficiency: Double // Storage efficiency metric (0.0-1.0)
    var processingLatency: TimeInterval // Average processing time in seconds
    
    // System health indicators
    var memoryPressure: Double // System memory pressure (0.0-1.0)
    var fragmentationIndex: Double // Memory fragmentation metric (0.0-1.0)
    var queryComplexity: Double // Average query complexity (0.0-1.0)
    
    init(timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        
        // Initialize memory counts
        self.stmCount = 0
        self.ltmCount = 0
        self.workingMemoryCount = 0
        self.episodicMemoryCount = 0
        
        // Initialize knowledge graph metrics
        self.totalEntities = 0
        self.totalRelationships = 0
        self.entityTypes = [:]
        
        // Initialize performance metrics
        self.consolidationRate = 0.0
        self.averageConfidence = 0.0
        self.memoryEfficiency = 0.0
        self.processingLatency = 0.0
        
        // Initialize health indicators
        self.memoryPressure = 0.0
        self.fragmentationIndex = 0.0
        self.queryComplexity = 0.0
    }
    
    // MARK: - Computed Properties
    
    /// Total memory items across all types
    var totalMemoryItems: Int {
        stmCount + ltmCount + workingMemoryCount + episodicMemoryCount
    }
    
    /// Memory distribution as percentages
    var memoryDistribution: MemoryDistribution {
        let total = Double(totalMemoryItems)
        guard total > 0 else {
            return MemoryDistribution(stm: 0, ltm: 0, working: 0, episodic: 0)
        }
        
        return MemoryDistribution(
            stm: Double(stmCount) / total,
            ltm: Double(ltmCount) / total,
            working: Double(workingMemoryCount) / total,
            episodic: Double(episodicMemoryCount) / total
        )
    }
    
    /// Overall system health score (0.0-1.0)
    var healthScore: Double {
        let factors = [
            consolidationRate,
            averageConfidence,
            memoryEfficiency,
            1.0 - memoryPressure, // Lower pressure is better
            1.0 - fragmentationIndex, // Lower fragmentation is better
            1.0 - min(queryComplexity, 1.0) // Lower complexity is better
        ]
        
        return factors.reduce(0.0, +) / Double(factors.count)
    }
    
    /// Health status based on score
    var healthStatus: HealthStatus {
        switch healthScore {
        case 0.8...1.0:
            return .excellent
        case 0.6..<0.8:
            return .good
        case 0.4..<0.6:
            return .fair
        case 0.2..<0.4:
            return .poor
        default:
            return .critical
        }
    }
}

// MARK: - Supporting Types

struct MemoryDistribution {
    let stm: Double // Percentage (0.0-1.0)
    let ltm: Double
    let working: Double
    let episodic: Double
}

enum HealthStatus: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .excellent:
            return "green"
        case .good:
            return "blue"
        case .fair:
            return "yellow"
        case .poor:
            return "orange"
        case .critical:
            return "red"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .excellent:
            return "checkmark.circle.fill"
        case .good:
            return "checkmark.circle"
        case .fair:
            return "exclamationmark.triangle"
        case .poor:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Extensions

extension MemoryAnalytics {
    /// Calculate growth rate compared to previous snapshot
    func growthRate(comparedTo previous: MemoryAnalytics?) -> Double {
        guard let previous = previous,
              previous.totalMemoryItems > 0 else {
            return 0.0
        }
        
        let currentTotal = Double(totalMemoryItems)
        let previousTotal = Double(previous.totalMemoryItems)
        
        return (currentTotal - previousTotal) / previousTotal
    }
    
    /// Check if this snapshot shows significant changes
    func hasSignificantChanges(comparedTo previous: MemoryAnalytics?, threshold: Double = 0.1) -> Bool {
        guard let previous = previous else { return true }
        
        let changes = [
            abs(consolidationRate - previous.consolidationRate),
            abs(averageConfidence - previous.averageConfidence),
            abs(memoryEfficiency - previous.memoryEfficiency),
            abs(healthScore - previous.healthScore)
        ]
        
        return changes.contains { $0 > threshold }
    }
    
    /// Generate summary description of current state
    var summaryDescription: String {
        let total = totalMemoryItems
        let health = healthStatus.rawValue
        let consolidation = String(format: "%.1f%%", consolidationRate * 100)
        
        return "Total: \(total) memories, Health: \(health), Consolidation: \(consolidation)"
    }
}