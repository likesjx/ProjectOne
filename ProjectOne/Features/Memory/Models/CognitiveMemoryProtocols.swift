//
//  CognitiveMemoryProtocols.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Cognitive Memory Layer Protocols for ComoRAG Integration
//

import Foundation
import SwiftData

// MARK: - Core Cognitive Layer Protocol

/// Base protocol for all cognitive memory layers
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public protocol CognitiveMemoryLayer: AnyObject {
    associatedtype NodeType: CognitiveMemoryNode
    
    var layerType: CognitiveLayerType { get }
    var nodes: [NodeType] { get set }
    var maxCapacity: Int { get }
    var consolidationThreshold: Double { get }
    
    func addNode(_ node: NodeType) async throws
    func removeNode(_ node: NodeType) async throws
    func searchNodes(query: String, limit: Int) async throws -> [NodeType]
    func consolidate() async throws
    func getRelevanceScore(for query: String, node: NodeType) async -> Double
}

// MARK: - Cognitive Memory Node Protocol

/// Protocol for individual memory nodes within cognitive layers
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public protocol CognitiveMemoryNode: AnyObject {
    var id: UUID { get }
    var content: String { get set }
    var timestamp: Date { get set }
    var importance: Double { get set }
    var accessCount: Int { get set }
    var lastAccessed: Date { get set }
    var nodeType: CognitiveNodeType { get }
    var embedding: [Float]? { get set }
    var connections: [String] { get set } // Connection IDs to other nodes
    
    func recordAccess() async
    func updateImportance(_ newImportance: Double) async
    func addConnection(to nodeId: String) async
    func removeConnection(to nodeId: String) async
}

// MARK: - Embedding Capability Protocol

/// Protocol for memory objects that support embedding generation
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public protocol EmbeddingCapable: AnyObject {
    var embedding: [Float]? { get set }
    var embeddingTimestamp: Date? { get set }
    var needsEmbedding: Bool { get }
    
    func getEmbedding() -> [Float]?
    func setEmbedding(_ embedding: [Float]) async
    func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool
}

// MARK: - Memory Fusion Protocol

/// Protocol for objects that can participate in memory fusion operations
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public protocol MemoryFusible: AnyObject {
    associatedtype FusionResult: MemoryFusible
    
    func canFuseWith(_ other: Self) async -> Bool
    func fuseWith(_ other: Self) async throws -> FusionResult
    func getFusionScore(with other: Self) async -> Double
}

// MARK: - Cognitive Control Participant Protocol

/// Protocol for components that participate in the cognitive control loop
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public protocol CognitiveControlParticipant: AnyObject {
    func reason(query: String, context: CognitiveContext) async throws -> ReasoningResult
    func probe(layers: [any CognitiveMemoryLayer]) async throws -> ProbeResult
    func retrieve(probeResult: ProbeResult) async throws -> RetrievalResult
    func consolidate(reasoning: ReasoningResult, retrieval: RetrievalResult) async throws -> ConsolidationResult
    func resolve(consolidation: ConsolidationResult, query: String) async throws -> CognitiveResponse
}

// MARK: - Enumerations

/// Types of cognitive memory layers based on ComoRAG architecture
public enum CognitiveLayerType: String, CaseIterable, Codable {
    case veridical = "veridical"     // Immediate facts and observations
    case semantic = "semantic"       // Consolidated knowledge and concepts
    case episodic = "episodic"       // Experiential memories and contexts
    case fusion = "fusion"           // Cross-layer fusion results
}

/// Types of cognitive memory nodes
public enum CognitiveNodeType: String, CaseIterable, Codable {
    case fact = "fact"               // VER - Veridical facts
    case concept = "concept"         // SEM - Semantic concepts  
    case episode = "episode"         // EPI - Episodic experiences
    case fusion = "fusion"           // FUSION - Cross-layer connections
    case pattern = "pattern"         // Identified patterns
    case hypothesis = "hypothesis"   // Working hypotheses
}

