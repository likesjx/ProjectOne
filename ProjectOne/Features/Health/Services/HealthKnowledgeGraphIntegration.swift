import Foundation
import SwiftData
import Combine

@MainActor
class HealthKnowledgeGraphIntegration: ObservableObject {
    private let modelContext: ModelContext
    private let healthKitManager: HealthKitManager
    private let healthEnrichment: HealthEnrichment
    
    @Published var healthEntities: [Entity] = []
    @Published var healthRelationships: [Relationship] = []
    @Published var isProcessing = false
    
    init(modelContext: ModelContext, healthKitManager: HealthKitManager, healthEnrichment: HealthEnrichment) {
        self.modelContext = modelContext
        self.healthKitManager = healthKitManager
        self.healthEnrichment = healthEnrichment
    }
    
    func processHealthDataIntoKnowledgeGraph() async {
        isProcessing = true
        defer { isProcessing = false }
        
        let healthData = healthKitManager.recentHealthData
        
        for data in healthData {
            await createHealthEntitiesAndRelationships(from: data)
        }
        
        await linkHealthDataWithNotes()
        await generateHealthInsightEntities()
    }
    
    private func createHealthEntitiesAndRelationships(from healthData: HealthData) async {
        let dateEntity = await findOrCreateDateEntity(healthData.date)
        
        if let heartRate = healthData.heartRate {
            let heartRateEntity = await createMetricEntity(
                name: "Heart Rate",
                value: heartRate,
                unit: "bpm",
                date: healthData.date,
                type: .concept
            )
            
            await createRelationship(
                from: dateEntity,
                to: heartRateEntity,
                predicate: .hasHealthMetric,
                importance: calculateMetricImportance(heartRate, normal: 60...100)
            )
        }
        
        if let steps = healthData.steps {
            let stepsEntity = await createMetricEntity(
                name: "Daily Steps",
                value: steps,
                unit: "steps",
                date: healthData.date,
                type: .activity
            )
            
            await createRelationship(
                from: dateEntity,
                to: stepsEntity,
                predicate: .hasHealthMetric,
                importance: calculateMetricImportance(steps, target: 10000)
            )
            
            if steps >= 10000 {
                let goalEntity = await findOrCreateConceptEntity("Step Goal Achievement")
                await createRelationship(
                    from: stepsEntity,
                    to: goalEntity,
                    predicate: .achieves,
                    importance: 0.8
                )
            }
        }
        
        if let calories = healthData.activeEnergyBurned {
            let caloriesEntity = await createMetricEntity(
                name: "Active Calories",
                value: calories,
                unit: "kcal",
                date: healthData.date,
                type: .activity
            )
            
            await createRelationship(
                from: dateEntity,
                to: caloriesEntity,
                predicate: .hasHealthMetric,
                importance: calculateMetricImportance(calories, target: 400)
            )
        }
        
        if let sleepDuration = healthData.sleepDuration {
            let hours = sleepDuration / 3600
            let sleepEntity = await createMetricEntity(
                name: "Sleep Duration",
                value: hours,
                unit: "hours",
                date: healthData.date,
                type: .activity
            )
            
            await createRelationship(
                from: dateEntity,
                to: sleepEntity,
                predicate: .hasHealthMetric,
                importance: calculateMetricImportance(hours, normal: 7...9)
            )
            
            if hours < 6 {
                let sleepDeprivationEntity = await findOrCreateConceptEntity("Sleep Deprivation")
                await createRelationship(
                    from: sleepEntity,
                    to: sleepDeprivationEntity,
                    predicate: .indicates,
                    importance: 0.9
                )
            } else if hours >= 7 && hours <= 9 {
                let goodSleepEntity = await findOrCreateConceptEntity("Quality Sleep")
                await createRelationship(
                    from: sleepEntity,
                    to: goodSleepEntity,
                    predicate: .indicates,
                    importance: 0.7
                )
            }
        }
        
        if let weight = healthData.bodyWeight {
            let weightEntity = await createMetricEntity(
                name: "Body Weight",
                value: weight,
                unit: "kg",
                date: healthData.date,
                type: .concept
            )
            
            await createRelationship(
                from: dateEntity,
                to: weightEntity,
                predicate: .hasHealthMetric,
                importance: 0.6
            )
        }
        
        if let systolic = healthData.bloodPressureSystolic,
           let diastolic = healthData.bloodPressureDiastolic {
            let bpEntity = await createBloodPressureEntity(
                systolic: systolic,
                diastolic: diastolic,
                date: healthData.date
            )
            
            await createRelationship(
                from: dateEntity,
                to: bpEntity,
                predicate: .hasHealthMetric,
                importance: calculateBloodPressureImportance(systolic: systolic, diastolic: diastolic)
            )
        }
        
        if let mindfulMinutes = healthData.mindfulMinutes, mindfulMinutes > 0 {
            let mindfulnessEntity = await createMetricEntity(
                name: "Mindfulness Practice",
                value: mindfulMinutes,
                unit: "minutes",
                date: healthData.date,
                type: .activity
            )
            
            await createRelationship(
                from: dateEntity,
                to: mindfulnessEntity,
                predicate: .hasHealthMetric,
                importance: 0.8
            )
            
            let wellbeingEntity = await findOrCreateConceptEntity("Mental Wellbeing")
            await createRelationship(
                from: mindfulnessEntity,
                to: wellbeingEntity,
                predicate: .improves,
                importance: 0.7
            )
        }
        
        if let workoutDuration = healthData.workoutDuration,
           let workoutType = healthData.workoutType,
           workoutDuration > 0 {
            let workoutEntity = await createWorkoutEntity(
                type: workoutType,
                duration: workoutDuration,
                date: healthData.date
            )
            
            await createRelationship(
                from: dateEntity,
                to: workoutEntity,
                predicate: .hasHealthMetric,
                importance: 0.8
            )
            
            let fitnessEntity = await findOrCreateConceptEntity("Physical Fitness")
            await createRelationship(
                from: workoutEntity,
                to: fitnessEntity,
                predicate: .improves,
                importance: 0.8
            )
        }
    }
    
