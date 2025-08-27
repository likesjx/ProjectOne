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
    // Store range as integers for SwiftData compatibility
    public var sourceRangeStart: Int?            // Start position in original text
    public var sourceRangeEnd: Int?              // End position in original text
    
    // LLM-generated tags instead of summary
    public var tags: [String] = []               // Specific tags relevant to this thought
    public var primaryTag: String?               // Most relevant tag for this thought
    
    // Thought categorization
    public var thoughtType: ThoughtType = ThoughtType.general
    public var importance: ThoughtImportance = ThoughtImportance.medium
    public var completeness: ThoughtCompleteness = ThoughtCompleteness.complete
    
    // Relationship to parent note
    @Relationship(deleteRule: .nullify)
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
    
    // Location and temporal context
    public var creationLatitude: Double?         // GPS latitude when thought was created
    public var creationLongitude: Double?        // GPS longitude when thought was created  
    public var creationLocationName: String?     // Human-readable location name
    public var creationLocationAccuracy: Double? // GPS accuracy in meters
    
    // Target/due temporal and location context
    public var targetDateTime: Date?             // When this thought should be acted upon or reviewed
    public var targetLatitude: Double?           // Target/relevant GPS latitude
    public var targetLongitude: Double?          // Target/relevant GPS longitude
    public var targetLocationName: String?       // Human-readable target location name
    public var targetLocationRadius: Double?     // Relevant radius around target location in meters
    
    public init(
        content: String,
        contextBefore: String? = nil,
        contextAfter: String? = nil,
        sequenceIndex: Int = 0,
        thoughtType: ThoughtType = ThoughtType.general,
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
    
    // MARK: - Location and Temporal Management
    
    /// Set the creation location for this thought
    public func setCreationLocation(latitude: Double, longitude: Double, locationName: String? = nil, accuracy: Double? = nil) {
        self.creationLatitude = latitude
        self.creationLongitude = longitude
        self.creationLocationName = locationName
        self.creationLocationAccuracy = accuracy
    }
    
    /// Set the target location for this thought
    public func setTargetLocation(latitude: Double, longitude: Double, locationName: String? = nil, radius: Double? = nil) {
        self.targetLatitude = latitude
        self.targetLongitude = longitude
        self.targetLocationName = locationName
        self.targetLocationRadius = radius
    }
    
    /// Check if thought has creation location data
    public var hasCreationLocation: Bool {
        return creationLatitude != nil && creationLongitude != nil
    }
    
    /// Check if thought has target location data
    public var hasTargetLocation: Bool {
        return targetLatitude != nil && targetLongitude != nil
    }
    
    /// Check if thought has a target date/time
    public var hasTargetDateTime: Bool {
        return targetDateTime != nil
    }
    
    /// Check if thought is overdue (target date has passed)
    public var isOverdue: Bool {
        guard let targetDate = targetDateTime else { return false }
        return Date() > targetDate
    }
    
    /// Check if thought is due soon (within specified hours)
    public func isDueSoon(withinHours hours: Double = 24.0) -> Bool {
        guard let targetDate = targetDateTime else { return false }
        let hoursUntilTarget = targetDate.timeIntervalSinceNow / 3600.0
        return hoursUntilTarget > 0 && hoursUntilTarget <= hours
    }
    
    /// Calculate distance from current location to creation location (in meters)
    public func distanceFromCreationLocation(currentLatitude: Double, currentLongitude: Double) -> Double? {
        guard let creationLat = creationLatitude, let creationLng = creationLongitude else { return nil }
        return haversineDistance(lat1: currentLatitude, lon1: currentLongitude, lat2: creationLat, lon2: creationLng)
    }
    
    /// Calculate distance from current location to target location (in meters)
    public func distanceFromTargetLocation(currentLatitude: Double, currentLongitude: Double) -> Double? {
        guard let targetLat = targetLatitude, let targetLng = targetLongitude else { return nil }
        return haversineDistance(lat1: currentLatitude, lon1: currentLongitude, lat2: targetLat, lon2: targetLng)
    }
    
    /// Check if current location is near target location
    public func isNearTargetLocation(currentLatitude: Double, currentLongitude: Double) -> Bool {
        guard let distance = distanceFromTargetLocation(currentLatitude: currentLatitude, currentLongitude: currentLongitude),
              let radius = targetLocationRadius else { return false }
        return distance <= radius
    }
    
    /// Haversine distance calculation between two GPS coordinates
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371000.0 // Earth's radius in meters
        
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        
        let lat1Rad = lat1 * .pi / 180.0
        let lat2Rad = lat2 * .pi / 180.0
        
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1Rad) * cos(lat2Rad) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
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