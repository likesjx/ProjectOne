import SwiftUI
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct ThoughtListView: View {
    let processedNote: ProcessedNote
    @State private var selectedThoughtType: ThoughtType? = nil
    @State private var selectedImportance: ThoughtImportance? = nil
    @State private var searchText = ""
    
    var filteredThoughts: [Thought] {
        var thoughts = processedNote.orderedThoughts
        
        if let selectedType = selectedThoughtType {
            thoughts = thoughts.filter { $0.thoughtType == selectedType }
        }
        
        if let selectedImportance = selectedImportance {
            thoughts = thoughts.filter { $0.importance == selectedImportance }
        }
        
        if !searchText.isEmpty {
            thoughts = thoughts.filter { thought in
                thought.content.localizedCaseInsensitiveContains(searchText) ||
                thought.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return thoughts
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters
                filterBar
                
                // Thoughts list
                List(filteredThoughts, id: \.id) { thought in
                    ThoughtRowView(thought: thought)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
                .searchable(text: $searchText, prompt: "Search thoughts and tags...")
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Thoughts (\(filteredThoughts.count))")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Thought type filter
                Menu {
                    Button("All Types") {
                        selectedThoughtType = nil
                    }
                    
                    Divider()
                    
                    ForEach(ThoughtType.allCases, id: \.self) { type in
                        Button("\(type.emoji) \(type.displayName)") {
                            selectedThoughtType = type
                        }
                    }
                } label: {
                    HStack {
                        if let selectedType = selectedThoughtType {
                            Text("\(selectedType.emoji) \(selectedType.displayName)")
                        } else {
                            Text("Type")
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
                }
                
                // Importance filter
                Menu {
                    Button("All Importance") {
                        selectedImportance = nil
                    }
                    
                    Divider()
                    
                    ForEach(ThoughtImportance.allCases.reversed(), id: \.self) { importance in
                        Button(importance.displayName) {
                            selectedImportance = importance
                        }
                    }
                } label: {
                    HStack {
                        if let selectedImportance = selectedImportance {
                            Text(selectedImportance.displayName)
                        } else {
                            Text("Importance")
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(16)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct ThoughtRowView: View {
    let thought: Thought
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with type and importance
            HStack {
                // Thought type
                HStack(spacing: 4) {
                    Text(thought.thoughtType.emoji)
                    Text(thought.thoughtType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
                
                // Importance indicator
                importanceIndicator
                
                Spacer()
                
                // Expand/collapse button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Content
            Text(thought.content)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
            
            // Tags
            if !thought.tags.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 4) {
                    ForEach(thought.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }
            }
            
            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let contextBefore = thought.contextBefore, !contextBefore.isEmpty {
                        DetailRow(label: "Context Before", value: contextBefore)
                    }
                    
                    if let contextAfter = thought.contextAfter, !contextAfter.isEmpty {
                        DetailRow(label: "Context After", value: contextAfter)
                    }
                    
                    if let primaryTag = thought.primaryTag {
                        DetailRow(label: "Primary Tag", value: "#\(primaryTag)")
                    }
                    
                    DetailRow(label: "Completeness", value: thought.completeness.displayName)
                    DetailRow(label: "Sequence", value: "\(thought.sequenceIndex + 1)")
                    
                    if let extractionMethod = thought.extractionMethod {
                        DetailRow(label: "Extraction", value: extractionMethod)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var importanceIndicator: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { level in
                Circle()
                    .fill(level <= thought.importance.priority ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Previews

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview {
    // Create sample data for preview
    let sampleNote = ProcessedNote(
        sourceType: .text,
        originalText: "Sample note for preview",
        summary: "This is a sample note",
        topics: ["sample", "preview"]
    )
    
    let sampleThought1 = Thought(
        content: "This is a sample thought about productivity and workflow optimization.",
        contextBefore: "I was thinking about ways to improve",
        contextAfter: "and then realized this could be useful",
        sequenceIndex: 0,
        thoughtType: .idea,
        parentNote: sampleNote
    )
    sampleThought1.setTags(["productivity", "workflow", "optimization"])
    sampleThought1.setPrimaryTag("productivity")
    sampleThought1.importance = .high
    
    let sampleThought2 = Thought(
        content: "Remember to call mom later today.",
        sequenceIndex: 1,
        thoughtType: .task,
        parentNote: sampleNote
    )
    sampleThought2.setTags(["personal", "family", "reminder"])
    sampleThought2.importance = .medium
    
    sampleNote.addThought(sampleThought1)
    sampleNote.addThought(sampleThought2)
    
    return ThoughtListView(processedNote: sampleNote)
}