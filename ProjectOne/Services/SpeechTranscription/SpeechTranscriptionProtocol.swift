//
//  SpeechTranscriptionProtocol.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import Foundation
import AVFoundation

// MARK: - Core Data Types

/// Represents audio data for processing
public struct AudioData {
    let audioBuffer: AVAudioBuffer?
    let samples: [Float]
    let format: AVAudioFormat
    let duration: TimeInterval
    let sampleRate: Double
    
    init(buffer: AVAudioBuffer, format: AVAudioFormat, duration: TimeInterval) {
        self.audioBuffer = buffer
        self.format = format
        self.duration = duration
        self.sampleRate = format.sampleRate
        
        // Extract samples from buffer if possible
        if let pcmBuffer = buffer as? AVAudioPCMBuffer,
           let channelData = pcmBuffer.floatChannelData {
            let frameLength = Int(pcmBuffer.frameLength)
            var extractedSamples: [Float] = []
            extractedSamples.reserveCapacity(frameLength)
            
            for i in 0..<frameLength {
                extractedSamples.append(channelData[0][i])
            }
            self.samples = extractedSamples
        } else {
            self.samples = []
        }
    }
    
    init(samples: [Float], format: AVAudioFormat, duration: TimeInterval) {
        self.audioBuffer = nil
        self.samples = samples
        self.format = format
        self.duration = duration
        self.sampleRate = format.sampleRate
    }
}

/// Represents processed audio data ready for transcription
public struct ProcessedAudioData {
    let samples: [Float]
    let sampleRate: Double
    let channels: Int
    let duration: TimeInterval
}

/// Result of transcription operation with enhanced metadata
public struct SpeechTranscriptionResult {
    let text: String
    let confidence: Float
    let segments: [SpeechTranscriptionSegment]
    let processingTime: TimeInterval
    let method: TranscriptionMethod
    let language: String?
    
    public init(text: String, confidence: Float = 1.0, segments: [SpeechTranscriptionSegment] = [], processingTime: TimeInterval, method: TranscriptionMethod, language: String? = nil) {
        self.text = text
        self.confidence = confidence
        self.segments = segments
        self.processingTime = processingTime
        self.method = method
        self.language = language
    }
}

/// Individual segment of transcribed text with enhanced metadata
public struct SpeechTranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
    
    public init(text: String, startTime: TimeInterval, endTime: TimeInterval, confidence: Float) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

/// Transcription method used
public enum TranscriptionMethod {
    case appleSpeech
    case speechAnalyzer
    case mlx
    case whisperKit
    case hybrid
    
    public var displayName: String {
        switch self {
        case .appleSpeech:
            return "Apple Speech"
        case .speechAnalyzer:
            return "SpeechAnalyzer"
        case .mlx:
            return "MLX"
        case .whisperKit:
            return "WhisperKit"
        case .hybrid:
            return "Hybrid"
        }
    }
}

/// Capabilities of a transcription implementation
public struct TranscriptionCapabilities {
    let supportsRealTime: Bool
    let supportsBatch: Bool
    let supportsOffline: Bool
    let supportedLanguages: [String]
    let maxAudioDuration: TimeInterval?
    let requiresPermission: Bool
    
    public init(supportsRealTime: Bool, supportsBatch: Bool, supportsOffline: Bool, supportedLanguages: [String], maxAudioDuration: TimeInterval? = nil, requiresPermission: Bool) {
        self.supportsRealTime = supportsRealTime
        self.supportsBatch = supportsBatch
        self.supportsOffline = supportsOffline
        self.supportedLanguages = supportedLanguages
        self.maxAudioDuration = maxAudioDuration
        self.requiresPermission = requiresPermission
    }
}

/// Configuration for transcription
public struct TranscriptionConfiguration {
    let language: String?
    let requiresOnDeviceRecognition: Bool
    let enablePartialResults: Bool
    let enableTranslation: Bool
    let contextualStrings: [String]
    
