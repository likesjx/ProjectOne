import Foundation
import SwiftData
import Collections

// MARK: - Memory Item Base

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
class MemoryItem {
    var id: UUID
    var timestamp: Date
    var importance: Double // 0.0 - 1.0
    var accessCount: Int
    var lastAccessed: Date
    var decay: Double // How much this memory has decayed over time
    
    init(importance: Double = 0.5) {
        self.id = UUID()
        self.timestamp = Date()
        self.importance = importance
        self.accessCount = 0
        self.lastAccessed = Date()
        self.decay = 0.0
    }
    
    func recordAccess() {
        accessCount += 1
        lastAccessed = Date()
        
        // Accessing memory strengthens it
        importance = min(1.0, importance + 0.05)
        decay = max(0.0, decay - 0.1)
    }
    
    func applyDecay(timeDelta: TimeInterval) {
        let daysSince = timeDelta / (24 * 60 * 60)
        let decayRate = 0.01 * daysSince // 1% decay per day
        decay = min(1.0, decay + decayRate)
        importance = max(0.0, importance - (decayRate * 0.5))
    }
}

// MARK: - Short-Term Memory

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class ShortTermMemory {
    var sessionId: UUID
    var createdAt: Date
    var isActive: Bool
    
    // Working set - currently relevant information
    @Relationship(deleteRule: .cascade)
    var workingSet: [WorkingMemoryItem] = []
    
    // Attention focus - entities currently in focus
    var focusedEntityIds: [String] // Entity UUIDs as strings
    
    // Recent interactions within this session
    @Relationship(deleteRule: .cascade)
    var recentInteractions: [InteractionMemory] = []
    
    // Temporary connections discovered in this session
    @Relationship(deleteRule: .cascade)
    var temporaryBindings: [TemporaryRelationship] = []
    
    // Session context
    var contextType: String // "work", "personal", etc.
    var location: String?
    var timeOfDay: String
    
    // Capacity management
    var maxWorkingSetSize: Int = 20
    var maxInteractionHistory: Int = 50
    
    init(sessionId: UUID = UUID(), contextType: String = "general") {
        self.sessionId = sessionId
        self.createdAt = Date()
        self.isActive = true
        self.focusedEntityIds = []
        self.contextType = contextType
        
        // Set time of day inline to avoid calling instance method before init
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: self.timeOfDay = "early_morning"
        case 9..<12: self.timeOfDay = "morning"
        case 12..<17: self.timeOfDay = "afternoon"
        case 17..<21: self.timeOfDay = "evening"
        default: self.timeOfDay = "night"
        }
    }
    
    // Add item to working set with capacity management
    func addToWorkingSet(_ item: WorkingMemoryItem) {
        workingSet.append(item)
        
        // Remove oldest items if over capacity
        if workingSet.count > maxWorkingSetSize {
            let sortedByAccess = workingSet.sorted { $0.lastAccessed < $1.lastAccessed }
            let itemsToRemove = sortedByAccess.prefix(workingSet.count - maxWorkingSetSize)
            
            for item in itemsToRemove {
                if let index = workingSet.firstIndex(where: { $0.id == item.id }) {
                    workingSet.remove(at: index)
                }
            }
        }
    }
    
    // Focus attention on specific entities
    func focusOn(entityIds: [String]) {
        focusedEntityIds = entityIds
        
        // Boost importance of related working memory items
        for item in workingSet {
            if entityIds.contains(item.relatedEntityId ?? "") {
                item.recordAccess()
            }
        }
    }
    
    // Record an interaction in this session
    func recordInteraction(_ interaction: InteractionMemory) {
        recentInteractions.append(interaction)
        
        // Manage interaction history size
        if recentInteractions.count > maxInteractionHistory {
            let sortedByTime = recentInteractions.sorted { $0.timestamp < $1.timestamp }
            let itemsToRemove = sortedByTime.prefix(recentInteractions.count - maxInteractionHistory)
            
            for item in itemsToRemove {
                if let index = recentInteractions.firstIndex(where: { $0.id == item.id }) {
                    recentInteractions.remove(at: index)
                }
            }
        }
    }
    
    // Get current context summary
    func getContextSummary() -> SessionContext {
        return SessionContext(
            sessionId: sessionId,
            contextType: contextType,
            location: location,
            timeOfDay: timeOfDay,
            focusedEntities: focusedEntityIds,
            workingSetSize: workingSet.count,
            interactionCount: recentInteractions.count,
            temporaryBindingsCount: temporaryBindings.count
        )
    }
    
    private func getCurrentTimeOfDay() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return "early_morning"
        case 9..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
}

