import Foundation
import SwiftData
import SwiftUI
import Combine

/// Service for managing knowledge graph visualization, layout, and interactions
@MainActor
public final class KnowledgeGraphService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var entities: [Entity] = []
    @Published var relationships: [Relationship] = []
    @Published var filteredEntities: [Entity] = []
    @Published var filteredRelationships: [Relationship] = []
    @Published var isLoading: Bool = false
    
    // MARK: - Private Properties
    
    private let modelContext: ModelContext
    private var nodePositions: [UUID: CGPoint] = [:]
    private var canvasSize: CGSize = CGSize(width: 400, height: 400)
    private var currentLayout: GraphLayout = .force
    private nonisolated(unsafe) var layoutTimer: Timer?
    
    // MARK: - Cognitive Integration
    
    private let cognitiveAdapter: KnowledgeGraphCognitiveAdapter?
    
    // Force-directed layout parameters
    private let springConstant: Double = 0.01
    private let repulsionConstant: Double = 1000.0
    private let damping: Double = 0.9
    private let maxVelocity: Double = 5.0
    private var nodeVelocities: [UUID: CGVector] = [:]
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, cognitiveAdapter: KnowledgeGraphCognitiveAdapter? = nil) {
        self.modelContext = modelContext
        self.cognitiveAdapter = cognitiveAdapter
    }
    
    deinit {
        // Note: Cannot call MainActor methods from deinit
        // layoutTimer should be invalidated manually before deallocation
        layoutTimer?.invalidate()
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load entities
            let entityDescriptor = FetchDescriptor<Entity>(sortBy: [SortDescriptor(\.importance, order: .reverse)])
            entities = try modelContext.fetch(entityDescriptor)
            
            // Load relationships
            let relationshipDescriptor = FetchDescriptor<Relationship>(sortBy: [SortDescriptor(\.importance, order: .reverse)])
            relationships = try modelContext.fetch(relationshipDescriptor)
            
            // Initialize filtered collections
            filteredEntities = entities
            filteredRelationships = relationships
            
            // Initialize node positions
            initializeNodePositions()
            
        } catch {
            print("Failed to load knowledge graph data: \(error)")
        }
    }
    
    func updateWithNewData(entities: [Entity], relationships: [Relationship]) {
        self.entities = entities
        self.relationships = relationships
        
        // Update filtered collections
        filteredEntities = entities
        filteredRelationships = relationships
        
        // Preserve existing node positions where possible
        let existingPositions = nodePositions
        initializeNodePositions()
        
        // Restore positions for entities that still exist
        for entity in filteredEntities {
            if let existingPosition = existingPositions[entity.id] {
                nodePositions[entity.id] = existingPosition
            }
        }
        
        // If using force layout, restart the animation
        if currentLayout == .force {
            updateLayout()
        }
        
        print("🔄 [KnowledgeGraphService] Updated with \(entities.count) entities and \(relationships.count) relationships")
    }
    
    // MARK: - Filtering
    
    func applyFilters(entityTypes: Set<EntityType>, relationshipCategories: Set<RelationshipCategory>, searchQuery: String?) {
        // Filter entities
        filteredEntities = entities.filter { entity in
            // Type filter
            guard entityTypes.contains(entity.type) else { return false }
            
            // Search filter
            if let query = searchQuery, !query.isEmpty {
                return entity.matches(query: query)
            }
            
            return true
        }
        
        // Filter relationships
        filteredRelationships = relationships.filter { relationship in
            // Category filter
            guard relationshipCategories.contains(relationship.predicateType.category) else { return false }
            
            // Ensure both entities are visible
            let subjectVisible = filteredEntities.contains { $0.id == relationship.subjectEntityId }
            let objectVisible = filteredEntities.contains { $0.id == relationship.objectEntityId }
            guard subjectVisible && objectVisible else { return false }
            
            // Search filter
            if let query = searchQuery, !query.isEmpty {
                return relationship.matches(query: query)
            }
            
            return true
        }
        
        // Update layout for filtered data
        updateLayout()
    }
    
    // MARK: - Layout Management
    
    func setCanvasSize(_ size: CGSize) {
        canvasSize = size
        updateLayout()
    }
    
    func setLayout(_ layout: GraphLayout) {
        currentLayout = layout
        updateLayout()
    }
    
    func resetLayout() {
        initializeNodePositions()
        updateLayout()
    }
    
    func stopLayout() {
        layoutTimer?.invalidate()
        layoutTimer = nil
    }
    
    private func initializeNodePositions() {
        nodePositions.removeAll()
        nodeVelocities.removeAll()
        
        switch currentLayout {
        case .force:
            initializeRandomPositions()
        case .circular:
            initializeCircularLayout()
        case .hierarchical:
            initializeHierarchicalLayout()
        case .radial:
            initializeRadialLayout()
        }
    }
    
    private func updateLayout() {
        stopLayout() // Clean up any existing timer first
        
        switch currentLayout {
        case .force:
            startForceDirectedLayout()
        case .circular:
            layoutCircular()
        case .hierarchical:
            layoutHierarchical()
        case .radial:
            layoutRadial()
        }
    }
    
    // MARK: - Force-Directed Layout
    
    private func initializeRandomPositions() {
        let margin: CGFloat = 50
        let width = canvasSize.width - 2 * margin
        let height = canvasSize.height - 2 * margin
        
        for entity in filteredEntities {
            let x = margin + CGFloat.random(in: 0...width)
            let y = margin + CGFloat.random(in: 0...height)
            nodePositions[entity.id] = CGPoint(x: x, y: y)
            nodeVelocities[entity.id] = CGVector(dx: 0, dy: 0)
        }
    }
    
    private func startForceDirectedLayout() {
        layoutTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            // Use DispatchQueue.main.async instead of Task { @MainActor } to avoid dispatch queue assertion failures
            DispatchQueue.main.async {
                self?.updateForceDirectedLayout()
            }
        }
        // Ensure timer runs on main RunLoop to avoid dispatch queue assertion failures
        if let timer = layoutTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func updateForceDirectedLayout() {
        var newVelocities: [UUID: CGVector] = [:]
        
        for entity in filteredEntities {
            guard let position = nodePositions[entity.id],
                  let velocity = nodeVelocities[entity.id] else { continue }
            
            var force = CGVector(dx: 0, dy: 0)
            
            // Repulsion forces between all nodes
            for otherEntity in filteredEntities {
                guard otherEntity.id != entity.id,
                      let otherPosition = nodePositions[otherEntity.id] else { continue }
                
                let dx = position.x - otherPosition.x
                let dy = position.y - otherPosition.y
                let distance = max(1.0, sqrt(dx * dx + dy * dy))
                
                let repulsionForce = repulsionConstant / (distance * distance)
                force.dx += (dx / distance) * repulsionForce
                force.dy += (dy / distance) * repulsionForce
            }
            
            // Attraction forces for connected nodes
            for relationship in filteredRelationships {
                var connectedEntityId: UUID?
                
                if relationship.subjectEntityId == entity.id {
                    connectedEntityId = relationship.objectEntityId
                } else if relationship.objectEntityId == entity.id {
                    connectedEntityId = relationship.subjectEntityId
                }
                
                guard let connectedId = connectedEntityId,
                      let connectedPosition = nodePositions[connectedId] else { continue }
                
                let dx = connectedPosition.x - position.x
                let dy = connectedPosition.y - position.y
                let distance = max(1.0, sqrt(dx * dx + dy * dy))
                
                let springForce = springConstant * (distance - 100) // Ideal distance: 100
                force.dx += (dx / distance) * springForce
                force.dy += (dy / distance) * springForce
            }
            
            // Update velocity with damping
            let newVelocity = CGVector(
                dx: (velocity.dx + force.dx) * damping,
                dy: (velocity.dy + force.dy) * damping
            )
            
            // Limit velocity
            let speed = sqrt(newVelocity.dx * newVelocity.dx + newVelocity.dy * newVelocity.dy)
            if speed > maxVelocity {
                newVelocities[entity.id] = CGVector(
                    dx: newVelocity.dx * maxVelocity / speed,
                    dy: newVelocity.dy * maxVelocity / speed
                )
            } else {
                newVelocities[entity.id] = newVelocity
            }
        }
        
        // Apply velocities to positions
        for entity in filteredEntities {
            guard let velocity = newVelocities[entity.id],
                  let position = nodePositions[entity.id] else { continue }
            
            let newPosition = CGPoint(
                x: max(25, min(canvasSize.width - 25, position.x + velocity.dx)),
                y: max(25, min(canvasSize.height - 25, position.y + velocity.dy))
            )
            
            nodePositions[entity.id] = newPosition
        }
        
        nodeVelocities = newVelocities
        
        // Stop layout if converged
        let totalEnergy = newVelocities.values.reduce(0) { total, velocity in
            total + sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        }
        
        if totalEnergy < 0.1 {
            stopLayout()
        }
    }
    
    // MARK: - Circular Layout
    
    private func initializeCircularLayout() {
        layoutCircular()
    }
    
    private func layoutCircular() {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let radius = min(canvasSize.width, canvasSize.height) * 0.35
        
        for (index, entity) in filteredEntities.enumerated() {
            let angle = 2 * Double.pi * Double(index) / Double(filteredEntities.count)
            let x = center.x + radius * CoreGraphics.cos(angle)
            let y = center.y + radius * CoreGraphics.sin(angle)
            nodePositions[entity.id] = CGPoint(x: x, y: y)
        }
    }
    
    // MARK: - Hierarchical Layout
    
    private func initializeHierarchicalLayout() {
        layoutHierarchical()
    }
    
    private func layoutHierarchical() {
        // Group entities by type for hierarchical arrangement
        let entityGroups = Dictionary(grouping: filteredEntities) { $0.type }
        let groupHeight = canvasSize.height / CGFloat(entityGroups.count)
        
        for (groupIndex, (_, entitiesInGroup)) in entityGroups.enumerated() {
            let y = CGFloat(groupIndex) * groupHeight + groupHeight / 2
            let spacing = canvasSize.width / CGFloat(entitiesInGroup.count + 1)
            
            for (entityIndex, entity) in entitiesInGroup.enumerated() {
                let x = CGFloat(entityIndex + 1) * spacing
                nodePositions[entity.id] = CGPoint(x: x, y: y)
            }
        }
    }
    
    // MARK: - Radial Layout
    
    private func initializeRadialLayout() {
        layoutRadial()
    }
    
    private func layoutRadial() {
        // Find the most connected entity as center
        let connectionCounts = filteredEntities.map { entity in
            let connections = filteredRelationships.filter {
                $0.subjectEntityId == entity.id || $0.objectEntityId == entity.id
            }.count
            return (entity, connections)
        }
        
        guard let centerEntity = connectionCounts.max(by: { $0.1 < $1.1 })?.0 else { return }
        
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        nodePositions[centerEntity.id] = center
        
        // Arrange other entities in concentric circles
        let otherEntities = filteredEntities.filter { $0.id != centerEntity.id }
        let entitiesPerRing = 8
        
        for (index, entity) in otherEntities.enumerated() {
            let ring = index / entitiesPerRing
            let positionInRing = index % entitiesPerRing
            let radius = CGFloat(ring + 1) * 80
            
            let angle = 2 * Double.pi * Double(positionInRing) / Double(min(entitiesPerRing, otherEntities.count - ring * entitiesPerRing))
            let x = center.x + radius * CoreGraphics.cos(angle)
            let y = center.y + radius * CoreGraphics.sin(angle)
            
            nodePositions[entity.id] = CGPoint(x: x, y: y)
        }
    }
    
    // MARK: - Position Management
    
    func getNodePosition(_ nodeId: UUID) -> CGPoint? {
        return nodePositions[nodeId]
    }
    
    func updateNodePosition(_ nodeId: UUID, position: CGPoint) {
        nodePositions[nodeId] = position
        nodeVelocities[nodeId] = CGVector(dx: 0, dy: 0) // Reset velocity on manual move
    }
    
    func getEntity(_ entityId: UUID) -> Entity? {
        return filteredEntities.first { $0.id == entityId }
    }
    
    // MARK: - Graph Analysis
    
    func getConnectedEntities(to entityId: UUID) -> [Entity] {
        let connectedIds = filteredRelationships.compactMap { relationship -> UUID? in
            if relationship.subjectEntityId == entityId {
                return relationship.objectEntityId
            } else if relationship.objectEntityId == entityId {
                return relationship.subjectEntityId
            }
            return nil
        }
        
        return filteredEntities.filter { connectedIds.contains($0.id) }
    }
    
    func getRelationshipsBetween(entity1: UUID, entity2: UUID) -> [Relationship] {
        return filteredRelationships.filter { relationship in
            (relationship.subjectEntityId == entity1 && relationship.objectEntityId == entity2) ||
            (relationship.subjectEntityId == entity2 && relationship.objectEntityId == entity1)
        }
    }
    
    func calculateGraphMetrics() -> GraphMetrics {
        let nodeCount = filteredEntities.count
        let edgeCount = filteredRelationships.count
        
        // Calculate average degree
        let totalDegree = filteredEntities.reduce(0) { total, entity in
            let degree = filteredRelationships.filter {
                $0.subjectEntityId == entity.id || $0.objectEntityId == entity.id
            }.count
            return total + degree
        }
        let averageDegree = nodeCount > 0 ? Double(totalDegree) / Double(nodeCount) : 0
        
        // Calculate density
        let maxPossibleEdges = nodeCount * (nodeCount - 1) / 2
        let density = maxPossibleEdges > 0 ? Double(edgeCount) / Double(maxPossibleEdges) : 0
        
        return GraphMetrics(
            nodeCount: nodeCount,
            edgeCount: edgeCount,
            averageDegree: averageDegree,
            density: density
        )
    }
}

