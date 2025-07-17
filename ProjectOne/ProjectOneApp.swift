import SwiftUI
import SwiftData

@main
struct ProjectOneApp: App {
    @State private var urlHandler = URLHandler()
    @State private var memoryAgentService: MemoryAgentService?
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // Analytics models
            MemoryAnalytics.self,
            ConsolidationEvent.self,
            MemoryPerformanceMetric.self,
            
            // Memory models
            STMEntry.self,
            LTMEntry.self,
            WorkingMemoryEntry.self,
            EpisodicMemoryEntry.self,
            
            // Knowledge graph models
            Entity.self,
            Relationship.self,
            
            // Note models
            RecordingItem.self,
            ProcessedNote.self,
            NoteItem.self,
            
            // Prompt models
            PromptTemplate.self
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
                    
                    // Initialize Memory Agent system - temporarily disabled during prompt testing
                    // await initializeMemoryAgent()
                    
                    // Run enhanced prompt system tests - temporarily disabled during prompt testing
                    // await runEnhancedPromptTests()
                    
                    // Run memory system tests - temporarily disabled during prompt testing
                    // await runMemorySystemTests(modelContext: sharedModelContainer.mainContext)
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
    
    @MainActor
    private func runEnhancedPromptTests() async {
        print("🧪 [ProjectOneApp] Enhanced Prompt System Tests disabled during development")
        // Tests temporarily disabled during prompt management integration
    }
    
    @MainActor
    private func runMemorySystemTests(modelContext: ModelContext) async {
        print("🧪 [ProjectOneApp] Memory System Tests disabled during development")
        // Tests temporarily disabled during prompt management integration
    }
}