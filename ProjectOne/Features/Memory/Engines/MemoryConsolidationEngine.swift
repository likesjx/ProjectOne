//
//  MemoryConsolidationEngine.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Memory Consolidation Engine for ComoRAG control loop consolidation phase
//

import Foundation
import SwiftData
import os.log

// MARK: - Memory Consolidation Engine

/// Engine responsible for consolidating reasoning, retrieval, and fusion results
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public class MemoryConsolidationEngine: @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryConsolidationEngine")
    private let cognitiveSystem: CognitiveMemorySystem
    
    // Configuration
    private let consolidationThreshold: Double
    private let insightGenerationEnabled: Bool
    private let maxInsights: Int
    
    public init(
        cognitiveSystem: CognitiveMemorySystem,
        consolidationThreshold: Double = 0.6,
        insightGenerationEnabled: Bool = true,
        maxInsights: Int = 5
    ) {
        self.cognitiveSystem = cognitiveSystem
        self.consolidationThreshold = consolidationThreshold
        self.insightGenerationEnabled = insightGenerationEnabled
        self.maxInsights = maxInsights
    }
    
    // MARK: - Main Consolidation Method
    
    /// Consolidate reasoning, retrieval, and fusion results
    public func consolidateKnowledge(
        reasoning: ReasoningResult,
        retrieval: RetrievalResult,
        fusionResult: FusionEngineResult
    ) async throws -> ConsolidationResult {
        logger.debug("Consolidating knowledge from reasoning, retrieval, and fusion")
        
        let startTime = Date()
        
        // Step 1: Analyze retrieved memory content
        let memoryAnalysis = await analyzeRetrievedMemories(retrieval.retrievedNodes)
        
        // Step 2: Integrate reasoning with memory content
        let integratedKnowledge = await integrateReasoningWithMemory(
            reasoning: reasoning,
            memoryAnalysis: memoryAnalysis,
            retrievalContext: retrieval.retrievalContext
        )
        
        // Step 3: Process fusion connections
        let connectionAnalysis = await processFusionConnections(fusionResult)
        
        // Step 4: Generate insights if enabled
        var insights: [String] = []
        if insightGenerationEnabled {
            insights = await generateInsights(
                integratedKnowledge: integratedKnowledge,
                memoryAnalysis: memoryAnalysis,
                fusionConnections: connectionAnalysis
            )
        }
        
        // Step 5: Calculate consolidation confidence
        let confidence = await calculateConsolidationConfidence(
            reasoning: reasoning,
            retrieval: retrieval,
            fusionQuality: fusionResult.qualityScore,
            insightCount: insights.count
        )
        
        // Step 6: Strengthen memory connections
        let strengthenedConnections = await strengthenMemoryConnections(
            retrievedNodes: retrieval.retrievedNodes,
            fusionResult: fusionResult
        )
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let result = ConsolidationResult(
            consolidatedKnowledge: integratedKnowledge,
            fusedConnections: fusionResult.newConnections,
            strengthenedConnections: strengthenedConnections,
            consolidationConfidence: confidence,
            newInsights: insights
        )
        
        logger.info("Knowledge consolidation completed in \(processingTime)s with confidence: \(confidence)")
        
        return result
    }
    
    // MARK: - Memory Analysis
    
    private func analyzeRetrievedMemories(_ nodes: [any CognitiveMemoryNode]) async -> MemoryAnalysis {
        logger.debug("Analyzing \(nodes.count) retrieved memory nodes")
        
        var layerCounts: [CognitiveLayerType: Int] = [:]
        var contentThemes: [String] = []
        var confidenceSum = 0.0
        var importanceSum = 0.0
        var totalStrength = 0.0
        
        var veridicalFacts: [String] = []
        var semanticConcepts: [String] = []
        var episodicExperiences: [String] = []
        var fusionInsights: [String] = []
        
        for node in nodes {
            // Count by layer type
            let layerType = getNodeLayerType(node)
            layerCounts[layerType, default: 0] += 1
            
            // Extract content by type
            switch node.nodeType {
            case .fact:
                veridicalFacts.append(node.content)
            case .concept:
                semanticConcepts.append(node.content)
            case .episode:
                episodicExperiences.append(node.content)
            case .fusion:
                fusionInsights.append(node.content)
            default:
                contentThemes.append(node.content)
            }
            
            // Aggregate metrics
            importanceSum += node.importance
            
            if let baseCognitiveNode = node as? BaseCognitiveNode {
                totalStrength += baseCognitiveNode.strengthScore
            }
            
            // Extract confidence if available
            if let semanticNode = node as? SemanticNode {
                confidenceSum += semanticNode.confidence
            } else if let veridicalNode = node as? VeridicalNode {
                confidenceSum += veridicalNode.verificationStatus == .verified ? 1.0 : 0.5
            } else {
                confidenceSum += 0.7 // Default confidence
            }
        }
        
        let averageConfidence = nodes.isEmpty ? 0.0 : confidenceSum / Double(nodes.count)
        let averageImportance = nodes.isEmpty ? 0.0 : importanceSum / Double(nodes.count)
        let averageStrength = nodes.isEmpty ? 0.0 : totalStrength / Double(nodes.count)
        
        let analysis = MemoryAnalysis(
            nodeCount: nodes.count,
            layerDistribution: layerCounts,
            averageConfidence: averageConfidence,
            averageImportance: averageImportance,
            averageStrength: averageStrength,
            veridicalFacts: veridicalFacts,
            semanticConcepts: semanticConcepts,
            episodicExperiences: episodicExperiences,
            fusionInsights: fusionInsights
        )
        
        logger.debug("Memory analysis: \(analysis.nodeCount) nodes, avg confidence: \(averageConfidence)")
        
        return analysis
    }
    
    // MARK: - Knowledge Integration
    
    private func integrateReasoningWithMemory(
        reasoning: ReasoningResult,
        memoryAnalysis: MemoryAnalysis,
        retrievalContext: String
    ) async -> String {
        logger.debug("Integrating reasoning with memory content")
        
        var integratedComponents: [String] = []
        
        // Start with reasoning trajectory
        integratedComponents.append("Reasoning: \(reasoning.reasoning)")
        
        // Add memory-based evidence
        if !memoryAnalysis.veridicalFacts.isEmpty {
            let factsSection = "Supporting Facts: " + memoryAnalysis.veridicalFacts.prefix(3).joined(separator: "; ")
            integratedComponents.append(factsSection)
        }
        
        // Add conceptual context
        if !memoryAnalysis.semanticConcepts.isEmpty {
            let conceptsSection = "Related Concepts: " + memoryAnalysis.semanticConcepts.prefix(3).joined(separator: "; ")
            integratedComponents.append(conceptsSection)
        }
        
        // Add experiential context
        if !memoryAnalysis.episodicExperiences.isEmpty {
            let experiencesSection = "Relevant Experiences: " + memoryAnalysis.episodicExperiences.prefix(2).joined(separator: "; ")
            integratedComponents.append(experiencesSection)
        }
        
        // Add fusion insights
        if !memoryAnalysis.fusionInsights.isEmpty {
            let fusionSection = "Cross-layer Insights: " + memoryAnalysis.fusionInsights.prefix(2).joined(separator: "; ")
            integratedComponents.append(fusionSection)
        }
        
        // Add confidence assessment
        let confidenceSection = "Memory Confidence: \(String(format: "%.1f", memoryAnalysis.averageConfidence * 100))%"
        integratedComponents.append(confidenceSection)
        
        return integratedComponents.joined(separator: "\n\n")
    }
    
    // MARK: - Fusion Processing
    
    private func processFusionConnections(_ fusionResult: FusionEngineResult) async -> ConnectionAnalysis {
        logger.debug("Processing \(fusionResult.newConnections.count) fusion connections")
        
        var strongConnections: [String] = []
        var weakConnections: [String] = []
        var crossLayerConnections: [String] = []
        
        for connectionId in fusionResult.newConnections {
            if let fusion = cognitiveSystem.fusionNodes.first(where: { $0.id.uuidString == connectionId }) {
                if fusion.coherenceScore > 0.7 {
                    strongConnections.append(connectionId)
                } else {
                    weakConnections.append(connectionId)
                }
                
                if fusion.fusedLayers.count > 1 {
                    crossLayerConnections.append(connectionId)
                }
            }
        }
        
        return ConnectionAnalysis(
            totalConnections: fusionResult.newConnections.count,
            strongConnections: strongConnections,
            weakConnections: weakConnections,
            crossLayerConnections: crossLayerConnections,
            averageQuality: fusionResult.qualityScore
        )
    }
    
    // MARK: - Insight Generation
    
    private func generateInsights(
        integratedKnowledge: String,
        memoryAnalysis: MemoryAnalysis,
        fusionConnections: ConnectionAnalysis
    ) async -> [String] {
        logger.debug("Generating insights from consolidated knowledge")
        
        var insights: [String] = []
        
        // Pattern-based insights
        if memoryAnalysis.layerDistribution.count >= 3 {
            insights.append("Multi-layer pattern identified across veridical, semantic, and episodic memories")
        }
        
        // Confidence-based insights
        if memoryAnalysis.averageConfidence > 0.8 {
            insights.append("High confidence knowledge base supports strong conclusions")
        } else if memoryAnalysis.averageConfidence < 0.5 {
            insights.append("Low confidence memories suggest need for additional verification")
        }
        
        // Connection-based insights
        if fusionConnections.crossLayerConnections.count > 2 {
            insights.append("Strong cross-layer connections indicate integrated understanding")
        }
        
        // Content-based insights
        if memoryAnalysis.veridicalFacts.count > memoryAnalysis.semanticConcepts.count * 2 {
            insights.append("Fact-heavy recall pattern suggests concrete thinking mode")
        } else if memoryAnalysis.semanticConcepts.count > memoryAnalysis.veridicalFacts.count * 2 {
            insights.append("Concept-heavy recall pattern suggests abstract thinking mode")
        }
        
        // Experience-based insights
        if !memoryAnalysis.episodicExperiences.isEmpty {
            insights.append("Personal experiences provide contextual grounding for abstract concepts")
        }
        
        let finalInsights = Array(insights.prefix(maxInsights))
        
        logger.debug("Generated \(finalInsights.count) insights")
        
        return finalInsights
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateConsolidationConfidence(
        reasoning: ReasoningResult,
        retrieval: RetrievalResult,
        fusionQuality: Double,
        insightCount: Int
    ) async -> Double {
        var confidence = 0.0
        
        // Reasoning contribution (30%)
        confidence += reasoning.confidence * 0.3
        
        // Retrieval contribution (40%)
        let retrievalConfidence = min(1.0, retrieval.totalRelevanceScore / Double(retrieval.retrievedNodes.count))
        confidence += retrievalConfidence * 0.4
        
        // Fusion quality contribution (20%)
        confidence += fusionQuality * 0.2
        
        // Insight generation bonus (10%)
        let insightBonus = min(0.1, Double(insightCount) * 0.02)
        confidence += insightBonus
        
        // Layer diversity bonus
        let layerCount = retrieval.layerDistribution.keys.count
        let diversityBonus = min(0.1, Double(layerCount) * 0.025)
        confidence += diversityBonus
        
        let finalConfidence = min(1.0, confidence)
        
        logger.debug("Calculated consolidation confidence: \(finalConfidence)")
        
        return finalConfidence
    }
    
    // MARK: - Connection Strengthening
    
    private func strengthenMemoryConnections(
        retrievedNodes: [any CognitiveMemoryNode],
        fusionResult: FusionEngineResult
    ) async -> [String] {
        logger.debug("Strengthening memory connections")
        
        var strengthenedConnections: [String] = []
        
        // Strengthen connections between retrieved nodes
        for i in 0..<retrievedNodes.count {
            for j in (i+1)..<retrievedNodes.count {
                let node1 = retrievedNodes[i]
                let node2 = retrievedNodes[j]
                
                let similarity = calculateContentSimilarity(node1.content, node2.content)
                if similarity > 0.5 {
                    await node1.addConnection(to: node2.id.uuidString)
                    await node2.addConnection(to: node1.id.uuidString)
                    strengthenedConnections.append("\(node1.id.uuidString)-\(node2.id.uuidString)")
                }
            }
        }
        
        // Update consolidation scores for nodes involved in fusion
        for connectionId in fusionResult.newConnections {
            if let fusion = cognitiveSystem.fusionNodes.first(where: { $0.id.uuidString == connectionId }) {
                for sourceNodeId in fusion.sourceNodes {
                    if let uuid = UUID(uuidString: sourceNodeId) {
                        // Find and update source nodes
                        if let veridicalNode = cognitiveSystem.veridicalLayer.nodes.first(where: { $0.id == uuid }) {
                            veridicalNode.consolidationScore = min(1.0, veridicalNode.consolidationScore + 0.1)
                        } else if let semanticNode = cognitiveSystem.semanticLayer.nodes.first(where: { $0.id == uuid }) {
                            semanticNode.consolidationScore = min(1.0, semanticNode.consolidationScore + 0.1)
                        } else if let episodicNode = cognitiveSystem.episodicLayer.nodes.first(where: { $0.id == uuid }) {
                            episodicNode.consolidationScore = min(1.0, episodicNode.consolidationScore + 0.1)
                        }
                    }
                }
            }
        }
        
        logger.debug("Strengthened \(strengthenedConnections.count) memory connections")
        
        return strengthenedConnections
    }
    
    // MARK: - Helper Methods
    
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
            return .semantic
        }
    }
    
    private func calculateContentSimilarity(_ content1: String, _ content2: String) -> Double {
        let words1 = Set(content1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(content2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
}

// MARK: - Supporting Types

private struct MemoryAnalysis {
    let nodeCount: Int
    let layerDistribution: [CognitiveLayerType: Int]
    let averageConfidence: Double
    let averageImportance: Double
    let averageStrength: Double
    let veridicalFacts: [String]
    let semanticConcepts: [String]
    let episodicExperiences: [String]
    let fusionInsights: [String]
}

private struct ConnectionAnalysis {
    let totalConnections: Int
    let strongConnections: [String]
    let weakConnections: [String]
    let crossLayerConnections: [String]
    let averageQuality: Double
}

// Forward declaration for FusionEngineResult - will be defined in MemoryFusionEngine
public struct FusionEngineResult {
    public let newConnections: [String]
    public let qualityScore: Double
    public let fusionCount: Int
    
    public init(newConnections: [String], qualityScore: Double, fusionCount: Int) {
        self.newConnections = newConnections
        self.qualityScore = qualityScore
        self.fusionCount = fusionCount
    }
}