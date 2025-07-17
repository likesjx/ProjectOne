import Foundation
import SwiftData

/// Represents a relationship between two entities in the knowledge graph
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class Relationship {
    public var id: UUID
    var timestamp: Date
    
    // Relationship structure (subject-predicate-object triple)
    var subjectEntityId: UUID
    var predicateType: PredicateType
    var objectEntityId: UUID
    
    // Relationship metadata
    var confidence: Double // Confidence in relationship extraction (0.0-1.0)
    var strength: Double // Strength of the relationship (0.0-1.0)
    var isValidated: Bool // Whether user has validated this relationship
    var extractionSource: String? // Source where relationship was extracted
    
    // Temporal information
    var isTemporallyBounded: Bool // Whether relationship has time constraints
    var startDate: Date? // When relationship began (if applicable)
    var endDate: Date? // When relationship ended (if applicable)
    var duration: TimeInterval? // Duration of relationship (if applicable)
    
    // Context and evidence
    var context: String? // Context in which relationship was mentioned
    var evidence: [String] // Text snippets that support this relationship
    var mentions: Int // Number of times this relationship was mentioned
    var lastMentioned: Date
    
    // Semantic information
    var importance: Double // Calculated importance of this relationship (0.0-1.0)
    var bidirectional: Bool // Whether relationship works in both directions
    var weight: Double // Graph weight for shortest path calculations
    
    init(subjectEntityId: UUID, predicateType: PredicateType, objectEntityId: UUID) {
        self.id = UUID()
        self.timestamp = Date()
        self.subjectEntityId = subjectEntityId
        self.predicateType = predicateType
        self.objectEntityId = objectEntityId
        self.confidence = 0.0
        self.strength = 0.0
        self.isValidated = false
        self.extractionSource = nil
        self.isTemporallyBounded = false
        self.startDate = nil
        self.endDate = nil
        self.duration = nil
        self.context = nil
        self.evidence = []
        self.mentions = 0
        self.lastMentioned = Date()
        self.importance = 0.0
        self.bidirectional = false
        self.weight = 1.0
    }
    
    // MARK: - Computed Properties
    
    /// Human-readable relationship description
    var description: String {
        return predicateType.description
    }
    
    /// Full relationship triple as string
    var tripleDescription: String {
        return "[Subject] \(predicateType.description) [Object]"
    }
    
    /// Freshness score based on last mention
    var freshness: Double {
        let daysSinceLastMention = Date().timeIntervalSince(lastMentioned) / 86400
        return max(0.0, 1.0 - (daysSinceLastMention / 30.0)) // Decays over 30 days
    }
    
    /// Efficiency score based on relationship strength and confidence
    var efficiency: Double {
        return (strength + confidence) / 2.0
    }
    
    /// Overall relationship score combining multiple factors
    var relationshipScore: Double {
        let mentionScore = min(1.0, Double(mentions) / 5.0) // Normalize mentions
        let confidenceScore = confidence
        let strengthScore = strength
        let freshnessScore = freshness
        let importanceScore = importance
        
        return (mentionScore + confidenceScore + strengthScore + freshnessScore + importanceScore) / 5.0
    }
    
    /// Visual properties for graph display
    var edgeWidth: Double {
        return 1.0 + (relationshipScore * 4.0) // Width based on relationship score
    }
    
    var edgeColor: String {
        return predicateType.color
    }
    
    /// Whether relationship is currently active
    var isActive: Bool {
        if !isTemporallyBounded {
            return true
        }
        
        let now = Date()
        
        if let start = startDate, start > now {
            return false // Hasn't started yet
        }
        
        if let end = endDate, end < now {
            return false // Has ended
        }
        
        return true
    }
}

// MARK: - Supporting Enums

enum PredicateType: String, CaseIterable, Codable {
    // Professional relationships
    case worksFor = "works_for"
    case manages = "manages"
    case collaboratesWith = "collaborates_with"
    case reportsTo = "reports_to"
    
