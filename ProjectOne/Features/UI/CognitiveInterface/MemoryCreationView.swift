//
//  MemoryCreationView.swift
//  ProjectOne
//
//  Created by Claude on 8/27/25.
//  UI for creating memories/thoughts from bubble-up cards
//

import SwiftUI
import MapKit
import CoreLocation
import os.log

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct MemoryCreationView: View {
    
    // MARK: - Properties
    
    let bubbleUpItem: BubbleUpItem
    let memoryCreator: BubbleUpMemoryCreator
    let onMemoryCreated: (Thought) -> Void
    let onCancel: () -> Void
    
    @State private var userContent: String = ""
    @State private var selectedThoughtType: ThoughtType = .insight
    @State private var selectedImportance: ThoughtImportance = .medium
    @State private var customTags: String = ""
    @State private var useCustomContent: Bool = false
    @State private var isCreating: Bool = false
    @State private var errorMessage: String?
    @State private var showingSuccess: Bool = false
    
    // Suggestions from the memory creator
    @State private var suggestedTypes: [ThoughtType] = []
    @State private var suggestedTags: [String] = []
    @State private var suggestedImportance: ThoughtImportance = .medium
    
    // Target datetime and location
    @State private var hasTargetDateTime: Bool = false
    @State private var targetDateTime: Date = Date().addingTimeInterval(86400) // Default to tomorrow
    @State private var hasTargetLocation: Bool = false
    @State private var targetLocationName: String = ""
    @State private var targetLocationRadius: Double = 100.0 // Default 100m radius
    @State private var showingLocationPicker: Bool = false
    @State private var targetCoordinate: CLLocationCoordinate2D?
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryCreationView")
    
    // MARK: - Initialization
    
    public init(
        bubbleUpItem: BubbleUpItem,
        memoryCreator: BubbleUpMemoryCreator,
        onMemoryCreated: @escaping (Thought) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.bubbleUpItem = bubbleUpItem
        self.memoryCreator = memoryCreator
        self.onMemoryCreated = onMemoryCreated
        self.onCancel = onCancel
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Source bubble-up context
                    sourceContextSection
                    
                    // Content input section
                    contentInputSection
                    
                    // Thought type selection
                    thoughtTypeSection
                    
                    // Importance selection
                    importanceSection
                    
                    // Tags section
                    tagsSection
                    
                    // Target datetime section
                    targetDateTimeSection
                    
                    // Target location section
                    targetLocationSection
                    
                    // Preview section
                    if !userContent.isEmpty || !useCustomContent {
                        previewSection
                    }
                }
                .padding()
            }
            .glassNavigationTitle("Create Memory", displayMode: .compact)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        Task {
                            await createMemory()
                        }
                    }
                    .disabled(isCreating || (useCustomContent && userContent.isEmpty))
                }
            }
            .task {
                await loadSuggestions()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Memory Created", isPresented: $showingSuccess) {
                Button("OK") {
                    // Will be handled by onMemoryCreated callback
                }
            } message: {
                Text("Your memory has been successfully created and added to the cognitive system.")
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView { coordinate, name in
                    targetCoordinate = coordinate
                    if let name = name {
                        targetLocationName = name
                    }
                }
            }
        }
        .tint(.blue)
    }
    
    // MARK: - View Sections
    
    private var sourceContextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: bubbleUpItem.taskType == .focus ? "bolt.circle.fill" : 
                      bubbleUpItem.taskType == .creative ? "lightbulb.circle.fill" :
                      bubbleUpItem.taskType == .planning ? "calendar.circle.fill" : "circle.fill")
                    .foregroundColor(.blue)
                
                Text("From Bubble-Up")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(bubbleUpItem.taskType.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text(bubbleUpItem.content)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(16)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Memory Content")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Custom Content", isOn: $useCustomContent)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            if useCustomContent {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Write your custom thought or memory:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $userContent)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The bubble-up content will be used as your memory.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("You can add context and categorization below.")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
            }
        }
    }
    
    private var thoughtTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thought Type")
                .font(.headline)
            
            // Suggested types (if any)
            if !suggestedTypes.isEmpty {
                Text("Suggested:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(suggestedTypes, id: \.self) { type in
                        Button(action: {
                            selectedThoughtType = type
                        }) {
                            HStack {
                                Text(type.emoji)
                                Text(type.displayName)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedThoughtType == type ? 
                                Color.blue.opacity(0.2) : Color.gray.opacity(0.1)
                            )
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        selectedThoughtType == type ? Color.blue : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // All types picker
            Picker("Thought Type", selection: $selectedThoughtType) {
                ForEach(ThoughtType.allCases, id: \.self) { type in
                    HStack {
                        Text(type.emoji)
                        Text(type.displayName)
                    }
                    .tag(type)
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    private var importanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Importance")
                    .font(.headline)
                
                Spacer()
                
                if suggestedImportance != selectedImportance {
                    Button("Use Suggested: \(suggestedImportance.displayName)") {
                        selectedImportance = suggestedImportance
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Picker("Importance", selection: $selectedImportance) {
                ForEach(ThoughtImportance.allCases, id: \.self) { importance in
                    HStack {
                        Circle()
                            .fill(importanceColor(for: importance))
                            .frame(width: 8, height: 8)
                        Text(importance.displayName)
                    }
                    .tag(importance)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            // Suggested tags
            if !suggestedTags.isEmpty {
                Text("Suggested:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(suggestedTags.prefix(9), id: \.self) { tag in
                        Button(action: {
                            addTagToCustomTags(tag)
                        }) {
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Custom tags input
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom tags (comma-separated):")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter tags...", text: $customTags)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private var targetDateTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target Date & Time")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Set Target", isOn: $hasTargetDateTime)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            if hasTargetDateTime {
                VStack(alignment: .leading, spacing: 8) {
                    Text("When should this thought be reviewed or acted upon?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DatePicker(
                        "Target Date & Time",
                        selection: $targetDateTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    
                    // Show relative time
                    let timeInterval = targetDateTime.timeIntervalSinceNow
                    if timeInterval > 0 {
                        Text("In \(formatTimeInterval(timeInterval))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text("Overdue by \(formatTimeInterval(-timeInterval))")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private var targetLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Target Location")
                    .font(.headline)
                
                Spacer()
                
                Toggle("Set Location", isOn: $hasTargetLocation)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            if hasTargetLocation {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where is this thought relevant?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("Location name (e.g., Home, Office, Coffee Shop)", text: $targetLocationName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Relevant radius: \(Int(targetLocationRadius))m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: $targetLocationRadius, in: 10...1000, step: 10) {
                            Text("Radius")
                        }
                    }
                    
                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                            Text("Pick Location on Map")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .padding(12)
                .background(Color.purple.opacity(0.05))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(selectedThoughtType.emoji)
                    Text(selectedThoughtType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Circle()
                        .fill(importanceColor(for: selectedImportance))
                        .frame(width: 8, height: 8)
                    
                    Text(selectedImportance.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(useCustomContent ? userContent : bubbleUpItem.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(12)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                
                if !allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(allTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(12)
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var allTags: [String] {
        let customTagsList = customTags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return Array(Set(customTagsList)).sorted()
    }
    
    // MARK: - Methods
    
    private func loadSuggestions() async {
        suggestedTypes = await memoryCreator.getSuggestedThoughtTypes(for: bubbleUpItem)
        suggestedTags = await memoryCreator.getSuggestedTags(for: bubbleUpItem)
        suggestedImportance = await memoryCreator.getSuggestedImportance(for: bubbleUpItem)
        
        // Set initial values to suggestions
        if !suggestedTypes.isEmpty {
            selectedThoughtType = suggestedTypes.first!
        }
        selectedImportance = suggestedImportance
    }
    
    private func addTagToCustomTags(_ tag: String) {
        let currentTags = Set(customTags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
        
        if !currentTags.contains(tag) {
            if customTags.isEmpty {
                customTags = tag
            } else {
                customTags += ", " + tag
            }
        }
    }
    
    private func importanceColor(for importance: ThoughtImportance) -> Color {
        switch importance {
        case .critical: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: interval) ?? "\(Int(interval))s"
    }
    
    private func createMemory() async {
        isCreating = true
        errorMessage = nil
        
        do {
            let createdThought: Thought
            
            if useCustomContent && !userContent.isEmpty {
                // Prepare target location data if enabled
                let targetLocation: (latitude: Double, longitude: Double, name: String?, radius: Double?)? = {
                    guard hasTargetLocation else { return nil }
                    
                    if let coordinate = targetCoordinate {
                        return (
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude,
                            name: targetLocationName.isEmpty ? nil : targetLocationName,
                            radius: targetLocationRadius
                        )
                    } else if !targetLocationName.isEmpty {
                        // For manual location name entry, we can't provide coordinates
                        return nil
                    }
                    
                    return nil
                }()
                
                createdThought = try await memoryCreator.createCustomMemoryFromBubbleUp(
                    bubbleUpItem,
                    userContent: userContent,
                    thoughtType: selectedThoughtType,
                    tags: allTags,
                    importance: selectedImportance,
                    targetDateTime: hasTargetDateTime ? targetDateTime : nil,
                    targetLocation: targetLocation
                )
            } else {
                createdThought = try await memoryCreator.createMemoryFromBubbleUp(
                    bubbleUpItem,
                    thoughtType: selectedThoughtType
                )
                
                // Apply any additional customizations
                if !allTags.isEmpty {
                    createdThought.setTags(allTags + createdThought.tags)
                }
                createdThought.importance = selectedImportance
                
                // Apply target datetime and location
                if hasTargetDateTime {
                    createdThought.targetDateTime = targetDateTime
                }
                
                if hasTargetLocation {
                    if let coordinate = targetCoordinate {
                        createdThought.setTargetLocation(
                            latitude: coordinate.latitude,
                            longitude: coordinate.longitude,
                            locationName: targetLocationName.isEmpty ? nil : targetLocationName,
                            radius: targetLocationRadius
                        )
                    } else if !targetLocationName.isEmpty {
                        // Fallback for manual location name entry
                        createdThought.targetLocationName = targetLocationName
                        createdThought.targetLocationRadius = targetLocationRadius
                    }
                }
            }
            
            logger.info("Successfully created memory: \(createdThought.id)")
            
            // Show success and call completion
            showingSuccess = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onMemoryCreated(createdThought)
            }
            
        } catch {
            logger.error("Failed to create memory: \(error)")
            errorMessage = "Failed to create memory: \(error.localizedDescription)"
        }
        
        isCreating = false
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct MemoryCreationView_Previews: PreviewProvider {
    static var previews: some View {
        // This would need to be set up with proper mock data for preview
        Text("Memory Creation View Preview")
    }
}