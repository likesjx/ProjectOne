//
//  WorkingMLXProvider.swift
//  ProjectOne
//
//  ACTUAL working MLX implementation based on current MLX Swift 0.25.6 APIs
//

import Foundation
import Combine
import MLXLMCommon
import os.log

/// Working MLX provider using the REAL MLX Swift APIs from the actual documentation
public class WorkingMLXProvider: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "WorkingMLXProvider")
    
    // MARK: - Properties
    
    @Published public var isLoading = false
    @Published public var loadingProgress: Double = 0.0
    @Published public var errorMessage: String?
    @Published public var isReady = false
    
    private var chatSession: ChatSession?
    private var modelContext: ModelContext?
    private var currentModelId: String?
    
    // MARK: - Supported Models (Real MLX Models from Hub)
    
    public enum MLXModel: String, CaseIterable {
        // Optimal Gemma-3n variants based on MLX community research
        case gemma3n_E4B_5bit = "mlx-community/gemma-3n-E4B-it-5bit"     // Mac optimized
        case gemma3n_E2B_4bit = "mlx-community/gemma-3n-E2B-it-4bit"     // iOS optimized
        case gemma3n_E4B_8bit = "mlx-community/gemma-3n-E4B-it-8bit"     // High quality Mac
        case gemma3n_E2B_5bit = "mlx-community/gemma-3n-E2B-it-5bit"     // Balanced mobile
        
        // Legacy models for compatibility
        case qwen3_4B = "mlx-community/Qwen3-4B-4bit"
        case gemma2_2B = "mlx-community/Gemma-2-2b-it-4bit" 
        case llama3_8B = "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"
        
        public var displayName: String {
            switch self {
            case .gemma3n_E4B_5bit: return "Gemma-3n E4B (5-bit) - Mac Optimized"
            case .gemma3n_E2B_4bit: return "Gemma-3n E2B (4-bit) - iOS Optimized"
            case .gemma3n_E4B_8bit: return "Gemma-3n E4B (8-bit) - High Quality"
            case .gemma3n_E2B_5bit: return "Gemma-3n E2B (5-bit) - Balanced Mobile"
            case .qwen3_4B: return "Qwen3 4B (4-bit)"
            case .gemma2_2B: return "Gemma 2 2B (4-bit)"
            case .llama3_8B: return "Llama 3.1 8B (4-bit)"
            }
        }
        
        public var memoryRequirement: String {
            switch self {
            case .gemma3n_E2B_4bit: return "~1.7GB RAM"
            case .gemma3n_E2B_5bit: return "~2.1GB RAM"
            case .gemma3n_E4B_5bit: return "~3-4GB RAM"
            case .gemma3n_E4B_8bit: return "~8GB RAM"
            case .qwen3_4B, .gemma2_2B: return "~3GB RAM"
            case .llama3_8B: return "~6-8GB RAM"
            }
        }
        
        public var targetPlatform: String {
            switch self {
            case .gemma3n_E2B_4bit, .gemma3n_E2B_5bit: return "iOS/Mobile"
            case .gemma3n_E4B_5bit, .gemma3n_E4B_8bit: return "Mac/Desktop"
            case .qwen3_4B, .gemma2_2B, .llama3_8B: return "Cross-platform"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing Working MLX Provider")
    }
    
    // MARK: - Model Management (Real MLX APIs)
    
    /// Load a model using the actual MLX Swift API
    public func loadModel(_ model: MLXModel) async throws {
        // Early check: MLX requires Metal 4 and real Apple Silicon hardware
        guard isMLXSupported else {
            await MainActor.run {
                isLoading = false
                isReady = false
                errorMessage = "MLX requires real Apple Silicon hardware (not simulator)"
            }
            logger.error("MLX not supported: running on simulator or Intel Mac")
            throw WorkingMLXError.loadingError("MLX requires real Apple Silicon hardware")
        }
        
        await MainActor.run {
            isLoading = true
            loadingProgress = 0.0
            errorMessage = nil
            isReady = false
        }
        
        do {
            logger.info("Loading MLX model: \(model.displayName)")
            
            // Progress update
            await MainActor.run { loadingProgress = 0.1 }
            
            // Use the REAL MLX Swift API from the documentation
            logger.info("Calling MLXLMCommon.loadModel with id: \(model.rawValue)")
            
            // This is the actual working API call from MLX Swift documentation
            let loadedModel = try await MLXLMCommon.loadModel(id: model.rawValue) { progress in
                Task { @MainActor in
                    self.loadingProgress = 0.1 + (progress.fractionCompleted * 0.8)
                }
            }
            
            await MainActor.run { loadingProgress = 0.9 }
            
            // Create chat session with the loaded model
            let session = ChatSession(loadedModel)
            
            // Store references
            self.modelContext = loadedModel
            self.chatSession = session
            self.currentModelId = model.rawValue
            
            await MainActor.run {
                loadingProgress = 1.0
                isReady = true
                isLoading = false
            }
            
            logger.info("✅ MLX model loaded successfully: \(model.displayName)")
            
        } catch {
            await MainActor.run {
                isLoading = false
                isReady = false
                errorMessage = "Failed to load \(model.displayName): \(error.localizedDescription)"
            }
            logger.error("❌ MLX model loading failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Generate response using loaded model
    public func generateResponse(to prompt: String) async throws -> String {
        guard let session = chatSession else {
            throw WorkingMLXError.modelNotLoaded("No model loaded")
        }
        
        guard isReady else {
            throw WorkingMLXError.modelNotReady("Model is not ready")
        }
        
        logger.info("Generating response for prompt: \(prompt.prefix(50))...")
        
        do {
            // Use the real ChatSession API
            let response = try await session.respond(to: prompt)
            logger.info("✅ Response generated successfully")
            return response
            
        } catch {
            logger.error("❌ Response generation failed: \(error.localizedDescription)")
            throw WorkingMLXError.inferenceError(error.localizedDescription)
        }
    }
    
    /// Stream response (for real-time UI updates)
    public func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let session = chatSession else {
                        continuation.finish(throwing: WorkingMLXError.modelNotLoaded("No model loaded"))
                        return
                    }
                    
                    // For now, simulate streaming by chunking the response
                    // Real MLX streaming would use TokenIterator
                    let response = try await session.respond(to: prompt)
                    
                    // Simulate streaming by yielding chunks
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
    
    /// Get model information
    public func getModelInfo() -> WorkingModelInfo? {
        guard let modelId = currentModelId,
              let model = MLXModel(rawValue: modelId) else {
            return nil
        }
        
        return WorkingModelInfo(
            id: modelId,
            displayName: model.displayName,
            memoryRequirement: model.memoryRequirement,
            isLoaded: isReady,
            loadingProgress: loadingProgress
        )
    }
    
    /// Unload current model to free memory
    public func unloadModel() async {
        logger.info("Unloading MLX model")
        
        chatSession = nil
        modelContext = nil
        currentModelId = nil
        
        await MainActor.run {
            isReady = false
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("✅ MLX model unloaded")
    }
}

// MARK: - Supporting Types

public struct WorkingModelInfo {
    public let id: String
    public let displayName: String
    public let memoryRequirement: String
    public let isLoaded: Bool
    public let loadingProgress: Double
}

public enum WorkingMLXError: Error, LocalizedError {
    case modelNotLoaded(String)
    case modelNotReady(String)
    case inferenceError(String)
    case loadingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded(let message):
            return "Model not loaded: \(message)"
        case .modelNotReady(let message):
            return "Model not ready: \(message)"
        case .inferenceError(let message):
            return "Inference error: \(message)"
        case .loadingError(let message):
            return "Loading error: \(message)"
        }
    }
}

// MARK: - Device Compatibility

extension WorkingMLXProvider {
    
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
    
    /// Get recommended model based on platform and available memory
    public func getRecommendedModel() -> MLXModel {
        #if os(iOS)
        // iOS: Use optimized Gemma-3n E2B variants
        return .gemma3n_E2B_4bit // Best for iOS constraints
        #else
        // macOS: Use more capable Gemma-3n E4B variants
        return .gemma3n_E4B_5bit // Optimal balance for Mac
        #endif
    }
    
    /// Get high-performance model recommendation
    public func getHighPerformanceModel() -> MLXModel {
        #if os(iOS)
        return .gemma3n_E2B_5bit // Best quality for iOS
        #else
        return .gemma3n_E4B_8bit // High quality for Mac
        #endif
    }
    
    /// Get memory-efficient model recommendation
    public func getMemoryEfficientModel() -> MLXModel {
        #if os(iOS)
        return .gemma3n_E2B_4bit // Most efficient for iOS
        #else
        return .gemma3n_E4B_5bit // Efficient for Mac
        #endif
    }
}