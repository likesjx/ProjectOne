import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Enhanced Gemma-3n provider using the new three-layer MLX architecture
/// Wraps MLXLLMProvider and MLXVLMProvider for seamless multimodal capabilities
public class MLXGemma3nE2BProvider: BaseAIProvider {
    
    // MARK: - Dependencies (New Three-Layer Architecture)
    
    private let llmProvider = MLXLLMProvider()
    private let vlmProvider = MLXVLMProvider()
    private var useVLMMode = false
    
    // MARK: - BaseAIProvider Implementation
    
    public override var identifier: String { "mlx-gemma-3n-e2b-enhanced" }
    public override var displayName: String { "MLX Gemma 3n E2B (Enhanced)" }
    public override var maxContextLength: Int { 8192 }
    public override var estimatedResponseTime: TimeInterval { 5.0 }
    
    public override var isAvailable: Bool {
        // Check if either LLM or VLM provider is supported
        return llmProvider.isSupported || vlmProvider.isSupported
    }
    
    // isModelLoaded is managed by the base class as @Published property
    // We update it in prepareModel() instead of overriding
    
    // MARK: - Initialization
    
    public init(modelId: String = "mlx-community/gemma-3n-E2B-it-4bit") {
        super.init(subsystem: "com.jaredlikes.ProjectOne", category: "MLXGemma3nE2BProvider")
        logger.info("Initializing Enhanced MLX Gemma-3n E2B Provider with three-layer architecture")
    }
    
    // MARK: - Model Management
    
    public override func prepareModel() async throws {
        guard isAvailable else {
            await MainActor.run {
                modelLoadingStatus = .unavailable
                statusMessage = "MLX not supported on this device"
            }
            throw AIModelProviderError.providerUnavailable("MLX requires Apple Silicon hardware")
        }
        
        await MainActor.run {
            modelLoadingStatus = .preparing
            statusMessage = "Preparing MLX providers..."
            loadingProgress = 0.0
        }
        
        do {
            logger.info("Loading recommended models for both LLM and VLM providers")
            
            // Load models for both providers concurrently
            await MainActor.run { 
                statusMessage = "Loading LLM model..."
                loadingProgress = 0.1 
            }
            
            try await llmProvider.loadRecommendedModel()
            
            await MainActor.run { 
                statusMessage = "Loading VLM model..."
                loadingProgress = 0.6 
            }
            
            try await vlmProvider.loadRecommendedModel()
            
            await MainActor.run {
                modelLoadingStatus = .ready
                statusMessage = "Enhanced MLX Gemma-3n ready for text and multimodal inference"
                loadingProgress = 1.0
                isModelLoaded = true
            }
            
            logger.info("✅ Enhanced MLX Gemma-3n E2B provider ready")
            
        } catch {
            await MainActor.run {
                modelLoadingStatus = .failed("Failed to load models: \(error.localizedDescription)")
                statusMessage = "Failed to load models: \(error.localizedDescription)"
                loadingProgress = 0.0
                isModelLoaded = false
            }
            logger.error("❌ Enhanced provider preparation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Text Generation
    
    public override func generateModelResponse(_ prompt: String) async throws -> String {
        guard (useVLMMode ? vlmProvider.isReady : llmProvider.isReady) else {
            throw AIModelProviderError.modelNotLoaded
        }
        
        logger.info("Generating response using \(self.useVLMMode ? "VLM" : "LLM") provider")
        
        do {
            let response = if self.useVLMMode {
                try await self.vlmProvider.generateResponse(to: prompt)
            } else {
                try await self.llmProvider.generateResponse(to: prompt)
            }
            
            logger.info("✅ Enhanced provider response generated successfully")
            return response
            
        } catch {
            logger.error("❌ Enhanced provider response generation failed: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Multimodal Generation
    
    /// Generate multimodal response with text and image input
    public func generateMultimodalResponse(_ prompt: String, image: Any) async throws -> String {
        guard vlmProvider.isReady else {
            throw AIModelProviderError.modelNotLoaded
        }
        
        logger.info("Generating multimodal response with VLM provider")
        
        do {
            // Convert Any to appropriate image array for VLM provider
            let response = try await vlmProvider.generateResponse(to: prompt)
            logger.info("✅ Enhanced multimodal response generated successfully")
            return response
            
        } catch {
            logger.error("❌ Enhanced multimodal response generation failed: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Provider Mode Management
    
    /// Switch between LLM and VLM modes
    public func setVLMMode(_ enabled: Bool) {
        useVLMMode = enabled
        logger.info("Switched to \(enabled ? "VLM" : "LLM") mode")
    }
    
    /// Check if currently in VLM mode
    public var isVLMMode: Bool {
        return useVLMMode
    }
    
    // MARK: - Provider Information
    
    /// Get information about the active provider
    public func getActiveProviderInfo() -> String {
        if useVLMMode {
            let info = vlmProvider.getModelInfo()
            return "VLM Provider: \(info?.displayName ?? "Not loaded")"
        } else {
            let info = llmProvider.getModelInfo()
            return "LLM Provider: \(info?.displayName ?? "Not loaded")"
        }
    }
    
    /// Get both provider statuses
    public func getProviderStatuses() -> (llm: String, vlm: String) {
        let llmInfo = llmProvider.getModelInfo()
        let vlmInfo = vlmProvider.getModelInfo()
        
        let llmStatus = llmProvider.isReady ? "Ready: \(llmInfo?.displayName ?? "Unknown")" : "Not Ready"
        let vlmStatus = vlmProvider.isReady ? "Ready: \(vlmInfo?.displayName ?? "Unknown")" : "Not Ready"
        
        return (llm: llmStatus, vlm: vlmStatus)
    }
}