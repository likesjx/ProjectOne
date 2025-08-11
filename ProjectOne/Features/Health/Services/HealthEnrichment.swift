import Foundation
import SwiftData
import Combine

@MainActor
class HealthEnrichment: ObservableObject {
    private let healthKitManager: HealthKitManager
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    @Published var healthInsights: [HealthInsight] = []
    @Published var healthTrends: [HealthTrend] = []
    @Published var correlations: [NoteHealthCorrelation] = []
    @Published var isAnalyzing = false
    
    init(healthKitManager: HealthKitManager, modelContext: ModelContext) {
        self.healthKitManager = healthKitManager
        self.modelContext = modelContext
        
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        healthKitManager.$recentHealthData
            .sink { [weak self] healthData in
                Task {
                    await self?.analyzeHealthTrends(healthData)
                }
            }
            .store(in: &cancellables)
    }
    
    func enrichNoteWithHealthData(_ noteId: UUID, noteDate: Date, noteContent: String) async -> NoteHealthEnrichment {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let correlations = await healthKitManager.getHealthDataCorrelations(with: noteId, date: noteDate)
        let healthContext = generateHealthContext(from: correlations)
        let insights = await generateHealthInsights(for: noteContent, with: correlations)
        let suggestions = generateHealthSuggestions(based: insights, correlations: correlations)
        
        let enrichment = NoteHealthEnrichment(
            noteId: noteId,
            noteDate: noteDate,
            healthCorrelations: correlations,
            healthContext: healthContext,
            insights: insights,
            suggestions: suggestions,
            enrichmentScore: calculateEnrichmentScore(correlations: correlations, insights: insights)
        )
        
        await saveNoteHealthCorrelation(enrichment)
        
        return enrichment
    }
    
    private func generateHealthContext(from correlations: [HealthCorrelation]) -> HealthContext {
        guard let primaryCorrelation = correlations.first else {
            return HealthContext()
        }
        
        let healthData = primaryCorrelation.healthData
        
        return HealthContext(
            timeOfDay: determineTimeOfDay(healthData.date),
            activityLevel: determineActivityLevel(healthData),
            wellnessState: determineWellnessState(healthData),
            physiologicalState: determinePhysiologicalState(healthData),
            environmentalFactors: determineEnvironmentalFactors(healthData)
        )
    }
    
    private func determineTimeOfDay(_ date: Date) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
    
    private func determineActivityLevel(_ healthData: HealthData) -> ActivityLevel {
        var score = 0.0
        
        if let steps = healthData.steps {
            score += min(steps / 10000.0, 1.0) * 0.4
        }
        
        if let calories = healthData.activeEnergyBurned {
            score += min(calories / 500.0, 1.0) * 0.3
        }
        
        if let workoutDuration = healthData.workoutDuration {
            score += min(workoutDuration / 3600.0, 1.0) * 0.3
        }
        
        switch score {
        case 0.0..<0.3:
            return .low
        case 0.3..<0.7:
            return .moderate
        default:
            return .high
        }
    }
    
    private func determineWellnessState(_ healthData: HealthData) -> WellnessState {
        var positiveFactors = 0
        var negativeFactors = 0
        
        if let sleepDuration = healthData.sleepDuration {
            let hours = sleepDuration / 3600
            if hours >= 7 && hours <= 9 {
                positiveFactors += 1
            } else {
                negativeFactors += 1
            }
        }
        
        if let mindfulMinutes = healthData.mindfulMinutes, mindfulMinutes > 0 {
            positiveFactors += 1
        }
        
        if let heartRate = healthData.heartRate {
            if heartRate >= 60 && heartRate <= 100 {
                positiveFactors += 1
            } else {
                negativeFactors += 1
            }
        }
        
        if positiveFactors > negativeFactors {
            return .good
        } else if negativeFactors > positiveFactors {
            return .poor
        } else {
            return .neutral
        }
    }
    
