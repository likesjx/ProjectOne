# Memory Agent Architecture

## Overview

The Memory Agent system is a sophisticated AI-powered memory management framework that provides privacy-first intelligent knowledge retrieval and autonomous memory operations. Built with Apple Foundation Models integration and SwiftData persistence, it implements a complete RAG (Retrieval-Augmented Generation) architecture with agentic capabilities.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Memory Agent System                      │
├─────────────────────────────────────────────────────────────┤
│  UI Layer           │ Memory Dashboard, Test Runner         │
├─────────────────────────────────────────────────────────────┤
│  Privacy Layer      │ Privacy Analyzer, Context Filtering   │
├─────────────────────────────────────────────────────────────┤
│  RAG Engine         │ Memory Retrieval, Ranking, Scoring    │
├─────────────────────────────────────────────────────────────┤
│  Agentic Layer      │ Orchestrator, Autonomous Operations   │
├─────────────────────────────────────────────────────────────┤
│  AI Layer           │ Apple Foundation Models Provider      │
├─────────────────────────────────────────────────────────────┤
│  Data Layer         │ SwiftData Models, Persistence         │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Privacy Analyzer (`PrivacyAnalyzer.swift`)

**Purpose**: Classifies queries and memory content based on privacy sensitivity to determine processing routing.

**Key Features**:
- **Privacy Levels**: Public Knowledge, Contextual, Personal, Sensitive
- **Automatic Routing**: On-device vs. cloud processing decisions
- **Context Filtering**: Removes sensitive data for external processing
- **Risk Assessment**: Identifies health, financial, and personal data

**Privacy Classifications**:
```swift
public enum PrivacyLevel {
    case publicKnowledge    // General facts → Cloud processing OK
    case contextual         // Context-dependent → Limited cloud
    case personal          // Personal data → On-device preferred
    case sensitive         // Health/Financial → On-device only
}
```

**Usage Example**:
```swift
let analyzer = PrivacyAnalyzer()
let analysis = analyzer.analyzePrivacy(query: "My doctor's appointment")
// Result: .personal level, requiresOnDevice: true
```

### 2. RAG Retrieval Engine (`MemoryRetrievalEngine.swift`)

**Purpose**: Advanced memory retrieval system with semantic ranking and multi-type memory access.

**Key Features**:
- **Multi-Type Retrieval**: STM, LTM, Episodic, Entities, Relationships, Notes
- **Semantic Scoring**: Relevance and recency-based ranking
- **Parallel Processing**: Async retrieval across memory types
- **Configurable Strategies**: Different configs for personal vs. general queries

**Retrieval Configuration**:
```swift
public struct RetrievalConfiguration {
    let maxResults: Int
    let recencyWeight: Double      // 0.0 to 1.0
    let relevanceWeight: Double    // 0.0 to 1.0
    let semanticThreshold: Double  // Quality filter
    // Memory type inclusion flags
}
```

**Scoring Algorithm**:
- Content relevance (exact/partial term matching)
- Recency scoring (time-based decay)
- Type-specific weighting
- Confidence thresholding

### 3. Apple Foundation Models Provider (`AppleFoundationModelsProvider.swift`)

**Purpose**: Native integration with Apple's on-device AI capabilities for privacy-conscious processing.

**Key Features**:
- **Privacy-Aware Routing**: Automatic on-device/cloud decisions
- **Context Optimization**: Token limit management based on privacy level
- **Fallback Strategy**: Graceful degradation when on-device unavailable
- **Memory Integration**: Uses retrieved context for enhanced responses

**Processing Flow**:
```
Query → Privacy Analysis → Context Retrieval → Processing Route Decision
                                           ↓
                     On-Device Processing ←→ Cloud Processing
                                           ↓
                              Enhanced Response with Memory Context
```

### 4. Agentic Orchestrator (`MemoryAgentOrchestrator.swift`)

**Purpose**: Manages autonomous background operations for memory system maintenance and optimization.

**Autonomous Actions**:
- **Memory Consolidation**: STM → LTM transfer based on importance
- **Entity Extraction**: Automatic entity recognition from new content
- **Knowledge Graph Updates**: Relationship discovery and maintenance
- **Proactive Notifications**: Context-aware suggestions
- **Memory Cleanup**: Removes obsolete or low-confidence memories

**Orchestration Logic**:
```swift
func scheduleAutonomousActions() {
    // Memory load assessment
    // Last consolidation timing
    // System resource availability
    // Priority-based action scheduling
}
```

### 5. Memory Integration (`MemoryAgentIntegration.swift`)

**Purpose**: Bridges the Memory Agent with existing app components and data sources.

**Integration Points**:
- **ProcessedNote Sync**: Real-time note processing and indexing
- **Audio Transcription**: Automatic memory creation from recordings
- **Knowledge Graph**: Entity and relationship management
- **Analytics**: Memory system health monitoring

## Data Models

### Memory Types

