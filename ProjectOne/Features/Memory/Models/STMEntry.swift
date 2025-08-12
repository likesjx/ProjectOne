//
//  STMEntry.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class STMEntry {
    public var id: UUID
    var content: String
    var timestamp: Date
    internal var memoryTypeRawValue: String = "episodic"
    
    var memoryType: MemoryType {
        get { MemoryType(rawValue: memoryTypeRawValue) ?? .episodic }
        set { memoryTypeRawValue = newValue.rawValue }
    }
    var importance: Double
    var accessCount: Int
    var lastAccessed: Date
    var decayFactor: Double
    var consolidationScore: Double
    var sourceNoteId: UUID?
    @Attribute(.transformable(by: "NSSecureUnarchiveFromData"))
    var relatedEntities: [UUID]
    var emotionalWeight: Double
    var contextTags: [String]
    
    // MARK: - Embedding Fields
    
    /// Vector embedding for semantic similarity search
    var embedding: Data?
    
    /// Version identifier for the embedding model used
    public var embeddingModelVersion: String?
    
    /// Timestamp when the embedding was generated
    public var embeddingGeneratedAt: Date?
    
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
        self.memoryTypeRawValue = memoryType.rawValue
        self.importance = importance
        self.accessCount = 0
        self.lastAccessed = Date()
        self.decayFactor = 1.0
        self.consolidationScore = 0.0
        self.sourceNoteId = sourceNoteId
        self.relatedEntities = relatedEntities
        self.emotionalWeight = emotionalWeight
        self.contextTags = contextTags
        
        // Initialize embedding fields
        self.embedding = nil
        self.embeddingModelVersion = nil
        self.embeddingGeneratedAt = nil
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
    public func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval = 7 * 24 * 3600) -> Bool {
        guard hasEmbedding else { return true }
        
        // Check model version
        if embeddingModelVersion != currentModelVersion {
            return true
        }
        
        // Check age
        if let generatedAt = embeddingGeneratedAt,
           Date().timeIntervalSince(generatedAt) > maxAge {
            return true
        }
        
        return false
    }
    
    /// Get combined text for embedding generation
    public var embeddingText: String {
        return content
    }
}

enum MemoryType: String, Codable, CaseIterable, Sendable {
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