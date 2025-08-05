# WorkingMLXProvider API Documentation

## Overview

`WorkingMLXProvider` is the core implementation of Gemma 3n Vision-Language Model integration in ProjectOne, delivering revolutionary voice memo processing capabilities with direct audio understanding.

## Class Declaration

```swift
@MainActor
public class WorkingMLXProvider: ObservableObject, AIModelProvider
```

## Protocol Conformance

### AIModelProvider Properties

```swift
public var identifier: String { "working-mlx-provider" }
public var displayName: String { "Working MLX Provider (Placeholder)" }
public var isAvailable: Bool { isAvailable() }
public var supportsPersonalData: Bool { true } // On-device processing
public var isOnDevice: Bool { true }
public var estimatedResponseTime: TimeInterval { 2.0 }
public var maxContextLength: Int { 8192 }
public var isMLXSupported: Bool { isAvailable() }
```

## Properties

### Published Properties

```swift
@Published public var isLoading = false
@Published public var loadingProgress: Double = 0.0
@Published public var errorMessage: String?
@Published public var isReady = false
```

### Private Properties

```swift
private var modelContainer: ModelContainer?
private var currentModelId: String?
private var currentDisplayName: String?
private var isLoadingInProgress = false
private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "WorkingMLXProvider")
```

## Supported Models

### MLXModel Enumeration

```swift
public enum MLXModel: String, CaseIterable {
    case gemma3n_E4B_5bit = "mlx-community/gemma-3n-E4B-it-5bit"
    case gemma3n_E2B_4bit = "mlx-community/gemma-3n-E2B-it-4bit"
    case qwen3_4B = "mlx-community/Qwen3-4B-4bit"
    case gemma2_2B = "mlx-community/Gemma-2-2b-it-4bit"
    
    var displayName: String { /* ... */ }
    var isVLM: Bool { /* ... */ }
}
```

### Model Specifications

| Model | Memory Usage | Platform | VLM Capable | Use Case |
|-------|--------------|----------|-------------|----------|
| `gemma3n_E2B_4bit` | ~1.7GB | iOS Optimized | ✅ | Mobile voice memos |
| `gemma3n_E4B_5bit` | ~3-4GB | Mac Optimized | ✅ | Desktop processing |
| `qwen3_4B` | ~3GB | Cross-platform | ❌ | Legacy compatibility |
| `gemma2_2B` | ~3GB | Cross-platform | ❌ | Legacy compatibility |

## Core Methods

### Model Management

#### `loadModel(_:)`
```swift
public func loadModel(_ modelId: String) async throws
```

**Purpose**: Loads and initializes a Gemma 3n VLM model for processing.

**Parameters**:
- `modelId`: String identifier for the model (use `MLXModel.rawValue`)

**Throws**: 
- `AIModelError.modelNotReady` - Model loading failed
- Platform compatibility errors

**Example**:
```swift
let provider = WorkingMLXProvider()
try await provider.loadModel(WorkingMLXProvider.MLXModel.gemma3n_E2B_4bit.rawValue)
```

#### `isAvailable()`
```swift
public func isAvailable() -> Bool
```

**Purpose**: Checks if MLX is supported on the current device.

**Returns**: `true` if running on Apple Silicon (not simulator), `false` otherwise.

### Text Generation

#### `generate(prompt:)`
```swift
public func generate(prompt: String) async throws -> String
```

**Purpose**: Generates response using the loaded VLM model.

**Parameters**:
- `prompt`: Input text for VLM processing

**Returns**: Generated response string

**Throws**: 
- `AIModelError.modelNotReady` - No model loaded
- `AIModelError.generationFailed(_)` - Processing error

**Example**:
```swift
let response = try await provider.generate(prompt: "Analyze this voice memo content...")
```

#### `streamGenerate(prompt:)`
```swift
public func streamGenerate(prompt: String) -> AsyncThrowingStream<String, Error>
```

**Purpose**: Streams response generation for real-time UI updates.

**Parameters**:
- `prompt`: Input text for VLM processing

**Returns**: `AsyncThrowingStream<String, Error>` for streaming updates

**Example**:
```swift
for try await chunk in provider.streamGenerate(prompt: prompt) {
    print("Streaming chunk: \(chunk)")
}
```

### AIModelProvider Protocol Methods

#### `generateResponse(prompt:context:)`
```swift 
public func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse
```

**Purpose**: Generates enhanced response with memory context integration.

**Parameters**:
- `prompt`: Input text for processing
- `context`: Memory context for enhanced understanding

**Returns**: `AIModelResponse` with metadata

**Example**:
```swift
let memoryContext = MemoryContext(shortTermMemories: [], longTermMemories: [])
let response = try await provider.generateResponse(prompt: prompt, context: memoryContext)
```