**STMEntry** (Short-Term Memory):
- Recent conversations and temporary data
- High volatility, automatic consolidation
- Fast retrieval for immediate context

**LTMEntry** (Long-Term Memory):
- Consolidated important information
- Summary + detailed content storage
- Confidence-based retention

**EpisodicMemoryEntry**:
- Personal experiences and events
- Participant, location, and context tracking
- Time-based organization

**Entity & Relationship**:
- Knowledge graph components
- Type classification (Person, Place, Concept, etc.)
- Relationship strength and context

### Memory Context Structure

```swift
public struct MemoryContext {
    let entities: [Entity]
    let relationships: [Relationship]
    let shortTermMemories: [STMEntry]
    let longTermMemories: [LTMEntry]
    let episodicMemories: [EpisodicMemoryEntry]
    let relevantNotes: [ProcessedNote]
    let timestamp: Date
    let userQuery: String
    let containsPersonalData: Bool
}
```

## Privacy Architecture

### Data Sensitivity Classification

1. **Public Knowledge** (32K tokens)
   - General facts and public information
   - Cloud processing acceptable
   - Full context sharing

2. **Contextual** (16K tokens)
   - Information that could be personal in context
   - Limited cloud processing
   - Filtered context sharing

3. **Personal** (8K tokens)
   - Clearly personal information
   - On-device processing preferred
   - Sanitized context for cloud

4. **Sensitive** (4K tokens)
   - Health, financial, highly personal data
   - On-device processing only
   - No external sharing

### Context Filtering

```swift
func filterPersonalDataFromContext(
    _ context: MemoryContext, 
    targetLevel: PrivacyLevel
) -> MemoryContext {
    // Remove/sanitize based on target privacy level
    // Maintain functionality while protecting privacy
}
```

## Performance Characteristics

### Retrieval Performance
- **Query Processing**: <100ms for term extraction
- **Memory Retrieval**: <500ms for standard queries
- **Context Assembly**: <200ms for filtered context
- **Total Latency**: <800ms end-to-end

### Memory Efficiency
- **Semantic Caching**: Reduces repeated retrievals
- **Incremental Updates**: Only processes changes
- **Background Processing**: Non-blocking consolidation
- **Resource Management**: Adaptive based on device capabilities

## Integration Points

### Audio Pipeline
```swift
// Automatic memory creation from transcriptions
func processTranscription(_ transcription: String) {
    let memoryData = MemoryIngestData(
        type: .transcription,
        content: transcription,
        timestamp: Date(),
        confidence: transcriptionConfidence
    )
    memoryAgent.ingestMemory(memoryData)
}
```

### Knowledge Graph
```swift
// Entity extraction and relationship discovery
func updateKnowledgeGraph() {
    let entities = textIngestionAgent.extractEntities(from: content)
    let relationships = knowledgeGraphService.discoverRelationships(entities)
    knowledgeGraphService.update(entities: entities, relationships: relationships)
}
```

### Analytics Dashboard
```swift
// Real-time system monitoring
class MemoryAnalyticsService {
    func collectMemorySnapshot() -> MemoryAnalytics
    func getHealthStatus() -> HealthStatus
    func getMemoryTrends() -> [MemoryTrend]
}
```

## Testing Strategy

### Comprehensive Test Suite

1. **Privacy Analysis Tests**
   - Query classification accuracy
   - Risk factor detection
   - Context filtering validation

2. **RAG Retrieval Tests**
   - Multi-type memory retrieval
   - Ranking algorithm validation
   - Performance benchmarks

3. **Integration Tests**
   - End-to-end memory flow
   - Cross-component communication
   - Error handling and recovery

4. **Agentic Tests**
   - Autonomous operation scheduling
   - Memory consolidation logic
   - System health maintenance

### Test Runner Integration

```swift
// Available through Memory Dashboard
MemoryAgentTestRunner.runAllTests()
```

## Future Enhancements

### Planned Features
- **Advanced Semantic Search**: Vector embeddings for improved relevance
- **Multi-Modal Memory**: Image and audio memory integration
- **Federated Learning**: Privacy-preserving model improvements
- **Real-Time Collaboration**: Shared knowledge graph updates

### Scalability Considerations
- **Horizontal Scaling**: Multi-device memory synchronization
- **Edge Computing**: Distributed memory processing
- **Adaptive Algorithms**: Self-improving retrieval and ranking

## Security Considerations

### Data Protection
- **Encryption at Rest**: All memory data encrypted
- **Transport Security**: TLS for cloud communications
- **Access Controls**: Fine-grained permission system
- **Audit Logging**: Comprehensive operation tracking

### Privacy Compliance
- **GDPR Compliance**: Right to deletion, data portability
- **CCPA Compliance**: Opt-out mechanisms, transparency
- **Apple Privacy**: Follows Apple's privacy guidelines
- **Local Processing**: Maximizes on-device computation

---

**Next**: [Implementation Guides](../guides/) | **Back**: [Architecture Overview](README.md)