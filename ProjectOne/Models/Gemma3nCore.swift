import Foundation
import SwiftUI
import Combine
import os.log

// Import unified provider system
// Note: These files should be in the same target, so no module import needed

/// Gemma3nCore - Integration layer for MLX Gemma3n with Memory Agent
@MainActor
class Gemma3nCore: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "Gemma3nCore")
    private var mlxProvider: WorkingMLXProvider?
    private var currentModelId: String?
    private var actualLoadedModel: WorkingMLXProvider.MLXModel?
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var actualModelName: String = "No Model Loaded"
    
    public init() {
        logger.info("Initializing Gemma3nCore")
    }
    
    public func setup() {
        logger.debug("Setting up MLX Gemma3n provider")
        mlxProvider = WorkingMLXProvider()
        
        Task {
            await prepareProvider()
        }
    }
    
    @MainActor
    private func prepareProvider() async {
        guard let provider = mlxProvider else { 
            logger.error("🚨 [GEMMA3N] No MLX provider available!")
            return 
        }
        
        logger.info("🚀 [GEMMA3N] Starting Gemma3nCore preparation")
        logger.info("🚀 [GEMMA3N] Provider type: \(type(of: provider))")
        logger.info("🚀 [GEMMA3N] Provider is available: \(provider.isAvailable)")
        
        isLoading = true
        errorMessage = nil
        
        // Try Gemma-3n models first, then fallback to Qwen if they fail
        let modelFallbackChain: [WorkingMLXProvider.MLXModel] = [
            .gemma3n_E2B_4bit,  // Primary: iOS optimized VLM
            .gemma3n_E4B_5bit,  // Secondary: Mac optimized VLM
            .qwen3_4B,          // Fallback: Reliable LLM
            .gemma2_2B          // Final fallback: Lightweight LLM
        ]
        
        var lastError: Error?
        var modelLoaded = false
        
        for (index, targetModel) in modelFallbackChain.enumerated() {
            logger.info("🚀 [GEMMA3N] Attempt \(index + 1)/\(modelFallbackChain.count): \(targetModel.displayName)")
            logger.info("🚀 [GEMMA3N] Target model raw value: \(targetModel.rawValue)")
            
            do {
                logger.info("🚀 [GEMMA3N] About to call provider.loadModel...")
                try await provider.loadModel(targetModel.rawValue)
                
                logger.info("🚀 [GEMMA3N] Model loaded successfully!")
                currentModelId = targetModel.rawValue
                actualLoadedModel = targetModel
                actualModelName = targetModel.displayName
                isReady = true
                modelLoaded = true
                
                // Log the actual model loaded vs what the class is named
                if targetModel.rawValue.contains("qwen") {
                    logger.warning("⚠️ [GEMMA3N] IMPORTANT: Gemma3nCore is actually running \(targetModel.displayName) (Qwen), not Gemma-3n!")
                } else {
                    logger.info("✅ [GEMMA3N] Gemma3nCore is ready with actual Gemma model: \(targetModel.displayName)")
                }
                break
                
            } catch {
                logger.warning("⚠️ [GEMMA3N] Failed to load \(targetModel.displayName): \(error.localizedDescription)")
                lastError = error
                
                // Continue to next model in fallback chain
                if index < modelFallbackChain.count - 1 {
                    logger.info("🔄 [GEMMA3N] Trying next model in fallback chain...")
                }
            }
        }
        
        if !modelLoaded {
            logger.error("❌ [GEMMA3N] All models in fallback chain failed!")
            if let error = lastError {
                logger.error("❌ [GEMMA3N] Final error: \(error.localizedDescription)")
                errorMessage = "All models failed. Last error: \(error.localizedDescription)"
            } else {
                errorMessage = "All models in fallback chain failed to load"
            }
            isReady = false
        }
        
        logger.info("🚀 [GEMMA3N] Preparation complete. isReady: \(self.isReady)")
        isLoading = false
    }
    
    // MARK: - Public Interface
    
    /// Process text using MLX Gemma3n model
    func processText(_ text: String) async -> String {
        guard let provider = mlxProvider, isReady else {
            logger.warning("MLX provider not available, returning original text")
            return text
        }
        
        do {
            let response = try await provider.generate(prompt: text)
            return response
        } catch {
            logger.error("Text processing failed: \(error.localizedDescription)")
            return "Error processing text: \(error.localizedDescription)"
        }
    }
    
    /// Check if Gemma3n is available and ready
    func isAvailable() -> Bool {
        return isReady && mlxProvider?.isReady == true
    }
    
    /// Get the MLX provider for direct access
    func getMLXProvider() -> WorkingMLXProvider? {
        return mlxProvider
    }
    
    /// Get the actual model that was loaded (might be different from "Gemma3n" name)
    func getActualLoadedModel() -> WorkingMLXProvider.MLXModel? {
        return actualLoadedModel
    }
    
    /// Get the actual model name that was loaded
    func getActualModelName() -> String {
        return actualModelName
    }
    
    /// Get detailed model information including discrepancy warning
    func getModelStatus() -> String {
        guard let model = actualLoadedModel else {
            return "No model loaded"
        }
        
        if model.rawValue.contains("qwen") {
            return "⚠️ Running \(model.displayName) (NOT Gemma-3n)"
        } else {
            return "✅ Running \(model.displayName)"
        }
    }
    
    /// Check if we're actually running a Gemma model vs a fallback
    func isActuallyGemma() -> Bool {
        guard let model = actualLoadedModel else { return false }
        return model.rawValue.contains("gemma") && !model.rawValue.contains("qwen")
    }
    
    /// Reload the model (useful for debugging or model updates)
    func reloadModel() async {
        logger.info("Reloading Gemma3n model")
        
        await mlxProvider?.cleanup()
        await prepareProvider()
    }
    
    /// Get current status information
    func getStatus() -> Gemma3nStatus {
        return Gemma3nStatus(
            isReady: isReady,
            isLoading: isLoading,
            errorMessage: errorMessage,
            providerAvailable: mlxProvider?.isReady ?? false,
            modelIdentifier: currentModelId ?? "none"
        )
    }
}

// MARK: - Supporting Types

struct Gemma3nStatus {
    let isReady: Bool
    let isLoading: Bool
    let errorMessage: String?
    let providerAvailable: Bool
    let modelIdentifier: String
}