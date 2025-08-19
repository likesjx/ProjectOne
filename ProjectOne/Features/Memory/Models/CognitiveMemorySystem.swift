//
//  CognitiveMemorySystem.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Cognitive Memory System coordinating all ComoRAG layers
//

import Foundation
import SwiftData
import os.log

// MARK: - Main Cognitive Memory System

/// Cognitive Memory System implementing ComoRAG 3-layer architecture
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class CognitiveMemorySystem: ObservableObject, @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "CognitiveMemorySystem")
    private let modelContext: ModelContext
    
    // MARK: - ComoRAG 3-Layer Architecture
    
    /// Veridical layer - immediate facts and observations (maps to STM)
    public let veridicalLayer: VeridicalMemoryLayer
    
    /// Semantic layer - consolidated knowledge and concepts (maps to LTM)
    public let semanticLayer: SemanticMemoryLayer
    
    /// Episodic layer - experiential memories and contexts (maps to Episodic Memory)
    public let episodicLayer: EpisodicMemoryLayer
    
    /// Fusion layer - cross-layer connections and insights
    @Published public private(set) var fusionNodes: [FusionNode] = []
    
    // MARK: - Integration with Existing ProjectOne Components
    
    /// Enhanced ProjectOne memory components
    public private(set) var shortTermMemory: ShortTermMemory?
    public private(set) var longTermMemory: LongTermMemory?
    public private(set) var workingMemory: [WorkingMemoryItem] = []
    public private(set) var episodicMemory: [EpisodicMemoryEntry] = []
    
    // MARK: - System State
    
    @Published public private(set) var systemMetrics: CognitiveSystemMetrics
    @Published public private(set) var isConsolidating: Bool = false
    @Published public private(set) var lastConsolidation: Date?
    
    // Performance optimization
    public private(set) lazy var performanceOptimizer: CognitivePerformanceOptimizer = {
        CognitivePerformanceOptimizer(
            cognitiveSystem: self,
            batchSize: 25,
            memoryThreshold: 0.8,
            indexingEnabled: true
        )
    }()
    
    // Configuration
    private let consolidationInterval: TimeInterval = 300 // 5 minutes
    private let maxFusionNodes: Int = 200
    private let fusionThreshold: Double = 0.6
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Initialize cognitive layers
        self.veridicalLayer = VeridicalMemoryLayer(modelContext: modelContext)
        self.semanticLayer = SemanticMemoryLayer(modelContext: modelContext)
        self.episodicLayer = EpisodicMemoryLayer(modelContext: modelContext)
        
        // Initialize system metrics
        self.systemMetrics = CognitiveSystemMetrics(
            veridicalCount: 0,
            semanticCount: 0,
            episodicCount: 0,
            fusionCount: 0,
            systemLoadFactor: 0.0,
            memoryEfficiency: 1.0,
            lastUpdateTime: Date()
        )
        
        // Load existing data and start background tasks
        Task {
            await initializeSystem()
            await startConsolidationLoop()
        }
        
        logger.info("Cognitive Memory System initialized")
    }
    
    // MARK: - Core System Operations
    
    /// Add a veridical (immediate fact) to the system
    public func addVeridicalFact(
        content: String,
        factType: VeridicalNode.FactType,
        sourceReference: String? = nil,
        importance: Double = 0.5
    ) async throws {
        let node = VeridicalNode(
            content: content,
            factType: factType,
            sourceReference: sourceReference,
            importance: importance
        )
        
        try await veridicalLayer.addNode(node)
        await updateSystemMetrics()
        
        logger.info("Added veridical fact: \(content.prefix(50))")
    }
    
    /// Add a semantic concept to the system
    public func addSemanticConcept(
        content: String,
        conceptType: SemanticNode.ConceptType,
        abstractionLevel: Int = 0,
        importance: Double = 0.7
    ) async throws {
        let node = SemanticNode(
            content: content,
            conceptType: conceptType,
            abstractionLevel: abstractionLevel,
            importance: importance
        )
        
        try await semanticLayer.addNode(node)
        await updateSystemMetrics()
        
        logger.info("Added semantic concept: \(content.prefix(50))")
    }
    
    /// Add an episodic experience to the system
    public func addEpisodicExperience(
        content: String,
        episodeType: EpisodicNode.EpisodeType,
        participants: [String] = [],
        location: String? = nil,
        emotionalValence: Double = 0.0,
        importance: Double = 0.6
    ) async throws {
        let node = EpisodicNode(
            content: content,
            episodeType: episodeType,
            participants: participants,
            location: location,
            emotionalValence: emotionalValence,
            importance: importance
        )
        
        try await episodicLayer.addNode(node)
        await updateSystemMetrics()
        
        logger.info("Added episodic experience: \(content.prefix(50))")
    }
    
    /// Create fusion between nodes from different layers
    public func createFusion(
        sourceNodes: [BaseCognitiveNode],
        fusionType: FusionNode.FusionType,
        content: String,
        importance: Double = 0.8
    ) async throws {
        guard fusionNodes.count < maxFusionNodes else {
            await pruneFusionNodes()
        }
        
        let fusedLayers = Array(Set(sourceNodes.map { $0.layerType }))
        let sourceNodeIds = sourceNodes.map { $0.id.uuidString }
        
        let fusionNode = FusionNode(
            content: content,
            fusedLayers: fusedLayers,
            sourceNodes: sourceNodeIds,
            fusionType: fusionType,
            importance: importance
        )
        
        fusionNodes.append(fusionNode)
        modelContext.insert(fusionNode)
        try modelContext.save()
        
        // Update connections in source nodes
        for sourceNode in sourceNodes {
            await sourceNode.addConnection(to: fusionNode.id.uuidString)
        }
        
        await updateSystemMetrics()
        
        logger.info("Created fusion: \(content.prefix(50))")
    }
    
    // MARK: - Cognitive Search Operations
    
    /// Search across all cognitive layers (standard implementation)
    public func searchCognitiveLayers(
        query: String,
        layerWeights: LayerWeights = .default,
        maxResults: Int = 20
    ) async throws -> CognitiveSearchResult {
        let startTime = Date()
        
        // Search each layer
        async let veridicalResults = veridicalLayer.searchNodes(query: query, limit: maxResults / 3)
        async let semanticResults = semanticLayer.searchNodes(query: query, limit: maxResults / 3)
        async let episodicResults = episodicLayer.searchNodes(query: query, limit: maxResults / 3)
        
        // Search fusion nodes
        let fusionResults = await searchFusionNodes(query: query, limit: maxResults / 4)
        
        let results = CognitiveSearchResult(
            veridicalNodes: try await veridicalResults,
            semanticNodes: try await semanticResults,
            episodicNodes: try await episodicResults,
            fusionNodes: fusionResults,
            processingTime: Date().timeIntervalSince(startTime),
            totalRelevance: 0.0 // Would calculate combined relevance
        )
        
        logger.info("Cognitive search completed in \(results.processingTime)s")
        
        return results
    }
    
    /// Optimized search with performance enhancements
    public func optimizedSearch(
        query: String,
        layerWeights: LayerWeights = .default,
        maxResults: Int = 20
    ) async throws -> CognitiveSearchResult {
        return try await performanceOptimizer.optimizedCognitiveSearch(
            query: query,
            maxResults: maxResults,
            layerWeights: layerWeights
        )
    }
    
    /// Batch multiple search operations for improved performance
    public func batchSearch(
        queries: [String],
        layerWeights: LayerWeights = .default,
        maxResults: Int = 20
    ) async throws -> [CognitiveSearchResult] {
        let operations = queries.map { query in
            { try await self.optimizedSearch(query: query, layerWeights: layerWeights, maxResults: maxResults) }
        }
        
        return try await performanceOptimizer.batchCognitiveOperations(operations: operations)
    }
    
    /// Get memory context for a query (used by control loop)
    public func getMemoryContext(for query: String) async throws -> CognitiveMemoryContext {
        let searchResult = try await searchCognitiveLayers(query: query)
        let memoryState = await getCurrentMemoryState()
        
        return CognitiveMemoryContext(
            query: query,
            searchResult: searchResult,
            memoryState: memoryState,
            systemMetrics: systemMetrics,
            timestamp: Date()
        )
    }
    
    // MARK: - System Maintenance
    
    /// Perform full system consolidation
    public func performConsolidation() async throws {
        guard !isConsolidating else { return }
        
        await MainActor.run { isConsolidating = true }
        
        logger.info("Starting full system consolidation")
        
        do {
            // Consolidate each layer
            try await veridicalLayer.consolidate()
            try await semanticLayer.consolidate()
            try await episodicLayer.consolidate()
            
            // Identify new fusion opportunities
            await identifyFusionOpportunities()
            
            // Update system metrics
            await updateSystemMetrics()
            
            await MainActor.run {
                lastConsolidation = Date()
                isConsolidating = false
            }
            
            logger.info("System consolidation completed successfully")
            
        } catch {
            await MainActor.run { isConsolidating = false }
            logger.error("System consolidation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get current system status
    public func getSystemStatus() async -> CognitiveSystemStatus {
        await updateSystemMetrics()
        
        return CognitiveSystemStatus(
            metrics: systemMetrics,
            isHealthy: isSystemHealthy(),
            memoryPressure: calculateMemoryPressure(),
            recommendedActions: getRecommendedActions(),
            lastConsolidation: lastConsolidation
        )
    }
    
    /// Get performance metrics and optimization status
    public func getPerformanceStatus() async -> CognitivePerformanceStatus {
        let performanceMetrics = await performanceOptimizer.performanceMetrics
        let optimizationLevel = await performanceOptimizer.optimizationLevel
        
        return CognitivePerformanceStatus(
            metrics: performanceMetrics,
            optimizationLevel: optimizationLevel,
            isOptimizing: await performanceOptimizer.isOptimizing,
            recommendedOptimizations: await getRecommendedOptimizations()
        )
    }
    
    /// Trigger performance optimization manually
    public func optimizePerformance() async throws {
        try await performanceOptimizer.optimizeMemoryUsage()
        try await performanceOptimizer.optimizeSearchIndices()
    }
    
    // MARK: - Private Implementation
    
    private func initializeSystem() async {
        // Load existing fusion nodes
        do {
            let descriptor = FetchDescriptor<FusionNode>(
                sortBy: [SortDescriptor(\\.timestamp, order: .reverse)]
            )
            fusionNodes = try modelContext.fetch(descriptor)
            
            // Load existing ProjectOne memory components if available
            await loadExistingMemoryComponents()
            
            await updateSystemMetrics()
            
        } catch {
            logger.error("Failed to initialize system: \(error.localizedDescription)")
        }
    }
    
    private func loadExistingMemoryComponents() async {
        // Load existing memory components from ProjectOne's memory system
        do {
            // Load STM
            let stmDescriptor = FetchDescriptor<ShortTermMemory>(
                predicate: #Predicate { $0.isActive == true },
                sortBy: [SortDescriptor(\\.createdAt, order: .reverse)]
            )
            let stmResults = try modelContext.fetch(stmDescriptor)
            shortTermMemory = stmResults.first
            
            // Load LTM
            let ltmDescriptor = FetchDescriptor<LongTermMemory>(
                sortBy: [SortDescriptor(\\.createdAt, order: .reverse)]
            )
            let ltmResults = try modelContext.fetch(ltmDescriptor)
            longTermMemory = ltmResults.first
            
            // Load Working Memory items
            let wmDescriptor = FetchDescriptor<WorkingMemoryItem>(
                sortBy: [SortDescriptor(\\.lastAccessed, order: .reverse)]
            )
            workingMemory = try modelContext.fetch(wmDescriptor)
            
            // Load Episodic Memory
            let epDescriptor = FetchDescriptor<EpisodicMemoryEntry>(
                sortBy: [SortDescriptor(\\.timestamp, order: .reverse)]
            )
            episodicMemory = try modelContext.fetch(epDescriptor)
            
            logger.info("Loaded existing memory components")
            
        } catch {
            logger.error("Failed to load existing memory components: \(error.localizedDescription)")
        }
    }
    
    private func startConsolidationLoop() async {
        // Start background consolidation loop
        Task.detached { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: UInt64(300 * 1_000_000_000)) // 5 minutes
                
                guard let self = self else { break }
                
                if await self.shouldPerformConsolidation() {
                    try? await self.performConsolidation()
                }
            }
        }
    }
    
    private func shouldPerformConsolidation() async -> Bool {
        guard let lastConsolidation = lastConsolidation else { return true }
        
        let timeSinceLastConsolidation = Date().timeIntervalSince(lastConsolidation)
        let memoryPressure = calculateMemoryPressure()
        
        return timeSinceLastConsolidation > consolidationInterval || memoryPressure > 0.8
    }
    
    private func updateSystemMetrics() async {
        let newMetrics = CognitiveSystemMetrics(
            veridicalCount: veridicalLayer.nodes.count,
            semanticCount: semanticLayer.nodes.count,
            episodicCount: episodicLayer.nodes.count,
            fusionCount: fusionNodes.count,
            systemLoadFactor: calculateSystemLoad(),
            memoryEfficiency: calculateMemoryEfficiency(),
            lastUpdateTime: Date()
        )
        
        await MainActor.run {
            systemMetrics = newMetrics
        }
    }
    
    private func searchFusionNodes(query: String, limit: Int) async -> [FusionNode] {
        let relevantNodes = fusionNodes.compactMap { node -> (node: FusionNode, score: Double)? in
            let score = calculateFusionRelevance(node: node, query: query)
            return score > 0.1 ? (node, score) : nil
        }
        
        let sortedNodes = relevantNodes.sorted { $0.score > $1.score }
        return Array(sortedNodes.prefix(limit)).map { $0.node }
    }
    
    private func calculateFusionRelevance(node: FusionNode, query: String) -> Double {
        let contentRelevance = calculateTextRelevance(content: node.content, query: query)
        let coherenceBonus = node.coherenceScore * 0.2
        let noveltyBonus = node.noveltyScore * 0.1
        
        return contentRelevance + coherenceBonus + noveltyBonus
    }
    
    private func calculateTextRelevance(content: String, query: String) -> Double {
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
    
    private func identifyFusionOpportunities() async {
        // Identify potential fusion opportunities across layers
        // This is a simplified implementation - full version would use ML
        
        var opportunityCount = 0
        
        // Look for veridical-semantic connections
        for verNode in veridicalLayer.nodes.prefix(50) { // Limit for performance
            for semNode in semanticLayer.nodes.prefix(50) {
                if await shouldCreateFusion(verNode, semNode) {
                    try? await createAutomaticFusion([verNode, semNode], type: .crossLayer)
                    opportunityCount += 1
                }
            }
        }
        
        logger.info("Identified \(opportunityCount) fusion opportunities")
    }
    
    private func shouldCreateFusion(_ node1: BaseCognitiveNode, _ node2: BaseCognitiveNode) async -> Bool {
        let contentSimilarity = calculateContentSimilarity(node1.content, node2.content)
        let connectionStrength = calculateConnectionStrength(node1, node2)
        
        return contentSimilarity > fusionThreshold || connectionStrength > fusionThreshold
    }
    
    private func createAutomaticFusion(_ nodes: [BaseCognitiveNode], type: FusionNode.FusionType) async throws {
        let fusionContent = "Fusion of: " + nodes.map { $0.content.prefix(30) }.joined(separator: " | ")
        let averageImportance = nodes.reduce(0.0) { $0 + $1.importance } / Double(nodes.count)
        
        try await createFusion(
            sourceNodes: nodes,
            fusionType: type,
            content: String(fusionContent),
            importance: averageImportance
        )
    }
    
    private func calculateContentSimilarity(_ content1: String, _ content2: String) -> Double {
        let words1 = Set(content1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(content2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func calculateConnectionStrength(_ node1: BaseCognitiveNode, _ node2: BaseCognitiveNode) -> Double {
        let sharedConnections = Set(node1.connections).intersection(Set(node2.connections))
        let totalConnections = Set(node1.connections).union(Set(node2.connections))
        
        return totalConnections.isEmpty ? 0.0 : Double(sharedConnections.count) / Double(totalConnections.count)
    }
    
    private func getCurrentMemoryState() async -> MemorySystemState {
        return MemorySystemState(
            shortTermCount: shortTermMemory?.workingSet.count ?? 0,
            longTermCount: semanticLayer.nodes.count,
            workingSetSize: workingMemory.count,
            episodicCount: episodicLayer.nodes.count,
            systemLoadFactor: systemMetrics.systemLoadFactor,
            lastConsolidation: lastConsolidation
        )
    }
    
    private func calculateSystemLoad() -> Double {
        let totalNodes = veridicalLayer.nodes.count + semanticLayer.nodes.count + episodicLayer.nodes.count + fusionNodes.count
        let maxCapacity = veridicalLayer.maxCapacity + semanticLayer.maxCapacity + episodicLayer.maxCapacity + maxFusionNodes
        
        return Double(totalNodes) / Double(maxCapacity)
    }
    
    private func calculateMemoryEfficiency() -> Double {
        let activeNodes = veridicalLayer.nodes.filter { $0.accessCount > 0 }.count +
                         semanticLayer.nodes.filter { $0.accessCount > 0 }.count +
                         episodicLayer.nodes.filter { $0.accessCount > 0 }.count
        
        let totalNodes = veridicalLayer.nodes.count + semanticLayer.nodes.count + episodicLayer.nodes.count
        
        return totalNodes > 0 ? Double(activeNodes) / Double(totalNodes) : 1.0
    }
    
    private func isSystemHealthy() -> Bool {
        let memoryPressure = calculateMemoryPressure()
        let efficiency = systemMetrics.memoryEfficiency
        
        return memoryPressure < 0.9 && efficiency > 0.3
    }
    
    private func calculateMemoryPressure() -> Double {
        return systemMetrics.systemLoadFactor
    }
    
    private func getRecommendedActions() -> [String] {
        var actions: [String] = []
        
        if calculateMemoryPressure() > 0.8 {
            actions.append("Consider consolidation")
        }
        
        if systemMetrics.memoryEfficiency < 0.5 {
            actions.append("Review unused memories")
        }
        
        if fusionNodes.count > maxFusionNodes * 9 / 10 {
            actions.append("Prune fusion nodes")
        }
        
        return actions
    }
    
    private func getRecommendedOptimizations() async -> [String] {
        var optimizations: [String] = []
        
        let performanceMetrics = await performanceOptimizer.performanceMetrics
        
        if performanceMetrics.avgQueryTime > 1.0 {
            optimizations.append("Enable query caching")
        }
        
        if performanceMetrics.cacheHitRate < 0.5 {
            optimizations.append("Increase cache size")
        }
        
        if performanceMetrics.memoryUsage > 0.8 {
            optimizations.append("Optimize memory usage")
        }
        
        if performanceMetrics.indexEfficiency < 0.7 {
            optimizations.append("Rebuild search indices")
        }
        
        if systemMetrics.systemLoadFactor > 0.7 {
            optimizations.append("Increase optimization level")
        }
        
        return optimizations
    }
    
    private func pruneFusionNodes() async {
        let sortedNodes = fusionNodes.sorted { node1, node2 in
            let score1 = node1.coherenceScore + node1.strengthScore
            let score2 = node2.coherenceScore + node2.strengthScore
            return score1 < score2
        }
        
        let removeCount = fusionNodes.count / 10 // Remove bottom 10%
        let nodesToRemove = Array(sortedNodes.prefix(removeCount))
        
        for node in nodesToRemove {
            fusionNodes.removeAll { $0.id == node.id }
            modelContext.delete(node)
        }
        
        try? modelContext.save()
        
        logger.info("Pruned \(nodesToRemove.count) fusion nodes")
    }
}

// MARK: - Supporting Data Structures

/// Configuration for layer search weighting
public struct LayerWeights: Sendable {
    public let veridical: Double
    public let semantic: Double
    public let episodic: Double
    public let fusion: Double
    
    public static let `default` = LayerWeights(veridical: 0.2, semantic: 0.4, episodic: 0.3, fusion: 0.1)
    public static let factFocus = LayerWeights(veridical: 0.5, semantic: 0.3, episodic: 0.1, fusion: 0.1)
    public static let conceptualFocus = LayerWeights(veridical: 0.1, semantic: 0.6, episodic: 0.2, fusion: 0.1)
    public static let experientialFocus = LayerWeights(veridical: 0.1, semantic: 0.2, episodic: 0.6, fusion: 0.1)
}

/// Results from cognitive layer search
public struct CognitiveSearchResult: Sendable {
    public let veridicalNodes: [VeridicalNode]
    public let semanticNodes: [SemanticNode]
    public let episodicNodes: [EpisodicNode]
    public let fusionNodes: [FusionNode]
    public let processingTime: TimeInterval
    public let totalRelevance: Double
}

/// Memory context for cognitive operations
public struct CognitiveMemoryContext: Sendable {
    public let query: String
    public let searchResult: CognitiveSearchResult
    public let memoryState: MemorySystemState
    public let systemMetrics: CognitiveSystemMetrics
    public let timestamp: Date
}

/// System metrics for cognitive memory
public struct CognitiveSystemMetrics: Sendable {
    public let veridicalCount: Int
    public let semanticCount: Int
    public let episodicCount: Int
    public let fusionCount: Int
    public let systemLoadFactor: Double
    public let memoryEfficiency: Double
    public let lastUpdateTime: Date
}

/// Overall system status
public struct CognitiveSystemStatus: Sendable {
    public let metrics: CognitiveSystemMetrics
    public let isHealthy: Bool
    public let memoryPressure: Double
    public let recommendedActions: [String]
    public let lastConsolidation: Date?
}

/// Performance status including optimization metrics
public struct CognitivePerformanceStatus: Sendable {
    public let metrics: PerformanceMetrics
    public let optimizationLevel: CognitivePerformanceOptimizer.OptimizationLevel
    public let isOptimizing: Bool
    public let recommendedOptimizations: [String]
}