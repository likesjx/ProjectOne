//
//  CognitiveEntityDetailView.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Detailed view for entities with cognitive enhancements
//

import SwiftUI
import Charts

// MARK: - Cognitive Entity Detail View

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveEntityDetailView: View {
    let entity: Entity
    @State private var selectedTab: DetailTab = .overview
    @State private var showEditSheet = false
    @Environment(\.dismiss) private var dismiss
    
    public init(entity: Entity) {
        self.entity = entity
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: GlassDesignSystem.Spacing.lg) {
                // Header with entity info
                entityHeader
                
                // Tab selection
                tabSelector
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .overview:
                        overviewContent
                    case .cognitive:
                        cognitiveContent
                    case .connections:
                        connectionsContent
                    case .attributes:
                        attributesContent
                    }
                }
                .animation(GlassDesignSystem.Animations.standard, value: selectedTab)
            }
            .padding()
        }
        .background {
            LinearGradient(
                colors: [
                    GlassDesignSystem.Colors.primaryGlass,
                    GlassDesignSystem.Colors.secondaryGlass
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit", systemImage: "pencil") {
                    showEditSheet = true
                }
                .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EntityEditView(entity: entity)
        }
    }
    
    // MARK: - Entity Header
    
    private var entityHeader: some View {
        VStack(spacing: GlassDesignSystem.Spacing.md) {
            HStack {
                // Entity icon and type
                VStack {
                    Image(systemName: entity.type.iconName)
                        .font(.largeTitle)
                        .foregroundColor(Color(entity.type.color))
                        .modifier(CognitiveGlow(
                            color: Color(entity.type.color),
                            isActive: entity.hasCognitiveRepresentation
                        ))
                    
                    Text(entity.type.rawValue)
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Cognitive status
                if entity.hasCognitiveRepresentation {
                    cognitiveStatusBadge
                }
            }
            
            // Entity name and description
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                Text(entity.name)
                    .font(GlassDesignSystem.Typography.title)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                if !entity.aliases.isEmpty {
                    Text("Also known as: \(entity.aliases.joined(separator: ", "))")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                if let description = entity.entityDescription {
                    Text(description)
                        .font(GlassDesignSystem.Typography.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                }
            }
            
            // Key metrics
            HStack(spacing: GlassDesignSystem.Spacing.md) {
                metricCard("Confidence", value: "\(Int(entity.confidence * 100))%", color: .blue)
                metricCard("Importance", value: "\(Int(entity.importance * 100))%", color: .purple)
                metricCard("Mentions", value: "\(entity.mentions)", color: .green)
                
                if entity.hasCognitiveRepresentation {
                    metricCard("Cognitive", value: "\(Int(entity.cognitiveConsolidationScore * 100))%", color: GlassDesignSystem.Colors.cognitiveAccent)
                }
            }
        }
        .glassCard()
    }
    
    private var cognitiveStatusBadge: some View {
        VStack(alignment: .trailing, spacing: GlassDesignSystem.Spacing.xs) {
            HStack(spacing: GlassDesignSystem.Spacing.xs) {
                if let layerType = entity.cognitiveLayerType {
                    LayerIndicator(layerType: layerType, isActive: true, size: 12)
                }
                Text("Cognitive")
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, GlassDesignSystem.Spacing.sm)
            .padding(.vertical, GlassDesignSystem.Spacing.xs)
            .background {
                if let layerType = entity.cognitiveLayerType {
                    cognitiveLayerBackgroundColor(layerType)
                } else {
                    Color.secondary.opacity(0.2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.sm))
            
            if !entity.fusionConnectionIds.isEmpty {
                Text("\(entity.fusionConnectionIds.count) fusions")
                    .font(GlassDesignSystem.Typography.caption2)
                    .foregroundColor(GlassDesignSystem.Colors.fusionHighlight)
            }
        }
    }
    
    private func cognitiveLayerBackgroundColor(_ layer: CognitiveLayerType) -> Color {
        switch layer {
        case .veridical: return GlassDesignSystem.Colors.veridicalGlass
        case .semantic: return GlassDesignSystem.Colors.semanticGlass
        case .episodic: return GlassDesignSystem.Colors.episodicGlass
        case .fusion: return GlassDesignSystem.Colors.fusionGlass
        }
    }
    
    private func metricCard(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: GlassDesignSystem.Spacing.xs) {
            Text(value)
                .font(GlassDesignSystem.Typography.metricValue)
                .foregroundColor(color)
            
            Text(title)
                .font(GlassDesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: GlassDesignSystem.Spacing.xs) {
                        Image(systemName: tab.iconName)
                            .font(.title3)
                        
                        Text(tab.displayName)
                            .font(GlassDesignSystem.Typography.caption)
                    }
                    .foregroundColor(selectedTab == tab ? GlassDesignSystem.Colors.cognitiveAccent : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, GlassDesignSystem.Spacing.sm)
                }
                .background {
                    if selectedTab == tab {
                        GlassDesignSystem.Colors.cognitiveAccent.opacity(0.1)
                    }
                }
            }
        }
        .glassCard()
    }
    
    // MARK: - Content Sections
    
    private var overviewContent: some View {
        VStack(spacing: GlassDesignSystem.Spacing.lg) {
            // Entity timeline
            if entity.mentions > 1 {
                timelineSection
            }
            
            // Tags and metadata
            tagsAndMetadataSection
            
            // Suggestions for improvement
            if !entity.improvementSuggestions.isEmpty {
                improvementSuggestionsSection
            }
        }
    }
    
    private var cognitiveContent: some View {
        VStack(spacing: GlassDesignSystem.Spacing.lg) {
            if entity.hasCognitiveRepresentation {
                // Cognitive metrics
                cognitiveMetricsSection
                
                // Layer information
                layerInformationSection
                
                // Fusion connections
                if !entity.fusionConnectionIds.isEmpty {
                    fusionConnectionsSection
                }
                
                // Cognitive timeline
                cognitiveTimelineSection
            } else {
                noCognitiveRepresentationView
            }
        }
    }
    
    private var connectionsContent: some View {
        VStack(spacing: GlassDesignSystem.Spacing.lg) {
            Text("Entity Connections")
                .font(GlassDesignSystem.Typography.headline)
            
            // This would show connected entities
            Text("Connection visualization would be implemented here")
                .font(GlassDesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .glassCard()
        }
    }
    
    private var attributesContent: some View {
        VStack(spacing: GlassDesignSystem.Spacing.lg) {
            // Entity attributes
            if !entity.attributes.isEmpty {
                attributesSection
            }
            
            // Technical metadata
            technicalMetadataSection
        }
    }
    
    // MARK: - Individual Sections
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Activity Timeline")
                .font(GlassDesignSystem.Typography.headline)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                HStack {
                    Text("First mentioned:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entity.timestamp, style: .date)
                }
                
                HStack {
                    Text("Last mentioned:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entity.lastMentioned, style: .date)
                }
                
                HStack {
                    Text("Total mentions:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(entity.mentions)")
                }
                
                HStack {
                    Text("Freshness score:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(entity.freshness * 100))%")
                        .foregroundColor(entity.freshness > 0.5 ? .green : .orange)
                }
            }
            .font(GlassDesignSystem.Typography.body)
        }
        .glassCard()
    }
    
    private var tagsAndMetadataSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Tags & Metadata")
                .font(GlassDesignSystem.Typography.headline)
            
            if !entity.tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: GlassDesignSystem.Spacing.xs) {
                    ForEach(entity.tags, id: \.self) { tag in
                        Text(tag)
                            .font(GlassDesignSystem.Typography.caption)
                            .padding(.horizontal, GlassDesignSystem.Spacing.sm)
                            .padding(.vertical, GlassDesignSystem.Spacing.xs)
                            .background(GlassDesignSystem.Colors.cognitiveAccent.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.sm))
                    }
                }
            } else {
                Text("No tags assigned")
                    .font(GlassDesignSystem.Typography.body)
                    .foregroundColor(.secondary)
            }
        }
        .glassCard()
    }
    
    private var improvementSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Improvement Suggestions")
                .font(GlassDesignSystem.Typography.headline)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                ForEach(entity.improvementSuggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: GlassDesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        
                        Text(suggestion)
                            .font(GlassDesignSystem.Typography.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .glassCard()
    }
    
    private var cognitiveMetricsSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Cognitive Metrics")
                .font(GlassDesignSystem.Typography.headline)
            
            VStack(spacing: GlassDesignSystem.Spacing.md) {
                HStack {
                    CognitiveMetricCard(
                        title: "Consolidation",
                        value: "\(Int(entity.cognitiveConsolidationScore * 100))%",
                        subtitle: "Memory strength",
                        color: GlassDesignSystem.Colors.memoryHighlight
                    )
                    
                    CognitiveMetricCard(
                        title: "Relevance",
                        value: "\(Int(entity.cognitiveRelevanceScore * 100))%",
                        subtitle: "Search relevance",
                        color: GlassDesignSystem.Colors.cognitiveAccent
                    )
                }
                
                CognitiveProgressBar(
                    progress: entity.enhancedEntityScore,
                    color: GlassDesignSystem.Colors.cognitiveAccent
                )
                
                Text("Enhanced entity score: \(Int(entity.enhancedEntityScore * 100))%")
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .glassCard()
    }
    
    private var layerInformationSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Cognitive Layer")
                .font(GlassDesignSystem.Typography.headline)
            
            if let layerType = entity.cognitiveLayerType {
                HStack(spacing: GlassDesignSystem.Spacing.md) {
                    LayerIndicator(layerType: layerType, isActive: true, size: 24)
                    
                    VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.xs) {
                        Text(layerType.displayName)
                            .font(GlassDesignSystem.Typography.subheadline)
                            .foregroundColor(.primary)
                        
                        Text(layerType.description)
                            .font(GlassDesignSystem.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .glassCard()
    }
    
    private var fusionConnectionsSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Fusion Connections")
                .font(GlassDesignSystem.Typography.headline)
            
            Text("\(entity.fusionConnectionIds.count) active fusion connections")
                .font(GlassDesignSystem.Typography.body)
                .foregroundColor(.primary)
            
            // Show fusion IDs (in real app, these would be more meaningful)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: GlassDesignSystem.Spacing.xs) {
                ForEach(entity.fusionConnectionIds.prefix(6), id: \.self) { fusionId in
                    Text(String(fusionId.prefix(8)) + "...")
                        .font(GlassDesignSystem.Typography.caption2)
                        .padding(.horizontal, GlassDesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(GlassDesignSystem.Colors.fusionHighlight.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .glassCard()
    }
    
    private var cognitiveTimelineSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Cognitive Timeline")
                .font(GlassDesignSystem.Typography.headline)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                if let lastSync = entity.lastCognitiveSyncAt {
                    HStack {
                        Text("Last cognitive sync:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastSync, style: .relative)
                    }
                }
                
                if let nodeId = entity.associatedCognitiveNodeId {
                    HStack {
                        Text("Cognitive node ID:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(nodeId.prefix(12)) + "...")
                            .font(.monospaced(GlassDesignSystem.Typography.caption)())
                    }
                }
            }
            .font(GlassDesignSystem.Typography.body)
        }
        .glassCard()
    }
    
    private var noCognitiveRepresentationView: some View {
        VStack(spacing: GlassDesignSystem.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Cognitive Representation")
                .font(GlassDesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            Text("This entity has not been integrated into the cognitive memory system. It would benefit from cognitive synchronization.")
                .font(GlassDesignSystem.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Sync with Cognitive System") {
                // Trigger cognitive sync
                Task {
                    // This would call the cognitive adapter to sync this entity
                    print("🧠 Triggering cognitive sync for entity: \(entity.name)")
                }
            }
            .font(GlassDesignSystem.Typography.body)
            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
        }
        .padding(GlassDesignSystem.Spacing.lg)
        .glassCard()
    }
    
    private var attributesSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Attributes")
                .font(GlassDesignSystem.Typography.headline)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                ForEach(Array(entity.attributes.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key + ":")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(entity.attributes[key] ?? "")
                            .foregroundColor(.primary)
                    }
                }
            }
            .font(GlassDesignSystem.Typography.body)
        }
        .glassCard()
    }
    
    private var technicalMetadataSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Technical Metadata")
                .font(GlassDesignSystem.Typography.headline)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                HStack {
                    Text("Entity ID:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entity.id.uuidString.prefix(8) + "...")
                        .font(.monospaced(GlassDesignSystem.Typography.caption)())
                }
                
                HStack {
                    Text("Entity score:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.3f", entity.entityScore))")
                }
                
                HStack {
                    Text("Salience:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.3f", entity.salience))")
                }
                
                HStack {
                    Text("Validated:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entity.isValidated ? "Yes" : "No")
                        .foregroundColor(entity.isValidated ? .green : .orange)
                }
                
                if let source = entity.extractionSource {
                    HStack {
                        Text("Extraction source:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(source)
                    }
                }
            }
            .font(GlassDesignSystem.Typography.body)
        }
        .glassCard()
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
enum DetailTab: String, CaseIterable {
    case overview = "Overview"
    case cognitive = "Cognitive"
    case connections = "Connections"
    case attributes = "Attributes"
    
