# Sentry Issues Resolution Guide

## Overview

Analysis of 3 unresolved Sentry issues in ProjectOne with root cause analysis and implementation fixes.

## Issue #1: PROJECTONE-1 - Privacy Violation (SIGABRT)

### Problem
```
SIGABRT: NSMicrophoneUsageDescription > This app has crashed because it attempted to access privacy-sensitive data without a usage description.
```

### Root Cause
- App attempts to access microphone without required Info.plist declaration
- iOS TCC framework blocks access and terminates app
- Missing `NSMicrophoneUsageDescription` key in Info.plist

### Fix: Add Microphone Permission to Info.plist

**File**: `/ProjectOne/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing keys... -->
    
    <!-- Add microphone permission -->
    <key>NSMicrophoneUsageDescription</key>
    <string>ProjectOne uses the microphone to record audio notes for transcription and knowledge management. This enables the AI-powered note-taking and memory consolidation features.</string>
    
    <!-- Optional: Add speech recognition permission if using Speech framework -->
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>ProjectOne uses speech recognition to provide real-time transcription of your audio notes, enhancing the AI knowledge system's accuracy.</string>
    
</dict>
</plist>
```

**Priority**: Critical - Blocks all audio recording functionality

---

## Issue #2: PROJECTONE-2 - Audio Recording Hang (App Hanging)

### Problem
```
App Hanging: App hanging for at least 2000 ms in AudioRecorder.startRecording
```

### Root Cause
- Lock contention in AudioToolbox framework during audio session initialization
- Improper AVAudioSession lifecycle management
- Audio hardware resource conflicts due to session activation timing

### Fix: Proper AVAudioSession Management

**File**: `/ProjectOne/AudioRecorder.swift` (Update existing implementation)

```swift
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    // Existing properties...
    private var audioSession: AVAudioSession
    private var isSessionActive = false
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Management
    
    private func setupAudioSession() {
        do {
            // Configure session category and mode
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() async {
        // Prevent multiple simultaneous calls
        guard !isRecording else { return }
        
        do {
            // Activate audio session BEFORE creating recorder
            if !isSessionActive {
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                isSessionActive = true
            }
            
            // Create and configure audio recorder
            try setupAudioRecorder()
            
            // Start recording
            audioRecorder?.record()
            
            await MainActor.run {
                isRecording = true
            }
            
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
            await deactivateAudioSession()
        }
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        // Stop recorder first
        audioRecorder?.stop()
        audioRecorder = nil
        
        await MainActor.run {
            isRecording = false
        }
        
        // Deactivate session after stopping
        await deactivateAudioSession()
    }
    
    private func deactivateAudioSession() async {
        guard isSessionActive else { return }
        
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            isSessionActive = false
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Lifecycle Management
    
    deinit {
        Task {
            await deactivateAudioSession()
        }
    }
}

// MARK: - Audio Session Interruption Handling

extension AudioRecorder {
    func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began - pause recording
            Task {
                await stopRecording()
            }
            
        case .ended:
            // Interruption ended - optionally resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Optionally restart recording based on app state
                }
            }
            
        @unknown default:
            break
        }
    }
}
```

**Additional Fix**: Add interruption handling in app initialization

```swift
// In ProjectOneApp.swift or AudioRecorder init
NotificationCenter.default.addObserver(
    forName: AVAudioSession.interruptionNotification,
    object: nil,
    queue: .main
) { [weak self] notification in
    self?.handleAudioSessionInterruption(notification)
}
```

**Priority**: High - Causes app freezing during core functionality

---

## Issue #3: PROJECTONE-3 - SwiftData Casting Error (SIGABRT)

### Problem
```
SIGABRT: Could not cast value of type 'ProjectOne.ProcessedNote' to 'SwiftData.PersistentModel'
```

### Root Cause
- ProcessedNote is declared as struct instead of class
- SwiftData requires @Model classes that conform to PersistentModel protocol
- Type casting failure when SwiftData tries to persist/observe ProcessedNote

### Fix: Convert ProcessedNote to SwiftData @Model Class

**File**: `/ProjectOne/Models/Core/ProcessedNote.swift`

