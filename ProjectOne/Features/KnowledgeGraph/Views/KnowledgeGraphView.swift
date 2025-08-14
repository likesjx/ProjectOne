import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Interactive knowledge graph visualization showing entities and their relationships
struct KnowledgeGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var graphService: KnowledgeGraphService
    
    // Real-time data monitoring with @Query
    @Query(sort: \Entity.importance, order: .reverse) private var allEntities: [Entity]
    @Query(sort: \Relationship.importance, order: .reverse) private var allRelationships: [Relationship]
    
    @State private var selectedEntity: Entity?
    @State private var selectedRelationship: Relationship?
    @State private var searchText = ""
    @State private var showingEntityDetails = false
    @State private var showingRelationshipDetails = false
    @State private var selectedEntityTypes: Set<EntityType> = Set(EntityType.allCases)
    @State private var selectedRelationshipCategories: Set<RelationshipCategory> = Set(RelationshipCategory.allCases)
    @State private var showingFilters = false
    @State private var showingCreateEntity = false
    @State private var showingCreateRelationship = false
    @State private var graphLayout: GraphLayout = .force
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewOffset: CGSize = .zero
    @State private var lastDataUpdate = Date()
    
    init(modelContext: ModelContext) {
        self._graphService = StateObject(wrappedValue: KnowledgeGraphService(modelContext: modelContext))
    }
    
    var body: some View {
        navigationContainer
            .task {
                await loadGraphData()
            }
            .onChange(of: selectedEntityTypes) { _, _ in
                updateGraph()
            }
            .onChange(of: selectedRelationshipCategories) { _, _ in
                updateGraph()
            }
            .onChange(of: searchText) { _, _ in
                updateGraph()
            }
            .onChange(of: graphLayout) { _, _ in
                graphService.setLayout(graphLayout)
            }
            .onChange(of: allEntities) { _, _ in
                Task {
                    await refreshGraphData()
                }
            }
            .onChange(of: allRelationships) { _, _ in
                Task {
                    await refreshGraphData()
                }
            }
            .onAppear {
                setupDataObservation()
            }
            .onDisappear {
                cleanupTimers()
            }
    }
    
    // MARK: - Main Container
    
    private var navigationContainer: some View {
        NavigationView {
            mainContent
                .navigationTitle("Knowledge Graph")
                .toolbar {
#if os(iOS)
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        toolbarButtons
                    }
#else
                    ToolbarItemGroup(placement: .primaryAction) {
                        toolbarButtons
                    }
#endif
                }
                .sheet(isPresented: $showingFilters) {
                    filtersView
                }
                .sheet(isPresented: $showingEntityDetails) {
                    entityDetailsSheet
                }
                .sheet(isPresented: $showingRelationshipDetails) {
                    relationshipDetailsSheet
                }
                .sheet(isPresented: $showingCreateEntity) {
                    CreateEntityView(modelContext: modelContext)
                }
                .sheet(isPresented: $showingCreateRelationship) {
                    CreateRelationshipView(modelContext: modelContext, entities: allEntities)
                }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
    
    private var mainContent: some View {
        ZStack {
            // Background
            ({
#if canImport(AppKit)
                Color(NSColor.controlBackgroundColor)
#else
                Color(.systemGray6)
#endif
            }())
                .ignoresSafeArea()
            
            // Graph Canvas
            graphCanvas
            
            // Overlay UI
            overlayContent
        }
    }
    
    private var overlayContent: some View {
        VStack {
            // Top toolbar
            topToolbar
            
            Spacer()
            
            // Bottom info panel
            if selectedEntity != nil || selectedRelationship != nil {
                bottomInfoPanel
            }
        }
    }
    
    private var toolbarButtons: some View {
        Group {
            Button(action: { showingFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            
            Menu {
                Button("Add Entity") {
                    showingCreateEntity = true
                }
                
                Button("Add Relationship") {
                    showingCreateRelationship = true
                }
                
                Divider()
                
                Button("Refresh Data") {
                    Task {
                        await refreshGraphData()
                    }
                }
            } label: {
                Image(systemName: "plus.circle")
            }
            
            layoutMenu
        }
    }
    
    private var layoutMenu: some View {
        Menu {
            layoutPicker
        } label: {
            Image(systemName: "rectangle.3.group")
        }
    }
    
    private var layoutPicker: some View {
        Picker("Layout", selection: $graphLayout) {
            ForEach(GraphLayout.allCases, id: \.self) { layout in
                Label(layout.displayName, systemImage: layout.iconName)
                    .tag(layout)
            }
        }
    }
    
    @ViewBuilder
    private var entityDetailsSheet: some View {
        if let entity = selectedEntity {
            EntityDetailView(entity: entity, modelContext: modelContext)
        }
    }
    
    @ViewBuilder
    private var relationshipDetailsSheet: some View {
        if let relationship = selectedRelationship {
            RelationshipDetailView(relationship: relationship, modelContext: modelContext)
        }
    }
    
    // MARK: - Graph Canvas
    
    private var graphCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                relationshipEdgesView
                entityNodesView
            }
            .scaleEffect(zoomScale)
            .offset(viewOffset)
            .clipped()
            .onTapGesture { location in
                selectedEntity = nil
                selectedRelationship = nil
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoomScale = value
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewOffset = value.translation
                    }
            )
            .onAppear {
                graphService.setCanvasSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                graphService.setCanvasSize(newSize)
            }
        }
    }
    
    private var relationshipEdgesView: some View {
        ForEach(Array(graphService.filteredRelationships.enumerated()), id: \.element.id) { index, relationship in
            relationshipEdge(for: relationship)
        }
    }
    
    @ViewBuilder
    private func relationshipEdge(for relationship: Relationship) -> some View {
        if let subject = graphService.getEntity(relationship.subjectEntityId),
           let object = graphService.getEntity(relationship.objectEntityId),
           let subjectPosition = graphService.getNodePosition(subject.id),
           let objectPosition = graphService.getNodePosition(object.id) {
            
            RelationshipEdgeView(
                relationship: relationship,
                startPosition: subjectPosition,
                endPosition: objectPosition,
                isSelected: selectedRelationship?.id == relationship.id
            )
            .onTapGesture {
                handleRelationshipTap(relationship)
            }
        }
    }
    
    private func handleRelationshipTap(_ relationship: Relationship) {
        selectedRelationship = relationship
        selectedEntity = nil
        showingRelationshipDetails = true
    }
    
    private var entityNodesView: some View {
        ForEach(Array(graphService.filteredEntities.enumerated()), id: \.element.id) { index, entity in
            entityNode(for: entity)
        }
    }
    
    @ViewBuilder
    private func entityNode(for entity: Entity) -> some View {
        if let position = graphService.getNodePosition(entity.id) {
            EntityNodeView(
                entity: entity,
                position: position,
                isSelected: selectedEntity?.id == entity.id
            )
            .onTapGesture {
                handleEntityTap(entity)
            }
            .gesture(entityDragGesture(for: entity, at: position))
        }
    }
    
    private func handleEntityTap(_ entity: Entity) {
        selectedEntity = entity
        selectedRelationship = nil
        showingEntityDetails = true
    }
    
    private func entityDragGesture(for entity: Entity, at position: CGPoint) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let newPosition = CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                )
                graphService.updateNodePosition(entity.id, position: newPosition)
            }
    }
    
    // MARK: - Top Toolbar
    
    private var topToolbar: some View {
        HStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search entities or relationships...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            
            // Graph stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(graphService.filteredEntities.count)/\(allEntities.count) entities")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(graphService.filteredRelationships.count)/\(allRelationships.count) relationships")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if lastDataUpdate != Date(timeIntervalSince1970: 0) {
                    Text("Updated \(lastDataUpdate.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.trailing)
        }
        .padding(.top)
        .background({
#if canImport(AppKit)
            Color(NSColor.controlBackgroundColor).opacity(0.9)
#else
            Color(.systemGray6).opacity(0.9)
#endif
        }())
    }
    
    // MARK: - Bottom Info Panel
    
    private var bottomInfoPanel: some View {
        VStack(spacing: 8) {
            if let entity = selectedEntity {
                HStack {
                    Image(systemName: entity.type.iconName)
                        .foregroundColor(Color(entity.type.color))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entity.name)
                            .font(.headline)
                        
                        Text("\(entity.mentions) mentions • \(entity.relationships.count) relationships")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let description = entity.entityDescription {
                            Text(description)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Details") {
                        showingEntityDetails = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }())
                .cornerRadius(12)
            }
            
            if let relationship = selectedRelationship {
                HStack {
                    Image(systemName: relationship.predicateType.category.iconName)
                        .foregroundColor(Color(relationship.predicateType.color))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(relationship.description)
                            .font(.headline)
                        
                        Text("Confidence: \(Int(relationship.confidence * 100))% • \(relationship.mentions) mentions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let context = relationship.context {
                            Text(context)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Details") {
                        showingRelationshipDetails = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background({
#if canImport(AppKit)
                    Color(NSColor.controlBackgroundColor)
#else
                    Color(.systemGray6)
#endif
                }())
                .cornerRadius(12)
            }
        }
        .padding()
        .background({
#if canImport(AppKit)
            Color(NSColor.controlBackgroundColor).opacity(0.9)
#else
            Color(.systemGray6).opacity(0.9)
#endif
        }())
    }
    
    // MARK: - Filters View
    
    private var filtersView: some View {
        NavigationView {
            Form {
                Section("Entity Types") {
                    ForEach(EntityType.allCases, id: \.self) { type in
                        entityTypeToggle(for: type)
                    }
                }
                
                Section("Relationship Categories") {
                    ForEach(RelationshipCategory.allCases, id: \.self) { category in
                        relationshipCategoryToggle(for: category)
                    }
                }
                
                Section("Graph Options") {
                    Button("Reset View", action: resetView)
                    Button("Select All Entities", action: selectAllEntities)
                    Button("Select All Relationships", action: selectAllRelationships)
                }
            }
            .navigationTitle("Filter Graph")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        showingFilters = false
                    }
                }
#else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingFilters = false
                    }
                }
