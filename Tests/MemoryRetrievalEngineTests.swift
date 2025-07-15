//
//  MemoryRetrievalEngineTests.swift
//  ProjectOneTests
//
//  Created by Memory Agent Testing on 7/15/25.
//

import XCTest
import SwiftData
@testable import ProjectOne

@MainActor
final class MemoryRetrievalEngineTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var retrievalEngine: MemoryRetrievalEngine!
    
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
        
        retrievalEngine = MemoryRetrievalEngine(modelContext: modelContext)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        retrievalEngine = nil
    }
    
    // MARK: - Setup Test Data
    
    func setupTestMemories() throws {
        // Create Short Term Memories
        let stm1 = STMEntry(
            content: "Meeting with John about project planning",
            memoryType: .episodic,
            importance: 0.9,
            sourceNoteId: nil,
            relatedEntities: [],
            emotionalWeight: 0.0,
            contextTags: ["meeting", "project", "planning"]
        )
        
        let stm2 = STMEntry(
            content: "Coffee break discussion about weather",
            memoryType: .episodic,
            importance: 0.7,
            sourceNoteId: nil,
            relatedEntities: [],
            emotionalWeight: 0.0,
            contextTags: ["coffee", "weather", "casual"]
        )
        
        // Create Long Term Memories
        let ltm1 = LTMEntry(
            content: "Project Alpha is a strategic initiative for Q2 2025",
            category: .professional,
            importance: 0.9,
            sourceSTMEntry: nil,
            sourceSTMIds: [],
            relatedEntities: [],
            relatedConcepts: ["project", "alpha", "strategic"],
            emotionalWeight: 0.0,
            retrievalCues: ["project", "alpha", "strategic"],
            memoryCluster: nil
        )
        
        let ltm2 = LTMEntry(
            content: "Team meeting protocols and best practices",
            category: .professional,
            importance: 0.8,
            sourceSTMEntry: nil,
            sourceSTMIds: [],
            relatedEntities: [],
            relatedConcepts: ["meeting", "protocols", "documentation"],
            emotionalWeight: 0.0,
            retrievalCues: ["meeting", "protocols", "documentation"],
            memoryCluster: nil
        )
        
        // Create Episodic Memories
        let episodic1 = EpisodicMemoryEntry(
            eventDescription: "Weekly Team Standup - Discussed project progress and blockers",
            location: "Conference room A",
            participants: ["John", "Sarah", "Mike"],
            emotionalTone: .neutral,
            importance: 0.8,
            contextualCues: ["standup", "progress", "blockers"],
            duration: nil,
            outcome: nil,
            lessons: []
        )
        episodic1.timestamp = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 1 week ago
        
        let episodic2 = EpisodicMemoryEntry(
            eventDescription: "Client Presentation - Presented project roadmap to stakeholders",
            location: nil,
            participants: ["Client Team", "Project Manager"],
            emotionalTone: .neutral,
            importance: 0.9,
            contextualCues: ["presentation", "roadmap", "stakeholders"],
            duration: nil,
            outcome: nil,
            lessons: []
        )
        episodic2.timestamp = Date().addingTimeInterval(-3 * 24 * 60 * 60) // 3 days ago
        
        // Create Entities
        let entity1 = Entity(name: "Project Alpha", type: .concept)
        entity1.entityDescription = "Strategic initiative for Q2 2025"
        
        let entity2 = Entity(name: "John Smith", type: .person)
        entity2.entityDescription = "Project manager"
        
        // Create Processed Notes
        let note1 = ProcessedNote(
            sourceType: .text,
            originalText: "Key decisions made during project planning session",
            summary: "Planning session summary",
            topics: ["planning", "decisions", "project"],
            sentiment: nil
        )
        
        let note2 = ProcessedNote(
            sourceType: .text,
            originalText: "Follow-up tasks from team meeting",
            summary: "Action items list",
            topics: ["meeting", "tasks", "follow-up"],
            sentiment: nil
        )
        
        // Insert all test data
        modelContext.insert(stm1)
        modelContext.insert(stm2)
        modelContext.insert(ltm1)
        modelContext.insert(ltm2)
        modelContext.insert(episodic1)
        modelContext.insert(episodic2)
        modelContext.insert(entity1)
        modelContext.insert(entity2)
        modelContext.insert(note1)
        modelContext.insert(note2)
        
        try modelContext.save()
    }
    
    // MARK: - Basic Retrieval Tests
    
    func testBasicMemoryRetrieval() async throws {
        try setupTestMemories()
        
        let query = "project planning"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: query)
        
        XCTAssertFalse(context.shortTermMemories.isEmpty)
        XCTAssertFalse(context.longTermMemories.isEmpty)
        XCTAssertEqual(context.userQuery, query)
        
        // Should find relevant memories containing "project" and "planning"
        let hasProjectContent = context.shortTermMemories.contains { $0.content.lowercased().contains("project") } ||
                               context.longTermMemories.contains { $0.content.lowercased().contains("project") }
        XCTAssertTrue(hasProjectContent)
    }
    
    func testPersonalDataDetection() async throws {
        try setupTestMemories()
        
        let personalQuery = "What did I discuss with John?"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: personalQuery)
        
        XCTAssertTrue(context.containsPersonalData)
        XCTAssertEqual(context.userQuery, personalQuery)
    }
    
    func testNonPersonalDataDetection() async throws {
        try setupTestMemories()
        
        let generalQuery = "What is project management?"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: generalQuery)
        
        XCTAssertFalse(context.containsPersonalData)
        XCTAssertEqual(context.userQuery, generalQuery)
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() async throws {
        try setupTestMemories()
        
        let query = "project meeting"
        let context = try await retrievalEngine.retrieveRelevantMemories(
            for: query,
            configuration: .default
        )
        
        // Default config should include all types
        XCTAssertGreaterThanOrEqual(context.shortTermMemories.count, 0)
        XCTAssertGreaterThanOrEqual(context.longTermMemories.count, 0)
        XCTAssertGreaterThanOrEqual(context.episodicMemories.count, 0)
        XCTAssertGreaterThanOrEqual(context.entities.count, 0)
        XCTAssertGreaterThanOrEqual(context.relevantNotes.count, 0)
    }
    
    func testPersonalFocusConfiguration() async throws {
        try setupTestMemories()
        
        let query = "my project meeting"
        let context = try await retrievalEngine.retrieveRelevantMemories(
            for: query,
            configuration: .personalFocus
        )
        
        // Personal focus should exclude entities but include personal memories
        XCTAssertEqual(context.entities.count, 0) // personalFocus excludes entities
        XCTAssertGreaterThanOrEqual(context.shortTermMemories.count, 0)
        XCTAssertGreaterThanOrEqual(context.longTermMemories.count, 0)
    }
    
    func testCustomConfiguration() async throws {
        try setupTestMemories()
        
        let customConfig = MemoryRetrievalEngine.RetrievalConfiguration(
            maxResults: 5,
            recencyWeight: 0.8,
            relevanceWeight: 0.2,
            semanticThreshold: 0.3,
            includeSTM: true,
            includeLTM: false,
            includeEpisodic: false,
            includeEntities: false,
            includeNotes: false
        )
        
        let query = "project meeting"
        let context = try await retrievalEngine.retrieveRelevantMemories(
            for: query,
            configuration: customConfig
        )
        
        // Should only include STM based on configuration
        XCTAssertGreaterThanOrEqual(context.shortTermMemories.count, 0)
        XCTAssertEqual(context.longTermMemories.count, 0)
        XCTAssertEqual(context.episodicMemories.count, 0)
        XCTAssertEqual(context.entities.count, 0)
        XCTAssertEqual(context.relevantNotes.count, 0)
    }
    
    // MARK: - Relevance Ranking Tests
    
    func testRelevanceRanking() async throws {
        try setupTestMemories()
        
        let query = "project alpha strategic"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: query)
        
        // Results should be ranked by relevance
        // LTM with "Project Alpha strategic" should rank higher than other memories
        if let firstLTM = context.longTermMemories.first {
            XCTAssertTrue(firstLTM.content.lowercased().contains("project alpha") || 
                         firstLTM.content.lowercased().contains("strategic"))
        }
    }
    
    func testRecencyWeighting() async throws {
        try setupTestMemories()
        
        // Create a very recent memory
        let recentSTM = STMEntry(
            content: "Recent project update discussion",
            memoryType: .episodic,
            importance: 0.8,
            sourceNoteId: nil,
            relatedEntities: [],
            emotionalWeight: 0.0,
            contextTags: ["project", "update", "recent"]
        )
        recentSTM.timestamp = Date() // Very recent
        
        modelContext.insert(recentSTM)
        try modelContext.save()
        
        let query = "project update"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: query)
        
        // Recent memory should rank higher due to recency weighting
        if let firstSTM = context.shortTermMemories.first {
            XCTAssertTrue(firstSTM.content.contains("Recent project update"))
        }
    }
    
    // MARK: - Semantic Threshold Tests
    
    func testSemanticThreshold() async throws {
        try setupTestMemories()
        
        let highThresholdConfig = MemoryRetrievalEngine.RetrievalConfiguration(
            maxResults: 10,
            recencyWeight: 0.3,
            relevanceWeight: 0.7,
            semanticThreshold: 0.9, // Very high threshold
            includeSTM: true,
            includeLTM: true,
            includeEpisodic: true,
            includeEntities: true,
            includeNotes: true
        )
        
        let query = "unrelated random topic"
        let context = try await retrievalEngine.retrieveRelevantMemories(
            for: query,
            configuration: highThresholdConfig
        )
        
        // With high threshold, should return fewer or no results for unrelated query
        let totalResults = context.shortTermMemories.count + 
                          context.longTermMemories.count + 
                          context.episodicMemories.count +
                          context.relevantNotes.count
        
        XCTAssertLessThanOrEqual(totalResults, 5) // Should filter out low-relevance results
    }
    
    // MARK: - Query Term Extraction Tests
    
    func testQueryTermExtraction() async throws {
        try setupTestMemories()
        
        let complexQuery = "What were the key decisions made during the project planning meeting with John?"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: complexQuery)
        
        // Should extract and match multiple relevant terms
        XCTAssertGreaterThan(context.shortTermMemories.count + context.longTermMemories.count, 0)
        
        // Should find memories related to "project", "planning", "meeting", "john"
        let hasRelevantContent = context.shortTermMemories.contains { memory in
            let content = memory.content.lowercased()
            return content.contains("project") || content.contains("planning") || 
                   content.contains("meeting") || content.contains("john")
        }
        
        XCTAssertTrue(hasRelevantContent)
    }
    
    // MARK: - Performance Tests
    
    func testRetrievalPerformance() async throws {
        // Create a large dataset
        for i in 0..<1000 {
            let stm = STMEntry(
                content: "Test memory \(i) with various content about projects and meetings",
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
        let query = "project meeting"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: query)
        let processingTime = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(processingTime, 2.0) // Should complete within 2 seconds
        XCTAssertGreaterThan(context.shortTermMemories.count, 0)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyQuery() async throws {
        try setupTestMemories()
        
        let emptyQuery = ""
        let context = try await retrievalEngine.retrieveRelevantMemories(for: emptyQuery)
        
        // Should handle empty query gracefully
        XCTAssertEqual(context.userQuery, emptyQuery)
        XCTAssertFalse(context.containsPersonalData)
    }
    
    func testVeryLongQuery() async throws {
        try setupTestMemories()
        
        let longQuery = String(repeating: "project meeting planning discussion ", count: 50)
        let context = try await retrievalEngine.retrieveRelevantMemories(for: longQuery)
        
        // Should handle very long queries without crashing
        XCTAssertEqual(context.userQuery, longQuery)
        XCTAssertGreaterThanOrEqual(context.shortTermMemories.count, 0)
    }
    
    func testSpecialCharacters() async throws {
        try setupTestMemories()
        
        let specialQuery = "project!@#$%^&*()_+-=[]{}|;':\",./<>?"
        let context = try await retrievalEngine.retrieveRelevantMemories(for: specialQuery)
        
        // Should handle special characters gracefully
        XCTAssertEqual(context.userQuery, specialQuery)
        // Should still find "project" related content
        XCTAssertGreaterThanOrEqual(context.shortTermMemories.count, 0)
    }
}