import Foundation
import SwiftData
import AVFoundation

/// Rule-based transcription engine for development and fallback
/// Provides sophisticated placeholder functionality until MLX Swift is integrated
class PlaceholderEngine: TranscriptionEngine {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    
    // Enhanced pattern matching for better simulation
    private let personPatterns = [
        "Sarah Johnson", "Michael Chen", "Dr. Amanda Rodriguez", "James Wilson", 
        "Lisa Thompson", "Robert Kim", "Dr. Martinez", "Jennifer Adams"
    ]
    
    private let organizationPatterns = [
        "Apple Inc.", "Microsoft Corporation", "Google LLC", "Amazon Web Services",
        "Meta Platforms", "Tesla Inc.", "OpenAI", "Anthropic"
    ]
    
    private let locationPatterns = [
        "San Francisco", "New York", "Seattle", "Austin", "Boston",
        "Palo Alto", "Mountain View", "Cupertino"
    ]
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - TranscriptionEngine Protocol
    
    func transcribeAudio(_ audioData: Data) async throws -> TranscriptionResult {
        // Simulate processing time based on audio length
        let duration = Double(audioData.count) / 44100.0 // Approximate duration
        let processingDelay = duration * 0.1 // 10% of audio duration
        
        try await Task.sleep(nanoseconds: UInt64(processingDelay * 1_000_000_000))
        
        // Generate realistic transcription based on audio characteristics
        let transcription = generateRealisticTranscription(for: duration)
        let segments = createSegments(from: transcription, duration: duration)
        
        return TranscriptionResult(
            text: transcription,
            confidence: calculateOverallConfidence(segments),
            segments: segments,
            processingTime: processingDelay,
            language: "en-US"
        )
    }
    
    func extractEntities(from text: String) -> [Entity] {
        var entities: [Entity] = []
        
        // Enhanced entity extraction with multiple pattern types
        entities.append(contentsOf: extractPersonEntities(from: text))
        entities.append(contentsOf: extractOrganizationEntities(from: text))
        entities.append(contentsOf: extractLocationEntities(from: text))
        entities.append(contentsOf: extractConceptEntities(from: text))
        entities.append(contentsOf: extractActivityEntities(from: text))
        
        // Remove duplicates and sort by confidence
        return entities
            .removingDuplicates()
            .sorted { $0.confidence > $1.confidence }
    }
    
    func detectRelationships(entities: [Entity], text: String) -> [Relationship] {
        var relationships: [Relationship] = []
        
        // Detect relationships between entity pairs
        for i in 0..<entities.count {
            for j in (i+1)..<entities.count {
                if let relationship = detectRelationship(
                    between: entities[i], 
                    and: entities[j], 
                    in: text
                ) {
                    relationships.append(relationship)
                }
            }
        }
        
        return relationships.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Transcription Generation
    
    private func generateRealisticTranscription(for duration: TimeInterval) -> String {
        let templates = [
            "Meeting with {person} about the {concept} project. We discussed {activity} and the upcoming {activity}.",
            "Call with {person} from {organization}. They're working on {concept} and need help with {activity}.",
            "Brainstorming session for {concept}. {Person} suggested we focus on {activity} in {location}.",
            "Project update: {activity} is complete. {Person} will handle {activity} next week.",
            "Discussion with {person} about {concept}. The team at {organization} is interested in our {activity}."
        ]
        
        let template = templates.randomElement() ?? templates[0]
        
        return template
            .replacingOccurrences(of: "{person}", with: personPatterns.randomElement() ?? "John Doe")
            .replacingOccurrences(of: "{Person}", with: personPatterns.randomElement() ?? "Jane Smith")
            .replacingOccurrences(of: "{organization}", with: organizationPatterns.randomElement() ?? "TechCorp")
            .replacingOccurrences(of: "{location}", with: locationPatterns.randomElement() ?? "the office")
            .replacingOccurrences(of: "{concept}", with: ["AI integration", "quarterly review", "product launch", "market analysis"].randomElement() ?? "project")
            .replacingOccurrences(of: "{activity}", with: ["implementation", "testing", "deployment", "research", "analysis"].randomElement() ?? "development")
    }
    
    private func createSegments(from text: String, duration: TimeInterval) -> [TranscriptionSegment] {
        let sentences = text.components(separatedBy: ". ").filter { !$0.isEmpty }
        let segmentDuration = duration / Double(sentences.count)
        
        return sentences.enumerated().map { index, sentence in
            let startTime = Double(index) * segmentDuration
            let endTime = startTime + segmentDuration
            
            return TranscriptionSegment(
                text: sentence + (index < sentences.count - 1 ? "." : ""),
                confidence: Double.random(in: 0.85...0.95),
                startTime: startTime,
                endTime: endTime,
                isComplete: true
            )
        }
    }
    
    // MARK: - Entity Extraction
    
    private func extractPersonEntities(from text: String) -> [Entity] {
        return extractEntitiesWithPatterns(
            from: text,
            patterns: [
                "\\b([A-Z][a-z]+ [A-Z][a-z]+)\\b",
                "\\b(Dr|Mr|Mrs|Ms)\\s+([A-Z][a-z]+ [A-Z][a-z]+)\\b"
            ],
            type: .person
        )
    }
    
    private func extractOrganizationEntities(from text: String) -> [Entity] {
        return extractEntitiesWithPatterns(
            from: text,
            patterns: [
                "\\b([A-Z][a-z]+ (Inc|LLC|Corp|Corporation|Company))\\b",
                "\\b(Apple|Microsoft|Google|Amazon|Meta|Tesla|OpenAI|Anthropic)\\b"
            ],
            type: .organization
        )
    }
    
    private func extractLocationEntities(from text: String) -> [Entity] {
        return extractEntitiesWithPatterns(
            from: text,
            patterns: [
                "\\b(San Francisco|New York|Seattle|Austin|Boston|Palo Alto)\\b",
                "\\b([A-Z][a-z]+ (Street|Avenue|Road|Boulevard))\\b"
            ],
            type: .location
        )
    }
    
    private func extractConceptEntities(from text: String) -> [Entity] {
        return extractEntitiesWithPatterns(
            from: text,
            patterns: [
                "\\b(project|meeting|presentation|review|discussion|integration)\\b"
            ],
            type: .concept,
            caseInsensitive: true
        )
    }
    
    private func extractActivityEntities(from text: String) -> [Entity] {
        return extractEntitiesWithPatterns(
            from: text,
            patterns: [
                "\\b(implementation|development|testing|deployment|analysis|research)\\b"
            ],
            type: .activity,
            caseInsensitive: true
        )
    }
    
    private func extractEntitiesWithPatterns(
        from text: String,
        patterns: [String],
        type: EntityType,
        caseInsensitive: Bool = false
    ) -> [Entity] {
        var entities: [Entity] = []
        
        for patternString in patterns {
            do {
                let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
                let regex = try NSRegularExpression(pattern: patternString, options: options)
                let range = NSRange(location: 0, length: text.count)
                let matches = regex.matches(in: text, options: [], range: range)
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let name = String(text[range])
                        
                        let entity = Entity(name: name, type: type)
                        entity.confidence = calculateEntityConfidence(name, type: type)
                        entity.importance = calculateEntityImportance(type)
                        entities.append(entity)
                    }
                }
            } catch {
                print("Regex error for pattern \\(patternString): \\(error)")
            }
        }
        
