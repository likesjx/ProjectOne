//
//  UnifiedModelProvider.swift
//  ProjectOne
//
//  Created for unified model provider interface
//

import Foundation
import AVFoundation
import os.log

// MARK: - Unified Model Types

/// Represents different types of AI models and their capabilities
public enum ModelType: String, CaseIterable {
    case textGeneration = "text-generation"
    case speechTranscription = "speech-transcription"
    case visionLanguage = "vision-language"
    case audioProcessing = "audio-processing"
    case multimodal = "multimodal"
    case remote = "remote"
    
    public var displayName: String {
        switch self {
        case .textGeneration:
            return "Text Generation"
        case .speechTranscription:
            return "Speech Transcription"
        case .visionLanguage:
            return "Vision-Language"
        case .audioProcessing:
            return "Audio Processing"
        case .multimodal:
            return "Multimodal"
        case .remote:
            return "Remote"
        }
    }
}

/// Represents the modality of input/output for AI models
public enum ModelModality: String, CaseIterable {
    case text = "text"
    case audio = "audio"
    case vision = "vision"
    case multimodal = "multimodal"
    
    public var displayName: String {
        switch self {
        case .text:
            return "Text"
        case .audio:
            return "Audio"
        case .vision:
            return "Vision"
        case .multimodal:
            return "Multimodal"
        }
    }
}

// MARK: - Unified Input/Output Types

/// Unified input for all model types
public struct UnifiedModelInput {
    let text: String?
    let audioData: AudioData?
    let imageData: Data?
    let videoData: Data?
    let context: MemoryContext?
    let configuration: [String: Any]
    let timestamp: Date
    
    public init(
        text: String? = nil,
        audioData: AudioData? = nil,
        imageData: Data? = nil,
        videoData: Data? = nil,
        context: MemoryContext? = nil,
        configuration: [String: Any] = [:],
        timestamp: Date = Date()
    ) {
        self.text = text
        self.audioData = audioData
        self.imageData = imageData
        self.videoData = videoData
        self.context = context
        self.configuration = configuration
        self.timestamp = timestamp
    }
}

/// Unified output from all model types
public struct UnifiedModelOutput {
    let text: String?
    let audioData: AudioData?
    let imageData: Data?
    let videoData: Data?
    let transcriptionResult: SpeechTranscriptionResult?
    let confidence: Double
    let processingTime: TimeInterval
    let modelUsed: String
    let tokensUsed: Int?
    let metadata: [String: Any]
    let timestamp: Date
    
    public init(
        text: String? = nil,
        audioData: AudioData? = nil,
        imageData: Data? = nil,
        videoData: Data? = nil,
        transcriptionResult: SpeechTranscriptionResult? = nil,
        confidence: Double = 1.0,
        processingTime: TimeInterval,
        modelUsed: String,
        tokensUsed: Int? = nil,
        metadata: [String: Any] = [:],
        timestamp: Date = Date()
    ) {
        self.text = text
        self.audioData = audioData
        self.imageData = imageData
        self.videoData = videoData
        self.transcriptionResult = transcriptionResult
        self.confidence = confidence
        self.processingTime = processingTime
        self.modelUsed = modelUsed
        self.tokensUsed = tokensUsed
        self.metadata = metadata
        self.timestamp = timestamp
    }
}

// MARK: - Model Capabilities

/// Comprehensive capabilities for all model types
public struct ModelCapabilities {
    let supportedModalities: [ModelModality]
    let supportedInputTypes: [ModelType]
    let supportedOutputTypes: [ModelType]
    let maxContextLength: Int?
    let supportsRealTime: Bool
    let supportsBatch: Bool
    let supportsOffline: Bool
    let supportsPersonalData: Bool
    let isOnDevice: Bool
    let estimatedResponseTime: TimeInterval
    let memoryRequirements: Int? // in MB
    let supportedLanguages: [String]
    let maxAudioDuration: TimeInterval?
    let maxImageSize: Int? // in bytes
    let maxVideoSize: Int? // in bytes
    let requiresPermission: Bool
    let requiresNetwork: Bool
    
