//
//  CognitiveMemoryDashboardViewModel.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  View model for Cognitive Memory Dashboard with real-time monitoring
//

import SwiftUI
import Combine
import Charts
import Foundation

// MARK: - Cognitive Memory Dashboard ViewModel

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@MainActor
public final class CognitiveMemoryDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var systemStatus: CognitiveStatus = .idle
    @Published public var totalNodes: Int = 0
    @Published public var activeFusions: Int = 0
    @Published public var consolidationScore: Double = 0.0
    
    @Published public var layerMetrics: [CognitiveLayerType: LayerMetrics] = [:]
    @Published public var controlLoopPhases: [ControlLoopPhaseStatus] = []
    @Published public var activityData: [ActivityDataPoint] = []
    @Published public var recentFusions: [RecentFusionActivity] = []
    
    @Published public var selectedTimeRange: TimeRange = .hour
    @Published public var isAppleIntelligenceEnabled: Bool = false
    @Published public var isRealTimeMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private let cognitiveSystem: CognitiveMemorySystem
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var activityHistory: [Date: [CognitiveLayerType: Double]] = [:]
    
    // Real-time update intervals
    private let metricsUpdateInterval: TimeInterval = 2.0
    private let activityUpdateInterval: TimeInterval = 5.0
    private let fusionUpdateInterval: TimeInterval = 3.0
    
    // MARK: - Initialization
    
    public init(cognitiveSystem: CognitiveMemorySystem) {
        self.cognitiveSystem = cognitiveSystem
        
        Task {
            await initializeViewModel()
        }
    }
    
    deinit {
        stopRealTimeMonitoring()
    }
    
    // MARK: - Initialization Methods
    
    private func initializeViewModel() async {
        await loadInitialData()
        setupControlLoopPhases()
        checkAppleIntelligenceAvailability()
        
        // Initialize layer metrics
        for layerType in CognitiveLayerType.allCases {
            layerMetrics[layerType] = LayerMetrics.empty
        }
    }
    
    private func loadInitialData() async {
        do {
            await updateSystemMetrics()
            await updateLayerMetrics()
            await updateActivityData()
            await updateRecentFusions()
        } catch {
            print("❌ [CognitiveMemoryDashboardViewModel] Failed to load initial data: \(error)")
        }
    }
    
    private func setupControlLoopPhases() {
        controlLoopPhases = ControlLoopPhase.allCases.map { phase in
            ControlLoopPhaseStatus(
                phase: phase,
                isActive: false,
                progress: 0.0
            )
        }
    }
    
    private func checkAppleIntelligenceAvailability() {
        // Check if Apple Intelligence is available
        // This would integrate with Apple Intelligence framework when available
        isAppleIntelligenceEnabled = false
    }
    
    // MARK: - Real-Time Monitoring
    
    public func startRealTimeMonitoring() async {
        guard !isRealTimeMonitoring else { return }
        
        isRealTimeMonitoring = true
        
        // Start periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: metricsUpdateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicUpdate()
            }
        }
        
        // Add to run loop for proper execution
        if let timer = monitoringTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("🔄 [CognitiveMemoryDashboardViewModel] Started real-time monitoring")
    }
    
    public func stopRealTimeMonitoring() {
        isRealTimeMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        print("⏹️ [CognitiveMemoryDashboardViewModel] Stopped real-time monitoring")
    }
    
    private func performPeriodicUpdate() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.updateSystemMetrics()
            }
            
            group.addTask {
                await self.updateLayerMetrics()
            }
            
            group.addTask {
                await self.updateControlLoopStatus()
            }
            
            group.addTask {
                await self.updateActivityData()
            }
            
            group.addTask {
                await self.updateRecentFusions()
            }
        }
    }
    
    // MARK: - Data Update Methods
    
    public func refreshData() async {
        await loadInitialData()
    }
    
    private func updateSystemMetrics() async {
        do {
            // Get total node count across all layers
            let veridicalCount = cognitiveSystem.veridicalLayer.nodes.count
            let semanticCount = cognitiveSystem.semanticLayer.nodes.count
            let episodicCount = cognitiveSystem.episodicLayer.nodes.count
            let fusionCount = cognitiveSystem.fusionLayer.nodes.count
            
            totalNodes = veridicalCount + semanticCount + episodicCount
            activeFusions = fusionCount
            
            // Calculate overall consolidation score
            let allNodes = cognitiveSystem.veridicalLayer.nodes.map { $0 as any CognitiveMemoryNode } +
                          cognitiveSystem.semanticLayer.nodes.map { $0 as any CognitiveMemoryNode } +
                          cognitiveSystem.episodicLayer.nodes.map { $0 as any CognitiveMemoryNode }
            
            if !allNodes.isEmpty {
                let totalImportance = allNodes.reduce(0.0) { $0 + $1.importance }
                consolidationScore = min(1.0, totalImportance / Double(allNodes.count))
            } else {
                consolidationScore = 0.0
            }
            
            // Update system status
            updateSystemStatus()
            
        } catch {
            print("❌ [CognitiveMemoryDashboardViewModel] Failed to update system metrics: \(error)")
        }
    }
    
    private func updateSystemStatus() {
        if activeFusions > 0 {
            systemStatus = .fusing
        } else if consolidationScore > 0.8 {
            systemStatus = .consolidating
        } else if totalNodes > 0 {
            systemStatus = .processing
        } else {
            systemStatus = .idle
        }
    }
    
    private func updateLayerMetrics() async {
        do {
            // Update veridical layer metrics
            layerMetrics[.veridical] = LayerMetrics(
                nodeCount: cognitiveSystem.veridicalLayer.nodes.count,
                averageQuality: calculateAverageQuality(cognitiveSystem.veridicalLayer.nodes),
                isActive: !cognitiveSystem.veridicalLayer.nodes.isEmpty
            )
            
            // Update semantic layer metrics
            layerMetrics[.semantic] = LayerMetrics(
                nodeCount: cognitiveSystem.semanticLayer.nodes.count,
                averageQuality: calculateAverageQuality(cognitiveSystem.semanticLayer.nodes),
                isActive: !cognitiveSystem.semanticLayer.nodes.isEmpty
            )
            
            // Update episodic layer metrics
            layerMetrics[.episodic] = LayerMetrics(
                nodeCount: cognitiveSystem.episodicLayer.nodes.count,
                averageQuality: calculateAverageQuality(cognitiveSystem.episodicLayer.nodes),
                isActive: !cognitiveSystem.episodicLayer.nodes.isEmpty
            )
            
            // Update fusion layer metrics
            layerMetrics[.fusion] = LayerMetrics(
                nodeCount: cognitiveSystem.fusionLayer.nodes.count,
                averageQuality: calculateAverageQuality(cognitiveSystem.fusionLayer.nodes),
                isActive: !cognitiveSystem.fusionLayer.nodes.isEmpty
            )
            
        } catch {
            print("❌ [CognitiveMemoryDashboardViewModel] Failed to update layer metrics: \(error)")
        }
    }
    
    private func calculateAverageQuality<T: CognitiveMemoryNode>(_ nodes: [T]) -> Double {
        guard !nodes.isEmpty else { return 0.0 }
        let totalQuality = nodes.reduce(0.0) { $0 + $1.importance }
        return totalQuality / Double(nodes.count)
    }
    
    private func updateControlLoopStatus() async {
        // Simulate control loop status based on system activity
        // In a real implementation, this would query the actual CognitiveControlLoop
        
        let isSystemActive = systemStatus != .idle
        
        controlLoopPhases = ControlLoopPhase.allCases.enumerated().map { index, phase in
            let isActive: Bool
            let progress: Double
            
            if isSystemActive {
                // Simulate cycling through phases
                let currentPhaseIndex = (Int(Date().timeIntervalSinceReferenceDate) / 2) % ControlLoopPhase.allCases.count
                isActive = index == currentPhaseIndex
                progress = isActive ? Double.random(in: 0.3...0.9) : 0.0
            } else {
                isActive = false
                progress = 0.0
            }
            
            return ControlLoopPhaseStatus(
                phase: phase,
                isActive: isActive,
                progress: progress
            )
        }
    }
    
    private func updateActivityData() async {
        let now = Date()
        let timeInterval = selectedTimeRange.timeInterval
        let dataPoints = selectedTimeRange.dataPointCount
        
        // Generate activity data points for the selected time range
        var newActivityData: [ActivityDataPoint] = []
        
        for i in 0..<dataPoints {
            let timestamp = now.addingTimeInterval(-timeInterval + (timeInterval * Double(i) / Double(dataPoints - 1)))
            
            for layer in CognitiveLayerType.allCases where layer != .fusion {
                let metrics = layerMetrics[layer] ?? LayerMetrics.empty
                
                // Generate activity value based on metrics with some randomness
                let baseActivity = Double(metrics.nodeCount) * metrics.averageQuality
                let randomFactor = Double.random(in: 0.8...1.2)
                let activityValue = min(100.0, baseActivity * randomFactor * 10)
                
                newActivityData.append(ActivityDataPoint(
                    timestamp: timestamp,
                    value: activityValue,
                    layer: layer
                ))
            }
        }
        
        activityData = newActivityData.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func updateRecentFusions() async {
        // Generate recent fusion activity based on system state
        var newFusions: [RecentFusionActivity] = []
        
        if activeFusions > 0 {
            let fusionCount = min(5, activeFusions)
            
            for i in 0..<fusionCount {
                let sourceLayers = Array(CognitiveLayerType.allCases.filter { $0 != .fusion }.shuffled().prefix(Int.random(in: 2...3)))
                
                let descriptions = [
                    "Cross-layer memory consolidation",
                    "Semantic concept integration",
                    "Episodic context fusion",
                    "Veridical fact validation",
                    "Multi-layer knowledge synthesis"
                ]
                
                let fusion = RecentFusionActivity(
                    description: descriptions.randomElement() ?? "Memory fusion process",
                    timestamp: Date().addingTimeInterval(-TimeInterval(i * 300)), // 5 minute intervals
                    quality: Double.random(in: 0.6...0.95),
                    sourceLayers: sourceLayers
                )
                
                newFusions.append(fusion)
            }
        }
        
        recentFusions = newFusions.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Apple Intelligence Integration
    
    public func generateAIInsights() {
        // Placeholder for Apple Intelligence integration
        // This would use Apple's ML frameworks to generate insights
        print("🧠 [CognitiveMemoryDashboardViewModel] Generating AI insights (placeholder)")
        
        // In a real implementation, this would:
        // 1. Analyze current cognitive patterns
        // 2. Generate actionable insights
        // 3. Provide optimization recommendations
        // 4. Surface anomalies or interesting patterns
    }
    
    // MARK: - Time Range Management
    
    public func updateTimeRange(_ timeRange: TimeRange) {
        selectedTimeRange = timeRange
        
        Task {
            await updateActivityData()
        }
    }
}

// MARK: - Supporting Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension TimeRange {
    var timeInterval: TimeInterval {
        switch self {
        case .hour: return 3600
        case .day: return 24 * 3600
        case .week: return 7 * 24 * 3600
        case .month: return 30 * 24 * 3600
        }
    }
    
    var dataPointCount: Int {
        switch self {
        case .hour: return 60 // One per minute
        case .day: return 96 // Every 15 minutes
        case .week: return 168 // Every hour
        case .month: return 120 // Every 6 hours
        }
    }
}

