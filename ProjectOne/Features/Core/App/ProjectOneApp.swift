import SwiftUI
import SwiftData
import Foundation

#if os(iOS)
import UIKit
#if canImport(HealthKit)
import HealthKit
#endif

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
        var models: [any PersistentModel.Type] = [
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
            // Thought.self, // TODO: Add Thought.swift to Xcode project target
            
            // Prompt models
            PromptTemplate.self,
            
            // User profile models
            UserSpeechProfile.self,
            
            // Cognitive decision models
            CognitiveDecision.self
        ]
        
        // Health models are included from HealthData.swift when available
        
        let schema = Schema(models)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            ErrorLogger.log(.modelContainerCreationFailed(error.localizedDescription))
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let systemManager = unifiedSystemManager {
                let enhancedCore = EnhancedGemma3nCore()
                ContentView()
                    .environmentObject(urlHandler)
                    .environmentObject(systemManager)
                    .environmentObject(enhancedCore)
                    .environmentObject(enhancedCore as Gemma3nCore)
                    .onOpenURL { url in
                        Task {
                            await urlHandler.handleURL(url, with: sharedModelContainer.mainContext)
                        }
                    }
            } else {
                if let initManager = initializingSystemManager {
                    SystemInitializationView() // Temporary - removed systemManager parameter
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
        
        // Create the unified system manager with dependency injection
        let systemManager = UnifiedSystemManager(
            modelContext: sharedModelContainer.mainContext,
            configuration: .default,
            serviceFactory: DefaultServiceFactory()
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