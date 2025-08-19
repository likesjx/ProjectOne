//
//  MemoryRetrievalEngine.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Memory Retrieval Engine for ComoRAG control loop retrieval phase
//

import Foundation
import SwiftData
import os.log

// MARK: - Memory Retrieval Engine

/// Engine responsible for retrieving specific memory nodes based on probe results
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class MemoryRetrievalEngine: @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryRetrievalEngine")
    private let cognitiveSystem: CognitiveMemorySystem
    
    // Configuration
    private let relevanceThreshold: Double
    private let diversityWeight: Double
    private let recencyWeight: Double
    
    public init(
        cognitiveSystem: CognitiveMemorySystem,
        relevanceThreshold: Double = 0.3,
        diversityWeight: Double = 0.15,
        recencyWeight: Double = 0.1
    ) {
        self.cognitiveSystem = cognitiveSystem
        self.relevanceThreshold = relevanceThreshold
        self.diversityWeight = diversityWeight
        self.recencyWeight = recencyWeight
    }
    
    // MARK: - Main Retrieval Methods
    
    /// Retrieve memory nodes based on probe results
    public func retrieveFromProbeResult(
        probeResult: ProbeResult,
        maxNodes: Int
    ) async throws -> RetrievalResult {
        logger.debug("Retrieving memories from probe result with \(maxNodes) max nodes")
        
        // Collect all candidate nodes with their relevance scores
        var candidateNodes: [(node: any CognitiveMemoryNode, relevance: Double)] = []
        
        // Retrieve from each layer
        let veridicalNodes = await retrieveVeridicalNodes(nodeIds: probeResult.veridicalHits, relevanceScores: probeResult.relevanceScores)
        let semanticNodes = await retrieveSemanticNodes(nodeIds: probeResult.semanticHits, relevanceScores: probeResult.relevanceScores)
        let episodicNodes = await retrieveEpisodicNodes(nodeIds: probeResult.episodicHits, relevanceScores: probeResult.relevanceScores)
        let fusionNodes = await retrieveFusionNodes(nodeIds: probeResult.fusionHits, relevanceScores: probeResult.relevanceScores)
        
        candidateNodes.append(contentsOf: veridicalNodes)
        candidateNodes.append(contentsOf: semanticNodes)
        candidateNodes.append(contentsOf: episodicNodes)
        candidateNodes.append(contentsOf: fusionNodes)
        
        // Filter by relevance threshold
        let filteredNodes = candidateNodes.filter { $0.relevance >= relevanceThreshold }
        
        // Apply ranking and selection
        let selectedNodes = await selectBestNodes(from: filteredNodes, maxCount: maxNodes)
        
        // Calculate layer distribution
        var layerDistribution: [CognitiveLayerType: Int] = [:]
        for (node, _) in selectedNodes {
            let layerType = getNodeLayerType(node)
            layerDistribution[layerType, default: 0] += 1
        }
        
        // Create retrieval context
        let retrievalContext = await generateRetrievalContext(from: selectedNodes)
        
        // Calculate total relevance
        let totalRelevance = selectedNodes.reduce(0.0) { $0 + $1.relevance }
        
        // Record access for retrieved nodes
        for (node, _) in selectedNodes {
            await node.recordAccess()
        }
        
        let result = RetrievalResult(
            retrievedNodes: selectedNodes.map { $0.node },
            retrievalContext: retrievalContext,
            totalRelevanceScore: totalRelevance,
            layerDistribution: layerDistribution
        )
        
        logger.debug("Retrieved \(selectedNodes.count) nodes with total relevance: \(totalRelevance)")
        
        return result
    }
    
    // MARK: - Layer-Specific Retrieval
    
    private func retrieveVeridicalNodes(
        nodeIds: [String],
        relevanceScores: [String: Double]
    ) async -> [(node: any CognitiveMemoryNode, relevance: Double)] {
        var retrievedNodes: [(node: any CognitiveMemoryNode, relevance: Double)] = []
        
        for nodeId in nodeIds {
            if let uuid = UUID(uuidString: nodeId),
               let node = cognitiveSystem.veridicalLayer.nodes.first(where: { $0.id == uuid }),
               let relevance = relevanceScores[nodeId] {
                retrievedNodes.append((node, relevance))
            }
        }
        
        logger.debug("Retrieved \(retrievedNodes.count) veridical nodes")
        return retrievedNodes
    }
    
    private func retrieveSemanticNodes(
        nodeIds: [String],
        relevanceScores: [String: Double]
    ) async -> [(node: any CognitiveMemoryNode, relevance: Double)] {
        var retrievedNodes: [(node: any CognitiveMemoryNode, relevance: Double)] = []
        
        for nodeId in nodeIds {
            if let uuid = UUID(uuidString: nodeId),
               let node = cognitiveSystem.semanticLayer.nodes.first(where: { $0.id == uuid }),
               let relevance = relevanceScores[nodeId] {
                retrievedNodes.append((node, relevance))
            }
        }
        
        logger.debug("Retrieved \(retrievedNodes.count) semantic nodes")
        return retrievedNodes
    }
    
    private func retrieveEpisodicNodes(
        nodeIds: [String],
        relevanceScores: [String: Double]
    ) async -> [(node: any CognitiveMemoryNode, relevance: Double)] {
        var retrievedNodes: [(node: any CognitiveMemoryNode, relevance: Double)] = []
        
        for nodeId in nodeIds {
            if let uuid = UUID(uuidString: nodeId),
               let node = cognitiveSystem.episodicLayer.nodes.first(where: { $0.id == uuid }),
               let relevance = relevanceScores[nodeId] {
                retrievedNodes.append((node, relevance))
            }
        }
        
        logger.debug("Retrieved \(retrievedNodes.count) episodic nodes")
        return retrievedNodes
    }
    
    private func retrieveFusionNodes(
        nodeIds: [String],
        relevanceScores: [String: Double]
    ) async -> [(node: any CognitiveMemoryNode, relevance: Double)] {
        var retrievedNodes: [(node: any CognitiveMemoryNode, relevance: Double)] = []
        
        for nodeId in nodeIds {
            if let uuid = UUID(uuidString: nodeId),
               let node = cognitiveSystem.fusionNodes.first(where: { $0.id == uuid }),
               let relevance = relevanceScores[nodeId] {
                retrievedNodes.append((node, relevance))
            }
        }
        
        logger.debug("Retrieved \(retrievedNodes.count) fusion nodes")
        return retrievedNodes
    }
    
    // MARK: - Node Selection and Ranking
    
    private func selectBestNodes(
        from candidates: [(node: any CognitiveMemoryNode, relevance: Double)],
        maxCount: Int
    ) async -> [(node: any CognitiveMemoryNode, relevance: Double)] {
        logger.debug("Selecting best \(maxCount) nodes from \(candidates.count) candidates")
        
        // Calculate composite scores for ranking
        var scoredCandidates: [(node: any CognitiveMemoryNode, relevance: Double, compositeScore: Double)] = []
        
        for (node, relevance) in candidates {
            let diversityScore = await calculateDiversityScore(node: node, existingNodes: scoredCandidates.map { $0.node })
            let recencyScore = calculateRecencyScore(node: node)
            let importanceScore = node.importance
            let strengthScore = getNodeStrengthScore(node)
            
            let compositeScore = relevance * 0.5 +
                               diversityScore * diversityWeight +
                               recencyScore * recencyWeight +
                               importanceScore * 0.15 +
                               strengthScore * 0.1
            
            scoredCandidates.append((node, relevance, compositeScore))
        }
        
        // Sort by composite score and take top candidates
        let sortedCandidates = scoredCandidates.sorted { $0.compositeScore > $1.compositeScore }
        let selectedCandidates = Array(sortedCandidates.prefix(maxCount))
        
        logger.debug("Selected \(selectedCandidates.count) best nodes based on composite scoring")
        
        return selectedCandidates.map { (node: $0.node, relevance: $0.relevance) }
    }
    
    // MARK: - Scoring Methods
    
    private func calculateDiversityScore(
        node: any CognitiveMemoryNode,
        existingNodes: [any CognitiveMemoryNode]
    ) async -> Double {
        if existingNodes.isEmpty { return 1.0 }
        
        let nodeLayerType = getNodeLayerType(node)
        let existingLayerTypes = existingNodes.map { getNodeLayerType($0) }
        
        // Bonus for layer diversity
        let layerDiversityBonus = existingLayerTypes.contains(nodeLayerType) ? 0.0 : 0.3
        
        // Content diversity (simplified)
        var minSimilarity = 1.0
        for existingNode in existingNodes {
            let similarity = calculateContentSimilarity(node.content, existingNode.content)
            minSimilarity = min(minSimilarity, similarity)
        }
        
        let contentDiversityScore = 1.0 - minSimilarity
        
        return layerDiversityBonus + contentDiversityScore * 0.7
    }
    
    private func calculateRecencyScore(node: any CognitiveMemoryNode) -> Double {
        let daysSinceAccess = Date().timeIntervalSince(node.lastAccessed) / (24 * 60 * 60)
        
        // Recency decays over 30 days
        return max(0.0, 1.0 - (daysSinceAccess / 30.0))
    }
    
    private func getNodeStrengthScore(_ node: any CognitiveMemoryNode) -> Double {
        if let baseCognitiveNode = node as? BaseCognitiveNode {
            return baseCognitiveNode.strengthScore
        }
        
        // Fallback calculation based on access count and importance
        let accessScore = min(1.0, Double(node.accessCount) * 0.1)
        return (accessScore + node.importance) / 2.0
    }
    
    private func getNodeLayerType(_ node: any CognitiveMemoryNode) -> CognitiveLayerType {
        switch node.nodeType {
        case .fact:
            return .veridical
        case .concept:
            return .semantic
        case .episode:
            return .episodic
        case .fusion:
            return .fusion
        default:
            return .semantic // Default fallback
        }
    }
    
    private func calculateContentSimilarity(_ content1: String, _ content2: String) -> Double {
        let words1 = Set(content1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(content2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    // MARK: - Context Generation
    
    private func generateRetrievalContext(
        from selectedNodes: [(node: any CognitiveMemoryNode, relevance: Double)]
    ) async -> String {
        var contextComponents: [String] = []
        
        // Group by layer type
        var layerContents: [CognitiveLayerType: [String]] = [:]
        
        for (node, relevance) in selectedNodes {
            let layerType = getNodeLayerType(node)
            let contentWithRelevance = "\(node.content) (relevance: \(String(format: "%.2f", relevance)))"
            layerContents[layerType, default: []].append(contentWithRelevance)
        }
        
        // Format context by layer
        for (layerType, contents) in layerContents.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let layerSection = "\(layerType.rawValue.capitalized) Layer:\n" + contents.joined(separator: "\n")
            contextComponents.append(layerSection)
        }
        
        let context = contextComponents.joined(separator: "\n\n")
        logger.debug("Generated retrieval context with \(contextComponents.count) layer sections")
        
        return context
    }
}