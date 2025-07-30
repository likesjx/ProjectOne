import Foundation
import SwiftData

enum NoteSourceType: String, CaseIterable, Codable {
    case audio = "audio"
    case text = "text"
    case health = "health"
    case external = "external"
}

enum ConsolidationLevel: String, CaseIterable, Codable {
    case volatile = "volatile"          // Fresh, unprocessed
    case consolidating = "consolidating" // Being processed
    case stable = "stable"              // Fully integrated
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class ProcessedNote {
    public var id: UUID
    var timestamp: Date
    var sourceType: NoteSourceType
    var originalText: String
    var audioURL: URL?
    
    // Gemma 3n enrichment results
    var summary: String
    var topics: [String]
    var sentiment: String?
    
    // Vector embedding for semantic search (stored as Data for SwiftData compatibility)
    var embeddingData: Data?
    
    // Embedding metadata
    var embeddingModelVersion: String?
    var embeddingGeneratedAt: Date?
    
    // Memory system integration
    var accessFrequency: Int
    var lastAccessed: Date
    var consolidationLevel: ConsolidationLevel
    
    // SwiftData relationships to KG entities
    @Relationship(deleteRule: .nullify)
    var entities: [Entity] = []
    
    @Relationship(deleteRule: .nullify)  
    var relationships: [Relationship] = []
    
    // Temporary storage for extracted data before KG integration
    var extractedEntityNames: [String] // Will be processed into entities
    var extractedRelationships: [String] // Will be processed into relationships
    var extractedKeywords: [String] // Extracted keywords for search
    
    // Computed properties for backward compatibility
    var extractedEntities: [Entity] {
        return entities
    }
    
    init(
        sourceType: NoteSourceType,
        originalText: String,
        audioURL: URL? = nil,
        summary: String = "",
        topics: [String] = [],
        sentiment: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.sourceType = sourceType
        self.originalText = originalText
        self.audioURL = audioURL
        self.summary = summary
        self.topics = topics
        self.sentiment = sentiment
        self.accessFrequency = 0
        self.lastAccessed = Date()
        self.consolidationLevel = .volatile
        self.extractedEntityNames = []
        self.extractedRelationships = []
        self.extractedKeywords = []
        self.embeddingModelVersion = nil
        self.embeddingGeneratedAt = nil
    }
    
    // MARK: - Embedding Management
    
    /// Check if the note has a valid embedding
    var hasEmbedding: Bool {
        return embeddingData != nil && embeddingModelVersion != nil
    }
    
    /// Set the embedding for this note
    func setEmbedding(_ embeddingVector: [Float], modelVersion: String) {
        self.embeddingData = EmbeddingUtils.embeddingToData(embeddingVector)
        self.embeddingModelVersion = modelVersion
        self.embeddingGeneratedAt = Date()
    }
    
    /// Get the embedding as a float array for calculations
    func getEmbedding() -> [Float]? {
        guard let data = embeddingData else { return nil }
        return EmbeddingUtils.dataToEmbedding(data)
    }
    
    /// Check if embedding needs regeneration
    func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval = 7 * 24 * 3600) -> Bool {
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
        
        // Check if content has been significantly updated
        if consolidationLevel == .volatile && lastAccessed > (embeddingGeneratedAt ?? Date.distantPast) {
            return true
        }
        
        return false
    }
    
    /// Computed property for backward compatibility
    var embedding: [Float]? {
        get {
            return getEmbedding()
        }
        set {
            guard let newValue = newValue else {
                embeddingData = nil
                embeddingModelVersion = nil
                embeddingGeneratedAt = nil
                return
            }
            // Note: This doesn't set model version, use setEmbedding() method instead
            embeddingData = EmbeddingUtils.embeddingToData(newValue)
        }
    }
    
    // Update access tracking for memory system
    func recordAccess() {
        accessFrequency += 1
        lastAccessed = Date()
    }
    
    // Update consolidation status
    func updateConsolidation(level: ConsolidationLevel) {
        consolidationLevel = level
    }
    
    // Check if note needs processing
    var needsProcessing: Bool {
        return summary.isEmpty || consolidationLevel == .volatile
    }
    
    // Get content for embedding generation
    var contentForEmbedding: String {
        let baseContent = originalText
        let enrichedContent = summary.isEmpty ? "" : " " + summary
        let topicContent = topics.isEmpty ? "" : " " + topics.joined(separator: " ")
        return baseContent + enrichedContent + topicContent
    }
}

// MARK: - Enrichment Data Structures

struct ExtractedEntity: Codable {
    let name: String
    let type: String
    let confidence: Double
    let mentions: [String] // Context where entity was mentioned
    
    init(name: String, type: String, confidence: Double = 1.0, mentions: [String] = []) {
        self.name = name
        self.type = type
        self.confidence = confidence
        self.mentions = mentions
    }
}

struct ExtractedRelationship: Codable {
    let subject: String
    let predicate: String
    let object: String
    let confidence: Double
    let context: String
    
    init(subject: String, predicate: String, object: String, confidence: Double = 1.0, context: String = "") {
        self.subject = subject
        self.predicate = predicate
        self.object = object
        self.confidence = confidence
        self.context = context
    }
}

// MARK: - Legacy Migration Support
// Legacy migration functionality removed - using SwiftData models directly