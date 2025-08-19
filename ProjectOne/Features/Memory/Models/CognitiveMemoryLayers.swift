//
//  CognitiveMemoryLayers.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Cognitive Memory Layer Implementations for ComoRAG Architecture
//

import Foundation
import SwiftData
import os.log

// MARK: - Veridical Memory Layer

/// Veridical layer - immediate facts and observations (maps to STM)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class VeridicalMemoryLayer: CognitiveMemoryLayer, ObservableObject, @unchecked Sendable {
    public typealias NodeType = VeridicalNode
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "VeridicalMemoryLayer")
    private let modelContext: ModelContext
    
    public let layerType: CognitiveLayerType = .veridical
    public var nodes: [VeridicalNode] = []
    public let maxCapacity: Int = 100 // Limit for immediate facts
    public let consolidationThreshold: Double = 0.8
    
    // Veridical-specific properties
    private let immediacyDecayRate: Double = 0.02 // Daily decay rate for immediacy
    private let verificationBonus: Double = 0.2
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await loadNodes()
        }
    }
    
    // MARK: - CognitiveMemoryLayer Implementation
    
    public func addNode(_ node: VeridicalNode) async throws {
        // Check capacity
        if nodes.count >= maxCapacity {
            await pruneOldestNodes()
        }
        
        // Add to in-memory collection
        nodes.append(node)
        
        // Persist to SwiftData
        modelContext.insert(node)
        try modelContext.save()
        
        logger.info("Added veridical node: \(node.content.prefix(50))")
    }
    
    public func removeNode(_ node: VeridicalNode) async throws {
        // Remove from in-memory collection
        nodes.removeAll { $0.id == node.id }
        
        // Remove from SwiftData
        modelContext.delete(node)
        try modelContext.save()
        
        logger.info("Removed veridical node: \(node.id)")
    }
    
    public func searchNodes(query: String, limit: Int) async throws -> [VeridicalNode] {
        let queryTerms = extractQueryTerms(from: query)
        
        // Score nodes by relevance
        let scoredNodes = nodes.compactMap { node -> (node: VeridicalNode, score: Double)? in
            let relevanceScore = await getRelevanceScore(for: query, node: node)
            return relevanceScore > 0.1 ? (node, relevanceScore) : nil
        }
        
        // Sort by score and apply limit
        let sortedNodes = scoredNodes.sorted { $0.score > $1.score }
        let limitedNodes = Array(sortedNodes.prefix(limit))
        
        // Record access for retrieved nodes
        for (node, _) in limitedNodes {
            await node.recordAccess()
        }
        
        try modelContext.save() // Save access updates
        
        return limitedNodes.map { $0.node }
    }
    
    public func consolidate() async throws {
        logger.info("Starting veridical layer consolidation")
        
        var consolidatedCount = 0
        var promotedNodes: [VeridicalNode] = []
        
        for node in nodes {
            // Update immediacy scores
            node.updateImmediacy()
            
            // Check for consolidation eligibility
            if shouldConsolidate(node) {
                promotedNodes.append(node)
                consolidatedCount += 1
            }
        }
        
        // Process consolidation (would integrate with semantic layer)
        for node in promotedNodes {
            await processConsolidation(node)
        }
        
        try modelContext.save()
        
        logger.info("Consolidated \(consolidatedCount) veridical nodes")
    }
    
    public func getRelevanceScore(for query: String, node: VeridicalNode) async -> Double {
        var score = 0.0
        
        // Content relevance
        score += calculateTextRelevanceScore(content: node.content, query: query) * 0.4
        
        // Immediacy bonus
        score += node.immediacyScore * 0.2
        
        // Verification status bonus
        switch node.verificationStatus {
        case .verified:
            score += verificationBonus
        case .conflicted:
            score *= 0.7 // Penalize conflicted facts
        case .deprecated:
            score *= 0.3 // Heavily penalize deprecated facts
        case .unverified:
            break // No bonus or penalty
        }
        
        // Fact type relevance
        score += getFactTypeRelevance(factType: node.factType, query: query) * 0.1
        
        // Importance and strength
        score += node.importance * 0.15
        score += node.strengthScore * 0.15
        
        return min(1.0, score)
    }
    
    // MARK: - Veridical-Specific Methods
    
    private func loadNodes() async {
        do {
            let descriptor = FetchDescriptor<VeridicalNode>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            nodes = try modelContext.fetch(descriptor)
            logger.info("Loaded \(nodes.count) veridical nodes")
        } catch {
            logger.error("Failed to load veridical nodes: \(error.localizedDescription)")
        }
    }
    
    private func pruneOldestNodes() async {
        // Remove nodes with lowest combined score (importance + immediacy + strength)
        let sortedNodes = nodes.sorted { node1, node2 in
            let score1 = node1.importance + node1.immediacyScore + node1.strengthScore
            let score2 = node2.importance + node2.immediacyScore + node2.strengthScore
            return score1 < score2
        }
        
        // Remove bottom 10% to make room
        let removeCount = max(1, nodes.count / 10)
        let nodesToRemove = Array(sortedNodes.prefix(removeCount))
        
        for node in nodesToRemove {
            try? await removeNode(node)
        }
        
        logger.info("Pruned \(nodesToRemove.count) oldest veridical nodes")
    }
    
    private func shouldConsolidate(_ node: VeridicalNode) -> Bool {
        // Consolidate if:
        // 1. High importance and verified
        // 2. Frequently accessed
        // 3. Strong connections to other nodes
        
        let importanceThreshold = node.importance > consolidationThreshold
        let verifiedStatus = node.verificationStatus == .verified
        let highAccess = node.accessCount > 5
        let strongConnections = node.connections.count > 2
        
        return (importanceThreshold && verifiedStatus) || (highAccess && strongConnections)
    }
    
    private func processConsolidation(_ node: VeridicalNode) async {
        // Increase consolidation score
        node.consolidationScore = min(1.0, node.consolidationScore + 0.1)
        
        // This would trigger promotion to semantic layer in full implementation
        logger.debug("Node \(node.id) eligible for semantic layer promotion")
    }
    
    // MARK: - Helper Methods
    
    private func extractQueryTerms(from query: String) -> [String] {
        return query.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }
            .map { $0.lowercased() }
    }
    
    private func calculateTextRelevanceScore(content: String, query: String) -> Double {
        let contentWords = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var matchCount = 0
        for queryWord in queryWords {
            if contentWords.contains(queryWord) {
                matchCount += 2 // Exact match
            } else if contentWords.contains(where: { $0.contains(queryWord) }) {
                matchCount += 1 // Partial match
            }
        }
        
        return Double(matchCount) / Double(queryWords.count * 2)
    }
    
    private func getFactTypeRelevance(factType: VeridicalNode.FactType, query: String) -> Double {
        let queryLower = query.lowercased()
        
        // Simple heuristics for fact type relevance
        switch factType {
        case .observation:
            return queryLower.contains("see") || queryLower.contains("observe") ? 0.3 : 0.0
        case .statement:
            return queryLower.contains("said") || queryLower.contains("told") ? 0.3 : 0.0
        case .measurement:
            return queryLower.contains("measure") || queryLower.contains("number") ? 0.3 : 0.0
        case .event:
            return queryLower.contains("happen") || queryLower.contains("occur") ? 0.3 : 0.0
        case .condition:
            return queryLower.contains("if") || queryLower.contains("when") ? 0.3 : 0.0
        }
    }
}

