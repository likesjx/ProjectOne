//
//  GraphFiltersView.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Filter controls for cognitive knowledge graph
//

import SwiftUI

// MARK: - Graph Filters View

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct GraphFiltersView: View {
    @ObservedObject var viewModel: CognitiveKnowledgeGraphViewModel
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        List {
            searchSection
            
            if viewModel.isCognitiveEnhanced {
                cognitiveFilterSection
            }
            
            entityTypesSection
            
            relationshipCategoriesSection
            
            layoutSection
            
            cognitiveVisualizationSection
            
            actionsSection
        }
        .navigationTitle("Graph Filters")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        Section("Search") {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search entities...", text: $viewModel.searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !viewModel.searchQuery.isEmpty {
                    Button("Clear") {
                        viewModel.searchQuery = ""
                    }
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
                }
            }
            
            if viewModel.isCognitiveEnhanced && !viewModel.searchQuery.isEmpty {
                Button("Cognitive Search", systemImage: "brain") {
                    Task {
                        await viewModel.performCognitiveSearch(viewModel.searchQuery)
                    }
                }
                .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
            }
        }
    }
    
    // MARK: - Cognitive Filter Section
    
    private var cognitiveFilterSection: some View {
        Section("Cognitive Filtering") {
            Picker("Cognitive Filter", selection: $viewModel.cognitiveFilter) {
                ForEach(CognitiveFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Text(viewModel.cognitiveFilter.description)
                .font(GlassDesignSystem.Typography.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        }
    }
    
    // MARK: - Entity Types Section
    
    private var entityTypesSection: some View {
        Section("Entity Types") {
            ForEach(EntityType.allCases, id: \.self) { entityType in
                HStack {
                    Image(systemName: entityType.iconName)
                        .foregroundColor(Color(entityType.color))
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entityType.rawValue)
                            .font(GlassDesignSystem.Typography.body)
                        
                        Text(entityType.description)
                            .font(GlassDesignSystem.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.selectedEntityTypes.contains(entityType) },
                        set: { isSelected in
                            if isSelected {
                                viewModel.selectedEntityTypes.insert(entityType)
                            } else {
                                viewModel.selectedEntityTypes.remove(entityType)
                            }
                        }
                    ))
                }
            }
            
            HStack {
                Button("Select All") {
                    viewModel.selectedEntityTypes = Set(EntityType.allCases)
                }
                
                Spacer()
                
                Button("Select None") {
                    viewModel.selectedEntityTypes.removeAll()
                }
            }
            .font(GlassDesignSystem.Typography.caption)
            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
        }
    }
    
    // MARK: - Relationship Categories Section
    
    private var relationshipCategoriesSection: some View {
        Section("Relationship Categories") {
            ForEach(RelationshipCategory.allCases, id: \.self) { category in
                HStack {
                    Text(category.displayName)
                        .font(GlassDesignSystem.Typography.body)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { viewModel.selectedRelationshipCategories.contains(category) },
                        set: { isSelected in
                            if isSelected {
                                viewModel.selectedRelationshipCategories.insert(category)
                            } else {
                                viewModel.selectedRelationshipCategories.remove(category)
                            }
                        }
                    ))
                }
            }
            
            HStack {
                Button("Select All") {
                    viewModel.selectedRelationshipCategories = Set(RelationshipCategory.allCases)
                }
                
                Spacer()
                
                Button("Select None") {
                    viewModel.selectedRelationshipCategories.removeAll()
                }
            }
            .font(GlassDesignSystem.Typography.caption)
            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
        }
    }
    
    // MARK: - Layout Section
    
    private var layoutSection: some View {
        Section("Graph Layout") {
            Picker("Layout Algorithm", selection: $viewModel.selectedLayout) {
                ForEach(GraphLayout.allCases, id: \.self) { layout in
                    Text(layout.displayName).tag(layout)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("Reset Layout", systemImage: "arrow.clockwise") {
                viewModel.resetLayout()
            }
            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
        }
    }
    
    // MARK: - Cognitive Visualization Section
    
    private var cognitiveVisualizationSection: some View {
        Section("Cognitive Visualization") {
            Toggle("Show Cognitive Heatmap", isOn: $viewModel.showCognitiveHeatmap)
                .disabled(!viewModel.isCognitiveEnhanced)
            
            Toggle("Show Layer Boundaries", isOn: $viewModel.showLayerBoundaries)
                .disabled(!viewModel.isCognitiveEnhanced)
            
            if !viewModel.isCognitiveEnhanced {
                Text("Cognitive visualization requires cognitive system integration")
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section("Actions") {
            Button("Export Graph Data", systemImage: "square.and.arrow.up") {
                exportGraphData()
            }
            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
            
            if viewModel.isCognitiveEnhanced {
                Button("Sync with Cognitive System", systemImage: "brain.head.profile") {
                    Task {
                        // This would trigger a sync with the cognitive system
                        await viewModel.loadData()
                    }
                }
                .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
            }
            
            Button("Reset All Filters", systemImage: "arrow.counterclockwise") {
                resetAllFilters()
            }
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Helper Methods
    
    private func exportGraphData() {
        let exportData = viewModel.exportGraphData()
        
        // Create share sheet or save functionality
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = .prettyPrinted
        
        // This would normally integrate with iOS sharing or file system
        print("📤 Exporting graph data: \(exportData.entities.count) entities, \(exportData.relationships.count) relationships")
    }
    
    private func resetAllFilters() {
        viewModel.selectedEntityTypes = Set(EntityType.allCases)
        viewModel.selectedRelationshipCategories = Set(RelationshipCategory.allCases)
        viewModel.searchQuery = ""
        viewModel.cognitiveFilter = .all
        viewModel.showCognitiveHeatmap = false
        viewModel.showLayerBoundaries = true
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview {
    NavigationView {
        GraphFiltersView(viewModel: CognitiveKnowledgeGraphViewModel.createMockViewModel())
    }
}

// MARK: - Mock Extension for Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CognitiveKnowledgeGraphViewModel {
    #if DEBUG
    static func createMockViewModel() -> CognitiveKnowledgeGraphViewModel {
        let mockContext = try! ModelContext(ModelContainer(for: Schema([]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
        let mockService = KnowledgeGraphService(modelContext: mockContext)
        
        let viewModel = CognitiveKnowledgeGraphViewModel(knowledgeGraphService: mockService)
        viewModel.isCognitiveEnhanced = true
        
        return viewModel
    }
    #endif
}