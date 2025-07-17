//
//  LTMEntry.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@Model
public final class LTMEntry {
    public var id: UUID
    var content: String
    var summary: String
    var timestamp: Date
    var category: LTMCategory
    var importance: Double
    var accessCount: Int
    var lastAccessed: Date
    var consolidationDate: Date
    var sourceSTMIds: [UUID]
    var relatedEntities: [UUID]
    var relatedConcepts: [String]
    var emotionalWeight: Double
    var strengthScore: Double
    var retrievalCues: [String]
    var crossReferences: [UUID]
    var memoryCluster: String?
    var consolidationScore: Double
    var evidenceCount: Int
    
    // SwiftData relationships
    @Relationship(deleteRule: .nullify)
    var relatedNotes: [ProcessedNote] = []
    
    init(
        content: String,
        category: LTMCategory,
        importance: Double = 0.5,
        sourceSTMEntry: STMEntry? = nil,
        sourceSTMIds: [UUID] = [],
        relatedEntities: [UUID] = [],
        relatedConcepts: [String] = [],
        emotionalWeight: Double = 0.0,
        retrievalCues: [String] = [],
        memoryCluster: String? = nil
    ) {
        self.id = UUID()
        self.content = content
        self.summary = ""
        self.timestamp = Date()
        self.category = category
        self.importance = importance
        self.accessCount = 0
        self.lastAccessed = Date()
        self.consolidationDate = Date()
        self.sourceSTMIds = sourceSTMEntry != nil ? [sourceSTMEntry!.id] : sourceSTMIds
        self.relatedEntities = relatedEntities
        self.relatedConcepts = relatedConcepts
        self.emotionalWeight = emotionalWeight
        self.strengthScore = importance
        self.retrievalCues = retrievalCues
        self.crossReferences = []
        self.memoryCluster = memoryCluster
        self.consolidationScore = 0.0
        self.evidenceCount = 0
    }
    
    // MARK: - Memory Strengthening
    
    func access() {
        accessCount += 1
        lastAccessed = Date()
        
        // Strengthen memory with each access
        strengthScore = min(strengthScore + 0.05, 1.0)
        importance = min(importance + 0.02, 1.0)
    }
    
    func addCrossReference(_ ltmEntryId: UUID) {
        if !crossReferences.contains(ltmEntryId) {
            crossReferences.append(ltmEntryId)
            strengthScore = min(strengthScore + 0.1, 1.0)
        }
    }
    
    func addRetrievalCue(_ cue: String) {
        if !retrievalCues.contains(cue) {
            retrievalCues.append(cue)
        }
    }
    
    var isWellEstablished: Bool {
        return strengthScore > 0.8 && accessCount > 5
    }
    
    var memoryAge: TimeInterval {
        return Date().timeIntervalSince(consolidationDate)
    }
}

enum LTMCategory: String, Codable, CaseIterable {
    case factual = "factual"
    case conceptual = "conceptual"
    case experiential = "experiential"
    case relational = "relational"
    case procedural = "procedural"
    case autobiographical = "autobiographical"
    case episodic = "episodic"
    case semantic = "semantic"
    case personal = "personal"
    case professional = "professional"
    case health = "health"
    case goals = "goals"
    case relationships = "relationships"
    case patterns = "patterns"
    
    var displayName: String {
        switch self {
        case .factual: return "Factual"
        case .conceptual: return "Conceptual"
        case .experiential: return "Experiential"
        case .relational: return "Relational"
        case .procedural: return "Procedural"
        case .autobiographical: return "Autobiographical"
        case .episodic: return "Episodic"
        case .semantic: return "Semantic"
        case .personal: return "Personal"
        case .professional: return "Professional"
        case .health: return "Health"
        case .goals: return "Goals"
        case .relationships: return "Relationships"
        case .patterns: return "Patterns"
        }
    }
    
    var consolidationPriority: Double {
        switch self {
        case .factual: return 0.6
        case .conceptual: return 0.8
        case .experiential: return 0.9
        case .relational: return 0.7
        case .procedural: return 0.5
        case .autobiographical: return 0.95
        case .episodic: return 0.8
        case .semantic: return 0.7
        case .personal: return 0.6
        case .professional: return 0.6
        case .health: return 0.7
        case .goals: return 0.8
        case .relationships: return 0.6
        case .patterns: return 0.7
        }
    }
}