//
//  CognitiveMemoryTests.swift
//  ProjectOneTests
//
//  Created by Claude on 8/19/25.
//  Unit tests for Cognitive Memory System components
//

import XCTest
import SwiftData
@testable import ProjectOne

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
final class CognitiveMemoryTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var cognitiveSystem: CognitiveMemorySystem!
    
    override func setUpWithError() throws {
        // Create in-memory model container for testing
        let schema = Schema([
            VeridicalNode.self,
            SemanticNode.self,
            EpisodicNode.self,
            FusionNode.self,
            STMEntry.self,
            LTMEntry.self,
            EpisodicMemoryEntry.self,
            ShortTermMemory.self,
            LongTermMemory.self,
            WorkingMemoryItem.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        
        // Initialize cognitive system
        cognitiveSystem = CognitiveMemorySystem(modelContext: modelContext)
    }
    
    override func tearDownWithError() throws {
        modelContainer = nil
        modelContext = nil
        cognitiveSystem = nil
    }
    
    // MARK: - Veridical Layer Tests
    
    func testVeridicalNodeCreation() throws {
        let node = VeridicalNode(
            content: "The sky is blue",
            factType: .observation,
            importance: 0.7
        )
        
        XCTAssertEqual(node.content, "The sky is blue")
        XCTAssertEqual(node.factType, .observation)
        XCTAssertEqual(node.layerType, .veridical)
        XCTAssertEqual(node.nodeType, .fact)
        XCTAssertEqual(node.importance, 0.7)
        XCTAssertEqual(node.immediacyScore, 1.0) // Should start at max immediacy
        XCTAssertEqual(node.verificationStatus, .unverified)
    }
    
    func testVeridicalNodeVerification() throws {
        let node = VeridicalNode(
            content: "Water boils at 100°C",
            factType: .measurement,
            importance: 0.8
        )
        
        let initialStrength = node.strengthScore
        node.verify(status: .verified)
        
        XCTAssertEqual(node.verificationStatus, .verified)
        XCTAssertGreaterThan(node.strengthScore, initialStrength)
    }
    
    func testVeridicalNodeImmediacy() throws {
        let node = VeridicalNode(
            content: "Meeting scheduled for tomorrow",
            factType: .event
        )
        
        // Simulate passage of time by modifying timestamp
        node.timestamp = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        
        let initialImmediacy = node.immediacyScore
        node.updateImmediacy()
        
        XCTAssertLessThan(node.immediacyScore, initialImmediacy)
    }
    
    func testVeridicalLayerAddNode() async throws {
        let layer = VeridicalMemoryLayer(modelContext: modelContext)
        
        let node = VeridicalNode(
            content: "Test fact",
            factType: .statement
        )
        
        try await layer.addNode(node)
        
        XCTAssertTrue(layer.nodes.contains { $0.id == node.id })
        XCTAssertEqual(layer.nodes.count, 1)
    }
    
    func testVeridicalLayerSearch() async throws {
        let layer = VeridicalMemoryLayer(modelContext: modelContext)
        
        // Add test nodes
        let node1 = VeridicalNode(content: "The cat is sleeping", factType: .observation)
        let node2 = VeridicalNode(content: "Dogs are loyal animals", factType: .statement)
        let node3 = VeridicalNode(content: "Cats have sharp claws", factType: .observation)
        
        try await layer.addNode(node1)
        try await layer.addNode(node2)
        try await layer.addNode(node3)
        
        // Search for cat-related facts
        let results = try await layer.searchNodes(query: "cat", limit: 5)
        
        XCTAssertEqual(results.count, 2) // Should find both cat-related nodes
        XCTAssertTrue(results.contains { $0.id == node1.id })
        XCTAssertTrue(results.contains { $0.id == node3.id })
    }
    
    // MARK: - Semantic Layer Tests
    
    func testSemanticNodeCreation() throws {
        let node = SemanticNode(
            content: "Animals are living beings",
            conceptType: .category,
            abstractionLevel: 2,
            importance: 0.8
        )
        
        XCTAssertEqual(node.content, "Animals are living beings")
        XCTAssertEqual(node.conceptType, .category)
        XCTAssertEqual(node.abstractionLevel, 2)
        XCTAssertEqual(node.layerType, .semantic)
        XCTAssertEqual(node.nodeType, .concept)
        XCTAssertEqual(node.confidence, 0.8)
    }
    
    func testSemanticNodeEvidence() throws {
        let node = SemanticNode(
            content: "Birds can fly",
            conceptType: .rule
        )
        
        let initialConfidence = node.confidence
        node.addEvidence("evidence-node-1")
        
        XCTAssertTrue(node.evidenceNodes.contains("evidence-node-1"))
        XCTAssertGreaterThan(node.confidence, initialConfidence)
    }
    
    func testSemanticNodeGeneralization() throws {
        let node = SemanticNode(
            content: "Specific concept",
            conceptType: .entity,
            abstractionLevel: 0
        )
        
        let initialLevel = node.abstractionLevel
        let initialStrength = node.strengthScore
        
        node.generalize()
        
        XCTAssertEqual(node.generalizationCount, 1)
        XCTAssertGreaterThan(node.abstractionLevel, initialLevel)
        XCTAssertGreaterThan(node.strengthScore, initialStrength)
    }
    
    // MARK: - Episodic Layer Tests
    
    func testEpisodicNodeCreation() throws {
        let node = EpisodicNode(
            content: "Had coffee with Sarah at the local cafe",
            episodeType: .interaction,
            participants: ["Sarah"],
            location: "Local Cafe",
            emotionalValence: 0.3
        )
        
        XCTAssertEqual(node.content, "Had coffee with Sarah at the local cafe")
        XCTAssertEqual(node.episodeType, .interaction)
        XCTAssertTrue(node.participants.contains("Sarah"))
        XCTAssertEqual(node.location, "Local Cafe")
        XCTAssertEqual(node.emotionalValence, 0.3)
        XCTAssertEqual(node.layerType, .episodic)
        XCTAssertEqual(node.nodeType, .episode)
    }
    
    func testEpisodicNodeContextualCues() throws {
        let node = EpisodicNode(
            content: "Presentation went well",
            episodeType: .event
        )
        
        node.addContextualCue("nervous_feeling")
        node.addContextualCue("positive_feedback")
        
        XCTAssertTrue(node.contextualCues.contains("nervous_feeling"))
        XCTAssertTrue(node.contextualCues.contains("positive_feedback"))
        XCTAssertEqual(node.contextualCues.count, 2)
    }
    
    func testEpisodicNodeVividness() throws {
        let node = EpisodicNode(
            content: "Important memory",
            episodeType: .experience,
            importance: 0.5
        )
        
        let initialVividness = node.vividnessScore
        
        // Test reinforcement through access
        node.updateVividness()
        XCTAssertGreaterThan(node.vividnessScore, initialVividness)
        
        // Test natural decay
        let reinforcedVividness = node.vividnessScore
        node.updateVividness(decay: true)
        XCTAssertLessThanOrEqual(node.vividnessScore, reinforcedVividness)
    }
    
    // MARK: - Fusion Node Tests
    
    func testFusionNodeCreation() throws {
        let fusionNode = FusionNode(
            content: "Connection between memory and emotion",
            fusedLayers: [.semantic, .episodic],
            sourceNodes: ["node1", "node2"],
            fusionType: .crossLayer,
            importance: 0.9
        )
        
        XCTAssertEqual(fusionNode.fusedLayers.count, 2)
        XCTAssertTrue(fusionNode.fusedLayers.contains(.semantic))
        XCTAssertTrue(fusionNode.fusedLayers.contains(.episodic))
        XCTAssertEqual(fusionNode.sourceNodes.count, 2)
        XCTAssertEqual(fusionNode.fusionType, .crossLayer)
        XCTAssertEqual(fusionNode.layerType, .fusion)
        XCTAssertEqual(fusionNode.nodeType, .fusion)
    }
    
    func testFusionNodeValidation() throws {
        let fusionNode = FusionNode(
            content: "Test fusion",
            fusedLayers: [.veridical, .semantic],
            sourceNodes: ["node1"],
            fusionType: .conceptual
        )
        
        let initialCoherence = fusionNode.coherenceScore
        let initialStrength = fusionNode.strengthScore
        
        fusionNode.validate(status: .validated)
        
        XCTAssertEqual(fusionNode.validationStatus, .validated)
        XCTAssertGreaterThan(fusionNode.coherenceScore, initialCoherence)
        XCTAssertGreaterThan(fusionNode.strengthScore, initialStrength)
    }
    
    // MARK: - Cognitive Memory System Tests
    
    func testCognitiveSystemInitialization() async throws {
        XCTAssertNotNil(cognitiveSystem.veridicalLayer)
        XCTAssertNotNil(cognitiveSystem.semanticLayer)
        XCTAssertNotNil(cognitiveSystem.episodicLayer)
        
        let status = await cognitiveSystem.getSystemStatus()
        XCTAssertNotNil(status.metrics)
        XCTAssertGreaterThanOrEqual(status.metrics.memoryEfficiency, 0.0)
        XCTAssertLessThanOrEqual(status.metrics.memoryEfficiency, 1.0)
    }
    
    func testAddVeridicalFact() async throws {
        let initialCount = cognitiveSystem.veridicalLayer.nodes.count
        
        try await cognitiveSystem.addVeridicalFact(
            content: "Test veridical fact",
            factType: .statement,
            importance: 0.6
        )
        
        XCTAssertEqual(cognitiveSystem.veridicalLayer.nodes.count, initialCount + 1)
        
        let addedNode = cognitiveSystem.veridicalLayer.nodes.last
        XCTAssertEqual(addedNode?.content, "Test veridical fact")
        XCTAssertEqual(addedNode?.factType, .statement)
    }
    
    func testAddSemanticConcept() async throws {
        let initialCount = cognitiveSystem.semanticLayer.nodes.count
        
        try await cognitiveSystem.addSemanticConcept(
            content: "Test semantic concept",
            conceptType: .entity,
            abstractionLevel: 1,
            importance: 0.7
        )
        
        XCTAssertEqual(cognitiveSystem.semanticLayer.nodes.count, initialCount + 1)
        
        let addedNode = cognitiveSystem.semanticLayer.nodes.last
        XCTAssertEqual(addedNode?.content, "Test semantic concept")
        XCTAssertEqual(addedNode?.conceptType, .entity)
        XCTAssertEqual(addedNode?.abstractionLevel, 1)
    }
    
    func testAddEpisodicExperience() async throws {
        let initialCount = cognitiveSystem.episodicLayer.nodes.count
        
        try await cognitiveSystem.addEpisodicExperience(
            content: "Test episodic experience",
            episodeType: .conversation,
            participants: ["Person1", "Person2"],
            location: "Office",
            emotionalValence: 0.2,
            importance: 0.5
        )
        
        XCTAssertEqual(cognitiveSystem.episodicLayer.nodes.count, initialCount + 1)
        
        let addedNode = cognitiveSystem.episodicLayer.nodes.last
        XCTAssertEqual(addedNode?.content, "Test episodic experience")
        XCTAssertEqual(addedNode?.episodeType, .conversation)
        XCTAssertEqual(addedNode?.participants.count, 2)
        XCTAssertEqual(addedNode?.location, "Office")
        XCTAssertEqual(addedNode?.emotionalValence, 0.2)
    }
    
    func testCreateFusion() async throws {
        // First add some nodes to fuse
        try await cognitiveSystem.addVeridicalFact(
            content: "The meeting was productive",
            factType: .observation
        )
        
        try await cognitiveSystem.addEpisodicExperience(
            content: "Team meeting in conference room",
            episodeType: .event,
            location: "Conference Room"
        )
        
        let veridicalNode = cognitiveSystem.veridicalLayer.nodes.last!
        let episodicNode = cognitiveSystem.episodicLayer.nodes.last!
        
        let initialFusionCount = cognitiveSystem.fusionNodes.count
        
        try await cognitiveSystem.createFusion(
            sourceNodes: [veridicalNode, episodicNode],
            fusionType: .crossLayer,
            content: "Productive meeting memory fusion",
            importance: 0.8
        )
        
        XCTAssertEqual(cognitiveSystem.fusionNodes.count, initialFusionCount + 1)
        
        let fusionNode = cognitiveSystem.fusionNodes.last!
        XCTAssertEqual(fusionNode.fusedLayers.count, 2)
        XCTAssertTrue(fusionNode.fusedLayers.contains(.veridical))
        XCTAssertTrue(fusionNode.fusedLayers.contains(.episodic))
        XCTAssertEqual(fusionNode.sourceNodes.count, 2)
    }
    
    func testCognitiveSearch() async throws {
        // Add test data across layers
        try await cognitiveSystem.addVeridicalFact(
            content: "Machine learning is a subset of AI",
            factType: .statement
        )
        
        try await cognitiveSystem.addSemanticConcept(
            content: "Artificial Intelligence systems",
            conceptType: .category
        )
        
        try await cognitiveSystem.addEpisodicExperience(
            content: "Discussed AI ethics in team meeting",
            episodeType: .conversation
        )
        
        let searchResults = try await cognitiveSystem.searchCognitiveLayers(
            query: "artificial intelligence AI",
            maxResults: 10
        )
        
        // Should find relevant nodes in multiple layers
        XCTAssertGreaterThan(searchResults.veridicalNodes.count + 
                           searchResults.semanticNodes.count + 
                           searchResults.episodicNodes.count, 0)
        
        XCTAssertGreaterThan(searchResults.processingTime, 0)
    }
    
    func testMemoryContext() async throws {
        // Add some test data
        try await cognitiveSystem.addVeridicalFact(
            content: "Weather is sunny today",
            factType: .observation
        )
        
        let memoryContext = try await cognitiveSystem.getMemoryContext(for: "weather sunny")
        
        XCTAssertEqual(memoryContext.query, "weather sunny")
        XCTAssertNotNil(memoryContext.searchResult)
        XCTAssertNotNil(memoryContext.memoryState)
        XCTAssertNotNil(memoryContext.systemMetrics)
    }
    
    // MARK: - Performance Tests
    
    func testCognitiveSearchPerformance() async throws {
        // Add multiple nodes for performance testing
        for i in 0..<50 {
            try await cognitiveSystem.addVeridicalFact(
                content: "Test fact number \(i)",
                factType: .statement
            )
        }
        
        for i in 0..<30 {
            try await cognitiveSystem.addSemanticConcept(
                content: "Test concept number \(i)",
                conceptType: .entity
            )
        }
        
        for i in 0..<20 {
            try await cognitiveSystem.addEpisodicExperience(
                content: "Test experience number \(i)",
                episodeType: .event
            )
        }
        
        let startTime = Date()
        let results = try await cognitiveSystem.searchCognitiveLayers(
            query: "test number",
            maxResults: 20
        )
        let endTime = Date()
        
        let searchTime = endTime.timeIntervalSince(startTime)
        
        // Search should complete within reasonable time
        XCTAssertLessThan(searchTime, 1.0) // Less than 1 second
        XCTAssertGreaterThan(results.veridicalNodes.count + 
                           results.semanticNodes.count + 
                           results.episodicNodes.count, 0)
    }
    
    // MARK: - Integration Tests with Existing Models
    
    func testEmbeddingCapabilityExtensions() async throws {
        let stmEntry = STMEntry()
        stmEntry.content = "Test STM content"
        
        XCTAssertTrue(stmEntry.needsEmbedding)
        XCTAssertNil(stmEntry.getEmbedding())
        XCTAssertTrue(stmEntry.shouldRegenerateEmbedding(maxAge: 100))
        
        // Test embedding setting (would need actual implementation)
        await stmEntry.setEmbedding([0.1, 0.2, 0.3])
        // Note: This test would pass once the actual embedding properties are added to the models
    }
}

// MARK: - Test Utilities

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CognitiveMemoryTests {
    
    /// Helper method to create test cognitive context
    func createTestCognitiveContext(query: String = "test query") -> CognitiveContext {
        return CognitiveContext(
            userQuery: query,
            memoryState: MemorySystemState(
                shortTermCount: 5,
                longTermCount: 10,
                workingSetSize: 3,
                episodicCount: 7
            )
        )
    }
    
    /// Helper method to create test veridical nodes
    func createTestVeridicalNodes(count: Int) -> [VeridicalNode] {
        return (0..<count).map { i in
            VeridicalNode(
                content: "Test fact \(i)",
                factType: .statement,
                importance: Double(i) / Double(count)
            )
        }
    }
    
    /// Helper method to create test semantic nodes
    func createTestSemanticNodes(count: Int) -> [SemanticNode] {
        return (0..<count).map { i in
            SemanticNode(
                content: "Test concept \(i)",
                conceptType: .entity,
                abstractionLevel: i % 3,
                importance: 0.5 + (Double(i) / Double(count)) * 0.5
            )
        }
    }
}