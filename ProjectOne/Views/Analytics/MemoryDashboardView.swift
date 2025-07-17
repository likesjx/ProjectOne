import SwiftUI
import SwiftData

/// Main dashboard view for memory analytics and system health monitoring
struct MemoryDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analyticsService: MemoryAnalyticsService
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @State private var showingDetailedMetrics = false
    @State private var refreshTask: Task<Void, Never>?
    
    init(modelContext: ModelContext) {
        self._analyticsService = StateObject(wrappedValue: MemoryAnalyticsService(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with refresh status
                    headerSection
                    
                    // Real-time Memory Overview
                    MemoryOverviewCard(
                        metrics: analyticsService.currentMetrics,
                        isLoading: analyticsService.isCollecting
                    )
                    
                    // Memory Health Indicators
                    MemoryHealthCard(
                        healthStatus: analyticsService.healthStatus,
                        metrics: analyticsService.currentMetrics
                    )
                    
                    // Memory Distribution Chart
                    if let metrics = analyticsService.currentMetrics {
                        MemoryDistributionChart(metrics: metrics)
                    }
                    
                    // Recent Consolidation Activity
                    ConsolidationActivityCard(
                        events: Array(analyticsService.recentEvents.prefix(5))
                    )
                    
                    // Performance Metrics Grid
                    PerformanceMetricsGrid(
                        metrics: Array(analyticsService.performanceMetrics.prefix(8))
                    )
                    
                    // Quick Actions
                    QuickActionsCard()
                }
                .padding()
            }
            .navigationTitle("Memory Analytics")
            .toolbar {
                ToolbarItemGroup(placement: {
                    #if os(iOS)
                    .navigationBarTrailing
                    #else
                    .automatic
                    #endif
                }()) {
                    timeRangeMenu
                    
                    Menu {
                        Button("Detailed Metrics", systemImage: "chart.bar") {
                            showingDetailedMetrics = true
                        }
                        
                        NavigationLink(destination: DataExportView(modelContext: modelContext)) {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        
                        Button("Force Refresh", systemImage: "arrow.clockwise") {
                            forceRefresh()
                        }
                        
                        Button("Run Memory Tests", systemImage: "testtube.2") {
                            runMemoryAgentTests()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await refreshData()
            }
            .sheet(isPresented: $showingDetailedMetrics) {
                DetailedMetricsView(analyticsService: analyticsService)
            }
        }
        .task {
            await initializeAnalytics()
        }
        .onDisappear {
            refreshTask?.cancel()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Overview")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let lastUpdate = analyticsService.currentMetrics?.timestamp {
                    Text("Last updated: \(lastUpdate, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Real-time status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(analyticsService.isCollecting ? .orange : .green)
                    .frame(width: 8, height: 8)
                
                Text(analyticsService.isCollecting ? "Collecting" : "Live")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(analyticsService.isCollecting ? .orange : .green)
            }
        }
    }
    
    // MARK: - Time Range Menu
    
    private var timeRangeMenu: some View {
        Menu {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(range.displayName) {
                    selectedTimeRange = range
                    Task {
                        await updateForTimeRange(range)
                    }
                }
                .foregroundColor(selectedTimeRange == range ? .accentColor : .primary)
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedTimeRange.shortName)
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Actions
    
    private func initializeAnalytics() async {
        // Initial data load is handled by the service
        await refreshData()
    }
    
    private func refreshData() async {
        _ = await analyticsService.collectMemorySnapshot()
    }
    
    private func forceRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            _ = await analyticsService.collectMemorySnapshot()
        }
    }
    
    private func updateForTimeRange(_ range: TimeRange) async {
        let timeRange = range.dateInterval
        _ = await analyticsService.getMemoryTrends(timeRange: timeRange)
        // Update UI based on time range data
    }
    
    private func runMemoryAgentTests() {
        Task {
            print("🧪 Memory Agent Tests disabled during development")
            // Tests temporarily disabled during prompt management integration
        }
    }
    
}

// MARK: - Memory Overview Card

struct MemoryOverviewCard: View {
    let metrics: MemoryAnalytics?
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Memory Overview")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let metrics = metrics {
                    Text(metrics.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let metrics = metrics {
                // Memory type grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    MemoryTypeCard(
                        title: "Short-Term",
                        count: metrics.stmCount,
                        color: .blue,
                        icon: "brain.head.profile",
                        percentage: metrics.memoryDistribution.stm
                    )
                    
                    MemoryTypeCard(
                        title: "Long-Term",
                        count: metrics.ltmCount,
                        color: .green,
                        icon: "archivebox",
                        percentage: metrics.memoryDistribution.ltm
                    )
                    
                    MemoryTypeCard(
                        title: "Working",
                        count: metrics.workingMemoryCount,
                        color: .orange,
                        icon: "cpu",
                        percentage: metrics.memoryDistribution.working
                    )
                    
                    MemoryTypeCard(
                        title: "Episodic",
                        count: metrics.episodicMemoryCount,
                        color: .purple,
                        icon: "timeline.selection",
                        percentage: metrics.memoryDistribution.episodic
                    )
                }
                
                // Summary stats
                HStack {
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("\(metrics.totalMemoryItems)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Total Items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("\(metrics.totalEntities)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Entities")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        Text("\(metrics.totalRelationships)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Relationships")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
                
            } else {
                // Loading state
                VStack(spacing: 12) {
                    ProgressView("Loading memory analytics...")
                    
                    Text("Collecting system metrics...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Memory Type Card

struct MemoryTypeCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    let percentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
                
                Text("\(Int(percentage * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 4)
                    .overlay(
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: geometry.size.width * percentage, height: 4)
                            Spacer(minLength: 0)
                        }
                    )
            }
            .frame(height: 4)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Memory Health Card

struct MemoryHealthCard: View {
    let healthStatus: HealthStatus
    let metrics: MemoryAnalytics?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("System Health")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Health status badge
                HStack(spacing: 6) {
                    Image(systemName: healthStatus.systemImageName)
                        .foregroundColor(Color(healthStatus.color))
                    
                    Text(healthStatus.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(healthStatus.color))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(healthStatus.color).opacity(0.1))
                .cornerRadius(6)
            }
            
            if let metrics = metrics {
                // Health metrics
                VStack(spacing: 12) {
                    HealthMetricRow(
                        title: "Consolidation Rate",
                        value: metrics.consolidationRate,
                        format: .percentage,
                        target: 0.8
                    )
                    
                    HealthMetricRow(
                        title: "Memory Efficiency",
                        value: metrics.memoryEfficiency,
                        format: .percentage,
                        target: 0.7
                    )
                    
                    HealthMetricRow(
                        title: "Average Confidence",
                        value: metrics.averageConfidence,
                        format: .percentage,
                        target: 0.85
                    )
                    
                    HealthMetricRow(
                        title: "Processing Latency",
                        value: metrics.processingLatency,
                        format: .time,
                        target: 1.0,
                        isReversed: true
                    )
                }
            }
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Health Metric Row

struct HealthMetricRow: View {
    let title: String
    let value: Double
    let format: MetricFormat
    let target: Double
    let isReversed: Bool
    
    init(title: String, value: Double, format: MetricFormat, target: Double, isReversed: Bool = false) {
        self.title = title
        self.value = value
        self.format = format
        self.target = target
        self.isReversed = isReversed
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(formattedValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(metricColor)
        }
    }
    
    private var formattedValue: String {
        switch format {
        case .percentage:
            return String(format: "%.1f%%", value * 100)
        case .time:
            return String(format: "%.2fs", value)
        case .count:
            return String(format: "%.0f", value)
        }
    }
    
    private var metricColor: Color {
        let isGood = isReversed ? value <= target : value >= target
        return isGood ? .green : (value >= target * 0.7 ? .orange : .red)
    }
}

enum MetricFormat {
    case percentage
    case time
    case count
}

// MARK: - Time Range Enum

enum TimeRange: String, CaseIterable {
    case lastHour = "1h"
    case last24Hours = "24h"
    case lastWeek = "7d"
    case lastMonth = "30d"
    
    var displayName: String {
        switch self {
        case .lastHour:
            return "Last Hour"
        case .last24Hours:
            return "Last 24 Hours"
        case .lastWeek:
            return "Last Week"
        case .lastMonth:
            return "Last Month"
        }
    }
    
    var shortName: String {
        return rawValue
    }
    
    var dateInterval: DateInterval {
        let end = Date()
        let start: Date
        
        switch self {
        case .lastHour:
            start = end.addingTimeInterval(-3600)
        case .last24Hours:
            start = end.addingTimeInterval(-86400)
        case .lastWeek:
            start = end.addingTimeInterval(-604800)
        case .lastMonth:
            start = end.addingTimeInterval(-2592000)
        }
        
        return DateInterval(start: start, end: end)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        MemoryDashboardView(modelContext: ModelContext(try! ModelContainer(for: MemoryAnalytics.self)))
    }
}