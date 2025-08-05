import SwiftUI
import SwiftData

#if os(iOS)
import UIKit

// Suppress haptic feedback system errors in simulator
private func disableHapticsInSimulator() {
    #if targetEnvironment(simulator)
    // Disable haptic feedback generation in simulator to prevent CHHapticPattern errors
    UserDefaults.standard.set(false, forKey: "UIFeedbackGenerator.hapticFeedbackEnabled")
    #endif
}
#endif

@main
struct ProjectOneApp: App {
    @State private var urlHandler = URLHandler()
    @State private var unifiedSystemManager: UnifiedSystemManager?
    @State private var initializingSystemManager: UnifiedSystemManager?
    
    var sharedModelContainer: SwiftData.ModelContainer = {
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
            PromptTemplate.self,
            
            // User profile models
            UserSpeechProfile.self,
            
            // Cognitive decision models
            CognitiveDecision.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let systemManager = unifiedSystemManager {
                ContentView()
                    .environmentObject(urlHandler)
                    .environmentObject(systemManager)
                    .environmentObject(Gemma3nCore())
                    .onOpenURL { url in
                        Task {
                            await urlHandler.handleURL(url, with: sharedModelContainer.mainContext)
                        }
                    }
            } else {
                if let initManager = initializingSystemManager {
                    SystemInitializationView(systemManager: initManager)
                } else {
                    SystemInitializationView()
                        .task {
                            // Disable haptic feedback in simulator to prevent log errors
                            #if os(iOS)
                            disableHapticsInSimulator()
                            #endif
                            
                            // Initialize the unified system
                            await initializeUnifiedSystem()
                        }
                }
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
    private func initializeUnifiedSystem() async {
        print("🚀 [ProjectOneApp] Starting unified system initialization...")
        
        // Create the unified system manager
        let systemManager = UnifiedSystemManager(
            modelContext: sharedModelContainer.mainContext,
            configuration: .default
        )
        
        // Store the initializing system manager so the UI can observe progress
        initializingSystemManager = systemManager
        
        // Initialize the entire system
        await systemManager.initializeSystem()
        
        // Store the system manager for use throughout the app
        unifiedSystemManager = systemManager
        initializingSystemManager = nil
        
        print("🎉 [ProjectOneApp] Unified system initialization completed successfully")
    }
}