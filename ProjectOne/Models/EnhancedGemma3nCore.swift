//
//  EnhancedGemma3nCore.swift
//  ProjectOne
//
//  Enhanced core with BOTH MLX Swift AND Foundation Models for iOS 26.0+
//

import Foundation
import SwiftUI
import Combine
import os.log

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// Foundation Models framework for iOS 26.0+ Beta
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Enhanced Gemma3n core with dual AI providers for iOS 26.0+ target
@available(iOS 26.0, macOS 26.0, *)
class EnhancedGemma3nCore: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EnhancedGemma3nCore")
    
    // MARK: - AI Providers (Three-Layer Architecture)
    
    @StateObject private var mlxLLMProvider = MLXLLMProvider()
    @StateObject private var mlxVLMProvider = MLXVLMProvider()
    @StateObject private var foundationProvider = AppleFoundationModelsProvider()
    
    // MARK: - State
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activeProvider: AIProviderType = .automatic
    @Published var lastResponse: String?
    
    public enum AIProviderType: String, CaseIterable {
        case automatic = "automatic"
        case mlxLLM = "mlx_llm"
        case mlxVLM = "mlx_vlm"
        case foundation = "foundation"
        
        var displayName: String {
            switch self {
            case .automatic: return "Automatic (Best Available)"
            case .mlxLLM: return "MLX LLM (Text-Only)"
            case .mlxVLM: return "MLX VLM (Multimodal)"
            case .foundation: return "Foundation Models (System)"
            }
        }
    }
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing Enhanced Gemma3n Core for iOS 26.0+")
    }
    
    public func setup() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        logger.info("Setting up MLX three-layer and Foundation providers...")
        
        // Setup all providers in parallel
        async let mlxLLMSetup: () = setupMLXLLMProvider()
        async let mlxVLMSetup: () = setupMLXVLMProvider()
        async let foundationSetup: () = setupFoundationProvider()
        
        await mlxLLMSetup
        await mlxVLMSetup
        await foundationSetup
        
        await MainActor.run {
            isReady = mlxLLMProvider.isReady || mlxVLMProvider.isReady || foundationProvider.isAvailable
            isLoading = false
            
            if isReady {
                logger.info("✅ Enhanced Gemma3n Core ready with available providers")
            } else {
                errorMessage = "No AI providers available"
                logger.error("❌ No AI providers available")
            }
        }
    }
    
    // MARK: - Provider Setup
    
    private func setupMLXLLMProvider() async {
        guard mlxLLMProvider.isSupported else {
            logger.info("MLX LLM not supported on this device")
            return
        }
        
        do {
            try await mlxLLMProvider.loadRecommendedModel()
            logger.info("✅ MLX LLM provider ready")
        } catch {
            logger.error("❌ MLX LLM provider setup failed: \(error.localizedDescription)")
        }
    }
    
    private func setupMLXVLMProvider() async {
        guard mlxVLMProvider.isSupported else {
            logger.info("MLX VLM not supported on this device")
            return
        }
        
        do {
            try await mlxVLMProvider.loadRecommendedModel()
            logger.info("✅ MLX VLM provider ready")
        } catch {
            logger.error("❌ MLX VLM provider setup failed: \(error.localizedDescription)")
        }
    }
    
    private func setupFoundationProvider() async {
        // Foundation provider initializes automatically in iOS 26.0+
        // Just wait for it to complete its availability check
        var attempts = 0
        while self.foundationProvider.modelLoadingStatus == .preparing && attempts < 20 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        if self.foundationProvider.isAvailable {
            logger.info("✅ Foundation Models provider ready")
        } else {
            logger.info("Foundation Models not available: \(self.foundationProvider.statusMessage ?? "Unknown error")")
        }
    }
    
    // MARK: - Text Processing
    
    /// Process text using the best available AI provider
    public func processText(_ text: String, forceProvider: AIProviderType? = nil) async -> String {
        return await processText(text, images: [], forceProvider: forceProvider)
    }
    
    /// Process text with optional images using smart routing
    public func processText(_ text: String, images: [PlatformImage] = [], forceProvider: AIProviderType? = nil) async -> String {
        let provider = forceProvider ?? selectBestProvider(for: text, images: images)
        
        logger.info("Processing \(images.isEmpty ? "text" : "multimodal") request with \(provider.displayName)")
        
        do {
            let response: String
            
            switch provider {
            case .mlxLLM:
                response = try await processWithMLXLLM(text)
            case .mlxVLM:
                response = try await processWithMLXVLM(text, images: images)
            case .foundation:
                response = try await processWithFoundation(text)
            case .automatic:
                response = try await processWithAutomatic(text, images: images)
            }
            
            await MainActor.run {
                lastResponse = response
            }
            
            return response
            
        } catch {
            let errorResponse = "Error processing request: \(error.localizedDescription)"
            logger.error("Processing failed: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = error.localizedDescription
                lastResponse = errorResponse
            }
            
            return errorResponse
        }
    }
    
    // MARK: - Private Processing Methods
    
    private func processWithMLXLLM(_ text: String) async throws -> String {
        guard mlxLLMProvider.isReady else {
            throw EnhancedGemmaError.mlxNotReady
        }
        
        return try await mlxLLMProvider.generateResponse(to: text)
    }
    
    private func processWithMLXVLM(_ text: String, images: [PlatformImage] = []) async throws -> String {
        guard mlxVLMProvider.isReady else {
            throw EnhancedGemmaError.mlxNotReady
        }
        
        return try await mlxVLMProvider.generateResponse(to: text, images: images)
    }
    
    private func processWithAutomatic(_ text: String, images: [PlatformImage] = []) async throws -> String {
        // Smart routing based on request type
        if !images.isEmpty {
            // Multimodal request - requires VLM provider
            if mlxVLMProvider.isReady {
                return try await processWithMLXVLM(text, images: images)
            } else {
                throw EnhancedGemmaError.noMultimodalProvider
            }
        } else {
            // Text-only request - try Foundation Models first, then MLX LLM
            if foundationProvider.isAvailable {
                return try await processWithFoundation(text)
            } else if mlxLLMProvider.isReady {
                return try await processWithMLXLLM(text)
            } else {
                throw EnhancedGemmaError.noProvidersAvailable
            }
        }
    }
    
    private func processWithFoundation(_ text: String) async throws -> String {
        guard foundationProvider.isAvailable else {
            throw EnhancedGemmaError.foundationNotAvailable
        }
        
        return try await foundationProvider.generateModelResponse(text)
    }
    
    // MARK: - Advanced Features (iOS 26.0+ only)
    
    /// Generate structured content using Foundation Models @Generable
    public func generateStructured<T: Generable>(prompt: String, type: T.Type) async throws -> T {
        guard foundationProvider.isAvailable else {
            throw EnhancedGemmaError.foundationNotAvailable
        }
        
        return try await foundationProvider.generateWithGuidance(prompt: prompt, type: type)
    }
    
    /// Extract entities using guided generation
    public func extractEntities(from text: String) async throws -> ExtractedEntities {
        let prompt = "Extract all people, places, organizations, and key concepts from this text: \(text)"
        return try await generateStructured(prompt: prompt, type: ExtractedEntities.self)
    }
    
    /// Summarize content using guided generation
    public func summarizeContent(_ text: String) async throws -> SummarizedContent {
        let prompt = "Provide a comprehensive summary with title, key points, and overview for: \(text)"
        return try await generateStructured(prompt: prompt, type: SummarizedContent.self)
    }
    
    // MARK: - Provider Management
    
    private func selectBestProvider(for text: String, images: [PlatformImage] = []) -> AIProviderType {
        // Smart routing based on request type
        if !images.isEmpty {
            // Multimodal request - requires VLM provider
            if mlxVLMProvider.isReady {
                return .mlxVLM
            } else {
                return .automatic // Will handle error in processing
            }
        } else {
            // Text-only request - prefer Foundation Models for system integration
            if foundationProvider.isAvailable {
                return .foundation
            } else if mlxLLMProvider.isReady {
                return .mlxLLM
            } else {
                return .automatic // Will handle error in processing
            }
        }
    }
    
    /// Get current provider status
    public func getProviderStatus() -> ProviderStatus {
        return ProviderStatus(
            mlxLLMAvailable: mlxLLMProvider.isReady,
            mlxLLMModel: mlxLLMProvider.getModelInfo()?.displayName,
            mlxVLMAvailable: mlxVLMProvider.isReady,
            mlxVLMModel: mlxVLMProvider.getModelInfo()?.displayName,
            foundationAvailable: foundationProvider.isAvailable,
            foundationStatus: foundationProvider.statusMessage ?? "Unknown",
            activeProvider: activeProvider.displayName,
            isReady: isReady
        )
    }
    
    /// Manually switch provider
    public func setActiveProvider(_ provider: AIProviderType) {
        activeProvider = provider
        logger.info("Switched to \(provider.displayName)")
    }
    
    // MARK: - Legacy Compatibility
    
    /// Check if any provider is available (legacy compatibility)
    func isAvailable() -> Bool {
        return isReady
    }
    
    /// Reload providers
    func reloadModel() async {
        await setup()
    }
}