// MARK: - Working Memory Item

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class WorkingMemoryItem: MemoryItem {
    var content: String
    var type: WorkingMemoryType
    var relatedEntityId: String? // Reference to Entity
    var relatedNoteId: String? // Reference to ProcessedNote
    var priority: LegacyWorkingMemoryPriority
    
    init(content: String, type: WorkingMemoryType, priority: LegacyWorkingMemoryPriority = .normal, importance: Double = 0.5) {
        self.content = content
        self.type = type
        self.priority = priority
        super.init(importance: importance)
    }
    
    var effectiveImportance: Double {
        let priorityMultiplier = priority.multiplier
        return min(1.0, importance * priorityMultiplier)
    }
}

enum WorkingMemoryType: String, CaseIterable, Codable {
    case entityReference = "entity_reference"
    case conceptualInsight = "conceptual_insight"
    case temporalContext = "temporal_context"
    case relationshipHypothesis = "relationship_hypothesis"
    case questionToResolve = "question_to_resolve"
    case patternObservation = "pattern_observation"
}

enum LegacyWorkingMemoryPriority: String, CaseIterable, Codable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    var multiplier: Double {
        switch self {
        case .low: return 0.5
        case .normal: return 1.0
        case .high: return 1.5
        case .critical: return 2.0
        }
    }
}

// MARK: - Long-Term Memory

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class LongTermMemory {
    var id: UUID
    var createdAt: Date
    
    // Episodic Memory - specific experiences and events
    @Relationship(deleteRule: .cascade)
    var episodicMemory: [EpisodicEvent] = []
    
    // Semantic Memory - general knowledge and facts
    @Relationship(deleteRule: .cascade)
    var semanticMemory: [SemanticConcept] = []
    
    // Procedural Memory - patterns and procedures
    @Relationship(deleteRule: .cascade)
    var proceduralMemory: [ProcedurePattern] = []
    
    // Consolidated Knowledge - proven and reinforced information
    @Relationship(deleteRule: .cascade)
    var consolidatedKnowledge: [ConsolidatedFact] = []
    
    init() {
        self.id = UUID()
        self.createdAt = Date()
    }
    
    // Add episodic memory from STM
    func consolidateEpisode(_ episode: EpisodicEvent) {
        // Check if similar episode already exists
        let similarEpisodes = episodicMemory.filter { existingEpisode in
            existingEpisode.isSimilar(to: episode)
        }
        
        if let existingEpisode = similarEpisodes.first {
            // Merge with existing episode
            existingEpisode.merge(with: episode)
        } else {
            // Add as new episode
            episodicMemory.append(episode)
        }
    }
    
    // Extract semantic concepts from episodes
    func extractSemanticConcepts() {
        let recentEpisodes = episodicMemory.filter { episode in
            Date().timeIntervalSince(episode.timestamp) < (30 * 24 * 60 * 60) // Last 30 days
        }
        
        // Analyze patterns in recent episodes to extract semantic concepts
        let conceptCandidates = analyzeConceptPatterns(in: recentEpisodes)
        
        for candidate in conceptCandidates {
            if let existingConcept = semanticMemory.first(where: { $0.name == candidate.name }) {
                existingConcept.reinforce(with: candidate)
            } else {
                semanticMemory.append(candidate)
            }
        }
    }
    
    // Identify procedural patterns
    func identifyProcedures() {
        // Look for repeated patterns in episodic memory
        let procedures = analyzeProceduralPatterns(in: episodicMemory)
        
        for procedure in procedures {
            if let existingProcedure = proceduralMemory.first(where: { $0.name == procedure.name }) {
                existingProcedure.reinforce()
            } else {
                proceduralMemory.append(procedure)
            }
        }
    }
    
    private func analyzeConceptPatterns(in episodes: [EpisodicEvent]) -> [SemanticConcept] {
        // Simplified concept extraction - in real implementation, this would use ML
        var concepts: [SemanticConcept] = []
        
        let entityFrequency = Dictionary(grouping: episodes.flatMap { $0.involvedEntityIds }) { $0 }
            .mapValues { $0.count }
        
        for (entityId, frequency) in entityFrequency where frequency >= 3 {
            let concept = SemanticConcept(
                name: "Entity_\(entityId)",
                type: .entity,
                strength: min(1.0, Double(frequency) / 10.0),
                evidence: episodes.filter { $0.involvedEntityIds.contains(entityId) }.map { $0.id.uuidString }
            )
            concepts.append(concept)
        }
        
        return concepts
    }
    
    private func analyzeProceduralPatterns(in episodes: [EpisodicEvent]) -> [ProcedurePattern] {
        // Simplified procedure detection
        var patterns: [ProcedurePattern] = []
        
        // Look for temporal patterns
        let sortedEpisodes = episodes.sorted { $0.timestamp < $1.timestamp }
        
        // Group episodes by time windows to find routines
        let timeWindows = groupEpisodesByTimeWindows(sortedEpisodes)
        
        for (window, episodes) in timeWindows {
            if episodes.count >= 3 {
                let pattern = ProcedurePattern(
                    name: "Routine_\(window)",
                    type: .temporal,
                    strength: min(1.0, Double(episodes.count) / 10.0),
                    steps: episodes.map { $0.summary }
                )
                patterns.append(pattern)
            }
        }
        
        return patterns
    }
    
    private func groupEpisodesByTimeWindows(_ episodes: [EpisodicEvent]) -> [String: [EpisodicEvent]] {
        var windows: [String: [EpisodicEvent]] = [:]
        
        for episode in episodes {
            let hour = Calendar.current.component(.hour, from: episode.timestamp)
            let timeWindow = "\(hour/3 * 3)-\((hour/3 + 1) * 3)" // 3-hour windows
            
            if windows[timeWindow] == nil {
                windows[timeWindow] = []
            }
            windows[timeWindow]?.append(episode)
        }
        
        return windows
    }
}

