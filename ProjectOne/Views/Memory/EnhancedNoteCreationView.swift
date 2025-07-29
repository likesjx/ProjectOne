//
//  EnhancedNoteCreationView.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/29/25.
//

import SwiftUI
import SwiftData

/// Enhanced note creation view with real-time memory context integration
struct EnhancedNoteCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Note editing state
    @State private var noteContent = ""
    @State private var noteTitle = ""
    @State private var selectedTags: Set<String> = []
    @State private var isProcessing = false
    
    // Memory integration
    @StateObject private var memoryService: RealTimeMemoryService
    @State private var showMemoryPanel = true
    @State private var memoryPanelWidth: CGFloat = 350
    
    // UI state
    @State private var showTagPicker = false
    @State private var showSaveOptions = false
    @State private var hasUnsavedChanges = false
    
    // Editing existing note (optional)
    let existingNote: ProcessedNote?
    
    // Configuration
    private let minMemoryPanelWidth: CGFloat = 300
    private let maxMemoryPanelWidth: CGFloat = 500
    private let minEditorWidth: CGFloat = 400
    
    init(existingNote: ProcessedNote? = nil, modelContext: ModelContext) {
        self.existingNote = existingNote
        self._memoryService = StateObject(wrappedValue: RealTimeMemoryService(modelContext: modelContext))
        
        if let note = existingNote {
            self._noteContent = State(initialValue: note.originalText)
            self._noteTitle = State(initialValue: note.summary.isEmpty ? "Untitled Note" : note.summary)
            self._selectedTags = State(initialValue: Set(note.topics))
        }
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Main editor area
                    editorPanel
                        .frame(minWidth: minEditorWidth)
                    
                    if showMemoryPanel {
                        // Resizable divider
                        ResizableDivider(
                            width: $memoryPanelWidth,
                            minWidth: minMemoryPanelWidth,
                            maxWidth: maxMemoryPanelWidth,
                            totalWidth: geometry.size.width - minEditorWidth
                        )
                        
                        // Memory context panel
                        MemoryContextPanel(memoryService: memoryService)
                            .frame(width: memoryPanelWidth)
                    }
                }
            }
            .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showSaveOptions = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .topBarTrailing) {
                    memoryPanelToggle
                    
                    Button("Save") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
#else
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Save") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showSaveOptions = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    memoryPanelToggle
                }