    public init(language: String? = nil, requiresOnDeviceRecognition: Bool = true, enablePartialResults: Bool = true, enableTranslation: Bool = false, contextualStrings: [String] = []) {
        self.language = language
        self.requiresOnDeviceRecognition = requiresOnDeviceRecognition
        self.enablePartialResults = enablePartialResults
        self.enableTranslation = enableTranslation
        self.contextualStrings = contextualStrings
    }
}

// MARK: - Error Types

public enum SpeechTranscriptionError: Error {
    case audioFormatUnsupported
    case modelUnavailable
    case insufficientResources
    case permissionDenied
    case networkRequired
    case processingFailed(String)
    case configurationInvalid
    case fallbackRequired
    case lowQualityResult
    
    public var localizedDescription: String {
        switch self {
        case .audioFormatUnsupported:
            return "Audio format is not supported"
        case .modelUnavailable:
            return "Transcription model is not available"
        case .insufficientResources:
            return "Insufficient system resources for transcription"
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .networkRequired:
            return "Network connection required for transcription"
        case .processingFailed(let message):
            return "Transcription processing failed: \(message)"
        case .configurationInvalid:
            return "Invalid transcription configuration"
        case .fallbackRequired:
            return "Fallback to alternative transcription method required"
        case .lowQualityResult:
            return "Transcription result quality below acceptable threshold"
        }
    }
}

// MARK: - Main Protocol

/// Main protocol for speech transcription implementations
public protocol SpeechTranscriptionProtocol: AnyObject {
    
    /// Transcribe audio data in batch mode
    func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult
    
    /// Transcribe audio in real-time streaming mode
    func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult>
    
    /// Check if the implementation is currently available
    var isAvailable: Bool { get }
    
    /// Get the capabilities of this implementation
    var capabilities: TranscriptionCapabilities { get }
    
    /// Get the transcription method identifier
    var method: TranscriptionMethod { get }
    
    /// Prepare the transcriber for use (load models, etc.)
    func prepare() async throws
    
    /// Clean up resources
    func cleanup() async
    
    /// Check if the transcriber can handle the given audio format
    func canProcess(audioFormat: AVAudioFormat) -> Bool
}

// MARK: - Audio Processing Protocol

/// Protocol for audio preprocessing operations
public protocol AudioProcessingProtocol {
    
    /// Preprocess audio for transcription
    func preprocess(audio: AudioData) throws -> ProcessedAudioData
    
    /// Normalize audio levels
    func normalize(audio: AudioData) throws -> AudioData
    
    /// Convert audio format
    func convert(audio: AudioData, to format: AVAudioFormat) throws -> AudioData
    
    /// Get supported audio formats
    var supportedFormats: [AVAudioFormat] { get }
    
    /// Get optimal audio format for this processor
    var preferredFormat: AVAudioFormat { get }
}

// MARK: - Model Loading Protocol

/// Protocol for dynamic model management
public protocol ModelLoadingProtocol {
    
    /// Load a transcription model
    func loadModel(name: String) async throws -> TranscriptionModel
    
    /// Unload a model to free resources
    func unloadModel(name: String) throws
    
    /// Check if a model is currently loaded
    func isModelLoaded(name: String) -> Bool
    
    /// Get list of available models
    var availableModels: [String] { get }
    
    /// Get list of currently loaded models
    var loadedModels: [String] { get }
    
    /// Get model information
    func getModelInfo(name: String) -> ModelInfo?
}

// MARK: - Model Types

/// Represents a loaded transcription model
public protocol TranscriptionModel {
    var name: String { get }
    var version: String { get }
    var supportedLanguages: [String] { get }
    var memoryFootprint: Int { get }
    var isLoaded: Bool { get }
}

/// Information about a transcription model
public struct ModelInfo {
    let name: String
    let version: String
    let size: Int
    let supportedLanguages: [String]
    let description: String
    let requiresDownload: Bool
    
    public init(name: String, version: String, size: Int, supportedLanguages: [String], description: String, requiresDownload: Bool) {
        self.name = name
        self.version = version
        self.size = size
        self.supportedLanguages = supportedLanguages
        self.description = description
        self.requiresDownload = requiresDownload
    }
}