//
//  MemoryContextPanel.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/29/25.
//

import SwiftUI
import SwiftData

/// Main memory context panel that displays relevant memory information during note creation
struct MemoryContextPanel: View {
    @ObservedObject var memoryService: RealTimeMemoryService
    
    @State private var expandedSections: Set<MemorySection> = [.shortTerm, .entities]
    @State private var showPrivacyIndicator = false
    
    private let minPanelWidth: CGFloat = 300
    private let maxPanelWidth: CGFloat = 500
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            memoryPanelHeader
            
            if memoryService.isLoading {
                loadingView
            } else if let context = memoryService.currentContext {
                if context.isEmpty {
                    emptyContextView
                } else {
                    contextSections(context)
                }
            } else {
                noContextView
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                }
        }
        .frame(minWidth: minPanelWidth, maxWidth: maxPanelWidth)
        .animation(.easeInOut(duration: 0.3), value: memoryService.currentContext?.isEmpty)
    }
    
    // MARK: - Header
    
    private var memoryPanelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.indigo)
                        .font(.title3.weight(.medium))
                    
                    Text("Memory Context")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    if memoryService.currentContext?.containsPersonalData == true {
                        privacyIndicator
                    }
                }
                
                if !memoryService.lastQuery.isEmpty {
                    Text("Query: \"\(memoryService.lastQuery.prefix(40))\(memoryService.lastQuery.count > 40 ? "..." : "")\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Performance indicator
            if memoryService.queryLatency > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(memoryService.queryLatency * 1000))ms")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(latencyColor)
                    
                    Text("Latency")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
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
    
    private var privacyIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.caption2)
            Text("Private")
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(.orange.opacity(0.15))
        }
    }
    
    private var latencyColor: Color {
        if memoryService.queryLatency < 0.5 {
            return .green
        } else if memoryService.queryLatency < 1.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Retrieving memory context...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var noContextView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Start Writing")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Memory context will appear here as you write your note")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.horizontal, 24)
    }
    
    private var emptyContextView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Related Memories")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("No relevant memory context found for your current content")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private func contextSections(_ context: MemoryContext) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Short-term Memory
                if !context.typedShortTermMemories.isEmpty {
                    MemorySectionView(
                        section: .shortTerm,
                        title: "Recent Context",
                        icon: "clock.fill",
                        color: .blue,
                        count: context.typedShortTermMemories.count,
                        isExpanded: expandedSections.contains(.shortTerm)
                    ) {
                        toggleSection(.shortTerm)
                    } content: {
                        ForEach(context.typedShortTermMemories.prefix(5), id: \.id) { memory in
                            ShortTermMemoryRow(memory: memory)
                        }
                    }
                }
                
                // Entities
                if !context.typedEntities.isEmpty {
                    MemorySectionView(
                        section: .entities,
                        title: "Related Entities",
                        icon: "person.2.fill",
                        color: .green,
                        count: context.typedEntities.count,
                        isExpanded: expandedSections.contains(.entities)
                    ) {
                        toggleSection(.entities)
                    } content: {
                        ForEach(context.typedEntities.prefix(8), id: \.id) { entity in
                            EntityMemoryRow(entity: entity)
                        }
                    }
                }
                
                // Long-term Memory
                if !context.typedLongTermMemories.isEmpty {
                    MemorySectionView(
                        section: .longTerm,
                        title: "Knowledge Base",
                        icon: "archivebox.fill",
                        color: .purple,
                        count: context.typedLongTermMemories.count,
                        isExpanded: expandedSections.contains(.longTerm)
                    ) {
                        toggleSection(.longTerm)
                    } content: {
                        ForEach(context.typedLongTermMemories.prefix(4), id: \.id) { memory in
                            LongTermMemoryRow(memory: memory)
                        }
                    }
                }
                
                // Episodic Memory
                if !context.typedEpisodicMemories.isEmpty {
                    MemorySectionView(
                        section: .episodic,
                        title: "Past Experiences",
                        icon: "timeline.selection",
                        color: .orange,
                        count: context.typedEpisodicMemories.count,
                        isExpanded: expandedSections.contains(.episodic)
                    ) {
                        toggleSection(.episodic)
                    } content: {
                        ForEach(context.typedEpisodicMemories.prefix(4), id: \.id) { memory in
                            EpisodicMemoryRow(memory: memory)
                        }
                    }
                }
                
                // Relationships
                if !context.typedRelationships.isEmpty {
                    MemorySectionView(
                        section: .relationships,
                        title: "Connections",
                        icon: "link",
                        color: .mint,
                        count: context.typedRelationships.count,
                        isExpanded: expandedSections.contains(.relationships)
                    ) {
                        toggleSection(.relationships)
                    } content: {
                        ForEach(context.typedRelationships.prefix(6), id: \.id) { relationship in
                            RelationshipMemoryRow(relationship: relationship)
                        }
                    }
                }
                
                // Related Notes
                if !context.typedNotes.isEmpty {
                    MemorySectionView(
                        section: .notes,
                        title: "Related Notes",
                        icon: "doc.text.fill",
                        color: .indigo,
                        count: context.typedNotes.count,
                        isExpanded: expandedSections.contains(.notes)
                    ) {
                        toggleSection(.notes)
                    } content: {
                        ForEach(context.typedNotes.prefix(4), id: \.id) { note in
                            NoteMemoryRow(note: note)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func toggleSection(_ section: MemorySection) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }
}

// MARK: - Memory Section Types

enum MemorySection: String, CaseIterable {
    case shortTerm = "short_term"
    case longTerm = "long_term"
    case episodic = "episodic"
    case entities = "entities"
    case relationships = "relationships"
    case notes = "notes"
}

// MARK: - Generic Section View

struct MemorySectionView<Content: View>: View {
    let section: MemorySection
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let isExpanded: Bool
    let toggleAction: () -> Void
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            // Section Header
            Button(action: toggleAction) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                            .font(.subheadline.weight(.medium))
                            .frame(width: 20)
                        
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                        Text("(\(count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.1))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                VStack(spacing: 8) {
                    content
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
    }
}

// MARK: - Memory Row Components

struct ShortTermMemoryRow: View {
    let memory: STMEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memory.content)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
            
            HStack {
                Text(memory.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if memory.accessCount > 0 {
                    Text("Accessed \(memory.accessCount) times")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.blue.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.blue.opacity(0.1), lineWidth: 1)
                }
        }
    }
}

