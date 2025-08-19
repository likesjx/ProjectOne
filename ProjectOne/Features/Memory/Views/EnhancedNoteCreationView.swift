//
//  EnhancedNoteCreationView.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Voice Memo Context

struct VoiceMemoContext {
    let transcription: String
    let audioURL: URL?
    let duration: TimeInterval
    let isFromVoiceMemo: Bool
    
    init(transcription: String, audioURL: URL? = nil, duration: TimeInterval = 0, isFromVoiceMemo: Bool = false) {
        self.transcription = transcription
        self.audioURL = audioURL
        self.duration = duration
        self.isFromVoiceMemo = isFromVoiceMemo
    }
}

/// Enhanced note creation view with real-time memory context integration
struct EnhancedNoteCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Note editing state
    @State private var noteContent = ""
    @State private var noteTitle = ""
    @State private var selectedTags: Set<String> = []
    @State private var isProcessing = false
    
    // Processing visibility
    @StateObject private var textIngestionAgent: TextIngestionAgent
    @State private var showProcessingDetails = false
    
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
    
    // Voice memo context (optional)
    let voiceMemoContext: VoiceMemoContext?
    
    // Configuration
    private let minMemoryPanelWidth: CGFloat = 300
    private let maxMemoryPanelWidth: CGFloat = 500
    private let minEditorWidth: CGFloat = 400
    
    // Computed properties
    private var navigationTitle: String {
        if existingNote != nil {
            return "Edit Note"
        } else if voiceMemoContext?.isFromVoiceMemo == true {
            return "Voice Note"
        } else {
            return "New Note"
        }
    }
    
    init(existingNote: ProcessedNote? = nil, voiceMemoContext: VoiceMemoContext? = nil, modelContext: ModelContext, systemManager: UnifiedSystemManager? = nil) {
        self.existingNote = existingNote
        self.voiceMemoContext = voiceMemoContext
        self._memoryService = StateObject(wrappedValue: RealTimeMemoryService(modelContext: modelContext))
        // Use shared memory service from system manager if available
        let sharedMemoryService = systemManager?.memoryService as? MemoryAgentService
        self._textIngestionAgent = StateObject(wrappedValue: TextIngestionAgent(modelContext: modelContext, memoryService: sharedMemoryService))
        
        if let note = existingNote {
            self._noteContent = State(initialValue: note.originalText)
            self._noteTitle = State(initialValue: note.summary.isEmpty ? "Untitled Note" : note.summary)
            self._selectedTags = State(initialValue: Set(note.topics))
        } else if let voiceContext = voiceMemoContext {
            self._noteContent = State(initialValue: voiceContext.transcription)
            self._noteTitle = State(initialValue: voiceContext.isFromVoiceMemo ? "Voice Note" : "Quick Note")
            self._selectedTags = State(initialValue: voiceContext.isFromVoiceMemo ? Set(["Voice Memo"]) : Set())
        }
    }
    
    var body: some View {
        NavigationStack {
            adaptiveLayout
            .navigationTitle(navigationTitle)
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasUnsavedChanges {
                            showSaveOptions = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
            .sheet(isPresented: $showTagPicker) {
                TagPickerView(selectedTags: $selectedTags) {
                    hasUnsavedChanges = true
                }
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
    
    // MARK: - Adaptive Layout
    
    @ViewBuilder
    private var adaptiveLayout: some View {
#if os(iOS)
        iosLayout
#else
        macOSLayout
#endif
    }
    
    private var iosLayout: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Editor content in full-screen form
                    fullFormEditor
                    
                    // Memory context always shown (stacked below form)
                    if showMemoryPanel {
                        memoryContextSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    private var macOSLayout: some View {
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
    }
    
    // MARK: - Full Form Editor (iOS)
    
    private var fullFormEditor: some View {
        VStack(spacing: 20) {
            // Voice memo context (if applicable)
            if let voiceContext = voiceMemoContext {
                voiceMemoContextSection(voiceContext)
            }
            
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
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80), spacing: 8)
                    ], spacing: 8) {
                        ForEach(Array(selectedTags), id: \.self) { tag in
                            TagChip(tag: tag) {
                                selectedTags.remove(tag)
                                hasUnsavedChanges = true
                            }
                        }
                    }
                }
            }
            
            // Content editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Content")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
#if os(iOS)
                TextEditor(text: $noteContent)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                }
                .frame(minHeight: 200)
