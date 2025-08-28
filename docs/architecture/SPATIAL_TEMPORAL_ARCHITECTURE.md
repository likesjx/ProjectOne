# Spatial-Temporal Context Architecture

## Overview

The Spatial-Temporal Context System provides location-aware memory surfacing and time-sensitive thought management for ProjectOne. It integrates GPS location tracking, target location selection, temporal scheduling, and dopamine wave alignment to create intelligent, context-aware memory retrieval.

## Architecture Components

### 1. Core Data Models

#### Enhanced Thought Model
```swift
@Model class Thought {
    // Spatial Context - Creation
    var creationLatitude: Double?         // GPS coordinates when created
    var creationLongitude: Double?        
    var creationLocationName: String?     // Human-readable location name
    var creationLocationAccuracy: Double? // GPS accuracy in meters
    
    // Spatial Context - Target/Relevant
    var targetLatitude: Double?           // Where thought is relevant
    var targetLongitude: Double?          
    var targetLocationName: String?       // Target location name
    var targetLocationRadius: Double?     // Relevant radius in meters
    
    // Temporal Context
    var targetDateTime: Date?             // When to surface this thought
    var timestamp: Date                   // Creation timestamp
    
    // Location Intelligence Methods
    func setCreationLocation(latitude: Double, longitude: Double, locationName: String?, accuracy: Double?)
    func setTargetLocation(latitude: Double, longitude: Double, locationName: String?, radius: Double?)
    func distanceFromTargetLocation(currentLatitude: Double, currentLongitude: Double) -> Double?
    func isNearTargetLocation(currentLatitude: Double, currentLongitude: Double) -> Bool
    func isDueSoon(withinHours hours: Double) -> Bool
    func isOverdue: Bool
}
```

### 2. Location Services Integration

#### BubbleUpMemoryCreator Actor
```swift
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public actor BubbleUpMemoryCreator {
    private let locationManager = CLLocationManager()
    
    // Automatic location capture during memory creation
    private func captureCurrentLocation() async -> (latitude: Double?, longitude: Double?, accuracy: Double?, locationName: String?) {
        // 1. Check location permissions
        // 2. Get current GPS coordinates
        // 3. Perform reverse geocoding for human-readable name
        // 4. Return location data bundle
    }
    
    // Memory creation with spatial context
    public func createMemoryFromBubbleUp(_ bubbleUpItem: BubbleUpItem, userInput: String?, thoughtType: ThoughtType) async throws -> Thought {
        // 1. Create base thought from bubble-up
        // 2. Capture current location automatically
        // 3. Store creation context
        // 4. Add to cognitive memory system with spatial metadata
    }
    
    // Custom memory creation with target location
    public func createCustomMemoryFromBubbleUp(
        _ bubbleUpItem: BubbleUpItem,
        userContent: String,
        thoughtType: ThoughtType,
        targetDateTime: Date?,
        targetLocation: (latitude: Double, longitude: Double, name: String?, radius: Double?)?
    ) async throws -> Thought {
        // 1. Create thought with user content
        // 2. Set target datetime if provided
        // 3. Set target location coordinates if provided
        // 4. Capture creation location context
    }
}
```

### 3. Interactive Location Selection

#### LocationPickerView Component
```swift
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct LocationPickerView: View {
    // Map region and user interaction
    @State private var region = MKCoordinateRegion(...)
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedLocationName: String?
    @State private var searchText = ""
    
    // Location selection callback
    let onLocationSelected: (CLLocationCoordinate2D, String?) -> Void
    
    // Features:
    // - Interactive map with tap-to-select
    // - Search functionality for places
    // - Current location button
    // - Reverse geocoding for location names
    // - Crosshair overlay for precise selection
}
```

#### MemoryCreationView Integration
```swift
struct MemoryCreationView: View {
    // Location state management
    @State private var hasTargetLocation: Bool = false
    @State private var targetLocationName: String = ""
    @State private var targetLocationRadius: Double = 100.0
    @State private var showingLocationPicker: Bool = false
    @State private var targetCoordinate: CLLocationCoordinate2D?
    
    // Target datetime state
    @State private var hasTargetDateTime: Bool = false
    @State private var targetDateTime: Date = Date().addingTimeInterval(86400)
    
    // Sheet presentation for location picker
    .sheet(isPresented: $showingLocationPicker) {
        LocationPickerView { coordinate, name in
            targetCoordinate = coordinate
            if let name = name { targetLocationName = name }
        }
    }
}
```

### 4. Spatial-Temporal Intelligence

#### Distance Calculations
```swift
// Haversine distance formula implementation in Thought model
private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
    let earthRadius = 6371000.0 // Earth's radius in meters
    
    let dLat = (lat2 - lat1) * .pi / 180.0
    let dLon = (lon2 - lon1) * .pi / 180.0
    
    let lat1Rad = lat1 * .pi / 180.0
    let lat2Rad = lat2 * .pi / 180.0
    
    let a = sin(dLat/2) * sin(dLat/2) + cos(lat1Rad) * cos(lat2Rad) * sin(dLon/2) * sin(dLon/2)
    let c = 2 * atan2(sqrt(a), sqrt(1-a))
    
    return earthRadius * c
}
```

