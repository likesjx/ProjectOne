//
//  KnowledgeGraphCognitiveIntegrationTests.swift
//  ProjectOneTests
//
//  Created by Claude on 8/19/25.
//  Unit tests for Knowledge Graph - Cognitive Memory integration
//

import XCTest
import SwiftData
@testable import ProjectOne

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
final class KnowledgeGraphCognitiveIntegrationTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var cognitiveSystem: CognitiveMemorySystem!
    var cognitiveAdapter: KnowledgeGraphCognitiveAdapter!
    var knowledgeGraphService: KnowledgeGraphService!
    
    override func setUp() async throws {
        super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            Entity.self,
            Relationship.self,
            VeridicalNode.self,
            SemanticNode.self,
            EpisodicNode.self,
            FusionNode.self
        ])
        
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Initialize cognitive system and adapter
        cognitiveSystem = CognitiveMemorySystem(modelContext: modelContext)
        cognitiveAdapter = KnowledgeGraphCognitiveAdapter(
            modelContext: modelContext,
            cognitiveSystem: cognitiveSystem
        )
        
        knowledgeGraphService = KnowledgeGraphService(
            modelContext: modelContext,
            cognitiveAdapter: cognitiveAdapter
        )
        
        await MainActor.run {
            // Empty since we don't need async setup here
        }
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        cognitiveSystem = nil
        cognitiveAdapter = nil
        knowledgeGraphService = nil
        super.tearDown()
    }
    
    // MARK: - Entity Model Enhancement Tests
    
    func testEntityCognitiveMetadataInitialization() throws {
        let entity = Entity(name: "Test Entity", type: .person)
        
        XCTAssertNil(entity.associatedCognitiveNodeId)
        XCTAssertNil(entity.primaryCognitiveLayer)
        XCTAssertEqual(entity.cognitiveConsolidationScore, 0.0)
        XCTAssertNil(entity.lastCognitiveSyncAt)
        XCTAssertTrue(entity.fusionConnectionIds.isEmpty)
        XCTAssertEqual(entity.cognitiveRelevanceScore, 0.0)
        XCTAssertFalse(entity.hasCognitiveRepresentation)
    }
    
    func testEntityCognitiveAssociation() throws {
        let entity = Entity(name: "Test Person", type: .person)
        let nodeId = UUID().uuidString
        
        entity.associateWithCognitiveNode(nodeId, layer: .semantic)
        
        XCTAssertEqual(entity.associatedCognitiveNodeId, nodeId)
        XCTAssertEqual(entity.primaryCognitiveLayer, CognitiveLayerType.semantic.rawValue)
        XCTAssertNotNil(entity.lastCognitiveSyncAt)
        XCTAssertTrue(entity.hasCognitiveRepresentation)
        XCTAssertEqual(entity.cognitiveLayerType, .semantic)
    }
    
    func testEntityConsolidationScoreUpdate() throws {
        let entity = Entity(name: "Test Entity", type: .concept)
        
        entity.updateCognitiveConsolidationScore(0.8)
        
        XCTAssertEqual(entity.cognitiveConsolidationScore, 0.8)
        XCTAssertNotNil(entity.lastCognitiveSyncAt)
        
        // Test bounds
        entity.updateCognitiveConsolidationScore(1.5)
        XCTAssertEqual(entity.cognitiveConsolidationScore, 1.0)
        
        entity.updateCognitiveConsolidationScore(-0.5)
        XCTAssertEqual(entity.cognitiveConsolidationScore, 0.0)
    }
    
    func testEntityFusionConnectionManagement() throws {
        let entity = Entity(name: "Test Entity", type: .organization)
        let fusionId1 = UUID().uuidString
        let fusionId2 = UUID().uuidString
        
        entity.addFusionConnection(fusionId1)
        XCTAssertEqual(entity.fusionConnectionIds.count, 1)
        XCTAssertTrue(entity.fusionConnectionIds.contains(fusionId1))
        
        // Test duplicate prevention
        entity.addFusionConnection(fusionId1)
        XCTAssertEqual(entity.fusionConnectionIds.count, 1)
        
        entity.addFusionConnection(fusionId2)
        XCTAssertEqual(entity.fusionConnectionIds.count, 2)
        
        entity.removeFusionConnection(fusionId1)
        XCTAssertEqual(entity.fusionConnectionIds.count, 1)
        XCTAssertTrue(entity.fusionConnectionIds.contains(fusionId2))
    }
    
    func testEnhancedEntityScore() throws {
        let entity = Entity(name: "Enhanced Entity", type: .person)
        entity.importance = 0.6
        entity.confidence = 0.8
        entity.mentions = 5
        
        let baseScore = entity.entityScore
        
        // Add cognitive enhancements
        entity.updateCognitiveConsolidationScore(0.9)
        entity.updateCognitiveRelevance(0.7)
        entity.addFusionConnection(UUID().uuidString)
        entity.addFusionConnection(UUID().uuidString)
        
        let enhancedScore = entity.enhancedEntityScore
        
        XCTAssertGreaterThan(enhancedScore, baseScore)
        XCTAssertLessThanOrEqual(enhancedScore, 1.0)
    }
    
    // MARK: - Cognitive Adapter Tests
    
    func testEntityToCognitiveSync() async throws {
        let entity = Entity(name: "Steve Jobs", type: .person)
        entity.entityDescription = "Co-founder of Apple Inc."
        entity.confidence = 0.9
        entity.isValidated = true
        modelContext.insert(entity)
        
        try await cognitiveAdapter.syncEntityToCognitive(entity)
        
        // Verify entity was updated
        XCTAssertNotNil(entity.associatedCognitiveNodeId)
        XCTAssertNotNil(entity.primaryCognitiveLayer)
        XCTAssertNotNil(entity.lastCognitiveSyncAt)
        
        // Verify cognitive node was created
        let layerType = entity.cognitiveLayerType
        XCTAssertNotNil(layerType)
        
        // Check appropriate layer based on entity characteristics
        if entity.isValidated && entity.confidence > 0.8 {
            XCTAssertEqual(layerType, .veridical)
        }
    }
    
    func testBatchEntitySync() async throws {
        let entities = [
            Entity(name: "Apple Inc.", type: .organization),
            Entity(name: "Innovation", type: .concept),
            Entity(name: "Cupertino", type: .location)
        ]
        
        for entity in entities {
            modelContext.insert(entity)
        }
        
        try await cognitiveAdapter.syncEntitiesToCognitive(entities)
        
        // Verify all entities were synced
        for entity in entities {
            XCTAssertTrue(entity.hasCognitiveRepresentation)
            XCTAssertNotNil(entity.associatedCognitiveNodeId)
        }
    }
    
    func testCognitiveToEntitySync() async throws {
        let entity = Entity(name: "Test Entity", type: .concept)
        entity.importance = 0.5
        entity.mentions = 1
        modelContext.insert(entity)
        
        // Sync to cognitive first
        try await cognitiveAdapter.syncEntityToCognitive(entity)
        
        guard let cognitiveNodeId = entity.associatedCognitiveNodeId else {
            XCTFail("Entity should have cognitive node ID after sync")
            return
        }
        
        // Simulate cognitive changes (e.g., increased importance)
        if let layerType = entity.cognitiveLayerType {
            switch layerType {
            case .semantic:
                if let node = cognitiveSystem.semanticLayer.nodes.first(where: { $0.id.uuidString == cognitiveNodeId }) {
                    node.importance = 0.8
                }
            case .veridical:
                if let node = cognitiveSystem.veridicalLayer.nodes.first(where: { $0.id.uuidString == cognitiveNodeId }) {
                    node.importance = 0.8
                }
            default:
                break
            }
        }
        
        let originalImportance = entity.importance
        
        // Sync changes back to entity
        try await cognitiveAdapter.syncCognitiveToEntity(cognitiveNodeId)
        
        // Verify entity was updated
        XCTAssertGreaterThan(entity.importance, originalImportance)
    }
    
    func testSemanticSearch() async throws {
        // Create test entities
        let entities = [
            createTestEntity("Apple Inc.", .organization, "Technology company founded by Steve Jobs"),
            createTestEntity("Steve Jobs", .person, "Co-founder of Apple, visionary leader"),
            createTestEntity("Innovation", .concept, "Creative problem-solving and new ideas"),
            createTestEntity("iPhone", .thing, "Revolutionary smartphone by Apple")
        ]
        
        for entity in entities {
            modelContext.insert(entity)
            try await cognitiveAdapter.syncEntityToCognitive(entity)
        }
        
        // Test semantic search
        let matches = try await cognitiveAdapter.findSimilarEntities(
            query: "technology innovation",
            limit: 5,
            threshold: 0.1
        )
        
        XCTAssertGreaterThan(matches.count, 0)
        
        // Verify matches have relevance scores
        for match in matches {
            XCTAssertGreaterThan(match.cognitiveRelevance, 0.0)
            XCTAssertLessThanOrEqual(match.cognitiveRelevance, 1.0)
        }
    }
    
    // MARK: - Knowledge Graph Service Integration Tests
    
    func testCognitiveSemanticSearchService() async throws {
        await MainActor.run {
            // Create test entities in the service
            knowledgeGraphService.entities = [
                createTestEntity("Machine Learning", .concept, "AI technique for pattern recognition"),
                createTestEntity("Neural Networks", .concept, "Computing systems inspired by biological neural networks"),
                createTestEntity("Data Science", .concept, "Interdisciplinary field using scientific methods")
            ]
        }
        
        // Sync with cognitive system
        try await knowledgeGraphService.syncWithCognitiveSystem()
        
        // Test cognitive search
        let searchResult = try await knowledgeGraphService.cognitiveSemanticSearch(
            query: "artificial intelligence",
            limit: 3
        )
        
        XCTAssertTrue(searchResult.cognitiveEnhanced)
        XCTAssertGreaterThan(searchResult.totalResults, 0)
    }
    
    func testCognitiveGraphInsights() async throws {
        await MainActor.run {
            knowledgeGraphService.entities = [
                createTestEntity("AI Research", .concept, "Artificial intelligence research"),
                createTestEntity("MIT", .organization, "Massachusetts Institute of Technology"),
                createTestEntity("Boston", .location, "City in Massachusetts")
            ]
        }
        
        // Sync and generate insights
        try await knowledgeGraphService.syncWithCognitiveSystem()
        let insights = try await knowledgeGraphService.getCognitiveGraphInsights()
        
        XCTAssertEqual(insights.totalEntities, 3)
        XCTAssertGreaterThan(insights.cognitivelyEnhancedEntities, 0)
        XCTAssertFalse(insights.insights.isEmpty)
        XCTAssertGreaterThanOrEqual(insights.enhancementPercentage, 0)
    }
    
    func testEntitiesNeedingSync() async throws {
        let entity1 = createTestEntity("Recent Entity", .person, "Recently created")
        let entity2 = createTestEntity("Old Entity", .organization, "Old entity")
        
        // Simulate old sync for entity2
        entity2.lastCognitiveSyncAt = Date(timeIntervalSinceNow: -25 * 3600) // 25 hours ago
        
        await MainActor.run {
            knowledgeGraphService.entities = [entity1, entity2]
        }
        
        let entitiesNeedingSync = knowledgeGraphService.findEntitiesNeedingCognitiveSync()
        
        // entity1 needs sync (never synced), entity2 needs sync (too old)
        XCTAssertEqual(entitiesNeedingSync.count, 2)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCognitiveLayerAssignment() async throws {
        // Test that direct fusion layer assignment fails
        // This would be tested if we had a direct API for it
        // For now, we test that the adapter properly handles layer determination
        
        let entity = Entity(name: "Test Entity", type: .concept)
        try await cognitiveAdapter.syncEntityToCognitive(entity)
        
        // Should not assign to fusion layer directly
        XCTAssertNotEqual(entity.cognitiveLayerType, .fusion)
    }
    
    func testAdapterWithoutCognitiveSystem() async throws {
        // Test fallback behavior when cognitive adapter is not available
        let serviceWithoutAdapter = KnowledgeGraphService(modelContext: modelContext)
        
        let searchResult = try await serviceWithoutAdapter.cognitiveSemanticSearch(query: "test")
        
        XCTAssertFalse(searchResult.cognitiveEnhanced)
        XCTAssertTrue(searchResult.cognitiveMatches.isEmpty)
    }
    
    // MARK: - Performance Tests
    
    func testBatchSyncPerformance() async throws {
        let entities = (0..<100).map { index in
            createTestEntity("Entity \(index)", .concept, "Test entity number \(index)")
        }
        
        for entity in entities {
            modelContext.insert(entity)
        }
        
        let startTime = Date()
        try await cognitiveAdapter.syncEntitiesToCognitive(entities)
        let syncTime = Date().timeIntervalSince(startTime)
        
        // Should sync 100 entities reasonably quickly
        XCTAssertLessThan(syncTime, 5.0)
        
        // Verify all entities were synced
        let syncedEntities = entities.filter { $0.hasCognitiveRepresentation }
        XCTAssertEqual(syncedEntities.count, entities.count)
    }
    
    // MARK: - Helper Methods
    
    private func createTestEntity(_ name: String, _ type: EntityType, _ description: String) -> Entity {
        let entity = Entity(name: name, type: type)
        entity.entityDescription = description
        entity.confidence = 0.7
        entity.importance = 0.5
        entity.mentions = Int.random(in: 1...10)
        return entity
    }
    
    private func createTestVeridicalNode(_ content: String, importance: Double = 0.5) -> VeridicalNode {
        let node = VeridicalNode(content: content, importance: importance)
        node.verificationStatus = .verified
        node.factType = .entityReference
        return node
    }
    
    private func createTestSemanticNode(_ content: String, importance: Double = 0.5) -> SemanticNode {
        let node = SemanticNode(content: content, importance: importance)
        node.conceptType = .entity
        node.confidence = 0.8
        return node
    }
    
    private func createTestEpisodicNode(_ content: String, importance: Double = 0.5) -> EpisodicNode {
        let node = EpisodicNode(content: content, importance: importance)
        node.temporalContext = EpisodicNode.TemporalContext(
            timeOfDay: .morning,
            dayOfWeek: .monday,
            season: .winter,
            relativeTime: .recent
        )
        return node
    }
}

