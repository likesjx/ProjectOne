//
//  AIModelProvider.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/15/25.
//

import Foundation

// MARK: - Memory Context (Enhanced with proper model support)

/// Enhanced memory context that can store actual model object references
/// Uses IDs for Sendable compliance with lazy loading capabilities
public struct MemoryContext: Sendable {
    let timestamp: Date
    let userQuery: String
    let containsPersonalData: Bool
    let contextData: [String: String] // Generic container for string-based context
    
    // Model object ID collections for lazy loading
    let shortTermMemoryIDs: [UUID]
    let longTermMemoryIDs: [UUID] 
    let episodicMemoryIDs: [UUID]
    let entityIDs: [UUID]
    let relationshipIDs: [UUID]
    let noteIDs: [UUID]
    
    public init(
        timestamp: Date = Date(),
        userQuery: String,
        containsPersonalData: Bool = false,
        contextData: [String: String] = [:],
        shortTermMemoryIDs: [UUID] = [],
        longTermMemoryIDs: [UUID] = [],
        episodicMemoryIDs: [UUID] = [],
        entityIDs: [UUID] = [],
        relationshipIDs: [UUID] = [],
        noteIDs: [UUID] = []
    ) {
        self.timestamp = timestamp
        self.userQuery = userQuery
        self.containsPersonalData = containsPersonalData
        self.contextData = contextData
        self.shortTermMemoryIDs = shortTermMemoryIDs
        self.longTermMemoryIDs = longTermMemoryIDs
        self.episodicMemoryIDs = episodicMemoryIDs
        self.entityIDs = entityIDs
        self.relationshipIDs = relationshipIDs
        self.noteIDs = noteIDs
    }
    
    /// Check if context has any relevant memories
    public var isEmpty: Bool {
        return shortTermMemoryIDs.isEmpty && 
               longTermMemoryIDs.isEmpty && 
               episodicMemoryIDs.isEmpty && 
               entityIDs.isEmpty && 
               relationshipIDs.isEmpty && 
               noteIDs.isEmpty
    }
    
    // Compatibility properties for BaseAIProvider - simplified for Sendable compatibility
    public var entities: [Any] { return [] }
    public var relationships: [Any] { return [] }
    public var shortTermMemories: [Any] { return [] }
    public var longTermMemories: [Any] { return [] }
    public var episodicMemories: [Any] { return [] }
    public var relevantNotes: [Any] { return [] }
}

// MARK: - AI Model Response

/// Response from AI model with metadata
public struct AIModelResponse: Sendable {
    let content: String
    let confidence: Double
    let processingTime: TimeInterval
    let modelUsed: String
    let tokensUsed: Int?
    let isOnDevice: Bool
    let containsPersonalData: Bool
    
    public init(
        content: String,
        confidence: Double = 1.0,
        processingTime: TimeInterval,
        modelUsed: String,
        tokensUsed: Int? = nil,
        isOnDevice: Bool,
        containsPersonalData: Bool = false
    ) {
        self.content = content
        self.confidence = confidence
        self.processingTime = processingTime
        self.modelUsed = modelUsed
        self.tokensUsed = tokensUsed
        self.isOnDevice = isOnDevice
        self.containsPersonalData = containsPersonalData
    }
}

// MARK: - AI Model Provider Protocol

/// Protocol for AI model providers in the Memory Agent system
@MainActor
public protocol AIModelProvider: AnyObject {
    
    /// Unique identifier for this provider
    var identifier: String { get }
    
    /// Display name for this provider
    var displayName: String { get }
    
    /// Check if this provider is currently available
    var isAvailable: Bool { get }
    
    /// Check if this provider supports personal data processing
    var supportsPersonalData: Bool { get }
    
    /// Check if this provider processes data on-device
    var isOnDevice: Bool { get }
    
    /// Estimated response time for typical queries
    var estimatedResponseTime: TimeInterval { get }
    
    /// Maximum context length this provider can handle
    var maxContextLength: Int { get }
    
    /// Generate response with memory context
    /// - Parameters:
    ///   - prompt: The user's query or prompt
    ///   - context: Memory context for RAG
    /// - Returns: AI model response
    func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse
    
    /// Prepare the provider for use (load models, authenticate, etc.)
    func prepare() async throws
    
    /// Clean up resources
    func cleanup() async
    
    /// Check if provider can handle the given context size
    func canHandle(contextSize: Int) -> Bool
}

// MARK: - AI Model Provider Error

public enum AIModelProviderError: Error, LocalizedError {
    case providerUnavailable(String)
    case contextTooLarge(Int, Int) // actual, maximum
    case processingFailed(String)
    case authenticationFailed
    case networkRequired
    case personalDataNotSupported
    case modelNotLoaded
    case rateLimitExceeded
    case invalidInput(String)
    
    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let provider):
            return "AI model provider unavailable: \(provider)"
        case .contextTooLarge(let actual, let maximum):
            return "Context too large: \(actual) tokens, maximum: \(maximum)"
        case .processingFailed(let reason):
            return "AI processing failed: \(reason)"
        case .authenticationFailed:
            return "Authentication failed for AI model provider"
        case .networkRequired:
            return "Network connection required for AI model provider"
        case .personalDataNotSupported:
            return "Personal data not supported by this AI model provider"
        case .modelNotLoaded:
            return "AI model not loaded or ready"
        case .rateLimitExceeded:
            return "Rate limit exceeded for AI model provider"
        case .invalidInput(let reason):
            return "Invalid input: \(reason)"
        }
    }
}

// MARK: - Model Selection Criteria

/// Criteria for selecting the best AI model provider
public struct ModelSelectionCriteria {
    let requiresPersonalData: Bool
    let requiresOnDevice: Bool
    let maxResponseTime: TimeInterval?
    let contextSize: Int
    let priority: Priority
    
    public enum Priority {
        case speed
        case accuracy
        case privacy
        case cost
    }
    
    public init(
        requiresPersonalData: Bool = false,
        requiresOnDevice: Bool = false,
        maxResponseTime: TimeInterval? = nil,
        contextSize: Int = 0,
        priority: Priority = .privacy
    ) {
        self.requiresPersonalData = requiresPersonalData
        self.requiresOnDevice = requiresOnDevice
        self.maxResponseTime = maxResponseTime
        self.contextSize = contextSize
        self.priority = priority
    }
}

// MARK: - Default Extension

extension AIModelProvider {
    
    public func canHandle(contextSize: Int) -> Bool {
        return contextSize <= maxContextLength
    }
    
    public var estimatedResponseTime: TimeInterval {
        return isOnDevice ? 0.5 : 2.0
    }
    
    public var maxContextLength: Int {
        return isOnDevice ? 8192 : 32768
    }
}