```swift
import Foundation
import SwiftData

@Model
final class ProcessedNote {
    var id: UUID
    var content: String
    var originalAudio: String? // File path to audio
    var timestamp: Date
    var transcriptionConfidence: Double
    var processingStatus: ProcessingStatus
    
    // Memory system integration
    var memoryType: MemoryType
    var importanceScore: Double
    var consolidationState: ConsolidationState
    
    // Knowledge graph relationships - USE PROPER @Relationship
    @Relationship(deleteRule: .nullify, inverse: \Entity.notes)
    var entities: [Entity] = []
    
    @Relationship(deleteRule: .cascade)
    var relationships: [Relationship] = []
    
    // Metadata
    var tags: [String] = []
    var metadata: [String: String] = [:]
    
    init(content: String, originalAudio: String? = nil) {
        self.id = UUID()
        self.content = content
        self.originalAudio = originalAudio
        self.timestamp = Date()
        self.transcriptionConfidence = 0.0
        self.processingStatus = .pending
        self.memoryType = .shortTerm
        self.importanceScore = 0.0
        self.consolidationState = .pending
        self.entities = []
        self.relationships = []
        self.tags = []
        self.metadata = [:]
    }
    
    // MARK: - Type-Safe Entity Management
    
    func addEntity(_ entity: Entity) {
        // Validate entity state before adding
        guard entity.persistentModelID != nil else {
            print("Warning: Attempting to add unpersisted entity to note \(self.id)")
            return
        }
        
        // Prevent duplicates
        guard !entities.contains(where: { $0.id == entity.id }) else {
            print("Entity \(entity.name) already exists in note")
            return
        }
        
        entities.append(entity)
    }
    
    func removeEntity(_ entity: Entity) {
        entities.removeAll { $0.id == entity.id }
    }
}

// MARK: - Supporting Enums

enum ProcessingStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
}

enum MemoryType: String, Codable, CaseIterable {
    case shortTerm = "short_term"
    case longTerm = "long_term"
    case working = "working"
    case episodic = "episodic"
}

enum ConsolidationState: String, Codable, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case consolidated = "consolidated"
    case archived = "archived"
}
```

**Fix for Entity Model** - Ensure Entity is also properly defined:

**File**: `/ProjectOne/Models/Core/Entity.swift`

```swift
import Foundation
import SwiftData

@Model
final class Entity {
    var id: UUID
    var name: String
    var type: EntityType
    var confidence: Double
    var metadata: [String: String] = [:]
    var createdAt: Date
    var lastUpdated: Date
    
    // Inverse relationship with ProcessedNote
    @Relationship(deleteRule: .nullify, inverse: \ProcessedNote.entities)
    var notes: [ProcessedNote] = []
    
    init(name: String, type: EntityType, confidence: Double = 1.0) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.confidence = confidence
        self.metadata = [:]
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.notes = []
    }
}

enum EntityType: String, Codable, CaseIterable {
    case person = "person"
    case organization = "organization"
    case location = "location"
    case concept = "concept"
    case activity = "activity"
}
```

**Priority**: Critical - Prevents app from working with core data models

---

## Implementation Order

### Immediate (Deploy Today)
1. **PROJECTONE-1**: Add Info.plist permissions - 5 minute fix
2. **PROJECTONE-3**: Fix ProcessedNote SwiftData model - Critical for data persistence

### Next (Deploy This Week)
3. **PROJECTONE-2**: Implement proper AVAudioSession management - Requires testing

## Testing Strategy

### PROJECTONE-1 Testing
```bash
# Test microphone permission
1. Clean install app
2. Navigate to AI Notes
3. Attempt to start recording
4. Verify permission prompt appears
5. Grant permission and verify recording works
```

### PROJECTONE-2 Testing
```bash
# Test audio session management
1. Start recording
2. Background app during recording
3. Return to app - verify no hang
4. Test with other audio apps running
5. Test interruption scenarios (phone calls, etc.)
```

### PROJECTONE-3 Testing
```bash
# Test SwiftData models
1. Create ProcessedNote with entities
2. Save to persistent store
3. Reload app and verify data persistence
4. Test entity relationship operations
```

## Sentry Integration

After deploying fixes, update Sentry issues:

```bash
# Commit messages should reference Sentry issues
git commit -m "Fix microphone permission crash

Fixes PROJECTONE-1 by adding NSMicrophoneUsageDescription to Info.plist.
This resolves the privacy violation crash when accessing microphone for audio recording."

git commit -m "Fix SwiftData model casting error

Fixes PROJECTONE-3 by converting ProcessedNote from struct to @Model class.
This resolves the type casting failure in SwiftData persistence operations."

git commit -m "Fix audio recording hang with proper session management

Fixes PROJECTONE-2 by implementing explicit AVAudioSession activation/deactivation.
This prevents lock contention in AudioToolbox framework during recording initialization."
```

These fixes address the root causes identified by Sentry's AI analysis and should resolve all three critical issues preventing proper app functionality.