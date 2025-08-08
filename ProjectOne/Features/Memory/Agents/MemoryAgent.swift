//
//  MemoryAgent.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/15/25.
//

import Foundation
import SwiftData
import os.log
import Combine

/// Memory Agent - Central intelligence with knowledge graph ownership and AI model routing
@MainActor
public class MemoryAgent: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryAgent")
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let retrievalEngine: MemoryRetrievalEngine
    private let knowledgeGraphService: KnowledgeGraphService
    private let aiModelProvider: MemoryAgentModelProvider
    private let promptManager: PromptManager
    private let promptResolver: MemoryPromptResolver
    private let cognitiveEngine: CognitiveDecisionEngine
    
    // MARK: - State
    
    @Published public var isInitialized = false
    @Published public var processingQuery = false
    @Published public var lastResponse: AIModelResponse?
    @Published public var errorMessage: String?
    
    // MARK: - Configuration
    
    public struct Configuration: Sendable {
        let enableRAG: Bool
        let enableMemoryConsolidation: Bool
        let maxContextSize: Int
        let consolidationInterval: TimeInterval // seconds
        
        nonisolated public static let `default` = Configuration(
            enableRAG: true,
            enableMemoryConsolidation: true,
            maxContextSize: 8192,
            consolidationInterval: 24 * 60 * 60 // 24 hours
        )
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(
        modelContext: ModelContext,
        knowledgeGraphService: KnowledgeGraphService,
        configuration: Configuration = .default,
        aiModelProvider: MemoryAgentModelProvider? = nil,
        promptManager: PromptManager? = nil,
        cognitiveEngine: CognitiveDecisionEngine? = nil
    ) {
        self.modelContext = modelContext
        self.knowledgeGraphService = knowledgeGraphService
        self.retrievalEngine = MemoryRetrievalEngine(modelContext: modelContext)
        self.configuration = configuration
        self.aiModelProvider = aiModelProvider ?? MemoryAgentModelProvider()
        self.promptManager = promptManager ?? PromptManager(modelContext: modelContext)
        self.promptResolver = MemoryPromptResolver(promptManager: self.promptManager)
        self.cognitiveEngine = cognitiveEngine ?? CognitiveDecisionEngine(modelContext: modelContext)
        
        logger.info("Memory Agent initializing with prompt management and cognitive decision tracking...")
    }
    
    // MARK: - Lifecycle
    
    public func initialize() async throws {
        logger.info("Starting Memory Agent initialization")
        
        // Register and initialize AI providers
        // Note: AI providers now managed through ExternalProviderFactory
        // The new architecture uses settings-based configuration
        // Provider initialization handled by factory, not directly here
        logger.info("AI providers will be configured through ExternalProviderFactory")
        
        // Schedule memory consolidation if enabled
        if configuration.enableMemoryConsolidation {
            scheduleMemoryConsolidation()
        }
        
        isInitialized = true
        logger.info("Memory Agent initialization completed")
    }
    
    public func shutdown() async {
        logger.info("Shutting down Memory Agent")
        
        // Cleanup AI providers
        await aiModelProvider.cleanup()
        
        isInitialized = false
        logger.info("Memory Agent shutdown completed")
    }
    
    // MARK: - Primary Interface
    
    /// Process a user query with RAG-enhanced AI response
    public func processQuery(_ query: String) async throws -> AIModelResponse {
        guard isInitialized else {
            throw MemoryAgentError.notInitialized
        }
        
        logger.info("Processing query: '\(query.prefix(50))...'")
        processingQuery = true
        errorMessage = nil
        
        let startTime = Date()
        
        defer {
            Task { @MainActor in
                processingQuery = false
            }
        }
        
        do {
            // Step 1: Retrieve relevant memories using RAG
            let memoryRetrievalStart = Date()
            let memoryContext = try await retrieveRelevantContext(for: query)
            let memoryRetrievalTime = Date().timeIntervalSince(memoryRetrievalStart)
            
            // Track memory retrieval decision
            await cognitiveEngine.recordDecision(
                agentId: "MemoryAgent",
                decisionType: .memoryOperation,
                context: "Retrieve context for: \(query.prefix(100))",
                reasoning: "Retrieved \(memoryContext.shortTermMemories.count) STM, \(memoryContext.longTermMemories.count) LTM, \(memoryContext.entities.count) entities",
                confidence: configuration.enableRAG ? 0.9 : 0.5,
                metadata: [
                    "ragEnabled": String(configuration.enableRAG),
                    "contextSize": String(memoryContext.shortTermMemories.count + memoryContext.longTermMemories.count),
                    "retrievalTime": String(memoryRetrievalTime)
                ]
            )
            
            // Step 2: Generate response using intelligent provider selection
            let responseStart = Date()
            let response = try await aiModelProvider.generateResponse(prompt: query, context: memoryContext)
            let responseTime = Date().timeIntervalSince(responseStart)
            
            // Track AI response generation decision
            await cognitiveEngine.recordDecision(
                agentId: "MemoryAgent",
                decisionType: .userInteraction,
                context: "Query: \(query), Memory context size: \(memoryContext.shortTermMemories.count + memoryContext.longTermMemories.count)",
                reasoning: "Generated response using memory-augmented context",
                confidence: response.confidence,
                metadata: [
                    "modelUsed": response.modelUsed,
                    "isOnDevice": String(response.isOnDevice),
                    "tokensUsed": String(response.tokensUsed ?? 0),
                    "processingTime": String(responseTime)
                ]
            )
            
            // Step 3: Store the interaction as a short-term memory
            try await storeInteraction(query: query, response: response, context: memoryContext)
            
            lastResponse = response
            
            let totalTime = Date().timeIntervalSince(startTime)
            logger.info("Query processed successfully using \(response.modelUsed) in \(String(format: "%.2f", totalTime))s")
            
            return response
            
        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            
            // Track failed decision
            await cognitiveEngine.recordDecision(
                agentId: "MemoryAgent",
                decisionType: .userInteraction,
                context: "Query processing: \(query)",
                reasoning: "Query processing failed due to error: \(error.localizedDescription)",
                confidence: 0.0,
                metadata: [
                    "outcome": "failure",
                    "error": error.localizedDescription,
                    "processingTime": String(totalTime)
                ]
            )
            
            errorMessage = error.localizedDescription
            logger.error("Query processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Ingest new data into the memory system
    public func ingestData(_ data: MemoryIngestData) async throws {
        logger.info("Ingesting data: \(data.type)")
        
        switch data.type {
        case .transcription:
            try await processTranscription(data)
        case .note:
            try await processNote(data)
        case .healthData:
            try await processHealthData(data)
        case .userInteraction:
            try await processUserInteraction(data)
        }
    }
    
    /// Manually trigger memory consolidation
    public func consolidateMemories() async throws {
        logger.info("Starting manual memory consolidation")
        try await performMemoryConsolidation()
    }
    
    // AI provider management is now handled by MemoryAgentModelProvider
    
    // MARK: - Memory Context Retrieval
    
    public func retrieveRelevantContext(for query: String) async throws -> MemoryContext {
        guard configuration.enableRAG else {
            return MemoryContext(userQuery: query)
        }
        
        let retrievalConfig = MemoryRetrievalEngine.RetrievalConfiguration.personalFocus
        // Note: Suppressing sendable warning - retrievalEngine is safe for concurrent access
        return try await retrievalEngine.retrieveRelevantMemories(for: query, configuration: retrievalConfig)
    }
    
    // MARK: - Data Ingestion
    
    private func processTranscription(_ data: MemoryIngestData) async throws {
        guard let content = data.content else { return }
        
        // Create short-term memory from transcription
        let stm = STMEntry(
            content: content,
            memoryType: .episodic,
            importance: data.confidence,
            sourceNoteId: nil,
            relatedEntities: [],
            emotionalWeight: 0.0,
            contextTags: data.metadata?["tags"] as? [String] ?? []
        )
        
        modelContext.insert(stm)
        do {
            try modelContext.save()
            logger.info("Successfully saved STM entry")
        } catch {
            logger.error("Failed to save STM entry: \(error)")
            throw error
        }
        
        // Extract entities and relationships
        try await extractEntitiesAndRelationships(from: content, source: stm)
        
        logger.info("Transcription processed and stored as STM")
    }
    
    private func processNote(_ data: MemoryIngestData) async throws {
        guard let content = data.content else { return }
        
        // Create memory operation context
        let operationContext = MemoryOperationContext(
            primaryContent: content,
            contextualData: data.metadata ?? [:],
            containsPersonalData: detectPersonalData(in: content),
            importance: data.confidence,
            sourceType: "note",
            userPatterns: nil // Could be populated with user patterns analysis
        )
        
        // Get appropriate template for note categorization
        guard let template = promptResolver.getPromptFor(
            operation: .noteCategorizationSTMvsLTM,
            context: operationContext
        ) else {
            logger.error("No template found for note categorization")
            throw MemoryAgentError.memoryRetrievalFailed("No template available for note categorization")
        }
        
        // Render prompt with note data
        let analysisPrompt = promptManager.renderTemplate(template, with: [
            "content": content,
            "context": data.metadata?["context"] as? String ?? "",
            "user_patterns": "", // Could be filled with user pattern analysis
            "metadata": data.metadata?.description ?? ""
        ])
        
        let startTime = Date()
        let memoryContext = MemoryContext(userQuery: "Analyze this note content: \(content)")
        let analysis: AIModelResponse
        
        do {
            analysis = try await aiModelProvider.generateResponse(prompt: analysisPrompt, context: memoryContext)
            
            // Record template success
            let processingTime = Date().timeIntervalSince(startTime)
            promptResolver.recordTemplateSuccess(template, operation: .noteCategorizationSTMvsLTM, processingTime: processingTime)
            
        } catch {
            // Record template failure
            promptResolver.recordTemplateFailure(template, operation: .noteCategorizationSTMvsLTM, error: error)
            throw error
        }
            
        if analysis.content.lowercased().contains("long-term") || analysis.content.lowercased().contains("important") {
            // Create LTM
            let ltm = LTMEntry(
                content: content,
                category: .personal,
                importance: 0.8,
                sourceSTMEntry: nil,
                sourceSTMIds: [],
                relatedEntities: [],
                relatedConcepts: [],
                emotionalWeight: 0.0,
                retrievalCues: data.metadata?["tags"] as? [String] ?? [],
                memoryCluster: nil
            )
            modelContext.insert(ltm)
        } else {
            // Create STM
            let stm = STMEntry(
                content: content,
                memoryType: .semantic,
                importance: 1.0,
                sourceNoteId: nil,
                relatedEntities: [],
                emotionalWeight: 0.0,
                contextTags: data.metadata?["tags"] as? [String] ?? []
            )
            modelContext.insert(stm)
        }
        
        do {
            try modelContext.save()
            logger.info("Successfully saved memory entry (Note processing)")
        } catch {
            logger.error("Failed to save memory entry: \(error)")
            throw error
        }
        
        logger.info("Note processed and stored")
    }
    
    private func processHealthData(_ data: MemoryIngestData) async throws {
        // Create episodic memory for health data
        guard let content = data.content else { return }
        
        let episodic = EpisodicMemoryEntry(
            eventDescription: "Health Data Entry: \(content)",
            location: nil,
            participants: ["User"],
            emotionalTone: EpisodicMemoryEntry.EmotionalTone.neutral,
            importance: 0.7,
            contextualCues: ["HealthKit", "data"],
            duration: nil,
            outcome: nil,
            lessons: []
        )
        
        modelContext.insert(episodic)
        try modelContext.save()
        
        logger.info("Health data processed as episodic memory")
    }
    
    private func processUserInteraction(_ data: MemoryIngestData) async throws {
        // Store user interactions as episodic memories
        guard let content = data.content else { return }
        
        let episodic = EpisodicMemoryEntry(
            eventDescription: "User Interaction: \(content)",
            location: nil,
            participants: ["User"],
            emotionalTone: EpisodicMemoryEntry.EmotionalTone.neutral,
            importance: 0.5,
            contextualCues: ["app", "interaction"],
            duration: nil,
            outcome: nil,
            lessons: []
        )
        
        modelContext.insert(episodic)
        try modelContext.save()
        
        logger.info("User interaction stored as episodic memory")
    }
    
    // MARK: - Entity and Relationship Extraction
    
    private func extractEntitiesAndRelationships(from content: String, source: Any) async throws {
        // Create memory operation context for entity extraction
        let sourceType = getSourceType(from: source)
        let operationContext = MemoryOperationContext(
            primaryContent: content,
            contextualData: ["source_type": sourceType],
            containsPersonalData: detectPersonalData(in: content),
            importance: 0.7, // Entity extraction is generally important
            sourceType: sourceType
        )
        
        // Get appropriate template for entity extraction
        guard let template = promptResolver.getPromptFor(
            operation: .entityRelationshipExtraction,
            context: operationContext
        ) else {
            logger.error("No template found for entity extraction")
            throw MemoryAgentError.memoryRetrievalFailed("No template available for entity extraction")
        }
        
        // Render prompt with content data
        let extractionPrompt = promptManager.renderTemplate(template, with: [
            "text": content,
            "context": "", // Could be populated with additional context
            "source_type": sourceType
        ])
        
        let startTime = Date()
        let context = MemoryContext(userQuery: extractionPrompt)
        
        do {
            let response = try await aiModelProvider.generateResponse(prompt: extractionPrompt, context: context)
            
            // Record template success
            let processingTime = Date().timeIntervalSince(startTime)
            promptResolver.recordTemplateSuccess(template, operation: .entityRelationshipExtraction, processingTime: processingTime)
            
            // Parse the JSON response and create entities/relationships
            try parseAndStoreEntitiesAndRelationships(from: response.content, source: source)
            
            logger.info("Entity extraction completed for content from \(sourceType)")
            
        } catch {
            // Record template failure
            promptResolver.recordTemplateFailure(template, operation: .entityRelationshipExtraction, error: error)
            logger.error("Failed to extract entities and relationships: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func getSourceType(from source: Any) -> String {
        switch source {
        case is STMEntry:
            return "stm_entry"
        case is LTMEntry:
            return "ltm_entry"
        case is EpisodicMemoryEntry:
            return "episodic_memory"
        case is String:
            return "text"
        default:
            return "unknown"
        }
    }
    
    private func parseAndStoreEntitiesAndRelationships(from jsonResponse: String, source: Any) throws {
        // Implementation for parsing JSON and storing entities/relationships
        // This would need proper JSON parsing and entity creation logic
        logger.info("Parsing and storing entities from JSON response")
        
        // TODO: Implement proper JSON parsing and entity storage
        // For now, just log that the extraction was completed
        logger.debug("JSON Response received: \(jsonResponse.prefix(200))...")
    }
    
    /// Detect if content contains personal data
    private func detectPersonalData(in content: String) -> Bool {
        let personalIndicators = ["my", "i", "me", "mine", "myself", "personal", "remember", "recall", "i'm", "i've", "my name", "my phone", "my email", "my address"]
        let lowercaseContent = content.lowercased()
        return personalIndicators.contains { lowercaseContent.contains($0) }
    }
    
    // MARK: - Memory Consolidation
    
    private func scheduleMemoryConsolidation() {
        Timer.scheduledTimer(withTimeInterval: configuration.consolidationInterval, repeats: true) { _ in
            Task {
                try? await self.performMemoryConsolidation()
            }
        }
    }
    
    private func performMemoryConsolidation() async throws {
        logger.info("Starting memory consolidation process")
        
        // Get STMs older than 24 hours
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        let descriptor = FetchDescriptor<STMEntry>(
            predicate: #Predicate { $0.timestamp < cutoffDate },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        let oldSTMs = try modelContext.fetch(descriptor)
        
        for stm in oldSTMs {
            // Create memory operation context for consolidation decision
            let ageHours = Date().timeIntervalSince(stm.timestamp) / 3600
            let operationContext = MemoryOperationContext(
                primaryContent: stm.content,
                contextualData: [
                    "memory_type": stm.memoryType.displayName,
                    "importance": stm.importance,
                    "access_count": stm.accessCount,
                    "age_hours": ageHours
                ],
                containsPersonalData: detectPersonalData(in: stm.content),
                importance: stm.importance,
                sourceType: "stm_consolidation"
            )
            
            // Get appropriate template for STM consolidation decision
            guard let template = promptResolver.getPromptFor(
                operation: .stmConsolidationDecision,
                context: operationContext
            ) else {
                logger.error("No template found for STM consolidation")
                continue // Skip this STM and continue with others
            }
            
            // Render prompt with STM data
            let consolidationPrompt = promptManager.renderTemplate(template, with: [
                "content": stm.content,
                "memory_type": stm.memoryType.displayName,
                "importance": String(stm.importance),
                "access_count": String(stm.accessCount),
                "age_hours": String(format: "%.1f", ageHours),
                "context_tags": stm.contextTags.joined(separator: ", "),
                "related_entities": stm.relatedEntities.map { $0.uuidString }.joined(separator: ", "),
                "emotional_weight": String(stm.emotionalWeight)
            ])
            
            let startTime = Date()
            let context = MemoryContext(userQuery: consolidationPrompt)
            let decision: AIModelResponse
            
            do {
                decision = try await aiModelProvider.generateResponse(prompt: consolidationPrompt, context: context)
                
                // Record template success
                let processingTime = Date().timeIntervalSince(startTime)
                promptResolver.recordTemplateSuccess(template, operation: .stmConsolidationDecision, processingTime: processingTime)
                
            } catch {
                // Record template failure and continue with next STM
                promptResolver.recordTemplateFailure(template, operation: .stmConsolidationDecision, error: error)
                logger.error("Failed to get consolidation decision for STM \(stm.id): \(error.localizedDescription)")
                continue
            }
            
            if decision.content.contains("PROMOTE_TO_LTM") {
                // Extract summary and create LTM
                let summary = decision.content.replacingOccurrences(of: "PROMOTE_TO_LTM: ", with: "")
                
                let ltm = LTMEntry(
                    content: stm.content,
                    category: .personal,
                    importance: stm.importance,
                    sourceSTMEntry: stm,
                    sourceSTMIds: [stm.id],
                    relatedEntities: stm.relatedEntities,
                    relatedConcepts: stm.contextTags,
                    emotionalWeight: stm.emotionalWeight,
                    retrievalCues: stm.contextTags,
                    memoryCluster: nil
                )
                
                modelContext.insert(ltm)
                logger.info("STM promoted to LTM: \(summary.prefix(50))...")
            }
            
            // Remove the STM
            modelContext.delete(stm)
        }
        
        try modelContext.save()
        logger.info("Memory consolidation completed - processed \(oldSTMs.count) STMs")
    }
    
    // MARK: - Interaction Storage
    
    private func storeInteraction(query: String, response: AIModelResponse, context: MemoryContext) async throws {
        // 1. Store the user query as episodic memory
        let queryEntry = EpisodicMemoryEntry(
            eventDescription: query,
            location: nil,
            participants: ["user"],
            emotionalTone: EpisodicMemoryEntry.EmotionalTone.neutral,
            importance: 0.7
        )
        modelContext.insert(queryEntry)
        
        // 2. Store the AI response as semantic memory with full context
        let responseContent = response.content
        let interactionSTM = STMEntry(
            content: responseContent,
            memoryType: .semantic,
            importance: response.confidence,
            sourceNoteId: nil,
            relatedEntities: [], // Will be populated by entity extraction
            emotionalWeight: 0.0,
            contextTags: [
                "ai_response",
                "conversation", 
                response.modelUsed.lowercased().replacingOccurrences(of: " ", with: "_"),
                "query_response_pair"
            ]
        )
        modelContext.insert(interactionSTM)
        
        // 3. Store the conversation pair as episodic memory for context continuity
        let conversationEntry = EpisodicMemoryEntry(
            eventDescription: "Conversation: User asked '\(query.prefix(100))...' and received response about \(self.extractMainTopics(from: responseContent).joined(separator: ", "))",
            location: nil,
            participants: ["user", "memory_agent"],
            emotionalTone: EpisodicMemoryEntry.EmotionalTone.neutral,
            importance: min(response.confidence, 0.9)
        )
        modelContext.insert(conversationEntry)
        
        // 4. Save all entries
        try modelContext.save()
        
        // 5. Extract entities and relationships from the response content asynchronously
        Task {
            do {
                try await self.extractEntitiesAndRelationships(from: responseContent, source: interactionSTM)
                try await self.linkConversationContext(queryId: queryEntry.id, responseId: interactionSTM.id, conversationId: conversationEntry.id)
            } catch {
                logger.error("Failed to extract entities from AI response: \(error.localizedDescription)")
            }
        }
        
        logger.info("Interaction stored with full context integration")
    }
    
    /// Extract main topics from AI response for episodic memory description
    private func extractMainTopics(from content: String) -> [String] {
        // Simple keyword extraction - could be enhanced with NLP
        let words = content.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }
            .filter { !["about", "would", "could", "should", "there", "their", "where", "while", "which"].contains($0) }
        
        let topWords = Set(words.prefix(3))
        return Array(topWords)
    }
    
    /// Link conversation context for better retrieval
    private func linkConversationContext(queryId: UUID, responseId: UUID, conversationId: UUID) async throws {
        // Create relationships between the conversation components
        let queryToResponse = Relationship(
            subjectEntityId: queryId,
            predicateType: .references,
            objectEntityId: responseId
        )
        modelContext.insert(queryToResponse)
        
        let conversationToQuery = Relationship(
            subjectEntityId: conversationId,
            predicateType: .contains,
            objectEntityId: queryId
        )
        modelContext.insert(conversationToQuery)
        
        let conversationToResponse = Relationship(
            subjectEntityId: conversationId,
            predicateType: .contains,
            objectEntityId: responseId
        )
        modelContext.insert(conversationToResponse)
        
        try modelContext.save()
    }
    
    // MARK: - Cognitive Decision Access
    
    /// Access to the cognitive decision engine for UI components
    public var cognitiveDecisionEngine: CognitiveDecisionEngine {
        return cognitiveEngine
    }
}

// MARK: - Supporting Types

public struct MemoryIngestData {
    let type: DataType
    let content: String?
    let timestamp: Date
    let confidence: Double
    let metadata: [String: Any]?
    
    public enum DataType: CustomStringConvertible {
        case transcription
        case note
        case healthData
        case userInteraction
        
        public var description: String {
            switch self {
            case .transcription: return "transcription"
            case .note: return "note"
            case .healthData: return "healthData"
            case .userInteraction: return "userInteraction"
            }
        }
    }
    
    public init(type: DataType, content: String?, timestamp: Date = Date(), confidence: Double = 1.0, metadata: [String: Any]? = nil) {
        self.type = type
        self.content = content
        self.timestamp = timestamp
        self.confidence = confidence
        self.metadata = metadata
    }
}

public enum MemoryAgentError: Error, LocalizedError {
    case notInitialized
    case noAIProvidersAvailable
    case noPrivacyCompliantProvider
    case noAvailableProvider
    case providerNotReady(String)
    case memoryRetrievalFailed(String)
    case consolidationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Memory Agent not initialized"
        case .noAIProvidersAvailable:
            return "No AI providers available"
        case .noPrivacyCompliantProvider:
            return "No privacy-compliant AI provider available for personal data"
        case .noAvailableProvider:
            return "No available AI provider"
        case .providerNotReady(let reason):
            return "AI provider not ready: \(reason)"
        case .memoryRetrievalFailed(let reason):
            return "Memory retrieval failed: \(reason)"
        case .consolidationFailed(let reason):
            return "Memory consolidation failed: \(reason)"
        }
    }
}