// MARK: - Supporting Types

struct GraphMetrics {
    let nodeCount: Int
    let edgeCount: Int
    let averageDegree: Double
    let density: Double
}

// MARK: - Graph Search

extension KnowledgeGraphService {
    func findShortestPath(from startId: UUID, to endId: UUID) -> [UUID]? {
        var visited: Set<UUID> = []
        var queue: [(UUID, [UUID])] = [(startId, [startId])]
        
        while !queue.isEmpty {
            let (currentId, path) = queue.removeFirst()
            
            if currentId == endId {
                return path
            }
            
            if visited.contains(currentId) {
                continue
            }
            
            visited.insert(currentId)
            
            // Get connected entities
            let connectedIds = filteredRelationships.compactMap { relationship -> UUID? in
                if relationship.subjectEntityId == currentId {
                    return relationship.objectEntityId
                } else if relationship.objectEntityId == currentId {
                    return relationship.subjectEntityId
                }
                return nil
            }
            
            for connectedId in connectedIds {
                if !visited.contains(connectedId) {
                    queue.append((connectedId, path + [connectedId]))
                }
            }
        }
        
        return nil
    }
    
    func findClusters() -> [[Entity]] {
        var visited: Set<UUID> = []
        var clusters: [[Entity]] = []
        
        for entity in filteredEntities {
            if !visited.contains(entity.id) {
                let cluster = findConnectedComponent(startingFrom: entity.id, visited: &visited)
                if !cluster.isEmpty {
                    clusters.append(cluster)
                }
            }
        }
        
        return clusters
    }
    
