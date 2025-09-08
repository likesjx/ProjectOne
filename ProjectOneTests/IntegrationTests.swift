//
//  IntegrationTests.swift
//  ProjectOneTests
//
//  Comprehensive integration tests - implements end-to-end testing
//  as recommended in the GPT-5 feedback
//

import XCTest
import SwiftData
@testable import ProjectOne

@MainActor
final class IntegrationTests: XCTestCase {
    var systemManager: UnifiedSystemManager!
    var memoryAgent: MemoryAgent!
    var aiProvider: WorkingMLXProvider!
    var modelContainer: SwiftData.ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            STMEntry.self,
            LTMEntry.self,
            EpisodicMemoryEntry.self,
            Entity.self,
            Relationship.self,
            ProcessedNote.self,
            RecordingItem.self,
            MemoryAnalytics.self,
            ConsolidationEvent.self,
            MemoryPerformanceMetric.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext
        
        // Initialize system with mock service factory for testing
        let mockServiceFactory = MockServiceFactory()
        systemManager = UnifiedSystemManager(
            modelContext: modelContext,
            configuration: .default,
            serviceFactory: mockServiceFactory
        )
        
        // Initialize the system
        try await systemManager.initializeSystem()
        
        // Get references to key components
        memoryAgent = systemManager.memoryService?.memoryAgent
        aiProvider = systemManager.mlxService?.aiProvider as? WorkingMLXProvider
    }
    
    override func tearDownWithError() throws {
        systemManager = nil
        memoryAgent = nil
        aiProvider = nil
        modelContainer = nil
        modelContext = nil
    }
    
    // MARK: - End-to-End Tests
    
    func testEndToEndVoiceMemoProcessing() async throws {
        // Given: Voice memo recording
        let audioData = createTestAudioData()
        let voiceMemo = RecordingItem(
            audioData: audioData,
            timestamp: Date(),
            duration: 30.0
        )
        
        // When: Process through entire pipeline
        let transcription = try await systemManager.transcribeAudio(audioData)
        let memoryEntry = try await memoryAgent?.ingestTranscription(transcription)
        let aiAnalysis = try await aiProvider?.analyzeContent(memoryEntry?.content ?? "")
        
        // Then: Verify complete workflow
        XCTAssertNotNil(transcription)
        XCTAssertNotNil(memoryEntry)
        XCTAssertNotNil(aiAnalysis)
        XCTAssertTrue(memoryEntry?.isConsolidated ?? false)
    }
    
    func testCrossComponentMemoryRetrieval() async throws {
        // Given: Multiple memory entries
        let entries = [
            createMemoryEntry(content: "Meeting with John about project Alpha"),
            createMemoryEntry(content: "Lunch with Sarah at Luigi's Pizza"),
            createMemoryEntry(content: "Project Alpha deadline is next Friday")
        ]
        
        for entry in entries {
            try await memoryAgent?.ingestData(entry)
        }
        
        // When: Query across all components
        let query = "What did I discuss about Project Alpha?"
        let response = try await memoryAgent?.processQuery(query)
        
        // Then: Verify cross-component integration
        XCTAssertNotNil(response)
        XCTAssertTrue(response?.content.contains("John") ?? false)
        XCTAssertTrue(response?.content.contains("deadline") ?? false)
        XCTAssertGreaterThan(response?.confidence ?? 0.0, 0.7)
    }
    
    func testKnowledgeGraphIntegration() async throws {
        // Given: Memory entries with entities
        let entry = createMemoryEntry(content: "Meeting with John Smith about Project Alpha at 2pm tomorrow")
        try await memoryAgent?.ingestData(entry)
        
        // When: Query knowledge graph
        let entities = try await systemManager.knowledgeGraphService?.getAllEntities()
        
        // Then: Verify entities were extracted
        XCTAssertNotNil(entities)
        XCTAssertGreaterThan(entities?.count ?? 0, 0)
        
        // Verify specific entities
        let personEntities = entities?.filter { $0.type == "person" } ?? []
        XCTAssertTrue(personEntities.contains { $0.name.contains("John") })
        
        let projectEntities = entities?.filter { $0.type == "project" } ?? []
        XCTAssertTrue(projectEntities.contains { $0.name.contains("Alpha") })
    }
    
    // MARK: - Performance Tests
    
    func testMemoryRetrievalPerformance() async throws {
        // Given: Large dataset
        let largeDataset = createLargeMemoryDataset(count: 1000)
        
        // When: Measure retrieval performance
        let startTime = Date()
        let results = try await memoryAgent?.retrieveMemories(query: "test", limit: 50)
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then: Verify performance targets
        XCTAssertLessThan(duration, 0.5, "Memory retrieval should complete within 500ms")
        XCTAssertEqual(results?.count ?? 0, 50)
    }
    
    func testConcurrentAccessPerformance() async throws {
        // Given: Multiple concurrent requests
        let concurrentTasks = 10
        let tasks = (0..<concurrentTasks).map { index in
            Task {
                let query = "Concurrent test query \(index)"
                return try await memoryAgent?.processQuery(query)
            }
        }
        
        // When: Execute concurrently
        let startTime = Date()
        let results = try await withThrowingTaskGroup(of: AIModelResponse?.self) { group in
            for task in tasks {
                group.addTask {
                    return try await task.value
                }
            }
            
            var responses: [AIModelResponse?] = []
            for try await response in group {
                responses.append(response)
            }
            return responses
        }
        let endTime = Date()
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Then: Verify concurrent performance
        XCTAssertEqual(results.count, concurrentTasks)
        XCTAssertLessThan(duration, 5.0, "Concurrent processing should complete within 5 seconds")
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkFailureRecovery() async throws {
        // Given: Network failure scenario
        let mockNetworkProvider = MockNetworkProvider(shouldFail: true)
        let aiProvider = WorkingMLXProvider(networkProvider: mockNetworkProvider)
        
        // When: Attempt AI operation
        do {
            let response = try await aiProvider.generateResponse(to: "test query")
            XCTFail("Should have thrown network error")
        } catch {
            // Then: Verify proper error handling
            XCTAssertTrue(error is NetworkError || error.localizedDescription.contains("network"))
        }
    }
    
    func testMemoryCorruptionRecovery() async throws {
        // Given: Corrupted memory data
        let corruptedData = createCorruptedMemoryData()
        
        // When: Attempt to load corrupted data
        do {
            let memory = try MemoryAgent.loadFromData(corruptedData)
            XCTFail("Should have thrown corruption error")
        } catch {
            // Then: Verify recovery mechanism
            XCTAssertTrue(error is MemoryCorruptionError || error.localizedDescription.contains("corruption"))
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestAudioData() -> Data {
        // Create mock audio data for testing
        return Data(repeating: 0, count: 1024)
    }
    
    private func createMemoryEntry(content: String) -> MemoryIngestData {
        return MemoryIngestData(
            type: .note,
            content: content,
            confidence: 1.0,
            metadata: ["type": "test"]
        )
    }
    
    private func createLargeMemoryDataset(count: Int) -> [MemoryIngestData] {
        return (0..<count).map { index in
            createMemoryEntry(content: "Test memory entry \(index)")
        }
    }
    
    private func createCorruptedMemoryData() -> Data {
        // Create corrupted data for testing
        return Data(repeating: 255, count: 100)
    }
}

// MARK: - Mock Implementations

class MockNetworkProvider {
    let shouldFail: Bool
    
    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }
}

enum NetworkError: Error {
    case connectionFailed
    case timeout
}

enum MemoryCorruptionError: Error {
    case dataCorrupted
    case invalidFormat
}