// MARK: - Supporting Memory Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class EpisodicEvent: MemoryItem {
    var summary: String
    var involvedEntityIds: [String] // Entity UUIDs
    var location: String?
    var emotionalValence: Double // -1.0 to 1.0
    var contextType: String
    var sourceNoteIds: [String] // ProcessedNote UUIDs
    
    init(summary: String, involvedEntityIds: [String] = [], location: String? = nil, 
         emotionalValence: Double = 0.0, contextType: String = "general", importance: Double = 0.5) {
        self.summary = summary
        self.involvedEntityIds = involvedEntityIds
        self.location = location
        self.emotionalValence = emotionalValence
        self.contextType = contextType
        self.sourceNoteIds = []
        super.init(importance: importance)
    }
    
    func isSimilar(to other: EpisodicEvent) -> Bool {
        // Check for similarity based on entities, location, and time proximity
        let commonEntities = Set(involvedEntityIds).intersection(Set(other.involvedEntityIds))
        let entitySimilarity = Double(commonEntities.count) / Double(max(involvedEntityIds.count, other.involvedEntityIds.count))
        
        let timeDifference = abs(timestamp.timeIntervalSince(other.timestamp))
        let timeProximity = timeDifference < (24 * 60 * 60) // Within 24 hours
        
        let locationMatch = location == other.location
        
        return entitySimilarity > 0.5 && timeProximity && (locationMatch || location == nil || other.location == nil)
    }
    
    func merge(with other: EpisodicEvent) {
        // Merge information from similar episode
        let combinedEntities = Set(involvedEntityIds + other.involvedEntityIds)
        involvedEntityIds = Array(combinedEntities)
        
        sourceNoteIds.append(contentsOf: other.sourceNoteIds)
        
        // Average emotional valence
        emotionalValence = (emotionalValence + other.emotionalValence) / 2.0
        
        // Use more recent summary if provided
        if !other.summary.isEmpty && other.timestamp > timestamp {
            summary = other.summary
        }
        
        recordAccess()
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class SemanticConcept: MemoryItem {
    var name: String
    var type: SemanticType
    var strength: Double // How well-established this concept is
    var evidence: [String] // References to supporting evidence
    var relatedConceptIds: [String] // Related semantic concepts
    
    init(name: String, type: SemanticType, strength: Double = 0.5, evidence: [String] = [], importance: Double = 0.5) {
        self.name = name
        self.type = type
        self.strength = strength
        self.evidence = evidence
        self.relatedConceptIds = []
        super.init(importance: importance)
    }
    
    func reinforce(with newConcept: SemanticConcept) {
        strength = min(1.0, strength + 0.1)
        evidence.append(contentsOf: newConcept.evidence)
        recordAccess()
    }
}

enum SemanticType: String, CaseIterable, Codable {
    case entity = "entity"
    case relationship = "relationship"
    case category = "category"
    case attribute = "attribute"
    case process = "process"
    case goal = "goal"
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class ProcedurePattern: MemoryItem {
    var name: String
    var type: ProcedureType
    var strength: Double
    var steps: [String]
    var triggers: [String] // What triggers this procedure
    var outcomes: [String] // Expected outcomes
    
    init(name: String, type: ProcedureType, strength: Double = 0.5, steps: [String] = [], importance: Double = 0.5) {
        self.name = name
        self.type = type
        self.strength = strength
        self.steps = steps
        self.triggers = []
        self.outcomes = []
        super.init(importance: importance)
    }
    
    func reinforce() {
        strength = min(1.0, strength + 0.1)
        recordAccess()
    }
}

enum ProcedureType: String, CaseIterable, Codable {
    case temporal = "temporal" // Time-based routines
    case contextual = "contextual" // Context-triggered behaviors
    case problemSolving = "problem_solving" // Solution patterns
    case communication = "communication" // Communication patterns
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class ConsolidatedFact: MemoryItem {
    var statement: String
    var confidence: Double
    var supportingEvidence: [String]
    var contradictingEvidence: [String]
    var domain: String // Topic area
    
    init(statement: String, confidence: Double = 0.8, domain: String = "general", importance: Double = 0.7) {
        self.statement = statement
        self.confidence = confidence
        self.supportingEvidence = []
        self.contradictingEvidence = []
        self.domain = domain
        super.init(importance: importance)
    }
    
    func addEvidence(_ evidence: String, supporting: Bool) {
        if supporting {
            supportingEvidence.append(evidence)
            confidence = min(1.0, confidence + 0.05)
        } else {
            contradictingEvidence.append(evidence)
            confidence = max(0.0, confidence - 0.1)
        }
        recordAccess()
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class InteractionMemory: MemoryItem {
    var type: InteractionType
    var content: String
    var involvedEntityIds: [String]
    var outcome: String?
    
    init(type: InteractionType, content: String, involvedEntityIds: [String] = [], outcome: String? = nil, importance: Double = 0.5) {
        self.type = type
        self.content = content
        self.involvedEntityIds = involvedEntityIds
        self.outcome = outcome
        super.init(importance: importance)
    }
}

enum InteractionType: String, CaseIterable, Codable {
    case query = "query"
    case note_creation = "note_creation"
    case entity_exploration = "entity_exploration"
    case relationship_discovery = "relationship_discovery"
    case agent_delegation = "agent_delegation"
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class TemporaryRelationship: MemoryItem {
    var subjectEntityId: String
    var predicate: String
    var objectEntityId: String
    var confidence: Double
    var context: String
    
    init(subjectEntityId: String, predicate: String, objectEntityId: String, 
         confidence: Double = 0.5, context: String = "", importance: Double = 0.3) {
        self.subjectEntityId = subjectEntityId
        self.predicate = predicate
        self.objectEntityId = objectEntityId
        self.confidence = confidence
        self.context = context
        super.init(importance: importance)
    }
}

// MARK: - Context Structures

struct SessionContext {
    let sessionId: UUID
    let contextType: String
    let location: String?
    let timeOfDay: String
    let focusedEntities: [String]
    let workingSetSize: Int
    let interactionCount: Int
    let temporaryBindingsCount: Int
}