    // Personal relationships
    case friendOf = "friend_of"
    case familyOf = "family_of"
    case mentorOf = "mentor_of"
    case studentOf = "student_of"
    
    // Activity relationships
    case participatesIn = "participates_in"
    case organizes = "organizes"
    case attends = "attends"
    case leads = "leads"
    
    // Conceptual relationships
    case relatedTo = "related_to"
    case partOf = "part_of"
    case hasProperty = "has_property"
    case causedBy = "caused_by"
    case influences = "influences"
    
    // Temporal relationships
    case happensBefore = "happens_before"
    case happensAfter = "happens_after"
    case happensDuring = "happens_during"
    case concurrent = "concurrent"
    
    // Spatial relationships
    case locatedAt = "located_at"
    case near = "near"
    case contains = "contains"
    case adjacentTo = "adjacent_to"
    
    // Ownership/possession
    case owns = "owns"
    case belongsTo = "belongs_to"
    case uses = "uses"
    case provides = "provides"
    
    // Generic relationships
    case associatedWith = "associated_with"
    case mentions = "mentions"
    case discusses = "discusses"
    case references = "references"
    
    var description: String {
        switch self {
        case .worksFor:
            return "works for"
        case .manages:
            return "manages"
        case .collaboratesWith:
            return "collaborates with"
        case .reportsTo:
            return "reports to"
        case .friendOf:
            return "friend of"
        case .familyOf:
            return "family of"
        case .mentorOf:
            return "mentor of"
        case .studentOf:
            return "student of"
        case .participatesIn:
            return "participates in"
        case .organizes:
            return "organizes"
        case .attends:
            return "attends"
        case .leads:
            return "leads"
        case .relatedTo:
            return "related to"
        case .partOf:
            return "part of"
        case .hasProperty:
            return "has property"
        case .causedBy:
            return "caused by"
        case .influences:
            return "influences"
        case .happensBefore:
            return "happens before"
        case .happensAfter:
            return "happens after"
        case .happensDuring:
            return "happens during"
        case .concurrent:
            return "concurrent with"
        case .locatedAt:
            return "located at"
        case .near:
            return "near"
        case .contains:
            return "contains"
        case .adjacentTo:
            return "adjacent to"
        case .owns:
            return "owns"
        case .belongsTo:
            return "belongs to"
        case .uses:
            return "uses"
        case .provides:
            return "provides"
        case .associatedWith:
            return "associated with"
        case .mentions:
            return "mentions"
        case .discusses:
            return "discusses"
        case .references:
            return "references"
        }
    }
    
    var color: String {
        switch self {
        case .worksFor, .manages, .reportsTo, .collaboratesWith:
            return "blue"
        case .friendOf, .familyOf, .mentorOf, .studentOf:
            return "pink"
        case .participatesIn, .organizes, .attends, .leads:
            return "green"
        case .relatedTo, .partOf, .hasProperty, .causedBy, .influences:
            return "orange"
        case .happensBefore, .happensAfter, .happensDuring, .concurrent:
            return "purple"
        case .locatedAt, .near, .contains, .adjacentTo:
            return "red"
        case .owns, .belongsTo, .uses, .provides:
            return "brown"
        case .associatedWith, .mentions, .discusses, .references:
            return "gray"
        }
    }
    
    var category: RelationshipCategory {
        switch self {
        case .worksFor, .manages, .reportsTo, .collaboratesWith:
            return .professional
        case .friendOf, .familyOf, .mentorOf, .studentOf:
            return .personal
        case .participatesIn, .organizes, .attends, .leads:
            return .activity
        case .relatedTo, .partOf, .hasProperty, .causedBy, .influences:
            return .conceptual
        case .happensBefore, .happensAfter, .happensDuring, .concurrent:
            return .temporal
        case .locatedAt, .near, .contains, .adjacentTo:
            return .spatial
        case .owns, .belongsTo, .uses, .provides:
            return .ownership
        case .associatedWith, .mentions, .discusses, .references:
            return .generic
        }
    }
    
