
//
//  TextIngestionAgent.swift
//  ProjectOne
//
//  Created by Gemini on 7/13/2025.
//

import Foundation
import SwiftData
import Combine
import os.log

public enum ProcessingStep: String, CaseIterable {
    case initialization = "Initializing"
    case textAnalysis = "Analyzing text"
    case thoughtExtraction = "Extracting thoughts"
    case tagGeneration = "Generating tags"
    case entityExtraction = "Extracting entities"
    case knowledgeGraphIntegration = "Integrating with knowledge graph"
    case embeddingGeneration = "Generating embeddings"
    case finalizing = "Finalizing"
    case completed = "Completed"
}

@MainActor
public class TextIngestionAgent: ObservableObject {
    
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "TextIngestionAgent")
    
    // AI providers and services
    private var providerFactory: ExternalProviderFactory?
    private var embeddingService: EmbeddingGenerationService?
    private weak var memoryService: MemoryAgentService? // Weak reference to avoid circular dependency
    // private lazy var thoughtExtractionService = ThoughtExtractionService(modelContext: modelContext)
    
    // Published properties for UI visibility
    @Published public var isProcessing = false
    @Published public var currentStep: ProcessingStep = .initialization
    @Published public var progress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var lastError: String?
    
    public init(modelContext: ModelContext, memoryService: MemoryAgentService? = nil) {
        self.modelContext = modelContext
        self.memoryService = memoryService
        logger.info("TextIngestionAgent initialized with \(memoryService != nil ? "shared" : "no") memory service")
        
        // Initialize AI providers
        setupAIProviders()
    }
    
    private func setupAIProviders() {
        if #available(iOS 26.0, macOS 26.0, *) {
            providerFactory = ExternalProviderFactory(settings: AIProviderSettings())
            Task {
                await providerFactory?.configureFromSettings()
            }
        }
        
        // Initialize embedding service
        Task {
            // Create a basic embedding provider for now
            // In a real implementation, this would use the actual MLX embedding provider
            // embeddingService = EmbeddingGenerationService(modelContext: modelContext, embeddingProvider: mlxEmbeddingProvider)
            logger.info("Embedding service setup deferred until provider is available")
        }
    }
    
    /// Process a ProcessedNote with full AI integration and memory formation
    func process(processedNote: ProcessedNote) async {
        await startProcessing(for: processedNote.id.uuidString)
        
        do {
            await updateProgress(step: .initialization, progress: 0.0, message: "Starting AI-powered note processing...")
            logger.info("📝 Processing note with AI: \(processedNote.id)")
            
            // Mark processing as started
            processedNote.startProcessing()
            
            // Step 1: Text Analysis with AI
            await updateProgress(step: .textAnalysis, progress: 0.125, message: "Analyzing content with AI...")
            let wordCount = processedNote.originalText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            logger.debug("Analyzed text: \(wordCount) words")
            
            // Step 2: Thought Extraction (replaces summary generation)
            await updateProgress(step: .thoughtExtraction, progress: 0.25, message: "Extracting granular thoughts...")
            let thoughtSummaries = try await extractThoughtSummaries(from: processedNote.originalText)
            
            // TODO: Create proper Thought objects when Thought model is available
            // For now, use temporary storage
            for thoughtSummary in thoughtSummaries {
                processedNote.addThoughtSummary(
                    content: thoughtSummary.content,
                    tags: thoughtSummary.tags,
                    type: thoughtSummary.type,
                    importance: thoughtSummary.importance
                )
            }
            
            // Step 3: Tag Generation (generate from thoughts)
            await updateProgress(step: .tagGeneration, progress: 0.375, message: "Generating tags from thoughts...")
            
            // Get tags from temporary storage (proper thoughts not available yet)
            let tempThoughtTags = processedNote.allThoughtTags
            let allTags = Array(Set(tempThoughtTags))
            
            processedNote.topics = Array(Set(allTags)).prefix(10).map { String($0) } // Store unique tags as topics
            
            // Generate a summary from thoughts for backward compatibility
            processedNote.summary = generateSummaryFromThoughtSummaries(thoughtSummaries)
            
            // Step 4: Entity Extraction with AI
            await updateProgress(step: .entityExtraction, progress: 0.5, message: "Extracting entities with AI...")
            let entities = try await extractEntitiesWithAI(from: processedNote.originalText)
            processedNote.extractedEntityNames = entities
            
            // Step 5: Knowledge Graph Integration
            await updateProgress(step: .knowledgeGraphIntegration, progress: 0.625, message: "Integrating with knowledge graph...")
            try await integrateWithKnowledgeGraph(processedNote: processedNote)
            
            // Step 6: Memory Formation
            await updateProgress(step: .embeddingGeneration, progress: 0.75, message: "Forming memories...")
            try await formMemories(from: processedNote)
            
            // Step 7: Embedding Generation
            await updateProgress(step: .embeddingGeneration, progress: 0.875, message: "Generating embeddings...")
            try await generateEmbeddings(for: processedNote)
            
            // Step 8: Complete processing
            await updateProgress(step: .completed, progress: 1.0, message: "AI processing completed successfully")
            processedNote.completeProcessing()
            
            // Save changes
            try modelContext.save()
            
            logger.info("✅ Successfully processed note with AI: \(processedNote.id)")
            
        } catch {
            let errorMessage = "Failed to process note with AI: \(error.localizedDescription)"
            await updateError(errorMessage)
            logger.error("❌ \(errorMessage)")
            
            // Mark error in the note
            processedNote.addProcessingError(errorMessage)
            try? modelContext.save()
        }
        
        await finishProcessing()
    }

    func process(note: NoteItem) async {
        await startProcessing(for: note.id.uuidString)
        
        do {
            await updateProgress(step: .initialization, progress: 0.0, message: "Starting note processing...")
            logger.info("📝 Processing note ID: \(note.id)")
            
            // Step 1: Text Analysis
            await updateProgress(step: .textAnalysis, progress: 0.125, message: "Analyzing note content...")
            let wordCount = note.markdownContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            logger.debug("Analyzed text: \(wordCount) words")
            
            // Step 2: Create ProcessedNote first
            await updateProgress(step: .thoughtExtraction, progress: 0.25, message: "Creating processed note...")
            let processedNote = ProcessedNote(
                sourceType: .text,
                originalText: note.markdownContent,
                summary: "", // Will be generated from thoughts
                topics: []   // Will be generated from thought tags
            )
            
            // Start processing tracking
            processedNote.startProcessing()
            
            // Step 3: Extract thoughts with tags
            await updateProgress(step: .thoughtExtraction, progress: 0.375, message: "Extracting thoughts and generating tags...")
            let thoughtSummaries = try await extractThoughtSummaries(from: note.markdownContent)
            
            // TODO: Create proper Thought objects when Thought model is available
            // For now, use temporary storage
            for thoughtSummary in thoughtSummaries {
                processedNote.addThoughtSummary(
                    content: thoughtSummary.content,
                    tags: thoughtSummary.tags,
                    type: thoughtSummary.type,
                    importance: thoughtSummary.importance
                )
            }
            
            // Step 4: Generate summary and topics from thoughts
            await updateProgress(step: .tagGeneration, progress: 0.5, message: "Generating summary from thoughts...")
            processedNote.summary = generateSummaryFromThoughtSummaries(thoughtSummaries)
            
            // Get tags from temporary storage (proper thoughts not available yet)
            let tempThoughtTags = processedNote.allThoughtTags
            let allTags = Array(Set(tempThoughtTags))
            processedNote.topics = Array(Set(allTags)).prefix(10).map { String($0) }
            
            // Step 5: Fallback entity extraction
            await updateProgress(step: .entityExtraction, progress: 0.625, message: "Extracting entities...")
            let entities = try await extractFallbackEntities(from: note.markdownContent)
            processedNote.extractedEntityNames = entities
            
            // Step 6: Save to context
            await updateProgress(step: .finalizing, progress: 0.75, message: "Saving note...")
            modelContext.insert(processedNote)
            try modelContext.save()
            
            // Step 7: Mark original note as processed
            await updateProgress(step: .embeddingGeneration, progress: 0.875, message: "Scheduling embedding generation...")
            note.isProcessedByMemoryAgent = true
            note.processingDate = Date()
            try modelContext.save()
            
            // Step 8: Complete
            await updateProgress(step: .completed, progress: 1.0, message: "Note processing completed successfully")
            processedNote.completeProcessing()
            try modelContext.save()
            
            logger.info("✅ Successfully processed note ID: \(note.id)")
            
            // Schedule embedding generation (async, don't wait)
            // Use Task instead of Task.detached to maintain actor context
            Task { [weak self] in
                await self?.scheduleEmbeddingGeneration(for: processedNote)
            }
            
        } catch {
            let errorMessage = "Failed to process note: \(error.localizedDescription)"
            await updateError(errorMessage)
            logger.error("❌ \(errorMessage)")
            
            // If we have a processedNote, mark the error
            // Note: This requires the processedNote to be accessible in catch block
            // In a real implementation, we'd need to restructure this slightly
        }
        
        await finishProcessing()
    }
    
    // MARK: - AI-Powered Processing Methods
    
    private func generateAISummary(from text: String) async throws -> String {
        guard let providerFactory = providerFactory else {
            return try await generateFallbackSummary(from: text)
        }
        
        let prompt = """
        Please provide a concise, informative summary of the following text. Focus on the main points and key information:
        
        \(text)
        
        Summary:
        """
        
        logger.info("Generating AI summary for text (\(text.count) characters)")
        let response = try await providerFactory.generateResponse(prompt: prompt)
        
        // Clean up the response
        let summary = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? try await generateFallbackSummary(from: text) : summary
    }
    
    private func identifyTopicsWithAI(from text: String) async throws -> [String] {
        guard let providerFactory = providerFactory else {
            return try await identifyFallbackTopics(from: text)
        }
        
        let prompt = """
        Analyze the following text and identify 3-5 main topics or themes. Return only the topics as a comma-separated list:
        
        \(text)
        
        Topics:
        """
        
        logger.info("Identifying topics with AI for text (\(text.count) characters)")
        let response = try await providerFactory.generateResponse(prompt: prompt)
        
        // Parse the response into topics
        let topics = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 2 }
            .prefix(5)
        
        return Array(topics)
    }
    
    private func extractEntitiesWithAI(from text: String) async throws -> [String] {
        guard let providerFactory = providerFactory else {
            return try await extractFallbackEntities(from: text)
        }
        
        let prompt = """
        Extract all important entities (people, places, organizations, concepts) from the following text. Return only the entity names as a comma-separated list:
        
        \(text)
        
        Entities:
        """
        
        logger.info("Extracting entities with AI for text (\(text.count) characters)")
        let response = try await providerFactory.generateResponse(prompt: prompt)
        
        // Parse the response into entities
        let entities = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 1 }
            .prefix(10)
        
        return Array(entities)
    }
    
    private func integrateWithKnowledgeGraph(processedNote: ProcessedNote) async throws {
        // Integration with knowledge graph would happen here
        // For now, we'll use the memory service to handle this
        logger.info("Integrating note with knowledge graph: \(processedNote.id)")
        
        // Extract relationships and add them to the note
        let relationships = try await extractRelationshipsWithAI(from: processedNote.originalText)
        processedNote.extractedRelationships = relationships
    }
    
    private func formMemories(from processedNote: ProcessedNote) async throws {
        guard let memoryService = memoryService else {
            logger.warning("MemoryAgentService not available for memory formation")
            return
        }
        
        logger.info("Forming memories from processed note: \(processedNote.id)")
        
        // Use the memory service to process and form memories
        let query = """
        Process this content and form appropriate memories:
        
        Title: \(processedNote.summary)
        Content: \(processedNote.originalText)
        Topics: \(processedNote.topics.joined(separator: ", "))
        Entities: \(processedNote.extractedEntityNames.joined(separator: ", "))
        """
        
        do {
            let memoryResponse = try await memoryService.processQuery(query)
            logger.info("Memory formation completed: \(memoryResponse)")
        } catch {
            logger.error("Memory formation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func generateEmbeddings(for processedNote: ProcessedNote) async throws {
        guard let embeddingService = embeddingService else {
            logger.warning("EmbeddingGenerationService not available")
            return
        }
        
        logger.info("Generating embeddings for note: \(processedNote.id)")
        
        do {
            let embedding = try await embeddingService.generateEmbedding(for: processedNote)
            logger.info("Generated embedding with \(embedding.count) dimensions")
        } catch {
            logger.error("Embedding generation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func extractRelationshipsWithAI(from text: String) async throws -> [String] {
        guard let providerFactory = providerFactory else {
            return []
        }
        
        let prompt = """
        Identify key relationships between entities in the following text. Return relationships in the format "Entity1 -> relationship -> Entity2" as a comma-separated list:
        
        \(text)
        
        Relationships:
        """
        
        logger.info("Extracting relationships with AI")
        let response = try await providerFactory.generateResponse(prompt: prompt)
        
        // Parse the response into relationships
        let relationships = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(10)
        
        return Array(relationships)
    }
    
    // MARK: - Fallback Methods (when AI not available)
    
    private func generateFallbackSummary(from text: String) async throws -> String {
        // Simple summary generation as fallback
        let sentences = text.components(separatedBy: .punctuationCharacters).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        if sentences.isEmpty {
            return "Empty note"
        } else if sentences.count == 1 {
            return String(sentences[0].prefix(100))
        } else {
            return String(sentences[0].prefix(80)) + "..."
        }
    }
    
    private func identifyFallbackTopics(from text: String) async throws -> [String] {
        // Simple topic identification as fallback
        let words = text.lowercased().components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 }
        
        let commonWords = Set(["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "man", "new", "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let", "put", "say", "she", "too", "use"])
        
        let topics = Array(Set(words.filter { !commonWords.contains($0) && $0.count > 4 }.prefix(5)))
        return topics
    }
    
    private func extractFallbackEntities(from text: String) async throws -> [String] {
        // Simple entity extraction as fallback
        let words = text.components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        // Find capitalized words that could be entities
        let entities = words.filter { word in
            word.first?.isUppercase == true && word.count > 2
        }
        
        return Array(Set(entities).prefix(10))
    }
    
    private func scheduleEmbeddingGeneration(for note: ProcessedNote) async {
        logger.info("📊 Scheduling embedding generation for note: \(note.id)")
        // This would integrate with EmbeddingGenerationService
        // For now, just log the scheduling
    }
    
    // MARK: - Thought-based Processing Helpers
    
    /// Temporary thought summary structure
    private struct ThoughtSummary {
        let content: String
        let tags: [String]
        let type: String
        let importance: String
    }
    
    /// Extract thought summaries using AI (temporary implementation)
    private func extractThoughtSummaries(from text: String) async throws -> [ThoughtSummary] {
        guard let providerFactory = providerFactory else {
            return try await extractFallbackThoughtSummaries(from: text)
        }
        
        let prompt = """
        Analyze the following text and break it down into distinct thoughts. For each thought, provide:
        1. The content of the thought
        2. Relevant tags (2-4 words each)
        3. Type (idea, task, question, insight, memory, plan, reflection, fact, opinion, decision, goal, or general)
        4. Importance (low, medium, high, critical)

        Format your response as JSON array with objects containing: content, tags, type, importance

        Text:
        \(text)

        Response:
        """
        
        logger.info("Extracting thought summaries with AI for text (\(text.count) characters)")
        let response = try await providerFactory.generateResponse(prompt: prompt)
        
        return try await parseThoughtSummariesResponse(response)
    }
    
    /// Parse AI response into thought summaries
    private func parseThoughtSummariesResponse(_ response: String) async throws -> [ThoughtSummary] {
        let cleanResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to parse as JSON
        if let jsonData = cleanResponse.data(using: .utf8) {
            do {
                if let jsonArray = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                    return jsonArray.compactMap { dict in
                        guard let content = dict["content"] as? String,
                              let tags = dict["tags"] as? [String],
                              let type = dict["type"] as? String,
                              let importance = dict["importance"] as? String else {
                            return nil
                        }
                        return ThoughtSummary(content: content, tags: tags, type: type, importance: importance)
                    }
                }
            } catch {
                logger.warning("Failed to parse JSON response, falling back to text parsing")
            }
        }
        
        // Fallback to simple parsing
        return try await extractFallbackThoughtSummaries(from: response)
    }
    
    /// Fallback thought summary extraction
    private func extractFallbackThoughtSummaries(from text: String) async throws -> [ThoughtSummary] {
        // Simple sentence-based thought extraction
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count > 10 }
        
        return sentences.enumerated().map { index, sentence in
            let words = sentence.lowercased().components(separatedBy: .whitespacesAndNewlines)
            let tags = words.filter { $0.count > 3 }.prefix(3).map { String($0) }
            
            let type: String
            if sentence.contains("?") {
                type = "question"
            } else if sentence.lowercased().contains("todo") || sentence.lowercased().contains("need to") {
                type = "task"
            } else if sentence.lowercased().contains("idea") || sentence.lowercased().contains("think") {
                type = "idea"
            } else {
                type = "general"
            }
            
            let importance = sentence.count > 100 ? "high" : "medium"
            
            return ThoughtSummary(
                content: sentence,
                tags: Array(tags),
                type: type,
                importance: importance
            )
        }
    }
    
    /// Generate a summary from extracted thought summaries for backward compatibility
    private func generateSummaryFromThoughtSummaries(_ thoughtSummaries: [ThoughtSummary]) -> String {
        guard !thoughtSummaries.isEmpty else { return "Empty note" }
        
        if thoughtSummaries.count == 1 {
            return thoughtSummaries[0].content
        }
        
        // Group by importance and type
        let highImportanceThoughts = thoughtSummaries.filter { $0.importance == "high" || $0.importance == "critical" }
        let keyThoughts = thoughtSummaries.filter { 
            $0.type == "insight" || $0.type == "decision" || $0.type == "goal" 
        }
        
        var summaryParts: [String] = []
        
        // Add high importance thoughts first
        if !highImportanceThoughts.isEmpty {
            let importantContent = highImportanceThoughts.prefix(2).map { $0.content }.joined(separator: "; ")
            summaryParts.append(importantContent)
        }
        
        // Add key insights/decisions/goals
        if !keyThoughts.isEmpty && summaryParts.count < 2 {
            let keyContent = keyThoughts.prefix(2).map { $0.content }.joined(separator: "; ")
            if !summaryParts.contains(keyContent) {
                summaryParts.append(keyContent)
            }
        }
        
        // Add first few thoughts if we don't have enough content
        if summaryParts.isEmpty || summaryParts.joined(separator: " ").count < 50 {
            let firstThoughts = thoughtSummaries.prefix(3).map { $0.content }.joined(separator: "; ")
            summaryParts.append(firstThoughts)
        }
        
        let summary = summaryParts.joined(separator: " | ")
        return String(summary.prefix(200)) + (summary.count > 200 ? "..." : "")
    }
    
    /// Generate a summary from extracted thoughts for backward compatibility (legacy method)
    // TODO: Restore when Thought model is available in Xcode project
    /*
    private func generateSummaryFromThoughts(_ thoughts: [Thought]) -> String {
        guard !thoughts.isEmpty else { return "Empty note" }
        
        if thoughts.count == 1 {
            return thoughts[0].content
        }
        
        // Group by importance and type
        let highImportanceThoughts = thoughts.filter { $0.importance == .high || $0.importance == .critical }
        let keyThoughts = thoughts.filter { 
            $0.thoughtType == .insight || $0.thoughtType == .decision || $0.thoughtType == .goal 
        }
        
        var summaryParts: [String] = []
        
        // Add high importance thoughts first
        if !highImportanceThoughts.isEmpty {
            let importantContent = highImportanceThoughts.prefix(2).map { $0.content }.joined(separator: "; ")
            summaryParts.append(importantContent)
        }
        
        // Add key insights/decisions/goals
        if !keyThoughts.isEmpty && summaryParts.count < 2 {
            let keyContent = keyThoughts.prefix(2).map { $0.content }.joined(separator: "; ")
            if !summaryParts.contains(keyContent) {
                summaryParts.append(keyContent)
            }
        }
        
        // Add first few thoughts if we don't have enough content
        if summaryParts.isEmpty || summaryParts.joined(separator: " ").count < 50 {
            let firstThoughts = thoughts.prefix(3).map { $0.content }.joined(separator: "; ")
            summaryParts.append(firstThoughts)
        }
        
        let summary = summaryParts.joined(separator: " | ")
        return String(summary.prefix(200)) + (summary.count > 200 ? "..." : "")
    }
    */
    
    // MARK: - Progress Tracking
    
    private func startProcessing(for noteId: String) async {
        isProcessing = true
        currentStep = .initialization
        progress = 0.0
        statusMessage = "Starting processing..."
        lastError = nil
        logger.info("🚀 Started processing for note: \(noteId)")
    }
    
    private func updateProgress(step: ProcessingStep, progress: Double, message: String) async {
        self.currentStep = step
        self.progress = progress
        self.statusMessage = message
        logger.debug("📈 Progress: \(Int(progress * 100))% - \(message)")
        
        // Small delay to make progress visible in UI
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    private func updateError(_ message: String) async {
        lastError = message
        statusMessage = "Error: \(message)"
        logger.error("❌ \(message)")
    }
    
    private func finishProcessing() async {
        // Small delay to show completion state
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        isProcessing = false
        currentStep = .initialization
        progress = 0.0
        statusMessage = ""
        lastError = nil
    }
}
