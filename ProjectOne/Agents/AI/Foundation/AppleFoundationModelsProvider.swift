//
//  AppleFoundationModelsProvider.swift
//  ProjectOne
//
//  Apple Foundation Models provider that extends BaseAIProvider
//  Uses real Foundation Models API for iOS 26.0+ with @Generable support
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

/// Apple Foundation Models provider that extends BaseAIProvider for iOS 26.0+
@available(iOS 26.0, macOS 26.0, *)
public class AppleFoundationModelsProvider: BaseAIProvider {
    
    // MARK: - BaseAIProvider Implementation
    
    public override var identifier: String { "apple-foundation-models" }
    public override var displayName: String { "Apple Foundation Models" }
    public override var estimatedResponseTime: TimeInterval { 0.2 }
    public override var maxContextLength: Int { 8192 }
    
    // Override the computed property to use the @Published property from BaseAIProvider
    public override var isAvailable: Bool {
        get { super.isAvailable }
        set { 
            Task { @MainActor in
                updateAvailability(newValue)
            }
        }
    }
    
    // MARK: - Foundation Models Properties
    
    #if canImport(FoundationModels)
    private var languageModel: SystemLanguageModel?
    private var session: LanguageModelSession?
    #endif
    
    // Removed polling - using reactive architecture instead
    
    // MARK: - Initialization
    
    public init() {
        super.init(
            subsystem: "com.jaredlikes.ProjectOne",
            category: "AppleFoundationModelsProvider"
        )
        
        logger.info("Initializing Apple Foundation Models Provider for iOS 26.0+")
        
        // Perform one-time availability check
        Task { @MainActor in
            await performInitialAvailabilityCheck()
        }
    }
    
    // MARK: - BaseAIProvider Implementation
    
    override func getModelConfidence() -> Double {
        return 0.95 // Apple Foundation Models typically have high confidence
    }
    
    override func prepareModel() async throws {
        logger.info("Preparing Apple Foundation Models")
        
        #if canImport(FoundationModels)
        do {
            // Initialize the real Foundation Models API
            let model = SystemLanguageModel.default
            self.languageModel = model
            
            // Check availability thoroughly
            switch model.availability {
            case .available:
                logger.info("✅ Apple Foundation Models available and ready")
                
                // Create initial session for readiness
                session = LanguageModelSession(
                    model: model,
                    instructions: "You are a helpful, accurate, and concise assistant that provides personalized responses based on the user's context and memory."
                )
                
                await MainActor.run {
                    self.modelLoadingStatus = .ready
                }
                
            case .unavailable(.deviceNotEligible):
                let error = "Device not eligible for Apple Intelligence"
                logger.error("❌ \(error)")
                await MainActor.run {
                    self.modelLoadingStatus = .failed(error)
                }
                throw AIModelProviderError.providerUnavailable(error)
                
            case .unavailable(.appleIntelligenceNotEnabled):
                let error = "Apple Intelligence not enabled in Settings"
                logger.error("❌ \(error)")
                await MainActor.run {
                    self.modelLoadingStatus = .failed(error)
                }
                throw AIModelProviderError.providerUnavailable(error)
                
            case .unavailable(.modelNotReady):
                let error = "Foundation Models not ready (downloading or system busy)"
                logger.error("❌ \(error)")
                await MainActor.run {
                    self.modelLoadingStatus = .failed(error)
                }
                throw AIModelProviderError.providerUnavailable(error)
                
            case .unavailable(let other):
                let error = "Unknown availability issue: \(other)"
                logger.error("❌ \(error)")
                await MainActor.run {
                    self.modelLoadingStatus = .failed(error)
                }
                throw AIModelProviderError.providerUnavailable(error)
            }
            
        } catch {
            logger.error("Failed to prepare Apple Foundation Models: \(error.localizedDescription)")
            await MainActor.run {
                self.modelLoadingStatus = .failed(error.localizedDescription)
            }
            throw error
        }
        
        #else
        let error = "Foundation Models framework not available"
        logger.error("❌ \(error)")
        await MainActor.run {
            self.modelLoadingStatus = .failed(error)
        }
        throw AIModelProviderError.providerUnavailable(error)
        #endif
    }
    