// MARK: - Supporting Data Structures

/// Context for cognitive operations
public struct CognitiveContext: Sendable {
    public let sessionId: UUID
    public let timestamp: Date
    public let userQuery: String
    public let focusEntities: [String]
    public let memoryState: MemorySystemState
    public let reasoningDepth: Int
    public let explorationEnabled: Bool
    
    public init(
        sessionId: UUID = UUID(),
        timestamp: Date = Date(),
        userQuery: String,
        focusEntities: [String] = [],
        memoryState: MemorySystemState,
        reasoningDepth: Int = 3,
        explorationEnabled: Bool = true
    ) {
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.userQuery = userQuery
        self.focusEntities = focusEntities
        self.memoryState = memoryState
        self.reasoningDepth = reasoningDepth
        self.explorationEnabled = explorationEnabled
    }
}

/// State of the memory system for cognitive operations
public struct MemorySystemState: Sendable {
    public let shortTermCount: Int
    public let longTermCount: Int
    public let workingSetSize: Int
    public let episodicCount: Int
    public let systemLoadFactor: Double
    public let lastConsolidation: Date?
    
    public init(
        shortTermCount: Int,
        longTermCount: Int,
        workingSetSize: Int,
        episodicCount: Int,
        systemLoadFactor: Double = 0.0,
        lastConsolidation: Date? = nil
    ) {
        self.shortTermCount = shortTermCount
        self.longTermCount = longTermCount
        self.workingSetSize = workingSetSize
        self.episodicCount = episodicCount
        self.systemLoadFactor = systemLoadFactor
        self.lastConsolidation = lastConsolidation
    }
}

// MARK: - Cognitive Control Loop Results

/// Result from reasoning phase
public struct ReasoningResult: Sendable {
    public let reasoning: String
    public let confidence: Double
    public let trajectory: ReasoningTrajectory
    public let timestamp: Date
    
    public init(reasoning: String, confidence: Double, trajectory: ReasoningTrajectory, timestamp: Date = Date()) {
        self.reasoning = reasoning
        self.confidence = confidence
        self.trajectory = trajectory
        self.timestamp = timestamp
    }
}

/// Result from probe phase
public struct ProbeResult: Sendable {
    public let veridicalHits: [String]    // Node IDs
    public let semanticHits: [String]     // Node IDs
    public let episodicHits: [String]     // Node IDs
    public let fusionHits: [String]       // Node IDs
    public let relevanceScores: [String: Double] // Node ID -> relevance score
    public let probeDepth: Int
    
    public init(
        veridicalHits: [String] = [],
        semanticHits: [String] = [],
        episodicHits: [String] = [],
        fusionHits: [String] = [],
        relevanceScores: [String: Double] = [:],
        probeDepth: Int = 1
    ) {
        self.veridicalHits = veridicalHits
        self.semanticHits = semanticHits
        self.episodicHits = episodicHits
        self.fusionHits = fusionHits
        self.relevanceScores = relevanceScores
        self.probeDepth = probeDepth
    }
}

/// Result from retrieval phase
public struct RetrievalResult: Sendable {
    public let retrievedNodes: [any CognitiveMemoryNode]
    public let retrievalContext: String
    public let totalRelevanceScore: Double
    public let layerDistribution: [CognitiveLayerType: Int]
    
    public init(
        retrievedNodes: [any CognitiveMemoryNode],
        retrievalContext: String,
        totalRelevanceScore: Double,
        layerDistribution: [CognitiveLayerType: Int]
    ) {
        self.retrievedNodes = retrievedNodes
        self.retrievalContext = retrievalContext
        self.totalRelevanceScore = totalRelevanceScore
        self.layerDistribution = layerDistribution
    }
}

/// Result from consolidation phase
public struct ConsolidationResult: Sendable {
    public let consolidatedKnowledge: String
    public let fusedConnections: [String] // New connections created
    public let strengthenedConnections: [String] // Existing connections strengthened
    public let consolidationConfidence: Double
    public let newInsights: [String] // Generated insights
    
