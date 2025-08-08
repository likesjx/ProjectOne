//
//  MemoryBrowserView.swift
//  ProjectOne
//
//  Advanced memory exploration and analysis interface
//  SwiftUI view for browsing, searching, and analyzing stored memories
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import Charts
import Combine
import os.log

/// Advanced interface for browsing and analyzing stored memories
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct MemoryBrowserView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allMemories: [ProcessedNote]
    @Query private var episodicMemories: [EpisodicMemoryEntry]
    @Query private var longTermMemories: [LTMEntry]
    @Query private var shortTermMemories: [STMEntry]
    
    @State private var selectedMemoryType: MemoryBrowserType = .all
    @State private var searchText = ""
    @State private var selectedTimeRange: BrowserTimeRange = .lastWeek
    @State private var sortOption: MemorySortOption = .dateDescending
    @State private var showingFilters = false
    @State private var memoryAnalytics: MemoryBrowserAnalytics = MemoryBrowserAnalytics()
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryBrowserView")
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // Search and filter header
                searchHeader
                
                // Memory analytics overview
                if selectedMemoryType == .all {
                    analyticsSection
                        .padding(.horizontal)
                }
                
                // Memory content
                memoryContentView
                
            }
            .navigationTitle("Memory Browser")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu("Options") {
                        Button(action: { showingFilters.toggle() }) {
                            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: refreshAnalytics) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: exportMemories) {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                MemoryFiltersSheet(
                    selectedType: $selectedMemoryType,
                    selectedTimeRange: $selectedTimeRange,
                    sortOption: $sortOption
                )
            }
            .task {
                updateAnalytics()
            }
            .onChange(of: selectedMemoryType) {
                updateAnalytics()
            }
            .onChange(of: selectedTimeRange) {
                updateAnalytics()
            }
        }
    }
    
    // MARK: - Search Header
    
    private var searchHeader: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search memories...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                }
            }
            
            // Memory type picker
            Picker("Memory Type", selection: $selectedMemoryType) {
                ForEach(MemoryBrowserType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
#if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
#else
        .background(Color(.systemGray6))
#endif
    }
    
    // MARK: - Analytics Section
    
    private var analyticsSection: some View {
        VStack(spacing: 16) {
            // Memory counts overview
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                MemoryCountCard(
                    title: "Processed",
                    count: memoryAnalytics.processedNotesCount,
                    color: .blue,
                    icon: "doc.text"
                )
                
                MemoryCountCard(
                    title: "Episodic",
                    count: memoryAnalytics.episodicCount,
                    color: .green,
                    icon: "brain.head.profile"
                )
                
                MemoryCountCard(
                    title: "Long-term",
                    count: memoryAnalytics.longTermCount,
                    color: .orange,
                    icon: "archivebox"
                )
                
                MemoryCountCard(
                    title: "Short-term",
                    count: memoryAnalytics.shortTermCount,
                    color: .purple,
                    icon: "timer"
                )
            }
            
            // Memory timeline chart
            if !memoryAnalytics.timelineData.isEmpty {
                memoryTimelineChart
            }
        }
        .padding(.vertical)
    }
    
    private var memoryTimelineChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Creation Timeline")
                .font(.headline)
            
            Chart {
                ForEach(memoryAnalytics.timelineData, id: \.date) { data in
                    BarMark(
                        x: .value("Date", data.date),
                        y: .value("Count", data.count)
                    )
                    .foregroundStyle(.blue.gradient)
                }
            }
            .frame(height: 150)
        }
        .padding()
#if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
#else
        .background(Color(.systemBackground))