    private func findConnectedComponent(startingFrom entityId: UUID, visited: inout Set<UUID>) -> [Entity] {
        var component: [Entity] = []
        var stack: [UUID] = [entityId]
        
        while !stack.isEmpty {
            let currentId = stack.removeLast()
            
            if visited.contains(currentId) {
                continue
            }
            
            visited.insert(currentId)
            
            if let entity = getEntity(currentId) {
                component.append(entity)
            }
            
            // Add connected entities to stack
            let connectedIds = filteredRelationships.compactMap { relationship -> UUID? in
                if relationship.subjectEntityId == currentId {
                    return relationship.objectEntityId
                } else if relationship.objectEntityId == currentId {
                    return relationship.subjectEntityId
                }
                return nil
            }
            
            for connectedId in connectedIds {
                if !visited.contains(connectedId) {
                    stack.append(connectedId)
                }
            }
        }
        
        return component
    }
}

// MARK: - Cognitive Search Integration

extension KnowledgeGraphService {
    
    /// Perform cognitive-enhanced semantic search for entities
    func cognitiveSemanticSearch(
        query: String,
        limit: Int = 10,
        includeTraditionalSearch: Bool = true
    ) async throws -> CognitiveSearchResult {
        guard let cognitiveAdapter = cognitiveAdapter else {
            // Fallback to traditional search
            return CognitiveSearchResult(
                query: query,
                cognitiveMatches: [],
                traditionalMatches: includeTraditionalSearch ? performTraditionalSearch(query: query, limit: limit) : [],
                totalResults: 0,
                cognitiveEnhanced: false
            )
        }
        
        // Perform cognitive semantic search
        let cognitiveMatches = try await cognitiveAdapter.findSimilarEntities(
            query: query,
            limit: limit,
            threshold: 0.3
        )
        
        // Perform traditional search if requested
        var traditionalMatches: [Entity] = []
        if includeTraditionalSearch {
            traditionalMatches = performTraditionalSearch(query: query, limit: limit)
        }
        
        // Combine and deduplicate results
        let combinedResults = combineSearchResults(
            cognitiveMatches: cognitiveMatches,
            traditionalMatches: traditionalMatches
        )
        
        return CognitiveSearchResult(
            query: query,
            cognitiveMatches: cognitiveMatches,
            traditionalMatches: traditionalMatches,
            totalResults: combinedResults.count,
            cognitiveEnhanced: true
        )
    }
    
