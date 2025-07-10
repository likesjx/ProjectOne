# ProjectOne: Personal AI Knowledge System
## Comprehensive Architecture Documentation

### Overview
ProjectOne is a SwiftUI-based personal AI knowledge system that centers around **Gemma 3n** as the primary on-device reasoning engine. The system combines voice notes, text notes, HealthKit data, and a local knowledge graph to create an intelligent personal assistant with optional delegation to specialized AI agents.

## Core Principles
1. **Local-First**: All primary processing happens on-device with Gemma 3n
2. **Privacy-Focused**: Sensitive data stays local unless explicitly shared
3. **Extensible**: Modular agent system for specialized tasks
4. **Personalized**: Adaptive to user's speech patterns and preferences
5. **Memory-Driven**: Titans-inspired memory hierarchy for context retention

---

## System Architecture

### 1. Core Model Stack
```swift
class LocalModelStack {
    let gemma3n: MLXGemma3n           // Primary reasoning/transcription
    let encoder: MLXEncoder           // Vector embeddings (all-MiniLM-L6-v2)
    let whisper: MLXWhisper?          // Backup transcription if needed
    let personalAdapter: LoRAAdapter? // User-specific adaptations
}
```

### 2. Central Processing Engine
```swift
class Gemma3nCore: ObservableObject {
    private let modelStack: LocalModelStack
    private let memorySystem: TitansMemory
    private let knowledgeGraph: LocalKG
    private let userProfile: UserSpeechProfile
    
    // Primary interface - everything goes through Gemma 3n first
    func processInput(_ input: UserInput) async -> ProcessingResult
    func shouldDelegate(query: String, context: KGContext) async -> DelegationDecision
    func integrateAgentResult(_ result: AgentResult) async -> ProcessingResult
}
```

---

## Data Models

### 3. Unified Content Model
```swift
@Model class ProcessedNote {
    var id: UUID
    var timestamp: Date
    var sourceType: NoteSourceType // .audio, .text, .health
    var originalText: String
    var audioURL: URL?
    
    // Gemma 3n enrichment
    var summary: String
    var entities: [ExtractedEntity]
    var relationships: [ExtractedRelationship]
    var topics: [String]
    var sentiment: String?
    
    // Vector embedding for semantic search
    var embedding: [Float] // 384-dim for all-MiniLM-L6-v2
    
    // KG integration
    var kgEntities: [Entity]
    var kgRelationships: [Relationship]
    
    // Memory system
    var memoryTrace: MemoryTrace
    var accessFrequency: Int
    var lastAccessed: Date
    var consolidationLevel: ConsolidationLevel
}
```

### 4. Knowledge Graph Schema
```swift
@Model class Entity {
    var name: String
    var type: EntityType // .person, .concept, .location, .health_metric, etc.
    var description: String
    var embedding: [Float]
    var mentions: [ProcessedNote]
    var confidence: Double
    var createdDate: Date
    var lastUpdated: Date
}

@Model class Relationship {
    var subject: Entity
    var predicate: String
    var object: Entity
    var embedding: [Float]
    var confidence: Double
    var sourceNotes: [ProcessedNote]
    var temporal: TemporalInfo?
}

enum EntityType: String, CaseIterable {
    case person, concept, location, organization
    case healthMetric, activity, goal
    case project, task, meeting
    case document, reference, quote
}
```

### 5. Memory System (Titans-Inspired)
```swift
@Model class ShortTermMemory {
    var sessionId: UUID
    var workingSet: [MemoryItem]
    var attentionFocus: [EntityReference]
    var recentInteractions: [AgentInteraction]
    var temporaryBindings: [TemporaryRelationship]
}

@Model class LongTermMemory {
    var episodicMemory: [EpisodicEvent]
    var semanticMemory: [SemanticConcept]
    var proceduralMemory: [ProcedurePattern]
    var consolidatedKnowledge: [ConsolidatedFact]
}

@Model class MemoryTrace {
    var stmReferences: [STMReference]
    var ltmConnections: [LTMConnection]
    var episodicLinks: [EpisodicEvent]
    var emotionalValence: Double?
    var accessPattern: AccessPattern
}
```

