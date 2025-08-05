//
//  EnhancedGemma3nCore.swift
//  ProjectOne
//
//  Enhanced core with BOTH MLX Swift AND Foundation Models for iOS 26.0+
//

import Foundation
import SwiftUI
import Combine
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// Foundation Models framework for iOS 26.0+ Beta
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Enhanced Gemma3n core with dual AI providers for iOS 26.0+ target
@available(iOS 26.0, macOS 26.0, *)
@MainActor
class EnhancedGemma3nCore: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EnhancedGemma3nCore")
    
    // MARK: - AI Providers (Three-Layer Architecture)
    
    private let mlxLLMProvider = MLXLLMProvider()
    private let mlxVLMProvider = MLXVLMProvider()
    private let foundationProvider = AppleFoundationModelsProvider()
    
    // MARK: - State
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activeProvider: AIProviderType = .automatic
    @Published var lastResponse: String?
    
    public enum AIProviderType: String, CaseIterable {
        case automatic = "automatic"
        case mlxLLM = "mlx_llm"
        case mlxVLM = "mlx_vlm"
        case foundation = "foundation"
        
        var displayName: String {
            switch self {
            case .automatic: return "Automatic (Best Available)"
            case .mlxLLM: return "MLX LLM (Text-Only)"
            case .mlxVLM: return "MLX VLM (Multimodal)"
            case .foundation: return "Foundation Models (System)"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing Enhanced Gemma3n Core for iOS 26.0+")
    }
    
    public func setup() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        logger.info("Setting up MLX three-layer and Foundation providers...")
        
        // Setup all providers in parallel
        async let mlxLLMSetup: () = setupMLXLLMProvider()
        async let mlxVLMSetup: () = setupMLXVLMProvider()
        async let foundationSetup: () = setupFoundationProvider()
        
        await mlxLLMSetup
        await mlxVLMSetup
        await foundationSetup
        
        await MainActor.run {
            isReady = mlxLLMProvider.isReady || mlxVLMProvider.isReady || foundationProvider.isAvailable
            isLoading = false
            
            if isReady {
                logger.info("✅ Enhanced Gemma3n Core ready with available providers")
            } else {
                errorMessage = "No AI providers available"
                logger.error("❌ No AI providers available")
            }
        }
    }
    
    // MARK: - Provider Setup
    
    private func setupMLXLLMProvider() async {
        guard mlxLLMProvider.isSupported else {
            logger.info("MLX LLM not supported on this device")
            return
        }
        
        do {
            try await mlxLLMProvider.loadRecommendedModel()
            logger.info("✅ MLX LLM provider ready")
        } catch {
            logger.error("❌ MLX LLM provider setup failed: \(error.localizedDescription)")
        }
    }
    
    private func setupMLXVLMProvider() async {
        guard mlxVLMProvider.isSupported else {
            logger.info("MLX VLM not supported on this device")
            return
        }
        
        do {
            try await mlxVLMProvider.loadRecommendedModel()
            logger.info("✅ MLX VLM provider ready")
        } catch {
            logger.error("❌ MLX VLM provider setup failed: \(error.localizedDescription)")
        }
    }
    
    private func setupFoundationProvider() async {
        // Foundation provider initializes automatically in iOS 26.0+
        // Just wait for it to complete its availability check
        var attempts = 0
        while self.foundationProvider.modelLoadingStatus == .preparing && attempts < 20 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        if self.foundationProvider.isAvailable {
            logger.info("✅ Foundation Models provider ready")
        } else {
            logger.info("Foundation Models not available: \(self.foundationProvider.statusMessage)")
        }
    }
    
    // MARK: - Text Processing
    
    /// Process text using the best available AI provider
    public func processText(_ text: String, forceProvider: AIProviderType? = nil) async -> String {
        return await processText(text, images: [], forceProvider: forceProvider)
    }
    
    /// Process text with optional images using smart routing
    public func processText(_ text: String, images: [PlatformImage] = [], forceProvider: AIProviderType? = nil) async -> String {
        let provider = forceProvider ?? selectBestProvider(for: text, images: images)
        
        logger.info("Processing \(images.isEmpty ? "text" : "multimodal") request with \(provider.displayName)")
        
        do {
            let response: String
            
            switch provider {
            case .mlxLLM:
                response = try await processWithMLXLLM(text)
            case .mlxVLM:
                response = try await processWithMLXVLM(text, images: images)
            case .foundation:
                response = try await processWithFoundation(text)
            case .automatic:
                response = try await processWithAutomatic(text, images: images)
            }
            
            await MainActor.run {
                lastResponse = response
            }
            
            return response
            
        } catch {
            let errorResponse = "Error processing request: \(error.localizedDescription)"
            logger.error("Processing failed: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = error.localizedDescription
                lastResponse = errorResponse
            }
            
            return errorResponse
        }
    }
    
    // MARK: - Private Processing Methods
    
    private func processWithMLXLLM(_ text: String) async throws -> String {
        guard mlxLLMProvider.isReady else {
            throw EnhancedGemmaError.mlxNotReady
        }
        
        return try await mlxLLMProvider.generateResponse(to: text)
    }
    
    private func processWithMLXVLM(_ text: String, images: [PlatformImage] = []) async throws -> String {
        guard mlxVLMProvider.isReady else {
            throw EnhancedGemmaError.mlxNotReady
        }
        
        return try await mlxVLMProvider.generateResponse(to: text, images: images)
    }
    
    private func processWithAutomatic(_ text: String, images: [PlatformImage] = []) async throws -> String {
        // Smart routing based on request type
        if !images.isEmpty {
            // Multimodal request - requires VLM provider
            if mlxVLMProvider.isReady {
                return try await processWithMLXVLM(text, images: images)
            } else {
                throw EnhancedGemmaError.noMultimodalProvider
            }
        } else {
            // Text-only request - try Foundation Models first, then MLX LLM
            if foundationProvider.isAvailable {
                return try await processWithFoundation(text)
            } else if mlxLLMProvider.isReady {
                return try await processWithMLXLLM(text)
            } else {
                throw EnhancedGemmaError.noProvidersAvailable
            }
        }
    }
    
    private func processWithFoundation(_ text: String) async throws -> String {
        guard foundationProvider.isAvailable else {
            throw EnhancedGemmaError.foundationNotAvailable
        }
        
        return try await foundationProvider.generateModelResponse(text)
    }
    
    // MARK: - Advanced Features (iOS 26.0+ only)
    
    /// Generate structured content using Foundation Models @Generable
    public func generateStructured<T: Generable>(prompt: String, type: T.Type) async throws -> T {
        guard foundationProvider.isAvailable else {
            throw EnhancedGemmaError.foundationNotAvailable
        }
        
        return try await foundationProvider.generateWithGuidance(prompt: prompt, type: type)
    }
    
    /// Extract entities using guided generation
    public func extractEntities(from text: String) async throws -> ExtractedEntities {
        let prompt = "Extract all people, places, organizations, and key concepts from this text: \(text)"
        return try await generateStructured(prompt: prompt, type: ExtractedEntities.self)
    }
    
    /// Summarize content using guided generation
    public func summarizeContent(_ text: String) async throws -> SummarizedContent {
        let prompt = "Provide a comprehensive summary with title, key points, and overview for: \(text)"
        return try await generateStructured(prompt: prompt, type: SummarizedContent.self)
    }
    
    /// Extract memory-relevant information from conversation
    public func extractMemoryContent(from conversation: String) async throws -> MemoryExtraction {
        let prompt = """
        Analyze this conversation and extract memory-relevant information. Identify what should be stored in different memory types:
        - Short-term: Current context, ongoing topics, recent decisions
        - Long-term: Facts learned, important insights, user preferences 
        - Episodic: Significant events, experiences, temporal context
        - Entities: People, places, concepts mentioned with their roles/relationships
        
        Conversation: \(conversation)
        """
        return try await generateStructured(prompt: prompt, type: MemoryExtraction.self)
    }
    
    /// Generate comprehensive conversation summary with context
    public func summarizeConversation(_ conversation: String) async throws -> ConversationSummary {
        let prompt = """
        Create a comprehensive conversation summary including:
        - Main topics discussed
        - Key decisions or outcomes
        - Action items or follow-ups
        - Participant roles and contributions
        - Important context for future reference
        
        Conversation: \(conversation)
        """
        return try await generateStructured(prompt: prompt, type: ConversationSummary.self)
    }
    
    /// Extract knowledge graph relationships and connections
    public func extractKnowledgeGraph(from text: String) async throws -> KnowledgeGraph {
        let prompt = """
        Analyze this text and create a knowledge graph structure with:
        - Entities (people, places, concepts, objects)
        - Relationships between entities (types and descriptions)
        - Temporal information (when events occurred)
        - Hierarchical structures (categories, containment)
        - Contextual metadata (importance, confidence)
        
        Text: \(text)
        """
        return try await generateStructured(prompt: prompt, type: KnowledgeGraph.self)
    }
    
    /// Generate task breakdown from natural language request
    public func extractTaskStructure(from request: String) async throws -> TaskStructure {
        let prompt = """
        Break down this request into a structured task format:
        - Primary goal and success criteria
        - Dependencies and prerequisites  
        - Subtasks with priorities and estimates
        - Required resources and skills
        - Potential risks and mitigation strategies
        
        Request: \(request)
        """
        return try await generateStructured(prompt: prompt, type: TaskStructure.self)
    }
    
    /// Analyze emotional context and sentiment
    public func analyzeEmotionalContext(from text: String) async throws -> EmotionalAnalysis {
        let prompt = """
        Analyze the emotional context and sentiment of this text:
        - Overall emotional tone and intensity
        - Specific emotions detected with confidence levels
        - Emotional triggers and themes
        - Suggested response approaches
        - Empathy and support recommendations
        
        Text: \(text)
        """
        return try await generateStructured(prompt: prompt, type: EmotionalAnalysis.self)
    }
    
    // MARK: - Provider Management
    
    private func selectBestProvider(for text: String, images: [PlatformImage] = []) -> AIProviderType {
        // Smart routing based on request type
        if !images.isEmpty {
            // Multimodal request - requires VLM provider
            if mlxVLMProvider.isReady {
                return .mlxVLM
            } else {
                return .automatic // Will handle error in processing
            }
        } else {
            // Text-only request - prefer Foundation Models for system integration
            if foundationProvider.isAvailable {
                return .foundation
            } else if mlxLLMProvider.isReady {
                return .mlxLLM
            } else {
                return .automatic // Will handle error in processing
            }
        }
    }
    
    /// Get current provider status
    public func getProviderStatus() -> ProviderStatus {
        return ProviderStatus(
            mlxLLMAvailable: mlxLLMProvider.isReady,
            mlxLLMModel: mlxLLMProvider.getModelInfo()?.displayName,
            mlxVLMAvailable: mlxVLMProvider.isReady,
            mlxVLMModel: mlxVLMProvider.getModelInfo()?.displayName,
            foundationAvailable: foundationProvider.isAvailable,
            foundationStatus: foundationProvider.statusMessage,
            activeProvider: activeProvider.displayName,
            isReady: isReady
        )
    }
    
    /// Manually switch provider
    public func setActiveProvider(_ provider: AIProviderType) {
        activeProvider = provider
        logger.info("Switched to \(provider.displayName)")
    }
    
    // MARK: - Legacy Compatibility
    
    /// Check if any provider is available (legacy compatibility)
    func isAvailable() -> Bool {
        return isReady
    }
    
    /// Reload providers
    func reloadModel() async {
        await setup()
    }
}

