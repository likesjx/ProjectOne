import SwiftUI
import SwiftData

/// Interactive knowledge graph visualization showing entities and their relationships
struct KnowledgeGraphView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var graphService: KnowledgeGraphService
    @State private var selectedEntity: Entity?
    @State private var selectedRelationship: Relationship?
    @State private var searchText = ""
    @State private var showingEntityDetails = false
    @State private var showingRelationshipDetails = false
    @State private var selectedEntityTypes: Set<EntityType> = Set(EntityType.allCases)
    @State private var selectedRelationshipCategories: Set<RelationshipCategory> = Set(RelationshipCategory.allCases)
    @State private var showingFilters = false
    @State private var graphLayout: GraphLayout = .force
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewOffset: CGSize = .zero
    
    init(modelContext: ModelContext) {
        self._graphService = StateObject(wrappedValue: KnowledgeGraphService(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                // Graph Canvas
                graphCanvas
                
                // Overlay UI
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
            .navigationTitle("Knowledge Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    
                    Menu {
                        Picker("Layout", selection: $graphLayout) {
                            ForEach(GraphLayout.allCases, id: \.self) { layout in
                                Label(layout.displayName, systemImage: layout.iconName)
                                    .tag(layout)
                            }
                        }
                    } label: {
                        Image(systemName: "rectangle.3.group")
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                filtersView
            }
            .sheet(isPresented: $showingEntityDetails) {
                if let entity = selectedEntity {
                    EntityDetailView(entity: entity, modelContext: modelContext)
                }
            }
            .sheet(isPresented: $showingRelationshipDetails) {
                if let relationship = selectedRelationship {
                    RelationshipDetailView(relationship: relationship, modelContext: modelContext)
                }
            }
        }
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
    }
    
    // MARK: - Graph Canvas
    
    private var graphCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                // Relationships (edges)
                ForEach(graphService.filteredRelationships, id: \.id) { relationship in
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
                            selectedRelationship = relationship
                            selectedEntity = nil
                            showingRelationshipDetails = true
                        }
                    }
                }
                
                // Entities (nodes)
                ForEach(graphService.filteredEntities, id: \.id) { entity in
                    if let position = graphService.getNodePosition(entity.id) {
                        EntityNodeView(
                            entity: entity,
                            position: position,
                            isSelected: selectedEntity?.id == entity.id
                        )
                        .onTapGesture {
                            selectedEntity = entity
                            selectedRelationship = nil
                            showingEntityDetails = true
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    graphService.updateNodePosition(entity.id, position: CGPoint(
                                        x: position.x + value.translation.x,
                                        y: position.y + value.translation.y
                                    ))
                                }
                        )
                    }
                }
            }
            .scaleEffect(zoomScale)
            .offset(viewOffset)
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
                Text("\(graphService.filteredEntities.count) entities")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(graphService.filteredRelationships.count) relationships")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.trailing)
        }
        .padding(.top)
        .background(Color(.systemBackground).opacity(0.9))
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
                        
                        if let description = entity.description {
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
                .background(Color(.systemGray6))
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
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
    }
    
    // MARK: - Filters View
    
    private var filtersView: some View {
        NavigationView {
            Form {
                Section("Entity Types") {
                    ForEach(EntityType.allCases, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { selectedEntityTypes.contains(type) },
                            set: { isSelected in
                                if isSelected {
                                    selectedEntityTypes.insert(type)
                                } else {
                                    selectedEntityTypes.remove(type)
                                }
                            }
                        )) {
                            Label(type.rawValue, systemImage: type.iconName)
                                .foregroundColor(Color(type.color))
                        }
                    }
                }
                
                Section("Relationship Categories") {
                    ForEach(RelationshipCategory.allCases, id: \.self) { category in
                        Toggle(isOn: Binding(
                            get: { selectedRelationshipCategories.contains(category) },
                            set: { isSelected in
                                if isSelected {
                                    selectedRelationshipCategories.insert(category)
                                } else {
                                    selectedRelationshipCategories.remove(category)
                                }
                            }
                        )) {
                            Label(category.rawValue, systemImage: category.iconName)
                                .foregroundColor(Color(category.color))
                        }
                    }
                }
                
                Section("Graph Options") {
                    Button("Reset View") {
                        zoomScale = 1.0
                        viewOffset = .zero
                        graphService.resetLayout()
                    }
                    
                    Button("Select All Entities") {
                        selectedEntityTypes = Set(EntityType.allCases)
                    }
                    
                    Button("Select All Relationships") {
                        selectedRelationshipCategories = Set(RelationshipCategory.allCases)
                    }
                }
            }
            .navigationTitle("Filter Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingFilters = false
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadGraphData() async {
        await graphService.loadData()
        updateGraph()
    }
    
    private func updateGraph() {
        graphService.applyFilters(
            entityTypes: selectedEntityTypes,
            relationshipCategories: selectedRelationshipCategories,
            searchQuery: searchText.isEmpty ? nil : searchText
        )
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

#Preview {
    NavigationView {
        KnowledgeGraphView(modelContext: ModelContext(try! ModelContainer(for: Entity.self, Relationship.self)))
    }
}