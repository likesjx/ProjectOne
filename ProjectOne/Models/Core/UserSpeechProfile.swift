import Foundation
import SwiftData

enum SpeechStyle: String, CaseIterable, Codable {
    case formal = "formal"
    case casual = "casual"
    case technical = "technical"
    case conversational = "conversational"
    case dictated = "dictated"
    case rapid = "rapid"
    case deliberate = "deliberate"
}

enum ContextType: String, CaseIterable, Codable {
    case work = "work"
    case personal = "personal"
    case health = "health"
    case learning = "learning"
    case planning = "planning"
    case social = "social"
    case creative = "creative"
}

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class UserSpeechProfile {
    var id: UUID
    var userIdentifier: String // To support multiple users
    var createdDate: Date
    var lastUpdated: Date
    
    // Basic speech characteristics
    var averagePace: Double // Words per minute
    var averagePauseLength: Double // Seconds
    var commonFillerWords: [String]
    var pronunciationPatterns: [String: String] // "gonna" -> "going to"
    
    // Vocabulary and language patterns
    var frequentWords: [String: Int] // Word frequency map
    var commonPhrases: [String: String] // "my wife" -> "Sarah"
    var technicalVocabulary: [String] // Domain-specific terms
    var personalReferences: [String: String] // References to people/places
    
    // Correction learning
    var corrections: [SpeechCorrection] // Historical corrections for learning
    var commonMistakes: [String: String] // Frequently corrected patterns
    
    // Context-based patterns
    var contextPatterns: [ContextPattern] // Different speech patterns by context
    var timeOfDayPatterns: [TimePattern] // Speech varies by time
    var locationPatterns: [LocationPattern] // Speech varies by location
    
    // Adaptation metadata
    var adaptationLevel: Double // How well-adapted the system is (0.0-1.0)
    var totalCorrections: Int
    var totalTranscriptions: Int
    var accuracyScore: Double // Current transcription accuracy
    
    init(userIdentifier: String = "default") {
        self.id = UUID()
        self.userIdentifier = userIdentifier
        self.createdDate = Date()
        self.lastUpdated = Date()
        self.averagePace = 150.0 // Default words per minute
        self.averagePauseLength = 0.5
        self.commonFillerWords = ["um", "uh", "like", "you know"]
        self.pronunciationPatterns = [:]
        self.frequentWords = [:]
        self.commonPhrases = [:]
        self.technicalVocabulary = []
        self.personalReferences = [:]
        self.corrections = []
        self.commonMistakes = [:]
        self.contextPatterns = []
        self.timeOfDayPatterns = []
        self.locationPatterns = []
        self.adaptationLevel = 0.0
        self.totalCorrections = 0
        self.totalTranscriptions = 0
        self.accuracyScore = 0.0
    }
    
    // Learn from a correction
    func learnFromCorrection(_ correction: SpeechCorrection) {
        corrections.append(correction)
        totalCorrections += 1
        lastUpdated = Date()
        
        // Update common mistakes
        commonMistakes[correction.original] = correction.corrected
        
        // Update pronunciation patterns
        if correction.type == .pronunciation {
            pronunciationPatterns[correction.original] = correction.corrected
        }
        
        // Update personal references
        if correction.type == .personalReference {
            personalReferences[correction.original] = correction.corrected
        }
        
        updateAdaptationLevel()
    }
    
    // Record a successful transcription
    func recordTranscription(wordCount: Int, duration: Double) {
        totalTranscriptions += 1
        
        // Update pace if we have duration info
        if duration > 0 {
            let wordsPerMinute = Double(wordCount) / (duration / 60.0)
            averagePace = (averagePace * 0.9) + (wordsPerMinute * 0.1) // Moving average
        }
        
        updateAdaptationLevel()
    }
    
    // Update frequency of words
    func updateWordFrequency(_ words: [String]) {
        for word in words {
            let cleanWord = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            frequentWords[cleanWord, default: 0] += 1
        }
        lastUpdated = Date()
    }
    
    // Get personalization context for a given situation
    func getPersonalizationContext(
        timeOfDay: TimeOfDay? = nil,
        location: String? = nil,
        context: ContextType? = nil
    ) -> PersonalizationContext {
        
        var relevantPatterns: [String] = []
        var relevantVocabulary: [String] = []
        var expectedStyle = SpeechStyle.conversational
        
        // Time-based adaptations
        if let timeOfDay = timeOfDay {
            if let pattern = timeOfDayPatterns.first(where: { $0.timeOfDay == timeOfDay }) {
                relevantPatterns.append(contentsOf: pattern.commonPhrases)
                expectedStyle = pattern.typicalStyle
            }
        }
        
        // Context-based adaptations
        if let context = context {
            if let pattern = contextPatterns.first(where: { $0.context == context }) {
                relevantVocabulary.append(contentsOf: pattern.vocabularyFocus)
                relevantPatterns.append(contentsOf: pattern.commonExpressions)
            }
        }
        
        // Location-based adaptations
        if let location = location {
            if let pattern = locationPatterns.first(where: { $0.location.lowercased() == location.lowercased() }) {
                relevantVocabulary.append(contentsOf: pattern.contextualTerms)
            }
        }
        
        return PersonalizationContext(
            expectedPace: averagePace,
            commonSubstitutions: commonMistakes,
            personalReferences: personalReferences,
            relevantVocabulary: Array(Set(relevantVocabulary + technicalVocabulary)),
            expectedStyle: expectedStyle,
            commonFillers: commonFillerWords,
            contextualPhrases: relevantPatterns
        )
    }
    
    // Update adaptation level based on success metrics
    private func updateAdaptationLevel() {
        if totalTranscriptions == 0 {
            adaptationLevel = 0.0
            return
        }
        
        // Base adaptation on correction ratio and total experience
        let errorRate = Double(totalCorrections) / Double(totalTranscriptions)
        let experienceBonus = min(0.3, Double(totalTranscriptions) / 1000.0 * 0.3)
        let accuracyBonus = accuracyScore * 0.4
        
        adaptationLevel = min(1.0, (1.0 - errorRate) * 0.5 + experienceBonus + accuracyBonus)
    }
    
    // Get adaptation summary for UI display
    func getAdaptationSummary() -> AdaptationSummary {
        return AdaptationSummary(
            level: adaptationLevel,
            totalTranscriptions: totalTranscriptions,
            totalCorrections: totalCorrections,
            accuracy: accuracyScore,
            learnedPatterns: corrections.count,
            personalizedTerms: personalReferences.count
        )
    }
}

