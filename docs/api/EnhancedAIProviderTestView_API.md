# EnhancedAIProviderTestView API Documentation

## Overview

`EnhancedAIProviderTestView` is a comprehensive SwiftUI view that provides testing and comparison capabilities for all AI providers available in ProjectOne. It supports local providers (MLX, Apple Foundation Models) and external API providers (OpenAI, OpenRouter, Ollama).

## Class Declaration

```swift
@available(iOS 26.0, macOS 26.0, *)
struct EnhancedAIProviderTestView: View
```

## Architecture

### State Management Properties

#### UI State
```swift
@State private var testPrompt: String
@State private var selectedProviders: Set<AIProviderType>
@State private var testResults: [AITestResult]
@State private var isLoading: Bool
@State private var loadingProviders: Set<AIProviderType>
@State private var showConfiguration: Bool
```

#### Provider Instances
```swift
@StateObject private var workingMLXProvider: WorkingMLXProvider
@StateObject private var appleFoundationProvider: AppleFoundationModelsProvider
@StateObject private var ollamaProvider: OllamaProvider
@StateObject private var openAIProvider: OpenAIProvider
@StateObject private var openRouterProvider: OpenRouterProvider
```

#### Configuration State
```swift
@State private var openAIAPIKey: String
@State private var openRouterAPIKey: String
@State private var ollamaBaseURL: String
```

## Core Types

### AIProviderType Enumeration

```swift
enum AIProviderType: String, CaseIterable {
    case workingMLX = "Working MLX"
    case appleFoundation = "Apple Foundation Models"
    case ollama = "Ollama"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    
    var icon: String { /* SF Symbol icon */ }
    var color: Color { /* Associated color */ }
    var description: String { /* Human-readable description */ }
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `icon` | `String` | SF Symbol name for provider icon |
| `color` | `Color` | SwiftUI Color for theming |
| `description` | `String` | Human-readable provider description |

#### Supported Providers

| Provider | Icon | Color | Description |
|----------|------|-------|-------------|
| `workingMLX` | `cpu.fill` | `.blue` | Local MLX models on Apple Silicon |
| `appleFoundation` | `apple.logo` | `.green` | Apple's on-device Foundation Models |
| `ollama` | `server.rack` | `.orange` | Local Ollama server models |
| `openAI` | `cloud.fill` | `.purple` | OpenAI GPT models via API |
| `openRouter` | `network` | `.pink` | Multiple models via OpenRouter API |

### AITestResult Structure

```swift
struct AITestResult {
    let id: UUID
    let providerType: AIProviderType
    let response: String
    let responseTime: TimeInterval
    let success: Bool
    let error: String?
    
