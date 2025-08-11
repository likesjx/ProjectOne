//
//  RealTimeMemoryService.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/29/25.
//

import Foundation
import SwiftData
import SwiftUI
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
        
        // Capture service reference to avoid data races
        let service = embeddingService
        
        do {
            logger.debug("Generating real-time embedding for content")
            let _ = try await service.generateEmbedding(for: content)
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
            
            // Retrieve memory context with additional error handling - ensure it stays on MainActor
            let context: MemoryContext
            do {
                // Retrieve context directly since we're already on MainActor
                context = try await withCheckedThrowingContinuation { continuation in
                    Task {
                        do {
                            let result = try await memoryRetrievalEngine.retrieveRelevantMemories(
                                for: query,
                                configuration: retrievalConfig
                            )
                            continuation.resume(returning: result)
                        } catch {
                            logger.error("Memory retrieval engine failed: \(error.localizedDescription)")
                            // Create empty context as fallback
                            let fallbackContext = MemoryContext(
                                timestamp: Date(),
                                userQuery: query,
                                containsPersonalData: false,
                                contextData: [:]
                            )
                            continuation.resume(returning: fallbackContext)
                        }
                    }
                }
            }
            
            // Filter context based on privacy level if needed
            let filteredContext = privacyAnalysis.requiresFiltering 
                ? filterContextForPrivacy(context, analysis: privacyAnalysis)
                : context
            
            // Cache the result
            cacheContext(filteredContext, for: query)
            
            // Update published property
            currentContext = filteredContext
            
            logger.info("Memory retrieval completed in \(self.queryLatency)s - Context size: \(self.estimateContextTokens(filteredContext)) tokens")
            
            // Trigger background embedding generation for items that need it (outside try-catch since it doesn't throw)
            await triggerBackgroundEmbeddingGeneration(for: filteredContext)
            
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
            // Keep essential context but limit details
            filteredData["context_level"] = "limited"
            
        case .sensitive:
            // Minimal context for sensitive queries
            filteredData = ["query_type": analysis.level.rawValue]
            
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
        
        // Estimate tokens from context data using string descriptions
        for (_, value) in context.contextData {
            tokenCount += value.count / 4 // Rough estimation based on string length
        }
        
        return tokenCount
    }
    
    /// Trigger background embedding generation for items that need updates
    private func triggerBackgroundEmbeddingGeneration(for context: MemoryContext) async {
        guard let service = embeddingGenerationService else {
            return
        }
        
        let currentModelVersion = service.modelVersion
        
        // Don't block the main thread - run in background
        Task.detached { [logger, service] in
            // Use the captured service directly (it's already non-optional)
            let capturedService = service
            // Check and generate embeddings for different content types
            let _ = await MainActor.run {
                logger.debug("Checking for items needing embedding updates in background")
            }
            
            // Check STM entries - process in MainActor to avoid data races
            let _ = await MainActor.run {
                Task {
                    for stm in context.typedShortTermMemories {
                        if stm.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 7 * 24 * 3600) {
                            let _ = try? await capturedService.generateEmbedding(for: stm)
                        }
                    }
                }
            }
            
            // Check LTM entries - process in MainActor to avoid data races
            let _ = await MainActor.run {
                Task {
                    for ltm in context.typedLongTermMemories {
                        if ltm.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 14 * 24 * 3600) {
                            let _ = try? await capturedService.generateEmbedding(for: ltm)
                        }
                    }
                }
            }
            
            // Check episodic memories - process in MainActor to avoid data races
            let _ = await MainActor.run {
                Task {
                    for episodic in context.typedEpisodicMemories {
                        if episodic.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 30 * 24 * 3600) {
                            let _ = try? await capturedService.generateEmbedding(for: episodic)
                        }
                    }
                }
            }
            
            // Check entities - process in MainActor to avoid data races
            let _ = await MainActor.run {
                Task {
                    for entity in context.typedEntities {
                        if entity.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 14 * 24 * 3600) {
                            let _ = try? await capturedService.generateEmbedding(for: entity)
                        }
                    }
                }
            }
            
            // Check notes - process in MainActor to avoid data races
            let _ = await MainActor.run {
                Task {
                    for note in context.typedNotes {
                        if note.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 7 * 24 * 3600) {
                            let _ = try? await capturedService.generateEmbedding(for: note)
                        }
                    }
                }
            }
            
            let _ = await MainActor.run {
                logger.debug("Background embedding generation check completed")
            }
        }
    }
    
    // MARK: - Convenience Methods for UI
    
    /// Check if there are relevant memories for the current context
    public var hasRelevantMemories: Bool {
        return currentContext?.isEmpty == false
    }
    
    /// Get recent memories for display in UI
    public func getRecentMemories() -> [MemoryDisplayItem] {
        guard let context = currentContext else { return [] }
        
        var displayItems: [MemoryDisplayItem] = []
        
        // Add STM entries
        displayItems += context.typedShortTermMemories.map { stm in
            MemoryDisplayItem(
                id: stm.id,
                content: stm.content,
                type: .shortTerm,
                timestamp: stm.timestamp,
                relevanceScore: Double(stm.accessCount)
            )
        }
        
        // Add LTM entries
        displayItems += context.typedLongTermMemories.map { ltm in
            MemoryDisplayItem(
                id: ltm.id,
                content: ltm.content,
                type: .longTerm,
                timestamp: ltm.timestamp,
                relevanceScore: ltm.strengthScore
            )
        }
        
        // Add episodic memories
        displayItems += context.typedEpisodicMemories.map { episodic in
            MemoryDisplayItem(
                id: episodic.id,
                content: episodic.eventDescription,
                type: .episodic,
                timestamp: episodic.timestamp,
                relevanceScore: episodic.importance
            )
        }
        
        // Sort by relevance and recency
        return displayItems
            .sorted { item1, item2 in
                let score1 = item1.relevanceScore + (item1.timestamp.timeIntervalSinceNow / -86400) // Boost recent items
                let score2 = item2.relevanceScore + (item2.timestamp.timeIntervalSinceNow / -86400)
                return score1 > score2
            }
    }
    
    /// Get suggested entities for the current context
    public func getSuggestedEntities() -> [Entity] {
        guard let context = currentContext else { return [] }
        
        return context.typedEntities
            .sorted { $0.entityScore > $1.entityScore }
    }
}