// MARK: - Supporting Data Structures

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
final class SpeechCorrection {
    var id: UUID
    var original: String
    var corrected: String
    var type: CorrectionType
    var context: String
    var timestamp: Date
    var confidence: Double
    
    init(original: String, corrected: String, type: CorrectionType, context: String = "", confidence: Double = 1.0) {
        self.id = UUID()
        self.original = original
        self.corrected = corrected
        self.type = type
        self.context = context
        self.timestamp = Date()
        self.confidence = confidence
    }
}

enum CorrectionType: String, CaseIterable, Codable {
    case pronunciation = "pronunciation"
    case vocabulary = "vocabulary"
    case personalReference = "personal_reference"
    case technical = "technical"
    case grammar = "grammar"
    case punctuation = "punctuation"
}

struct ContextPattern: Codable {
    let context: ContextType
    let vocabularyFocus: [String]
    let commonExpressions: [String]
    let typicalStyle: SpeechStyle
}

struct TimePattern: Codable {
    let timeOfDay: TimeOfDay
    let commonPhrases: [String]
    let typicalStyle: SpeechStyle
    let energyLevel: Double
}

enum TimeOfDay: String, CaseIterable, Codable {
    case earlyMorning = "early_morning" // 5-9 AM
    case morning = "morning"            // 9-12 PM
    case afternoon = "afternoon"        // 12-5 PM
    case evening = "evening"            // 5-9 PM
    case night = "night"                // 9 PM-5 AM
}

struct LocationPattern: Codable {
    let location: String
    let contextualTerms: [String]
    let formalityLevel: Double // 0.0 = very casual, 1.0 = very formal
}

struct PersonalizationContext {
    let expectedPace: Double
    let commonSubstitutions: [String: String]
    let personalReferences: [String: String]
    let relevantVocabulary: [String]
    let expectedStyle: SpeechStyle
    let commonFillers: [String]
    let contextualPhrases: [String]
    
    // Generate prompt additions for Gemma 3n
    func toPromptAdditions() -> String {
        var prompt = ""
        
        if !commonSubstitutions.isEmpty {
            let substitutions = commonSubstitutions.map { "\($0.key) -> \($0.value)" }.joined(separator: ", ")
            prompt += "Common speech patterns: \(substitutions). "
        }
        
        if !personalReferences.isEmpty {
            let references = personalReferences.map { "\($0.key) refers to \($0.value)" }.joined(separator: ", ")
            prompt += "Personal references: \(references). "
        }
        
        if !relevantVocabulary.isEmpty && relevantVocabulary.count <= 20 {
            prompt += "Expected vocabulary: \(relevantVocabulary.joined(separator: ", ")). "
        }
        
        prompt += "Speaking style: \(expectedStyle.rawValue). "
        prompt += "Typical pace: \(Int(expectedPace)) words per minute. "
        
        if !commonFillers.isEmpty {
            prompt += "Common filler words: \(commonFillers.joined(separator: ", ")). "
        }
        
        return prompt
    }
}

struct AdaptationSummary {
    let level: Double
    let totalTranscriptions: Int
    let totalCorrections: Int
    let accuracy: Double
    let learnedPatterns: Int
    let personalizedTerms: Int
    
    var adaptationDescription: String {
        switch level {
        case 0.0..<0.2:
            return "Learning your speech patterns"
        case 0.2..<0.5:
            return "Getting familiar with your voice"
        case 0.5..<0.8:
            return "Well-adapted to your speech"
        case 0.8...1.0:
            return "Highly personalized"
        default:
            return "Unknown"
        }
    }
}