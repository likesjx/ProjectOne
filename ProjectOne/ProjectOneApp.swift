import SwiftUI
import SwiftData

@main
struct ProjectOneApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MemoryAnalytics.self,
            ConsolidationEvent.self,
            MemoryPerformanceMetric.self,
            Entity.self,
            Relationship.self,
            RecordingItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Start background WhisperKit model preloading when app launches
                    await startBackgroundModelPreloading()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    @MainActor
    private func startBackgroundModelPreloading() async {
        print("🚀 [ProjectOneApp] Starting background WhisperKit model preloading...")
        WhisperKitModelPreloader.shared.startPreloading()
    }
}