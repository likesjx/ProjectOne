//
//  MLXLLMProvider.swift
//  ProjectOne
//
//  Text-only chat interface wrapping MLXService
//  Clean separation between model management and chat interface
//

import Foundation
import SwiftUI
import Combine
import MLXLMCommon
import os.log

/// Text-only LLM provider wrapping MLXService
public class MLXLLMProvider: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXLLMProvider")
    
    // MARK: - Dependencies
    
    private let mlxService = MLXService()
    
    // MARK: - State
    
    @Published public var isReady = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var loadingProgress: Double = 0.0
    
    private var modelContainer: ModelContainer?
    private var currentConfiguration: MLXModelConfiguration?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing MLX LLM Provider")
        
        // Observe MLXService state
        mlxService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)
        
        mlxService.$loadingProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$loadingProgress)
        
        mlxService.$errorMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$errorMessage)
    }
    
    // MARK: - Device Compatibility
    
    /// Check if MLX LLM is supported on current device
    public var isSupported: Bool {
        return mlxService.isMLXSupported
    }
    
    // MARK: - Model Management
    
    /// Load a specific LLM model configuration
    public func loadModel(_ configuration: MLXModelConfiguration) async throws {
        guard configuration.type == .llm else {
            throw MLXLLMError.invalidModelType("Configuration is not for LLM model")
        }
        
        guard isSupported else {
            throw MLXLLMError.deviceNotSupported("MLX requires real Apple Silicon hardware")
        }
        
        logger.info("Loading LLM model: \(configuration.name)")
        
        await MainActor.run {
            isReady = false
            errorMessage = nil
        }
        
        do {
            // Load model through MLXService using model ID
            let container = try await mlxService.loadModel(modelId: configuration.modelId, type: .llm)
            
            // Store references
            self.modelContainer = container
            self.currentConfiguration = configuration
            
            await MainActor.run {
                isReady = true
                logger.info("✅ LLM model loaded: \(configuration.name)")
            }
            
        } catch {
            await MainActor.run {
                isReady = false
                errorMessage = "Failed to load \(configuration.name): \(error.localizedDescription)"
            }
            logger.error("❌ LLM model loading failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Load recommended model for current platform
    public func loadRecommendedModel() async throws {
        guard let config = MLXModelRegistry.getRecommendedModel(for: .llm) else {
            throw MLXLLMError.noModelAvailable("No recommended LLM model found")
        }
        
        try await loadModel(config)
    }
    
    /// Unload current model to free memory
    public func unloadModel() async {
        logger.info("Unloading LLM model")
        
        modelContainer = nil
        currentConfiguration = nil
        
        await MainActor.run {
            isReady = false
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("✅ LLM model unloaded")
    }
    
    // MARK: - Text Generation
    
    /// Generate response to text prompt
    public func generateResponse(to prompt: String) async throws -> String {
        guard let container = modelContainer else {
            throw MLXLLMError.modelNotLoaded("No LLM model loaded")
        }
        
        guard isReady else {
            throw MLXLLMError.modelNotReady("LLM model is not ready")
        }
        
        logger.info("Generating response for text prompt")
        
        do {
            // Generate using MLXService with simple prompt
            let response = try await mlxService.generate(with: container, prompt: prompt)
            
            logger.info("✅ LLM response generated successfully")
            return response
            
        } catch {
            logger.error("❌ LLM response generation failed: \(error.localizedDescription)")
            throw MLXLLMError.generationFailed(error.localizedDescription)
        }
    }
    
    /// Stream response for real-time UI updates
    public func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let container = modelContainer else {
                        continuation.finish(throwing: MLXLLMError.modelNotLoaded("No LLM model loaded"))
                        return
                    }
                    
                    guard isReady else {
                        continuation.finish(throwing: MLXLLMError.modelNotReady("LLM model is not ready"))
                        return
                    }
                    
                    // Stream using MLXService
                    for try await chunk in mlxService.streamGenerate(with: container, prompt: prompt) {
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Conversation Management
    
    /// Generate response with conversation history (simplified)
    public func generateResponse(withHistory conversationText: String) async throws -> String {
        guard let container = modelContainer else {
            throw MLXLLMError.modelNotLoaded("No LLM model loaded")
        }
        
        guard isReady else {
            throw MLXLLMError.modelNotReady("LLM model is not ready")
        }
        
        logger.info("Generating response with conversation history")
        
        do {
            // Generate using MLXService with conversation history
            let response = try await mlxService.generate(with: container, prompt: conversationText)
            
            logger.info("✅ Conversation response generated successfully")
            return response
            
        } catch {
            logger.error("❌ Conversation response generation failed: \(error.localizedDescription)")
            throw MLXLLMError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Model Information
    
    /// Get information about current model
    public func getModelInfo() -> MLXLLMModelInfo? {
        guard let config = currentConfiguration else {
            return nil
        }
        
        return MLXLLMModelInfo(
            configuration: config,
            isLoaded: isReady,
            loadingProgress: loadingProgress,
            isSupported: isSupported
        )
    }
    
    /// Get available LLM models for current platform
    public func getAvailableModels() -> [MLXModelConfiguration] {
        let platform: Platform = {
            #if os(iOS)
            return .iOS
            #else
            return .macOS
            #endif
        }()
        
        return MLXModelRegistry.models(for: platform).filter { $0.type == .llm }
    }
    
}

// MARK: - Supporting Types

/// Model information for LLM provider
public struct MLXLLMModelInfo {
    public let configuration: MLXModelConfiguration
    public let isLoaded: Bool
    public let loadingProgress: Double
    public let isSupported: Bool
    
    public var displayName: String {
        return configuration.name
    }
    
    public var memoryRequirement: String {
        return configuration.memoryRequirement
    }
}

/// MLX LLM Provider specific errors
public enum MLXLLMError: Error, LocalizedError {
    case deviceNotSupported(String)
    case modelNotLoaded(String)
    case modelNotReady(String)
    case generationFailed(String)
    case invalidModelType(String)
    case noModelAvailable(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let message):
            return "Device not supported: \(message)"
        case .modelNotLoaded(let message):
            return "Model not loaded: \(message)"
        case .modelNotReady(let message):
            return "Model not ready: \(message)"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .invalidModelType(let message):
            return "Invalid model type: \(message)"
        case .noModelAvailable(let message):
            return "No model available: \(message)"
        }
    }
}