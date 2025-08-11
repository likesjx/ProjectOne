import XCTest
import SwiftData
@testable import ProjectOne

@MainActor
class HealthKitIntegrationTests: XCTestCase {
    var healthKitManager: HealthKitManager!
    var modelContext: ModelContext!
    var container: ModelContainer!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up in-memory model container for testing
        let schema = Schema([HealthData.self, NoteHealthCorrelation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = container.mainContext
        
        healthKitManager = HealthKitManager()
        healthKitManager.modelContext = modelContext
    }
    
    override func tearDown() async throws {
        healthKitManager = nil
        modelContext = nil
        container = nil
        try await super.tearDown()
    }
    
    func testHealthKitManagerInitialization() {
        XCTAssertNotNil(healthKitManager)
        XCTAssertFalse(healthKitManager.isLoading)
        XCTAssertTrue(healthKitManager.recentHealthData.isEmpty)
        XCTAssertNil(healthKitManager.error)
    }
    
    func testHealthDataModelCreation() {
        // Test creating a HealthData instance
        let healthData = HealthData()
        healthData.heartRate = 75.0
        healthData.steps = 10000.0
        healthData.activeEnergyBurned = 400.0
        healthData.sleepDuration = 28800.0 // 8 hours in seconds
        
        XCTAssertEqual(healthData.heartRate, 75.0)
        XCTAssertEqual(healthData.steps, 10000.0)
        XCTAssertEqual(healthData.activeEnergyBurned, 400.0)
        XCTAssertEqual(healthData.sleepDuration, 28800.0)
        XCTAssertTrue(healthData.hasCardioData)
        XCTAssertTrue(healthData.hasActivityData)
        XCTAssertFalse(healthData.hasWellnessData) // No mindfulness data set
    }
    
    func testHealthDataMetricsSummary() {
        let healthData = HealthData()
        healthData.heartRate = 75.0
        healthData.steps = 10000.0
        healthData.activeEnergyBurned = 400.0
        
        let summary = healthData.summarizeMetrics()
        
        XCTAssertTrue(summary.contains("75.0 bpm"))
        XCTAssertTrue(summary.contains("10000.0 steps"))
        XCTAssertTrue(summary.contains("400.0 kcal"))
    }
    
    func testHealthEnrichmentInitialization() {
        let healthEnrichment = HealthEnrichment(
            healthKitManager: healthKitManager,
            modelContext: modelContext
        )
        
        XCTAssertNotNil(healthEnrichment)
        XCTAssertTrue(healthEnrichment.healthTrends.isEmpty)
        XCTAssertTrue(healthEnrichment.healthInsights.isEmpty)
    }
    
    func testHealthDataPersistence() throws {
        // Test saving HealthData to SwiftData
        let healthData = HealthData()
        healthData.heartRate = 80.0
        healthData.steps = 12000.0
        healthData.date = Date()
        
        modelContext.insert(healthData)
        try modelContext.save()
        
        // Fetch the saved data
        let descriptor = FetchDescriptor<HealthData>()
        let savedData = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(savedData.count, 1)
        XCTAssertEqual(savedData.first?.heartRate, 80.0)
        XCTAssertEqual(savedData.first?.steps, 12000.0)
    }
    
    func testNoteHealthCorrelationModel() throws {
        // Test creating and saving a NoteHealthCorrelation
        let noteId = UUID()
        let correlation = NoteHealthCorrelation(
            noteId: noteId,
            noteDate: Date(),
            enrichmentScore: 0.85,
            healthContext: "Test health context",
            insights: ["Test insight 1", "Test insight 2"],
            suggestions: ["Test suggestion 1"]
        )
        
        modelContext.insert(correlation)
        try modelContext.save()
        
        // Fetch the saved correlation
        let descriptor = FetchDescriptor<NoteHealthCorrelation>(
            predicate: #Predicate<NoteHealthCorrelation> { $0.noteId == noteId }
        )
        let savedCorrelations = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(savedCorrelations.count, 1)
        let savedCorrelation = savedCorrelations.first!
        XCTAssertEqual(savedCorrelation.enrichmentScore, 0.85)
        XCTAssertEqual(savedCorrelation.insights.count, 2)
        XCTAssertEqual(savedCorrelation.suggestions.count, 1)
    }
    
    func testHealthContextEnumValues() {
        // Test TimeOfDay enum
        XCTAssertEqual(TimeOfDay.morning.rawValue, "morning")
        XCTAssertEqual(TimeOfDay.afternoon.rawValue, "afternoon")
        XCTAssertEqual(TimeOfDay.evening.rawValue, "evening")
        XCTAssertEqual(TimeOfDay.night.rawValue, "night")
        
        // Test ActivityLevel enum
        XCTAssertEqual(ActivityLevel.sedentary.rawValue, "sedentary")
        XCTAssertEqual(ActivityLevel.light.rawValue, "light")
        XCTAssertEqual(ActivityLevel.moderate.rawValue, "moderate")
        XCTAssertEqual(ActivityLevel.vigorous.rawValue, "vigorous")
        
        // Test WellnessState enum
        XCTAssertEqual(WellnessState.poor.rawValue, "poor")
        XCTAssertEqual(WellnessState.fair.rawValue, "fair")
        XCTAssertEqual(WellnessState.good.rawValue, "good")
        XCTAssertEqual(WellnessState.excellent.rawValue, "excellent")
    }
    
    func testTrendDirectionProperties() {
        XCTAssertEqual(TrendDirection.increasing.iconName, "arrow.up.right")
        XCTAssertEqual(TrendDirection.decreasing.iconName, "arrow.down.right")
        XCTAssertEqual(TrendDirection.stable.iconName, "arrow.right")
    }
    
    func testSuggestionPriorityColor() {
        // This test requires the SuggestionPriority extension from the Views file
        // which adds color properties for UI testing
        let lowPriority = SuggestionPriority.low
        let mediumPriority = SuggestionPriority.medium  
        let highPriority = SuggestionPriority.high
        
        // Test that priorities have different raw values
        XCTAssertNotEqual(lowPriority.rawValue, mediumPriority.rawValue)
        XCTAssertNotEqual(mediumPriority.rawValue, highPriority.rawValue)
    }
    
    func testHealthKnowledgeGraphIntegrationInitialization() {
        let integration = HealthKnowledgeGraphIntegration(
            modelContext: modelContext,
            healthKitManager: healthKitManager,
            healthEnrichment: HealthEnrichment(healthKitManager: healthKitManager, modelContext: modelContext)
        )
        
        XCTAssertNotNil(integration)
        XCTAssertTrue(integration.healthEntities.isEmpty)
        XCTAssertTrue(integration.healthRelationships.isEmpty)
        XCTAssertFalse(integration.isProcessing)
    }
}