#endif
            }
            .confirmationDialog("Unsaved Changes", isPresented: $showSaveOptions) {
                Button("Save") {
                    Task {
                        await saveNote()
                    }
                }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. What would you like to do?")
            }
        }
        .onChange(of: noteContent) { _, newValue in
            hasUnsavedChanges = true
            
            // Trigger memory retrieval with debouncing
            memoryService.queryMemory(newValue)
        }
        .task {
            // Initialize memory context for existing note
            if let existingNote = existingNote {
                await memoryService.queryMemoryImmediate(existingNote.originalText)
            }
        }
    }
    
    // MARK: - Editor Panel
    
    private var editorPanel: some View {
        VStack(spacing: 0) {
            // Editor header
            editorHeader
            
            // Main text editor
            ScrollView {
                VStack(spacing: 16) {
                    // Content editor
                    TextEditor(text: $noteContent)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 400)
                    
                    // Entity suggestions (if available)
                    if !memoryService.getSuggestedEntities().isEmpty {
                        entitySuggestions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private var editorHeader: some View {
        VStack(spacing: 16) {
            // Title input
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                TextField("Enter note title...", text: $noteTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2.weight(.medium))
            }
            
            // Tags section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tags")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Add Tag") {
                        showTagPicker = true
                    }
                    .font(.caption)
                    .foregroundStyle(.mint)
                }
                
                if selectedTags.isEmpty {
                    Text("No tags added")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedTags), id: \.self) { tag in
                                TagChip(tag: tag) {
                                    selectedTags.remove(tag)
                                    hasUnsavedChanges = true
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
            
            // Editor instructions
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Note Editor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text("Memory context updates as you write")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        
                        Text("Processing...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                        .frame(height: 1)
                }
        }
    }
    
    private var entitySuggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline)
                
                Text("Related Entities")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(memoryService.getSuggestedEntities().prefix(5), id: \.id) { entity in
                        EntitySuggestionChip(entity: entity) {
                            insertEntityReference(entity)
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.yellow.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.yellow.opacity(0.3), lineWidth: 1)
                }
        }
    }
    
    private var memoryPanelToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                showMemoryPanel.toggle()
            }
        } label: {
            Image(systemName: showMemoryPanel ? "sidebar.right" : "sidebar.left")
                .foregroundStyle(showMemoryPanel ? .mint : .secondary)
        }
    }
    
    // MARK: - Actions
    
    private func insertEntityReference(_ entity: Entity) {
        let reference = "[[\(entity.name)]]"
        noteContent += (noteContent.isEmpty ? "" : " ") + reference
        hasUnsavedChanges = true
    }
    
    private func saveNote() async {
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let trimmedContent = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalTitle = noteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let existingNote = existingNote {
                // Update existing note
                existingNote.originalText = trimmedContent
                existingNote.summary = finalTitle.isEmpty ? "Updated Note" : finalTitle
                existingNote.topics = Array(selectedTags)
                existingNote.lastAccessed = Date()
                existingNote.consolidationLevel = .volatile // Mark for reprocessing
                
            } else {
                // Create new note
                let newNote = ProcessedNote(
                    sourceType: .text,
                    originalText: trimmedContent,
                    summary: finalTitle.isEmpty ? "Quick Note" : finalTitle,
                    topics: Array(selectedTags)
                )
                
                modelContext.insert(newNote)
            }
            
            try modelContext.save()
            hasUnsavedChanges = false
            dismiss()
            
        } catch {
            print("Failed to save note: \(error)")
        }
    }
}

// MARK: - Supporting Components

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.caption.weight(.medium))
                .foregroundStyle(.mint)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.mint.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.mint.opacity(0.15))
        }
    }
}

struct EntitySuggestionChip: View {
    let entity: Entity
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: entity.type.systemImageName)
                    .font(.caption2)
                    .foregroundStyle(entity.type.swiftUIColor)
                
                Text(entity.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(entity.type.swiftUIColor.opacity(0.1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(entity.type.swiftUIColor.opacity(0.3), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

struct ResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let totalWidth: CGFloat
    
    @State private var isDragging = false
    
    var body: some View {
        Rectangle()
            .fill(.secondary.opacity(0.3))
            .frame(width: 1)
            .overlay {
                Rectangle()
                    .fill(.clear)
                    .frame(width: 10)
                    .contentShape(Rectangle())
#if os(macOS)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.resizeLeftRight.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
#endif
                    .onDrag {
                        NSItemProvider(object: "" as NSString)
                    } preview: {
                        EmptyView()
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let translationX = value.translation.width // Use width instead of x
                                let newWidth = width - translationX
                                width = max(minWidth, min(maxWidth, min(newWidth, totalWidth)))
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .background {
                if isDragging {
                    Rectangle()
                        .fill(.mint.opacity(0.1))
                        .frame(width: 10)
                }
            }
    }
}

// MARK: - Note Creation Sheet

struct NoteCreationView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        EnhancedNoteCreationView(modelContext: modelContext)
    }
}

#Preview {
    struct PreviewWrapper: View {
        let container = try! SwiftData.ModelContainer(
            for: ProcessedNote.self, STMEntry.self, LTMEntry.self, EpisodicMemoryEntry.self, Entity.self, Relationship.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        var body: some View {
            EnhancedNoteCreationView(modelContext: container.mainContext)
        }
    }
    
    return PreviewWrapper()
}