#endif
            }
        }
    }
    
    // MARK: - Filter Helpers
    
    private func entityTypeToggle(for type: EntityType) -> some View {
        Toggle(isOn: entityTypeBinding(for: type)) {
            Label(type.rawValue, systemImage: type.iconName)
                .foregroundColor(Color(type.color))
        }
    }
    
    private func relationshipCategoryToggle(for category: RelationshipCategory) -> some View {
        Toggle(isOn: relationshipCategoryBinding(for: category)) {
            Label(category.rawValue, systemImage: category.iconName)
                .foregroundColor(Color(category.color))
        }
    }
    
    private func entityTypeBinding(for type: EntityType) -> Binding<Bool> {
        Binding(
            get: { selectedEntityTypes.contains(type) },
            set: { isSelected in
                if isSelected {
                    selectedEntityTypes.insert(type)
                } else {
                    selectedEntityTypes.remove(type)
                }
            }
        )
    }
    
    private func relationshipCategoryBinding(for category: RelationshipCategory) -> Binding<Bool> {
        Binding(
            get: { selectedRelationshipCategories.contains(category) },
            set: { isSelected in
                if isSelected {
                    selectedRelationshipCategories.insert(category)
                } else {
                    selectedRelationshipCategories.remove(category)
                }
            }
        )
    }
    
    // MARK: - Actions
    
    private func loadGraphData() async {
        await graphService.loadData()
        updateGraph()
        lastDataUpdate = Date()
    }
    
    private func refreshGraphData() async {
        // Use the real-time data from @Query with improved synchronization
        graphService.updateWithNewData(entities: allEntities, relationships: allRelationships)
        updateGraph()
        lastDataUpdate = Date()
    }
    
    private func updateGraph() {
        graphService.applyFilters(
            entityTypes: selectedEntityTypes,
            relationshipCategories: selectedRelationshipCategories,
            searchQuery: searchText.isEmpty ? nil : searchText
        )
    }
    
    private func setupDataObservation() {
        // Additional setup for data observation if needed
        print("🔍 [KnowledgeGraphView] Setting up data observation")
    }
    
    private func cleanupTimers() {
        // Clean up any running timers when view disappears
        graphService.stopLayout()
        print("🧹 [KnowledgeGraphView] Cleaned up timers")
    }
    
    private func resetView() {
        zoomScale = 1.0
        viewOffset = .zero
        graphService.resetLayout()
    }
    
    private func selectAllEntities() {
        selectedEntityTypes = Set(EntityType.allCases)
    }
    
    private func selectAllRelationships() {
        selectedRelationshipCategories = Set(RelationshipCategory.allCases)
    }
}

