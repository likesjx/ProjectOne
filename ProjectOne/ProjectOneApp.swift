import SwiftUI
import SwiftData

@main
struct ProjectOneApp: App {
    @State private var urlHandler = URLHandler()
    @State private var memoryAgentService: MemoryAgentService?
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MemoryAnalytics.self,
            ConsolidationEvent.self,
            MemoryPerformanceMetric.self,
            Entity.self,
            Relationship.self,
            RecordingItem.self,
            ProcessedNote.self,
            NoteItem.self
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
                .environmentObject(urlHandler)
                .onOpenURL { url in
                    Task {
                        await urlHandler.handleURL(url, with: sharedModelContainer.mainContext)
                    }
                }
                .task {
                    // Start background WhisperKit model preloading when app launches
                    await startBackgroundModelPreloading()
                    
                    // Initialize Memory Agent system
                    await initializeMemoryAgent()
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            AppCommands()
        }
        #endif
    }
    
    @MainActor
    private func startBackgroundModelPreloading() async {
        print("🚀 [ProjectOneApp] Starting background WhisperKit model preloading...")
        WhisperKitModelPreloader.shared.startPreloading()
    }
    
    @MainActor
    private func initializeMemoryAgent() async {
        print("🧠 [ProjectOneApp] Initializing Memory Agent system...")
        
        do {
            let service = MemoryAgentService(modelContext: sharedModelContainer.mainContext)
            try await service.start()
            memoryAgentService = service
            print("✅ [ProjectOneApp] Memory Agent system initialized successfully")
        } catch {
            print("❌ [ProjectOneApp] Failed to initialize Memory Agent: \(error)")
        }
    }
}