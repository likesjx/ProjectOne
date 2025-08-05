//
//  MLXLLMProvider.swift
//  ProjectOne
//
//  🎓 SWIFT LEARNING: This file demonstrates advanced Swift concepts including:
//  • **Three-Layer Architecture**: Service → Provider → Core pattern
//  • **ObservableObject**: SwiftUI reactive data binding
//  • **Combine Framework**: Publisher/Subscriber pattern with @Published
//  • **MLX Swift Integration**: Apple Silicon ML framework usage
//  • **Async Streams**: Real-time data streaming for AI responses
//  • **Error Handling**: Custom error types and propagation
//  • **Dependency Injection**: Service layer abstraction
//
//  Text-only chat interface wrapping MLXService
//  Clean separation between model management and chat interface
//

import Foundation
import SwiftUI      // 🎓 SWIFT LEARNING: Apple's declarative UI framework
import Combine      // 🎓 SWIFT LEARNING: Reactive programming - handles async events
import MLX  // 🎓 SWIFT LEARNING: MLX Swift framework for Apple Silicon ML
import os.log       // 🎓 SWIFT LEARNING: Apple's structured logging system

// MARK: - MLX Text-Only LLM Provider
// 🎓 SWIFT LEARNING: This class demonstrates the Provider layer in our three-layer architecture

/// Text-only LLM provider wrapping MLXService
/// 
/// 🎓 SWIFT LEARNING: This class demonstrates several key Swift patterns:
/// • **ObservableObject**: Enables SwiftUI views to automatically update when data changes
/// • **Three-Layer Architecture**: Provider wraps Service layer, provides clean abstraction
/// • **Publisher Pattern**: @Published properties create data streams UI can subscribe to
/// • **Dependency Injection**: Takes MLXService as dependency rather than creating it directly
/// • **State Management**: Manages loading, error, and availability states
@MainActor
public class MLXLLMProvider: ObservableObject {
    
    // 🎓 SWIFT LEARNING: Logger for structured, performance-optimized logging
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXLLMProvider")
    
    // MARK: - Dependencies
    // 🎓 SWIFT LEARNING: Dependency injection pattern - separates concerns cleanly
    
    // 🎓 SWIFT LEARNING: Service layer dependency
    // Rather than MLXLLMProvider doing everything itself, it delegates to MLXService
    // This creates clean separation: Provider handles UI state, Service handles ML operations
    private let mlxService = MLXService()
    
    // MARK: - Published State Properties
    // 🎓 SWIFT LEARNING: @Published creates reactive data streams
    
    // 🎓 SWIFT LEARNING: These @Published properties automatically trigger UI updates
    // When any of these values change, SwiftUI views observing this object will re-render
    // This is the magic that makes SwiftUI reactive and declarative
    @Published public var isReady = false           // 🎓 Model is loaded and ready for inference
    @Published public var isLoading = false         // 🎓 Currently loading model or processing
    @Published public var errorMessage: String?     // 🎓 Optional - only set when errors occur
    @Published public var loadingProgress: Double = 0.0  // 🎓 0.0 to 1.0 progress indicator
    
    // MARK: - Private State
    // 🎓 SWIFT LEARNING: Internal state not exposed to UI
    
    // 🎓 SWIFT LEARNING: Optional types for model state
    // These can be nil when no model is loaded, or contain values when model is active
    private var modelContainer: ModelContainer?           // 🎓 Wrapper around loaded MLX model
    private var currentConfiguration: MLXModelConfiguration?  // 🎓 Config for currently loaded model
    
    // 🎓 SWIFT LEARNING: Combine framework for managing subscriptions
    // Set<AnyCancellable> stores references to Combine publishers to prevent memory leaks
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    // 🎓 SWIFT LEARNING: Setting up reactive data binding with Combine
    
