# Memory Agent Specification

**Status**: Planned  
**Date**: 2025-07-12  
**Priority**: High  

## Overview

The Memory Agent is the central intelligence of ProjectOne's agentic framework, implementing the Perception-Reasoning-Action model described in ADR 002. It serves as the single concrete implementation that owns and manages the knowledge graph while making intelligent routing decisions between on-device and remote AI models.

## Core Responsibilities

### 1. Memory Ownership
- **Direct ownership** of the knowledge graph (entities, relationships, metadata)
- **Memory management** including updates, queries, consistency maintenance
- **Context creation** from relevant memories for model interactions
- **Privacy enforcement** ensuring personal data never leaves the device inappropriately

### 2. Intelligent Routing
- **Request analysis** to determine if query relates to personal data or general knowledge
- **Model selection** between on-device Gemma and external API based on context
- **Privacy boundary enforcement** as described in ADR 002's "Golden Rule"
- **Performance optimization** choosing the most appropriate model for each task

### 3. Agentic Framework Implementation
- **Perception**: Ingests data from transcriptions, HealthKit, and existing knowledge graph
- **Reasoning**: Uses on-device Gemma model with memory context for personal queries
- **Action**: Executes through tool selection (internal memory ops, external API calls, notifications)

## Architecture

```
Memory Agent
├── Knowledge Graph (owned)
│   ├── Entities
│   ├── Relationships  
│   └── Metadata
├── On-Device Gemma Model (tool)
├── External API Tool (tool)
├── Routing Engine
│   ├── Privacy Analyzer
│   ├── Context Builder
│   └── Model Selector
└── Tool Execution Engine
```

## Key Features

### Privacy-First Design
- All personal data (transcripts, HealthKit, knowledge graph) remains on-device
- Intelligent filtering prevents personal context from reaching external APIs
- Clear user indicators when external models are used

### Context-Aware Processing
- Pulls relevant memories to create rich context for model interactions
- Correlates data across sources (e.g., transcript events + HealthKit data)
- Maintains conversation history and long-term memory

### Adaptive Model Selection
- Personal queries → On-device Gemma with memory context
- General knowledge → External API without personal data
- Complex reasoning → Hybrid approach with privacy preservation

## Integration Points

### Input Sources
- **Speech Transcription**: Receives transcribed text for entity extraction and memory updates
- **HealthKit**: Processes health data with user permission
- **User Interactions**: Direct queries and commands from the UI

### Output Interfaces
- **Knowledge Graph Updates**: Maintains and evolves the user's personal knowledge base
- **Response Generation**: Provides contextual responses using appropriate models
- **Proactive Notifications**: Suggests actions based on memory analysis

## Implementation Phases

### Phase 1: Core Memory Management
- Basic knowledge graph ownership and CRUD operations
- Simple routing between on-device and external models
- Privacy boundary enforcement

### Phase 2: Entity Extraction Integration
- Move entity extraction from transcription layer to Memory Agent
- Implement context-aware entity recognition using memory
- Relationship detection and knowledge graph updates

### Phase 3: Advanced Reasoning
- Sophisticated context building from multiple memory sources
- Proactive suggestion generation based on memory patterns
- Multi-turn conversation support with memory persistence

## Success Criteria

1. **Privacy Preservation**: Zero personal data leakage to external APIs
2. **Performance**: Sub-second response times for personal queries
3. **Accuracy**: High-quality responses using memory context
4. **User Experience**: Seamless switching between model types
5. **Memory Quality**: Continuously improving knowledge graph accuracy

## Future Considerations

- Fine-tuning on-device Gemma model with user-specific data
- Advanced memory search and retrieval algorithms
- Integration with additional data sources (calendar, location, etc.)
- Multi-modal memory support (images, audio, documents)

---

This specification implements the central intelligence described in ADR 002 while maintaining the privacy-first, on-device approach that defines ProjectOne's architecture.