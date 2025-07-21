//
//  MarkdownNotesView.swift
//  ProjectOne
//
//  Created on 7/13/25.
//

import SwiftUI
import SwiftData

struct MarkdownNotesView: View {
    let modelContext: ModelContext
    
    @Query(sort: [SortDescriptor(\ProcessedNote.timestamp, order: .reverse)]) 
    private var allNotes: [ProcessedNote]
    
    private var notes: [ProcessedNote] {
        allNotes.filter { $0.sourceType == .text }
    }
    
    @State private var showingNoteCreation = false
    @State private var searchText = ""
    
    var filteredNotes: [ProcessedNote] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter { note in
                note.originalText.localizedCaseInsensitiveContains(searchText) ||
                note.summary.localizedCaseInsensitiveContains(searchText) ||
                note.topics.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        LiquidGlassView {
            VStack(spacing: 0) {
                // Header
                LiquidGlassHeader {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    LiquidGlassIcon(
                                        icon: "doc.text.fill",
                                        size: 32,
                                        color: .mint,
                                        isAnimated: false
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Notes")
                                            .font(.title.weight(.bold))
                                            .foregroundStyle(.primary)
                                        
                                        Text("\(notes.count) notes")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Text("Markdown-powered note-taking")
                                    .font(.caption)
                                    .foregroundStyle(.mint)
                            }
                            
                            Spacer()
                            
                            // New note button
                            Button {
                                showingNoteCreation = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.mint)
                                    .frame(width: 44, height: 44)
                                    .background {
                                        Circle()
                                            .fill(.regularMaterial)
                                            .overlay { Color.mint.opacity(0.15) }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            
                            TextField("Search notes...", text: $searchText)
                                .textFieldStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(.regularMaterial)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(.mint.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                
                // Notes list
                if filteredNotes.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: searchText.isEmpty ? "doc.text" : "magnifyingglass")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.mint.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text(searchText.isEmpty ? "No notes yet" : "No matching notes")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                            
                            Text(searchText.isEmpty ? "Tap + to create your first note" : "Try a different search term")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        if searchText.isEmpty {
                            Button {
                                showingNoteCreation = true
                            } label: {
                                Text("Create Note")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.mint)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                } else {
                    // Notes list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredNotes) { note in
                                NoteCard(note: note)
                                    .onTapGesture {
                                        // TODO: Open note for editing
                                    }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    }
                }
            }
        }
        .navigationTitle("Notes")
        .sheet(isPresented: $showingNoteCreation) {
            LiquidGlassSheet {
                NoteCreationView()
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

// MARK: - Note Card Component

struct NoteCard: View {
    let note: ProcessedNote
    
    private var previewText: String {
        let text = note.originalText
        if text.count > 150 {
            return String(text.prefix(150)) + "..."
        }
        return text
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: note.timestamp, relativeTo: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with topics and date
            HStack {
                if !note.topics.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(note.topics.prefix(3), id: \.self) { topic in
                                Text(topic)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.mint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(.mint.opacity(0.15))
                                    }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                } else {
                    Text("Quick Note")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Content preview
            VStack(alignment: .leading, spacing: 8) {
                if !note.summary.isEmpty && note.summary != "Quick note" {
                    Text(note.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                
                Text(previewText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            // Footer with consolidation status
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(consolidationColor)
                        .frame(width: 8, height: 8)
                    
                    Text(consolidationText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if note.accessFrequency > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "eye")
                            .font(.caption2)
                        
                        Text("\(note.accessFrequency)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.mint.opacity(0.2), lineWidth: 1)
                }
        }
        .contentShape(Rectangle())
    }
    
    private var consolidationColor: Color {
        switch note.consolidationLevel {
        case .volatile: return .orange
        case .consolidating: return .yellow
        case .stable: return .green
        }
    }
    
    private var consolidationText: String {
        switch note.consolidationLevel {
        case .volatile: return "Processing"
        case .consolidating: return "Analyzing"
        case .stable: return "Integrated"
        }
    }
}

#Preview {
    NavigationStack {
        MarkdownNotesView(modelContext: ModelContext.preview)
    }
}

// MARK: - Preview Extensions

extension ModelContext {
    static var preview: ModelContext {
        let container = try! SwiftData.ModelContainer(for: ProcessedNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        
        // Add sample notes
        let context = container.mainContext
        
        let note1 = ProcessedNote(
            sourceType: .text,
            originalText: "# Meeting Notes\n\n- Discussed project timeline\n- **Action items:** Review documentation\n- Follow up on budget approval",
            summary: "Meeting notes with action items",
            topics: ["Meeting", "Timeline", "Budget"]
        )
        note1.consolidationLevel = .stable
        note1.accessFrequency = 3
        
        let note2 = ProcessedNote(
            sourceType: .text,
            originalText: "Quick idea: What if we added a feature that automatically categorizes notes based on content? Could use ML for this.",
            summary: "Feature idea for auto-categorization",
            topics: ["Feature", "ML"]
        )
        note2.consolidationLevel = .consolidating
        
        context.insert(note1)
        context.insert(note2)
        
        return context
    }
}