struct EntityMemoryRow: View {
    let entity: Entity
    
    var body: some View {
        HStack(spacing: 12) {
            // Entity type icon
            Image(systemName: entity.type.systemImageName)
                .foregroundStyle(entity.type.swiftUIColor)
                .font(.subheadline.weight(.medium))
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(entity.type.swiftUIColor.opacity(0.15))
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                if let description = entity.entityDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.green.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.green.opacity(0.1), lineWidth: 1)
                }
        }
    }
}

struct LongTermMemoryRow: View {
    let memory: LTMEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            summaryText
            contentText
            metadataFooter
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
    }
    
    @ViewBuilder
    private var summaryText: some View {
        if !memory.summary.isEmpty {
            Text(memory.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
    
    private var contentText: some View {
        Text(memory.content)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(3)
    }
    
    private var metadataFooter: some View {
        HStack {
            Text("Strength: \(Int(memory.strengthScore * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(memory.lastAccessed.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.purple.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.purple.opacity(0.1), lineWidth: 1)
            }
    }
}

struct EpisodicMemoryRow: View {
    let memory: EpisodicMemoryEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memory.eventDescription)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
            
            HStack {
                if let location = memory.location {
                    Label(location, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(memory.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.orange.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.orange.opacity(0.1), lineWidth: 1)
                }
        }
    }
}

struct RelationshipMemoryRow: View {
    let relationship: Relationship
    
    var body: some View {
        HStack(spacing: 8) {
            Text(relationship.subjectName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(relationship.predicate)
                .font(.caption)
                .foregroundStyle(.mint)
                .lineLimit(1)
            
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text(relationship.objectName)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.mint.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.mint.opacity(0.1), lineWidth: 1)
                }
        }
    }
}

struct NoteMemoryRow: View {
    let note: ProcessedNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !note.summary.isEmpty {
                Text(note.summary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            
            Text(note.originalText.prefix(100) + (note.originalText.count > 100 ? "..." : ""))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                if !note.topics.isEmpty {
                    Text(note.topics.prefix(2).joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.indigo)
                }
                
                Spacer()
                
                Text(note.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.indigo.opacity(0.05))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.indigo.opacity(0.1), lineWidth: 1)
                }
        }
    }
}

// MARK: - Extensions

extension EntityType {
    var systemImageName: String {
        switch self {
        case .person: return "person.fill"
        case .place, .location: return "location.fill"
        case .organization: return "building.2.fill"
        case .concept: return "lightbulb.fill"
        case .event: return "calendar"
        case .thing: return "cube.fill"
        case .activity: return "figure.run"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .person: return .blue
        case .place, .location: return .green
        case .organization: return .purple
        case .concept: return .orange
        case .event: return .red
        case .thing: return .gray
        case .activity: return .mint
        }
    }
}

#Preview("Memory Context Panel") {
    struct PreviewWrapper: View {
        @StateObject private var memoryService = RealTimeMemoryService(modelContext: ModelContext.preview)
        
        var body: some View {
            MemoryContextPanel(memoryService: memoryService)
                .frame(width: 400, height: 600)
        }
    }
    
    return PreviewWrapper()
}

