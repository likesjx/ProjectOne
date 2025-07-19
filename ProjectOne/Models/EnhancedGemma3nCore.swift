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

// Foundation Models framework for iOS 26.0+ Beta
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Enhanced Gemma3n core with dual AI providers for iOS 26.0+ target
@available(iOS 26.0, macOS 26.0, *)
class EnhancedGemma3nCore: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EnhancedGemma3nCore")
    
    // MARK: - AI Providers
    
    @StateObject private var mlxProvider = WorkingMLXProvider()
    @StateObject private var foundationProvider = RealFoundationModelsProvider()
    
    // MARK: - State
    
    @Published var isReady = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var activeProvider: AIProviderType = .automatic
    @Published var lastResponse: String?
    
    public enum AIProviderType: String, CaseIterable {
        case automatic = "automatic"
        case mlx = "mlx"
        case foundation = "foundation"
        
        var displayName: String {
            switch self {
            case .automatic: return "Automatic (Best Available)"
            case .mlx: return "MLX Swift (On-Device)"
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
        
        logger.info("Setting up dual AI providers...")
        
        // Setup both providers in parallel
        async let mlxSetup: () = setupMLXProvider()
        async let foundationSetup: () = setupFoundationProvider()
        
        await mlxSetup
        await foundationSetup
        
        await MainActor.run {
            isReady = mlxProvider.isReady || foundationProvider.isAvailable
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
    
    private func setupMLXProvider() async {
        guard mlxProvider.isMLXSupported else {
            logger.info("MLX not supported on this device")
            return
        }
        
        do {
            let recommendedModel = mlxProvider.getRecommendedModel()
            try await mlxProvider.loadModel(recommendedModel)
            logger.info("✅ MLX provider ready with \(recommendedModel.displayName)")
        } catch {
            logger.error("❌ MLX provider setup failed: \(error.localizedDescription)")
        }
    }
    
    private func setupFoundationProvider() async {
        // Foundation provider initializes automatically in iOS 26.0+
        // Just wait for it to complete its availability check
        var attempts = 0
        while self.foundationProvider.isLoading && attempts < 20 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            attempts += 1
        }
        
        if foundationProvider.isAvailable {
            logger.info("✅ Foundation Models provider ready")
        } else {
            logger.info("Foundation Models not available: \(self.foundationProvider.errorMessage ?? "Unknown error")")
        }
    }
    
    // MARK: - Text Processing
    
    /// Process text using the best available AI provider
    public func processText(_ text: String, forceProvider: AIProviderType? = nil) async -> String {
        let provider = forceProvider ?? selectBestProvider()
        
        logger.info("Processing text with \(provider.displayName)")
        
        do {
            let response: String
            
            switch provider {
            case .mlx:
                response = try await processWithMLX(text)
            case .foundation:
                response = try await processWithFoundation(text)
            case .automatic:
                // Try Foundation Models first (system-integrated), fall back to MLX
                if foundationProvider.isAvailable {
                    response = try await processWithFoundation(text)
                } else if mlxProvider.isReady {
                    response = try await processWithMLX(text)
                } else {
                    throw EnhancedGemmaError.noProvidersAvailable
                }
            }
            
            await MainActor.run {
                lastResponse = response
            }
            
            return response
            
        } catch {
            let errorResponse = "Error processing request: \(error.localizedDescription)"
            logger.error("Text processing failed: \(error.localizedDescription)")
            
            await MainActor.run {
                errorMessage = error.localizedDescription
                lastResponse = errorResponse
            }
            
            return errorResponse
        }
    }
    
    // MARK: - Private Processing Methods
    
    private func processWithMLX(_ text: String) async throws -> String {
        guard mlxProvider.isReady else {
            throw EnhancedGemmaError.mlxNotReady
        }
        
        return try await mlxProvider.generateResponse(to: text)
    }
    
    private func processWithFoundation(_ text: String) async throws -> String {
        guard foundationProvider.isAvailable else {
            throw EnhancedGemmaError.foundationNotAvailable
        }
        
        return try await foundationProvider.generateText(prompt: text, useCase: .contentGeneration)
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
    
    private func selectBestProvider() -> AIProviderType {
        // For iOS 26.0+, prefer Foundation Models for system integration
        if foundationProvider.isAvailable {
            return .foundation
        } else if mlxProvider.isReady {
            return .mlx
        } else {
            return .automatic // Will handle error in processing
        }
    }
    
    /// Get current provider status
    public func getProviderStatus() -> ProviderStatus {
        return ProviderStatus(
            mlxAvailable: mlxProvider.isReady,
            mlxModel: mlxProvider.getModelInfo()?.displayName,
            foundationAvailable: foundationProvider.isAvailable,
            foundationStatus: foundationProvider.modelStatus,
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
    public let mlxAvailable: Bool
    public let mlxModel: String?
    public let foundationAvailable: Bool
    public let foundationStatus: String
    public let activeProvider: String
    public let isReady: Bool
}

public enum EnhancedGemmaError: Error, LocalizedError {
    case noProvidersAvailable
    case mlxNotReady
    case foundationNotAvailable
    case processingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noProvidersAvailable:
            return "No AI providers are available"
        case .mlxNotReady:
            return "MLX provider is not ready"
        case .foundationNotAvailable:
            return "Foundation Models not available"
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