// MARK: - Supporting Types

public struct ProviderStatus {
    public let mlxLLMAvailable: Bool
    public let mlxLLMModel: String?
    public let mlxVLMAvailable: Bool
    public let mlxVLMModel: String?
    public let foundationAvailable: Bool
    public let foundationStatus: String
    public let activeProvider: String
    public let isReady: Bool
    
    public var hasMultimodalSupport: Bool {
        return mlxVLMAvailable
    }
    
    public var hasTextSupport: Bool {
        return mlxLLMAvailable || foundationAvailable
    }
}

public enum EnhancedGemmaError: Error, LocalizedError {
    case noProvidersAvailable
    case mlxNotReady
    case foundationNotAvailable
    case noMultimodalProvider
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noProvidersAvailable:
            return "No AI providers are available"
        case .mlxNotReady:
            return "MLX provider is not ready"
        case .foundationNotAvailable:
            return "Foundation Models not available"
        case .noMultimodalProvider:
            return "No multimodal provider available for image processing"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}

// MARK: - @Generable Protocol and Types Support

// Disable Foundation Models @Generable features to avoid compilation complexity
// These advanced features can be re-enabled once the core app is working
#if false && canImport(FoundationModels)
// These would be the real protocol definitions in iOS 26.0+ Foundation Models
// Using types from RealFoundationModelsProvider
#else
// Local fallback protocol when Foundation Models not available
public protocol Generable {}
#endif

