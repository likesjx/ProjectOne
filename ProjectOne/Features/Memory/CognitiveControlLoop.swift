//
//  CognitiveControlLoop.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Cognitive Control Loop implementing the ComoRAG "Reason → Probe → Retrieve → Consolidate → Resolve" cycle
//

import Foundation
import SwiftData
import os.log

// MARK: - Cognitive Control Loop

/// Cognitive Control Loop implementing ComoRAG's 5-phase reasoning cycle
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class CognitiveControlLoop: CognitiveControlParticipant, ObservableObject, @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "CognitiveControlLoop")
    
    // Core components
    private let cognitiveSystem: CognitiveMemorySystem
    private let reasoningEngine: CognitiveReasoningEngine
    private let probeEngine: MemoryProbeEngine
    private let retrievalEngine: MemoryRetrievalEngine
    private let consolidationEngine: MemoryConsolidationEngine
    private let fusionEngine: MemoryFusionEngine
    
    // State tracking
    @Published public private(set) var currentPhase: ControlLoopPhase = .idle
    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var lastCycleMetrics: CognitiveMetrics?
    @Published public private(set) var activeTrajectories: [ReasoningTrajectory] = []
    
    // Configuration
    private let maxReasoningDepth: Int
    private let explorationThreshold: Double
    private let fusionThreshold: Double
    private let consolidationInterval: TimeInterval
    
    public enum ControlLoopPhase: String, CaseIterable {
        case idle = "idle"
        case reasoning = "reasoning"
        case probing = "probing"
        case retrieving = "retrieving"
        case consolidating = "consolidating"
        case resolving = "resolving"
        case exploring = "exploring" // REX-RAG exploration phase
    }
    
    // MARK: - Initialization
    
    public init(
        cognitiveSystem: CognitiveMemorySystem,
        maxReasoningDepth: Int = 5,
        explorationThreshold: Double = 0.6,
        fusionThreshold: Double = 0.7,
        consolidationInterval: TimeInterval = 60
    ) {
        self.cognitiveSystem = cognitiveSystem
        self.maxReasoningDepth = maxReasoningDepth
        self.explorationThreshold = explorationThreshold
        self.fusionThreshold = fusionThreshold
        self.consolidationInterval = consolidationInterval
        
        // Initialize sub-engines
        self.reasoningEngine = CognitiveReasoningEngine()
        self.probeEngine = MemoryProbeEngine(cognitiveSystem: cognitiveSystem)
        self.retrievalEngine = MemoryRetrievalEngine(cognitiveSystem: cognitiveSystem)
        self.consolidationEngine = MemoryConsolidationEngine(cognitiveSystem: cognitiveSystem)
        self.fusionEngine = MemoryFusionEngine(cognitiveSystem: cognitiveSystem, fusionThreshold: fusionThreshold)
        
        logger.info("Cognitive Control Loop initialized")
    }
    
    // MARK: - Main Control Loop Execution
    
    /// Execute the complete cognitive control loop for a query
    public func processQuery(_ query: String, context: CognitiveContext? = nil) async throws -> CognitiveResponse {
        let startTime = Date()
        let effectiveContext = context ?? await createDefaultContext(for: query)
        
        await MainActor.run { 
            isProcessing = true
            currentPhase = .reasoning
        }
        
        do {
            logger.info("Starting cognitive control loop for query: \(query.prefix(50))")
            
            // Phase 1: Reason
            let reasoningResult = try await reason(query: query, context: effectiveContext)
            
            // Phase 2: Probe
            let probeResult = try await probe(layers: [
                cognitiveSystem.veridicalLayer,
                cognitiveSystem.semanticLayer,
                cognitiveSystem.episodicLayer
            ])
            
            // Phase 3: Retrieve
            let retrievalResult = try await retrieve(probeResult: probeResult)
            
            // Phase 4: Consolidate
            let consolidationResult = try await consolidate(
                reasoning: reasoningResult, 
                retrieval: retrievalResult
            )
            
            // Phase 5: Resolve
            let response = try await resolve(
                consolidation: consolidationResult, 
                query: query
            )
            
            // Calculate final metrics
            let processingTime = Date().timeIntervalSince(startTime)
            let metrics = CognitiveMetrics(
                processingTimeMs: processingTime * 1000,
                memoryHits: retrievalResult.retrievedNodes.count,
                layersEngaged: retrievalResult.layerDistribution.keys.count,
                fusionOperations: consolidationResult.fusedConnections.count,
                confidenceScore: response.confidence,
                explorationPaths: activeTrajectories.count
            )
            
            await MainActor.run {
                lastCycleMetrics = metrics
                isProcessing = false
                currentPhase = .idle
            }
            
            logger.info("Cognitive control loop completed in \(processingTime)s")
            
            return response
            
        } catch {
            await MainActor.run {
                isProcessing = false
                currentPhase = .idle
            }
            
            logger.error("Cognitive control loop failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - CognitiveControlParticipant Implementation
    
    public func reason(query: String, context: CognitiveContext) async throws -> ReasoningResult {
        await MainActor.run { currentPhase = .reasoning }
        
        logger.debug("Phase 1: Reasoning about query")
        
        // Generate initial reasoning trajectory
        let initialTrajectory = await reasoningEngine.generateInitialTrajectory(
            query: query,
            context: context,
            maxDepth: maxReasoningDepth
        )
        
        // REX-RAG: Generate alternative exploration trajectories if enabled
        var trajectories = [initialTrajectory]
        
        if context.explorationEnabled && initialTrajectory.likelihood < explorationThreshold {
            let explorationTrajectories = await reasoningEngine.generateExplorationTrajectories(
                from: initialTrajectory,
                context: context,
                maxAlternatives: 3
            )
            trajectories.append(contentsOf: explorationTrajectories)
        }
        
        // Select best trajectory (initially the original policy trajectory)
        let selectedTrajectory = trajectories.max { $0.likelihood < $1.likelihood } ?? initialTrajectory
        
        await MainActor.run {
            activeTrajectories = trajectories
        }
        
        let result = ReasoningResult(
            reasoning: selectedTrajectory.steps.map { $0.content }.joined(separator: " → "),
            confidence: selectedTrajectory.likelihood,
            trajectory: selectedTrajectory
        )
        
        logger.debug("Generated reasoning with confidence: \(result.confidence)")
        
        return result
    }
    
    public func probe(layers: [any CognitiveMemoryLayer]) async throws -> ProbeResult {
        await MainActor.run { currentPhase = .probing }
        
        logger.debug("Phase 2: Probing cognitive layers")
        
        let result = try await probeEngine.probeAllLayers(
            activeTrajectories: activeTrajectories,
            probeDepth: 2
        )
        
        logger.debug("Probe found \(result.veridicalHits.count + result.semanticHits.count + result.episodicHits.count) total hits")
        
        return result
    }
    
    public func retrieve(probeResult: ProbeResult) async throws -> RetrievalResult {
        await MainActor.run { currentPhase = .retrieving }
        
        logger.debug("Phase 3: Retrieving relevant memories")
        
        let result = try await retrievalEngine.retrieveFromProbeResult(
            probeResult: probeResult,
            maxNodes: 20
        )
        
        logger.debug("Retrieved \(result.retrievedNodes.count) nodes with total relevance: \(result.totalRelevanceScore)")
        
        return result
    }
    
    public func consolidate(reasoning: ReasoningResult, retrieval: RetrievalResult) async throws -> ConsolidationResult {
        await MainActor.run { currentPhase = .consolidating }
        
        logger.debug("Phase 4: Consolidating knowledge")
        
        // Perform memory fusion
        let fusionResult = try await fusionEngine.identifyAndCreateFusions(
            retrievedNodes: retrieval.retrievedNodes,
            reasoningTrajectory: reasoning.trajectory
        )
        
        // Consolidate knowledge
        let result = try await consolidationEngine.consolidateKnowledge(
            reasoning: reasoning,
            retrieval: retrieval,
            fusionResult: fusionResult
        )
        
        logger.debug("Consolidated knowledge with \(result.fusedConnections.count) new connections")
        
        return result
    }
    
    public func resolve(consolidation: ConsolidationResult, query: String) async throws -> CognitiveResponse {
        await MainActor.run { currentPhase = .resolving }
        
        logger.debug("Phase 5: Resolving final response")
        
        // REX-RAG: Policy correction if confidence is low
        var finalConsolidation = consolidation
        var finalTrajectory = activeTrajectories.first!
        
        if consolidation.consolidationConfidence < explorationThreshold {
            await MainActor.run { currentPhase = .exploring }
            
            let correctedResults = try await performPolicyCorrection(
                originalConsolidation: consolidation,
                query: query
            )
            
            if correctedResults.consolidationConfidence > consolidation.consolidationConfidence {
                finalConsolidation = correctedResults
                logger.debug("Applied policy correction, improved confidence from \(consolidation.consolidationConfidence) to \(correctedResults.consolidationConfidence)")
            }
        }
        
        // Generate final response
        let response = await reasoningEngine.generateFinalResponse(
            query: query,
            consolidation: finalConsolidation,
            trajectory: finalTrajectory
        )
        
        let metrics = CognitiveMetrics(
            processingTimeMs: 0, // Will be set by caller
            memoryHits: 0,
            layersEngaged: 0,
            fusionOperations: finalConsolidation.fusedConnections.count,
            confidenceScore: finalConsolidation.consolidationConfidence,
            explorationPaths: activeTrajectories.count
        )
        
        let cognitiveResponse = CognitiveResponse(
            response: response,
            reasoning: ReasoningResult(reasoning: "", confidence: finalConsolidation.consolidationConfidence, trajectory: finalTrajectory),
            memoryContext: RetrievalResult(retrievedNodes: [], retrievalContext: "", totalRelevanceScore: 0.0, layerDistribution: [:]),
            consolidation: finalConsolidation,
            confidence: finalConsolidation.consolidationConfidence,
            cognitiveMetrics: metrics
        )
        
        logger.debug("Generated final response with confidence: \(cognitiveResponse.confidence)")
        
        return cognitiveResponse
    }
    
    // MARK: - REX-RAG Policy Correction
    
    private func performPolicyCorrection(
        originalConsolidation: ConsolidationResult,
        query: String
    ) async throws -> ConsolidationResult {
        logger.debug("Performing REX-RAG policy correction")
        
        // Find alternative trajectories that weren't explored
        let unexploredTrajectories = activeTrajectories.filter { !$0.isExplored && !$0.originalPolicy }
        
        guard !unexploredTrajectories.isEmpty else {
            return originalConsolidation
        }
        
        // Evaluate alternative trajectories
        var bestConsolidation = originalConsolidation
        var bestConfidence = originalConsolidation.consolidationConfidence
        
        for trajectory in unexploredTrajectories.prefix(2) { // Limit exploration
            let alternativeReasoning = ReasoningResult(
                reasoning: trajectory.steps.map { $0.content }.joined(separator: " → "),
                confidence: trajectory.likelihood,
                trajectory: trajectory
            )
            
            // Re-probe with alternative trajectory
            let probeResult = try await probeEngine.probeWithTrajectory(trajectory)
            let retrievalResult = try await retrievalEngine.retrieveFromProbeResult(probeResult: probeResult, maxNodes: 15)
            
            // Consolidate alternative path
            let fusionResult = try await fusionEngine.identifyAndCreateFusions(
                retrievedNodes: retrievalResult.retrievedNodes,
                reasoningTrajectory: trajectory
            )
            
            let alternativeConsolidation = try await consolidationEngine.consolidateKnowledge(
                reasoning: alternativeReasoning,
                retrieval: retrievalResult,
                fusionResult: fusionResult
            )
            
            if alternativeConsolidation.consolidationConfidence > bestConfidence {
                bestConsolidation = alternativeConsolidation
                bestConfidence = alternativeConsolidation.consolidationConfidence
                
                logger.debug("Policy correction found better path with confidence: \(bestConfidence)")
            }
        }
        
        return bestConsolidation
    }
    
    // MARK: - Helper Methods
    
    private func createDefaultContext(for query: String) async -> CognitiveContext {
        let memoryState = await cognitiveSystem.getCurrentMemoryState()
        
        return CognitiveContext(
            userQuery: query,
            memoryState: memoryState,
            reasoningDepth: maxReasoningDepth,
            explorationEnabled: true
        )
    }
    
    /// Get current control loop status
    public func getControlLoopStatus() async -> ControlLoopStatus {
        return ControlLoopStatus(
            currentPhase: currentPhase,
            isProcessing: isProcessing,
            activeTrajectories: activeTrajectories.count,
            lastCycleMetrics: lastCycleMetrics
        )
    }
    
    /// Reset control loop state
    public func reset() async {
        await MainActor.run {
            currentPhase = .idle
            isProcessing = false
            activeTrajectories = []
            lastCycleMetrics = nil
        }
        
        logger.info("Cognitive control loop reset")
    }
}

// MARK: - Supporting Data Structures

/// Status information for the cognitive control loop
public struct ControlLoopStatus: Sendable {
    public let currentPhase: CognitiveControlLoop.ControlLoopPhase
    public let isProcessing: Bool
    public let activeTrajectories: Int
    public let lastCycleMetrics: CognitiveMetrics?
    public let timestamp: Date
    
    public init(
        currentPhase: CognitiveControlLoop.ControlLoopPhase,
        isProcessing: Bool,
        activeTrajectories: Int,
        lastCycleMetrics: CognitiveMetrics?
    ) {
        self.currentPhase = currentPhase
        self.isProcessing = isProcessing
        self.activeTrajectories = activeTrajectories
        self.lastCycleMetrics = lastCycleMetrics
        self.timestamp = Date()
    }
}

// MARK: - Extension to CognitiveMemorySystem

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CognitiveMemorySystem {
    internal func getCurrentMemoryState() async -> MemorySystemState {
        return MemorySystemState(
            shortTermCount: shortTermMemory?.workingSet.count ?? 0,
            longTermCount: semanticLayer.nodes.count,
            workingSetSize: workingMemory.count,
            episodicCount: episodicLayer.nodes.count,
            systemLoadFactor: systemMetrics.systemLoadFactor,
            lastConsolidation: lastConsolidation
        )
    }
}