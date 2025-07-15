//
//  EpisodicMemoryEntry.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 19.0, macOS 16.0, tvOS 19.0, watchOS 12.0, *)
@Model
public final class EpisodicMemoryEntry {
    public var id: UUID
    var eventDescription: String
    var timestamp: Date
    var location: String?
    var participants: [String]
    var emotionalTone: EmotionalTone
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
    
    init(
        eventDescription: String,
        location: String? = nil,
        participants: [String] = [],
        emotionalTone: EmotionalTone = .neutral,
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
    
    func updateEmotionalTone(_ tone: EmotionalTone) {
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
}

enum EmotionalTone: String, Codable, CaseIterable {
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