// MARK: - Simple Types for @Generable Support (separate from SwiftData models)

// These simple struct versions avoid naming conflicts with SwiftData @Model classes
public struct SimpleMemoryItem {
    public let content: String
    public let timestamp: Date
    public let importance: Double
    public let category: String
    
    public init(content: String, timestamp: Date, importance: Double, category: String) {
        self.content = content
        self.timestamp = timestamp
        self.importance = importance
        self.category = category
    }
}

public struct SimpleEpisodicItem {
    public let event: String
    public let timestamp: Date
    public let participants: [String]
    public let significance: Double
    
    public init(event: String, timestamp: Date, participants: [String], significance: Double) {
        self.event = event
        self.timestamp = timestamp
        self.participants = participants
        self.significance = significance
    }
}

public struct SimpleEntityItem {
    public let name: String
    public let type: String
    public let description: String
    public let relationships: [String]
    
    public init(name: String, type: String, description: String, relationships: [String]) {
        self.name = name
        self.type = type
        self.description = description
        self.relationships = relationships
    }
}

public struct SimpleTemporalEvent {
    public let event: String
    public let timestamp: String
    public let duration: String
    public let relatedEntities: [String]
    
    public init(event: String, timestamp: String, duration: String, relatedEntities: [String]) {
        self.event = event
        self.timestamp = timestamp
        self.duration = duration
        self.relatedEntities = relatedEntities
    }
}

