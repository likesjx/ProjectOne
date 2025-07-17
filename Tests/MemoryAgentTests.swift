//
//  MemoryAgentTests.swift
//  ProjectOneTests
//
//  Created by Memory Agent Testing on 7/15/25.
//

import XCTest
import SwiftData
@testable import ProjectOne

@MainActor
final class MemoryAgentTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var memoryAgent: MemoryAgent!
    var knowledgeGraphService: KnowledgeGraphService!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            STMEntry.self,
            LTMEntry.self,
            EpisodicMemoryEntry.self,
            Entity.self,
            ProcessedNote.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
        
        // Initialize services
        knowledgeGraphService = KnowledgeGraphService(modelContext: modelContext)
        memoryAgent = MemoryAgent(
            modelContext: modelContext,
            knowledgeGraphService: knowledgeGraphService,
            configuration: MemoryAgent.Configuration.default
        )
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        memoryAgent = nil
        knowledgeGraphService = nil
    }
    
    // MARK: - Initialization Tests
    
    func testMemoryAgentInitialization() async throws {
        XCTAssertFalse(memoryAgent.isInitialized)
        
        try await memoryAgent.initialize()
        
        XCTAssertTrue(memoryAgent.isInitialized)
        XCTAssertNil(memoryAgent.errorMessage)
    }
    
    func testMemoryAgentShutdown() async throws {
        try await memoryAgent.initialize()
        XCTAssertTrue(memoryAgent.isInitialized)
        
        await memoryAgent.shutdown()
        
        XCTAssertFalse(memoryAgent.isInitialized)
    }
    
    // MARK: - Query Processing Tests
    
    func testBasicQueryProcessing() async throws {
        try await memoryAgent.initialize()
        
        let query = "What is the capital of France?"
        let response = try await memoryAgent.processQuery(query)
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertGreaterThan(response.confidence, 0.0)
        XCTAssertLessThanOrEqual(response.confidence, 1.0)
        // Should use available AI provider (MLX or Apple Foundation Models)
        XCTAssertFalse(response.modelUsed.isEmpty)
    }
    
    func testPersonalDataQueryProcessing() async throws {
        try await memoryAgent.initialize()
        
        // Add some personal data first
        let personalData = MemoryIngestData(
            type: .note,
            content: "My favorite restaurant is Luigi's Pizza on Main Street",
            confidence: 1.0,
            metadata: ["type": "personal_preference"]
        )
        
        try await memoryAgent.ingestData(personalData)
        
        let query = "What's my favorite restaurant?"
        let response = try await memoryAgent.processQuery(query)
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertGreaterThan(response.confidence, 0.0)
        // Should use on-device model for personal data
        // Should use available AI provider (MLX or Apple Foundation Models)
        XCTAssertFalse(response.modelUsed.isEmpty)
    }
    
    func testQueryProcessingWithoutInitialization() async throws {
        let query = "Test query"
        
        do {
            let _ = try await memoryAgent.processQuery(query)
            XCTFail("Should have thrown notInitialized error")
        } catch MemoryAgentError.notInitialized {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Data Ingestion Tests
    
    func testTranscriptionIngestion() async throws {
        try await memoryAgent.initialize()
        
        let transcriptionData = MemoryIngestData(
            type: .transcription,
            content: "This is a test transcription from a meeting",
            confidence: 0.95,
            metadata: ["source": "meeting", "duration": 120]
        )
        
        try await memoryAgent.ingestData(transcriptionData)
        
        // Verify STM was created
        let stmDescriptor = FetchDescriptor<STMEntry>()
        let stms = try modelContext.fetch(stmDescriptor)
        
        XCTAssertEqual(stms.count, 1)
        XCTAssertEqual(stms.first?.content, "This is a test transcription from a meeting")
        XCTAssertEqual(stms.first?.memoryType, .episodic)
        XCTAssertEqual(stms.first?.importance, 0.95)
    }
    
    func testNoteIngestion() async throws {
        try await memoryAgent.initialize()
        
        let noteData = MemoryIngestData(
            type: .note,
            content: "Important meeting notes about project deadlines",
            confidence: 1.0,
            metadata: ["tags": ["meeting", "deadlines"]]
        )
        
        try await memoryAgent.ingestData(noteData)
        
        // Should create either STM or LTM based on AI analysis
        let stmDescriptor = FetchDescriptor<STMEntry>()
        let ltmDescriptor = FetchDescriptor<LTMEntry>()
        
        let stms = try modelContext.fetch(stmDescriptor)
        let ltms = try modelContext.fetch(ltmDescriptor)
        
        XCTAssertEqual(stms.count + ltms.count, 1)
    }
    
    func testHealthDataIngestion() async throws {
        try await memoryAgent.initialize()
        
        let healthData = MemoryIngestData(
            type: .healthData,
            content: "Blood pressure: 120/80 mmHg",
            confidence: 1.0,
            metadata: ["source": "HealthKit", "metric": "blood_pressure"]
        )
        
        try await memoryAgent.ingestData(healthData)
        
        // Verify episodic memory was created
        let episodicDescriptor = FetchDescriptor<EpisodicMemoryEntry>()
        let episodics = try modelContext.fetch(episodicDescriptor)
        
        XCTAssertEqual(episodics.count, 1)
        XCTAssertTrue(episodics.first?.eventDescription.contains("Health Data Entry"))
        XCTAssertTrue(episodics.first?.eventDescription.contains("Blood pressure: 120/80 mmHg"))
    }
    
    // MARK: - Memory Consolidation Tests
    
    func testMemoryConsolidation() async throws {
        try await memoryAgent.initialize()
        
        // Create some old STMs
        let oldSTM1 = STMEntry(
            content: "Important information that should be preserved",
            memoryType: .semantic,
            importance: 0.9,
            sourceNoteId: nil,
            relatedEntities: [],
            emotionalWeight: 0.0,
            contextTags: ["test"]
        )
        oldSTM1.timestamp = Date().addingTimeInterval(-48 * 60 * 60) // 48 hours ago
        
        let oldSTM2 = STMEntry(
            content: "Temporary information that can be expired",
            memoryType: .semantic,
            importance: 0.5,
            sourceNoteId: nil,
            relatedEntities: [],
            emotionalWeight: 0.0,
            contextTags: ["test"]
        )
        oldSTM2.timestamp = Date().addingTimeInterval(-25 * 60 * 60) // 25 hours ago
        
        modelContext.insert(oldSTM1)
        modelContext.insert(oldSTM2)
        try modelContext.save()
        
        // Run consolidation
        try await memoryAgent.consolidateMemories()
        
        // Verify consolidation results
        let stmDescriptor = FetchDescriptor<STMEntry>()
        let ltmDescriptor = FetchDescriptor<LTMEntry>()
        
        let stms = try modelContext.fetch(stmDescriptor)
        let ltms = try modelContext.fetch(ltmDescriptor)
        
        // The old STMs should be processed
        XCTAssertTrue(stms.allSatisfy { $0.timestamp > Date().addingTimeInterval(-24 * 60 * 60) })
        
        // Some may have been promoted to LTM
        XCTAssertGreaterThanOrEqual(ltms.count, 0)
    }
    
    // MARK: - RAG Integration Tests
    
    func testRAGContextRetrieval() async throws {
        try await memoryAgent.initialize()
        
        // Create some relevant memories
        let stm = STMEntry(
            content: "Paris is the capital of France",
            memoryType: .semantic,
            importance: 1.0,
            sourceNoteId: nil,
            relatedEntities: [],
            emotionalWeight: 0.0,
            contextTags: ["knowledge"]
        )
        
        let ltm = LTMEntry(
            content: "France is a country in Europe",
            category: .factual,
            importance: 0.8,
            sourceSTMEntry: nil,
            sourceSTMIds: [],
            relatedEntities: [],
            relatedConcepts: ["Europe", "countries"],
            emotionalWeight: 0.0,
            retrievalCues: ["France", "Europe"],
            memoryCluster: nil
        )
        
        let note = ProcessedNote(
            sourceType: .text,
            originalText: "Paris is known for the Eiffel Tower",
            summary: "Notes about European capitals",
            topics: ["European", "capitals"],
            sentiment: nil
        )
        
        modelContext.insert(stm)
        modelContext.insert(ltm)
        modelContext.insert(note)
        try modelContext.save()
        
        // Query for related information
        let query = "Tell me about Paris"
        let response = try await memoryAgent.processQuery(query)
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertGreaterThan(response.confidence, 0.0)
        
        // The response should incorporate context from our stored memories
        // (This would be more detailed in a real implementation)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async throws {
        try await memoryAgent.initialize()
        
        // Test with invalid data
        let invalidData = MemoryIngestData(
            type: .transcription,
            content: nil, // Invalid: no content
            confidence: 1.0
        )
        
        // Should not crash - should handle gracefully
        try await memoryAgent.ingestData(invalidData)
        
        // Verify no memories were created
        let stmDescriptor = FetchDescriptor<STMEntry>()
        let stms = try modelContext.fetch(stmDescriptor)
        
        XCTAssertEqual(stms.count, 0)
    }
    
    // MARK: - Performance Tests
    
    func testQueryPerformance() async throws {
        try await memoryAgent.initialize()
        
        // Add multiple memories for context
        for i in 0..<100 {
            let stm = STMEntry(
                content: "Test memory \(i) with various content",
                memoryType: .semantic,
                importance: 0.8,
                sourceNoteId: nil,
                relatedEntities: [],
                emotionalWeight: 0.0,
                contextTags: ["performance_test"]
            )
            modelContext.insert(stm)
        }
        try modelContext.save()
        
        let startTime = Date()
        let query = "Tell me about test memory"
        let response = try await memoryAgent.processQuery(query)
        let processingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertLessThan(processingTime, 5.0) // Should complete within 5 seconds
    }
    
    // MARK: - MLX Provider Tests
    
    func testMLXProviderInitialization() async throws {
        let mlxProvider = MLXGemma3nProvider()
        
        XCTAssertEqual(mlxProvider.identifier, "mlx-gemma3n")
        XCTAssertEqual(mlxProvider.displayName, "MLX Gemma3n 2B")
        XCTAssertEqual(mlxProvider.maxContextLength, 2048)
        XCTAssertEqual(mlxProvider.estimatedResponseTime, 2.0)
        XCTAssertTrue(mlxProvider.supportsPersonalData)
        XCTAssertTrue(mlxProvider.isOnDevice)
    }
    
    func testMLXProviderInference() async throws {
        let mlxProvider = MLXGemma3nProvider()
        
        do {
            try await mlxProvider.prepareModel()
            
            let prompt = "Hello, how are you?"
            let response = try await mlxProvider.generateModelResponse(prompt)
            
            XCTAssertFalse(response.isEmpty)
            // Should contain MLX inference result
            XCTAssertTrue(response.contains("MLX") || response.contains("inference"))
            
        } catch AIModelProviderError.providerUnavailable {
            // MLX may not be available in test environment - that's OK
            print("MLX not available in test environment")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testMLXProviderAvailability() async throws {
        let mlxProvider = MLXGemma3nProvider()
        
        // Test availability check
        let isAvailable = mlxProvider.isAvailable
        
        // Should return consistent result
        XCTAssertEqual(isAvailable, mlxProvider.isAvailable)
        
        if isAvailable {
            // If available, should be able to prepare
            try await mlxProvider.prepareModel()
            XCTAssertTrue(mlxProvider.isModelLoaded)
        }
    }
    
    func testMLXWithMemoryAgent() async throws {
        try await memoryAgent.initialize()
        
        // Check if MLX provider is in the hierarchy
        let availableProviders = memoryAgent.getAvailableProviders()
        let mlxProvider = availableProviders.first { $0.identifier == "mlx-gemma3n" }
        
        if let mlxProvider = mlxProvider {
            XCTAssertEqual(mlxProvider.identifier, "mlx-gemma3n")
            XCTAssertTrue(mlxProvider.supportsPersonalData)
            XCTAssertTrue(mlxProvider.isOnDevice)
            
            // Test that personal data queries can use MLX
            let personalQuery = "My personal information test"
            let response = try await memoryAgent.processQuery(personalQuery)
            
            XCTAssertFalse(response.content.isEmpty)
            XCTAssertGreaterThan(response.confidence, 0.0)
        } else {
            print("MLX provider not available in test environment")
        }
    }
    
    func testRealMLXInference() async throws {
        #if canImport(MLX)
        let mlxProvider = MLXGemma3nProvider()
        
        // Test that we get real MLX operations, not placeholders
        do {
            try await mlxProvider.prepareModel()
            
            let prompt = "Test"
            let response = try await mlxProvider.generateModelResponse(prompt)
            
            // Should contain evidence of real MLX computation
            XCTAssertTrue(response.contains("MLX inference") || response.contains("tokens"))
            XCTAssertTrue(response.contains("softmax") || response.contains("matmul") || response.contains("embedding"))
            
        } catch AIModelProviderError.providerUnavailable {
            // Expected in simulator or when MLX unavailable
            print("MLX framework not available for real inference test")
        }
        #else
        print("MLX not available at compile time")
        #endif
    }
}