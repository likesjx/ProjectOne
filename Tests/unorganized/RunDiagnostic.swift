#!/usr/bin/env swift

import Foundation
import Speech
import AVFoundation

// Import the diagnostic utility
#if canImport(ProjectOne)
import ProjectOne
#endif

print("🔍 Running ProjectOne Transcription Diagnostic")
print("=============================================")

let diagnostic = TranscriptionDiagnostic()

Task {
    let result = await diagnostic.quickCheck()
    print(result)
    
    print("\n" + String(repeating("=", 50))
    print("📋 Diagnostic Report Summary:")
    print("   Status: \(result.contains("✅") ? "SUCCESS" : "ISSUES FOUND")")
    print("   Time: \(Date())")
    
    if result.contains("❌") {
        print("\n🚨 CRITICAL ISSUES DETECTED")
        print("   This explains the 'still getting an error on transcription' issue!")
    } else if result.contains("⚠️") {
        print("\n⚠️  WARNING ISSUES DETECTED")
        print("   These may affect transcription reliability")
    } else {
        print("\n✅ NO ISSUES FOUND")
        print("   Transcription system appears healthy")
    }
}

// Keep the script running until diagnostic completes
RunLoop.main.run()