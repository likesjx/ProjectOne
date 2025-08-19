//
//  CognitiveMemoryModels.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Extended SwiftData models for ComoRAG cognitive memory layers
//

import Foundation
import SwiftData

// MARK: - Base Cognitive Memory Node

/// Base SwiftData model for cognitive memory nodes
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public class BaseCognitiveNode: CognitiveMemoryNode, EmbeddingCapable {
    public var id: UUID
    public var content: String
    public var timestamp: Date
    public var importance: Double
    public var accessCount: Int
    public var lastAccessed: Date
    public var nodeType: CognitiveNodeType
    public var embedding: [Float]?
    public var embeddingTimestamp: Date?
    public var connections: [String] // Connection UUIDs as strings
    
    // Cognitive-specific properties
    public var layerType: CognitiveLayerType
    public var consolidationScore: Double
    public var fusionCount: Int
    public var strengthScore: Double // How well-established this node is
    
    public init(
        content: String,
        nodeType: CognitiveNodeType,
        layerType: CognitiveLayerType,
        importance: Double = 0.5
    ) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.importance = importance
        self.accessCount = 0
        self.lastAccessed = Date()
        self.nodeType = nodeType
        self.embedding = nil
        self.embeddingTimestamp = nil
        self.connections = []
        self.layerType = layerType
        self.consolidationScore = 0.0
        self.fusionCount = 0
        self.strengthScore = importance
    }
    
    // MARK: - CognitiveMemoryNode Implementation
    
    public func recordAccess() async {
        accessCount += 1
        lastAccessed = Date()
        
        // Cognitive strengthening through access
        importance = min(1.0, importance + 0.02)
        strengthScore = min(1.0, strengthScore + 0.01)
    }
    
    public func updateImportance(_ newImportance: Double) async {
        importance = max(0.0, min(1.0, newImportance))
        strengthScore = importance * 0.8 + strengthScore * 0.2 // Weighted update
    }
    
    public func addConnection(to nodeId: String) async {
        if !connections.contains(nodeId) {
            connections.append(nodeId)
            fusionCount += 1
        }
    }
    
    public func removeConnection(to nodeId: String) async {
        connections.removeAll { $0 == nodeId }
    }
    
    // MARK: - EmbeddingCapable Implementation
    
    public var needsEmbedding: Bool {
        return embedding == nil || shouldRegenerateEmbedding(maxAge: 7 * 24 * 3600) // 7 days
    }
    
    public func getEmbedding() -> [Float]? {
        return embedding
    }
    
    public func setEmbedding(_ embedding: [Float]) async {
        self.embedding = embedding
        self.embeddingTimestamp = Date()
    }
    
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool {
        guard let embeddingTimestamp = embeddingTimestamp else { return true }
        return Date().timeIntervalSince(embeddingTimestamp) > maxAge
    }
}

// MARK: - Veridical Memory Layer Node

/// Veridical layer node - immediate facts and observations (maps to STM)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class VeridicalNode: BaseCognitiveNode {
    // Veridical-specific properties
    public var factType: FactType
    public var verificationStatus: VerificationStatus
    public var sourceReference: String? // Reference to source memory item
    public var immediacyScore: Double // How immediate/recent this fact is
    
    public enum FactType: String, CaseIterable, Codable {
        case observation = "observation"
        case statement = "statement"
        case measurement = "measurement"
        case event = "event"
        case condition = "condition"
    }
    
    public enum VerificationStatus: String, CaseIterable, Codable {
        case unverified = "unverified"
        case verified = "verified"
        case conflicted = "conflicted"
        case deprecated = "deprecated"
    }
    
    public init(
        content: String,
        factType: FactType,
        sourceReference: String? = nil,
        importance: Double = 0.5
    ) {
        self.factType = factType
        self.verificationStatus = .unverified
        self.sourceReference = sourceReference
        self.immediacyScore = 1.0 // Start with maximum immediacy
        
        super.init(
            content: content,
            nodeType: .fact,
            layerType: .veridical,
            importance: importance
        )
    }
    
    public func updateImmediacy() {
        let daysSinceCreation = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
        immediacyScore = max(0.0, 1.0 - (daysSinceCreation / 30.0)) // Decay over 30 days
    }
    
    public func verify(status: VerificationStatus) {
        verificationStatus = status
        if status == .verified {
            strengthScore = min(1.0, strengthScore + 0.2)
        }
    }
}

// MARK: - Semantic Memory Layer Node

