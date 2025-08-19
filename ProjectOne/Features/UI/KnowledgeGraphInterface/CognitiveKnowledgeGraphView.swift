//
//  CognitiveKnowledgeGraphView.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Enhanced Knowledge Graph visualization with cognitive overlays and Glass design
//

import SwiftUI
import Charts

// MARK: - Cognitive Knowledge Graph View

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveKnowledgeGraphView: View {
    @StateObject private var viewModel: CognitiveKnowledgeGraphViewModel
    @State private var selectedEntity: Entity?
    @State private var selectedLayout: GraphLayout = .force
    @State private var showCognitiveOverlay = true
    @State private var showFilters = false
    @State private var dragOffset = CGSize.zero
    @Environment(\.colorScheme) private var colorScheme
    
    public init(knowledgeGraphService: KnowledgeGraphService) {
        self._viewModel = StateObject(wrappedValue: CognitiveKnowledgeGraphViewModel(knowledgeGraphService: knowledgeGraphService))
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                backgroundGradient
                
                GeometryReader { geometry in
                    ZStack {
                        // Main graph canvas
                        graphCanvas(geometry: geometry)
                        
                        // Cognitive overlays
                        if showCognitiveOverlay {
                            cognitiveOverlays(geometry: geometry)
                        }
                        
                        // Interactive elements
                        interactionOverlays(geometry: geometry)
                    }
                }
                
                // Floating controls
                VStack {
                    HStack {
                        layoutControls
                        Spacer()
                        cognitiveControls
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Bottom status bar
                    if viewModel.isLoading || viewModel.cognitiveInsights != nil {
                        bottomStatusBar
                    }
                }
            }
            .navigationTitle("Knowledge Graph")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    cognitiveStatusIndicator
                    
                    Button("Filters", systemImage: "line.3.horizontal.decrease.circle") {
                        showFilters.toggle()
                    }
                    .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
                }
            }
            .sheet(isPresented: $showFilters) {
                filtersSheet
            }
            .sheet(item: $selectedEntity) { entity in
                entityDetailSheet(entity)
            }
        }
        .task {
            await viewModel.loadData()
        }
        .onReceive(viewModel.$selectedLayout) { layout in
            selectedLayout = layout
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                GlassDesignSystem.Colors.primaryGlass,
                GlassDesignSystem.Colors.secondaryGlass,
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Graph Canvas
    
    private func graphCanvas(geometry: GeometryProxy) -> some View {
        ZStack {
            // Connection lines
            ForEach(viewModel.visibleRelationships, id: \.id) { relationship in
                relationshipLine(relationship, in: geometry)
            }
            
            // Entity nodes
            ForEach(viewModel.visibleEntities, id: \.id) { entity in
                entityNode(entity, in: geometry)
                    .onTapGesture {
                        selectedEntity = entity
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                viewModel.updateEntityPosition(entity.id, offset: value.translation, in: geometry.size)
                            }
                            .onEnded { _ in
                                viewModel.finalizeEntityPosition(entity.id)
                            }
                    )
            }
        }
        .onAppear {
            viewModel.setCanvasSize(geometry.size)
        }
        .onChange(of: geometry.size) { oldSize, newSize in
            viewModel.setCanvasSize(newSize)
        }
    }
    
    private func relationshipLine(_ relationship: Relationship, in geometry: GeometryProxy) -> some View {
        Path { path in
            guard let startPos = viewModel.getEntityPosition(relationship.subjectEntityId, in: geometry.size),
                  let endPos = viewModel.getEntityPosition(relationship.objectEntityId, in: geometry.size) else {
                return
            }
            
            path.move(to: startPos)
            path.addLine(to: endPos)
        }
        .stroke(
            relationshipColor(relationship).opacity(0.6),
            lineWidth: relationshipLineWidth(relationship)
        )
        .modifier(CognitiveGlow(
            color: relationshipColor(relationship),
            radius: 1,
            isActive: relationship.importance > 0.7
        ))
    }
    
    private func relationshipColor(_ relationship: Relationship) -> Color {
        if relationship.importance > 0.8 {
            return GlassDesignSystem.Colors.fusionHighlight
        } else if relationship.confidence > 0.7 {
            return GlassDesignSystem.Colors.memoryHighlight
        } else {
            return .primary
        }
    }
    
    private func relationshipLineWidth(_ relationship: Relationship) -> CGFloat {
        return 1.5 + (relationship.importance * 2.5)
    }
    
    private func entityNode(_ entity: Entity, in geometry: GeometryProxy) -> some View {
        Group {
            if let position = viewModel.getEntityPosition(entity.id, in: geometry.size) {
                ZStack {
                    // Node background with cognitive enhancement
                    Circle()
                        .fill(nodeBackgroundColor(entity))
                        .frame(width: nodeSize(entity), height: nodeSize(entity))
                    
                    // Cognitive layer indicator ring
                    if entity.hasCognitiveRepresentation {
                        Circle()
                            .stroke(cognitiveLayerColor(entity), lineWidth: 2)
                            .frame(width: nodeSize(entity) + 4, height: nodeSize(entity) + 4)
                            .modifier(CognitiveGlow(
                                color: cognitiveLayerColor(entity),
                                radius: 2,
                                isActive: true
                            ))
                    }
                    
                    // Entity type icon
                    Image(systemName: entity.type.iconName)
                        .font(.system(size: nodeIconSize(entity)))
                        .foregroundColor(.primary)
                    
                    // Fusion connections indicator
                    if !entity.fusionConnectionIds.isEmpty {
                        Circle()
                            .fill(GlassDesignSystem.Colors.fusionHighlight)
                            .frame(width: 8, height: 8)
                            .offset(x: nodeSize(entity) / 2, y: -nodeSize(entity) / 2)
                            .modifier(CognitiveGlow(
                                color: GlassDesignSystem.Colors.fusionHighlight,
                                radius: 1
                            ))
                    }
                }
                .position(position)
                .scaleEffect(selectedEntity?.id == entity.id ? 1.2 : 1.0)
                .animation(GlassDesignSystem.Animations.spring, value: selectedEntity?.id)
            }
        }
    }
    
    private func nodeBackgroundColor(_ entity: Entity) -> Color {
        if entity.hasCognitiveRepresentation {
            // Use cognitive layer color with transparency
            switch entity.cognitiveLayerType {
            case .veridical:
                return GlassDesignSystem.Colors.veridicalGlass
            case .semantic:
                return GlassDesignSystem.Colors.semanticGlass
            case .episodic:
                return GlassDesignSystem.Colors.episodicGlass
            case .fusion:
                return GlassDesignSystem.Colors.fusionGlass
            case nil:
                return Color.secondary.opacity(0.3)
            }
        } else {
            return Color.secondary.opacity(0.3)
        }
    }
    
    private func cognitiveLayerColor(_ entity: Entity) -> Color {
        switch entity.cognitiveLayerType {
        case .veridical: return .blue
        case .semantic: return .purple
        case .episodic: return .green
        case .fusion: return .orange
        case nil: return .gray
        }
    }
    
    private func nodeSize(_ entity: Entity) -> CGFloat {
        let baseSize: CGFloat = 30
        let sizeMultiplier = entity.hasCognitiveRepresentation ? entity.enhancedEntityScore : entity.entityScore
        return baseSize + (sizeMultiplier * 20)
    }
    
    private func nodeIconSize(_ entity: Entity) -> CGFloat {
        return nodeSize(entity) * 0.4
    }
    
    // MARK: - Cognitive Overlays
    
    private func cognitiveOverlays(geometry: GeometryProxy) -> some View {
        ZStack {
            // Fusion connection highlights
            fusionConnectionOverlays(geometry: geometry)
            
            // Cognitive strength heatmap
            if viewModel.showCognitiveHeatmap {
                cognitiveHeatmapOverlay(geometry: geometry)
            }
            
            // Layer boundaries
            if viewModel.showLayerBoundaries {
                layerBoundariesOverlay(geometry: geometry)
            }
        }
    }
    
    private func fusionConnectionOverlays(geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(viewModel.fusionConnections, id: \.id) { connection in
                fusionConnectionPath(connection, in: geometry)
            }
        }
    }
    
    private func fusionConnectionPath(_ connection: FusionConnection, in geometry: GeometryProxy) -> some View {
        Path { path in
            let points = connection.entityIds.compactMap { entityId in
                viewModel.getEntityPosition(entityId, in: geometry.size)
            }
            
            guard points.count >= 2 else { return }
            
            // Create curved path connecting fusion nodes
            path.move(to: points[0])
            for i in 1..<points.count {
                let controlPoint = CGPoint(
                    x: (points[i-1].x + points[i].x) / 2,
                    y: (points[i-1].y + points[i].y) / 2 - 20
                )
                path.addQuadCurve(to: points[i], control: controlPoint)
            }
        }
        .stroke(
            GlassDesignSystem.Colors.fusionHighlight,
            style: StrokeStyle(lineWidth: 3, dash: [5, 5])
        )
        .modifier(CognitiveGlow(
            color: GlassDesignSystem.Colors.fusionHighlight,
            radius: 2
        ))
    }
    
    private func cognitiveHeatmapOverlay(geometry: GeometryProxy) -> some View {
        Canvas { context, size in
            // Draw cognitive strength heatmap
            for entity in viewModel.visibleEntities.filter({ $0.hasCognitiveRepresentation }) {
                guard let position = viewModel.getEntityPosition(entity.id, in: size) else { continue }
                
                let radius = CGFloat(entity.cognitiveConsolidationScore * 60)
                let opacity = entity.cognitiveConsolidationScore * 0.3
                
                let gradient = Gradient(colors: [
                    cognitiveLayerColor(entity).opacity(opacity),
                    Color.clear
                ])
                
                let radialGradient = RadialGradient(
                    gradient: gradient,
                    center: UnitPoint(x: position.x / size.width, y: position.y / size.height),
                    startRadius: 0,
                    endRadius: radius
                )
                
                context.fill(
                    Circle().path(in: CGRect(
                        x: position.x - radius,
                        y: position.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .linearGradient(
                        Gradient(colors: [
                            cognitiveLayerColor(entity).opacity(opacity),
                            Color.clear
                        ]),
                        startPoint: position,
                        endPoint: CGPoint(x: position.x + radius, y: position.y + radius)
                    )
                )
            }
        }
    }
    
    private func layerBoundariesOverlay(geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(CognitiveLayerType.allCases.filter { $0 != .fusion }, id: \.self) { layer in
                layerBoundary(layer, in: geometry)
            }
        }
    }
    
    private func layerBoundary(_ layer: CognitiveLayerType, in geometry: GeometryProxy) -> some View {
        let entities = viewModel.visibleEntities.filter { $0.cognitiveLayerType == layer }
        
        return ConvexHullPath(points: entities.compactMap { entity in
            viewModel.getEntityPosition(entity.id, in: geometry.size)
        })
        .stroke(
            cognitiveLayerColor(Entity(name: "", type: .concept)).opacity(0.5),
            style: StrokeStyle(lineWidth: 2, dash: [10, 5])
        )
    }
    
    // MARK: - Interactive Overlays
    
    private func interactionOverlays(geometry: GeometryProxy) -> some View {
        ZStack {
            // Entity labels on hover/selection
            if let selected = selectedEntity,
               let position = viewModel.getEntityPosition(selected.id, in: geometry.size) {
                entityLabel(selected)
                    .position(x: position.x, y: position.y - 40)
            }
        }
    }
    
    private func entityLabel(_ entity: Entity) -> some View {
        VStack(spacing: GlassDesignSystem.Spacing.xs) {
            Text(entity.name)
                .font(GlassDesignSystem.Typography.caption)
                .foregroundColor(.primary)
            
            if entity.hasCognitiveRepresentation {
                HStack(spacing: GlassDesignSystem.Spacing.xs) {
                    LayerIndicator(layerType: entity.cognitiveLayerType!, size: 6)
                    Text("Cognitive: \(Int(entity.cognitiveConsolidationScore * 100))%")
                        .font(GlassDesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(GlassDesignSystem.Spacing.sm)
        .glassCard(material: GlassDesignSystem.Materials.ultraThin)
        .animation(GlassDesignSystem.Animations.quick, value: selectedEntity?.id)
    }
    
    // MARK: - Controls
    
    private var layoutControls: some View {
        HStack(spacing: GlassDesignSystem.Spacing.sm) {
            ForEach(GraphLayout.allCases, id: \.self) { layout in
                Button(layout.displayName) {
                    viewModel.setLayout(layout)
                }
                .font(GlassDesignSystem.Typography.caption)
                .padding(.horizontal, GlassDesignSystem.Spacing.sm)
                .padding(.vertical, GlassDesignSystem.Spacing.xs)
                .background {
                    if selectedLayout == layout {
                        GlassDesignSystem.Colors.cognitiveAccent.opacity(0.3)
                    } else {
                        GlassDesignSystem.Materials.ultraThin
                    }
                }
                .foregroundColor(selectedLayout == layout ? .primary : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.sm))
            }
        }
        .glassCard()
    }
    
    private var cognitiveControls: some View {
        VStack(spacing: GlassDesignSystem.Spacing.xs) {
            Button(action: {
                showCognitiveOverlay.toggle()
            }) {
                Label("Cognitive Overlays", systemImage: "brain.head.profile")
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(showCognitiveOverlay ? GlassDesignSystem.Colors.cognitiveAccent : .secondary)
            }
            
            if showCognitiveOverlay {
                VStack(spacing: GlassDesignSystem.Spacing.xs) {
                    Toggle("Heatmap", isOn: $viewModel.showCognitiveHeatmap)
                        .font(GlassDesignSystem.Typography.caption2)
                    
                    Toggle("Boundaries", isOn: $viewModel.showLayerBoundaries)
                        .font(GlassDesignSystem.Typography.caption2)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(GlassDesignSystem.Spacing.sm)
        .glassCard()
        .animation(GlassDesignSystem.Animations.standard, value: showCognitiveOverlay)
    }
    
    private var cognitiveStatusIndicator: some View {
        HStack(spacing: GlassDesignSystem.Spacing.xs) {
            if viewModel.isCognitiveEnhanced {
                Circle()
                    .fill(GlassDesignSystem.Colors.cognitiveAccent)
                    .frame(width: 8, height: 8)
                    .modifier(CognitiveGlow(color: GlassDesignSystem.Colors.cognitiveAccent))
            }
            
            Text(viewModel.isCognitiveEnhanced ? "Enhanced" : "Traditional")
                .font(GlassDesignSystem.Typography.caption2)
                .foregroundColor(viewModel.isCognitiveEnhanced ? .primary : .secondary)
        }
    }
    
    // MARK: - Bottom Status Bar
    
    private var bottomStatusBar: some View {
        HStack {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading graph...")
                        .font(GlassDesignSystem.Typography.caption)
                }
            }
            
            if let insights = viewModel.cognitiveInsights {
                HStack(spacing: GlassDesignSystem.Spacing.md) {
                    Text("\(insights.cognitivelyEnhancedEntities)/\(insights.totalEntities) cognitive")
                        .font(GlassDesignSystem.Typography.caption)
                    
                    Text("\(insights.fusionConnections) fusions")
                        .font(GlassDesignSystem.Typography.caption)
                    
                    Text("\(Int(insights.averageCognitiveScore * 100))% avg")
                        .font(GlassDesignSystem.Typography.caption)
                }
            }
            
            Spacer()
            
            Text("\(viewModel.visibleEntities.count) entities")
                .font(GlassDesignSystem.Typography.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .glassCard()
        .padding(.horizontal)
    }
    
    // MARK: - Sheets
    
    private var filtersSheet: some View {
        NavigationView {
            GraphFiltersView(viewModel: viewModel)
                .navigationTitle("Graph Filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showFilters = false
                        }
                    }
                }
        }
    }
    
    private func entityDetailSheet(_ entity: Entity) -> some View {
        NavigationView {
            CognitiveEntityDetailView(entity: entity)
                .navigationTitle(entity.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            selectedEntity = nil
                        }
                    }
                }
        }
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct FusionConnection: Identifiable {
    public let id = UUID()
    public let entityIds: [UUID]
    public let strength: Double
    public let fusionNodeId: String
}

// MARK: - Convex Hull Path

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct ConvexHullPath: Shape {
    let points: [CGPoint]
    
    public func path(in rect: CGRect) -> Path {
        guard points.count >= 3 else { return Path() }
        
        let hull = convexHull(points)
        var path = Path()
        
        if let first = hull.first {
            path.move(to: first)
            for point in hull.dropFirst() {
                path.addLine(to: point)
            }
            path.closeSubpath()
        }
        
        return path
    }
    
    private func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        // Graham scan algorithm for convex hull
        let sorted = points.sorted { p1, p2 in
            if p1.x == p2.x {
                return p1.y < p2.y
            }
            return p1.x < p2.x
        }
        
        guard sorted.count >= 3 else { return sorted }
        
        // Build lower hull
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        
        // Build upper hull
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        
        // Remove last point of each half because they repeat
        lower.removeLast()
        upper.removeLast()
        
        return lower + upper
    }
    
    private func cross(_ O: CGPoint, _ A: CGPoint, _ B: CGPoint) -> Double {
        return Double((A.x - O.x) * (B.y - O.y) - (A.y - O.y) * (B.x - O.x))
    }
}

// MARK: - Graph Layout Enum

public enum GraphLayout: String, CaseIterable {
    case force = "Force"
    case circular = "Circular"
    case hierarchical = "Hierarchical"
    case radial = "Radial"
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview {
    let mockContext = try! ModelContext(ModelContainer(for: Schema([]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
    let mockService = KnowledgeGraphService(modelContext: mockContext)
    
    return CognitiveKnowledgeGraphView(knowledgeGraphService: mockService)
}