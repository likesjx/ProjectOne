//
//  MemoryFusionEngine.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Memory Fusion Engine for ComoRAG control loop fusion operations
//

import Foundation
import SwiftData
import os.log

// MARK: - Memory Fusion Engine

/// Engine responsible for identifying and creating memory fusion connections
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class MemoryFusionEngine: @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryFusionEngine")
    private let cognitiveSystem: CognitiveMemorySystem
    
    // Configuration
    private let fusionThreshold: Double
    private let maxFusionsPerOperation: Int
    private let noveltyWeight: Double
    private let coherenceWeight: Double
    
    public init(
        cognitiveSystem: CognitiveMemorySystem,
        fusionThreshold: Double = 0.6,
        maxFusionsPerOperation: Int = 10,
        noveltyWeight: Double = 0.3,
        coherenceWeight: Double = 0.4
    ) {
        self.cognitiveSystem = cognitiveSystem
        self.fusionThreshold = fusionThreshold
        self.maxFusionsPerOperation = maxFusionsPerOperation
        self.noveltyWeight = noveltyWeight
        self.coherenceWeight = coherenceWeight
    }
    
    // MARK: - Main Fusion Operations
    
    /// Identify and create fusion connections from retrieved nodes
    public func identifyAndCreateFusions(
        retrievedNodes: [any CognitiveMemoryNode],
        reasoningTrajectory: ReasoningTrajectory
    ) async throws -> FusionEngineResult {
        logger.debug("Identifying fusion opportunities among \(retrievedNodes.count) retrieved nodes")
        
        let startTime = Date()
        var newConnections: [String] = []
        var qualityScores: [Double] = []
        
        // Step 1: Identify potential fusion pairs
        let fusionCandidates = await identifyFusionCandidates(
            nodes: retrievedNodes,
            reasoningTrajectory: reasoningTrajectory
        )
        
        logger.debug("Found \(fusionCandidates.count) fusion candidates")
        
        // Step 2: Evaluate and create fusion nodes
        let evaluatedCandidates = await evaluateFusionCandidates(fusionCandidates)
        let selectedCandidates = evaluatedCandidates
            .filter { $0.fusionScore > fusionThreshold }
            .sorted { $0.fusionScore > $1.fusionScore }
            .prefix(maxFusionsPerOperation)
        
        // Step 3: Create fusion nodes
        for candidate in selectedCandidates {
            do {
                let fusionNode = try await createFusionNode(from: candidate)
                newConnections.append(fusionNode.id.uuidString)
                qualityScores.append(candidate.fusionScore)
                
                logger.debug("Created fusion node: \(fusionNode.id) with score: \(candidate.fusionScore)")
                
            } catch {
                logger.error("Failed to create fusion node: \(error.localizedDescription)")
            }
        }
        
        // Step 4: Calculate overall quality
        let averageQuality = qualityScores.isEmpty ? 0.0 : qualityScores.reduce(0.0, +) / Double(qualityScores.count)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let result = FusionEngineResult(
            newConnections: newConnections,
            qualityScore: averageQuality,
            fusionCount: newConnections.count
        )
        
        logger.info("Fusion operation completed in \(processingTime)s: \(newConnections.count) fusions created with avg quality: \(averageQuality)")
        
        return result
    }
    
    // MARK: - Fusion Candidate Identification
    
    private func identifyFusionCandidates(
        nodes: [any CognitiveMemoryNode],
        reasoningTrajectory: ReasoningTrajectory
    ) async -> [FusionCandidate] {
        var candidates: [FusionCandidate] = []
        
        // Cross-layer fusion candidates
        let crossLayerCandidates = await identifyCrossLayerFusions(nodes: nodes)
        candidates.append(contentsOf: crossLayerCandidates)
        
        // Temporal fusion candidates (based on reasoning trajectory)
        let temporalCandidates = await identifyTemporalFusions(nodes: nodes, trajectory: reasoningTrajectory)
        candidates.append(contentsOf: temporalCandidates)
        
        // Causal fusion candidates
        let causalCandidates = await identifyCausalFusions(nodes: nodes)
        candidates.append(contentsOf: causalCandidates)
        
        // Analogical fusion candidates
        let analogicalCandidates = await identifyAnalogicalFusions(nodes: nodes)
        candidates.append(contentsOf: analogicalCandidates)
        
        // Conceptual fusion candidates
        let conceptualCandidates = await identifyConceptualFusions(nodes: nodes)
        candidates.append(contentsOf: conceptualCandidates)
        
        return candidates
    }
    
    private func identifyCrossLayerFusions(nodes: [any CognitiveMemoryNode]) async -> [FusionCandidate] {
        var candidates: [FusionCandidate] = []
        
        let nodesByLayer = Dictionary(grouping: nodes) { node in
            getNodeLayerType(node)
        }
        
        // Find pairs across different layers
        let layerTypes = Array(nodesByLayer.keys)
        
        for i in 0..<layerTypes.count {
            for j in (i+1)..<layerTypes.count {
                let layer1 = layerTypes[i]
                let layer2 = layerTypes[j]
                
                let nodes1 = nodesByLayer[layer1] ?? []
                let nodes2 = nodesByLayer[layer2] ?? []
                
                for node1 in nodes1.prefix(5) { // Limit combinations for performance
                    for node2 in nodes2.prefix(5) {
                        let similarity = await calculateNodeSimilarity(node1, node2)
                        if similarity > 0.4 {
                            let candidate = FusionCandidate(
                                sourceNodes: [node1, node2],
                                fusionType: .crossLayer,
                                fusionScore: 0.0, // Will be calculated later
                                contentSimilarity: similarity,
                                importance: (node1.importance + node2.importance) / 2.0,
                                novelty: 1.0 // Cross-layer is inherently novel
                            )
                            candidates.append(candidate)
                        }
                    }
                }
            }
        }
        
        return candidates
    }
    
    private func identifyTemporalFusions(nodes: [any CognitiveMemoryNode], trajectory: ReasoningTrajectory) async -> [FusionCandidate] {
        var candidates: [FusionCandidate] = []
        
        // Group nodes by temporal proximity
        let episodicNodes = nodes.compactMap { $0 as? EpisodicNode }
        
        for i in 0..<episodicNodes.count {
            for j in (i+1)..<episodicNodes.count {
                let node1 = episodicNodes[i]
                let node2 = episodicNodes[j]
                
                let temporalSimilarity = calculateTemporalSimilarity(node1.temporalContext, node2.temporalContext)
                
                if temporalSimilarity > 0.5 {
                    let candidate = FusionCandidate(
                        sourceNodes: [node1, node2],
                        fusionType: .temporal,
                        fusionScore: 0.0,
                        contentSimilarity: await calculateNodeSimilarity(node1, node2),
                        importance: (node1.importance + node2.importance) / 2.0,
                        novelty: 0.7
                    )
                    candidates.append(candidate)
                }
            }
        }
        
        return candidates
    }
    
    private func identifyCausalFusions(nodes: [any CognitiveMemoryNode]) async -> [FusionCandidate] {
        var candidates: [FusionCandidate] = []
        
        // Look for cause-effect patterns in content
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let node1 = nodes[i]
                let node2 = nodes[j]
                
                let causalScore = calculateCausalRelationship(node1.content, node2.content)
                
                if causalScore > 0.6 {
                    let candidate = FusionCandidate(
                        sourceNodes: [node1, node2],
                        fusionType: .causal,
                        fusionScore: 0.0,
                        contentSimilarity: causalScore,
                        importance: max(node1.importance, node2.importance),
                        novelty: 0.8
                    )
                    candidates.append(candidate)
                }
            }
        }
        
        return candidates
    }
    
    private func identifyAnalogicalFusions(nodes: [any CognitiveMemoryNode]) async -> [FusionCandidate] {
        var candidates: [FusionCandidate] = []
        
        // Find analogical relationships between semantic concepts
        let semanticNodes = nodes.compactMap { $0 as? SemanticNode }
        
        for i in 0..<semanticNodes.count {
            for j in (i+1)..<semanticNodes.count {
                let node1 = semanticNodes[i]
                let node2 = semanticNodes[j]
                
                let analogyScore = calculateAnalogyScore(node1, node2)
                
                if analogyScore > 0.5 {
                    let candidate = FusionCandidate(
                        sourceNodes: [node1, node2],
                        fusionType: .analogical,
                        fusionScore: 0.0,
                        contentSimilarity: analogyScore,
                        importance: (node1.importance + node2.importance) / 2.0,
                        novelty: 0.9 // Analogies are highly novel
                    )
                    candidates.append(candidate)
                }
            }
        }
        
        return candidates
    }
    
    private func identifyConceptualFusions(nodes: [any CognitiveMemoryNode]) async -> [FusionCandidate] {
        var candidates: [FusionCandidate] = []
        
        // Find conceptual integration opportunities
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let node1 = nodes[i]
                let node2 = nodes[j]
                
                let conceptualScore = await calculateConceptualIntegration(node1, node2)
                
                if conceptualScore > 0.5 {
                    let candidate = FusionCandidate(
                        sourceNodes: [node1, node2],
                        fusionType: .conceptual,
                        fusionScore: 0.0,
                        contentSimilarity: conceptualScore,
                        importance: (node1.importance + node2.importance) / 2.0,
                        novelty: 0.6
                    )
                    candidates.append(candidate)
                }
            }
        }
        
        return candidates
    }
    
    // MARK: - Fusion Evaluation
    
    private func evaluateFusionCandidates(_ candidates: [FusionCandidate]) async -> [FusionCandidate] {
        var evaluatedCandidates: [FusionCandidate] = []
        
        for candidate in candidates {
            let coherenceScore = await calculateCoherenceScore(candidate)
            let noveltyScore = await calculateNoveltyScore(candidate)
            let importanceScore = candidate.importance
            
            // Calculate composite fusion score
            let fusionScore = coherenceScore * coherenceWeight +
                             noveltyScore * noveltyWeight +
                             importanceScore * 0.3
            
            var evaluatedCandidate = candidate
            evaluatedCandidate.fusionScore = fusionScore
            
            evaluatedCandidates.append(evaluatedCandidate)
        }
        
        return evaluatedCandidates
    }
    
    private func calculateCoherenceScore(_ candidate: FusionCandidate) async -> Double {
        // Check how well the nodes fit together conceptually
        let contentSimilarity = candidate.contentSimilarity
        let layerCompatibility = calculateLayerCompatibility(candidate.sourceNodes)
        let connectionStrength = await calculateConnectionStrength(candidate.sourceNodes)
        
        return (contentSimilarity + layerCompatibility + connectionStrength) / 3.0
    }
    
    private func calculateNoveltyScore(_ candidate: FusionCandidate) async -> Double {
        // Check if this fusion represents new knowledge
        let baseNovelty = candidate.novelty
        
        // Penalty for existing similar fusions
        let existingSimilarFusions = await countSimilarFusions(candidate)
        let noveltyPenalty = min(0.3, Double(existingSimilarFusions) * 0.1)
        
        return max(0.0, baseNovelty - noveltyPenalty)
    }
    
    // MARK: - Fusion Node Creation
    
    private func createFusionNode(from candidate: FusionCandidate) async throws -> FusionNode {
        let fusedLayers = candidate.sourceNodes.map { getNodeLayerType($0) }
        let sourceNodeIds = candidate.sourceNodes.map { $0.id.uuidString }
        
        let fusionContent = await generateFusionContent(from: candidate)
        
        let fusionNode = FusionNode(
            content: fusionContent,
            fusedLayers: fusedLayers,
            sourceNodes: sourceNodeIds,
            fusionType: candidate.fusionType,
            importance: candidate.importance
        )
        
        // Set fusion-specific properties
        fusionNode.coherenceScore = await calculateCoherenceScore(candidate)
        fusionNode.noveltyScore = await calculateNoveltyScore(candidate)
        fusionNode.validationStatus = .pending
        
        // Add to cognitive system
        cognitiveSystem.fusionNodes.append(fusionNode)
        
        // Update connections in source nodes
        for sourceNode in candidate.sourceNodes {
            await sourceNode.addConnection(to: fusionNode.id.uuidString)
        }
        
        return fusionNode
    }
    
    private func generateFusionContent(from candidate: FusionCandidate) async -> String {
        let sourceContents = candidate.sourceNodes.map { $0.content }
        let fusionTypeDescription = getFusionTypeDescription(candidate.fusionType)
        
        return "\(fusionTypeDescription): \(sourceContents.joined(separator: " ↔ "))"
    }
    
    // MARK: - Helper Methods
    
    private func getNodeLayerType(_ node: any CognitiveMemoryNode) -> CognitiveLayerType {
        switch node.nodeType {
        case .fact: return .veridical
        case .concept: return .semantic
        case .episode: return .episodic
        case .fusion: return .fusion
        default: return .semantic
        }
    }
    
    private func calculateNodeSimilarity(_ node1: any CognitiveMemoryNode, _ node2: any CognitiveMemoryNode) async -> Double {
        let contentSimilarity = calculateContentSimilarity(node1.content, node2.content)
        let importanceSimilarity = 1.0 - abs(node1.importance - node2.importance)
        
        return (contentSimilarity + importanceSimilarity) / 2.0
    }
    
    private func calculateContentSimilarity(_ content1: String, _ content2: String) -> Double {
        let words1 = Set(content1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(content2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func calculateTemporalSimilarity(_ context1: EpisodicNode.TemporalContext, _ context2: EpisodicNode.TemporalContext) -> Double {
        var similarity = 0.0
        
        if context1.timeOfDay == context2.timeOfDay { similarity += 0.3 }
        if context1.dayOfWeek == context2.dayOfWeek { similarity += 0.2 }
        if context1.season == context2.season { similarity += 0.1 }
        if context1.relativeTime == context2.relativeTime { similarity += 0.4 }
        
        return similarity
    }
    
    private func calculateCausalRelationship(_ content1: String, _ content2: String) -> Double {
        let causalKeywords = ["because", "therefore", "causes", "leads to", "results in", "due to", "since"]
        
        let content1Lower = content1.lowercased()
        let content2Lower = content2.lowercased()
        
        var causalScore = 0.0
        
        for keyword in causalKeywords {
            if content1Lower.contains(keyword) || content2Lower.contains(keyword) {
                causalScore += 0.2
            }
        }
        
        return min(1.0, causalScore)
    }
    
    private func calculateAnalogyScore(_ node1: SemanticNode, _ node2: SemanticNode) -> Double {
        // Similar concept types but different content suggests analogy
        if node1.conceptType == node2.conceptType {
            let contentSimilarity = calculateContentSimilarity(node1.content, node2.content)
            return contentSimilarity > 0.2 && contentSimilarity < 0.8 ? 0.6 : 0.0
        }
        
        return 0.0
    }
    
    private func calculateConceptualIntegration(_ node1: any CognitiveMemoryNode, _ node2: any CognitiveMemoryNode) async -> Double {
        let sharedConnections = Set(node1.connections).intersection(Set(node2.connections))
        let connectionScore = Double(sharedConnections.count) * 0.1
        
        let contentScore = calculateContentSimilarity(node1.content, node2.content)
        
        return (connectionScore + contentScore) / 2.0
    }
    
    private func calculateLayerCompatibility(_ nodes: [any CognitiveMemoryNode]) -> Double {
        let layers = Set(nodes.map { getNodeLayerType($0) })
        
        // Cross-layer fusions are more valuable
        return layers.count > 1 ? 0.8 : 0.5
    }
    
    private func calculateConnectionStrength(_ nodes: [any CognitiveMemoryNode]) async -> Double {
        var totalConnections = 0
        var sharedConnections = 0
        
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let connections1 = Set(nodes[i].connections)
                let connections2 = Set(nodes[j].connections)
                
                totalConnections += connections1.count + connections2.count
                sharedConnections += connections1.intersection(connections2).count
            }
        }
        
        return totalConnections > 0 ? Double(sharedConnections) / Double(totalConnections) : 0.0
    }
    
    private func countSimilarFusions(_ candidate: FusionCandidate) async -> Int {
        let sourceNodeIds = Set(candidate.sourceNodes.map { $0.id.uuidString })
        
        return cognitiveSystem.fusionNodes.count { fusionNode in
            let fusionSourceIds = Set(fusionNode.sourceNodes)
            return !fusionSourceIds.intersection(sourceNodeIds).isEmpty
        }
    }
    
    private func getFusionTypeDescription(_ fusionType: FusionNode.FusionType) -> String {
        switch fusionType {
        case .crossLayer: return "Cross-layer integration"
        case .withinLayer: return "Within-layer connection"
        case .temporal: return "Temporal relationship"
        case .causal: return "Causal relationship"
        case .analogical: return "Analogical connection"
        case .conceptual: return "Conceptual integration"
        }
    }
}

// MARK: - Supporting Types

private struct FusionCandidate {
    let sourceNodes: [any CognitiveMemoryNode]
    let fusionType: FusionNode.FusionType
    var fusionScore: Double
    let contentSimilarity: Double
    let importance: Double
    let novelty: Double
}