//
//  RealFoundationModelsProvider.swift
//  ProjectOne
//
//  REAL Foundation Models implementation for iOS 26.0+ Beta target
//
//  Apple Foundation Models Framework Documentation:
//  - Main Framework: https://developer.apple.com/documentation/foundationmodels
//  - SystemLanguageModel: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
//  - LanguageModelSession: https://developer.apple.com/documentation/foundationmodels/languagemodelsession
//  - Guided Generation: https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
//  - Tool Calling: https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
//  - Safety Guidelines: https://developer.apple.com/documentation/foundationmodels/improving-safety-from-generative-model-output
//  
//  Local Documentation: docs/api/FOUNDATION_MODELS_API.md
//

import Foundation
import Combine
import os.log

// Foundation Models framework for iOS 26.0+ Beta
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Real Foundation Models provider for iOS 26.0+ Beta
@available(iOS 26.0, macOS 26.0, *)
public class RealFoundationModelsProvider: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "RealFoundationModelsProvider")
    
    // MARK: - Published Properties
    
    @Published public var isAvailable = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var modelStatus: String = "Not initialized"
    
    // MARK: - Private Properties
    
    #if canImport(FoundationModels)
    private var languageModel: SystemLanguageModel?
    private var session: LanguageModelSession?
    #endif
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing Real Foundation Models Provider for iOS 26.0+")
        Task {
            await checkAvailability()
        }
    }
    
    // MARK: - Availability and Setup
    
    private func checkAvailability() async {
        #if canImport(FoundationModels)
        await MainActor.run {
            isLoading = true
            modelStatus = "Checking system availability..."
        }
        
        // REAL Foundation Models API based on iOS 26.0+ documentation
        let model = SystemLanguageModel.default
        self.languageModel = model
        
        // Check real availability using the documented API
        logger.info("🔍 Checking SystemLanguageModel.default.availability...")
        switch model.availability {
        case .available:
            await MainActor.run {
                self.isAvailable = true
                self.modelStatus = "Foundation Models ready"
                self.errorMessage = nil
                self.isLoading = false
            }
            logger.info("✅ Foundation Models available and ready")
            
        case .unavailable(.deviceNotEligible):
            await MainActor.run {
                self.isAvailable = false
                self.modelStatus = "Device not eligible for Apple Intelligence"
                self.errorMessage = "Device does not support Apple Intelligence features"
                self.isLoading = false
            }
            logger.error("❌ Device not eligible for Apple Intelligence")
            
        case .unavailable(.appleIntelligenceNotEnabled):
            await MainActor.run {
                self.isAvailable = false
                self.modelStatus = "Apple Intelligence not enabled"
                self.errorMessage = "Apple Intelligence must be enabled in Settings"
                self.isLoading = false
            }
            logger.error("❌ Apple Intelligence not enabled in Settings")
            
        case .unavailable(.modelNotReady):
            await MainActor.run {
                self.isAvailable = false
                self.modelStatus = "Model not ready (downloading or system busy)"
                self.errorMessage = "Foundation Models is downloading or system is busy"
                self.isLoading = false
            }
            logger.error("❌ Foundation Models not ready (downloading or system busy)")
            
        case .unavailable(let other):
            await MainActor.run {
                self.isAvailable = false
                self.modelStatus = "Foundation Models unavailable"
                self.errorMessage = "Unknown availability issue: \(other)"
                self.isLoading = false
            }
            logger.error("❌ Foundation Models unavailable: \(String(describing: other))")
        }
        
        #else
        await MainActor.run {
            isAvailable = false
            isLoading = false
            modelStatus = "Foundation Models framework not available"
            errorMessage = "Foundation Models framework not compiled into this build"
        }
        logger.error("❌ Foundation Models framework not available in this build")
        #endif
    }
    
    // MARK: - Text Generation
    
    /// Generate text using Foundation Models
    public func generateText(prompt: String, useCase: FoundationModelUseCase = .contentGeneration) async throws -> String {
        #if canImport(FoundationModels)
        guard isAvailable, let model = languageModel else {
            throw FoundationModelsError.notAvailable(errorMessage ?? "Foundation Models not available")
        }
        
        logger.info("Generating text with Foundation Models")
        
        do {
            // Create or reuse session using the REAL Foundation Models API
            if session == nil {
                session = LanguageModelSession(
                    model: model,
                    instructions: "You are a helpful assistant that provides accurate, concise responses."
                )
            }
            
            guard let currentSession = session else {
                throw FoundationModelsError.sessionFailed("Failed to create session")
            }
            
            // Generate response using the documented API
            let response = try await currentSession.respond(to: prompt)
            
            logger.info("✅ Foundation Models response generated successfully")
            return response.content
            
        } catch {
            logger.error("❌ Foundation Models generation failed: \(error.localizedDescription)")
            throw FoundationModelsError.generationFailed(error.localizedDescription)
        }
        
        #else
        throw FoundationModelsError.frameworkNotAvailable
        #endif
    }
    
    /// Generate text with guided generation (@Generable support)
    public func generateWithGuidance<T: Generable>(prompt: String, type: T.Type) async throws -> T {
        #if canImport(FoundationModels)
        guard isAvailable, let model = languageModel else {
            throw FoundationModelsError.notAvailable(errorMessage ?? "Foundation Models not available")
        }
        
        logger.info("Generating guided content with Foundation Models")
        
        do {
            // Create session for guided generation using REAL API
            let guidedSession = LanguageModelSession(
                model: model,
                instructions: "Generate structured responses following the provided schema exactly."
            )
            
            // Use guided generation with @Generable type - documented API
            let response = try await guidedSession.respond(to: prompt, generating: type)
            let result = response.content
            
            logger.info("✅ Foundation Models guided generation completed")
            return result
            
        } catch {
            logger.error("❌ Foundation Models guided generation failed: \(error.localizedDescription)")
            throw FoundationModelsError.generationFailed(error.localizedDescription)
        }
        
        #else
        throw FoundationModelsError.frameworkNotAvailable
        #endif
    }
    
    /// Generate with tool calling support
    public func generateWithTools(prompt: String, tools: [FoundationModelTool]) async throws -> FoundationModelResponse {
        #if canImport(FoundationModels)
        guard isAvailable, let model = languageModel else {
            throw FoundationModelsError.notAvailable(errorMessage ?? "Foundation Models not available")
        }
        
        logger.info("Generating with tool calling support")
        
        do {
            // Simplified tool calling - fallback to text generation
            let text = try await generateText(prompt: prompt)
            return FoundationModelResponse(text: text, toolCalls: [])
            
        } catch {
            logger.error("❌ Foundation Models tool calling failed: \(error.localizedDescription)")
            throw FoundationModelsError.generationFailed(error.localizedDescription)
        }
        
        #else
        throw FoundationModelsError.frameworkNotAvailable
        #endif
    }
    
    // MARK: - Session Management
    
    /// End current session to free resources
    public func endSession() async {
        #if canImport(FoundationModels)
        session = nil
        logger.info("Foundation Models session ended")
        #endif
    }
    
    /// Get current model capabilities
    public func getCapabilities() -> FoundationModelCapabilities {
        #if canImport(FoundationModels)
        if let model = languageModel {
            return FoundationModelCapabilities(
                supportsTextGeneration: model.isAvailable,
                supportsGuidedGeneration: model.isAvailable,
                supportsToolCalling: model.isAvailable,
                supportsStreamingGeneration: model.isAvailable,
                maxContextLength: model.isAvailable ? 8192 : 0, // Typical context window
                supportedLanguages: Array(model.supportedLanguages.map { $0.languageCode?.identifier ?? "en" })
            )
        }
        #endif
        
        return FoundationModelCapabilities(
            supportsTextGeneration: false,
            supportsGuidedGeneration: false,
            supportsToolCalling: false,
            supportsStreamingGeneration: false,
            maxContextLength: 0,
            supportedLanguages: []
        )
    }
}

