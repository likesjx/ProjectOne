//
//  TestRunner.swift
//  ProjectOne
//
//  Created by Claude on 7/12/25.
//

import Foundation

/// Simple test runner for WhisperKit functionality
class TestRunner {
    
    static func runAllTests() async {
        print("🚀 [TestRunner] Starting WhisperKit integration tests...")
        print("==================================================")
        
        // Test 1: Basic WhisperKit functionality
        await WhisperKitTest.runBasicTest()
        print("\n" + "="*50 + "\n")
        
        // Test 2: SpeechTranscriber integration
        await WhisperKitTest.testSpeechTranscriberIntegration()
        print("\n" + "="*50 + "\n")
        
        print("🏁 [TestRunner] All tests completed!")
    }
}