import SwiftUI
import SwiftData
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
    
    // Trimmed SwiftData schema to only include models that currently exist in the project.
    // Add additional models back here as they are implemented and available.
    var sharedModelContainer: SwiftData.ModelContainer = {
        let schema = Schema([
            // Note and content models known to exist
            ProcessedNote.self,
            Thought.self,
            NoteItem.self,
            RecordingItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If you don't have ErrorLogger implemented, replace the following line with a simple Logger.
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
}
