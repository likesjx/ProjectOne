# SwiftData Crash Fixes and Type Safety Improvements

## Overview

Based on test failures showing `swift_dynamicCast` crashes in entity relationship operations, this document provides analysis and fixes for common SwiftData type safety issues in ProjectOne.

## Identified Crash Patterns

### 1. Entity Relationship Casting Issues

**Problem**: `swift_dynamicCast` failures in `ProcessedNote.entities.setter`
**Root Cause**: Type mismatches in SwiftData relationship handling

**Common Issues**:
- Attempting to cast between incompatible model types
- Relationship property type mismatches
- Optional unwrapping failures in entity collections

### 2. Entity Deduplication Logic Crashes

**Problem**: Crashes during entity deduplication across notes
**Root Cause**: Type safety violations during entity comparison and merging

## Recommended Fixes

### Fix 1: ProcessedNote Entity Relationship Type Safety

```swift
// BEFORE: Potential casting issues
@Model
final class ProcessedNote {
    @Relationship(deleteRule: .nullify, inverse: \Entity.notes)
    var entities: [Entity] = []
    
    func addEntity(_ entity: Any) {
        if let typedEntity = entity as? Entity {
            entities.append(typedEntity)
        }
    }
}

// AFTER: Type-safe entity handling
@Model
final class ProcessedNote {
    @Relationship(deleteRule: .nullify, inverse: \Entity.notes)
    var entities: [Entity] = []
    
    func addEntity(_ entity: Entity) {
        // Ensure entity is properly persisted before relationship
        guard entity.persistentModelID != nil else {
            print("Warning: Attempting to add unpersisted entity")
            return
        }
        
        // Check for duplicates before adding
        if !entities.contains(where: { $0.id == entity.id }) {
            entities.append(entity)
        }
    }
    
    func removeEntity(_ entity: Entity) {
        entities.removeAll { $0.id == entity.id }
    }
}
```

### Fix 2: Entity Deduplication with Type Safety

```swift
// Type-safe entity deduplication
extension Entity {
    static func deduplicate(
        entities: [Entity],
        context: ModelContext
    ) -> [Entity] {
        var deduplicatedEntities: [Entity] = []
        var seenIDs: Set<UUID> = []
        
        for entity in entities {
            // Ensure entity has valid ID
            guard let entityID = entity.id else {
                print("Warning: Entity missing ID during deduplication")
                continue
            }
            
            if !seenIDs.contains(entityID) {
                seenIDs.insert(entityID)
                
                // Ensure entity is properly attached to context
                if entity.modelContext == nil {
                    context.insert(entity)
                }
                
                deduplicatedEntities.append(entity)
            } else {
                // Handle duplicate by merging confidence scores
                if let existingEntity = deduplicatedEntities.first(where: { $0.id == entityID }) {
                    existingEntity.mergeConfidence(from: entity)
                }
            }
        }
        
        return deduplicatedEntities
    }
}
```

### Fix 3: Safe Entity Merging

```swift
extension Entity {
    func mergeConfidence(from other: Entity) {
        // Type-safe confidence merging
        guard self.name == other.name,
              self.type == other.type else {
            print("Warning: Attempting to merge incompatible entities")
            return
        }
        
        // Take higher confidence score
        if other.confidence > self.confidence {
            self.confidence = other.confidence
        }
        
        // Merge any additional metadata safely
        if let otherMetadata = other.metadata,
           !otherMetadata.isEmpty {
            self.metadata = (self.metadata ?? [:]).merging(otherMetadata) { current, new in
                return new // Prefer new metadata
            }
        }
    }
}
```

### Fix 4: Model Container Error Handling

```swift
// Safe model container setup with error handling
extension ModelContainer {
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
            
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            print("Failed to create ModelContainer: \(error)")
            return nil
        }
    }
}
```

### Fix 5: Relationship Query Safety

```swift
// Safe relationship querying
extension ProcessedNote {
    func safeEntityQuery(
        context: ModelContext,
        predicate: Predicate<Entity>? = nil
    ) -> [Entity] {
        do {
            var descriptor = FetchDescriptor<Entity>()
            if let predicate = predicate {
                descriptor.predicate = predicate
            }
            
            let allEntities = try context.fetch(descriptor)
            
            // Filter to entities actually related to this note
            return allEntities.filter { entity in
                entity.notes.contains { note in
                    note.id == self.id
                }
            }
        } catch {
            print("Error fetching related entities: \(error)")
            return []
        }
    }
}
```

## Test-Specific Fixes

### Safe Integration Test Pattern

```swift
@Test("Entity Relationship Network - Type Safe")
func testEntityDeduplicationAcrossNotes() async throws {
    // Create test container with error handling
    guard let container = ModelContainer.createSafeContainer() else {
        throw TestError.containerCreationFailed
    }
    
    let context = ModelContext(container)
    
    // Create test entities with proper type checking
    let entity1 = Entity(name: "Test Person", type: .person)
    let entity2 = Entity(name: "Test Person", type: .person) // Duplicate
    
    // Ensure entities are inserted before creating relationships
    context.insert(entity1)
    context.insert(entity2)
    
    do {
        try context.save()
    } catch {
        throw TestError.contextSaveFailed(error)
    }
    
    // Create notes with type-safe entity addition
    let note1 = ProcessedNote(content: "Note about Test Person")
    let note2 = ProcessedNote(content: "Another note about Test Person")
    
    context.insert(note1)
    context.insert(note2)
    
    // Safe entity addition
    note1.addEntity(entity1)
    note2.addEntity(entity2)
    
    try context.save()
    
    // Perform deduplication with type safety
    let allEntities = [entity1, entity2]
    let deduplicated = Entity.deduplicate(entities: allEntities, context: context)
    
    // Verify results
    #expect(deduplicated.count == 1)
    #expect(deduplicated[0].name == "Test Person")
}

enum TestError: Error {
    case containerCreationFailed
    case contextSaveFailed(Error)
}
```

## Implementation Priority

1. **High Priority**: Fix ProcessedNote entity relationship type safety
2. **High Priority**: Implement safe entity deduplication
3. **Medium Priority**: Add comprehensive error handling to model operations
4. **Medium Priority**: Implement safe relationship querying
5. **Low Priority**: Add performance monitoring for SwiftData operations

## Testing Strategy

1. Run tests in isolated ModelContainer instances
2. Use proper error handling and type checking
3. Ensure all entities are persisted before relationship creation
4. Implement comprehensive logging for debugging type issues

## Additional Recommendations

1. **Use Explicit Type Annotations**: Always specify types for SwiftData properties
2. **Validate Entity State**: Check persistentModelID before relationship operations
3. **Handle Optionals Safely**: Use guard statements for optional unwrapping
4. **Implement Proper Error Recovery**: Don't crash on type mismatches
5. **Add Comprehensive Logging**: Track entity lifecycle for debugging

This approach should resolve the `swift_dynamicCast` crashes and improve overall SwiftData stability in the ProjectOne application.