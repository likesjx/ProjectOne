# SwiftData Implementation Guide for ProjectOne

## Quick Fix Implementation Checklist

Based on the identified SwiftData crashes in entity relationship operations, here's a prioritized implementation guide for fixing the type safety issues.

## Immediate Actions Required

### 1. ProcessedNote Model Updates (High Priority)

**File**: `ProjectOne/Models/Core/ProcessedNote.swift`

```swift
// Add these type-safe methods to ProcessedNote
extension ProcessedNote {
    /// Type-safe entity addition with validation
    func addEntity(_ entity: Entity) {
        // Validate entity state
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
    
    /// Safe entity removal
    func removeEntity(_ entity: Entity) {
        entities.removeAll { $0.id == entity.id }
    }
    
    /// Safe entity querying with error handling
    func getEntitiesOfType(_ type: EntityType) -> [Entity] {
        return entities.filter { $0.type == type }
    }
}
```

### 2. Entity Model Type Safety (High Priority)

**File**: `ProjectOne/Models/Core/Entity.swift`

```swift
// Add deduplication and merging logic
extension Entity {
    /// Safe entity deduplication with type checking
    static func deduplicate(entities: [Entity], context: ModelContext) -> [Entity] {
        var deduplicatedEntities: [Entity] = []
        var seenIDs: Set<UUID> = []
        
        for entity in entities {
            guard let entityID = entity.id else {
                print("Warning: Entity missing ID during deduplication")
                continue
            }
            
            if !seenIDs.contains(entityID) {
                seenIDs.insert(entityID)
                
                // Ensure entity is attached to context
                if entity.modelContext == nil {
                    context.insert(entity)
                }
                
                deduplicatedEntities.append(entity)
            } else {
                // Merge duplicate
                if let existingEntity = deduplicatedEntities.first(where: { $0.id == entityID }) {
                    existingEntity.mergeConfidence(from: entity)
                }
            }
        }
        
        return deduplicatedEntities
    }
    
    /// Safe confidence merging
    func mergeConfidence(from other: Entity) {
        guard self.name == other.name, self.type == other.type else {
            print("Warning: Attempting to merge incompatible entities")
            return
        }
        
        if other.confidence > self.confidence {
            self.confidence = other.confidence
        }
        
        // Merge metadata safely
        if let otherMetadata = other.metadata, !otherMetadata.isEmpty {
            self.metadata = (self.metadata ?? [:]).merging(otherMetadata) { _, new in new }
        }
    }
}
```

### 3. ModelContainer Safety (Medium Priority)

**File**: `ProjectOne/Services/ModelContainer+Extensions.swift` (Create new file)

```swift
import SwiftData
import Foundation

extension ModelContainer {
    /// Create ModelContainer with comprehensive error handling
    static func createSafeContainer() -> ModelContainer? {
        do {
            let schema = Schema([
                ProcessedNote.self,
                Entity.self,
                Relationship.self,
                STMEntry.self,
                LTMEntry.self,
                WorkingMemoryEntry.self,
                EpisodicMemoryEntry.self,
                ConceptNode.self,
                TemporalEvent.self,
                UserSpeechProfile.self,
                ConversationContext.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Validate container
            let context = ModelContext(container)
            try context.save() // Test basic functionality
            
            return container
        } catch {
            print("ModelContainer creation failed: \(error)")
            return nil
        }
    }
}
```

### 4. Test Fixes (High Priority)

**Update Integration Tests** - Add type safety to entity relationship tests:

```swift
// Safe test pattern for entity operations
@Test("Entity Deduplication - Type Safe")
func testEntityDeduplicationAcrossNotes() async throws {
    guard let container = ModelContainer.createSafeContainer() else {
        throw TestError.containerCreationFailed
    }
    
    let context = ModelContext(container)
    
    // Create entities with proper validation
    let entity1 = Entity(name: "Test Person", type: .person, confidence: 0.9)
    let entity2 = Entity(name: "Test Person", type: .person, confidence: 0.8)
    
    context.insert(entity1)
    context.insert(entity2)
    
    do {
        try context.save()
    } catch {
        throw TestError.contextSaveFailed(error)
    }
    
    // Create notes with type-safe operations
    let note1 = ProcessedNote(content: "Note about Test Person")
    let note2 = ProcessedNote(content: "Another note about Test Person")
    
    context.insert(note1)
    context.insert(note2)
    
    // Use type-safe entity addition
    note1.addEntity(entity1)
    note2.addEntity(entity2)
    
    try context.save()
    
    // Perform safe deduplication
    let allEntities = [entity1, entity2]
    let deduplicated = Entity.deduplicate(entities: allEntities, context: context)
    
    #expect(deduplicated.count == 1)
    #expect(deduplicated[0].confidence == 0.9) // Higher confidence wins
}
```

## Implementation Order

### Phase 1: Critical Fixes (Immediate)
1. Update ProcessedNote with type-safe entity methods
2. Add Entity deduplication logic
3. Fix integration test type safety issues
4. Test basic entity relationship operations

### Phase 2: Safety Improvements (Next)
1. Implement ModelContainer safety extensions
2. Add comprehensive error handling
3. Update all entity relationship code to use safe methods
4. Add validation to all SwiftData operations

### Phase 3: Testing & Validation (Final)
1. Run comprehensive test suite
2. Verify no more `swift_dynamicCast` crashes
3. Performance testing with large entity sets
4. Integration testing with real audio transcription data

## Code Review Checklist

- [ ] All entity additions use `addEntity()` method
- [ ] Entity deduplication uses type-safe methods
- [ ] ModelContext operations include error handling
- [ ] Relationship queries validate entity state
- [ ] Tests use safe container creation
- [ ] No direct array manipulation of entity relationships
- [ ] All entity merging operations validate compatibility

## Performance Considerations

1. **Entity Deduplication**: O(n) complexity with Set-based tracking
2. **Relationship Validation**: Minimal overhead with early returns
3. **Error Handling**: Logging-only approach to avoid performance impact
4. **Memory Usage**: Efficient Set operations for duplicate detection

## Monitoring & Debugging

Add these debug helpers for tracking SwiftData issues:

```swift
extension ModelContext {
    func debugEntityState(_ entity: Entity) {
        print("Entity Debug: \(entity.name)")
        print("  - ID: \(entity.id)")
        print("  - Persistent ID: \(entity.persistentModelID?.description ?? "nil")")
        print("  - Model Context: \(entity.modelContext != nil ? "attached" : "detached")")
        print("  - Related Notes: \(entity.notes.count)")
    }
}
```

This implementation guide provides a systematic approach to resolving the SwiftData crashes while maintaining code quality and performance.