#### Context-Aware Surfacing
- **Proximity Detection**: Thoughts surface when user approaches target locations
- **Time-Based Triggers**: Thoughts surface at target datetime or during optimal dopamine windows
- **Context Switching**: Different thought types surface based on location context
- **Routine Learning**: System learns user location patterns for better predictions

## Integration with Dopamine Wave Scheduling

### Temporal Alignment
```swift
// Dopamine wave time windows
enum DopamineWave {
    case morningPeak    // 7:30-11:30am - Deep focus, critical thoughts
    case middayDip      // 12:00-2:00pm - Light tasks, meetings
    case afternoonBoost // 3:00-6:00pm - Structured work, problem-solving
    case eveningCreative // 6:30-9:00pm - Creative ideas, reflection
    case windDown      // 9:30pm+ - Light review, sleep prep
    
    func isOptimalFor(_ thoughtType: ThoughtType) -> Bool {
        switch (self, thoughtType) {
        case (.morningPeak, .task), (.morningPeak, .decision):
            return true
        case (.afternoonBoost, .plan), (.afternoonBoost, .insight):
            return true
        case (.eveningCreative, .idea), (.eveningCreative, .reflection):
            return true
        default:
            return false
        }
    }
}
```

### Context-Aware Bubble-Up Algorithm
```swift
func selectBubbleUpThoughts(currentLocation: CLLocation, currentTime: Date) -> [Thought] {
    let thoughts = fetchAllThoughts()
    let currentWave = DopamineWave.forTime(currentTime)
    
    return thoughts.filter { thought in
        // Location relevance
        let locationRelevant = thought.isNearTargetLocation(
            currentLatitude: currentLocation.coordinate.latitude,
            currentLongitude: currentLocation.coordinate.longitude
        )
        
        // Time relevance
        let timeRelevant = thought.isDueSoon() || 
                          thought.isOverdue ||
                          currentWave.isOptimalFor(thought.thoughtType)
        
        return locationRelevant || timeRelevant
    }
    .sorted { $0.importance.priority > $1.importance.priority }
}
```

## Data Flow Architecture

### Memory Creation Flow
```
User Input → MemoryCreationView → LocationPickerView
     ↓              ↓                      ↓
Target DateTime   Location Selection   GPS Coordinates
     ↓              ↓                      ↓
BubbleUpMemoryCreator → CoreLocation → Reverse Geocoding
     ↓                      ↓                ↓
Enhanced Thought    Creation Context   SwiftData Storage
     ↓                      ↓                ↓
Cognitive Memory   Spatial-Temporal    Local Persistence
System             Metadata
```

### Memory Surfacing Flow
```
Background Service → Location Manager → Current GPS
     ↓                      ↓               ↓
Context Detection   Proximity Calc   Time Check
     ↓                      ↓               ↓
Bubble-Up Engine → Thought Selection → UI Surface
     ↓                      ↓               ↓
Dopamine Wave      Spatial Filter    Coach Cards
Alignment          Algorithm         Display
```

## Privacy & Security

### Local-First Approach
- All GPS coordinates stored locally in SwiftData
- No location data transmitted to external services
- User controls location sharing per thought
- Location permissions requested only when needed

### Data Protection
- Location accuracy configurable (10m - 1km radius)
- Automatic location capture can be disabled
- Target locations user-controlled via interactive map
- Location names stored as user-friendly strings

### Permission Management
```swift
// Location manager setup with proper permissions
private func setupLocationManager() {
    locationManager.requestWhenInUseAuthorization()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
}

// Permission checks before location access
guard CLLocationManager.locationServicesEnabled(),
      locationManager.authorizationStatus == .authorizedWhenInUse || 
      locationManager.authorizationStatus == .authorizedAlways else {
    return (nil, nil, nil, nil)
}
```

## Performance Considerations

### Optimization Strategies
- **Lazy Loading**: Location services activated only when needed
- **Caching**: Reverse geocoding results cached locally
- **Background Processing**: Location updates handled in background
- **Battery Optimization**: Location accuracy balanced with battery usage

### Scalability
- **Incremental Updates**: Location context added without rebuilding
- **Efficient Queries**: Spatial queries optimized with indexed coordinates
- **Memory Management**: Location data cleaned up for old thoughts
- **Offline Support**: Core functionality works without network connectivity

## Future Enhancements

### Advanced Spatial Intelligence
- **Route Tracking**: Memory surfacing along travel routes
- **Location Clustering**: Automatic grouping of similar locations
- **Geofencing**: Advanced proximity detection with custom shapes
- **Location History**: Pattern learning from user movement

### Enhanced Temporal Features
- **Recurring Reminders**: Thoughts that surface at regular intervals
- **Seasonal Context**: Time-of-year relevance for memories
- **Calendar Integration**: Sync with system calendar for better timing
- **Time Zone Support**: Multi-timezone awareness for travelers

This architecture provides a comprehensive foundation for intelligent, context-aware memory management that adapts to user location and time patterns while maintaining privacy and performance.