    private func determinePhysiologicalState(_ healthData: HealthData) -> PhysiologicalState {
        var stressIndicators = 0
        var restIndicators = 0
        
        if let heartRate = healthData.heartRate {
            if heartRate > 100 {
                stressIndicators += 1
            } else if heartRate < 70 {
                restIndicators += 1
            }
        }
        
        if let systolic = healthData.bloodPressureSystolic, let diastolic = healthData.bloodPressureDiastolic {
            if systolic > 140 || diastolic > 90 {
                stressIndicators += 1
            } else if systolic < 120 && diastolic < 80 {
                restIndicators += 1
            }
        }
        
        if stressIndicators > restIndicators {
            return .stressed
        } else if restIndicators > stressIndicators {
            return .relaxed
        } else {
            return .balanced
        }
    }
    
    private func determineEnvironmentalFactors(_ healthData: HealthData) -> [String] {
        var factors: [String] = []
        
        let hour = Calendar.current.component(.hour, from: healthData.date)
        
        if hour >= 6 && hour <= 9 {
            factors.append("Morning routine period")
        } else if hour >= 12 && hour <= 14 {
            factors.append("Lunch time period")
        } else if hour >= 18 && hour <= 20 {
            factors.append("Evening wind-down period")
        }
        
        if let workoutDuration = healthData.workoutDuration, workoutDuration > 0 {
            factors.append("Post-workout period")
        }
        
        if let mindfulMinutes = healthData.mindfulMinutes, mindfulMinutes > 0 {
            factors.append("Mindfulness practice period")
        }
        
        return factors
    }
    
    private func generateHealthInsights(for noteContent: String, with correlations: [HealthCorrelation]) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        for correlation in correlations.prefix(3) {
            let contextualInsights = await analyzeNoteHealthContext(noteContent, correlation.healthData)
            insights.append(contentsOf: contextualInsights)
        }
        
