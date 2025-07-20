//
//  MLXService.swift
//  ProjectOne
//
//  Core MLX service layer - handles all MLX operations with clean separation of concerns
//  Based on real MLX Swift Examples patterns for production use
//

import Foundation
import Combine
import MLXLMCommon
import MLXLLM
import MLXVLM
import os.log

/// Core service layer for all MLX operations
/// Provides model caching, factory pattern, and generation execution
public class MLXService: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXService")
    
    // MARK: - Properties
    
    /// Model cache using NSCache for automatic memory management
    private let modelCache = NSCache<NSString, ModelContainer>()
    
    @Published public var isLoading = false
    @Published public var loadingProgress: Double = 0.0
    @Published public var errorMessage: String?
    
    // MARK: - Device Compatibility
    
    /// Check if MLX is supported on current device
    public var isMLXSupported: Bool {
        #if targetEnvironment(simulator)
        return false // MLX requires real Apple Silicon hardware
        #else
        #if arch(arm64)
        return true // Apple Silicon Macs and iOS devices
        #else
        return false // Intel Macs not supported
        #endif
        #endif
    }
    
    // MARK: - Initialization
    
    public init() {
        setupCache()
        logger.info("MLXService initialized")
    }
    
    private func setupCache() {
        // Configure cache limits
        modelCache.countLimit = 3 // Max 3 models in memory
        modelCache.totalCostLimit = 8 * 1024 * 1024 * 1024 // 8GB total
    }
    
    // MARK: - Core Model Loading
    
    /// Load a model using the real MLX API
    public func loadModel(modelId: String, type: MLXModelType) async throws -> ModelContainer {
        guard isMLXSupported else {
            throw MLXServiceError.deviceNotSupported("MLX requires real Apple Silicon hardware")
        }
        
        await MainActor.run {
            isLoading = true
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("Loading \(type.displayName) model: \(modelId)")
        
        do {
            let cacheKey = getCacheKey(for: modelId, type: type)
            
            // Check cache first
            if let cached = modelCache.object(forKey: cacheKey) {
                logger.info("Using cached model")
                await MainActor.run {
                    loadingProgress = 1.0
                    isLoading = false
                }
                return cached
            }
            
            await MainActor.run { loadingProgress = 0.1 }
            
            // Use the real MLX Swift API from the documentation
            let loadedModel = try await MLXLMCommon.loadModel(id: modelId) { progress in
                Task { @MainActor in
                    self.loadingProgress = 0.1 + (progress.fractionCompleted * 0.8)
                }
            }
            
            await MainActor.run { loadingProgress = 0.9 }
            
            // Wrap in container (simplified approach)
            let container = ModelContainer(loadedModel)
            
            // Cache the loaded model
            modelCache.setObject(container, forKey: cacheKey)
            
            await MainActor.run {
                loadingProgress = 1.0
                isLoading = false
            }
            
            logger.info("✅ Model loaded successfully")
            return container
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            logger.error("❌ Model loading failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    
    // MARK: - Core Generation
    
    /// Core generation execution using ChatSession
    public func generate(with container: ModelContainer, prompt: String) async throws -> String {
        logger.info("Starting generation with container")
        
        // Create chat session with the loaded model
        let session = ChatSession(container.loadedModel)
        
        do {
            // Use the real ChatSession API
            let response = try await session.respond(to: prompt)
            logger.info("✅ Generation completed successfully")
            return response
            
        } catch {
            logger.error("❌ Generation failed: \(error.localizedDescription)")
            throw MLXServiceError.generationFailed(error.localizedDescription)
        }
    }
    
    /// Stream generation for real-time responses
    public func streamGenerate(with container: ModelContainer, prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // For now, simulate streaming by chunking the response
                    // Real streaming would use TokenIterator from the context
                    let response = try await generate(with: container, prompt: prompt)
                    
                    // Yield response in chunks
                    let words = response.components(separatedBy: " ")
                    for (index, word) in words.enumerated() {
                        if index == 0 {
                            continuation.yield(word)
                        } else {
                            continuation.yield(" " + word)
                        }
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached models
    public func clearCache() {
        modelCache.removeAllObjects()
        logger.info("Model cache cleared")
    }
    
    /// Get cached model for specific model ID
    public func getCachedModel(for modelId: String, type: MLXModelType) -> ModelContainer? {
        let cacheKey = getCacheKey(for: modelId, type: type)
        return modelCache.object(forKey: cacheKey)
    }
    
    /// Generate cache key for model ID and type
    private func getCacheKey(for modelId: String, type: MLXModelType) -> NSString {
        return "\(type.rawValue)_\(modelId)" as NSString
    }
    
    // MARK: - Model Information
    
    /// Get information about cached models
    public func getCacheInfo() -> MLXServiceCacheInfo {
        return MLXServiceCacheInfo(
            cachedModelCount: modelCache.totalCostLimit > 0 ? modelCache.totalCostLimit : 0,
            memoryUsage: estimateMemoryUsage(),
            isSupported: isMLXSupported
        )
    }
    
    private func estimateMemoryUsage() -> Double {
        // Estimate based on typical model sizes
        // This would be enhanced with actual memory tracking
        return Double(modelCache.totalCostLimit) / (1024 * 1024 * 1024) // Convert to GB
    }
}

// MARK: - Supporting Types

/// Model type enumeration
public enum MLXModelType: String, CaseIterable {
    case llm = "llm"
    case vlm = "vlm"
    
    public var displayName: String {
        switch self {
        case .llm: return "Language Model"
        case .vlm: return "Vision-Language Model"
        }
    }
}

/// Cache information structure
public struct MLXServiceCacheInfo {
    public let cachedModelCount: Int
    public let memoryUsage: Double // GB
    public let isSupported: Bool
    public let timestamp: Date = Date()
}

/// MLX Service specific errors
public enum MLXServiceError: Error, LocalizedError {
    case deviceNotSupported(String)
    case modelLoadingFailed(String)
    case generationFailed(String)
    case cacheError(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let message):
            return "Device not supported: \(message)"
        case .modelLoadingFailed(let message):
            return "Model loading failed: \(message)"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        }
    }
}

/// Simple model container wrapper for MLX models
public class ModelContainer {
    public let loadedModel: ModelContext
    
    public init(_ loadedModel: ModelContext) {
        self.loadedModel = loadedModel
    }
}