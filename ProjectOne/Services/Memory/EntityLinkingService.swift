//
//  EntityLinkingService.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/29/25.
//

import Foundation
import SwiftData
import Combine
import os.log

/// Service for real-time entity linking and relationship discovery during note creation
@MainActor
public class EntityLinkingService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var suggestedEntities: [Entity] = []
    @Published public var suggestedRelationships: [Relationship] = []
    @Published public var linkedEntities: Set<UUID> = []
    
    // MARK: - Private Properties
    
    private let modelContext: ModelContext
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EntityLinkingService")
    
    // Entity patterns for linking
    private let entityPatterns: [String: EntityType] = [
        // Person patterns
        "\\b[A-Z][a-z]+ [A-Z][a-z]+\\b": .person,
        "\\b(?:Dr|Mr|Ms|Mrs|Prof)\\. [A-Z][a-z]+": .person,
        
        // Organization patterns  
        "\\b[A-Z][a-zA-Z]* (?:Corp|Inc|LLC|Ltd|Company|Organization)\\b": .organization,
        "\\b(?:Apple|Google|Microsoft|Amazon|Meta)\\b": .organization,
        
        // Location patterns
        "\\b[A-Z][a-z]+ (?:Street|Ave|Avenue|Road|Rd|Drive|Dr|Blvd|Boulevard)\\b": .location,
        "\\b(?:New York|Los Angeles|San Francisco|Chicago|Boston)\\b": .location,
        
        // Event patterns
        "\\b[A-Z][a-zA-Z]* (?:Meeting|Conference|Workshop|Seminar)\\b": .event,
        
        // Concept patterns
        "\\b(?:AI|Machine Learning|Swift|iOS|macOS|Programming)\\b": .concept
    ]
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("EntityLinkingService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Analyze text and suggest entity links
    public func analyzeTextForEntities(_ text: String) {
        logger.debug("Analyzing text for entities: '\(text.prefix(50))...'")
        
        Task {
            let newSuggestions = await extractPotentialEntities(from: text)
            let existingEntities = await findExistingEntities(matching: newSuggestions)
            
            suggestedEntities = existingEntities
            suggestedRelationships = await discoverRelationships(from: text, entities: existingEntities)
        }
    }
    
    /// Link an entity to the current text
    public func linkEntity(_ entity: Entity) {
        linkedEntities.insert(entity.id)
        
        // Update entity mentions
        entity.mentions += 1
        entity.lastMentioned = Date()
        
        try? modelContext.save()
        logger.info("Linked entity: \(entity.name)")
    }
    
    /// Create a new entity from suggested text
    public func createEntity(name: String, type: EntityType, description: String? = nil) -> Entity {
        let entity = Entity(name: name, type: type)
        entity.entityDescription = description
        entity.confidence = 0.8 // High confidence for user-created entities
        entity.mentions = 1
        entity.isValidated = true
        
        modelContext.insert(entity)
        
        do {
            try modelContext.save()
            linkedEntities.insert(entity.id)
            logger.info("Created new entity: \(name) (\(type.rawValue))")
        } catch {
            logger.error("Failed to create entity: \(error.localizedDescription)")
        }
        
        return entity
    }
    
    /// Clear current suggestions and links
    public func clearSuggestions() {
        suggestedEntities = []
        suggestedRelationships = []
        linkedEntities = []
    }
    
    // MARK: - Private Methods
    
    private func extractPotentialEntities(from text: String) async -> [PotentialEntity] {
        var potentialEntities: [PotentialEntity] = []
        
        // Use regex patterns to find potential entities
        for (pattern, type) in entityPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)
                
                for match in matches {
                    if let matchRange = Range(match.range, in: text) {
                        let matchedText = String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let potential = PotentialEntity(
                            name: matchedText,
                            type: type,
                            confidence: 0.7,
                            context: extractContext(for: matchRange, in: text)
                        )
                        potentialEntities.append(potential)
                    }
                }
            }
        }
        
        return potentialEntities
    }
    
    private func findExistingEntities(matching potentials: [PotentialEntity]) async -> [Entity] {
        guard !potentials.isEmpty else { return [] }
        
        do {
            // Fetch all entities and filter in memory since SwiftData predicates don't support lowercased()
            let allEntities = try modelContext.fetch(FetchDescriptor<Entity>(
                sortBy: [SortDescriptor(\.lastMentioned, order: .reverse)]
            ))
            
            let entityNames = potentials.map { $0.name.lowercased() }
            
            return allEntities.filter { entity in
                entityNames.contains { potentialName in
                    entity.name.lowercased().contains(potentialName) ||
                    entity.aliases.contains { alias in
                        alias.lowercased().contains(potentialName)
                    }
                }
            }
            
        } catch {
            logger.error("Failed to fetch existing entities: \(error.localizedDescription)")
            return []
        }
    }
    
    private func discoverRelationships(from text: String, entities: [Entity]) async -> [Relationship] {
        guard entities.count >= 2 else { return [] }
        
        var discoveredRelationships: [Relationship] = []
        
        // Look for relationship patterns between entities
        let relationshipPatterns = [
            "works at", "employed by", "member of",
            "located in", "based in", "from",
            "knows", "met with", "contacted",
            "created", "developed", "designed",
            "related to", "connected to", "associated with"
        ]
        
        for i in 0..<entities.count {
            for j in (i+1)..<entities.count {
                let entity1 = entities[i]
                let entity2 = entities[j]
                
                // Check if these entities appear near each other in text
                if entitiesAppearTogether(entity1: entity1, entity2: entity2, in: text) {
                    // Try to infer relationship type
                    let relationshipType = inferRelationshipType(
                        between: entity1, 
                        and: entity2, 
                        in: text, 
                        patterns: relationshipPatterns
                    )
                    
                    if let relationship = await findOrCreateRelationship(
                        subject: entity1,
                        predicate: relationshipType,
                        object: entity2,
                        context: text
                    ) {
                        discoveredRelationships.append(relationship)
                    }
                }
            }
        }
        
        return discoveredRelationships
    }
    
    private func entitiesAppearTogether(entity1: Entity, entity2: Entity, in text: String) -> Bool {
        let text = text.lowercased()
        let entity1Pos = text.range(of: entity1.name.lowercased())
        let entity2Pos = text.range(of: entity2.name.lowercased())
        
        guard let pos1 = entity1Pos, let pos2 = entity2Pos else { return false }
        
        // Check if entities appear within reasonable distance (e.g., same sentence)
        let distance = abs(text.distance(from: pos1.lowerBound, to: pos2.lowerBound))
        return distance < 200 // Arbitrary threshold for "nearby"
    }
    
    private func inferRelationshipType(between entity1: Entity, and entity2: Entity, in text: String, patterns: [String]) -> String {
        let text = text.lowercased()
        
        // Look for explicit relationship patterns
        for pattern in patterns {
            if text.contains(pattern) {
                return pattern
            }
        }
        
        // Fallback based on entity types
        switch (entity1.type, entity2.type) {
        case (.person, .organization):
            return "works at"
        case (.organization, .person):
            return "employs"
        case (.person, .location):
            return "located in"
        case (.person, .person):
            return "knows"
        case (.concept, .concept):
            return "related to"
        default:
            return "associated with"
        }
    }
    
    private func findOrCreateRelationship(subject: Entity, predicate: String, object: Entity, context: String) async -> Relationship? {
        do {
            // Check if relationship already exists - fetch and filter in memory for reliability
            let allRelationships = try modelContext.fetch(FetchDescriptor<Relationship>())
            
            if let existing = allRelationships.first(where: { relationship in
                relationship.subjectEntityId == subject.id &&
                relationship.objectEntityId == object.id &&
                relationship.predicate == predicate
            }) {
                // Update existing relationship
                existing.confidence = min(1.0, existing.confidence + 0.1)
                existing.lastConfirmed = Date()
                return existing
            } else {
                // Create new relationship
                let relationship = Relationship(
                    subjectEntityId: subject.id.uuidString,
                    predicate: predicate,
                    objectEntityId: object.id.uuidString
                )
                relationship.confidence = 0.6
                relationship.context = String(context.prefix(200))
                relationship.subjectName = subject.name
                relationship.objectName = object.name
                
                modelContext.insert(relationship)
                try modelContext.save()
                
                return relationship
            }
            
        } catch {
            logger.error("Failed to find or create relationship: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func extractContext(for range: Range<String.Index>, in text: String) -> String {
        let contextRange = 50
        let startIndex = text.index(range.lowerBound, offsetBy: -contextRange, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: contextRange, limitedBy: text.endIndex) ?? text.endIndex
        
        return String(text[startIndex..<endIndex])
    }
}

// MARK: - Supporting Types

private struct PotentialEntity {
    let name: String
    let type: EntityType
    let confidence: Double
    let context: String
}

// MARK: - Extensions

extension EntityLinkingService {
    /// Get entity suggestions for auto-completion
    public func getEntitySuggestions(for query: String) -> [Entity] {
        guard query.count >= 2 else { return [] }
        
        do {
            let queryLower = query.lowercased()
            
            // Fetch all entities and filter in memory
            let allEntities = try modelContext.fetch(FetchDescriptor<Entity>(
                sortBy: [
                    SortDescriptor(\.mentions, order: .reverse),
                    SortDescriptor(\.lastMentioned, order: .reverse)
                ]
            ))
            
            return Array(allEntities.filter { entity in
                entity.name.lowercased().contains(queryLower) ||
                entity.aliases.contains { alias in
                    alias.lowercased().contains(queryLower)
                }
            }.prefix(5))
            
        } catch {
            logger.error("Failed to fetch entity suggestions: \(error.localizedDescription)")
            return []
        }
    }
}