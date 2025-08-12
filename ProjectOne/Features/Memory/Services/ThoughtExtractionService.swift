import Foundation
import SwiftData
import os.log

/// Service responsible for extracting granular thoughts from raw text and generating appropriate tags
@MainActor
public class ThoughtExtractionService: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "ThoughtExtractionService")
    private let modelContext: ModelContext
    private var gemmaCore: EnhancedGemma3nCore?
    
    // Configuration
    private let minThoughtLength = 10
    private let maxThoughtsPerNote = 50
    private let contextWindowSize = 150 // characters before/after for context
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupAIProviders()
    }
    
    private func setupAIProviders() {
        if #available(iOS 26.0, macOS 26.0, *) {
            gemmaCore = EnhancedGemma3nCore()
            Task {
                await gemmaCore?.setup()
            }
        }
    }
    
    // MARK: - Main Extraction Methods
    
    /// Extract thoughts from raw text using intelligent segmentation
    public func extractThoughts(from text: String, for note: ProcessedNote) async throws -> [Thought] {
        logger.info("Extracting thoughts from text (\(text.count) characters)")
        
        // Step 1: Intelligent segmentation
        let segments = await segmentTextIntoThoughts(text)
        logger.debug("Segmented text into \(segments.count) potential thoughts")
        
        // Step 2: Process each segment into a thought with context
        var thoughts: [Thought] = []
        
        for (index, segment) in segments.enumerated() {
            let thought = try await processSegmentIntoThought(
                segment: segment,
                fullText: text,
                sequenceIndex: index,
                parentNote: note
            )
            thoughts.append(thought)
        }
        
        logger.info("Successfully extracted \(thoughts.count) thoughts")
        return thoughts
    }
    
    // MARK: - Intelligent Text Segmentation
    
    /// Segment text into meaningful thought units using AI or rule-based approach
    private func segmentTextIntoThoughts(_ text: String) async -> [TextSegment] {
        // Try AI-based segmentation first
        if let segments = await aiBasedSegmentation(text) {
            return segments
        }
        
        // Fallback to rule-based segmentation
        return ruleBasedSegmentation(text)
    }
    
    /// AI-powered text segmentation into logical thoughts
    private func aiBasedSegmentation(_ text: String) async -> [TextSegment]? {
        guard let gemmaCore = gemmaCore else { return nil }
        
        let prompt = """
        Analyze the following text and break it down into discrete, meaningful thoughts or ideas. Each thought should be self-contained but preserve important context. 
        
        Return the segmentation as a JSON array where each item has:
        - "content": the main thought content
        - "startIndex": approximate character position where this thought begins
        - "endIndex": approximate character position where this thought ends
        - "thoughtType": one of [general, idea, task, question, insight, memory, plan, reflection, fact, opinion, decision, goal]
        
        Text to analyze:
        \(text)
        
        JSON segmentation:
        """
        
        logger.debug("Requesting AI-based text segmentation")
        let response = await gemmaCore.processText(prompt)
        
        // Parse JSON response
        return parseSegmentationResponse(response, originalText: text)
    }
    
    /// Parse AI response into text segments
    private func parseSegmentationResponse(_ response: String, originalText: String) -> [TextSegment]? {
        // Extract JSON from response
        guard let jsonStart = response.range(of: "["),
              let jsonEnd = response.range(of: "]", options: .backwards),
              jsonStart.lowerBound < jsonEnd.upperBound else {
            logger.warning("No valid JSON found in AI segmentation response")
            return nil
        }
        
        let jsonString = String(response[jsonStart.lowerBound...jsonEnd.upperBound])
        
        do {
            if let data = jsonString.data(using: .utf8),
               let segments = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                
                var textSegments: [TextSegment] = []
                
                for (index, segmentData) in segments.enumerated() {
                    guard let content = segmentData["content"] as? String,
                          !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    
                    let thoughtTypeString = segmentData["thoughtType"] as? String ?? "general"
                    let thoughtType = ThoughtType(rawValue: thoughtTypeString) ?? .general
                    
                    // Use provided indices or estimate them
                    let startIndex = segmentData["startIndex"] as? Int ?? (index * (originalText.count / segments.count))
                    let endIndex = segmentData["endIndex"] as? Int ?? min(startIndex + content.count, originalText.count)
                    
                    let segment = TextSegment(
                        content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                        startIndex: startIndex,
                        endIndex: endIndex,
                        thoughtType: thoughtType
                    )
                    
                    textSegments.append(segment)
                }
                
                logger.debug("Successfully parsed \(textSegments.count) segments from AI response")
                return textSegments
            }
        } catch {
            logger.error("Failed to parse AI segmentation response: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Rule-based text segmentation as fallback
    private func ruleBasedSegmentation(_ text: String) -> [TextSegment] {
        logger.debug("Using rule-based text segmentation")
        
        var segments: [TextSegment] = []
        
        // Split by natural boundaries
        let boundaries = [
            ".\\s+",          // Sentence endings
            "\\n\\n",         // Paragraph breaks
            "\\?\\s+",        // Questions
            "!\\s+",          // Exclamations
            ";\\s+",          // Semicolons
            ":\\s+(?=[A-Z])", // Colons followed by capitals
        ]
        
        let pattern = "(" + boundaries.joined(separator: "|") + ")"
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, options: [], range: range)
            
            var lastEnd = text.startIndex
            var currentIndex = 0
            
            for match in matches {
                guard let matchRange = Range(match.range, in: text) else { continue }
                
                let content = String(text[lastEnd..<matchRange.upperBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if content.count >= minThoughtLength {
                    let segment = TextSegment(
                        content: content,
                        startIndex: text.distance(from: text.startIndex, to: lastEnd),
                        endIndex: text.distance(from: text.startIndex, to: matchRange.upperBound),
                        thoughtType: inferThoughtType(from: content)
                    )
                    segments.append(segment)
                    currentIndex += 1
                }
                
                lastEnd = matchRange.upperBound
                
                if segments.count >= maxThoughtsPerNote {
                    break
                }
            }
            
            // Add remaining text
            if lastEnd < text.endIndex {
                let content = String(text[lastEnd...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if content.count >= minThoughtLength {
                    let segment = TextSegment(
                        content: content,
                        startIndex: text.distance(from: text.startIndex, to: lastEnd),
                        endIndex: text.count,
                        thoughtType: inferThoughtType(from: content)
                    )
                    segments.append(segment)
                }
            }
            
        } catch {
            logger.error("Regex segmentation failed: \(error.localizedDescription)")
            // Simple fallback: split by sentences
            segments = simpleSentenceSplit(text)
        }
        
        logger.debug("Rule-based segmentation created \(segments.count) segments")
        return segments
    }
    
    /// Simple sentence-based splitting as last resort
    private func simpleSentenceSplit(_ text: String) -> [TextSegment] {
        let sentences = text.components(separatedBy: .punctuationCharacters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= minThoughtLength }
        
        return sentences.enumerated().map { index, sentence in
            TextSegment(
                content: sentence,
                startIndex: 0, // Approximate
                endIndex: sentence.count, // Approximate
                thoughtType: inferThoughtType(from: sentence)
            )
        }
    }
    
    /// Infer thought type from content using simple heuristics
    private func inferThoughtType(from content: String) -> ThoughtType {
        let lowercased = content.lowercased()
        
        if lowercased.contains("?") { return .question }
        if lowercased.hasPrefix("todo") || lowercased.contains("need to") || lowercased.contains("should") { return .task }
        if lowercased.contains("remember") || lowercased.contains("recall") { return .memory }
        if lowercased.contains("idea") || lowercased.contains("maybe") || lowercased.contains("could") { return .idea }
        if lowercased.contains("plan") || lowercased.contains("strategy") { return .plan }
        if lowercased.contains("think") || lowercased.contains("feel like") { return .reflection }
        if lowercased.contains("decide") || lowercased.contains("choose") { return .decision }
        if lowercased.contains("goal") || lowercased.contains("want to") || lowercased.contains("aim") { return .goal }
        if lowercased.contains("learned") || lowercased.contains("insight") || lowercased.contains("realized") { return .insight }
        if lowercased.contains("believe") || lowercased.contains("opinion") || lowercased.contains("think that") { return .opinion }
        
        return .general
    }
    
    // MARK: - Thought Processing
    
    /// Process a text segment into a complete Thought object
    private func processSegmentIntoThought(
        segment: TextSegment,
        fullText: String,
        sequenceIndex: Int,
        parentNote: ProcessedNote
    ) async throws -> Thought {
        
        // Extract context around the segment
        let (contextBefore, contextAfter) = extractContext(
            for: segment,
            from: fullText
        )
        
        // Create the thought
        let thought = Thought(
            content: segment.content,
            contextBefore: contextBefore,
            contextAfter: contextAfter,
            sequenceIndex: sequenceIndex,
            thoughtType: segment.thoughtType,
            parentNote: parentNote
        )
        
        // Generate tags for this thought using AI
        let tags = try await generateTagsForThought(thought)
        thought.setTags(tags)
        
        // Set primary tag (most relevant)
        if let primaryTag = await determinePrimaryTag(for: thought, from: tags) {
            thought.setPrimaryTag(primaryTag)
        }
        
        // Determine importance and completeness
        thought.importance = await determineImportance(for: thought)
        thought.completeness = await determineCompleteness(for: thought)
        
        thought.extractionMethod = gemmaCore != nil ? "ai_segmentation" : "rule_based"
        
        return thought
    }
    
    /// Extract contextual information around a segment
    private func extractContext(for segment: TextSegment, from fullText: String) -> (before: String?, after: String?) {
        let text = fullText
        
        // Calculate context boundaries
        let beforeStart = max(0, segment.startIndex - contextWindowSize)
        let beforeEnd = segment.startIndex
        
        let afterStart = segment.endIndex
        let afterEnd = min(text.count, segment.endIndex + contextWindowSize)
        
        // Extract context before
        var contextBefore: String?
        if beforeStart < beforeEnd {
            let beforeIndex = text.index(text.startIndex, offsetBy: beforeStart)
            let segmentStartIndex = text.index(text.startIndex, offsetBy: beforeEnd)
            contextBefore = String(text[beforeIndex..<segmentStartIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract context after
        var contextAfter: String?
        if afterStart < afterEnd && afterStart < text.count {
            let segmentEndIndex = text.index(text.startIndex, offsetBy: afterStart)
            let afterIndex = text.index(text.startIndex, offsetBy: afterEnd)
            contextAfter = String(text[segmentEndIndex..<afterIndex])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return (contextBefore, contextAfter)
    }
    
    // MARK: - Tag Generation
    
    /// Generate appropriate tags for a thought using AI
    private func generateTagsForThought(_ thought: Thought) async throws -> [String] {
        guard let gemmaCore = gemmaCore else {
            return generateFallbackTags(for: thought)
        }
        
        let prompt = """
        Analyze this thought and generate 3-5 specific, relevant tags that best describe its content and meaning. Focus on:
        - Key concepts, themes, or topics
        - Actionable items or categories
        - Emotional or contextual markers
        - Domain-specific terms
        
        Return only the tags as a comma-separated list, using lowercase.
        
        Thought Type: \(thought.thoughtType.displayName)
        Content: \(thought.content)
        Context: \(thought.fullContext)
        
        Tags:
        """
        
        logger.debug("Generating AI tags for thought: \(thought.content.prefix(50))...")
        let response = await gemmaCore.processText(prompt)
        
        // Parse tags from response
        let tags = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && $0.count > 1 && $0.count < 25 }
            .prefix(5)
        
        if tags.isEmpty {
            logger.warning("AI generated no valid tags, falling back to rule-based tags")
            return generateFallbackTags(for: thought)
        }
        
        logger.debug("Generated \(tags.count) AI tags: \(Array(tags).joined(separator: ", "))")
        return Array(tags)
    }
    
    /// Generate tags using rule-based approach as fallback
    private func generateFallbackTags(for thought: Thought) -> [String] {
        var tags: Set<String> = []
        
        // Add thought type as base tag
        tags.insert(thought.thoughtType.rawValue)
        
        // Extract keywords from content
        let words = thought.content.lowercased()
            .components(separatedBy: .punctuationCharacters)
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 3 && $0.count < 20 }
        
        // Common stop words to exclude
        let stopWords = Set(["the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one", "our", "out", "day", "get", "has", "him", "his", "how", "man", "new", "now", "old", "see", "two", "way", "who", "boy", "did", "its", "let", "put", "say", "she", "too", "use", "that", "with", "will", "this", "from", "they", "have", "been", "would", "could", "should", "might"])
        
        // Add meaningful words as tags
        let meaningfulWords = words.filter { !stopWords.contains($0) }
        for word in meaningfulWords.prefix(3) {
            tags.insert(word)
        }
        
        // Add contextual tags based on patterns
        let content = thought.content.lowercased()
        if content.contains("work") || content.contains("office") || content.contains("meeting") {
            tags.insert("work")
        }
        if content.contains("home") || content.contains("family") {
            tags.insert("personal")
        }
        if content.contains("learn") || content.contains("study") || content.contains("research") {
            tags.insert("learning")
        }
        if content.contains("project") || content.contains("task") || content.contains("todo") {
            tags.insert("project")
        }
        
        return Array(tags).prefix(5).map { String($0) }
    }
    
    /// Determine the primary (most relevant) tag for a thought
    private func determinePrimaryTag(for thought: Thought, from tags: [String]) async -> String? {
        guard !tags.isEmpty else { return nil }
        
        // Use AI to select the most relevant tag
        if let gemmaCore = gemmaCore {
            let prompt = """
            From these tags: \(tags.joined(separator: ", "))
            
            Select the single most relevant tag for this thought:
            "\(thought.content)"
            
            Return only the tag name:
            """
            
            let response = await gemmaCore.processText(prompt)
            let selectedTag = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            if tags.contains(selectedTag) {
                return selectedTag
            }
        }
        
        // Fallback: use thought type or first tag
        return tags.first ?? thought.thoughtType.rawValue
    }
    
    /// Determine importance level of a thought
    private func determineImportance(for thought: Thought) async -> ThoughtImportance {
        let content = thought.content.lowercased()
        
        // High importance indicators
        if content.contains("important") || content.contains("critical") || content.contains("urgent") ||
           content.contains("must") || content.contains("deadline") || content.contains("priority") {
            return .high
        }
        
        // Critical importance indicators
        if content.contains("emergency") || content.contains("asap") || content.contains("immediately") {
            return .critical
        }
        
        // Low importance indicators
        if content.contains("maybe") || content.contains("sometime") || content.contains("eventually") ||
           content.contains("if i have time") || content.contains("low priority") {
            return .low
        }
        
        // Task and decision types tend to be more important
        if thought.thoughtType == .task || thought.thoughtType == .decision || thought.thoughtType == .goal {
            return .high
        }
        
        return .medium
    }
    
    /// Determine completeness of a thought
    private func determineCompleteness(for thought: Thought) async -> ThoughtCompleteness {
        let content = thought.content
        
        // Check for fragment indicators
        if content.count < 20 || content.hasSuffix("...") || content.hasPrefix("...") {
            return .fragment
        }
        
        // Check for partial indicators
        if content.contains("...") || content.contains("etc") || content.contains("and so on") ||
           content.lowercased().contains("more on this") {
            return .partial
        }
        
        // Check for expanded indicators
        if content.count > 200 || (thought.contextBefore != nil && thought.contextAfter != nil) {
            return .expanded
        }
        
        return .complete
    }
}

// MARK: - Supporting Structures

/// Represents a segment of text to be processed into a thought
private struct TextSegment {
    let content: String
    let startIndex: Int
    let endIndex: Int
    let thoughtType: ThoughtType
}