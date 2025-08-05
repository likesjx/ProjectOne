//
//  CognitiveDecisionEngine.swift
//  ProjectOne
//
//  AI decision tracking with SwiftData integration
//  Tracks and analyzes AI agent decision-making processes
//

import Foundation
import SwiftData
import Combine
import os.log

/// Engine for tracking and analyzing AI agent decision-making processes
@MainActor
public class CognitiveDecisionEngine: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "CognitiveDecisionEngine")
    private let modelContext: ModelContext
    
    // MARK: - Published State
    
    @Published public var recentDecisions: [CognitiveDecision] = []
    @Published public var decisionMetrics: DecisionMetrics = DecisionMetrics()
    @Published public var isTracking = true
    
    // MARK: - Decision Streaming
    
    private let decisionSubject = PassthroughSubject<CognitiveDecision, Never>()
    public var decisionStream: AnyPublisher<CognitiveDecision, Never> {
        decisionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Configuration
    
    public struct Configuration: Sendable {
        let maxRecentDecisions: Int
        let enableDetailedTracking: Bool
        let enablePerformanceMetrics: Bool
        let autoCleanupInterval: TimeInterval
        
        public static let `default` = Configuration(
            maxRecentDecisions: 100,
            enableDetailedTracking: true,
            enablePerformanceMetrics: true,
            autoCleanupInterval: 3600.0 // 1 hour
        )
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext, configuration: Configuration = .default) {
        self.modelContext = modelContext
        self.configuration = configuration
        
        logger.info("CognitiveDecisionEngine initialized")
        
        Task {
            await loadRecentDecisions()
            await updateMetrics()
        }
    }
    
    // MARK: - Decision Tracking
    
    /// Record a new cognitive decision
    public func recordDecision(
        agentId: String,
        decisionType: DecisionType,
        context: String,
        reasoning: String? = nil,
        confidence: Double = 1.0,
        metadata: [String: String] = [:]
    ) async {
        let decision = CognitiveDecision(
            agentId: agentId,
            decisionType: decisionType,
            context: context,
            reasoning: reasoning,
            confidence: confidence,
            metadata: metadata
        )
        
        // Save to SwiftData
        modelContext.insert(decision)
        
        do {
            try modelContext.save()
            
            // Update published state
            recentDecisions.insert(decision, at: 0)
            if recentDecisions.count > configuration.maxRecentDecisions {
                recentDecisions.removeLast()
            }
            
            // Stream the decision
            decisionSubject.send(decision)
            
            // Update metrics
            await updateMetrics()
            
            logger.debug("Recorded decision: \(decisionType.rawValue) for agent \(agentId)")
            
        } catch {
            logger.error("Failed to save decision: \(error.localizedDescription)")
        }
    }
    
    /// Record a memory-related decision
    public func recordMemoryDecision(
        operation: String,
        context: String,
        reasoning: String? = nil,
        confidence: Double = 1.0
    ) async {
        await recordDecision(
            agentId: "MemoryAgent",
            decisionType: .memoryOperation,
            context: context,
            reasoning: reasoning,
            confidence: confidence,
            metadata: ["operation": operation]
        )
    }
    
    /// Record a knowledge graph decision
    public func recordKnowledgeGraphDecision(
        operation: String,
        entityCount: Int,
        reasoning: String? = nil
    ) async {
        await recordDecision(
            agentId: "KnowledgeGraphAgent",
            decisionType: .knowledgeGraph,
            context: "Operation: \(operation)",
            reasoning: reasoning,
            metadata: [
                "operation": operation,
                "entityCount": String(entityCount)
            ]
        )
    }
    
    /// Record an AI provider selection decision
    public func recordProviderSelection(
        selectedProvider: String,
        availableProviders: [String],
        selectionReason: String,
        confidence: Double
    ) async {
        await recordDecision(
            agentId: "ProviderSelector",
            decisionType: .providerSelection,
            context: "Selected \(selectedProvider) from \(availableProviders.count) providers",
            reasoning: selectionReason,
            confidence: confidence,
            metadata: [
                "selectedProvider": selectedProvider,
                "availableProviders": availableProviders.joined(separator: ","),
                "providerCount": String(availableProviders.count)
            ]
        )
    }
    
    // MARK: - Decision Analysis
    
    /// Get decisions for a specific agent
    public func getDecisions(for agentId: String, limit: Int = 50) async -> [CognitiveDecision] {
        let descriptor = FetchDescriptor<CognitiveDecision>(
            predicate: #Predicate { $0.agentId == agentId },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let decisions = try modelContext.fetch(descriptor)
            return Array(decisions.prefix(limit))
        } catch {
            logger.error("Failed to fetch decisions for agent \(agentId): \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get decisions by type
    public func getDecisions(ofType type: DecisionType, limit: Int = 50) async -> [CognitiveDecision] {
        let descriptor = FetchDescriptor<CognitiveDecision>(
            predicate: #Predicate { $0.decisionType == type },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let decisions = try modelContext.fetch(descriptor)
            return Array(decisions.prefix(limit))
        } catch {
            logger.error("Failed to fetch decisions of type \(type.rawValue): \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get decision patterns and insights
    public func getDecisionInsights(timeRange: TimeInterval = 3600) async -> DecisionInsights {
        let cutoffDate = Date().addingTimeInterval(-timeRange)
        
        let descriptor = FetchDescriptor<CognitiveDecision>(
            predicate: #Predicate { $0.timestamp >= cutoffDate },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let decisions = try modelContext.fetch(descriptor)
            return analyzeDecisions(decisions)
        } catch {
            logger.error("Failed to fetch decisions for insights: \(error.localizedDescription)")
            return DecisionInsights()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadRecentDecisions() async {
        let descriptor = FetchDescriptor<CognitiveDecision>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let decisions = try modelContext.fetch(descriptor)
            recentDecisions = Array(decisions.prefix(configuration.maxRecentDecisions))
        } catch {
            logger.error("Failed to load recent decisions: \(error.localizedDescription)")
        }
    }
    
    private func updateMetrics() async {
        let totalDecisions = recentDecisions.count
        let averageConfidence = recentDecisions.isEmpty ? 0.0 : 
            recentDecisions.map(\.confidence).reduce(0, +) / Double(totalDecisions)
        
        let agentCounts = Dictionary(grouping: recentDecisions, by: \.agentId)
            .mapValues { $0.count }
        
        let typeCounts = Dictionary(grouping: recentDecisions, by: \.decisionType)
            .mapValues { $0.count }
        
        decisionMetrics = DecisionMetrics(
            totalDecisions: totalDecisions,
            averageConfidence: averageConfidence,
            agentDecisionCounts: agentCounts,
            typeDecisionCounts: typeCounts.mapKeys { $0.rawValue }
        )
    }
    
    private func analyzeDecisions(_ decisions: [CognitiveDecision]) -> DecisionInsights {
        let agentPerformance = Dictionary(grouping: decisions, by: \.agentId)
            .mapValues { agentDecisions in
                let avgConfidence = agentDecisions.map(\.confidence).reduce(0, +) / Double(agentDecisions.count)
                return AgentPerformance(
                    agentId: agentDecisions.first?.agentId ?? "",
                    decisionCount: agentDecisions.count,
                    averageConfidence: avgConfidence,
                    recentActivity: agentDecisions.prefix(10).map(\.decisionType.rawValue)
                )
            }
        
        return DecisionInsights(
            timeRange: 3600,
            totalDecisions: decisions.count,
            agentPerformance: Array(agentPerformance.values),
            commonPatterns: extractPatterns(from: decisions)
        )
    }
    
    private func extractPatterns(from decisions: [CognitiveDecision]) -> [String] {
        // Simple pattern extraction - can be enhanced
        let sequences = decisions.map(\.decisionType.rawValue)
        var patterns: [String] = []
        
        // Find common decision sequences
        for i in 0..<(sequences.count - 1) {
            let pattern = "\(sequences[i]) → \(sequences[i + 1])"
            patterns.append(pattern)
        }
        
        // Return most common patterns
        let patternCounts = Dictionary(grouping: patterns, by: { $0 })
            .mapValues { $0.count }
        
        return patternCounts.sorted { $0.value > $1.value }
            .prefix(5)
            .map(\.key)
    }
}

// MARK: - Supporting Types

/// Types of cognitive decisions that can be tracked
public enum DecisionType: String, CaseIterable, Codable {
    case memoryOperation = "memory_operation"
    case knowledgeGraph = "knowledge_graph"
    case providerSelection = "provider_selection"
    case textProcessing = "text_processing"
    case audioProcessing = "audio_processing"
    case userInteraction = "user_interaction"
    case systemOptimization = "system_optimization"
    case errorRecovery = "error_recovery"
}

/// SwiftData model for storing cognitive decisions
@Model
public class CognitiveDecision {
    public var id: UUID
    public var agentId: String
    public var decisionType: DecisionType
    public var context: String
    public var reasoning: String?
    public var confidence: Double
    public var metadata: [String: String]
    public var timestamp: Date
    
    public init(
        agentId: String,
        decisionType: DecisionType,
        context: String,
        reasoning: String? = nil,
        confidence: Double = 1.0,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.agentId = agentId
        self.decisionType = decisionType
        self.context = context
        self.reasoning = reasoning
        self.confidence = confidence
        self.metadata = metadata
        self.timestamp = Date()
    }
}

/// Current decision metrics
public struct DecisionMetrics {
    public let totalDecisions: Int
    public let averageConfidence: Double
    public let agentDecisionCounts: [String: Int]
    public let typeDecisionCounts: [String: Int]
    
    public init(
        totalDecisions: Int = 0,
        averageConfidence: Double = 0.0,
        agentDecisionCounts: [String: Int] = [:],
        typeDecisionCounts: [String: Int] = [:]
    ) {
        self.totalDecisions = totalDecisions
        self.averageConfidence = averageConfidence
        self.agentDecisionCounts = agentDecisionCounts
        self.typeDecisionCounts = typeDecisionCounts
    }
}

/// Insights from decision analysis
public struct DecisionInsights {
    public let timeRange: TimeInterval
    public let totalDecisions: Int
    public let agentPerformance: [AgentPerformance]
    public let commonPatterns: [String]
    
    public init(
        timeRange: TimeInterval = 0,
        totalDecisions: Int = 0,
        agentPerformance: [AgentPerformance] = [],
        commonPatterns: [String] = []
    ) {
        self.timeRange = timeRange
        self.totalDecisions = totalDecisions
        self.agentPerformance = agentPerformance
        self.commonPatterns = commonPatterns
    }
}

/// Performance metrics for an individual agent
public struct AgentPerformance {
    public let agentId: String
    public let decisionCount: Int
    public let averageConfidence: Double
    public let recentActivity: [String]
    
    public init(agentId: String, decisionCount: Int, averageConfidence: Double, recentActivity: [String]) {
        self.agentId = agentId
        self.decisionCount = decisionCount
        self.averageConfidence = averageConfidence
        self.recentActivity = recentActivity
    }
}

// MARK: - Extensions

extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> Dictionary<T, Value> {
        return Dictionary<T, Value>(uniqueKeysWithValues: self.map { (transform($0.key), $0.value) })
    }
}