    var displayName: String {
        rawValue
    }
    
    var iconName: String {
        switch self {
        case .overview: return "doc.text"
        case .cognitive: return "brain.head.profile"
        case .connections: return "link"
        case .attributes: return "list.bullet"
        }
    }
}

// MARK: - Entity Edit View Placeholder

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct EntityEditView: View {
    let entity: Entity
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Entity editing interface would be implemented here")
                .navigationTitle("Edit \(entity.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview {
    NavigationView {
        CognitiveEntityDetailView(entity: createMockEntity())
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private func createMockEntity() -> Entity {
    let entity = Entity(name: "Apple Inc.", type: .organization)
    entity.entityDescription = "Multinational technology company headquartered in Cupertino, California"
    entity.confidence = 0.95
    entity.importance = 0.88
    entity.mentions = 47
    entity.isValidated = true
    entity.tags = ["Technology", "Innovation", "Consumer Electronics"]
    entity.aliases = ["Apple Computer", "Apple Computer Inc."]
    entity.attributes = [
        "Founded": "1976",
        "Headquarters": "Cupertino, California",
        "Industry": "Technology",
        "CEO": "Tim Cook"
    ]
    
    // Mock cognitive enhancement
    entity.associateWithCognitiveNode("mock-node-id-12345", layer: .semantic)
    entity.updateCognitiveConsolidationScore(0.82)
    entity.updateCognitiveRelevance(0.76)
    entity.addFusionConnection("fusion-1")
    entity.addFusionConnection("fusion-2")
    
    return entity
}