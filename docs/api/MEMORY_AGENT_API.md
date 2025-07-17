# Memory Agent API Documentation

## Overview

The Memory Agent API provides programmatic access to AI-powered memory management capabilities, including privacy analysis, RAG retrieval, and autonomous operations.

## Core Classes

### PrivacyAnalyzer

**Purpose**: Analyzes query and memory content privacy to determine processing routes.

#### Public Interface

```swift
public class PrivacyAnalyzer {
    public init()
    
    // Primary analysis method
    public func analyzePrivacy(
        query: String, 
        context: MemoryContext? = nil
    ) -> PrivacyAnalysis
    
    // Memory-specific analysis
    public func analyzeMemoryPrivacy(memory: Any) -> PrivacyAnalysis
    
    // Utility methods
    public func shouldUseOnDeviceProcessing(for analysis: PrivacyAnalysis) -> Bool
    public func getRecommendedContextSize(for analysis: PrivacyAnalysis) -> Int
    public func filterPersonalDataFromContext(
        _ context: MemoryContext, 
        targetLevel: PrivacyLevel
    ) -> MemoryContext
}
```

#### PrivacyAnalysis Structure

```swift
public struct PrivacyAnalysis {
    let level: PrivacyLevel                // Privacy classification
    let personalIndicators: [String]       // Detected personal terms
    let sensitiveEntities: [String]        // Sensitive data found
    let riskFactors: [String]             // Risk assessment factors
    let confidence: Double                // Classification confidence
    let requiresOnDevice: Bool            // Processing requirement
}
```

#### PrivacyLevel Enum

```swift
public enum PrivacyLevel: CustomStringConvertible {
    case publicKnowledge    // General facts → Cloud OK
    case contextual         // Context-dependent → Limited cloud
    case personal          // Personal data → On-device preferred
    case sensitive         // Health/Financial → On-device only
    
    public var requiresOnDevice: Bool { /* implementation */ }
    public var maxContextSize: Int { /* implementation */ }
}
```

#### Usage Examples

```swift
// Basic privacy analysis
let analyzer = PrivacyAnalyzer()
let analysis = analyzer.analyzePrivacy(query: "My doctor's appointment tomorrow")

print(analysis.level)              // .personal
print(analysis.requiresOnDevice)   // true
print(analysis.personalIndicators) // ["my", "i"]

// Check processing requirements
if analyzer.shouldUseOnDeviceProcessing(for: analysis) {
    // Route to on-device processing
    processOnDevice(query, contextSize: analysis.level.maxContextSize)
} else {
    // Safe for cloud processing
    processInCloud(query)
}

// Filter context for external processing
let filteredContext = analyzer.filterPersonalDataFromContext(
    context, 
    targetLevel: .publicKnowledge
)
```

---

### MemoryRetrievalEngine

**Purpose**: Advanced RAG-based memory retrieval with semantic ranking.

#### Public Interface

```swift
public class MemoryRetrievalEngine: ObservableObject {
    public init(modelContext: ModelContext)
    
    // Primary retrieval method
    public func retrieveRelevantMemories(
        for query: String,
        configuration: RetrievalConfiguration = .default
    ) async throws -> MemoryContext
}
```

#### RetrievalConfiguration

```swift
public struct RetrievalConfiguration {
    let maxResults: Int
    let recencyWeight: Double      // 0.0 to 1.0
    let relevanceWeight: Double    // 0.0 to 1.0
    let semanticThreshold: Double  // Quality filter
    let includeSTM: Bool
    let includeLTM: Bool
    let includeEpisodic: Bool
    let includeEntities: Bool
    let includeNotes: Bool
    
    public static let `default`: RetrievalConfiguration
    public static let personalFocus: RetrievalConfiguration
}
```

#### Usage Examples

