# AI Provider APIs

> **Production AI provider system with real MLX Swift 0.25.6 and iOS 26.0+ Foundation Models**

Complete API reference for ProjectOne's dual AI provider architecture with production-ready implementations.

## Architecture Overview

ProjectOne implements a sophisticated dual AI provider system that automatically routes requests between:
- **MLX Swift 0.25.6**: On-device inference with real community models
- **iOS 26.0+ Foundation Models**: System-integrated AI with Apple Intelligence

## Core Providers

### WorkingMLXProvider

Production MLX Swift implementation using the actual MLX Swift 0.25.6 APIs.

#### Supported Models

```swift
public enum MLXModel: String, CaseIterable {
    case qwen3_4B = "mlx-community/Qwen3-4B-4bit"
    case gemma2_2B = "mlx-community/Gemma-2-2b-it-4bit" 
    case gemma2_9B = "mlx-community/Gemma-2-9b-it-4bit"
    case llama3_8B = "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit"
    case mistral_7B = "mlx-community/Mistral-7B-Instruct-v0.3-4bit"
}
```

#### Key Methods

```swift
// Load model using real MLX APIs
public func loadModel(_ model: MLXModel) async throws

// Generate response with loaded model
public func generateResponse(to prompt: String) async throws -> String

// Stream response for real-time UI updates
public func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error>

// Device compatibility checking
public var isMLXSupported: Bool

// Get recommended model based on platform
public func getRecommendedModel() -> MLXModel
```

#### Usage Example

```swift
let provider = WorkingMLXProvider()

// Check device compatibility
guard provider.isMLXSupported else {
    print("MLX not supported on this device")
    return
}

// Load recommended model
let model = provider.getRecommendedModel()
try await provider.loadModel(model)

// Generate response
let response = try await provider.generateResponse(to: "Hello, how are you?")
```

### RealFoundationModelsProvider

iOS 26.0+ Foundation Models implementation with real SystemLanguageModel integration.

#### Availability States

```swift
// Real Foundation Models availability checking
switch model.availability {
case .available:
    // Ready to use
case .unavailable(.deviceNotEligible):
    // Device doesn't support Apple Intelligence
case .unavailable(.appleIntelligenceNotEnabled):
    // Apple Intelligence not enabled in Settings
case .unavailable(.modelNotReady):
    // Model downloading or system busy
}
```

#### Key Methods

```swift
// Generate text with Foundation Models
public func generateText(prompt: String, useCase: FoundationModelUseCase) async throws -> String

// Structured generation with @Generable
public func generateWithGuidance<T: Generable>(prompt: String, type: T.Type) async throws -> T

// Check current capabilities
public func getCapabilities() -> FoundationModelCapabilities
```

#### Usage Example

```swift
@available(iOS 26.0, *)
let provider = RealFoundationModelsProvider()

// Wait for availability check
while provider.isLoading { 
    try await Task.sleep(nanoseconds: 100_000_000) 
}

if provider.isAvailable {
    let response = try await provider.generateText(
        prompt: "Summarize this content", 
        useCase: .summarization
    )
}
```

### EnhancedGemma3nCore

Dual provider orchestration with automatic routing and advanced features.

#### Provider Selection

```swift
public enum AIProviderType: String, CaseIterable {
    case automatic = "automatic"
    case mlx = "mlx"
    case foundation = "foundation"
}
```

#### Key Methods

```swift
// Setup both providers
public func setup() async

// Process text with best available provider
public func processText(_ text: String, forceProvider: AIProviderType?) async -> String

// Structured generation (iOS 26.0+ only)
public func generateStructured<T: Generable>(prompt: String, type: T.Type) async throws -> T

// Extract entities using guided generation
public func extractEntities(from text: String) async throws -> ExtractedEntities

// Get provider status
public func getProviderStatus() -> ProviderStatus
```

#### Usage Example

