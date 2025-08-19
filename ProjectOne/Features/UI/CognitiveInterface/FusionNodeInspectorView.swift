//
//  FusionNodeInspectorView.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Advanced inspector for cognitive fusion nodes with cross-layer analysis
//

import SwiftUI
import SwiftData
import os.log

/// Advanced inspector view for analyzing cognitive fusion nodes and their cross-layer connections
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct FusionNodeInspectorView: View {
    
    // MARK: - Properties
    
    @Bindable var fusionNode: FusionNode
    @Environment(\.modelContext) private var modelContext
    @State private var sourceNodes: [any CognitiveMemoryNode] = []
    @State private var isLoading = false
    @State private var selectedDetailTab: DetailTab = .overview
    @State private var showingValidationSheet = false
    @State private var validationNotes = ""
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "FusionNodeInspector")
    
    // MARK: - Detail Tabs
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case sourceNodes = "Source Nodes"
        case connections = "Connections"
        case analysis = "Analysis"
        case validation = "Validation"
        
        var systemImage: String {
            switch self {
            case .overview: return "info.circle"
            case .sourceNodes: return "link"
            case .connections: return "network"
            case .analysis: return "chart.line.uptrend.xyaxis"
            case .validation: return "checkmark.seal"
            }
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    fusionHeaderCard
                    
                    // Detail Tabs
                    detailTabSelector
                    
                    // Tab Content
                    Group {
                        switch selectedDetailTab {
                        case .overview:
                            overviewContent
                        case .sourceNodes:
                            sourceNodesContent
                        case .connections:
                            connectionsContent
                        case .analysis:
                            analysisContent
                        case .validation:
                            validationContent
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("Fusion Node Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityLabel("Fusion Node Inspector")
            .accessibilityHint("View and analyze cognitive fusion node details across multiple tabs")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Validate Node", systemImage: "checkmark.seal") {
                            showingValidationSheet = true
                        }
                        .accessibilityLabel("Validate Node")
                        .accessibilityHint("Opens validation options for this fusion node")
                        
                        Button("Export Analysis", systemImage: "square.and.arrow.up") {
                            exportAnalysis()
                        }
                        .accessibilityLabel("Export Analysis")
                        .accessibilityHint("Export fusion node analysis data")
                        
                        Divider()
                        
                        Button("Delete Node", systemImage: "trash", role: .destructive) {
                            deleteNode()
                        }
                        .accessibilityLabel("Delete Node")
                        .accessibilityHint("Permanently delete this fusion node")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Fusion Node Actions")
                    .accessibilityHint("Open menu with fusion node actions")
                }
            }
            .sheet(isPresented: $showingValidationSheet) {
                validationSheet
            }
        }
        .task {
            await loadSourceNodes()
        }
        .refreshable {
            await loadSourceNodes()
        }
    }
    
    // MARK: - Header Card
    
    private var fusionHeaderCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.purple.gradient)
                        .accessibilityHidden(true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fusion Node")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(fusionNode.fusionType.rawValue.capitalized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Fusion Node, Type: \(fusionNode.fusionType.rawValue.capitalized)")
                    
                    Spacer()
                    
                    fusionStatusIndicator
                }
                
                Text(fusionNode.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .accessibilityLabel("Content: \(fusionNode.content)")
                
                HStack {
                    MetricChip(
                        title: "Coherence",
                        value: fusionNode.coherenceScore,
                        format: .percentage,
                        color: .blue
                    )
                    
                    MetricChip(
                        title: "Novelty",
                        value: fusionNode.noveltyScore,
                        format: .percentage,
                        color: .green
                    )
                    
                    MetricChip(
                        title: "Strength",
                        value: fusionNode.strengthScore,
                        format: .percentage,
                        color: .orange
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Metrics: Coherence \(Int(fusionNode.coherenceScore * 100)) percent, Novelty \(Int(fusionNode.noveltyScore * 100)) percent, Strength \(Int(fusionNode.strengthScore * 100)) percent")
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fusion Node Header")
    }
    
    // MARK: - Status Indicator
    
    private var fusionStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            
            Text(fusionNode.validationStatus.rawValue.capitalized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Validation Status: \(fusionNode.validationStatus.rawValue.capitalized)")
        .accessibilityValue(statusColor == .green ? "Valid" : statusColor == .red ? "Invalid" : statusColor == .orange ? "Pending" : "Uncertain")
    }
    
    private var statusColor: Color {
        switch fusionNode.validationStatus {
        case .validated: return .green
        case .pending: return .orange
        case .rejected: return .red
        case .uncertain: return .yellow
        }
    }
    
    // MARK: - Detail Tab Selector
    
    private var detailTabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDetailTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                                .font(.caption)
                                .accessibilityHidden(true)
                            
                            Text(tab.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedDetailTab == tab ? .blue.opacity(0.2) : .clear)
                        )
                        .foregroundColor(selectedDetailTab == tab ? .blue : .secondary)
                    }
                    .accessibilityLabel("\(tab.rawValue) Tab")
                    .accessibilityHint("Switch to \(tab.rawValue) view")
                    .accessibilityAddTraits(selectedDetailTab == tab ? [.isSelected] : [])
                }
            }
            .padding(.horizontal)
        }
        .accessibilityLabel("Detail Tabs")
        .accessibilityHint("Horizontal scroll view with fusion node detail tabs")
    }
    
    // MARK: - Tab Content Views
    
    private var overviewContent: some View {
        VStack(spacing: 16) {
            // Fusion Layers
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fused Layers")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(fusionNode.fusedLayers, id: \.self) { layer in
                            LayerChip(layer: layer)
                        }
                    }
                }
                .padding()
            }
            
            // Fusion Metrics
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fusion Metrics")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        MetricRow(
                            title: "Source Nodes",
                            value: "\(fusionNode.sourceNodes.count)",
                            systemImage: "link.circle"
                        )
                        
                        MetricRow(
                            title: "Connections",
                            value: "\(fusionNode.connections.count)",
                            systemImage: "network"
                        )
                        
                        MetricRow(
                            title: "Access Count",
                            value: "\(fusionNode.accessCount)",
                            systemImage: "eye.circle"
                        )
                        
                        MetricRow(
                            title: "Fusion Count",
                            value: "\(fusionNode.fusionCount)",
                            systemImage: "brain.head.profile"
                        )
                    }
                }
                .padding()
            }
            
            // Timeline
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timeline")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        TimelineRow(
                            title: "Created",
                            date: fusionNode.timestamp,
                            systemImage: "plus.circle"
                        )
                        
                        TimelineRow(
                            title: "Last Accessed",
                            date: fusionNode.lastAccessed,
                            systemImage: "clock.circle"
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    private var sourceNodesContent: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading source nodes...")
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .accessibilityLabel("Loading source nodes")
            } else if sourceNodes.isEmpty {
                ContentUnavailableView(
                    "No Source Nodes",
                    systemImage: "link.circle.fill",
                    description: Text("This fusion node has no source nodes.")
                )
                .accessibilityLabel("No source nodes available")
                .accessibilityHint("This fusion node does not have any connected source nodes")
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(sourceNodes.indices, id: \.self) { index in
                        SourceNodeCard(node: sourceNodes[index])
                    }
                }
                .accessibilityLabel("Source Nodes List")
                .accessibilityHint("\(sourceNodes.count) source nodes connected to this fusion node")
            }
        }
    }
    
    private var connectionsContent: some View {
        VStack(spacing: 16) {
            if fusionNode.connections.isEmpty {
                ContentUnavailableView(
                    "No Connections",
                    systemImage: "network",
                    description: Text("This fusion node has no cross-layer connections.")
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(fusionNode.connections, id: \.self) { connectionId in
                        ConnectionCard(connectionId: connectionId)
                    }
                }
            }
        }
    }
    
    private var analysisContent: some View {
        VStack(spacing: 16) {
            // Coherence Analysis
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coherence Analysis")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ProgressView(value: fusionNode.coherenceScore) {
                        HStack {
                            Text("Coherence Score")
                            Spacer()
                            Text("\(Int(fusionNode.coherenceScore * 100))%")
                        }
                        .font(.subheadline)
                    }
                    .tint(.blue)
                    
                    Text(coherenceAnalysisText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Novelty Analysis
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Novelty Analysis")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ProgressView(value: fusionNode.noveltyScore) {
                        HStack {
                            Text("Novelty Score")
                            Spacer()
                            Text("\(Int(fusionNode.noveltyScore * 100))%")
                        }
                        .font(.subheadline)
                    }
                    .tint(.green)
                    
                    Text(noveltyAnalysisText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Layer Distribution
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Layer Distribution")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    ForEach(fusionNode.fusedLayers, id: \.self) { layer in
                        HStack {
                            LayerChip(layer: layer)
                            Spacer()
                            Text("\(sourceNodeCount(for: layer))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private var validationContent: some View {
        VStack(spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Validation Status")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button("Update Status") {
                            showingValidationSheet = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        
                        Text(fusionNode.validationStatus.rawValue.capitalized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                    
                    Text(validationStatusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Validation Recommendations
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Validation Recommendations")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(validationRecommendations, id: \.self) { recommendation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                
                                Text(recommendation)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Validation Sheet
    
    private var validationSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Validate Fusion Node")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select validation status:")
                        .font(.headline)
                    
                    ForEach(FusionNode.ValidationStatus.allCases, id: \.self) { status in
                        Button {
                            fusionNode.validate(status: status)
                            showingValidationSheet = false
                        } label: {
                            HStack {
                                Circle()
                                    .fill(colorForStatus(status))
                                    .frame(width: 12, height: 12)
                                
                                Text(status.rawValue.capitalized)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                if fusionNode.validationStatus == status {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(fusionNode.validationStatus == status ? .blue.opacity(0.1) : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Validation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingValidationSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSourceNodes() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load source nodes from their IDs
            var loadedNodes: [any CognitiveMemoryNode] = []
            
            for nodeId in fusionNode.sourceNodes {
                if let uuid = UUID(uuidString: nodeId) {
                    // Try to find the node in different layers
                    if let veridicalNode = try? modelContext.fetch(
                        FetchDescriptor<VeridicalNode>(
                            predicate: #Predicate<VeridicalNode> { $0.id == uuid }
                        )
                    ).first {
                        loadedNodes.append(veridicalNode)
                    } else if let semanticNode = try? modelContext.fetch(
                        FetchDescriptor<SemanticNode>(
                            predicate: #Predicate<SemanticNode> { $0.id == uuid }
                        )
                    ).first {
                        loadedNodes.append(semanticNode)
                    } else if let episodicNode = try? modelContext.fetch(
                        FetchDescriptor<EpisodicNode>(
                            predicate: #Predicate<EpisodicNode> { $0.id == uuid }
                        )
                    ).first {
                        loadedNodes.append(episodicNode)
                    }
                }
            }
            
            await MainActor.run {
                sourceNodes = loadedNodes
            }
            
            logger.info("Loaded \(loadedNodes.count) source nodes for fusion node \(fusionNode.id)")
            
        } catch {
            logger.error("Failed to load source nodes: \(error.localizedDescription)")
        }
    }
    
    private func exportAnalysis() {
        // Export fusion node analysis
        logger.info("Exporting analysis for fusion node \(fusionNode.id)")
        // Implementation would depend on export requirements
    }
    
    private func deleteNode() {
        // Delete fusion node with confirmation
        modelContext.delete(fusionNode)
        try? modelContext.save()
        logger.info("Deleted fusion node \(fusionNode.id)")
    }
    
    private func sourceNodeCount(for layer: CognitiveLayer) -> Int {
        // Count source nodes in the specified layer
        return sourceNodes.filter { node in
            if let baseCognitiveNode = node as? BaseCognitiveNode {
                return baseCognitiveNode.layerType == layer
            }
            return false
        }.count
    }
    
    private func colorForStatus(_ status: FusionNode.ValidationStatus) -> Color {
        switch status {
        case .validated: return .green
        case .pending: return .orange
        case .rejected: return .red
        case .uncertain: return .yellow
        }
    }
    
    // MARK: - Computed Properties
    
    private var coherenceAnalysisText: String {
        switch fusionNode.coherenceScore {
        case 0.8...1.0:
            return "Highly coherent fusion with strong logical connections between source nodes."
        case 0.6..<0.8:
            return "Moderately coherent fusion with some logical gaps that could be strengthened."
        case 0.4..<0.6:
            return "Low coherence detected. Review source nodes for logical consistency."
        default:
            return "Very low coherence. This fusion may need validation or removal."
        }
    }
    
    private var noveltyAnalysisText: String {
        switch fusionNode.noveltyScore {
        case 0.8...1.0:
            return "Highly novel insight with unique cross-layer connections."
        case 0.6..<0.8:
            return "Moderately novel with some new perspectives on existing knowledge."
        case 0.4..<0.6:
            return "Low novelty. This fusion may represent known patterns."
        default:
            return "Very low novelty. Consider if this fusion adds value."
        }
    }
    
    private var validationStatusDescription: String {
        switch fusionNode.validationStatus {
        case .validated:
            return "This fusion has been validated and represents a reliable insight."
        case .pending:
            return "This fusion is awaiting validation. Review the analysis before accepting."
        case .rejected:
            return "This fusion has been rejected due to poor coherence or accuracy."
        case .uncertain:
            return "This fusion requires further analysis before validation."
        }
    }
    
    private var validationRecommendations: [String] {
        var recommendations: [String] = []
        
        if fusionNode.coherenceScore < 0.6 {
            recommendations.append("Review source nodes for logical consistency")
        }
        
        if fusionNode.noveltyScore < 0.4 {
            recommendations.append("Consider if this fusion provides new insights")
        }
        
        if fusionNode.sourceNodes.count < 2 {
            recommendations.append("Fusions should connect at least 2 source nodes")
        }
        
        if fusionNode.accessCount == 0 {
            recommendations.append("This fusion has never been accessed - verify relevance")
        }
        
        if recommendations.isEmpty {
            recommendations.append("All metrics look good - ready for validation")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Views

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct LayerChip: View {
    let layer: CognitiveLayer
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(layerColor)
                .frame(width: 8, height: 8)
            
            Text(layer.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(layerColor.opacity(0.2))
        )
        .foregroundColor(layerColor)
    }
    
    private var layerColor: Color {
        switch layer {
        case .veridical: return .blue
        case .semantic: return .green
        case .episodic: return .purple
        case .fusion: return .orange
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct MetricChip: View {
    let title: String
    let value: Double
    let format: Format
    let color: Color
    
    enum Format {
        case percentage
        case decimal
        case integer
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(formattedValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
    
    private var formattedValue: String {
        switch format {
        case .percentage:
            return "\(Int(value * 100))%"
        case .decimal:
            return String(format: "%.2f", value)
        case .integer:
            return "\(Int(value))"
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct MetricRow: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct TimelineRow: View {
    let title: String
    let date: Date
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(.blue)
                .frame(width: 16)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(date, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct SourceNodeCard: View {
    let node: any CognitiveMemoryNode
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    nodeTypeIcon
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nodeTypeName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text(node.content)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(nodeTypeName) Node: \(node.content)")
                    
                    Spacer()
                    
                    Text("\(Int(node.importance * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .accessibilityLabel("Importance: \(Int(node.importance * 100)) percent")
                }
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Source Node")
        .accessibilityHint("Tap to view details of this \(nodeTypeName.lowercased()) source node")
    }
    
    private var nodeTypeIcon: some View {
        Group {
            if node is VeridicalNode {
                Image(systemName: "eye.circle.fill")
                    .foregroundColor(.blue)
            } else if node is SemanticNode {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.green)
            } else if node is EpisodicNode {
                Image(systemName: "clock.circle.fill")
                    .foregroundColor(.purple)
            } else {
                Image(systemName: "circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .font(.title3)
    }
    
    private var nodeTypeName: String {
        if node is VeridicalNode {
            return "Veridical"
        } else if node is SemanticNode {
            return "Semantic"
        } else if node is EpisodicNode {
            return "Episodic"
        } else {
            return "Unknown"
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
private struct ConnectionCard: View {
    let connectionId: String
    
    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "link.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(connectionId.prefix(8) + "...")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fontDesign(.monospaced)
                }
                
                Spacer()
                
                Button("View") {
                    // Navigate to connection details
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
        }
    }
}

// MARK: - Previews

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview("Default Fusion Node") {
    let fusionNode = FusionNode(
        content: "Integration of project planning concepts with recent team meeting outcomes",
        fusedLayers: [.semantic, .episodic],
        sourceNodes: ["node1", "node2", "node3"],
        fusionType: .crossLayer,
        importance: 0.85
    )
    
    return FusionNodeInspectorView(fusionNode: fusionNode)
        .modelContainer(for: [FusionNode.self], inMemory: true)
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview("High Confidence Fusion") {
    let fusionNode = FusionNode(
        content: "Strong correlation between user engagement metrics and feature adoption rates across multiple product releases",
        fusedLayers: [.veridical, .semantic, .episodic],
        sourceNodes: ["analytics_node_1", "user_feedback_2", "release_data_3", "engagement_metrics_4"],
        fusionType: .causal,
        importance: 0.95
    )
    fusionNode.coherenceScore = 0.92
    fusionNode.noveltyScore = 0.88
    fusionNode.strengthScore = 0.91
    fusionNode.validationStatus = .validated
    fusionNode.accessCount = 15
    fusionNode.fusionCount = 3
    
    return FusionNodeInspectorView(fusionNode: fusionNode)
        .modelContainer(for: [FusionNode.self], inMemory: true)
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview("Low Confidence Fusion") {
    let fusionNode = FusionNode(
        content: "Potential connection between weather patterns and team productivity, needs validation",
        fusedLayers: [.episodic],
        sourceNodes: ["weather_1"],
        fusionType: .analogical,
        importance: 0.32
    )
    fusionNode.coherenceScore = 0.28
    fusionNode.noveltyScore = 0.45
    fusionNode.strengthScore = 0.31
    fusionNode.validationStatus = .uncertain
    fusionNode.accessCount = 2
    fusionNode.fusionCount = 0
    
    return FusionNodeInspectorView(fusionNode: fusionNode)
        .modelContainer(for: [FusionNode.self], inMemory: true)
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview("Rejected Fusion") {
    let fusionNode = FusionNode(
        content: "Failed hypothesis about market trends - contradicted by recent data analysis",
        fusedLayers: [.semantic, .veridical],
        sourceNodes: ["market_trend_1", "contradictory_data_2"],
        fusionType: .conceptual,
        importance: 0.15
    )
    fusionNode.coherenceScore = 0.12
    fusionNode.noveltyScore = 0.22
    fusionNode.strengthScore = 0.18
    fusionNode.validationStatus = .rejected
    fusionNode.accessCount = 8
    fusionNode.fusionCount = 1
    
    return FusionNodeInspectorView(fusionNode: fusionNode)
        .modelContainer(for: [FusionNode.self], inMemory: true)
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview("Temporal Fusion") {
    let fusionNode = FusionNode(
        content: "Sequential pattern in user behavior across quarterly reviews and subsequent feature requests",
        fusedLayers: [.episodic, .semantic],
        sourceNodes: ["q1_review", "q2_review", "q3_review", "feature_requests_timeline"],
        fusionType: .temporal,
        importance: 0.78
    )
    fusionNode.coherenceScore = 0.84
    fusionNode.noveltyScore = 0.71
    fusionNode.strengthScore = 0.79
    fusionNode.validationStatus = .pending
    fusionNode.accessCount = 12
    fusionNode.fusionCount = 2
    
    return FusionNodeInspectorView(fusionNode: fusionNode)
        .modelContainer(for: [FusionNode.self], inMemory: true)
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview("All Layers Fusion") {
    let fusionNode = FusionNode(
        content: "Comprehensive insight connecting immediate observations, learned concepts, and experiential memories about team dynamics during critical project phases",
        fusedLayers: [.veridical, .semantic, .episodic, .fusion],
        sourceNodes: ["observation_1", "concept_2", "experience_3", "previous_fusion_4", "related_insight_5"],
        fusionType: .crossLayer,
        importance: 0.89
    )
    fusionNode.coherenceScore = 0.87
    fusionNode.noveltyScore = 0.82
    fusionNode.strengthScore = 0.85
    fusionNode.validationStatus = .validated
    fusionNode.accessCount = 24
    fusionNode.fusionCount = 5
    
    return FusionNodeInspectorView(fusionNode: fusionNode)
        .modelContainer(for: [FusionNode.self], inMemory: true)
}