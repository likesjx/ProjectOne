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
    
    // MARK: - EmbeddingCapable Implementation (align to canonical protocol)
    
    public var hasEmbedding: Bool {
        return embedding != nil
    }
    
    public var embeddingModelVersion: String? {
        // Not tracked on BaseCognitiveNode yet
        return nil
    }
    
    public var embeddingGeneratedAt: Date? {
        return embeddingTimestamp
    }
    
    public var embeddingText: String {
        return content
    }
    
    public func setEmbedding(_ embeddingVector: [Float], modelVersion: String) {
        self.embedding = embeddingVector
        self.embeddingTimestamp = Date()
        // modelVersion can be stored when the model is extended to support it
    }
    
    public func getEmbedding() -> [Float]? {
        return embedding
    }
    
    public func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval) -> Bool {
        guard hasEmbedding else { return true }
        if let ts = embeddingTimestamp {
            return Date().timeIntervalSince(ts) > maxAge
        }
        return true
    }
}

// MARK: - Veridical Memory Layer Node

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class VeridicalNode: BaseCognitiveNode {
    public var factType: FactType
    public var verificationStatus: VerificationStatus
    public var sourceReference: String?
    public var immediacyScore: Double
    
    public enum FactType: String, CaseIterable, Codable {
        case observation, statement, measurement, event, condition
    }
    
    public enum VerificationStatus: String, CaseIterable, Codable {
        case unverified, verified, conflicted, deprecated
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
        self.immediacyScore = 1.0
        super.init(content: content, nodeType: .fact, layerType: .veridical, importance: importance)
    }
    
    public func updateImmediacy() {
        let daysSinceCreation = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
        immediacyScore = max(0.0, 1.0 - (daysSinceCreation / 30.0))
    }
    
    public func verify(status: VerificationStatus) {
        verificationStatus = status
        if status == .verified {
            strengthScore = min(1.0, strengthScore + 0.2)
        }
    }
}

// MARK: - Semantic Memory Layer Node

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class SemanticNode: BaseCognitiveNode {
    public var conceptType: ConceptType
    public var abstractionLevel: Int
    public var generalizationCount: Int
    public var evidenceNodes: [String]
    public var contradictionNodes: [String]
    public var confidence: Double
    
    public enum ConceptType: String, CaseIterable, Codable {
        case entity, relationship, category, attribute, process, rule, principle
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
        super.init(content: content, nodeType: .concept, layerType: .semantic, importance: importance)
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
        abstractionLevel = min(abstractionLevel + 1, 10)
        strengthScore = min(1.0, strengthScore + 0.1)
    }
    
    private func updateConfidence() {
        let evidenceWeight = Double(evidenceNodes.count) * 0.1
        let contradictionWeight = Double(contradictionNodes.count) * 0.15
        confidence = max(0.0, min(1.0, importance + evidenceWeight - contradictionWeight))
    }
}

// MARK: - Episodic Memory Layer Node

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model 
public final class EpisodicNode: BaseCognitiveNode {
    public var episodeType: EpisodeType
    public var contextualCues: [String]
    public var participants: [String]
    public var location: String?
    public var emotionalValence: Double
    public var vividnessScore: Double
    public var temporalContext: TemporalContext
    
    public enum EpisodeType: String, CaseIterable, Codable {
        case interaction, event, experience, conversation, observation, decision
    }
    
    public struct TemporalContext: Codable {
        public let timeOfDay: String
        public let dayOfWeek: String
        public let season: String?
        public let relativeTime: String
        
        public init(timestamp: Date) {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: timestamp)
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            
            switch hour {
            case 5..<9: timeOfDay = "early_morning"
            case 9..<12: timeOfDay = "morning"
            case 12..<17: timeOfDay = "afternoon"
            case 17..<21: timeOfDay = "evening"
            default: timeOfDay = "night"
            }
            dayOfWeek = weekdayFormatter.string(from: timestamp).lowercased()
            
            let month = calendar.component(.month, from: timestamp)
            switch month {
            case 12, 1, 2: season = "winter"
            case 3, 4, 5: season = "spring"
            case 6, 7, 8: season = "summer"
            case 9, 10, 11: season = "fall"
            default: season = nil
            }
            
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
        self.vividnessScore = importance
        self.temporalContext = TemporalContext(timestamp: Date())
        super.init(content: content, nodeType: .episode, layerType: .episodic, importance: importance)
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
            let decayFactor = max(0.5, 1.0 - (daysSince / 365.0))
            vividnessScore *= decayFactor
        } else {
            vividnessScore = min(1.0, vividnessScore + 0.02)
        }
    }
}

// MARK: - Fusion Memory Node

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class FusionNode: BaseCognitiveNode {
    public var fusedLayers: [CognitiveLayerType]
    public var sourceNodes: [String]
    public var fusionType: FusionType
    public var coherenceScore: Double
    public var noveltyScore: Double
    public var validationStatus: ValidationStatus
    
    public enum FusionType: String, CaseIterable, Codable {
        case crossLayer, withinLayer, temporal, causal, analogical, conceptual
    }
    
    public enum ValidationStatus: String, CaseIterable, Codable {
        case pending, validated, rejected, uncertain
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
        self.noveltyScore = 1.0
        self.validationStatus = .pending
        super.init(content: content, nodeType: .fusion, layerType: .fusion, importance: importance)
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
        let daysSince = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
        let timeDecay = max(0.1, 1.0 - (daysSince / 90.0))
        let accessDecay = max(0.3, 1.0 - (Double(accessCount) * 0.05))
        noveltyScore = noveltyScore * timeDecay * accessDecay
    }
}

// MARK: - Cognitive Memory System State Extensions
// NOTE: The following extensions referenced a different EmbeddingCapable shape.
// They are commented out to avoid protocol mismatch. Update to the canonical
// EmbeddingCapable (EmbeddingGenerationService.swift) before re-enabling.

/*
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension STMEntry: EmbeddingCapable {
    public var embeddingTimestamp: Date? { lastAccessed }
    public var needsEmbedding: Bool { getEmbedding() == nil }
    public func getEmbedding() -> [Float]? { nil }
    public func setEmbedding(_ embedding: [Float]) async {}
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool { true }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension LTMEntry: EmbeddingCapable {
    public var embeddingTimestamp: Date? { lastAccessed }
    public var needsEmbedding: Bool { getEmbedding() == nil }
    public func getEmbedding() -> [Float]? { nil }
    public func setEmbedding(_ embedding: [Float]) async {}
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool { true }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension EpisodicMemoryEntry: EmbeddingCapable {
    public var embeddingTimestamp: Date? { timestamp }
    public var needsEmbedding: Bool { getEmbedding() == nil }
    public func getEmbedding() -> [Float]? { nil }
    public func setEmbedding(_ embedding: [Float]) async {}
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool { true }
}
*/
