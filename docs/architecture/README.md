# Architecture Documentation

This directory contains comprehensive system architecture documentation for ProjectOne.

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
UI Layer → Service Layer → Data Layer → AI/ML Layer
    ↓           ↓            ↓           ↓
SwiftUI → Gemma3nCore → SwiftData → PlaceholderEngine
```

Memory Architecture: STM → Working Memory → LTM → Episodic Memory