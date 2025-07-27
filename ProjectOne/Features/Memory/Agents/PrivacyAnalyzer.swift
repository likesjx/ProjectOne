//
//  PrivacyAnalyzer.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/15/25.
//

import Foundation
import os.log

/// Privacy analyzer for determining data sensitivity and routing decisions
public class PrivacyAnalyzer {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "PrivacyAnalyzer")
    
    // MARK: - Privacy Classification
    
    public enum PrivacyLevel: CustomStringConvertible {
        case publicKnowledge    // General facts, public information
        case contextual         // Information that could be personal in context
        case personal          // Clearly personal information
        case sensitive         // Highly sensitive personal data
        
        public var description: String {
            switch self {
            case .publicKnowledge:
                return "public knowledge"
            case .contextual:
                return "contextual"
            case .personal:
                return "personal"
            case .sensitive:
                return "sensitive"
            }
        }
        
        public var requiresOnDevice: Bool {
            switch self {
            case .publicKnowledge:
                return false
            case .contextual, .personal, .sensitive:
                return true
            }
        }
        
        public var maxContextSize: Int {
            switch self {
            case .publicKnowledge:
                return 32768
            case .contextual:
                return 16384
            case .personal:
                return 8192
            case .sensitive:
                return 4096
            }
        }
    }
    
    public struct PrivacyAnalysis {
        let level: PrivacyLevel
        let personalIndicators: [String]
        let sensitiveEntities: [String]
        let riskFactors: [String]
        let confidence: Double
        let requiresOnDevice: Bool
        
        public init(level: PrivacyLevel, personalIndicators: [String] = [], sensitiveEntities: [String] = [], riskFactors: [String] = [], confidence: Double = 1.0) {
            self.level = level
            self.personalIndicators = personalIndicators
            self.sensitiveEntities = sensitiveEntities
            self.riskFactors = riskFactors
            self.confidence = confidence
            self.requiresOnDevice = level.requiresOnDevice
        }
    }
    
    // MARK: - Personal Data Patterns
    
    private let personalPronouns = ["i", "me", "my", "mine", "myself", "we", "us", "our", "ours"]
    private let personalVerbs = ["remember", "recall", "forget", "experienced", "felt", "thought", "believe", "know"]
    private let familyTerms = ["mom", "dad", "mother", "father", "sister", "brother", "family", "spouse", "wife", "husband", "child", "daughter", "son"]
    private let locationIndicators = ["home", "work", "office", "school", "house", "apartment", "address", "street", "city"]
    private let healthTerms = ["health", "doctor", "medication", "symptom", "illness", "treatment", "hospital", "clinic"]
    private let financialTerms = ["money", "bank", "account", "credit", "loan", "income", "salary", "payment", "investment"]
    private let temporalPersonalIndicators = ["yesterday", "today", "tomorrow", "last week", "this morning", "tonight"]
    
    // MARK: - Analysis Methods
    
    public func analyzePrivacy(query: String, context: MemoryContext? = nil) -> PrivacyAnalysis {
        logger.debug("Analyzing privacy for query: '\(query.prefix(50))...'")
        
        let normalizedQuery = query.lowercased()
        var personalIndicators: [String] = []
        var sensitiveEntities: [String] = []
        var riskFactors: [String] = []
        var score = 0.0
        
        // Check for personal pronouns
        let foundPronouns = personalPronouns.filter { normalizedQuery.contains($0) }
        if !foundPronouns.isEmpty {
            personalIndicators.append(contentsOf: foundPronouns)
            score += Double(foundPronouns.count) * 0.3
        }
        
        // Check for personal verbs
        let foundVerbs = personalVerbs.filter { normalizedQuery.contains($0) }
        if !foundVerbs.isEmpty {
            personalIndicators.append(contentsOf: foundVerbs)
            score += Double(foundVerbs.count) * 0.2
        }
        
        // Check for family references
        let foundFamily = familyTerms.filter { normalizedQuery.contains($0) }
        if !foundFamily.isEmpty {
            sensitiveEntities.append(contentsOf: foundFamily)
            score += Double(foundFamily.count) * 0.4
        }
        
        // Check for location indicators
        let foundLocations = locationIndicators.filter { normalizedQuery.contains($0) }
        if !foundLocations.isEmpty {
            sensitiveEntities.append(contentsOf: foundLocations)
            score += Double(foundLocations.count) * 0.3
        }
        
        // Check for health information
        let foundHealth = healthTerms.filter { normalizedQuery.contains($0) }
        if !foundHealth.isEmpty {
            sensitiveEntities.append(contentsOf: foundHealth)
            riskFactors.append("health_information")
            score += Double(foundHealth.count) * 0.6
        }
        
        // Check for financial information
        let foundFinancial = financialTerms.filter { normalizedQuery.contains($0) }
        if !foundFinancial.isEmpty {
            sensitiveEntities.append(contentsOf: foundFinancial)
            riskFactors.append("financial_information")
            score += Double(foundFinancial.count) * 0.5
        }
        
        // Check for temporal personal indicators
        let foundTemporal = temporalPersonalIndicators.filter { normalizedQuery.contains($0) }
        if !foundTemporal.isEmpty {
            personalIndicators.append(contentsOf: foundTemporal)
            score += Double(foundTemporal.count) * 0.2
        }
        
        // Analyze context if provided
        if let context = context {
            let contextScore = analyzeMemoryContext(context)
            score += contextScore
            
            if contextScore > 0.3 {
                riskFactors.append("personal_memory_context")
            }
        }
        
        // Determine privacy level based on score
        let level = determinePrivacyLevel(score: score, riskFactors: riskFactors)
        
        let analysis = PrivacyAnalysis(
            level: level,
            personalIndicators: personalIndicators,
            sensitiveEntities: sensitiveEntities,
            riskFactors: riskFactors,
            confidence: min(1.0, score)
        )
        
        logger.info("Privacy analysis: \(level) (score: \(score), confidence: \(analysis.confidence))")
        
        return analysis
    }
    
    public func analyzeMemoryPrivacy(memory: Any) -> PrivacyAnalysis {
        var content = ""
        var source = ""
        
        switch memory {
        case let stm as STMEntry:
            content = stm.content
            source = stm.memoryType.displayName.lowercased()
        case let ltm as LTMEntry:
            content = "\(ltm.content) \(ltm.summary)"
            source = "long_term_memory"
        case let episodic as EpisodicMemoryEntry:
            content = episodic.eventDescription
            source = "episodic_memory"
        case let note as ProcessedNote:
            content = "\(note.originalText) \(note.summary)"
            source = "user_note"
        default:
            return PrivacyAnalysis(level: .publicKnowledge)
        }
        
        let baseAnalysis = analyzePrivacy(query: content)
        
        // Adjust based on source
        var adjustedLevel = baseAnalysis.level
        var riskFactors = baseAnalysis.riskFactors
        
        if source.contains("transcription") || source.contains("voice") {
            riskFactors.append("voice_data")
            if baseAnalysis.level == .contextual {
                adjustedLevel = .personal
            }
        }
        
        if source.contains("health") {
            riskFactors.append("health_data_source")
            adjustedLevel = .sensitive
        }
        
        return PrivacyAnalysis(
            level: adjustedLevel,
            personalIndicators: baseAnalysis.personalIndicators,
            sensitiveEntities: baseAnalysis.sensitiveEntities,
            riskFactors: riskFactors,
            confidence: baseAnalysis.confidence
        )
    }
    
    // MARK: - Context Analysis
    
    private func analyzeMemoryContext(_ context: MemoryContext) -> Double {
        var score = 0.0
        
        // STM analysis
        for stm in context.shortTermMemories {
            let memoryAnalysis = analyzeMemoryPrivacy(memory: stm)
            switch memoryAnalysis.level {
            case .publicKnowledge:
                score += 0.0
            case .contextual:
                score += 0.1
            case .personal:
                score += 0.3
            case .sensitive:
                score += 0.5
            }
        }
        
        // LTM analysis
        for ltm in context.longTermMemories {
            let memoryAnalysis = analyzeMemoryPrivacy(memory: ltm)
            switch memoryAnalysis.level {
            case .publicKnowledge:
                score += 0.0
            case .contextual:
                score += 0.1
            case .personal:
                score += 0.3
            case .sensitive:
                score += 0.5
            }
        }
        
        // Episodic memory analysis
        for episodic in context.episodicMemories {
            // Episodic memories are inherently personal
            score += 0.4
        }
        
        // Entity analysis - simplified due to generic context
        // Note: Entity analysis disabled until proper Entity type is available
        // let entityCount = context.entities.count
        // if entityCount > 0 {
        //     score += Double(entityCount) * 0.1 // Basic scoring based on entity count
        // }
        
        return min(1.0, score)
    }
    
    // MARK: - Privacy Level Determination
    
    private func determinePrivacyLevel(score: Double, riskFactors: [String]) -> PrivacyLevel {
        // High-risk factors force sensitive classification
        if riskFactors.contains("health_information") || riskFactors.contains("financial_information") {
            return .sensitive
        }
        
        // Score-based classification
        switch score {
        case 0.0..<0.2:
            return .publicKnowledge
        case 0.2..<0.5:
            return .contextual
        case 0.5..<0.8:
            return .personal
        default:
            return .sensitive
        }
    }
    
    // MARK: - Filtering Methods
    
    public func filterPersonalDataFromContext(_ context: MemoryContext, targetLevel: PrivacyLevel) -> MemoryContext {
        var filteredContext = context
        
        switch targetLevel {
        case .publicKnowledge:
            // Remove all personal content
            filteredContext = MemoryContext(
                userQuery: sanitizeQuery(context.userQuery),
                containsPersonalData: false
            )
            
        case .contextual:
            // Keep only public entities and general relationships
            filteredContext = MemoryContext(
                timestamp: context.timestamp,
                userQuery: context.userQuery,
                containsPersonalData: false,
                contextData: [
                    "entities": context.entities.filter { analyzeMemoryPrivacy(memory: $0).level == .publicKnowledge },
                    "relationships": context.relationships,
                    "shortTermMemories": [],
                    "longTermMemories": [],
                    "episodicMemories": [],
                    "relevantNotes": []
                ]
            )
            
        case .personal:
            // Keep personal data but remove sensitive information
            let filteredSTM = context.shortTermMemories.filter { analyzeMemoryPrivacy(memory: $0).level != .sensitive }
            let filteredLTM = context.longTermMemories.filter { analyzeMemoryPrivacy(memory: $0).level != .sensitive }
            let filteredNotes = context.relevantNotes.filter { analyzeMemoryPrivacy(memory: $0).level != .sensitive }
            
            filteredContext = MemoryContext(
                timestamp: context.timestamp,
                userQuery: context.userQuery,
                containsPersonalData: true,
                contextData: [
                    "entities": context.entities,
                    "relationships": context.relationships,
                    "shortTermMemories": filteredSTM,
                    "longTermMemories": filteredLTM,
                    "episodicMemories": [], // Remove episodic memories for external processing
                    "relevantNotes": filteredNotes
                ]
            )
            
        case .sensitive:
            // Keep all data - no filtering needed
            break
        }
        
        return filteredContext
    }
    
    private func sanitizeQuery(_ query: String) -> String {
        var sanitized = query
        
        // Replace personal pronouns
        for pronoun in personalPronouns {
            sanitized = sanitized.replacingOccurrences(of: pronoun, with: "[PERSONAL]", options: .caseInsensitive)
        }
        
        // Replace family terms
        for term in familyTerms {
            sanitized = sanitized.replacingOccurrences(of: term, with: "[FAMILY]", options: .caseInsensitive)
        }
        
        // Replace location indicators
        for location in locationIndicators {
            sanitized = sanitized.replacingOccurrences(of: location, with: "[LOCATION]", options: .caseInsensitive)
        }
        
        return sanitized
    }
    
    // MARK: - Utility Methods
    
    public func shouldUseOnDeviceProcessing(for analysis: PrivacyAnalysis) -> Bool {
        return analysis.requiresOnDevice || analysis.riskFactors.contains("health_information") || analysis.riskFactors.contains("financial_information")
    }
    
    public func getRecommendedContextSize(for analysis: PrivacyAnalysis) -> Int {
        return analysis.level.maxContextSize
    }
    
    public func getPrivacyReport(for analysis: PrivacyAnalysis) -> String {
        var report = "Privacy Analysis Report:\n"
        report += "Level: \(analysis.level)\n"
        report += "Requires On-Device: \(analysis.requiresOnDevice)\n"
        report += "Confidence: \(String(format: "%.2f", analysis.confidence))\n"
        
        if !analysis.personalIndicators.isEmpty {
            report += "Personal Indicators: \(analysis.personalIndicators.joined(separator: ", "))\n"
        }
        
        if !analysis.sensitiveEntities.isEmpty {
            report += "Sensitive Entities: \(analysis.sensitiveEntities.joined(separator: ", "))\n"
        }
        
        if !analysis.riskFactors.isEmpty {
            report += "Risk Factors: \(analysis.riskFactors.joined(separator: ", "))\n"
        }
        
        return report
    }
}