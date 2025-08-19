import SwiftUI
import SwiftData

struct NoteHealthCorrelationView: View {
    let noteId: UUID
    let noteDate: Date
    let noteContent: String
    
    @StateObject private var healthKitManager: HealthKitManager
    @StateObject private var healthEnrichment: HealthEnrichment
    @Environment(\.modelContext) private var modelContext
    
    @State private var enrichmentResult: NoteHealthEnrichment?
    @State private var isAnalyzing = false
    @State private var showingDetails = false
    
    init(noteId: UUID, noteDate: Date, noteContent: String) {
        self.noteId = noteId
        self.noteDate = noteDate
        self.noteContent = noteContent
        
        let healthKitManager = HealthKitManager()
        self._healthKitManager = StateObject(wrappedValue: healthKitManager)
        self._healthEnrichment = StateObject(wrappedValue: HealthEnrichment(healthKitManager: healthKitManager, modelContext: ModelData.shared.modelContainer.mainContext))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if !healthKitManager.isAuthorized {
                HealthCorrelationDisabledView()
            } else if isAnalyzing {
                HealthAnalysisLoadingView()
            } else if let enrichment = enrichmentResult {
                HealthCorrelationResultsView(enrichment: enrichment) {
                    showingDetails = true
                }
            } else {
                HealthCorrelationPromptView {
                    await analyzeNoteHealthCorrelation()
                }
            }
        }
        .onAppear {
            setupHealthIntegration()
        }
        .sheet(isPresented: $showingDetails) {
            if let enrichment = enrichmentResult {
                HealthCorrelationDetailView(enrichment: enrichment)
            }
        }
    }
    
    private func setupHealthIntegration() {
        healthKitManager.modelContext = modelContext
        
        if healthKitManager.isAuthorized {
            Task {
                await loadExistingCorrelation()
            }
        }
    }
    
    private func loadExistingCorrelation() async {
        let descriptor = FetchDescriptor<NoteHealthCorrelation>(
            predicate: #Predicate<NoteHealthCorrelation> { correlation in
                correlation.noteId == noteId
            }
        )
        
        do {
            let existingCorrelations = try modelContext.fetch(descriptor)
            if let existing = existingCorrelations.first {
                let healthCorrelations = await healthKitManager.getHealthDataCorrelations(
                    with: noteId,
                    date: noteDate
                )
                
                let enrichment = NoteHealthEnrichment(
                    noteId: existing.noteId,
                    noteDate: existing.noteDate,
                    healthCorrelations: healthCorrelations,
                    healthContext: existing.healthContext,
                    insights: existing.insights,
                    suggestions: existing.suggestions,
                    enrichmentScore: existing.enrichmentScore
                )
                
                await MainActor.run {
                    self.enrichmentResult = enrichment
                }
            }
        } catch {
            print("Error loading existing correlation: \(error)")
        }
    }
    
    private func analyzeNoteHealthCorrelation() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        do {
            try await healthKitManager.fetchRecentHealthData(days: 1)
            
            let enrichment = await healthEnrichment.enrichNoteWithHealthData(
                noteId,
                noteDate: noteDate,
                noteContent: noteContent
            )
            
            await MainActor.run {
                self.enrichmentResult = enrichment
            }
        } catch {
            print("Error analyzing health correlation: \(error)")
        }
    }
}

struct HealthCorrelationDisabledView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Health Integration Disabled")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Enable Health access to see correlations with your health data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthAnalysisLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Analyzing Health Correlations")
                .font(.headline)
            
            Text("Comparing your note with recent health data...")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthCorrelationPromptView: View {
    let onAnalyze: () async -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundColor(.red)
            
            Text("Health Correlation Available")
                .font(.headline)
            
            Text("Analyze this note's relationship to your health data for personalized insights.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await onAnalyze()
                }
            }) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                    Text("Analyze Health Data")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.gradient)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthCorrelationResultsView: View {
    let enrichment: NoteHealthEnrichment
    let onShowDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Insights")
                        .font(.headline)
                    
                    Text("\(enrichment.insights.count) insights found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(enrichment.enrichmentScore * 100))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("Correlation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let topInsight = enrichment.insights.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(topInsight.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(topInsight.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            HStack {
                if !enrichment.suggestions.isEmpty {
                    Text("\(enrichment.suggestions.count) suggestions")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: onShowDetails) {
                    Text("View Details")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HealthCorrelationDetailView: View {
    let enrichment: NoteHealthEnrichment
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    
                    CorrelationOverviewSection(enrichment: enrichment)
                    
                    HealthContextSection(context: enrichment.healthContext)
                    
                    InsightsSection(insights: enrichment.insights)
                    
                    SuggestionsSection(suggestions: enrichment.suggestions)
                    
                    HealthDataSection(correlations: enrichment.healthCorrelations)
                }
                .padding()
            }
            .navigationTitle("Health Correlation")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CorrelationOverviewSection: View {
    let enrichment: NoteHealthEnrichment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Correlation Overview")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Correlation Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(enrichment.enrichmentScore * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Analysis Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(enrichment.noteDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                }
            }
            .padding()
            .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct HealthContextSection: View {
    let context: HealthContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Context")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ContextCard(title: "Time of Day", value: context.timeOfDay.rawValue)
                ContextCard(title: "Activity Level", value: context.activityLevel.rawValue)
                ContextCard(title: "Wellness State", value: context.wellnessState.rawValue)
                ContextCard(title: "Physiological", value: context.physiologicalState.rawValue)
            }
            
            if !context.environmentalFactors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Environmental Factors")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(context.environmentalFactors, id: \.self) { factor in
                        Text("• \(factor)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

struct ContextCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct InsightsSection: View {
    let insights: [HealthInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Insights")
                .font(.title2)
                .fontWeight(.semibold)
            
            if insights.isEmpty {
                Text("No specific insights identified for this note.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ForEach(insights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }
}

struct InsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(insight.confidence * 100))%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
            }
            
            Text(insight.description)
                .font(.body)
            
            if insight.actionable && !insight.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    ForEach(insight.suggestions, id: \.self) { suggestion in
                        Text("• \(suggestion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct SuggestionsSection: View {
    let suggestions: [HealthSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalized Suggestions")
                .font(.title2)
                .fontWeight(.semibold)
            
            if suggestions.isEmpty {
                Text("No specific suggestions available.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ForEach(suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: HealthSuggestion
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.action)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(suggestion.category.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(suggestion.priority.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(suggestion.priority.color.opacity(0.2))
                    .foregroundColor(suggestion.priority.color)
                    .cornerRadius(4)
                
                Text("\(Int(suggestion.estimatedImpact * 100))% impact")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct HealthDataSection: View {
    let correlations: [HealthCorrelation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Data Points")
                .font(.title2)
                .fontWeight(.semibold)
            
            if correlations.isEmpty {
                Text("No health data found for this time period.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                ForEach(Array(correlations.enumerated()), id: \.offset) { index, correlation in
                    HealthDataCard(correlation: correlation, rank: index + 1)
                }
            }
        }
    }
}

struct HealthDataCard: View {
    let correlation: HealthCorrelation
    let rank: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Data Point #\(rank)")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(correlation.correlationStrength * 100))% match")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
            
            Text(correlation.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(correlation.healthData.summarizeMetrics())
                .font(.body)
            
            if !correlation.insights.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notable:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    ForEach(correlation.insights.prefix(2), id: \.self) { insight in
                        Text("• \(insight)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    .padding()
    .appGlass(.elevated, shape: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension SuggestionPriority {
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}