    var displayTime: String { /* Formatted time string */ }
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | `UUID` | Unique identifier for result |
| `providerType` | `AIProviderType` | Provider that generated result |
| `response` | `String` | Generated response content |
| `responseTime` | `TimeInterval` | Time taken to generate response |
| `success` | `Bool` | Whether generation succeeded |
| `error` | `String?` | Error message if failed |
| `displayTime` | `String` | Formatted response time (e.g., "2.34s") |

### AITestError Enumeration

```swift
enum AITestError: Error, LocalizedError {
    case providerNotAvailable(String)
    case configurationMissing(String)
    
    var errorDescription: String? { /* Localized error description */ }
}
```

## Core Methods

### Provider Management

#### `isProviderAvailable(_:)`
```swift
private func isProviderAvailable(_ providerType: AIProviderType) -> Bool
```

**Purpose**: Checks if a provider is properly configured and available for testing.

**Parameters**:
- `providerType`: The provider type to check

**Returns**: `true` if provider is available, `false` otherwise

**Implementation Logic**:
```swift
switch providerType {
case .workingMLX:
    return workingMLXProvider.isMLXSupported
case .appleFoundation:
    return appleFoundationProvider.isAvailable
case .ollama:
    return isOllamaConfigured
case .openAI:
    return isOpenAIConfigured
case .openRouter:
    return isOpenRouterConfigured
}
```

#### `toggleProvider(_:)`
```swift
private func toggleProvider(_ providerType: AIProviderType)
```

**Purpose**: Adds or removes a provider from the selected set for testing.

**Parameters**:
- `providerType`: Provider to toggle

### Provider Setup

#### `setupProviders()`
```swift
private func setupProviders()
```

**Purpose**: Initializes all available providers with default configurations.

**Implementation**:
```swift
Task {
    // Setup Apple Foundation Models
    try? await appleFoundationProvider.prepareModel()
    
    // Setup Working MLX Provider if supported
    if workingMLXProvider.isMLXSupported {
        try? await workingMLXProvider.loadModel(
            WorkingMLXProvider.MLXModel.gemma2_2B.rawValue
        )
    }
}
```

### Testing Workflow

#### `testSelectedProviders()`
```swift
private func testSelectedProviders()
```

**Purpose**: Tests all currently selected providers with the current prompt.

#### `testAllAvailableProviders()`
```swift
private func testAllAvailableProviders()
```

**Purpose**: Tests all available and configured providers.

#### `testProviders(_:)`
```swift
private func testProviders(_ providers: [AIProviderType])
```

**Purpose**: Core testing method that runs providers in parallel using TaskGroup.

**Parameters**:
- `providers`: Array of provider types to test

**Implementation Pattern**:
```swift
await withTaskGroup(of: AITestResult.self) { group in
    for providerType in providers {
        group.addTask {
            await testProvider(providerType)
        }
    }
    
    for await result in group {
        results.append(result)
    }
}
```

#### `testProvider(_:)`
```swift
private func testProvider(_ providerType: AIProviderType) async -> AITestResult
```

**Purpose**: Tests a single provider and returns result with timing information.

**Parameters**:
- `providerType`: Provider to test

**Returns**: `AITestResult` with response and performance data

### Response Generation

#### `generateResponse(for:prompt:)`
```swift
private func generateResponse(
    for providerType: AIProviderType, 
    prompt: String
) async throws -> String
```

**Purpose**: Generates response from specific provider with proper error handling.

**Parameters**:
- `providerType`: Provider to use for generation
- `prompt`: Input prompt for generation

**Returns**: Generated response string

**Throws**: `AITestError` for configuration or generation failures

**Provider-Specific Implementation**:
```swift
switch providerType {
case .workingMLX:
    let context = MemoryContext(userQuery: prompt)
    let response = try await workingMLXProvider.generateResponse(
        prompt: prompt, 
        context: context
    )
    return response.content

case .appleFoundation:
    guard appleFoundationProvider.isAvailable else {
        throw AITestError.providerNotAvailable("Apple Foundation Models not available")
    }
    return try await appleFoundationProvider.generateModelResponse(prompt)

case .ollama:
    guard isOllamaConfigured else {
        throw AITestError.providerNotAvailable("Ollama not configured")
    }
    ollamaProvider.configuration.baseURL = ollamaBaseURL
    try await ollamaProvider.prepareModel()
    return try await ollamaProvider.generateModelResponse(prompt)

case .openAI:
    guard isOpenAIConfigured else {
        throw AITestError.providerNotAvailable("OpenAI API key not configured")
    }
    openAIProvider.configuration.apiKey = openAIAPIKey
    try await openAIProvider.prepareModel()
    return try await openAIProvider.generateModelResponse(prompt)

case .openRouter:
    guard isOpenRouterConfigured else {
        throw AITestError.providerNotAvailable("OpenRouter API key not configured")
    }
    openRouterProvider.configuration.apiKey = openRouterAPIKey
    try await openRouterProvider.prepareModel()
    return try await openRouterProvider.generateModelResponse(prompt)
}
```

## UI Components

### Supporting Views

#### ProviderCard
```swift
struct ProviderCard: View {
    let providerType: AIProviderType
    let isSelected: Bool
    let isAvailable: Bool
    let isLoading: Bool
    let onToggle: () -> Void
}
```

**Purpose**: Interactive card for provider selection with status indicators.

#### StatusCard
```swift
struct StatusCard: View {
    let name: String
    let isReady: Bool
    let color: Color
}
```

**Purpose**: Shows provider readiness status in the status grid.

#### TestResultCard
```swift
struct TestResultCard: View {
    let result: AITestResult
}
```

**Purpose**: Displays test results with performance metrics and response content.

#### ConfigurationView
```swift
struct ConfigurationView: View {
    @Binding var openAIAPIKey: String
    @Binding var openRouterAPIKey: String
    @Binding var ollamaBaseURL: String
}
```

**Purpose**: Modal sheet for configuring external provider credentials.

### Button Styles

#### PrimaryButtonStyle
```swift
struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        // Primary button styling with color and press effects
    }
}
```

#### SecondaryButtonStyle
```swift
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        // Secondary button styling with border and press effects
    }
}
```

## Configuration Properties

### Computed Properties

#### `isOllamaConfigured`
```swift
private var isOllamaConfigured: Bool {
    !ollamaBaseURL.isEmpty
}
```

#### `isOpenAIConfigured`
```swift
private var isOpenAIConfigured: Bool {
    !openAIAPIKey.isEmpty
}
```

#### `isOpenRouterConfigured`
```swift
private var isOpenRouterConfigured: Bool {
    !openRouterAPIKey.isEmpty
}
```

## Quick Prompts

### Pre-defined Test Prompts
```swift
private let quickPrompts = [
    "Hello! Can you tell me about yourself and your capabilities?",
    "Explain quantum computing in simple terms",
    "Write a short creative story about AI",
    "What are the benefits of on-device AI processing?",
    "Compare Swift and Python programming languages",
    "Explain the concept of machine learning",
    "What is the future of artificial intelligence?",
    "Describe how neural networks work"
]
```

## Performance Considerations

### Concurrency
- Uses `@MainActor` for UI thread safety
- Employs `withTaskGroup` for parallel provider testing
- Implements proper async/await patterns

### Memory Management
- Uses `@StateObject` for proper ObservableObject lifecycle
- Implements cleanup in provider instances
- Manages configuration state efficiently

### Error Handling
- Comprehensive error types for different failure modes
- User-friendly error messages with actionable guidance
- Graceful degradation when providers are unavailable

## Integration Points

### Provider Compatibility
```swift
// Working MLX Provider
workingMLXProvider.generateResponse(prompt: String, context: MemoryContext)

// Apple Foundation Models Provider
appleFoundationProvider.generateModelResponse(String)

// External Providers (Ollama, OpenAI, OpenRouter)
provider.generateModelResponse(String)
```

### Settings Integration
```swift
// Accessed via Settings → Advanced → AI Provider Testing
NavigationLink("AI Provider Testing") {
    if #available(iOS 26.0, macOS 26.0, *) {
        EnhancedAIProviderTestView()
    } else {
        AIProviderTestView()
    }
}
```

## Usage Examples

### Basic Testing
```swift
// 1. Select providers via UI
// 2. Enter test prompt
// 3. Tap "Test Selected Providers"
// 4. View results sorted by performance
```

### Configuration Example
```swift
// Configure OpenAI
openAIAPIKey = "sk-..."
openAIProvider.configuration.apiKey = openAIAPIKey
try await openAIProvider.prepareModel()

// Configure Ollama
ollamaBaseURL = "http://localhost:11434"
ollamaProvider.configuration.baseURL = ollamaBaseURL
try await ollamaProvider.prepareModel()
```

### Error Handling Example
```swift
do {
    let response = try await generateResponse(for: .openAI, prompt: testPrompt)
    // Handle successful response
} catch AITestError.providerNotAvailable(let reason) {
    // Show configuration guidance
} catch AITestError.configurationMissing(let details) {
    // Show setup instructions
} catch {
    // Handle other errors
}
```

## Platform Requirements

- **Minimum**: iOS 26.0, macOS 26.0
- **Fallback**: Uses `AIProviderTestView` on older platforms
- **Hardware**: Apple Silicon recommended for MLX providers

## Thread Safety

All UI updates are performed on the main actor:
```swift
await MainActor.run {
    testResults = results
    isLoading = false
    loadingProviders.removeAll()
}
```

## Future Enhancements

### Planned Features
- Batch testing with multiple prompts
- Response comparison and diff view
- Export test results functionality
- Automated provider health monitoring
- Multi-modal testing (images, audio)

### API Evolution
- Backwards compatibility maintained through versioning
- Provider plugin architecture for extensibility
- Enhanced configuration management
- Performance analytics and reporting