// MARK: - Supporting Types

public struct ProviderStatus {
    public let mlxLLMAvailable: Bool
    public let mlxLLMModel: String?
    public let mlxVLMAvailable: Bool
    public let mlxVLMModel: String?
    public let foundationAvailable: Bool
    public let foundationStatus: String
    public let activeProvider: String
    public let isReady: Bool
    
    public var hasMultimodalSupport: Bool {
        return mlxVLMAvailable
    }
    
    public var hasTextSupport: Bool {
        return mlxLLMAvailable || foundationAvailable
    }
}

public enum EnhancedGemmaError: Error, LocalizedError {
    case noProvidersAvailable
    case mlxNotReady
    case foundationNotAvailable
    case noMultimodalProvider
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noProvidersAvailable:
            return "No AI providers are available"
        case .mlxNotReady:
            return "MLX provider is not ready"
        case .foundationNotAvailable:
            return "Foundation Models not available"
        case .noMultimodalProvider:
            return "No multimodal provider available for image processing"
        case .processingFailed(let reason):
            return "Processing failed: \(reason)"
        }
    }
}

// MARK: - @Generable Protocol and Types Support

#if canImport(FoundationModels)
// These would be the real protocol definitions in iOS 26.0+ Foundation Models
// Using types from RealFoundationModelsProvider
#else
// Local fallback protocol when Foundation Models not available
public protocol Generable {}
#endif

// Define the structured content types that conform to the real Generable protocol
#if canImport(FoundationModels)
@Generable
public struct SummarizedContent {
    public let title: String
    public let keyPoints: [String]
    public let summary: String
}

@Generable
public struct ExtractedEntities {
    public let people: [String]
    public let places: [String]
    public let organizations: [String]
    public let concepts: [String]
}
#else
// Local fallback types when Foundation Models not available
public struct SummarizedContent: Generable {
    public let title: String
    public let keyPoints: [String]
    public let summary: String
}

public struct ExtractedEntities: Generable {
    public let people: [String]
    public let places: [String]
    public let organizations: [String]
    public let concepts: [String]
}
#endif