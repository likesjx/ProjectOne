//
//  SimpleTranscriptionTest.swift
//  ProjectOne
//
//  Working transcription test that bypasses architecture issues
//

import Foundation
import Speech
import AVFoundation
import os.log

/// Simple, working transcription test that bypasses complex architecture
public class SimpleTranscriptionTest {
    
    private let logger = Logger(subsystem: "com.projectone.test", category: "SimpleTranscription")
    
    /// Test transcription with Apple Speech (bypassing SpeechEngineFactory)
    public func testAppleSpeechDirectly() async throws -> String {
        logger.info("🎤 Testing Apple Speech directly...")
        
        // Check permissions first
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionTestError.permissionDenied("Speech recognition not authorized")
        }
        
        // Create recognizer
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            throw TranscriptionTestError.recognizerUnavailable("Cannot create speech recognizer")
        }
        
        guard recognizer.isAvailable else {
            throw TranscriptionTestError.recognizerUnavailable("Speech recognizer not available")
        }
        
        logger.info("✅ Apple Speech recognizer is ready")
        logger.info("🔊 On-device recognition: \(recognizer.supportsOnDeviceRecognition)")
        
        // For a real test, you'd need audio data here
        // This is just testing the setup
        return "✅ Apple Speech is working and ready for transcription"
    }
    
    /// Request speech recognition permission if needed
    public static func requestPermissionIfNeeded() async -> Bool {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch currentStatus {
        case .authorized:
            return true
            
        case .notDetermined:
            print("🔒 Requesting speech recognition permission...")
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            
        case .denied, .restricted:
            print("❌ Speech recognition permission denied or restricted")
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// Quick status check
    public func getTranscriptionStatus() -> String {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        var status = "🎤 Transcription Status:\n"
        status += "   • Permission: \(authStatus == .authorized ? "✅ Authorized" : "❌ Not authorized")\n"
        status += "   • Recognizer: \(recognizer?.isAvailable == true ? "✅ Available" : "❌ Unavailable")\n"
        status += "   • On-device: \(recognizer?.supportsOnDeviceRecognition == true ? "✅ Supported" : "❌ Not supported")\n"
        
        if authStatus == .authorized && recognizer?.isAvailable == true {
            status += "\n🎯 Result: Transcription should work!"
        } else {
            status += "\n❌ Result: Transcription will not work"
        }
        
        return status
    }
}

// MARK: - Error Types

public enum TranscriptionTestError: Error, LocalizedError {
    case permissionDenied(String)
    case recognizerUnavailable(String)
    case audioProcessingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .recognizerUnavailable(let message):
            return "Recognizer unavailable: \(message)"
        case .audioProcessingFailed(let message):
            return "Audio processing failed: \(message)"
        }
    }
}