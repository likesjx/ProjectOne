//
//  BaseAIProvider.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/16/25.
//

import Foundation
import os.log
import SwiftData
import Combine

/// Status of model loading for real-time UI feedback
public enum ModelLoadingStatus: Equatable {
    case notStarted
    case preparing
    case downloading(progress: Double)
    case loading
    case ready
    case failed(String)
    case unavailable
    
    public var isLoading: Bool {
        switch self {
        case .preparing, .downloading, .loading:
            return true
        default:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .notStarted: return "Not Started"
        case .preparing: return "Preparing..."
        case .downloading(let progress): return "Downloading \(Int(progress * 100))%"
        case .loading: return "Loading Model..."
        case .ready: return "Ready"
        case .failed(let error): return "Failed: \(error)"
        case .unavailable: return "Unavailable"
        }
    }
}

/// Base class for AI model providers that eliminates code duplication
/// and provides common functionality for all AI providers
public class BaseAIProvider: AIModelProvider, ObservableObject {
    
    // MARK: - Common Infrastructure
    
    internal let logger: Logger
    @Published public var isModelLoaded = false
    @Published public var modelLoadingStatus: ModelLoadingStatus = .notStarted
    @Published public var loadingProgress: Double = 0.0
    @Published public var statusMessage: String = ""
    internal let processingQueue = DispatchQueue(label: "ai-provider", qos: .userInitiated)
    
    // MARK: - Abstract Properties (Override Required)
    
    public var identifier: String { fatalError("Must override identifier") }
    public var displayName: String { fatalError("Must override displayName") }
    public var isAvailable: Bool { fatalError("Must override isAvailable") }
    public var estimatedResponseTime: TimeInterval { fatalError("Must override estimatedResponseTime") }
    public var maxContextLength: Int { fatalError("Must override maxContextLength") }
    
    // MARK: - Common Properties
    
    public let supportsPersonalData = true
    public let isOnDevice = true
    
    // MARK: - Initialization
    
