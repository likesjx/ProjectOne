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
    var topics: [String] = []
    var sentiment: String?
    
    // Vector embedding for semantic search (stored as Data for SwiftData compatibility)
    var embeddingData: Data?
    
    // Embedding metadata
    public var embeddingModelVersion: String?
    public var embeddingGeneratedAt: Date?
    
    // Memory system integration
    var accessFrequency: Int
    var lastAccessed: Date
    var consolidationLevel: ConsolidationLevel
    
    // Metadata for additional properties
    var metadata: [String: String]?
    
    // SwiftData relationships to KG entities
    @Relationship(deleteRule: .nullify)
    var entities: [Entity] = []
    
    @Relationship(deleteRule: .nullify)  
    var knowledgeRelationships: [Relationship] = []
    
    // Granular thoughts extracted from the note content
    @Relationship(deleteRule: .cascade, inverse: \Thought.parentNote)
    var thoughts: [Thought] = []
    
    // Temporary thought storage as encoded data until Thought model is available
    var thoughtsData: Data?
    
    // Temporary storage for extracted data before KG integration
    var extractedEntityNames: [String] = [] // Will be processed into entities
    var extractedRelationships: [String] = [] // Will be processed into relationships
    var extractedKeywords: [String] = [] // Extracted keywords for search
    
    // Processing status tracking
    var processingStartedAt: Date?
    var processingCompletedAt: Date?
    var processingErrors: [String] = [] // Store any processing errors
    
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
        self.processingStartedAt = nil
        self.processingCompletedAt = nil
        self.processingErrors = []
        self.embeddingModelVersion = nil
        self.embeddingGeneratedAt = nil
    }
    
    // MARK: - Embedding Management
    
    /// Check if the note has a valid embedding
    public var hasEmbedding: Bool {
        return embeddingData != nil && embeddingModelVersion != nil
    }
    
    /// Set the embedding for this note
    public func setEmbedding(_ embeddingVector: [Float], modelVersion: String) {
        self.embeddingData = EmbeddingUtils.embeddingToData(embeddingVector)
        self.embeddingModelVersion = modelVersion
        self.embeddingGeneratedAt = Date()
    }
    
    /// Get the embedding as a float array for calculations
    public func getEmbedding() -> [Float]? {
        guard let data = embeddingData else { return nil }
        return EmbeddingUtils.dataToEmbedding(data)
    }
    
    /// Check if embedding needs regeneration
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
    public var contentForEmbedding: String {
        let baseContent = originalText
        let enrichedContent = summary.isEmpty ? "" : " " + summary
        let topicContent = topics.isEmpty ? "" : " " + topics.joined(separator: " ")
        return baseContent + enrichedContent + topicContent
    }
    
    // MARK: - Processing Status Tracking
    
    /// Mark processing as started
    public func startProcessing() {
        processingStartedAt = Date()
        processingCompletedAt = nil
        processingErrors = []
        consolidationLevel = .consolidating
    }
    
    /// Mark processing as completed
    public func completeProcessing() {
        processingCompletedAt = Date()
        consolidationLevel = .stable
    }
    
    /// Add a processing error
    public func addProcessingError(_ error: String) {
        processingErrors.append(error)
    }
    
    /// Check if currently being processed
    public var isBeingProcessed: Bool {
        return processingStartedAt != nil && processingCompletedAt == nil
    }
    
    /// Check if processing completed successfully
    public var processingCompletedSuccessfully: Bool {
        return processingCompletedAt != nil && processingErrors.isEmpty
    }
    
    /// Get processing duration
    public var processingDuration: TimeInterval? {
        guard let startTime = processingStartedAt else { return nil }
        let endTime = processingCompletedAt ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Get processing status description
    public var processingStatusDescription: String {
        if isBeingProcessed {
            return "Processing in progress..."
        } else if processingCompletedSuccessfully {
            return "Processing completed successfully"
        } else if !processingErrors.isEmpty {
            return "Processing completed with errors"
        } else if processingStartedAt == nil {
            return "Not processed"
        } else {
            return "Processing status unknown"
        }
    }
    
    // MARK: - Thought Management (Temporary Implementation)
    
    // TODO: Replace with proper Thought relationship when Xcode project is updated
    
    /// Temporary thought data structure for storage
    private struct TempThoughtData: Codable {
        let content: String
        let contextBefore: String?
        let contextAfter: String?
        let tags: [String]
        let primaryTag: String?
        let thoughtType: String
        let importance: String
        let sequenceIndex: Int
    }
    
    /// Add a thought summary to this note (temporary implementation)
    public func addThoughtSummary(content: String, tags: [String], type: String, importance: String) {
        var tempThoughts = getTemporaryThoughts()
        
        let tempThought = TempThoughtData(
            content: content,
            contextBefore: nil,
            contextAfter: nil,
            tags: tags,
            primaryTag: tags.first,
            thoughtType: type,
            importance: importance,
            sequenceIndex: tempThoughts.count
        )
        
        tempThoughts.append(tempThought)
        
        do {
            thoughtsData = try JSONEncoder().encode(tempThoughts)
        } catch {
            print("Failed to encode thoughts data: \(error)")
        }
    }
    
    /// Get temporary thoughts from storage
    private func getTemporaryThoughts() -> [TempThoughtData] {
        guard let data = thoughtsData else { return [] }
        
        do {
            return try JSONDecoder().decode([TempThoughtData].self, from: data)
        } catch {
            print("Failed to decode thoughts data: \(error)")
            return []
        }
    }
    
    /// Get all unique tags from all thoughts (temporary implementation)
    public var allThoughtTags: [String] {
        let tempThoughts = getTemporaryThoughts()
        let allTags = tempThoughts.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    /// Check if the note has been processed into thoughts (temporary implementation)
    public var hasThoughts: Bool {
        let tempThoughts = getTemporaryThoughts()
        return !tempThoughts.isEmpty
    }
    
    /// Get thought count (temporary implementation)
    public var thoughtCount: Int {
        return getTemporaryThoughts().count
    }
    
    /// Get content for embedding that includes thought summaries (temporary implementation)
    public var contentForEmbeddingWithThoughts: String {
        let baseContent = self.contentForEmbedding
        let tempThoughts = getTemporaryThoughts()
        
        if tempThoughts.isEmpty {
            return baseContent
        }
        
        let thoughtSummary = tempThoughts.map { thought in
            "\(thought.thoughtType): \(thought.content)"
        }.joined(separator: " | ")
        
        return baseContent + " [Thoughts: " + thoughtSummary + "]"
    }
    
    // MARK: - Proper Thought Relationship Methods (for when Thought model is available)
    
    /// Add a thought to this note
    public func addThought(_ thought: Thought) {
        if !thoughts.contains(where: { $0.id == thought.id }) {
            thoughts.append(thought)
            thought.parentNote = self
        }
    }
    
    /// Remove a thought from this note
    public func removeThought(_ thought: Thought) {
        thoughts.removeAll { $0.id == thought.id }
        thought.parentNote = nil
    }
    
    /// Get thoughts ordered by sequence index
    public var orderedThoughts: [Thought] {
        return thoughts.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }
    
    /// Get all unique tags from all thoughts
    public var allThoughtTagsFromModel: [String] {
        let allTags = thoughts.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }
    
    /// Get thought count from model
    public var thoughtCountFromModel: Int {
        return thoughts.count
    }
    
    /// Check if note has thoughts from model
    public var hasThoughtsFromModel: Bool {
        return !thoughts.isEmpty
    }
    
    /// Get thoughts by type
    public func getThoughts(ofType type: ThoughtType) -> [Thought] {
        return thoughts.filter { $0.thoughtType == type }
    }
    
    /// Get thoughts by importance
    public func getThoughts(withImportance importance: ThoughtImportance) -> [Thought] {
        return thoughts.filter { $0.importance == importance }
    }
    
    /// Get high importance thoughts
    public var highImportanceThoughts: [Thought] {
        return thoughts.filter { $0.importance == .high || $0.importance == .critical }
    }
    
    /// Get content for embedding that includes proper thoughts
    public var contentForEmbeddingWithProperThoughts: String {
        let baseContent = self.contentForEmbedding
        
        if thoughts.isEmpty {
            return baseContent
        }
        
        let thoughtSummary = thoughts.map { thought in
            "\(thought.thoughtType.rawValue): \(thought.content)"
        }.joined(separator: " | ")
        
        return baseContent + " [Thoughts: " + thoughtSummary + "]"
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