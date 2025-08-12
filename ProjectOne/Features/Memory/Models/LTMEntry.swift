//
//  LTMEntry.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
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
    @Attribute(.transformable(by: "NSSecureUnarchiveFromData"))
    var sourceSTMIds: [UUID]
    @Attribute(.transformable(by: "NSSecureUnarchiveFromData"))
    var relatedEntities: [UUID]
    var relatedConcepts: [String]
    var emotionalWeight: Double
    var strengthScore: Double
    var retrievalCues: [String]
    @Attribute(.transformable(by: "NSSecureUnarchiveFromData"))
    var crossReferences: [UUID]
    var memoryCluster: String?
    var consolidationScore: Double
    var evidenceCount: Int
    
    // MARK: - Embedding Fields
    
    /// Vector embedding for semantic similarity search
    var embedding: Data?
    
    /// Version identifier for the embedding model used
    public var embeddingModelVersion: String?
    
    /// Timestamp when the embedding was generated
    public var embeddingGeneratedAt: Date?
    
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
        
        // Initialize embedding fields
        self.embedding = nil
        self.embeddingModelVersion = nil
        self.embeddingGeneratedAt = nil
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
    
    // MARK: - Embedding Management
    
    /// Check if the memory has a valid embedding
    public var hasEmbedding: Bool {
        return embedding != nil && embeddingModelVersion != nil
    }
    
    /// Set the embedding for this memory entry
    public func setEmbedding(_ embeddingVector: [Float], modelVersion: String) {
        self.embedding = EmbeddingUtils.embeddingToData(embeddingVector)
        self.embeddingModelVersion = modelVersion
        self.embeddingGeneratedAt = Date()
    }
    
    /// Get the embedding as a float array for calculations
    public func getEmbedding() -> [Float]? {
        guard let embeddingData = embedding else { return nil }
        return EmbeddingUtils.dataToEmbedding(embeddingData)
    }
    
    /// Check if embedding needs regeneration (model version changed or too old)
    public func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval = 30 * 24 * 3600) -> Bool {
        guard hasEmbedding else { return true }
        
        // Check model version
        if embeddingModelVersion != currentModelVersion {
            return true
        }
        
        // Check age (LTM embeddings can be older since content is more stable)
        if let generatedAt = embeddingGeneratedAt,
           Date().timeIntervalSince(generatedAt) > maxAge {
            return true
        }
        
        return false
    }
    
    /// Get combined text for embedding generation (content + summary)
    public var embeddingText: String {
        if summary.isEmpty {
            return content
        } else {
            return "\(summary). \(content)"
        }
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