        return insights
    }
    
    private func analyzeNoteHealthContext(_ noteContent: String, _ healthData: HealthData) async -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        let lowercaseContent = noteContent.lowercased()
        
        if containsStressKeywords(lowercaseContent) {
            if let heartRate = healthData.heartRate, heartRate > 90 {
                insights.append(HealthInsight(
                    type: .physiological,
                    title: "Stress Correlation Detected",
                    description: "Your elevated heart rate (\(Int(heartRate)) bpm) aligns with stress indicators in your note",
                    confidence: 0.8,
                    actionable: true,
                    suggestions: ["Consider breathing exercises", "Take a short walk", "Practice mindfulness"]
                ))
            }
        }
        
        if containsEnergyKeywords(lowercaseContent) {
            if let steps = healthData.steps, steps < 5000 {
                insights.append(HealthInsight(
                    type: .activity,
                    title: "Low Activity Correlation",
                    description: "Your low step count (\(Int(steps))) may be related to energy levels mentioned in your note",
                    confidence: 0.7,
                    actionable: true,
                    suggestions: ["Take a 10-minute walk", "Do some light stretching", "Get some sunlight"]
                ))
            }
        }
        
        if containsSleepKeywords(lowercaseContent) {
            if let sleepDuration = healthData.sleepDuration {
                let hours = sleepDuration / 3600
                if hours < 7 {
                    insights.append(HealthInsight(
                        type: .sleep,
                        title: "Sleep Quality Impact",
                        description: "Your sleep duration (\(String(format: "%.1f", hours))h) may be affecting the sleep concerns in your note",
                        confidence: 0.9,
                        actionable: true,
                        suggestions: ["Establish bedtime routine", "Limit screen time before bed", "Create a sleep-friendly environment"]
                    ))
                }
            }
        }
        
        if containsMoodKeywords(lowercaseContent) {
            if let mindfulMinutes = healthData.mindfulMinutes, mindfulMinutes > 0 {
                insights.append(HealthInsight(
                    type: .mental,
                    title: "Mindfulness Practice Alignment",
                    description: "Your mindfulness practice (\(Int(mindfulMinutes)) minutes) shows positive mental health engagement",
                    confidence: 0.8,
                    actionable: false,
                    suggestions: []
                ))
            }
        }
        
        return insights
    }
    
    private func containsStressKeywords(_ content: String) -> Bool {
        let stressKeywords = ["stress", "anxious", "worried", "overwhelmed", "pressure", "tense", "nervous"]
        return stressKeywords.contains { content.contains($0) }
    }
    
    private func containsEnergyKeywords(_ content: String) -> Bool {
        let energyKeywords = ["tired", "fatigue", "exhausted", "energy", "sleepy", "drained", "weary"]
        return energyKeywords.contains { content.contains($0) }
    }
    
    private func containsSleepKeywords(_ content: String) -> Bool {
        let sleepKeywords = ["sleep", "insomnia", "rest", "bed", "night", "dream", "wake"]
        return sleepKeywords.contains { content.contains($0) }
    }
    
    private func containsMoodKeywords(_ content: String) -> Bool {
        let moodKeywords = ["happy", "sad", "depressed", "mood", "emotional", "feeling", "mental"]
        return moodKeywords.contains { content.contains($0) }
    }
    
    private func generateHealthSuggestions(based insights: [HealthInsight], correlations: [HealthCorrelation]) -> [HealthSuggestion] {
        var suggestions: [HealthSuggestion] = []
        
        let actionableInsights = insights.filter { $0.actionable }
        
        for insight in actionableInsights {
            for suggestionText in insight.suggestions {
                suggestions.append(HealthSuggestion(
                    category: insight.type.rawValue,
                    action: suggestionText,
                    priority: insight.confidence > 0.8 ? .high : .medium,
                    estimatedImpact: insight.confidence
                ))
            }
        }
        
        if let latestHealth = correlations.first?.healthData {
            suggestions.append(contentsOf: generateProactiveHealthSuggestions(latestHealth))
        }
        
        return suggestions
    }
    
    private func generateProactiveHealthSuggestions(_ healthData: HealthData) -> [HealthSuggestion] {
        var suggestions: [HealthSuggestion] = []
        
        if let steps = healthData.steps, steps < 8000 {
            suggestions.append(HealthSuggestion(
                category: "activity",
                action: "Aim for \(10000 - Int(steps)) more steps today",
                priority: .medium,
                estimatedImpact: 0.6
            ))
        }
        
        if healthData.workoutDuration == nil || healthData.workoutDuration == 0 {
            suggestions.append(HealthSuggestion(
                category: "fitness",
                action: "Consider 20 minutes of exercise today",
                priority: .low,
                estimatedImpact: 0.5
            ))
        }
        
        if healthData.mindfulMinutes == nil || healthData.mindfulMinutes == 0 {
            suggestions.append(HealthSuggestion(
                category: "mental",
                action: "Try 5 minutes of mindfulness or meditation",
                priority: .low,
                estimatedImpact: 0.4
            ))
        }
        
        return suggestions
    }
    
    private func calculateEnrichmentScore(correlations: [HealthCorrelation], insights: [HealthInsight]) -> Double {
        let correlationScore = correlations.prefix(5).reduce(0.0) { $0 + $1.correlationStrength } / 5.0
        let insightScore = insights.reduce(0.0) { $0 + $1.confidence } / Double(max(insights.count, 1))
        
        return (correlationScore * 0.4) + (insightScore * 0.6)
    }
    
    private func saveNoteHealthCorrelation(_ enrichment: NoteHealthEnrichment) async {
        let correlation = NoteHealthCorrelation(
            noteId: enrichment.noteId,
            noteDate: enrichment.noteDate,
            enrichmentScore: enrichment.enrichmentScore,
            insights: enrichment.insights,
            suggestions: enrichment.suggestions,
            healthContext: enrichment.healthContext
        )
        
        modelContext.insert(correlation)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save note-health correlation: \(error)")
        }
    }
    
    func analyzeHealthTrends(_ healthData: [HealthData]) async {
        guard healthData.count >= 3 else { return }
        
        var trends: [HealthTrend] = []
        
        let sortedData = healthData.sorted { $0.date < $1.date }
        
        if let heartRateTrend = analyzeMetricTrend(data: sortedData, keyPath: \.heartRate, metricName: "Heart Rate", unit: "bpm") {
            trends.append(heartRateTrend)
        }
        
        if let stepsTrend = analyzeMetricTrend(data: sortedData, keyPath: \.steps, metricName: "Steps", unit: "steps") {
            trends.append(stepsTrend)
        }
        
        if let sleepTrend = analyzeMetricTrend(data: sortedData, keyPath: \.sleepDuration, metricName: "Sleep Duration", unit: "hours", valueTransform: { $0 / 3600 }) {
            trends.append(sleepTrend)
        }
        
        if let weightTrend = analyzeMetricTrend(data: sortedData, keyPath: \.bodyWeight, metricName: "Weight", unit: "kg") {
            trends.append(weightTrend)
        }
        
        await MainActor.run {
            self.healthTrends = trends
        }
    }
    
    private func analyzeMetricTrend<T: Numeric>(
        data: [HealthData],
        keyPath: KeyPath<HealthData, T?>,
        metricName: String,
        unit: String,
        valueTransform: ((T) -> Double)? = nil
    ) -> HealthTrend? {
        let values = data.compactMap { $0[keyPath: keyPath] }
        guard values.count >= 3 else { return nil }
        
        let doubleValues = values.compactMap { value -> Double? in
            if let transform = valueTransform {
                return transform(value)
            } else if let doubleValue = value as? Double {
                return doubleValue
            } else if let intValue = value as? Int {
                return Double(intValue)
            }
            return nil
        }
        
        guard doubleValues.count >= 3 else { return nil }
        
        let trend = calculateTrendDirection(doubleValues)
        let average = doubleValues.reduce(0, +) / Double(doubleValues.count)
        let variance = calculateVariance(doubleValues, mean: average)
        
        let insight = generateTrendInsight(
            metricName: metricName,
            trend: trend,
            average: average,
            variance: variance,
            unit: unit
        )
        
        return HealthTrend(
            metricName: metricName,
            direction: trend,
            strength: calculateTrendStrength(doubleValues),
            timeRange: "\(data.count) days",
            insight: insight,
            currentValue: doubleValues.last ?? 0,
            averageValue: average,
            unit: unit
        )
    }
    
    private func calculateTrendDirection(_ values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let percentChange = (secondAverage - firstAverage) / firstAverage * 100
        
        if percentChange > 5 {
            return .increasing
        } else if percentChange < -5 {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateTrendStrength(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        
        let linearRegression = calculateLinearRegression(values)
        return abs(linearRegression.correlation)
    }
    
    private func calculateLinearRegression(_ values: [Double]) -> (slope: Double, correlation: Double) {
        let n = Double(values.count)
        let x = Array(0..<values.count).map { Double($0) }
        
        let xMean = x.reduce(0, +) / n
        let yMean = values.reduce(0, +) / n
        
        let numerator = zip(x, values).reduce(0) { result, pair in
            result + (pair.0 - xMean) * (pair.1 - yMean)
        }
        
        let xDenominator = x.reduce(0) { result, value in
            result + pow(value - xMean, 2)
        }
        
        let yDenominator = values.reduce(0) { result, value in
            result + pow(value - yMean, 2)
        }
        
        let slope = numerator / xDenominator
        let correlation = numerator / sqrt(xDenominator * yDenominator)
        
        return (slope, correlation)
    }
    
    private func calculateVariance(_ values: [Double], mean: Double) -> Double {
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count)
    }
    
    private func generateTrendInsight(metricName: String, trend: TrendDirection, average: Double, variance: Double, unit: String) -> String {
        switch trend {
        case .increasing:
            return "\(metricName) is trending upward with an average of \(String(format: "%.1f", average)) \(unit). This shows positive progress."
        case .decreasing:
            return "\(metricName) is trending downward with an average of \(String(format: "%.1f", average)) \(unit). Consider focusing on improvement."
        case .stable:
            return "\(metricName) remains stable with an average of \(String(format: "%.1f", average)) \(unit). Consistency is being maintained."
        }
    }
}

