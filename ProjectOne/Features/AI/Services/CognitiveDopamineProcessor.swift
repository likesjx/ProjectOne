//
//  CognitiveDopamineProcessor.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  Cognitive processing service for Dopamine Cognitive Design system
//

import Foundation
import Combine
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Cognitive Processing Service

/// Advanced cognitive processing using Apple Foundation Models
/// Integrates with the Dopamine Cognitive Design architecture
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@MainActor
public class CognitiveDopamineProcessor: ObservableObject {
    
    // MARK: - Dependencies
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "CognitiveDopamineProcessor")
    private let foundationProvider: AppleFoundationModelsProvider
    private let privacyAnalyzer: PrivacyAnalyzer
    private let cognitiveMemorySystem: CognitiveMemorySystem
    
    // MARK: - State
    
    @Published public var isProcessing: Bool = false
    @Published public var lastProcessingTime: Date?
    @Published public var processingMetrics: ProcessingMetrics = ProcessingMetrics()
    
    // MARK: - Configuration
    
    public struct ProcessorConfiguration: Sendable {
        let enableStructuredGeneration: Bool
        let enableToolCalling: Bool
        let maxProcessingTime: TimeInterval
        let privacyThreshold: Double
        let cognitiveLoadLimit: Double
        
        public static let `default` = ProcessorConfiguration(
            enableStructuredGeneration: true,
            enableToolCalling: true,
            maxProcessingTime: 30.0,
            privacyThreshold: 0.7,
            cognitiveLoadLimit: 0.8
        )
    }
    
    private let configuration: ProcessorConfiguration
    
    // MARK: - Initialization
    
    public init(foundationProvider: AppleFoundationModelsProvider,
                privacyAnalyzer: PrivacyAnalyzer,
                cognitiveMemorySystem: CognitiveMemorySystem,
                configuration: ProcessorConfiguration = .default) {
        self.foundationProvider = foundationProvider
        self.privacyAnalyzer = privacyAnalyzer
        self.cognitiveMemorySystem = cognitiveMemorySystem
        self.configuration = configuration
        
        logger.info("CognitiveDopamineProcessor initialized")
    }
    
    // MARK: - Cognitive Metadata Generation
    
    /// Generates AI-driven cognitive metadata for bubble-up items
    public func generateCognitiveMetadata(for item: BubbleUpItem, context: OrchestratorContext) async throws -> CognitiveMetadata {
        isProcessing = true
        defer { isProcessing = false }
        
        logger.info("Generating cognitive metadata for item: \(item.id)")
        
        let analysisPrompt = buildMetadataAnalysisPrompt(item: item, context: context)
        
        do {
            let response = try await foundationProvider.generateModelResponse(analysisPrompt)
            let metadata = try parseMetadataResponse(response, fallbackTaskType: item.taskType)
            
            logger.info("Generated cognitive metadata with confidence: \(metadata.aiConfidence)")
            return metadata
            
        } catch {
            logger.error("Failed to generate cognitive metadata: \(error.localizedDescription)")
            // Return default metadata with low confidence
            return CognitiveMetadata.defaultMetadata(for: item.taskType)
        }
    }
    
    /// Generates dynamic evaluation scripts for bubble-up items
    public func generateDynamicEvaluationScript(for item: BubbleUpItem, context: OrchestratorContext) async throws -> String? {
        logger.info("Generating dynamic evaluation script for item: \(item.id)")
        
        let scriptPrompt = buildScriptGenerationPrompt(item: item, context: context)
        
        do {
            let response = try await foundationProvider.generateModelResponse(scriptPrompt)
            let script = extractEvaluationScript(from: response)
            
            if let validScript = script {
                logger.info("Generated evaluation script: \(validScript.prefix(50))...")
                return validScript
            } else {
                logger.debug("No valid script generated from response")
                return nil
            }
            
        } catch {
            logger.error("Failed to generate evaluation script: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Updates cognitive metadata for existing bubble-up items based on new context
    public func updateCognitiveMetadataIfNeeded(_ item: BubbleUpItem, context: OrchestratorContext) async throws {
        let metadata = item.cognitiveMetadata
        let hoursSinceGeneration = Date().timeIntervalSince(metadata.generatedAt) / 3600
        
        // Update metadata if it's old or confidence is low
        if hoursSinceGeneration > 24 || metadata.aiConfidence < 0.7 {
            logger.debug("Updating cognitive metadata for item \(item.id) (age: \(hoursSinceGeneration)h, confidence: \(metadata.aiConfidence))")
            
            let newMetadata = try await generateCognitiveMetadata(for: item, context: context)
            await item.updateCognitiveMetadata(newMetadata)
        }
    }
    
    // MARK: - Bubble-Up Generation
    
    /// Generates contextual bubble-up items using Foundation Models
    public func generateBubbleUpItems(context: OrchestratorContext, 
                                     sourceMemories: [UUID] = []) async throws -> [CoachCardData] {
        
        guard foundationProvider.isAvailable else {
            throw CognitiveProcessingError.foundationModelsUnavailable
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let startTime = Date()
        
        do {
            // 1. Privacy screening
            let privacyContext = try await privacyAnalyzer.analyzeContext(context)
            guard privacyContext.overallSensitivity <= configuration.privacyThreshold else {
                logger.warning("Skipping processing due to high privacy sensitivity")
                return []
            }
            
            // 2. Generate structured analysis of current state
            let cognitiveAnalysis = try await generateCognitiveAnalysis(
                context: context,
                sourceMemories: sourceMemories
            )
            
            // 3. Generate actionable coach cards based on analysis
            let coachCards = try await generateCoachCards(
                analysis: cognitiveAnalysis,
                context: context
            )
            
            // 4. Record metrics
            let processingTime = Date().timeIntervalSince(startTime)
            updateProcessingMetrics(processingTime: processingTime, itemsGenerated: coachCards.count)
            
            logger.info("Generated \(coachCards.count) coach cards in \(processingTime)s")
            return coachCards
            
        } catch {
            logger.error("Error generating bubble-up items: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Idea Node Enhancement
    
    /// Enhances idea nodes with semantic connections and insights
    public func enhanceIdeaNode(_ ideaNode: IdeaNode, 
                               relatedNodes: [IdeaNode] = []) async throws -> IdeaNodeEnhancement {
        
        guard foundationProvider.isAvailable else {
            throw CognitiveProcessingError.foundationModelsUnavailable
        }
        
        // Privacy check
        let contentSensitivity = await privacyAnalyzer.analyzeSensitivity(ideaNode.title + " " + (ideaNode.description ?? ""))
        guard contentSensitivity <= configuration.privacyThreshold else {
            return IdeaNodeEnhancement(enhancedConnections: [], insights: [], suggestedTags: [])
        }
        
        // Generate enhancement
        let enhancement = try await generateIdeaEnhancement(
            node: ideaNode,
            relatedNodes: relatedNodes
        )
        
        return enhancement
    }
    
    // MARK: - Memory Synthesis
    
    /// Synthesizes insights from memory consolidation using Foundation Models
    public func synthesizeMemoryInsights(memoryNodes: [UUID], 
                                        context: OrchestratorContext) async throws -> [MemoryInsight] {
        
        guard foundationProvider.isAvailable else {
            throw CognitiveProcessingError.foundationModelsUnavailable
        }
        
        // Retrieve memory content
        let memoryContent = try await retrieveMemoryContent(nodeIDs: memoryNodes)
        
        // Privacy filtering
        let filteredContent = try await privacyAnalyzer.filterMemoryContent(memoryContent)
        
        // Generate insights
        let insights = try await generateMemoryInsights(
            content: filteredContent,
            context: context
        )
        
        return insights
    }
    
    // MARK: - Foundation Models Integration
    
    /// Generates structured cognitive analysis using Foundation Models
    private func generateCognitiveAnalysis(context: OrchestratorContext,
                                         sourceMemories: [UUID]) async throws -> CognitiveAnalysis {
        
        let prompt = buildCognitiveAnalysisPrompt(context: context, sourceMemories: sourceMemories)
        
        // Use structured generation for reliable output
        if configuration.enableStructuredGeneration {
            return try await foundationProvider.generateStructured(
                prompt: prompt,
                outputType: CognitiveAnalysis.self
            )
        } else {
            // Fallback to text generation and parsing
            let response = try await foundationProvider.generateText(prompt: prompt)
            return try parseCognitiveAnalysis(response)
        }
    }
    
    /// Generates coach cards from cognitive analysis
    private func generateCoachCards(analysis: CognitiveAnalysis,
                                   context: OrchestratorContext) async throws -> [CoachCardData] {
        
        var coachCards: [CoachCardData] = []
        
        // Generate action cards from actionable insights
        for insight in analysis.actionableInsights {
            let card = CoachCardData(
                type: .action,
                title: insight.title,
                content: insight.description,
                priority: insight.priority,
                cognitiveLoad: insight.estimatedCognitiveLoad,
                estimatedDuration: insight.estimatedDuration,
                optimalWindows: insight.optimalWindows,
                primaryAction: CoachCardAction(
                    title: insight.suggestedAction,
                    actionType: .complete
                )
            )
            coachCards.append(card)
        }
        
        // Generate insight cards from patterns
        for pattern in analysis.identifiedPatterns {
            let card = CoachCardData(
                type: .insight,
                title: "Pattern: \(pattern.name)",
                content: pattern.description,
                priority: .medium,
                cognitiveLoad: 0.4,
                optimalWindows: [.eveningCreative, .morningPeak],
                primaryAction: CoachCardAction(
                    title: "Explore Pattern",
                    actionType: .navigate,
                    navigationTarget: "patterns/\(pattern.id)"
                )
            )
            coachCards.append(card)
        }
        
        // Generate reminder cards from time-sensitive items
        for reminder in analysis.timeSensitiveReminders {
            let card = CoachCardData(
                type: .reminder,
                title: reminder.title,
                content: reminder.description,
                priority: reminder.urgency > 0.7 ? .high : .medium,
                cognitiveLoad: 0.3,
                estimatedDuration: 300, // 5 minutes
                primaryAction: CoachCardAction(
                    title: "Handle Now",
                    actionType: .complete
                ),
                secondaryActions: [
                    CoachCardAction(title: "Snooze", actionType: .snooze),
                    CoachCardAction(title: "Schedule", actionType: .schedule)
                ]
            )
            coachCards.append(card)
        }
        
        return coachCards
    }
    
    /// Generates idea node enhancements
    private func generateIdeaEnhancement(node: IdeaNode,
                                        relatedNodes: [IdeaNode]) async throws -> IdeaNodeEnhancement {
        
        let prompt = buildIdeaEnhancementPrompt(node: node, relatedNodes: relatedNodes)
        
        if configuration.enableStructuredGeneration {
            return try await foundationProvider.generateStructured(
                prompt: prompt,
                outputType: IdeaNodeEnhancement.self
            )
        } else {
            let response = try await foundationProvider.generateText(prompt: prompt)
            return try parseIdeaEnhancement(response)
        }
    }
    
    /// Generates memory insights from consolidated content
    private func generateMemoryInsights(content: [MemoryContent],
                                       context: OrchestratorContext) async throws -> [MemoryInsight] {
        
        let prompt = buildMemoryInsightsPrompt(content: content, context: context)
        
        if configuration.enableStructuredGeneration {
            return try await foundationProvider.generateStructured(
                prompt: prompt,
                outputType: [MemoryInsight].self
            )
        } else {
            let response = try await foundationProvider.generateText(prompt: prompt)
            return try parseMemoryInsights(response)
        }
    }
    
    // MARK: - Prompt Building
    
    private func buildCognitiveAnalysisPrompt(context: OrchestratorContext,
                                            sourceMemories: [UUID]) -> String {
        return """
        Analyze the current cognitive state and provide actionable insights.
        
        Current Context:
        - Dopamine Window: \(context.currentWindow.rawValue)
        - Cognitive Capacity: \(context.cognitiveCapacity)
        - Current Focus: \(context.currentFocus ?? "None")
        - Recently Completed: \(context.recentlyCompleted.joined(separator: ", "))
        
        Provide structured analysis including:
        1. Actionable insights that align with current capacity
        2. Identified patterns in recent activity
        3. Time-sensitive reminders
        4. Optimal next actions for this dopamine window
        
        Focus on ADHD-friendly recommendations with clear, specific actions.
        """
    }
    
    private func buildIdeaEnhancementPrompt(node: IdeaNode, relatedNodes: [IdeaNode]) -> String {
        let relatedTitles = relatedNodes.map(\.title).joined(separator: ", ")
        
        return """
        Enhance the idea node with semantic connections and insights.
        
        Main Idea: "\(node.title)"
        Description: \(node.description ?? "None")
        Current Tags: \(node.tags.joined(separator: ", "))
        
        Related Ideas: \(relatedTitles)
        
        Provide:
        1. Enhanced semantic connections to related ideas
        2. Key insights about this idea's relationships
        3. Suggested additional tags for better categorization
        4. Potential connections to concepts not yet explored
        
        Keep suggestions concise and actionable.
        """
    }
    
    private func buildMemoryInsightsPrompt(content: [MemoryContent],
                                         context: OrchestratorContext) -> String {
        let contentSummary = content.map { "\($0.type): \($0.summary)" }.joined(separator: "\n")
        
        return """
        Synthesize insights from consolidated memory content.
        
        Memory Content:
        \(contentSummary)
        
        Current Context: \(context.currentWindow.rawValue) window
        
        Generate insights that:
        1. Connect patterns across different memory types
        2. Identify actionable opportunities
        3. Suggest areas for deeper exploration
        4. Highlight potential knowledge gaps
        
        Focus on practical insights that can guide future actions.
        """
    }
    
    // MARK: - Helper Methods
    
    private func retrieveMemoryContent(nodeIDs: [UUID]) async throws -> [MemoryContent] {
        // TODO: Implement memory content retrieval from CognitiveMemorySystem
        return []
    }
    
    private func updateProcessingMetrics(processingTime: TimeInterval, itemsGenerated: Int) {
        processingMetrics.totalProcessingTime += processingTime
        processingMetrics.totalItemsGenerated += itemsGenerated
        processingMetrics.averageProcessingTime = processingMetrics.totalProcessingTime / Double(processingMetrics.totalProcessingRuns + 1)
        processingMetrics.totalProcessingRuns += 1
        lastProcessingTime = Date()
    }
    
    // MARK: - Parsing Methods (for fallback when structured generation unavailable)
    
    private func parseCognitiveAnalysis(_ response: String) throws -> CognitiveAnalysis {
        // TODO: Implement robust parsing logic
        return CognitiveAnalysis(
            actionableInsights: [],
            identifiedPatterns: [],
            timeSensitiveReminders: [],
            recommendedActions: []
        )
    }
    
    private func parseIdeaEnhancement(_ response: String) throws -> IdeaNodeEnhancement {
        // TODO: Implement robust parsing logic
        return IdeaNodeEnhancement(
            enhancedConnections: [],
            insights: [],
            suggestedTags: []
        )
    }
    
    private func parseMemoryInsights(_ response: String) throws -> [MemoryInsight] {
        // TODO: Implement robust parsing logic
        return []
    }
}

// MARK: - Foundation Models Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension AppleFoundationModelsProvider {
    
    /// Generates structured output using Foundation Models guided generation
    func generateStructured<T: Codable>(prompt: String, outputType: T.Type) async throws -> T {
        // TODO: Implement with actual Foundation Models API
        // This is a placeholder implementation
        throw CognitiveProcessingError.structuredGenerationUnavailable
    }
    
    /// Generates text response using Foundation Models
    func generateText(prompt: String) async throws -> String {
        // TODO: Implement with actual Foundation Models API
        // This is a placeholder implementation
        return "Generated response placeholder"
    }
}

// MARK: - Data Structures

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveAnalysis: Codable, Sendable {
    let actionableInsights: [ActionableInsight]
    let identifiedPatterns: [CognitivePattern]
    let timeSensitiveReminders: [TimeSensitiveReminder]
    let recommendedActions: [RecommendedAction]
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct ActionableInsight: Codable, Sendable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let priority: IdeaPriority
    let estimatedCognitiveLoad: Double
    let estimatedDuration: TimeInterval?
    let optimalWindows: [DopamineWindow]
    let suggestedAction: String
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitivePattern: Codable, Sendable {
    let id: UUID = UUID()
    let name: String
    let description: String
    let confidence: Double
    let frequency: String
    let recommendations: [String]
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct TimeSensitiveReminder: Codable, Sendable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let urgency: Double
    let dueDate: Date?
    let category: String
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct RecommendedAction: Codable, Sendable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let benefit: String
    let effort: String
    let timeframe: String
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct IdeaNodeEnhancement: Codable, Sendable {
    let enhancedConnections: [SemanticConnection]
    let insights: [String]
    let suggestedTags: [String]
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct SemanticConnection: Codable, Sendable {
    let targetNodeId: UUID
    let relationshipType: String
    let strength: Double
    let description: String
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct MemoryContent: Codable, Sendable {
    let id: UUID
    let type: String
    let summary: String
    let timestamp: Date
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct MemoryInsight: Codable, Sendable {
    let id: UUID = UUID()
    let title: String
    let description: String
    let confidence: Double
    let relatedMemoryIds: [UUID]
    let actionable: Bool
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct ProcessingMetrics: Codable, Sendable {
    var totalProcessingTime: TimeInterval = 0
    var totalItemsGenerated: Int = 0
    var totalProcessingRuns: Int = 0
    var averageProcessingTime: TimeInterval = 0
}

// MARK: - Errors

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum CognitiveProcessingError: Error, LocalizedError {
    case foundationModelsUnavailable
    case structuredGenerationUnavailable
    case privacyThresholdExceeded
    case processingTimeout
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .foundationModelsUnavailable:
            return "Apple Foundation Models not available"
        case .structuredGenerationUnavailable:
            return "Structured generation not available"
        case .privacyThresholdExceeded:
            return "Privacy threshold exceeded"
        case .processingTimeout:
            return "Processing timeout"
        case .invalidResponse:
            return "Invalid response from model"
        }
    }
}

// MARK: - Cognitive Metadata Processing Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CognitiveDopamineProcessor {
    
    /// Builds AI prompt for analyzing cognitive metadata of bubble-up items
    private func buildMetadataAnalysisPrompt(item: BubbleUpItem, context: OrchestratorContext) -> String {
        return """
        Analyze this bubble-up item and generate cognitive metadata for importance evaluation:
        
        ITEM DETAILS:
        - Content: "\(item.content)"
        - Tags: \(item.tags.joined(separator: ", "))
        - Task Type: \(item.taskType.rawValue)
        - Surface Count: \(item.surfaceCount)
        
        CURRENT CONTEXT:
        - Dopamine Window: \(context.currentWindow.rawValue)
        - Cognitive Capacity: \(String(format: "%.2f", context.cognitiveCapacity))
        - Current Focus: \(context.currentFocus ?? "none")
        - Hour of Day: \(Calendar.current.component(.hour, from: Date()))
        
        Generate a JSON response with the following structure:
        {
            "emotionalRelevance": 0.0-1.0,
            "requiredCognitiveLoad": 0.0-1.0,
            "attentionFactors": ["novelty", "urgency", "relevance", "curiosity", "completion", "social", "achievement"],
            "dopamineTriggers": ["immediateReward", "progressVisual", "socialConnection", "noveltyStimulus", "completionSatisfaction", "challengeEngagement"],
            "timeSensitive": {
                "urgencyPattern": "linear|exponential|deadlineBased|periodic",
                "timeDecayFactor": 0.0-1.0,
                "criticalWindows": []
            },
            "locationRelevant": {
                "isLocationBased": true/false,
                "relevantTypes": ["home", "office", "store", "gym"],
                "locationMultiplier": 1.0-2.0
            },
            "memoryConnection": 0.0-1.0,
            "aiConfidence": 0.0-1.0
        }
        
        Focus on ADHD-friendly factors and dopamine optimization. Consider time-sensitivity and location-based urgency.
        """
    }
    
    /// Builds AI prompt for generating dynamic evaluation scripts
    private func buildScriptGenerationPrompt(item: BubbleUpItem, context: OrchestratorContext) -> String {
        return """
        Generate a dynamic evaluation script for this bubble-up item that calculates importance at runtime:
        
        ITEM: "\(item.content)" (Type: \(item.taskType.rawValue))
        
        Available variables:
        - $baseScore (0.0-1.0): Base priority score
        - $cognitiveCapacity (0.0-1.0): Current cognitive capacity
        - $hourOfDay (0-23): Current hour
        - $surfaceCount (int): How many times shown
        - $daysSinceCreated (double): Days since creation
        - $emotionalRelevance (0.0-1.0): Emotional connection strength
        - $requiredLoad (0.0-1.0): Cognitive load required
        
        Generate a mathematical expression that evaluates importance. Examples:
        - "$baseScore * (1.0 + 0.2 * (1.0 - abs($requiredLoad - $cognitiveCapacity)))"
        - "$baseScore * (1.5 - $surfaceCount * 0.1) * ($hourOfDay >= 9 && $hourOfDay <= 17 ? 1.2 : 1.0)"
        
        Return ONLY the expression, no explanation. Make it ADHD-friendly with time/location awareness.
        """
    }
    
    /// Parses AI response to extract cognitive metadata
    private func parseMetadataResponse(_ response: String, fallbackTaskType: BubbleUpTaskType) throws -> CognitiveMetadata {
        // Try to extract JSON from the response
        guard let jsonData = extractJSON(from: response) else {
            throw CognitiveProcessingError.invalidResponse
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            guard let data = json else {
                throw CognitiveProcessingError.invalidResponse
            }
            
            // Parse individual fields with fallbacks
            let emotionalRelevance = data["emotionalRelevance"] as? Double ?? 0.5
            let requiredCognitiveLoad = data["requiredCognitiveLoad"] as? Double ?? fallbackTaskType.defaultCognitiveLoad
            
            // Parse attention factors
            let attentionFactorStrings = data["attentionFactors"] as? [String] ?? []
            let attentionFactors = Set(attentionFactorStrings.compactMap { AttentionFactor(rawValue: $0) })
            
            // Parse dopamine triggers
            let triggerStrings = data["dopamineTriggers"] as? [String] ?? []
            let dopamineTriggers = triggerStrings.compactMap { triggerString in
                DopamineTrigger.allCases.first { String(describing: $0) == triggerString }
            }
            
            // Parse time sensitivity
            let timeSensitiveData = data["timeSensitive"] as? [String: Any] ?? [:]
            let urgencyPatternString = timeSensitiveData["urgencyPattern"] as? String ?? "linear"
            let urgencyPattern = UrgencyPattern(rawValue: urgencyPatternString) ?? .linear
            let timeDecayFactor = timeSensitiveData["timeDecayFactor"] as? Double ?? 0.1
            
            let timeSensitivity = TimeSensitivity(
                urgencyPattern: urgencyPattern,
                criticalTimeWindows: [], // Simplified for now
                timeDecayFactor: timeDecayFactor,
                recurringPatterns: []
            )
            
            // Parse location relevance
            let locationData = data["locationRelevant"] as? [String: Any] ?? [:]
            let isLocationBased = locationData["isLocationBased"] as? Bool ?? false
            let locationMultiplier = locationData["locationMultiplier"] as? Double ?? 1.0
            
            let locationRelevance = isLocationBased 
                ? LocationRelevance(
                    relevantLocations: [], // Simplified for now
                    activationRadius: 100.0,
                    locationMultiplier: locationMultiplier,
                    locationTimeSensitive: true
                )
                : LocationRelevance.notLocationBased
            
            let memoryConnection = data["memoryConnection"] as? Double ?? 0.3
            let aiConfidence = data["aiConfidence"] as? Double ?? 0.7
            
            return CognitiveMetadata(
                emotionalRelevance: emotionalRelevance,
                requiredCognitiveLoad: requiredCognitiveLoad,
                attentionCaptureFactors: attentionFactors.isEmpty ? fallbackTaskType.defaultAttentionFactors : attentionFactors,
                dopamineTriggers: dopamineTriggers.isEmpty ? fallbackTaskType.defaultDopamineTriggers : dopamineTriggers,
                timeSensitivity: timeSensitivity,
                locationRelevance: locationRelevance,
                memoryConnectionStrength: memoryConnection,
                aiConfidence: aiConfidence
            )
            
        } catch {
            logger.error("Failed to parse metadata JSON: \(error.localizedDescription)")
            throw CognitiveProcessingError.invalidResponse
        }
    }
    
    /// Extracts evaluation script from AI response
    private func extractEvaluationScript(from response: String) -> String? {
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
        
        // Validate that it looks like a mathematical expression
        let allowedCharacters = CharacterSet(charactersIn: "0123456789+-*/().abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$& <>!=")
        
        if cleaned.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            logger.warning("Invalid characters in evaluation script, rejecting")
            return nil
        }
        
        // Basic safety checks
        if cleaned.contains("import") || cleaned.contains("eval") || cleaned.contains("exec") {
            logger.warning("Potentially unsafe script detected, rejecting")
            return nil
        }
        
        return cleaned.isEmpty ? nil : cleaned
    }
    
    /// Extracts JSON from AI response text
    private func extractJSON(from response: String) -> Data? {
        // Look for JSON block markers
        if let jsonStart = response.range(of: "{"),
           let jsonEnd = response.range(of: "}", options: .backwards, range: jsonStart.upperBound..<response.endIndex) {
            let jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
            return jsonString.data(using: .utf8)
        }
        
        // Try the entire response as JSON
        return response.data(using: .utf8)
    }
}

// MARK: - DopamineTrigger Extensions for Processing

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension DopamineTrigger: CaseIterable {
    public static var allCases: [DopamineTrigger] {
        return [.immediateReward, .progressVisual, .socialConnection, .noveltyStimulus, .completionSatisfaction, .challengeEngagement]
    }
}