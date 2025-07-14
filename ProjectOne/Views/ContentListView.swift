//
//  ContentListView.swift
//  ProjectOne
//
//  Created on 7/13/25.
//

import SwiftUI
import SwiftData

struct ContentListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\RecordingItem.timestamp, order: .reverse)]) 
    private var recordings: [RecordingItem]
    @Query(sort: [SortDescriptor(\ProcessedNote.timestamp, order: .reverse)]) 
    private var notes: [ProcessedNote]
    
    @State private var searchText = ""
    @State private var selectedFilter: ContentFilter = .all
    @State private var showingFilters = false
    
    private var combinedContent: [ContentItem] {
        let allItems = recordings.map { ContentItem.recording($0) } + 
                      notes.map { ContentItem.note($0) }
        
        let filtered = filteredContent(allItems)
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func filteredContent(_ items: [ContentItem]) -> [ContentItem] {
        var filtered = items
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .recordings:
            filtered = filtered.filter { if case .recording = $0 { return true }; return false }
        case .notes:
            filtered = filtered.filter { if case .note = $0 { return true }; return false }
        case .favorites:
            filtered = filtered.filter { $0.isFavorite }
        case .unprocessed:
            filtered = filtered.filter { !$0.isProcessed }
        }
        
        // Apply search
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.content.localizedCaseInsensitiveContains(searchText) ||
                item.tags.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and Filter Bar
                ContentSearchBar(
                    searchText: $searchText,
                    selectedFilter: $selectedFilter,
                    showingFilters: $showingFilters
                )
                
                // Content List
                List {
                    if combinedContent.isEmpty {
                        ContentEmptyState(hasSearchOrFilter: !searchText.isEmpty || selectedFilter != .all)
                    } else {
                        ForEach(combinedContent) { item in
                            ContentListRow(item: item)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .listRowSeparator(.hidden)
                                #if os(iOS)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    ContentSwipeActions(item: item, modelContext: modelContext)
                                }
                                #endif
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    // Pull to refresh functionality
                    await refreshContent()
                }
            }
            .navigationTitle("All Content")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    ContentToolbarActions(showingFilters: $showingFilters)
                }
            }
            .sheet(isPresented: $showingFilters) {
                ContentFilterSheet(selectedFilter: $selectedFilter)
            }
        }
    }
    
    @MainActor
    private func refreshContent() async {
        // Trigger any background processing or refresh operations
        try? await Task.sleep(for: .milliseconds(500))
    }
}

// MARK: - Content Item Wrapper

enum ContentItem: Identifiable {
    case recording(RecordingItem)
    case note(ProcessedNote)
    
    var id: UUID {
        switch self {
        case .recording(let item): return item.id
        case .note(let item): return item.id
        }
    }
    
    var timestamp: Date {
        switch self {
        case .recording(let item): return item.timestamp
        case .note(let item): return item.timestamp
        }
    }
    
    var title: String {
        switch self {
        case .recording(let item): return item.displayTitle
        case .note(let item): 
            let summary = item.summary.isEmpty ? "Untitled Note" : item.summary
            return summary.prefix(60) + (summary.count > 60 ? "..." : "")
        }
    }
    
    var content: String {
        switch self {
        case .recording(let item): return item.transcriptionText ?? "Audio recording"
        case .note(let item): return item.originalText
        }
    }
    
    var contentType: ContentType {
        switch self {
        case .recording: return .recording
        case .note: return .note
        }
    }
    
    var isFavorite: Bool {
        switch self {
        case .recording(let item): return item.isFavorite
        case .note: return false // Notes don't have favorite field yet
        }
    }
    
    var isProcessed: Bool {
        switch self {
        case .recording(let item): return item.isTranscribed
        case .note(let item): return item.consolidationLevel != .volatile
        }
    }
    
    var tags: [String] {
        switch self {
        case .recording(let item): return item.tags
        case .note(let item): return item.topics
        }
    }
    
    var duration: TimeInterval? {
        switch self {
        case .recording(let item): return item.duration
        case .note: return nil
        }
    }
    
    var entityCount: Int {
        switch self {
        case .recording(let item): return item.extractedEntityIds.count
        case .note(let item): return item.entities.count
        }
    }
}

enum ContentType: String, CaseIterable {
    case recording = "Recording"
    case note = "Note"
    
    var icon: String {
        switch self {
        case .recording: return "waveform"
        case .note: return "doc.text"
        }
    }
    
    var color: Color {
        switch self {
        case .recording: return .blue
        case .note: return .mint
        }
    }
}

enum ContentFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case recordings = "Recordings"
    case notes = "Notes"
    case favorites = "Favorites"
    case unprocessed = "Unprocessed"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .recordings: return "waveform"
        case .notes: return "doc.text"
        case .favorites: return "heart.fill"
        case .unprocessed: return "clock"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .recordings: return .blue
        case .notes: return .mint
        case .favorites: return .pink
        case .unprocessed: return .orange
        }
    }
}

