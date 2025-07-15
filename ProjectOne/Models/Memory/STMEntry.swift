//
//  STMEntry.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 19.0, macOS 16.0, tvOS 19.0, watchOS 12.0, *)
@Model
public final class STMEntry {
    public var id: UUID
    var content: String
    var timestamp: Date
    var memoryType: MemoryType
    var importance: Double
    var accessCount: Int
    var lastAccessed: Date
    var decayFactor: Double
    var consolidationScore: Double
    var sourceNoteId: UUID?
    var relatedEntities: [UUID]
    var emotionalWeight: Double
    var contextTags: [String]
    
    init(
        content: String,
        memoryType: MemoryType = .episodic,
        importance: Double = 0.5,
        sourceNoteId: UUID? = nil,
        relatedEntities: [UUID] = [],
        emotionalWeight: Double = 0.0,
        contextTags: [String] = []
    ) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.memoryType = memoryType
        self.importance = importance
        self.accessCount = 0
        self.lastAccessed = Date()
        self.decayFactor = 1.0
        self.consolidationScore = 0.0
        self.sourceNoteId = sourceNoteId
        self.relatedEntities = relatedEntities
        self.emotionalWeight = emotionalWeight
        self.contextTags = contextTags
    }
    
    // MARK: - Memory Decay
    
    func updateDecay() {
        let timeSinceAccess = Date().timeIntervalSince(lastAccessed)
        let hoursSinceAccess = timeSinceAccess / 3600
        
        // Exponential decay based on memory type
        let baseDecayRate = memoryType.decayRate
        decayFactor = exp(-Double(baseDecayRate * hoursSinceAccess))
        
        // Adjust for importance and emotional weight
        let stabilityFactor = (importance + emotionalWeight) / 2.0
        decayFactor = max(decayFactor * (1.0 + stabilityFactor), 0.1)
    }
    
    func access() {
        accessCount += 1
        lastAccessed = Date()
        
        // Increase importance based on repeated access
        importance = min(importance + 0.1, 1.0)
        
        updateDecay()
    }
    
    var currentStrength: Double {
        updateDecay()
        return decayFactor * importance
    }
    
    var shouldConsolidate: Bool {
        return consolidationScore > 0.7 && currentStrength > 0.5
    }
}

enum MemoryType: String, Codable, CaseIterable {
    case episodic = "episodic"
    case semantic = "semantic"
    case procedural = "procedural"
    case working = "working"
    
    var decayRate: Double {
        switch self {
        case .episodic: return 0.1
        case .semantic: return 0.05
        case .procedural: return 0.02
        case .working: return 0.5
        }
    }
    
    var displayName: String {
        switch self {
        case .episodic: return "Episodic"
        case .semantic: return "Semantic"
        case .procedural: return "Procedural"
        case .working: return "Working"
        }
    }
}