//
//  PrivacyAnalyzerTests.swift
//  ProjectOneTests
//
//  Created by Memory Agent Testing on 7/15/25.
//

import XCTest
@testable import ProjectOne

final class PrivacyAnalyzerTests: XCTestCase {
    
    var privacyAnalyzer: PrivacyAnalyzer!
    
    override func setUpWithError() throws {
        privacyAnalyzer = PrivacyAnalyzer()
    }
    
    override func tearDownWithError() throws {
        privacyAnalyzer = nil
    }
    
    // MARK: - Privacy Level Classification Tests
    
    func testPublicKnowledgeClassification() throws {
        let publicQueries = [
            "What is the capital of France?",
            "How does photosynthesis work?",
            "What is the speed of light?",
            "Who invented the telephone?",
            "What is machine learning?"
        ]
        
        for query in publicQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertEqual(analysis.level, .publicKnowledge, "Query '\(query)' should be classified as public knowledge")
            XCTAssertFalse(analysis.requiresOnDevice)
        }
    }
    
    func testPersonalClassification() throws {
        let personalQueries = [
            "What did I eat for breakfast?",
            "Where did I go yesterday?",
            "What time did I wake up this morning?",
            "Who did I meet with last week?",
            "What are my weekend plans?"
        ]
        
        for query in personalQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertTrue(analysis.level == .personal || analysis.level == .contextual, 
                         "Query '\(query)' should be classified as personal or contextual")
            XCTAssertTrue(analysis.requiresOnDevice)
        }
    }
    
    func testSensitiveClassification() throws {
        let sensitiveQueries = [
            "What is my blood pressure reading?",
            "How much money do I have in my bank account?",
            "What medication am I taking?",
            "What is my home address?",
            "What are my investment portfolio details?"
        ]
        
        for query in sensitiveQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertEqual(analysis.level, .sensitive, "Query '\(query)' should be classified as sensitive")
            XCTAssertTrue(analysis.requiresOnDevice)
        }
    }
    
    // MARK: - Personal Indicator Detection Tests
    
    func testPersonalPronounDetection() throws {
        let pronounQueries = [
            "I went to the store",
            "My favorite color is blue",
            "Tell me about my schedule",
            "We had a meeting yesterday",
            "Our team discussed the project"
        ]
        
        for query in pronounQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertFalse(analysis.personalIndicators.isEmpty, "Query '\(query)' should detect personal pronouns")
            XCTAssertTrue(analysis.level != .publicKnowledge)
        }
    }
    
    func testPersonalVerbDetection() throws {
        let verbQueries = [
            "I remember going to the park",
            "Can you recall what happened?",
            "I experienced something strange",
            "I believe this is correct",
            "I know the answer"
        ]
        
        for query in verbQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertFalse(analysis.personalIndicators.isEmpty, "Query '\(query)' should detect personal verbs")
            XCTAssertTrue(analysis.level != .publicKnowledge)
        }
    }
    
    func testFamilyTermDetection() throws {
        let familyQueries = [
            "I called my mom yesterday",
            "My father works at the bank",
            "My sister is visiting",
            "Our family went on vacation",
            "My spouse likes cooking"
        ]
        
        for query in familyQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertFalse(analysis.sensitiveEntities.isEmpty, "Query '\(query)' should detect family terms")
            XCTAssertTrue(analysis.level != .publicKnowledge)
        }
    }
    
    // MARK: - Health Information Detection Tests
    
    func testHealthInformationDetection() throws {
        let healthQueries = [
            "I have a doctor appointment tomorrow",
            "My medication dosage was increased",
            "I'm experiencing symptoms of flu",
            "The hospital visit went well",
            "My health insurance covers this treatment"
        ]
        
        for query in healthQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertFalse(analysis.sensitiveEntities.isEmpty, "Query '\(query)' should detect health terms")
            XCTAssertTrue(analysis.riskFactors.contains("health_information"))
            XCTAssertEqual(analysis.level, .sensitive)
        }
    }
    
    func testFinancialInformationDetection() throws {
        let financialQueries = [
            "I need to check my bank account",
            "My credit score improved",
            "The loan application was approved",
            "My salary was increased",
            "I made an investment in stocks"
        ]
        
        for query in financialQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertFalse(analysis.sensitiveEntities.isEmpty, "Query '\(query)' should detect financial terms")
            XCTAssertTrue(analysis.riskFactors.contains("financial_information"))
            XCTAssertEqual(analysis.level, .sensitive)
        }
    }
    
    // MARK: - Temporal Personal Indicator Tests
    
    func testTemporalPersonalIndicators() throws {
        let temporalQueries = [
            "What did I do yesterday?",
            "My schedule for today is busy",
            "Tomorrow I have a meeting",
            "Last week we had a presentation",
            "This morning I went for a run"
        ]
        
        for query in temporalQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            XCTAssertFalse(analysis.personalIndicators.isEmpty, "Query '\(query)' should detect temporal personal indicators")
            XCTAssertTrue(analysis.level != .publicKnowledge)
        }
    }
    
    // MARK: - Context Analysis Tests
    
    func testMemoryContextAnalysis() throws {
        // Create a mock memory context with personal data
        let personalSTM = STMEntry(
            content: "I met with John at my office yesterday",
            memoryType: .episodic,
            importance: 0.9
        )
        
        let personalLTM = LTMEntry(
            content: "My home address is 123 Main Street",
            summary: "Personal address information",
            importance: 0.8
        )
        
        let personalEntity = Entity(
            name: "John Smith",
            type: .person
        )
        personalEntity.entityDescription = "Colleague"
        
        let context = MemoryContext(
            entities: [personalEntity],
            shortTermMemories: [personalSTM],
            longTermMemories: [personalLTM],
            userQuery: "Tell me about my meeting"
        )
        
        let analysis = privacyAnalyzer.analyzePrivacy(query: "Tell me about my meeting", context: context)
        
        XCTAssertTrue(analysis.level != .publicKnowledge)
        XCTAssertTrue(analysis.requiresOnDevice)
        XCTAssertTrue(analysis.riskFactors.contains("personal_memory_context"))
    }
    
    // MARK: - Memory Privacy Analysis Tests
    
    func testShortTermMemoryPrivacyAnalysis() throws {
        let personalSTM = STMEntry(
            content: "I had lunch with my sister at our favorite restaurant",
            memoryType: .episodic,
            importance: 0.9
        )
        
        let analysis = privacyAnalyzer.analyzeMemoryPrivacy(memory: personalSTM)
        
        XCTAssertTrue(analysis.level != .publicKnowledge)
        XCTAssertTrue(analysis.requiresOnDevice)
        XCTAssertFalse(analysis.sensitiveEntities.isEmpty)
    }
    
    func testLongTermMemoryPrivacyAnalysis() throws {
        let medicalLTM = LTMEntry(
            content: "Patient has history of hypertension, takes medication daily",
            summary: "Medical history summary",
            importance: 0.9
        )
        
        let analysis = privacyAnalyzer.analyzeMemoryPrivacy(memory: medicalLTM)
        
        XCTAssertEqual(analysis.level, .sensitive)
        XCTAssertTrue(analysis.requiresOnDevice)
        XCTAssertTrue(analysis.riskFactors.contains("health_information"))
    }
    
    func testEpisodicMemoryPrivacyAnalysis() throws {
        let personalEpisodic = EpisodicMemoryEntry(
            eventDescription: "Had dinner with parents and discussed work",
            participants: ["Mom", "Dad", "Me"],
            location: "Home",
            emotionalTone: 0.5,
            contextualCues: ["family", "dinner", "work"],
            importance: 0.8
        )
        
        let analysis = privacyAnalyzer.analyzeMemoryPrivacy(memory: personalEpisodic)
        
        XCTAssertTrue(analysis.level != .publicKnowledge)
        XCTAssertTrue(analysis.requiresOnDevice)
    }
    
    func testProcessedNotePrivacyAnalysis() throws {
        let financialNote = ProcessedNote(
            originalText: "Portfolio performance: +12% this quarter, considering rebalancing",
            summary: "Investment performance notes",
            extractedKeywords: ["portfolio", "performance", "rebalancing"],
            topics: ["investment", "finance"],
            sourceType: .userNote
        )
        
        let analysis = privacyAnalyzer.analyzeMemoryPrivacy(memory: financialNote)
        
        XCTAssertEqual(analysis.level, .sensitive)
        XCTAssertTrue(analysis.requiresOnDevice)
        XCTAssertTrue(analysis.riskFactors.contains("financial_information"))
    }
    
    // MARK: - Data Filtering Tests
    
    func testPublicDataFiltering() throws {
        let context = createTestMemoryContext()
        
        let filteredContext = privacyAnalyzer.filterPersonalDataFromContext(context, targetLevel: .publicKnowledge)
        
        XCTAssertFalse(filteredContext.containsPersonalData)
        XCTAssertTrue(filteredContext.userQuery.contains("[PERSONAL]") || 
                     filteredContext.userQuery.contains("[FAMILY]") || 
                     filteredContext.userQuery.contains("[LOCATION]"))
    }
    
    func testContextualDataFiltering() throws {
        let context = createTestMemoryContext()
        
        let filteredContext = privacyAnalyzer.filterPersonalDataFromContext(context, targetLevel: .contextual)
        
        XCTAssertFalse(filteredContext.containsPersonalData)
        XCTAssertLessThanOrEqual(filteredContext.entities.count, context.entities.count)
    }
    
    func testPersonalDataFiltering() throws {
        let context = createTestMemoryContext()
        
        let filteredContext = privacyAnalyzer.filterPersonalDataFromContext(context, targetLevel: .personal)
        
        XCTAssertTrue(filteredContext.containsPersonalData)
        XCTAssertEqual(filteredContext.episodicMemories.count, 0) // Should remove episodic memories
    }
    
    func testSensitiveDataFiltering() throws {
        let context = createTestMemoryContext()
        
        let filteredContext = privacyAnalyzer.filterPersonalDataFromContext(context, targetLevel: .sensitive)
        
        // Should keep all data for sensitive level
        XCTAssertEqual(filteredContext.entities.count, context.entities.count)
        XCTAssertEqual(filteredContext.shortTermMemories.count, context.shortTermMemories.count)
        XCTAssertEqual(filteredContext.longTermMemories.count, context.longTermMemories.count)
    }
    
    // MARK: - Utility Method Tests
    
    func testShouldUseOnDeviceProcessing() throws {
        let publicAnalysis = PrivacyAnalyzer.PrivacyAnalysis(level: .publicKnowledge)
        let personalAnalysis = PrivacyAnalyzer.PrivacyAnalysis(level: .personal)
        let sensitiveAnalysis = PrivacyAnalyzer.PrivacyAnalysis(level: .sensitive)
        
        XCTAssertFalse(privacyAnalyzer.shouldUseOnDeviceProcessing(for: publicAnalysis))
        XCTAssertTrue(privacyAnalyzer.shouldUseOnDeviceProcessing(for: personalAnalysis))
        XCTAssertTrue(privacyAnalyzer.shouldUseOnDeviceProcessing(for: sensitiveAnalysis))
    }
    
    func testRecommendedContextSize() throws {
        let publicAnalysis = PrivacyAnalyzer.PrivacyAnalysis(level: .publicKnowledge)
        let personalAnalysis = PrivacyAnalyzer.PrivacyAnalysis(level: .personal)
        let sensitiveAnalysis = PrivacyAnalyzer.PrivacyAnalysis(level: .sensitive)
        
        XCTAssertEqual(privacyAnalyzer.getRecommendedContextSize(for: publicAnalysis), 32768)
        XCTAssertEqual(privacyAnalyzer.getRecommendedContextSize(for: personalAnalysis), 8192)
        XCTAssertEqual(privacyAnalyzer.getRecommendedContextSize(for: sensitiveAnalysis), 4096)
    }
    
    func testPrivacyReport() throws {
        let analysis = PrivacyAnalyzer.PrivacyAnalysis(
            level: .personal,
            personalIndicators: ["my", "i"],
            sensitiveEntities: ["home", "family"],
            riskFactors: ["personal_memory_context"],
            confidence: 0.8
        )
        
        let report = privacyAnalyzer.getPrivacyReport(for: analysis)
        
        XCTAssertTrue(report.contains("Level: personal"))
        XCTAssertTrue(report.contains("Requires On-Device: true"))
        XCTAssertTrue(report.contains("Confidence: 0.80"))
        XCTAssertTrue(report.contains("Personal Indicators: my, i"))
        XCTAssertTrue(report.contains("Sensitive Entities: home, family"))
        XCTAssertTrue(report.contains("Risk Factors: personal_memory_context"))
    }
    
    // MARK: - Helper Methods
    
    private func createTestMemoryContext() -> MemoryContext {
        let personalSTM = STMEntry(
            content: "I met with my family at home",
            memoryType: .episodic,
            importance: 0.9
        )
        
        let sensitiveSTM = STMEntry(
            content: "Discussed health insurance with doctor",
            memoryType: .episodic,
            importance: 0.8
        )
        
        let personalLTM = LTMEntry(
            content: "My favorite restaurant is Luigi's",
            summary: "Personal preferences",
            importance: 0.7
        )
        
        let sensitiveLTM = LTMEntry(
            content: "Bank account information and routing numbers",
            summary: "Financial details",
            importance: 0.9
        )
        
        let episodic = EpisodicMemoryEntry(
            eventDescription: "Had dinner with family",
            participants: ["Family"],
            location: "Home",
            emotionalTone: 0.5,
            contextualCues: ["family", "dinner"],
            importance: 0.8
        )
        
        let entity = Entity(
            name: "John Smith",
            type: .person
        )
        entity.entityDescription = "Family friend"
        
        let relationship = Relationship(
            subjectEntityId: entity.id,
            predicateType: .friendOf,
            objectEntityId: entity.id
        )
        
        let note = ProcessedNote(
            originalText: "Remember to call my mother",
            summary: "Family reminder",
            extractedKeywords: ["call", "mother"],
            topics: ["family"],
            sourceType: .userNote
        )
        
        return MemoryContext(
            entities: [entity],
            relationships: [relationship],
            shortTermMemories: [personalSTM, sensitiveSTM],
            longTermMemories: [personalLTM, sensitiveLTM],
            episodicMemories: [episodic],
            relevantNotes: [note],
            userQuery: "Tell me about my family meeting at home"
        )
    }
}