    public init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        logger.info("Initializing \(type(of: self)) provider")
    }
    
    // MARK: - AIModelProvider Implementation
    
    public func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse {
        guard isAvailable else {
            throw AIModelProviderError.providerUnavailable("\(displayName) not available")
        }
        
        // Build enriched prompt with memory context
        let enrichedPrompt = buildEnrichedPromptWithFallback(prompt: prompt, context: context)
        
        // Validate context size
        try validateContextSize(enrichedPrompt, maxLength: maxContextLength)
        
        // Generate response with timing
        let (response, processingTime) = try await measureProcessingTime {
            try await generateModelResponse(enrichedPrompt)
        }
        
        logger.info("Generated response in \(processingTime)s using \(self.displayName)")
        
        // Create standardized response
        return createResponse(
            content: response,
            confidence: getModelConfidence(),
            processingTime: processingTime,
            tokensUsed: estimateTokenCount(enrichedPrompt + response),
            context: context
        )
    }
    
    public func prepare() async throws {
        logger.info("Preparing \(self.displayName) provider")
        
        do {
            try await prepareModel()
            isModelLoaded = true
            logger.info("\(self.displayName) loaded successfully")
        } catch {
            logger.error("Failed to load \(self.displayName): \(error.localizedDescription)")
            isModelLoaded = false
            throw error
        }
    }
    
    public func cleanup() async {
        logger.info("Cleaning up \(self.displayName) provider")
        await cleanupModel()
        isModelLoaded = false
    }
    
    // MARK: - Abstract Methods (Override Required)
    
    /// Override to implement model-specific preparation
    internal func prepareModel() async throws {
        fatalError("Must override prepareModel()")
    }
    
    /// Override to implement model-specific generation
    internal func generateModelResponse(_ prompt: String) async throws -> String {
        fatalError("Must override generateModelResponse(_:)")
    }
    
    /// Override to implement model-specific cleanup
    internal func cleanupModel() async {
        // Default implementation - override if needed
    }
    
    /// Override to provide model-specific confidence scoring
    internal func getModelConfidence() -> Double {
        return 0.85 // Default confidence
    }
    
    // MARK: - Shared Implementation
    
    /// Measures processing time for any async operation
    public func measureProcessingTime<T>(_ operation: () async throws -> T) async throws -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let processingTime = Date().timeIntervalSince(startTime)
        return (result, processingTime)
    }
    
    /// Validates context size against provider limits
    internal func validateContextSize(_ prompt: String, maxLength: Int) throws {
        let estimatedTokens = estimateTokenCount(prompt)
        guard estimatedTokens <= maxLength else {
            throw AIModelProviderError.contextTooLarge(estimatedTokens, maxLength)
        }
    }
    
    /// Builds enriched prompt with PromptManager integration and fallback
    internal func buildEnrichedPromptWithFallback(prompt: String, context: MemoryContext) -> String {
        // Use SwiftData-based PromptManager for centralized prompt generation
        do {
            let templateName = selectOptimalTemplate(for: prompt, context: context)
            let arguments = buildArgumentsFromContext(context: context, userQuery: prompt)
            
            logger.debug("Using template: \(templateName) for query type")
            
            // Try to use SwiftData-based PromptManager
            if let promptManager = getPromptManager() {
                return promptManager.renderTemplate(named: templateName, with: arguments) ?? buildManualPrompt(prompt: prompt, context: context)
            } else {
                logger.warning("PromptManager not available, falling back to manual prompt")
                return buildManualPrompt(prompt: prompt, context: context)
            }
        } catch {
            logger.warning("Failed to use PromptManager, falling back to manual prompt: \(error.localizedDescription)")
            
            // Fallback to manual prompt construction
            return buildManualPrompt(prompt: prompt, context: context)
        }
    }
    
    /// Get the SwiftData-based PromptManager instance
    private func getPromptManager() -> PromptManager? {
        // This will be injected or accessed through the environment
        // For now, return nil to use fallback
        return nil
    }
    
    /// Build arguments dictionary from MemoryContext
    private func buildArgumentsFromContext(context: MemoryContext, userQuery: String) -> [String: Any] {
        var arguments: [String: Any] = [:]
        
        // Add user query
        arguments["user_query"] = userQuery
        
        // Add memory context
        if !context.longTermMemories.isEmpty {
            let ltmContent = context.longTermMemories.prefix(3)
                .map { "- [\($0.category.rawValue.capitalized)] \($0.content.prefix(100))" }
                .joined(separator: "\n")
            arguments["long_term_memories"] = ltmContent
        }
        
        if !context.shortTermMemories.isEmpty {
            let stmContent = context.shortTermMemories.prefix(5)
                .map { memory in
                    let timeAgo = formatTimeAgo(from: memory.timestamp)
                    return "- [\(timeAgo)] \(memory.content.prefix(80))"
                }
                .joined(separator: "\n")
            arguments["short_term_memories"] = stmContent
        }
        
        if !context.episodicMemories.isEmpty {
            let episodicContent = context.episodicMemories.prefix(3)
                .map { memory in
                    let timeAgo = formatTimeAgo(from: memory.timestamp)
                    return "- [\(timeAgo)] \(memory.eventDescription.prefix(100))"
                }
                .joined(separator: "\n")
            arguments["episodic_memories"] = episodicContent
        }
        
        if !context.entities.isEmpty {
            let entityContent = context.entities.prefix(5)
                .map { "- [\($0.type.rawValue.capitalized)] \($0.name): \($0.entityDescription ?? "No description")" }
                .joined(separator: "\n")
            arguments["entities"] = entityContent
        }
        
        if !context.relevantNotes.isEmpty {
            let notesContent = context.relevantNotes.prefix(3)
                .map { "- \($0.originalText.prefix(50))...: \($0.summary)" }
                .joined(separator: "\n")
            arguments["relevant_notes"] = notesContent
        }
        
        // Add conversation history
        let conversationMemories = context.shortTermMemories.filter { $0.contextTags.contains("conversation") }
        if !conversationMemories.isEmpty {
            let conversationContent = conversationMemories.prefix(3)
                .map { memory in
                    let timeAgo = formatTimeAgo(from: memory.timestamp)
                    return "- [\(timeAgo)] \(memory.content.prefix(60))"
                }
                .joined(separator: "\n")
            arguments["conversation_history"] = conversationContent
        }
        
        return arguments
    }
    
    /// Select optimal template based on query type and context
    private func selectOptimalTemplate(for query: String, context: MemoryContext) -> String {
        let lowercaseQuery = query.lowercased()
        
        // Privacy-sensitive queries
        if context.containsPersonalData && (lowercaseQuery.contains("personal") || lowercaseQuery.contains("private")) {
            return "Privacy-Sensitive Query"
        }
        
        // Entity-focused queries
        if lowercaseQuery.contains("who is") || lowercaseQuery.contains("what is") || 
           lowercaseQuery.contains("tell me about") || lowercaseQuery.contains("describe") {
            return "Entity-Focused Query"
        }
        
        // Experience/memory queries
        if lowercaseQuery.contains("remember") || lowercaseQuery.contains("recall") || 
           lowercaseQuery.contains("when did") || lowercaseQuery.contains("what happened") {
            return "Episodic Memory Retrieval"
        }
        
        // Fact-based queries
        if lowercaseQuery.contains("how") || lowercaseQuery.contains("why") || 
           lowercaseQuery.contains("explain") || lowercaseQuery.contains("definition") {
            return "Fact-Based Information"
        }
        
        // Complex synthesis queries
        if lowercaseQuery.contains("analyze") || lowercaseQuery.contains("compare") || 
           lowercaseQuery.contains("relationship") || lowercaseQuery.contains("connection") {
            return "Memory Synthesis"
        }
        
        // Conversation continuity (if there's recent conversation history)
        let hasConversationHistory = context.shortTermMemories.contains { $0.contextTags.contains("conversation") }
        if hasConversationHistory && (lowercaseQuery.contains("continue") || lowercaseQuery.contains("also") || 
                                      lowercaseQuery.contains("and") || lowercaseQuery.contains("but")) {
            return "Conversation Continuity"
        }
        
        // Default to general memory agent template
        return "General Memory Agent"
    }
    
    /// Manual prompt construction fallback
    internal func buildManualPrompt(prompt: String, context: MemoryContext) -> String {
        var enrichedPrompt = ""
        
        // Add system context with specific memory type guidance
        enrichedPrompt += """
        You are the Memory Agent for ProjectOne, an intelligent personal knowledge assistant. You have access to the user's personal memory and knowledge graph. 
        
        ## Response Guidelines:
        
        **Memory Type Handling:**
        - **Long-term Memories**: Use for established facts, learned information, and important historical context
        - **Recent Memories**: Prioritize for current conversations, immediate context, and ongoing situations
        - **Episodic Memories**: Reference for personal experiences, events, and temporal context
        - **Entities**: Use for identifying people, places, concepts, and their relationships
        - **Notes**: Draw from for detailed information, references, and structured knowledge
        
        **Response Strategy:**
        - If querying about recent conversations → Reference recent memories and conversation history
        - If asking about people/places → Use entity information and relationships
        - If requesting facts/information → Draw from long-term memories and notes
        - If asking about experiences → Reference episodic memories and timeline
        - If context is personal → Prioritize privacy and use personal knowledge appropriately
        - If no relevant context → Be honest about limitations and offer general assistance
        
        **Response Format:**
        - Be conversational and personalized based on memory context
        - Reference specific memories when relevant ("Based on our conversation yesterday...")
        - Connect related information across different memory types
        - Maintain continuity with previous interactions
        - Be concise but comprehensive
        
        """
        
        // Add memory context with type-specific formatting
        if !context.longTermMemories.isEmpty {
            enrichedPrompt += "## Long-term Knowledge:\n"
            for memory in context.longTermMemories.prefix(3) {
                let category = memory.category.rawValue.capitalized
                enrichedPrompt += "- [\(category)] \(memory.content.prefix(100))\n"
            }
            enrichedPrompt += "\n"
        }
        
        if !context.shortTermMemories.isEmpty {
            enrichedPrompt += "## Recent Context:\n"
            for memory in context.shortTermMemories.prefix(5) {
                let timeAgo = formatTimeAgo(from: memory.timestamp)
                let type = memory.memoryType.displayName
                enrichedPrompt += "- [\(timeAgo) - \(type)] \(memory.content.prefix(80))\n"
            }
            enrichedPrompt += "\n"
        }
        
        if !context.episodicMemories.isEmpty {
            enrichedPrompt += "## Personal Experiences:\n"
            for memory in context.episodicMemories.prefix(3) {
                let timeAgo = formatTimeAgo(from: memory.timestamp)
                enrichedPrompt += "- [\(timeAgo)] \(memory.eventDescription.prefix(100))\n"
            }
            enrichedPrompt += "\n"
        }
        
        if !context.entities.isEmpty {
            enrichedPrompt += "## Relevant People/Places/Concepts:\n"
            for entity in context.entities.prefix(5) {
                let type = entity.type.rawValue.capitalized
                enrichedPrompt += "- [\(type)] \(entity.name): \(entity.entityDescription ?? "No description")\n"
            }
            enrichedPrompt += "\n"
        }
        
        if !context.relevantNotes.isEmpty {
            enrichedPrompt += "## Reference Materials:\n"
            for note in context.relevantNotes.prefix(3) {
                enrichedPrompt += "- [Note] \(note.originalText.prefix(50))...: \(note.summary)\n"
            }
            enrichedPrompt += "\n"
        }
        
        // Add conversation continuity context
        let conversationMemories = context.shortTermMemories.filter { $0.contextTags.contains("conversation") }
        if !conversationMemories.isEmpty {
            enrichedPrompt += "## Conversation History:\n"
            for memory in conversationMemories.prefix(3) {
                let timeAgo = formatTimeAgo(from: memory.timestamp)
                enrichedPrompt += "- [\(timeAgo)] \(memory.content.prefix(60))...\n"
            }
            enrichedPrompt += "\n"
        }
        
        // Add the user's query with context awareness
        enrichedPrompt += "## Current Query:\n\(prompt)\n\n"
        enrichedPrompt += """
        ## Instructions:
        Respond naturally and helpfully using the provided context. Reference relevant memories when appropriate, maintain conversation continuity, and provide personalized assistance based on the available knowledge.
        
        ## Response:
        """
        
        return enrichedPrompt
    }
    
    /// Format time ago for memory context
    private func formatTimeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))min ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
    
    /// Creates standardized AI response object
    internal func createResponse(
        content: String,
        confidence: Double,
        processingTime: TimeInterval,
        tokensUsed: Int?,
        context: MemoryContext
    ) -> AIModelResponse {
        return AIModelResponse(
            content: content,
            confidence: confidence,
            processingTime: processingTime,
            modelUsed: displayName,
            tokensUsed: tokensUsed,
            isOnDevice: isOnDevice,
            containsPersonalData: context.containsPersonalData
        )
    }
    
    /// Estimates token count from text
    public func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        return text.count / 4
    }
}

// ModelSelectionCriteria is defined in AIModelProvider.swift - using that definition

// MARK: - Provider Health Status

/// Health status for monitoring provider performance
public struct ProviderHealthStatus {
    let isHealthy: Bool
    let lastSuccessfulResponse: Date?
    let consecutiveFailures: Int
    let averageResponseTime: TimeInterval
    let errorRate: Double
    
    public var shouldFallback: Bool {
        return !isHealthy || consecutiveFailures > 3 || errorRate > 0.5
    }
}