// MARK: - Mock Classes for Testing

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
class MockCognitiveMemorySystem: CognitiveMemorySystem {
    var mockSearchResults: [any CognitiveMemoryNode] = []
    var mockRelevanceScores: [Double] = []
    
    override func searchCognitiveLayers(query: String) async throws -> CognitiveSearchResult {
        return CognitiveSearchResult(
            relevantNodes: mockSearchResults,
            relevanceScores: mockRelevanceScores,
            layerDistribution: [.semantic: mockSearchResults.count],
            totalNodes: mockSearchResults.count,
            retrievalContext: "Mock search for: \(query)"
        )
    }
}

// MARK: - Integration Test Scenarios

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension KnowledgeGraphCognitiveIntegrationTests {
    
    func testFullIntegrationScenario() async throws {
        // Scenario: Create entities, sync to cognitive, perform fusion, sync back
        
        let person = createTestEntity("John Doe", .person, "Software engineer")
        let company = createTestEntity("Tech Corp", .organization, "Technology company")
        let concept = createTestEntity("Programming", .concept, "Software development skill")
        
        modelContext.insert(person)
        modelContext.insert(company)
        modelContext.insert(concept)
        
        // Step 1: Sync entities to cognitive layers
        try await cognitiveAdapter.syncEntitiesToCognitive([person, company, concept])
        
        // Verify cognitive representation
        XCTAssertTrue(person.hasCognitiveRepresentation)
        XCTAssertTrue(company.hasCognitiveRepresentation)
        XCTAssertTrue(concept.hasCognitiveRepresentation)
        
        // Step 2: Simulate cognitive processing that creates connections
        // (This would happen through the CognitiveControlLoop in real usage)
        
        // Step 3: Test semantic search finds related entities
        let searchResults = try await cognitiveAdapter.findSimilarEntities(
            query: "software development",
            limit: 5,
            threshold: 0.1
        )
        
        XCTAssertGreaterThan(searchResults.count, 0)
        
        // Step 4: Verify Knowledge Graph Service integration
        await MainActor.run {
            knowledgeGraphService.entities = [person, company, concept]
        }
        
        let serviceSearchResult = try await knowledgeGraphService.cognitiveSemanticSearch(
            query: "technology programming"
        )
        
        XCTAssertTrue(serviceSearchResult.cognitiveEnhanced)
        XCTAssertGreaterThan(serviceSearchResult.totalResults, 0)
    }
}