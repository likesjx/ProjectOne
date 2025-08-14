//
//  MLXLLMProvider.swift
//  ProjectOne
//
//  MLX Language Model Provider for text generation
//  Implements ObservableObject pattern for reactive UI updates
//

import Foundation
import SwiftUI
import Combine
import os.log

/// MLX Language Model Provider for text generation
@MainActor
public class MLXLLMProvider: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXLLMProvider")
    
    // MARK: - Published Properties
    
    @Published public var isSupported: Bool = false
    @Published public var isReady: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var loadingProgress: Double = 0.0
    @Published public var errorMessage: String?
    
    // MARK: - Configuration
    
    private let mlxService: MLXService
    private var currentConfiguration: MLXModelConfiguration?
    private var modelContainer: ModelContainer?
    
    // MARK: - Initialization
    
    public init() {
        self.mlxService = MLXService()
        self.isSupported = checkMLXSupport()
        
        logger.info("MLXLLMProvider initialized, supported: \(isSupported)")
    }
    
    // MARK: - Support Check
    
    private func checkMLXSupport() -> Bool {
        #if canImport(MLX)
        #if targetEnvironment(simulator)
        return false // MLX requires real Apple Silicon hardware
        #else
        #if arch(arm64)
        return true // Apple Silicon Macs and iOS devices
        #else
        return false // Intel Macs not supported
        #endif
        #endif
        #else
        return false
        #endif
    }
    
    // MARK: - Model Management
    
    /// Load a specific model configuration
    public func loadModel(_ configuration: MLXModelConfiguration) async throws {
        guard isSupported else {
            throw MLXError.deviceNotSupported("MLX requires Apple Silicon hardware")
        }
        
        await MainActor.run {
            isLoading = true
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        do {
            logger.info("Loading MLX LLM model: \(configuration.modelId)")
            
            // Load through service layer
            let container = try await mlxService.loadModel(modelId: configuration.modelId)
            
            // Store configuration and container
            self.currentConfiguration = configuration
            self.modelContainer = container
            
            await MainActor.run {
                isReady = true
                isLoading = false
                loadingProgress = 1.0
            }
            
            logger.info("✅ MLX LLM model loaded successfully")
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            logger.error("❌ Failed to load MLX LLM model: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Unload the current model
    public func unloadModel() async {
        logger.info("Unloading MLX LLM model")
        
        currentConfiguration = nil
        modelContainer = nil
        
        await MainActor.run {
            isReady = false
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("MLX LLM model unloaded")
    }
    
    /// Generate text using the loaded model
    public func generateText(_ prompt: String) async throws -> String {
        guard isReady, let container = modelContainer else {
            throw MLXError.modelNotReady("MLX LLM model not loaded")
        }
        
        logger.info("Generating text with MLX LLM")
        
        do {
            let response = try await mlxService.generate(with: container, prompt: prompt)
            logger.info("✅ MLX LLM text generation completed")
            return response
            
        } catch {
            logger.error("❌ MLX LLM text generation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get model information
    public func getModelInfo() -> MLXModelInfo? {
        guard let config = currentConfiguration else { return nil }
        
        return MLXModelInfo(
            displayName: config.name,
            modelId: config.modelId,
            type: .llm,
            isLoaded: isReady
        )
    }
}

// MARK: - Supporting Types

public struct MLXModelConfiguration {
    public let modelId: String
    public let name: String
    public let type: MLXModelType
    public let downloadURL: String?
    
    public init(modelId: String, name: String, type: MLXModelType, downloadURL: String? = nil) {
        self.modelId = modelId
        self.name = name
        self.type = type
        self.downloadURL = downloadURL
    }
}

public struct MLXModelInfo {
    public let displayName: String
    public let modelId: String
    public let type: MLXModelType
    public let isLoaded: Bool
}

public enum MLXModelType {
    case llm
    case vlm
}

public enum MLXError: Error, LocalizedError {
    case deviceNotSupported(String)
    case modelNotReady(String)
    case configurationInvalid(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let message):
            return "Device not supported: \(message)"
        case .modelNotReady(let message):
            return "Model not ready: \(message)"
        case .configurationInvalid(let message):
            return "Invalid configuration: \(message)"
        }
    }
}