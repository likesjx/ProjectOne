//
//  BubbleUpItem.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  Core Bubble-Up item for the Dopamine Cognitive Design system
//

import Foundation
import SwiftData
import os.log

// MARK: - Dopamine Wave Context

/// Represents the five cognitive windows in the dopamine cycle
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum DopamineWindow: String, CaseIterable, Codable, Sendable {
    case morningPeak = "morning_peak"
    case midDayDip = "midday_dip"
    case afternoonBoost = "afternoon_boost"
    case eveningCreative = "evening_creative"
    case nightRest = "night_rest"
    
    /// Gets the current dopamine window based on time of day
    public static var current: DopamineWindow {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<10: return .morningPeak
        case 10..<14: return .midDayDip
        case 14..<18: return .afternoonBoost
        case 18..<22: return .eveningCreative
        default: return .nightRest
        }
    }
    
    /// Cognitive capacity for this window (0.0 to 1.0)
    public var cognitiveCapacity: Double {
        switch self {
        case .morningPeak: return 0.9
        case .midDayDip: return 0.4
        case .afternoonBoost: return 0.8
        case .eveningCreative: return 0.7
        case .nightRest: return 0.2
        }
    }
    
    /// Optimal task types for this window
    public var optimalTaskTypes: [BubbleUpTaskType] {
        switch self {
        case .morningPeak: return [.focus, .planning]
        case .midDayDip: return [.routine, .maintenance]
        case .afternoonBoost: return [.action, .implementation]
        case .eveningCreative: return [.creative, .reflection]
        case .nightRest: return [.preparation, .review]
        }
    }
}

// MARK: - Task Classification

/// Types of tasks that bubble up based on cognitive requirements
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum BubbleUpTaskType: String, CaseIterable, Codable, Sendable {
    case focus = "focus"           // Deep work requiring high cognitive load
    case planning = "planning"     // Strategic thinking and organization
    case routine = "routine"       // Habitual tasks with low cognitive load
    case maintenance = "maintenance" // System upkeep and administration
    case action = "action"         // Implementation and execution
    case implementation = "implementation" // Building and creating
    case creative = "creative"     // Innovation and ideation
    case reflection = "reflection" // Analysis and learning
    case preparation = "preparation" // Setting up for future tasks
    case review = "review"         // Evaluation and assessment
}

// MARK: - Priority Scoring

/// Context-aware priority scoring system
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct BubbleUpPriority: Codable, Sendable {
    /// Base importance score (0.0 to 1.0)
    public let baseImportance: Double
    
    /// Recency multiplier based on creation/due dates
    public let recencyScore: Double
    
    /// Context match score for current dopamine window
    public let contextMatchScore: Double
    
    /// ADHD-friendly urgency indicator
    public let adhdUrgency: Double
    
    /// Final computed priority score
    public var finalScore: Double {
        let weighted = (baseImportance * 0.4) + 
                      (recencyScore * 0.2) + 
                      (contextMatchScore * 0.3) + 
                      (adhdUrgency * 0.1)
        return min(1.0, weighted)
    }
}

// MARK: - Orchestrator Context

/// Context information for the orchestrator to make bubble-up decisions
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct OrchestratorContext: Sendable {
    public let currentWindow: DopamineWindow
    public let cognitiveCapacity: Double
    public let currentFocus: String?
    public let recentlyCompleted: [String]
    public let userPreferences: [String: String]
    public let environmentalFactors: [String: Double] // stress, energy, etc.
    
    public init(currentWindow: DopamineWindow = .current,
                cognitiveCapacity: Double? = nil,
                currentFocus: String? = nil,
                recentlyCompleted: [String] = [],
                userPreferences: [String: String] = [:],
                environmentalFactors: [String: Double] = [:]) {
        self.currentWindow = currentWindow
        self.cognitiveCapacity = cognitiveCapacity ?? currentWindow.cognitiveCapacity
        self.currentFocus = currentFocus
        self.recentlyCompleted = recentlyCompleted
        self.userPreferences = userPreferences
        self.environmentalFactors = environmentalFactors
    }
}

// MARK: - Core Bubble Up Item

