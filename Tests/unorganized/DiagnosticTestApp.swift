#!/usr/bin/env swift

import Foundation
import Speech
import AVFoundation

// Minimal diagnostic test that mimics our TranscriptionDiagnostic functionality
// This will help identify the "still getting an error on transcription" issue

print("🔍 ProjectOne Transcription Error Analysis")
print("=========================================")

// 1. Check Speech Recognition Authorization
print("\n1️⃣ Speech Recognition Authorization:")
let speechAuth = SFSpeechRecognizer.authorizationStatus()
switch speechAuth {
case .notDetermined:
    print("   ❌ CRITICAL: Speech recognition permission not requested")
    print("   💡 Fix: App needs to request permission on first launch")
case .denied:
    print("   ❌ CRITICAL: Speech recognition permission DENIED by user")
    print("   💡 Fix: Guide user to Settings > Privacy > Speech Recognition")
case .restricted:
    print("   ❌ CRITICAL: Speech recognition RESTRICTED by device policy")
    print("   💡 Fix: Contact device administrator")
case .authorized:
    print("   ✅ Speech recognition permission granted")
@unknown default:
    print("   ⚠️  WARNING: Unknown permission status: \(speechAuth.rawValue)")
}

// 2. Check Speech Recognizer Availability
print("\n2️⃣ Speech Recognizer Availability:")
if let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) {
    if recognizer.isAvailable {
        print("   ✅ Speech recognizer is available")
        print("   📱 On-device support: \(recognizer.supportsOnDeviceRecognition)")
    } else {
        print("   ❌ CRITICAL: Speech recognizer exists but not available")
        print("   💡 Fix: Check network connectivity, try again later")
    }
} else {
    print("   ❌ CRITICAL: Cannot create speech recognizer for en-US")
    print("   💡 Fix: Check device language settings")
}

// 3. Check Microphone Permission (iOS specific)
print("\n3️⃣ Microphone Permission:")
#if canImport(UIKit)
let micAuth = AVAudioSession.sharedInstance().recordPermission
switch micAuth {
case .undetermined:
    print("   ❌ CRITICAL: Microphone permission not requested")
    print("   💡 Fix: App needs to request microphone access")
case .denied:
    print("   ❌ CRITICAL: Microphone permission DENIED by user")
    print("   💡 Fix: Guide user to Settings > Privacy > Microphone")
case .granted:
    print("   ✅ Microphone permission granted")
@unknown default:
    print("   ⚠️  WARNING: Unknown microphone status: \(micAuth.rawValue)")
}
#else
print("   ⚠️  Cannot check microphone on this platform")
#endif

// 4. Check Environment
print("\n4️⃣ Runtime Environment:")
#if targetEnvironment(simulator)
print("   🖥️  Running in iOS Simulator")
print("   ⚠️  WhisperKit and MLX disabled in simulator")
print("   ✅ Apple Speech should be primary transcription engine")
#else
print("   📱 Running on physical device")
print("   ✅ All transcription engines available")
#endif

// 5. Summary and Next Steps
print("\n📊 DIAGNOSIS SUMMARY:")
let hasAllPermissions = speechAuth == .authorized && 
                       (SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.isAvailable ?? false)

#if canImport(UIKit)
let micGranted = AVAudioSession.sharedInstance().recordPermission == .granted
let allOK = hasAllPermissions && micGranted
#else
let allOK = hasAllPermissions
#endif

if allOK {
    print("   ✅ All systems ready - transcription should work")
    print("   💭 If still getting errors, check:")
    print("      • Audio recording quality/format")
    print("      • Network connectivity for cloud recognition")
    print("      • Engine selection logic in SpeechEngineFactory")
} else {
    print("   ❌ TRANSCRIPTION WILL FAIL - Missing critical permissions!")
    print("   🎯 This explains the 'still getting an error on transcription' issue")
    print("   📋 Required fixes:")
    
    if speechAuth != .authorized {
        print("      1. ⚠️  Request speech recognition permission")
    }
    
    #if canImport(UIKit)
    if AVAudioSession.sharedInstance().recordPermission != .granted {
        print("      2. ⚠️  Request microphone permission")
    }
    #endif
    
    if !(SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.isAvailable ?? false) {
        print("      3. ⚠️  Fix speech recognizer availability")
    }
}

print("\n🔧 RECOMMENDED ACTIONS:")
print("   1. Run app and trigger permission requests")
print("   2. Check iOS Settings > Privacy & Security > Speech Recognition")
print("   3. Check iOS Settings > Privacy & Security > Microphone")
print("   4. Test transcription after permission grants")
print("   5. If issues persist, test on physical device")

print("\n" + String(repeating: "=", count: 50))
print("📝 Diagnostic completed: \(Date())")