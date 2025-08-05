# Implementation Guides

This directory contains practical implementation guides, troubleshooting documentation, and production AI provider integration logs for ProjectOne development.

## Documents

### 🧪 [AI Provider Testing Suite](AI_PROVIDER_TESTING.md) ⭐ **Latest**
Comprehensive guide for testing and comparing all AI providers:
- Enhanced testing interface with provider management
- Local (MLX, Apple Foundation) and external (OpenAI, Ollama, OpenRouter) providers
- Performance benchmarking and comparison tools
- Configuration management and troubleshooting

### 💾 [SwiftData Implementation Guide](SWIFTDATA_IMPLEMENTATION_GUIDE.md)
Best practices for SwiftData usage:
- Model design patterns
- Relationship configurations
- Query optimization
- Performance considerations

### 🔧 [SwiftData Crash Fixes](SWIFTDATA_CRASH_FIXES.md)
Solutions to common SwiftData crashes:
- Memory management issues
- Relationship handling problems
- Context management patterns
- Debugging strategies

### 🐛 [Sentry Issues Fixes](SENTRY_ISSUES_FIXES.md)
Production issue analysis and resolutions:
- Crash pattern analysis
- Performance optimization fixes
- Error handling improvements
- Monitoring best practices

### 🎯 [MLX Swift Correct API Usage](MLX_SWIFT_CORRECT_API_USAGE.md) ⭐ **Production Ready**
Complete guide to production MLX Swift 0.25.6 implementation:
- Real MLX Swift APIs with MLXLMCommon integration
- Community model loading and inference patterns
- WorkingMLXProvider implementation details
- Device compatibility and performance optimization

### 🧠 [Gemma-3n Model Selection Guide](GEMMA_3N_MODEL_SELECTION.md) ⭐ **Latest Research**
Comprehensive model selection strategy based on MLX community research:
- Optimal Gemma-3n variants for Mac and iOS platforms
- MatFormer architecture and selective parameter activation
- Performance benchmarks and memory requirements
- Platform-specific recommendations and deployment strategies

### ✅ [MLX Gemma3n Implementation Complete](MLX_GEMMA3N_IMPLEMENTATION_COMPLETE.md)
End-to-end MLX Swift integration documentation:
- Production-ready MLX provider implementation
- Real model loading with community hub integration
- Comprehensive testing and validation results
- Performance benchmarking and optimization

### 🤖 [MLX Swift Integration Session](MLX_SWIFT_INTEGRATION_SESSION.md)
Historical session log from early MLX Swift integration work:
- Initial integration process documentation
- Challenges and solutions encountered during development
- Configuration steps and setup procedures
- Early testing and validation results

### 🎵 [Audio Recording Implementation](AUDIO_RECORDING_IMPLEMENTATION.md)
Complete implementation guide for the audio recording system:
- AudioPlayer and AppleSpeechEngine architecture
- Cross-platform audio session management
- SwiftData integration for recording metadata
- UI components and playback controls
- iOS Simulator fallback strategy
- Testing and troubleshooting guide

### 🔍 [Vector Similarity Search Implementation](VECTOR_SIMILARITY_SEARCH_IMPLEMENTATION.md) ✅ **Complete**
Comprehensive guide for semantic vector search using local MLX embeddings:
- Model selection and configuration guide
- Performance optimization strategies
- Migration and setup procedures
- Troubleshooting and best practices
- Integration examples with SwiftUI and Combine
- Advanced usage patterns and customization

### 📱 [iOS Simulator Fallback Strategy](IOS_SIMULATOR_FALLBACK_STRATEGY.md)
Comprehensive guide to the iOS Simulator fallback strategy implementation:
- WhisperKit CoreML compatibility issues and solutions
- Multi-layer fallback architecture with Apple Speech prioritization
- Background model preloading and dynamic configuration updates
- Enhanced CoreML error detection and graceful degradation
- Technical deep dive and performance analysis

## Navigation

- **← Back to [Main Documentation](../README.md)**
- **→ System Design: [Architecture](../architecture/README.md)**
- **→ Feature Specs: [Specifications](../specifications/README.md)**

## Quick Troubleshooting

### Common Issues
- **MLX Swift Setup**: See [MLX Swift Correct API Usage](MLX_SWIFT_CORRECT_API_USAGE.md)
- **AI Provider Integration**: Check [MLX Gemma3n Implementation Complete](MLX_GEMMA3N_IMPLEMENTATION_COMPLETE.md)
- **SwiftData Crashes**: See [SwiftData Crash Fixes](SWIFTDATA_CRASH_FIXES.md)
- **Audio Recording**: Check [Audio Recording Implementation](AUDIO_RECORDING_IMPLEMENTATION.md)
- **iOS Simulator Crashes**: See [iOS Simulator Fallback Strategy](IOS_SIMULATOR_FALLBACK_STRATEGY.md)

### Development Workflow
1. Check implementation guides for best practices
2. Review troubleshooting docs for known issues
3. Follow session logs for integration examples