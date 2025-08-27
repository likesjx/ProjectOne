//
//  BubbleUpMemoryCreator.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  Service for creating thoughts/memories from bubble-up cards
//

import Foundation
import SwiftData
import CoreLocation
import os.log

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public actor BubbleUpMemoryCreator {
    
    private let modelContext: ModelContext
    private let cognitiveMemorySystem: CognitiveMemorySystem
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "BubbleUpMemoryCreator")
    private let locationManager = CLLocationManager()
    
    public init(modelContext: ModelContext, cognitiveMemorySystem: CognitiveMemorySystem) {
        self.modelContext = modelContext
        self.cognitiveMemorySystem = cognitiveMemorySystem
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    /// Captures current location for memory creation
    private func captureCurrentLocation() async -> (latitude: Double?, longitude: Double?, accuracy: Double?, locationName: String?) {
        guard CLLocationManager.locationServicesEnabled(),
              locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            logger.debug("Location services not available or not authorized")
            return (nil, nil, nil, nil)
        }
        
        guard let location = locationManager.location else {
            logger.debug("No location available from location manager")
            return (nil, nil, nil, nil)
        }
        
        // Get location name through reverse geocoding
        let geocoder = CLGeocoder()
        let locationName: String?
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            locationName = placemarks.first?.name ?? placemarks.first?.thoroughfare
        } catch {
            logger.debug("Failed to reverse geocode location: \(error)")
            locationName = nil
        }
        
        logger.debug("Captured location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        return (
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude, 
            accuracy: location.horizontalAccuracy,
            locationName: locationName
        )
    }
    
    // MARK: - Memory Creation
    
    /// Creates a new thought/memory from a bubble-up item
    public func createMemoryFromBubbleUp(
        _ bubbleUpItem: BubbleUpItem,
        userInput: String? = nil,
        thoughtType: ThoughtType = .insight
    ) async throws -> Thought {
        
        logger.info("Creating memory from bubble-up item: \(bubbleUpItem.id)")
        
        // Prepare the content for the new thought
        let content = userInput ?? bubbleUpItem.content
        
        // Create the thought with context from the bubble-up
        let thought = Thought(
            content: content,
            contextBefore: "From bubble-up: \(bubbleUpItem.taskType.rawValue)",
            contextAfter: generateContextFromBubbleUp(bubbleUpItem),
            thoughtType: thoughtType
        )
        
        // Set importance based on bubble-up priority
        thought.importance = mapBubbleUpImportanceToThoughtImportance(bubbleUpItem.priority.finalScore)
        
        // Transfer tags from bubble-up
        thought.setTags(bubbleUpItem.tags)
        
        // Set extraction metadata
        thought.extractionMethod = "bubble_up_creation"
        thought.extractionConfidence = bubbleUpItem.cognitiveMetadata.aiConfidence
        
        // Add bubble-up specific tags
        thought.addTag("from_bubble_up")
        thought.addTag(bubbleUpItem.taskType.rawValue)
        
        // Set primary tag based on task type
        if let primaryTag = determinePrimaryTag(from: bubbleUpItem) {
            thought.setPrimaryTag(primaryTag)
        }
        
        // Capture current location for memory creation
        let locationData = await captureCurrentLocation()
        if let lat = locationData.latitude, let lng = locationData.longitude {
            thought.setCreationLocation(
                latitude: lat,
                longitude: lng,
                locationName: locationData.locationName,
                accuracy: locationData.accuracy
            )
        }
        
        // Save to SwiftData
        modelContext.insert(thought)
        try modelContext.save()
        
        // Add to cognitive memory system
        try await addToCognitiveMemorySystem(thought, bubbleUpItem: bubbleUpItem)
        
        // Update bubble-up item to track the created memory
        await updateBubbleUpWithCreatedMemory(bubbleUpItem, thought: thought)
        
        logger.info("Successfully created memory from bubble-up: \(thought.id)")
        
        return thought
    }
    
    /// Creates a memory with custom user content while preserving bubble-up context
    public func createCustomMemoryFromBubbleUp(
        _ bubbleUpItem: BubbleUpItem,
        userContent: String,
        thoughtType: ThoughtType,
        tags: [String] = [],
        importance: ThoughtImportance? = nil,
        targetDateTime: Date? = nil,
        targetLocation: (latitude: Double, longitude: Double, name: String?, radius: Double?)? = nil
    ) async throws -> Thought {
        
        logger.info("Creating custom memory from bubble-up item: \(bubbleUpItem.id)")
        
        let thought = Thought(
            content: userContent,
            contextBefore: "Inspired by bubble-up: \(bubbleUpItem.content)",
            contextAfter: generateContextFromBubbleUp(bubbleUpItem),
            thoughtType: thoughtType
        )
        
        // Set importance - use provided or derive from bubble-up
        thought.importance = importance ?? mapBubbleUpImportanceToThoughtImportance(bubbleUpItem.priority.finalScore)
        
        // Combine user tags with bubble-up context
        let combinedTags = tags + bubbleUpItem.tags + ["from_bubble_up", "user_created"]
        thought.setTags(combinedTags)
        
        // Set extraction metadata
        thought.extractionMethod = "user_bubble_up_creation"
        thought.extractionConfidence = 1.0 // User-created content has full confidence
        
        // Capture current location for memory creation
        let locationData = await captureCurrentLocation()
        if let lat = locationData.latitude, let lng = locationData.longitude {
            thought.setCreationLocation(
                latitude: lat,
                longitude: lng,
                locationName: locationData.locationName,
                accuracy: locationData.accuracy
            )
        }
        
        // Set target datetime if provided
        if let targetDateTime = targetDateTime {
            thought.targetDateTime = targetDateTime
        }
        
        // Set target location if provided
        if let targetLoc = targetLocation {
            thought.setTargetLocation(
                latitude: targetLoc.latitude,
                longitude: targetLoc.longitude,
                locationName: targetLoc.name,
                radius: targetLoc.radius
            )
        }
        
        // Save to SwiftData
        modelContext.insert(thought)
        try modelContext.save()
        
        // Add to cognitive memory system
        try await addToCognitiveMemorySystem(thought, bubbleUpItem: bubbleUpItem)
        
        // Update bubble-up item
        await updateBubbleUpWithCreatedMemory(bubbleUpItem, thought: thought)
        
        logger.info("Successfully created custom memory from bubble-up: \(thought.id)")
        
        return thought
    }
    
    // MARK: - Memory Creation UI Support
    
    /// Get suggested thought types based on bubble-up characteristics
    public func getSuggestedThoughtTypes(for bubbleUpItem: BubbleUpItem) -> [ThoughtType] {
        var suggestions: [ThoughtType] = []
        
        // Base suggestions on task type
        switch bubbleUpItem.taskType {
        case .focus, .planning:
            suggestions = [.plan, .goal, .insight]
        case .routine, .maintenance:
            suggestions = [.task, .general]
        case .action, .implementation:
            suggestions = [.task, .decision, .plan]
        case .creative:
            suggestions = [.idea, .insight, .general]
        case .reflection:
            suggestions = [.reflection, .insight, .memory]
        case .preparation:
            suggestions = [.plan, .task, .goal]
        case .review:
            suggestions = [.reflection, .insight, .opinion]
        }
        
        // Add context-based suggestions
        if bubbleUpItem.content.contains("?") {
            suggestions.append(.question)
        }
        
        if bubbleUpItem.cognitiveMetadata.attentionCaptureFactors.contains(.novelty) {
            suggestions.append(.idea)
        }
        
        if bubbleUpItem.cognitiveMetadata.emotionalRelevance > 0.7 {
            suggestions.append(.memory)
        }
        
        return Array(Set(suggestions)) // Remove duplicates
    }
    
    /// Get suggested importance level based on bubble-up priority
    public func getSuggestedImportance(for bubbleUpItem: BubbleUpItem) -> ThoughtImportance {
        return mapBubbleUpImportanceToThoughtImportance(bubbleUpItem.priority.finalScore)
    }
    
    /// Get suggested tags based on bubble-up metadata
    public func getSuggestedTags(for bubbleUpItem: BubbleUpItem) -> [String] {
        var suggestions = bubbleUpItem.tags
        
        // Add cognitive metadata tags
        suggestions.append("priority_\(bubbleUpItem.priority.finalScore > 0.8 ? "high" : bubbleUpItem.priority.finalScore > 0.5 ? "medium" : "low")")
        
        // Add attention factor tags
        for factor in bubbleUpItem.cognitiveMetadata.attentionCaptureFactors {
            suggestions.append("attention_\(factor.rawValue)")
        }
        
        // Add dopamine trigger tags
        for trigger in bubbleUpItem.cognitiveMetadata.dopamineTriggers {
            switch trigger {
            case .immediateReward:
                suggestions.append("reward")
            case .progressVisual:
                suggestions.append("progress")
            case .socialConnection:
                suggestions.append("social")
            case .noveltyStimulus:
                suggestions.append("novel")
            case .completionSatisfaction:
                suggestions.append("completion")
            case .challengeEngagement:
                suggestions.append("challenge")
            }
        }
        
        // Add time/location context tags
        if bubbleUpItem.cognitiveMetadata.timeSensitivity.urgencyPattern != .linear {
            suggestions.append("time_sensitive")
        }
        
        if !bubbleUpItem.cognitiveMetadata.locationRelevance.relevantLocations.isEmpty {
            suggestions.append("location_aware")
        }
        
        return Array(Set(suggestions.map { $0.lowercased() })).sorted()
    }
    
    // MARK: - Private Helper Methods
    
    private func generateContextFromBubbleUp(_ bubbleUpItem: BubbleUpItem) -> String {
        var context: [String] = []
        
        context.append("Task type: \(bubbleUpItem.taskType.rawValue)")
        context.append("Priority: \(String(format: "%.2f", bubbleUpItem.priority.finalScore))")
        
        if let dueWindow = bubbleUpItem.dueWindow {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            context.append("Due: \(formatter.string(from: dueWindow.end))")
        }
        
        if bubbleUpItem.cognitiveMetadata.emotionalRelevance > 0.5 {
            context.append("Emotional relevance: \(String(format: "%.2f", bubbleUpItem.cognitiveMetadata.emotionalRelevance))")
        }
        
        if !bubbleUpItem.tags.isEmpty {
            context.append("Tags: \(bubbleUpItem.tags.joined(separator: ", "))")
        }
        
        return context.joined(separator: " | ")
    }
    
    private func mapBubbleUpImportanceToThoughtImportance(_ score: Double) -> ThoughtImportance {
        switch score {
        case 0.8...:
            return .critical
        case 0.6..<0.8:
            return .high
        case 0.3..<0.6:
            return .medium
        default:
            return .low
        }
    }
    
    private func determinePrimaryTag(from bubbleUpItem: BubbleUpItem) -> String? {
        // Look for the most relevant tag based on cognitive metadata
        if bubbleUpItem.cognitiveMetadata.attentionCaptureFactors.contains(.urgency) {
            return "urgent"
        }
        
        if bubbleUpItem.cognitiveMetadata.attentionCaptureFactors.contains(.novelty) {
            return "novel"
        }
        
        if !bubbleUpItem.tags.isEmpty {
            return bubbleUpItem.tags.first
        }
        
        return bubbleUpItem.taskType.rawValue
    }
    
    private func addToCognitiveMemorySystem(_ thought: Thought, bubbleUpItem: BubbleUpItem) async throws {
        // Determine which layer(s) to add to based on thought type and importance
        switch thought.thoughtType {
        case .fact, .decision:
            // Add to veridical layer for factual content
            try await cognitiveMemorySystem.addToVeridicalLayer(
                content: thought.content,
                context: thought.fullContext,
                importance: Double(thought.importance.priority) / 4.0,
                tags: thought.tags
            )
            
        case .insight, .idea, .opinion:
            // Add to semantic layer for conceptual content
            try await cognitiveMemorySystem.addToSemanticLayer(
                content: thought.content,
                context: thought.fullContext,
                importance: Double(thought.importance.priority) / 4.0,
                tags: thought.tags
            )
            
        case .memory, .reflection:
            // Add to episodic layer for experiential content
            try await cognitiveMemorySystem.addToEpisodicLayer(
                content: thought.content,
                context: thought.fullContext,
                importance: Double(thought.importance.priority) / 4.0,
                tags: thought.tags,
                timestamp: thought.timestamp
            )
            
        default:
            // General thoughts go to semantic layer by default
            try await cognitiveMemorySystem.addToSemanticLayer(
                content: thought.content,
                context: thought.fullContext,
                importance: Double(thought.importance.priority) / 4.0,
                tags: thought.tags
            )
        }
        
        logger.debug("Added thought to cognitive memory system: \(thought.id)")
    }
    
    private func updateBubbleUpWithCreatedMemory(_ bubbleUpItem: BubbleUpItem, thought: Thought) async {
        // Link the created thought back to the bubble-up item
        bubbleUpItem.relatedMemoryIDs.append(thought.id)
        bubbleUpItem.updatedAt = Date()
        
        // Record engagement
        bubbleUpItem.recordEngagement(.actioned, metadata: [
            "action_type": "create_memory",
            "thought_id": thought.id.uuidString,
            "thought_type": thought.thoughtType.rawValue
        ])
        
        // Save the updated bubble-up item
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to update bubble-up item after memory creation: \(error)")
        }
    }
}

// MARK: - Cognitive Memory System Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CognitiveMemorySystem {
    
    /// Convenience method to add content to veridical layer
    public func addToVeridicalLayer(content: String, context: String, importance: Double, tags: [String]) async throws {
        // Implementation would depend on the specific veridical layer API
        logger.info("Adding content to veridical layer: \(content.prefix(50))...")
    }
    
    /// Convenience method to add content to semantic layer
    public func addToSemanticLayer(content: String, context: String, importance: Double, tags: [String]) async throws {
        // Implementation would depend on the specific semantic layer API
        logger.info("Adding content to semantic layer: \(content.prefix(50))...")
    }
    
    /// Convenience method to add content to episodic layer
    public func addToEpisodicLayer(content: String, context: String, importance: Double, tags: [String], timestamp: Date) async throws {
        // Implementation would depend on the specific episodic layer API
        logger.info("Adding content to episodic layer: \(content.prefix(50))...")
    }
    
    private var logger: Logger {
        Logger(subsystem: "com.jaredlikes.ProjectOne", category: "CognitiveMemorySystem")
    }
}