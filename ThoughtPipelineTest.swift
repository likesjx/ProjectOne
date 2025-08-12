import Foundation
import SwiftData

/// Test script for the new thought-based note processing pipeline
@MainActor
class ThoughtPipelineTest {
    
    private let modelContext: ModelContext
    private let textIngestionAgent: TextIngestionAgent
    
    init() {
        // Create in-memory model context for testing
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: NoteItem.self, ProcessedNote.self, Thought.self,
            configurations: configuration
        )
        self.modelContext = container.mainContext
        self.textIngestionAgent = TextIngestionAgent(modelContext: modelContext)
    }
    
    func runTest() async {
        print("🧪 Testing Thought-Based Note Processing Pipeline")
        print("=" * 50)
        
        let testNotes = [
            createTestNote(content: """
            Had an interesting conversation with Sarah today about the new project. 
            She mentioned we need to focus on user experience first. 
            I think we should also consider performance metrics early on.
            
            TODO: Set up meeting with the design team next week.
            TODO: Research competitor analysis tools.
            
            Question: Should we use React or Vue for the frontend?
            
            Realized that our current approach might be too complex. 
            Maybe we should start with a simpler MVP and iterate from there.
            """),
            
            createTestNote(content: """
            Learning Swift has been challenging but rewarding. 
            The syntax is quite different from Python. 
            Especially the optional handling and memory management concepts.
            
            Goals for this week:
            - Complete the SwiftUI tutorial
            - Build a simple app with Core Data
            - Practice with Combine framework
            
            Note: Remember to check out WWDC videos on Swift concurrency.
            """),
            
            createTestNote(content: """
            Quick idea: What if we created a habit tracking app that uses AI to suggest personalized recommendations?
            
            This could analyze patterns in user behavior and provide insights.
            """)
        ]
        
        for (index, note) in testNotes.enumerated() {
            print("\n📝 Processing Test Note \(index + 1)")
            print("-" * 30)
            
            await processAndAnalyzeNote(note)
            
            print("\n" + "=" * 50)
        }
        
        await printOverallStatistics()
    }
    
    private func createTestNote(content: String) -> NoteItem {
        return NoteItem(
            timestamp: Date(),
            markdownContent: content,
            sourceApp: "ThoughtPipelineTest"
        )
    }
    
    private func processAndAnalyzeNote(_ note: NoteItem) async {
        print("Original content (\(note.markdownContent.count) characters):")
        print(note.markdownContent.prefix(100))
        if note.markdownContent.count > 100 {
            print("...")
        }
        
        // Process the note
        await textIngestionAgent.process(note: note)
        
        // Find the processed note
        let descriptor = FetchDescriptor<ProcessedNote>(
            predicate: #Predicate { $0.originalText == note.markdownContent }
        )
        
        guard let processedNote = try? modelContext.fetch(descriptor).first else {
            print("❌ Failed to find processed note")
            return
        }
        
        print("\n🧠 Extracted Thoughts:")
        let orderedThoughts = processedNote.orderedThoughts
        
        for (index, thought) in orderedThoughts.enumerated() {
            print("  \(index + 1). [\(thought.thoughtType.emoji) \(thought.thoughtType.displayName)] \(thought.content)")
            
            if !thought.tags.isEmpty {
                print("     Tags: \(thought.tags.joined(separator: ", "))")
            }
            
            if let primaryTag = thought.primaryTag {
                print("     Primary: \(primaryTag)")
            }
            
            print("     Importance: \(thought.importance.displayName)")
            
            if let contextBefore = thought.contextBefore, !contextBefore.isEmpty {
                print("     Context Before: \(contextBefore.prefix(50))...")
            }
            
            if let contextAfter = thought.contextAfter, !contextAfter.isEmpty {
                print("     Context After: \(contextAfter.prefix(50))...")
            }
            
            print()
        }
        
        print("📊 Processing Statistics:")
        print("  • Thoughts extracted: \(orderedThoughts.count)")
        print("  • Unique tags: \(processedNote.allThoughtTags.count)")
        print("  • Generated summary: \(processedNote.summary)")
        print("  • Topics: \(processedNote.topics.joined(separator: ", "))")
        
        // Analyze thought types
        let thoughtTypeCounts = Dictionary(grouping: orderedThoughts, by: { $0.thoughtType })
            .mapValues { $0.count }
        
        print("  • Thought type distribution:")
        for (type, count) in thoughtTypeCounts.sorted(by: { $0.value > $1.value }) {
            print("    - \(type.displayName): \(count)")
        }
        
        // Analyze importance distribution
        let importanceCounts = Dictionary(grouping: orderedThoughts, by: { $0.importance })
            .mapValues { $0.count }
        
        print("  • Importance distribution:")
        for (importance, count) in importanceCounts.sorted(by: { $0.key.priority > $1.key.priority }) {
            print("    - \(importance.displayName): \(count)")
        }
    }
    
    private func printOverallStatistics() async {
        print("\n📈 Overall Pipeline Statistics")
        print("=" * 30)
        
        let thoughtDescriptor = FetchDescriptor<Thought>()
        let processedNoteDescriptor = FetchDescriptor<ProcessedNote>()
        
        do {
            let allThoughts = try modelContext.fetch(thoughtDescriptor)
            let allProcessedNotes = try modelContext.fetch(processedNoteDescriptor)
            
            print("Total processed notes: \(allProcessedNotes.count)")
            print("Total thoughts extracted: \(allThoughts.count)")
            print("Average thoughts per note: \(String(format: "%.1f", Double(allThoughts.count) / Double(max(allProcessedNotes.count, 1))))")
            
            let allTags = allThoughts.flatMap { $0.tags }
            let uniqueTags = Set(allTags)
            print("Total unique tags: \(uniqueTags.count)")
            print("Most common tags: \(mostCommonTags(from: allTags).prefix(5).map { "\($0.key) (\($0.value))" }.joined(separator: ", "))")
            
        } catch {
            print("❌ Error fetching statistics: \(error)")
        }
    }
    
    private func mostCommonTags(from tags: [String]) -> [(key: String, value: Int)] {
        let counts = Dictionary(tags.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }
    }
}

// Test execution
Task {
    await ThoughtPipelineTest().runTest()
    print("\n✅ Thought pipeline test completed!")
}