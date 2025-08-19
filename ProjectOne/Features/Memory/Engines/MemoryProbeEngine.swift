//
//  MemoryProbeEngine.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Memory Probe Engine for ComoRAG control loop probing phase
//

import Foundation
import SwiftData
import os.log

// MARK: - Memory Probe Engine

/// Engine responsible for probing cognitive memory layers to identify relevant nodes
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class MemoryProbeEngine: @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryProbeEngine")
    private let cognitiveSystem: CognitiveMemorySystem
    
    // Configuration
    private let defaultProbeDepth: Int
    private let relevanceThreshold: Double
    private let maxNodesPerLayer: Int
    
    public init(
        cognitiveSystem: CognitiveMemorySystem,
        defaultProbeDepth: Int = 2,
        relevanceThreshold: Double = 0.2,
        maxNodesPerLayer: Int = 10
    ) {
        self.cognitiveSystem = cognitiveSystem
        self.defaultProbeDepth = defaultProbeDepth
        self.relevanceThreshold = relevanceThreshold
        self.maxNodesPerLayer = maxNodesPerLayer
    }
    
    // MARK: - Main Probing Methods
    
    /// Probe all cognitive layers with active reasoning trajectories
    public func probeAllLayers(
        activeTrajectories: [ReasoningTrajectory],
        probeDepth: Int? = nil
    ) async throws -> ProbeResult {
        let effectiveDepth = probeDepth ?? defaultProbeDepth
        logger.debug("Probing all layers with \(activeTrajectories.count) trajectories at depth \(effectiveDepth)")
        
        // Extract probe queries from trajectories
        let probeQueries = extractProbeQueries(from: activeTrajectories)
        
        // Probe each layer
        async let veridicalHits = probeVeridicalLayer(queries: probeQueries, depth: effectiveDepth)
        async let semanticHits = probeSemanticLayer(queries: probeQueries, depth: effectiveDepth)
        async let episodicHits = probeEpisodicLayer(queries: probeQueries, depth: effectiveDepth)
        async let fusionHits = probeFusionLayer(queries: probeQueries, depth: effectiveDepth)
        
        // Collect results
        let vHits = try await veridicalHits
        let sHits = try await semanticHits
        let eHits = try await episodicHits
        let fHits = try await fusionHits
        
        // Calculate relevance scores
        var relevanceScores: [String: Double] = [:]
        relevanceScores.merge(vHits.relevanceScores) { $1 } // Use second value in case of conflict
        relevanceScores.merge(sHits.relevanceScores) { $1 }
        relevanceScores.merge(eHits.relevanceScores) { $1 }
        relevanceScores.merge(fHits.relevanceScores) { $1 }
        
        let result = ProbeResult(
            veridicalHits: vHits.nodeIds,
            semanticHits: sHits.nodeIds,
            episodicHits: eHits.nodeIds,
            fusionHits: fHits.nodeIds,
            relevanceScores: relevanceScores,
            probeDepth: effectiveDepth
        )
        
        let totalHits = result.veridicalHits.count + result.semanticHits.count + 
                       result.episodicHits.count + result.fusionHits.count
        
        logger.debug("Probe completed: \(totalHits) total hits across all layers")
        
        return result
    }
    
    /// Probe with a specific trajectory (for REX-RAG policy correction)
    public func probeWithTrajectory(_ trajectory: ReasoningTrajectory) async throws -> ProbeResult {
        logger.debug("Probing with specific trajectory: \(trajectory.id)")
        
        let probeQueries = extractProbeQueries(from: [trajectory])
        
        // Enhanced probing for alternative trajectory
        let veridicalProbe = await probeVeridicalLayer(queries: probeQueries, depth: 3)
        let semanticProbe = await probeSemanticLayer(queries: probeQueries, depth: 3)
        let episodicProbe = await probeEpisodicLayer(queries: probeQueries, depth: 2)
        let fusionProbe = await probeFusionLayer(queries: probeQueries, depth: 2)
        
        var relevanceScores: [String: Double] = [:]
        relevanceScores.merge(veridicalProbe.relevanceScores) { $1 }
        relevanceScores.merge(semanticProbe.relevanceScores) { $1 }
        relevanceScores.merge(episodicProbe.relevanceScores) { $1 }
        relevanceScores.merge(fusionProbe.relevanceScores) { $1 }
        
        return ProbeResult(
            veridicalHits: veridicalProbe.nodeIds,
            semanticHits: semanticProbe.nodeIds,
            episodicHits: episodicProbe.nodeIds,
            fusionHits: fusionProbe.nodeIds,
            relevanceScores: relevanceScores,
            probeDepth: 3
        )
    }
    
    // MARK: - Layer-Specific Probing
    
    private func probeVeridicalLayer(queries: [ProbeQuery], depth: Int) async -> LayerProbeResult {
        logger.debug("Probing veridical layer with \(queries.count) queries")
        
        var nodeIds: [String] = []
        var relevanceScores: [String: Double] = [:]
        
        for query in queries.prefix(depth) {
            let nodes = cognitiveSystem.veridicalLayer.nodes
            
            for node in nodes.prefix(maxNodesPerLayer) {
                let relevance = await calculateVeridicalRelevance(node: node, query: query)
                
                if relevance > relevanceThreshold {
                    let nodeId = node.id.uuidString
                    nodeIds.append(nodeId)
                    relevanceScores[nodeId] = relevance
                }
            }
        }
        
        // Remove duplicates while preserving highest relevance scores
        let uniqueNodeIds = Array(Set(nodeIds))
        let filteredScores = relevanceScores.filter { uniqueNodeIds.contains($0.key) }
        
        logger.debug("Veridical probe found \(uniqueNodeIds.count) relevant nodes")
        
        return LayerProbeResult(nodeIds: uniqueNodeIds, relevanceScores: filteredScores)
    }
    
    private func probeSemanticLayer(queries: [ProbeQuery], depth: Int) async -> LayerProbeResult {
        logger.debug("Probing semantic layer with \(queries.count) queries")
        
        var nodeIds: [String] = []
        var relevanceScores: [String: Double] = [:]
        
        for query in queries.prefix(depth) {
            let nodes = cognitiveSystem.semanticLayer.nodes
            
            for node in nodes.prefix(maxNodesPerLayer) {
                let relevance = await calculateSemanticRelevance(node: node, query: query)
                
                if relevance > relevanceThreshold {
                    let nodeId = node.id.uuidString
                    nodeIds.append(nodeId)
                    relevanceScores[nodeId] = relevance
                }
            }
        }
        
        let uniqueNodeIds = Array(Set(nodeIds))
        let filteredScores = relevanceScores.filter { uniqueNodeIds.contains($0.key) }
        
        logger.debug("Semantic probe found \(uniqueNodeIds.count) relevant nodes")
        
        return LayerProbeResult(nodeIds: uniqueNodeIds, relevanceScores: filteredScores)
    }
    
    private func probeEpisodicLayer(queries: [ProbeQuery], depth: Int) async -> LayerProbeResult {
        logger.debug("Probing episodic layer with \(queries.count) queries")
        
        var nodeIds: [String] = []
        var relevanceScores: [String: Double] = [:]
        
        for query in queries.prefix(depth) {
            let nodes = cognitiveSystem.episodicLayer.nodes
            
            for node in nodes.prefix(maxNodesPerLayer) {
                let relevance = await calculateEpisodicRelevance(node: node, query: query)
                
                if relevance > relevanceThreshold {
                    let nodeId = node.id.uuidString
                    nodeIds.append(nodeId)
                    relevanceScores[nodeId] = relevance
                }
            }
        }
        
        let uniqueNodeIds = Array(Set(nodeIds))
        let filteredScores = relevanceScores.filter { uniqueNodeIds.contains($0.key) }
        
        logger.debug("Episodic probe found \(uniqueNodeIds.count) relevant nodes")
        
        return LayerProbeResult(nodeIds: uniqueNodeIds, relevanceScores: filteredScores)
    }
    
    private func probeFusionLayer(queries: [ProbeQuery], depth: Int) async -> LayerProbeResult {
        logger.debug("Probing fusion layer with \(queries.count) queries")
        
        var nodeIds: [String] = []
        var relevanceScores: [String: Double] = [:]
        
        for query in queries.prefix(depth) {
            let fusionNodes = cognitiveSystem.fusionNodes
            
            for node in fusionNodes.prefix(maxNodesPerLayer) {
                let relevance = await calculateFusionRelevance(node: node, query: query)
                
                if relevance > relevanceThreshold {
                    let nodeId = node.id.uuidString
                    nodeIds.append(nodeId)
                    relevanceScores[nodeId] = relevance
                }
            }
        }
        
        let uniqueNodeIds = Array(Set(nodeIds))
        let filteredScores = relevanceScores.filter { uniqueNodeIds.contains($0.key) }
        
        logger.debug("Fusion probe found \(uniqueNodeIds.count) relevant nodes")
        
        return LayerProbeResult(nodeIds: uniqueNodeIds, relevanceScores: filteredScores)
    }
    
    // MARK: - Relevance Calculation
    
    private func calculateVeridicalRelevance(node: VeridicalNode, query: ProbeQuery) async -> Double {
        var relevance = 0.0
        
        // Content similarity
        relevance += calculateTextSimilarity(node.content, query.text) * 0.4
        
        // Immediacy bonus
        relevance += node.immediacyScore * 0.2
        
        // Verification status bonus
        if node.verificationStatus == .verified {
            relevance += 0.2
        }
        
        // Query type alignment
        relevance += getFactTypeAlignment(node.factType, query.type) * 0.2
        
        return min(1.0, relevance)
    }
    
    private func calculateSemanticRelevance(node: SemanticNode, query: ProbeQuery) async -> Double {
        var relevance = 0.0
        
        // Content similarity
        relevance += calculateTextSimilarity(node.content, query.text) * 0.35
        
        // Concept type alignment
        relevance += getConceptTypeAlignment(node.conceptType, query.type) * 0.25
        
        // Confidence and abstraction
        relevance += node.confidence * 0.2
        relevance += (Double(node.abstractionLevel) / 10.0) * 0.1
        
        // Evidence support
        relevance += min(0.1, Double(node.evidenceNodes.count) * 0.02)
        
        return min(1.0, relevance)
    }
    
    private func calculateEpisodicRelevance(node: EpisodicNode, query: ProbeQuery) async -> Double {
        var relevance = 0.0
        
        // Content similarity
        relevance += calculateTextSimilarity(node.content, query.text) * 0.3
        
        // Contextual cue matching
        for cue in node.contextualCues {
            if query.text.lowercased().contains(cue.lowercased()) {
                relevance += 0.1
            }
        }
        
        // Participant matching
        for participant in node.participants {
            if query.text.lowercased().contains(participant.lowercased()) {
                relevance += 0.15
            }
        }
        
        // Vividness and emotional strength
        relevance += node.vividnessScore * 0.15
        relevance += abs(node.emotionalValence) * 0.1
        
        // Temporal relevance
        relevance += getTemporalRelevance(node.temporalContext, query.temporalContext) * 0.1
        
        return min(1.0, relevance)
    }
    
    private func calculateFusionRelevance(node: FusionNode, query: ProbeQuery) async -> Double {
        var relevance = 0.0
        
        // Content similarity
        relevance += calculateTextSimilarity(node.content, query.text) * 0.4
        
        // Coherence and novelty
        relevance += node.coherenceScore * 0.2
        relevance += node.noveltyScore * 0.1
        
        // Cross-layer bonus (fusion is valuable for integration)
        if node.fusedLayers.count > 1 {
            relevance += 0.2
        }
        
        // Validation status
        if node.validationStatus == .validated {
            relevance += 0.1
        }
        
        return min(1.0, relevance)
    }
    
    // MARK: - Helper Methods
    
    private func extractProbeQueries(from trajectories: [ReasoningTrajectory]) -> [ProbeQuery] {
        var queries: [ProbeQuery] = []
        
        for trajectory in trajectories {
            for step in trajectory.steps {
                let query = ProbeQuery(
                    text: step.content,
                    type: mapStepTypeToQueryType(step.stepType),
                    confidence: step.confidence,
                    temporalContext: nil
                )
                queries.append(query)
            }
        }
        
        return queries
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func getFactTypeAlignment(_ factType: VeridicalNode.FactType, _ queryType: ProbeQueryType) -> Double {
        switch (factType, queryType) {
        case (.observation, .factual): return 0.8
        case (.statement, .factual): return 0.7
        case (.measurement, .factual): return 0.9
        case (.event, .experiential): return 0.8
        default: return 0.3
        }
    }
    
    private func getConceptTypeAlignment(_ conceptType: SemanticNode.ConceptType, _ queryType: ProbeQueryType) -> Double {
        switch (conceptType, queryType) {
        case (.entity, .factual): return 0.7
        case (.relationship, .conceptual): return 0.8
        case (.process, .conceptual): return 0.9
        case (.rule, .conceptual): return 0.8
        default: return 0.4
        }
    }
    
    private func getTemporalRelevance(_ nodeContext: EpisodicNode.TemporalContext, _ queryContext: String?) -> Double {
        guard let queryContext = queryContext else { return 0.0 }
        
        let queryLower = queryContext.lowercased()
        var relevance = 0.0
        
        if queryLower.contains(nodeContext.timeOfDay) { relevance += 0.3 }
        if queryLower.contains(nodeContext.dayOfWeek) { relevance += 0.2 }
        if queryLower.contains(nodeContext.relativeTime) { relevance += 0.4 }
        if let season = nodeContext.season, queryLower.contains(season) { relevance += 0.1 }
        
        return min(1.0, relevance)
    }
    
    private func mapStepTypeToQueryType(_ stepType: ReasoningStepType) -> ProbeQueryType {
        switch stepType {
        case .initial, .retrieval: return .factual
        case .inference, .consolidation: return .conceptual
        case .exploration, .correction: return .experiential
        case .final: return .integrative
        }
    }
}

// MARK: - Supporting Types

public struct ProbeQuery {
    public let text: String
    public let type: ProbeQueryType
    public let confidence: Double
    public let temporalContext: String?
}

public enum ProbeQueryType {
    case factual
    case conceptual
    case experiential
    case integrative
}

private struct LayerProbeResult {
    let nodeIds: [String]
    let relevanceScores: [String: Double]
}