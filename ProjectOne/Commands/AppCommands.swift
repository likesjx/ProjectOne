//
//  AppCommands.swift
//  ProjectOne
//
//  Created on 7/13/25.
//

import SwiftUI

#if os(macOS)
struct AppCommands: Commands {
    @FocusedValue(\.selectedSection) private var selectedSection
    @FocusedValue(\.showingQuickNote) private var showingQuickNote
    
    var body: some Commands {
        // File Menu
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                showingQuickNote?.wrappedValue = true
            }
            .keyboardShortcut("n", modifiers: .command)
            
            Button("New Voice Memo") {
                selectedSection?.wrappedValue = .voiceMemos
                // Trigger voice memo recording
            }
            .keyboardShortcut("r", modifiers: .command)
        }
        
        // View Menu
        CommandMenu("View") {
            Button("All Content") {
                selectedSection?.wrappedValue = .allContent
            }
            .keyboardShortcut("1", modifiers: .command)
            
            Button("Voice Memos") {
                selectedSection?.wrappedValue = .voiceMemos
            }
            .keyboardShortcut("2", modifiers: .command)
            
            Button("Memory Dashboard") {
                selectedSection?.wrappedValue = .memory
            }
            .keyboardShortcut("3", modifiers: .command)
            
            Button("Knowledge Graph") {
                selectedSection?.wrappedValue = .knowledge
            }
            .keyboardShortcut("4", modifiers: .command)
            
            Button("Notes") {
                selectedSection?.wrappedValue = .notes
            }
            .keyboardShortcut("5", modifiers: .command)
            
            Button("Data Export") {
                selectedSection?.wrappedValue = .data
            }
            .keyboardShortcut("6", modifiers: .command)
            
            Divider()
            
            Button("Settings") {
                selectedSection?.wrappedValue = .settings
            }
            .keyboardShortcut("7", modifiers: .command)
        }
        
        // Window Menu
        CommandGroup(after: .windowArrangement) {
            Button("Toggle Sidebar") {
                // Will implement sidebar toggle
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
        }
    }
}

// MARK: - Focused Value Keys

private struct SelectedSectionKey: FocusedValueKey {
    typealias Value = Binding<SidebarSection>
}

private struct ShowingQuickNoteKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    var selectedSection: Binding<SidebarSection>? {
        get { self[SelectedSectionKey.self] }
        set { self[SelectedSectionKey.self] = newValue }
    }
    
    var showingQuickNote: Binding<Bool>? {
        get { self[ShowingQuickNoteKey.self] }
        set { self[ShowingQuickNoteKey.self] = newValue }
    }
}
#endif