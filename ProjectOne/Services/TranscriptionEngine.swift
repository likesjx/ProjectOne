import Foundation
import SwiftData

/// Protocol for transcription engines that convert audio to text and extract knowledge
protocol TranscriptionEngine {
    
    /// Transcribe audio data to text with confidence scoring
    /// - Parameter audioData: Raw audio data to transcribe
    /// - Returns: TranscriptionResult with text, confidence, and segments
    func transcribeAudio(_ audioData: Data) async throws -> TranscriptionResult
    
    /// Extract entities from transcribed text
    /// - Parameter text: Text to analyze for entities
    /// - Returns: Array of detected entities with confidence scores
    func extractEntities(from text: String) -> [Entity]
    
    /// Detect relationships between entities in text
    /// - Parameters:
    ///   - entities: Array of entities to analyze
    ///   - text: Original text context
    /// - Returns: Array of detected relationships
    func detectRelationships(entities: [Entity], text: String) -> [Relationship]
}

/// Result of audio transcription operation
struct TranscriptionResult {
    let text: String
    let confidence: Double
    let segments: [TranscriptionSegment]
    let processingTime: TimeInterval
    let language: String
    
    init(text: String, confidence: Double, segments: [TranscriptionSegment], processingTime: TimeInterval, language: String = "en-US") {
        self.text = text
        self.confidence = confidence
        self.segments = segments
        self.processingTime = processingTime
        self.language = language
    }
}

/// Individual segment of transcription with timing information
struct TranscriptionSegment {
    let text: String
    let confidence: Double
    let startTime: TimeInterval
    let endTime: TimeInterval
    let isComplete: Bool
    
    init(text: String, confidence: Double, startTime: TimeInterval, endTime: TimeInterval, isComplete: Bool = true) {
        self.text = text
        self.confidence = confidence
        self.startTime = startTime
        self.endTime = endTime
        self.isComplete = isComplete
    }
}

/// Engine capabilities for feature detection
struct EngineCapabilities {
    let supportsRealTimeTranscription: Bool
    let supportsEntityExtraction: Bool
    let supportsRelationshipDetection: Bool
    let supportsSpeakerDiarization: Bool
    let supportsLanguageDetection: Bool
    let maxAudioDuration: TimeInterval
    
    static let placeholder = EngineCapabilities(
        supportsRealTimeTranscription: true,
        supportsEntityExtraction: true,
        supportsRelationshipDetection: true,
        supportsSpeakerDiarization: false,
        supportsLanguageDetection: false,
        maxAudioDuration: 3600 // 1 hour
    )
    
    static let mlx = EngineCapabilities(
        supportsRealTimeTranscription: true,
        supportsEntityExtraction: true,
        supportsRelationshipDetection: true,
        supportsSpeakerDiarization: true,
        supportsLanguageDetection: true,
        maxAudioDuration: 7200 // 2 hours
    )
}