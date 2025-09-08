//
//  BubbleUpEngine.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  Core engine for the Dopamine Cognitive Design bubble-up system
//

import Foundation
import SwiftData
import Combine
import os.log

// MARK: - Bubble-Up Engine

/// Core engine that manages the surfacing of contextually relevant items
/// based on dopamine wave patterns and cognitive load optimization
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@MainActor
public class BubbleUpEngine: ObservableObject {
    
    // MARK: - Dependencies
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "BubbleUpEngine")
    private let modelContext: ModelContext
    private let cognitiveMemorySystem: CognitiveMemorySystem
    private let privacyAnalyzer: PrivacyAnalyzer
    private let knowledgeGraphService: KnowledgeGraphService?
    private let knowledgeGraphCognitiveAdapter: KnowledgeGraphCognitiveAdapter?
    
    // MARK: - State
    
    @Published public var currentSurfacedItems: [BubbleUpItem] = []
    @Published public var currentDopamineWindow: DopamineWindow = .current
    @Published public var surfacingActive: Bool = false
    @Published public var lastEngineRun: Date?
    
    // MARK: - Configuration
    
    public struct EngineConfiguration: Sendable {
        let maxSurfacedItems: Int
        let minTimeBetweenSurfaces: TimeInterval
        let cognitiveLoadThreshold: Double
        let enableProactiveSurfacing: Bool
        let surfacingInterval: TimeInterval
        
        public static let `default` = EngineConfiguration(
            maxSurfacedItems: 5,
            minTimeBetweenSurfaces: 300, // 5 minutes
            cognitiveLoadThreshold: 0.7,
            enableProactiveSurfacing: true,
            surfacingInterval: 900 // 15 minutes
        )
    }
    
    private let configuration: EngineConfiguration
    private var surfacingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext,
                cognitiveMemorySystem: CognitiveMemorySystem,
                privacyAnalyzer: PrivacyAnalyzer,
                knowledgeGraphService: KnowledgeGraphService? = nil,
                knowledgeGraphCognitiveAdapter: KnowledgeGraphCognitiveAdapter? = nil,
                configuration: EngineConfiguration = .default) {
        self.modelContext = modelContext
        self.cognitiveMemorySystem = cognitiveMemorySystem
        self.privacyAnalyzer = privacyAnalyzer
        self.knowledgeGraphService = knowledgeGraphService
        self.knowledgeGraphCognitiveAdapter = knowledgeGraphCognitiveAdapter
        self.configuration = configuration
        
        setupDopamineWindowTracking()
        setupAutomaticSurfacing()
        
        logger.info("BubbleUpEngine initialized with configuration: maxItems=\(configuration.maxSurfacedItems), knowledgeGraph=\(knowledgeGraphService != nil)")
    }
    
    deinit {
        stopAutomaticSurfacing()
    }
    
    // MARK: - Core Engine Logic
    
    /// Runs the bubble-up algorithm to surface contextually relevant items
    public func runBubbleUpAlgorithm(forceRun: Bool = false) async throws {
        let context = await getCurrentOrchestratorContext()
        
        // Check if we should run based on timing and cognitive load
        guard shouldRunBubbleUp(context: context, forceRun: forceRun) else {
            logger.debug("Skipping bubble-up run: conditions not met")
            return
        }
        
        surfacingActive = true
        defer { surfacingActive = false }
        
        logger.info("Running bubble-up algorithm for window: \(context.currentWindow.rawValue)")
        
        do {
            // 1. Get candidate items from various sources
            let candidates = try await getCandidateItems(context: context)
            
            // 2. Score and filter candidates based on context
            let scoredCandidates = await scoreCandidates(candidates, context: context)
            
            // 3. Select optimal items for current context
            let selectedItems = selectOptimalItems(scoredCandidates, context: context)
            
            // 4. Update surfaced items and mark as surfaced
            await updateSurfacedItems(selectedItems)
            
            // 5. Record analytics and performance metrics
            recordBubbleUpMetrics(candidates: candidates.count, 
                                surfaced: selectedItems.count,
                                context: context)
            
            lastEngineRun = Date()
            
        } catch {
            logger.error("Error in bubble-up algorithm: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Candidate Generation
    
    /// Generates candidate items from multiple sources for bubble-up consideration
    private func getCandidateItems(context: OrchestratorContext) async throws -> [BubbleUpItem] {
        var candidates: [BubbleUpItem] = []
        
        // 1. Get stored bubble-up items
        let storedItems = try await getStoredBubbleUpItems()
        candidates.append(contentsOf: storedItems)
        
        // 2. Generate items from fusion nodes (cross-layer insights)
        let fusionBasedItems = try await generateFromFusionNodes(context: context)
        candidates.append(contentsOf: fusionBasedItems)
        
        // 3. Generate items from memory consolidation patterns
        let consolidationItems = try await generateFromConsolidation(context: context)
        candidates.append(contentsOf: consolidationItems)
        
        // 4. Generate proactive insights from recent activity
        let proactiveItems = try await generateProactiveItems(context: context)
        candidates.append(contentsOf: proactiveItems)
        
        // 5. Privacy filtering
        candidates = try await privacyAnalyzer.filterBubbleUpItems(candidates, context: context)
        
        logger.debug("Generated \(candidates.count) candidate items for bubble-up")
        return candidates
    }
    
    /// Retrieves existing bubble-up items from storage
    private func getStoredBubbleUpItems() async throws -> [BubbleUpItem] {
        let descriptor = FetchDescriptor<BubbleUpItem>(
            predicate: #Predicate { item in
                item.lastSurfaced == nil || 
                item.lastSurfaced! < Date().addingTimeInterval(-configuration.minTimeBetweenSurfaces)
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    /// Generates bubble-up items from fusion nodes in the cognitive memory system
    private func generateFromFusionNodes(context: OrchestratorContext) async throws -> [BubbleUpItem] {
        let fusionNodes = cognitiveMemorySystem.fusionNodes
        var items: [BubbleUpItem] = []
        
        for fusionNode in fusionNodes {
            // Skip recently processed fusion nodes
            if let lastProcessed = fusionNode.lastBubbleUpGeneration,
               lastProcessed > Date().addingTimeInterval(-3600) { // 1 hour
                continue
            }
            
            // Generate contextual insights from fusion node
            if let insight = await generateInsightFromFusion(fusionNode, context: context) {
                let priority = BubbleUpPriority(
                    baseImportance: fusionNode.importance,
                    recencyScore: calculateRecencyScore(fusionNode.createdAt),
                    contextMatchScore: 0.8, // High for fusion-generated insights
                    adhdUrgency: 0.6
                )
                
                let item = BubbleUpItem(
                    content: insight,
                    tags: ["insight", "fusion", "cross-layer"],
                    taskType: .reflection,
                    preferredWindows: [.eveningCreative, .morningPeak],
                    priority: priority,
                    fusionNodeID: fusionNode.id,
                    privacySensitivity: fusionNode.privacySensitivity
                )
                
                items.append(item)
                
                // Update fusion node tracking
                fusionNode.lastBubbleUpGeneration = Date()
            }
        }
        
        return items
    }
    
    /// Generates items from memory consolidation patterns
    private func generateFromConsolidation(context: OrchestratorContext) async throws -> [BubbleUpItem] {
        var items: [BubbleUpItem] = []
        
        // Check if there are patterns in recent consolidation that suggest actionable insights
        if let consolidationInsights = await analyzeConsolidationPatterns(context: context) {
            for insight in consolidationInsights {
                let priority = BubbleUpPriority(
                    baseImportance: insight.importance,
                    recencyScore: 0.9, // High recency for fresh consolidations
                    contextMatchScore: insight.contextMatch,
                    adhdUrgency: insight.urgency
                )
                
                let item = BubbleUpItem(
                    content: insight.content,
                    tags: insight.tags,
                    taskType: insight.taskType,
                    priority: priority,
                    relatedMemoryIDs: insight.relatedMemoryIDs
                )
                
                items.append(item)
            }
        }
        
        return items
    }
    
    /// Generates proactive items based on user patterns and upcoming needs
    private func generateProactiveItems(context: OrchestratorContext) async throws -> [BubbleUpItem] {
        var items: [BubbleUpItem] = []
        
        // Analyze user patterns to predict upcoming needs
        let patterns = await analyzeUserPatterns(context: context)
        
        for pattern in patterns {
            if pattern.confidence > 0.7 && pattern.shouldSurface(in: context.currentWindow) {
                let priority = BubbleUpPriority(
                    baseImportance: pattern.importance,
                    recencyScore: 0.5, // Medium recency for predictions
                    contextMatchScore: pattern.contextMatch,
                    adhdUrgency: pattern.adhdUrgency
                )
                
                let item = BubbleUpItem(
                    content: pattern.suggestedAction,
                    tags: ["proactive", "pattern", "prediction"],
                    taskType: pattern.taskType,
                    preferredWindows: pattern.optimalWindows,
                    priority: priority
                )
                
                items.append(item)
            }
        }
        
        return items
    }
    
    // MARK: - Scoring & Selection
    
    /// Scores candidate items using advanced cognitive evaluation system with time/location urgency
    private func scoreCandidates(_ candidates: [BubbleUpItem], 
                                context: OrchestratorContext) async -> [(BubbleUpItem, Double)] {
        var scoredItems: [(BubbleUpItem, Double)] = []
        
        logger.debug("Scoring \(candidates.count) candidates using cognitive evaluation system")
        
        for item in candidates {
            do {
                // Use the new cognitive evaluation system with time/location urgency
                let cognitiveScore = try await item.evaluateImportance(context: context)
                
                // Apply additional contextual factors
                let contextScore = await calculateContextScore(item, context: context)
                
                // Blend cognitive evaluation (primary) with contextual factors (secondary)
                var finalScore = (cognitiveScore * 0.8) + (contextScore * 0.2)
                
                // Apply memory system integration boost
                if !item.relatedMemoryIDs.isEmpty {
                    let memoryBoost = 1.0 + (Double(item.relatedMemoryIDs.count) * 0.05)
                    finalScore *= min(1.3, memoryBoost) // Cap at 30% boost
                    logger.debug("Applied memory boost to item \(item.id): \(memoryBoost)")
                }
                
                // Apply knowledge graph connectivity boost
                if !item.relatedEntityIDs.isEmpty {
                    let entityBoost = 1.0 + (Double(item.relatedEntityIDs.count) * 0.03)
                    finalScore *= min(1.2, entityBoost) // Cap at 20% boost
                    logger.debug("Applied entity graph boost to item \(item.id): \(entityBoost)")
                }
                
                // Apply fusion node boost for cross-layer insights
                if item.fusionNodeID != nil {
                    finalScore *= 1.15
                    logger.debug("Applied fusion node boost to item \(item.id)")
                }
                
                // Critical privacy override (overrides all other factors)
                if item.privacySensitivity > 0.8 && context.environmentalFactors["publicSpace"] == 1.0 {
                    finalScore *= 0.2 // Dramatically reduce sensitive items in public
                    logger.debug("Applied privacy reduction to item \(item.id) in public space")
                }
                
                // Final score clamping
                finalScore = min(1.0, max(0.0, finalScore))
                
                scoredItems.append((item, finalScore))
                
                logger.debug("Item \(item.id): cognitive=\(cognitiveScore), context=\(contextScore), final=\(finalScore)")
                
            } catch {
                logger.error("Failed to evaluate item \(item.id): \(error.localizedDescription)")
                // Fallback to legacy scoring
                let contextScore = await calculateContextScore(item, context: context)
                let fallbackScore = (item.priority.finalScore * 0.7) + (contextScore * 0.3)
                scoredItems.append((item, fallbackScore * 0.5)) // Penalty for evaluation failure
            }
        }
        
        let sortedItems = scoredItems.sorted { $0.1 > $1.1 }
        
        if !sortedItems.isEmpty {
            let topScores = sortedItems.prefix(3).map { String(format: "%.3f", $0.1) }
            logger.info("Scored candidates: top 3 scores = \(topScores)")
        }
        
        return sortedItems
    }
    
    /// Calculates how well an item matches the current context
    private func calculateContextScore(_ item: BubbleUpItem, 
                                     context: OrchestratorContext) async -> Double {
        var score: Double = 0.0
        
        // Dopamine window matching
        if item.preferredWindows.contains(context.currentWindow) {
            score += 0.3
        }
        
        // Cognitive capacity matching
        let taskComplexity = getTaskComplexity(item.taskType)
        if taskComplexity <= context.cognitiveCapacity {
            score += 0.2
        }
        
        // Recent activity context
        if let currentFocus = context.currentFocus {
            if item.tags.contains { $0.lowercased().contains(currentFocus.lowercased()) } {
                score += 0.2
            }
        }
        
        // Avoid recently completed similar items
        let similarRecentlyCompleted = context.recentlyCompleted.contains { recent in
            item.tags.contains { tag in
                recent.lowercased().contains(tag.lowercased())
            }
        }
        if !similarRecentlyCompleted {
            score += 0.15
        }
        
        // Environmental factors
        if let stressLevel = context.environmentalFactors["stress"],
           stressLevel > 0.7 && item.taskType == .routine {
            score += 0.1 // Prefer routine tasks when stressed
        }
        
        // ADHD-friendly timing (not too many surfaces recently)
        if item.lastSurfaced == nil || 
           item.lastSurfaced! < Date().addingTimeInterval(-configuration.minTimeBetweenSurfaces * 2) {
            score += 0.05
        }
        
        return min(1.0, score)
    }
    
    /// Selects the optimal items for surfacing based on context constraints
    private func selectOptimalItems(_ scoredItems: [(BubbleUpItem, Double)], 
                                   context: OrchestratorContext) -> [BubbleUpItem] {
        let maxItems = min(configuration.maxSurfacedItems, 
                          Int(context.cognitiveCapacity * Double(configuration.maxSurfacedItems)))
        
        var selectedItems: [BubbleUpItem] = []
        var usedTags: Set<String> = []
        
        for (item, score) in scoredItems {
            guard selectedItems.count < maxItems else { break }
            
            // Avoid too many similar items
            let hasOverlappingTags = !Set(item.tags).isDisjoint(with: usedTags)
            if hasOverlappingTags && selectedItems.count >= 2 {
                continue
            }
            
            // Minimum score threshold
            if score >= 0.3 {
                selectedItems.append(item)
                usedTags.formUnion(item.tags)
            }
        }
        
        return selectedItems
    }
    
    // MARK: - State Management
    
    /// Updates the currently surfaced items and marks them as surfaced
    private func updateSurfacedItems(_ items: [BubbleUpItem]) async {
        // Clear previous items
        for previousItem in currentSurfacedItems {
            if !items.contains(where: { $0.id == previousItem.id }) {
                // Item is no longer surfaced - could record this event
            }
        }
        
        // Update current items
        currentSurfacedItems = items
        
        // Mark items as surfaced and persist changes
        for item in items {
            item.markSurfaced()
        }
        
        try? modelContext.save()
    }
    
    // MARK: - Context Generation
    
    /// Generates current orchestrator context for decision making
    private func getCurrentOrchestratorContext() async -> OrchestratorContext {
        let currentWindow = DopamineWindow.current
        
        // TODO: Integrate with user activity monitoring
        let recentlyCompleted = await getRecentlyCompletedItems()
        let environmentalFactors = await getEnvironmentalFactors()
        
        return OrchestratorContext(
            currentWindow: currentWindow,
            cognitiveCapacity: currentWindow.cognitiveCapacity,
            currentFocus: nil, // TODO: Integrate with focus detection
            recentlyCompleted: recentlyCompleted,
            userPreferences: [:], // TODO: Integrate with user preferences
            environmentalFactors: environmentalFactors
        )
    }
    
    // MARK: - Helper Methods
    
    private func shouldRunBubbleUp(context: OrchestratorContext, forceRun: Bool) -> Bool {
        if forceRun { return true }
        
        // Don't run if recently ran
        if let lastRun = lastEngineRun,
           lastRun > Date().addingTimeInterval(-configuration.surfacingInterval) {
            return false
        }
        
        // Don't run during low-capacity windows unless specifically needed
        if context.cognitiveCapacity < configuration.cognitiveLoadThreshold &&
           !currentSurfacedItems.isEmpty {
            return false
        }
        
        return configuration.enableProactiveSurfacing
    }
    
    private func getTaskComplexity(_ taskType: BubbleUpTaskType) -> Double {
        switch taskType {
        case .focus, .planning, .creative: return 0.8
        case .implementation, .action: return 0.7
        case .reflection, .preparation: return 0.5
        case .routine, .maintenance, .review: return 0.3
        }
    }
    
    private func calculateRecencyScore(_ date: Date) -> Double {
        let hoursAgo = Date().timeIntervalSince(date) / 3600
        return max(0.1, 1.0 - (hoursAgo / 168.0)) // Decay over 1 week
    }
    
    private func setupDopamineWindowTracking() {
        Timer.publish(every: 300, on: .main, in: .common) // Check every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                let newWindow = DopamineWindow.current
                if newWindow != self?.currentDopamineWindow {
                    self?.currentDopamineWindow = newWindow
                    self?.logger.info("Dopamine window changed to: \(newWindow.rawValue)")
                    
                    // Trigger bubble-up on window change
                    Task { @MainActor in
                        try? await self?.runBubbleUpAlgorithm()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupAutomaticSurfacing() {
        guard configuration.enableProactiveSurfacing else { return }
        
        surfacingTimer = Timer.scheduledTimer(withTimeInterval: configuration.surfacingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.runBubbleUpAlgorithm()
            }
        }
    }
    
    private func stopAutomaticSurfacing() {
        surfacingTimer?.invalidate()
        surfacingTimer = nil
    }
    
    // MARK: - Memory System Integration
    
    /// Handle memory consolidation events that may surface new thoughts
    public func handleMemoryConsolidation(event: ConsolidationEvent) async {
        logger.info("Processing memory consolidation event: \(event.eventType.rawValue)")
        
        switch event.eventType {
        case .newFusion:
            await handleNewFusionNode(event)
        case .semanticConsolidation:
            await handleSemanticConsolidation(event)
        case .episodicConsolidation:
            await handleEpisodicConsolidation(event)
        case .crossLayerInsight:
            await handleCrossLayerInsight(event)
        case .thoughtExtraction:
            await handleNewThoughtExtraction(event)
        }
    }
    
    /// Monitor for newly extracted thoughts that should bubble up
    public func monitorThoughtExtraction() async {
        // Query for recent high-importance thoughts from the memory system
        let recentThoughts = await getRecentHighImportanceThoughts()
        
        for thought in recentThoughts {
            if await shouldBubbleUpThought(thought) {
                await createBubbleUpFromThought(thought)
            }
        }
    }
    
    /// Create fusion-based bubble-ups from cross-layer connections
    public func monitorFusionNodes() async {
        let recentFusions = cognitiveMemorySystem.fusionNodes.filter { fusion in
            fusion.timestamp > Date().addingTimeInterval(-3600) // Last hour
        }
        
        for fusion in recentFusions {
            if await shouldBubbleUpFusion(fusion) {
                await createBubbleUpFromFusion(fusion)
            }
        }
    }
    
    /// Start monitoring memory system for bubble-up opportunities
    public func startMemoryMonitoring() {
        Task.detached { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 300 * 1_000_000_000) // 5 minutes
                
                guard let self = self else { break }
                
                await self.monitorThoughtExtraction()
                await self.monitorFusionNodes()
                await self.checkMemoryConsolidationTriggers()
                await self.monitorKnowledgeGraphChanges()
            }
        }
    }
    
    /// Get recently extracted thoughts that meet importance criteria
    private func getRecentHighImportanceThoughts() async -> [Thought] {
        do {
            let descriptor = FetchDescriptor<Thought>(
                predicate: #Predicate<Thought> { thought in
                    thought.timestamp > Date().addingTimeInterval(-1800) && // Last 30 minutes
                    (thought.importance == .high || thought.importance == .critical)
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            
            let thoughts = try modelContext.fetch(descriptor)
            logger.debug("Found \(thoughts.count) recent high-importance thoughts")
            return thoughts
        } catch {
            logger.error("Failed to fetch recent thoughts: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Check if a thought should bubble up based on cognitive criteria
    private func shouldBubbleUpThought(_ thought: Thought) async -> Bool {
        // High or critical importance thoughts are candidates
        guard thought.importance.priority >= 3 else { return false }
        
        // Don't bubble up fragments unless critical
        if thought.completeness == .fragment && thought.importance != .critical {
            return false
        }
        
        // Check if already bubbled up recently
        let existingItem = await findExistingBubbleUpItem(for: thought)
        if let existing = existingItem,
           existing.createdAt > Date().addingTimeInterval(-3600) { // Within last hour
            return false
        }
        
        // Task and decision thoughts are high priority for bubble-up
        if thought.thoughtType == .task || thought.thoughtType == .decision || thought.thoughtType == .goal {
            return true
        }
        
        // Questions and insights bubble up if they're high importance
        if (thought.thoughtType == .question || thought.thoughtType == .insight) && 
           thought.importance == .high {
            return true
        }
        
        return false
    }
    
    /// Check if a fusion node should generate a bubble-up
    private func shouldBubbleUpFusion(_ fusion: FusionNode) async -> Bool {
        // Only bubble up high-coherence, novel fusions
        guard fusion.coherenceScore > 0.7 && fusion.noveltyScore > 0.6 else { return false }
        
        // Don't bubble up if recently used
        if let lastBubbleUp = fusion.lastBubbleUpGeneration,
           lastBubbleUp > Date().addingTimeInterval(-3600) {
            return false
        }
        
        return true
    }
    
    /// Create a bubble-up item from a thought
    private func createBubbleUpFromThought(_ thought: Thought) async {
        let content = thought.content
        let taskType: BubbleUpTaskType = thought.thoughtType == .task ? .actionable : 
                                        thought.thoughtType == .decision ? .decision : .reminder
        
        let bubbleUpItem = BubbleUpItem(
            content: content,
            taskType: taskType,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(300), // Surface in 5 minutes
            importance: Double(thought.importance.priority) / 4.0,
            contextTags: thought.tags,
            relatedMemoryIDs: []
        )
        
        // Set cognitive metadata from thought
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "thoughtType": Double(thought.thoughtType == .task ? 0.8 : 0.6),
                "completeness": Double(thought.completeness == .complete ? 0.8 : 0.5),
                "hasContext": Double(thought.contextBefore != nil || thought.contextAfter != nil ? 0.7 : 0.4)
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: thought.thoughtType == .task ? [Date().addingTimeInterval(1800)] : [],
                urgencyPattern: thought.importance == .critical ? .exponential : .linear,
                proximityMultiplier: 2.0
            ),
            locationRelevance: LocationRelevance(
                contextMultipliers: [:],
                geospatialRelevance: []
            ),
            privacySensitivity: 0.3,
            contextDependency: 0.7,
            lastUpdated: Date()
        )
        
        // Link to the source thought
        bubbleUpItem.sourceThoughtID = thought.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from thought: \(content.prefix(50))")
    }
    
    /// Create a bubble-up item from a fusion node
    private func createBubbleUpFromFusion(_ fusion: FusionNode) async {
        guard let insight = await generateInsightFromFusion(fusion, context: await getCurrentOrchestratorContext()) else {
            return
        }
        
        let bubbleUpItem = BubbleUpItem(
            content: insight,
            taskType: .insight,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(600), // 10 minutes
            importance: fusion.strengthScore,
            contextTags: ["fusion", "cross-layer", "insight"],
            relatedMemoryIDs: []
        )
        
        // Set fusion-specific cognitive metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "coherenceScore": fusion.coherenceScore,
                "noveltyScore": fusion.noveltyScore,
                "strengthScore": fusion.strengthScore,
                "fusionType": fusion.fusionType == .insight ? 0.9 : 0.7
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: [Date().addingTimeInterval(3600)], // Next hour
                urgencyPattern: .insight,
                proximityMultiplier: 1.5
            ),
            locationRelevance: LocationRelevance(
                contextMultipliers: [:],
                geospatialRelevance: []
            ),
            privacySensitivity: calculateEntityPrivacySensitivity(fusion),
            contextDependency: 0.8,
            lastUpdated: Date()
        )
        
        // Link to fusion node
        bubbleUpItem.fusionNodeID = fusion.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        // Update fusion node's bubble-up timestamp
        fusion.lastBubbleUpGeneration = Date()
        
        logger.info("Created bubble-up from fusion: \(insight.prefix(50))")
    }
    
    /// Find existing bubble-up item for a thought
    private func findExistingBubbleUpItem(for thought: Thought) async -> BubbleUpItem? {
        do {
            let descriptor = FetchDescriptor<BubbleUpItem>(
                predicate: #Predicate<BubbleUpItem> { item in
                    item.sourceThoughtID == thought.id
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            let items = try modelContext.fetch(descriptor)
            return items.first
        } catch {
            logger.error("Failed to find existing bubble-up item: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Check for memory consolidation triggers that should create bubble-ups
    private func checkMemoryConsolidationTriggers() async {
        // Check if consolidation created new insights worth surfacing
        let systemStatus = await cognitiveMemorySystem.getSystemStatus()
        
        if let lastConsolidation = systemStatus.lastConsolidation,
           lastConsolidation > Date().addingTimeInterval(-1800) { // Last 30 minutes
            
            // Look for new fusion nodes created during consolidation
            let newFusions = cognitiveMemorySystem.fusionNodes.filter { fusion in
                fusion.timestamp > lastConsolidation
            }
            
            for fusion in newFusions {
                if await shouldBubbleUpFusion(fusion) {
                    await createBubbleUpFromFusion(fusion)
                }
            }
        }
    }
    
    // MARK: - Memory Event Handlers
    
    private func handleNewFusionNode(_ event: ConsolidationEvent) async {
        logger.debug("Handling new fusion node from consolidation")
        // Fusion nodes are handled by monitorFusionNodes()
    }
    
    private func handleSemanticConsolidation(_ event: ConsolidationEvent) async {
        logger.debug("Handling semantic consolidation event")
        // Check if semantic consolidation revealed new patterns
        if let insights = await analyzeConsolidationPatterns(context: await getCurrentOrchestratorContext()) {
            for insight in insights {
                await createBubbleUpFromConsolidationInsight(insight)
            }
        }
    }
    
    private func handleEpisodicConsolidation(_ event: ConsolidationEvent) async {
        logger.debug("Handling episodic consolidation event")
        // Episodic consolidation may surface relevant memories for current context
    }
    
    private func handleCrossLayerInsight(_ event: ConsolidationEvent) async {
        logger.debug("Handling cross-layer insight from consolidation")
        // Cross-layer insights are high-value bubble-up candidates
    }
    
    private func handleNewThoughtExtraction(_ event: ConsolidationEvent) async {
        logger.debug("Handling new thought extraction event")
        await monitorThoughtExtraction()
    }
    
    private func createBubbleUpFromConsolidationInsight(_ insight: ConsolidationInsight) async {
        let bubbleUpItem = BubbleUpItem(
            content: insight.content,
            taskType: insight.taskType,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(insight.urgency < 0.3 ? 1800 : 300), // 30 min or 5 min
            importance: insight.importance,
            contextTags: insight.tags,
            relatedMemoryIDs: insight.relatedMemoryIDs
        )
        
        // Set consolidation-based cognitive metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "consolidationImportance": insight.importance,
                "contextMatch": insight.contextMatch,
                "urgency": insight.urgency
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: insight.urgency > 0.7 ? [Date().addingTimeInterval(900)] : [],
                urgencyPattern: insight.urgency > 0.5 ? .exponential : .linear,
                proximityMultiplier: insight.urgency > 0.7 ? 3.0 : 1.5
            ),
            locationRelevance: LocationRelevance(
                contextMultipliers: [:],
                geospatialRelevance: []
            ),
            privacySensitivity: 0.4,
            contextDependency: insight.contextMatch,
            lastUpdated: Date()
        )
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from consolidation insight: \(insight.content.prefix(50))")
    }
    
    // MARK: - Knowledge Graph Integration
    
    /// Monitor knowledge graph for entity changes that should bubble up
    private func monitorKnowledgeGraphChanges() async {
        guard let knowledgeGraphService = knowledgeGraphService else {
            logger.debug("Knowledge graph service not available - skipping graph monitoring")
            return
        }
        
        logger.debug("Monitoring knowledge graph changes for bubble-up opportunities")
        
        // Monitor for newly created high-importance entities
        await monitorNewEntities()
        
        // Monitor for relationship changes that suggest important connections
        await monitorEntityRelationshipChanges()
        
        // Monitor for cognitive fusion connections involving entities
        await monitorEntityCognitiveFusions()
        
        // Monitor for entities with recent mention spikes
        await monitorEntityMentionSpikes()
        
        // Monitor for location/time-based entity relevance changes
        await monitorEntityContextualRelevance()
    }
    
    /// Monitor for newly created entities that should bubble up
    private func monitorNewEntities() async {
        guard let knowledgeGraphService = knowledgeGraphService else { return }
        
        // Query for entities created in the last 30 minutes
        let recentThreshold = Date().addingTimeInterval(-1800) // 30 minutes ago
        
        let newEntities = knowledgeGraphService.entities.filter { entity in
            entity.timestamp > recentThreshold && 
            (entity.importance > 0.6 || entity.mentions > 2 || entity.isValidated)
        }
        
        for entity in newEntities {
            if await shouldBubbleUpEntity(entity) {
                await createBubbleUpFromEntity(entity)
            }
        }
        
        if !newEntities.isEmpty {
            logger.info("Found \(newEntities.count) new entities for potential bubble-up")
        }
    }
    
    /// Monitor for relationship changes that indicate important connections
    private func monitorEntityRelationshipChanges() async {
        guard let knowledgeGraphService = knowledgeGraphService else { return }
        
        // Find entities that recently gained significant new relationships
        let recentThreshold = Date().addingTimeInterval(-1800) // 30 minutes ago
        let relationshipThreshold = 3 // Minimum connections to be considered significant
        
        for entity in knowledgeGraphService.entities {
            let recentRelationships = knowledgeGraphService.relationships.filter { relationship in
                relationship.timestamp > recentThreshold &&
                (relationship.subjectEntityId == entity.id || relationship.objectEntityId == entity.id) &&
                relationship.confidence > 0.7
            }
            
            if recentRelationships.count >= relationshipThreshold {
                if await shouldBubbleUpEntityFromRelationshipGrowth(entity, newRelationships: recentRelationships) {
                    await createBubbleUpFromEntityRelationshipGrowth(entity, relationships: recentRelationships)
                }
            }
        }
    }
    
    /// Monitor for entities involved in cognitive fusions
    private func monitorEntityCognitiveFusions() async {
        guard let knowledgeGraphService = knowledgeGraphService,
              let cognitiveAdapter = knowledgeGraphCognitiveAdapter else { return }
        
        // Find entities with recent cognitive fusion connections
        let recentFusionThreshold = Date().addingTimeInterval(-3600) // 1 hour ago
        
        for entity in knowledgeGraphService.entities {
            if entity.hasCognitiveRepresentation &&
               !entity.fusionConnectionIds.isEmpty &&
               (entity.lastCognitiveSyncAt ?? Date.distantPast) > recentFusionThreshold {
                
                if await shouldBubbleUpEntityFromCognitiveFusion(entity) {
                    await createBubbleUpFromEntityCognitiveFusion(entity)
                }
            }
        }
    }
    
    /// Monitor for entities with recent mention spikes
    private func monitorEntityMentionSpikes() async {
        guard let knowledgeGraphService = knowledgeGraphService else { return }
        
        let recentThreshold = Date().addingTimeInterval(-3600) // 1 hour ago
        let spikeThreshold = 0.5 // Significant increase in mentions
        
        for entity in knowledgeGraphService.entities {
            if entity.lastMentioned > recentThreshold {
                let dailyMentionAverage = Double(entity.mentions) / max(1.0, Date().timeIntervalSince(entity.timestamp) / 86400)
                let recentMentionRate = calculateRecentMentionRate(entity)
                
                // Check for mention spike (recent rate significantly higher than average)
                if recentMentionRate > dailyMentionAverage * (1.0 + spikeThreshold) {
                    if await shouldBubbleUpEntityFromMentionSpike(entity, spikeRatio: recentMentionRate / dailyMentionAverage) {
                        await createBubbleUpFromEntityMentionSpike(entity, spikeRatio: recentMentionRate / dailyMentionAverage)
                    }
                }
            }
        }
    }
    
    /// Monitor for entities with contextual relevance changes based on time/location
    private func monitorEntityContextualRelevance() async {
        guard let knowledgeGraphService = knowledgeGraphService else { return }
        
        let currentContext = await getCurrentOrchestratorContext()
        
        // Check for location-relevant entities
        for entity in knowledgeGraphService.entities {
            if entity.type == .location || entity.type == .place {
                if await isEntityLocationRelevant(entity, context: currentContext) {
                    if await shouldBubbleUpEntityFromLocationRelevance(entity, context: currentContext) {
                        await createBubbleUpFromEntityLocationRelevance(entity, context: currentContext)
                    }
                }
            }
            
            // Check for time-relevant entities (events, activities with temporal context)
            if entity.type == .event || entity.type == .activity {
                if await isEntityTimeRelevant(entity, context: currentContext) {
                    if await shouldBubbleUpEntityFromTimeRelevance(entity, context: currentContext) {
                        await createBubbleUpFromEntityTimeRelevance(entity, context: currentContext)
                    }
                }
            }
        }
    }
    
    /// Determine if entity should bubble up based on general criteria
    private func shouldBubbleUpEntity(_ entity: Entity) async -> Bool {
        // Check if entity already has a recent bubble-up
        if await hasRecentBubbleUpForEntity(entity.id) {
            return false
        }
        
        // High importance threshold
        if entity.importance > 0.8 {
            return true
        }
        
        // High confidence + validated combination
        if entity.confidence > 0.8 && entity.isValidated {
            return true
        }
        
        // Recent high-frequency mentions
        if entity.mentions > 5 && entity.lastMentioned > Date().addingTimeInterval(-1800) {
            return true
        }
        
        // Strong cognitive representation
        if entity.hasCognitiveRepresentation && entity.cognitiveConsolidationScore > 0.7 {
            return true
        }
        
        return false
    }
    
    /// Create bubble-up item from entity
    private func createBubbleUpFromEntity(_ entity: Entity) async {
        let entityInsight = await generateEntityInsight(entity)
        let taskType = mapEntityTypeToTaskType(entity.type)
        
        let bubbleUpItem = BubbleUpItem(
            content: entityInsight,
            taskType: taskType,
            createdAt: Date(),
            scheduledFor: calculateOptimalScheduleTime(for: entity),
            importance: entity.enhancedEntityScore,
            contextTags: generateEntityTags(entity),
            relatedMemoryIDs: [],
            relatedEntityIDs: [entity.id]
        )
        
        // Set entity-specific cognitive metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "entityImportance": entity.importance,
                "entityScore": entity.enhancedEntityScore,
                "mentionCount": min(1.0, Double(entity.mentions) / 10.0),
                "confidence": entity.confidence,
                "cognitiveScore": entity.cognitiveConsolidationScore
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: entity.lastMentioned > Date().addingTimeInterval(-3600) ? [Date().addingTimeInterval(1800)] : [],
                urgencyPattern: entity.type == .event ? .exponential : .linear,
                proximityMultiplier: entity.mentions > 5 ? 2.0 : 1.5
            ),
            locationRelevance: LocationRelevance(
                contextMultipliers: entity.type == .location ? ["current_location": 2.0] : [:],
                geospatialRelevance: entity.type == .location || entity.type == .place ? [entity.name] : []
            ),
            privacySensitivity: calculateEntityPrivacySensitivity(entity),
            contextDependency: 0.7,
            lastUpdated: Date()
        )
        
        // Link to source entity
        bubbleUpItem.sourceEntityID = entity.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from entity: \(entity.name)")
    }
    
    /// Create bubble-up from entity relationship growth
    private func createBubbleUpFromEntityRelationshipGrowth(_ entity: Entity, relationships: [Relationship]) async {
        let relationshipInsight = "The entity '\(entity.name)' has formed \(relationships.count) new significant connections, suggesting growing importance in your network."
        
        let bubbleUpItem = BubbleUpItem(
            content: relationshipInsight,
            taskType: .insight,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(600), // 10 minutes
            importance: min(0.9, entity.importance + (Double(relationships.count) * 0.1)),
            contextTags: ["relationship_growth", "network", "connections", entity.type.rawValue],
            relatedMemoryIDs: [],
            relatedEntityIDs: [entity.id] + relationships.flatMap { [$0.subjectEntityId, $0.objectEntityId] }
        )
        
        // Set relationship growth metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "relationshipCount": Double(relationships.count),
                "relationshipQuality": relationships.map { $0.confidence }.reduce(0, +) / Double(relationships.count),
                "entityImportance": entity.importance
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: [Date().addingTimeInterval(1800)],
                urgencyPattern: .linear,
                proximityMultiplier: 2.0
            ),
            locationRelevance: LocationRelevance(contextMultipliers: [:], geospatialRelevance: []),
            privacySensitivity: calculateEntityPrivacySensitivity(entity),
            contextDependency: 0.8,
            lastUpdated: Date()
        )
        
        bubbleUpItem.sourceEntityID = entity.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from entity relationship growth: \(entity.name)")
    }
    
    /// Create bubble-up from entity cognitive fusion
    private func createBubbleUpFromEntityCognitiveFusion(_ entity: Entity) async {
        let fusionInsight = "The concept of '\(entity.name)' has been connected across multiple layers of your cognitive memory, indicating deeper significance."
        
        let bubbleUpItem = BubbleUpItem(
            content: fusionInsight,
            taskType: .insight,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(300), // 5 minutes (high priority)
            importance: min(0.95, entity.enhancedEntityScore + 0.2),
            contextTags: ["cognitive_fusion", "deep_insight", "cross_layer", entity.type.rawValue],
            relatedMemoryIDs: [],
            relatedEntityIDs: [entity.id]
        )
        
        // Set cognitive fusion metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "cognitiveScore": entity.cognitiveConsolidationScore,
                "fusionConnections": Double(entity.fusionConnectionIds.count),
                "cognitiveRelevance": entity.cognitiveRelevanceScore
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: [Date().addingTimeInterval(900)],
                urgencyPattern: .exponential,
                proximityMultiplier: 3.0
            ),
            locationRelevance: LocationRelevance(contextMultipliers: [:], geospatialRelevance: []),
            privacySensitivity: calculateEntityPrivacySensitivity(entity),
            contextDependency: 0.9,
            lastUpdated: Date()
        )
        
        bubbleUpItem.sourceEntityID = entity.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from entity cognitive fusion: \(entity.name)")
    }
    
    /// Create bubble-up from entity mention spike
    private func createBubbleUpFromEntityMentionSpike(_ entity: Entity, spikeRatio: Double) async {
        let spikeRatioFormatted = String(format: "%.1f", spikeRatio)
        let spikeInsight = "'\(entity.name)' is being mentioned \(spikeRatioFormatted)x more than usual. This might indicate emerging importance."
        
        let bubbleUpItem = BubbleUpItem(
            content: spikeInsight,
            taskType: .insight,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(min(1800, max(300, 1800 / spikeRatio))), // Faster surfacing for bigger spikes
            importance: min(0.9, entity.importance + (min(0.3, spikeRatio - 1.0) * 0.1)),
            contextTags: ["mention_spike", "trending", "emerging", entity.type.rawValue],
            relatedMemoryIDs: [],
            relatedEntityIDs: [entity.id]
        )
        
        // Set mention spike metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "spikeRatio": min(5.0, spikeRatio),
                "mentionVelocity": Double(entity.mentions),
                "recency": Date().timeIntervalSince(entity.lastMentioned) < 3600 ? 1.0 : 0.5
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: [Date().addingTimeInterval(900)],
                urgencyPattern: .exponential,
                proximityMultiplier: min(3.0, spikeRatio)
            ),
            locationRelevance: LocationRelevance(contextMultipliers: [:], geospatialRelevance: []),
            privacySensitivity: calculateEntityPrivacySensitivity(entity),
            contextDependency: 0.6,
            lastUpdated: Date()
        )
        
        bubbleUpItem.sourceEntityID = entity.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from entity mention spike: \(entity.name) (ratio: \(spikeRatio))")
    }
    
    /// Create bubble-up from entity location relevance
    private func createBubbleUpFromEntityLocationRelevance(_ entity: Entity, context: OrchestratorContext) async {
        let locationInsight = "You're near '\(entity.name)' - this might be relevant to your current activities or plans."
        
        let bubbleUpItem = BubbleUpItem(
            content: locationInsight,
            taskType: .location,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(180), // 3 minutes (location is time-sensitive)
            importance: min(0.85, entity.importance + 0.3),
            contextTags: ["location_relevant", "spatial", "contextual", entity.type.rawValue],
            relatedMemoryIDs: [],
            relatedEntityIDs: [entity.id]
        )
        
        // Set location relevance metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "locationRelevance": 0.9,
                "proximityBoost": 0.8,
                "entityImportance": entity.importance
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: [Date().addingTimeInterval(600)], // Next 10 minutes
                urgencyPattern: .exponential,
                proximityMultiplier: 4.0
            ),
            locationRelevance: LocationRelevance(
                contextMultipliers: ["current_location": 3.0, "proximity": 2.5],
                geospatialRelevance: [entity.name]
            ),
            privacySensitivity: calculateEntityPrivacySensitivity(entity),
            contextDependency: 0.9,
            lastUpdated: Date()
        )
        
        bubbleUpItem.sourceEntityID = entity.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from entity location relevance: \(entity.name)")
    }
    
    /// Create bubble-up from entity time relevance
    private func createBubbleUpFromEntityTimeRelevance(_ entity: Entity, context: OrchestratorContext) async {
        let timeInsight = "'\(entity.name)' might be time-sensitive or scheduled for around now."
        
        let bubbleUpItem = BubbleUpItem(
            content: timeInsight,
            taskType: entity.type == .event ? .event : .task,
            createdAt: Date(),
            scheduledFor: Date().addingTimeInterval(300), // 5 minutes
            importance: min(0.9, entity.importance + 0.25),
            contextTags: ["time_relevant", "temporal", "scheduled", entity.type.rawValue],
            relatedMemoryIDs: [],
            relatedEntityIDs: [entity.id]
        )
        
        // Set time relevance metadata
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            aiImportanceFactors: [
                "timeRelevance": 0.85,
                "temporalBoost": 0.7,
                "entityImportance": entity.importance
            ],
            timeSensitivity: TimeSensitivity(
                criticalWindows: [Date(), Date().addingTimeInterval(1800)],
                urgencyPattern: .exponential,
                proximityMultiplier: 3.5
            ),
            locationRelevance: LocationRelevance(contextMultipliers: [:], geospatialRelevance: []),
            privacySensitivity: calculateEntityPrivacySensitivity(entity),
            contextDependency: 0.8,
            lastUpdated: Date()
        )
        
        bubbleUpItem.sourceEntityID = entity.id
        
        modelContext.insert(bubbleUpItem)
        try? modelContext.save()
        
        logger.info("Created bubble-up from entity time relevance: \(entity.name)")
    }
    
    // MARK: - Knowledge Graph Helper Methods
    
    /// Check if entity has recent bubble-up
    private func hasRecentBubbleUpForEntity(_ entityId: UUID) async -> Bool {
        do {
            let recentThreshold = Date().addingTimeInterval(-3600) // 1 hour
            let descriptor = FetchDescriptor<BubbleUpItem>(
                predicate: #Predicate<BubbleUpItem> { item in
                    item.sourceEntityID == entityId && item.createdAt > recentThreshold
                }
            )
            let items = try modelContext.fetch(descriptor)
            return !items.isEmpty
        } catch {
            logger.error("Failed to check for recent entity bubble-ups: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Calculate recent mention rate for entity
    private func calculateRecentMentionRate(_ entity: Entity) -> Double {
        // This is a simplified calculation - in practice, this would analyze 
        // mention timestamps from the entity's source data
        let recentTimeWindow = 3600.0 // 1 hour
        let timeSinceLastMention = Date().timeIntervalSince(entity.lastMentioned)
        
        if timeSinceLastMention > recentTimeWindow {
            return 0.0
        }
        
        // Estimate recent mention rate based on recency and total mentions
        let recencyFactor = (recentTimeWindow - timeSinceLastMention) / recentTimeWindow
        return Double(entity.mentions) * recencyFactor / max(1.0, Date().timeIntervalSince(entity.timestamp) / 86400)
    }
    
    /// Determine if entity is location-relevant
    private func isEntityLocationRelevant(_ entity: Entity, context: OrchestratorContext) async -> Bool {
        // Check environmental factors for location context
        let environmentalFactors = await getEnvironmentalFactors()
        
        // If we have location data, check proximity
        if let currentLocation = environmentalFactors["currentLocation"],
           currentLocation > 0.5 {
            return true
        }
        
        // Check if entity name matches any location-based context
        if let locationContext = environmentalFactors["locationContext"] {
            return locationContext > 0.3
        }
        
        return false
    }
    
    /// Determine if entity is time-relevant
    private func isEntityTimeRelevant(_ entity: Entity, context: OrchestratorContext) async -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if entity has temporal attributes that match current time
        if let timeAttribute = entity.attributes["scheduledTime"],
           let scheduledTime = ISO8601DateFormatter().date(from: timeAttribute) {
            return abs(scheduledTime.timeIntervalSince(now)) < 3600 // Within 1 hour
        }
        
        // Check if entity name contains time-related keywords
        let timeKeywords = ["today", "now", "tonight", "morning", "afternoon", "evening"]
        return timeKeywords.contains { keyword in
            entity.name.lowercased().contains(keyword) ||
            entity.entityDescription?.lowercased().contains(keyword) == true
        }
    }
    
    /// Generate insight text for entity
    private func generateEntityInsight(_ entity: Entity) async -> String {
        let insights = [
            "'\(entity.name)' has emerged as important in your knowledge network",
            "The concept of '\(entity.name)' might be worth exploring further",
            "'\(entity.name)' has gained significance - consider how it relates to your current activities",
            "You've been engaging with '\(entity.name)' - this could inform your next steps"
        ]
        
        // Select insight based on entity characteristics
        if entity.mentions > 5 {
            return "'\(entity.name)' has been mentioned frequently (\(entity.mentions) times) - it might be central to your current thinking"
        } else if entity.confidence > 0.8 {
            return "'\(entity.name)' has been identified with high confidence - consider its relevance to your goals"
        } else {
            return insights.randomElement() ?? insights[0]
        }
    }
    
    /// Map entity type to bubble-up task type
    private func mapEntityTypeToTaskType(_ entityType: EntityType) -> BubbleUpTaskType {
        switch entityType {
        case .person:
            return .social
        case .organization:
            return .work
        case .activity:
            return .task
        case .concept:
            return .insight
        case .location, .place:
            return .location
        case .event:
            return .event
        case .thing:
            return .task
        }
    }
    
    /// Generate context tags for entity
    private func generateEntityTags(_ entity: Entity) -> [String] {
        var tags = [entity.type.rawValue, "knowledge_graph"]
        
        if entity.isValidated {
            tags.append("validated")
        }
        
        if entity.confidence > 0.8 {
            tags.append("high_confidence")
        }
        
        if entity.mentions > 5 {
            tags.append("frequently_mentioned")
        }
        
        if entity.hasCognitiveRepresentation {
            tags.append("cognitive_enhanced")
        }
        
        tags.append(contentsOf: entity.tags)
        
        return tags
    }
    
    /// Calculate optimal schedule time for entity bubble-up
    private func calculateOptimalScheduleTime(for entity: Entity) -> Date {
        var delay: TimeInterval = 900 // Default 15 minutes
        
        // High importance entities surface faster
        if entity.importance > 0.8 {
            delay = 300 // 5 minutes
        } else if entity.importance > 0.6 {
            delay = 600 // 10 minutes
        }
        
        // Recent mentions surface faster
        if entity.lastMentioned > Date().addingTimeInterval(-1800) {
            delay *= 0.5
        }
        
        // Location/event types are more time-sensitive
        if entity.type == .location || entity.type == .event {
            delay *= 0.3
        }
        
        return Date().addingTimeInterval(delay)
    }
    
    /// Calculate privacy sensitivity for entity
    private func calculateEntityPrivacySensitivity(_ entity: Entity) -> Double {
        var sensitivity = 0.3 // Base sensitivity
        
        if entity.type == .person {
            sensitivity = 0.7 // People are more sensitive
        }
        
        // Check for privacy-related keywords
        let privateKeywords = ["private", "personal", "confidential", "secret"]
        if let description = entity.entityDescription,
           privateKeywords.contains(where: { description.lowercased().contains($0) }) {
            sensitivity += 0.3
        }
        
        return min(1.0, sensitivity)
    }
    
    /// Entity relationship growth evaluation helpers
    private func shouldBubbleUpEntityFromRelationshipGrowth(_ entity: Entity, newRelationships: [Relationship]) async -> Bool {
        let recent = await hasRecentBubbleUpForEntity(entity.id)
        return !newRelationships.isEmpty && entity.importance > 0.4 && !recent
    }
    
    private func shouldBubbleUpEntityFromCognitiveFusion(_ entity: Entity) async -> Bool {
        let recent = await hasRecentBubbleUpForEntity(entity.id)
        return entity.cognitiveConsolidationScore > 0.5 && !recent
    }
    
    private func shouldBubbleUpEntityFromMentionSpike(_ entity: Entity, spikeRatio: Double) async -> Bool {
        let recent = await hasRecentBubbleUpForEntity(entity.id)
        return spikeRatio > 1.5 && entity.importance > 0.3 && !recent
    }
    
    private func shouldBubbleUpEntityFromLocationRelevance(_ entity: Entity, context: OrchestratorContext) async -> Bool {
        let recent = await hasRecentBubbleUpForEntity(entity.id)
        return entity.importance > 0.2 && !recent
    }
    
    private func shouldBubbleUpEntityFromTimeRelevance(_ entity: Entity, context: OrchestratorContext) async -> Bool {
        let recent = await hasRecentBubbleUpForEntity(entity.id)
        return entity.importance > 0.2 && !recent
    }

    // MARK: - CoachCard Integration
    
    /// Create a CoachCardData from a bubble-up item with memory creation capability
    public func createCoachCard(from bubbleUpItem: BubbleUpItem, context: OrchestratorContext? = nil) async -> CoachCardData {
        let contextToUse = context ?? await getCurrentOrchestratorContext()
        
        // Generate personalized coach message based on bubble-up characteristics
        let coachMessage = generateCoachMessage(for: bubbleUpItem, context: contextToUse)
        
        // Create actions based on bubble-up type and cognitive metadata
        let actions = generateCoachCardActions(for: bubbleUpItem, context: contextToUse)
        
        // Determine visual styling based on importance and task type
        let style = determineCoachCardStyle(for: bubbleUpItem)
        
        return CoachCardData(
            id: bubbleUpItem.id,
            coachMessage: coachMessage,
            actions: actions,
            style: style,
            priority: bubbleUpItem.priority.finalScore,
            bubbleUpItem: bubbleUpItem
        )
    }
    
    /// Generate contextual coach message for the bubble-up item
    private func generateCoachMessage(for bubbleUpItem: BubbleUpItem, context: OrchestratorContext) -> String {
        let baseContent = bubbleUpItem.content
        
        // Customize message based on task type and cognitive factors
        switch bubbleUpItem.taskType {
        case .focus, .planning:
            return "🎯 Time to focus: \(baseContent)"
        case .creative:
            return "💡 Creative inspiration: \(baseContent)"
        case .reflection:
            return "🤔 Worth reflecting on: \(baseContent)"
        case .action, .implementation:
            return "⚡ Ready to act: \(baseContent)"
        case .routine, .maintenance:
            return "🔄 Routine check: \(baseContent)"
        case .preparation:
            return "📝 Prepare for: \(baseContent)"
        case .review:
            return "📊 Time to review: \(baseContent)"
        }
    }
    
    /// Generate appropriate actions for the coach card
    private func generateCoachCardActions(for bubbleUpItem: BubbleUpItem, context: OrchestratorContext) -> [CoachCardAction] {
        var actions: [CoachCardAction] = []
        
        // Always include memory creation action
        let createMemoryAction = CoachCardAction(
            id: UUID(),
            title: "💭 Create Memory",
            actionType: .createMemory,
            isDestructive: false,
            requiresConfirmation: false
        )
        actions.append(createMemoryAction)
        
        // Add task-specific actions based on bubble-up type
        switch bubbleUpItem.taskType {
        case .focus:
            actions.append(CoachCardAction(
                id: UUID(),
                title: "🎯 Start Focus Session",
                actionType: .startTimer,
                isDestructive: false,
                requiresConfirmation: false
            ))
            
        case .creative:
            actions.append(CoachCardAction(
                id: UUID(),
                title: "💡 Explore Ideas",
                actionType: .openNotes,
                isDestructive: false,
                requiresConfirmation: false
            ))
            
        case .action, .implementation:
            actions.append(CoachCardAction(
                id: UUID(),
                title: "✅ Mark as Done",
                actionType: .markComplete,
                isDestructive: false,
                requiresConfirmation: false
            ))
            
        case .planning:
            actions.append(CoachCardAction(
                id: UUID(),
                title: "📅 Schedule",
                actionType: .schedule,
                isDestructive: false,
                requiresConfirmation: false
            ))
            
        case .reflection:
            actions.append(CoachCardAction(
                id: UUID(),
                title: "📝 Journal",
                actionType: .openJournal,
                isDestructive: false,
                requiresConfirmation: false
            ))
            
        default:
            // Generic actions for other types
            actions.append(CoachCardAction(
                id: UUID(),
                title: "📋 Add to Tasks",
                actionType: .addToTasks,
                isDestructive: false,
                requiresConfirmation: false
            ))
        }
        
        // Add dismiss action (always last)
        let dismissAction = CoachCardAction(
            id: UUID(),
            title: "⏭️ Maybe Later",
            actionType: .dismiss,
            isDestructive: false,
            requiresConfirmation: false
        )
        actions.append(dismissAction)
        
        return actions
    }
    
    /// Determine visual style based on bubble-up characteristics
    private func determineCoachCardStyle(for bubbleUpItem: BubbleUpItem) -> CoachCardStyle {
        let importance = bubbleUpItem.priority.finalScore
        
        // High importance items get attention-grabbing styles
        if importance > 0.8 {
            return CoachCardStyle(
                backgroundColor: .red.opacity(0.1),
                borderColor: .red,
                accentColor: .red,
                animation: .pulse
            )
        } else if importance > 0.6 {
            return CoachCardStyle(
                backgroundColor: .orange.opacity(0.1),
                borderColor: .orange,
                accentColor: .orange,
                animation: .gentle
            )
        }
        
        // Task-type specific styling
        switch bubbleUpItem.taskType {
        case .creative:
            return CoachCardStyle(
                backgroundColor: .purple.opacity(0.1),
                borderColor: .purple,
                accentColor: .purple,
                animation: .sparkle
            )
        case .focus:
            return CoachCardStyle(
                backgroundColor: .blue.opacity(0.1),
                borderColor: .blue,
                accentColor: .blue,
                animation: .focus
            )
        case .reflection:
            return CoachCardStyle(
                backgroundColor: .green.opacity(0.1),
                borderColor: .green,
                accentColor: .green,
                animation: .gentle
            )
        default:
            return CoachCardStyle(
                backgroundColor: .gray.opacity(0.05),
                borderColor: .gray,
                accentColor: .gray,
                animation: .none
            )
        }
    }
    
    /// Get current coach cards for display
    public func getCurrentCoachCards() async -> [CoachCardData] {
        let context = await getCurrentOrchestratorContext()
        var coachCards: [CoachCardData] = []
        
        for bubbleUpItem in currentSurfacedItems {
            let coachCard = await createCoachCard(from: bubbleUpItem, context: context)
            coachCards.append(coachCard)
        }
        
        // Sort by priority (highest first)
        coachCards.sort { $0.priority > $1.priority }
        
        return coachCards
    }
    
    /// Handle coach card action and update bubble-up item accordingly
    public func handleCoachCardAction(_ action: CoachCardAction, for cardData: CoachCardData) async {
        guard let bubbleUpItem = cardData.bubbleUpItem else {
            logger.warning("Coach card action called without bubble-up item")
            return
        }
        
        logger.info("Handling coach card action: \(action.actionType.rawValue) for item \(bubbleUpItem.id)")
        
        // Record engagement based on action type
        switch action.actionType {
        case .createMemory:
            bubbleUpItem.recordEngagement(.interacted, metadata: ["action": "create_memory"])
        case .markComplete:
            bubbleUpItem.recordEngagement(.completed, metadata: ["action": "mark_complete"])
        case .dismiss:
            bubbleUpItem.recordEngagement(.dismissed, metadata: ["action": "dismiss"])
        default:
            bubbleUpItem.recordEngagement(.interacted, metadata: ["action": action.actionType.rawValue])
        }
        
        // Handle specific actions
        switch action.actionType {
        case .dismiss:
            await removeBubbleUpFromSurface(bubbleUpItem)
        case .markComplete:
            bubbleUpItem.markCompleted()
            await removeBubbleUpFromSurface(bubbleUpItem)
        default:
            // Most actions just record engagement, UI handles the specific behavior
            break
        }
        
        // Save changes
        try? modelContext.save()
    }
    
    /// Remove bubble-up item from currently surfaced items
    private func removeBubbleUpFromSurface(_ bubbleUpItem: BubbleUpItem) async {
        currentSurfacedItems.removeAll { $0.id == bubbleUpItem.id }
        bubbleUpItem.lastSurfaced = Date()
    }

    // MARK: - Memory Consolidation Triggers
    
    /// Called when memory system completes consolidation - creates bubble-ups for new insights
    public func onMemoryConsolidation(consolidationResult: MemoryConsolidationResult) async throws {
        logger.info("Processing memory consolidation triggers for bubble-up generation")
        
        // Process fusion nodes created during consolidation
        for fusionNode in consolidationResult.newFusionNodes {
            await processFusionNodeForBubbleUp(fusionNode)
        }
        
        // Process cross-layer connections
        for connection in consolidationResult.newCrossLayerConnections {
            await processCrossLayerConnectionForBubbleUp(connection)
        }
        
        // Process patterns detected during consolidation
        for pattern in consolidationResult.detectedPatterns {
            await processMemoryPatternForBubbleUp(pattern)
        }
        
        // Process memory pressure indicators
        if consolidationResult.memoryPressureReduction > 0.2 {
            await createMemoryConsolidationInsight(consolidationResult)
        }
        
        // Save any new bubble-up items
        try await saveBubbleUpItems()
        
        logger.info("Generated \(pendingItems.count) bubble-ups from memory consolidation")
    }
    
    /// Creates a bubble-up from a new fusion node
    private func processFusionNodeForBubbleUp(_ fusionNode: FusionNode) async {
        // Skip if fusion doesn't meet novelty threshold
        guard fusionNode.noveltyScore > 0.6 else { return }
        
        let bubbleUpItem = BubbleUpItem(
            content: generateFusionInsightContent(fusionNode),
            taskType: .reflection,
            sourceEntityID: fusionNode.id,
            tags: ["fusion_insight", "memory_consolidation"] + extractTagsFromFusion(fusionNode)
        )
        
        // Set high priority based on fusion characteristics
        let priority = BubbleUpPriority(
            baseScore: fusionNode.strengthScore,
            urgencyMultiplier: 1.2, // Fusion insights are valuable
            timedecayRate: 0.8,
            contextualFactors: [:]
        )
        bubbleUpItem.priority = priority
        
        // Add cognitive metadata reflecting fusion properties
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            attentionCaptureFactors: [.novelty, .personalRelevance],
            dopamineTriggers: [.challengeEngagement, .progressVisual],
            cognitiveLoad: CognitivePressure(
                perceptualLoad: 0.3,
                cognitiveLoad: 0.7,
                memoryLoad: 0.4
            ),
            locationRelevance: LocationRelevance(relevantLocations: [], spatialContext: ""),
            timeSensitivity: TimeSensitivity(urgencyPattern: .exponential, decayRate: 0.1),
            emotionalRelevance: fusionNode.emotionalResonance,
            personalRelevance: calculatePersonalRelevance(for: fusionNode),
            aiConfidence: fusionNode.coherenceScore
        )
        
        // Calculate optimal timing based on fusion characteristics
        let nextDueTime = Date().addingTimeInterval(calculateFusionBubbleUpDelay(fusionNode))
        bubbleUpItem.nextDueTime = nextDueTime
        
        pendingItems.append(bubbleUpItem)
        await addToDopamineWave(bubbleUpItem, phase: .reflection)
        
        logger.debug("Created fusion bubble-up: \(fusionNode.fusionType.rawValue)")
    }
    
    /// Creates bubble-ups from cross-layer memory connections
    private func processCrossLayerConnectionForBubbleUp(_ connection: CrossLayerConnection) async {
        // Only create bubble-ups for strong connections
        guard connection.strengthScore > 0.7 else { return }
        
        let bubbleUpItem = BubbleUpItem(
            content: generateConnectionInsightContent(connection),
            taskType: .creative, // Cross-layer connections often lead to creative insights
            sourceEntityID: UUID(), // Connection doesn't have UUID, create new
            tags: ["cross_layer", "pattern_recognition", "memory_integration"]
        )
        
        let priority = BubbleUpPriority(
            baseScore: connection.strengthScore,
            urgencyMultiplier: 1.0,
            timedecayRate: 0.9,
            contextualFactors: [:]
        )
        bubbleUpItem.priority = priority
        
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            attentionCaptureFactors: [.personalRelevance, .novelty],
            dopamineTriggers: [.challengeEngagement, .noveltyStimulus],
            cognitiveLoad: CognitivePressure(
                perceptualLoad: 0.2,
                cognitiveLoad: 0.6,
                memoryLoad: 0.5
            ),
            locationRelevance: LocationRelevance(relevantLocations: [], spatialContext: ""),
            timeSensitivity: TimeSensitivity(urgencyPattern: .linear, decayRate: 0.05),
            emotionalRelevance: 0.5,
            personalRelevance: connection.relevanceScore,
            aiConfidence: connection.strengthScore
        )
        
        let nextDueTime = Date().addingTimeInterval(TimeInterval.random(in: 300...1800)) // 5-30 minutes
        bubbleUpItem.nextDueTime = nextDueTime
        
        pendingItems.append(bubbleUpItem)
        await addToDopamineWave(bubbleUpItem, phase: .creative)
        
        logger.debug("Created cross-layer connection bubble-up")
    }
    
    /// Creates bubble-ups from detected memory patterns
    private func processMemoryPatternForBubbleUp(_ pattern: DetectedMemoryPattern) async {
        // Only surface significant patterns
        guard pattern.significanceScore > 0.6 else { return }
        
        let taskType: BubbleUpTaskType = {
            switch pattern.patternType {
            case .recurring: return .routine
            case .emerging: return .creative
            case .temporal: return .planning
            case .emotional: return .reflection
            case .behavioral: return .action
            }
        }()
        
        let bubbleUpItem = BubbleUpItem(
            content: generatePatternInsightContent(pattern),
            taskType: taskType,
            sourceEntityID: UUID(),
            tags: ["pattern_analysis", pattern.patternType.rawValue, "behavioral_insight"]
        )
        
        let priority = BubbleUpPriority(
            baseScore: pattern.significanceScore,
            urgencyMultiplier: pattern.isActionable ? 1.3 : 0.9,
            timedecayRate: 0.7,
            contextualFactors: [:]
        )
        bubbleUpItem.priority = priority
        
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            attentionCaptureFactors: [.personalRelevance, .urgency],
            dopamineTriggers: pattern.isActionable ? [.immediateReward, .completionSatisfaction] : [.noveltyStimulus],
            cognitiveLoad: CognitivePressure(
                perceptualLoad: 0.3,
                cognitiveLoad: 0.5,
                memoryLoad: 0.6
            ),
            locationRelevance: LocationRelevance(relevantLocations: [], spatialContext: ""),
            timeSensitivity: TimeSensitivity(
                urgencyPattern: pattern.isTimeSelective ? .exponential : .linear,
                decayRate: 0.1
            ),
            emotionalRelevance: pattern.emotionalIntensity,
            personalRelevance: pattern.significanceScore,
            aiConfidence: pattern.confidenceLevel
        )
        
        let delay = pattern.isActionable ? TimeInterval.random(in: 600...3600) : TimeInterval.random(in: 1800...7200)
        bubbleUpItem.nextDueTime = Date().addingTimeInterval(delay)
        
        pendingItems.append(bubbleUpItem)
        await addToDopamineWave(bubbleUpItem, phase: determinePhaseForPattern(pattern))
        
        logger.debug("Created pattern bubble-up: \(pattern.patternType.rawValue)")
    }
    
    /// Creates a meta-insight about the consolidation process itself
    private func createMemoryConsolidationInsight(_ result: MemoryConsolidationResult) async {
        let bubbleUpItem = BubbleUpItem(
            content: generateConsolidationMetaInsight(result),
            taskType: .reflection,
            sourceEntityID: UUID(),
            tags: ["meta_cognition", "memory_health", "system_insight"]
        )
        
        let priority = BubbleUpPriority(
            baseScore: 0.7, // Meta-insights have moderate priority
            urgencyMultiplier: 0.8,
            timedecayRate: 0.6,
            contextualFactors: [:]
        )
        bubbleUpItem.priority = priority
        
        bubbleUpItem.cognitiveMetadata = CognitiveMetadata(
            attentionCaptureFactors: [.personalRelevance],
            dopamineTriggers: [.progressVisual, .completionSatisfaction],
            cognitiveLoad: CognitivePressure(
                perceptualLoad: 0.2,
                cognitiveLoad: 0.4,
                memoryLoad: 0.3
            ),
            locationRelevance: LocationRelevance(relevantLocations: [], spatialContext: ""),
            timeSensitivity: TimeSensitivity(urgencyPattern: .linear, decayRate: 0.02),
            emotionalRelevance: 0.4,
            personalRelevance: 0.8,
            aiConfidence: 0.9
        )
        
        // Surface this after other insights have had time to process
        bubbleUpItem.nextDueTime = Date().addingTimeInterval(TimeInterval.random(in: 3600...10800))
        
        pendingItems.append(bubbleUpItem)
        await addToDopamineWave(bubbleUpItem, phase: .reflection)
        
        logger.debug("Created memory consolidation meta-insight")
    }
    
    // MARK: - Consolidation Helper Methods
    
    private func generateFusionInsightContent(_ fusionNode: FusionNode) -> String {
        let layerTypes = fusionNode.fusedLayers.map { $0.displayName }.joined(separator: " + ")
        
        switch fusionNode.fusionType {
        case .crossLayer:
            return "I've connected ideas across \(layerTypes). This fusion reveals: \(fusionNode.content)"
        case .temporal:
            return "A pattern emerged over time in \(layerTypes): \(fusionNode.content)"
        case .spatial:
            return "Location-based connections in \(layerTypes) show: \(fusionNode.content)"
        case .conceptual:
            return "These concepts from \(layerTypes) relate in an interesting way: \(fusionNode.content)"
        case .emotional:
            return "An emotional connection across \(layerTypes) suggests: \(fusionNode.content)"
        }
    }
    
    private func generateConnectionInsightContent(_ connection: CrossLayerConnection) -> String {
        return "I noticed a strong connection between your \(connection.sourceLayerType.displayName) and \(connection.targetLayerType.displayName) memories. This might suggest: \(connection.insightContent)"
    }
    
    private func generatePatternInsightContent(_ pattern: DetectedMemoryPattern) -> String {
        switch pattern.patternType {
        case .recurring:
            return "I've noticed a recurring pattern in your thoughts: \(pattern.description). This happens \(pattern.frequency) times per \(pattern.timeframe)."
        case .emerging:
            return "A new pattern is emerging in your thinking: \(pattern.description). This could be worth exploring further."
        case .temporal:
            return "Your thoughts show a time-based pattern: \(pattern.description). This often occurs during \(pattern.contextualDetails)."
        case .emotional:
            return "There's an emotional pattern I've detected: \(pattern.description). This relates to \(pattern.emotionalContext)."
        case .behavioral:
            return "I see a behavioral pattern developing: \(pattern.description). This could influence your \(pattern.behavioralDomain)."
        }
    }
    
    private func generateConsolidationMetaInsight(_ result: MemoryConsolidationResult) -> String {
        let improvement = Int(result.memoryPressureReduction * 100)
        let newConnections = result.newCrossLayerConnections.count
        let newFusions = result.newFusionNodes.count
        
        return "Your memory system just consolidated, reducing pressure by \(improvement)% and creating \(newConnections) new connections and \(newFusions) insights. This suggests your thinking is becoming more integrated."
    }
    
    private func extractTagsFromFusion(_ fusionNode: FusionNode) -> [String] {
        var tags: [String] = []
        tags.append(fusionNode.fusionType.rawValue)
        tags.append("novelty_\(Int(fusionNode.noveltyScore * 10))")
        tags.append("strength_\(Int(fusionNode.strengthScore * 10))")
        
        // Add layer-specific tags
        for layer in fusionNode.fusedLayers {
            tags.append(layer.rawValue)
        }
        
        return tags
    }
    
    private func calculatePersonalRelevance(for fusionNode: FusionNode) -> Double {
        // Base relevance on fusion characteristics
        let baseRelevance = (fusionNode.strengthScore + fusionNode.coherenceScore) / 2.0
        
        // Boost for cross-layer fusions (more personally meaningful)
        let crossLayerBoost = fusionNode.fusedLayers.count > 1 ? 0.2 : 0.0
        
        // Boost for emotional content
        let emotionalBoost = fusionNode.emotionalResonance > 0.5 ? 0.1 : 0.0
        
        return min(1.0, baseRelevance + crossLayerBoost + emotionalBoost)
    }
    
    private func calculateFusionBubbleUpDelay(_ fusionNode: FusionNode) -> TimeInterval {
        // More novel fusions surface sooner
        let noveltyFactor = fusionNode.noveltyScore
        let baseDelay: TimeInterval = 1800 // 30 minutes base
        let maxDelay: TimeInterval = 7200 // 2 hours max
        
        // Inverse relationship - higher novelty = shorter delay
        let delayMultiplier = 1.0 - (noveltyFactor * 0.7)
        let calculatedDelay = baseDelay + (maxDelay - baseDelay) * delayMultiplier
        
        return TimeInterval.random(in: calculatedDelay...(calculatedDelay * 1.5))
    }
    
    private func determinePhaseForPattern(_ pattern: DetectedMemoryPattern) -> DopamineWavePhase {
        switch pattern.patternType {
        case .recurring, .behavioral:
            return .routine
        case .emerging:
            return .creative
        case .temporal:
            return .planning
        case .emotional:
            return .reflection
        }
    }
    
    // MARK: - Placeholder Methods (To Be Implemented)
    
    private func generateInsightFromFusion(_ fusionNode: FusionNode, context: OrchestratorContext) async -> String? {
        // TODO: Implement fusion node insight generation
        return "Insight from fusion: \(fusionNode.id)"
    }
    
    private func analyzeConsolidationPatterns(context: OrchestratorContext) async -> [ConsolidationInsight]? {
        // TODO: Implement consolidation pattern analysis
        return nil
    }
    
    private func analyzeUserPatterns(context: OrchestratorContext) async -> [UserPattern] {
        // TODO: Implement user pattern analysis
        return []
    }
    
    private func getRecentlyCompletedItems() async -> [String] {
        // TODO: Implement recently completed tracking
        return []
    }
    
    private func getEnvironmentalFactors() async -> [String: Double] {
        // TODO: Integrate with HealthKit and environmental sensors
        return [:]
    }
    
    private func recordBubbleUpMetrics(candidates: Int, surfaced: Int, context: OrchestratorContext) {
        logger.info("Bubble-up metrics: \(candidates) candidates, \(surfaced) surfaced in \(context.currentWindow.rawValue)")
        // TODO: Integrate with analytics system
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct ConsolidationInsight: Sendable {
    let content: String
    let importance: Double
    let contextMatch: Double
    let urgency: Double
    let tags: [String]
    let taskType: BubbleUpTaskType
    let relatedMemoryIDs: [UUID]
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct UserPattern: Sendable {
    let suggestedAction: String
    let confidence: Double
    let importance: Double
    let contextMatch: Double
    let adhdUrgency: Double
    let taskType: BubbleUpTaskType
    let optimalWindows: [DopamineWindow]
    
    func shouldSurface(in window: DopamineWindow) -> Bool {
        optimalWindows.contains(window)
    }
}

// MARK: - Memory Consolidation Types

/// Result of memory system consolidation, used to trigger bubble-ups
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct MemoryConsolidationResult: Sendable {
    public let consolidationTimestamp: Date
    public let memoryPressureReduction: Double // 0.0 to 1.0
    public let newFusionNodes: [FusionNode]
    public let newCrossLayerConnections: [CrossLayerConnection]
    public let detectedPatterns: [DetectedMemoryPattern]
    public let prunedNodes: Int
    public let optimizedConnections: Int
    public let systemPerformanceImprovement: Double
    
    public init(
        consolidationTimestamp: Date = Date(),
        memoryPressureReduction: Double,
        newFusionNodes: [FusionNode],
        newCrossLayerConnections: [CrossLayerConnection],
        detectedPatterns: [DetectedMemoryPattern],
        prunedNodes: Int = 0,
        optimizedConnections: Int = 0,
        systemPerformanceImprovement: Double = 0.0
    ) {
        self.consolidationTimestamp = consolidationTimestamp
        self.memoryPressureReduction = memoryPressureReduction
        self.newFusionNodes = newFusionNodes
        self.newCrossLayerConnections = newCrossLayerConnections
        self.detectedPatterns = detectedPatterns
        self.prunedNodes = prunedNodes
        self.optimizedConnections = optimizedConnections
        self.systemPerformanceImprovement = systemPerformanceImprovement
    }
}

/// Cross-layer connection between different memory layers
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CrossLayerConnection: Sendable, Identifiable {
    public let id = UUID()
    public let sourceLayerType: CognitiveLayerType
    public let targetLayerType: CognitiveLayerType
    public let sourceNodeId: String
    public let targetNodeId: String
    public let connectionType: ConnectionType
    public let strengthScore: Double // 0.0 to 1.0
    public let relevanceScore: Double // 0.0 to 1.0
    public let insightContent: String
    public let timestamp: Date
    
    public enum ConnectionType: String, Sendable, CaseIterable {
        case semantic = "semantic"
        case temporal = "temporal"
        case causal = "causal"
        case associative = "associative"
        case emotional = "emotional"
        case spatial = "spatial"
    }
    
    public init(
        sourceLayerType: CognitiveLayerType,
        targetLayerType: CognitiveLayerType,
        sourceNodeId: String,
        targetNodeId: String,
        connectionType: ConnectionType,
        strengthScore: Double,
        relevanceScore: Double,
        insightContent: String,
        timestamp: Date = Date()
    ) {
        self.sourceLayerType = sourceLayerType
        self.targetLayerType = targetLayerType
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.connectionType = connectionType
        self.strengthScore = strengthScore
        self.relevanceScore = relevanceScore
        self.insightContent = insightContent
        self.timestamp = timestamp
    }
}

/// Pattern detected in memory during consolidation
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct DetectedMemoryPattern: Sendable, Identifiable {
    public let id = UUID()
    public let patternType: PatternType
    public let description: String
    public let significanceScore: Double // 0.0 to 1.0
    public let confidenceLevel: Double // 0.0 to 1.0
    public let frequency: Int
    public let timeframe: String
    public let contextualDetails: String
    public let emotionalIntensity: Double // 0.0 to 1.0
    public let emotionalContext: String
    public let behavioralDomain: String
    public let isActionable: Bool
    public let isTimeSelective: Bool
    public let relatedNodeIds: [String]
    public let detectionTimestamp: Date
    
    public enum PatternType: String, Sendable, CaseIterable {
        case recurring = "recurring"
        case emerging = "emerging"
        case temporal = "temporal"
        case emotional = "emotional"
        case behavioral = "behavioral"
    }
    
    public init(
        patternType: PatternType,
        description: String,
        significanceScore: Double,
        confidenceLevel: Double,
        frequency: Int,
        timeframe: String,
        contextualDetails: String,
        emotionalIntensity: Double = 0.0,
        emotionalContext: String = "",
        behavioralDomain: String = "",
        isActionable: Bool = false,
        isTimeSelective: Bool = false,
        relatedNodeIds: [String] = [],
        detectionTimestamp: Date = Date()
    ) {
        self.patternType = patternType
        self.description = description
        self.significanceScore = significanceScore
        self.confidenceLevel = confidenceLevel
        self.frequency = frequency
        self.timeframe = timeframe
        self.contextualDetails = contextualDetails
        self.emotionalIntensity = emotionalIntensity
        self.emotionalContext = emotionalContext
        self.behavioralDomain = behavioralDomain
        self.isActionable = isActionable
        self.isTimeSelective = isTimeSelective
        self.relatedNodeIds = relatedNodeIds
        self.detectionTimestamp = detectionTimestamp
    }
}

/// Represents the different cognitive layer types for memory consolidation
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)

// MARK: - Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension FusionNode {
    /// Tracks when this fusion node was last used for bubble-up generation
    var lastBubbleUpGeneration: Date? {
        get {
            // TODO: Implement persistent storage for this property
            return nil
        }
        set {
            // TODO: Implement persistent storage for this property
        }
    }
}
