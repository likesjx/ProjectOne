//
//  MemoryRetrievalEngine.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/15/25.
//

import Foundation
import SwiftData
import os.log
import Combine

/// RAG-based memory retrieval engine for the Memory Agent
public class MemoryRetrievalEngine: ObservableObject, @unchecked Sendable {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryRetrievalEngine")
    private let modelContext: ModelContext
    private let embeddingProvider: MLXProvider?
    private let embeddingService: EmbeddingGenerationService?
    
    // MARK: - Configuration
    
    public struct RetrievalConfiguration: Sendable {
        let maxResults: Int
        let recencyWeight: Double // 0.0 to 1.0
        let relevanceWeight: Double // 0.0 to 1.0
        let semanticThreshold: Double // 0.0 to 1.0
        let includeSTM: Bool
        let includeLTM: Bool
        let includeEpisodic: Bool
        let includeEntities: Bool
        let includeNotes: Bool
        
        // MARK: - Semantic Search Configuration
        
        /// Enable semantic similarity search using embeddings
        let enableSemanticSearch: Bool
        
        /// Weight for semantic similarity vs keyword matching (0.0 = only keywords, 1.0 = only semantic)
        let semanticWeight: Double // 0.0 to 1.0
        
        /// Weight for keyword matching vs semantic similarity (0.0 = only semantic, 1.0 = only keywords)
        let keywordWeight: Double // 0.0 to 1.0
        
        /// Minimum semantic similarity score to include results (0.0 to 1.0)
        let semanticSimilarityThreshold: Double
        
        /// Maximum age for embeddings before regeneration (in seconds)
        let embeddingMaxAge: TimeInterval
        
        public static let `default` = RetrievalConfiguration(
            maxResults: 10,
            recencyWeight: 0.3,
            relevanceWeight: 0.7,
            semanticThreshold: 0.5,
            includeSTM: true,
            includeLTM: true,
            includeEpisodic: true,
            includeEntities: true,
            includeNotes: true,
            enableSemanticSearch: true,
            semanticWeight: 0.6,
            keywordWeight: 0.4,
            semanticSimilarityThreshold: 0.3,
            embeddingMaxAge: 7 * 24 * 3600 // 7 days
        )
        
        public static let personalFocus = RetrievalConfiguration(
            maxResults: 15,
            recencyWeight: 0.4,
            relevanceWeight: 0.6,
            semanticThreshold: 0.4,
            includeSTM: true,
            includeLTM: true,
            includeEpisodic: true,
            includeEntities: false,
            includeNotes: true,
            enableSemanticSearch: true,
            semanticWeight: 0.7,
            keywordWeight: 0.3,
            semanticSimilarityThreshold: 0.4,
            embeddingMaxAge: 14 * 24 * 3600 // 14 days
        )
        
        public static let keywordOnly = RetrievalConfiguration(
            maxResults: 10,
            recencyWeight: 0.3,
            relevanceWeight: 0.7,
            semanticThreshold: 0.5,
            includeSTM: true,
            includeLTM: true,
            includeEpisodic: true,
            includeEntities: true,
            includeNotes: true,
            enableSemanticSearch: false,
            semanticWeight: 0.0,
            keywordWeight: 1.0,
            semanticSimilarityThreshold: 0.0,
            embeddingMaxAge: 0
        )
        
        public static let semanticOnly = RetrievalConfiguration(
            maxResults: 10,
            recencyWeight: 0.2,
            relevanceWeight: 0.8,
            semanticThreshold: 0.4,
            includeSTM: true,
            includeLTM: true,
            includeEpisodic: true,
            includeEntities: true,
            includeNotes: true,
            enableSemanticSearch: true,
            semanticWeight: 1.0,
            keywordWeight: 0.0,
            semanticSimilarityThreshold: 0.5, 
            embeddingMaxAge: 7 * 24 * 3600 // 7 days
        )
    }
    
    // MARK: - Initialization
    
    public init(
        modelContext: ModelContext,
        embeddingProvider: MLXProvider? = nil,
        embeddingService: EmbeddingGenerationService? = nil
    ) {
        self.modelContext = modelContext
        self.embeddingProvider = embeddingProvider
        self.embeddingService = embeddingService
        logger.info("Memory Retrieval Engine initialized with semantic search: \(embeddingProvider != nil)")
    }
    
    // MARK: - Primary Retrieval Method
    