// MARK: - Required Enums for @Generable Protocol

public enum ImportanceLevel: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    // Required for @Generable - PartiallyGenerated cases
    public enum PartiallyGenerated: String, Codable, CaseIterable {
        case pending = "pending"
        case incomplete = "incomplete"
    }
}

public enum EmotionalTone: String, Codable, CaseIterable {
    case positive = "positive"
    case negative = "negative"
    case neutral = "neutral"
    case mixed = "mixed"
    
    // Required for @Generable - PartiallyGenerated cases
    public enum PartiallyGenerated: String, Codable, CaseIterable {
        case pending = "pending"
        case incomplete = "incomplete"
    }
}

public enum Priority: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    // Required for @Generable - PartiallyGenerated cases
    public enum PartiallyGenerated: String, Codable, CaseIterable {
        case pending = "pending"
        case incomplete = "incomplete"
    }
}

// Define the structured content types that conform to the real Generable protocol
#if false && canImport(FoundationModels)

// MARK: - Basic Structured Generation Types

@Generable
public struct SummarizedContent {
    public let title: String
    public let keyPoints: [String]
    public let summary: String
    public let wordCount: Int
    public let readingTimeMinutes: Int
}

@Generable
public struct ExtractedEntities {
    public let people: [String]
    public let places: [String]
    public let organizations: [String]
    public let concepts: [String]
    public let relationships: [String]
}

// MARK: - Simple Memory Types for @Generable

// These conflicting structs have been removed to avoid naming conflicts with SwiftData models
// The @Generable types use GeneratedMemoryItem, GeneratedEpisodicItem, GeneratedEntityItem instead

// MARK: - Advanced Memory and Knowledge Graph Types

@Generable
public struct MemoryExtraction {
    public let shortTermMemories: [SimpleMemoryItem]
    public let longTermMemories: [SimpleMemoryItem]
    public let episodicMemories: [SimpleEpisodicItem]
    public let extractedEntities: [SimpleEntityItem]
    public let contextualTags: [String]
    public let importanceLevel: String // Simplified from enum
}

@Generable
public struct ConversationSummary {
    public let mainTopics: [String]
    public let keyDecisions: [String]
    public let actionItems: [ActionItem]
    public let participants: [ParticipantInfo]
    public let timeframe: String
    public let nextSteps: [String]
    public let contextForFuture: String
}

@Generable
public struct KnowledgeGraph {
    public let entities: [GraphEntity]
    public let relationships: [GraphRelationship]
    public let temporalEvents: [SimpleTemporalEvent]
    public let hierarchies: [Hierarchy]
    public let confidence: Double
    public let contextMetadata: [String] // Simplified from dictionary
}

@Generable
public struct TaskStructure {
    public let primaryGoal: String
    public let successCriteria: [String]
    public let dependencies: [String]
    public let subtasks: [Subtask]
    public let requiredResources: [String]
    public let estimatedDuration: String
    public let riskFactors: [RiskFactor]
}

@Generable
public struct EmotionalAnalysis {
    public let overallTone: String // Simplified from enum
    public let specificEmotions: [DetectedEmotion]
    public let intensityLevel: Double
    public let emotionalTriggers: [String]
    public let suggestedResponses: [String]
    public let empathyRecommendations: [String]
}

// MARK: - Supporting Data Structures

// Note: Using SimpleMemoryItem, SimpleEpisodicItem, SimpleEntityItem types defined above

@Generable
public struct ActionItem {
    public let task: String
    public let assignee: String
    public let deadline: String
    public let priority: String // Simplified from enum
}

@Generable
public struct ParticipantInfo {
    public let name: String
    public let role: String
    public let contributions: [String]
}

@Generable
public struct GraphEntity {
    public let id: String
    public let name: String
    public let type: String
    public let attributes: [String] // Simplified from dictionary
}

@Generable
public struct GraphRelationship {
    public let fromEntity: String
    public let toEntity: String
    public let relationshipType: String
    public let description: String
    public let strength: Double
}

