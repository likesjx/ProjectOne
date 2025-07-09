# Object Interaction Diagrams

## Overview

This document provides detailed object interaction diagrams showing how components in ProjectOne communicate and collaborate. These diagrams illustrate the runtime behavior and message flow between objects.

## 1. Audio Recording and Transcription Interaction

### Sequence Diagram: Audio Recording Flow

```mermaid
sequenceDiagram
    participant User
    participant ContentView
    participant AudioRecorder
    participant TranscriptionEngine
    participant PlaceholderEngine
    participant Gemma3nCore
    participant ProcessedNote
    participant Entity
    participant Relationship
    
    User->>ContentView: Tap Record Button
    ContentView->>AudioRecorder: startRecording()
    AudioRecorder->>AudioRecorder: requestMicrophonePermission()
    AudioRecorder->>TranscriptionEngine: beginTranscription()
    TranscriptionEngine->>PlaceholderEngine: processAudioData()
    
    loop Real-time Processing
        PlaceholderEngine->>PlaceholderEngine: analyzeAudioSegment()
        PlaceholderEngine->>TranscriptionEngine: updateTranscription()
        TranscriptionEngine->>AudioRecorder: onTranscriptionUpdate()
        AudioRecorder->>ContentView: updateUI()
    end
    
    User->>ContentView: Tap Stop Button
    ContentView->>AudioRecorder: stopRecording()
    AudioRecorder->>AudioRecorder: finalizeAudioFile()
    AudioRecorder->>TranscriptionEngine: finalizeTranscription()
    
    TranscriptionEngine->>PlaceholderEngine: extractEntities()
    PlaceholderEngine->>Entity: createEntity()
    PlaceholderEngine->>Relationship: createRelationship()
    
    TranscriptionEngine->>Gemma3nCore: processTranscription()
    Gemma3nCore->>ProcessedNote: createNote()
    Gemma3nCore->>ContentView: onProcessingComplete()
```

### Collaboration Diagram: Transcription Components

```mermaid
graph TB
    subgraph "User Interface"
        CV[ContentView]
        TAB[TranscriptionActionBar]
        TDV[TranscriptionDisplayView]
        TCView[TranscriptionCorrectionView]
    end
    
    subgraph "Audio Processing"
        AR[AudioRecorder]
        AS[AudioSession]
        AF[AudioFile]
    end
    
    subgraph "Transcription Engine"
        TE[TranscriptionEngine]
        PE[PlaceholderEngine]
        EE[EntityExtractor]
        RE[RelationshipExtractor]
    end
    
    subgraph "AI Core"
        GC[Gemma3nCore]
        WM[WorkingMemory]
        STM[ShortTermMemory]
    end
    
    subgraph "Data Models"
        PN[ProcessedNote]
        E[Entity]
        R[Relationship]
        USP[UserSpeechProfile]
    end
    
    CV --> AR
    CV --> TDV
    CV --> TCView
    TAB --> AR
    
    AR --> AS
    AR --> AF
    AR --> TE
    
    TE --> PE
    PE --> EE
    PE --> RE
    
    EE --> E
    RE --> R
    
    TE --> GC
    GC --> WM
    GC --> STM
    
    GC --> PN
    PN --> E
    PN --> R
    
    TCView --> USP
    USP --> PE
```

## 2. Knowledge Graph Visualization Interaction

### Sequence Diagram: Knowledge Graph Loading

```mermaid
sequenceDiagram
    participant User
    participant KnowledgeGraphView
    participant KnowledgeGraphService
    participant SwiftData
    participant Entity
    participant Relationship
    participant EntityNodeView
    participant RelationshipEdgeView
    
    User->>KnowledgeGraphView: Navigate to Graph
    KnowledgeGraphView->>KnowledgeGraphService: loadData()
    
    KnowledgeGraphService->>SwiftData: fetch(Entity)
    SwiftData->>Entity: createInstances()
    Entity->>KnowledgeGraphService: returnEntities()
    
    KnowledgeGraphService->>SwiftData: fetch(Relationship)
    SwiftData->>Relationship: createInstances()
    Relationship->>KnowledgeGraphService: returnRelationships()
    
    KnowledgeGraphService->>KnowledgeGraphService: initializeNodePositions()
    KnowledgeGraphService->>KnowledgeGraphService: startForceDirectedLayout()
    
    KnowledgeGraphService->>KnowledgeGraphView: dataLoaded()
    KnowledgeGraphView->>EntityNodeView: render()
    KnowledgeGraphView->>RelationshipEdgeView: render()
    
    loop Layout Animation
        KnowledgeGraphService->>KnowledgeGraphService: updateForceDirectedLayout()
        KnowledgeGraphService->>KnowledgeGraphView: updatePositions()
        KnowledgeGraphView->>EntityNodeView: updatePosition()
        KnowledgeGraphView->>RelationshipEdgeView: updateEndpoints()
    end
    
    User->>EntityNodeView: dragGesture()
    EntityNodeView->>KnowledgeGraphService: updateNodePosition()
    KnowledgeGraphService->>KnowledgeGraphView: positionChanged()
    KnowledgeGraphView->>RelationshipEdgeView: updateConnectedEdges()
```