    /// Retrieve relevant memories for a given query using RAG principles
    public func retrieveRelevantMemories(
        for query: String,
        configuration: RetrievalConfiguration = .default
    ) async throws -> MemoryContext {
        
        logger.info("Retrieving memories for query: '\(query.prefix(50))...'")
        let startTime = Date()
        
        // Extract key terms and concepts from the query
        let queryTerms = extractQueryTerms(from: query)
        let containsPersonalData = detectPersonalData(in: query)
        
        // Generate query embedding for semantic search if enabled
        let queryEmbedding = await generateQueryEmbedding(query, configuration: configuration)
        
        // Retrieve different types of memories sequentially (avoiding async let data race issues)
        let shortTermMemories = configuration.includeSTM ? try await retrieveShortTermMemories(queryTerms: queryTerms, limit: configuration.maxResults / 2) : []
        let longTermMemories = configuration.includeLTM ? try await retrieveLongTermMemories(queryTerms: queryTerms, limit: configuration.maxResults / 2) : []
        let episodicMemories = configuration.includeEpisodic ? try await retrieveEpisodicMemories(queryTerms: queryTerms, limit: configuration.maxResults / 3) : []
        let entities = configuration.includeEntities ? try await retrieveRelevantEntities(queryTerms: queryTerms, limit: configuration.maxResults / 3) : []
        let relationships = configuration.includeEntities ? try await retrieveRelevantRelationships(queryTerms: queryTerms, limit: configuration.maxResults / 4) : []
        let notes = configuration.includeNotes ? try await retrieveRelevantNotes(queryTerms: queryTerms, limit: configuration.maxResults / 3) : []
        
        // Score and rank all results with semantic search if available
        let rankedSTM: [STMEntry]
        let rankedLTM: [LTMEntry]
        let rankedEpisodic: [EpisodicMemoryEntry]
        let rankedEntities: [Entity]
        let rankedNotes: [ProcessedNote]
        
        if configuration.enableSemanticSearch && queryEmbedding != nil {
            // Use hybrid semantic + keyword ranking
            rankedSTM = rankMemoriesWithSemantics(shortTermMemories, queryTerms: queryTerms, queryEmbedding: queryEmbedding, configuration: configuration)
            rankedLTM = rankMemoriesWithSemantics(longTermMemories, queryTerms: queryTerms, queryEmbedding: queryEmbedding, configuration: configuration)
            rankedEpisodic = rankMemoriesWithSemantics(episodicMemories, queryTerms: queryTerms, queryEmbedding: queryEmbedding, configuration: configuration)
            rankedEntities = rankEntitiesWithSemantics(entities, queryTerms: queryTerms, queryEmbedding: queryEmbedding, configuration: configuration)
            rankedNotes = rankNotesWithSemantics(notes, queryTerms: queryTerms, queryEmbedding: queryEmbedding, configuration: configuration)
        } else {
            // Use traditional keyword-only ranking
            rankedSTM = rankMemoriesByRelevance(shortTermMemories, queryTerms: queryTerms, configuration: configuration)
            rankedLTM = rankMemoriesByRelevance(longTermMemories, queryTerms: queryTerms, configuration: configuration)
            rankedEpisodic = rankEpisodicMemoriesByRelevance(episodicMemories, queryTerms: queryTerms, configuration: configuration)
            rankedEntities = rankEntitiesByRelevance(entities, queryTerms: queryTerms)
            rankedNotes = rankNotesByRelevance(notes, queryTerms: queryTerms, configuration: configuration)
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("Memory retrieval completed in \(processingTime)s - STM: \(rankedSTM.count), LTM: \(rankedLTM.count), Episodic: \(rankedEpisodic.count), Entities: \(rankedEntities.count), Notes: \(rankedNotes.count)")
        
        return MemoryContext(
            timestamp: Date(),
            userQuery: query,
            containsPersonalData: containsPersonalData,
            contextData: [
                "entities": "\(rankedEntities.count) entities",
                "relationships": "\(relationships.count) relationships",
                "shortTermMemories": "\(rankedSTM.count) STM entries",
                "longTermMemories": "\(rankedLTM.count) LTM entries",
                "episodicMemories": "\(rankedEpisodic.count) episodic memories",
                "relevantNotes": "\(rankedNotes.count) relevant notes"
            ]
        )
    }
    
    // MARK: - Memory Type Retrieval
    
    private func retrieveShortTermMemories(queryTerms: [String], limit: Int) async throws -> [STMEntry] {
        guard !queryTerms.isEmpty else { return [] }
        
        if let predicate = buildSTMSearchPredicate(queryTerms: queryTerms) {
            // Use SwiftData predicate for simple queries
            var descriptor = FetchDescriptor<STMEntry>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } else {
            // Fall back to in-memory filtering for complex queries
            let allMemories = try modelContext.fetch(FetchDescriptor<STMEntry>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            ))
            
            let searchTerms = queryTerms.map { $0.lowercased() }
            let filteredMemories = allMemories.filter { memory in
                searchTerms.contains { term in
                    memory.content.localizedLowercase.contains(term)
                }
            }
            
            return Array(filteredMemories.prefix(limit))
        }
    }
    
