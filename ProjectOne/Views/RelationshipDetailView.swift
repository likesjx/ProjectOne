import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Detailed view for exploring and editing relationship information
struct RelationshipDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let relationship: Relationship
    let modelContext: ModelContext
    
    @State private var isEditing = false
    @State private var editedContext: String
    @State private var editedStrength: Double
    @State private var editedConfidence: Double
    @State private var subjectEntity: Entity?
    @State private var objectEntity: Entity?
    @State private var showingSubjectDetails = false
    @State private var showingObjectDetails = false
    
    init(relationship: Relationship, modelContext: ModelContext) {
        self.relationship = relationship
        self.modelContext = modelContext
        self._editedContext = State(initialValue: relationship.context ?? "")
        self._editedStrength = State(initialValue: relationship.strength)
        self._editedConfidence = State(initialValue: relationship.confidence)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    headerSection
                    
                    // Relationship Triple
                    relationshipTripleSection
                    
                    // Basic Information
                    basicInfoSection
                    
                    // Metrics Section
                    metricsSection
                    
                    // Evidence Section
                    evidenceSection
                    
                    // Temporal Information
                    if relationship.isTemporallyBounded {
                        temporalSection
                    }
                    
                    // Improvement Suggestions
                    if !relationship.improvementSuggestions.isEmpty {
                        suggestionsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Relationship Details")
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
            .sheet(isPresented: $showingSubjectDetails) {
                if let entity = subjectEntity {
                    EntityDetailView(entity: entity, modelContext: modelContext)
                }
            }
            .sheet(isPresented: $showingObjectDetails) {
                if let entity = objectEntity {
                    EntityDetailView(entity: entity, modelContext: modelContext)
                }
            }
        }
        .task {
            await loadEntities()
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Relationship icon and category
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(relationship.predicateType.color).opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: relationship.predicateType.category.iconName)
                        .font(.system(size: 40))
                        .foregroundColor(Color(relationship.predicateType.color))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(relationship.description)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(relationship.predicateType.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Validation and activity badges
                    HStack(spacing: 8) {
                        HStack {
                            Image(systemName: relationship.isValidated ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(relationship.isValidated ? .green : .orange)
                            
                            Text(relationship.isValidated ? "Validated" : "Needs Validation")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        HStack {
                            Image(systemName: relationship.isActive ? "circle.fill" : "circle.slash")
                                .foregroundColor(relationship.isActive ? .green : .gray)
                            
                            Text(relationship.isActive ? "Active" : "Inactive")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Relationship score visualization
            RelationshipScoreView(relationship: relationship)
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
    
    // MARK: - Relationship Triple Section
    
    private var relationshipTripleSection: some View {
        VStack(spacing: 16) {
            Text("Relationship Triple")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Subject Entity
                EntityButton(
                    entity: subjectEntity,
                    label: "Subject",
                    action: { showingSubjectDetails = true }
                )
                
                // Predicate
                VStack(spacing: 8) {
                    Image(systemName: relationship.bidirectional ? "arrow.left.arrow.right" : "arrow.right")
                        .font(.title2)
                        .foregroundColor(Color(relationship.predicateType.color))
                    
                    Text(relationship.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                // Object Entity
                EntityButton(
                    entity: objectEntity,
                    label: "Object",
                    action: { showingObjectDetails = true }
                )
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
    
    // MARK: - Basic Information Section
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Context
            VStack(alignment: .leading, spacing: 8) {
                Text("Context")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isEditing {
                    TextField("Relationship context...", text: $editedContext, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                } else {
                    Text(relationship.context?.isEmpty == false ? relationship.context! : "No context provided")
                        .font(.subheadline)
                        .foregroundColor(relationship.context?.isEmpty == false ? .primary : .secondary)
                }
            }
            
            // Adjustable metrics
            if isEditing {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Strength: \(Int(editedStrength * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Slider(value: $editedStrength, in: 0...1, step: 0.01)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confidence: \(Int(editedConfidence * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Slider(value: $editedConfidence, in: 0...1, step: 0.01)
                    }
                }
            }
            
            // Extraction source
            if let source = relationship.extractionSource {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extraction Source")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }()))
                        .cornerRadius(6)
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
                    value: "\(relationship.mentions)",
                    icon: "bubble.left.and.bubble.right",
                    color: .blue
                )
                
                MetricCard(
                    title: "Strength",
                    value: "\(Int(relationship.strength * 100))%",
                    icon: "bolt",
                    color: .orange
                )
                
                MetricCard(
                    title: "Confidence",
                    value: "\(Int(relationship.confidence * 100))%",
                    icon: "checkmark.circle",
                    color: relationship.confidence > 0.7 ? .green : .orange
                )
                
                MetricCard(
                    title: "Importance",
                    value: "\(Int(relationship.importance * 100))%",
                    icon: "star",
                    color: .purple
                )
            }
            
            // Additional metrics
            VStack(spacing: 12) {
                HStack {
                    Text("Efficiency")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f%%", relationship.efficiency * 100))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: relationship.efficiency)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 1 - relationship.efficiency, green: relationship.efficiency, blue: 0)))
                
                HStack {
                    Text("Freshness")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f%%", relationship.freshness * 100))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: relationship.freshness)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(red: 1 - relationship.freshness, green: relationship.freshness, blue: 0)))
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
    
    // MARK: - Evidence Section
    
    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Evidence")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(relationship.evidence.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if relationship.evidence.isEmpty {
                Text("No evidence provided")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(relationship.evidence.enumerated()), id: \.offset) { index, evidence in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color(.systemBlue))
                                .clipShape(Circle())
                            
                            Text(evidence)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
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
    
    // MARK: - Temporal Section
    
    private var temporalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Temporal Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if let startDate = relationship.startDate {
                    HStack {
                        Text("Start Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let endDate = relationship.endDate {
                    HStack {
                        Text("End Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(endDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let duration = relationship.duration {
                    HStack {
                        Text("Duration")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
            
            ForEach(relationship.improvementSuggestions, id: \.self) { suggestion in
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
    
    private func loadEntities() async {
        do {
            // Load subject entity
            var subjectDescriptor = FetchDescriptor<Entity>()
            subjectDescriptor.fetchLimit = 1
            let allEntities = try modelContext.fetch(subjectDescriptor)
            subjectEntity = allEntities.first { $0.id == relationship.subjectEntityId }
            
            // Load object entity
            objectEntity = allEntities.first { $0.id == relationship.objectEntityId }
            
        } catch {
            print("Failed to load entities: \(error)")
        }
    }
    
    private func saveChanges() {
        relationship.context = editedContext.isEmpty ? nil : editedContext
        relationship.strength = editedStrength
        relationship.confidence = editedConfidence
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save relationship changes: \(error)")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let days = Int(duration) / 86400
        let hours = (Int(duration) % 86400) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if days > 0 {
            return "\(days) days, \(hours) hours"
        } else if hours > 0 {
            return "\(hours) hours, \(minutes) minutes"
        } else {
            return "\(minutes) minutes"
        }
    }
}

// MARK: - Supporting Views

struct RelationshipScoreView: View {
    let relationship: Relationship
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Relationship Score")
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
                    .trim(from: 0, to: relationship.relationshipScore)
                    .stroke(Color(relationship.predicateType.color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(relationship.relationshipScore * 100))")
                    .font(.headline)
                    .fontWeight(.bold)
            }
        }
    }
}

struct EntityButton: View {
    let entity: Entity?
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if let entity = entity {
                    ZStack {
                        Circle()
                            .fill(Color(entity.type.color).opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: entity.type.iconName)
                            .font(.title3)
                            .foregroundColor(Color(entity.type.color))
                    }
                    
                    Text(entity.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    ZStack {
                        Circle()
                            .fill(({
#if canImport(AppKit)
                    Color(NSColor.separatorColor)
#else
                    Color(.separator)
#endif
                }()))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "questionmark")
                            .font(.title3)
                            .foregroundColor(.white)
                    }
                    
                    Text("Unknown")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    let relationship = {
        let relationship = Relationship(
            subjectEntityId: UUID(),
            predicateType: .worksFor,
            objectEntityId: UUID()
        )
        relationship.context = "Mentioned during discussion about team structure"
        relationship.confidence = 0.85
        relationship.strength = 0.9
        relationship.mentions = 5
        relationship.addEvidence("John works for Apple according to his LinkedIn profile")
        relationship.addEvidence("He mentioned Apple as his employer in the meeting")
        return relationship
    }()
    
    return RelationshipDetailView(relationship: relationship, modelContext: ModelContext(try! SwiftData.ModelContainer(for: Relationship.self)))
}