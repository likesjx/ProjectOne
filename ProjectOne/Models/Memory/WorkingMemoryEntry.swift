//
//  WorkingMemoryEntry.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@Model
final class WorkingMemoryEntry {
    var id: UUID
    var content: String
    var timestamp: Date
    var priority: WorkingMemoryPriority
    var contextId: UUID?
    var relatedSTMIds: [UUID]
    var relatedLTMIds: [UUID]
    var activeTask: String?
    var processingStage: ProcessingStage
    var attentionWeight: Double
    var retentionDuration: TimeInterval
    var lastUpdated: Date
    
    init(
        content: String,
        priority: WorkingMemoryPriority = .medium,
        contextId: UUID? = nil,
        activeTask: String? = nil,
        attentionWeight: Double = 0.5,
        retentionDuration: TimeInterval = 3600 // 1 hour default
    ) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.priority = priority
        self.contextId = contextId
        self.relatedSTMIds = []
        self.relatedLTMIds = []
        self.activeTask = activeTask
        self.processingStage = .incoming
        self.attentionWeight = attentionWeight
        self.retentionDuration = retentionDuration
        self.lastUpdated = Date()
    }
    
    // MARK: - Working Memory Management
    
    func updateAttention(_ weight: Double) {
        attentionWeight = max(0.0, min(1.0, weight))
        lastUpdated = Date()
    }
    
    func linkSTMEntry(_ stmId: UUID) {
        if !relatedSTMIds.contains(stmId) {
            relatedSTMIds.append(stmId)
            lastUpdated = Date()
        }
    }
    
    func linkLTMEntry(_ ltmId: UUID) {
        if !relatedLTMIds.contains(ltmId) {
            relatedLTMIds.append(ltmId)
            lastUpdated = Date()
        }
    }
    
    func advanceProcessingStage() {
        switch processingStage {
        case .incoming:
            processingStage = .active
        case .active:
            processingStage = .consolidating
        case .consolidating:
            processingStage = .completed
        case .completed:
            break
        }
        lastUpdated = Date()
    }
    
    var isExpired: Bool {
        let elapsed = Date().timeIntervalSince(timestamp)
        return elapsed > retentionDuration
    }
    
    var shouldRetain: Bool {
        return attentionWeight > 0.6 && !isExpired
    }
    
    var effectivePriority: Double {
        let timeFactor = max(0.1, 1.0 - (Date().timeIntervalSince(timestamp) / retentionDuration))
        return priority.rawValue * attentionWeight * timeFactor
    }
}

enum WorkingMemoryPriority: Double, Codable, CaseIterable {
    case low = 0.3
    case medium = 0.6
    case high = 0.9
    case critical = 1.0
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

enum ProcessingStage: String, Codable, CaseIterable {
    case incoming = "incoming"
    case active = "active"
    case consolidating = "consolidating"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .incoming: return "Incoming"
        case .active: return "Active"
        case .consolidating: return "Consolidating"
        case .completed: return "Completed"
        }
    }
}