    private func retrieveLongTermMemories(queryTerms: [String], limit: Int) async throws -> [LTMEntry] {
        guard !queryTerms.isEmpty else { return [] }
        
        if let predicate = buildLTMSearchPredicate(queryTerms: queryTerms) {
            // Use SwiftData predicate for simple queries
            var descriptor = FetchDescriptor<LTMEntry>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } else {
            // Fall back to in-memory filtering for complex queries
            let allMemories = try modelContext.fetch(FetchDescriptor<LTMEntry>(
                sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
            ))
            
            let searchTerms = queryTerms.map { $0.lowercased() }
            let filteredMemories = allMemories.filter { memory in
                searchTerms.contains { term in
                    memory.content.localizedLowercase.contains(term) ||
                    memory.summary.localizedLowercase.contains(term)
                }
            }
            
            return Array(filteredMemories.prefix(limit))
        }
    }
    
    private func retrieveEpisodicMemories(queryTerms: [String], limit: Int) async throws -> [EpisodicMemoryEntry] {
        guard !queryTerms.isEmpty else { return [] }
        
        if let predicate = buildEpisodicSearchPredicate(queryTerms: queryTerms) {
            // Use SwiftData predicate for simple queries
            var descriptor = FetchDescriptor<EpisodicMemoryEntry>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } else {
            // Fall back to in-memory filtering for complex queries
            let allMemories = try modelContext.fetch(FetchDescriptor<EpisodicMemoryEntry>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            ))
            
            let searchTerms = queryTerms.map { $0.lowercased() }
            let filteredMemories = allMemories.filter { memory in
                searchTerms.contains { term in
                    memory.eventDescription.localizedLowercase.contains(term)
                }
            }
            
            return Array(filteredMemories.prefix(limit))
        }
    }
    
    private func retrieveRelevantEntities(queryTerms: [String], limit: Int) async throws -> [Entity] {
        guard !queryTerms.isEmpty else { return [] }
        
        if let predicate = buildEntitySearchPredicate(queryTerms: queryTerms) {
            // Use SwiftData predicate for simple queries
            var descriptor = FetchDescriptor<Entity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } else {
            // Fall back to in-memory filtering for complex queries
            let allEntities = try modelContext.fetch(FetchDescriptor<Entity>(
                sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
            ))
            
            let searchTerms = queryTerms.map { $0.lowercased() }
            let filteredEntities = allEntities.filter { entity in
                searchTerms.contains { term in
                    entity.name.localizedLowercase.contains(term)
                }
            }
            
            return Array(filteredEntities.prefix(limit))
        }
    }
    
    private func retrieveRelevantRelationships(queryTerms: [String], limit: Int) async throws -> [Relationship] {
        var descriptor = FetchDescriptor<Relationship>(
            sortBy: [SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    private func retrieveRelevantNotes(queryTerms: [String], limit: Int) async throws -> [ProcessedNote] {
        guard !queryTerms.isEmpty else { return [] }
        
        if let predicate = buildNoteSearchPredicate(queryTerms: queryTerms) {
            // Use SwiftData predicate for simple queries
            var descriptor = FetchDescriptor<ProcessedNote>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            return try modelContext.fetch(descriptor)
        } else {
            // Fall back to in-memory filtering for complex queries
            let allNotes = try modelContext.fetch(FetchDescriptor<ProcessedNote>(
                sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
            ))
            
            let searchTerms = queryTerms.map { $0.lowercased() }
            let filteredNotes = allNotes.filter { note in
                searchTerms.contains { term in
                    note.originalText.localizedLowercase.contains(term) || 
                    note.summary.localizedLowercase.contains(term)
                }
            }
            
            return Array(filteredNotes.prefix(limit))
        }
    }
    
    // MARK: - Search Predicate Building
    
    private func buildSTMSearchPredicate(queryTerms: [String]) -> Predicate<STMEntry>? {
        guard !queryTerms.isEmpty else { return nil }
        
        let searchTerms = queryTerms.map { $0.lowercased() }
        
        if searchTerms.count == 1 {
            let term = searchTerms[0]
            return #Predicate<STMEntry> { memory in
                memory.content.contains(term)
            }
        } else if searchTerms.count == 2 {
            let term1 = searchTerms[0]
            let term2 = searchTerms[1]
            return #Predicate<STMEntry> { memory in
                memory.content.contains(term1) || memory.content.contains(term2)
            }
        } else {
            return nil // Fall back to in-memory filtering
        }
    }
    
    private func buildLTMSearchPredicate(queryTerms: [String]) -> Predicate<LTMEntry>? {
        guard !queryTerms.isEmpty else { return nil }
        
        let searchTerms = queryTerms.map { $0.lowercased() }
        
        if searchTerms.count == 1 {
            let term = searchTerms[0]
            return #Predicate<LTMEntry> { memory in
                memory.content.contains(term) || memory.summary.contains(term)
            }
        } else if searchTerms.count == 2 {
            let term1 = searchTerms[0]
            let term2 = searchTerms[1]
            return #Predicate<LTMEntry> { memory in
                memory.content.contains(term1) || memory.summary.contains(term1) ||
                memory.content.contains(term2) || memory.summary.contains(term2)
            }
        } else {
            return nil // Fall back to in-memory filtering
        }
    }
    
    private func buildEpisodicSearchPredicate(queryTerms: [String]) -> Predicate<EpisodicMemoryEntry>? {
        guard !queryTerms.isEmpty else { return nil }
        
        let searchTerms = queryTerms.map { $0.lowercased() }
        
        if searchTerms.count == 1 {
            let term = searchTerms[0]
            return #Predicate<EpisodicMemoryEntry> { memory in
                memory.eventDescription.contains(term)
            }
        } else if searchTerms.count == 2 {
            let term1 = searchTerms[0]
            let term2 = searchTerms[1]
            return #Predicate<EpisodicMemoryEntry> { memory in
                memory.eventDescription.contains(term1) || memory.eventDescription.contains(term2)
            }
        } else {
            return nil // Fall back to in-memory filtering
        }
    }
    
    private func buildEntitySearchPredicate(queryTerms: [String]) -> Predicate<Entity>? {
        guard !queryTerms.isEmpty else { return nil }
        
        // Create individual predicates for each term and combine with OR to avoid subquery
        let searchTerms = queryTerms.map { $0.lowercased() }
        
        // Build a compound predicate with OR conditions for each search term
        if searchTerms.count == 1 {
            let term = searchTerms[0]
            return #Predicate<Entity> { entity in
                entity.name.contains(term)
            }
        } else if searchTerms.count == 2 {
            let term1 = searchTerms[0]
            let term2 = searchTerms[1]
            return #Predicate<Entity> { entity in
                entity.name.contains(term1) || entity.name.contains(term2)
            }
        } else {
            // For more than 2 terms, fall back to in-memory filtering
            return nil // This will cause the method to fetch all and filter in-memory
        }
    }
    
    
    private func buildNoteSearchPredicate(queryTerms: [String]) -> Predicate<ProcessedNote>? {
        guard !queryTerms.isEmpty else { return nil }
        
        // Create individual predicates for each term and combine with OR
        let searchTerms = queryTerms.map { $0.lowercased() }
        
        // Build a compound predicate with OR conditions for each search term
        if searchTerms.count == 1 {
            let term = searchTerms[0]
            return #Predicate<ProcessedNote> { note in
                note.originalText.contains(term) || note.summary.contains(term)
            }
        } else if searchTerms.count == 2 {
            let term1 = searchTerms[0]
            let term2 = searchTerms[1]
            return #Predicate<ProcessedNote> { note in
                note.originalText.contains(term1) || note.summary.contains(term1) ||
                note.originalText.contains(term2) || note.summary.contains(term2)
            }
        } else {
            // For more than 2 terms, fall back to in-memory filtering
            return nil // This will cause the method to fetch all and filter in-memory
        }
    }
    
    // MARK: - Ranking and Scoring
    
    private func rankMemoriesByRelevance<T: AnyObject>(_ memories: [T], queryTerms: [String], configuration: RetrievalConfiguration) -> [T] {
        let scoredMemories = memories.map { memory in
            (memory: memory, score: calculateRelevanceScore(for: memory, queryTerms: queryTerms, configuration: configuration))
        }
        
        return scoredMemories
            .filter { $0.score >= configuration.semanticThreshold }
            .sorted { $0.score > $1.score }
            .map { $0.memory }
    }
    
    private func rankEpisodicMemoriesByRelevance(_ memories: [EpisodicMemoryEntry], queryTerms: [String], configuration: RetrievalConfiguration) -> [EpisodicMemoryEntry] {
        let scoredMemories = memories.map { memory in
            (memory: memory, score: calculateEpisodicRelevanceScore(for: memory, queryTerms: queryTerms, configuration: configuration))
        }
        
        return scoredMemories
            .filter { $0.score >= configuration.semanticThreshold }
            .sorted { $0.score > $1.score }
            .map { $0.memory }
    }
    
    private func rankEntitiesByRelevance(_ entities: [Entity], queryTerms: [String]) -> [Entity] {
        let scoredEntities = entities.map { entity in
            (entity: entity, score: calculateEntityRelevanceScore(for: entity, queryTerms: queryTerms))
        }
        
        return scoredEntities
            .sorted { $0.score > $1.score }
            .map { $0.entity }
    }
    
    private func rankNotesByRelevance(_ notes: [ProcessedNote], queryTerms: [String], configuration: RetrievalConfiguration) -> [ProcessedNote] {
        let scoredNotes = notes.map { note in
            (note: note, score: calculateNoteRelevanceScore(for: note, queryTerms: queryTerms, configuration: configuration))
        }
        
        return scoredNotes
            .filter { $0.score >= configuration.semanticThreshold }
            .sorted { $0.score > $1.score }
            .map { $0.note }
    }
    
    // MARK: - Scoring Algorithms
    
    private func calculateRelevanceScore<T: AnyObject>(for memory: T, queryTerms: [String], configuration: RetrievalConfiguration) -> Double {
        var score = 0.0
        
        // Content relevance
        let content = extractContentForScoring(from: memory)
        score += calculateTextRelevanceScore(content: content, queryTerms: queryTerms) * configuration.relevanceWeight
        
        // Recency score
        if let timestamp = extractTimestampForScoring(from: memory) {
            let daysSinceCreation = Date().timeIntervalSince(timestamp) / (24 * 60 * 60)
            let recencyScore = max(0, 1.0 - (daysSinceCreation / 30.0)) // Decay over 30 days
            score += recencyScore * configuration.recencyWeight
        }
        
        return min(1.0, score)
    }
    
    private func calculateEpisodicRelevanceScore(for memory: EpisodicMemoryEntry, queryTerms: [String], configuration: RetrievalConfiguration) -> Double {
        var score = 0.0
        
        // Event description relevance
        score += calculateTextRelevanceScore(content: memory.eventDescription, queryTerms: queryTerms) * configuration.relevanceWeight
        
        // Participants relevance
        let participantsContent = memory.participants.joined(separator: " ")
        score += calculateTextRelevanceScore(content: participantsContent, queryTerms: queryTerms) * 0.3
        
        // Contextual cues relevance
        let contextualContent = memory.contextualCues.joined(separator: " ")
        score += calculateTextRelevanceScore(content: contextualContent, queryTerms: queryTerms) * 0.3
        
        // Location relevance
        if let location = memory.location {
            score += calculateTextRelevanceScore(content: location, queryTerms: queryTerms) * 0.2
        }
        
        // Recency score
        let daysSinceEvent = Date().timeIntervalSince(memory.timestamp) / (24 * 60 * 60)
        let recencyScore = max(0, 1.0 - (daysSinceEvent / 60.0)) // Decay over 60 days
        score += recencyScore * configuration.recencyWeight
        
        return min(1.0, score)
    }
    
    private func calculateEntityRelevanceScore(for entity: Entity, queryTerms: [String]) -> Double {
        var score = 0.0
        
        // Name relevance (higher weight)
        score += calculateTextRelevanceScore(content: entity.name, queryTerms: queryTerms) * 0.8
        
        // Description relevance
        if let description = entity.entityDescription {
            score += calculateTextRelevanceScore(content: description, queryTerms: queryTerms) * 0.4
        }
        
        // Type relevance
        score += calculateTextRelevanceScore(content: entity.type.rawValue, queryTerms: queryTerms) * 0.3
        
        // Aliases relevance
        let aliasesContent = entity.aliases.joined(separator: " ")
        score += calculateTextRelevanceScore(content: aliasesContent, queryTerms: queryTerms) * 0.3
        
        // Tags relevance
        let tagsContent = entity.tags.joined(separator: " ")
        score += calculateTextRelevanceScore(content: tagsContent, queryTerms: queryTerms) * 0.2
        
        return min(1.0, score)
    }
    
    private func calculateNoteRelevanceScore(for note: ProcessedNote, queryTerms: [String], configuration: RetrievalConfiguration) -> Double {
        var score = 0.0
        
        // Original text relevance
        score += calculateTextRelevanceScore(content: note.originalText, queryTerms: queryTerms) * configuration.relevanceWeight
        
        // Summary relevance
        score += calculateTextRelevanceScore(content: note.summary, queryTerms: queryTerms) * 0.4
        
        // Topics relevance
        let topicsContent = note.topics.joined(separator: " ")
        score += calculateTextRelevanceScore(content: topicsContent, queryTerms: queryTerms) * 0.3
        
        // Keywords relevance
        let keywordsContent = note.extractedKeywords.joined(separator: " ")
        score += calculateTextRelevanceScore(content: keywordsContent, queryTerms: queryTerms) * 0.3
        
        // Recency score
        let daysSinceModified = Date().timeIntervalSince(note.lastAccessed) / (24 * 60 * 60)
        let recencyScore = max(0, 1.0 - (daysSinceModified / 30.0)) // Decay over 30 days
        score += recencyScore * configuration.recencyWeight
        
        return min(1.0, score)
    }
    
    private func calculateTextRelevanceScore(content: String, queryTerms: [String]) -> Double {
        let lowercaseContent = content.lowercased()
        let words = lowercaseContent.components(separatedBy: .whitespacesAndNewlines)
        var matchCount = 0
        
        for term in queryTerms {
            let termLower = term.lowercased()
            // Exact match
            if words.contains(termLower) {
                matchCount += 2
            }
            // Partial match
            else if lowercaseContent.contains(termLower) {
                matchCount += 1
            }
        }
        
        return Double(matchCount) / Double(queryTerms.count * 2)
    }
    
    // MARK: - Utility Methods
    
    private func extractQueryTerms(from query: String) -> [String] {
        // Simple tokenization - could be enhanced with NLP
        let words = query.components(separatedBy: .whitespacesAndNewlines)
        return words
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 } // Filter out short words
            .map { $0.lowercased() }
    }
    
    private func detectPersonalData(in query: String) -> Bool {
        let personalIndicators = ["my", "i", "me", "mine", "myself", "personal", "remember", "recall"]
        let lowercaseQuery = query.lowercased()
        return personalIndicators.contains { lowercaseQuery.contains($0) }
    }
    
    private func extractContentForScoring<T: AnyObject>(from memory: T) -> String {
        switch memory {
        case let stm as STMEntry:
            return stm.content
        case let ltm as LTMEntry:
            return "\(ltm.content) \(ltm.summary)"
        case let episodic as EpisodicMemoryEntry:
            return episodic.eventDescription
        default:
            return ""
        }
    }
    
    private func extractTimestampForScoring<T: AnyObject>(from memory: T) -> Date? {
        switch memory {
        case let stm as STMEntry:
            return stm.timestamp
        case let ltm as LTMEntry:
            return ltm.lastAccessed
        case let episodic as EpisodicMemoryEntry:
            return episodic.timestamp
        default:
            return nil
        }
    }
    
    // MARK: - Semantic Search Methods
    
    /// Generate embedding for a query if semantic search is enabled
    private func generateQueryEmbedding(_ query: String, configuration: RetrievalConfiguration) async -> [Float]? {
        guard configuration.enableSemanticSearch,
              let embeddingProvider = embeddingProvider else {
            return nil
        }
        
        do {
            // Ensure model is loaded
            let isLoaded = await MainActor.run { 
                if case .ready = embeddingProvider.modelLoadingStatus {
                    return true
                } else {
                    return false
                }
            }
            if !isLoaded {
                try await embeddingProvider.prepareModel()
            }
            
            let embedding = try await embeddingProvider.generateEmbedding(text: query, modelId: "default")
            logger.debug("Generated query embedding with \(embedding.count) dimensions")
            
            return embedding
        } catch {
            logger.error("Failed to generate query embedding: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Calculate hybrid relevance score combining keyword and semantic similarity
    private func calculateHybridRelevanceScore(
        keywordScore: Double,
        semanticScore: Float,
        configuration: RetrievalConfiguration
    ) -> Double {
        let keywordWeighted = keywordScore * configuration.keywordWeight
        let semanticWeighted = Double(semanticScore) * configuration.semanticWeight
        
        return keywordWeighted + semanticWeighted
    }
    
    /// Enhanced ranking with semantic similarity for general memory types
    private func rankMemoriesWithSemantics<T: AnyObject>(
        _ memories: [T],
        queryTerms: [String],
        queryEmbedding: [Float]?,
        configuration: RetrievalConfiguration
    ) -> [T] where T: EmbeddingCapable {
        
        let scoredMemories = memories.map { memory in
            // Calculate keyword-based score
            let keywordScore = calculateRelevanceScore(for: memory, queryTerms: queryTerms, configuration: configuration)
            
            // Calculate semantic score if embedding available
            var semanticScore: Float = 0.0
            if let queryEmb = queryEmbedding,
               let memoryEmb = memory.getEmbedding() {
                semanticScore = EmbeddingUtils.semanticSimilarityScore(queryEmb, memoryEmb)
            }
            
            // Combine scores
            let hybridScore = calculateHybridRelevanceScore(
                keywordScore: keywordScore,
                semanticScore: semanticScore,
                configuration: configuration
            )
            
            return (memory: memory, hybridScore: hybridScore)
        }
        
        return scoredMemories
            .filter { $0.hybridScore >= Double(configuration.semanticThreshold) }
            .sorted { $0.hybridScore > $1.hybridScore }
            .map { $0.memory }
    }
    
    /// Enhanced entity ranking with semantic similarity
    private func rankEntitiesWithSemantics(
        _ entities: [Entity],
        queryTerms: [String],
        queryEmbedding: [Float]?,
        configuration: RetrievalConfiguration
    ) -> [Entity] {
        
        let scoredEntities = entities.map { entity in
            // Calculate keyword-based score
            let keywordScore = calculateEntityRelevanceScore(for: entity, queryTerms: queryTerms)
            
            // Calculate semantic score if embedding available
            var semanticScore: Float = 0.0
            if let queryEmb = queryEmbedding,
               let entityEmb = entity.getEmbedding() {
                semanticScore = EmbeddingUtils.semanticSimilarityScore(queryEmb, entityEmb)
            }
            
            // Combine scores
            let hybridScore = calculateHybridRelevanceScore(
                keywordScore: keywordScore,
                semanticScore: semanticScore,
                configuration: configuration
            )
            
            return (entity: entity, hybridScore: hybridScore)
        }
        
        return scoredEntities
            .filter { $0.hybridScore >= Double(configuration.semanticSimilarityThreshold) }
            .sorted { $0.hybridScore > $1.hybridScore }
            .map { $0.entity }
    }
    
    /// Enhanced note ranking with semantic similarity
    private func rankNotesWithSemantics(
        _ notes: [ProcessedNote],
        queryTerms: [String],
        queryEmbedding: [Float]?,
        configuration: RetrievalConfiguration
    ) -> [ProcessedNote] {
        
        let scoredNotes = notes.map { note in
            // Calculate keyword-based score
            let keywordScore = calculateNoteRelevanceScore(for: note, queryTerms: queryTerms, configuration: configuration)
            
            // Calculate semantic score if embedding available
            var semanticScore: Float = 0.0
            if let queryEmb = queryEmbedding,
               let noteEmb = note.getEmbedding() {
                semanticScore = EmbeddingUtils.semanticSimilarityScore(queryEmb, noteEmb)
            }
            
            // Combine scores
            let hybridScore = calculateHybridRelevanceScore(
                keywordScore: keywordScore,
                semanticScore: semanticScore,
                configuration: configuration
            )
            
            return (note: note, hybridScore: hybridScore)
        }
        
        return scoredNotes
            .filter { $0.hybridScore >= Double(configuration.semanticSimilarityThreshold) }
            .sorted { $0.hybridScore > $1.hybridScore }
            .map { $0.note }
    }
}