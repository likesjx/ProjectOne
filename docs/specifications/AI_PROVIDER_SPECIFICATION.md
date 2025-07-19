# Production AI Provider Specification

> **Comprehensive specification for ProjectOne's dual AI provider system with MLX Swift 0.25.6 and iOS 26.0+ Foundation Models**

This document defines the requirements, architecture, and implementation details for ProjectOne's production AI provider system featuring automatic routing between on-device MLX inference and system-integrated Foundation Models.

## Executive Summary

### Vision
Create a robust, production-ready AI system that seamlessly combines the privacy and control of on-device MLX inference with the optimization and integration of iOS 26.0+ Foundation Models, providing users with the best possible AI experience across all supported platforms.

### Objectives
1. **Production Readiness**: Replace all placeholder AI implementations with real, functional providers
2. **Dual Provider Architecture**: Implement intelligent routing between MLX Swift and Foundation Models
3. **Platform Optimization**: Leverage each platform's strengths for optimal performance
4. **Comprehensive Testing**: Ensure reliability through concurrent provider validation
5. **Future Extensibility**: Design for easy integration of additional AI providers

## Technical Requirements

### Core Provider Requirements

#### WorkingMLXProvider
- **Framework**: MLX Swift 0.25.6+ with MLXLMCommon integration
- **Models**: Real community models from MLX Hub (Qwen3, Gemma2, Llama3.1, Mistral)
- **Performance**: Sub-5-second inference on Apple Silicon
- **Memory**: Efficient model loading and GPU memory management
- **Compatibility**: Apple Silicon only (real hardware, not simulator)

#### RealFoundationModelsProvider
- **Framework**: iOS 26.0+ Foundation Models with SystemLanguageModel
- **Availability**: Real device eligibility checking and Apple Intelligence status
- **Features**: @Generable protocol support for structured generation
- **Integration**: System-level optimization and native iOS integration
- **Compatibility**: iOS 26.0+ devices with Apple Intelligence enabled

#### EnhancedGemma3nCore
- **Orchestration**: Intelligent provider selection and automatic routing
- **Fallback**: Graceful degradation when providers are unavailable
- **Advanced Features**: Structured generation, entity extraction, content summarization
- **Performance**: Response time optimization and resource management
- **Testing**: Integration with UnifiedAITestView for validation

### Platform Requirements

#### iOS Platform
- **Minimum Version**: iOS 26.0+ (for Foundation Models support)
- **Hardware**: Apple Silicon recommended for MLX, Foundation Models on all supported devices
- **Features**: Full dual provider support with automatic routing
- **Testing**: Comprehensive validation on physical devices and simulators

#### macOS Platform
- **Minimum Version**: macOS 26.0+ (Tahoe)
- **Hardware**: Apple Silicon required for MLX Swift support
- **Features**: Enhanced development and testing capabilities
- **Integration**: Cross-platform provider consistency

## Functional Specifications

### Provider Selection Logic

#### Automatic Routing Algorithm
```
1. Check iOS version and Foundation Models availability
2. If Foundation Models available and content is general → Use Foundation Models
3. If content is privacy-sensitive → Prefer MLX Swift (if available)
4. If Foundation Models unavailable → Use MLX Swift (if available)
5. If no providers available → Return clear error message
```

#### Content Analysis Factors
- **Privacy Sensitivity**: Personal data, financial information, health records
- **Processing Requirements**: Real-time response, batch processing, structured output
- **Platform Optimization**: System integration vs. dedicated processing
- **User Preferences**: Manual provider override capabilities

### Model Management

#### MLX Swift Models
| Model ID | Parameters | Quantization | Memory | Use Case |
|----------|------------|--------------|--------|----------|
| mlx-community/Qwen3-4B-4bit | 4B | 4-bit | ~3GB | General purpose, mobile |
| mlx-community/Gemma-2-2b-it-4bit | 2B | 4-bit | ~3GB | Lightweight, fast |
| mlx-community/Gemma-2-9b-it-4bit | 9B | 4-bit | ~6GB | High quality, desktop |
| mlx-community/Meta-Llama-3.1-8B-Instruct-4bit | 8B | 4-bit | ~8GB | Instruction following |
| mlx-community/Mistral-7B-Instruct-v0.3-4bit | 7B | 4-bit | ~6GB | Conversational |

#### Model Selection Strategy
- **iOS Devices**: Default to Gemma-2-2b-it-4bit for memory efficiency
- **Apple Silicon Macs**: Default to Qwen3-4B-4bit for balanced performance
- **High Memory Systems**: Allow selection of larger models (9B, 8B parameters)
- **Dynamic Selection**: Adjust based on available system memory