    public init(
        supportedModalities: [ModelModality],
        supportedInputTypes: [ModelType],
        supportedOutputTypes: [ModelType],
        maxContextLength: Int? = nil,
        supportsRealTime: Bool = false,
        supportsBatch: Bool = true,
        supportsOffline: Bool = true,
        supportsPersonalData: Bool = true,
        isOnDevice: Bool = true,
        estimatedResponseTime: TimeInterval = 1.0,
        memoryRequirements: Int? = nil,
        supportedLanguages: [String] = ["en"],
        maxAudioDuration: TimeInterval? = nil,
        maxImageSize: Int? = nil,
        maxVideoSize: Int? = nil,
        requiresPermission: Bool = false,
        requiresNetwork: Bool = false
    ) {
        self.supportedModalities = supportedModalities
        self.supportedInputTypes = supportedInputTypes
        self.supportedOutputTypes = supportedOutputTypes
        self.maxContextLength = maxContextLength
        self.supportsRealTime = supportsRealTime
        self.supportsBatch = supportsBatch
        self.supportsOffline = supportsOffline
        self.supportsPersonalData = supportsPersonalData
        self.isOnDevice = isOnDevice
        self.estimatedResponseTime = estimatedResponseTime
        self.memoryRequirements = memoryRequirements
        self.supportedLanguages = supportedLanguages
        self.maxAudioDuration = maxAudioDuration
        self.maxImageSize = maxImageSize
        self.maxVideoSize = maxVideoSize
        self.requiresPermission = requiresPermission
        self.requiresNetwork = requiresNetwork
    }
}

// MARK: - Unified Model Provider Protocol

/// Unified protocol for all AI model providers
public protocol UnifiedModelProvider: AnyObject {
    
    // MARK: - Identity
    
    /// Unique identifier for this provider
    var identifier: String { get }
    
    /// Display name for this provider
    var displayName: String { get }
    
    /// Version of the provider
    var version: String { get }
    
    /// Primary model type this provider handles
    var primaryModelType: ModelType { get }
    
    /// All model types this provider can handle
    var supportedModelTypes: [ModelType] { get }
    
    // MARK: - Capabilities
    
    /// Comprehensive capabilities of this provider
    var capabilities: ModelCapabilities { get }
    
    /// Check if this provider is currently available
    var isAvailable: Bool { get }
    
    /// Current health status of the provider
    var healthStatus: ProviderHealthStatus { get }
    
    // MARK: - Core Operations
    
    /// Process input and generate output
    /// - Parameters:
    ///   - input: Unified input containing text, audio, images, etc.
    ///   - modelType: Specific model type to use (optional, defaults to primary)
    /// - Returns: Unified output with generated content
    func process(input: UnifiedModelInput, modelType: ModelType?) async throws -> UnifiedModelOutput
    
    /// Process streaming input (for real-time operations)
    /// - Parameters:
    ///   - inputStream: Stream of unified inputs
    ///   - modelType: Specific model type to use
    /// - Returns: Stream of unified outputs
    func processStream(inputStream: AsyncStream<UnifiedModelInput>, modelType: ModelType?) -> AsyncStream<UnifiedModelOutput>
    
    /// Prepare the provider for use (load models, authenticate, etc.)
    /// - Parameter modelTypes: Specific model types to prepare (optional, defaults to all)
    func prepare(modelTypes: [ModelType]?) async throws
    
    /// Clean up resources
    /// - Parameter modelTypes: Specific model types to clean up (optional, defaults to all)
    func cleanup(modelTypes: [ModelType]?) async
    
    // MARK: - Validation
    