/// Core bubble-up item that surfaces at appropriate dopamine windows
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class BubbleUpItem {
    
    // MARK: - Identity
    
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    
    // MARK: - Core Content
    
    /// Human-readable content or action description
    public var content: String
    
    /// Categorization tags for filtering and grouping
    public var tags: [String]
    
    /// Task type for cognitive window matching
    public var taskType: BubbleUpTaskType
    
    // MARK: - Temporal Context
    
    /// When this item should be considered for bubbling up
    public var dueWindow: DateInterval?
    
    /// Specific dopamine windows this item is optimal for
    public var preferredWindows: [DopamineWindow]
    
    /// When this item was last surfaced to the user
    public var lastSurfaced: Date?
    
    /// How many times this has been surfaced
    public var surfaceCount: Int
    
    // MARK: - Priority & Relevance
    
    /// Priority scoring for bubble-up decisions
    public var priority: BubbleUpPriority
    
    /// User engagement history (dismissed, completed, snoozed)
    public var engagementHistory: [String] // JSON serialized engagement events
    
    // MARK: - Memory Integration
    
    /// Related memory node IDs from the cognitive memory system
    public var relatedMemoryIDs: [UUID]
    
    /// Knowledge graph entity IDs related to this item
    public var relatedEntityIDs: [UUID]
    
    /// Fusion node ID if this item emerged from cross-layer synthesis
    public var fusionNodeID: UUID?
    
    /// Source thought ID if this bubble-up item was created from a specific thought
    public var sourceThoughtID: UUID?
    
    /// Source entity ID if this bubble-up item was created from a knowledge graph entity
    public var sourceEntityID: UUID?
    
    // MARK: - Cognitive Metadata & AI-Driven Importance
    
    /// AI-generated cognitive metadata for importance evaluation
    public var cognitiveMetadata: CognitiveMetadata
    
    /// Dynamic evaluation script for runtime importance calculation
    public var dynamicEvaluationScript: String?
    
    /// Cached evaluation results to avoid repeated computation
    private var cachedEvaluationResult: EvaluationResult?
    private var lastEvaluationContext: String?
    
    // MARK: - Privacy & Context
    
    /// Privacy sensitivity level from PrivacyAnalyzer
    public var privacySensitivity: Double
    
    /// Whether this item requires private-only processing
    public var requiresLocalProcessing: Bool
    
    /// Context matching function for orchestrator decisions
    /// TODO(human): Implement the context matching logic
    /// This should evaluate whether this BubbleUpItem should surface
    /// given the current OrchestratorContext (time, capacity, focus, etc.)
    public func contextMatch(_ context: OrchestratorContext) -> Bool {
        // TODO(human): Add implementation here
        return true
    }
    
    // MARK: - Initialization
    
    public init(content: String,
                tags: [String] = [],
                taskType: BubbleUpTaskType = .routine,
                dueWindow: DateInterval? = nil,
                preferredWindows: [DopamineWindow] = [],
                priority: BubbleUpPriority,
                relatedMemoryIDs: [UUID] = [],
                relatedEntityIDs: [UUID] = [],
                fusionNodeID: UUID? = nil,
                sourceThoughtID: UUID? = nil,
                sourceEntityID: UUID? = nil,
                cognitiveMetadata: CognitiveMetadata? = nil,
                dynamicEvaluationScript: String? = nil,
                privacySensitivity: Double = 0.5,
                requiresLocalProcessing: Bool = false) {
        
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.content = content
        self.tags = tags
        self.taskType = taskType
        self.dueWindow = dueWindow
        self.preferredWindows = preferredWindows.isEmpty ? taskType.defaultWindows : preferredWindows
        self.lastSurfaced = nil
        self.surfaceCount = 0
        self.priority = priority
        self.engagementHistory = []
        self.relatedMemoryIDs = relatedMemoryIDs
        self.relatedEntityIDs = relatedEntityIDs
        self.fusionNodeID = fusionNodeID
        self.sourceThoughtID = sourceThoughtID
        self.sourceEntityID = sourceEntityID
        self.cognitiveMetadata = cognitiveMetadata ?? CognitiveMetadata.defaultMetadata(for: taskType)
        self.dynamicEvaluationScript = dynamicEvaluationScript
        self.cachedEvaluationResult = nil
        self.lastEvaluationContext = nil
        self.privacySensitivity = privacySensitivity
        self.requiresLocalProcessing = requiresLocalProcessing
    }
    
    // MARK: - State Management
    
    /// Updates the last surfaced time and increments surface count
    public func markSurfaced() {
        lastSurfaced = Date()
        surfaceCount += 1
        updatedAt = Date()
    }
    
    /// Records user engagement with this item
    public func recordEngagement(_ type: EngagementType, metadata: [String: Any] = [:]) {
        let engagement = EngagementEvent(
            type: type,
            timestamp: Date(),
            metadata: metadata
        )
        
        if var history = try? JSONDecoder().decode([EngagementEvent].self, 
                                                 from: Data(engagementHistory.joined().utf8)) {
            history.append(engagement)
            if let encoded = try? JSONEncoder().encode(history),
               let jsonString = String(data: encoded, encoding: .utf8) {
                engagementHistory = [jsonString]
            }
        } else {
            if let encoded = try? JSONEncoder().encode([engagement]),
               let jsonString = String(data: encoded, encoding: .utf8) {
                engagementHistory = [jsonString]
            }
        }
        
        updatedAt = Date()
    }
    
    // MARK: - Cognitive Evaluation
    
    /// Evaluates importance using AI-driven metadata and optional dynamic scripts
    public func evaluateImportance(context: OrchestratorContext) async throws -> Double {
        let contextKey = generateContextKey(context)
        
        // Return cached result if context hasn't changed
        if let cached = cachedEvaluationResult,
           lastEvaluationContext == contextKey,
           cached.timestamp > Date().addingTimeInterval(-300) { // 5-minute cache
            return cached.importanceScore
        }
        
        var importanceScore = priority.finalScore
        
        // Apply cognitive metadata factors
        importanceScore = applyCognitiveFactors(baseScore: importanceScore, context: context)
        
        // Apply dynamic script evaluation if available
        if let script = dynamicEvaluationScript {
            importanceScore = try await evaluateDynamicScript(script, baseScore: importanceScore, context: context)
        }
        
        // Cache the result
        cachedEvaluationResult = EvaluationResult(
            importanceScore: importanceScore,
            timestamp: Date(),
            contextFactors: extractContextFactors(context)
        )
        lastEvaluationContext = contextKey
        
        return importanceScore
    }
    
    /// Updates cognitive metadata from AI model analysis
    @MainActor
    public func updateCognitiveMetadata(_ newMetadata: CognitiveMetadata) {
        cognitiveMetadata = newMetadata
        cachedEvaluationResult = nil // Invalidate cache
        updatedAt = Date()
    }
    
    /// Updates the dynamic evaluation script
    public func updateDynamicScript(_ script: String?) {
        dynamicEvaluationScript = script
        cachedEvaluationResult = nil // Invalidate cache
        updatedAt = Date()
    }
    
    // MARK: - Private Evaluation Methods
    
    private func applyCognitiveFactors(baseScore: Double, context: OrchestratorContext) -> Double {
        var score = baseScore
        
        // Apply emotional relevance
        score *= (1.0 + cognitiveMetadata.emotionalRelevance * 0.3)
        
        // Apply attention capture factors
        if cognitiveMetadata.attentionCaptureFactors.contains(.novelty) {
            score *= 1.2
        }
        if cognitiveMetadata.attentionCaptureFactors.contains(.urgency) {
            score *= 1.15
        }
        if cognitiveMetadata.attentionCaptureFactors.contains(.relevance) {
            score *= 1.1
        }
        
        // Apply cognitive load considerations
        let capacityFit = max(0, 1.0 - abs(cognitiveMetadata.requiredCognitiveLoad - context.cognitiveCapacity))
        score *= (0.7 + capacityFit * 0.3)
        
        // Apply dopamine triggers
        let triggerMultiplier = cognitiveMetadata.dopamineTriggers.reduce(1.0) { result, trigger in
            result * trigger.multiplier(for: context.currentWindow)
        }
        score *= triggerMultiplier
        
        // CRITICAL: Apply time-based urgency acceleration
        score = applyTimeSensitivityUrgency(score: score, context: context)
        
        // CRITICAL: Apply location-based urgency acceleration
        score = applyLocationBasedUrgency(score: score, context: context)
        
        return min(1.0, score)
    }
    
    /// Applies time-based urgency that accelerates bubble-up for time-sensitive items
    private func applyTimeSensitivityUrgency(score: Double, context: OrchestratorContext) -> Double {
        var adjustedScore = score
        let timeSensitivity = cognitiveMetadata.timeSensitivity
        let now = Date()
        
        // Check critical time windows - these get MASSIVE priority boosts
        for criticalWindow in timeSensitivity.criticalTimeWindows {
            if criticalWindow.contains(now) {
                // We're IN a critical window - this should bubble up immediately
                adjustedScore *= 2.5
                break
            } else if criticalWindow.start > now {
                // Approaching a critical window - urgency increases as we get closer
                let timeToWindow = criticalWindow.start.timeIntervalSince(now)
                let hoursToWindow = timeToWindow / 3600
                
                if hoursToWindow <= 24 {
                    // Within 24 hours - significant urgency boost
                    let proximityMultiplier = max(1.2, 2.0 - (hoursToWindow / 24))
                    adjustedScore *= proximityMultiplier
                } else if hoursToWindow <= 168 { // Within a week
                    // Within a week - moderate urgency boost
                    let proximityMultiplier = 1.0 + (0.3 * (168 - hoursToWindow) / 168)
                    adjustedScore *= proximityMultiplier
                }
            }
        }
        
        // Apply urgency pattern-specific calculations
        switch timeSensitivity.urgencyPattern {
        case .exponential:
            // Exponential urgency growth as we approach deadlines
            let timeSinceCreation = now.timeIntervalSince(createdAt)
            let exponentialMultiplier = 1.0 + (timeSinceCreation * timeSensitivity.timeDecayFactor * 0.001)
            adjustedScore *= min(2.0, exponentialMultiplier) // Cap at 2x
            
        case .deadlineBased:
            // Deadline pressure - get increasingly urgent as deadlines approach
            if let dueWindow = dueWindow {
                let timeToDeadline = dueWindow.end.timeIntervalSince(now)
                if timeToDeadline > 0 && timeToDeadline <= 86400 { // Within 24 hours
                    let deadlineMultiplier = 1.5 + (1.0 - timeToDeadline / 86400)
                    adjustedScore *= deadlineMultiplier
                }
            }
            
        case .periodic:
            // Check recurring patterns for time-sensitive activation
            for pattern in timeSensitivity.recurringPatterns {
                if isWithinRecurrenceWindow(pattern, at: now) {
                    adjustedScore *= 1.4
                }
            }
            
        case .linear:
            // Linear time decay factor
            let timeSinceCreation = now.timeIntervalSince(createdAt)
            let linearMultiplier = 1.0 + (timeSinceCreation * timeSensitivity.timeDecayFactor * 0.0001)
            adjustedScore *= min(1.5, linearMultiplier)
        }
        
        return adjustedScore
    }
    
    /// Applies location-based urgency that accelerates bubble-up when at relevant locations
    private func applyLocationBasedUrgency(score: Double, context: OrchestratorContext) -> Double {
        let locationRelevance = cognitiveMetadata.locationRelevance
        
        // If not location-based, return unchanged
        if locationRelevance.relevantLocations.isEmpty {
            return score
        }
        
        // TODO: In real implementation, get current location from LocationManager
        // For now, we'll simulate based on environmental factors or user preferences
        
        var adjustedScore = score
        let now = Date()
        
        // Check if we're likely at a relevant location based on context
        for locationContext in locationRelevance.relevantLocations {
            // Check if we're in the right time window for this location
            let isInTimeWindow = locationContext.activeTimeWindows.isEmpty || 
                locationContext.activeTimeWindows.contains { $0.contains(now) }
            
            if isInTimeWindow {
                // Apply location-based boost
                adjustedScore *= locationRelevance.locationMultiplier
                
                // Additional boost for time-sensitive location items
                if locationRelevance.locationTimeSensitive {
                    adjustedScore *= 1.3
                }
                
                // Location type specific boosts during relevant windows
                let currentHour = Calendar.current.component(.hour, from: now)
                switch locationContext.type {
                case .office:
                    if currentHour >= 8 && currentHour <= 18 { // Business hours
                        adjustedScore *= 1.2
                    }
                case .home:
                    if currentHour <= 8 || currentHour >= 18 { // Home hours
                        adjustedScore *= 1.15
                    }
                case .store, .restaurant:
                    // Shopping/dining times - moderate boost
                    adjustedScore *= 1.1
                case .gym:
                    if currentHour >= 6 && currentHour <= 22 { // Gym hours
                        adjustedScore *= 1.25
                    }
                default:
                    break
                }
                
                break // Only apply first matching location boost
            }
        }
        
        return adjustedScore
    }
    
    /// Checks if current time is within a recurring pattern window
    private func isWithinRecurrenceWindow(_ pattern: RecurrencePattern, at date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        
        guard let weekday = components.weekday else { return false }
        
        // Check if current day is in pattern
        if !pattern.daysOfWeek.contains(weekday) {
            return false
        }
        
        // Check if we're within the pattern's date range
        if date < pattern.startDate {
            return false
        }
        
        if let endDate = pattern.endDate, date > endDate {
            return false
        }
        
        // Check interval timing - simplified check for hourly/daily patterns
        let timeSinceStart = date.timeIntervalSince(pattern.startDate)
        let intervalCount = Int(timeSinceStart / pattern.interval)
        let intervalStart = pattern.startDate.addingTimeInterval(Double(intervalCount) * pattern.interval)
        let intervalEnd = intervalStart.addingTimeInterval(pattern.interval)
        
        return date >= intervalStart && date < intervalEnd
    }
    
    private func evaluateDynamicScript(_ script: String, baseScore: Double, context: OrchestratorContext) async throws -> Double {
        // Simple script evaluation using NSExpression for mathematical expressions
        // In a full implementation, this could use a more sophisticated scripting engine
        
        let scriptVariables = [
            "baseScore": baseScore,
            "cognitiveCapacity": context.cognitiveCapacity,
            "hourOfDay": Double(Calendar.current.component(.hour, from: Date())),
            "surfaceCount": Double(surfaceCount),
            "daysSinceCreated": Date().timeIntervalSince(createdAt) / (24 * 3600),
            "emotionalRelevance": cognitiveMetadata.emotionalRelevance,
            "requiredLoad": cognitiveMetadata.requiredCognitiveLoad
        ]
        
        // Replace variables in script
        var processedScript = script
        for (variable, value) in scriptVariables {
            processedScript = processedScript.replacingOccurrences(of: "$\(variable)", with: "\(value)")
        }
        
        // Evaluate using NSExpression (limited but safe)
        do {
            let expression = NSExpression(format: processedScript)
            if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
                return min(1.0, max(0.0, result.doubleValue))
            }
        } catch {
            Logger(subsystem: "com.jaredlikes.ProjectOne", category: "BubbleUpItem")
                .error("Dynamic script evaluation failed: \(error.localizedDescription)")
        }
        
        return baseScore // Fallback to base score if script evaluation fails
    }
    
    private func generateContextKey(_ context: OrchestratorContext) -> String {
        return "\(context.currentWindow.rawValue)-\(context.cognitiveCapacity)-\(context.currentFocus ?? "none")"
    }
    
    private func extractContextFactors(_ context: OrchestratorContext) -> [String: Double] {
        return [
            "cognitiveCapacity": context.cognitiveCapacity,
            "hourOfDay": Double(Calendar.current.component(.hour, from: Date())),
            "environmentalStress": context.environmentalFactors["stress"] ?? 0.5
        ]
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum EngagementType: String, Codable, Sendable {
    case viewed = "viewed"
    case dismissed = "dismissed"
    case completed = "completed"
    case snoozed = "snoozed"
    case expanded = "expanded"
    case actioned = "actioned"
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct EngagementEvent: Codable, Sendable {
    public let type: EngagementType
    public let timestamp: Date
    public let metadata: [String: String] // Simplified for Codable compliance
    
    public init(type: EngagementType, timestamp: Date, metadata: [String: Any] = [:]) {
        self.type = type
        self.timestamp = timestamp
        // Convert Any values to String for Codable compliance
        self.metadata = metadata.mapValues { "\($0)" }
    }
}

// MARK: - Cognitive Metadata System

/// AI-generated metadata for cognitive evaluation of bubble-up items
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveMetadata: Codable, Sendable {
    /// Emotional relevance score (0.0 to 1.0)
    public let emotionalRelevance: Double
    
    /// Required cognitive load to process this item
    public let requiredCognitiveLoad: Double
    
    /// Attention capture factors identified by AI
    public let attentionCaptureFactors: Set<AttentionFactor>
    
    /// Dopamine trigger mechanisms
    public let dopamineTriggers: [DopamineTrigger]
    
    /// Time-sensitivity factors for temporal urgency
    public let timeSensitivity: TimeSensitivity
    
    /// Location-based relevance factors
    public let locationRelevance: LocationRelevance
    
    /// Memory connection strength to related concepts
    public let memoryConnectionStrength: Double
    
    /// AI confidence in this metadata (0.0 to 1.0)
    public let aiConfidence: Double
    
    /// When this metadata was generated
    public let generatedAt: Date
    
    public init(emotionalRelevance: Double,
                requiredCognitiveLoad: Double,
                attentionCaptureFactors: Set<AttentionFactor>,
                dopamineTriggers: [DopamineTrigger],
                timeSensitivity: TimeSensitivity,
                locationRelevance: LocationRelevance,
                memoryConnectionStrength: Double,
                aiConfidence: Double) {
        self.emotionalRelevance = emotionalRelevance
        self.requiredCognitiveLoad = requiredCognitiveLoad
        self.attentionCaptureFactors = attentionCaptureFactors
        self.dopamineTriggers = dopamineTriggers
        self.timeSensitivity = timeSensitivity
        self.locationRelevance = locationRelevance
        self.memoryConnectionStrength = memoryConnectionStrength
        self.aiConfidence = aiConfidence
        self.generatedAt = Date()
    }
    
    /// Creates default metadata for a task type
    public static func defaultMetadata(for taskType: BubbleUpTaskType) -> CognitiveMetadata {
        return CognitiveMetadata(
            emotionalRelevance: 0.5,
            requiredCognitiveLoad: taskType.defaultCognitiveLoad,
            attentionCaptureFactors: taskType.defaultAttentionFactors,
            dopamineTriggers: taskType.defaultDopamineTriggers,
            timeSensitivity: TimeSensitivity.defaultSensitivity,
            locationRelevance: LocationRelevance.notLocationBased,
            memoryConnectionStrength: 0.3,
            aiConfidence: 0.6
        )
    }
}

/// Time-based urgency factors for bubble-up acceleration
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct TimeSensitivity: Codable, Sendable {
    /// How urgency changes over time (linear, exponential, deadline-based)
    public let urgencyPattern: UrgencyPattern
    
    /// Time windows when this becomes critically important
    public let criticalTimeWindows: [DateInterval]
    
    /// How much importance increases per unit time
    public let timeDecayFactor: Double
    
    /// Whether this has recurring time-based patterns
    public let recurringPatterns: [RecurrencePattern]
    
    public static let defaultSensitivity = TimeSensitivity(
        urgencyPattern: .linear,
        criticalTimeWindows: [],
        timeDecayFactor: 0.1,
        recurringPatterns: []
    )
}

/// Location-based relevance for contextual bubble-up
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct LocationRelevance: Codable, Sendable {
    /// Specific locations where this becomes more important
    public let relevantLocations: [LocationContext]
    
    /// Distance threshold for location-based activation
    public let activationRadius: Double // In meters
    
    /// How much importance multiplies when in relevant location
    public let locationMultiplier: Double
    
    /// Whether this is time-sensitive within the location
    public let locationTimeSensitive: Bool
    
    public static let notLocationBased = LocationRelevance(
        relevantLocations: [],
        activationRadius: 0,
        locationMultiplier: 1.0,
        locationTimeSensitive: false
    )
}

/// Coordinates structure for Codable conformance
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct Coordinates: Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Specific location context for bubble-up items
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct LocationContext: Codable, Sendable {
    /// Location identifier (address, place ID, or coordinates)
    public let identifier: String
    
    /// Human-readable name
    public let name: String
    
    /// Location type (home, office, store, etc.)
    public let type: LocationType
    
    /// Coordinates if available
    public let coordinates: Coordinates?
    
    /// Time windows when this location is relevant
    public let activeTimeWindows: [DateInterval]
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum LocationType: String, Codable, Sendable, CaseIterable {
    case home, office, store, restaurant, gym, school, hospital, transport, outdoor, social
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum UrgencyPattern: String, Codable, Sendable, CaseIterable {
    case linear, exponential, deadlineBased, periodic
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct RecurrencePattern: Codable, Sendable {
    public let interval: TimeInterval
    public let startDate: Date
    public let endDate: Date?
    public let daysOfWeek: Set<Int> // 1-7, Sunday = 1
}

/// Attention capture mechanisms identified by AI
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum AttentionFactor: String, CaseIterable, Codable, Sendable {
    case novelty, urgency, relevance, curiosity, completion, social, achievement
}

/// Dopamine trigger mechanisms for ADHD-friendly engagement
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum DopamineTrigger: Codable, Sendable {
    case immediateReward, progressVisual, socialConnection, noveltyStimulus, completionSatisfaction, challengeEngagement
    
    /// Returns importance multiplier for specific dopamine window
    public func multiplier(for window: DopamineWindow) -> Double {
        switch (self, window) {
        case (.immediateReward, .morningPeak), (.progressVisual, .afternoonBoost):
            return 1.3
        case (.socialConnection, .eveningCreative), (.noveltyStimulus, .morningPeak):
            return 1.2
        case (.completionSatisfaction, .afternoonBoost), (.challengeEngagement, .morningPeak):
            return 1.25
        default:
            return 1.0
        }
    }
}

/// Dopamine wave phase types for pattern-based processing
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum DopamineWavePhase: String, CaseIterable, Codable, Sendable {
    case routine = "routine"
    case creative = "creative"
    case planning = "planning"
    case emotional = "emotional"
    case focus = "focus"
}

/// Cached evaluation result
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct EvaluationResult: Codable, Sendable {
    public let importanceScore: Double
    public let timestamp: Date
    public let contextFactors: [String: Double]
}

// MARK: - Task Type Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension BubbleUpTaskType {
    /// Default dopamine windows for each task type
    public var defaultWindows: [DopamineWindow] {
        switch self {
        case .focus, .planning:
            return [.morningPeak, .afternoonBoost]
        case .routine, .maintenance:
            return [.midDayDip, .afternoonBoost]
        case .action, .implementation:
            return [.afternoonBoost, .morningPeak]
        case .creative, .reflection:
            return [.eveningCreative, .morningPeak]
        case .preparation, .review:
            return [.eveningCreative, .nightRest]
        }
    }
    
    /// Default cognitive load for each task type
    public var defaultCognitiveLoad: Double {
        switch self {
        case .focus, .planning: return 0.8
        case .routine, .maintenance: return 0.3
        case .action, .implementation: return 0.6
        case .creative, .reflection: return 0.7
        case .preparation, .review: return 0.4
        }
    }
    
    /// Default attention capture factors
    public var defaultAttentionFactors: Set<AttentionFactor> {
        switch self {
        case .focus: return [.urgency, .relevance]
        case .planning: return [.completion, .achievement]
        case .routine: return [.completion]
        case .maintenance: return [.completion]
        case .action: return [.urgency, .achievement]
        case .implementation: return [.completion, .achievement]
        case .creative: return [.novelty, .curiosity]
        case .reflection: return [.relevance, .social]
        case .preparation: return [.completion]
        case .review: return [.achievement, .completion]
        }
    }
    
    /// Default dopamine triggers
    public var defaultDopamineTriggers: [DopamineTrigger] {
        switch self {
        case .focus, .planning: return [.challengeEngagement, .completionSatisfaction]
        case .routine, .maintenance: return [.completionSatisfaction]
        case .action, .implementation: return [.immediateReward, .progressVisual]
        case .creative, .reflection: return [.noveltyStimulus, .socialConnection]
        case .preparation, .review: return [.completionSatisfaction]
        }
    }
}