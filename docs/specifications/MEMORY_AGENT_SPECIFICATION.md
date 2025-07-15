# Memory Agent Specification

**Status**: In Development  
**Date**: 2025-07-15  
**Priority**: High  
**Version**: 2.0

## Overview

The Memory Agent is the central intelligence of ProjectOne's agentic framework, implementing the Perception-Reasoning-Action model described in ADR 002. It serves as an autonomous AI agent that owns and manages the knowledge graph while making intelligent routing decisions between Apple Foundation Models and external AI models. The Memory Agent transforms from passive storage into an active reasoning engine that autonomously consolidates memories, surfaces relevant context, and protects user privacy.

## Core Responsibilities

### 1. Autonomous Memory Management
- **Direct ownership** of the knowledge graph (entities, relationships, metadata)
- **Intelligent consolidation** from Short-Term Memory (STM) to Long-Term Memory (LTM)
- **Context creation** from relevant memories for model interactions
- **Privacy enforcement** ensuring personal data never leaves the device inappropriately
- **Proactive memory maintenance** including cleanup, optimization, and pattern recognition

### 2. Intelligent Model Selection & Routing
- **Request analysis** to determine if query relates to personal data or general knowledge
- **Model selection** between Apple Foundation Models (iOS 26+), Gemma3n, and external APIs
- **Privacy boundary enforcement** as described in ADR 002's "Golden Rule"
- **Performance optimization** choosing the most appropriate model for each task
- **Extensible architecture** supporting future model additions

### 3. Agentic Framework Implementation
- **Perception**: Ingests data from transcriptions, HealthKit, and existing knowledge graph
- **Reasoning**: Uses Apple Foundation Models or Gemma3n with memory context for personal queries
- **Action**: Executes through tool selection (internal memory ops, external API calls, notifications)
- **Learning**: Continuously improves memory consolidation and retrieval patterns

## Architecture

```
Memory Agent (Autonomous AI Agent)
├── Memory System (owned)
│   ├── Short-Term Memory (STM)
│   ├── Working Memory
│   ├── Long-Term Memory (LTM)
│   │   ├── Episodic Memory
│   │   ├── Semantic Memory
│   │   └── Procedural Memory
│   └── Knowledge Graph
│       ├── Entities
│       ├── Relationships
│       └── Metadata
├── AI Model Providers (extensible)
│   ├── Apple Foundation Models (iOS 26+) - PRIMARY
│   ├── Gemma3n Provider (future)
│   └── External API Provider (privacy-filtered)
├── Reasoning Engine
│   ├── Privacy Analyzer
│   ├── Context Builder
│   ├── Model Selector
│   ├── Memory Consolidation Engine
│   └── Proactive Insight Generator
└── Agent Orchestration
    ├── Tool Execution Engine
    ├── Inter-Agent Communication
    └── Autonomous Decision Making
```

## Key Features

### Apple Foundation Models Integration
- **On-Device Intelligence**: 3B parameter model running entirely on Apple Silicon
- **Privacy-First**: All personal data processing happens on-device
- **Performance**: Sub-second response times with memory context
- **Availability**: iOS 26.0+ and macOS 26.0+ with automatic availability detection

### Privacy-First Design
- All personal data (transcripts, HealthKit, knowledge graph) remains on-device
- Apple Foundation Models process personal queries without network requests
- Intelligent filtering prevents personal context from reaching external APIs
- Clear user indicators when external models are used

### Context-Aware Processing
- Pulls relevant memories to create rich context for Apple Foundation Models
- Correlates data across sources (e.g., transcript events + HealthKit data)
- Maintains conversation history and long-term memory on-device
- Leverages Apple Foundation Models' understanding of personal context

### Adaptive Model Selection
- Personal queries → Apple Foundation Models (iOS 26+) with memory context
- General knowledge → External API without personal data
- Complex reasoning → Hybrid approach with privacy preservation
- Fallback support → Extensible architecture for Gemma3n and future models

