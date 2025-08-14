import SwiftUI
import SwiftData
import Foundation
import Combine
import os.log

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
    @StateObject private var initCoordinator = InitializationCoordinator()
    @StateObject private var providerFactory = ExternalProviderFactory(settings: AIProviderSettings())
    
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
            Thought.self,
            
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
            ErrorLogger.log(.modelContainerCreationFailed(error.localizedDescription))
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if let systemManager = initCoordinator.systemManager {
                ContentView()
                    .environmentObject(urlHandler)
                    .environmentObject(systemManager)
                    .environmentObject(providerFactory)
                    .onOpenURL { url in
                        Task {
                            await urlHandler.handleURL(url, with: sharedModelContainer.mainContext)
                        }
                    }
            } else {
                SystemInitializationView()
                    .environmentObject(initCoordinator)
                    .onAppear {
                        // Disable haptic feedback in simulator to prevent log errors
                        #if os(iOS)
                        disableHapticsInSimulator()
                        #endif
                        
                        // Start cancellation-resistant initialization
                        initCoordinator.ensureInitialized(modelContainer: sharedModelContainer)
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
}