struct NoteHealthEnrichment {
    let noteId: UUID
    let noteDate: Date
    let healthCorrelations: [HealthCorrelation]
    let healthContext: HealthContext
    let insights: [HealthInsight]
    let suggestions: [HealthSuggestion]
    let enrichmentScore: Double
}

@Model
class NoteHealthCorrelation {
    var noteId: UUID
    var noteDate: Date
    var enrichmentScore: Double
    var insightsData: Data
    var suggestionsData: Data
    var contextData: Data
    var createdAt: Date
    
    init(noteId: UUID, noteDate: Date, enrichmentScore: Double, insights: [HealthInsight], suggestions: [HealthSuggestion], healthContext: HealthContext) {
        self.noteId = noteId
        self.noteDate = noteDate
        self.enrichmentScore = enrichmentScore
        self.createdAt = Date()
        
        self.insightsData = (try? JSONEncoder().encode(insights)) ?? Data()
        self.suggestionsData = (try? JSONEncoder().encode(suggestions)) ?? Data()
        self.contextData = (try? JSONEncoder().encode(healthContext)) ?? Data()
    }
    
    var insights: [HealthInsight] {
        (try? JSONDecoder().decode([HealthInsight].self, from: insightsData)) ?? []
    }
    
    var suggestions: [HealthSuggestion] {
        (try? JSONDecoder().decode([HealthSuggestion].self, from: suggestionsData)) ?? []
    }
    
