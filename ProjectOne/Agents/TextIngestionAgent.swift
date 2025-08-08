
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
    case entityExtraction = "Extracting entities"
    case summaryGeneration = "Generating summary"
    case topicIdentification = "Identifying topics"
    case knowledgeGraphIntegration = "Integrating with knowledge graph"
    case embeddingGeneration = "Generating embeddings"
    case finalizing = "Finalizing"
    case completed = "Completed"
}

@MainActor
public class TextIngestionAgent: ObservableObject {
    
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "TextIngestionAgent")
    
    // AI providers
    private var gemmaCore: EnhancedGemma3nCore?
    private var embeddingService: EmbeddingGenerationService?
    private weak var memoryService: MemoryAgentService? // Weak reference to avoid circular dependency
    
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
            gemmaCore = EnhancedGemma3nCore()
            Task {
                await gemmaCore?.setup()
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
            
            // Step 2: Summary Generation with AI
            await updateProgress(step: .summaryGeneration, progress: 0.25, message: "Generating AI summary...")
            let summary = try await generateAISummary(from: processedNote.originalText)
            processedNote.summary = summary
            
            // Step 3: Topic Identification with AI
            await updateProgress(step: .topicIdentification, progress: 0.375, message: "Identifying topics with AI...")
            let topics = try await identifyTopicsWithAI(from: processedNote.originalText)
            processedNote.topics = topics
            
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
            
            // Step 2: Summary Generation
            await updateProgress(step: .summaryGeneration, progress: 0.25, message: "Generating summary...")
            let summary = try await generateFallbackSummary(from: note.markdownContent)
            
            // Step 3: Topic Identification
            await updateProgress(step: .topicIdentification, progress: 0.375, message: "Identifying topics...")
            let topics = try await identifyFallbackTopics(from: note.markdownContent)
            
            // Step 4: Entity Extraction
            await updateProgress(step: .entityExtraction, progress: 0.5, message: "Extracting entities...")
            let entities = try await extractFallbackEntities(from: note.markdownContent)
            
            // Step 5: Create ProcessedNote
            await updateProgress(step: .knowledgeGraphIntegration, progress: 0.625, message: "Creating processed note...")
            let processedNote = ProcessedNote(
                sourceType: .text,
                originalText: note.markdownContent,
                summary: summary,
                topics: topics
            )
            
            // Start processing tracking
            processedNote.startProcessing()
            
            // Add extracted entity names for later KG integration
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
        guard let gemmaCore = gemmaCore else {
            return try await generateFallbackSummary(from: text)
        }
        
        let prompt = """
        Please provide a concise, informative summary of the following text. Focus on the main points and key information:
        
        \(text)
        
        Summary:
        """
        
        logger.info("Generating AI summary for text (\(text.count) characters)")
        let response = await gemmaCore.processText(prompt)
        
        // Clean up the response
        let summary = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? try await generateFallbackSummary(from: text) : summary
    }
    
    private func identifyTopicsWithAI(from text: String) async throws -> [String] {
        guard let gemmaCore = gemmaCore else {
            return try await identifyFallbackTopics(from: text)
        }
        
        let prompt = """
        Analyze the following text and identify 3-5 main topics or themes. Return only the topics as a comma-separated list:
        
        \(text)
        
        Topics:
        """
        
        logger.info("Identifying topics with AI for text (\(text.count) characters)")
        let response = await gemmaCore.processText(prompt)
        
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
        guard let gemmaCore = gemmaCore else {
            return try await extractFallbackEntities(from: text)
        }
        
        let prompt = """
        Extract all important entities (people, places, organizations, concepts) from the following text. Return only the entity names as a comma-separated list:
        
        \(text)
        
        Entities:
        """
        
        logger.info("Extracting entities with AI for text (\(text.count) characters)")
        let response = await gemmaCore.processText(prompt)
        
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
        guard let gemmaCore = gemmaCore else {
            return []
        }
        
        let prompt = """
        Identify key relationships between entities in the following text. Return relationships in the format "Entity1 -> relationship -> Entity2" as a comma-separated list:
        
        \(text)
        
        Relationships:
        """
        
        logger.info("Extracting relationships with AI")
        let response = await gemmaCore.processText(prompt)
        
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