### Structured Generation Capabilities

#### @Generable Protocol Support (iOS 26.0+)
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

#### Use Cases
1. **Entity Extraction**: Automatic identification of people, places, organizations
2. **Content Summarization**: Structured summaries with titles and key points
3. **Memory Management**: Enhanced memory extraction with guaranteed structure
4. **Knowledge Graph**: Automatic entity and relationship extraction

## Implementation Requirements

### Error Handling

#### Provider-Specific Error Management
```swift
// MLX Swift specific errors
public enum WorkingMLXError: Error, LocalizedError {
    case modelNotLoaded(String)
    case modelNotReady(String)
    case inferenceError(String)
    case loadingError(String)
}

// Foundation Models specific errors
public enum FoundationModelsError: Error, LocalizedError {
    case notAvailable(String)
    case frameworkNotAvailable
    case sessionFailed(String)
    case generationFailed(String)
}
```

#### Recovery Strategies
1. **Automatic Fallback**: Seamless provider switching on failure
2. **Retry Logic**: Exponential backoff for transient errors
3. **User Notification**: Clear error messages with actionable guidance
4. **Resource Recovery**: Memory cleanup and reinitialization

### Performance Requirements

#### Response Time Targets
- **Foundation Models**: < 3 seconds for standard queries
- **MLX Swift**: < 5 seconds for loaded models, < 30 seconds cold start
- **Structured Generation**: < 10 seconds for complex extraction tasks
- **Provider Selection**: < 100ms decision time

#### Memory Management
- **MLX Models**: Automatic unloading when inactive for > 10 minutes
- **Foundation Models**: Session management with resource cleanup
- **Concurrent Usage**: Intelligent resource balancing
- **Memory Pressure**: Automatic model unloading under memory constraints

### Testing Requirements

#### UnifiedAITestView Features
1. **Concurrent Testing**: Test multiple providers simultaneously
2. **Performance Benchmarking**: Response time and success rate tracking
3. **Provider Comparison**: Side-by-side result analysis
4. **Availability Monitoring**: Real-time provider status updates
5. **Device Compatibility**: Cross-platform testing validation

#### Test Coverage Requirements
- **Provider Functionality**: 100% core API coverage
- **Error Scenarios**: All error conditions and recovery paths
- **Performance Testing**: Response time and memory usage validation
- **Cross-Platform**: iOS and macOS compatibility verification
- **Integration Testing**: End-to-end workflow validation

## Security and Privacy Specifications

### Privacy-First Design

#### Data Handling Principles
1. **On-Device Priority**: Prefer MLX Swift for sensitive content
2. **User Control**: Allow manual provider selection
3. **Transparency**: Clear indication of which provider is being used
4. **No Data Retention**: Ensure providers don't store conversation history

#### Content Classification
- **High Sensitivity**: Personal information, financial data, health records → MLX Swift
- **Medium Sensitivity**: Work documents, private communications → User choice
- **Low Sensitivity**: General queries, public information → Foundation Models

### Device Eligibility

#### MLX Swift Requirements
- **Hardware**: Apple Silicon (M1/M2/M3/A15+)
- **Platform**: Real hardware only (no simulator support)
- **Memory**: Minimum 8GB unified memory recommended
- **Storage**: 3-8GB available for model files

#### Foundation Models Requirements
- **iOS Version**: 26.0+ (Beta)
- **Apple Intelligence**: Must be enabled in Settings
- **Device Support**: iPhone 15 Pro+, iPad Pro/Air M1+, Apple Silicon Macs
- **Network**: Initial setup may require internet connectivity

## API Specifications

### Core Provider Interface

#### WorkingMLXProvider
```swift
public class WorkingMLXProvider: ObservableObject {
    // Model management
    public func loadModel(_ model: MLXModel) async throws
    public func unloadModel() async
    
    // Inference
    public func generateResponse(to prompt: String) async throws -> String
    public func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error>
    
    // Status and info
    public var isReady: Bool
    public var isMLXSupported: Bool
    public func getModelInfo() -> WorkingModelInfo?
}
```

#### RealFoundationModelsProvider
```swift
@available(iOS 26.0, macOS 26.0, *)
public class RealFoundationModelsProvider: ObservableObject {
    // Text generation
    public func generateText(prompt: String, useCase: FoundationModelUseCase) async throws -> String
    
    // Structured generation
    public func generateWithGuidance<T: Generable>(prompt: String, type: T.Type) async throws -> T
    
    // Status and capabilities
    public var isAvailable: Bool
    public func getCapabilities() -> FoundationModelCapabilities
}
```

