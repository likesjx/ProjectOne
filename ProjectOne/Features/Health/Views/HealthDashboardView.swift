import SwiftUI
import SwiftData

struct HealthDashboardView: View {
    @StateObject private var healthKitManager: HealthKitManager
    @StateObject private var healthEnrichment: HealthEnrichment
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    
    init() {
        let healthKitManager = HealthKitManager()
        self._healthKitManager = StateObject(wrappedValue: healthKitManager)
        self._healthEnrichment = StateObject(wrappedValue: HealthEnrichment(healthKitManager: healthKitManager, modelContext: ModelData.shared.modelContainer.mainContext))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    
                    if !healthKitManager.isAuthorized {
                        HealthPermissionCard(healthKitManager: healthKitManager)
                            .padding(.horizontal)
                    } else {
                        
                        TimeRangeSelector(selectedRange: $selectedTimeRange)
                            .padding(.horizontal)
                        
                        if healthKitManager.isLoading {
                            ProgressView("Loading health data...")
                                .frame(maxWidth: .infinity, minHeight: 100)
                        } else {
                            
                            HealthMetricsGrid(healthData: healthKitManager.recentHealthData)
                                .padding(.horizontal)
                            
                            HealthTrendsSection(trends: healthEnrichment.healthTrends)
                                .padding(.horizontal)
                            
                            HealthInsightsSection(insights: healthEnrichment.healthInsights)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Health Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshHealthData()
            }
            .onAppear {
                setupHealthIntegration()
            }
            .alert("Health Access Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Health access in Settings to view your health data and correlations.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(healthKitManager.error?.localizedDescription ?? "An unknown error occurred.")
            }
        }
    }
    
    private func setupHealthIntegration() {
        healthKitManager.modelContext = modelContext
        healthEnrichment.modelContext = modelContext
        
        if !healthKitManager.isAuthorized {
            Task {
                do {
                    try await healthKitManager.requestHealthKitAuthorization()
                    await refreshHealthData()
                } catch {
                    showingErrorAlert = true
                }
            }
        } else {
            Task {
                await refreshHealthData()
            }
        }
    }
    
    private func refreshHealthData() async {
        do {
            let days = selectedTimeRange.days
            try await healthKitManager.fetchRecentHealthData(days: days)
        } catch {
            showingErrorAlert = true
        }
    }
}

struct HealthPermissionCard: View {
    @ObservedObject var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text("Health Integration")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Connect your health data to get personalized insights and correlations with your voice notes.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: {
                Task {
                    try? await healthKitManager.requestHealthKitAuthorization()
                }
            }) {
                HStack {
                    Image(systemName: "heart.circle")
                    Text("Connect Health Data")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.gradient)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(healthKitManager.isLoading)
        }
    .padding(24)
    .appGlass(.elevated, tint: .red, shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        HStack {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedRange == range ? Color.accentColor : Color.clear
                        )
                        .foregroundColor(
                            selectedRange == range ? .white : .primary
                        )
                        .cornerRadius(8)
                }
            }
        }
    .padding(4)
    .appGlass(.header, tint: .accentColor, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthMetricsGrid: View {
    let healthData: [HealthData]
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            if let latestData = healthData.first {
                if let heartRate = latestData.heartRate {
                    HealthMetricCard(
                        title: "Heart Rate",
                        value: "\(Int(heartRate))",
                        unit: "bpm",
                        icon: "heart.fill",
                        color: .red
                    )
                }
                
                if let steps = latestData.steps {
                    HealthMetricCard(
                        title: "Steps",
                        value: "\(Int(steps))",
                        unit: "steps",
                        icon: "figure.walk",
                        color: .green
                    )
                }
                
                if let calories = latestData.activeEnergyBurned {
                    HealthMetricCard(
                        title: "Calories",
                        value: "\(Int(calories))",
                        unit: "kcal",
                        icon: "flame.fill",
                        color: .orange
                    )
                }
                
                if let sleep = latestData.sleepDuration {
                    let hours = sleep / 3600
                    HealthMetricCard(
                        title: "Sleep",
                        value: String(format: "%.1f", hours),
                        unit: "hours",
                        icon: "bed.double.fill",
                        color: .blue
                    )
                }
            } else {
                Text("No health data available")
                    .foregroundColor(.secondary)
                    .gridCellColumns(2)
            }
        }
    }
}

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    .appGlass(.surface, tint: color, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthTrendsSection: View {
    let trends: [HealthTrend]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Trends")
                .font(.title2)
                .fontWeight(.semibold)
            
            if trends.isEmpty {
                Text("Collect more data to see trends")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(trends) { trend in
                        HealthTrendCard(trend: trend)
                    }
                }
            }
        }
    }
}

struct HealthTrendCard: View {
    let trend: HealthTrend
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trend.metricName)
                    .font(.headline)
                
                Text(trend.insight)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: trend.direction.iconName)
                        .foregroundColor(trend.direction.color)
                    
                    Text(trend.direction.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(trend.direction.color)
                }
                
                Text(String(format: "%.1f %@", trend.currentValue, trend.unit))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    .appGlass(.surface, tint: trend.direction.color, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct HealthInsightsSection: View {
    let insights: [HealthInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Insights")
                .font(.title2)
                .fontWeight(.semibold)
            
            if insights.isEmpty {
                Text("No insights available yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(insights) { insight in
                        HealthInsightCard(insight: insight)
                    }
                }
            }
        }
    }
}

struct HealthInsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(insight.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.primary)
            
            if insight.actionable && !insight.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggestions:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(insight.suggestions.prefix(3), id: \.self) { suggestion in
                        Text("• \(suggestion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    .appGlass(.surface, tint: .mint, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

enum TimeRange: String, CaseIterable {
    case day = "1d"
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
    
    var displayName: String {
        switch self {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        }
    }
    
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

extension TrendDirection {
    var iconName: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing: return .green
        case .decreasing: return .red
        case .stable: return .orange
        }
    }
}

struct ModelData {
    static let shared = ModelData()
    
    lazy var modelContainer: ModelContainer = {
        let schema = Schema([HealthData.self, NoteHealthCorrelation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}