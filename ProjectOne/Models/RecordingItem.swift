import Foundation
import SwiftData

/// Represents an audio recording with its metadata and transcription
@Model
final class RecordingItem {
    var id: UUID
    var timestamp: Date
    
    // File information
    var filename: String
    var fileURL: URL
    var fileSizeBytes: Int64
    var duration: TimeInterval
    
    // Audio metadata
    var sampleRate: Double
    var channels: Int
    var format: String // e.g., "m4a", "wav"
    var bitRate: Int?
    
    // Transcription data
    var transcriptionText: String?
    var transcriptionConfidence: Double
    var transcriptionLanguage: String?
    var transcriptionEngine: String // "Apple Speech", "Placeholder", "MLX", etc.
    var transcriptionDate: Date?
    
    // Transcription segments (stored as JSON)
    var transcriptionSegments: Data? // Encoded TranscriptionSegment array
    
    // Processing status
    var isTranscribed: Bool
    var isTranscribing: Bool
    var transcriptionError: String?
    
    // User metadata
    var title: String? // User-provided title
    var notes: String? // User notes about the recording
    var tags: [String] // User-assigned tags
    var isFavorite: Bool
    var isArchived: Bool
    
    // Knowledge graph connections
    var extractedEntityIds: [UUID] // IDs of entities extracted from transcription
    var extractedRelationshipIds: [UUID] // IDs of relationships extracted
    var memoryScore: Double // Importance score for memory system
    
    // Playback tracking
    var playCount: Int
    var lastPlayedAt: Date?
    var bookmarkPosition: TimeInterval // For resuming playback
    
    init(
        filename: String,
        fileURL: URL,
        fileSizeBytes: Int64,
        duration: TimeInterval = 0,
        sampleRate: Double = 12000,
        channels: Int = 1,
        format: String = "m4a"
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.filename = filename
        self.fileURL = fileURL
        self.fileSizeBytes = fileSizeBytes
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.bitRate = nil
        
        // Transcription
        self.transcriptionText = nil
        self.transcriptionConfidence = 0.0
        self.transcriptionLanguage = nil
        self.transcriptionEngine = "Unknown"
        self.transcriptionDate = nil
        self.transcriptionSegments = nil
        
        // Status
        self.isTranscribed = false
        self.isTranscribing = false
        self.transcriptionError = nil
        
        // User metadata
        self.title = nil
        self.notes = nil
        self.tags = []
        self.isFavorite = false
        self.isArchived = false
        
        // Knowledge graph
        self.extractedEntityIds = []
        self.extractedRelationshipIds = []
        self.memoryScore = 0.0
        
        // Playback
        self.playCount = 0
        self.lastPlayedAt = nil
        self.bookmarkPosition = 0.0
    }
    
    // MARK: - Convenience Methods
    
    /// Update with transcription result
    func updateWithTranscription(
        _ result: TranscriptionResult,
        engine: String
    ) {
        self.transcriptionText = result.text
        self.transcriptionConfidence = result.confidence
        self.transcriptionLanguage = result.language
        self.transcriptionEngine = engine
        self.transcriptionDate = Date()
        self.isTranscribed = true
        self.isTranscribing = false
        self.transcriptionError = nil
        
        // Store segments as JSON
        if let segmentsData = try? JSONEncoder().encode(result.segments) {
            self.transcriptionSegments = segmentsData
        }
    }
    
    /// Mark transcription as failed
    func markTranscriptionFailed(error: String) {
        self.isTranscribing = false
        self.transcriptionError = error
        self.transcriptionDate = Date()
    }
    
    /// Get decoded transcription segments
    func getTranscriptionSegments() -> [TranscriptionSegment] {
        guard let segmentsData = transcriptionSegments else { return [] }
        
        do {
            return try JSONDecoder().decode([TranscriptionSegment].self, from: segmentsData)
        } catch {
            print("Failed to decode transcription segments: \(error)")
            return []
        }
    }
    
    /// Record a play event
    func recordPlayback() {
        self.playCount += 1
        self.lastPlayedAt = Date()
    }
    
    /// Update bookmark position for resuming playback
    func updateBookmark(position: TimeInterval) {
        self.bookmarkPosition = max(0, min(position, duration))
    }
    
    /// Get display title (user title or formatted filename)
    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        
        // Format the filename into a readable title
        let nameWithoutExtension = filename.replacingOccurrences(of: ".\(format)", with: "")
        
        // Try to parse as date format (dd-MM-YY_HH-mm-ss)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yy_HH-mm-ss"
        
        if let date = dateFormatter.date(from: nameWithoutExtension) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .short
            return "Recording \(displayFormatter.string(from: date))"
        }
        
        return nameWithoutExtension
    }
    
    /// Get formatted file size
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
    
    /// Get formatted duration
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Check if file exists on disk
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}

// MARK: - TranscriptionSegment Codable Support

extension TranscriptionSegment: Codable {
    enum CodingKeys: String, CodingKey {
        case text, confidence, startTime, endTime, isComplete
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(isComplete, forKey: .isComplete)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        confidence = try container.decode(Double.self, forKey: .confidence)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
    }
}