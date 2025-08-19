//
//  KnowledgeGraphCognitiveAdapter.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Bridge component for integrating Knowledge Graph with ComoRAG cognitive architecture
//

import Foundation
import SwiftData
import os.log

// Resolve CognitiveLayerType ambiguity by using explicit alias
// Both definitions are identical, using the one from CognitiveMemoryProtocols
private typealias CognitiveLayer = ProjectOne.CognitiveLayerType

// MARK: - Knowledge Graph Cognitive Adapter

/// Service for bidirectional synchronization between Knowledge Graph entities and cognitive memory nodes
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@MainActor
public final class KnowledgeGraphCognitiveAdapter: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "KnowledgeGraphCognitiveAdapter")
    
    // Dependencies
    private let modelContext: ModelContext
    private let cognitiveSystem: CognitiveMemorySystem
    
    // Mapping storage
    @Published private var entityToCognitiveMapping: [UUID: String] = [:]
    @Published private var cognitiveToEntityMapping: [String: UUID] = [:]
    
    // Configuration
    private let syncThreshold: Double
    private let maxSyncBatchSize: Int
    
    public init(
        modelContext: ModelContext,
        cognitiveSystem: CognitiveMemorySystem,
        syncThreshold: Double = 0.7,
        maxSyncBatchSize: Int = 50
    ) {
        self.modelContext = modelContext
        self.cognitiveSystem = cognitiveSystem
        self.syncThreshold = syncThreshold
        self.maxSyncBatchSize = maxSyncBatchSize
    }
    
    // MARK: - Entity to Cognitive Sync
    
    /// Synchronize a Knowledge Graph entity to cognitive memory layers
    public func syncEntityToCognitive(_ entity: Entity) async throws {
        logger.debug("Syncing entity '\(entity.name)' to cognitive layers")
        
        // Check if entity already has cognitive representation
        if let existingCognitiveId = entityToCognitiveMapping[entity.id] {
            try await updateCognitiveFromEntity(entity, cognitiveId: existingCognitiveId)
        } else {
            try await createCognitiveFromEntity(entity)
        }
    }
    
    /// Sync multiple entities in batch
    public func syncEntitiesToCognitive(_ entities: [Entity]) async throws {
        logger.info("Batch syncing \(entities.count) entities to cognitive layers")
        
        let batches = entities.chunked(into: maxSyncBatchSize)
        
        for batch in batches {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for entity in batch {
                    group.addTask {
                        try await self.syncEntityToCognitive(entity)
                    }
                }
                try await group.waitForAll()
            }
        }
        
        logger.info("Completed batch sync of \(entities.count) entities")
    }
    
    private func createCognitiveFromEntity(_ entity: Entity) async throws {
        let cognitiveNode = try await createCognitiveNodeFromEntity(entity)
        
        // Add to appropriate cognitive layer based on entity characteristics
        switch determineCognitiveLayer(for: entity) {
        case .veridical:
            if let veridicalNode = cognitiveNode as? VeridicalNode {
                try await cognitiveSystem.veridicalLayer.addNode(veridicalNode)
            }
        case .semantic:
            if let semanticNode = cognitiveNode as? SemanticNode {
                try await cognitiveSystem.semanticLayer.addNode(semanticNode)
            }
        case .episodic:
            if let episodicNode = cognitiveNode as? EpisodicNode {
                try await cognitiveSystem.episodicLayer.addNode(episodicNode)
            }
        case .fusion:
            // Fusion nodes are created through fusion engine, not direct sync
            break
        }
        
        // Update mapping
        entityToCognitiveMapping[entity.id] = cognitiveNode.id.uuidString
        cognitiveToEntityMapping[cognitiveNode.id.uuidString] = entity.id
        
        logger.debug("Created cognitive node \(cognitiveNode.id) for entity \(entity.name)")
    }
    
    private func updateCognitiveFromEntity(_ entity: Entity, cognitiveId: String) async throws {
        guard let cognitiveUUID = UUID(uuidString: cognitiveId) else { return }
        
        // Find the cognitive node in appropriate layer
        let layerType = determineCognitiveLayer(for: entity)
        
        switch layerType {
        case .veridical:
            if let node = cognitiveSystem.veridicalLayer.nodes.first(where: { $0.id == cognitiveUUID }) {
                await updateCognitiveNode(node, from: entity)
            }
        case .semantic:
            if let node = cognitiveSystem.semanticLayer.nodes.first(where: { $0.id == cognitiveUUID }) {
                await updateCognitiveNode(node, from: entity)
            }
        case .episodic:
            if let node = cognitiveSystem.episodicLayer.nodes.first(where: { $0.id == cognitiveUUID }) {
                await updateCognitiveNode(node, from: entity)
            }
        case .fusion:
            break
        }
        
        logger.debug("Updated cognitive node \(cognitiveId) from entity \(entity.name)")
    }
    
    private func createCognitiveNodeFromEntity(_ entity: Entity) async throws -> any CognitiveMemoryNode {
        let layerType = determineCognitiveLayer(for: entity)
        let nodeContent = generateCognitiveContent(from: entity)
        
        switch layerType {
        case .veridical:
            let veridicalNode = VeridicalNode(
                content: nodeContent,
                factType: .observation,
                importance: entity.importance
            )
            
            // Set entity-specific properties
            veridicalNode.verificationStatus = entity.isValidated ? .verified : .unverified
            veridicalNode.sourceReference = entity.id.uuidString
            
            return veridicalNode
            
        case .semantic:
            let semanticNode = SemanticNode(
                content: nodeContent,
                conceptType: mapEntityTypeToConceptType(entity.type),
                abstractionLevel: 0,
                importance: entity.importance
            )
            
            // Set entity-specific properties
            semanticNode.confidence = entity.confidence
            
            return semanticNode
            
        case .episodic:
            let episodicNode = EpisodicNode(
                content: nodeContent,
                episodeType: .event,
                importance: entity.importance
            )
            
            // Set entity-specific temporal context (using current timestamp)
            episodicNode.temporalContext = EpisodicNode.TemporalContext(timestamp: Date())
            episodicNode.addContextualCue("entity_sync")
            if !entity.aliases.isEmpty {
                entity.aliases.forEach { alias in
                    episodicNode.addContextualCue(alias)
                }
            }
            episodicNode.emotionalValence = 0.0 // Neutral for entities
            
            return episodicNode
            
        case .fusion:
            // This should not happen in direct sync
            throw CognitiveAdapterError.invalidLayerAssignment
        }
    }
    
    private func updateCognitiveNode(_ node: any CognitiveMemoryNode, from entity: Entity) async {
        // Update common properties
        if let baseCognitiveNode = node as? BaseCognitiveNode {
            baseCognitiveNode.content = generateCognitiveContent(from: entity)
            baseCognitiveNode.importance = entity.importance
            baseCognitiveNode.lastAccessed = Date()
        }
        
        // Update layer-specific properties
        if let veridicalNode = node as? VeridicalNode {
            veridicalNode.verificationStatus = entity.isValidated ? .verified : .unverified
            veridicalNode.sourceReference = entity.id.uuidString
        } else if let semanticNode = node as? SemanticNode {
            semanticNode.confidence = entity.confidence
        }
    }
    
    // MARK: - Cognitive to Entity Sync
    
    /// Synchronize cognitive memory changes back to Knowledge Graph entities
    public func syncCognitiveToEntity(_ cognitiveNodeId: String) async throws {
        guard let entityId = cognitiveToEntityMapping[cognitiveNodeId] else {
            logger.warning("No entity mapping found for cognitive node: \(cognitiveNodeId)")
            return
        }
        
        // Fetch entity
        let entityDescriptor = FetchDescriptor<Entity>(
            predicate: #Predicate<Entity> { entity in
                entity.id == entityId
            }
        )
        
        guard let entities = try? modelContext.fetch(entityDescriptor),
              let entity = entities.first else {
            logger.error("Entity not found for ID: \(entityId)")
            return
        }
        
        // Find cognitive node and update entity
        try await updateEntityFromCognitive(entity, cognitiveNodeId: cognitiveNodeId)
        
        logger.debug("Synced cognitive changes to entity '\(entity.name)'")
    }
    
    private func updateEntityFromCognitive(_ entity: Entity, cognitiveNodeId: String) async throws {
        guard let cognitiveUUID = UUID(uuidString: cognitiveNodeId) else { return }
        
        // Find cognitive node across all layers
        var cognitiveNode: (any CognitiveMemoryNode)?
        
        if let node = cognitiveSystem.veridicalLayer.nodes.first(where: { $0.id == cognitiveUUID }) {
            cognitiveNode = node
        } else if let node = cognitiveSystem.semanticLayer.nodes.first(where: { $0.id == cognitiveUUID }) {
            cognitiveNode = node
        } else if let node = cognitiveSystem.episodicLayer.nodes.first(where: { $0.id == cognitiveUUID }) {
            cognitiveNode = node
        }
        
        guard let node = cognitiveNode else { return }
        
        // Update entity properties from cognitive node
        entity.importance = max(entity.importance, node.importance)
        
        // Update mentions count if node has been accessed recently
        if let baseCognitiveNode = node as? BaseCognitiveNode,
           baseCognitiveNode.accessCount > 0 {
            entity.mentions += baseCognitiveNode.accessCount
            entity.lastMentioned = baseCognitiveNode.lastAccessed
        }
        
        // Update confidence from semantic nodes
        if let semanticNode = node as? SemanticNode {
            entity.confidence = max(entity.confidence, semanticNode.confidence)
        }
        
        // Update validation status from veridical nodes
        if let veridicalNode = node as? VeridicalNode,
           veridicalNode.verificationStatus == .verified {
            entity.isValidated = true
        }
    }
    
    // MARK: - Fusion Integration
    
    /// Create entity relationships from cognitive fusion connections
    public func createRelationshipsFromFusions(_ fusionNodes: [FusionNode]) async throws {
        logger.info("Creating entity relationships from \(fusionNodes.count) fusion nodes")
        
        for fusionNode in fusionNodes {
            try await createRelationshipFromFusion(fusionNode)
        }
    }
    
    private func createRelationshipFromFusion(_ fusionNode: FusionNode) async throws {
        // Get entities corresponding to source nodes
        let sourceEntityIds = fusionNode.sourceNodes.compactMap { nodeId -> UUID? in
            return cognitiveToEntityMapping[nodeId]
        }
        
        guard sourceEntityIds.count >= 2 else { return }
        
        // Create relationships between entities
        for i in 0..<sourceEntityIds.count {
            for j in (i+1)..<sourceEntityIds.count {
                let subjectId = sourceEntityIds[i]
                let objectId = sourceEntityIds[j]
                
                try await createRelationshipIfNeeded(
                    subjectId: subjectId,
                    objectId: objectId,
                    fusionNode: fusionNode
                )
            }
        }
    }
    
    private func createRelationshipIfNeeded(
        subjectId: UUID,
        objectId: UUID,
        fusionNode: FusionNode
    ) async throws {
        // Check if relationship already exists
        let relationshipDescriptor = FetchDescriptor<Relationship>(
            predicate: #Predicate<Relationship> { relationship in
                (relationship.subjectEntityId == subjectId && relationship.objectEntityId == objectId) ||
                (relationship.subjectEntityId == objectId && relationship.objectEntityId == subjectId)
            }
        )
        
        let existingRelationships = try modelContext.fetch(relationshipDescriptor)
        
        if !existingRelationships.isEmpty {
            // Update existing relationship importance
            for relationship in existingRelationships {
                relationship.importance = max(relationship.importance, fusionNode.importance)
            }
        } else {
            // Create new relationship
            let predicateType = mapFusionTypeToPredicateType(fusionNode.fusionType)
            
            let relationship = Relationship(
                subjectEntityId: subjectId,
                predicateType: predicateType,
                objectEntityId: objectId
            )
            
            relationship.confidence = fusionNode.coherenceScore
            relationship.importance = fusionNode.importance
            relationship.context = "Generated from cognitive fusion: \(fusionNode.fusionType)"
            
            modelContext.insert(relationship)
        }
    }
    
    // MARK: - Semantic Search Enhancement
    
    /// Find entities similar to a given query using cognitive semantic search
    public func findSimilarEntities(
        query: String,
        limit: Int = 10,
        threshold: Double = 0.5
    ) async throws -> [EntityCognitiveMatch] {
        logger.debug("Finding entities similar to query: '\(query)'")
        
        // Search across cognitive layers
        let cognitiveResults = try await cognitiveSystem.searchCognitiveLayers(query: query)
        
        var matches: [EntityCognitiveMatch] = []
        
        // Convert cognitive matches to entity matches
        for (nodeId, relevance) in zip(cognitiveResults.relevantNodes.map { $0.id.uuidString }, cognitiveResults.relevanceScores) {
            guard relevance > threshold,
                  let entityId = cognitiveToEntityMapping[nodeId] else { continue }
            
            // Fetch entity
            let entityDescriptor = FetchDescriptor<Entity>(
                predicate: #Predicate<Entity> { entity in
                    entity.id == entityId
                }
            )
            
            if let entities = try? modelContext.fetch(entityDescriptor) as [Entity],
               let entity = entities.first {
                matches.append(EntityCognitiveMatch(
                    entity: entity,
                    cognitiveRelevance: relevance,
                    matchingCognitiveLayer: cognitiveResults.layerDistribution.keys.first ?? CognitiveLayer.semantic
                ))
            }
        }
        
        // Sort by relevance and limit results
        return Array(matches.sorted { $0.cognitiveRelevance > $1.cognitiveRelevance }.prefix(limit))
    }
    
    // MARK: - Helper Methods
    
    private func determineCognitiveLayer(for entity: Entity) -> CognitiveLayer {
        // Logic to determine which cognitive layer best represents this entity
        
        if entity.isValidated && entity.confidence > 0.8 {
            // High-confidence, validated entities go to veridical layer
            return .veridical
        }
        
        if entity.type == .concept || entity.type == .activity {
            // Abstract concepts go to semantic layer
            return .semantic
        }
        
        if entity.mentions > 1 && entity.lastMentioned.timeIntervalSinceNow > -86400 { // Last 24 hours
            // Recently mentioned entities with context go to episodic layer
            return .episodic
        }
        
        // Default to semantic layer
        return .semantic
    }
    
    private func generateCognitiveContent(from entity: Entity) -> String {
        var content = entity.name
        
        if let description = entity.entityDescription, !description.isEmpty {
            content += ": \(description)"
        }
        
        if !entity.aliases.isEmpty {
            content += " (also: \(entity.aliases.joined(separator: ", ")))"
        }
        
        return content
    }
    
    private func mapEntityTypeToConceptType(_ entityType: EntityType) -> SemanticNode.ConceptType {
        switch entityType {
        case .person:
            return .entity
        case .organization:
            return .category
        case .activity:
            return .process
        case .concept:
            return .category
        case .location, .place:
            return .entity
        case .event:
            return .process
        case .thing:
            return .entity
        }
    }
    
    private func mapFusionTypeToPredicateType(_ fusionType: FusionNode.FusionType) -> PredicateType {
        switch fusionType {
        case .crossLayer, .withinLayer, .conceptual:
            return .relatedTo
        case .temporal:
            return .temporallyRelatedTo
        case .causal:
            return .causes
        case .analogical:
            return .similarTo
        }
    }
    
    // MARK: - Batch Operations
    
    /// Perform full synchronization between Knowledge Graph and cognitive system
    public func performFullSync() async throws {
        logger.info("Performing full synchronization between Knowledge Graph and cognitive system")
        
        let startTime = Date()
        
        // Sync all entities to cognitive layers
        let entityDescriptor = FetchDescriptor<Entity>()
        let entities = try modelContext.fetch(entityDescriptor)
        
        try await syncEntitiesToCognitive(entities)
        
        // Sync cognitive changes back to entities
        let allMappings = Array(cognitiveToEntityMapping.keys)
        for cognitiveId in allMappings {
            try await syncCognitiveToEntity(cognitiveId)
        }
        
        // Create relationships from existing fusions
        try await createRelationshipsFromFusions(cognitiveSystem.fusionNodes)
        
        let syncTime = Date().timeIntervalSince(startTime)
        logger.info("Full synchronization completed in \(syncTime)s for \(entities.count) entities")
    }
    
    /// Clear all mappings (useful for testing or reset)
    public func clearMappings() {
        entityToCognitiveMapping.removeAll()
        cognitiveToEntityMapping.removeAll()
        logger.info("Cleared all entity-cognitive mappings")
    }
}

// MARK: - Supporting Types

public struct EntityCognitiveMatch {
    public let entity: Entity
    public let cognitiveRelevance: Double
    public let matchingCognitiveLayer: CognitiveLayer
}

public enum CognitiveAdapterError: Error, LocalizedError {
    case invalidLayerAssignment
    case entityNotFound(UUID)
    case cognitiveNodeNotFound(String)
    case syncThresholdNotMet
    
    public var errorDescription: String? {
        switch self {
        case .invalidLayerAssignment:
            return "Cannot assign entity to fusion layer directly"
        case .entityNotFound(let id):
            return "Entity not found: \(id)"
        case .cognitiveNodeNotFound(let id):
            return "Cognitive node not found: \(id)"
        case .syncThresholdNotMet:
            return "Entity does not meet synchronization threshold"
        }
    }
}

// MARK: - Array Extension for Batching
// Note: chunked extension is already defined in EmbeddingMigrationService.swift

// MARK: - Missing PredicateType Cases

extension PredicateType {
    static let temporallyRelatedTo = PredicateType.relatedTo // Placeholder
    static let causes = PredicateType.relatedTo // Placeholder  
    static let similarTo = PredicateType.relatedTo // Placeholder
}