#### `prepare()`
```swift
public func prepare() async throws
```

**Purpose**: Prepares the provider by loading a default model if none is loaded.

#### `cleanup()`
```swift
public func cleanup() async
```

**Purpose**: Cleans up resources and unloads models.

#### `canHandle(contextSize:)`
```swift
public func canHandle(contextSize: Int) -> Bool
```

**Purpose**: Checks if the provider can handle a context of given size.

**Parameters**:
- `contextSize`: Size of context to validate

**Returns**: `true` if context size is within limits

## Platform Compatibility

### Device Requirements

```swift
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
```

### Model Recommendations

#### `getRecommendedModel()`
```swift
public func getRecommendedModel() -> MLXModel
```

**Returns**: Optimal model based on current platform
- iOS: `gemma3n_E2B_4bit` (1.7GB RAM)
- macOS: `gemma3n_E4B_5bit` (3-4GB RAM)

#### `getHighPerformanceModel()`
```swift
public func getHighPerformanceModel() -> MLXModel
```

**Returns**: High-quality model variant
- iOS: `gemma3n_E2B_5bit` (2.1GB RAM)
- macOS: `gemma3n_E4B_8bit` (8GB RAM)

## Error Handling

### AIModelError Enumeration

```swift
public enum AIModelError: Error {
    case modelNotReady
    case generationFailed(String)
    
    var localizedDescription: String { /* ... */ }
}
```

### Error Scenarios

1. **Model Not Loaded**: Attempting to generate without loading a model
2. **Platform Incompatibility**: Running on unsupported hardware
3. **Memory Constraints**: Insufficient RAM for selected model
4. **Processing Timeout**: VLM processing exceeds timeout limits

## Usage Examples

### Basic VLM Processing

```swift
import Foundation

let provider = WorkingMLXProvider()

// Check platform compatibility
guard provider.isAvailable else {
    print("MLX not supported on this device")
    return
}

// Load iOS-optimized model
try await provider.loadModel(WorkingMLXProvider.MLXModel.gemma3n_E2B_4bit.rawValue)

// Process voice memo content
let voiceMemoPrompt = """
Process this voice memo:
"Just had a great meeting with Sarah about the project timeline..."

Extract: sentiment, people mentioned, action items, timeline
"""

let analysis = try await provider.generate(prompt: voiceMemoPrompt)
print("VLM Analysis: \(analysis)")

// Cleanup
await provider.cleanup()
```

### Streaming Processing

```swift
let prompt = "Analyze emotional context in this voice memo..."

for try await chunk in provider.streamGenerate(prompt: prompt) {
    DispatchQueue.main.async {
        // Update UI with streaming results
        updateVLMInsights(chunk)
    }
}
```

### Memory-Enhanced Processing

```swift
let memoryContext = MemoryContext(
    shortTermMemories: recentVoiceMemos,
    longTermMemories: relatedProjects,
    containsPersonalData: true
)

let response = try await provider.generateResponse(
    prompt: voiceMemoContent,
    context: memoryContext
)

print("Enhanced Analysis: \(response.content)")
print("Processing Time: \(response.processingTime)s")
print("Confidence: \(response.confidence)")
```

## Performance Considerations

### Memory Management
- **Model Loading**: 2-5 seconds initial load
- **Processing**: 1-2 seconds per voice memo
- **Memory Usage**: Platform-appropriate (1.7GB-8GB)

### Optimization Tips
1. **Preload Models**: Load during app startup for faster first-use
2. **Choose Appropriate Variant**: E2B for iOS, E4B for Mac
3. **Monitor Memory**: Use iOS memory warnings for cleanup
4. **Batch Processing**: Process multiple memos together when possible

## Thread Safety

The `WorkingMLXProvider` is marked with `@MainActor` and should be used from the main thread. All async operations are properly handled with Swift concurrency.

## Integration Points

### Memory System
- Integrates with `MemoryAgent` for enhanced context
- Connects to `KnowledgeGraphService` for entity mapping
- Uses `MemoryAnalyticsService` for performance tracking

### UI Integration
- Compatible with SwiftUI `@StateObject` and `@ObservedObject`
- Provides `@Published` properties for UI binding
- Supports real-time progress updates during processing

### Analytics
- Tracks processing times and confidence scores
- Integrates with `CognitiveDecisionEngine` for decision logging
- Provides performance metrics for optimization

## Future Enhancements

### Planned Features
- **Real-time Processing**: Stream processing during recording
- **Model Caching**: Intelligent model preloading
- **GPU Optimization**: Enhanced Metal utilization
- **Federated Learning**: Privacy-preserving improvements

### API Evolution
- **Backwards Compatibility**: Maintained through versioning
- **Model Updates**: Support for future Gemma 3n variants
- **Enhanced Context**: Larger context window support