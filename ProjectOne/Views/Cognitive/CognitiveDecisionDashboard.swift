//
//  CognitiveDecisionDashboard.swift
//  ProjectOne
//
//  Real-time decision visualization UI
//  SwiftUI dashboard for cognitive decision tracking and analysis
//

import SwiftUI
import SwiftData
import Charts
import Combine
import os.log

/// SwiftUI dashboard for visualizing AI agent decision-making processes
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct CognitiveDecisionDashboard: View {
    
    @EnvironmentObject private var cognitiveEngine: CognitiveDecisionEngine
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTimeRange: TimeRange = .lastHour
    @State private var selectedAgent: String = "All"
    @State private var decisionInsights: DecisionInsights = DecisionInsights()
    @State private var isLoading = false
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "CognitiveDecisionDashboard")
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    
                    // Header with controls
                    dashboardHeader
                    
                    // Real-time metrics
                    metricsSection
                    
                    // Decision timeline chart
                    timelineSection
                    
                    // Agent performance
                    agentPerformanceSection
                    
                    // Recent decisions
                    recentDecisionsSection
                    
                    // Decision patterns
                    patternsSection
                    
                }
                .padding()
            }
            .navigationTitle("Cognitive Decisions")
            .refreshable {
                await refreshData()
            }
            .task {
                await loadInitialData()
            }
            .onReceive(cognitiveEngine.decisionStream) { _ in
                Task {
                    await refreshData()
                }
            }
        }
    }
    
    // MARK: - Dashboard Header
    
    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Decision Tracking")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                StatusIndicator(isActive: cognitiveEngine.isTracking)
            }
            
            HStack {
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                // Agent filter
                Menu("Agent: \(selectedAgent)") {
                    Button("All") { selectedAgent = "All" }
                    ForEach(getAvailableAgents(), id: \.self) { agent in
                        Button(agent) { selectedAgent = agent }
                    }
                }
                #if os(iOS)
                .menuStyle(BorderedProminentMenuStyle())
                #endif
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
        #endif
        .cornerRadius(12)
    }
    
    // MARK: - Metrics Section
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Real-time Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                CognitiveMetricCard(
                    title: "Total Decisions",
                    value: "\(cognitiveEngine.decisionMetrics.totalDecisions)",
                    color: .blue
                )
                
                CognitiveMetricCard(
                    title: "Avg Confidence",
                    value: String(format: "%.1f%%", cognitiveEngine.decisionMetrics.averageConfidence * 100),
                    color: .green
                )
                
                CognitiveMetricCard(
                    title: "Active Agents",
                    value: "\(cognitiveEngine.decisionMetrics.agentDecisionCounts.count)",
                    color: .orange
                )
            }
        }
    }
    
    // MARK: - Timeline Section
    
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Decision Timeline")
                .font(.headline)
            
            Chart {
                ForEach(getChartData(), id: \.timestamp) { data in
                    LineMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Decisions", data.count)
                    )
                    .foregroundStyle(.blue)
                    
                    AreaMark(
                        x: .value("Time", data.timestamp),
                        y: .value("Decisions", data.count)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                }
            }
            .frame(height: 200)
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
        .cornerRadius(12)
    }
    
    // MARK: - Agent Performance Section
    
    private var agentPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agent Performance")
                .font(.headline)
            
            ForEach(decisionInsights.agentPerformance, id: \.agentId) { performance in
                AgentPerformanceRow(performance: performance)
            }
        }
    }
    
    // MARK: - Recent Decisions Section
    
    private var recentDecisionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Decisions")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink("View All") {
                    DecisionListView()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(cognitiveEngine.recentDecisions.prefix(5), id: \.id) { decision in
                    DecisionRow(decision: decision)
                }
            }
        }
    }
    
    // MARK: - Patterns Section
    
    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Decision Patterns")
                .font(.headline)
            
            if decisionInsights.commonPatterns.isEmpty {
                Text("No patterns detected yet")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(decisionInsights.commonPatterns, id: \.self) { pattern in
                    HStack {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundColor(.blue)
                        Text(pattern)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func getAvailableAgents() -> [String] {
        return Array(cognitiveEngine.decisionMetrics.agentDecisionCounts.keys).sorted()
    }
    
    private func getChartData() -> [ChartDataPoint] {
        let decisions = selectedAgent == "All" ? 
            cognitiveEngine.recentDecisions : 
            cognitiveEngine.recentDecisions.filter { $0.agentId == selectedAgent }
        
        // Group decisions by hour
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: decisions) { decision in
            calendar.dateInterval(of: .hour, for: decision.timestamp)?.start ?? decision.timestamp
        }
        
        return grouped.map { (timestamp, decisions) in
            ChartDataPoint(timestamp: timestamp, count: decisions.count)
        }.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func loadInitialData() async {
        isLoading = true
        decisionInsights = await cognitiveEngine.getDecisionInsights(timeRange: selectedTimeRange.seconds)
        isLoading = false
    }
    
    private func refreshData() async {
        decisionInsights = await cognitiveEngine.getDecisionInsights(timeRange: selectedTimeRange.seconds)
    }
}

// MARK: - Supporting Views

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct StatusIndicator: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(isActive ? "Tracking" : "Paused")
                .font(.caption)
                .foregroundColor(isActive ? .green : .red)
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct CognitiveMetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct AgentPerformanceRow: View {
    let performance: AgentPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(performance.agentId)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(performance.decisionCount) decisions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Confidence: \(String(format: "%.1f%%", performance.averageConfidence * 100))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Recent activity indicators
                HStack(spacing: 4) {
                    ForEach(performance.recentActivity.prefix(3), id: \.self) { activity in
                        Circle()
                            .fill(colorForDecisionType(activity))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
        .cornerRadius(8)
    }
    
    private func colorForDecisionType(_ type: String) -> Color {
        switch type {
        case "memory_operation": return .blue
        case "knowledge_graph": return .green
        case "provider_selection": return .orange
        case "text_processing": return .purple
        case "audio_processing": return .pink
        default: return .gray
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct DecisionRow: View {
    let decision: CognitiveDecision
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(decision.agentId)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(decision.timestamp, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(decision.decisionType.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(decision.context)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Confidence indicator
            ConfidenceIndicator(confidence: decision.confidence)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f%%", confidence * 100))
                .font(.caption2)
                .fontWeight(.medium)
            
            RoundedRectangle(cornerRadius: 2)
                .fill(confidenceColor)
                .frame(width: 30, height: 4)
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
struct DecisionListView: View {
    @EnvironmentObject private var cognitiveEngine: CognitiveDecisionEngine
    
    var body: some View {
        List {
            ForEach(cognitiveEngine.recentDecisions, id: \.id) { decision in
                DecisionRow(decision: decision)
                    .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("All Decisions")
    }
}

// MARK: - Supporting Types

enum TimeRange: CaseIterable {
    case lastHour
    case last6Hours
    case last24Hours
    case lastWeek
    
    var displayName: String {
        switch self {
        case .lastHour: return "1H"
        case .last6Hours: return "6H"
        case .last24Hours: return "24H"
        case .lastWeek: return "1W"
        }
    }
    
    var seconds: TimeInterval {
        switch self {
        case .lastHour: return 3600
        case .last6Hours: return 21600
        case .last24Hours: return 86400
        case .lastWeek: return 604800
        }
    }
}

struct ChartDataPoint {
    let timestamp: Date
    let count: Int
}