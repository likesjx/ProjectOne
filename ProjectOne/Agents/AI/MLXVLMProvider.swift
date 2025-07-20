//
//  MLXVLMProvider.swift
//  ProjectOne
//
//  Multimodal chat interface wrapping MLXService
//  Supports text + image understanding using Vision-Language Models
//

import Foundation
import SwiftUI
import Combine
import MLXLMCommon
import MLXVLM
import os.log

#if canImport(UIKit)
import UIKit
#endif

/// Multimodal VLM provider wrapping MLXService
public class MLXVLMProvider: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXVLMProvider")
    
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
        logger.info("Initializing MLX VLM Provider")
        
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
    
    /// Check if MLX VLM is supported on current device
    public var isSupported: Bool {
        return mlxService.isMLXSupported
    }
    
    // MARK: - Model Management
    
    /// Load a specific VLM model configuration
    public func loadModel(_ configuration: MLXModelConfiguration) async throws {
        guard configuration.type == .vlm else {
            throw MLXVLMError.invalidModelType("Configuration is not for VLM model")
        }
        
        guard isSupported else {
            throw MLXVLMError.deviceNotSupported("MLX requires real Apple Silicon hardware")
        }
        
        logger.info("Loading VLM model: \(configuration.name)")
        
        await MainActor.run {
            isReady = false
            errorMessage = nil
        }
        
        do {
            // Load model through MLXService using model ID
            let container = try await mlxService.loadModel(modelId: configuration.modelId, type: .vlm)
            
            // Store references
            self.modelContainer = container
            self.currentConfiguration = configuration
            
            await MainActor.run {
                isReady = true
                logger.info("✅ VLM model loaded: \(configuration.name)")
            }
            
        } catch {
            await MainActor.run {
                isReady = false
                errorMessage = "Failed to load \(configuration.name): \(error.localizedDescription)"
            }
            logger.error("❌ VLM model loading failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Load recommended VLM model for current platform
    public func loadRecommendedModel() async throws {
        guard let config = MLXModelRegistry.getRecommendedModel(for: .vlm) else {
            throw MLXVLMError.noModelAvailable("No recommended VLM model found")
        }
        
        try await loadModel(config)
    }
    
    /// Unload current model to free memory
    public func unloadModel() async {
        logger.info("Unloading VLM model")
        
        modelContainer = nil
        currentConfiguration = nil
        
        await MainActor.run {
            isReady = false
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("✅ VLM model unloaded")
    }
    
    // MARK: - Multimodal Generation
    
    /// Generate response to text prompt with images
    public func generateResponse(to prompt: String, images: [UIImage] = []) async throws -> String {
        guard let container = modelContainer else {
            throw MLXVLMError.modelNotLoaded("No VLM model loaded")
        }
        
        guard isReady else {
            throw MLXVLMError.modelNotReady("VLM model is not ready")
        }
        
        logger.info("Generating multimodal response (text + \(images.count) images)")
        
        do {
            // For now, handle text-only until multimodal support is complete
            if !images.isEmpty {
                logger.warning("Image processing not yet implemented, processing text only")
            }
            
            // Generate using MLXService with simple prompt
            let response = try await mlxService.generate(with: container, prompt: prompt)
            
            logger.info("✅ Multimodal response generated successfully")
            return response
            
        } catch {
            logger.error("❌ Multimodal response generation failed: \(error.localizedDescription)")
            throw MLXVLMError.generationFailed(error.localizedDescription)
        }
    }
    
    /// Generate text-only response (fallback mode)
    public func generateResponse(to prompt: String) async throws -> String {
        return try await generateResponse(to: prompt, images: [])
    }
    
    /// Stream multimodal response for real-time UI updates
    public func streamResponse(to prompt: String, images: [UIImage] = []) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let container = modelContainer else {
                        continuation.finish(throwing: MLXVLMError.modelNotLoaded("No VLM model loaded"))
                        return
                    }
                    
                    guard isReady else {
                        continuation.finish(throwing: MLXVLMError.modelNotReady("VLM model is not ready"))
                        return
                    }
                    
                    // For now, handle text-only until multimodal support is complete
                    if !images.isEmpty {
                        logger.warning("Image processing not yet implemented, processing text only")
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
    
    /// Generate response with conversation history and images
    public func generateResponse(withHistory messages: [Chat.Message], images: [UIImage] = []) async throws -> String {
        guard let container = modelContainer else {
            throw MLXVLMError.modelNotLoaded("No VLM model loaded")
        }
        
        guard isReady else {
            throw MLXVLMError.modelNotReady("VLM model is not ready")
        }
        
        logger.info("Generating multimodal conversation response (\(messages.count) messages, \(images.count) images)")
        
        do {
            // For now, handle text-only until multimodal support is complete
            if !images.isEmpty {
                logger.warning("Image processing not yet implemented, processing text only")
            }
            
            // Convert conversation to single prompt (simplified approach)
            let conversationPrompt = messages.map { "\($0.role.rawValue): \($0.content)" }.joined(separator: "\n")
            
            // Generate using MLXService
            let response = try await mlxService.generate(with: container, prompt: conversationPrompt)
            
            logger.info("✅ Multimodal conversation response generated successfully")
            return response
            
        } catch {
            logger.error("❌ Multimodal conversation response generation failed: \(error.localizedDescription)")
            throw MLXVLMError.generationFailed(error.localizedDescription)
        }
    }
    
    
    // MARK: - Model Information
    
    /// Get information about current model
    public func getModelInfo() -> MLXVLMModelInfo? {
        guard let config = currentConfiguration else {
            return nil
        }
        
        return MLXVLMModelInfo(
            configuration: config,
            isLoaded: isReady,
            loadingProgress: loadingProgress,
            isSupported: isSupported
        )
    }
    
    /// Get available VLM models for current platform
    public func getAvailableModels() -> [MLXModelConfiguration] {
        let platform: Platform = {
            #if os(iOS)
            return .iOS
            #else
            return .macOS
            #endif
        }()
        
        return MLXModelRegistry.models(for: platform).filter { $0.type == .vlm }
    }
    
}

// MARK: - Supporting Types

/// Image processing configuration
public struct ImageProcessing {
    public let resize: ImageResize?
    
    public init(resize: ImageResize? = nil) {
        self.resize = resize
    }
}

/// Image resize configuration
public struct ImageResize {
    public let width: Int
    public let height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Model information for VLM provider
public struct MLXVLMModelInfo {
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
    
    public var supportsMultimodal: Bool {
        return true // VLM models always support multimodal
    }
}

/// MLX VLM Provider specific errors
public enum MLXVLMError: Error, LocalizedError {
    case deviceNotSupported(String)
    case modelNotLoaded(String)
    case modelNotReady(String)
    case generationFailed(String)
    case invalidModelType(String)
    case noModelAvailable(String)
    case imageProcessingFailed(String)
    
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
        case .imageProcessingFailed(let message):
            return "Image processing failed: \(message)"
        }
    }
}