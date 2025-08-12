import Foundation
import HealthKit
import SwiftData

@Model
class HealthData {
    var id: UUID
    var date: Date
    var heartRate: Double?
    var steps: Double?
    var activeEnergyBurned: Double?
    var sleepDuration: Double?
    var bodyWeight: Double?
    var bloodPressureSystolic: Double?
    var bloodPressureDiastolic: Double?
    var mindfulMinutes: Double?
    var workoutDuration: Double?
    var workoutType: String?
    var sourceIdentifier: String
    var createdAt: Date
    var updatedAt: Date
    
    init(
        date: Date = Date(),
        heartRate: Double? = nil,
        steps: Double? = nil,
        activeEnergyBurned: Double? = nil,
        sleepDuration: Double? = nil,
        bodyWeight: Double? = nil,
        bloodPressureSystolic: Double? = nil,
        bloodPressureDiastolic: Double? = nil,
        mindfulMinutes: Double? = nil,
        workoutDuration: Double? = nil,
        workoutType: String? = nil,
        sourceIdentifier: String = "ProjectOne"
    ) {
        self.id = UUID()
        self.date = date
        self.heartRate = heartRate
        self.steps = steps
        self.activeEnergyBurned = activeEnergyBurned
        self.sleepDuration = sleepDuration
        self.bodyWeight = bodyWeight
        self.bloodPressureSystolic = bloodPressureSystolic
        self.bloodPressureDiastolic = bloodPressureDiastolic
        self.mindfulMinutes = mindfulMinutes
        self.workoutDuration = workoutDuration
        self.workoutType = workoutType
        self.sourceIdentifier = sourceIdentifier
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension HealthData {
    var hasCardioData: Bool {
        heartRate != nil || bloodPressureSystolic != nil || bloodPressureDiastolic != nil
    }
    
    var hasActivityData: Bool {
        steps != nil || activeEnergyBurned != nil || workoutDuration != nil
    }
    
    var hasWellnessData: Bool {
        sleepDuration != nil || mindfulMinutes != nil
    }
    
    var hasBodyMetrics: Bool {
        bodyWeight != nil
    }
    
    func summarizeMetrics() -> String {
        var summary: [String] = []
        
        if let heartRate = heartRate {
            summary.append("Heart Rate: \(Int(heartRate)) bpm")
        }
        
        if let steps = steps {
            summary.append("Steps: \(Int(steps))")
        }
        
        if let calories = activeEnergyBurned {
            summary.append("Calories: \(Int(calories))")
        }
        
        if let sleep = sleepDuration {
            let hours = sleep / 3600
            summary.append("Sleep: \(String(format: "%.1f", hours))h")
        }
        
        if let weight = bodyWeight {
            summary.append("Weight: \(String(format: "%.1f", weight)) kg")
        }
        
        if let systolic = bloodPressureSystolic, let diastolic = bloodPressureDiastolic {
            summary.append("BP: \(Int(systolic))/\(Int(diastolic))")
        }
        
        if let mindful = mindfulMinutes {
            summary.append("Mindfulness: \(Int(mindful))min")
        }
        
        if let workout = workoutDuration, let type = workoutType {
            let workoutMin = workout / 60
            summary.append("\(type): \(Int(workoutMin))min")
        }
        
        return summary.isEmpty ? "No metrics available" : summary.joined(separator: ", ")
    }
}

struct HealthCorrelation {
    let date: Date
    let healthData: HealthData
    let noteId: UUID?
    let correlationStrength: Double
    let insights: [String]
    
    init(date: Date, healthData: HealthData, noteId: UUID? = nil, correlationStrength: Double = 0.0, insights: [String] = []) {
        self.date = date
        self.healthData = healthData
        self.noteId = noteId
        self.correlationStrength = correlationStrength
        self.insights = insights
    }
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

enum HealthDataType: String, CaseIterable {
    case heartRate = "Heart Rate"
    case steps = "Steps"
    case activeEnergyBurned = "Active Energy"
    case sleepDuration = "Sleep"
    case bodyWeight = "Weight"
    case bloodPressure = "Blood Pressure"
    case mindfulMinutes = "Mindfulness"
    case workout = "Workout"
    
    var hkQuantityType: HKQuantityType? {
        switch self {
        case .heartRate:
            return HKQuantityType.quantityType(forIdentifier: .heartRate)
        case .steps:
            return HKQuantityType.quantityType(forIdentifier: .stepCount)
        case .activeEnergyBurned:
            return HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        case .sleepDuration:
            return HKQuantityType.quantityType(forIdentifier: .sleepDurationGoal)
        case .bodyWeight:
            return HKQuantityType.quantityType(forIdentifier: .bodyMass)
        case .bloodPressure:
            return nil
        case .mindfulMinutes:
            return HKQuantityType.quantityType(forIdentifier: .mindfulSession)
        case .workout:
            return nil
        }
    }
    
    var hkCategoryType: HKCategoryType? {
        switch self {
        case .sleepDuration:
            return HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)
        case .mindfulMinutes:
            return HKCategoryType.categoryType(forIdentifier: .mindfulSession)
        default:
            return nil
        }
    }
    
    var unit: String {
        switch self {
        case .heartRate:
            return "bpm"
        case .steps:
            return "steps"
        case .activeEnergyBurned:
            return "kcal"
        case .sleepDuration:
            return "hours"
        case .bodyWeight:
            return "kg"
        case .bloodPressure:
            return "mmHg"
        case .mindfulMinutes:
            return "minutes"
        case .workout:
            return "minutes"
        }
    }
}