    private func linkHealthDataWithNotes() async {
        let noteFetchDescriptor = FetchDescriptor<NoteItem>()
        
        do {
            let notes = try modelContext.fetch(noteFetchDescriptor)
            
            for note in notes {
                await linkNoteWithHealthData(note)
            }
        } catch {
            print("Error fetching notes for health integration: \(error)")
        }
    }
    
    private func linkNoteWithHealthData(_ note: NoteItem) async {
        let correlations = await healthKitManager.getHealthDataCorrelations(
            with: note.id,
            date: note.timestamp,
            timeWindow: 3600 // 1 hour window
        )
        
        for correlation in correlations {
            if correlation.correlationStrength > 0.3 {
                let noteEntity = await findOrCreateNoteEntity(note)
                let healthDateEntity = await findOrCreateDateEntity(correlation.healthData.date)
                
                await createRelationship(
                    from: noteEntity,
                    to: healthDateEntity,
                    predicate: .correlatesWithHealth,
                    importance: correlation.correlationStrength
                )
                
                if correlation.healthData.hasCardioData {
                    let cardioEntity = await findOrCreateConceptEntity("Cardiovascular Health")
                    await createRelationship(
                        from: noteEntity,
                        to: cardioEntity,
                        predicate: .relatesTo,
                        importance: correlation.correlationStrength
                    )
                }
                
                if correlation.healthData.hasActivityData {
                    let activityEntity = await findOrCreateConceptEntity("Physical Activity")
                    await createRelationship(
                        from: noteEntity,
                        to: activityEntity,
                        predicate: .relatesTo,
                        importance: correlation.correlationStrength
                    )
                }
                
                if correlation.healthData.hasWellnessData {
                    let wellnessEntity = await findOrCreateConceptEntity("Mental Wellness")
                    await createRelationship(
                        from: noteEntity,
                        to: wellnessEntity,
                        predicate: .relatesTo,
                        importance: correlation.correlationStrength
                    )
                }
            }
        }
    }
    
    private func generateHealthInsightEntities() async {
        let trends = healthEnrichment.healthTrends
        
        for trend in trends {
            let trendEntity = await createTrendEntity(trend)
            let metricEntity = await findOrCreateConceptEntity(trend.metricName)
            
            await createRelationship(
                from: trendEntity,
                to: metricEntity,
                predicate: .analyzes,
                importance: trend.strength
            )
            
            if trend.direction == .increasing && trend.strength > 0.7 {
                let improvementEntity = await findOrCreateConceptEntity("Health Improvement")
                await createRelationship(
                    from: trendEntity,
                    to: improvementEntity,
                    predicate: .indicates,
                    importance: trend.strength
                )
            } else if trend.direction == .decreasing && trend.strength > 0.7 {
                let concernEntity = await findOrCreateConceptEntity("Health Concern")
                await createRelationship(
                    from: trendEntity,
                    to: concernEntity,
                    predicate: .indicates,
                    importance: trend.strength
                )
            }
        }
    }
    
