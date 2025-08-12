//
//  ConceptNode.swift
//  ProjectOne
//
//  Created by Jared Likes on 7/6/25.
//

import Foundation
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class ConceptNode {
    var id: UUID
    var name: String
    var definition: String?
    var conceptType: ConceptType
    var abstraction: AbstractionLevel
    var importance: Double
    var confidence: Double
    @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformer"))
    var relatedConcepts: [UUID]
    @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformer"))
    var relatedEntities: [UUID]
    @Attribute(.transformable(by: "NSSecureUnarchiveFromDataTransformer"))
    var relatedNotes: [UUID]
    var properties: [String: String]
    var examples: [String]
    var counterExamples: [String]
    var createdDate: Date
    var lastUpdated: Date
    var accessCount: Int
    var strengthScore: Double
    
    init(
        name: String,
        definition: String? = nil,
        conceptType: ConceptType = .general,
        abstraction: AbstractionLevel = .intermediate,
        importance: Double = 0.5,
        confidence: Double = 0.5,
        properties: [String: String] = [:],
        examples: [String] = [],
        counterExamples: [String] = []
    ) {
        self.id = UUID()
        self.name = name
        self.definition = definition
        self.conceptType = conceptType
        self.abstraction = abstraction
        self.importance = importance
        self.confidence = confidence
        self.relatedConcepts = []
        self.relatedEntities = []
        self.relatedNotes = []
        self.properties = properties
        self.examples = examples
        self.counterExamples = counterExamples
        self.createdDate = Date()
        self.lastUpdated = Date()
        self.accessCount = 0
        self.strengthScore = confidence
    }
    
    // MARK: - Concept Management
    
    func access() {
        accessCount += 1
        lastUpdated = Date()
        strengthScore = min(strengthScore + 0.05, 1.0)
    }
    
    func addRelatedConcept(_ conceptId: UUID, strength: Double = 0.5) {
        if !relatedConcepts.contains(conceptId) {
            relatedConcepts.append(conceptId)
            strengthScore = min(strengthScore + (strength * 0.1), 1.0)
            lastUpdated = Date()
        }
    }
    
    func addExample(_ example: String) {
        if !examples.contains(example) {
            examples.append(example)
            confidence = min(confidence + 0.1, 1.0)
            lastUpdated = Date()
        }
    }
    
    func addCounterExample(_ counterExample: String) {
        if !counterExamples.contains(counterExample) {
            counterExamples.append(counterExample)
            confidence = min(confidence + 0.05, 1.0)
            lastUpdated = Date()
        }
    }
    
    func updateDefinition(_ newDefinition: String) {
        definition = newDefinition
        confidence = min(confidence + 0.2, 1.0)
        lastUpdated = Date()
    }
    
    func setProperty(_ key: String, value: String) {
        properties[key] = value
        lastUpdated = Date()
    }
    
    var isWellDefined: Bool {
        return definition != nil && 
               !examples.isEmpty && 
               confidence > 0.7 && 
               strengthScore > 0.6
    }
    
    var conceptualDepth: Double {
        let exampleFactor = min(Double(examples.count) * 0.1, 0.5)
        let relationFactor = min(Double(relatedConcepts.count) * 0.05, 0.3)
        let propertyFactor = min(Double(properties.count) * 0.05, 0.2)
        
        return confidence + exampleFactor + relationFactor + propertyFactor
    }
}

enum ConceptType: String, Codable, CaseIterable {
    case general = "general"
    case domain = "domain"
    case method = "method"
    case principle = "principle"
    case pattern = "pattern"
    case category = "category"
    case process = "process"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .domain: return "Domain"
        case .method: return "Method"
        case .principle: return "Principle"
        case .pattern: return "Pattern"
        case .category: return "Category"
        case .process: return "Process"
        case .system: return "System"
        }
    }
}

enum AbstractionLevel: String, Codable, CaseIterable {
    case concrete = "concrete"
    case intermediate = "intermediate"
    case abstract = "abstract"
    case meta = "meta"
    
    var displayName: String {
        switch self {
        case .concrete: return "Concrete"
        case .intermediate: return "Intermediate"
        case .abstract: return "Abstract"
        case .meta: return "Meta"
        }
    }
    
    var complexityScore: Double {
        switch self {
        case .concrete: return 0.2
        case .intermediate: return 0.5
        case .abstract: return 0.8
        case .meta: return 1.0
        }
    }
}