/// Semantic layer node - consolidated knowledge and concepts (maps to LTM)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class SemanticNode: BaseCognitiveNode {
    // Semantic-specific properties
    public var conceptType: ConceptType
    public var abstractionLevel: Int // 0 = concrete, higher = more abstract
    public var generalizationCount: Int // How many times this has been generalized
    public var evidenceNodes: [String] // UUIDs of supporting evidence nodes
    public var contradictionNodes: [String] // UUIDs of contradicting evidence
    public var confidence: Double // How confident we are in this concept
    
    public enum ConceptType: String, CaseIterable, Codable {
        case entity = "entity"
        case relationship = "relationship"
        case category = "category"
        case attribute = "attribute"
        case process = "process"
        case rule = "rule"
        case principle = "principle"
    }
    
    public init(
        content: String,
        conceptType: ConceptType,
        abstractionLevel: Int = 0,
        importance: Double = 0.7
    ) {
        self.conceptType = conceptType
        self.abstractionLevel = abstractionLevel
        self.generalizationCount = 0
        self.evidenceNodes = []
        self.contradictionNodes = []
        self.confidence = importance
        
        super.init(
            content: content,
            nodeType: .concept,
            layerType: .semantic,
            importance: importance
        )
    }
    
    public func addEvidence(_ nodeId: String) {
        if !evidenceNodes.contains(nodeId) {
            evidenceNodes.append(nodeId)
            updateConfidence()
        }
    }
    
    public func addContradiction(_ nodeId: String) {
        if !contradictionNodes.contains(nodeId) {
            contradictionNodes.append(nodeId)
            updateConfidence()
        }
    }
    
    public func generalize() {
        generalizationCount += 1
        abstractionLevel = min(abstractionLevel + 1, 10) // Max abstraction level
        strengthScore = min(1.0, strengthScore + 0.1)
    }
    
    private func updateConfidence() {
        let evidenceWeight = Double(evidenceNodes.count) * 0.1
        let contradictionWeight = Double(contradictionNodes.count) * 0.15
        confidence = max(0.0, min(1.0, importance + evidenceWeight - contradictionWeight))
    }
}

// MARK: - Episodic Memory Layer Node

/// Episodic layer node - experiential memories and contexts (maps to Episodic Memory)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model 
public final class EpisodicNode: BaseCognitiveNode {
    // Episodic-specific properties
    public var episodeType: EpisodeType
    public var contextualCues: [String] // Environmental/situational cues
    public var participants: [String] // Entity IDs involved
    public var location: String?
    public var emotionalValence: Double // -1.0 (negative) to 1.0 (positive)
    public var vividnessScore: Double // How vivid/detailed this memory is
    public var temporalContext: TemporalContext
    
    public enum EpisodeType: String, CaseIterable, Codable {
        case interaction = "interaction"
        case event = "event"
        case experience = "experience"
        case conversation = "conversation"
        case observation = "observation"
        case decision = "decision"
    }
    
    public struct TemporalContext: Codable {
        public let timeOfDay: String
        public let dayOfWeek: String
        public let season: String?
        public let relativeTime: String // "recently", "long ago", etc.
        
        public init(timestamp: Date) {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: timestamp)
            let weekday = calendar.component(.weekday, from: timestamp)
            
            // Time of day
            switch hour {
            case 5..<9: timeOfDay = "early_morning"
            case 9..<12: timeOfDay = "morning"
            case 12..<17: timeOfDay = "afternoon"
            case 17..<21: timeOfDay = "evening"
            default: timeOfDay = "night"
            }
            
            // Day of week
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            dayOfWeek = weekdayFormatter.string(from: timestamp).lowercased()
            
            // Season (simplified)
            let month = calendar.component(.month, from: timestamp)
            switch month {
            case 12, 1, 2: season = "winter"
            case 3, 4, 5: season = "spring"
            case 6, 7, 8: season = "summer"
            case 9, 10, 11: season = "fall"
            default: season = nil
            }
            
            // Relative time
            let daysSince = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
            switch daysSince {
            case 0..<1: relativeTime = "today"
            case 1..<2: relativeTime = "yesterday"
            case 2..<7: relativeTime = "this_week"
            case 7..<30: relativeTime = "recently"
            case 30..<90: relativeTime = "some_time_ago"
            default: relativeTime = "long_ago"
            }
        }
    }
    
    public init(
        content: String,
        episodeType: EpisodeType,
        participants: [String] = [],
        location: String? = nil,
        emotionalValence: Double = 0.0,
        importance: Double = 0.6
    ) {
        self.episodeType = episodeType
        self.contextualCues = []
        self.participants = participants
        self.location = location
        self.emotionalValence = emotionalValence
        self.vividnessScore = importance // Start with importance as vividness
        self.temporalContext = TemporalContext(timestamp: Date())
        
        super.init(
            content: content,
            nodeType: .episode,
            layerType: .episodic,
            importance: importance
        )
    }
    
    public func addContextualCue(_ cue: String) {
        if !contextualCues.contains(cue) {
            contextualCues.append(cue)
            vividnessScore = min(1.0, vividnessScore + 0.05)
        }
    }
    
    public func addParticipant(_ participantId: String) {
        if !participants.contains(participantId) {
            participants.append(participantId)
        }
    }
    
    public func updateVividness(decay: Bool = false) {
        if decay {
            let daysSince = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
            let decayFactor = max(0.5, 1.0 - (daysSince / 365.0)) // Decay over a year, min 0.5
            vividnessScore *= decayFactor
        } else {
            // Reinforce through access
            vividnessScore = min(1.0, vividnessScore + 0.02)
        }
    }
}