// MARK: - Mock Data Generation (Development Only)

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension CognitiveMemoryDashboardViewModel {
    
    #if DEBUG
    static func createMockViewModel() -> CognitiveMemoryDashboardViewModel {
        // Create a mock cognitive system for development/preview purposes
        let mockContext = try! ModelContext(ModelContainer(for: Schema([]), configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
        let mockCognitiveSystem = CognitiveMemorySystem(modelContext: mockContext)
        
        let viewModel = CognitiveMemoryDashboardViewModel(cognitiveSystem: mockCognitiveSystem)
        
        // Set up mock data
        Task { @MainActor in
            viewModel.totalNodes = 157
            viewModel.activeFusions = 12
            viewModel.consolidationScore = 0.78
            viewModel.systemStatus = .processing
            
            // Mock layer metrics
            viewModel.layerMetrics = [
                .veridical: LayerMetrics(nodeCount: 45, averageQuality: 0.92, isActive: true),
                .semantic: LayerMetrics(nodeCount: 67, averageQuality: 0.85, isActive: true),
                .episodic: LayerMetrics(nodeCount: 45, averageQuality: 0.73, isActive: true),
                .fusion: LayerMetrics(nodeCount: 12, averageQuality: 0.89, isActive: true)
            ]
            
            // Mock recent fusions
            viewModel.recentFusions = [
                RecentFusionActivity(
                    description: "Semantic-Episodic knowledge integration",
                    timestamp: Date().addingTimeInterval(-300),
                    quality: 0.87,
                    sourceLayers: [.semantic, .episodic]
                ),
                RecentFusionActivity(
                    description: "Veridical fact validation with context",
                    timestamp: Date().addingTimeInterval(-600),
                    quality: 0.92,
                    sourceLayers: [.veridical, .episodic]
                )
            ]
        }
        
        return viewModel
    }
    #endif
}