// MARK: - List Row Component

struct ContentListRow: View {
    let item: ContentItem
    @State private var isHovered = false
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            HStack(spacing: 12) {
                // Content Type Indicator
                ContentTypeIndicator(
                    type: item.contentType,
                    isFavorite: item.isFavorite,
                    isProcessed: item.isProcessed
                )
                
                // Content Info
                VStack(alignment: .leading, spacing: 4) {
                    // Title and Timestamp
                    HStack {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(item.timestamp.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Content Preview
                    Text(item.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Metadata Row
                    ContentMetadataRow(item: item)
                }
                
                #if os(macOS)
                // macOS-specific hover indicator
                if isHovered {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                #endif
            }
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
                    .opacity(isHovered ? 0.3 : 0)
            }
            #if os(macOS)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            #endif
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .contextMenu {
            ContentContextMenu(item: item)
        }
        #endif
    }
    
    @ViewBuilder
    private var destinationView: some View {
        switch item {
        case .recording(let recording):
            VoiceMemoDetailView(recording: recording)
        case .note(let note):
            NoteDetailView(note: note)
        }
    }
}

// MARK: - Supporting Components

struct ContentTypeIndicator: View {
    let type: ContentType
    let isFavorite: Bool
    let isProcessed: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(type.color.opacity(0.15))
                .frame(width: 48, height: 48)
            
            VStack(spacing: 2) {
                Image(systemName: type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(type.color)
                
                // Status indicators
                HStack(spacing: 2) {
                    if isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.pink)
                    }
                    if !isProcessed {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}

struct ContentMetadataRow: View {
    let item: ContentItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Duration (for recordings)
            if let duration = item.duration {
                Label {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Entity count
            if item.entityCount > 0 {
                Label {
                    Text("\(item.entityCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "person.2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Tags
            if !item.tags.isEmpty {
                Label {
                    Text(item.tags.prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "tag")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ContentSearchBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: ContentFilter
    @Binding var showingFilters: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search content...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // Quick Filter Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ContentFilter.allCases) { filter in
                        FilterButton(
                            filter: filter,
                            isSelected: selectedFilter == filter
                        ) {
                            selectedFilter = filter
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

struct FilterButton: View {
    let filter: ContentFilter
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.rawValue)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? filter.color.opacity(0.2) : Color.secondary.opacity(0.1))
            }
            .foregroundStyle(isSelected ? filter.color : .secondary)
        }
        .buttonStyle(.plain)
    }
}

struct ContentEmptyState: View {
    let hasSearchOrFilter: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasSearchOrFilter ? "magnifyingglass" : "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(hasSearchOrFilter ? "No matching content" : "No content yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(hasSearchOrFilter ? "Try adjusting your search or filters" : "Create your first note or recording to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

struct ContentToolbarActions: View {
    @Binding var showingFilters: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Button("Filter") {
                showingFilters = true
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct ContentFilterSheet: View {
    @Binding var selectedFilter: ContentFilter
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(ContentFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: filter.icon)
                                .foregroundStyle(filter.color)
                            Text(filter.rawValue)
                            Spacer()
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Filter Content")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#if os(iOS)
struct ContentSwipeActions: View {
    let item: ContentItem
    let modelContext: ModelContext
    
    var body: some View {
        Group {
            Button("Archive") {
                archiveItem()
            }
            .tint(.orange)
            
            Button("Delete") {
                deleteItem()
            }
            .tint(.red)
        }
    }
    
    private func archiveItem() {
        switch item {
        case .recording(let recording):
            recording.isArchived = true
        case .note(_):
            // Implement archiving for notes if needed
            break
        }
        
        try? modelContext.save()
    }
    
    private func deleteItem() {
        switch item {
        case .recording(let recording):
            modelContext.delete(recording)
        case .note(let note):
            modelContext.delete(note)
        }
        
        try? modelContext.save()
    }
}
#endif

#if os(macOS)
struct ContentContextMenu: View {
    let item: ContentItem
    
    var body: some View {
        Group {
            Button("Open") {
                // Navigation handled by NavigationLink
            }
            
            Divider()
            
            Button("Archive") {
                // Implement archiving
            }
            
            Button("Delete") {
                // Implement deletion
            }
        }
    }
}
#endif

// MARK: - Detail Views (Placeholders)

struct VoiceMemoDetailView: View {
    let recording: RecordingItem
    
    var body: some View {
        VStack {
            Text("Recording Detail")
            Text(recording.displayTitle)
        }
        .navigationTitle("Recording")
    }
}

struct NoteDetailView: View {
    let note: ProcessedNote
    
    var body: some View {
        VStack {
            Text("Note Detail")
            Text(note.originalText)
        }
        .navigationTitle("Note")
    }
}

#Preview {
    ContentListView()
        .modelContainer(for: [RecordingItem.self, ProcessedNote.self], inMemory: true)
}