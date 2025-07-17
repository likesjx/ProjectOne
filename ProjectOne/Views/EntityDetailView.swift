import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Detailed view for exploring and editing entity information
struct EntityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let entity: Entity
    let modelContext: ModelContext
    
    @State private var isEditing = false
    @State private var editedName: String
    @State private var editedDescription: String
    @State private var editedAliases: String
    @State private var editedTags: String
    @State private var connectedEntities: [Entity] = []
    @State private var entityRelationships: [Relationship] = []
    @State private var showingRelationshipDetails = false
    @State private var selectedRelationship: Relationship?
    
    init(entity: Entity, modelContext: ModelContext) {
        self.entity = entity
        self.modelContext = modelContext
        self._editedName = State(initialValue: entity.name)
        self._editedDescription = State(initialValue: entity.entityDescription ?? "")
        self._editedAliases = State(initialValue: entity.aliases.joined(separator: ", "))
        self._editedTags = State(initialValue: entity.tags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Basic Information
                    basicInfoSection
                    
                    // Metrics Section
                    metricsSection
                    
                    // Relationships Section
                    relationshipsSection
                    
                    // Connected Entities Section
                    connectedEntitiesSection
                    
                    // Improvement Suggestions
                    if !entity.improvementSuggestions.isEmpty {
                        suggestionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Entity Details")
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Done") {
                        if isEditing {
                            saveChanges()
                        }
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .confirmationAction) {
                    if isEditing {
                        Button("Save") {
                            saveChanges()
                            isEditing = false
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingRelationshipDetails) {
                if let relationship = selectedRelationship {
                    RelationshipDetailView(relationship: relationship, modelContext: modelContext)
                }
            }
        }
        .task {
            await loadRelatedData()
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Entity icon and type
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(entity.type.color).opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: entity.type.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(Color(entity.type.color))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Entity Name", text: $editedName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    } else {
                        Text(entity.name)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text(entity.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Validation badge
                    HStack {
                        Image(systemName: entity.isValidated ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(entity.isValidated ? .green : .orange)
                        
                        Text(entity.isValidated ? "Validated" : "Needs Validation")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
            }
            
            // Entity score visualization
            EntityScoreView(entity: entity)
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(12)
    }
    
    // MARK: - Basic Information Section
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isEditing {
                    TextField("Add a description...", text: $editedDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                } else {
                    Text(entity.entityDescription?.isEmpty == false ? entity.entityDescription! : "No description provided")
                        .font(.subheadline)
                        .foregroundColor(entity.entityDescription?.isEmpty == false ? .primary : .secondary)
                }
            }
            
            // Aliases
            VStack(alignment: .leading, spacing: 8) {
                Text("Aliases")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isEditing {
                    TextField("Alternative names (comma-separated)", text: $editedAliases)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    if entity.aliases.isEmpty {
                        Text("No aliases")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(entity.aliases, id: \.self) { alias in
                                    Text(alias)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemBlue).opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isEditing {
                    TextField("Tags (comma-separated)", text: $editedTags)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                } else {
                    if entity.tags.isEmpty {
                        Text("No tags")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(entity.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGreen).opacity(0.1))
                                        .foregroundColor(.green)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
            }
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricCard(
                    title: "Mentions",
                    value: "\(entity.mentions)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                
                MetricCard(
                    title: "Relationships",
                    value: "\(entity.relationships.count)",
                    icon: "link",
                    color: .green
                )
                
                MetricCard(
                    title: "Confidence",
                    value: "\(Int(entity.confidence * 100))%",
                    icon: "checkmark.circle",
                    color: entity.confidence > 0.7 ? .green : .orange
                )
                
                MetricCard(
                    title: "Importance",
                    value: "\(Int(entity.importance * 100))%",
                    icon: "star",
                    color: .purple
                )
            }
            
            // Temporal information
            VStack(alignment: .leading, spacing: 8) {
                Text("Timeline")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("First Mentioned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entity.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last Mentioned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entity.lastMentioned.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                    }
                }
                
                // Freshness indicator
                ProgressView(value: entity.freshness)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 1 - entity.freshness, green: entity.freshness, blue: 0)))
                
                Text("Freshness: \(Int(entity.freshness * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Relationships Section
    
    private var relationshipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Relationships")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(entityRelationships.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if entityRelationships.isEmpty {
                Text("No relationships found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(entityRelationships, id: \.id) { relationship in
                        RelationshipRowView(
                            relationship: relationship,
                            currentEntityId: entity.id,
                            connectedEntities: connectedEntities
                        )
                        .onTapGesture {
                            selectedRelationship = relationship
                            showingRelationshipDetails = true
                        }
                    }
                }
            }
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Connected Entities Section
    
    private var connectedEntitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Connected Entities")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(connectedEntities.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if connectedEntities.isEmpty {
                Text("No connected entities")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(connectedEntities, id: \.id) { connectedEntity in
                        ConnectedEntityRowView(entity: connectedEntity)
                    }
                }
            }
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Suggestions Section
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Improvement Suggestions")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(entity.improvementSuggestions, id: \.self) { suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.orange)
                        .font(.system(size: 16))
                    
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemOrange).opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Actions
    
    private func loadRelatedData() async {
        do {
            // Load all relationships and filter
            var relationshipDescriptor = FetchDescriptor<Relationship>()
            relationshipDescriptor.sortBy = [SortDescriptor(\.importance, order: .reverse)]
            let allRelationships = try modelContext.fetch(relationshipDescriptor)
            entityRelationships = allRelationships.filter { 
                $0.subjectEntityId == entity.id || $0.objectEntityId == entity.id 
            }
            
            // Load connected entities
            let connectedEntityIds = entityRelationships.compactMap { relationship -> UUID? in
                if relationship.subjectEntityId == entity.id {
                    return relationship.objectEntityId
                } else if relationship.objectEntityId == entity.id {
                    return relationship.subjectEntityId
                }
                return nil
            }
            
            var entityDescriptor = FetchDescriptor<Entity>()
            entityDescriptor.sortBy = [SortDescriptor(\.importance, order: .reverse)]
            let allEntities = try modelContext.fetch(entityDescriptor)
            connectedEntities = allEntities.filter { connectedEntityIds.contains($0.id) }
            
        } catch {
            print("Failed to load related data: \(error)")
        }
    }
    
    private func saveChanges() {
        entity.name = editedName
        entity.entityDescription = editedDescription.isEmpty ? nil : editedDescription
        entity.aliases = editedAliases.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        entity.tags = editedTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save entity changes: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct EntityScoreView: View {
    let entity: Entity
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Entity Score")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(({
#if canImport(AppKit)
                    Color(NSColor.separatorColor)
#else
                    Color(.separator)
#endif
                }()), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: entity.entityScore)
                    .stroke(Color(entity.type.color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(entity.entityScore * 100))")
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct RelationshipRowView: View {
    let relationship: Relationship
    let currentEntityId: UUID
    let connectedEntities: [Entity]
    
    private var connectedEntity: Entity? {
        let connectedId = relationship.subjectEntityId == currentEntityId ? relationship.objectEntityId : relationship.subjectEntityId
        return connectedEntities.first { $0.id == connectedId }
    }
    
    var body: some View {
        HStack {
            Image(systemName: relationship.predicateType.category.iconName)
                .foregroundColor(Color(relationship.predicateType.color))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(relationship.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let entity = connectedEntity {
                    Text("→ \(entity.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(relationship.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("confidence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(8)
    }
}

struct ConnectedEntityRowView: View {
    let entity: Entity
    
    var body: some View {
        HStack {
            Image(systemName: entity.type.iconName)
                .foregroundColor(Color(entity.type.color))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(entity.type.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(entity.mentions)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    let entity = Entity(name: "John Doe", type: .person)
    entity.entityDescription = "Software engineer working on AI projects"
    entity.mentions = 15
    entity.confidence = 0.85
    entity.importance = 0.7
    entity.aliases = ["John", "Johnny"]
    entity.tags = ["engineer", "AI", "colleague"]
    
    return EntityDetailView(entity: entity, modelContext: ModelContext(try! ModelContainer(for: Entity.self)))
}