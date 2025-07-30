//
//  EpisodicMemoryEntry.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class EpisodicMemoryEntry {
    public var id: UUID
    var eventDescription: String
    var timestamp: Date
    var location: String?
    var participants: [String]
    var emotionalTone: EpisodicMemoryEntry.EmotionalTone
    var importance: Double
    var contextualCues: [String]
    var relatedEntities: [UUID]
    var relatedEvents: [UUID]
    var duration: TimeInterval?
    var outcome: String?
    var lessons: [String]
    var vividity: Double
    var accessCount: Int
    var lastAccessed: Date
    
    // MARK: - Embedding Fields
    
    /// Vector embedding for semantic similarity search
    var embedding: Data?
    
    /// Version identifier for the embedding model used
    var embeddingModelVersion: String?
    
    /// Timestamp when the embedding was generated
    var embeddingGeneratedAt: Date?
    
    init(
        eventDescription: String,
        location: String? = nil,
        participants: [String] = [],
        emotionalTone: EpisodicMemoryEntry.EmotionalTone = .neutral,
        importance: Double = 0.5,
        contextualCues: [String] = [],
        duration: TimeInterval? = nil,
        outcome: String? = nil,
        lessons: [String] = []
    ) {
        self.id = UUID()
        self.eventDescription = eventDescription
        self.timestamp = Date()
        self.location = location
        self.participants = participants
        self.emotionalTone = emotionalTone
        self.importance = importance
        self.contextualCues = contextualCues
        self.relatedEntities = []
        self.relatedEvents = []
        self.duration = duration
        self.outcome = outcome
        self.lessons = lessons
        self.vividity = 1.0
        self.accessCount = 0
        self.lastAccessed = Date()
        
        // Initialize embedding fields
        self.embedding = nil
        self.embeddingModelVersion = nil
        self.embeddingGeneratedAt = nil
    }
    
    // MARK: - Episodic Memory Functions
    
    func access() {
        accessCount += 1
        lastAccessed = Date()
        
        // Episodic memories can become more vivid with rehearsal
        vividity = min(vividity + 0.05, 1.0)
    }
    
    func addRelatedEvent(_ eventId: UUID) {
        if !relatedEvents.contains(eventId) {
            relatedEvents.append(eventId)
        }
    }
    
    func addLesson(_ lesson: String) {
        if !lessons.contains(lesson) {
            lessons.append(lesson)
            importance = min(importance + 0.1, 1.0)
        }
    }
    
    func updateEmotionalTone(_ tone: EpisodicMemoryEntry.EmotionalTone) {
        emotionalTone = tone
        
        // Emotional events are more memorable
        if tone != .neutral {
            importance = min(importance + 0.2, 1.0)
            vividity = min(vividity + 0.1, 1.0)
        }
    }
    
    var memoryStrength: Double {
        let recencyFactor = max(0.1, 1.0 - (Date().timeIntervalSince(timestamp) / (365 * 24 * 3600))) // 1 year decay
        let emotionalFactor = emotionalTone == .neutral ? 1.0 : 1.5
        let accessFactor = min(1.0 + (Double(accessCount) * 0.1), 2.0)
        
        return (importance * vividity * recencyFactor * emotionalFactor * accessFactor) / 2.0
    }
    
    var isSignificant: Bool {
        return memoryStrength > 0.7 || emotionalTone != .neutral
    }
    
    // MARK: - Embedding Management
    
    /// Check if the memory has a valid embedding
    var hasEmbedding: Bool {
        return embedding != nil && embeddingModelVersion != nil
    }
    
    /// Set the embedding for this memory entry
    func setEmbedding(_ embeddingVector: [Float], modelVersion: String) {
        self.embedding = EmbeddingUtils.embeddingToData(embeddingVector)
        self.embeddingModelVersion = modelVersion
        self.embeddingGeneratedAt = Date()
    }
    
    /// Get the embedding as a float array for calculations
    func getEmbedding() -> [Float]? {
        guard let embeddingData = embedding else { return nil }
        return EmbeddingUtils.dataToEmbedding(embeddingData)
    }
    
    /// Check if embedding needs regeneration (model version changed or too old)
    func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval = 14 * 24 * 3600) -> Bool {
        guard hasEmbedding else { return true }
        
        // Check model version
        if embeddingModelVersion != currentModelVersion {
            return true
        }
        
        // Check age (episodic memories can update embeddings as context changes)
        if let generatedAt = embeddingGeneratedAt,
           Date().timeIntervalSince(generatedAt) > maxAge {
            return true
        }
        
        return false
    }
    
    /// Get combined text for embedding generation
    var embeddingText: String {
        var text = eventDescription
        
        if let location = location, !location.isEmpty {
            text += " at \(location)"
        }
        
        if !participants.isEmpty {
            text += " involving \(participants.joined(separator: ", "))"
        }
        
        if let outcome = outcome, !outcome.isEmpty {
            text += ". Outcome: \(outcome)"
        }
        
        if !lessons.isEmpty {
            text += ". Lessons: \(lessons.joined(separator: "; "))"
        }
        
        return text
    }
    
    // MARK: - Nested Types
    
    public enum EmotionalTone: String, Codable, CaseIterable {
    case veryPositive = "very_positive"
    case positive = "positive"
    case neutral = "neutral"
    case negative = "negative"
    case veryNegative = "very_negative"
    
        var displayName: String {
            switch self {
            case .veryPositive: return "Very Positive"
            case .positive: return "Positive"
            case .neutral: return "Neutral"
            case .negative: return "Negative"
            case .veryNegative: return "Very Negative"
            }
        }
        
        var emotionalWeight: Double {
            switch self {
            case .veryPositive: return 1.0
            case .positive: return 0.6
            case .neutral: return 0.0
            case .negative: return 0.6
            case .veryNegative: return 1.0
            }
        }
    }
}