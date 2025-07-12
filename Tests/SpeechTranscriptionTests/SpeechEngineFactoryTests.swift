//
//  SpeechEngineFactoryTests.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import XCTest
import AVFoundation
@testable import ProjectOne

// MARK: - Mock Implementation

class MockSpeechTranscriber: SpeechTranscriptionProtocol {
    let method: TranscriptionMethod
    let mockIsAvailable: Bool
    let mockCapabilities: TranscriptionCapabilities
    
    init(method: TranscriptionMethod, isAvailable: Bool = true) {
        self.method = method
        self.mockIsAvailable = isAvailable
        self.mockCapabilities = TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true,
            supportedLanguages: ["en-US"],
            requiresPermission: method == .appleSpeech
        )
    }
    
    var isAvailable: Bool { mockIsAvailable }
    var capabilities: TranscriptionCapabilities { mockCapabilities }
    
    func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        return SpeechTranscriptionResult(
            text: "Mock transcription from \(method.displayName)",
            confidence: 0.95,
            segments: [],
            processingTime: 0.1,
            method: method
        )
    }
    
    func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    func prepare() async throws {
        // Mock preparation
    }
    
    func cleanup() async {
        // Mock cleanup
    }
    
    func canProcess(audioFormat: AVAudioFormat) -> Bool {
        return true
    }
}

// MARK: - Tests

class SpeechEngineFactoryTests: XCTestCase {
    
    func testDeviceCapabilitiesDetection() {
        let capabilities = DeviceCapabilities.detect()
        
        // Basic sanity checks
        XCTAssertGreaterThan(capabilities.totalMemory, 0)
        XCTAssertGreaterThan(capabilities.availableMemory, 0)
        XCTAssertFalse(capabilities.deviceModel.isEmpty)
        XCTAssertFalse(capabilities.osVersion.isEmpty)
        
        // On simulator or Apple Silicon devices, should support MLX
        #if targetEnvironment(simulator)
        XCTAssertTrue(capabilities.hasAppleSilicon)
        XCTAssertTrue(capabilities.supportsMLX)
        #endif
    }
    
    func testSpeechEngineConfigurationDefaults() {
        let config = SpeechEngineConfiguration.default
        
        XCTAssertEqual(config.strategy, .automatic)
        XCTAssertTrue(config.enableFallback)
        XCTAssertNil(config.maxMemoryUsage)
        XCTAssertNil(config.preferredLanguage)
    }
    
    func testSpeechEngineConfigurationCustom() {
        let config = SpeechEngineConfiguration(
            strategy: .preferMLX,
            enableFallback: false,
            maxMemoryUsage: 1024 * 1024 * 1024, // 1GB
            preferredLanguage: "en-US"
        )
        
        XCTAssertEqual(config.strategy, .preferMLX)
        XCTAssertFalse(config.enableFallback)
        XCTAssertEqual(config.maxMemoryUsage, 1024 * 1024 * 1024)
        XCTAssertEqual(config.preferredLanguage, "en-US")
    }
    
    func testEngineSelectionStrategyDescriptions() {
        XCTAssertEqual(EngineSelectionStrategy.automatic.description, "Automatic (best available)")
        XCTAssertEqual(EngineSelectionStrategy.preferApple.description, "Prefer Apple Speech")
        XCTAssertEqual(EngineSelectionStrategy.preferMLX.description, "Prefer MLX")
        XCTAssertEqual(EngineSelectionStrategy.appleOnly.description, "Apple Speech only")
        XCTAssertEqual(EngineSelectionStrategy.mlxOnly.description, "MLX only")
    }
    
    func testFactoryInitialization() {
        let config = SpeechEngineConfiguration(strategy: .preferApple)
        let factory = SpeechEngineFactory(configuration: config)
        
        let status = factory.getEngineStatus()
        XCTAssertNil(status.primary) // No engine selected yet
        XCTAssertNil(status.fallback) // No fallback set yet
        XCTAssertGreaterThan(status.capabilities.totalMemory, 0)
    }
    
    func testSharedInstance() {
        let factory1 = SpeechEngineFactory.shared
        let factory2 = SpeechEngineFactory.shared
        
        // Should be the same instance
        XCTAssertTrue(factory1 === factory2)
    }
    
    func testTranscriptionWithMockEngine() async throws {
        // Use the test factory with mock implementations
        let factory = SpeechEngineFactory.createTestFactory()
        
        // Create test audio data
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        let audioData = AudioData(buffer: buffer, format: format, duration: 1.0)
        
        let config = TranscriptionConfiguration()
        
        // This should work with the mock implementation
        do {
            let result = try await factory.transcribe(audio: audioData, configuration: config)
            XCTAssertFalse(result.text.isEmpty)
            XCTAssertEqual(result.method, .appleSpeech)
            XCTAssertGreaterThan(result.confidence, 0.0)
        } catch {
            XCTFail("Mock transcription should not fail: \(error)")
        }
    }
}

// MARK: - Factory Extension for Testing

extension SpeechEngineFactory {
    
    /// Test helper to create mock engines for testing without real hardware dependencies
    static func createTestFactory() -> SpeechEngineFactory {
        class TestSpeechEngineFactory: SpeechEngineFactory {
            override func createAppleEngine() async throws -> SpeechTranscriptionProtocol {
                return MockSpeechTranscriber(method: .appleSpeech)
            }
            
            override func createMLXEngine() async throws -> SpeechTranscriptionProtocol {
                return MockSpeechTranscriber(method: .mlx)
            }
        }
        
        return TestSpeechEngineFactory()
    }
}