#else
                TextEditor(text: $noteContent)
                    .font(.body)
                    .padding(12)
                    .appGlass(.surface, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    }
                    .frame(minHeight: 200)
#endif
            }
            
            // Entity suggestions (if available)
            if !memoryService.getSuggestedEntities().isEmpty {
                entitySuggestions
            }
            
            // Processing indicator with detailed progress
            if isProcessing || textIngestionAgent.isProcessing {
                processingIndicator
            }
        }
    }
    
    // MARK: - Memory Context Section (iOS)
    
    private var memoryContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.mint)
                    .font(.subheadline)
                
                Text("Memory Context")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showMemoryPanel.toggle()
                    }
                } label: {
                    Image(systemName: showMemoryPanel ? "eye.slash" : "eye")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            let memories = Array(memoryService.getRecentMemories().prefix(3))
            if !memories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(memories, id: \.id) { memory in
                        HStack {
                            Circle()
                                .fill(.mint.opacity(0.3))
                                .frame(width: 6, height: 6)
                            
                            Text(memory.content.prefix(100) + (memory.content.count > 100 ? "..." : ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start typing to see relevant memories")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                    
                    if !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No relevant memories found for this content")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.mint.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.mint.opacity(0.2), lineWidth: 1)
                }
        }
    }
    
    // MARK: - Editor Panel (macOS)
    
    private var editorPanel: some View {
        VStack(spacing: 0) {
            // Editor header
            editorHeader
            
            // Main text editor
            ScrollView {
                VStack(spacing: 16) {
                    // Content editor
#if os(iOS)
                    TextEditor(text: $noteContent)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                    .frame(minHeight: 400)
#else
                    TextEditor(text: $noteContent)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .frame(minHeight: 400)
#endif
                    
                    // Entity suggestions (if available)
                    if !memoryService.getSuggestedEntities().isEmpty {
                        entitySuggestions
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    private var editorHeader: some View {
        VStack(spacing: 16) {
            // Voice memo context (if applicable)
            if let voiceContext = voiceMemoContext {
                voiceMemoContextSection(voiceContext)
            }
            
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
                        .foregroundStyle(.secondary)
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
                
                if isProcessing || textIngestionAgent.isProcessing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        
                        Text(textIngestionAgent.statusMessage.isEmpty ? "Processing..." : textIngestionAgent.statusMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            Rectangle()
                .appGlass(.header, shape: Rectangle())
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
    
    // MARK: - Processing Indicator
    
    private var processingIndicator: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(.mint)
                    .font(.subheadline)
                    .rotationEffect(.degrees(textIngestionAgent.isProcessing ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: textIngestionAgent.isProcessing)
                
                Text("Processing Note")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showProcessingDetails.toggle()
                    }
                } label: {
                    Image(systemName: showProcessingDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Progress bar
            ProgressView(value: textIngestionAgent.progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .mint))
                .scaleEffect(y: 1.5)
            
            // Current step and message
            HStack {
                Text(textIngestionAgent.currentStep.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.mint)
                
                Spacer()
                
                Text("\(Int(textIngestionAgent.progress * 100))%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            if !textIngestionAgent.statusMessage.isEmpty {
                Text(textIngestionAgent.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }
            
            // Detailed steps (expandable)
            if showProcessingDetails {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ProcessingStep.allCases, id: \.self) { step in
                        HStack {
                            Image(systemName: stepIcon(for: step))
                                .font(.caption2)
                                .foregroundStyle(stepColor(for: step))
                                .frame(width: 12)
                            
                            Text(step.rawValue)
                                .font(.caption2)
                                .foregroundStyle(stepTextColor(for: step))
                            
                            Spacer()
                            
                            if step == textIngestionAgent.currentStep && textIngestionAgent.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.5)
                            } else if isStepCompleted(step) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            // Error display
            if let error = textIngestionAgent.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.mint.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.mint.opacity(0.2), lineWidth: 1)
                }
        }
    }
    
    // MARK: - Processing Step Helpers
    
    private func stepIcon(for step: ProcessingStep) -> String {
        switch step {
        case .initialization: return "play.circle"
        case .textAnalysis: return "doc.text.magnifyingglass"
        case .entityExtraction: return "person.3"
        case .thoughtExtraction: return "brain"
        case .tagGeneration: return "tag"
        case .knowledgeGraphIntegration: return "network"
        case .embeddingGeneration: return "brain.head.profile"
        case .finalizing: return "archivebox"
        case .completed: return "checkmark.circle"
        }
    }
    
    private func stepColor(for step: ProcessingStep) -> Color {
        if step == textIngestionAgent.currentStep && textIngestionAgent.isProcessing {
            return .mint
        } else if isStepCompleted(step) {
            return .green
        } else {
            return .secondary
        }
    }
    
    private func stepTextColor(for step: ProcessingStep) -> Color {
        if step == textIngestionAgent.currentStep && textIngestionAgent.isProcessing {
            return .primary
        } else if isStepCompleted(step) {
            return .secondary
        } else {
            return .secondary
        }
    }
    
    private func isStepCompleted(_ step: ProcessingStep) -> Bool {
        let allSteps = ProcessingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: textIngestionAgent.currentStep),
              let stepIndex = allSteps.firstIndex(of: step) else {
            return false
        }
        
        return stepIndex < currentIndex || (step == .completed && textIngestionAgent.currentStep == .completed)
    }
    
    // MARK: - Voice Memo Context Section
    
    @ViewBuilder
    private func voiceMemoContextSection(_ context: VoiceMemoContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.subheadline)
                
                Text("Voice Memo Context")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if context.duration > 0 {
                    Text(formatDuration(context.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(.secondary.opacity(0.1))
                        }
                }
            }
            
            if context.isFromVoiceMemo {
                HStack {
                    Circle()
                        .fill(.blue.opacity(0.3))
                        .frame(width: 6, height: 6)
                    
                    Text("Transcribed from voice recording")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.blue.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.blue.opacity(0.2), lineWidth: 1)
                }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
                
                // Save changes first
                try modelContext.save()
                
                // Process with AI in background
                Task {
                    await textIngestionAgent.process(processedNote: existingNote)
                }
                
            } else {
                // Create new note
                let sourceType: NoteSourceType = voiceMemoContext?.isFromVoiceMemo == true ? .audio : .text
                let newNote = ProcessedNote(
                    sourceType: sourceType,
                    originalText: trimmedContent,
                    audioURL: voiceMemoContext?.audioURL,
                    summary: finalTitle.isEmpty ? "Quick Note" : finalTitle,
                    topics: Array(selectedTags)
                )
                
                modelContext.insert(newNote)
                try modelContext.save()
                
                // Process with AI - this will show the progress UI
                await textIngestionAgent.process(processedNote: newNote)
            }
            
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

// MARK: - Note Creation Convenience Initializer

extension EnhancedNoteCreationView {
    /// Convenience initializer for simple note creation without existing note
    init(modelContext: ModelContext) {
        self.init(existingNote: nil, voiceMemoContext: nil, modelContext: modelContext, systemManager: nil)
    }
    
    /// Convenience initializer for voice memo note creation
    init(voiceMemoContext: VoiceMemoContext, modelContext: ModelContext) {
        self.init(existingNote: nil, voiceMemoContext: voiceMemoContext, modelContext: modelContext, systemManager: nil)
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

// MARK: - Tag Picker

struct TagPickerView: View {
    @Binding var selectedTags: Set<String>
    let onTagsChanged: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var newTagText = ""
    @State private var commonTags = ["Important", "Work", "Personal", "Ideas", "Meeting", "TODO", "Research", "Project"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Add new tag section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add New Tag")
                        .font(.headline)
                    
                    HStack {
                        TextField("Enter tag name...", text: $newTagText)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Add") {
                            addNewTag()
                        }
                        .disabled(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.horizontal)
                
                // Common tags section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggested Tags")
                        .font(.headline)
                    
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 8)
                    ], spacing: 8) {
                        ForEach(commonTags, id: \.self) { tag in
                            TagButton(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Currently selected tags
                if !selectedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Selected Tags")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 100), spacing: 8)
                        ], spacing: 8) {
                            ForEach(Array(selectedTags), id: \.self) { tag in
                                TagChip(tag: tag) {
                                    selectedTags.remove(tag)
                                    onTagsChanged()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Tags")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
#endif
            }
        }
    }
    
    private func addNewTag() {
        let trimmedTag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTag.isEmpty else { return }
        
        selectedTags.insert(trimmedTag)
        newTagText = ""
        onTagsChanged()
        
        // Add to common tags if not already there
        if !commonTags.contains(trimmedTag) {
            commonTags.append(trimmedTag)
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
        } else {
            selectedTags.insert(tag)
        }
        onTagsChanged()
    }
}

struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(tag)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? .mint : .secondary.opacity(0.1))
                }
        }
        .buttonStyle(.plain)
    }
}