    /// Check if provider can handle the given input
    /// - Parameters:
    ///   - input: Input to validate
    ///   - modelType: Model type to validate against
    /// - Returns: True if input can be processed
    func canProcess(input: UnifiedModelInput, modelType: ModelType) -> Bool
    
    /// Get estimated processing time for input
    /// - Parameters:
    ///   - input: Input to estimate for
    ///   - modelType: Model type to estimate for
    /// - Returns: Estimated processing time
    func estimateProcessingTime(for input: UnifiedModelInput, modelType: ModelType) -> TimeInterval
    
    // MARK: - Model Management
    
    /// Load a specific model
    /// - Parameters:
    ///   - modelName: Name of the model to load
    ///   - modelType: Type of the model
    func loadModel(name: String, type: ModelType) async throws
    
    /// Unload a specific model
    /// - Parameters:
    ///   - modelName: Name of the model to unload
    ///   - modelType: Type of the model
    func unloadModel(name: String, type: ModelType) async throws
    
    /// Check if a model is loaded
    /// - Parameters:
    ///   - modelName: Name of the model
    ///   - modelType: Type of the model
    /// - Returns: True if model is loaded
    func isModelLoaded(name: String, type: ModelType) -> Bool
    
    /// Get available models for a type
    /// - Parameter modelType: Type of models to list
    /// - Returns: List of available model names
    func getAvailableModels(for modelType: ModelType) -> [String]
    
    /// Get currently loaded models
    /// - Returns: Dictionary of model types to loaded model names
    func getLoadedModels() -> [ModelType: [String]]
}

// MARK: - Provider Health Status

/// Health status for monitoring provider performance
public struct ProviderHealthStatus {
    let isHealthy: Bool
    let lastSuccessfulOperation: Date?
    let consecutiveFailures: Int
    let averageResponseTime: TimeInterval
    let errorRate: Double
    let memoryUsage: Int? // in MB
    let activeModels: [String]
    let lastError: Error?
    
    public var shouldFallback: Bool {
        return !isHealthy || consecutiveFailures > 3 || errorRate > 0.5
    }
    
    public init(
        isHealthy: Bool,
        lastSuccessfulOperation: Date? = nil,
        consecutiveFailures: Int = 0,
        averageResponseTime: TimeInterval = 0,
        errorRate: Double = 0,
        memoryUsage: Int? = nil,
        activeModels: [String] = [],
        lastError: Error? = nil
    ) {
        self.isHealthy = isHealthy
        self.lastSuccessfulOperation = lastSuccessfulOperation
        self.consecutiveFailures = consecutiveFailures
        self.averageResponseTime = averageResponseTime
        self.errorRate = errorRate
        self.memoryUsage = memoryUsage
        self.activeModels = activeModels
        self.lastError = lastError
    }
}

// MARK: - Unified Model Provider Errors

public enum UnifiedModelProviderError: Error, LocalizedError {
    case providerUnavailable(String)
    case modelTypeNotSupported(ModelType)
    case modalityNotSupported(ModelModality)
    case inputValidationFailed(String)
    case outputGenerationFailed(String)
    case modelNotLoaded(String, ModelType)
    case modelLoadingFailed(String, ModelType, Error)
    case resourcesExhausted(String)
    case permissionDenied(String)
    case networkRequired(String)
    case processingFailed(String)
    case invalidConfiguration(String)
    case rateLimitExceeded
    case contextTooLarge(Int, Int) // actual, maximum
    case audioFormatUnsupported(String)
    case imageFormatUnsupported(String)
    case videoFormatUnsupported(String)
    
