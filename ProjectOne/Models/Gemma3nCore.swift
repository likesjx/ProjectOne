import Foundation
import SwiftUI
import Combine
import os.log

// Import unified provider system
// Note: These files should be in the same target, so no module import needed

/// Gemma3nCore - Integration layer for MLX Gemma3n with Memory Agent
class Gemma3nCore: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "Gemma3nCore")
    private var mlxProvider: UnifiedMLXProvider?
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    public init() {
        logger.info("Initializing Gemma3nCore")
    }
    
    public func setup() {
        logger.debug("Setting up MLX Gemma3n provider")
        mlxProvider = UnifiedMLXProvider()
        
        Task {
            await prepareProvider()
        }
    }
    
    @MainActor
    private func prepareProvider() async {
        guard let provider = mlxProvider else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await provider.prepare(modelTypes: [.multimodal])
            // Load the specific Gemma3n model
            try await provider.loadModel(name: "mlx-community/gemma-3n-E2B-it-lm-bf16", type: .multimodal)
            isReady = true
            logger.info("Gemma3nCore is ready with MLX provider")
        } catch {
            errorMessage = error.localizedDescription
            isReady = false
            logger.error("Failed to prepare Gemma3nCore: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Public Interface
    
    /// Process text using MLX Gemma3n model
    func processText(_ text: String) async -> String {
        guard let provider = mlxProvider, provider.isAvailable else {
            logger.warning("MLX provider not available, returning original text")
            return text
        }
        
        do {
            let input = UnifiedModelInput(text: text)
            let response = try await provider.process(input: input, modelType: .multimodal)
            return response.text ?? "No response generated"
        } catch {
            logger.error("Text processing failed: \(error.localizedDescription)")
            return "Error processing text: \(error.localizedDescription)"
        }
    }
    
    /// Check if Gemma3n is available and ready
    func isAvailable() -> Bool {
        return isReady && mlxProvider?.isAvailable == true
    }
    
    /// Get the MLX provider for direct access
    func getMLXProvider() -> UnifiedMLXProvider? {
        return mlxProvider
    }
    
    /// Reload the model (useful for debugging or model updates)
    func reloadModel() async {
        logger.info("Reloading Gemma3n model")
        
        await mlxProvider?.cleanup(modelTypes: [.multimodal])
        await prepareProvider()
    }
    
    /// Get current status information
    func getStatus() -> Gemma3nStatus {
        return Gemma3nStatus(
            isReady: isReady,
            isLoading: isLoading,
            errorMessage: errorMessage,
            providerAvailable: mlxProvider?.isAvailable ?? false,
            modelIdentifier: mlxProvider?.identifier ?? "none"
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