// MARK: - Semantic Memory Layer

/// Semantic layer - consolidated knowledge and concepts (maps to LTM)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class SemanticMemoryLayer: CognitiveMemoryLayer, ObservableObject, @unchecked Sendable {
    public typealias NodeType = SemanticNode
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "SemanticMemoryLayer")
    private let modelContext: ModelContext
    
    public let layerType: CognitiveLayerType = .semantic
    public var nodes: [SemanticNode] = []
    public let maxCapacity: Int = 500 // Higher capacity for consolidated knowledge
    public let consolidationThreshold: Double = 0.7
    
    // Semantic-specific properties
    private let abstractionBonus: Double = 0.1
    private let evidenceWeight: Double = 0.15
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await loadNodes()
        }
    }
    
    // MARK: - CognitiveMemoryLayer Implementation
    
    public func addNode(_ node: SemanticNode) async throws {
        // Check for similar existing concepts
        let similarNodes = await findSimilarConcepts(to: node)
        
        if let existingNode = similarNodes.first, await shouldMergeConcepts(node, existingNode) {
            await mergeConcepts(new: node, existing: existingNode)
            return
        }
        
        // Check capacity
        if nodes.count >= maxCapacity {
            await pruneWeakestNodes()
        }
        
        nodes.append(node)
        modelContext.insert(node)
        try modelContext.save()
        
        logger.info("Added semantic node: \(node.content.prefix(50))")
    }
    
    public func removeNode(_ node: SemanticNode) async throws {
        nodes.removeAll { $0.id == node.id }
        modelContext.delete(node)
        try modelContext.save()
        
        logger.info("Removed semantic node: \(node.id)")
    }
    
    public func searchNodes(query: String, limit: Int) async throws -> [SemanticNode] {
        let scoredNodes = nodes.compactMap { node -> (node: SemanticNode, score: Double)? in
            let relevanceScore = await getRelevanceScore(for: query, node: node)
            return relevanceScore > 0.1 ? (node, relevanceScore) : nil
        }
        
        let sortedNodes = scoredNodes.sorted { $0.score > $1.score }
        let limitedNodes = Array(sortedNodes.prefix(limit))
        
        // Record access
        for (node, _) in limitedNodes {
            await node.recordAccess()
        }
        
        try modelContext.save()
        
        return limitedNodes.map { $0.node }
    }
    
    public func consolidate() async throws {
        logger.info("Starting semantic layer consolidation")
        
        var consolidatedCount = 0
        
        // Generalize frequently accessed concepts
        for node in nodes {
            if shouldGeneralize(node) {
                node.generalize()
                consolidatedCount += 1
            }
        }
        
        // Find and create fusion opportunities
        await createFusionOpportunities()
        
        try modelContext.save()
        
        logger.info("Consolidated \(consolidatedCount) semantic nodes")
    }
    
    public func getRelevanceScore(for query: String, node: SemanticNode) async -> Double {
        var score = 0.0
        
        // Content relevance
        score += calculateTextRelevanceScore(content: node.content, query: query) * 0.4
        
        // Concept type relevance
        score += getConceptTypeRelevance(conceptType: node.conceptType, query: query) * 0.15
        
        // Abstraction bonus (higher abstraction often more relevant for complex queries)
        score += Double(node.abstractionLevel) * abstractionBonus * 0.1
        
        // Evidence support
        score += Double(node.evidenceNodes.count) * evidenceWeight * 0.1
        
        // Confidence and strength
        score += node.confidence * 0.2
        score += node.strengthScore * 0.15
        
        return min(1.0, score)
    }
    
    // MARK: - Semantic-Specific Methods
    
    private func loadNodes() async {
        do {
            let descriptor = FetchDescriptor<SemanticNode>(
                sortBy: [SortDescriptor(\.confidence, order: .reverse)]
            )
            nodes = try modelContext.fetch(descriptor)
            logger.info("Loaded \(nodes.count) semantic nodes")
        } catch {
            logger.error("Failed to load semantic nodes: \(error.localizedDescription)")
        }
    }
    
    private func findSimilarConcepts(to node: SemanticNode) async -> [SemanticNode] {
        // Find nodes with similar content or concept type
        return nodes.filter { existingNode in
            let contentSimilarity = calculateSimilarity(node.content, existingNode.content)
            let typeSimilarity = node.conceptType == existingNode.conceptType
            return contentSimilarity > 0.7 || typeSimilarity
        }
    }
    
    private func shouldMergeConcepts(_ new: SemanticNode, _ existing: SemanticNode) async -> Bool {
        let similarity = calculateSimilarity(new.content, existing.content)
        let sameType = new.conceptType == existing.conceptType
        return similarity > 0.8 && sameType
    }
    
    private func mergeConcepts(new: SemanticNode, existing: SemanticNode) async {
        // Merge evidence
        existing.evidenceNodes.append(contentsOf: new.evidenceNodes)
        existing.evidenceNodes = Array(Set(existing.evidenceNodes)) // Remove duplicates
        
        // Update confidence and strength
        existing.confidence = (existing.confidence + new.confidence) / 2.0
        existing.strengthScore = max(existing.strengthScore, new.strengthScore)
        
        // Merge connections
        existing.connections.append(contentsOf: new.connections)
        existing.connections = Array(Set(existing.connections))
        
        await existing.recordAccess()
        
        logger.debug("Merged concepts: \(existing.id) absorbed \(new.id)")
    }
    
    private func shouldGeneralize(_ node: SemanticNode) -> Bool {
        return node.accessCount > 10 && node.confidence > 0.7 && node.generalizationCount < 5
    }
    
    private func pruneWeakestNodes() async {
        let weakNodes = nodes.sorted { node1, node2 in
            let score1 = node1.confidence + node1.strengthScore
            let score2 = node2.confidence + node2.strengthScore
            return score1 < score2
        }
        
        let removeCount = max(1, nodes.count / 20) // Remove bottom 5%
        let nodesToRemove = Array(weakNodes.prefix(removeCount))
        
        for node in nodesToRemove {
            try? await removeNode(node)
        }
        
        logger.info("Pruned \(nodesToRemove.count) weakest semantic nodes")
    }
    
    private func createFusionOpportunities() async {
        // Identify nodes that could be fused together
        // This would create FusionNode instances in full implementation
        logger.debug("Analyzing fusion opportunities in semantic layer")
    }
    
    private func getConceptTypeRelevance(conceptType: SemanticNode.ConceptType, query: String) -> Double {
        let queryLower = query.lowercased()
        
        switch conceptType {
        case .entity:
            return queryLower.contains("who") || queryLower.contains("what") ? 0.3 : 0.0
        case .relationship:
            return queryLower.contains("how") || queryLower.contains("connect") ? 0.3 : 0.0
        case .process:
            return queryLower.contains("process") || queryLower.contains("step") ? 0.3 : 0.0
        case .rule:
            return queryLower.contains("rule") || queryLower.contains("always") ? 0.3 : 0.0
        default:
            return 0.0
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func calculateTextRelevanceScore(content: String, query: String) -> Double {
        let contentWords = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var matchCount = 0
        for queryWord in queryWords {
            if contentWords.contains(queryWord) {
                matchCount += 2
            } else if contentWords.contains(where: { $0.contains(queryWord) }) {
                matchCount += 1
            }
        }
        
        return Double(matchCount) / Double(queryWords.count * 2)
    }
}

// MARK: - Episodic Memory Layer

/// Episodic layer - experiential memories and contexts (maps to Episodic Memory)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class EpisodicMemoryLayer: CognitiveMemoryLayer, ObservableObject, @unchecked Sendable {
    public typealias NodeType = EpisodicNode
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EpisodicMemoryLayer")
    private let modelContext: ModelContext
    
    public let layerType: CognitiveLayerType = .episodic
    public var nodes: [EpisodicNode] = []
    public let maxCapacity: Int = 300 // Moderate capacity for experiences
    public let consolidationThreshold: Double = 0.6
    
    // Episodic-specific properties
    private let vividnessWeight: Double = 0.2
    private let emotionalWeight: Double = 0.15
    private let recencyBonus: Double = 0.1
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await loadNodes()
        }
    }
    
    // MARK: - CognitiveMemoryLayer Implementation
    
    public func addNode(_ node: EpisodicNode) async throws {
        // Check capacity
        if nodes.count >= maxCapacity {
            await pruneLeastVividNodes()
        }
        
        nodes.append(node)
        modelContext.insert(node)
        try modelContext.save()
        
        logger.info("Added episodic node: \(node.content.prefix(50))")
    }
    
    public func removeNode(_ node: EpisodicNode) async throws {
        nodes.removeAll { $0.id == node.id }
        modelContext.delete(node)
        try modelContext.save()
        
        logger.info("Removed episodic node: \(node.id)")
    }
    
    public func searchNodes(query: String, limit: Int) async throws -> [EpisodicNode] {
        let scoredNodes = nodes.compactMap { node -> (node: EpisodicNode, score: Double)? in
            let relevanceScore = await getRelevanceScore(for: query, node: node)
            return relevanceScore > 0.1 ? (node, relevanceScore) : nil
        }
        
        let sortedNodes = scoredNodes.sorted { $0.score > $1.score }
        let limitedNodes = Array(sortedNodes.prefix(limit))
        
        // Record access and update vividness
        for (node, _) in limitedNodes {
            await node.recordAccess()
            node.updateVividness() // Reinforce through retrieval
        }
        
        try modelContext.save()
        
        return limitedNodes.map { $0.node }
    }
    
    public func consolidate() async throws {
        logger.info("Starting episodic layer consolidation")
        
        var consolidatedCount = 0
        
        // Apply natural decay to vividness
        for node in nodes {
            node.updateVividness(decay: true)
            
            // Consolidate vivid episodes with strong connections
            if shouldConsolidate(node) {
                await processEpisodicConsolidation(node)
                consolidatedCount += 1
            }
        }
        
        try modelContext.save()
        
        logger.info("Consolidated \(consolidatedCount) episodic nodes")
    }
    
    public func getRelevanceScore(for query: String, node: EpisodicNode) async -> Double {
        var score = 0.0
        
        // Content relevance
        score += calculateTextRelevanceScore(content: node.content, query: query) * 0.3
        
        // Contextual cue relevance
        let contextScore = node.contextualCues.reduce(0.0) { sum, cue in
            sum + (query.lowercased().contains(cue.lowercased()) ? 0.1 : 0.0)
        }
        score += contextScore * 0.2
        
        // Participant relevance
        let participantScore = node.participants.reduce(0.0) { sum, participant in
            sum + (query.lowercased().contains(participant.lowercased()) ? 0.15 : 0.0)
        }
        score += participantScore
        
        // Location relevance
        if let location = node.location {
            score += query.lowercased().contains(location.lowercased()) ? 0.1 : 0.0
        }
        
        // Vividness bonus
        score += node.vividnessScore * vividnessWeight
        
        // Emotional relevance (strong emotions are more memorable)
        score += abs(node.emotionalValence) * emotionalWeight
        
        // Recency bonus
        let daysSince = Date().timeIntervalSince(node.timestamp) / (24 * 60 * 60)
        let recencyScore = max(0.0, 1.0 - (daysSince / 30.0)) // Decay over 30 days
        score += recencyScore * recencyBonus
        
        // Importance and strength
        score += node.importance * 0.1
        score += node.strengthScore * 0.1
        
        return min(1.0, score)
    }
    
    // MARK: - Episodic-Specific Methods
    
    private func loadNodes() async {
        do {
            let descriptor = FetchDescriptor<EpisodicNode>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            nodes = try modelContext.fetch(descriptor)
            logger.info("Loaded \(nodes.count) episodic nodes")
        } catch {
            logger.error("Failed to load episodic nodes: \(error.localizedDescription)")
        }
    }
    
    private func shouldConsolidate(_ node: EpisodicNode) -> Bool {
        let highVividness = node.vividnessScore > consolidationThreshold
        let strongEmotion = abs(node.emotionalValence) > 0.5
        let wellConnected = node.connections.count > 3
        let frequentlyAccessed = node.accessCount > 3
        
        return (highVividness && strongEmotion) || (wellConnected && frequentlyAccessed)
    }
    
    private func processEpisodicConsolidation(_ node: EpisodicNode) async {
        node.consolidationScore = min(1.0, node.consolidationScore + 0.15)
        
        // Strong episodic memories could contribute to semantic layer formation
        logger.debug("Episodic node \(node.id) marked for potential semantic contribution")
    }
    
    private func pruneLeastVividNodes() async {
        let sortedByVividness = nodes.sorted { $0.vividnessScore < $1.vividnessScore }
        let removeCount = max(1, nodes.count / 15) // Remove bottom ~7%
        let nodesToRemove = Array(sortedByVividness.prefix(removeCount))
        
        for node in nodesToRemove {
            try? await removeNode(node)
        }
        
        logger.info("Pruned \(nodesToRemove.count) least vivid episodic nodes")
    }
    
    private func calculateTextRelevanceScore(content: String, query: String) -> Double {
        let contentWords = content.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let queryWords = query.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var matchCount = 0
        for queryWord in queryWords {
            if contentWords.contains(queryWord) {
                matchCount += 2
            } else if contentWords.contains(where: { $0.contains(queryWord) }) {
                matchCount += 1
            }
        }
        
        return Double(matchCount) / Double(queryWords.count * 2)
    }
}