    var healthContext: HealthContext {
        (try? JSONDecoder().decode(HealthContext.self, from: contextData)) ?? HealthContext()
    }
}

struct HealthContext: Codable {
    let timeOfDay: TimeOfDay
    let activityLevel: ActivityLevel
    let wellnessState: WellnessState
    let physiologicalState: PhysiologicalState
    let environmentalFactors: [String]
    
    init(
        timeOfDay: TimeOfDay = .unknown,
        activityLevel: ActivityLevel = .unknown,
        wellnessState: WellnessState = .unknown,
        physiologicalState: PhysiologicalState = .unknown,
        environmentalFactors: [String] = []
    ) {
        self.timeOfDay = timeOfDay
        self.activityLevel = activityLevel
        self.wellnessState = wellnessState
        self.physiologicalState = physiologicalState
        self.environmentalFactors = environmentalFactors
    }
}

struct HealthInsight: Codable, Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let confidence: Double
    let actionable: Bool
    let suggestions: [String]
}

struct HealthSuggestion: Codable, Identifiable {
    let id = UUID()
    let category: String
    let action: String
    let priority: SuggestionPriority
    let estimatedImpact: Double
}

struct HealthTrend: Identifiable {
    let id = UUID()
    let metricName: String
    let direction: TrendDirection
    let strength: Double
    let timeRange: String
    let insight: String
    let currentValue: Double
    let averageValue: Double
    let unit: String
}

enum TimeOfDay: String, Codable, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"
    case unknown = "Unknown"
}

enum ActivityLevel: String, Codable, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case unknown = "Unknown"
}

enum WellnessState: String, Codable, CaseIterable {
    case poor = "Poor"
    case neutral = "Neutral"
    case good = "Good"
    case unknown = "Unknown"
}

enum PhysiologicalState: String, Codable, CaseIterable {
    case stressed = "Stressed"
    case balanced = "Balanced"
    case relaxed = "Relaxed"
    case unknown = "Unknown"
}

enum InsightType: String, Codable, CaseIterable {
    case physiological = "Physiological"
    case activity = "Activity"
    case sleep = "Sleep"
    case mental = "Mental"
    case nutrition = "Nutrition"
}

enum SuggestionPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum TrendDirection: String, CaseIterable {
    case increasing = "Increasing"
    case decreasing = "Decreasing"
    case stable = "Stable"
}