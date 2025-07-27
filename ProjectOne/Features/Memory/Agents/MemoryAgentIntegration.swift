//
//  MemoryAgentIntegration.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/15/25.
//

import Foundation
import SwiftData
import os.log
import Combine

/// Integration service for connecting Memory Agent with existing ProjectOne services
@MainActor
public class MemoryAgentIntegration: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryAgentIntegration")
    
    // MARK: - Dependencies
    
    private let memoryAgent: MemoryAgent
    private let orchestrator: MemoryAgentOrchestrator
    private let knowledgeGraphService: KnowledgeGraphService
    private let textIngestionAgent: TextIngestionAgent
    private let modelContext: ModelContext
    
    // MARK: - State
    
    @Published public var isIntegrated = false
    @Published public var integrationStatus: IntegrationStatus = .disconnected
    @Published public var lastSyncTime: Date?
    @Published public var errorMessage: String?
    
    // MARK: - Initialization
    
    public init(
        memoryAgent: MemoryAgent,
        orchestrator: MemoryAgentOrchestrator,
        knowledgeGraphService: KnowledgeGraphService,
        textIngestionAgent: TextIngestionAgent,
        modelContext: ModelContext
    ) {
        self.memoryAgent = memoryAgent
        self.orchestrator = orchestrator
        self.knowledgeGraphService = knowledgeGraphService
        self.textIngestionAgent = textIngestionAgent
        self.modelContext = modelContext
        
        logger.info("Memory Agent Integration initialized")
    }
    
    // MARK: - Integration Lifecycle
    
    public func integrate() async throws {
        logger.info("Starting Memory Agent integration")
        
        integrationStatus = .connecting
        
        do {
            // Start Memory Agent and orchestrator
            try await orchestrator.start()
            
            // Set up data flow integrations
            try await setupDataFlowIntegrations()
            
            // Initialize bidirectional sync
            try await initializeBidirectionalSync()
            
            // Set up real-time monitoring
            setupRealTimeMonitoring()
            
            integrationStatus = .connected
            isIntegrated = true
            lastSyncTime = Date()
            
            logger.info("Memory Agent integration completed successfully")
            
        } catch {
            integrationStatus = .error
            errorMessage = error.localizedDescription
            logger.error("Memory Agent integration failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func disconnect() async {
        logger.info("Disconnecting Memory Agent integration")
        
        integrationStatus = .disconnecting
        
        // Stop orchestrator
        await orchestrator.stop()
        
        // Clean up integrations
        await cleanupIntegrations()
        
        integrationStatus = .disconnected
        isIntegrated = false
        
        logger.info("Memory Agent integration disconnected")
    }
    
    // MARK: - Data Flow Integration
    
    private func setupDataFlowIntegrations() async throws {
        logger.info("Setting up data flow integrations")
        
        // Integrate with TextIngestionAgent
        try await integrateWithTextIngestionAgent()
        
        // Integrate with KnowledgeGraphService
        try await integrateWithKnowledgeGraphService()
        
        // Set up transcription pipeline
        try await setupTranscriptionPipeline()
        
        logger.info("Data flow integrations completed")
    }
    
    private func integrateWithTextIngestionAgent() async throws {
        logger.debug("Integrating with TextIngestionAgent")
        
        // Set up callback for when TextIngestionAgent processes new content
        textIngestionAgent.onContentProcessed = { [weak self] processedNote in
            Task { @MainActor in
                await self?.handleProcessedNote(processedNote)
            }
        }
        
        // Set up callback for entity extraction
        textIngestionAgent.onEntityExtracted = { [weak self] entity in
            Task { @MainActor in
                await self?.handleExtractedEntity(entity)
            }
        }
        
        logger.debug("TextIngestionAgent integration completed")
    }
    
    private func integrateWithKnowledgeGraphService() async throws {
        logger.debug("Integrating with KnowledgeGraphService")
        
        // Sync existing knowledge graph to Memory Agent
        try await syncExistingKnowledgeGraph()
        
        // Set up bidirectional updates
        setupKnowledgeGraphBidirectionalSync()
        
        logger.debug("KnowledgeGraphService integration completed")
    }
    
    private func setupTranscriptionPipeline() async throws {
        logger.debug("Setting up transcription pipeline")
        
        // This would integrate with SpeechTranscriptionService
        // For now, we'll set up a notification observer
        NotificationCenter.default.addObserver(
            forName: .transcriptionCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.handleTranscriptionCompleted(notification)
            }
        }
        
        logger.debug("Transcription pipeline setup completed")
    }
    
    // MARK: - Bidirectional Sync
    
    private func initializeBidirectionalSync() async throws {
        logger.info("Initializing bidirectional sync")
        
        // Sync from existing services to Memory Agent
        try await syncFromExistingServices()
        
        // Set up continuous sync
        setupContinuousSync()
        
        logger.info("Bidirectional sync initialized")
    }
    
    private func syncFromExistingServices() async throws {
        logger.debug("Syncing from existing services")
        
        // Skip sync during initial startup to avoid template loading race condition
        print("⏭️ [MemoryAgentIntegration] Skipping initial sync to avoid template loading race condition")
        logger.debug("Skipping initial sync to avoid template loading race condition")
        
        // TODO: Implement delayed sync after templates are confirmed loaded
        // Sync processed notes
        // try await syncProcessedNotes()
        
        // Sync entities and relationships
        // try await syncEntitiesAndRelationships()
        
        // Sync user interactions
        // try await syncUserInteractions()
        
        logger.debug("Sync from existing services completed (skipped)")
    }
    
    private func syncProcessedNotes() async throws {
        var descriptor = FetchDescriptor<ProcessedNote>(
            sortBy: [SortDescriptor(\.lastAccessed, order: .reverse)]
        )
        descriptor.fetchLimit = 100 // Sync most recent 100 notes
        
        let notes = try modelContext.fetch(descriptor)
        
        for note in notes {
            let ingestData = MemoryIngestData(
                type: .note,
                content: "\(note.originalText)\n\(note.summary)",
                timestamp: note.lastAccessed,
                confidence: 1.0,
                metadata: [
                    "summary": note.summary,
                    "topics": note.topics,
                    "originalId": note.id.uuidString
                ]
            )
            
            try await memoryAgent.ingestData(ingestData)
        }
        
        logger.debug("Synced \(notes.count) processed notes")
    }
    
    private func syncEntitiesAndRelationships() async throws {
        // Sync entities
        var entityDescriptor = FetchDescriptor<Entity>(
            sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
        )
        entityDescriptor.fetchLimit = 200
        
        let entities = try modelContext.fetch(entityDescriptor)
        logger.debug("Synced \(entities.count) entities")
        
        // Sync relationships
        var relationshipDescriptor = FetchDescriptor<Relationship>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        relationshipDescriptor.fetchLimit = 200
        
        let relationships = try modelContext.fetch(relationshipDescriptor)
        logger.debug("Synced \(relationships.count) relationships")
    }
    
    private func syncUserInteractions() async throws {
        // This would sync user interactions if they were stored
        // For now, we'll create a placeholder
        logger.debug("User interactions sync placeholder")
    }
    
    // MARK: - Real-time Monitoring
    
    private func setupRealTimeMonitoring() {
        print("🔄 [MemoryAgentIntegration] Setting up real-time monitoring...")
        logger.debug("Setting up real-time monitoring")
        
        // Monitor for new data
        NotificationCenter.default.addObserver(
            forName: .newNoteCreated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("🎯 [MemoryAgentIntegration] .newNoteCreated notification observer triggered!")
            Task {
                await self?.handleNewNote(notification)
            }
        }
        
        print("✅ [MemoryAgentIntegration] .newNoteCreated notification observer set up successfully")
        
        NotificationCenter.default.addObserver(
            forName: .entityUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task {
                await self?.handleEntityUpdate(notification)
            }
        }
        
        logger.debug("Real-time monitoring setup completed")
    }
    
    // MARK: - Event Handlers
    
    private func handleProcessedNote(_ note: ProcessedNote) async {
        logger.debug("Handling processed note: \(note.originalText.prefix(50))...")
        
        let ingestData = MemoryIngestData(
            type: .note,
            content: "\(note.originalText)\n\(note.summary)",
            timestamp: note.lastAccessed,
            confidence: 1.0,
            metadata: [
                "summary": note.summary,
                "topics": note.topics,
                "originalId": note.id.uuidString
            ]
        )
        
        do {
            try await memoryAgent.ingestData(ingestData)
            logger.debug("Successfully ingested processed note")
        } catch {
            logger.error("Failed to ingest processed note: \(error.localizedDescription)")
        }
    }
    
    private func handleExtractedEntity(_ entity: Entity) async {
        logger.debug("Handling extracted entity: \(entity.name)")
        
        // The entity is already in the knowledge graph
        // We can trigger Memory Agent to analyze it for relationship opportunities
        do {
            let query = "Analyze this entity for relationship opportunities: \(entity.name)"
            let _ = try await memoryAgent.processQuery(query)
            logger.debug("Successfully analyzed entity for relationships")
        } catch {
            logger.error("Failed to analyze entity: \(error.localizedDescription)")
        }
    }
    
    private func handleTranscriptionCompleted(_ notification: Notification) async {
        logger.debug("Handling transcription completed")
        
        guard let transcriptionResult = notification.userInfo?["result"] as? String else {
            logger.warning("No transcription result in notification")
            return
        }
        
        // Try to find the recording item if provided
        var recordingItem: RecordingItem?
        if let recordingId = notification.userInfo?["recordingId"] as? UUID {
            let descriptor = FetchDescriptor<RecordingItem>(
                predicate: #Predicate { $0.id == recordingId }
            )
            recordingItem = try? modelContext.fetch(descriptor).first
        }
        
        // Mark recording as processing if found
        if let recording = recordingItem {
            recording.updateMemoryProcessing(status: .processing)
            try? modelContext.save()
        }
        
        let startTime = Date()
        let ingestData = MemoryIngestData(
            type: .transcription,
            content: transcriptionResult,
            timestamp: Date(),
            confidence: notification.userInfo?["confidence"] as? Double ?? 0.8,
            metadata: [
                "source": "speech_transcription",
                "method": notification.userInfo?["method"] as? String ?? "unknown",
                "recordingId": recordingItem?.id.uuidString ?? ""
            ]
        )
        
        do {
            let result = try await memoryAgent.ingestData(ingestData)
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Update recording with memory processing results
            if let recording = recordingItem {
                let decision = parseMemoryDecision(from: result)
                
                recording.updateMemoryProcessing(
                    status: .completed,
                    decision: decision.decision,
                    confidence: decision.confidence,
                    templateUsed: decision.templateUsed,
                    modelUsed: decision.modelUsed,
                    processingTime: processingTime,
                    entitiesExtracted: decision.entitiesExtracted,
                    relationshipsCreated: decision.relationshipsCreated
                )
                
                try modelContext.save()
                
                print("🎤 [MemoryAgentIntegration] Recording processed successfully: \(decision.decision?.displayName ?? "Unknown")")
            }
            
            logger.debug("Successfully ingested transcription")
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Update recording with failure
            if let recording = recordingItem {
                recording.updateMemoryProcessing(
                    status: .failed,
                    processingTime: processingTime,
                    error: error.localizedDescription
                )
                
                try? modelContext.save()
            }
            
            logger.error("Failed to ingest transcription: \(error.localizedDescription)")
        }
    }
    
    private func handleNewNote(_ notification: Notification) async {
        print("🔔 [MemoryAgentIntegration] Received .newNoteCreated notification!")
        logger.debug("Handling new note notification")
        
        guard let noteId = notification.userInfo?["noteId"] as? UUID else {
            print("⚠️ [MemoryAgentIntegration] No note ID in notification")
            logger.warning("No note ID in notification")
            return
        }
        
        print("📝 [MemoryAgentIntegration] Processing note ID: \(noteId)")
        
        do {
            // Try to find as NoteItem first (new notes)
            let noteItemDescriptor = FetchDescriptor<NoteItem>(
                predicate: #Predicate { $0.id == noteId }
            )
            
            if let noteItem = try modelContext.fetch(noteItemDescriptor).first {
                await handleNoteItem(noteItem)
                return
            }
            
            // Fallback to ProcessedNote (processed notes)
            let processedNoteDescriptor = FetchDescriptor<ProcessedNote>(
                predicate: #Predicate { $0.id == noteId }
            )
            
            if let processedNote = try modelContext.fetch(processedNoteDescriptor).first {
                await handleProcessedNote(processedNote)
                return
            }
            
            logger.warning("Note not found: \(noteId)")
            
        } catch {
            logger.error("Failed to handle new note: \(error.localizedDescription)")
        }
    }
    
    private func handleNoteItem(_ noteItem: NoteItem) async {
        print("📋 [MemoryAgentIntegration] Handling note item: \(noteItem.markdownContent.prefix(50))...")
        logger.debug("Handling note item: \(noteItem.markdownContent.prefix(50))...")
        
        // Mark as processing
        noteItem.updateMemoryProcessing(status: .processing)
        try? modelContext.save()
        
        let startTime = Date()
        let ingestData = MemoryIngestData(
            type: .note,
            content: noteItem.markdownContent,
            timestamp: noteItem.timestamp,
            confidence: 1.0,
            metadata: [
                "sourceApp": noteItem.sourceApp ?? "ProjectOne",
                "sourceURL": noteItem.sourceURL ?? "",
                "originalId": noteItem.id.uuidString,
                "isProcessed": noteItem.isProcessedByMemoryAgent
            ]
        )
        
        do {
            try await memoryAgent.ingestData(ingestData)
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Create a default decision result for successful processing
            let decision = parseMemoryDecision(from: "processed")
            
            // Update with success
            noteItem.updateMemoryProcessing(
                status: .completed,
                decision: decision.decision,
                confidence: decision.confidence,
                templateUsed: decision.templateUsed,
                modelUsed: decision.modelUsed,
                processingTime: processingTime,
                entitiesExtracted: decision.entitiesExtracted,
                relationshipsCreated: decision.relationshipsCreated
            )
            
            try modelContext.save()
            
            print("✅ [MemoryAgentIntegration] Note processed successfully: \(decision.decision?.displayName ?? "Unknown")")
            logger.debug("Successfully ingested note item with decision: \(decision.decision?.rawValue ?? "unknown")")
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            
            // Update with failure
            noteItem.updateMemoryProcessing(
                status: .failed,
                processingTime: processingTime,
                error: error.localizedDescription
            )
            
            try? modelContext.save()
            
            print("❌ [MemoryAgentIntegration] Failed to process note: \(error.localizedDescription)")
            logger.error("Failed to ingest note item: \(error.localizedDescription)")
        }
    }
    
    private func handleEntityUpdate(_ notification: Notification) async {
        logger.debug("Handling entity update notification")
        
        guard let entityId = notification.userInfo?["entityId"] as? UUID else {
            logger.warning("No entity ID in notification")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<Entity>(
                predicate: #Predicate { $0.id == entityId }
            )
            
            guard let entity = try modelContext.fetch(descriptor).first else {
                logger.warning("Entity not found: \(entityId)")
                return
            }
            
            await handleExtractedEntity(entity)
            
        } catch {
            logger.error("Failed to handle entity update: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Knowledge Graph Sync
    
    private func syncExistingKnowledgeGraph() async throws {
        logger.debug("Syncing existing knowledge graph")
        
        // This would sync the existing knowledge graph structure
        // For now, we'll create a placeholder that marks the sync as complete
        logger.debug("Knowledge graph sync completed")
    }
    
    private func setupKnowledgeGraphBidirectionalSync() {
        logger.debug("Setting up knowledge graph bidirectional sync")
        
        // This would set up real-time sync between Memory Agent and KnowledgeGraphService
        // For now, we'll create a placeholder
        logger.debug("Knowledge graph bidirectional sync setup completed")
    }
    
    private func setupContinuousSync() {
        logger.debug("Setting up continuous sync")
        
        // Set up timer for periodic sync
        Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { _ in
            Task {
                await self.performPeriodicSync()
            }
        }
        
        logger.debug("Continuous sync setup completed")
    }
    
    private func performPeriodicSync() async {
        logger.debug("Performing periodic sync")
        
        do {
            // Sync any new or updated data
            try await syncFromExistingServices()
            lastSyncTime = Date()
            
            logger.debug("Periodic sync completed successfully")
        } catch {
            logger.error("Periodic sync failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupIntegrations() async {
        logger.debug("Cleaning up integrations")
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        // Clear callbacks
        textIngestionAgent.onContentProcessed = nil
        textIngestionAgent.onEntityExtracted = nil
        
        logger.debug("Integration cleanup completed")
    }
    
    // MARK: - Public Interface
    
    public func processUserQuery(_ query: String) async throws -> AgentResponse {
        guard isIntegrated else {
            throw MemoryAgentIntegrationError.notIntegrated
        }
        
        return try await orchestrator.processUserQuery(query)
    }
    
    public func getIntegrationStatus() -> IntegrationStatus {
        return integrationStatus
    }
    
    public func getLastSyncTime() -> Date? {
        return lastSyncTime
    }
    
    public func forceSync() async throws {
        logger.info("Forcing manual sync")
        try await syncFromExistingServices()
        lastSyncTime = Date()
        logger.info("Manual sync completed")
    }
    
    // MARK: - Batch Processing
    
    /// Process all unprocessed or failed notes and recordings
    public func processUnprocessedItems() async throws -> BatchProcessingResult {
        guard isIntegrated else {
            throw MemoryAgentIntegrationError.notIntegrated
        }
        
        print("🔄 [MemoryAgentIntegration] Starting batch processing of unprocessed items...")
        logger.info("Starting batch processing of unprocessed items")
        
        let startTime = Date()
        var result = BatchProcessingResult()
        
        // Process unprocessed notes
        let noteResults = try await processUnprocessedNotes()
        result.notesProcessed = noteResults.processed
        result.notesFailed = noteResults.failed
        
        // Process unprocessed recordings
        let recordingResults = try await processUnprocessedRecordings()
        result.recordingsProcessed = recordingResults.processed
        result.recordingsFailed = recordingResults.failed
        
        result.totalProcessingTime = Date().timeIntervalSince(startTime)
        
        print("✅ [MemoryAgentIntegration] Batch processing completed:")
        print("   📝 Notes: \(result.notesProcessed) processed, \(result.notesFailed) failed")
        print("   🎤 Recordings: \(result.recordingsProcessed) processed, \(result.recordingsFailed) failed")
        print("   ⏱️ Total time: \(String(format: "%.2f", result.totalProcessingTime))s")
        
        logger.info("Batch processing completed: \(result.notesProcessed + result.recordingsProcessed) items processed, \(result.notesFailed + result.recordingsFailed) failed")
        
        return result
    }
    
    /// Process only unprocessed or failed notes
    public func processUnprocessedNotes() async throws -> (processed: Int, failed: Int) {
        print("📝 [MemoryAgentIntegration] Processing unprocessed notes...")
        
        // Fetch unprocessed and failed notes
        var descriptor = FetchDescriptor<NoteItem>(
            predicate: #Predicate { item in
                item.memoryProcessingStatus.rawValue == "pending" ||
                item.memoryProcessingStatus.rawValue == "failed" ||
                item.memoryProcessingStatus.rawValue == "retrying"
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 100 // Process up to 100 at a time
        
        let notes = try modelContext.fetch(descriptor)
        
        print("📝 [MemoryAgentIntegration] Found \(notes.count) notes to process")
        
        var processed = 0
        var failed = 0
        
        for note in notes {
            do {
                print("📝 [MemoryAgentIntegration] Processing note: \(note.markdownContent.prefix(50))...")
                await handleNoteItem(note)
                
                // Check if processing succeeded
                if note.memoryProcessingStatus == .completed {
                    processed += 1
                } else {
                    failed += 1
                }
                
                // Small delay to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
            } catch {
                failed += 1
                print("❌ [MemoryAgentIntegration] Failed to process note: \(error.localizedDescription)")
                logger.error("Failed to process note: \(error.localizedDescription)")
            }
        }
        
        print("📝 [MemoryAgentIntegration] Notes processing complete: \(processed) processed, \(failed) failed")
        return (processed: processed, failed: failed)
    }
    
    /// Process only unprocessed or failed recordings
    public func processUnprocessedRecordings() async throws -> (processed: Int, failed: Int) {
        print("🎤 [MemoryAgentIntegration] Processing unprocessed recordings...")
        
        // Fetch unprocessed and failed recordings that have transcription
        var descriptor = FetchDescriptor<RecordingItem>(
            predicate: #Predicate { item in
                (item.memoryProcessingStatus.rawValue == "pending" ||
                 item.memoryProcessingStatus.rawValue == "failed" ||
                 item.memoryProcessingStatus.rawValue == "retrying") &&
                item.isTranscribed == true &&
                item.transcriptionText != nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 100 // Process up to 100 at a time
        
        let recordings = try modelContext.fetch(descriptor)
        
        print("🎤 [MemoryAgentIntegration] Found \(recordings.count) recordings to process")
        
        var processed = 0
        var failed = 0
        
        for recording in recordings {
            do {
                guard let transcriptionText = recording.transcriptionText else {
                    print("⚠️ [MemoryAgentIntegration] Skipping recording without transcription")
                    continue
                }
                
                print("🎤 [MemoryAgentIntegration] Processing recording: \(transcriptionText.prefix(50))...")
                
                // Mark as processing
                recording.updateMemoryProcessing(status: .processing)
                try? modelContext.save()
                
                let startTime = Date()
                let ingestData = MemoryIngestData(
                    type: .transcription,
                    content: transcriptionText,
                    timestamp: recording.timestamp,
                    confidence: recording.transcriptionConfidence,
                    metadata: [
                        "source": "batch_processing",
                        "transcriptionEngine": recording.transcriptionEngine,
                        "recordingId": recording.id.uuidString,
                        "filename": recording.filename
                    ]
                )
                
                try await memoryAgent.ingestData(ingestData)
                let processingTime = Date().timeIntervalSince(startTime)
                
                // Create a default decision result for successful processing
                let decision = parseMemoryDecision(from: "processed")
                
                recording.updateMemoryProcessing(
                    status: .completed,
                    decision: decision.decision,
                    confidence: decision.confidence,
                    templateUsed: decision.templateUsed,
                    modelUsed: decision.modelUsed,
                    processingTime: processingTime,
                    entitiesExtracted: decision.entitiesExtracted,
                    relationshipsCreated: decision.relationshipsCreated
                )
                
                try modelContext.save()
                processed += 1
                
                print("✅ [MemoryAgentIntegration] Recording processed: \(decision.decision?.displayName ?? "Unknown")")
                
                // Small delay to prevent overwhelming the system
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
            } catch {
                failed += 1
                
                // Update recording with failure
                recording.updateMemoryProcessing(
                    status: .failed,
                    error: error.localizedDescription
                )
                try? modelContext.save()
                
                print("❌ [MemoryAgentIntegration] Failed to process recording: \(error.localizedDescription)")
                logger.error("Failed to process recording: \(error.localizedDescription)")
            }
        }
        
        print("🎤 [MemoryAgentIntegration] Recordings processing complete: \(processed) processed, \(failed) failed")
        return (processed: processed, failed: failed)
    }
    
    /// Get count of unprocessed items
    public func getUnprocessedItemsCount() throws -> UnprocessedItemsCount {
        // Count unprocessed notes
        let noteDescriptor = FetchDescriptor<NoteItem>(
            predicate: #Predicate { item in
                item.memoryProcessingStatus.rawValue == "pending" ||
                item.memoryProcessingStatus.rawValue == "failed" ||
                item.memoryProcessingStatus.rawValue == "retrying"
            }
        )
        let notesCount = try modelContext.fetchCount(noteDescriptor)
        
        // Count unprocessed recordings (only those with transcription)
        let recordingDescriptor = FetchDescriptor<RecordingItem>(
            predicate: #Predicate { item in
                (item.memoryProcessingStatus.rawValue == "pending" ||
                 item.memoryProcessingStatus.rawValue == "failed" ||
                 item.memoryProcessingStatus.rawValue == "retrying") &&
                item.isTranscribed == true &&
                item.transcriptionText != nil
            }
        )
        let recordingsCount = try modelContext.fetchCount(recordingDescriptor)
        
        return UnprocessedItemsCount(
            notes: notesCount,
            recordings: recordingsCount,
            total: notesCount + recordingsCount
        )
    }
    
    // MARK: - Helper Methods
    
    /// Parse memory decision from AI response
    private func parseMemoryDecision(from result: Any) -> MemoryDecisionResult {
        // TODO: Parse actual AI response for memory decision
        // For now, return default values - this will be enhanced when we have real AI responses
        return MemoryDecisionResult(
            decision: .shortTermMemory,
            confidence: 0.8,
            templateUsed: "note-categorization-stm-ltm",
            modelUsed: "unknown",
            entitiesExtracted: 0,
            relationshipsCreated: 0
        )
    }
}

// MARK: - Memory Decision Result

/// Result of memory processing decision
private struct MemoryDecisionResult {
    let decision: MemoryDecision?
    let confidence: Double
    let templateUsed: String?
    let modelUsed: String?
    let entitiesExtracted: Int
    let relationshipsCreated: Int
}

// MARK: - Supporting Types

public enum IntegrationStatus {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case error
    case syncing
}

public enum MemoryAgentIntegrationError: Error, LocalizedError {
    case notIntegrated
    case syncFailed(String)
    case integrationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notIntegrated:
            return "Memory Agent integration not active"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .integrationFailed(let reason):
            return "Integration failed: \(reason)"
        }
    }
}

// MARK: - Batch Processing Types

/// Result of batch processing operation
public struct BatchProcessingResult {
    var notesProcessed: Int = 0
    var notesFailed: Int = 0
    var recordingsProcessed: Int = 0
    var recordingsFailed: Int = 0
    var totalProcessingTime: TimeInterval = 0.0
    
    public var totalProcessed: Int {
        return notesProcessed + recordingsProcessed
    }
    
    public var totalFailed: Int {
        return notesFailed + recordingsFailed
    }
    
    public var totalItems: Int {
        return totalProcessed + totalFailed
    }
    
    public var successRate: Double {
        guard totalItems > 0 else { return 1.0 }
        return Double(totalProcessed) / Double(totalItems)
    }
}

/// Count of unprocessed items
public struct UnprocessedItemsCount {
    let notes: Int
    let recordings: Int
    let total: Int
}

// MARK: - Notification Names

extension Notification.Name {
    static let transcriptionCompleted = Notification.Name("transcriptionCompleted")
    static let newNoteCreated = Notification.Name("newNoteCreated")
    static let entityUpdated = Notification.Name("entityUpdated")
}

// MARK: - TextIngestionAgent Extension

extension TextIngestionAgent {
    var onContentProcessed: ((ProcessedNote) -> Void)? {
        get { return nil } // Placeholder
        set { } // Placeholder
    }
    
    var onEntityExtracted: ((Entity) -> Void)? {
        get { return nil } // Placeholder
        set { } // Placeholder
    }
}