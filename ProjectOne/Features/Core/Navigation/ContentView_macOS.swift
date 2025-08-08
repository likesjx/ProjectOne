//
//  ContentView_macOS.swift
//  ProjectOne
//
//  Created on 7/13/25.
//

#if os(macOS)
import SwiftUI
import SwiftData

struct ContentView_macOS: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var urlHandler: URLHandler
    @EnvironmentObject private var systemManager: UnifiedSystemManager
    @State private var selectedSection: SidebarSection = .allContent
    @State private var showingQuickNote = false
    @State private var triggerVoiceMemoRecording = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .automatic
    
    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            MacOSSidebar(selectedSection: $selectedSection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            Group {
                switch selectedSection {
                case .allContent:
                    ContentListView()
                case .voiceMemos:
                    VoiceMemoView(modelContext: modelContext, triggerRecording: $triggerVoiceMemoRecording)
                case .memory:
                    MemoryDashboardView(modelContext: modelContext)
                case .cognitive:
                    if let cognitiveEngine = systemManager.cognitiveEngine {
                        CognitiveDecisionDashboard()
                            .environmentObject(cognitiveEngine)
                    } else {
                        VStack {
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.cyan.opacity(0.6))
                            Text("Cognitive Dashboard Initializing...")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("Decision tracking engine starting up")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .knowledge:
                    KnowledgeGraphView(modelContext: modelContext)
                case .notes:
                    MarkdownNotesView(modelContext: modelContext)
                case .data:
                    DataExportView(modelContext: modelContext)
                case .prompts:
                    PromptManagementView(modelContext: modelContext)
                case .settings:
                    SettingsView(gemmaCore: Gemma3nCore())
                }
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .navigationTitle("ProjectOne")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                MacOSToolbarGroup(
                    showingQuickNote: $showingQuickNote, 
                    selectedSection: $selectedSection,
                    triggerVoiceMemoRecording: $triggerVoiceMemoRecording
                )
            }
        }
        .sheet(isPresented: $showingQuickNote) {
            EnhancedNoteCreationView(modelContext: modelContext)
                .frame(minWidth: 800, minHeight: 600)
        }
        .alert("Note Imported", isPresented: $urlHandler.showingImportedNote) {
            Button("View All Content") {
                selectedSection = .allContent
            }
            Button("OK") { }
        } message: {
            Text("Successfully imported note from external app")
        }
        .focusedSceneValue(\.selectedSection, $selectedSection)
        .focusedSceneValue(\.showingQuickNote, $showingQuickNote)
        .focusedSceneValue(\.triggerVoiceMemoRecording, $triggerVoiceMemoRecording)
    }
}

// MARK: - Sidebar Section Definition

enum SidebarSection: String, CaseIterable, Identifiable {
    case allContent = "All Content"
    case voiceMemos = "Voice Memos"
    case memory = "Memory"
    case cognitive = "Cognitive"
    case knowledge = "Knowledge"
    case notes = "Notes"
    case data = "Data"
    case prompts = "Prompts"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .allContent: return "list.bullet"
        case .voiceMemos: return "mic.circle.fill"
        case .memory: return "brain.head.profile"
        case .cognitive: return "cpu.fill"
        case .knowledge: return "network"
        case .notes: return "doc.text.fill"
        case .data: return "externaldrive.fill"
        case .prompts: return "quote.bubble.fill"
        case .settings: return "gearshape.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .allContent: return .indigo
        case .voiceMemos: return .blue
        case .memory: return .purple
        case .cognitive: return .cyan
        case .knowledge: return .green
        case .notes: return .mint
        case .data: return .orange
        case .prompts: return .pink
        case .settings: return .gray
        }
    }
    
    var shortcutKey: String {
        switch self {
        case .allContent: return "1"
        case .voiceMemos: return "2"
        case .memory: return "3"
        case .cognitive: return "4"
        case .knowledge: return "5"
        case .notes: return "6"
        case .data: return "7"
        case .prompts: return "8"
        case .settings: return "9"
        }
    }
}

// MARK: - macOS Sidebar

struct MacOSSidebar: View {
    @Binding var selectedSection: SidebarSection
    
    var body: some View {
        List(SidebarSection.allCases, selection: $selectedSection) { section in
            SidebarRow(section: section, isSelected: selectedSection == section)
                .tag(section)
        }
        .listStyle(.sidebar)
        .navigationTitle("ProjectOne")
        .background {
            MacOSSidebarBackground()
        }
    }
}

struct SidebarRow: View {
    let section: SidebarSection
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: section.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(section.color)
                .frame(width: 20)
            
            Text(section.rawValue)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            Spacer()
            
            if isHovered && !isSelected {
                Text("⌘\(section.shortcutKey)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.selection)
            } else if isHovered {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(0.06))
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .contentShape(Rectangle())
    }
}

struct MacOSSidebarBackground: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
            }
            .ignoresSafeArea()
    }
}

// MARK: - macOS Toolbar

struct MacOSToolbarGroup: View {
    @Binding var showingQuickNote: Bool
    @Binding var selectedSection: SidebarSection
    @Binding var triggerVoiceMemoRecording: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            MacOSToolbarButton(
                icon: "plus.circle.fill",
                color: .mint,
                tooltip: "Quick Note (⌘N)"
            ) {
                showingQuickNote = true
            }
            
            MacOSToolbarButton(
                icon: "mic.badge.plus",
                color: .red,
                tooltip: "Quick Voice Memo (⌘R)"
            ) {
                selectedSection = .voiceMemos
                triggerVoiceMemoRecording = true
            }
        }
    }
}

struct MacOSToolbarButton: View {
    let icon: String
    let color: Color
    let tooltip: String
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(.primary.opacity(0.1), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
        .pressEvents {
            isPressed = true
        } onRelease: {
            isPressed = false
        }
    }
}

// MARK: - Press Events Modifier

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

struct PressEventsModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }, perform: {})
    }
}

#Preview {
    let schema = Schema([ProcessedNote.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! SwiftData.ModelContainer(for: schema, configurations: [configuration])
    let systemManager = UnifiedSystemManager(modelContext: container.mainContext)
    
    ContentView_macOS()
        .environmentObject(URLHandler())
        .environmentObject(systemManager)
        .modelContainer(container)
}

#endif