    private func findOrCreateDateEntity(_ date: Date) async -> Entity {
        let dateString = DateFormatter.healthDateFormatter.string(from: date)
        
        if let existingEntity = await findEntityByName(dateString, type: .event) {
            return existingEntity
        }
        
        let entity = Entity(name: dateString, type: .event)
        entity.entityDescription = "Health data collection date"
        entity.setAttribute("date", value: dateString)
        entity.setAttribute("source", value: "HealthKit")
        entity.confidence = 1.0
        entity.isValidated = true
        entity.importance = 0.5
        
        modelContext.insert(entity)
        return entity
    }
    
    private func createMetricEntity(name: String, value: Double, unit: String, date: Date, type: EntityType) async -> Entity {
        let metricName = "\(name) (\(String(format: "%.1f", value)) \(unit))"
        
        let entity = Entity(name: metricName, type: type)
        entity.entityDescription = "Health metric recorded on \(DateFormatter.healthDateFormatter.string(from: date))"
        entity.setAttribute("metric_type", value: name)
        entity.setAttribute("value", value: String(value))
        entity.setAttribute("unit", value: unit)
        entity.setAttribute("date", value: DateFormatter.healthDateFormatter.string(from: date))
        entity.setAttribute("source", value: "HealthKit")
        entity.confidence = 1.0
        entity.isValidated = true
        entity.importance = 0.7
        
        modelContext.insert(entity)
        return entity
    }
    
    private func createBloodPressureEntity(systolic: Double, diastolic: Double, date: Date) async -> Entity {
        let bpValue = "\(Int(systolic))/\(Int(diastolic)) mmHg"
        let entity = Entity(name: "Blood Pressure (\(bpValue))", type: .concept)
        entity.entityDescription = "Blood pressure reading recorded on \(DateFormatter.healthDateFormatter.string(from: date))"
        entity.setAttribute("systolic", value: String(systolic))
        entity.setAttribute("diastolic", value: String(diastolic))
        entity.setAttribute("date", value: DateFormatter.healthDateFormatter.string(from: date))
        entity.setAttribute("source", value: "HealthKit")
        entity.confidence = 1.0
        entity.isValidated = true
        entity.importance = 0.8
        
        modelContext.insert(entity)
        return entity
    }
    
    private func createWorkoutEntity(type: String, duration: Double, date: Date) async -> Entity {
        let durationMinutes = duration / 60
        let workoutName = "\(type) Workout (\(Int(durationMinutes)) min)"
        
        let entity = Entity(name: workoutName, type: .activity)
        entity.entityDescription = "Workout activity recorded on \(DateFormatter.healthDateFormatter.string(from: date))"
        entity.setAttribute("workout_type", value: type)
        entity.setAttribute("duration", value: String(duration))
        entity.setAttribute("duration_minutes", value: String(durationMinutes))
        entity.setAttribute("date", value: DateFormatter.healthDateFormatter.string(from: date))
        entity.setAttribute("source", value: "HealthKit")
        entity.confidence = 1.0
        entity.isValidated = true
        entity.importance = 0.8
        
        modelContext.insert(entity)
        return entity
    }
    
    private func createTrendEntity(_ trend: HealthTrend) async -> Entity {
        let trendName = "\(trend.metricName) Trend (\(trend.direction.rawValue))"
        
        let entity = Entity(name: trendName, type: .concept)
        entity.entityDescription = trend.insight
        entity.setAttribute("metric", value: trend.metricName)
        entity.setAttribute("direction", value: trend.direction.rawValue)
        entity.setAttribute("strength", value: String(trend.strength))
        entity.setAttribute("time_range", value: trend.timeRange)
        entity.setAttribute("current_value", value: String(trend.currentValue))
        entity.setAttribute("average_value", value: String(trend.averageValue))
        entity.setAttribute("unit", value: trend.unit)
        entity.setAttribute("source", value: "HealthKit Analysis")
        entity.confidence = trend.strength
        entity.isValidated = false
        entity.importance = trend.strength
        
        modelContext.insert(entity)
        return entity
    }
    
    private func findOrCreateNoteEntity(_ note: NoteItem) async -> Entity {
        if let existingEntity = await findEntityByName(note.title, type: .concept) {
            return existingEntity
        }
        
        let entity = Entity(name: note.title, type: .concept)
        entity.entityDescription = String(note.content.prefix(100))
        entity.setAttribute("note_id", value: note.id.uuidString)
        entity.setAttribute("created_at", value: DateFormatter.healthDateFormatter.string(from: note.timestamp))
        entity.setAttribute("source", value: "Voice Memo")
        entity.confidence = 0.8
        entity.isValidated = false
        entity.importance = 0.6
        
        modelContext.insert(entity)
        return entity
    }
    
