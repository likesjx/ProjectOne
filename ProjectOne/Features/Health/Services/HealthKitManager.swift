import Foundation
import HealthKit
import SwiftData
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private var modelContext: ModelContext?
    
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var error: Error?
    @Published var recentHealthData: [HealthData] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        checkHealthKitAvailability()
    }
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
        
        checkAuthorizationStatus()
    }
    
    private func checkAuthorizationStatus() {
        let readTypes = getHealthDataTypesToRead()
        let writeTypes = getHealthDataTypesToWrite()
        
        for type in readTypes {
            let status = healthStore.authorizationStatus(for: type)
            if status == .sharingDenied {
                self.authorizationStatus = .sharingDenied
                return
            }
        }
        
        self.authorizationStatus = .notDetermined
        self.isAuthorized = false
    }
    
    func requestHealthKitAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let readTypes = getHealthDataTypesToRead()
        let writeTypes = getHealthDataTypesToWrite()
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            
            await MainActor.run {
                self.isAuthorized = true
                self.authorizationStatus = .sharingAuthorized
            }
            
            print("HealthKit authorization granted")
        } catch {
            await MainActor.run {
                self.error = error
                self.isAuthorized = false
            }
            throw HealthKitError.authorizationFailed(error)
        }
    }
    
    private func getHealthDataTypesToRead() -> Set<HKSampleType> {
        var types = Set<HKSampleType>()
        
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        
        if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }
        
        if let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergyType)
        }
        
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        
        if let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weightType)
        }
        
        if let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic) {
            types.insert(systolicType)
        }
        
        if let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            types.insert(diastolicType)
        }
        
        if let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindfulType)
        }
        
        if let workoutType = HKWorkoutType.workoutType() {
            types.insert(workoutType)
        }
        
        return types
    }
    
    private func getHealthDataTypesToWrite() -> Set<HKSampleType> {
        return Set<HKSampleType>()
    }
    
    func fetchRecentHealthData(days: Int = 7) async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        do {
            let healthData = try await fetchHealthDataForDateRange(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.recentHealthData = healthData
            }
            
            await saveHealthDataToDatabase(healthData)
            
        } catch {
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }
    
    private func fetchHealthDataForDateRange(startDate: Date, endDate: Date) async throws -> [HealthData] {
        var healthDataMap: [String: HealthData] = [:]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            
            group.addTask {
                await self.fetchHeartRateData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            group.addTask {
                await self.fetchStepsData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            group.addTask {
                await self.fetchActiveEnergyData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            group.addTask {
                await self.fetchSleepData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            group.addTask {
                await self.fetchWeightData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            group.addTask {
                await self.fetchBloodPressureData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            group.addTask {
                await self.fetchMindfulnessData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            group.addTask {
                await self.fetchWorkoutData(startDate: startDate, endDate: endDate, healthDataMap: &healthDataMap, dateFormatter: dateFormatter)
            }
            
            try await group.waitForAll()
        }
        
        return Array(healthDataMap.values).sorted { $0.date > $1.date }
    }
    
    private func fetchHeartRateData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                let dailyAverages = self.calculateDailyAverages(samples: samples, dateFormatter: dateFormatter)
                
                for (dateKey, value) in dailyAverages {
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: dateFormatter.date(from: dateKey) ?? Date())
                    }
                    healthDataMap[dateKey]?.heartRate = value
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchStepsData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )
            
            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume()
                    return
                }
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let dateKey = dateFormatter.string(from: statistics.startDate)
                    let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: statistics.startDate)
                    }
                    healthDataMap[dateKey]?.steps = steps
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchActiveEnergyData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: DateComponents(day: 1)
            )
            
            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume()
                    return
                }
                
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let dateKey = dateFormatter.string(from: statistics.startDate)
                    let calories = statistics.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                    
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: statistics.startDate)
                    }
                    healthDataMap[dateKey]?.activeEnergyBurned = calories
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchSleepData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume()
                    return
                }
                
                var dailySleepDurations: [String: TimeInterval] = [:]
                
                for sample in samples {
                    let dateKey = dateFormatter.string(from: sample.startDate)
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    dailySleepDurations[dateKey, default: 0] += duration
                }
                
                for (dateKey, duration) in dailySleepDurations {
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: dateFormatter.date(from: dateKey) ?? Date())
                    }
                    healthDataMap[dateKey]?.sleepDuration = duration
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchWeightData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                let dailyAverages = self.calculateDailyAverages(samples: samples, dateFormatter: dateFormatter)
                
                for (dateKey, value) in dailyAverages {
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: dateFormatter.date(from: dateKey) ?? Date())
                    }
                    healthDataMap[dateKey]?.bodyWeight = value
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchBloodPressureData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let systolicQuery = HKSampleQuery(sampleType: systolicType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                let dailyAverages = self.calculateDailyAverages(samples: samples, dateFormatter: dateFormatter)
                
                for (dateKey, value) in dailyAverages {
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: dateFormatter.date(from: dateKey) ?? Date())
                    }
                    healthDataMap[dateKey]?.bloodPressureSystolic = value
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(systolicQuery)
        }
        
        await withCheckedContinuation { continuation in
            let diastolicQuery = HKSampleQuery(sampleType: diastolicType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume()
                    return
                }
                
                let dailyAverages = self.calculateDailyAverages(samples: samples, dateFormatter: dateFormatter)
                
                for (dateKey, value) in dailyAverages {
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: dateFormatter.date(from: dateKey) ?? Date())
                    }
                    healthDataMap[dateKey]?.bloodPressureDiastolic = value
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(diastolicQuery)
        }
    }
    
    private func fetchMindfulnessData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume()
                    return
                }
                
                var dailyMindfulMinutes: [String: TimeInterval] = [:]
                
                for sample in samples {
                    let dateKey = dateFormatter.string(from: sample.startDate)
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    dailyMindfulMinutes[dateKey, default: 0] += duration
                }
                
                for (dateKey, duration) in dailyMindfulMinutes {
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: dateFormatter.date(from: dateKey) ?? Date())
                    }
                    healthDataMap[dateKey]?.mindfulMinutes = duration / 60.0
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func fetchWorkoutData(startDate: Date, endDate: Date, healthDataMap: inout [String: HealthData], dateFormatter: DateFormatter) async {
        let workoutType = HKWorkoutType.workoutType()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                
                guard let samples = samples as? [HKWorkout] else {
                    continuation.resume()
                    return
                }
                
                var dailyWorkouts: [String: (duration: TimeInterval, type: String)] = [:]
                
                for workout in samples {
                    let dateKey = dateFormatter.string(from: workout.startDate)
                    let duration = workout.duration
                    let workoutTypeName = workout.workoutActivityType.displayName
                    
                    if let existing = dailyWorkouts[dateKey] {
                        dailyWorkouts[dateKey] = (duration: existing.duration + duration, type: existing.type)
                    } else {
                        dailyWorkouts[dateKey] = (duration: duration, type: workoutTypeName)
                    }
                }
                
                for (dateKey, workoutData) in dailyWorkouts {
                    if healthDataMap[dateKey] == nil {
                        healthDataMap[dateKey] = HealthData(date: dateFormatter.date(from: dateKey) ?? Date())
                    }
                    healthDataMap[dateKey]?.workoutDuration = workoutData.duration
                    healthDataMap[dateKey]?.workoutType = workoutData.type
                }
                
                continuation.resume()
            }
            
            self.healthStore.execute(query)
        }
    }
    
    private func calculateDailyAverages(samples: [HKQuantitySample], dateFormatter: DateFormatter) -> [String: Double] {
        var dailyValues: [String: [Double]] = [:]
        
        for sample in samples {
            let dateKey = dateFormatter.string(from: sample.startDate)
            let value = sample.quantity.doubleValue(for: sample.quantityType.preferredUnit)
            dailyValues[dateKey, default: []].append(value)
        }
        
        return dailyValues.mapValues { values in
            values.reduce(0, +) / Double(values.count)
        }
    }
    
    private func saveHealthDataToDatabase(_ healthData: [HealthData]) async {
        guard let modelContext = modelContext else { return }
        
        for data in healthData {
            modelContext.insert(data)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save health data: \(error)")
        }
    }
    
    func getHealthDataCorrelations(with noteId: UUID, date: Date, timeWindow: TimeInterval = 3600) async -> [HealthCorrelation] {
        let startDate = date.addingTimeInterval(-timeWindow)
        let endDate = date.addingTimeInterval(timeWindow)
        
        let relevantHealthData = recentHealthData.filter { healthData in
            healthData.date >= startDate && healthData.date <= endDate
        }
        
        return relevantHealthData.map { healthData in
            let correlationStrength = calculateCorrelationStrength(healthData: healthData, noteDate: date)
            let insights = generateHealthInsights(healthData: healthData)
            
            return HealthCorrelation(
                date: healthData.date,
                healthData: healthData,
                noteId: noteId,
                correlationStrength: correlationStrength,
                insights: insights
            )
        }.sorted { $0.correlationStrength > $1.correlationStrength }
    }
    
    private func calculateCorrelationStrength(healthData: HealthData, noteDate: Date) -> Double {
        let timeDifference = abs(healthData.date.timeIntervalSince(noteDate))
        let maxTime: TimeInterval = 3600
        
        let timeProximity = max(0, 1 - (timeDifference / maxTime))
        
        var dataRichness = 0.0
        if healthData.heartRate != nil { dataRichness += 0.2 }
        if healthData.steps != nil { dataRichness += 0.15 }
        if healthData.activeEnergyBurned != nil { dataRichness += 0.15 }
        if healthData.sleepDuration != nil { dataRichness += 0.2 }
        if healthData.bodyWeight != nil { dataRichness += 0.1 }
        if healthData.bloodPressureSystolic != nil && healthData.bloodPressureDiastolic != nil { dataRichness += 0.15 }
        if healthData.mindfulMinutes != nil { dataRichness += 0.05 }
        
        return timeProximity * dataRichness
    }
    
    private func generateHealthInsights(healthData: HealthData) -> [String] {
        var insights: [String] = []
        
        if let heartRate = healthData.heartRate {
            if heartRate > 100 {
                insights.append("Elevated heart rate detected - may indicate stress or physical activity")
            } else if heartRate < 60 {
                insights.append("Low resting heart rate - indicates good cardiovascular fitness")
            }
        }
        
        if let steps = healthData.steps {
            if steps > 10000 {
                insights.append("Excellent daily activity - exceeded 10k steps goal")
            } else if steps < 5000 {
                insights.append("Low activity day - consider increasing movement")
            }
        }
        
        if let sleepDuration = healthData.sleepDuration {
            let hours = sleepDuration / 3600
            if hours < 6 {
                insights.append("Insufficient sleep detected - may impact cognitive performance")
            } else if hours > 9 {
                insights.append("Extended sleep period - consider sleep quality assessment")
            }
        }
        
        if let mindfulMinutes = healthData.mindfulMinutes, mindfulMinutes > 0 {
            insights.append("Mindfulness practice detected - positive impact on mental well-being")
        }
        
        if let workoutDuration = healthData.workoutDuration, workoutDuration > 0 {
            let minutes = workoutDuration / 60
            insights.append("Workout completed: \(Int(minutes)) minutes of \(healthData.workoutType ?? "exercise")")
        }
        
        return insights
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case authorizationFailed(Error)
    case queryFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access not authorized"
        case .authorizationFailed(let error):
            return "HealthKit authorization failed: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "HealthKit query failed: \(error.localizedDescription)"
        }
    }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running:
            return "Running"
        case .walking:
            return "Walking"
        case .cycling:
            return "Cycling"
        case .swimming:
            return "Swimming"
        case .yoga:
            return "Yoga"
        case .strengthTraining:
            return "Strength Training"
        case .dance:
            return "Dance"
        case .hiking:
            return "Hiking"
        case .tennis:
            return "Tennis"
        case .basketball:
            return "Basketball"
        case .soccer:
            return "Soccer"
        case .golf:
            return "Golf"
        default:
            return "Workout"
        }
    }
}

extension HKQuantityType {
    var preferredUnit: HKUnit {
        switch self {
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            return HKUnit(from: "count/min")
        case HKQuantityType.quantityType(forIdentifier: .stepCount):
            return HKUnit.count()
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            return HKUnit.kilocalorie()
        case HKQuantityType.quantityType(forIdentifier: .bodyMass):
            return HKUnit.gramUnit(with: .kilo)
        case HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
             HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic):
            return HKUnit.millimeterOfMercury()
        default:
            return HKUnit.count()
        }
    }
}