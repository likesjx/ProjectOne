//
//  CognitiveKnowledgeGraphViewModel.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  View model for Cognitive Knowledge Graph with enhanced visualization
//

import SwiftUI
import Combine
import Foundation

// MARK: - Cognitive Knowledge Graph ViewModel

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@MainActor
public final class CognitiveKnowledgeGraphViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var visibleEntities: [Entity] = []
    @Published public var visibleRelationships: [Relationship] = []
    @Published public var fusionConnections: [FusionConnection] = []
    
    @Published public var isLoading: Bool = false
    @Published public var isCognitiveEnhanced: Bool = false
    @Published public var cognitiveInsights: GraphCognitiveInsights?
    
    @Published public var selectedLayout: GraphLayout = .force
    @Published public var showCognitiveHeatmap: Bool = false
    @Published public var showLayerBoundaries: Bool = true
    
    // Filter states
    @Published public var selectedEntityTypes: Set<EntityType> = Set(EntityType.allCases)
    @Published public var selectedRelationshipCategories: Set<RelationshipCategory> = Set(RelationshipCategory.allCases)
    @Published public var searchQuery: String = ""
    @Published public var cognitiveFilter: CognitiveFilter = .all
    
    // MARK: - Private Properties
    
    private let knowledgeGraphService: KnowledgeGraphService
    private var cancellables = Set<AnyCancellable>()
    private var entityPositions: [UUID: CGPoint] = [:]
    private var canvasSize: CGSize = .zero
    
    // MARK: - Initialization
    
    public init(knowledgeGraphService: KnowledgeGraphService) {
        self.knowledgeGraphService = knowledgeGraphService
        self.isCognitiveEnhanced = knowledgeGraphService.cognitiveAdapter != nil
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe knowledge graph service changes
        knowledgeGraphService.$entities
            .combineLatest(knowledgeGraphService.$relationships)
            .sink { [weak self] entities, relationships in
                Task { @MainActor in
                    await self?.updateVisibleData(entities: entities, relationships: relationships)
                }
            }
            .store(in: &cancellables)
        
        // Observe filter changes
        Publishers.CombineLatest4(
            $selectedEntityTypes,
            $selectedRelationshipCategories,
            $searchQuery.debounce(for: .milliseconds(300), scheduler: RunLoop.main),
            $cognitiveFilter
        )
        .sink { [weak self] entityTypes, relationshipCategories, searchQuery, cognitiveFilter in
            Task { @MainActor in
                await self?.applyFilters(
                    entityTypes: entityTypes,
                    relationshipCategories: relationshipCategories,
                    searchQuery: searchQuery.isEmpty ? nil : searchQuery,
                    cognitiveFilter: cognitiveFilter
                )
            }
        }
        .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    public func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load knowledge graph data
            await knowledgeGraphService.loadData()
            
            // Load cognitive insights if available
            if isCognitiveEnhanced {
                cognitiveInsights = try await knowledgeGraphService.getCognitiveGraphInsights()
            }
            
            // Generate fusion connections
            await generateFusionConnections()
            
        } catch {
            print("❌ [CognitiveKnowledgeGraphViewModel] Failed to load data: \(error)")
        }
    }
    
    private func updateVisibleData(entities: [Entity], relationships: [Relationship]) async {
        // Apply current filters to new data
        await applyFilters(
            entityTypes: selectedEntityTypes,
            relationshipCategories: selectedRelationshipCategories,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            cognitiveFilter: cognitiveFilter
        )
    }
    
    // MARK: - Filtering
    
    private func applyFilters(
        entityTypes: Set<EntityType>,
        relationshipCategories: Set<RelationshipCategory>,
        searchQuery: String?,
        cognitiveFilter: CognitiveFilter
    ) async {
        var filteredEntities = knowledgeGraphService.entities.filter { entity in
            // Entity type filter
            guard entityTypes.contains(entity.type) else { return false }
            
            // Search filter
            if let query = searchQuery, !query.isEmpty {
                guard entity.matches(query: query) else { return false }
            }
            
            // Cognitive filter
            switch cognitiveFilter {
            case .all:
                break
            case .cognitiveOnly:
                guard entity.hasCognitiveRepresentation else { return false }
            case .nonCognitive:
                guard !entity.hasCognitiveRepresentation else { return false }
            case .highConsolidation:
                guard entity.cognitiveConsolidationScore > 0.7 else { return false }
            case .withFusions:
                guard !entity.fusionConnectionIds.isEmpty else { return false }
            }
            
            return true
        }
        
        var filteredRelationships = knowledgeGraphService.relationships.filter { relationship in
            // Relationship category filter
            guard relationshipCategories.contains(relationship.predicateType.category) else { return false }
            
            // Ensure both entities are visible
            let subjectVisible = filteredEntities.contains { $0.id == relationship.subjectEntityId }
            let objectVisible = filteredEntities.contains { $0.id == relationship.objectEntityId }
            guard subjectVisible && objectVisible else { return false }
            
            return true
        }
        
        // Sort by cognitive enhancement and importance
        filteredEntities.sort { entity1, entity2 in
            if entity1.hasCognitiveRepresentation != entity2.hasCognitiveRepresentation {
                return entity1.hasCognitiveRepresentation
            }
            return entity1.enhancedEntityScore > entity2.enhancedEntityScore
        }
        
        filteredRelationships.sort { $0.importance > $1.importance }
        
        visibleEntities = filteredEntities
        visibleRelationships = filteredRelationships
        
        // Update fusion connections
        await generateFusionConnections()
        
        // Update layout if canvas size is set
        if canvasSize != .zero {
            updateLayout()
        }
    }
    
    // MARK: - Layout Management
    
    public func setCanvasSize(_ size: CGSize) {
        canvasSize = size
        knowledgeGraphService.setCanvasSize(size)
        updateLayout()
    }
    
    public func setLayout(_ layout: GraphLayout) {
        selectedLayout = layout
        knowledgeGraphService.setLayout(layout)
        updateLayout()
    }
    
    public func resetLayout() {
        knowledgeGraphService.resetLayout()
        updateLayout()
    }
    
    private func updateLayout() {
        // Sync positions from knowledge graph service
        for entity in visibleEntities {
            if let position = knowledgeGraphService.getNodePosition(entity.id) {
                entityPositions[entity.id] = position
            }
        }
    }
    
    // MARK: - Position Management
    
    public func getEntityPosition(_ entityId: UUID, in canvasSize: CGSize) -> CGPoint? {
        if let position = entityPositions[entityId] {
            return position
        }
        
        // Fallback to knowledge graph service
        return knowledgeGraphService.getNodePosition(entityId)
    }
    
    public func updateEntityPosition(_ entityId: UUID, offset: CGSize, in canvasSize: CGSize) {
        guard let currentPosition = getEntityPosition(entityId, in: canvasSize) else { return }
        
        let newPosition = CGPoint(
            x: max(25, min(canvasSize.width - 25, currentPosition.x + offset.x)),
            y: max(25, min(canvasSize.height - 25, currentPosition.y + offset.y))
        )
        
        entityPositions[entityId] = newPosition
        knowledgeGraphService.updateNodePosition(entityId, position: newPosition)
    }
    
    public func finalizeEntityPosition(_ entityId: UUID) {
        // Position is already updated in real-time, no additional action needed
    }
    
    // MARK: - Fusion Connections
    
    private func generateFusionConnections() async {
        var connections: [FusionConnection] = []
        
        // Group entities by fusion connection IDs
        var fusionGroups: [String: [UUID]] = [:]
        
        for entity in visibleEntities {
            for fusionId in entity.fusionConnectionIds {
                fusionGroups[fusionId, default: []].append(entity.id)
            }
        }
        
        // Create fusion connections for groups with multiple entities
        for (fusionId, entityIds) in fusionGroups {
            if entityIds.count >= 2 {
                // Calculate fusion strength based on entities involved
                let avgConsolidation = visibleEntities
                    .filter { entityIds.contains($0.id) }
                    .reduce(0.0) { $0 + $1.cognitiveConsolidationScore } / Double(entityIds.count)
                
                connections.append(FusionConnection(
                    entityIds: entityIds,
                    strength: avgConsolidation,
                    fusionNodeId: fusionId
                ))
            }
        }
        
        fusionConnections = connections.sorted { $0.strength > $1.strength }
    }
    
    // MARK: - Search and Analysis
    
    public func performCognitiveSearch(_ query: String) async {
        guard isCognitiveEnhanced else {
            // Fall back to traditional search
            searchQuery = query
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let searchResult = try await knowledgeGraphService.cognitiveSemanticSearch(query: query)
            
            // Update visible entities based on search results
            let searchEntityIds = Set(searchResult.allMatches.map { $0.id })
            
            visibleEntities = knowledgeGraphService.entities.filter { entity in
                searchEntityIds.contains(entity.id)
            }
            
            // Update relationships to only show those between visible entities
            visibleRelationships = knowledgeGraphService.relationships.filter { relationship in
                searchEntityIds.contains(relationship.subjectEntityId) &&
                searchEntityIds.contains(relationship.objectEntityId)
            }
            
            // Regenerate fusion connections
            await generateFusionConnections()
            
            // Update layout
            updateLayout()
            
        } catch {
            print("❌ [CognitiveKnowledgeGraphViewModel] Cognitive search failed: \(error)")
        }
    }
    
    public func clearSearch() {
        searchQuery = ""
        // Filters will automatically update through bindings
    }
    
    // MARK: - Entity Analysis
    
    public func getEntityConnections(_ entityId: UUID) -> [Entity] {
        return knowledgeGraphService.getConnectedEntities(to: entityId)
    }
    
    public func getEntityFusionPartners(_ entity: Entity) -> [Entity] {
        let fusionIds = Set(entity.fusionConnectionIds)
        
        return visibleEntities.filter { otherEntity in
            otherEntity.id != entity.id &&
            !Set(otherEntity.fusionConnectionIds).intersection(fusionIds).isEmpty
        }
    }
    
    // MARK: - Cognitive Layer Analysis
    
    public func getEntitiesByLayer(_ layer: CognitiveLayerType) -> [Entity] {
        return visibleEntities.filter { $0.cognitiveLayerType == layer }
    }
    
    public func getLayerConnectivity(_ layer: CognitiveLayerType) -> Double {
        let layerEntities = getEntitiesByLayer(layer)
        guard layerEntities.count > 1 else { return 0.0 }
        
        let layerEntityIds = Set(layerEntities.map { $0.id })
        let intraLayerConnections = visibleRelationships.filter { relationship in
            layerEntityIds.contains(relationship.subjectEntityId) &&
            layerEntityIds.contains(relationship.objectEntityId)
        }.count
        
        let maxPossibleConnections = layerEntities.count * (layerEntities.count - 1) / 2
        return maxPossibleConnections > 0 ? Double(intraLayerConnections) / Double(maxPossibleConnections) : 0.0
    }
    
    // MARK: - Export and Sharing
    
    public func exportGraphData() -> GraphExportData {
        return GraphExportData(
            entities: visibleEntities,
            relationships: visibleRelationships,
            fusionConnections: fusionConnections,
            cognitiveInsights: cognitiveInsights,
            layoutType: selectedLayout,
            filters: GraphFilters(
                entityTypes: selectedEntityTypes,
                relationshipCategories: selectedRelationshipCategories,
                searchQuery: searchQuery,
                cognitiveFilter: cognitiveFilter
            )
        )
    }
    
    // MARK: - Real-time Updates
    
    public func startRealTimeUpdates() {
        // Set up real-time monitoring if cognitive system supports it
        if isCognitiveEnhanced {
            Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshCognitiveInsights()
                }
            }
        }
    }
    
    private func refreshCognitiveInsights() async {
        guard isCognitiveEnhanced else { return }
        
        do {
            cognitiveInsights = try await knowledgeGraphService.getCognitiveGraphInsights()
        } catch {
            print("❌ [CognitiveKnowledgeGraphViewModel] Failed to refresh cognitive insights: \(error)")
        }
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum CognitiveFilter: String, CaseIterable {
    case all = "All Entities"
    case cognitiveOnly = "Cognitive Only"
    case nonCognitive = "Non-Cognitive"
    case highConsolidation = "High Consolidation"
    case withFusions = "With Fusions"
    
    var displayName: String {
        rawValue
    }
    
    var description: String {
        switch self {
        case .all:
            return "Show all entities regardless of cognitive status"
        case .cognitiveOnly:
            return "Show only entities with cognitive representation"
        case .nonCognitive:
            return "Show only entities without cognitive representation"
        case .highConsolidation:
            return "Show entities with consolidation score > 70%"
        case .withFusions:
            return "Show entities with fusion connections"
        }
    }
}

public enum RelationshipCategory: String, CaseIterable {
    case semantic = "Semantic"
    case temporal = "Temporal"
    case spatial = "Spatial"
    case causal = "Causal"
    case social = "Social"
    
    var displayName: String {
        rawValue
    }
}

public struct GraphFilters {
    public let entityTypes: Set<EntityType>
    public let relationshipCategories: Set<RelationshipCategory>
    public let searchQuery: String
    public let cognitiveFilter: CognitiveFilter
}

public struct GraphExportData {
    public let entities: [Entity]
    public let relationships: [Relationship]
    public let fusionConnections: [FusionConnection]
    public let cognitiveInsights: GraphCognitiveInsights?
    public let layoutType: GraphLayout
    public let filters: GraphFilters
    public let exportedAt: Date
    
    public init(
        entities: [Entity],
        relationships: [Relationship],
        fusionConnections: [FusionConnection],
        cognitiveInsights: GraphCognitiveInsights?,
        layoutType: GraphLayout,
        filters: GraphFilters
    ) {
        self.entities = entities
        self.relationships = relationships
        self.fusionConnections = fusionConnections
        self.cognitiveInsights = cognitiveInsights
        self.layoutType = layoutType
        self.filters = filters
        self.exportedAt = Date()
    }
}