    /// Sync entities with cognitive system
    func syncWithCognitiveSystem() async throws {
        guard let cognitiveAdapter = cognitiveAdapter else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Sync all entities to cognitive layers
            try await cognitiveAdapter.syncEntitiesToCognitive(entities)
            
            // Update entity importance scores from cognitive consolidation
            await updateEntityImportanceFromCognitive()
            
            // Create new relationships from fusion connections
            try await updateRelationshipsFromFusions()
            
            print("🧠 [KnowledgeGraphService] Synchronized \(entities.count) entities with cognitive system")
            
        } catch {
            print("❌ [KnowledgeGraphService] Cognitive sync failed: \(error)")
            throw error
        }
    }
    
    /// Find entities that need cognitive synchronization
    func findEntitiesNeedingCognitiveSync() -> [Entity] {
        return entities.filter { entity in
            entity.needsCognitiveSync()
        }
    }
    
    /// Get cognitive insights for the knowledge graph
    func getCognitiveGraphInsights() async throws -> GraphCognitiveInsights {
        guard let cognitiveAdapter = cognitiveAdapter else {
            return GraphCognitiveInsights(
                totalEntities: entities.count,
                cognitivelyEnhancedEntities: 0,
                fusionConnections: 0,
                averageCognitiveScore: 0.0,
                layerDistribution: [:],
                insights: ["Cognitive integration not available"]
            )
        }
        
        let enhancedEntities = entities.filter { $0.hasCognitiveRepresentation }
        let fusionConnectionCount = entities.reduce(0) { total, entity in
            total + entity.fusionConnectionIds.count
        }
        
        let averageScore = enhancedEntities.isEmpty ? 0.0 :
            enhancedEntities.reduce(0.0) { $0 + $1.cognitiveConsolidationScore } / Double(enhancedEntities.count)
        
        // Calculate layer distribution
        var layerDistribution: [CognitiveLayerType: Int] = [:]
        for entity in enhancedEntities {
            if let layerType = entity.cognitiveLayerType {
                layerDistribution[layerType, default: 0] += 1
            }
        }
        
        // Generate insights
        var insights: [String] = []
        
        if enhancedEntities.count > entities.count / 2 {
            insights.append("Over half of entities have cognitive representation")
        }
        
        if averageScore > 0.7 {
            insights.append("High cognitive consolidation scores indicate strong memory integration")
        }
        
        if fusionConnectionCount > 0 {
            insights.append("\(fusionConnectionCount) fusion connections create cross-layer relationships")
        }
        
        if layerDistribution[.semantic, default: 0] > layerDistribution[.veridical, default: 0] {
            insights.append("Semantic layer dominance suggests conceptual knowledge focus")
        }
        
        if insights.isEmpty {
            insights.append("Knowledge graph shows basic cognitive integration")
        }
        
        return GraphCognitiveInsights(
            totalEntities: entities.count,
            cognitivelyEnhancedEntities: enhancedEntities.count,
            fusionConnections: fusionConnectionCount,
            averageCognitiveScore: averageScore,
            layerDistribution: layerDistribution,
            insights: insights
        )
    }
    
    // MARK: - Private Cognitive Methods
    
    private func performTraditionalSearch(query: String, limit: Int) -> [Entity] {
        let lowercaseQuery = query.lowercased()
        
        return entities.filter { entity in
            entity.matches(query: query)
        }.sorted { entity1, entity2 in
            // Score by relevance (name match > description match > tag match)
            let score1 = calculateTraditionalSearchScore(entity: entity1, query: lowercaseQuery)
            let score2 = calculateTraditionalSearchScore(entity: entity2, query: lowercaseQuery)
            return score1 > score2
        }.prefix(limit).map { $0 }
    }
    
    private func calculateTraditionalSearchScore(entity: Entity, query: String) -> Double {
        var score = 0.0
        
        if entity.name.lowercased().contains(query) {
            score += 1.0
        }
        
        if let description = entity.entityDescription,
           description.lowercased().contains(query) {
            score += 0.7
        }
        
        if entity.tags.contains(where: { $0.lowercased().contains(query) }) {
            score += 0.5
        }
        
        if entity.aliases.contains(where: { $0.lowercased().contains(query) }) {
            score += 0.8
        }
        
        return score
    }
    
    private func combineSearchResults(
        cognitiveMatches: [EntityCognitiveMatch],
        traditionalMatches: [Entity]
    ) -> [Entity] {
        var combinedResults: [Entity] = []
        var seenEntityIds: Set<UUID> = []
        
        // Add cognitive matches first (higher priority)
        for match in cognitiveMatches {
            if !seenEntityIds.contains(match.entity.id) {
                combinedResults.append(match.entity)
                seenEntityIds.insert(match.entity.id)
            }
        }
        
        // Add traditional matches that weren't already included
        for entity in traditionalMatches {
            if !seenEntityIds.contains(entity.id) {
                combinedResults.append(entity)
                seenEntityIds.insert(entity.id)
            }
        }
        
        return combinedResults
    }
    
    private func updateEntityImportanceFromCognitive() async {
        for entity in entities {
            if entity.hasCognitiveRepresentation {
                // Update importance based on cognitive consolidation
                let enhancedImportance = entity.enhancedEntityScore
                entity.importance = max(entity.importance, enhancedImportance)
            }
        }
    }
    
    private func updateRelationshipsFromFusions() async throws {
        guard let cognitiveAdapter = cognitiveAdapter else { return }
        
        // This would need to be implemented to get fusion nodes from cognitive system
        // For now, we'll implement a placeholder that updates existing relationships
        // with fusion-based importance scores
        
        for relationship in relationships {
            if let subjectEntity = entities.first(where: { $0.id == relationship.subjectEntityId }),
               let objectEntity = entities.first(where: { $0.id == relationship.objectEntityId }) {
                
                // Check if both entities have fusion connections
                let sharedFusions = Set(subjectEntity.fusionConnectionIds)
                    .intersection(Set(objectEntity.fusionConnectionIds))
                
                if !sharedFusions.isEmpty {
                    relationship.importance = min(1.0, relationship.importance + 0.2)
                }
            }
        }
    }
}

// MARK: - Supporting Types for Cognitive Search

public struct CognitiveSearchResult {
    public let query: String
    public let cognitiveMatches: [EntityCognitiveMatch]
    public let traditionalMatches: [Entity]
    public let totalResults: Int
    public let cognitiveEnhanced: Bool
    
    public var allMatches: [Entity] {
        var results = cognitiveMatches.map { $0.entity }
        let cognitiveEntityIds = Set(results.map { $0.id })
        
        // Add traditional matches that aren't already in cognitive results
        for entity in traditionalMatches {
            if !cognitiveEntityIds.contains(entity.id) {
                results.append(entity)
            }
        }
        
        return results
    }
}

public struct GraphCognitiveInsights {
    public let totalEntities: Int
    public let cognitivelyEnhancedEntities: Int
    public let fusionConnections: Int
    public let averageCognitiveScore: Double
    public let layerDistribution: [CognitiveLayerType: Int]
    public let insights: [String]
    
    public var enhancementPercentage: Double {
        return totalEntities > 0 ? Double(cognitivelyEnhancedEntities) / Double(totalEntities) * 100 : 0
    }
}