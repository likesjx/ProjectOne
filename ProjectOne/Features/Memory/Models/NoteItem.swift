
//
//  NoteItem.swift
//  ProjectOne
//
//  Created by Gemini on 7/13/2025.
//

import Foundation
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class NoteItem {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var markdownContent: String
    
    // Contextual Metadata
    var sourceApp: String?
    var sourceURL: String?
    
    // Memory Processing Status
    var isProcessedByMemoryAgent: Bool = false
    var processingDate: Date?
    var memoryProcessingStatus: MemoryProcessingStatus = MemoryProcessingStatus.pending
    var memoryDecision: MemoryDecision?
    var memoryDecisionConfidence: Double = 0.0
    var memoryPromptTemplateUsed: String?
    var memoryModelUsed: String?
    var memoryProcessingTime: TimeInterval = 0.0
    var memoryProcessingError: String?
    var memoryEntitiesExtracted: Int = 0
    var memoryRelationshipsCreated: Int = 0
    
    init(
        timestamp: Date,
        markdownContent: String,
        sourceApp: String? = nil,
        sourceURL: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.markdownContent = markdownContent
        self.sourceApp = sourceApp
        self.sourceURL = sourceURL
    }
    
    /// Update memory processing results
    func updateMemoryProcessing(
        status: MemoryProcessingStatus,
        decision: MemoryDecision? = nil,
        confidence: Double = 0.0,
        templateUsed: String? = nil,
        modelUsed: String? = nil,
        processingTime: TimeInterval = 0.0,
        error: String? = nil,
        entitiesExtracted: Int = 0,
        relationshipsCreated: Int = 0
    ) {
        self.memoryProcessingStatus = status
        self.memoryDecision = decision
        self.memoryDecisionConfidence = confidence
        self.memoryPromptTemplateUsed = templateUsed
        self.memoryModelUsed = modelUsed
        self.memoryProcessingTime = processingTime
        self.memoryProcessingError = error
        self.memoryEntitiesExtracted = entitiesExtracted
        self.memoryRelationshipsCreated = relationshipsCreated
        
        if status == .completed {
            self.isProcessedByMemoryAgent = true
            self.processingDate = Date()
        }
    }
}

// MARK: - Memory Processing Types

/// Status of memory processing for notes and recordings
public enum MemoryProcessingStatus: String, CaseIterable, Codable {
    case pending = "pending"                  // Not yet processed
    case processing = "processing"            // Currently being processed
    case completed = "completed"              // Successfully processed
    case failed = "failed"                   // Processing failed
    case skipped = "skipped"                 // Skipped due to filters or rules
    case retrying = "retrying"               // Retrying after failure
    
    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .skipped: return "Skipped"
        case .retrying: return "Retrying"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "gear"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "minus.circle"
        case .retrying: return "arrow.clockwise"
        }
    }
}

/// Memory decision made by the AI system
public enum MemoryDecision: String, CaseIterable, Codable {
    case shortTermMemory = "stm"              // Store as Short Term Memory
    case longTermMemory = "ltm"               // Store as Long Term Memory
    case episodicMemory = "episodic"          // Store as Episodic Memory
    case entityExtraction = "entities"       // Extract entities only
    case ignore = "ignore"                   // Don't store in memory
    
    public var displayName: String {
        switch self {
        case .shortTermMemory: return "Short Term Memory"
        case .longTermMemory: return "Long Term Memory"
        case .episodicMemory: return "Episodic Memory"
        case .entityExtraction: return "Entity Extraction"
        case .ignore: return "Ignored"
        }
    }
    
    public var description: String {
        switch self {
        case .shortTermMemory: return "Stored temporarily for recent context"
        case .longTermMemory: return "Stored permanently as important knowledge"
        case .episodicMemory: return "Stored as personal experience or event"
        case .entityExtraction: return "Entities extracted, content not stored"
        case .ignore: return "Content filtered out or deemed unimportant"
        }
    }
    
    public var color: String {
        switch self {
        case .shortTermMemory: return "blue"
        case .longTermMemory: return "green"
        case .episodicMemory: return "purple"
        case .entityExtraction: return "orange"
        case .ignore: return "gray"
        }
    }
}