    public var errorDescription: String? {
        switch self {
        case .providerUnavailable(let provider):
            return "Provider unavailable: \(provider)"
        case .modelTypeNotSupported(let type):
            return "Model type not supported: \(type.displayName)"
        case .modalityNotSupported(let modality):
            return "Modality not supported: \(modality.displayName)"
        case .inputValidationFailed(let reason):
            return "Input validation failed: \(reason)"
        case .outputGenerationFailed(let reason):
            return "Output generation failed: \(reason)"
        case .modelNotLoaded(let name, let type):
            return "Model not loaded: \(name) (\(type.displayName))"
        case .modelLoadingFailed(let name, let type, let error):
            return "Model loading failed: \(name) (\(type.displayName)) - \(error.localizedDescription)"
        case .resourcesExhausted(let reason):
            return "Resources exhausted: \(reason)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .networkRequired(let reason):
            return "Network required: \(reason)"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .contextTooLarge(let actual, let maximum):
            return "Context too large: \(actual) tokens, maximum: \(maximum)"
        case .audioFormatUnsupported(let format):
            return "Audio format unsupported: \(format)"
        case .imageFormatUnsupported(let format):
            return "Image format unsupported: \(format)"
        case .videoFormatUnsupported(let format):
            return "Video format unsupported: \(format)"
        }
    }
}

// MARK: - Default Extensions

extension UnifiedModelProvider {
    
    public var version: String {
        return "1.0.0"
    }
    
    public var supportedModelTypes: [ModelType] {
        return [primaryModelType]
    }
    
    public func process(input: UnifiedModelInput, modelType: ModelType? = nil) async throws -> UnifiedModelOutput {
        let targetType = modelType ?? primaryModelType
        return try await process(input: input, modelType: targetType)
    }
    
    public func prepare(modelTypes: [ModelType]? = nil) async throws {
        let targetTypes = modelTypes ?? supportedModelTypes
        try await prepare(modelTypes: targetTypes)
    }
    
    public func cleanup(modelTypes: [ModelType]? = nil) async {
        let targetTypes = modelTypes ?? supportedModelTypes
        await cleanup(modelTypes: targetTypes)
    }
    
    public func estimateProcessingTime(for input: UnifiedModelInput, modelType: ModelType) -> TimeInterval {
        return capabilities.estimatedResponseTime
    }
    
    public func canProcess(input: UnifiedModelInput, modelType: ModelType) -> Bool {
        // Basic validation - can be overridden by providers
        guard supportedModelTypes.contains(modelType) else { return false }
        
        // Check modality support
        if let _ = input.text, !capabilities.supportedModalities.contains(.text) && !capabilities.supportedModalities.contains(.multimodal) {
            return false
        }
        
        if let _ = input.audioData, !capabilities.supportedModalities.contains(.audio) && !capabilities.supportedModalities.contains(.multimodal) {
            return false
        }
        
        if let _ = input.imageData, !capabilities.supportedModalities.contains(.vision) && !capabilities.supportedModalities.contains(.multimodal) {
            return false
        }
        
        return true
    }
    
    public func processStream(inputStream: AsyncStream<UnifiedModelInput>, modelType: ModelType? = nil) -> AsyncStream<UnifiedModelOutput> {
        // Default implementation - providers can override for true streaming
        return AsyncStream { continuation in
            Task {
                for await input in inputStream {
                    do {
                        let output = try await process(input: input, modelType: modelType)
                        continuation.yield(output)
                    } catch {
                        continuation.finish()
                        break
                    }
                }
                continuation.finish()
            }
        }
    }
    
    public func loadModel(name: String, type: ModelType) async throws {
        // Default implementation - providers can override
        throw UnifiedModelProviderError.modelTypeNotSupported(type)
    }
    
    public func unloadModel(name: String, type: ModelType) async throws {
        // Default implementation - providers can override
        throw UnifiedModelProviderError.modelTypeNotSupported(type)
    }
    
    public func isModelLoaded(name: String, type: ModelType) -> Bool {
        // Default implementation - providers can override
        return false
    }
    
    public func getAvailableModels(for modelType: ModelType) -> [String] {
        // Default implementation - providers can override
        return []
    }
    
    public func getLoadedModels() -> [ModelType: [String]] {
        // Default implementation - providers can override
        return [:]
    }
}