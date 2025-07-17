//
//  TemporalEvent.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@Model
final class TemporalEvent {
    var id: UUID
    var title: String
    var eventDescription: String
    var startTime: Date
    var endTime: Date?
    var eventType: EventType
    var importance: Double
    var participants: [UUID] // Entity IDs
    var location: String?
    var relatedNotes: [UUID]
    var relatedEvents: [UUID]
    var outcomes: [String]
    var preconditions: [String]
    var consequences: [String]
    var tags: [String]
    var confidence: Double
    var accessCount: Int
    var lastAccessed: Date
    
    init(
        title: String,
        description: String,
        startTime: Date,
        endTime: Date? = nil,
        eventType: EventType = .general,
        importance: Double = 0.5,
        participants: [UUID] = [],
        location: String? = nil,
        outcomes: [String] = [],
        preconditions: [String] = [],
        consequences: [String] = [],
        tags: [String] = [],
        confidence: Double = 0.8
    ) {
        self.id = UUID()
        self.title = title
        self.eventDescription = description
        self.startTime = startTime
        self.endTime = endTime
        self.eventType = eventType
        self.importance = importance
        self.participants = participants
        self.location = location
        self.relatedNotes = []
        self.relatedEvents = []
        self.outcomes = outcomes
        self.preconditions = preconditions
        self.consequences = consequences
        self.tags = tags
        self.confidence = confidence
        self.accessCount = 0
        self.lastAccessed = Date()
    }
    
    // MARK: - Temporal Relationships
    
    func access() {
        accessCount += 1
        lastAccessed = Date()
    }
    
    func addRelatedEvent(_ eventId: UUID, relationship: TemporalRelationship) {
        if !relatedEvents.contains(eventId) {
            relatedEvents.append(eventId)
        }
    }
    
    func addParticipant(_ entityId: UUID) {
        if !participants.contains(entityId) {
            participants.append(entityId)
        }
    }
    
    func addOutcome(_ outcome: String) {
        if !outcomes.contains(outcome) {
            outcomes.append(outcome)
            importance = min(importance + 0.1, 1.0)
        }
    }
    
    func addConsequence(_ consequence: String) {
        if !consequences.contains(consequence) {
            consequences.append(consequence)
            importance = min(importance + 0.05, 1.0)
        }
    }
    
    var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    var isOngoing: Bool {
        return endTime == nil || endTime! > Date()
    }
    
    var timeUntilStart: TimeInterval? {
        let now = Date()
        return startTime > now ? startTime.timeIntervalSince(now) : nil
    }
    
    var timeSinceEnd: TimeInterval? {
        guard let endTime = endTime, endTime <= Date() else { return nil }
        return Date().timeIntervalSince(endTime)
    }
    
    var temporalSignificance: Double {
        let recencyFactor: Double
        if let timeSince = timeSinceEnd {
            recencyFactor = max(0.1, 1.0 - (timeSince / (365 * 24 * 3600))) // 1 year decay
        } else {
            recencyFactor = 1.0 // Ongoing or future events
        }
        
        let participantFactor = min(1.0 + (Double(participants.count) * 0.1), 2.0)
        let outcomeFactor = min(1.0 + (Double(outcomes.count) * 0.1), 1.5)
        
        return importance * confidence * recencyFactor * participantFactor * outcomeFactor / 3.0
    }
}

enum EventType: String, Codable, CaseIterable {
    case general = "general"
    case meeting = "meeting"
    case milestone = "milestone"
    case decision = "decision"
    case learning = "learning"
    case creation = "creation"
    case communication = "communication"
    case problem = "problem"
    case resolution = "resolution"
    case insight = "insight"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .meeting: return "Meeting"
        case .milestone: return "Milestone"
        case .decision: return "Decision"
        case .learning: return "Learning"
        case .creation: return "Creation"
        case .communication: return "Communication"
        case .problem: return "Problem"
        case .resolution: return "Resolution"
        case .insight: return "Insight"
        }
    }
    
    var defaultImportance: Double {
        switch self {
        case .general: return 0.3
        case .meeting: return 0.4
        case .milestone: return 0.8
        case .decision: return 0.9
        case .learning: return 0.7
        case .creation: return 0.8
        case .communication: return 0.5
        case .problem: return 0.6
        case .resolution: return 0.7
        case .insight: return 0.9
        }
    }
}

enum TemporalRelationship: String, Codable, CaseIterable {
    case before = "before"
    case after = "after"
    case during = "during"
    case overlaps = "overlaps"
    case precedes = "precedes"
    case follows = "follows"
    case causes = "causes"
    case enables = "enables"
    case prevents = "prevents"
    
    var displayName: String {
        return rawValue.capitalized
    }
}