#endif
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Memory Content View
    
    private var memoryContentView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMemories, id: \.id) { memory in
                    MemoryCardView(memory: memory)
                }
                
                if filteredMemories.isEmpty {
                    emptyStateView
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No memories found")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Try adjusting your search criteria or memory type filter")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Clear Filters") {
                searchText = ""
                selectedMemoryType = .all
                selectedTimeRange = .allTime
            }
            .buttonStyle(BorderedProminentButtonStyle())
        }
        .padding(40)
    }
    
    // MARK: - Computed Properties
    
    private var filteredMemories: [BrowserMemoryItem] {
        var items: [BrowserMemoryItem] = []
        
        // Add memories based on selected type
        switch selectedMemoryType {
        case .all:
            items.append(contentsOf: allMemories.map { BrowserMemoryItem.processedNote($0) })
            items.append(contentsOf: episodicMemories.map { BrowserMemoryItem.episodic($0) })
            items.append(contentsOf: longTermMemories.map { BrowserMemoryItem.longTerm($0) })
            items.append(contentsOf: shortTermMemories.map { BrowserMemoryItem.shortTerm($0) })
        case .processed:
            items.append(contentsOf: allMemories.map { BrowserMemoryItem.processedNote($0) })
        case .episodic:
            items.append(contentsOf: episodicMemories.map { BrowserMemoryItem.episodic($0) })
        case .longTerm:
            items.append(contentsOf: longTermMemories.map { BrowserMemoryItem.longTerm($0) })
        case .shortTerm:
            items.append(contentsOf: shortTermMemories.map { BrowserMemoryItem.shortTerm($0) })
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.searchableContent.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply time range filter
        let cutoffDate = selectedTimeRange.cutoffDate
        if let cutoffDate = cutoffDate {
            items = items.filter { item in
                item.timestamp >= cutoffDate
            }
        }
        
        // Apply sorting
        return items.sorted { first, second in
            switch sortOption {
            case .dateDescending:
                return first.timestamp > second.timestamp
            case .dateAscending:
                return first.timestamp < second.timestamp
            case .relevance:
                // Simple relevance based on search text match strength
                if searchText.isEmpty { return first.timestamp > second.timestamp }
                let firstMatch = first.searchableContent.localizedCaseInsensitiveContains(searchText)
                let secondMatch = second.searchableContent.localizedCaseInsensitiveContains(searchText)
                if firstMatch && !secondMatch { return true }
                if !firstMatch && secondMatch { return false }
                return first.timestamp > second.timestamp
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateAnalytics() {
        memoryAnalytics = MemoryBrowserAnalytics(
            processedNotesCount: allMemories.count,
            episodicCount: episodicMemories.count,
            longTermCount: longTermMemories.count,
            shortTermCount: shortTermMemories.count,
            timelineData: generateTimelineData()
        )
    }
    
    private func generateTimelineData() -> [MemoryTimelineData] {
        let calendar = Calendar.current
        let now = Date()
        let dayCount = 7 // Last 7 days
        
        var data: [MemoryTimelineData] = []
        
        for i in 0..<dayCount {
            let date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
            
            let dayMemories = allMemories.filter { memory in
                memory.timestamp >= dayStart && memory.timestamp < dayEnd
            }
            
            data.append(MemoryTimelineData(date: dayStart, count: dayMemories.count))
        }
        
        return data.reversed() // Show oldest to newest
    }
    
    private func refreshAnalytics() {
        updateAnalytics()
        logger.info("Memory analytics refreshed")
    }
    
    private func exportMemories() {
        // TODO: Implement memory export functionality
        logger.info("Memory export requested")
    }
}

// MARK: - Supporting Views

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct MemoryCountCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
#if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
#else
        .background(Color(.systemBackground))
#endif
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct MemoryCardView: View {
    let memory: BrowserMemoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(memory.type.displayName, systemImage: memory.type.icon)
                    .font(.subheadline)
                    .foregroundColor(memory.type.color)
                
                Spacer()
                
                Text(memory.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Content preview
            Text(memory.preview)
                .font(.body)
                .lineLimit(3)
            
            // Metadata
            if !memory.metadata.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(memory.metadata, id: \.key) { item in
                            MetadataTag(key: item.key, value: item.value)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding()
#if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
#else
        .background(Color(.systemBackground))
#endif
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct MetadataTag: View {
    let key: String
    let value: String
    
    var body: some View {
        Text("\(key): \(value)")
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
#if os(macOS)
            .background(Color(nsColor: .controlColor))
#else
            .background(Color(.systemGray5))
#endif
            .cornerRadius(6)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct MemoryFiltersSheet: View {
    @Binding var selectedType: MemoryBrowserType
    @Binding var selectedTimeRange: BrowserTimeRange
    @Binding var sortOption: MemorySortOption
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Memory Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(MemoryBrowserType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                Section("Time Range") {
                    Picker("Range", selection: $selectedTimeRange) {
                        ForEach(BrowserTimeRange.allCases, id: \.self) { range in
                            Text(range.displayName).tag(range)
                        }
                    }
                    .pickerStyle(.automatic)
                }
                
                Section("Sort Order") {
                    Picker("Sort", selection: $sortOption) {
                        ForEach(MemorySortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.automatic)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum MemoryBrowserType: CaseIterable {
    case all, processed, episodic, longTerm, shortTerm
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .processed: return "Processed"
        case .episodic: return "Episodic"
        case .longTerm: return "Long-term"
        case .shortTerm: return "Short-term"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "brain"
        case .processed: return "doc.text"
        case .episodic: return "brain.head.profile"
        case .longTerm: return "archivebox"
        case .shortTerm: return "timer"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .processed: return .blue
        case .episodic: return .green
        case .longTerm: return .orange
        case .shortTerm: return .purple
        }
    }
}

enum BrowserTimeRange: CaseIterable {
    case allTime, lastDay, lastWeek, lastMonth, lastYear
    
    var displayName: String {
        switch self {
        case .allTime: return "All Time"
        case .lastDay: return "Last Day"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        case .lastYear: return "Last Year"
        }
    }
    
    var cutoffDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .allTime: return nil
        case .lastDay: return calendar.date(byAdding: .day, value: -1, to: now)
        case .lastWeek: return calendar.date(byAdding: .weekOfYear, value: -1, to: now)
        case .lastMonth: return calendar.date(byAdding: .month, value: -1, to: now)
        case .lastYear: return calendar.date(byAdding: .year, value: -1, to: now)
        }
    }
}

enum MemorySortOption: CaseIterable {
    case dateDescending, dateAscending, relevance
    
    var displayName: String {
        switch self {
        case .dateDescending: return "Newest First"
        case .dateAscending: return "Oldest First"
        case .relevance: return "Relevance"
        }
    }
}

enum BrowserMemoryItem {
    case processedNote(ProcessedNote)
    case episodic(EpisodicMemoryEntry)
    case longTerm(LTMEntry)
    case shortTerm(STMEntry)
    
    var id: UUID {
        switch self {
        case .processedNote(let note): return note.id
        case .episodic(let entry): return entry.id
        case .longTerm(let entry): return entry.id
        case .shortTerm(let entry): return entry.id
        }
    }
    
    var timestamp: Date {
        switch self {
        case .processedNote(let note): return note.timestamp
        case .episodic(let entry): return entry.timestamp
        case .longTerm(let entry): return entry.timestamp
        case .shortTerm(let entry): return entry.timestamp
        }
    }
    
    var preview: String {
        switch self {
        case .processedNote(let note):
            return note.summary.isEmpty ? note.originalText : note.summary
        case .episodic(let entry):
            return entry.description
        case .longTerm(let entry):
            return entry.content
        case .shortTerm(let entry):
            return entry.content
        }
    }
    
    var metadata: [(key: String, value: String)] {
        switch self {
        case .processedNote(let note):
            return [
                ("Source", note.sourceType.rawValue.capitalized),
                ("Topics", note.topics.joined(separator: ", ")),
                ("Words", "\(note.originalText.split(separator: " ").count)")
            ].filter { !$0.value.isEmpty }
        case .episodic(let entry):
            return [
                ("Location", entry.location ?? "Unknown"),
                ("Participants", "\(entry.participants.count)")
            ].filter { !$0.value.isEmpty && $0.value != "Unknown" }
        case .longTerm(let entry):
            return [
                ("Importance", String(format: "%.1f", entry.importance)),
                ("Access Count", "\(entry.accessCount)")
            ]
        case .shortTerm(let entry):
            return [
                ("Importance", String(format: "%.1f", entry.importance)),
                ("Access Count", "\(entry.accessCount)")
            ]
        }
    }
    
    var searchableContent: String {
        switch self {
        case .processedNote(let note):
            return [note.originalText, note.summary].joined(separator: " ")
        case .episodic(let entry):
            return entry.description
        case .longTerm(let entry):
            return entry.content
        case .shortTerm(let entry):
            return entry.content
        }
    }
    
    var type: MemoryBrowserType {
        switch self {
        case .processedNote: return .processed
        case .episodic: return .episodic
        case .longTerm: return .longTerm
        case .shortTerm: return .shortTerm
        }
    }
    
}

struct MemoryBrowserAnalytics {
    let processedNotesCount: Int
    let episodicCount: Int
    let longTermCount: Int
    let shortTermCount: Int
    let timelineData: [MemoryTimelineData]
    
    init(
        processedNotesCount: Int = 0,
        episodicCount: Int = 0,
        longTermCount: Int = 0,
        shortTermCount: Int = 0,
        timelineData: [MemoryTimelineData] = []
    ) {
        self.processedNotesCount = processedNotesCount
        self.episodicCount = episodicCount
        self.longTermCount = longTermCount
        self.shortTermCount = shortTermCount
        self.timelineData = timelineData
    }
}

struct MemoryTimelineData {
    let date: Date
    let count: Int
}