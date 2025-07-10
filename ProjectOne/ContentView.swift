import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationSplitView {
            List {
                NavigationLink("Memory Analytics") {
                    MemoryDashboardView(modelContext: modelContext)
                }
                
                NavigationLink("Knowledge Graph") {
                    KnowledgeGraphView(modelContext: modelContext)
                }
                
                NavigationLink("Data Management") {
                    DataExportView(modelContext: modelContext)
                }
                
                NavigationLink("Settings") {
                    SettingsView(gemmaCore: Gemma3nCore.shared)
                }
            }
            .navigationTitle("ProjectOne")
        } detail: {
            VStack {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
                Text("Welcome to ProjectOne")
                    .font(.title)
                    .padding()
                
                Text("AI-powered knowledge system with memory consolidation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
        }
    }
}



#Preview {
    ContentView()
}