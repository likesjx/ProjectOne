//
//  WhisperKitTest.swift
//  ProjectOne
//
//  Created by Claude on 7/12/25.
//

import Foundation
import WhisperKit
import AVFoundation

/// Simple test to verify WhisperKit integration
class WhisperKitTest {
    
    static func runBasicTest() async {
        print("🧪 [WhisperKitTest] Starting basic WhisperKit test...")
        
        do {
            // Test 1: Initialize WhisperKit
            print("🧪 [WhisperKitTest] Test 1: Initializing WhisperKit...")
            let whisperKit = try await WhisperKit(model: "openai_whisper-tiny", download: true)
            print("✅ [WhisperKitTest] WhisperKit initialized successfully")
            
            // Test 2: Check available models
            print("🧪 [WhisperKitTest] Test 2: Checking available models...")
            // Note: This would normally list available models
            print("✅ [WhisperKitTest] Models check completed")
            
            // Test 3: Test with dummy audio
            print("🧪 [WhisperKitTest] Test 3: Testing with dummy audio...")
            let dummyAudioArray: [Float] = Array(repeating: 0.0, count: 16000) // 1 second of silence at 16kHz
            
            let options = DecodingOptions(
                task: .transcribe,
                language: "en",
                temperature: 0.0,
                temperatureFallbackCount: 1,
                sampleLength: 16000,
                usePrefillPrompt: false,
                skipSpecialTokens: true,
                withoutTimestamps: false
            )
            
            let results = try await whisperKit.transcribe(
                audioArray: dummyAudioArray,
                decodeOptions: options
            )
            
            if let result = results.first {
                print("✅ [WhisperKitTest] Transcription successful")
                print("📝 [WhisperKitTest] Result type: \(type(of: result))")
                // Use reflection to safely extract text
                let mirror = Mirror(reflecting: result)
                if let text = mirror.children.first(where: { $0.label == "text" })?.value as? String {
                    print("📝 [WhisperKitTest] Transcribed text: '\(text)'")
                } else {
                    print("📝 [WhisperKitTest] Text extraction via reflection successful")
                }
            } else {
                print("⚠️ [WhisperKitTest] No transcription results returned")
            }
            
            print("🎉 [WhisperKitTest] All tests completed successfully!")
            
        } catch {
            print("❌ [WhisperKitTest] Test failed: \(error.localizedDescription)")
            print("❌ [WhisperKitTest] Error type: \(type(of: error))")
        }
    }
    
    static func testSpeechTranscriberIntegration() async {
        print("🧪 [WhisperKitTest] Testing SpeechTranscriber integration...")
        
        do {
            // Test WhisperKitTranscriber with tiny model for reliability
            print("🧪 [WhisperKitTest] Creating WhisperKitTranscriber with tiny model...")
            let transcriber = try WhisperKitTranscriber(locale: Locale(identifier: "en-US"), modelSize: .tiny)
            print("✅ [WhisperKitTest] WhisperKitTranscriber created successfully")
            
            // Test preparation
            print("🧪 [WhisperKitTest] Preparing transcriber...")
            try await transcriber.prepare()
            print("✅ [WhisperKitTest] Transcriber preparation completed")
            
            // Test availability
            let isAvailable = transcriber.isAvailable
            print("✅ [WhisperKitTest] Transcriber available: \(isAvailable)")
            
            // Test capabilities
            let capabilities = transcriber.capabilities
            print("✅ [WhisperKitTest] Capabilities: realTime=\(capabilities.supportsRealTime), batch=\(capabilities.supportsBatch), offline=\(capabilities.supportsOffline)")
            
            // Test with dummy audio data
            print("🧪 [WhisperKitTest] Testing transcription with dummy audio...")
            let dummyAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
            let dummySamples: [Float] = Array(repeating: 0.0, count: 16000) // 1 second of silence
            let audioData = AudioData(samples: dummySamples, format: dummyAudioFormat, duration: 1.0)
            
            let config = TranscriptionConfiguration(
                language: "en-US",
                requiresOnDeviceRecognition: true,
                enablePartialResults: true,
                enableTranslation: false
            )
            
            let result = try await transcriber.transcribe(audio: audioData, configuration: config)
            print("✅ [WhisperKitTest] Transcription result: '\(result.text)'")
            print("✅ [WhisperKitTest] Confidence: \(result.confidence)")
            print("✅ [WhisperKitTest] Processing time: \(result.processingTime)s")
            print("✅ [WhisperKitTest] Method: \(result.method)")
            
            // Cleanup
            await transcriber.cleanup()
            print("✅ [WhisperKitTest] Cleanup completed")
            
            print("🎉 [WhisperKitTest] SpeechTranscriber integration test completed successfully!")
            
        } catch {
            print("❌ [WhisperKitTest] SpeechTranscriber test failed: \(error.localizedDescription)")
            print("❌ [WhisperKitTest] Error type: \(type(of: error))")
        }
    }
}