## Integration Points

### Input Sources
- **Speech Transcription**: Receives transcribed text via MemoryIngestionService
- **HealthKit**: Processes health data with user permission using Apple Foundation Models
- **User Interactions**: Direct queries and commands processed through AI model routing
- **Knowledge Graph**: Existing entities and relationships for context building

### Output Interfaces
- **Knowledge Graph Updates**: Maintains and evolves the user's personal knowledge base
- **Response Generation**: Contextual responses using Apple Foundation Models or external APIs
- **Proactive Notifications**: AI-generated suggestions based on memory analysis
- **Memory Consolidation**: Autonomous STM → LTM transfers with reasoning

### Model Integration Points
- **Apple Foundation Models**: Primary processing for personal data queries
- **External APIs**: General knowledge queries with privacy filtering
- **Fallback Architecture**: Graceful degradation for older iOS versions
- **Future Extensions**: Pluggable architecture for Gemma3n and custom models

## Implementation Phases

### Phase 1: Core Memory Management
- Basic knowledge graph ownership and CRUD operations
- Apple Foundation Models provider implementation (iOS 26+)
- Privacy boundary enforcement with on-device processing

### Phase 2: Entity Extraction Integration
- Move entity extraction from transcription layer to Memory Agent
- Implement context-aware entity recognition using Apple Foundation Models
- Relationship detection and knowledge graph updates
- Extensible model architecture for future Gemma3n support

### Phase 3: Advanced Reasoning
- Sophisticated context building from multiple memory sources
- Proactive suggestion generation based on memory patterns
- Multi-turn conversation support with memory persistence
- Autonomous memory consolidation and insight generation

## Success Criteria

1. **Privacy Preservation**: Zero personal data leakage to external APIs
2. **Performance**: Sub-second response times using Apple Foundation Models
3. **Accuracy**: High-quality responses with rich memory context
4. **User Experience**: Seamless on-device processing with Apple Foundation Models
5. **Memory Quality**: Continuously improving knowledge graph accuracy
6. **Model Integration**: Smooth fallback to external models for general queries
7. **Extensibility**: Clean architecture supporting future model additions
8. **Autonomy**: Proactive memory consolidation and insight generation

## Technical Implementation

### Apple Foundation Models Integration
- **Primary Model**: Apple Foundation Models (3B parameters, iOS 26+)
- **On-Device Processing**: All personal data remains on device
- **Privacy-First**: No personal context sent to external APIs
- **Performance**: Optimized for Apple Silicon with sub-second response times

### Extensible Model Architecture
```swift
protocol AIModelProvider {
    func generateResponse(prompt: String, context: MemoryContext) async throws -> String
    func isAvailable() -> Bool
    func supportsPersonalData() -> Bool
    func estimatedResponseTime() -> TimeInterval
}

class AppleFoundationModelsProvider: AIModelProvider {
    @available(iOS 26.0, macOS 26.0, *)
    func generateResponse(prompt: String, context: MemoryContext) async throws -> String
}

class ExternalModelProvider: AIModelProvider {
    func generateResponse(prompt: String, context: MemoryContext) async throws -> String
}
```

### Model Selection Engine
- **Personal Data Detection**: Analyze query for personal information
- **Model Routing**: Route personal queries to on-device Apple Foundation Models
- **Privacy Filtering**: Strip personal context for external model queries
- **Performance Optimization**: Select optimal model based on query complexity

## Future Considerations

- Integration with additional on-device models (Gemma3n, custom fine-tuned models)
- Advanced memory search and retrieval algorithms
- Integration with additional data sources (calendar, location, etc.)
- Multi-modal memory support (images, audio, documents)
- Model performance analytics and optimization

---

This specification implements the central intelligence described in ADR 002 while maintaining the privacy-first, on-device approach that defines ProjectOne's architecture.