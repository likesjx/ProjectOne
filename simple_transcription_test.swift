#!/usr/bin/env swift

//
// Simple Transcription Test
// Quick diagnostic to test Apple Speech transcription
//

import Foundation
import Speech

print("🎤 Simple Transcription Test")
print("==========================")

// Check authorization status
let authStatus = SFSpeechRecognizer.authorizationStatus()
print("📝 Speech Recognition Authorization: \(authStatus.rawValue)")

switch authStatus {
case .notDetermined:
    print("   ⚠️  Not requested yet")
case .denied:
    print("   ❌ DENIED - this is the issue!")
case .restricted:
    print("   🚫 RESTRICTED")
case .authorized:
    print("   ✅ Authorized")
@unknown default:
    print("   ❓ Unknown")
}

// Check recognizer availability
if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
    print("📱 Speech Recognizer Available: \(recognizer.isAvailable)")
    print("🔊 On-device Recognition: \(recognizer.supportsOnDeviceRecognition)")
    
    if recognizer.isAvailable && authStatus == .authorized {
        print("✅ Transcription should work!")
    } else {
        print("❌ Transcription will NOT work")
        
        if authStatus != .authorized {
            print("🔧 Fix: Request speech recognition permission")
        }
        if !recognizer.isAvailable {
            print("🔧 Fix: Check network connectivity or try again later")
        }
    }
} else {
    print("❌ Cannot create speech recognizer")
}

print("\n🎯 Conclusion:")
if authStatus == .authorized {
    print("   Speech recognition should work - check other components")
} else {
    print("   REQUEST PERMISSION: Add speech recognition request to app startup")
}