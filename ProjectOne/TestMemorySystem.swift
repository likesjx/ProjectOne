//
//  TestMemorySystem.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/16/25.
//

import Foundation
import SwiftData
import os.log

@available(iOS 26.0, iPadOS 26.0, macOS 26.0, tvOS 26.0, watchOS 11.0, *)
@MainActor
class TestMemorySystem {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "TestMemorySystem")
    private let modelContext: ModelContext
    private let analyticsService: MemoryAnalyticsService
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.analyticsService = MemoryAnalyticsService(modelContext: modelContext)
    }
    
    /// Test memory storage functionality
    func testMemoryStorage() async {
        logger.info("🧪 Testing memory storage functionality...")
        
        // Test 1: Create a simple STM entry
        do {
            let stmEntry = STMEntry(
                content: "Today I had a meeting with Sarah about the quarterly budget review. We discussed increasing the marketing spend.",
                memoryType: .semantic,
                importance: 0.7,
                sourceNoteId: nil,
                relatedEntities: [],
                emotionalWeight: 0.5,
                contextTags: ["meeting", "budget", "marketing"]
            )
            
            modelContext.insert(stmEntry)
            try modelContext.save()
            logger.info("✅ Successfully stored STM entry")
            
        } catch {
            logger.error("❌ Failed to store STM entry: \(error)")
        }
        
        // Test 2: Create an LTM entry
        do {
            let ltmEntry = LTMEntry(
                content: "Swift 6 brings strict concurrency checking. Need to update all @MainActor annotations.",
                category: .procedural,
                importance: 0.8,
                sourceSTMEntry: nil,
                sourceSTMIds: [],
                relatedEntities: [],
                relatedConcepts: ["swift", "programming", "concurrency"],
                emotionalWeight: 0.0,
                retrievalCues: ["swift", "programming", "concurrency"],
                memoryCluster: nil
            )
            
            modelContext.insert(ltmEntry)
            try modelContext.save()
            logger.info("✅ Successfully stored LTM entry")
            
        } catch {
            logger.error("❌ Failed to store LTM entry: \(error)")
        }
        
        // Test 3: Create an episodic memory
        do {
            let episodicMemory = EpisodicMemoryEntry(
                eventDescription: "Implemented memory system fixes and successfully registered SwiftData models",
                location: "Home office",
                participants: ["Claude", "User"],
                emotionalTone: .positive
            )
            
            modelContext.insert(episodicMemory)
            try modelContext.save()
            logger.info("✅ Successfully stored episodic memory")
            
        } catch {
            logger.error("❌ Failed to store episodic memory: \(error)")
        }
        
        // Test 4: Create some entities for testing
        do {
            let person = Entity(
                name: "Sarah",
                type: .person
            )
            person.entityDescription = "Team member who handles budget reviews"
            
            let concept = Entity(
                name: "Swift 6 Concurrency",
                type: .concept
            )
            concept.entityDescription = "New strict concurrency checking in Swift 6"
            
            modelContext.insert(person)
            modelContext.insert(concept)
            try modelContext.save()
            logger.info("✅ Successfully stored entities")
            
        } catch {
            logger.error("❌ Failed to store entities: \(error)")
        }
        
        logger.info("🎉 Memory storage test completed!")
    }
    
    /// Test memory retrieval functionality
    func testMemoryRetrieval() async {
        logger.info("🧪 Testing memory retrieval functionality...")
        
        // Test retrieving STM entries
        do {
            let stmDescriptor = FetchDescriptor<STMEntry>()
            let stmEntries = try modelContext.fetch(stmDescriptor)
            logger.info("📊 Found \(stmEntries.count) STM entries")
            
            for entry in stmEntries {
                logger.info("  - STM: \(entry.content.prefix(50))...")
            }
            
        } catch {
            logger.error("❌ Failed to retrieve STM entries: \(error)")
        }
        
        // Test retrieving LTM entries
        do {
            let ltmDescriptor = FetchDescriptor<LTMEntry>()
            let ltmEntries = try modelContext.fetch(ltmDescriptor)
            logger.info("📊 Found \(ltmEntries.count) LTM entries")
            
            for entry in ltmEntries {
                logger.info("  - LTM: \(entry.content.prefix(50))...")
            }
            
        } catch {
            logger.error("❌ Failed to retrieve LTM entries: \(error)")
        }
        
        // Test retrieving episodic memories
        do {
            let episodicDescriptor = FetchDescriptor<EpisodicMemoryEntry>()
            let episodicEntries = try modelContext.fetch(episodicDescriptor)
            logger.info("📊 Found \(episodicEntries.count) episodic memories")
            
            for entry in episodicEntries {
                logger.info("  - Episodic: \(entry.eventDescription.prefix(50))...")
            }
            
        } catch {
            logger.error("❌ Failed to retrieve episodic memories: \(error)")
        }
        
        // Test retrieving entities
        do {
            let entityDescriptor = FetchDescriptor<Entity>()
            let entities = try modelContext.fetch(entityDescriptor)
            logger.info("📊 Found \(entities.count) entities")
            
            for entity in entities {
                logger.info("  - Entity (\(entity.type.rawValue)): \(entity.name)")
            }
            
        } catch {
            logger.error("❌ Failed to retrieve entities: \(error)")
        }
        
        logger.info("🎉 Memory retrieval test completed!")
    }
    
    /// Test memory analytics functionality
    func testMemoryAnalytics() async {
        logger.info("🧪 Testing memory analytics functionality...")
        
        do {
            // Test collecting memory analytics by calling the service methods directly
            let workingMemoryCount = try await analyticsService.getMemoryCount(type: .working)
            let semanticMemoryCount = try await analyticsService.getMemoryCount(type: .semantic)
            let proceduralMemoryCount = try await analyticsService.getMemoryCount(type: .procedural)
            let episodicMemoryCount = try await analyticsService.getMemoryCount(type: .episodic)
            let entityCount = try await analyticsService.getEntityCount()
            let relationshipCount = try await analyticsService.getRelationshipCount()
            let entityTypeBreakdown = try await analyticsService.getEntityTypeCounts()
            
            logger.info("📊 Memory Analytics Results:")
            logger.info("  - Working Memory: \(workingMemoryCount)")
            logger.info("  - Semantic Memory: \(semanticMemoryCount)")
            logger.info("  - Procedural Memory: \(proceduralMemoryCount)")
            logger.info("  - Episodic Memory: \(episodicMemoryCount)")
            logger.info("  - Total Entities: \(entityCount)")
            logger.info("  - Total Relationships: \(relationshipCount)")
            
            // Test entity type breakdown
            logger.info("📊 Entity Type Breakdown:")
            for (type, count) in entityTypeBreakdown {
                logger.info("  - \(type): \(count)")
            }
            
        } catch {
            logger.error("❌ Failed to collect memory analytics: \(error)")
        }
        
        logger.info("🎉 Memory analytics test completed!")
    }
    
    /// Run all memory system tests
    func runAllTests() async {
        logger.info("🚀 Starting comprehensive memory system tests...")
        logger.info("=============================================")
        
        await testMemoryStorage()
        await testMemoryRetrieval()
        await testMemoryAnalytics()
        
        logger.info("=============================================")
        logger.info("✅ All memory system tests completed!")
    }
}

// MARK: - Test Runner Function

/// Run comprehensive memory system tests
@MainActor
func runMemorySystemTests(modelContext: ModelContext) async {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
        let tester = TestMemorySystem(modelContext: modelContext)
        await tester.runAllTests()
    } else {
        print("⚠️ Memory system tests require iOS 17.0+")
    }
}