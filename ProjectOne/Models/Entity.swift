import Foundation
import SwiftData

/// Represents a named entity in the knowledge graph (people, organizations, activities, concepts, locations)
@Model
final class Entity {
    var id: UUID
    var timestamp: Date
    
    // Entity identification
    var name: String
    var type: EntityType
    var aliases: [String] // Alternative names for this entity
    
    // Confidence and validation
    var confidence: Double // Confidence in entity extraction (0.0-1.0)
    var isValidated: Bool // Whether user has validated this entity
    var extractionSource: String? // Source where entity was first extracted
    
    // Knowledge graph connections
    var mentions: Int // Number of times mentioned across all notes
    var lastMentioned: Date
    var relationships: [UUID] // IDs of relationships this entity participates in
    
    // Entity attributes
    var attributes: [String: String] // Key-value pairs for additional entity info
    var entityDescription: String? // User-provided or AI-generated description
    var tags: [String] // User-assigned tags
    
    // Semantic information
    var semanticEmbedding: [Double]? // Vector embedding for semantic similarity
    var importance: Double // Calculated importance score (0.0-1.0)
    var salience: Double // How central this entity is to the knowledge graph
    
    init(name: String, type: EntityType) {
        self.id = UUID()
        self.timestamp = Date()
        self.name = name
        self.type = type
        self.aliases = []
        self.confidence = 0.0
        self.isValidated = false
        self.extractionSource = nil
        self.mentions = 0
        self.lastMentioned = Date()
        self.relationships = []
        self.attributes = [:]
        self.entityDescription = nil
        self.tags = []
        self.semanticEmbedding = nil
        self.importance = 0.0
        self.salience = 0.0
    }
    
    // MARK: - Computed Properties
    
    /// Display name including aliases
    var displayName: String {
        if aliases.isEmpty {
            return name
        } else {
            return "\(name) (\(aliases.joined(separator: ", ")))"
        }
    }
    
    /// Freshness score based on last mention
    var freshness: Double {
        let daysSinceLastMention = Date().timeIntervalSince(lastMentioned) / 86400
        return max(0.0, 1.0 - (daysSinceLastMention / 30.0)) // Decays over 30 days
    }
    
    /// Overall entity score combining multiple factors
    var entityScore: Double {
        let mentionScore = min(1.0, Double(mentions) / 10.0) // Normalize mentions
        let confidenceScore = confidence
        let freshnessScore = freshness
        let importanceScore = importance
        
        return (mentionScore + confidenceScore + freshnessScore + importanceScore) / 4.0
    }
    
    /// Visual representation properties for graph display
    var nodeSize: Double {
        return 20.0 + (entityScore * 30.0) // Size based on entity score
    }
    
    var nodeColor: String {
        return type.color
    }
}

// MARK: - Supporting Enums

enum EntityType: String, CaseIterable, Codable {
    case person = "Person"
    case organization = "Organization"
    case activity = "Activity"
    case concept = "Concept"
    case location = "Location"
    
    var color: String {
        switch self {
        case .person:
            return "blue"
        case .organization:
            return "purple"
        case .activity:
            return "green"
        case .concept:
            return "orange"
        case .location:
            return "red"
        }
    }
    
    var iconName: String {
        switch self {
        case .person:
            return "person.circle"
        case .organization:
            return "building.2"
        case .activity:
            return "figure.run"
        case .concept:
            return "lightbulb"
        case .location:
            return "location"
        }
    }
    
    var description: String {
        switch self {
        case .person:
            return "People mentioned in notes"
        case .organization:
            return "Companies, institutions, groups"
        case .activity:
            return "Actions, events, processes"
        case .concept:
            return "Ideas, topics, themes"
        case .location:
            return "Places, addresses, regions"
        }
    }
}

// MARK: - Extensions

extension Entity {
    /// Add a new alias for this entity
    func addAlias(_ alias: String) {
        if !aliases.contains(alias) && alias != name {
            aliases.append(alias)
        }
    }
    
    /// Record a new mention of this entity
    func recordMention() {
        mentions += 1
        lastMentioned = Date()
    }
    
    /// Update entity attributes
    func setAttribute(_ key: String, value: String) {
        attributes[key] = value
    }
    
    /// Get entity attribute
    func getAttribute(_ key: String) -> String? {
        return attributes[key]
    }
    
    /// Add a relationship ID
    func addRelationship(_ relationshipId: UUID) {
        if !relationships.contains(relationshipId) {
            relationships.append(relationshipId)
        }
    }
    
    /// Remove a relationship ID
    func removeRelationship(_ relationshipId: UUID) {
        relationships.removeAll { $0 == relationshipId }
    }
    
    /// Check if entity matches search query
    func matches(query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        
        // Check name
        if name.lowercased().contains(lowercaseQuery) {
            return true
        }
        
        // Check aliases
        if aliases.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
            return true
        }
        
        // Check description
        if let description = entityDescription, description.lowercased().contains(lowercaseQuery) {
            return true
        }
        
        // Check tags
        if tags.contains(where: { $0.lowercased().contains(lowercaseQuery) }) {
            return true
        }
        
        return false
    }
    
    /// Generate suggestions for improving this entity
    var improvementSuggestions: [String] {
        var suggestions: [String] = []
        
        if confidence < 0.7 {
            suggestions.append("Consider validating this entity - low confidence score")
        }
        
        if mentions == 1 {
            suggestions.append("This entity is only mentioned once - may be noise")
        }
        
        if entityDescription == nil {
            suggestions.append("Add a description to provide more context")
        }
        
        if relationships.isEmpty {
            suggestions.append("No relationships found - consider linking to other entities")
        }
        
        if freshness < 0.3 {
            suggestions.append("Entity not mentioned recently - may be outdated")
        }
        
        return suggestions
    }
}