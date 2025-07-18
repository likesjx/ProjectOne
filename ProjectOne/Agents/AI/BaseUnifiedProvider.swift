//
//  BaseUnifiedProvider.swift
//  ProjectOne
//
//  Created for unified base implementation
//

import Foundation
import AVFoundation
import os.log

/// Base implementation for unified model providers
/// Provides common functionality and infrastructure for all provider types
public class BaseUnifiedProvider: UnifiedModelProvider {
    
    // MARK: - Common Infrastructure
    
    internal let logger: Logger
    internal let processingQueue = DispatchQueue(label: "unified-provider", qos: .userInitiated)
    internal var loadedModels: [ModelType: Set<String>] = [:]
    internal var modelHealthStatus: ProviderHealthStatus
    internal var consecutiveFailures: Int = 0
    internal var lastSuccessfulOperation: Date?
    internal var responseTimeSamples: [TimeInterval] = []
    internal let maxResponseTimeSamples = 10
    
    // MARK: - Abstract Properties (Override Required)
    
    public var identifier: String { fatalError("Must override identifier") }
    public var displayName: String { fatalError("Must override displayName") }
    public var primaryModelType: ModelType { fatalError("Must override primaryModelType") }
    public var capabilities: ModelCapabilities { fatalError("Must override capabilities") }
    public var isAvailable: Bool { fatalError("Must override isAvailable") }
    
    // MARK: - Common Properties
    
    public var version: String { "1.0.0" }
    public var supportedModelTypes: [ModelType] { [primaryModelType] }
    
    public var healthStatus: ProviderHealthStatus {
        return modelHealthStatus
    }
    
    // MARK: - Initialization
    
    public init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        self.modelHealthStatus = ProviderHealthStatus(isHealthy: true)
        
