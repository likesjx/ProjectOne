//
//  EmbeddingMigrationService.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/30/25.
//

import Foundation
import SwiftData
import Combine
import os.log

/// Service for migrating existing content to new embedding models or generating initial embeddings
@MainActor
public class EmbeddingMigrationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isMigrating = false
    @Published public var migrationProgress: Double = 0.0
    @Published public var currentOperation: String = ""
    @Published public var migrationStats = MigrationStats()
    @Published public var lastError: String?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EmbeddingMigrationService")
    private let modelContext: ModelContext
    private let embeddingGenerationService: EmbeddingGenerationService
    private let targetModelVersion: String
    
    private var migrationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let batchSize = 8
    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    
    // Progress tracking
    private var totalItemsToMigrate = 0
    private var migratedItems = 0
    
    // MARK: - Initialization
    
    public init(
        modelContext: ModelContext,
        embeddingGenerationService: EmbeddingGenerationService,
        targetModelVersion: String
    ) {
        self.modelContext = modelContext
        self.embeddingGenerationService = embeddingGenerationService
        self.targetModelVersion = targetModelVersion
        
        logger.info("EmbeddingMigrationService initialized for target model: \(targetModelVersion)")
    }
    
    // MARK: - Public Methods
    
    /// Start full migration of all content to target model version
    public func startFullMigration() async {
        guard !isMigrating else {
            logger.warning("Migration already in progress")
            return
        }
        
        migrationTask = Task {
            await performFullMigration()
        }
        
        await migrationTask?.value
    }
    
    /// Migrate content that lacks embeddings (initial embedding generation)
    public func generateInitialEmbeddings() async {
        guard !isMigrating else {
            logger.warning("Migration already in progress")
            return
        }
        
        migrationTask = Task {
            await performInitialEmbeddingGeneration()
        }
        
        await migrationTask?.value
    }
    
    /// Migrate content from a specific old model version
    public func migrateFromModelVersion(_ oldModelVersion: String) async {
        guard !isMigrating else {
            logger.warning("Migration already in progress")
            return
        }
        
        migrationTask = Task {
            await performModelVersionMigration(from: oldModelVersion)
        }
        
        await migrationTask?.value
    }
    
    /// Migrate content older than specified age
    public func migrateOldEmbeddings(olderThan maxAge: TimeInterval) async {
        guard !isMigrating else {
            logger.warning("Migration already in progress")
            return
        }
        
        migrationTask = Task {
            await performAgeBasedMigration(maxAge: maxAge)
        }
        
        await migrationTask?.value
    }
    
    /// Cancel current migration
    public func cancelMigration() {
        migrationTask?.cancel()
        migrationTask = nil
        isMigrating = false
        currentOperation = ""
        migrationProgress = 0.0
        logger.info("Embedding migration cancelled")
    }
    
    /// Get migration statistics
    public func updateMigrationStats() async {
        do {
            let stats = try await calculateMigrationStats()
            migrationStats = stats
            logger.info("Migration stats updated: \(stats.itemsNeedingMigration) items need migration")
        } catch {
            logger.error("Failed to update migration stats: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Implementation
    
    private func performFullMigration() async {
        isMigrating = true
        migrationProgress = 0.0
        lastError = nil
        currentOperation = "Starting full migration to \(targetModelVersion)..."
        
        defer {
            isMigrating = false
            currentOperation = ""
            migrationProgress = 0.0
        }
        
        do {
            // Count total items needing migration
            totalItemsToMigrate = try await countAllItemsNeedingMigration()
            migratedItems = 0
            
            logger.info("Starting full migration for \(self.totalItemsToMigrate) items")
            
            // Migrate each content type
            await migrateContentType(STMEntry.self, typeName: "Short-term memories")
            await migrateContentType(LTMEntry.self, typeName: "Long-term memories")
            await migrateContentType(EpisodicMemoryEntry.self, typeName: "Episodic memories")
            await migrateContentType(ProcessedNote.self, typeName: "Notes")
            await migrateContentType(Entity.self, typeName: "Entities")
            
            // Update final stats
            await updateMigrationStats()
            
            logger.info("✅ Full migration completed successfully")
            
        } catch {
            let errorMessage = "Full migration failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
        }
    }
    
    private func performInitialEmbeddingGeneration() async {
        isMigrating = true
        migrationProgress = 0.0
        lastError = nil
        currentOperation = "Generating initial embeddings..."
        
        defer {
            isMigrating = false
            currentOperation = ""
            migrationProgress = 0.0
        }
        
        do {
            // Count items without embeddings
            totalItemsToMigrate = try await countItemsWithoutEmbeddings()
            migratedItems = 0
            
            logger.info("Generating initial embeddings for \(self.totalItemsToMigrate) items")
            
            // Generate embeddings for each content type
            await generateEmbeddingsForType(STMEntry.self, typeName: "Short-term memories", mode: .missingOnly)
            await generateEmbeddingsForType(LTMEntry.self, typeName: "Long-term memories", mode: .missingOnly)
            await generateEmbeddingsForType(EpisodicMemoryEntry.self, typeName: "Episodic memories", mode: .missingOnly)
            await generateEmbeddingsForType(ProcessedNote.self, typeName: "Notes", mode: .missingOnly)
            await generateEmbeddingsForType(Entity.self, typeName: "Entities", mode: .missingOnly)
            
            // Update final stats
            await updateMigrationStats()
            
            logger.info("✅ Initial embedding generation completed successfully")
            
        } catch {
            let errorMessage = "Initial embedding generation failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
        }
    }
    
    private func performModelVersionMigration(from oldModelVersion: String) async {
        isMigrating = true
        migrationProgress = 0.0
        lastError = nil
        currentOperation = "Migrating from \(oldModelVersion) to \(targetModelVersion)..."
        
        defer {
            isMigrating = false
            currentOperation = ""
            migrationProgress = 0.0
        }
        
        do {
            // Count items with old model version
            totalItemsToMigrate = try await countItemsWithModelVersion(oldModelVersion)
            migratedItems = 0
            
            logger.info("Migrating \(self.totalItemsToMigrate) items from model version \(oldModelVersion)")
            
            // Migrate each content type
            await generateEmbeddingsForType(STMEntry.self, typeName: "Short-term memories", mode: .specificVersion(oldModelVersion))
            await generateEmbeddingsForType(LTMEntry.self, typeName: "Long-term memories", mode: .specificVersion(oldModelVersion))
            await generateEmbeddingsForType(EpisodicMemoryEntry.self, typeName: "Episodic memories", mode: .specificVersion(oldModelVersion))
            await generateEmbeddingsForType(ProcessedNote.self, typeName: "Notes", mode: .specificVersion(oldModelVersion))
            await generateEmbeddingsForType(Entity.self, typeName: "Entities", mode: .specificVersion(oldModelVersion))
            
            // Update final stats
            await updateMigrationStats()
            
            logger.info("✅ Model version migration completed successfully")
            
        } catch {
            let errorMessage = "Model version migration failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
        }
    }
    
    private func performAgeBasedMigration(maxAge: TimeInterval) async {
        isMigrating = true
        migrationProgress = 0.0
        lastError = nil
        currentOperation = "Migrating embeddings older than \(Int(maxAge / 86400)) days..."
        
        defer {
            isMigrating = false
            currentOperation = ""
            migrationProgress = 0.0
        }
        
        do {
            // Count items with old embeddings
            totalItemsToMigrate = try await countItemsWithOldEmbeddings(maxAge: maxAge)
            migratedItems = 0
            
            logger.info("Migrating \(self.totalItemsToMigrate) items with embeddings older than \(maxAge) seconds")
            
            // Migrate each content type
            await generateEmbeddingsForType(STMEntry.self, typeName: "Short-term memories", mode: .olderThan(maxAge))
            await generateEmbeddingsForType(LTMEntry.self, typeName: "Long-term memories", mode: .olderThan(maxAge))
            await generateEmbeddingsForType(EpisodicMemoryEntry.self, typeName: "Episodic memories", mode: .olderThan(maxAge))
            await generateEmbeddingsForType(ProcessedNote.self, typeName: "Notes", mode: .olderThan(maxAge))
            await generateEmbeddingsForType(Entity.self, typeName: "Entities", mode: .olderThan(maxAge))
            
            // Update final stats
            await updateMigrationStats()
            
            logger.info("✅ Age-based migration completed successfully")
            
        } catch {
            let errorMessage = "Age-based migration failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
        }
    }
    
    // MARK: - Content Type Migration
    
    private func migrateContentType<T>(_ type: T.Type, typeName: String) async where T: EmbeddingCapable & PersistentModel {
        await generateEmbeddingsForType(type, typeName: typeName, mode: .all)
    }
    
    private func generateEmbeddingsForType<T>(_ type: T.Type, typeName: String, mode: MigrationMode) async where T: EmbeddingCapable & PersistentModel {
        currentOperation = "Migrating \(typeName.lowercased())..."
        
        do {
            let itemsToMigrate = try await fetchItemsForMigration(type: type, mode: mode)
            guard !itemsToMigrate.isEmpty else {
                logger.info("No \(typeName.lowercased()) need migration for mode: \(mode)")
                return
            }
            
            logger.info("Migrating \(itemsToMigrate.count) \(typeName.lowercased())")
            
            // Process in batches
            for batch in itemsToMigrate.chunked(into: batchSize) {
                try Task.checkCancellation()
                
                await processMigrationBatch(batch, typeName: typeName)
                
                // Save after each batch
                try modelContext.save()
                
                // Small delay to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
            }
            
        } catch {
            logger.error("Failed to migrate \(typeName): \(error.localizedDescription)")
        }
    }
    
    private func processMigrationBatch<T>(_ batch: [T], typeName: String) async where T: EmbeddingCapable & PersistentModel {
        for (index, item) in batch.enumerated() {
            do {
                try Task.checkCancellation()
                
                // Generate new embedding
                _ = try await embeddingGenerationService.generateEmbedding(for: item)
                
                migratedItems += 1
                migrationProgress = Double(migratedItems) / Double(totalItemsToMigrate)
                
                logger.debug("Migrated \(typeName) item \(index + 1)/\(batch.count) (\(self.migratedItems)/\(self.totalItemsToMigrate) total)")
                
            } catch {
                logger.error("Failed to migrate \(typeName) item: \(error.localizedDescription)")
                
                // Continue with other items in batch
                migratedItems += 1
                migrationProgress = Double(migratedItems) / Double(totalItemsToMigrate)
            }
        }
    }
    
    // MARK: - Database Queries
    
    private func countAllItemsNeedingMigration() async throws -> Int {
        let stmCount = try await countItemsNeedingMigration(type: STMEntry.self)
        let ltmCount = try await countItemsNeedingMigration(type: LTMEntry.self)
        let episodicCount = try await countItemsNeedingMigration(type: EpisodicMemoryEntry.self)
        let noteCount = try await countItemsNeedingMigration(type: ProcessedNote.self)
        let entityCount = try await countItemsNeedingMigration(type: Entity.self)
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsWithoutEmbeddings() async throws -> Int {
        let stmCount = try await countItemsWithoutEmbeddings(type: STMEntry.self)
        let ltmCount = try await countItemsWithoutEmbeddings(type: LTMEntry.self)
        let episodicCount = try await countItemsWithoutEmbeddings(type: EpisodicMemoryEntry.self)
        let noteCount = try await countItemsWithoutEmbeddings(type: ProcessedNote.self)
        let entityCount = try await countItemsWithoutEmbeddings(type: Entity.self)
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsWithModelVersion(_ modelVersion: String) async throws -> Int {
        let stmCount = try await countItemsWithModelVersion(type: STMEntry.self, modelVersion: modelVersion)
        let ltmCount = try await countItemsWithModelVersion(type: LTMEntry.self, modelVersion: modelVersion)
        let episodicCount = try await countItemsWithModelVersion(type: EpisodicMemoryEntry.self, modelVersion: modelVersion)
        let noteCount = try await countItemsWithModelVersion(type: ProcessedNote.self, modelVersion: modelVersion)
        let entityCount = try await countItemsWithModelVersion(type: Entity.self, modelVersion: modelVersion)
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsWithOldEmbeddings(maxAge: TimeInterval) async throws -> Int {
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        let stmCount = try await countItemsWithOldEmbeddings(type: STMEntry.self, cutoffDate: cutoffDate)
        let ltmCount = try await countItemsWithOldEmbeddings(type: LTMEntry.self, cutoffDate: cutoffDate)
        let episodicCount = try await countItemsWithOldEmbeddings(type: EpisodicMemoryEntry.self, cutoffDate: cutoffDate)
        let noteCount = try await countItemsWithOldEmbeddings(type: ProcessedNote.self, cutoffDate: cutoffDate)
        let entityCount = try await countItemsWithOldEmbeddings(type: Entity.self, cutoffDate: cutoffDate)
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsNeedingMigration<T>(type: T.Type) async throws -> Int where T: EmbeddingCapable & PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { $0.needsEmbeddingUpdate(currentModelVersion: targetModelVersion, maxAge: 30 * 24 * 3600) }.count
    }
    
    private func countItemsWithoutEmbeddings<T>(type: T.Type) async throws -> Int where T: EmbeddingCapable & PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { !$0.hasEmbedding }.count
    }
    
    private func countItemsWithModelVersion<T>(type: T.Type, modelVersion: String) async throws -> Int where T: EmbeddingCapable & PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { $0.embeddingModelVersion == modelVersion }.count
    }
    
    private func countItemsWithOldEmbeddings<T>(type: T.Type, cutoffDate: Date) async throws -> Int where T: EmbeddingCapable & PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { item in
            guard let generatedAt = item.embeddingGeneratedAt else { return false }
            return generatedAt < cutoffDate
        }.count
    }
    
    private func fetchItemsForMigration<T>(type: T.Type, mode: MigrationMode) async throws -> [T] where T: EmbeddingCapable & PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        switch mode {
        case .all:
            return allItems.filter { $0.needsEmbeddingUpdate(currentModelVersion: targetModelVersion, maxAge: 30 * 24 * 3600) }
        case .missingOnly:
            return allItems.filter { !$0.hasEmbedding }
        case .specificVersion(let modelVersion):
            return allItems.filter { $0.embeddingModelVersion == modelVersion }
        case .olderThan(let maxAge):
            let cutoffDate = Date().addingTimeInterval(-maxAge)
            return allItems.filter { item in
                guard let generatedAt = item.embeddingGeneratedAt else { return true }
                return generatedAt < cutoffDate
            }
        }
    }
    
    private func calculateMigrationStats() async throws -> MigrationStats {
        let totalItems = try await countTotalItems()
        let itemsWithEmbeddings = try await countItemsWithEmbeddings()
        let itemsNeedingMigration = try await countAllItemsNeedingMigration()
        let itemsWithCurrentModel = try await countItemsWithModelVersion(targetModelVersion)
        
        return MigrationStats(
            totalItems: totalItems,
            itemsWithEmbeddings: itemsWithEmbeddings,
            itemsNeedingMigration: itemsNeedingMigration,
            itemsWithCurrentModel: itemsWithCurrentModel,
            targetModelVersion: targetModelVersion,
            lastUpdated: Date()
        )
    }
    
    private func countTotalItems() async throws -> Int {
        let stmCount = try modelContext.fetch(FetchDescriptor<STMEntry>()).count
        let ltmCount = try modelContext.fetch(FetchDescriptor<LTMEntry>()).count
        let episodicCount = try modelContext.fetch(FetchDescriptor<EpisodicMemoryEntry>()).count
        let noteCount = try modelContext.fetch(FetchDescriptor<ProcessedNote>()).count
        let entityCount = try modelContext.fetch(FetchDescriptor<Entity>()).count
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsWithEmbeddings() async throws -> Int {
        let stmCount = try await countItemsWithEmbeddings(type: STMEntry.self)
        let ltmCount = try await countItemsWithEmbeddings(type: LTMEntry.self)
        let episodicCount = try await countItemsWithEmbeddings(type: EpisodicMemoryEntry.self)
        let noteCount = try await countItemsWithEmbeddings(type: ProcessedNote.self)
        let entityCount = try await countItemsWithEmbeddings(type: Entity.self)
        
        return stmCount + ltmCount + episodicCount + noteCount + entityCount
    }
    
    private func countItemsWithEmbeddings<T>(type: T.Type) async throws -> Int where T: EmbeddingCapable & PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let allItems = try modelContext.fetch(descriptor)
        
        return allItems.filter { $0.hasEmbedding }.count
    }
}

// MARK: - Supporting Types

public struct MigrationStats {
    public let totalItems: Int
    public let itemsWithEmbeddings: Int
    public let itemsNeedingMigration: Int
    public let itemsWithCurrentModel: Int
    public let targetModelVersion: String
    public let lastUpdated: Date
    
    public init(
        totalItems: Int = 0,
        itemsWithEmbeddings: Int = 0,
        itemsNeedingMigration: Int = 0,
        itemsWithCurrentModel: Int = 0,
        targetModelVersion: String = "",
        lastUpdated: Date = Date()
    ) {
        self.totalItems = totalItems
        self.itemsWithEmbeddings = itemsWithEmbeddings
        self.itemsNeedingMigration = itemsNeedingMigration
        self.itemsWithCurrentModel = itemsWithCurrentModel
        self.targetModelVersion = targetModelVersion
        self.lastUpdated = lastUpdated
    }
    
    public var migrationCompletionPercentage: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(itemsWithCurrentModel) / Double(totalItems)
    }
    
    public var embeddingCoveragePercentage: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(itemsWithEmbeddings) / Double(totalItems)
    }
}

public enum MigrationMode: CustomStringConvertible, Equatable {
    case all
    case missingOnly
    case specificVersion(String)
    case olderThan(TimeInterval)
    
    public var description: String {
        switch self {
        case .all: return "all"
        case .missingOnly: return "missingOnly"
        case .specificVersion(let version): return "specificVersion(\(version))"
        case .olderThan(let interval): return "olderThan(\(interval))"
        }
    }
}

// MARK: - Array Extension

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}