// Note: Using SimpleTemporalEvent defined above

@Generable
public struct Hierarchy {
    public let parentEntity: String
    public let childEntities: [String]
    public let hierarchyType: String
}

@Generable
public struct Subtask {
    public let title: String
    public let description: String
    public let estimatedTime: String
    public let priority: String // Simplified from enum
    public let dependencies: [String]
}

@Generable
public struct RiskFactor {
    public let risk: String
    public let probability: Double
    public let impact: String
    public let mitigation: String
}

@Generable
public struct DetectedEmotion {
    public let emotion: String
    public let confidence: Double
    public let intensity: Double
    public let context: String
}

// MARK: - Enums for Structured Data
// Note: Enum definitions moved to top of file with PartiallyGenerated support

#else
// Local fallback types when Foundation Models not available
public struct SummarizedContent: Generable {
    public let title: String
    public let keyPoints: [String]
    public let summary: String
    public let wordCount: Int
    public let readingTimeMinutes: Int
}

public struct ExtractedEntities: Generable {
    public let people: [String]
    public let places: [String]
    public let organizations: [String]
    public let concepts: [String]
    public let relationships: [String]
}

public struct MemoryExtraction: Generable {
    public let shortTermMemories: [FallbackMemoryItem]
    public let longTermMemories: [FallbackMemoryItem]
    public let episodicMemories: [FallbackEpisodicItem]
    public let extractedEntities: [FallbackEntityItem]
    public let contextualTags: [String]
    public let importanceLevel: String // Simplified from enum
}

public struct ConversationSummary: Generable {
    public let mainTopics: [String]
    public let keyDecisions: [String]
    public let actionItems: [ActionItem]
    public let participants: [ParticipantInfo]
    public let timeframe: String
    public let nextSteps: [String]
    public let contextForFuture: String
}

public struct KnowledgeGraph: Generable {
    public let entities: [GraphEntity]
    public let relationships: [GraphRelationship]
    public let temporalEvents: [FallbackTemporalEvent]
    public let hierarchies: [Hierarchy]
    public let confidence: Double
    public let contextMetadata: [String] // Simplified from dictionary
}

public struct TaskStructure: Generable {
    public let primaryGoal: String
    public let successCriteria: [String]
    public let dependencies: [String]
    public let subtasks: [Subtask]
    public let requiredResources: [String]
    public let estimatedDuration: String
    public let riskFactors: [RiskFactor]
}

public struct EmotionalAnalysis: Generable {
    public let overallTone: String // Simplified from enum
    public let specificEmotions: [DetectedEmotion]
    public let intensityLevel: Double
    public let emotionalTriggers: [String]
    public let suggestedResponses: [String]
    public let empathyRecommendations: [String]
}

// Supporting data structures for fallback
public struct FallbackMemoryItem: Codable {
    public let content: String
    public let category: String
    public let confidence: Double
    public let relevanceScore: Double
}

public struct FallbackEpisodicItem: Codable {
    public let event: String
    public let timeContext: String
    public let participants: [String]
    public let significance: String
}

public struct FallbackEntityItem: Codable {
    public let name: String
    public let type: String
    public let description: String
    public let relationships: [String]
}

public struct ActionItem: Codable {
    public let task: String
    public let assignee: String
    public let deadline: String
    public let priority: String // Simplified from enum
}

public struct ParticipantInfo: Codable {
    public let name: String
    public let role: String
    public let contributions: [String]
}

public struct GraphEntity: Codable {
    public let id: String
    public let name: String
    public let type: String
    public let attributes: [String] // Simplified from dictionary
}

public struct GraphRelationship: Codable {
    public let fromEntity: String
    public let toEntity: String
    public let relationshipType: String
    public let description: String
    public let strength: Double
}

public struct FallbackTemporalEvent: Codable {
    public let event: String
    public let timestamp: String
    public let duration: String
    public let relatedEntities: [String]
}

public struct Hierarchy: Codable {
    public let parentEntity: String
    public let childEntities: [String]
    public let hierarchyType: String
}

public struct Subtask: Codable {
    public let title: String
    public let description: String
    public let estimatedTime: String
    public let priority: String // Simplified from enum
    public let dependencies: [String]
}

public struct RiskFactor: Codable {
    public let risk: String
    public let probability: Double
    public let impact: String
    public let mitigation: String
}

public struct DetectedEmotion: Codable {
    public let emotion: String
    public let confidence: Double
    public let intensity: Double
    public let context: String
}

// Note: Enum definitions moved to top of file with PartiallyGenerated support for @Generable conformance
#endif