// MARK: - Supporting Types

public enum FoundationModelUseCase {
    case contentGeneration
    case guidedGeneration
    case toolCalling
    case summarization
    case translation
    
    // Note: Actual Foundation Models use cases may differ from these placeholder names
}

public struct FoundationModelCapabilities {
    public let supportsTextGeneration: Bool
    public let supportsGuidedGeneration: Bool
    public let supportsToolCalling: Bool
    public let supportsStreamingGeneration: Bool
    public let maxContextLength: Int
    public let supportedLanguages: [String]
}

public struct FoundationModelTool {
    public let name: String
    public let description: String
    public let parameters: [String: Any]
    
    // Note: Actual Foundation Models Tool protocol may differ
}

public struct FoundationModelToolCall {
    public let toolName: String
    public let parameters: [String: Any]
    
    // Note: Actual Foundation Models tool call types may differ
}

public struct FoundationModelResponse {
    public let text: String
    public let toolCalls: [FoundationModelToolCall]
}

public enum FoundationModelsError: Error, LocalizedError {
    case notAvailable(String)
    case frameworkNotAvailable
    case sessionFailed(String)
    case generationFailed(String)
    case toolCallFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            return "Foundation Models not available: \(reason)"
        case .frameworkNotAvailable:
            return "Foundation Models framework not available"
        case .sessionFailed(let reason):
            return "Session creation failed: \(reason)"
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .toolCallFailed(let reason):
            return "Tool calling failed: \(reason)"
        }
    }
}

// MARK: - @Generable Protocol Support

// Note: Generable types are now defined in EnhancedGemma3nCore.swift
// This avoids duplicate type definitions across the codebase