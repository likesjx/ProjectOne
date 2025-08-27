//
//  IdeaNode.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  Hierarchical navigation system for the Dopamine Cognitive Design
//

import Foundation
import SwiftData
import os.log

// MARK: - IdeaNode Hierarchical System

/// Represents a hierarchical node in the idea navigation system
/// Provides tree-like organization of concepts with memory integration
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class IdeaNode {
    
    // MARK: - Identity & Hierarchy
    
    public let id: UUID
    public let createdAt: Date
    public var updatedAt: Date
    
    /// Human-readable title for this idea
    public var title: String
    
    /// Optional detailed description
    public var description: String?
    
    /// Parent node ID (nil for root nodes)
    public var parentID: UUID?
    
    /// Child node IDs for hierarchical navigation
    public var childrenIDs: [UUID]
    
    /// Hierarchical depth (0 for root, 1 for children, etc.)
    public var depth: Int
    
    /// Full path from root to this node
    public var hierarchicalPath: [String] // ["Root", "Category", "Subcategory"]
    
    // MARK: - Content & Context
    
    /// Categorization tags for filtering and grouping
    public var tags: [String]
    
    /// Content type for display and interaction optimization
    public var nodeType: IdeaNodeType
    
    /// Current status in the ideation lifecycle
    public var status: IdeaStatus
    
    /// Priority level for attention management
    public var priority: IdeaPriority
    
    // MARK: - Memory Integration
    
    /// Related memory node IDs from cognitive memory system
    public var relatedMemoryIDs: [UUID]
    
    /// Knowledge graph entity IDs related to this idea
    public var relatedEntityIDs: [UUID]
    
    /// Fusion node ID if this idea emerged from cross-layer synthesis
    public var fusionNodeID: UUID?
    
    /// Bubble-up item IDs that reference this idea
    public var bubbleUpItemIDs: [UUID]
    
    // MARK: - Navigation & Discovery
    
    /// Semantic similarity scores to other nodes (for intelligent navigation)
    public var semanticConnections: [String: Double] // nodeID: similarity
    
    /// User interaction history for personalized navigation
    public var navigationHistory: [NavigationEvent] // JSON serialized events
    
    /// Last time this node was accessed
    public var lastAccessed: Date?
    
    /// How many times this node has been visited
    public var accessCount: Int
    
    // MARK: - ADHD-Friendly Features
    
    /// Visual representation hints for consistent UI
    public var visualStyle: IdeaVisualStyle
    
    /// Estimated cognitive load for processing this node
    public var cognitiveLoad: Double
    
    /// Whether this node should be highlighted in current context
    public var isHighlighted: Bool
    
    /// Custom color for visual categorization
    public var customColor: String? // Hex color code
    
    // MARK: - Temporal Context
    
    /// Optimal dopamine windows for exploring this idea
    public var preferredExplorationWindows: [DopamineWindow]
    
    /// Time-sensitive relevance (e.g., project deadlines)
    public var relevanceWindow: DateInterval?
    
    /// Last time related content was bubbled up
    public var lastBubbleUp: Date?
    
    // MARK: - Initialization
    
    public init(title: String,
                description: String? = nil,
                parentID: UUID? = nil,
                nodeType: IdeaNodeType = .concept,
                status: IdeaStatus = .exploring,
                priority: IdeaPriority = .medium,
                tags: [String] = [],
                visualStyle: IdeaVisualStyle = .default,
                cognitiveLoad: Double = 0.5,
                preferredExplorationWindows: [DopamineWindow] = []) {
        
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.title = title
        self.description = description
        self.parentID = parentID
        self.childrenIDs = []
        self.depth = 0 // Will be calculated when added to hierarchy
        self.hierarchicalPath = [title]
        self.tags = tags
        self.nodeType = nodeType
        self.status = status
        self.priority = priority
        self.relatedMemoryIDs = []
        self.relatedEntityIDs = []
        self.fusionNodeID = nil
        self.bubbleUpItemIDs = []
        self.semanticConnections = [:]
        self.navigationHistory = []
        self.lastAccessed = nil
        self.accessCount = 0
        self.visualStyle = visualStyle
        self.cognitiveLoad = cognitiveLoad
        self.isHighlighted = false
        self.customColor = nil
        self.preferredExplorationWindows = preferredExplorationWindows.isEmpty ? 
            nodeType.defaultExplorationWindows : preferredExplorationWindows
        self.relevanceWindow = nil
        self.lastBubbleUp = nil
    }
    
    // MARK: - Hierarchy Management
    
    /// Adds a child node to this node
    public func addChild(_ childID: UUID) {
        if !childrenIDs.contains(childID) {
            childrenIDs.append(childID)
            updatedAt = Date()
        }
    }
    
    /// Removes a child node from this node
    public func removeChild(_ childID: UUID) {
        childrenIDs.removeAll { $0 == childID }
        updatedAt = Date()
    }
    
    /// Updates hierarchical information when structure changes
    public func updateHierarchicalContext(depth: Int, path: [String]) {
        self.depth = depth
        self.hierarchicalPath = path
        self.updatedAt = Date()
    }
    
    // MARK: - Navigation Tracking
    
    /// Records user navigation to this node
    public func recordAccess(context: NavigationContext) {
        lastAccessed = Date()
        accessCount += 1
        
        let event = NavigationEvent(
            type: .accessed,
            timestamp: Date(),
            context: context,
            metadata: [
                "accessCount": String(accessCount),
                "cognitiveLoad": String(cognitiveLoad)
            ]
        )
        
        navigationHistory.append(event)
        
        // Keep only recent history (last 50 events)
        if navigationHistory.count > 50 {
            navigationHistory = Array(navigationHistory.suffix(50))
        }
        
        updatedAt = Date()
    }
    
    /// Records expansion/collapse events for hierarchy navigation
    public func recordExpansion(expanded: Bool, childrenCount: Int) {
        let event = NavigationEvent(
            type: expanded ? .expanded : .collapsed,
            timestamp: Date(),
            context: NavigationContext(
                dopamineWindow: DopamineWindow.current,
                cognitiveCapacity: DopamineWindow.current.cognitiveCapacity,
                navigationPath: hierarchicalPath
            ),
            metadata: [
                "childrenCount": String(childrenCount),
                "depth": String(depth)
            ]
        )
        
        navigationHistory.append(event)
        updatedAt = Date()
    }
    
    // MARK: - Semantic Connections
    
    /// Updates semantic similarity to another node
    public func updateSemanticConnection(to nodeID: UUID, similarity: Double) {
        semanticConnections[nodeID.uuidString] = similarity
        updatedAt = Date()
    }
    
    /// Gets semantically similar nodes sorted by relevance
    public func getSemanticallySimilarNodes(threshold: Double = 0.5) -> [(UUID, Double)] {
        return semanticConnections
            .compactMap { (idString, similarity) -> (UUID, Double)? in
                guard similarity >= threshold,
                      let uuid = UUID(uuidString: idString) else { return nil }
                return (uuid, similarity)
            }
            .sorted { $0.1 > $1.1 }
    }
    
    // MARK: - Memory Integration
    
    /// Links this idea to a memory node
    public func linkToMemory(_ memoryID: UUID) {
        if !relatedMemoryIDs.contains(memoryID) {
            relatedMemoryIDs.append(memoryID)
            updatedAt = Date()
        }
    }
    
    /// Links this idea to a knowledge graph entity
    public func linkToEntity(_ entityID: UUID) {
        if !relatedEntityIDs.contains(entityID) {
            relatedEntityIDs.append(entityID)
            updatedAt = Date()
        }
    }
    
    /// Links this idea to a bubble-up item
    public func linkToBubbleUpItem(_ itemID: UUID) {
        if !bubbleUpItemIDs.contains(itemID) {
            bubbleUpItemIDs.append(itemID)
            updatedAt = Date()
        }
    }
    
    // MARK: - Context-Aware Properties
    
    /// Determines if this node should be highlighted in current context
    public func shouldHighlight(in context: NavigationContext) -> Bool {
        // Highlight if recently accessed
        if let lastAccess = lastAccessed,
           lastAccess > Date().addingTimeInterval(-3600) { // Last hour
            return true
        }
        
        // Highlight if optimal window for exploration
        if preferredExplorationWindows.contains(context.dopamineWindow) {
            return true
        }
        
        // Highlight if high priority and sufficient cognitive capacity
        if priority == .high && context.cognitiveCapacity > cognitiveLoad {
            return true
        }
        
        // Highlight if within relevance window
        if let relevanceWindow = relevanceWindow,
           relevanceWindow.contains(Date()) {
            return true
        }
        
        return false
    }
    
    /// Calculates relevance score for current context
    public func calculateRelevance(in context: NavigationContext) -> Double {
        var score: Double = 0.0
        
        // Base priority score
        score += priority.rawValue * 0.3
        
        // Recency score
        if let lastAccess = lastAccessed {
            let hoursSinceAccess = Date().timeIntervalSince(lastAccess) / 3600
            score += max(0, (24 - hoursSinceAccess) / 24) * 0.2
        }
        
        // Dopamine window alignment
        if preferredExplorationWindows.contains(context.dopamineWindow) {
            score += 0.2
        }
        
        // Cognitive load fit
        if cognitiveLoad <= context.cognitiveCapacity {
            score += 0.15
        }
        
        // Path relevance (deeper nodes get slight penalty for complexity)
        score += max(0, (5 - depth) / 10) * 0.1
        
        // Status relevance
        if status == .active || status == .implementing {
            score += 0.05
        }
        
        return min(1.0, score)
    }
}

