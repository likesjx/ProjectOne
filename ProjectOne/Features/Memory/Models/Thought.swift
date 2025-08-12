import Foundation
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class Thought {
    @Attribute(.unique) public var id: UUID
    public var timestamp: Date
    
    // Core content with context preservation
    public var content: String                    // The actual thought content
    public var contextBefore: String?            // Preceding context for understanding
    public var contextAfter: String?             // Following context for understanding
    public var sourceRange: Range<String.Index>? // Original position in source text (stored as String indices)
    
    // LLM-generated tags instead of summary
    public var tags: [String] = []               // Specific tags relevant to this thought
    public var primaryTag: String?               // Most relevant tag for this thought
    
    // Thought categorization
    public var thoughtType: ThoughtType = .general
    public var importance: ThoughtImportance = .medium
    public var completeness: ThoughtCompleteness = .complete
    
    // Relationship to parent note
    @Relationship(deleteRule: .cascade, inverse: \ProcessedNote.thoughts)
    public var parentNote: ProcessedNote?
    
    // Sequence information for maintaining order
    public var sequenceIndex: Int = 0            // Order within the parent note
    
    // Processing metadata
    public var extractionMethod: String?         // How this thought was extracted
    public var extractionConfidence: Double = 1.0
    public var processingTimestamp: Date?
    
    // Vector embedding for this specific thought
    public var embeddingData: Data?
    public var embeddingModelVersion: String?
    public var embeddingGeneratedAt: Date?
    
    public init(
        content: String,
        contextBefore: String? = nil,
        contextAfter: String? = nil,
        sequenceIndex: Int = 0,
        thoughtType: ThoughtType = .general,
        parentNote: ProcessedNote? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.content = content
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.sequenceIndex = sequenceIndex
        self.thoughtType = thoughtType
        self.parentNote = parentNote
        self.processingTimestamp = Date()
    }
    
    // MARK: - Context Methods
    
    /// Get the full context for this thought (before + content + after)
    public var fullContext: String {
        var result = ""
        
        if let before = contextBefore, !before.isEmpty {
            result += before + " "
        }
        
        result += content
        
        if let after = contextAfter, !after.isEmpty {
            result += " " + after
        }
        
        return result
    }
    
    /// Get content suitable for LLM processing (with context)
    public var contentForLLM: String {
        return fullContext
    }
    
    /// Get content for embedding generation
    public var contentForEmbedding: String {
        let baseContent = content
        let tagContent = tags.isEmpty ? "" : " " + tags.joined(separator: " ")
        let typeContent = " " + thoughtType.rawValue
        return baseContent + tagContent + typeContent
    }
    
    // MARK: - Tag Management
    
    /// Add a tag if it doesn't already exist
    public func addTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanTag.isEmpty && !tags.contains(cleanTag) {
            tags.append(cleanTag)
        }
    }
    
    /// Set tags from an array, filtering duplicates
    public func setTags(_ newTags: [String]) {
        tags = Array(Set(newTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }))
            .filter { !$0.isEmpty }
            .sorted()
    }
    
    /// Set the primary tag (most relevant)
    public func setPrimaryTag(_ tag: String) {
        let cleanTag = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanTag.isEmpty {
            primaryTag = cleanTag
            addTag(cleanTag) // Ensure it's also in the tags array
        }
    }
    
    // MARK: - Embedding Management
    
    /// Check if the thought has a valid embedding
    public var hasEmbedding: Bool {
        return embeddingData != nil && embeddingModelVersion != nil
    }
    
    /// Set the embedding for this thought
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
        
        return false
    }
}

// MARK: - Supporting Enums

/// Type of thought content
public enum ThoughtType: String, CaseIterable, Codable {
    case general = "general"                     // General thoughts or observations
    case idea = "idea"                          // Creative ideas or concepts
    case task = "task"                          // Action items or tasks
    case question = "question"                  // Questions or uncertainties
    case insight = "insight"                    // Key insights or realizations
    case memory = "memory"                      // Memories or recollections
    case plan = "plan"                          // Plans or strategies
    case reflection = "reflection"              // Reflective thoughts
    case fact = "fact"                          // Factual information
    case opinion = "opinion"                    // Personal opinions or views
    case decision = "decision"                  // Decisions made
    case goal = "goal"                          // Goals or objectives
    
    public var displayName: String {
        switch self {
        case .general: return "General"
        case .idea: return "Idea"
        case .task: return "Task"
        case .question: return "Question"
        case .insight: return "Insight"
        case .memory: return "Memory"
        case .plan: return "Plan"
        case .reflection: return "Reflection"
        case .fact: return "Fact"
        case .opinion: return "Opinion"
        case .decision: return "Decision"
        case .goal: return "Goal"
        }
    }
    
    public var emoji: String {
        switch self {
        case .general: return "💭"
        case .idea: return "💡"
        case .task: return "✅"
        case .question: return "❓"
        case .insight: return "🧠"
        case .memory: return "📖"
        case .plan: return "📋"
        case .reflection: return "🤔"
        case .fact: return "📊"
        case .opinion: return "💬"
        case .decision: return "⚖️"
        case .goal: return "🎯"
        }
    }
}

/// Importance level of the thought
public enum ThoughtImportance: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

/// Completeness of the thought
public enum ThoughtCompleteness: String, CaseIterable, Codable {
    case fragment = "fragment"                   // Incomplete thought or fragment
    case partial = "partial"                     // Partially complete thought
    case complete = "complete"                   // Complete thought
    case expanded = "expanded"                   // Thought with additional context/details
    
    public var displayName: String {
        switch self {
        case .fragment: return "Fragment"
        case .partial: return "Partial"
        case .complete: return "Complete"
        case .expanded: return "Expanded"
        }
    }
}