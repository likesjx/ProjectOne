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

@available(iOS 17.0, macOS 16.0, tvOS 19.0, watchOS 12.0, *)
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
    }
    
    // Computed property for vector embedding
    var embedding: [Float]? {
        get {
            guard let data = embeddingData else { return nil }
            return data.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
        }
        set {
            guard let newValue = newValue else {
                embeddingData = nil
                return
            }
            embeddingData = Data(bytes: newValue, count: newValue.count * MemoryLayout<Float>.size)
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