// MARK: - Supporting Enums

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum IdeaNodeType: String, CaseIterable, Codable, Sendable {
    case concept = "concept"           // Abstract ideas and concepts
    case project = "project"           // Actionable projects
    case resource = "resource"         // Reference materials and resources
    case insight = "insight"           // Key insights and learnings
    case goal = "goal"                 // Objectives and targets
    case process = "process"           // Workflows and procedures
    case decision = "decision"         // Decision points and outcomes
    case question = "question"         // Open questions and investigations
    
    public var defaultExplorationWindows: [DopamineWindow] {
        switch self {
        case .concept, .insight:
            return [.eveningCreative, .morningPeak]
        case .project, .goal:
            return [.morningPeak, .afternoonBoost]
        case .resource, .process:
            return [.afternoonBoost, .midDayDip]
        case .decision, .question:
            return [.morningPeak, .eveningCreative]
        }
    }
    
    public var defaultCognitiveLoad: Double {
        switch self {
        case .concept, .decision, .question: return 0.7
        case .project, .goal, .insight: return 0.8
        case .resource, .process: return 0.4
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum IdeaStatus: String, CaseIterable, Codable, Sendable {
    case exploring = "exploring"       // Initial exploration phase
    case developing = "developing"     // Active development
    case active = "active"             // Currently being worked on
    case implementing = "implementing" // In implementation phase
    case completed = "completed"       // Finished/resolved
    case paused = "paused"            // Temporarily suspended
    case archived = "archived"        // Archived for future reference
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum IdeaPriority: Double, CaseIterable, Codable, Sendable {
    case low = 0.3
    case medium = 0.5
    case high = 0.8
    case critical = 1.0
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum IdeaVisualStyle: String, CaseIterable, Codable, Sendable {
    case `default` = "default"         // Standard representation
    case bubble = "bubble"             // Bubble/node visualization
    case card = "card"                 // Card-based layout
    case timeline = "timeline"         // Timeline entry
    case mindMap = "mindMap"           // Mind map node
}

// MARK: - Navigation Support Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct NavigationContext: Codable, Sendable {
    public let dopamineWindow: DopamineWindow
    public let cognitiveCapacity: Double
    public let navigationPath: [String]
    public let currentFocus: String?
    public let searchQuery: String?
    
    public init(dopamineWindow: DopamineWindow,
                cognitiveCapacity: Double,
                navigationPath: [String],
                currentFocus: String? = nil,
                searchQuery: String? = nil) {
        self.dopamineWindow = dopamineWindow
        self.cognitiveCapacity = cognitiveCapacity
        self.navigationPath = navigationPath
        self.currentFocus = currentFocus
        self.searchQuery = searchQuery
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct NavigationEvent: Codable, Sendable {
    public let type: NavigationEventType
    public let timestamp: Date
    public let context: NavigationContext
    public let metadata: [String: String]
    
    public init(type: NavigationEventType,
                timestamp: Date,
                context: NavigationContext,
                metadata: [String: String] = [:]) {
        self.type = type
        self.timestamp = timestamp
        self.context = context
        self.metadata = metadata
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum NavigationEventType: String, CaseIterable, Codable, Sendable {
    case accessed = "accessed"
    case expanded = "expanded"
    case collapsed = "collapsed"
    case edited = "edited"
    case linked = "linked"
    case tagged = "tagged"
    case prioritized = "prioritized"
}