    /// Whether this predicate typically implies a bidirectional relationship
    var isTypicallyBidirectional: Bool {
        switch self {
        case .friendOf, .familyOf, .collaboratesWith, .near, .adjacentTo, .concurrent:
            return true
        default:
            return false
        }
    }
}

enum RelationshipCategory: String, CaseIterable {
    case professional = "Professional"
    case personal = "Personal"
    case activity = "Activity"
    case conceptual = "Conceptual"
    case temporal = "Temporal"
    case spatial = "Spatial"
    case ownership = "Ownership"
    case generic = "Generic"
    
    var color: String {
        switch self {
        case .professional:
            return "blue"
        case .personal:
            return "pink"
        case .activity:
            return "green"
        case .conceptual:
            return "orange"
        case .temporal:
            return "purple"
        case .spatial:
            return "red"
        case .ownership:
            return "brown"
        case .generic:
            return "gray"
        }
    }
    
    var iconName: String {
        switch self {
        case .professional:
            return "briefcase"
        case .personal:
            return "heart"
        case .activity:
            return "figure.run"
        case .conceptual:
            return "brain"
        case .temporal:
            return "clock"
        case .spatial:
            return "location"
        case .ownership:
            return "person.crop.rectangle"
        case .generic:
            return "link"
        }
    }
}

// MARK: - Extensions

extension Relationship {
    /// Add evidence for this relationship
    func addEvidence(_ text: String) {
        if !evidence.contains(text) {
            evidence.append(text)
        }
    }
    
    /// Record a new mention of this relationship
    func recordMention() {
        mentions += 1
        lastMentioned = Date()
    }
    
    /// Set temporal bounds for the relationship
    func setTemporalBounds(start: Date?, end: Date?) {
        self.isTemporallyBounded = (start != nil || end != nil)
        self.startDate = start
        self.endDate = end
        
        if let start = start, let end = end {
            self.duration = end.timeIntervalSince(start)
        }
    }
    
    /// Check if relationship matches search query
    func matches(query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        
        // Check predicate description
        if description.lowercased().contains(lowercaseQuery) {
            return true
        }
        
        // Check context
        if let context = context, context.lowercased().contains(lowercaseQuery) {
            return true
        }
        
        // Check evidence
        if evidence.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
            return true
        }
        
        return false
    }
    
    /// Calculate relationship importance based on various factors
    func calculateImportance(totalEntities: Int, totalRelationships: Int) {
        let mentionWeight = min(1.0, Double(mentions) / 10.0)
        let confidenceWeight = confidence
        let strengthWeight = strength
        let freshnessWeight = freshness
        
        // Relationship rarity (inverse frequency)
        let rarityWeight = 1.0 - (Double(mentions) / Double(totalRelationships))
        
        self.importance = (mentionWeight + confidenceWeight + strengthWeight + freshnessWeight + rarityWeight) / 5.0
    }
    
    /// Generate suggestions for improving this relationship
    var improvementSuggestions: [String] {
        var suggestions: [String] = []
        
        if confidence < 0.7 {
            suggestions.append("Consider validating this relationship - low confidence score")
        }
        
        if strength < 0.5 {
            suggestions.append("Relationship strength is low - may need more evidence")
        }
        
        if evidence.isEmpty {
            suggestions.append("No evidence provided - add supporting text")
        }
        
        if mentions == 1 {
            suggestions.append("Relationship mentioned only once - may be incidental")
        }
        
        if freshness < 0.3 {
            suggestions.append("Relationship not mentioned recently - may be outdated")
        }
        
        if predicateType.isTypicallyBidirectional && !bidirectional {
            suggestions.append("Consider making this relationship bidirectional")
        }
        
        return suggestions
    }
}