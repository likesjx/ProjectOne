import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            LiquidGlassTabContainer(selectedTab: $selectedTab) {
                TabView(selection: $selectedTab) {
                    VoiceMemoView(modelContext: modelContext)
                        .tabItem {
                            Label("Voice Memos", systemImage: "mic.circle.fill")
                        }
                        .tag(0)
                        .background { Color.blue.opacity(0.15) }
                        .glassEffect(.regular)
                    
                    MemoryDashboardView(modelContext: modelContext)
                        .tabItem {
                            Label("Memory", systemImage: "brain.head.profile")
                        }
                        .tag(1)
                        .background { Color.purple.opacity(0.15) }
                        .glassEffect(.regular)
                    
                    KnowledgeGraphView(modelContext: modelContext)
                        .tabItem {
                            Label("Knowledge", systemImage: "network")
                        }
                        .tag(2)
                        .background { Color.green.opacity(0.15) }
                        .glassEffect(.regular)
                    
                    DataExportView(modelContext: modelContext)
                        .tabItem {
                            Label("Data", systemImage: "externaldrive.fill")
                        }
                        .tag(3)
                        .background { Color.orange.opacity(0.15) }
                        .glassEffect(.regular)
                    
                    SettingsView(gemmaCore: Gemma3nCore.shared)
                        .tabItem {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .tag(4)
                        .background { Color.gray.opacity(0.15) }
                        .glassEffect(.regular)
                }
                .liquidGlassTabStyle()
            }
            .navigationTitle("ProjectOne")
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    LiquidGlassToolbarGroup {
                        QuickActionButton(icon: "plus.circle.fill", color: .blue) {
                            // Quick note action
                        }
                        
                        QuickActionButton(icon: "mic.badge.plus", color: .red) {
                            // Quick voice memo
                        }
                    }
                }
            }
            .liquidGlassToolbar()
        }
        .liquidGlassContainer()
    }
}

// MARK: - Enhanced Liquid Glass Components

struct LiquidGlassTabContainer<Content: View>: View {
    @Binding var selectedTab: Int
    let content: Content
    
    init(selectedTab: Binding<Int>, @ViewBuilder content: () -> Content) {
        self._selectedTab = selectedTab
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                LiquidGlassBackgroundExtension(selectedTab: selectedTab)
            }
    }
}

struct LiquidGlassBackgroundExtension: View {
    let selectedTab: Int
    
    private var activeColor: Color {
        switch selectedTab {
        case 0: return .blue
        case 1: return .purple
        case 2: return .green
        case 3: return .orange
        case 4: return .gray
        default: return .blue
        }
    }
    
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay { activeColor.opacity(0.08) }
            .ignoresSafeArea(.all)
            .animation(.smooth(duration: 0.5), value: selectedTab)
    }
}

struct LiquidGlassToolbarGroup<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay { Color.primary.opacity(0.05) }
        }
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
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.regularMaterial)
                        .overlay { color.opacity(0.15) }
                }
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Liquid Glass View Modifiers

extension View {
    func liquidGlassContainer() -> some View {
        self
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark) // Optimize for glass readability
    }
    
    func glassBackground() -> some View {
        self
            .glassEffect(.regular)
            .compositingGroup()
    }
    
    func liquidGlassTabStyle() -> some View {
        self
            .tabViewStyle(.automatic)
            .background(.regularMaterial)
    }
    
    func liquidGlassToolbar() -> some View {
        self
#if os(iOS)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackground(.regularMaterial, for: .tabBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
            #endif
    }
}



#Preview {
    ContentView()
}