```swift
// Basic memory retrieval
let retrievalEngine = MemoryRetrievalEngine(modelContext: context)
let memoryContext = try await retrievalEngine.retrieveRelevantMemories(
    for: "Tell me about my recent project meetings"
)

print("Found \(memoryContext.shortTermMemories.count) STM entries")
print("Found \(memoryContext.entities.count) related entities")

// Custom configuration for personal queries
let personalConfig = RetrievalConfiguration.personalFocus
let personalContext = try await retrievalEngine.retrieveRelevantMemories(
    for: "My health appointments this month",
    configuration: personalConfig
)

// Access retrieved data
for stm in personalContext.shortTermMemories {
    print("STM: \(stm.content)")
}

for entity in personalContext.entities {
    print("Entity: \(entity.name) (\(entity.type))")
}
```

---

### AppleFoundationModelsProvider

**Purpose**: Native Apple AI integration with privacy-aware routing.

#### Public Interface

```swift
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public class AppleFoundationModelsProvider: ObservableObject {
    public static let shared: AppleFoundationModelsProvider
    
    // Core processing methods
    public func processQuery(
        _ query: String,
        context: MemoryContext,
        privacyLevel: PrivacyLevel
    ) async throws -> AIResponse
    
    public func processMemoryIngest(
        _ data: MemoryIngestData
    ) async throws -> ProcessedMemory
    
    // Capability checking
    public func isOnDeviceProcessingAvailable() -> Bool
    public func getRecommendedProcessingRoute(
        for privacyLevel: PrivacyLevel
    ) -> ProcessingRoute
}
```

#### Supporting Types

```swift
public struct AIResponse {
    let content: String
    let confidence: Double
    let processingRoute: ProcessingRoute
    let contextUsed: Bool
}

public enum ProcessingRoute {
    case onDevice
    case cloud
    case hybrid
}

public struct MemoryIngestData {
    let type: MemoryType
    let content: String
    let timestamp: Date
    let confidence: Double
    let metadata: [String: Any]
}
```

#### Usage Examples

```swift
// Check capabilities and process query
let provider = AppleFoundationModelsProvider.shared

if provider.isOnDeviceProcessingAvailable() {
    let response = try await provider.processQuery(
        "Summarize my recent work notes",
        context: memoryContext,
        privacyLevel: .personal
    )
    
    print("Response: \(response.content)")
    print("Processed \(response.processingRoute)")
    print("Used context: \(response.contextUsed)")
}

// Memory ingestion
let memoryData = MemoryIngestData(
    type: .note,
    content: "Important meeting notes about Q2 planning",
    timestamp: Date(),
    confidence: 0.9,
    metadata: ["source": "voice_recording"]
)

let processed = try await provider.processMemoryIngest(memoryData)
```

---

### MemoryAgentOrchestrator

**Purpose**: Autonomous memory system operations and maintenance.

#### Public Interface

```swift
public class MemoryAgentOrchestrator: ObservableObject {
    public init(modelContext: ModelContext)
    
    // Control methods
    public func startAutonomousOperations()
    public func stopAutonomousOperations()
    public func scheduleAction(_ action: AutonomousActionType)
    
    // Status monitoring
    public var isRunning: Bool { get }
    public var lastActionTimestamp: Date? { get }
    public var queuedActions: [AutonomousActionType] { get }
}
```

#### AutonomousActionType

```swift
public enum AutonomousActionType: CustomStringConvertible {
    case memoryConsolidation
    case entityExtraction
    case knowledgeGraphUpdate
    case proactiveNotification
    case memoryCleanup
    
    public var description: String { /* implementation */ }
}
```

#### Usage Examples

```swift
// Start autonomous operations
let orchestrator = MemoryAgentOrchestrator(modelContext: context)
orchestrator.startAutonomousOperations()

// Monitor status
print("Orchestrator running: \(orchestrator.isRunning)")
print("Queued actions: \(orchestrator.queuedActions)")

// Manual action scheduling
orchestrator.scheduleAction(.memoryConsolidation)

// Stop when needed
orchestrator.stopAutonomousOperations()
```

---

### MemoryAgentIntegration

**Purpose**: Bridge between Memory Agent and app components.

#### Public Interface

