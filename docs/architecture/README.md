# Architecture Documentation

This directory contains comprehensive system architecture documentation for ProjectOne's production AI provider system and dual-provider architecture.

## Documents

### 📋 [System Architecture Overview](SYSTEM_ARCHITECTURE_OVERVIEW.md)
Complete system overview including:
- Executive summary and current status
- High-level architecture diagrams
- Core component deep dive
- Data flow and memory architecture
- Technology stack and dependencies

### 🕸️ [Knowledge Graph Architecture](KNOWLEDGE_GRAPH_ARCHITECTURE.md)
Knowledge graph visualization system:
- Component architecture and relationships
- Class diagrams and data models
- Sequence diagrams for user interactions
- Implementation patterns and best practices

### 🧠 [Memory Agent Architecture](MEMORY_AGENT_ARCHITECTURE.md)
AI-powered memory management system:
- Privacy-first architecture with automatic routing
- RAG (Retrieval-Augmented Generation) implementation
- Agentic framework for autonomous operations
- Dual AI provider integration (MLX Swift + Foundation Models)
- Comprehensive testing and monitoring

### 🤖 [AI Provider Architecture](AI_PROVIDER_ARCHITECTURE.md)
Production dual AI provider system:
- MLX Swift 0.25.6 integration with real community models
- iOS 26.0+ Foundation Models with SystemLanguageModel
- EnhancedGemma3nCore orchestration and automatic routing
- Device compatibility and availability checking
- @Generable protocol for structured generation

### 🤖 [ADR-004: Agent-Centric Architecture](ADR_004_Agent_Centric_Architecture.md)
Decision record for refactoring to a modular, agent-based system to enhance scalability and reduce complexity.

### 🔄 [Object Interaction Diagrams](OBJECT_INTERACTION_DIAGRAMS.md)
Component interaction patterns:
- Runtime behavior documentation
- Sequence diagrams for key workflows
- Service layer interactions
- Data persistence patterns

## Navigation

- **← Back to [Main Documentation](../README.md)**
- **→ Next: [Implementation Guides](../guides/README.md)**
- **→ Feature Specs: [Specifications](../specifications/README.md)**

## Architecture Quick Reference

```
UI Layer → Memory Agent → Service Layer → Data Layer → AI/ML Layer
    ↓           ↓             ↓            ↓           ↓
SwiftUI → Privacy/RAG → EnhancedGemma3nCore → SwiftData → Dual AI Providers
                                                              ↓
                                            MLX Swift 0.25.6 + Foundation Models
```

Memory Architecture: STM → Working Memory → LTM → Episodic Memory
Memory Agent: Privacy Analysis → RAG Retrieval → Agentic Operations
AI Providers: MLX (on-device) ↔ Foundation Models (system) ↔ Automatic Routing