    private func findOrCreateConceptEntity(_ conceptName: String) async -> Entity {
        if let existingEntity = await findEntityByName(conceptName, type: .concept) {
            return existingEntity
        }
        
        let entity = Entity(name: conceptName, type: .concept)
        entity.entityDescription = "Health-related concept automatically identified"
        entity.setAttribute("source", value: "Health Analysis")
        entity.confidence = 0.7
        entity.isValidated = false
        entity.importance = 0.6
        
        modelContext.insert(entity)
        return entity
    }
    
    private func findEntityByName(_ name: String, type: EntityType) async -> Entity? {
        let descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate<Entity> { entity in
                entity.name == name && entity.type == type
            }
        )
        
        do {
            let entities = try modelContext.fetch(descriptor)
            return entities.first
        } catch {
            print("Error finding entity: \(error)")
            return nil
        }
    }
    
    private func createRelationship(from subject: Entity, to object: Entity, predicate: RelationshipPredicate, importance: Double) async {
        let relationship = Relationship(
            subjectEntityId: subject.id,
            objectEntityId: object.id,
            predicateType: predicate
        )
        relationship.importance = importance
        relationship.confidence = 0.8
        relationship.isValidated = false
        relationship.extractionSource = "Health Analysis"
        
        modelContext.insert(relationship)
        
        subject.addRelationship(relationship.id)
        object.addRelationship(relationship.id)
    }
    
    private func calculateMetricImportance(_ value: Double, normal: ClosedRange<Double>) -> Double {
        if normal.contains(value) {
            return 0.5
        } else {
            let distance = min(abs(value - normal.lowerBound), abs(value - normal.upperBound))
            let range = normal.upperBound - normal.lowerBound
            return min(1.0, 0.5 + (distance / range) * 0.5)
        }
    }
    
    private func calculateMetricImportance(_ value: Double, target: Double) -> Double {
        let ratio = value / target
        if ratio >= 1.0 {
            return min(1.0, 0.7 + (ratio - 1.0) * 0.3)
        } else {
            return 0.3 + ratio * 0.4
        }
    }
    
    private func calculateBloodPressureImportance(systolic: Double, diastolic: Double) -> Double {
        if systolic < 120 && diastolic < 80 {
            return 0.3 // Normal
        } else if systolic < 130 && diastolic < 80 {
            return 0.5 // Elevated
        } else if (systolic >= 130 && systolic < 140) || (diastolic >= 80 && diastolic < 90) {
            return 0.7 // Stage 1 Hypertension
        } else if systolic >= 140 || diastolic >= 90 {
            return 0.9 // Stage 2 Hypertension
        } else if systolic >= 180 || diastolic >= 120 {
            return 1.0 // Hypertensive Crisis
        } else {
            return 0.5
        }
    }
    
    func getHealthRelatedEntities() -> [Entity] {
        let descriptor = FetchDescriptor<Entity>(
            predicate: #Predicate<Entity> { entity in
                entity.attributes.keys.contains("source") && 
                (entity.attributes["source"] == "HealthKit" || 
                 entity.attributes["source"] == "Health Analysis")
            }
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching health entities: \(error)")
            return []
        }
    }
    
    func getHealthRelatedRelationships() -> [Relationship] {
        let descriptor = FetchDescriptor<Relationship>(
            predicate: #Predicate<Relationship> { relationship in
                relationship.extractionSource == "Health Analysis"
            }
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching health relationships: \(error)")
            return []
        }
    }
}

extension DateFormatter {
    static let healthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

enum RelationshipPredicate: String, CaseIterable, Codable {
    case hasHealthMetric = "has_health_metric"
    case correlatesWithHealth = "correlates_with_health"
    case indicates = "indicates"
    case improves = "improves"
    case achieves = "achieves"
    case analyzes = "analyzes"
    case relatesTo = "relates_to"
    
    var category: RelationshipCategory {
        switch self {
        case .hasHealthMetric, .correlatesWithHealth:
            return .temporal
        case .indicates, .analyzes:
            return .analytical
        case .improves, .achieves:
            return .causal
        case .relatesTo:
            return .semantic
        }
    }
    
    var displayName: String {
        switch self {
        case .hasHealthMetric:
            return "has health metric"
        case .correlatesWithHealth:
            return "correlates with health"
        case .indicates:
            return "indicates"
        case .improves:
            return "improves"
        case .achieves:
            return "achieves"
        case .analyzes:
            return "analyzes"
        case .relatesTo:
            return "relates to"
        }
    }
}

extension EntityType {
    static let healthMetric: EntityType = .concept
    static let healthInsight: EntityType = .concept
    static let healthTrend: EntityType = .concept
}