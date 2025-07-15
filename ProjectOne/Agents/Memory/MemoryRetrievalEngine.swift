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
public class MemoryRetrievalEngine: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryRetrievalEngine")
    private let modelContext: ModelContext
    
    // MARK: - Configuration
    
    public struct RetrievalConfiguration {
        let maxResults: Int
        let recencyWeight: Double // 0.0 to 1.0
        let relevanceWeight: Double // 0.0 to 1.0
        let semanticThreshold: Double // 0.0 to 1.0
        let includeSTM: Bool
        let includeLTM: Bool
        let includeEpisodic: Bool
        let includeEntities: Bool
        let includeNotes: Bool
        
        public static let `default` = RetrievalConfiguration(
            maxResults: 10,
            recencyWeight: 0.3,
            relevanceWeight: 0.7,
            semanticThreshold: 0.5,
            includeSTM: true,
            includeLTM: true,
            includeEpisodic: true,
            includeEntities: true,
            includeNotes: true
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
            includeNotes: true
        )
    }
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("Memory Retrieval Engine initialized")
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
        
        // Retrieve different types of memories in parallel
        async let stmResults = configuration.includeSTM ? retrieveShortTermMemories(queryTerms: queryTerms, limit: configuration.maxResults / 2) : []
        async let ltmResults = configuration.includeLTM ? retrieveLongTermMemories(queryTerms: queryTerms, limit: configuration.maxResults / 2) : []
        async let episodicResults = configuration.includeEpisodic ? retrieveEpisodicMemories(queryTerms: queryTerms, limit: configuration.maxResults / 3) : []
        async let entityResults = configuration.includeEntities ? retrieveRelevantEntities(queryTerms: queryTerms, limit: configuration.maxResults / 3) : []
        async let relationshipResults = configuration.includeEntities ? retrieveRelevantRelationships(queryTerms: queryTerms, limit: configuration.maxResults / 4) : []
        async let noteResults = configuration.includeNotes ? retrieveRelevantNotes(queryTerms: queryTerms, limit: configuration.maxResults / 3) : []
        
        // Await all results
        let shortTermMemories = try await stmResults
        let longTermMemories = try await ltmResults
        let episodicMemories = try await episodicResults
        let entities = try await entityResults
        let relationships = try await relationshipResults
        let notes = try await noteResults
        
        // Score and rank all results
        let rankedSTM = rankMemoriesByRelevance(shortTermMemories, queryTerms: queryTerms, configuration: configuration)
        let rankedLTM = rankMemoriesByRelevance(longTermMemories, queryTerms: queryTerms, configuration: configuration)
        let rankedEpisodic = rankEpisodicMemoriesByRelevance(episodicMemories, queryTerms: queryTerms, configuration: configuration)
        let rankedEntities = rankEntitiesByRelevance(entities, queryTerms: queryTerms)
        let rankedNotes = rankNotesByRelevance(notes, queryTerms: queryTerms, configuration: configuration)
        
        let processingTime = Date().timeIntervalSince(startTime)
        logger.info("Memory retrieval completed in \(processingTime)s - STM: \(rankedSTM.count), LTM: \(rankedLTM.count), Episodic: \(rankedEpisodic.count), Entities: \(rankedEntities.count), Notes: \(rankedNotes.count)")
        
        return MemoryContext(
            entities: rankedEntities,
            relationships: relationships,
            shortTermMemories: rankedSTM,
            longTermMemories: rankedLTM,
            episodicMemories: rankedEpisodic,
            relevantNotes: rankedNotes,
            timestamp: Date(),
            userQuery: query,
            containsPersonalData: containsPersonalData
        )
    }
    
    // MARK: - Memory Type Retrieval
    
    private func retrieveShortTermMemories(queryTerms: [String], limit: Int) async throws -> [STMEntry] {
        var descriptor = FetchDescriptor<STMEntry>(
            predicate: buildSearchPredicate(for: STMEntry.self, queryTerms: queryTerms),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    private func retrieveLongTermMemories(queryTerms: [String], limit: Int) async throws -> [LTMEntry] {
        var descriptor = FetchDescriptor<LTMEntry>(
            predicate: buildSearchPredicate(for: LTMEntry.self, queryTerms: queryTerms),
            sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    private func retrieveEpisodicMemories(queryTerms: [String], limit: Int) async throws -> [EpisodicMemoryEntry] {
        var descriptor = FetchDescriptor<EpisodicMemoryEntry>(
            predicate: buildSearchPredicate(for: EpisodicMemoryEntry.self, queryTerms: queryTerms),
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    private func retrieveRelevantEntities(queryTerms: [String], limit: Int) async throws -> [Entity] {
        var descriptor = FetchDescriptor<Entity>(
            predicate: buildEntitySearchPredicate(queryTerms: queryTerms),
            sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    private func retrieveRelevantRelationships(queryTerms: [String], limit: Int) async throws -> [Relationship] {
        var descriptor = FetchDescriptor<Relationship>(
            sortBy: [SortDescriptor(\.id)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    private func retrieveRelevantNotes(queryTerms: [String], limit: Int) async throws -> [ProcessedNote] {
        var descriptor = FetchDescriptor<ProcessedNote>(
            predicate: buildNoteSearchPredicate(queryTerms: queryTerms),
            sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Search Predicate Building
    
    private func buildSearchPredicate<T>(for type: T.Type, queryTerms: [String]) -> Predicate<T>? {
        guard !queryTerms.isEmpty else { return nil }
        
        switch type {
        case is STMEntry.Type:
            return buildSTMSearchPredicate(queryTerms: queryTerms) as? Predicate<T>
        case is LTMEntry.Type:
            return buildLTMSearchPredicate(queryTerms: queryTerms) as? Predicate<T>
        case is EpisodicMemoryEntry.Type:
            return buildEpisodicSearchPredicate(queryTerms: queryTerms) as? Predicate<T>
        default:
            return nil
        }
    }
    
    private func buildSTMSearchPredicate(queryTerms: [String]) -> Predicate<STMEntry>? {
        let searchTerms = queryTerms.map { $0.lowercased() }
        return #Predicate<STMEntry> { memory in
            searchTerms.contains { term in
                memory.content.contains(term)
            }
        }
    }
    
    private func buildLTMSearchPredicate(queryTerms: [String]) -> Predicate<LTMEntry>? {
        let searchTerms = queryTerms.map { $0.lowercased() }
        return #Predicate<LTMEntry> { memory in
            searchTerms.contains { term in
                memory.content.contains(term) || memory.summary.contains(term)
            }
        }
    }
    
    private func buildEpisodicSearchPredicate(queryTerms: [String]) -> Predicate<EpisodicMemoryEntry>? {
        let searchTerms = queryTerms.map { $0.lowercased() }
        return #Predicate<EpisodicMemoryEntry> { memory in
            searchTerms.contains { term in
                memory.eventDescription.contains(term)
            }
        }
    }
    
    private func buildEntitySearchPredicate(queryTerms: [String]) -> Predicate<Entity>? {
        let searchTerms = queryTerms.map { $0.lowercased() }
        return #Predicate<Entity> { entity in
            searchTerms.contains { term in
                entity.name.contains(term)
            }
        }
    }
    
    
    private func buildNoteSearchPredicate(queryTerms: [String]) -> Predicate<ProcessedNote>? {
        let searchTerms = queryTerms.map { $0.lowercased() }
        return #Predicate<ProcessedNote> { note in
            searchTerms.contains { term in
                note.originalText.contains(term) || note.summary.contains(term)
            }
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
}