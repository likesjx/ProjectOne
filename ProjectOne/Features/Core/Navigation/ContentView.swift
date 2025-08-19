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
                    .navigationTitle("ProjectOne")
                    .navigationBarTitleDisplayMode(.inline)
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



// MARK: - Health Dashboard Implementation

struct HealthDashboardView: View {
    @State private var selectedTimeRange: HealthTimeRange = .week
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if !HKHealthStore.isHealthDataAvailable() {
                        HealthUnavailableCard()
                            .padding(.horizontal)
                    } else {
                        TimeRangeSelector(selectedRange: $selectedTimeRange)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView("Loading health data...")
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            HealthMetricsPlaceholder()
                                .padding(.horizontal)
                            
                            HealthInsightsSection()
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Health Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

struct HealthUnavailableCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("Health Data Unavailable")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Health data is not available on this device or simulator.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    .padding(24)
    .appGlass(.elevated, tint: .red, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct TimeRangeSelector: View {
    @Binding var selectedRange: HealthTimeRange
    
    var body: some View {
        HStack {
            ForEach(HealthTimeRange.allCases, id: \.self) { range in
                Button(action: { selectedRange = range }) {
                    Text(range.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedRange == range ? Color.accentColor : Color.clear)
                        .foregroundColor(selectedRange == range ? .white : .primary)
                        .cornerRadius(8)
                }
            }
        }
    .padding(4)
    .appGlass(.header, tint: .accentColor, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthMetricsPlaceholder: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            HealthMetricCard(title: "Heart Rate", value: "--", unit: "bpm", icon: "heart.fill", color: .red)
            HealthMetricCard(title: "Steps", value: "--", unit: "steps", icon: "figure.walk", color: .green)
            HealthMetricCard(title: "Calories", value: "--", unit: "kcal", icon: "flame.fill", color: .orange)
            HealthMetricCard(title: "Sleep", value: "--", unit: "hours", icon: "bed.double.fill", color: .blue)
        }
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .appGlass(.surface, tint: color, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthInsightsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Insights")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Connect with HealthKit to see personalized insights and correlations with your voice notes.")
                .foregroundColor(.secondary)
                .padding()
                .appGlass(.surface, tint: .indigo, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

enum HealthTimeRange: String, CaseIterable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
    
    var displayName: String {
        switch self {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        }
    }
}

#Preview {
    ContentView()
}