// MARK: - Supporting Types

private struct CachedContext {
    let context: MemoryContext
    let timestamp: Date
}

public struct MemoryDisplayItem: Identifiable {
    public let id: UUID
    public let content: String
    public let type: MemoryType
    public let timestamp: Date
    public let relevanceScore: Double
    
    public enum MemoryType {
        case shortTerm
        case longTerm
        case episodic
        
        public var displayName: String {
            switch self {
            case .shortTerm: return "Short Term"
            case .longTerm: return "Long Term"
            case .episodic: return "Episodic"
            }
        }
        
        public var color: Color {
            switch self {
            case .shortTerm: return .blue
            case .longTerm: return .green
            case .episodic: return .purple
            }
        }
    }
}

// MARK: - Memory Context Extension

extension MemoryContext {
    // Convenience accessors - since contextData is [String: String], we can't store actual model objects
    // These return empty arrays until the MemoryContext structure is updated to support complex types
    public var typedShortTermMemories: [STMEntry] {
        // TODO: contextData is [String: String] so can't cast to [STMEntry]
        // This needs architectural fix to store actual model objects
        return []
    }
    
    public var typedLongTermMemories: [LTMEntry] {
        // TODO: contextData is [String: String] so can't cast to [LTMEntry]
        return []
    }
    
    public var typedEpisodicMemories: [EpisodicMemoryEntry] {
        // TODO: contextData is [String: String] so can't cast to [EpisodicMemoryEntry]
        return []
    }
    
    public var typedEntities: [Entity] {
        // TODO: contextData is [String: String] so can't cast to [Entity]
        return []
    }
    
    public var typedRelationships: [Relationship] {
        // TODO: contextData is [String: String] so can't cast to [Relationship]
        return []
    }
    
    public var typedNotes: [ProcessedNote] {
        // TODO: contextData is [String: String] so can't cast to [ProcessedNote]
        return []
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