        logger.info("Initializing \(type(of: self)) unified provider")
    }
    
    // MARK: - Core Operations (Override Required)
    
    /// Override to implement model-specific processing
    public func process(input: UnifiedModelInput, modelType: ModelType?) async throws -> UnifiedModelOutput {
        fatalError("Must override process(input:modelType:)")
    }
    
    /// Override to implement model-specific preparation
    public func prepare(modelTypes: [ModelType]?) async throws {
        fatalError("Must override prepare(modelTypes:)")
    }
    
    /// Override to implement model-specific cleanup
    public func cleanup(modelTypes: [ModelType]?) async {
        fatalError("Must override cleanup(modelTypes:)")
    }
    
    // MARK: - Shared Implementation
    
    /// Process with timing, error handling, and health monitoring
    public func processWithMonitoring(input: UnifiedModelInput, modelType: ModelType?) async throws -> UnifiedModelOutput {
        let targetType = modelType ?? primaryModelType
        
        // Validate input
        guard canProcess(input: input, modelType: targetType) else {
            throw UnifiedModelProviderError.inputValidationFailed("Input not supported for model type: \(targetType.displayName)")
        }
        
        // Check availability
        guard isAvailable else {
            throw UnifiedModelProviderError.providerUnavailable(displayName)
        }
        
        // Measure processing time
        let startTime = Date()
        
        do {
            let output = try await process(input: input, modelType: targetType)
            
            // Update health status on success
            let processingTime = Date().timeIntervalSince(startTime)
            updateHealthStatus(success: true, processingTime: processingTime)
            
            return output
            
        } catch {
            // Update health status on failure
            updateHealthStatus(success: false, processingTime: nil, error: error)
            throw error
        }
    }
    
    /// Measures processing time for any async operation
    public func measureProcessingTime<T>(_ operation: () async throws -> T) async throws -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let processingTime = Date().timeIntervalSince(startTime)
        return (result, processingTime)
    }
    
    /// Validates input against provider capabilities
    public func canProcess(input: UnifiedModelInput, modelType: ModelType) -> Bool {
        // Check if model type is supported
        guard supportedModelTypes.contains(modelType) else {
            logger.warning("Model type \(modelType.displayName) not supported by \(self.displayName)")
            return false
        }
        
        // Check modality support
        let hasText = input.text != nil
        let hasAudio = input.audioData != nil
        let hasImage = input.imageData != nil
        let hasVideo = input.videoData != nil
        
        let requiredModalities: Set<ModelModality> = Set([
            hasText ? .text : nil,
            hasAudio ? .audio : nil,
            hasImage ? .vision : nil,
            hasVideo ? .vision : nil
        ].compactMap { $0 })
        
        let supportedModalities = Set(capabilities.supportedModalities)
        
        // Check if all required modalities are supported
        if requiredModalities.isSubset(of: supportedModalities) {
            return true
        }
        
        // Check if multimodal is supported and we have multiple modalities
        if requiredModalities.count > 1 && supportedModalities.contains(.multimodal) {
            return true
        }
        
        logger.warning("Required modalities \(requiredModalities) not supported by \(self.displayName)")
        return false
    }
    
    /// Validates context size against provider limits
    public func validateContextSize(_ input: UnifiedModelInput) throws {
        guard let maxLength = capabilities.maxContextLength else { return }
        
        if let text = input.text {
            let estimatedTokens = estimateTokenCount(text)
            guard estimatedTokens <= maxLength else {
                throw UnifiedModelProviderError.contextTooLarge(estimatedTokens, maxLength)
            }
        }
    }
    
    /// Estimates token count from text (rough approximation)
    public func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        return text.count / 4
    }
    
    /// Updates health status based on operation results
    private func updateHealthStatus(success: Bool, processingTime: TimeInterval?, error: Error? = nil) {
        if success {
            consecutiveFailures = 0
            lastSuccessfulOperation = Date()
            
            if let processingTime = processingTime {
                responseTimeSamples.append(processingTime)
                if responseTimeSamples.count > maxResponseTimeSamples {
                    responseTimeSamples.removeFirst()
                }
            }
        } else {
            consecutiveFailures += 1
        }
        
        let averageResponseTime = responseTimeSamples.isEmpty ? 0 : responseTimeSamples.reduce(0, +) / Double(responseTimeSamples.count)
        let errorRate = consecutiveFailures > 0 ? Double(consecutiveFailures) / Double(consecutiveFailures + 1) : 0
        
        modelHealthStatus = ProviderHealthStatus(
            isHealthy: consecutiveFailures < 3,
            lastSuccessfulOperation: lastSuccessfulOperation,
            consecutiveFailures: consecutiveFailures,
            averageResponseTime: averageResponseTime,
            errorRate: errorRate,
            memoryUsage: nil, // Can be overridden by providers
            activeModels: getAllLoadedModels(),
            lastError: error
        )
    }
    
    /// Gets all loaded models across all types
    private func getAllLoadedModels() -> [String] {
        var allModels: [String] = []
        for (_, models) in loadedModels {
            allModels.append(contentsOf: models)
        }
        return allModels
    }
    
    // MARK: - Model Management (Default Implementation)
    
    public func loadModel(name: String, type: ModelType) async throws {
        logger.info("Loading model \(name) of type \(type.displayName)")
        
        // Default implementation - providers can override
        if loadedModels[type] == nil {
            loadedModels[type] = Set()
        }
        loadedModels[type]?.insert(name)
    }
    
    public func unloadModel(name: String, type: ModelType) async throws {
        logger.info("Unloading model \(name) of type \(type.displayName)")
        
        // Default implementation - providers can override
        loadedModels[type]?.remove(name)
    }
    
    public func isModelLoaded(name: String, type: ModelType) -> Bool {
        return loadedModels[type]?.contains(name) ?? false
    }
    
    public func getAvailableModels(for modelType: ModelType) -> [String] {
        // Default implementation - providers should override
        return []
    }
    
    public func getLoadedModels() -> [ModelType: [String]] {
        var result: [ModelType: [String]] = [:]
        for (type, modelSet) in loadedModels {
            result[type] = Array(modelSet)
        }
        return result
    }
    
    // MARK: - Streaming Support (Default Implementation)
    
    public func processStream(inputStream: AsyncStream<UnifiedModelInput>, modelType: ModelType?) -> AsyncStream<UnifiedModelOutput> {
        return AsyncStream { continuation in
            Task {
                for await input in inputStream {
                    do {
                        let output = try await processWithMonitoring(input: input, modelType: modelType)
                        continuation.yield(output)
                    } catch {
                        logger.error("Stream processing failed: \(error.localizedDescription)")
                        continuation.finish()
                        break
                    }
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: - Utility Methods
    
    /// Creates a text-only output
    public func createTextOutput(
        text: String,
        confidence: Double = 1.0,
        processingTime: TimeInterval,
        tokensUsed: Int? = nil,
        metadata: [String: Any] = [:]
    ) -> UnifiedModelOutput {
        return UnifiedModelOutput(
            text: text,
            confidence: confidence,
            processingTime: processingTime,
            modelUsed: displayName,
            tokensUsed: tokensUsed,
            metadata: metadata
        )
    }
    
    /// Creates a transcription output
    public func createTranscriptionOutput(
        transcriptionResult: SpeechTranscriptionResult,
        confidence: Double? = nil,
        processingTime: TimeInterval,
        metadata: [String: Any] = [:]
    ) -> UnifiedModelOutput {
        return UnifiedModelOutput(
            text: transcriptionResult.text,
            transcriptionResult: transcriptionResult,
            confidence: confidence ?? Double(transcriptionResult.confidence),
            processingTime: processingTime,
            modelUsed: displayName,
            metadata: metadata
        )
    }
    
    /// Creates a multimodal output
    public func createMultimodalOutput(
        text: String? = nil,
        audioData: AudioData? = nil,
        imageData: Data? = nil,
        videoData: Data? = nil,
        confidence: Double = 1.0,
        processingTime: TimeInterval,
        tokensUsed: Int? = nil,
        metadata: [String: Any] = [:]
    ) -> UnifiedModelOutput {
        return UnifiedModelOutput(
            text: text,
            audioData: audioData,
            imageData: imageData,
            videoData: videoData,
            confidence: confidence,
            processingTime: processingTime,
            modelUsed: displayName,
            tokensUsed: tokensUsed,
            metadata: metadata
        )
    }
    
    /// Enriches prompt with memory context (for text generation models)
    public func enrichPromptWithContext(prompt: String, context: MemoryContext?) -> String {
        guard let context = context else { return prompt }
        
        var enrichedPrompt = ""
        
        // Add system context
        enrichedPrompt += """
        You are the Memory Agent for ProjectOne, an intelligent personal knowledge assistant. You have access to the user's personal memory and knowledge graph.
        
        """
        
        // Add memory context
        if !context.longTermMemories.isEmpty {
            enrichedPrompt += "## Long-term Knowledge:\n"
            for memory in context.longTermMemories.prefix(3) {
                enrichedPrompt += "- [\(memory.category.rawValue.capitalized)] \(memory.content.prefix(100))\n"
            }
            enrichedPrompt += "\n"
        }
        
        if !context.shortTermMemories.isEmpty {
            enrichedPrompt += "## Recent Context:\n"
            for memory in context.shortTermMemories.prefix(5) {
                enrichedPrompt += "- \(memory.content.prefix(80))\n"
            }
            enrichedPrompt += "\n"
        }
        
        if !context.entities.isEmpty {
            enrichedPrompt += "## Relevant Entities:\n"
            for entity in context.entities.prefix(5) {
                enrichedPrompt += "- [\(entity.type.rawValue.capitalized)] \(entity.name): \(entity.entityDescription ?? "No description")\n"
            }
            enrichedPrompt += "\n"
        }
        
        // Add the user's query
        enrichedPrompt += "## Current Query:\n\(prompt)\n\n"
        enrichedPrompt += "## Response:\n"
        
        return enrichedPrompt
    }
}

// MARK: - Convenience Extensions

extension UnifiedModelInput {
    
    /// Creates a text-only input
    public static func text(
        _ text: String,
        context: MemoryContext? = nil,
        configuration: [String: Any] = [:]
    ) -> UnifiedModelInput {
        return UnifiedModelInput(
            text: text,
            context: context,
            configuration: configuration
        )
    }
    
    /// Creates an audio-only input
    public static func audio(
        _ audioData: AudioData,
        context: MemoryContext? = nil,
        configuration: [String: Any] = [:]
    ) -> UnifiedModelInput {
        return UnifiedModelInput(
            audioData: audioData,
            context: context,
            configuration: configuration
        )
    }
    
    /// Creates an image-only input
    public static func image(
        _ imageData: Data,
        context: MemoryContext? = nil,
        configuration: [String: Any] = [:]
    ) -> UnifiedModelInput {
        return UnifiedModelInput(
            imageData: imageData,
            context: context,
            configuration: configuration
        )
    }
    
    /// Creates a multimodal input
    public static func multimodal(
        text: String? = nil,
        audioData: AudioData? = nil,
        imageData: Data? = nil,
        videoData: Data? = nil,
        context: MemoryContext? = nil,
        configuration: [String: Any] = [:]
    ) -> UnifiedModelInput {
        return UnifiedModelInput(
            text: text,
            audioData: audioData,
            imageData: imageData,
            videoData: videoData,
            context: context,
            configuration: configuration
        )
    }
}