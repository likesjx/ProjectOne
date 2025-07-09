import SwiftUI
import Charts
import AppKit

// MARK: - Memory Distribution Chart

struct MemoryDistributionChart: View {
    let metrics: MemoryAnalytics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Distribution")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Pie chart using Swift Charts
            Chart(memoryData, id: \.type) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.4),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .opacity(0.8)
            }
            .frame(height: 200)
            .chartBackground { chartProxy in
                // Center text showing total
                VStack(spacing: 2) {
                    Text("\(metrics.totalMemoryItems)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Total Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Legend
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(memoryData, id: \.type) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        
                        Text(item.type)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(item.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var memoryData: [MemoryDataPoint] {
        [
            MemoryDataPoint(type: "STM", count: metrics.stmCount, color: .blue),
            MemoryDataPoint(type: "LTM", count: metrics.ltmCount, color: .green),
            MemoryDataPoint(type: "Working", count: metrics.workingMemoryCount, color: .orange),
            MemoryDataPoint(type: "Episodic", count: metrics.episodicMemoryCount, color: .purple)
        ]
    }
}

struct MemoryDataPoint {
    let type: String
    let count: Int
    let color: Color
}

// MARK: - Consolidation Activity Card

struct ConsolidationActivityCard: View {
    let events: [ConsolidationEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Consolidations")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !events.isEmpty {
                    Text("\(events.count) recent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.merge")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No recent consolidations")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Memory consolidation events will appear here")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack(spacing: 12) {
                    ForEach(events, id: \.id) { event in
                        ConsolidationEventRow(event: event)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct ConsolidationEventRow: View {
    let event: ConsolidationEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(event.wasSuccessful ? .green : .orange)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.flowDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(event.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(event.itemsProcessed)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%%", event.successRate * 100))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(event.wasSuccessful ? .green : .orange)
                
                Text("success")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Performance Metrics Grid

struct PerformanceMetricsGrid: View {
    let metrics: [MemoryPerformanceMetric]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            if metrics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    Text("No performance data")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Performance metrics will appear as the system processes data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(metrics.prefix(6), id: \.id) { metric in
                        PerformanceMetricCard(metric: metric)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct PerformanceMetricCard: View {
    let metric: MemoryPerformanceMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: metric.processingPhase.iconName)
                    .foregroundColor(statusColor)
                    .font(.caption)
                
                Spacer()
                
                Image(systemName: metric.performanceStatus.iconName)
                    .foregroundColor(Color(metric.performanceStatus.color))
                    .font(.caption2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(metric.formattedValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(metric.metricType.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // Performance bar
            GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(NSColor.systemGray))
                    .frame(height: 3)
                    .overlay(
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(statusColor)
                                .frame(width: geometry.size.width * min(1.0, metric.efficiency), height: 3)
                            Spacer(minLength: 0)
                        }
                    )
            }
            .frame(height: 3)
        }
        .padding()
        .background(Color(NSColor.systemGray))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch metric.performanceStatus {
        case .optimal:
            return .green
        case .acceptable:
            return .orange
        case .needsImprovement:
            return .red
        }
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                QuickActionButton(
                    title: "Force Consolidation",
                    icon: "arrow.triangle.merge",
                    color: .blue
                ) {
                    // TODO: Trigger manual consolidation
                }
                
                QuickActionButton(
                    title: "Optimize Memory",
                    icon: "speedometer",
                    color: .green
                ) {
                    // TODO: Trigger memory optimization
                }
                
                QuickActionButton(
                    title: "Clear Cache",
                    icon: "trash",
                    color: .orange
                ) {
                    // TODO: Clear system cache
                }
                
                QuickActionButton(
                    title: "Export Report",
                    icon: "square.and.arrow.up",
                    color: .purple
                ) {
                    // TODO: Export analytics report
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Detailed Metrics View

struct DetailedMetricsView: View {
    @ObservedObject var analyticsService: MemoryAnalyticsService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: MetricCategory = .performance
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category picker
                Picker("Metric Category", selection: $selectedCategory) {
                    ForEach(MetricCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.iconName)
                            .tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Metrics list
                List {
                    ForEach(filteredMetrics, id: \.id) { metric in
                        DetailedMetricRow(metric: metric)
                    }
                }
            }
            .navigationTitle("Detailed Metrics")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredMetrics: [MemoryPerformanceMetric] {
        analyticsService.performanceMetrics.filter { metric in
            metric.metricType.category == selectedCategory
        }
    }
}

struct DetailedMetricRow: View {
    let metric: MemoryPerformanceMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.metricType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(metric.formattedValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(metric.performanceStatus.color))
            }
            
            HStack {
                Text(metric.processingPhase.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(metric.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let context = metric.context {
                Text(context)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}