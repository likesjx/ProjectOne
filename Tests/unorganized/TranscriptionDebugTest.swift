#!/usr/bin/env swift

//
// TranscriptionDebugTest.swift
// Simple debug script to identify transcription errors in ProjectOne
//

import Foundation
import Speech
import AVFoundation

print("🔍 ProjectOne Transcription Debug Test")
print("=====================================")

// Check speech recognition authorization
let speechAuth = SFSpeechRecognizer.authorizationStatus()
print("📝 Speech Recognition Authorization: \(speechAuth.rawValue)")

switch speechAuth {
case .notDetermined:
    print("   ⚠️  Speech recognition permission not requested yet")
case .denied:
    print("   ❌ Speech recognition permission DENIED")
case .restricted:
    print("   🚫 Speech recognition RESTRICTED")
case .authorized:
    print("   ✅ Speech recognition authorized")
@unknown default:
    print("   ❓ Unknown authorization status")
}

// Check if speech recognizer is available
let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
print("📱 Speech Recognizer Available: \(recognizer?.isAvailable ?? false)")
print("🔊 On-device Recognition: \(recognizer?.supportsOnDeviceRecognition ?? false)")

// Check microphone permission
let micAuth = AVAudioSession.sharedInstance().recordPermission
print("🎤 Microphone Permission: \(micAuth.rawValue)")

switch micAuth {
case .undetermined:
    print("   ⚠️  Microphone permission not requested yet")
case .denied:
    print("   ❌ Microphone permission DENIED") 
case .granted:
    print("   ✅ Microphone permission granted")
@unknown default:
    print("   ❓ Unknown microphone permission")
}

// Check if we're in simulator
#if targetEnvironment(simulator)
print("🖥️  Running in iOS Simulator")
print("   ⚠️  WhisperKit and MLX disabled in simulator")
print("   ✅ Apple Speech should be primary engine")
#else
print("📱 Running on physical device")
print("   ✅ All transcription engines available")
#endif

// Summary
print("\n📊 Status Summary:")
if speechAuth == .authorized && (recognizer?.isAvailable ?? false) && micAuth == .granted {
    print("   ✅ All permissions granted - transcription should work")
} else {
    print("   ❌ Missing permissions - this explains transcription errors!")
    print("   📋 Required fixes:")
    
    if speechAuth != .authorized {
        print("      • Request speech recognition permission")
    }
    
    if micAuth != .granted {
        print("      • Request microphone permission")
    }
    
    if !(recognizer?.isAvailable ?? false) {
        print("      • Speech recognizer not available (network/language issue)")
    }
}

print("\n🎯 Next steps to resolve 'still getting an error on transcription':")
print("   1. Check app permissions in System Settings")
print("   2. Ensure microphone access is enabled")  
print("   3. Ensure speech recognition is enabled")
print("   4. Test on physical device for full functionality")