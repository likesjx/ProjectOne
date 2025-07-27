//
//  WorkingMLXProvider.swift
//  ProjectOne
//
//  ACTUAL working MLX implementation based on current MLX Swift 0.25.6 APIs
//

import Foundation
import Combine
import MLXLMCommon
import MLXLLM
import MLXVLM
import os.log

/// Working MLX provider using the REAL MLX Swift APIs from the actual documentation
public class WorkingMLXProvider: ObservableObject, AIModelProvider {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "WorkingMLXProvider")
    
    // MARK: - Properties
    
    @Published public var isLoading = false
    @Published public var loadingProgress: Double = 0.0
    @Published public var errorMessage: String?
    @Published public var isReady = false
    
    private var modelContainer: MLXLMCommon.ModelContainer?
    private var chatSession: MLXLMCommon.ChatSession?
    private var currentModelId: String?
    
    // MARK: - Supported Models (Real MLX Models from Hub)
    
    public enum MLXModel: String, CaseIterable {
        // Gemma-3n VLM variants - these are Vision-Language Models
        case gemma3n_E4B_5bit = "mlx-community/gemma-3n-E4B-it-5bit"     // Mac optimized VLM
        case gemma3n_E2B_4bit = "mlx-community/gemma-3n-E2B-it-4bit"     // iOS optimized VLM
        case gemma3n_E4B_8bit = "mlx-community/gemma-3n-E4B-it-8bit"     // High quality Mac VLM
        case gemma3n_E2B_5bit = "mlx-community/gemma-3n-E2B-it-5bit"     // Balanced mobile VLM
        
        // Legacy LLM models for compatibility
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
        
        public var isVLM: Bool {
            switch self {
            case .gemma3n_E4B_5bit, .gemma3n_E2B_4bit, .gemma3n_E4B_8bit, .gemma3n_E2B_5bit:
                return true // Gemma-3n models are VLMs
            case .qwen3_4B, .gemma2_2B, .llama3_8B:
                return false // Legacy models are LLMs
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
            logger.info("🔧 [MLX LOAD] Starting model load process")
            logger.info("🔧 [MLX LOAD] Model enum case: \(model.displayName)")
            logger.info("🔧 [MLX LOAD] Model display name: \(model.displayName)")
            logger.info("🔧 [MLX LOAD] Model raw value (HF path): '\(model.rawValue)'")
            logger.info("🔧 [MLX LOAD] Model memory requirement: \(model.memoryRequirement)")
            logger.info("🔧 [MLX LOAD] Model target platform: \(model.targetPlatform)")
            logger.info("🔧 [MLX LOAD] Model is VLM: \(model.isVLM)")
            
            // Progress update
            await MainActor.run { loadingProgress = 0.1 }
            logger.info("🔧 [MLX LOAD] Progress set to 0.1, about to call loadModelContainer")
            
            // Log exactly what we're passing to MLX
            let modelIdToLoad = model.rawValue
            logger.info("🔧 [MLX LOAD] Exact string being passed to loadModelContainer: '\(modelIdToLoad)'")
            logger.info("🔧 [MLX LOAD] String length: \(modelIdToLoad.count) characters")
            logger.info("🔧 [MLX LOAD] String bytes: \(Array(modelIdToLoad.utf8))")
            
            // Use the correct MLX Swift API - VLMModelFactory for VLMs, LLMModelFactory for LLMs
            let config = ModelConfiguration(id: modelIdToLoad)
            let container: MLXLMCommon.ModelContainer
            
            if model.isVLM {
                logger.info("🔧 [MLX LOAD] Loading VLM model with VLMModelFactory.shared.loadContainer...")
                container = try await VLMModelFactory.shared.loadContainer(
                    configuration: config
                ) { [weak self] (progress: Foundation.Progress) in
                    Task { @MainActor in
                        self?.loadingProgress = 0.1 + (progress.fractionCompleted * 0.8)
                        self?.logger.info("🔧 [MLX LOAD] VLM download progress: \(progress.fractionCompleted * 100)%")
                    }
                }
            } else {
                logger.info("🔧 [MLX LOAD] Loading LLM model with LLMModelFactory.shared.loadContainer...")
                container = try await LLMModelFactory.shared.loadContainer(
                    configuration: config
                ) { [weak self] (progress: Foundation.Progress) in
                    Task { @MainActor in
                        self?.loadingProgress = 0.1 + (progress.fractionCompleted * 0.8)
                        self?.logger.info("🔧 [MLX LOAD] LLM download progress: \(progress.fractionCompleted * 100)%")
                    }
                }
            }
            logger.info("🔧 [MLX LOAD] ModelContainer loaded successfully!")
            
            await MainActor.run { loadingProgress = 0.9 }
            
            // Create ChatSession for simplified API
            let session = MLXLMCommon.ChatSession(container)
            
            // Store references
            self.modelContainer = container
            self.chatSession = session
            self.currentModelId = model.rawValue
            
            await MainActor.run {
                loadingProgress = 1.0
                isReady = true
                isLoading = false
            }
            
            logger.info("✅ MLX model loaded successfully: \(model.displayName)")
            
        } catch {
            logger.error("❌ [MLX ERROR] MLX model loading failed!")
            logger.error("❌ [MLX ERROR] Error type: \(type(of: error))")
            logger.error("❌ [MLX ERROR] Error description: \(error.localizedDescription)")
            logger.error("❌ [MLX ERROR] Full error: \(error)")
            
            // Check for Gemma3n audio tower errors and try text-only fallback
            if error.localizedDescription.contains("269 parameters not in model") ||
               error.localizedDescription.contains("audio_tower.conformer") ||
               error.localizedDescription.contains("audio_tower") {
                
                logger.info("🔄 [MLX FALLBACK] Detected audio tower error, attempting text-only fallback...")
                
                do {
                    // Try text-only variant by modifying the model ID
                    let textOnlyModelId = model.rawValue.replacingOccurrences(of: "it-", with: "text-")
                    logger.info("🔄 [MLX FALLBACK] Trying text-only model: \(textOnlyModelId)")
                    
                    let fallbackConfig = ModelConfiguration(id: textOnlyModelId)
                    let container: MLXLMCommon.ModelContainer
                    
                    if model.isVLM {
                        container = try await VLMModelFactory.shared.loadContainer(
                            configuration: fallbackConfig
                        ) { [weak self] (progress: Foundation.Progress) in
                            Task { @MainActor in
                                self?.loadingProgress = 0.1 + (progress.fractionCompleted * 0.8)
                                self?.logger.info("🔄 [MLX FALLBACK] VLM fallback download progress: \(progress.fractionCompleted * 100)%")
                            }
                        }
                    } else {
                        container = try await LLMModelFactory.shared.loadContainer(
                            configuration: fallbackConfig
                        ) { [weak self] (progress: Foundation.Progress) in
                            Task { @MainActor in
                                self?.loadingProgress = 0.1 + (progress.fractionCompleted * 0.8)
                                self?.logger.info("🔄 [MLX FALLBACK] LLM fallback download progress: \(progress.fractionCompleted * 100)%")
                            }
                        }
                    }
                    
                    // Store references for fallback model
                    self.modelContainer = container
                    self.chatSession = MLXLMCommon.ChatSession(container)
                    self.currentModelId = textOnlyModelId
                    
                    await MainActor.run {
                        loadingProgress = 1.0
                        isReady = true
                        isLoading = false
                    }
                    
                    logger.info("✅ [MLX FALLBACK] Text-only fallback loaded successfully")
                    return
                    
                } catch let fallbackError {
                    logger.error("❌ [MLX FALLBACK] Text-only fallback also failed: \(fallbackError.localizedDescription)")
                    // Fall through to original error handling
                }
            }
            
            // Log additional error details if available
            if let nsError = error as NSError? {
                logger.error("❌ [MLX ERROR] NSError domain: \(nsError.domain)")
                logger.error("❌ [MLX ERROR] NSError code: \(nsError.code)")
                logger.error("❌ [MLX ERROR] NSError userInfo: \(nsError.userInfo)")
            }
            
            // Check if it's a specific MLX error
            logger.error("❌ [MLX ERROR] Attempted to load model: \(model.rawValue)")
            logger.error("❌ [MLX ERROR] Model display name: \(model.displayName)")
            
            await MainActor.run {
                isLoading = false
                isReady = false
                errorMessage = "Failed to load \(model.displayName): \(error.localizedDescription)"
            }
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
        
        logger.info("🔧 [MLX GEN] Generating response for prompt: \(prompt.prefix(50))...")
        
        do {
            // Use the simplified ChatSession API
            let response = try await session.respond(to: prompt)
            
            logger.info("✅ [MLX GEN] Response generated successfully")
            return response
            
        } catch {
            logger.error("❌ [MLX GEN] Response generation failed: \(error.localizedDescription)")
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
                    
                    guard isReady else {
                        continuation.finish(throwing: WorkingMLXError.modelNotReady("Model is not ready"))
                        return
                    }
                    
                    // Use ChatSession streaming API
                    for try await chunk in session.streamResponse(to: prompt) {
                        continuation.yield(chunk)
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
        logger.info("🔧 [MLX UNLOAD] Unloading MLX model")
        
        modelContainer = nil
        chatSession = nil
        currentModelId = nil
        
        await MainActor.run {
            isReady = false
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("✅ [MLX UNLOAD] MLX model unloaded")
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

// MARK: - AIModelProvider Protocol Implementation

extension WorkingMLXProvider {
    
    public var identifier: String {
        return "mlx-provider"
    }
    
    public var displayName: String {
        return "MLX On-Device AI"
    }
    
    public var isAvailable: Bool {
        return isMLXSupported // Provider is available if MLX hardware is supported
    }
    
    public var supportsPersonalData: Bool {
        return true // MLX processes everything on-device
    }
    
    public var isOnDevice: Bool {
        return true // MLX is always on-device
    }
    
    public var estimatedResponseTime: TimeInterval {
        return 1.0 // On-device inference is fast
    }
    
    public var maxContextLength: Int {
        return 8192 // Conservative estimate for MLX models
    }
    
    public func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse {
        let startTime = Date()
        
        // Generate the actual response using our existing method
        let responseContent = try await generateResponse(to: prompt)
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        return AIModelResponse(
            content: responseContent,
            confidence: 1.0,
            processingTime: processingTime,
            modelUsed: currentModelId ?? "unknown-mlx-model",
            tokensUsed: nil, // MLX doesn't expose token counts easily
            isOnDevice: true,
            containsPersonalData: context.containsPersonalData
        )
    }
    
    public func prepare() async throws {
        // MLX provider doesn't need special preparation beyond model loading
        // The model loading is handled separately via loadModel()
        logger.info("MLX Provider prepared successfully")
    }
    
    public func cleanup() async {
        await unloadModel()
        logger.info("MLX Provider cleaned up")
    }
    
    public func canHandle(contextSize: Int) -> Bool {
        return contextSize <= maxContextLength
    }
}