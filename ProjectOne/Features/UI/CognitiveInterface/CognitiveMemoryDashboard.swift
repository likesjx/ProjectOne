//
//  CognitiveMemoryDashboard.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Real-time cognitive memory monitoring dashboard with Glass design
//

import SwiftUI
import Charts

// MARK: - Cognitive Memory Dashboard

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveMemoryDashboard: View {
    @StateObject private var viewModel: CognitiveMemoryDashboardViewModel
    @State private var selectedLayer: CognitiveLayerType?
    @State private var isExpanded = true
    @Environment(\.colorScheme) private var colorScheme
    
    public init(cognitiveSystem: CognitiveMemorySystem) {
        self._viewModel = StateObject(wrappedValue: CognitiveMemoryDashboardViewModel(cognitiveSystem: cognitiveSystem))
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: GlassDesignSystem.Spacing.lg) {
                    // Status Overview
                    statusOverviewSection
                    
                    // Layer Metrics
                    layerMetricsSection
                    
                    // Control Loop Status
                    controlLoopSection
                    
                    // Memory Activity Chart
                    memoryActivitySection
                    
                    // Recent Fusion Activity
                    fusionActivitySection
                }
                .padding(GlassDesignSystem.Spacing.md)
            }
            .navigationTitle("Cognitive Memory")
            .navigationBarTitleDisplayMode(.large)
            .background {
                // Glass background with subtle gradient
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
                    Menu {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            Task {
                                await viewModel.refreshData()
                            }
                        }
                        
                        Button("Settings", systemImage: "gearshape") {
                            // Settings action
                        }
                        
                        if viewModel.isAppleIntelligenceEnabled {
                            Button("AI Insights", systemImage: "brain") {
                                viewModel.generateAIInsights()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
                    }
                }
            }
        }
        .task {
            await viewModel.startRealTimeMonitoring()
        }
    }
    
    // MARK: - Status Overview Section
    
    private var statusOverviewSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            HStack {
                Text("System Status")
                    .font(GlassDesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                CognitiveStatusBadge(status: viewModel.systemStatus)
            }
            
            HStack(spacing: GlassDesignSystem.Spacing.md) {
                CognitiveMetricCard(
                    title: "Total Nodes",
                    value: "\(viewModel.totalNodes)",
                    subtitle: "Across all layers",
                    color: GlassDesignSystem.Colors.cognitiveAccent
                )
                
                CognitiveMetricCard(
                    title: "Active Fusions",
                    value: "\(viewModel.activeFusions)",
                    subtitle: "Cross-layer connections",
                    color: GlassDesignSystem.Colors.fusionHighlight,
                    isActive: viewModel.activeFusions > 0
                )
                
                CognitiveMetricCard(
                    title: "Consolidation",
                    value: "\(Int(viewModel.consolidationScore * 100))%",
                    subtitle: "Memory strength",
                    color: GlassDesignSystem.Colors.memoryHighlight,
                    isActive: viewModel.consolidationScore > 0.7
                )
            }
        }
        .glassCard(material: GlassDesignSystem.Materials.regular, cornerRadius: GlassDesignSystem.CornerRadius.dashboard)
    }
    
    // MARK: - Layer Metrics Section
    
    private var layerMetricsSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Memory Layers")
                .font(GlassDesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: GlassDesignSystem.Spacing.sm), count: 2), spacing: GlassDesignSystem.Spacing.md) {
                ForEach(CognitiveLayerType.allCases.filter { $0 != .fusion }, id: \.self) { layer in
                    layerMetricCard(for: layer)
                }
            }
            
            // Fusion layer gets special treatment
            fusionLayerCard
        }
        .glassCard(material: GlassDesignSystem.Materials.regular, cornerRadius: GlassDesignSystem.CornerRadius.dashboard)
    }
    
    private func layerMetricCard(for layer: CognitiveLayerType) -> some View {
        let metrics = viewModel.layerMetrics[layer] ?? LayerMetrics.empty
        
        return VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
            HStack {
                LayerIndicator(layerType: layer, isActive: metrics.isActive, size: 16)
                
                Text(layer.displayName)
                    .font(GlassDesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.xs) {
                HStack {
                    Text("Nodes")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(metrics.nodeCount)")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Avg Quality")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(metrics.averageQuality * 100))%")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                }
                
                CognitiveProgressBar(
                    progress: metrics.averageQuality,
                    color: layerColor(for: layer),
                    height: 3
                )
            }
        }
        .padding(GlassDesignSystem.Spacing.md)
        .memoryLayerStyle(layer, isActive: metrics.isActive)
        .onTapGesture {
            selectedLayer = layer
        }
    }
    
    private var fusionLayerCard: some View {
        let fusionMetrics = viewModel.layerMetrics[.fusion] ?? LayerMetrics.empty
        
        return HStack(spacing: GlassDesignSystem.Spacing.md) {
            LayerIndicator(layerType: .fusion, isActive: fusionMetrics.isActive, size: 20)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.xs) {
                Text("Fusion Layer")
                    .font(GlassDesignSystem.Typography.subheadline)
                    .foregroundColor(.primary)
                
                Text("\(fusionMetrics.nodeCount) fusion connections active")
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: GlassDesignSystem.Spacing.xs) {
                Text("\(Int(fusionMetrics.averageQuality * 100))%")
                    .font(GlassDesignSystem.Typography.metricValue)
                    .foregroundColor(.primary)
                
                Text("Quality")
                    .font(GlassDesignSystem.Typography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(GlassDesignSystem.Spacing.md)
        .memoryLayerStyle(.fusion, isActive: fusionMetrics.isActive)
    }
    
    // MARK: - Control Loop Section
    
    private var controlLoopSection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Control Loop")
                .font(GlassDesignSystem.Typography.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: GlassDesignSystem.Spacing.md) {
                ForEach(viewModel.controlLoopPhases, id: \.phase) { phaseStatus in
                    controlLoopPhaseCard(phaseStatus)
                }
            }
        }
        .glassCard(material: GlassDesignSystem.Materials.regular, cornerRadius: GlassDesignSystem.CornerRadius.dashboard)
    }
    
    private func controlLoopPhaseCard(_ phaseStatus: ControlLoopPhaseStatus) -> some View {
        VStack(spacing: GlassDesignSystem.Spacing.xs) {
            Image(systemName: phaseStatus.iconName)
                .font(.title2)
                .foregroundColor(phaseStatus.isActive ? phaseStatus.color : .secondary)
                .modifier(CognitiveGlow(color: phaseStatus.color, isActive: phaseStatus.isActive))
            
            Text(phaseStatus.phase.displayName)
                .font(GlassDesignSystem.Typography.caption)
                .foregroundColor(phaseStatus.isActive ? .primary : .secondary)
                .multilineTextAlignment(.center)
            
            if phaseStatus.isActive {
                CognitiveProgressBar(
                    progress: phaseStatus.progress,
                    color: phaseStatus.color,
                    height: 2
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(GlassDesignSystem.Spacing.sm)
        .background {
            if phaseStatus.isActive {
                phaseStatus.color.opacity(0.1)
            } else {
                Color.clear
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.sm)
                .stroke(
                    phaseStatus.isActive ? phaseStatus.color.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.sm))
        .animation(GlassDesignSystem.Animations.standard, value: phaseStatus.isActive)
    }
    
    // MARK: - Memory Activity Chart
    
    private var memoryActivitySection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            HStack {
                Text("Memory Activity")
                    .font(GlassDesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName)
                            .tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            Chart {
                ForEach(viewModel.activityData) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Activity", dataPoint.value)
                    )
                    .foregroundStyle(by: .value("Layer", dataPoint.layer.displayName))
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartForegroundStyleScale(range: layerColorScale)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(position: .bottom) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
        .glassCard(material: GlassDesignSystem.Materials.regular, cornerRadius: GlassDesignSystem.CornerRadius.dashboard)
    }
    
    // MARK: - Recent Fusion Activity
    
    private var fusionActivitySection: some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            HStack {
                Text("Recent Fusions")
                    .font(GlassDesignSystem.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to full fusion list
                }
                .font(GlassDesignSystem.Typography.caption)
                .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
            }
            
            LazyVStack(spacing: GlassDesignSystem.Spacing.sm) {
                ForEach(viewModel.recentFusions.prefix(5), id: \.id) { fusion in
                    recentFusionCard(fusion)
                }
                
                if viewModel.recentFusions.isEmpty {
                    Text("No recent fusion activity")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
        }
        .glassCard(material: GlassDesignSystem.Materials.regular, cornerRadius: GlassDesignSystem.CornerRadius.dashboard)
    }
    
    private func recentFusionCard(_ fusion: RecentFusionActivity) -> some View {
        HStack(spacing: GlassDesignSystem.Spacing.md) {
            VStack(spacing: GlassDesignSystem.Spacing.xs) {
                ForEach(fusion.sourceLayers, id: \.self) { layer in
                    LayerIndicator(layerType: layer, size: 8)
                }
            }
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.xs) {
                Text(fusion.description)
                    .font(GlassDesignSystem.Typography.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    Text(fusion.timestamp, style: .relative)
                        .font(GlassDesignSystem.Typography.caption2)
                        .foregroundColor(.tertiary)
                    
                    Spacer()
                    
                    Text("Quality: \(Int(fusion.quality * 100))%")
                        .font(GlassDesignSystem.Typography.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.triangle.merge")
                .font(.caption)
                .foregroundColor(GlassDesignSystem.Colors.fusionHighlight)
                .modifier(CognitiveGlow(color: GlassDesignSystem.Colors.fusionHighlight, radius: 1))
        }
        .padding(GlassDesignSystem.Spacing.sm)
        .background(GlassDesignSystem.Materials.ultraThin, in: RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.sm))
    }
    
    // MARK: - Helper Methods
    
    private func layerColor(for layer: CognitiveLayerType) -> Color {
        switch layer {
        case .veridical: return .blue
        case .semantic: return .purple
        case .episodic: return .green
        case .fusion: return .orange
        }
    }
    
    private var layerColorScale: [Color] {
        [
            layerColor(for: .veridical),
            layerColor(for: .semantic),
            layerColor(for: .episodic),
            layerColor(for: .fusion)
        ]
    }
}

// MARK: - Supporting Types

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct LayerMetrics {
    let nodeCount: Int
    let averageQuality: Double
    let isActive: Bool
    
    static let empty = LayerMetrics(nodeCount: 0, averageQuality: 0, isActive: false)
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct ControlLoopPhaseStatus {
    let phase: ControlLoopPhase
    let isActive: Bool
    let progress: Double
    
    var iconName: String {
        switch phase {
        case .reason: return "brain"
        case .probe: return "magnifyingglass"
        case .retrieve: return "tray.and.arrow.down"
        case .consolidate: return "gearshape.2"
        case .resolve: return "checkmark.circle"
        }
    }
    
    var color: Color {
        switch phase {
        case .reason: return .cyan
        case .probe: return .blue
        case .retrieve: return .purple
        case .consolidate: return .orange
        case .resolve: return .green
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum ControlLoopPhase: String, CaseIterable {
    case reason = "Reason"
    case probe = "Probe"
    case retrieve = "Retrieve"
    case consolidate = "Consolidate"
    case resolve = "Resolve"
    
    var displayName: String {
        rawValue
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct ActivityDataPoint: Identifiable {
    public let id = UUID()
    let timestamp: Date
    let value: Double
    let layer: CognitiveLayerType
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct RecentFusionActivity: Identifiable {
    public let id = UUID()
    let description: String
    let timestamp: Date
    let quality: Double
    let sourceLayers: [CognitiveLayerType]
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public enum TimeRange: String, CaseIterable {
    case hour = "1H"
    case day = "1D"
    case week = "1W"
    case month = "1M"
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview {
    // Mock cognitive system for preview
    let mockContext = try! ModelContext(ModelContainer(for: Schema([]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
    let mockCognitiveSystem = CognitiveMemorySystem(modelContext: mockContext)
    
    return CognitiveMemoryDashboard(cognitiveSystem: mockCognitiveSystem)
}