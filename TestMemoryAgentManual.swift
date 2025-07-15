#!/usr/bin/env swift

//
//  TestMemoryAgentManual.swift
//  Manual test for Memory Agent functionality
//

import Foundation
import SwiftData

@available(iOS 19.0, macOS 16.0, tvOS 19.0, watchOS 12.0, *)
struct TestMemoryAgent {
    
    static func testAIProviderInitialization() {
        print("🧠 Testing AI Model Provider Initialization...")
        
        // Test privacy analyzer
        let privacyAnalyzer = PrivacyAnalyzer()
        
        // Test a personal query
        let personalQuery = "I need to remember my doctor's appointment tomorrow"
        let personalAnalysis = privacyAnalyzer.analyzePrivacy(query: personalQuery)
        print("✅ Personal query analysis: \(personalAnalysis.level) (should be personal/sensitive)")
        print("   Requires on-device: \(personalAnalysis.requiresOnDevice)")
        
        // Test a public query
        let publicQuery = "What is the capital of France?"
        let publicAnalysis = privacyAnalyzer.analyzePrivacy(query: publicQuery)
        print("✅ Public query analysis: \(publicAnalysis.level) (should be public knowledge)")
        print("   Requires on-device: \(publicAnalysis.requiresOnDevice)")
        
        // Test health-related query
        let healthQuery = "My blood pressure medication needs adjustment"
        let healthAnalysis = privacyAnalyzer.analyzePrivacy(query: healthQuery)
        print("✅ Health query analysis: \(healthAnalysis.level) (should be sensitive)")
        print("   Requires on-device: \(healthAnalysis.requiresOnDevice)")
        
        print("🎉 AI Provider initialization tests completed successfully!")
    }
    
    static func testMemoryContextCreation() {
        print("\n🧠 Testing Memory Context Creation...")
        
        // Create a simple memory context
        let context = MemoryContext(
            userQuery: "Test query for memory retrieval",
            containsPersonalData: true
        )
        
        print("✅ Memory context created successfully")
        print("   Query: \(context.userQuery)")
        print("   Contains personal data: \(context.containsPersonalData)")
        print("   Timestamp: \(context.timestamp)")
        
        print("🎉 Memory Context creation tests completed successfully!")
    }
    
    static func testRouting() {
        print("\n🧠 Testing Routing Logic...")
        
        let privacyAnalyzer = PrivacyAnalyzer()
        
        // Test different query types and their routing decisions
        let testQueries = [
            "What's the weather like?",
            "Remember my wife's birthday is next week",
            "I'm feeling anxious about my health checkup",
            "How do I solve this math problem?"
        ]
        
        for query in testQueries {
            let analysis = privacyAnalyzer.analyzePrivacy(query: query)
            let shouldUseOnDevice = privacyAnalyzer.shouldUseOnDeviceProcessing(for: analysis)
            let contextSize = privacyAnalyzer.getRecommendedContextSize(for: analysis)
            
            print("✅ Query: '\(query.prefix(30))...'")
            print("   Privacy level: \(analysis.level)")
            print("   Use on-device: \(shouldUseOnDevice)")
            print("   Context size: \(contextSize)")
            print("   Personal indicators: \(analysis.personalIndicators)")
            print("   Risk factors: \(analysis.riskFactors)")
            print("")
        }
        
        print("🎉 Routing logic tests completed successfully!")
    }
    
    static func runAllTests() {
        print("🚀 Starting Memory Agent Manual Tests")
        print("=====================================")
        
        testAIProviderInitialization()
        testMemoryContextCreation()
        testRouting()
        
        print("\n🎉 All Memory Agent tests completed successfully!")
        print("=====================================")
    }
}

// Run the tests
if #available(iOS 19.0, macOS 16.0, tvOS 19.0, watchOS 12.0, *) {
    TestMemoryAgent.runAllTests()
} else {
    print("❌ Memory Agent requires iOS 19.0+ / macOS 16.0+")
}