```swift
@available(iOS 26.0, *)
let core = EnhancedGemma3nCore()
await core.setup()

// Automatic provider selection
let response = await core.processText("Explain quantum computing")

// Force specific provider
let mlxResponse = await core.processText("Hello world", forceProvider: .mlx)

// Structured generation
let entities = try await core.extractEntities(from: "Apple Inc. was founded in Cupertino")
```

## Testing Framework

### UnifiedAITestView

Comprehensive testing interface for concurrent provider evaluation.

#### Provider Testing

```swift
// Test multiple providers concurrently
private func testProviders(_ providers: [AIProviderType]) {
    Task {
        await withTaskGroup(of: ProviderTestResult.self) { group in
            for providerType in providers {
                group.addTask {
                    await testProvider(providerType)
                }
            }
            // Collect and analyze results
        }
    }
}
```

#### Result Analysis

```swift
struct ProviderTestResult {
    let providerName: String
    let response: String
    let responseTime: TimeInterval
    let success: Bool
    let error: String?
}
```

## Production Patterns

### Error Handling

```swift
public enum WorkingMLXError: Error, LocalizedError {
    case modelNotLoaded(String)
    case modelNotReady(String)
    case inferenceError(String)
    case loadingError(String)
}

public enum FoundationModelsError: Error, LocalizedError {
    case notAvailable(String)
    case frameworkNotAvailable
    case sessionFailed(String)
    case generationFailed(String)
}
```

### Device Compatibility

```swift
// MLX compatibility checking
#if targetEnvironment(simulator)
return false // MLX requires real Apple Silicon hardware
#else
#if arch(arm64)
return true // Apple Silicon Macs and iOS devices
#else
return false // Intel Macs not supported
#endif
#endif

// Foundation Models availability
#if canImport(FoundationModels)
let model = SystemLanguageModel.default
switch model.availability {
    // Handle all availability states
}
#endif
```

### Memory Management

```swift
// Unload MLX model to free memory
public func unloadModel() async {
    chatSession = nil
    modelContext = nil
    currentModelId = nil
}

// End Foundation Models session
public func endSession() async {
    session = nil
}
```

## Structured Generation (iOS 26.0+)

### @Generable Protocol Support

```swift
@Generable
public struct ExtractedEntities {
    public let people: [String]
    public let places: [String]
    public let organizations: [String]
    public let concepts: [String]
}

@Generable
public struct SummarizedContent {
    public let title: String
    public let keyPoints: [String]
    public let summary: String
}
```

### Usage Patterns

```swift
// Entity extraction
let entities = try await provider.generateWithGuidance(
    prompt: "Extract entities from: \(text)",
    type: ExtractedEntities.self
)

// Content summarization
let summary = try await provider.generateWithGuidance(
    prompt: "Summarize with key points: \(content)",
    type: SummarizedContent.self
)
```

## Best Practices

### Provider Selection Strategy

1. **iOS 26.0+ Devices**: Prefer Foundation Models for system integration
2. **Apple Silicon Macs**: Use MLX for privacy-sensitive content
3. **Fallback Strategy**: Always implement graceful degradation
4. **Performance**: Monitor response times and adapt routing

### Model Management

1. **MLX Models**: Load appropriate model size based on available memory
2. **Foundation Models**: Check availability before every session
3. **Resource Cleanup**: Unload models when not in use
4. **Error Recovery**: Implement retry logic with exponential backoff

### Testing Strategy

1. **Concurrent Testing**: Test all providers simultaneously for comparison
2. **Performance Benchmarking**: Track response times and success rates
3. **Device Variation**: Test across different hardware configurations
4. **Availability Monitoring**: Continuous checking of provider status

## Navigation

- **← Back to [API Index](README.md)**
- **→ Memory System: [Memory Agent API](MEMORY_AGENT_API.md)**
- **→ Foundation Models: [Foundation Models API](FOUNDATION_MODELS_API.md)**

---

*Last updated: 2025-07-19 - Production AI provider integration complete*