### 6. User Personalization
```swift
@Model class UserSpeechProfile {
    var vocabulary: [String: String]     // "gonna" -> "going to"
    var phrases: [String: String]        // Common expressions
    var topics: [String: [String]]       // Domain-specific terms
    var corrections: [String: String]    // Historical corrections
    
    // Audio characteristics
    var averagePace: Double
    var commonFillerWords: [String]
    var pronunciationPatterns: [String: String]
    
    // Context patterns
    var timeOfDayPatterns: [String: SpeechStyle]
    var locationPatterns: [String: [String]]
    var moodIndicators: [String: EmotionalContext]
}
```

---

## Processing Pipelines

### 7. Unified Note Processing
```swift
class NoteProcessor {
    func processNote(_ input: NoteInput) async -> ProcessedNote {
        // Step 1: Convert to text (if needed)
        let text = switch input {
        case .text(let content): content
        case .audio(let url): await gemma3n.transcribeWithPersonalization(url)
        case .health(let data): await formatHealthData(data)
        }
        
        // Step 2: Gemma 3n enrichment
        let enrichment = await gemma3n.enrichNote(text, context: await getKGContext())
        
        // Step 3: Generate embeddings
        let embedding = await encoder.encode(text + enrichment.summary)
        
        // Step 4: Extract entities/relationships for KG
        return ProcessedNote(
            originalText: text,
            enrichment: enrichment,
            embedding: embedding,
            entities: enrichment.entities,
            relationships: enrichment.relationships
        )
    }
}
```

### 8. HealthKit Integration
```swift
@Model class HealthData {
    var id: UUID
    var type: HKSampleType
    var value: Double
    var unit: String
    var timestamp: Date
    var enrichment: HealthEnrichment?
    var correlations: [HealthCorrelation]
}

@Model class HealthEnrichment {
    var trends: [String]
    var correlations: [String]
    var insights: [String]
    var recommendations: [String]
    var kgConnections: [Entity] // Link to related entities
}
```

---

## AI Agent System

### 9. Agent Architecture
```swift
@Model class AIAgent {
    var id: UUID
    var name: String
    var description: String
    var model: AIModel // local or remote
    var mcpServers: [MCPServerConfig]
    var localTools: [LocalTool]
    var permissions: AgentPermissions
    var memoryState: AgentMemoryState
}

@Model class AIModel {
    var type: ModelType // .gemma3n, .gpt4, .claude, .local
    var endpoint: String?
    var apiKey: String? // encrypted
    var capabilities: [String]
}

@Model class AgentPermissions {
    var canRead: [EntityType]
    var canWrite: [EntityType]
    var timeRange: DateInterval?
    var dataTypes: [SourceType]
    var mcpToolAccess: [String]
}
```

### 10. MCP Integration
```swift
class ProjectOneMCPServer: MCPServer {
    var capabilities: MCPCapabilities {
        MCPCapabilities(
            tools: [
                "kg_query", "kg_search", "kg_add_entity", "kg_add_relationship",
                "health_query", "health_trends", "health_correlations",
                "create_note", "search_notes", "enrich_note",
                "export_subgraph", "export_timeline",
                "memory_consolidate", "semantic_search"
            ],
            resources: [
                "kg://entities", "kg://relationships", 
                "health://data", "notes://all", "memory://ltm"
            ]
        )
    }
}

@Model class MCPServerConfig {
    var name: String
    var endpoint: String // Local socket or remote
    var authentication: MCPAuth?
    var availableTools: [String]
    var resourceAccess: [String]
}
```

---

## Core Features

### 11. Semantic Search System
```swift
class SemanticSearch {
    private let vectorStore: VectorStore
    
    func findSimilarNotes(query: String, limit: Int = 10) async -> [ProcessedNote]
    func findRelatedEntities(entity: Entity) async -> [Entity]
    func semanticQuery(query: String, filters: SearchFilters) async -> SearchResults
    func temporalSearch(entity: Entity, timeRange: DateInterval) async -> [ProcessedNote]
}
```