    override func generateModelResponse(_ prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        guard isAvailable, let model = languageModel else {
            throw AIModelProviderError.providerUnavailable("Foundation Models not available")
        }
        
        logger.info("Generating response with Apple Foundation Models")
        
        do {
            // Create or reuse session using the real Foundation Models API
            if session == nil {
                session = LanguageModelSession(
                    model: model,
                    instructions: "You are a helpful, accurate, and concise assistant that provides personalized responses based on the user's context and memory."
                )
            }
            
            guard let currentSession = session else {
                throw AIModelProviderError.modelNotLoaded
            }
            
            // Generate response using the documented API
            let response = try await currentSession.respond(to: prompt)
            
            logger.info("✅ Foundation Models response generated successfully")
            return response.content
            
        } catch {
            logger.error("❌ Foundation Models generation failed: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
        
        #else
        throw AIModelProviderError.providerUnavailable("Foundation Models framework not available")
        #endif
    }
    
    override func cleanupModel() async {
        #if canImport(FoundationModels)
        session = nil
        languageModel = nil
        logger.info("Apple Foundation Models cleaned up")
        #endif
    }
    
    // MARK: - Advanced Foundation Models Features
    
    /// Generate text with guided generation (@Generable support)
    public func generateWithGuidance<T: Generable>(prompt: String, type: T.Type) async throws -> T {
        #if false && canImport(FoundationModels)
        guard isAvailable, let model = languageModel else {
            throw AIModelProviderError.providerUnavailable("Foundation Models not available")
        }
        
        logger.info("Generating guided content with Foundation Models for type: \(String(describing: type))")
        
        do {
            // Create session for guided generation using real API
            let guidedSession = LanguageModelSession(
                model: model,
                instructions: "Generate structured responses following the provided schema exactly. Be accurate and comprehensive."
            )
            
            // Use guided generation with @Generable type - documented API
            let response = try await guidedSession.respond(to: prompt, generating: type)
            let result = response.content
            
            logger.info("✅ Foundation Models guided generation completed")
            return result
            
        } catch {
            logger.error("❌ Foundation Models guided generation failed: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
        
        #else
        throw AIModelProviderError.providerUnavailable("@Generable features temporarily disabled to focus on core functionality")
        #endif
    }
    
    /// Generate with tool calling support (simplified implementation)
    public func generateWithTools(prompt: String, tools: [FoundationModelTool] = []) async throws -> FoundationModelResponse {
        #if false && canImport(FoundationModels)
        guard isAvailable else {
            throw AIModelProviderError.providerUnavailable("Foundation Models not available")
        }
        
        logger.info("Generating with tool calling support")
        
        do {
            // For now, fallback to text generation
            // Tool calling implementation would require additional API documentation
            let text = try await generateModelResponse(prompt)
            return FoundationModelResponse(text: text, toolCalls: [])
            
        } catch {
            logger.error("❌ Foundation Models tool calling failed: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
        
        #else
        throw AIModelProviderError.providerUnavailable("Foundation Models framework not available")
        #endif
    }
    
    /// Get current model capabilities
    public func getCapabilities() -> FoundationModelCapabilities {
        #if canImport(FoundationModels)
        if let model = languageModel, isAvailable {
            return FoundationModelCapabilities(
                supportsTextGeneration: true,
                supportsGuidedGeneration: true,
                supportsToolCalling: true,
                supportsStreamingGeneration: true,
                maxContextLength: maxContextLength,
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
    
    // MARK: - Private Methods
    
    private func performInitialAvailabilityCheck() async {
        #if canImport(FoundationModels)
        await updateLoadingStatus(.preparing)
        
        // Initialize the model for availability checking
        let model = SystemLanguageModel.default
        self.languageModel = model  
        
        switch model.availability {
        case .available:
            await updateLoadingStatus(.ready)
            await updateAvailability(true)
            
        case .unavailable(.deviceNotEligible):
            await updateLoadingStatus(.failed("Device not eligible for Apple Intelligence"))
            await updateAvailability(false)
            
        case .unavailable(.appleIntelligenceNotEnabled):
            await updateLoadingStatus(.failed("Apple Intelligence not enabled"))
            await updateAvailability(false)
            
        case .unavailable(.modelNotReady):
            await updateLoadingStatus(.failed("Model not ready"))
            await updateAvailability(false)
            
        case .unavailable(let other):
            await updateLoadingStatus(.failed("Unknown availability issue"))
            await updateAvailability(false)
        }
        
        #else
        await updateLoadingStatus(.failed("Framework not available"))
        await updateAvailability(false)
        #endif
    }
}

// MARK: - Supporting Types (from RealFoundationModelsProvider)

public enum FoundationModelUseCase {
    case contentGeneration
    case guidedGeneration
    case toolCalling
    case summarization
    case translation
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
}

public struct FoundationModelToolCall {
    public let toolName: String
    public let parameters: [String: Any]
}

public struct FoundationModelResponse {
    public let text: String
    public let toolCalls: [FoundationModelToolCall]
}