### Collaboration Diagram: Graph Interaction Components

```mermaid
graph TB
    subgraph "Graph UI Layer"
        KGV[KnowledgeGraphView]
        ENV[EntityNodeView]
        REV[RelationshipEdgeView]
        EDV[EntityDetailView]
        RDV[RelationshipDetailView]
        FV[FiltersView]
    end
    
    subgraph "Graph Service Layer"
        KGS[KnowledgeGraphService]
        LA[LayoutAlgorithms]
        GF[GraphFiltering]
        GA[GraphAnalysis]
        PM[PositionManager]
    end
    
    subgraph "Layout Algorithms"
        FDL[ForceDirectedLayout]
        CL[CircularLayout]
        HL[HierarchicalLayout]
        RL[RadialLayout]
    end
    
    subgraph "Graph Data"
        E[Entity]
        R[Relationship]
        ET[EntityType]
        PT[PredicateType]
        GL[GraphLayout]
    end
    
    subgraph "Interaction Handling"
        DG[DragGesture]
        TG[TapGesture]
        MG[MagnificationGesture]
        SH[SelectionHandler]
    end
    
    KGV --> KGS
    KGV --> ENV
    KGV --> REV
    KGV --> EDV
    KGV --> RDV
    KGV --> FV
    
    KGS --> LA
    KGS --> GF
    KGS --> GA
    KGS --> PM
    
    LA --> FDL
    LA --> CL
    LA --> HL
    LA --> RL
    
    KGS --> E
    KGS --> R
    E --> ET
    R --> PT
    
    ENV --> DG
    ENV --> TG
    REV --> TG
    KGV --> MG
    
    DG --> SH
    TG --> SH
    MG --> SH
    
    SH --> KGS
```

## 3. Memory Consolidation Interaction

### Sequence Diagram: STM to LTM Consolidation

```mermaid
sequenceDiagram
    participant Timer
    participant Gemma3nCore
    participant STMEntry
    participant ImportanceEvaluator
    participant ConsolidationEngine
    participant LTMEntry
    participant PatternRecognizer
    participant UserFeedback
    
    Timer->>Gemma3nCore: consolidationTrigger()
    Gemma3nCore->>STMEntry: getAllEntries()
    STMEntry->>Gemma3nCore: returnEntries()
    
    loop For Each STM Entry
        Gemma3nCore->>ImportanceEvaluator: evaluateImportance(entry)
        ImportanceEvaluator->>ImportanceEvaluator: calculateFrequency()
        ImportanceEvaluator->>ImportanceEvaluator: calculateRelevance()
        ImportanceEvaluator->>UserFeedback: getUserFeedback()
        UserFeedback->>ImportanceEvaluator: returnFeedback()
        ImportanceEvaluator->>Gemma3nCore: returnImportanceScore()
        
        alt High Importance
            Gemma3nCore->>ConsolidationEngine: consolidateEntry(entry)
            ConsolidationEngine->>PatternRecognizer: identifyPatterns()
            PatternRecognizer->>ConsolidationEngine: returnPatterns()
            ConsolidationEngine->>LTMEntry: createLTMEntry()
            ConsolidationEngine->>STMEntry: markForRemoval()
        else Low Importance
            Gemma3nCore->>STMEntry: decreaseImportance()
            alt Importance Below Threshold
                Gemma3nCore->>STMEntry: removeEntry()
            end
        end
    end
    
    Gemma3nCore->>Gemma3nCore: updateMemoryMetrics()
```

### Collaboration Diagram: Memory System Components