### 12. Memory Consolidation
```swift
class MemoryConsolidationEngine {
    func consolidateSTMtoLTM() async
    func strengthenFrequentPathways() async
    func decayUnusedConnections() async
    func identifyEmergingPatterns() async -> [Pattern]
    func suggestKGExpansions() async -> [KGExpansion]
}
```

### 13. Context Management
```swift
protocol MemoryContextManager {
    func buildContext(for agent: AIAgent, query: String) async -> AgentContext
    func updateMemory(interaction: AgentInteraction) async
    func consolidateSession(sessionId: UUID) async
}

struct AgentContext {
    var relevantSTM: [MemoryItem]
    var activatedLTM: [SemanticConcept]
    var kgSubgraph: KGSubgraph
    var memoryHints: [MemoryHint]
    var userProfile: UserContextSnapshot
}
```

---

## User Interface

### 14. Main UI Architecture
```swift
struct ContentView: View {
    @StateObject private var gemmaCore = Gemma3nCore()
    @StateObject private var audioRecorder = AudioRecorder()
    @State private var currentNote = ""
    @State private var processingState: ProcessingState = .idle
    
    var body: some View {
        NavigationSplitView {
            VStack {
                // Note input (text + audio)
                NoteInputSection(
                    audioRecorder: audioRecorder,
                    textNote: $currentNote,
                    onSubmit: processNote
                )
                
                // Processing status
                ProcessingStatusView(state: processingState)
                
                // Recent notes with enrichment
                NotesListView(notes: gemmaCore.recentNotes)
            }
        } detail: {
            // KG browser, agent management, insights
            DetailView(selectedItem: selectedItem)
        }
    }
}
```

### 15. Agent Management UI
```swift
struct AgentManagementView: View {
    @StateObject private var agentManager = AgentManager()
    
    var body: some View {
        List {
            Section("Active Agents") {
                ForEach(agentManager.activeAgents) { agent in
                    AgentCardView(agent: agent)
                }
            }
            
            Section("Available Tools") {
                MCPToolsView(tools: agentManager.availableTools)
            }
            
            Section("Delegation History") {
                DelegationHistoryView(history: agentManager.delegationHistory)
            }
        }
    }
}
```

---

## Security & Privacy

### 16. Data Protection
- **Local encryption**: All data encrypted at rest using device keychain
- **API key management**: External agent keys stored securely
- **Permission system**: Granular control over agent access
- **Audit logging**: Track all data access and modifications
- **Data retention**: Configurable automatic archiving/deletion

### 17. Privacy Controls
- **Local-first processing**: Gemma 3n handles sensitive data locally
- **Selective sharing**: Choose what data to share with external agents
- **Anonymization**: Option to strip personal identifiers before delegation
- **Consent management**: Explicit consent for each external service

---

## Dependencies

### 18. Required Packages
```swift
// Package.swift dependencies
.package(url: "https://github.com/ml-explore/mlx-swift", from: "0.1.0")
.package(url: "https://github.com/anthropics/mcp-swift", from: "0.1.0")
.package(url: "https://github.com/apple/swift-collections", from: "1.0.0")

// Internal frameworks
import SwiftUI
import SwiftData
import AVFoundation
import HealthKit
import CoreML
import Foundation
```

### 19. Model Files
- **Gemma 3n**: Local MLX-optimized model (~4-8GB)
- **Encoder model**: all-MiniLM-L6-v2 MLX version (~100MB)
- **Optional Whisper**: Backup transcription model (~1GB)
- **LoRA adapters**: User-specific fine-tuning weights (~10-50MB)

---

## Performance Considerations

### 20. Optimization Strategies
- **Lazy loading**: Load models on-demand
- **Caching**: Vector embeddings and frequent queries
- **Background processing**: Non-urgent enrichment in background
- **Memory management**: Efficient STM/LTM transitions
- **Model quantization**: Reduce model size for mobile deployment

### 21. Scalability
- **Incremental updates**: Add to KG without full rebuilds
- **Archival system**: Move old data to compressed storage
- **Federation**: Optional sync between devices
- **Cloud backup**: Encrypted backup of KG structure only

---

This architecture provides a comprehensive foundation for a personal AI system that learns, adapts, and grows with the user while maintaining privacy and extensibility.