#### EnhancedGemma3nCore
```swift
@available(iOS 26.0, macOS 26.0, *)
class EnhancedGemma3nCore: ObservableObject {
    // Orchestration
    public func setup() async
    public func processText(_ text: String, forceProvider: AIProviderType?) async -> String
    
    // Advanced features
    public func generateStructured<T: Generable>(prompt: String, type: T.Type) async throws -> T
    public func extractEntities(from text: String) async throws -> ExtractedEntities
    public func summarizeContent(_ text: String) async throws -> SummarizedContent
    
    // Management
    public func getProviderStatus() -> ProviderStatus
    public func setActiveProvider(_ provider: AIProviderType)
}
```

## Integration Specifications

### Memory Agent Integration

#### Enhanced Memory Extraction
```swift
// Use structured generation for better memory management
let entities = try await core.extractEntities(from: userInput)
let summary = try await core.summarizeContent(conversationContext)

// Integrate with existing memory systems
memoryAgent.processEntities(entities)
memoryAgent.addSummary(summary)
```

#### Privacy-Aware Processing
```swift
// Analyze content sensitivity
let privacyLevel = privacyAnalyzer.analyze(content)

// Route based on sensitivity
let provider: AIProviderType = privacyLevel.isHighSensitivity ? .mlx : .automatic
let response = await core.processText(content, forceProvider: provider)
```

### UI Integration

#### Provider Status Display
- Real-time provider availability indicators
- Model loading progress for MLX Swift
- Apple Intelligence status for Foundation Models
- Manual provider selection controls

#### Testing Interface
- Concurrent provider testing capabilities
- Performance comparison visualizations
- Error reporting and debugging tools
- Example prompt library for testing

## Deployment Specifications

### Release Strategy

#### Phase 1: Core Provider Implementation ✅ **Complete**
- WorkingMLXProvider with real MLX Swift 0.25.6 APIs
- RealFoundationModelsProvider with iOS 26.0+ integration
- Basic provider selection and fallback mechanisms

#### Phase 2: Enhanced Orchestration ✅ **Complete**
- EnhancedGemma3nCore with automatic routing
- Comprehensive error handling and recovery
- UnifiedAITestView for validation and testing

#### Phase 3: Advanced Features 🚧 **In Progress**
- @Generable protocol integration for structured generation
- Enhanced memory extraction using structured output
- Performance optimization and memory management

#### Phase 4: Production Optimization 📋 **Planned**
- Advanced caching and preloading strategies
- Enhanced provider selection algorithms
- Comprehensive analytics and monitoring

### Version Compatibility

#### Backward Compatibility
- Graceful degradation on older iOS versions
- Clear feature availability messaging
- Fallback to available providers when newer features unavailable

#### Forward Compatibility
- Extensible architecture for future AI providers
- Modular design for easy integration of new capabilities
- Version-aware feature detection and enablement

## Success Metrics

### Performance Metrics
- **Response Time**: < 5 seconds average across all providers
- **Success Rate**: > 95% successful inference attempts
- **Availability**: > 99% provider availability during normal operation
- **Memory Efficiency**: < 8GB maximum memory usage for largest models

### User Experience Metrics
- **Seamless Operation**: Users shouldn't notice provider switching
- **Reliability**: Consistent responses across different providers
- **Privacy Assurance**: Clear indication of data processing location
- **Error Recovery**: Graceful handling of all error scenarios

### Technical Metrics
- **Test Coverage**: > 90% code coverage for all provider components
- **Cross-Platform**: 100% feature parity between iOS and macOS
- **Resource Usage**: Efficient memory and CPU utilization
- **Extensibility**: Easy integration of new providers and capabilities

## Documentation Requirements

### Developer Documentation
- Complete API reference for all provider classes
- Integration examples and best practices
- Error handling and troubleshooting guides
- Performance optimization recommendations

### User Documentation
- Provider selection and configuration guides
- Privacy and security explanations
- Troubleshooting common issues
- Feature availability and requirements

### Architectural Documentation
- System design and component interaction diagrams
- Provider selection logic and routing algorithms
- Integration patterns and extension points
- Performance characteristics and optimization strategies

## Navigation

- **← Back to [Specifications Index](README.md)**
- **→ Architecture: [AI Provider Architecture](../architecture/AI_PROVIDER_ARCHITECTURE.md)**
- **→ API Reference: [AI Provider APIs](../api/AI_PROVIDERS.md)**

---

*Last updated: 2025-07-19 - Production AI provider specification complete*