// MARK: - Graph Layout Enum

enum GraphLayout: String, CaseIterable {
    case force = "force"
    case circular = "circular"
    case hierarchical = "hierarchical"
    case radial = "radial"
    
    var displayName: String {
        switch self {
        case .force:
            return "Force-Directed"
        case .circular:
            return "Circular"
        case .hierarchical:
            return "Hierarchical"
        case .radial:
            return "Radial"
        }
    }
    
    var iconName: String {
        switch self {
        case .force:
            return "circle.hexagongrid"
        case .circular:
            return "circle"
        case .hierarchical:
            return "rectangle.3.group"
        case .radial:
            return "sun.max"
        }
    }
}

// MARK: - Preview

// MARK: - Create Entity View

struct CreateEntityView: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var type: EntityType = .person
    @State private var description = ""
    @State private var tags = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Entity Name", text: $name)
                    
                    Picker("Type", selection: $type) {
                        ForEach(EntityType.allCases, id: \.self) { entityType in
                            Label(entityType.rawValue, systemImage: entityType.iconName)
                                .tag(entityType)
                        }
                    }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $tags)
                }
            }
            .navigationTitle("New Entity")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createEntity()
                    }
                    .disabled(name.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createEntity() {
        isCreating = true
        
        let entity = Entity(name: name, type: type)
        entity.entityDescription = description.isEmpty ? nil : description
        entity.tags = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        entity.confidence = 1.0 // User-created entities have high confidence
        entity.isValidated = true
        
        modelContext.insert(entity)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Failed to create entity: \(error)")
            isCreating = false
        }
    }
}