    public init(
        consolidatedKnowledge: String,
        fusedConnections: [String] = [],
        strengthenedConnections: [String] = [],
        consolidationConfidence: Double,
        newInsights: [String] = []
    ) {
        self.consolidatedKnowledge = consolidatedKnowledge
        self.fusedConnections = fusedConnections
        self.strengthenedConnections = strengthenedConnections
        self.consolidationConfidence = consolidationConfidence
        self.newInsights = newInsights
    }
}

/// Final cognitive response
public struct CognitiveResponse: Sendable {
    public let response: String
    public let reasoning: ReasoningResult
    public let memoryContext: RetrievalResult
    public let consolidation: ConsolidationResult
    public let confidence: Double
    public let cognitiveMetrics: CognitiveMetrics
    public let timestamp: Date
    
    public init(
        response: String,
        reasoning: ReasoningResult,
        memoryContext: RetrievalResult,
        consolidation: ConsolidationResult,
        confidence: Double,
        cognitiveMetrics: CognitiveMetrics,
        timestamp: Date = Date()
    ) {
        self.response = response
        self.reasoning = reasoning
        self.memoryContext = memoryContext
        self.consolidation = consolidation
        self.confidence = confidence
        self.cognitiveMetrics = cognitiveMetrics
        self.timestamp = timestamp
    }
}

/// Metrics for cognitive operations
public struct CognitiveMetrics: Sendable {
    public let processingTimeMs: Double
    public let memoryHits: Int
    public let layersEngaged: Int
    public let fusionOperations: Int
    public let confidenceScore: Double
    public let explorationPaths: Int
    
    public init(
        processingTimeMs: Double,
        memoryHits: Int,
        layersEngaged: Int,
        fusionOperations: Int,
        confidenceScore: Double,
        explorationPaths: Int = 0
    ) {
        self.processingTimeMs = processingTimeMs
        self.memoryHits = memoryHits
        self.layersEngaged = layersEngaged
        self.fusionOperations = fusionOperations
        self.confidenceScore = confidenceScore
        self.explorationPaths = explorationPaths
    }
}

// MARK: - Reasoning Trajectory for REX-RAG Integration

/// Represents a reasoning path for policy correction
public struct ReasoningTrajectory: Sendable {
    public let id: UUID
    public let steps: [ReasoningStep]
    public let likelihood: Double
    public let isExplored: Bool
    public let originalPolicy: Bool
    public let correctnessScore: Double
    public let timestamp: Date
    
    public init(
        id: UUID = UUID(),
        steps: [ReasoningStep],
        likelihood: Double,
        isExplored: Bool = false,
        originalPolicy: Bool = true,
        correctnessScore: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.steps = steps
        self.likelihood = likelihood
        self.isExplored = isExplored
        self.originalPolicy = originalPolicy
        self.correctnessScore = correctnessScore
        self.timestamp = timestamp
    }
}

/// Individual step in a reasoning trajectory
public struct ReasoningStep: Sendable {
    public let stepId: UUID
    public let content: String
    public let stepType: ReasoningStepType
    public let confidence: Double
    public let memoryReferences: [String] // Node IDs referenced
    
    public init(
        stepId: UUID = UUID(),
        content: String,
        stepType: ReasoningStepType,
        confidence: Double,
        memoryReferences: [String] = []
    ) {
        self.stepId = stepId
        self.content = content
        self.stepType = stepType
        self.confidence = confidence
        self.memoryReferences = memoryReferences
    }
}

/// Types of reasoning steps
public enum ReasoningStepType: String, CaseIterable, Codable {
    case initial = "initial"
    case retrieval = "retrieval"
    case inference = "inference"
    case consolidation = "consolidation"
    case exploration = "exploration"
    case correction = "correction"
    case final = "final"
}