    public init() {
        logger.info("Initializing MLX LLM Provider")
        
        // 🎓 SWIFT LEARNING: Combine publishers and reactive data binding
        // This sets up automatic state synchronization between MLXService and MLXLLMProvider
        
        // 🎓 SWIFT LEARNING: Publisher chain explanation:
        // 1. mlxService.$isLoading creates a publisher that emits when isLoading changes
        // 2. .receive(on: DispatchQueue.main) ensures UI updates happen on main thread
        // 3. .assign(to: &$isLoading) automatically updates our @Published property
        // 4. The & creates a reference to the property wrapper's publisher
        mlxService.$isLoading
            .receive(on: DispatchQueue.main)    // 🎓 Switch to main thread for UI updates
            .assign(to: &$isLoading)            // 🎓 Auto-assign values to our @Published property
        
        // 🎓 SWIFT LEARNING: Same pattern for loading progress
        // This creates real-time progress updates from service layer to UI
        mlxService.$loadingProgress
            .receive(on: DispatchQueue.main)    // 🎓 Ensure UI thread safety
            .assign(to: &$loadingProgress)      // 🎓 Bind service progress to provider progress
        
        // 🎓 SWIFT LEARNING: Error message propagation
        // Errors from MLX service automatically appear in the provider layer
        mlxService.$errorMessage
            .receive(on: DispatchQueue.main)    // 🎓 UI updates must be on main thread
            .assign(to: &$errorMessage)         // 🎓 Propagate errors up the architecture layers
    }
    
    // MARK: - Device Compatibility
    // 🎓 SWIFT LEARNING: Computed properties for dynamic values
    
    /// Check if MLX LLM is supported on current device
    /// 
    /// 🎓 SWIFT LEARNING: Computed property that delegates to service layer
    /// • No stored value - calculates result each time it's accessed
    /// • Provides clean abstraction over MLXService's compatibility check
    /// • Encapsulates complex device/architecture checking logic
    public var isSupported: Bool {
        return mlxService.isMLXSupported  // 🎓 Delegates to service layer
    }
    
    // MARK: - Model Management
    // 🎓 SWIFT LEARNING: Async model loading with comprehensive error handling
    
