import SwiftUI
import SwiftData
import HealthKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var urlHandler: URLHandler
    @EnvironmentObject private var systemManager: UnifiedSystemManager
    @State private var selectedTab = 0
    @State private var showingQuickNote = false
    
    var body: some View {
        #if os(macOS)
        ContentView_macOS()
            .environmentObject(urlHandler)
            .environmentObject(systemManager)
        #else
        ZStack {
            // Adaptive tinted gradient behind system glass (fallback on < iOS 26)
            LinearGradient(colors: [.black, .indigo.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            // Optional dynamic tint overlay by tab
            Color(activeTabColor.opacity(0.10)).ignoresSafeArea()
            
            NavigationStack {
                MainTabView(selectedTab: $selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .glassNavigationTitle("ProjectOne", displayMode: .compact)
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            GlassToolbarActions(selectedTab: $selectedTab, showingQuickNote: $showingQuickNote)
                        }
                    }
                    .toolbarBackground(.ultraThinMaterial, for: .navigationBar, .tabBar)
                    .toolbarBackgroundVisibility(.visible, for: .navigationBar, .tabBar)
                    .ignoresSafeArea(edges: [.bottom])
            }
        }
        .ignoresSafeArea()
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showingQuickNote) {
            EnhancedNoteCreationView(modelContext: modelContext, systemManager: systemManager)
        }
        .alert("Note Imported", isPresented: $urlHandler.showingImportedNote) {
            Button("View Notes") {
                selectedTab = 0 // Switch to All Content tab which shows notes
            }
            Button("OK") { }
        } message: {
            Text("Successfully imported note from external app")
        }
        #endif
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Binding var selectedTab: Int
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var systemManager: UnifiedSystemManager
    @State private var triggerVoiceMemoRecording = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ContentListView()
                .tabItem {
                    Label("All Content", systemImage: "list.bullet")
                }
                .tag(0)
                
            PromptManagementView(modelContext: modelContext)
                .tabItem {
                    Label("Prompts", systemImage: "quote.bubble.fill")
                }
                .tag(1)
                
            VoiceMemoView(modelContext: modelContext, triggerRecording: $triggerVoiceMemoRecording)
                .tabItem {
                    Label("Voice Memos", systemImage: "mic.circle.fill")
                }
                .tag(2)
                
            #if canImport(HealthKit)
            HealthDashboardView()
                .tabItem {
                    Label("Health", systemImage: "heart.text.square")
                }
                .tag(3)
            #endif
            
            MemoryDashboardView(modelContext: modelContext)
                .tabItem {
                    Label("Memory", systemImage: "brain.head.profile")
                }
                .tag(4)
                
            KnowledgeGraphView(modelContext: modelContext)
                .tabItem {
                    Label("Knowledge", systemImage: "network")
                }
                .tag(5)
                
            NavigationStack {
                // Temporary placeholder view until LLMManagementView build issues are resolved
                VStack(spacing: 20) {
                    Image(systemName: "cpu")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("AI Models Management")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Model management interface is being set up.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("AI Models")
            }
            .tabItem {
                Label("AI Models", systemImage: "cpu")
            }
            .tag(6)
                
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(7)
        }
    }
}

// (Deprecated LiquidGlass components removed after migration to appGlass / system glass)

struct LiquidGlassToolbarGroup<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 12) { content }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .appGlass(.pill, tint: .primary.opacity(0.4), shape: Capsule())
    }
}

struct QuickActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .circleGlass(tint: color)
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Glass Toolbar Wrapper

private struct GlassToolbarActions: View {
    @Binding var selectedTab: Int
    @Binding var showingQuickNote: Bool
    
    var body: some View {
        LiquidGlassToolbarGroup {
            QuickActionButton(icon: "plus.circle.fill", color: .mint) { showingQuickNote = true }
            QuickActionButton(icon: "mic.badge.plus", color: .red) { selectedTab = 2 }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick Actions")
    }
}

// MARK: - Active Tab Color Helper

extension ContentView {
    var activeTabColor: Color {
        switch selectedTab {
        case 0: return .indigo
        case 1: return .pink
        case 2: return .blue
        case 3: return .purple
        case 4: return .cyan
        case 5: return .green
        case 6: return .orange
        case 7: return .mint
        default: return .indigo
        }
    }
}

// MARK: - Liquid Glass View Modifiers

extension View {
    func liquidGlassContainer() -> some View {
        self
            .background(
                Group {
            // Unified material background (previously conditional glassEffect for iOS 26)
            Color.clear.background(.ultraThinMaterial)
                }
            )
    }
    
    func glassBackground() -> some View {
        self
        // Replaced unsupported glassEffect with ultraThinMaterial to simulate translucency
        .background(.ultraThinMaterial)
            .compositingGroup()
    }
    
    func liquidGlassTabStyle() -> some View {
        self
            .tabViewStyle(.automatic)
    }
    
    func liquidGlassToolbar() -> some View {
        self
#if os(iOS)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
#endif
    }
}





#Preview {
    ContentView()
}