// MARK: - Fusion Memory Node

/// Fusion node - represents cross-layer connections and integrated insights
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class FusionNode: BaseCognitiveNode {
    // Fusion-specific properties
    public var fusedLayers: [CognitiveLayerType] // Which layers were fused
    public var sourceNodes: [String] // UUIDs of nodes that contributed to this fusion
    public var fusionType: FusionType
    public var coherenceScore: Double // How well the fusion holds together
    public var noveltyScore: Double // How novel this fusion is
    public var validationStatus: ValidationStatus
    
    public enum FusionType: String, CaseIterable, Codable {
        case crossLayer = "cross_layer" // Fusion across different layers
        case withinLayer = "within_layer" // Fusion within same layer
        case temporal = "temporal" // Temporal connection/pattern
        case causal = "causal" // Causal relationship
        case analogical = "analogical" // Analogy-based connection
        case conceptual = "conceptual" // Conceptual integration
    }
    
    public enum ValidationStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case validated = "validated"
        case rejected = "rejected"
        case uncertain = "uncertain"
    }
    
    public init(
        content: String,
        fusedLayers: [CognitiveLayerType],
        sourceNodes: [String],
        fusionType: FusionType,
        importance: Double = 0.8
    ) {
        self.fusedLayers = fusedLayers
        self.sourceNodes = sourceNodes
        self.fusionType = fusionType
        self.coherenceScore = importance
        self.noveltyScore = 1.0 // Start with high novelty
        self.validationStatus = .pending
        
        super.init(
            content: content,
            nodeType: .fusion,
            layerType: .fusion,
            importance: importance
        )
    }
    
    public func validate(status: ValidationStatus) {
        validationStatus = status
        switch status {
        case .validated:
            coherenceScore = min(1.0, coherenceScore + 0.2)
            strengthScore = min(1.0, strengthScore + 0.3)
        case .rejected:
            coherenceScore = max(0.0, coherenceScore - 0.3)
            strengthScore = max(0.0, strengthScore - 0.2)
        case .uncertain:
            coherenceScore *= 0.9
        case .pending:
            break
        }
    }
    
    public func updateNovelty() {
        // Novelty decreases over time and with access
        let daysSince = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
        let timeDecay = max(0.1, 1.0 - (daysSince / 90.0)) // Decay over 90 days
        let accessDecay = max(0.3, 1.0 - (Double(accessCount) * 0.05)) // Decay with access
        noveltyScore = noveltyScore * timeDecay * accessDecay
    }
}

// MARK: - Cognitive Memory System State Extensions

/// Extension to existing memory models to support cognitive integration
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension STMEntry: EmbeddingCapable {
    public var embeddingTimestamp: Date? {
        get {
            // Use existing metadata or last accessed time
            return lastAccessed
        }
        set {
            // Could extend model to include embedding timestamp if needed
        }
    }
    
    public var needsEmbedding: Bool {
        return getEmbedding() == nil
    }
    
    public func getEmbedding() -> [Float]? {
        // STM entries would need embedding support added
        return nil // Placeholder - would need to add embedding property to STMEntry
    }
    
    public func setEmbedding(_ embedding: [Float]) async {
        // Would need to add embedding property to STMEntry model
    }
    
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool {
        return true // STM should always regenerate for freshness
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension LTMEntry: EmbeddingCapable {
    public var embeddingTimestamp: Date? {
        get {
            return lastAccessed
        }
        set {
            // Could extend model if needed
        }
    }
    
    public var needsEmbedding: Bool {
        return getEmbedding() == nil
    }
    
    public func getEmbedding() -> [Float]? {
        return nil // Placeholder - would need to add embedding property
    }
    
    public func setEmbedding(_ embedding: [Float]) async {
        // Would need to add embedding property to LTMEntry model
    }
    
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool {
        guard let lastAccessed = embeddingTimestamp else { return true }
        return Date().timeIntervalSince(lastAccessed) > maxAge
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension EpisodicMemoryEntry: EmbeddingCapable {
    public var embeddingTimestamp: Date? {
        get {
            return timestamp
        }
        set {
            // Could extend model if needed
        }
    }
    
    public var needsEmbedding: Bool {
        return getEmbedding() == nil
    }
    
    public func getEmbedding() -> [Float]? {
        return nil // Placeholder - would need to add embedding property
    }
    
    public func setEmbedding(_ embedding: [Float]) async {
        // Would need to add embedding property to EpisodicMemoryEntry model
    }
    
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool {
        return Date().timeIntervalSince(timestamp) > maxAge
    }
}