    /// Load a specific LLM model configuration
    /// 
    /// 🎓 SWIFT LEARNING: This method demonstrates several async patterns:
    /// • **async throws**: Can both wait for completion AND throw errors
    /// • **guard statements**: Multiple validation checks with early exit
    /// • **MainActor.run**: Safe UI updates from background threads
    /// • **do-catch**: Structured error handling with cleanup
    public func loadModel(_ configuration: MLXModelConfiguration) async throws {
        // 🎓 SWIFT LEARNING: Guard statement for type validation
        // Ensures we only load LLM models, not VLM (vision-language) models
        guard configuration.type == .llm else {
            throw MLXLLMError.invalidModelType("Configuration is not for LLM model")
        }
        
        // 🎓 SWIFT LEARNING: Device compatibility check
        // MLX only works on Apple Silicon (M1, M2, M3, etc.) - not Intel or simulators
        guard isSupported else {
            throw MLXLLMError.deviceNotSupported("MLX requires real Apple Silicon hardware")
        }
        
        logger.info("Loading LLM model: \(configuration.name)")
        
        // 🎓 SWIFT LEARNING: MainActor.run for safe UI updates
        // This ensures UI state changes happen on the main thread, preventing crashes
        await MainActor.run {
            isReady = false      // 🎓 Mark as not ready while loading
            errorMessage = nil   // 🎓 Clear any previous errors
        }
        
        do {
            // 🔧 FIXED: Load model through MLXService with proper type and ID
            let container = try await mlxService.loadModel(modelId: configuration.modelId, type: .llm)
            
            // Store references with validation
            self.modelContainer = container
            self.currentConfiguration = configuration
            
            // 🔧 FIXED: Validate container is properly loaded
            guard container.isReady else {
                throw MLXLLMError.modelNotReady("Container loaded but model not ready")
            }
            
            await MainActor.run {
                isReady = true
                logger.info("✅ LLM model loaded: \(configuration.name) (\(container.info))")
            }
            
        } catch {
            await MainActor.run {
                isReady = false
                errorMessage = "Failed to load \(configuration.name): \(error.localizedDescription)"
            }
            logger.error("❌ LLM model loading failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Load recommended model for current platform
    public func loadRecommendedModel() async throws {
        guard let config = MLXModelRegistry.getRecommendedModel(for: .llm) else {
            throw MLXLLMError.noModelAvailable("No recommended LLM model found")
        }
        
        try await loadModel(config)
    }
    
    /// Unload current model to free memory
    public func unloadModel() async {
        logger.info("Unloading LLM model")
        
        modelContainer = nil
        currentConfiguration = nil
        
        await MainActor.run {
            isReady = false
            loadingProgress = 0.0
            errorMessage = nil
        }
        
        logger.info("✅ LLM model unloaded")
    }
    
    // MARK: - Text Generation
    
    /// Generate response to text prompt
    public func generateResponse(to prompt: String) async throws -> String {
        guard let container = modelContainer else {
            throw MLXLLMError.modelNotLoaded("No LLM model loaded")
        }
        
        guard isReady else {
            throw MLXLLMError.modelNotReady("LLM model is not ready")
        }
        
        logger.info("Generating response for text prompt")
        
        do {
            // 🔧 FIXED: Generate using updated MLXService with proper error handling
            let response = try await mlxService.generate(with: container, prompt: prompt)
            
            // 🔧 ADDED: Validate response quality
            guard !response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                throw MLXLLMError.generationFailed("Model returned empty response")
            }
            
            logger.info("✅ LLM response generated: \(response.count) characters")
            return response
            
        } catch {
            logger.error("❌ LLM response generation failed: \(error.localizedDescription)")
            throw MLXLLMError.generationFailed("Generation error: \(error.localizedDescription)")
        }
    }
    
    /// Stream response for real-time UI updates
    /// 
    /// 🎓 SWIFT LEARNING: AsyncThrowingStream - Advanced Swift Concurrency
    /// This demonstrates one of Swift's most powerful concurrency features for real-time data
    /// 
    /// **What this method does:**
    /// • Creates a stream of String chunks as the AI generates text
    /// • UI can display partial responses as they arrive (like ChatGPT's typing effect)
    /// • Handles errors gracefully without breaking the stream
    /// 
    /// **Key Swift concepts:**
    /// • **AsyncThrowingStream**: Swift's async iterator that can emit values over time
    /// • **Continuation**: Controls the stream - can yield values, finish, or throw errors
    /// • **for try await**: Consumes another async stream and forwards its values
    /// • **Task**: Creates concurrent execution context for the stream processing
    public func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        
        // 🎓 SWIFT LEARNING: AsyncThrowingStream creation
        // The closure defines how the stream produces values over time
        return AsyncThrowingStream { continuation in
            
            // 🎓 SWIFT LEARNING: Task creates concurrent execution context
            // This prevents the stream creation from blocking the caller
            Task {
                do {
                    // 🎓 SWIFT LEARNING: Validation before streaming
                    guard let container = modelContainer else {
                        continuation.finish(throwing: MLXLLMError.modelNotLoaded("No LLM model loaded"))
                        return
                    }
                    
                    guard isReady else {
                        continuation.finish(throwing: MLXLLMError.modelNotReady("LLM model is not ready"))
                        return
                    }
                    
                    // 🎓 SWIFT LEARNING: Consuming and forwarding an async stream
                    // for try await iterates over MLXService's stream and forwards each chunk
                    for try await chunk in mlxService.streamGenerate(with: container, prompt: prompt) {
                        continuation.yield(chunk)  // 🎓 Emit chunk to our stream consumers
                    }
                    
                    continuation.finish()  // 🎓 Signal end of stream (no more values)
                    
                } catch {
                    continuation.finish(throwing: error)  // 🎓 Propagate any errors to stream consumers
                }
            }
        }
    }
    
    // MARK: - Conversation Management
    
    /// Generate response with conversation history (simplified)
    public func generateResponse(withHistory conversationText: String) async throws -> String {
        guard let container = modelContainer else {
            throw MLXLLMError.modelNotLoaded("No LLM model loaded")
        }
        
        guard isReady else {
            throw MLXLLMError.modelNotReady("LLM model is not ready")
        }
        
        logger.info("Generating response with conversation history")
        
        do {
            // Generate using MLXService with conversation history
            let response = try await mlxService.generate(with: container, prompt: conversationText)
            
            logger.info("✅ Conversation response generated successfully")
            return response
            
        } catch {
            logger.error("❌ Conversation response generation failed: \(error.localizedDescription)")
            throw MLXLLMError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Model Information
    
    /// Get information about current model
    public func getModelInfo() -> MLXLLMModelInfo? {
        guard let config = currentConfiguration else {
            return nil
        }
        
        return MLXLLMModelInfo(
            configuration: config,
            isLoaded: isReady,
            loadingProgress: loadingProgress,
            isSupported: isSupported
        )
    }
    
    /// Get available LLM models for current platform
    public func getAvailableModels() -> [MLXModelConfiguration] {
        let platform: Platform = {
            #if os(iOS)
            return .iOS
            #else
            return .macOS
            #endif
        }()
        
        return MLXModelRegistry.models(for: platform).filter { $0.type == .llm }
    }
    
}

// MARK: - Supporting Types
// 🎓 SWIFT LEARNING: Custom types for clean architecture and type safety

/// Model information for LLM provider
/// 
/// 🎓 SWIFT LEARNING: Data structure with computed properties
/// • Combines stored properties (raw data) with computed properties (derived values)
/// • Provides clean interface for UI components to access model information
/// • Encapsulates complex configuration details behind simple properties
public struct MLXLLMModelInfo {
    // 🎓 SWIFT LEARNING: Stored properties - actual data storage
    public let configuration: MLXModelConfiguration  // 🎓 Full model configuration
    public let isLoaded: Bool                        // 🎓 Current loading state
    public let loadingProgress: Double               // 🎓 0.0 to 1.0 progress
    public let isSupported: Bool                     // 🎓 Device compatibility
    
    // 🎓 SWIFT LEARNING: Computed properties - derived from stored properties
    // These provide convenient access to nested configuration data
    public var displayName: String {
        return configuration.name  // 🎓 Extract user-friendly name
    }
    
    public var memoryRequirement: String {
        return configuration.memoryRequirement  // 🎓 Extract memory info for UI
    }
}

// MARK: - Custom Error Types
// 🎓 SWIFT LEARNING: Custom error enums with associated values

/// MLX LLM Provider specific errors
/// 
/// 🎓 SWIFT LEARNING: This enum demonstrates advanced error handling:
/// • **Error protocol**: Makes this enum throwable with 'throw' keyword
/// • **LocalizedError**: Provides user-friendly error messages
/// • **Associated Values**: Each error case can carry additional context
/// • **Pattern Matching**: Switch statements can extract associated values
/// • **Descriptive Cases**: Each error type has specific meaning and context
public enum MLXLLMError: Error, LocalizedError {
    case deviceNotSupported(String)   // 🎓 MLX needs Apple Silicon
    case modelNotLoaded(String)       // 🎓 No model in memory
    case modelNotReady(String)        // 🎓 Model loading/initializing
    case generationFailed(String)     // 🎓 AI inference failed
    case invalidModelType(String)     // 🎓 Wrong model type (e.g., VLM instead of LLM)
    case noModelAvailable(String)     // 🎓 No compatible models found
    
    // 🎓 SWIFT LEARNING: LocalizedError protocol implementation
    // This computed property provides user-friendly error messages
    // Swift's error handling system automatically uses these messages
    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let message):
            return "Device not supported: \(message)"  // 🎓 Extract associated value
        case .modelNotLoaded(let message):
            return "Model not loaded: \(message)"
        case .modelNotReady(let message):
            return "Model not ready: \(message)"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .invalidModelType(let message):
            return "Invalid model type: \(message)"
        case .noModelAvailable(let message):
            return "No model available: \(message)"
        }
    }
}