```swift
public class MemoryAgentIntegration: ObservableObject {
    public init(modelContext: ModelContext)
    
    // Sync operations
    public func syncProcessedNotes() async
    public func syncRecordingTranscriptions() async
    public func syncKnowledgeGraph() async
    
    // Manual operations
    public func ingestMemory(_ data: MemoryIngestData) async throws
    public func consolidateMemories() async throws
    public func updateEntities() async throws
}
```

#### Usage Examples

```swift
// Initialize integration
let integration = MemoryAgentIntegration(modelContext: context)

// Sync all data sources
await integration.syncProcessedNotes()
await integration.syncRecordingTranscriptions()
await integration.syncKnowledgeGraph()

// Manual memory ingestion
let noteData = MemoryIngestData(
    type: .note,
    content: noteContent,
    timestamp: Date(),
    confidence: 1.0,
    metadata: ["noteId": note.id.uuidString]
)

try await integration.ingestMemory(noteData)
```

---

## Data Models

### MemoryContext

**Purpose**: Structured container for retrieved memory data.

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
    
    public init(/* parameters */)
}
```

### Memory Entry Types

#### STMEntry (Short-Term Memory)

```swift
@Model
public final class STMEntry {
    public var id: UUID
    public var content: String
    public var timestamp: Date
    public var memoryType: MemoryType
    public var confidence: Double
    public var isConsolidated: Bool
    
    public init(/* parameters */)
}
```

#### LTMEntry (Long-Term Memory)

```swift
@Model
public final class LTMEntry {
    public var id: UUID
    public var content: String
    public var summary: String
    public var importance: Double
    public var lastAccessed: Date
    public var accessCount: Int
    
    public init(/* parameters */)
}
```

#### EpisodicMemoryEntry

```swift
@Model
public final class EpisodicMemoryEntry {
    public var id: UUID
    public var eventDescription: String
    public var timestamp: Date
    public var location: String?
    public var participants: [String]
    public var contextualCues: [String]
    public var emotionalContext: String?
    
    public init(/* parameters */)
}
```

---

## Testing API

### MemoryAgentTestRunner

**Purpose**: Comprehensive testing utilities for Memory Agent components.

```swift
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public class MemoryAgentTestRunner {
    
    // Individual test methods
    public static func testAIProviderInitialization()
    public static func testMemoryContextCreation()
    public static func testRouting()
    public static func testRAGRetrieval()
    
    // Comprehensive test suite
    public static func runAllTests()
}
```

#### Usage Examples

```swift
// Run all tests
MemoryAgentTestRunner.runAllTests()

// Run specific test categories
MemoryAgentTestRunner.testPrivacyAnalysis()
MemoryAgentTestRunner.testRAGRetrieval()
```

---

## Error Handling

### Common Errors

```swift
public enum MemoryAgentError: Error {
    case modelContextUnavailable
    case privacyAnalysisFailed
    case retrievalTimeout
    case onDeviceProcessingUnavailable
    case invalidMemoryData
    case orchestratorNotRunning
}
```

### Error Handling Patterns

```swift
do {
    let context = try await retrievalEngine.retrieveRelevantMemories(for: query)
    // Process context
} catch MemoryAgentError.retrievalTimeout {
    // Handle timeout
} catch MemoryAgentError.modelContextUnavailable {
    // Handle data unavailability
} catch {
    // Handle unexpected errors
}
```

---

## Performance Guidelines

### Best Practices

1. **Async/Await Usage**: Always use async methods for memory operations
2. **Context Filtering**: Apply privacy filters before external processing
3. **Batch Operations**: Group multiple memory operations when possible
4. **Cache Management**: Leverage semantic caching for repeated queries
5. **Resource Monitoring**: Check device capabilities before heavy operations

### Performance Characteristics

- **Privacy Analysis**: <100ms for typical queries
- **Memory Retrieval**: <500ms for standard configurations
- **Context Assembly**: <200ms for filtered contexts
- **Total Latency**: <800ms end-to-end for complete flow

---

**Next**: [Implementation Guides](../guides/) | **Back**: [Architecture](../architecture/)