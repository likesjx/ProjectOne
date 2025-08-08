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
    private var layoutTimer: Timer?
    
    // Force-directed layout parameters
    private let springConstant: Double = 0.01
    private let repulsionConstant: Double = 1000.0
    private let damping: Double = 0.9
    private let maxVelocity: Double = 5.0
    private var nodeVelocities: [UUID: CGVector] = [:]
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    deinit {
        // Note: Cannot call MainActor methods from deinit
        // layoutTimer should be invalidated manually before deallocation
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
        layoutTimer?.invalidate()
        
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
            Task { @MainActor [weak self] in
                self?.updateForceDirectedLayout()
            }
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
            layoutTimer?.invalidate()
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