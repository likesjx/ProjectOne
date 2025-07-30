//
//  RealTimeMemoryService.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/29/25.
//

import Foundation
import SwiftData
import Combine
import os.log

/// Real-time memory retrieval service for enhanced note creation
@MainActor
public class RealTimeMemoryService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentContext: MemoryContext?
    @Published public var isLoading = false
    @Published public var lastQuery = ""
    @Published public var queryLatency: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private let memoryRetrievalEngine: MemoryRetrievalEngine
    private let embeddingGenerationService: EmbeddingGenerationService?
    private let privacyAnalyzer = PrivacyAnalyzer()
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "RealTimeMemoryService")
    
    private var searchCancellable: AnyCancellable?
    private let searchSubject = PassthroughSubject<String, Never>()
    
    // Configuration
    private let debounceInterval: TimeInterval = 0.3 // 300ms debounce
    private let maxContextTokens = 8000 // Conservative token limit
    private let cacheTimeout: TimeInterval = 60 // 1 minute cache
    
    // Cache for frequently accessed contexts
    private var contextCache: [String: CachedContext] = [:]
    
    // MARK: - Initialization
    
    public init(
        modelContext: ModelContext,
        embeddingProvider: MLXEmbeddingProvider? = nil,
        embeddingGenerationService: EmbeddingGenerationService? = nil
    ) {
        self.memoryRetrievalEngine = MemoryRetrievalEngine(
            modelContext: modelContext,
            embeddingProvider: embeddingProvider,
            embeddingService: embeddingGenerationService
        )
        self.embeddingGenerationService = embeddingGenerationService
        setupDebouncedSearch()
        logger.info("RealTimeMemoryService initialized with semantic search: \(embeddingProvider != nil)")
    }
    
    // MARK: - Public Methods
    
    /// Trigger memory retrieval for the given query with debouncing
    public func queryMemory(_ query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearContext()
            return
        }
        
        lastQuery = query
        searchSubject.send(query)
    }
    
    /// Force immediate memory retrieval without debouncing
    public func queryMemoryImmediate(_ query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clearContext()
            return
        }
        
        await performMemoryRetrieval(query: query)
    }
    
    /// Clear current memory context
    public func clearContext() {
        currentContext = nil
        lastQuery = ""
        isLoading = false
    }
    
    /// Get suggested entities based on current context
    public func getSuggestedEntities() -> [Entity] {
        guard let context = currentContext else {
            return []
        }
        return Array(context.typedEntities.prefix(5)) // Return top 5 suggestions
    }
    
    /// Get suggested relationships for entity linking
    public func getSuggestedRelationships() -> [Relationship] {
        guard let context = currentContext else {
            return []
        }
        return Array(context.typedRelationships.prefix(3)) // Return top 3 suggestions
    }
    
    /// Generate embedding for new content in real-time
    public func generateEmbeddingForContent<T>(_ content: T) async throws where T: EmbeddingCapable {
        guard let embeddingService = embeddingGenerationService else {
            logger.warning("Embedding generation service not available")
            return
        }
        
        do {
            logger.debug("Generating real-time embedding for content")
            let _ = try await embeddingService.generateEmbedding(for: content)
            logger.debug("Successfully generated real-time embedding")
        } catch {
            logger.error("Failed to generate real-time embedding: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Check if semantic search is available
    public var isSemanticSearchAvailable: Bool {
        return embeddingGenerationService != nil
    }
    
    // MARK: - Private Methods
    
    private func setupDebouncedSearch() {
        searchCancellable = searchSubject
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                Task {
                    await self?.performMemoryRetrieval(query: query)
                }
            }
    }
    
    private func performMemoryRetrieval(query: String) async {
        let startTime = Date()
        isLoading = true
        
        defer {
            queryLatency = Date().timeIntervalSince(startTime)
            isLoading = false
        }
        
        do {
            // Check cache first
            if let cachedContext = getCachedContext(for: query) {
                logger.debug("Using cached context for query: '\(query.prefix(50))...'")
                currentContext = cachedContext.context
                return
            }
            
            // Analyze privacy level to determine retrieval configuration
            let privacyAnalysis = privacyAnalyzer.analyzePrivacy(query: query)
            let retrievalConfig = buildRetrievalConfiguration(for: privacyAnalysis)
            
            logger.info("Retrieving memory context for query: '\(query.prefix(50))...' (Privacy: \(privacyAnalysis.level.description))")
            
            // Retrieve memory context with additional error handling
            let context: MemoryContext
            do {
                context = try await memoryRetrievalEngine.retrieveRelevantMemories(
                    for: query,
                    configuration: retrievalConfig
                )
            } catch {
                logger.error("Memory retrieval engine failed: \(error.localizedDescription)")
                // Create empty context as fallback
                context = MemoryContext(
                    timestamp: Date(),
                    userQuery: query,
                    containsPersonalData: false,
                    contextData: [:]
                )
            }
            
            // Filter context based on privacy level if needed
            let filteredContext = privacyAnalysis.requiresFiltering 
                ? filterContextForPrivacy(context, analysis: privacyAnalysis)
                : context
            
            // Cache the result
            cacheContext(filteredContext, for: query)
            
            // Update published property
            currentContext = filteredContext
            
            // Trigger background embedding generation for items that need it
            await triggerBackgroundEmbeddingGeneration(for: filteredContext)
            
            logger.info("Memory retrieval completed in \(self.queryLatency)s - Context size: \(self.estimateContextTokens(filteredContext)) tokens")
            
        } catch {
            logger.error("Memory retrieval failed: \(error.localizedDescription)")
            // Provide an empty context instead of nil to prevent UI issues
            currentContext = MemoryContext(
                timestamp: Date(),
                userQuery: query,
                containsPersonalData: false,
                contextData: [:]
            )
        }
    }
    
    private func buildRetrievalConfiguration(for analysis: PrivacyAnalyzer.PrivacyAnalysis) -> MemoryRetrievalEngine.RetrievalConfiguration {
        switch analysis.level {
        case .publicKnowledge:
            return .default
            
        case .contextual:
            return MemoryRetrievalEngine.RetrievalConfiguration(
                maxResults: 12,
                recencyWeight: 0.4,
                relevanceWeight: 0.6,
                semanticThreshold: 0.4,
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
            
        case .personal:
            return .personalFocus
            
        case .sensitive:
            // Minimal retrieval for sensitive queries - prefer keyword-only for privacy
            return MemoryRetrievalEngine.RetrievalConfiguration(
                maxResults: 6,
                recencyWeight: 0.5,
                relevanceWeight: 0.5,
                semanticThreshold: 0.6,
                includeSTM: true,
                includeLTM: false,
                includeEpisodic: true,
                includeEntities: false,
                includeNotes: true,
                enableSemanticSearch: false, // Disable semantic search for sensitive queries
                semanticWeight: 0.0,
                keywordWeight: 1.0,
                semanticSimilarityThreshold: 0.0,
                embeddingMaxAge: 0
            )
        }
    }
    
    private func filterContextForPrivacy(_ context: MemoryContext, analysis: PrivacyAnalyzer.PrivacyAnalysis) -> MemoryContext {
        var filteredData = context.contextData
        
        // Remove or sanitize sensitive data based on privacy level
        switch analysis.level {
        case .contextual, .personal:
            // Limit token count and remove low-confidence items
            if let entities = filteredData["entities"] as? [Entity] {
                filteredData["entities"] = Array(entities.prefix(5))
            }
            if let relationships = filteredData["relationships"] as? [Relationship] {
                filteredData["relationships"] = Array(relationships.prefix(3))
            }
            
        case .sensitive:
            // Minimal context for sensitive queries
            filteredData["entities"] = []
            filteredData["relationships"] = []
            if let stm = filteredData["shortTermMemories"] as? [STMEntry] {
                filteredData["shortTermMemories"] = Array(stm.prefix(2))
            }
            
        case .publicKnowledge:
            break // No filtering needed
        }
        
        return MemoryContext(
            timestamp: context.timestamp,
            userQuery: context.userQuery,
            containsPersonalData: context.containsPersonalData,
            contextData: filteredData
        )
    }
    
    // MARK: - Caching
    
    private func getCachedContext(for query: String) -> CachedContext? {
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let cached = contextCache[cacheKey],
              Date().timeIntervalSince(cached.timestamp) < cacheTimeout else {
            return nil
        }
        
        return cached
    }
    
    private func cacheContext(_ context: MemoryContext, for query: String) {
        let cacheKey = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        contextCache[cacheKey] = CachedContext(context: context, timestamp: Date())
        
        // Clean up old cache entries
        cleanupCache()
    }
    
    private func cleanupCache() {
        let cutoffTime = Date().addingTimeInterval(-cacheTimeout * 2)
        contextCache = contextCache.filter { $0.value.timestamp > cutoffTime }
    }
    
    // MARK: - Utility Methods
    
    private func estimateContextTokens(_ context: MemoryContext) -> Int {
        var tokenCount = 0
        
        // Rough token estimation (1 token ≈ 4 characters)
        tokenCount += context.userQuery.count / 4
        
        if let stm = context.contextData["shortTermMemories"] as? [STMEntry] {
            tokenCount += stm.reduce(0) { $0 + $1.content.count / 4 }
        }
        
        if let ltm = context.contextData["longTermMemories"] as? [LTMEntry] {
            tokenCount += ltm.reduce(0) { $0 + ($1.content.count + $1.summary.count) / 4 }
        }
        
        if let episodic = context.contextData["episodicMemories"] as? [EpisodicMemoryEntry] {
            tokenCount += episodic.reduce(0) { $0 + $1.eventDescription.count / 4 }
        }
        
        if let entities = context.contextData["entities"] as? [Entity] {
            tokenCount += entities.reduce(0) { $0 + ($1.name.count + ($1.entityDescription?.count ?? 0)) / 4 }
        }
        
        return tokenCount
    }
    
    /// Trigger background embedding generation for items that need updates
    private func triggerBackgroundEmbeddingGeneration(for context: MemoryContext) async {
        guard let embeddingService = embeddingGenerationService else {
            return
        }
        
        let currentModelVersion = embeddingService.modelVersion
        
        // Don't block the main thread - run in background
        Task.detached { [weak embeddingService, logger] in
            do {
                // Check and generate embeddings for different content types
                await MainActor.run {
                    logger.debug("Checking for items needing embedding updates in background")
                }
                
                // Check STM entries
                for stm in context.typedShortTermMemories {
                    if stm.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 7 * 24 * 3600) {
                        try? await embeddingService?.generateEmbedding(for: stm)
                    }
                }
                
                // Check LTM entries
                for ltm in context.typedLongTermMemories {
                    if ltm.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 14 * 24 * 3600) {
                        try? await embeddingService?.generateEmbedding(for: ltm)
                    }
                }
                
                // Check episodic memories
                for episodic in context.typedEpisodicMemories {
                    if episodic.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 30 * 24 * 3600) {
                        try? await embeddingService?.generateEmbedding(for: episodic)
                    }
                }
                
                // Check entities
                for entity in context.typedEntities {
                    if entity.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 14 * 24 * 3600) {
                        try? await embeddingService?.generateEmbedding(for: entity)
                    }
                }
                
                // Check notes
                for note in context.typedNotes {
                    if note.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 7 * 24 * 3600) {
                        try? await embeddingService?.generateEmbedding(for: note)
                    }
                }
                
                await MainActor.run {
                    logger.debug("Background embedding generation check completed")
                }
                
            } catch {
                await MainActor.run {
                    logger.error("Background embedding generation failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Supporting Types

private struct CachedContext {
    let context: MemoryContext
    let timestamp: Date
}

// MARK: - Memory Context Extension

extension MemoryContext {
    // Convenience accessors with proper type casting
    public var typedShortTermMemories: [STMEntry] {
        return contextData["shortTermMemories"] as? [STMEntry] ?? []
    }
    
    public var typedLongTermMemories: [LTMEntry] {
        return contextData["longTermMemories"] as? [LTMEntry] ?? []
    }
    
    public var typedEpisodicMemories: [EpisodicMemoryEntry] {
        return contextData["episodicMemories"] as? [EpisodicMemoryEntry] ?? []
    }
    
    public var typedEntities: [Entity] {
        return contextData["entities"] as? [Entity] ?? []
    }
    
    public var typedRelationships: [Relationship] {
        return contextData["relationships"] as? [Relationship] ?? []
    }
    
    public var typedNotes: [ProcessedNote] {
        return contextData["relevantNotes"] as? [ProcessedNote] ?? []
    }
    
    public var isEmpty: Bool {
        return typedShortTermMemories.isEmpty && 
               typedLongTermMemories.isEmpty && 
               typedEpisodicMemories.isEmpty && 
               typedEntities.isEmpty && 
               typedRelationships.isEmpty && 
               typedNotes.isEmpty
    }
}