// MARK: - Create Relationship View

struct CreateRelationshipView: View {
    let modelContext: ModelContext
    let entities: [Entity]
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSubjectEntity: Entity?
    @State private var selectedObjectEntity: Entity?
    @State private var predicateType: PredicateType = .relatedTo
    @State private var context = ""
    @State private var strength: Double = 0.5
    @State private var confidence: Double = 0.8
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Relationship Structure") {
                    Picker("Subject Entity", selection: $selectedSubjectEntity) {
                        Text("Select entity...").tag(nil as Entity?)
                        ForEach(entities, id: \.id) { entity in
                            Text(entity.name).tag(entity as Entity?)
                        }
                    }
                    
                    Picker("Predicate", selection: $predicateType) {
                        ForEach(PredicateType.allCases, id: \.self) { predicate in
                            Text(predicate.description).tag(predicate)
                        }
                    }
                    
                    Picker("Object Entity", selection: $selectedObjectEntity) {
                        Text("Select entity...").tag(nil as Entity?)
                        ForEach(entities, id: \.id) { entity in
                            Text(entity.name).tag(entity as Entity?)
                        }
                    }
                }
                
                Section("Relationship Details") {
                    TextField("Context", text: $context, axis: .vertical)
                        .lineLimit(2...4)
                    
                    VStack(alignment: .leading) {
                        Text("Strength: \(strength, specifier: "%.1f")")
                        Slider(value: $strength, in: 0...1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Confidence: \(confidence, specifier: "%.1f")")
                        Slider(value: $confidence, in: 0...1)
                    }
                }
            }
            .navigationTitle("New Relationship")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createRelationship()
                    }
                    .disabled(!canCreateRelationship || isCreating)
                }
            }
        }
    }
    
    private var canCreateRelationship: Bool {
        guard let subject = selectedSubjectEntity,
              let object = selectedObjectEntity else { return false }
        return subject.id != object.id
    }
    
    private func createRelationship() {
        guard let subject = selectedSubjectEntity,
              let object = selectedObjectEntity else { return }
        
        isCreating = true
        
        let relationship = Relationship(
            subjectEntityId: subject.id,
            predicateType: predicateType,
            objectEntityId: object.id
        )
        
        relationship.subjectName = subject.name
        relationship.objectName = object.name
        relationship.context = context.isEmpty ? nil : context
        relationship.strength = strength
        relationship.confidence = confidence
        relationship.isValidated = true
        relationship.mentions = 1
        relationship.importance = (strength + confidence) / 2.0
        
        // Update entity relationships
        subject.addRelationship(relationship.id)
        object.addRelationship(relationship.id)
        subject.recordMention()
        object.recordMention()
        
        modelContext.insert(relationship)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ Failed to create relationship: \(error)")
            isCreating = false
        }
    }
}

#Preview {
    NavigationView {
        KnowledgeGraphView(modelContext: ModelContext(try! SwiftData.ModelContainer(for: Entity.self, Relationship.self)))
    }
}