```mermaid
graph TB
    subgraph "Memory Management"
        GC[Gemma3nCore]
        MC[MemoryConsolidation]
        IE[ImportanceEvaluator]
        PR[PatternRecognizer]
    end
    
    subgraph "Memory Storage"
        STM[STMEntry]
        LTM[LTMEntry]
        WM[WorkingMemoryEntry]
        EM[EpisodicMemoryEntry]
    end
    
    subgraph "Memory Analytics"
        MA[MemoryAnalytics]
        CE[ConsolidationEvent]
        MPM[MemoryPerformanceMetric]
    end
    
    subgraph "Context & Patterns"
        CN[ConceptNode]
        TE[TemporalEvent]
        CC[ConversationContext]
        USP[UserSpeechProfile]
    end
    
    subgraph "Input Sources"
        PN[ProcessedNote]
        E[Entity]
        R[Relationship]
        UF[UserFeedback]
    end
    
    GC --> MC
    GC --> STM
    GC --> LTM
    GC --> WM
    GC --> EM
    
    MC --> IE
    MC --> PR
    
    IE --> UF
    PR --> CN
    PR --> TE
    
    STM --> LTM
    
    MC --> MA
    MA --> CE
    MA --> MPM
    
    PN --> STM
    E --> STM
    R --> STM
    
    CC --> WM
    USP --> WM
```

## 4. Data Export/Import Interaction

### Sequence Diagram: Data Export Process

```mermaid
sequenceDiagram
    participant User
    participant ContentView
    participant DataExportService
    participant SwiftData
    participant FileManager
    participant Entity
    participant Relationship
    participant ProcessedNote
    participant ExportMetadata
    
    User->>ContentView: Request Export
    ContentView->>DataExportService: exportData()
    
    DataExportService->>SwiftData: fetchAllEntities()
    SwiftData->>Entity: getAllEntities()
    Entity->>DataExportService: returnEntities()
    
    DataExportService->>SwiftData: fetchAllRelationships()
    SwiftData->>Relationship: getAllRelationships()
    Relationship->>DataExportService: returnRelationships()
    
    DataExportService->>SwiftData: fetchAllNotes()
    SwiftData->>ProcessedNote: getAllNotes()
    ProcessedNote->>DataExportService: returnNotes()
    
    DataExportService->>ExportMetadata: createMetadata()
    ExportMetadata->>DataExportService: returnMetadata()
    
    DataExportService->>DataExportService: serializeToJSON()
    DataExportService->>FileManager: writeToFile()
    FileManager->>DataExportService: confirmWrite()
    
    DataExportService->>ContentView: exportComplete()
    ContentView->>User: showSuccessMessage()
```

### Collaboration Diagram: Export/Import System

```mermaid
graph TB
    subgraph "Export/Import UI"
        EIV[ExportImportView]
        EP[ExportProgress]
        IP[ImportProgress]
        FC[FileChooser]
    end
    
    subgraph "Export Services"
        DES[DataExportService]
        JS[JSONSerializer]
        EM[ExportMetadata]
        FW[FileWriter]
    end
    
    subgraph "Import Services"
        DIS[DataImportService]
        JD[JSONDeserializer]
        DV[DataValidator]
        FR[FileReader]
    end
    
    subgraph "Data Models"
        E[Entity]
        R[Relationship]
        PN[ProcessedNote]
        STM[STMEntry]
        LTM[LTMEntry]
    end
    
    subgraph "Platform Services"
        FM[FileManager]
        SD[SwiftData]
        DP[DocumentPicker]
    end
    
    EIV --> DES
    EIV --> DIS
    EIV --> FC
    EIV --> EP
    EIV --> IP
    
    DES --> JS
    DES --> EM
    DES --> FW
    
    DIS --> JD
    DIS --> DV
    DIS --> FR
    
    DES --> E
    DES --> R
    DES --> PN
    DES --> STM
    DES --> LTM
    
    DIS --> E
    DIS --> R
    DIS --> PN
    DIS --> STM
    DIS --> LTM
    
    FW --> FM
    FR --> FM
    FC --> DP
    
    DES --> SD
    DIS --> SD
```

## 5. User Interface Navigation Interaction

### Sequence Diagram: Navigation Flow