        return entities
    }
    
    // MARK: - Relationship Detection
    
    private func detectRelationship(between entity1: Entity, and entity2: Entity, in text: String) -> Relationship? {
        let relationshipPatterns: [(String, PredicateType)] = [
            ("works for|employed by|at", .worksFor),
            ("located at|in|based in", .locatedAt),
            ("part of|belongs to|member of", .partOf),
            ("related to|associated with|connected to", .relatedTo),
            ("meeting with|discussed with|talked to", .mentions),
            ("manages|supervises|leads", .manages),
            ("collaborates with|works with|partners with", .collaboratesWith)
        ]
        
        for (pattern, predicateType) in relationshipPatterns {
            let searchPattern = "\\b\\(NSRegularExpression.escapedPattern(for: entity1.name)).{1,50}(\\(pattern)).{1,50}\\(NSRegularExpression.escapedPattern(for: entity2.name))\\b"
            
            do {
                let regex = try NSRegularExpression(pattern: searchPattern, options: [.caseInsensitive])
                let range = NSRange(location: 0, length: text.count)
                
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    let relationship = Relationship(
                        subjectEntityId: entity1.id,
                        predicateType: predicateType,
                        objectEntityId: entity2.id
                    )
                    relationship.confidence = calculateRelationshipConfidence(entity1, entity2, predicateType)
                    relationship.importance = calculateRelationshipImportance(entity1, entity2)
                    return relationship
                }
            } catch {
                print("Regex error for relationship pattern: \\(error)")
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func calculateOverallConfidence(_ segments: [TranscriptionSegment]) -> Double {
        guard !segments.isEmpty else { return 0.0 }
        return segments.map { $0.confidence }.reduce(0, +) / Double(segments.count)
    }
    
    private func calculateEntityConfidence(_ name: String, type: EntityType) -> Double {
        var confidence = 0.75
        
        // Longer names typically more confident
        if name.count > 10 { confidence += 0.1 }
        
        // Type-specific confidence adjustments
        switch type {
        case .person:
            confidence += name.contains(" ") ? 0.15 : 0.0
        case .organization:
            confidence += (name.contains("Inc") || name.contains("Corp")) ? 0.1 : 0.0
        case .location:
            confidence += 0.05
        default:
            break
        }
        
        return min(confidence, 1.0)
    }
    
    private func calculateEntityImportance(_ type: EntityType) -> Double {
        switch type {
        case .person: return 0.8
        case .organization: return 0.7
        case .location: return 0.6
        case .concept: return 0.5
        case .activity: return 0.4
        }
    }
    
    private func calculateRelationshipConfidence(_ entity1: Entity, _ entity2: Entity, _ predicateType: PredicateType) -> Double {
        var confidence = 0.7
        
        // Type combination confidence boosts
        if entity1.type == .person && entity2.type == .organization && predicateType == .worksFor {
            confidence = 0.9
        } else if entity1.type == .organization && entity2.type == .location && predicateType == .locatedAt {
            confidence = 0.85
        }
        
        return confidence
    }
    
    private func calculateRelationshipImportance(_ entity1: Entity, _ entity2: Entity) -> Double {
        return (entity1.importance + entity2.importance) / 2.0
    }
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Entity: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name.lowercased())
        hasher.combine(type)
    }
    
    public static func == (lhs: Entity, rhs: Entity) -> Bool {
        return lhs.name.lowercased() == rhs.name.lowercased() && lhs.type == rhs.type
    }
}