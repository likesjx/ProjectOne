//
//  MLXVLMProvider.swift
//  ProjectOne
//
//  MLX Vision-Language Model Provider for multimodal AI
//  Implements ObservableObject pattern for reactive UI updates
//

import Foundation
import SwiftUI
import Combine
import os.log

/// MLX Vision-Language Model Provider for multimodal AI
@MainActor
public class MLXVLMProvider: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXVLMProvider")
    
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
        
        logger.info("MLXVLMProvider initialized, supported: \(isSupported)")
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
            logger.info("Loading MLX VLM model: \(configuration.modelId)")
            
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
            
            logger.info("✅ MLX VLM model loaded successfully")
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            logger.error("❌ Failed to load MLX VLM model: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Unload the current model
    public func unloadModel() async {
        logger.info("Unloading MLX VLM model")
        
        currentConfiguration = nil
        modelContainer = nil
        
        await MainActor.run {
            isReady = false
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("MLX VLM model unloaded")
    }
    
    /// Generate text with vision input using the loaded model
    public func generateWithVision(prompt: String, imageData: Data) async throws -> String {
        guard isReady, let container = modelContainer else {
            throw MLXError.modelNotReady("MLX VLM model not loaded")
        }
        
        logger.info("Generating vision-language response with MLX VLM")
        
        do {
            // For now, use text generation - VLM integration can be added later
            let response = try await mlxService.generate(with: container, prompt: prompt)
            logger.info("✅ MLX VLM generation completed")
            return response
            
        } catch {
            logger.error("❌ MLX VLM generation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Get model information
    public func getModelInfo() -> MLXModelInfo? {
        guard let config = currentConfiguration else { return nil }
        
        return MLXModelInfo(
            displayName: config.name,
            modelId: config.modelId,
            type: .vlm,
            isLoaded: isReady
        )
    }
}