```mermaid
sequenceDiagram
    participant User
    participant ContentView
    participant NavigationSplitView
    participant NotesListView
    participant NoteDetailView
    participant KnowledgeGraphView
    participant QuickActionBar
    participant AudioRecorder
    
    User->>ContentView: Launch App
    ContentView->>NavigationSplitView: initialize()
    NavigationSplitView->>NotesListView: loadSidebar()
    NavigationSplitView->>NoteDetailView: loadDetail()
    ContentView->>QuickActionBar: showFloatingBar()
    
    User->>NotesListView: Select Note
    NotesListView->>NoteDetailView: showNote(note)
    NoteDetailView->>NoteDetailView: loadNoteContent()
    
    User->>QuickActionBar: Tap Record
    QuickActionBar->>AudioRecorder: startRecording()
    AudioRecorder->>QuickActionBar: showRecordingState()
    
    User->>ContentView: Navigate to Knowledge Graph
    ContentView->>NavigationSplitView: switchToGraph()
    NavigationSplitView->>KnowledgeGraphView: loadGraph()
    KnowledgeGraphView->>KnowledgeGraphView: loadGraphData()
    
    User->>KnowledgeGraphView: Select Entity
    KnowledgeGraphView->>NoteDetailView: showEntityDetails()
    NoteDetailView->>NoteDetailView: loadEntityRelations()
```

### Collaboration Diagram: UI Component Hierarchy

```mermaid
graph TB
    subgraph "App Level"
        PA[ProjectOneApp]
        CV[ContentView]
    end
    
    subgraph "Navigation Structure"
        NSV[NavigationSplitView]
        NV[NavigationView]
        TB[TabBar]
    end
    
    subgraph "Main Views"
        NLV[NotesListView]
        NDV[NoteDetailView]
        KGV[KnowledgeGraphView]
        MDV[MemoryDashboardView]
    end
    
    subgraph "Specialized Views"
        TDV[TranscriptionDisplayView]
        TCView[TranscriptionCorrectionView]
        ENV[EntityNodeView]
        REV[RelationshipEdgeView]
        EDV[EntityDetailView]
        RDV[RelationshipDetailView]
    end
    
    subgraph "Action Components"
        QAB[QuickActionBar]
        AC[AudioControls]
        TP[TranscriptionPreview]
        FB[FilterBar]
    end
    
    subgraph "State Management"
        AS[AppState]
        NS[NavigationState]
        US[UIState]
        SS[SelectionState]
    end
    
    PA --> CV
    CV --> NSV
    CV --> QAB
    
    NSV --> NLV
    NSV --> NDV
    NSV --> KGV
    NSV --> MDV
    
    NDV --> TDV
    NDV --> TCView
    
    KGV --> ENV
    KGV --> REV
    KGV --> EDV
    KGV --> RDV
    KGV --> FB
    
    QAB --> AC
    QAB --> TP
    
    CV --> AS
    AS --> NS
    AS --> US
    AS --> SS
```

## 6. Error Handling and Recovery Interaction

### Sequence Diagram: Error Recovery Flow

```mermaid
sequenceDiagram
    participant User
    participant ContentView
    participant AudioRecorder
    participant ErrorHandler
    participant NotificationCenter
    participant RecoveryService
    participant SwiftData
    
    User->>ContentView: Initiate Action
    ContentView->>AudioRecorder: performOperation()
    AudioRecorder->>AudioRecorder: checkPermissions()
    
    alt Permission Denied
        AudioRecorder->>ErrorHandler: handlePermissionError()
        ErrorHandler->>ContentView: showPermissionAlert()
        ContentView->>User: requestPermission()
        User->>ContentView: grantPermission()
        ContentView->>AudioRecorder: retryOperation()
    end
    
    AudioRecorder->>AudioRecorder: startRecording()
    
    alt Recording Failure
        AudioRecorder->>ErrorHandler: handleRecordingError()
        ErrorHandler->>NotificationCenter: postErrorNotification()
        NotificationCenter->>ContentView: receiveErrorNotification()
        ContentView->>RecoveryService: attemptRecovery()
        
        alt Recovery Successful
            RecoveryService->>AudioRecorder: retryRecording()
            AudioRecorder->>ContentView: recordingResumed()
        else Recovery Failed
            RecoveryService->>ContentView: showErrorMessage()
            ContentView->>User: displayErrorUI()
        end
    end
    
    alt Data Corruption
        SwiftData->>ErrorHandler: handleDataError()
        ErrorHandler->>RecoveryService: initiateDataRecovery()
        RecoveryService->>SwiftData: attemptDataRepair()
        SwiftData->>RecoveryService: repairResult()
        RecoveryService->>ContentView: notifyRecoveryStatus()
    end
```

These interaction diagrams provide a comprehensive view of how objects collaborate in the ProjectOne system, showing both the static relationships and dynamic runtime behavior across all major functional areas.