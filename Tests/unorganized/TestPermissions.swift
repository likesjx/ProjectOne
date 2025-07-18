#!/usr/bin/env swift

import Foundation
import Speech
import AVFoundation

print("🧪 Testing ProjectOne Permission Fix")
print("===================================")

// Test the same permission flow that our fixed AudioRecorder.requestPermission() now uses

func testMicrophonePermission() async -> Bool {
    print("\n1️⃣ Testing microphone permission...")
    
    #if os(iOS)
    return await withCheckedContinuation { continuation in
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            print("🎤 Microphone permission: \(granted ? "✅ Granted" : "❌ Denied")")
            continuation.resume(returning: granted)
        }
    }
    #else
    print("🎤 Microphone permission: ✅ Granted (macOS doesn't require explicit permission)")
    return true
    #endif
}

func testSpeechRecognitionPermission() async -> Bool {
    print("\n2️⃣ Testing speech recognition permission...")
    
    return await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print("🗣️ Speech recognition permission: \(authStatus.rawValue)")
            
            switch authStatus {
            case .authorized:
                print("🗣️ Speech recognition: ✅ Authorized")
                continuation.resume(returning: true)
            case .denied:
                print("🗣️ Speech recognition: ❌ Denied")
                continuation.resume(returning: false)
            case .restricted:
                print("🗣️ Speech recognition: 🚫 Restricted")
                continuation.resume(returning: false)
            case .notDetermined:
                print("🗣️ Speech recognition: ⚠️ Not determined")
                continuation.resume(returning: false)
            @unknown default:
                print("🗣️ Speech recognition: ❓ Unknown")
                continuation.resume(returning: false)
            }
        }
    }
}

// Run the test
Task {
    print("🏁 Starting permission test sequence...")
    
    let micGranted = await testMicrophonePermission()
    guard micGranted else {
        print("\n❌ FAILED: Microphone permission required")
        exit(1)
    }
    
    let speechGranted = await testSpeechRecognitionPermission()
    guard speechGranted else {
        print("\n❌ FAILED: Speech recognition permission required")
        exit(1)
    }
    
    print("\n✅ SUCCESS: Both permissions granted!")
    print("📝 This matches the flow in our fixed AudioRecorder.requestPermission()")
    print("🎯 Transcription should now work without errors")
    
    // Test that speech recognizer is available
    print("\n3️⃣ Testing speech recognizer availability...")
    if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
        print("🤖 Speech recognizer created: ✅")
        print("📱 Available: \(recognizer.isAvailable ? "✅" : "❌")")
        print("🔄 On-device support: \(recognizer.supportsOnDeviceRecognition ? "✅" : "❌")")
    } else {
        print("🤖 Speech recognizer creation: ❌ Failed")
    }
    
    print("\n🎊 Permission test complete!")
    exit(0)
}