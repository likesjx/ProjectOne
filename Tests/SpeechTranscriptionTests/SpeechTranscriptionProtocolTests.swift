//
//  SpeechTranscriptionProtocolTests.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import XCTest
import AVFoundation
@testable import ProjectOne

class SpeechTranscriptionProtocolTests: XCTestCase {
    
    func testAudioDataCreation() throws {
        // Create a simple audio buffer for testing
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        
        let audioData = AudioData(buffer: buffer, format: format, duration: 1.0)
        
        XCTAssertEqual(audioData.sampleRate, 44100)
        XCTAssertEqual(audioData.duration, 1.0)
        XCTAssertEqual(audioData.format.channelCount, 1)
    }
    
    func testTranscriptionResultCreation() {
        let segment = SpeechTranscriptionSegment(
            text: "Hello world",
            startTime: 0.0,
            endTime: 1.0,
            confidence: 0.95
        )
        
        let result = SpeechTranscriptionResult(
            text: "Hello world",
            confidence: 0.95,
            segments: [segment],
            processingTime: 0.1,
            method: .appleSpeech,
            language: "en-US"
        )
        
        XCTAssertEqual(result.text, "Hello world")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.segments.count, 1)
        XCTAssertEqual(result.segments.first?.text, "Hello world")
        XCTAssertEqual(result.method.displayName, "Apple Speech")
        XCTAssertEqual(result.language, "en-US")
    }
    
    func testTranscriptionMethodDisplayNames() {
        XCTAssertEqual(TranscriptionMethod.appleSpeech.displayName, "Apple Speech")
        XCTAssertEqual(TranscriptionMethod.appleFoundation.displayName, "Apple Foundation")
        XCTAssertEqual(TranscriptionMethod.mlx.displayName, "MLX")
        XCTAssertEqual(TranscriptionMethod.hybrid.displayName, "Hybrid")
    }
    
    func testTranscriptionCapabilities() {
        let capabilities = TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: false,
            supportedLanguages: ["en-US", "es-ES"],
            maxAudioDuration: 60.0,
            requiresPermission: true
        )
        
        XCTAssertTrue(capabilities.supportsRealTime)
        XCTAssertTrue(capabilities.supportsBatch)
        XCTAssertFalse(capabilities.supportsOffline)
        XCTAssertEqual(capabilities.supportedLanguages.count, 2)
        XCTAssertEqual(capabilities.maxAudioDuration, 60.0)
        XCTAssertTrue(capabilities.requiresPermission)
    }
    
    func testTranscriptionConfiguration() {
        let config = TranscriptionConfiguration(
            language: "en-US",
            requiresOnDeviceRecognition: true,
            enablePartialResults: false,
            contextualStrings: ["ProjectOne", "voice memo"]
        )
        
        XCTAssertEqual(config.language, "en-US")
        XCTAssertTrue(config.requiresOnDeviceRecognition)
        XCTAssertFalse(config.enablePartialResults)
        XCTAssertEqual(config.contextualStrings.count, 2)
    }
    
    func testDefaultTranscriptionConfiguration() {
        let config = TranscriptionConfiguration()
        
        XCTAssertNil(config.language)
        XCTAssertTrue(config.requiresOnDeviceRecognition)
        XCTAssertTrue(config.enablePartialResults)
        XCTAssertTrue(config.contextualStrings.isEmpty)
    }
    
    func testSpeechTranscriptionErrorDescriptions() {
        XCTAssertEqual(
            SpeechTranscriptionError.audioFormatUnsupported.localizedDescription,
            "Audio format is not supported"
        )
        
        XCTAssertEqual(
            SpeechTranscriptionError.processingFailed("Network timeout").localizedDescription,
            "Transcription processing failed: Network timeout"
        )
        
        XCTAssertEqual(
            SpeechTranscriptionError.permissionDenied.localizedDescription,
            "Speech recognition permission denied"
        )
    }
    
    func testModelInfo() {
        let modelInfo = ModelInfo(
            name: "whisper-small",
            version: "1.0",
            size: 244 * 1024 * 1024, // 244MB
            supportedLanguages: ["en", "es", "fr"],
            description: "Small Whisper model for fast transcription",
            requiresDownload: true
        )
        
        XCTAssertEqual(modelInfo.name, "whisper-small")
        XCTAssertEqual(modelInfo.version, "1.0")
        XCTAssertEqual(modelInfo.size, 244 * 1024 * 1024)
        XCTAssertEqual(modelInfo.supportedLanguages.count, 3)
        XCTAssertTrue(modelInfo.requiresDownload)
    }
}