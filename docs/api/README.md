# API Documentation

Code-level documentation for ProjectOne production AI providers, memory systems, and core services.

## Available Documentation

### 🤖 [AI Provider APIs](AI_PROVIDERS.md)
Production AI provider system with real implementations:
- **WorkingMLXProvider**: MLX Swift 0.25.6 with real community models
- **RealFoundationModelsProvider**: iOS 26.0+ SystemLanguageModel integration
- **EnhancedGemma3nCore**: Dual provider system with automatic routing
- **AppleIntelligenceProvider**: Device eligibility and feature detection
- **UnifiedAITestView**: Concurrent testing framework for all providers

### 🧠 [Memory Agent API](MEMORY_AGENT_API.md)
Complete API reference for the Memory Agent system:
- **PrivacyAnalyzer**: Query and memory privacy analysis
- **MemoryRetrievalEngine**: RAG-based memory retrieval with ranking
- **MemoryAgentOrchestrator**: Autonomous memory operations
- **Data Models**: Memory types, contexts, and configurations
- **Testing API**: Comprehensive test utilities

### 🍎 [Foundation Models API](FOUNDATION_MODELS_API.md)
Complete reference for Apple's Foundation Models framework (iOS 26.0+):
- **SystemLanguageModel**: Real device availability checking and model access
- **LanguageModelSession**: Session management with proper error handling
- **@Generable Protocol**: Structured content generation with Swift types
- **Guided Generation**: Entity extraction and structured summarization
- **Device Eligibility**: Apple Intelligence requirements and feature detection
- **Production Patterns**: Real API usage with availability monitoring

## Planned Documentation

### Service APIs
- **MLXIntegrationService**: MLX Swift model management and optimization
- **TranscriptionEngine**: Apple Speech Recognition integration
- **KnowledgeGraphService**: Entity and relationship management
- **MemoryAnalyticsService**: System monitoring and health metrics

### Data Models
- **Entity & Relationship**: Knowledge graph components
- **ProcessedNote**: Note processing and analysis
- **RecordingItem**: Audio metadata and transcriptions
- **Memory Models**: STM, LTM, Working, and Episodic memory

### UI Components
- **Liquid Glass Components**: Glass design system elements
- **Memory Dashboard**: Analytics and monitoring UI
- **Knowledge Graph Views**: Interactive visualization components

## Navigation

- **← Back to [Main Documentation](../README.md)**
- **→ System Design: [Architecture](../architecture/README.md)**
- **→ Implementation: [Guides](../guides/README.md)**

## Contributing

To add API documentation:
1. Use Swift DocC for in-code documentation
2. Generate documentation with Xcode's documentation compiler
3. Add high-level API guides to this directory
4. Cross-reference with architecture and implementation guides