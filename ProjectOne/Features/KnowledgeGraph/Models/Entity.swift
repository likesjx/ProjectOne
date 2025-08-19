import Foundation
import SwiftData
import SwiftUI

/// Represents a named entity in the knowledge graph (people, organizations, activities, concepts, locations)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class Entity {
    public var id: UUID
    public var timestamp: Date
    
    // Entity identification
    public var name: String
    public var type: EntityType
    public var aliases: [String] // Alternative names for this entity
    
    // Confidence and validation
    public var confidence: Double // Confidence in entity extraction (0.0-1.0)
    public var isValidated: Bool // Whether user has validated this entity
    public var extractionSource: String? // Source where entity was first extracted
    
    // Knowledge graph connections
    public var mentions: Int // Number of times mentioned across all notes
    public var lastMentioned: Date
    @Attribute(.transformable(by: "NSSecureUnarchiveFromData"))
    public var relationships: [UUID] // IDs of relationships this entity participates in
    
    // Entity attributes
    public var attributes: [String: String] // Key-value pairs for additional entity info
    public var entityDescription: String? // User-provided or AI-generated description
    public var tags: [String] // User-assigned tags
    
    // Semantic information
    public var importance: Double // Calculated importance score (0.0-1.0)
    public var salience: Double // How central this entity is to the knowledge graph
    
    // MARK: - Cognitive Integration Fields
    
    /// UUID of associated cognitive memory node (if any)
    public var associatedCognitiveNodeId: String?
    
    /// Which cognitive layer this entity is primarily represented in
    public var primaryCognitiveLayer: String? // CognitiveLayerType.rawValue
    
    /// Cognitive consolidation score from memory fusion processes
    public var cognitiveConsolidationScore: Double
    
    /// Timestamp when cognitive sync was last performed
    public var lastCognitiveSyncAt: Date?
    
    /// IDs of fusion connections involving this entity
    @Attribute(.transformable(by: "NSSecureUnarchiveFromData"))
    public var fusionConnectionIds: [String] // FusionNode IDs
    
    /// Cognitive relevance score for search and retrieval
    public var cognitiveRelevanceScore: Double
    
    // MARK: - Embedding Fields
    
    /// Vector embedding for semantic similarity search
    var embedding: Data?
    
    /// Version identifier for the embedding model used
    public var embeddingModelVersion: String?
    
    /// Timestamp when the embedding was generated
    public var embeddingGeneratedAt: Date?
    
    /// Deprecated: Use embedding methods instead
    @available(*, deprecated, message: "Use embedding property and methods instead")
    public var semanticEmbedding: [Double]? // Vector embedding for semantic similarity
    
    public init(name: String, type: EntityType) {
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
        self.importance = 0.0
        self.salience = 0.0
        
        // Initialize cognitive integration fields
        self.associatedCognitiveNodeId = nil
        self.primaryCognitiveLayer = nil
        self.cognitiveConsolidationScore = 0.0
        self.lastCognitiveSyncAt = nil
        self.fusionConnectionIds = []
        self.cognitiveRelevanceScore = 0.0
        
        // Initialize embedding fields
        self.embedding = nil
        self.embeddingModelVersion = nil
        self.embeddingGeneratedAt = nil
        // Backward compatibility initialization (deprecation warning acceptable)
        self.semanticEmbedding = nil
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

public enum EntityType: String, CaseIterable, Codable {
    case person = "Person"
    case organization = "Organization"
    case activity = "Activity"
    case concept = "Concept"
    case location = "Location"
    case event = "Event"
    case thing = "Thing"
    case place = "Place"
    
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
        case .location, .place:
            return "red"
        case .event:
            return "pink"
        case .thing:
            return "gray"
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
        case .location, .place:
            return "location"
        case .event:
            return "calendar"
        case .thing:
            return "cube"
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
        case .location, .place:
            return "Places, addresses, regions"
        case .event:
            return "Events, meetings, occurrences"
        case .thing:
            return "Objects, items, things"
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
    
    // MARK: - Embedding Management
    
    /// Check if the entity has a valid embedding
    public var hasEmbedding: Bool {
        return embedding != nil && embeddingModelVersion != nil
    }
    
    /// Set the embedding for this entity
    public func setEmbedding(_ embeddingVector: [Float], modelVersion: String) {
        self.embedding = EmbeddingUtils.embeddingToData(embeddingVector)
        self.embeddingModelVersion = modelVersion
        self.embeddingGeneratedAt = Date()
        
        // Update deprecated property for backward compatibility (deprecation warning acceptable)
        self.semanticEmbedding = embeddingVector.map { Double($0) }
    }
    
    /// Get the embedding as a float array for calculations
    public func getEmbedding() -> [Float]? {
        guard let embeddingData = embedding else { return nil }
        return EmbeddingUtils.dataToEmbedding(embeddingData)
    }
    
    /// Check if embedding needs regeneration
    public func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval = 14 * 24 * 3600) -> Bool {
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
        
        // Check if entity has been significantly updated
        if lastMentioned > (embeddingGeneratedAt ?? Date.distantPast) {
            return true
        }
        
        return false
    }
    
    /// Get combined text for embedding generation
    public var embeddingText: String {
        var text = name
        
        if !aliases.isEmpty {
            text += " (also known as: \(aliases.joined(separator: ", ")))"
        }
        
        if let description = entityDescription, !description.isEmpty {
            text += ". \(description)"
        }
        
        if !tags.isEmpty {
            text += ". Tags: \(tags.joined(separator: ", "))"
        }
        
        text += ". Type: \(type.rawValue)"
        
        return text
    }
    
    // MARK: - Cognitive Integration Methods
    
    /// Associate this entity with a cognitive memory node
    public func associateWithCognitiveNode(_ nodeId: String, layer: CognitiveLayerType) {
        self.associatedCognitiveNodeId = nodeId
        self.primaryCognitiveLayer = layer.rawValue
        self.lastCognitiveSyncAt = Date()
    }
    
    /// Update cognitive consolidation score
    public func updateCognitiveConsolidationScore(_ score: Double) {
        self.cognitiveConsolidationScore = max(0.0, min(1.0, score))
        self.lastCognitiveSyncAt = Date()
    }
    
    /// Add a fusion connection ID
    public func addFusionConnection(_ fusionId: String) {
        if !fusionConnectionIds.contains(fusionId) {
            fusionConnectionIds.append(fusionId)
        }
    }
    
    /// Remove a fusion connection ID
    public func removeFusionConnection(_ fusionId: String) {
        fusionConnectionIds.removeAll { $0 == fusionId }
    }
    
    /// Update cognitive relevance score based on recent cognitive activity
    public func updateCognitiveRelevance(_ score: Double) {
        self.cognitiveRelevanceScore = max(0.0, min(1.0, score))
    }
    
    /// Check if entity has cognitive representation
    public var hasCognitiveRepresentation: Bool {
        return associatedCognitiveNodeId != nil
    }
    
    /// Check if entity needs cognitive sync
    public func needsCognitiveSync(maxAge: TimeInterval = 24 * 3600) -> Bool {
        guard let lastSync = lastCognitiveSyncAt else { return true }
        return Date().timeIntervalSince(lastSync) > maxAge
    }
    
    /// Get cognitive layer type from string
    public var cognitiveLayerType: CognitiveLayerType? {
        guard let layerString = primaryCognitiveLayer else { return nil }
        return CognitiveLayerType(rawValue: layerString)
    }
    
    /// Enhanced entity score including cognitive factors
    public var enhancedEntityScore: Double {
        let baseScore = entityScore
        let cognitiveBonus = cognitiveConsolidationScore * 0.2
        let relevanceBonus = cognitiveRelevanceScore * 0.1
        let fusionBonus = min(0.1, Double(fusionConnectionIds.count) * 0.02)
        
        return min(1.0, baseScore + cognitiveBonus + relevanceBonus + fusionBonus)
    }
}

// MARK: - Cognitive Layer Type

public enum CognitiveLayerType: String, CaseIterable, Codable {
    case veridical = "veridical"
    case semantic = "semantic"
    case episodic = "episodic"
    case fusion = "fusion"
    
    public var displayName: String {
        switch self {
        case .veridical:
            return "Veridical Layer"
        case .semantic:
            return "Semantic Layer"
        case .episodic:
            return "Episodic Layer"
        case .fusion:
            return "Fusion Layer"
        }
    }
    
    public var description: String {
        switch self {
        case .veridical:
            return "Immediate facts and verified information"
        case .semantic:
            return "Consolidated knowledge and concepts"
        case .episodic:
            return "Contextual experiences and temporal information"
        case .fusion:
            return "Cross-layer integrated insights"
        }
    }
}