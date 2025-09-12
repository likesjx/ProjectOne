//
//  EmbeddingGenerationService.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/30/25.
//

import Foundation
import SwiftData
import Combine
import os.log

// MARK: - Temporary Protocol Definition
// TODO: Move to separate file once project structure is finalized

/// Protocol for SwiftData models that can participate in embedding operations
/// This protocol accommodates SwiftData's limitations (no Sendable, Data storage)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public protocol SwiftDataEmbeddingCapable: PersistentModel {
    /// Raw embedding data stored as Data for SwiftData compatibility
    var embedding: Data? { get set }
    
    /// Model version used to generate the embedding
    var embeddingModelVersion: String? { get set }
    
    /// Timestamp when embedding was generated
    var embeddingGeneratedAt: Date? { get set }
    
    /// Content to be used for embedding generation
    var embeddingText: String { get }
    
    /// Check if this model has a valid embedding
    var hasEmbedding: Bool { get }
    
    /// Set embedding data from float array
    func setEmbedding(_ embeddingVector: [Float], modelVersion: String)
    
    /// Get embedding as float array for calculations
    func getEmbedding() -> [Float]?
    
    /// Check if embedding needs regeneration
    func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval) -> Bool
}

/// Service for generating and managing embeddings for memory content
@MainActor
public class EmbeddingGenerationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isGenerating = false
    @Published public var generationProgress: Double = 0.0
    @Published public var currentOperation: String = ""
    @Published public var lastError: String?
    @Published public var embeddingStats = EmbeddingStats()
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EmbeddingGenerationService")
    private let modelContext: ModelContext
    private let embeddingProvider: MLXProvider
    private let currentModelVersion: String
    
    /// Get the current model version for external access
    public var modelVersion: String {
        return currentModelVersion
    }
    
    private var generationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let batchSize = 10
    private let maxConcurrentOperations = 3
    private let retryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    // Progress tracking
    private var totalItems = 0
    private var processedItems = 0
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext, embeddingProvider: MLXProvider) {
        self.modelContext = modelContext
        self.embeddingProvider = embeddingProvider
        self.currentModelVersion = embeddingProvider.configuration.model
        
        logger.info("EmbeddingGenerationService initialized with model: \(self.currentModelVersion)")
        
        // Update stats on initialization
        Task {
            await updateEmbeddingStats()
        }
    }
    
    // MARK: - Public Methods
    
    /// Generate embeddings for all content that needs them
    public func generateMissingEmbeddings() async {
        guard !isGenerating else {
            logger.warning("Embedding generation already in progress")
            return
        }
        
        generationTask = Task {
            await performEmbeddingGeneration()
        }
        
        await generationTask?.value
    }
    
    /// Generate embedding for a single piece of content
    public func generateEmbedding<T>(for item: T) async throws -> [Float] where T: SwiftDataEmbeddingCapable {
        if !embeddingProvider.isAvailable {
            logger.info("Loading embedding model...")
            try await embeddingProvider.prepareModel()
        }
        
        let text = item.embeddingText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EmbeddingGenerationError.emptyContent
        }
        
        do {
            let embedding = try await embeddingProvider.generateEmbedding(text: text, modelId: currentModelVersion)
            
            // Validate embedding quality
            let qualityReport = EmbeddingUtils.analyzeEmbeddingQuality(embedding)
            if !qualityReport.isValid {
                logger.warning("Generated low-quality embedding for content: \(qualityReport.issues)")
            }
            
            // Update the item with the new embedding
            item.setEmbedding(embedding, modelVersion: currentModelVersion)
            
            return embedding
            
        } catch {
            logger.error("Failed to generate embedding: \(error.localizedDescription)")
            throw EmbeddingGenerationError.generationFailed(error.localizedDescription)
        }
    }
    
    /// Force regeneration of embeddings for specific model version
    public func regenerateEmbeddings(forModelVersion modelVersion: String) async {
        guard !isGenerating else {
            logger.warning("Embedding generation already in progress")
            return
        }
        
        generationTask = Task {
            await performEmbeddingRegeneration(forModelVersion: modelVersion)
        }
        
        await generationTask?.value
    }
    
    /// Cancel current generation process
    public func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        currentOperation = ""
        generationProgress = 0.0
        logger.info("Embedding generation cancelled")
    }
    
    /// Update embedding statistics
    public func updateEmbeddingStats() async {
        do {
            let stmStats = try await getEmbeddingStats(for: STMEntry.self)
            let ltmStats = try await getEmbeddingStats(for: LTMEntry.self)
            let episodicStats = try await getEmbeddingStats(for: EpisodicMemoryEntry.self)
            let noteStats = try await getEmbeddingStats(for: ProcessedNote.self)
            let entityStats = try await getEmbeddingStats(for: Entity.self)
            
            embeddingStats = EmbeddingStats(
                totalItems: stmStats.total + ltmStats.total + episodicStats.total + noteStats.total + entityStats.total,
                itemsWithEmbeddings: stmStats.withEmbeddings + ltmStats.withEmbeddings + episodicStats.withEmbeddings + noteStats.withEmbeddings + entityStats.withEmbeddings,
                itemsNeedingUpdate: stmStats.needingUpdate + ltmStats.needingUpdate + episodicStats.needingUpdate + noteStats.needingUpdate + entityStats.needingUpdate,
                modelVersionCounts: [:], // TODO: Implement detailed version tracking
                lastUpdated: Date()
            )
            
            logger.info("Updated embedding stats: \(self.embeddingStats.itemsWithEmbeddings)/\(self.embeddingStats.totalItems) items have embeddings")
            
        } catch {
            logger.error("Failed to update embedding stats: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func performEmbeddingGeneration() async {
        isGenerating = true
        generationProgress = 0.0
        lastError = nil
        
        defer {
            isGenerating = false
            currentOperation = ""
            generationProgress = 0.0
        }
        
        do {
            // Ensure model is loaded
            if !embeddingProvider.isAvailable {
                currentOperation = "Loading embedding model..."
                try await embeddingProvider.prepareModel()
            }
            
            // Count total items needing embeddings
            totalItems = try await countItemsNeedingEmbeddings()
            processedItems = 0
            
            logger.info("Starting embedding generation for \(self.totalItems) items")
            
            // Generate embeddings for each content type
            await generateEmbeddingsForType(STMEntry.self, typeName: "Short-term memories")
            await generateEmbeddingsForType(LTMEntry.self, typeName: "Long-term memories")
            await generateEmbeddingsForType(EpisodicMemoryEntry.self, typeName: "Episodic memories")
            await generateEmbeddingsForType(ProcessedNote.self, typeName: "Notes")
            await generateEmbeddingsForType(Entity.self, typeName: "Entities")
            
            // Update stats
            await updateEmbeddingStats()
            
            logger.info("✅ Embedding generation completed successfully")
            
        } catch {
            let errorMessage = "Embedding generation failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
        }
    }
    
    private func performEmbeddingRegeneration(forModelVersion modelVersion: String) async {
        isGenerating = true
        generationProgress = 0.0
        lastError = nil
        currentOperation = "Regenerating embeddings for model version: \(modelVersion)"
        
        defer {
            isGenerating = false
            currentOperation = ""
            generationProgress = 0.0
        }
        
        do {
            // Ensure model is loaded
            if !embeddingProvider.isAvailable {
                try await embeddingProvider.prepareModel()
            }
            
            // Count items with the specified model version
            totalItems = try await countItemsWithModelVersion(modelVersion)
            processedItems = 0
            
            logger.info("Starting embedding regeneration for \(self.totalItems) items with model version: \(modelVersion)")
            
            // Regenerate embeddings for each content type
            await regenerateEmbeddingsForType(STMEntry.self, modelVersion: modelVersion, typeName: "Short-term memories")
            await regenerateEmbeddingsForType(LTMEntry.self, modelVersion: modelVersion, typeName: "Long-term memories")
            await regenerateEmbeddingsForType(EpisodicMemoryEntry.self, modelVersion: modelVersion, typeName: "Episodic memories")
            await regenerateEmbeddingsForType(ProcessedNote.self, modelVersion: modelVersion, typeName: "Notes")
            await regenerateEmbeddingsForType(Entity.self, modelVersion: modelVersion, typeName: "Entities")
            
            // Update stats
            await updateEmbeddingStats()
            
            logger.info("✅ Embedding regeneration completed successfully")
            
        } catch {
            let errorMessage = "Embedding regeneration failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
        }
    }
    
    private func generateEmbeddingsForType<T>(_ type: T.Type, typeName: String) async where T: SwiftDataEmbeddingCapable {
        currentOperation = "Generating embeddings for \(typeName.lowercased())..."
        
        do {
            let itemsNeedingEmbeddings = try await fetchItemsNeedingEmbeddings(type: type)
            guard !itemsNeedingEmbeddings.isEmpty else {
                logger.info("No \(typeName.lowercased()) need embeddings")
                return
            }
            
            logger.info("Generating embeddings for \(itemsNeedingEmbeddings.count) \(typeName.lowercased())")
            
            // Process in batches
            for batch in stride(from: 0, to: itemsNeedingEmbeddings.count, by: batchSize).map({ start in
                Array(itemsNeedingEmbeddings[start..<min(start + batchSize, itemsNeedingEmbeddings.count)])
            }) {
                try Task.checkCancellation()
                
                await processBatch(batch, typeName: typeName)
                
                // Save after each batch
                try modelContext.save()
                
                // Small delay to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
        } catch {
            logger.error("Failed to generate embeddings for \(typeName): \(error.localizedDescription)")
        }
    }
    
    private func regenerateEmbeddingsForType<T>(_ type: T.Type, modelVersion: String, typeName: String) async where T: SwiftDataEmbeddingCapable {
        currentOperation = "Regenerating embeddings for \(typeName.lowercased())..."
        
        do {
            let itemsWithModelVersion = try await fetchItemsWithModelVersion(type: type, modelVersion: modelVersion)
            guard !itemsWithModelVersion.isEmpty else {
                logger.info("No \(typeName.lowercased()) have model version \(modelVersion)")
                return
            }
            
            logger.info("Regenerating embeddings for \(itemsWithModelVersion.count) \(typeName.lowercased())")
            
            // Process in batches
            for batch in stride(from: 0, to: itemsWithModelVersion.count, by: batchSize).map({ start in
                Array(itemsWithModelVersion[start..<min(start + batchSize, itemsWithModelVersion.count)])
            }) {
                try Task.checkCancellation()
                
                await processBatch(batch, typeName: typeName)
                
                // Save after each batch
                try modelContext.save()
                
                // Small delay to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            
        } catch {
            logger.error("Failed to regenerate embeddings for \(typeName): \(error.localizedDescription)")
        }
    }
    
    private func processBatch<T>(_ batch: [T], typeName: String) async where T: SwiftDataEmbeddingCapable {
        for item in batch {
            do {
                try Task.checkCancellation()
                
                _ = try await generateEmbedding(for: item)
                processedItems += 1
                generationProgress = Double(processedItems) / Double(totalItems)
                
                logger.debug("Generated embedding for \(typeName) item (\(self.processedItems)/\(self.totalItems))")
                
            } catch {
                logger.error("Failed to generate embedding for \(typeName) item: \(error.localizedDescription)")
                
                // Continue with other items in batch
                processedItems += 1
                generationProgress = Double(processedItems) / Double(totalItems)
            }
        }
    }
    
    // MARK: - Database Queries
    
    private func countItemsNeedingEmbeddings() async throws -> Int {
        let stmCount = try await countItemsNeedingEmbeddings(type: STMEntry.self)
        let ltmCount = try await countItemsNeedingEmbeddings(type: LTMEntry.self)
        let episodicCount = try await countItemsNeedingEmbeddings(type: EpisodicMemoryEntry.self)
        let noteCount = try await countItemsNeedingEmbeddings(type: ProcessedNote.self)
        let entityCount = try await countItemsNeedingEmbeddings(type: Entity.self)
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsNeedingEmbeddings<T>(type: T.Type) async throws -> Int where T: SwiftDataEmbeddingCapable {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { $0.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 7 * 24 * 3600) }.count
    }
    
    private func countItemsWithModelVersion(_ modelVersion: String) async throws -> Int {
        let stmCount = try await countItemsWithModelVersion(type: STMEntry.self, modelVersion: modelVersion)
        let ltmCount = try await countItemsWithModelVersion(type: LTMEntry.self, modelVersion: modelVersion)
        let episodicCount = try await countItemsWithModelVersion(type: EpisodicMemoryEntry.self, modelVersion: modelVersion)
        let noteCount = try await countItemsWithModelVersion(type: ProcessedNote.self, modelVersion: modelVersion)
        let entityCount = try await countItemsWithModelVersion(type: Entity.self, modelVersion: modelVersion)
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsWithModelVersion<T>(type: T.Type, modelVersion: String) async throws -> Int where T: SwiftDataEmbeddingCapable {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { item in
            item.embeddingModelVersion == modelVersion
        }.count
    }
    
    private func fetchItemsNeedingEmbeddings<T>(type: T.Type) async throws -> [T] where T: SwiftDataEmbeddingCapable {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { $0.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 7 * 24 * 3600) }
    }
    
    private func fetchItemsWithModelVersion<T>(type: T.Type, modelVersion: String) async throws -> [T] where T: SwiftDataEmbeddingCapable {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { item in
            item.embeddingModelVersion == modelVersion
        }
    }
    
    private func getEmbeddingStats<T>(for type: T.Type) async throws -> (total: Int, withEmbeddings: Int, needingUpdate: Int) where T: SwiftDataEmbeddingCapable {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        let total = allItems.count
        let withEmbeddings = allItems.filter { $0.hasEmbedding }.count
        let needingUpdate = allItems.filter { $0.needsEmbeddingUpdate(currentModelVersion: currentModelVersion, maxAge: 7 * 24 * 3600) }.count
        
        return (total: total, withEmbeddings: withEmbeddings, needingUpdate: needingUpdate)
    }
}

// MARK: - Supporting Types

public struct EmbeddingStats {
    public let totalItems: Int
    public let itemsWithEmbeddings: Int
    public let itemsNeedingUpdate: Int
    public let modelVersionCounts: [String: Int]
    public let lastUpdated: Date
    
    public init(
        totalItems: Int = 0,
        itemsWithEmbeddings: Int = 0,
        itemsNeedingUpdate: Int = 0,
        modelVersionCounts: [String: Int] = [:],
        lastUpdated: Date = Date()
    ) {
        self.totalItems = totalItems
        self.itemsWithEmbeddings = itemsWithEmbeddings
        self.itemsNeedingUpdate = itemsNeedingUpdate
        self.modelVersionCounts = modelVersionCounts
        self.lastUpdated = lastUpdated
    }
    
    public var completionPercentage: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(itemsWithEmbeddings) / Double(totalItems)
    }
    
    public var itemsMissingEmbeddings: Int {
        return totalItems - itemsWithEmbeddings
    }
}

public enum EmbeddingGenerationError: LocalizedError {
    case emptyContent
    case generationFailed(String)
    case modelNotLoaded
    
    public var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Content is empty or contains only whitespace"
        case .generationFailed(let message):
            return "Embedding generation failed: \(message)"
        case .modelNotLoaded:
            return "Embedding model is not loaded"
        }
    }
}

// MARK: - Protocol Conformance

// SwiftData models now implement SwiftDataEmbeddingCapable instead of EmbeddingCapable
// to resolve Sendable protocol conflicts and property type mismatches.
// Use the adapter pattern when needed for EmbeddingCapable compatibility.


