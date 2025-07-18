import Foundation
import SwiftData
import AVFoundation

/// Test file for MLX Swift integration
/// This file demonstrates how MLX Swift will be integrated into ProjectOne
/// Run this test to verify MLX integration works properly

class MLXIntegrationTest {
    
    private let modelContext: ModelContext
    private let mlxService: MLXIntegrationService
    private let mlxEngine: MLXTranscriptionEngine
    private let placeholderEngine: PlaceholderEngine
    
    init() throws {
        // Create test model context
        let container = try ModelContainer(for: ProcessedNote.self, Entity.self, Relationship.self)
        self.modelContext = ModelContext(container)
        
        // Initialize services
        self.mlxService = MLXIntegrationService(modelContext: modelContext)
        self.mlxEngine = MLXTranscriptionEngine(modelContext: modelContext)
        self.placeholderEngine = PlaceholderEngine(modelContext: modelContext)
    }
    
    // MARK: - Test Methods
    
    func runIntegrationTests() async {
        print("🧪 Starting MLX Swift Integration Tests")
        print("=" * 50)
        
        await testMLXAvailability()
        await testModelLoading()
        await testTranscriptionComparison()
        await testEntityExtractionComparison()
        await testRelationshipDetectionComparison()
        await testPerformanceComparison()
        
        print("\n✅ MLX Swift Integration Tests Complete")
    }
    
    // MARK: - Individual Tests
    
    private func testMLXAvailability() async {
        print("\n🔍 Testing MLX Swift Availability...")
        
        let isAvailable = mlxService.isMLXAvailable
        print("MLX Swift Available: \(isAvailable)")
        
        if !isAvailable {
            print("⚠️  MLX Swift not available - using enhanced PlaceholderEngine")
            print("   This is expected until MLX Swift package is added")
        }
    }
    
    private func testModelLoading() async {
        print("\n📦 Testing Model Loading...")
        
        await mlxService.loadModels()
        
        let metrics = mlxService.getModelPerformanceMetrics()
        print("Models Loaded: \(metrics.modelsLoaded)")
        print("Cache Size: \(metrics.cacheSize)")
        print("Memory Usage: \(metrics.memoryUsage) MB")
        print("Average Inference Time: \(metrics.averageInferenceTime)s")
        
        if let error = mlxService.errorMessage {
            print("❌ Error: \(error)")
        }
    }
    
    private func testTranscriptionComparison() async {
        print("\n🎤 Testing Transcription Comparison...")
        
        // Generate test audio data
        let testAudioData = generateTestAudioData()
        
        do {
            // Test MLX transcription
            let startTime = Date()
            let mlxResult = try await mlxEngine.transcribeAudio(testAudioData)
            let mlxTime = Date().timeIntervalSince(startTime)
            
            // Test Placeholder transcription
            let startTime2 = Date()
            let placeholderResult = try await placeholderEngine.transcribeAudio(testAudioData)
            let placeholderTime = Date().timeIntervalSince(startTime2)
            
            print("MLX Result:")
            print("  Text: \(mlxResult.text)")
            print("  Confidence: \(mlxResult.confidence)")
            print("  Segments: \(mlxResult.segments.count)")
            print("  Processing Time: \(mlxTime)s")
            
            print("Placeholder Result:")
            print("  Text: \(placeholderResult.text)")
            print("  Confidence: \(placeholderResult.confidence)")
            print("  Segments: \(placeholderResult.segments.count)")
            print("  Processing Time: \(placeholderTime)s")
            
            // Compare results
            compareTranscriptionResults(mlxResult, placeholderResult)
            
        } catch {
            print("❌ Transcription test failed: \(error)")
        }
    }
    
    private func testEntityExtractionComparison() async {
        print("\n🏷️  Testing Entity Extraction Comparison...")
        
        let testText = "Sarah Johnson from Apple Inc. will meet with Dr. Michael Chen at the San Francisco office to discuss the new AI project implementation."
        
        // Test MLX entity extraction
        let startTime = Date()
        let mlxEntities = mlxEngine.extractEntities(from: testText)
        let mlxTime = Date().timeIntervalSince(startTime)
        
        // Test Placeholder entity extraction
        let startTime2 = Date()
        let placeholderEntities = placeholderEngine.extractEntities(from: testText)
        let placeholderTime = Date().timeIntervalSince(startTime2)
        
        print("MLX Entities (\(mlxEntities.count)):")
        for entity in mlxEntities {
            print("  \(entity.name) (\(entity.type)) - confidence: \(entity.confidence)")
        }
        print("  Processing Time: \(mlxTime)s")
        
        print("Placeholder Entities (\(placeholderEntities.count)):")
        for entity in placeholderEntities {
            print("  \(entity.name) (\(entity.type)) - confidence: \(entity.confidence)")
        }
        print("  Processing Time: \(placeholderTime)s")
        
        // Compare results
        compareEntityResults(mlxEntities, placeholderEntities)
    }
    
    private func testRelationshipDetectionComparison() async {
        print("\n🔗 Testing Relationship Detection Comparison...")
        
        let testText = "Sarah Johnson works for Apple Inc. and collaborates with Dr. Michael Chen on the AI project."
        
        // Extract entities first
        let entities = mlxEngine.extractEntities(from: testText)
        
        // Test MLX relationship detection
        let startTime = Date()
        let mlxRelationships = mlxEngine.detectRelationships(entities: entities, text: testText)
        let mlxTime = Date().timeIntervalSince(startTime)
        
        // Test Placeholder relationship detection
        let startTime2 = Date()
        let placeholderRelationships = placeholderEngine.detectRelationships(entities: entities, text: testText)
        let placeholderTime = Date().timeIntervalSince(startTime2)
        
        print("MLX Relationships (\(mlxRelationships.count)):")
        for relationship in mlxRelationships {
            print("  \(relationship.predicateType) - confidence: \(relationship.confidence)")
        }
        print("  Processing Time: \(mlxTime)s")
        
        print("Placeholder Relationships (\(placeholderRelationships.count)):")
        for relationship in placeholderRelationships {
            print("  \(relationship.predicateType) - confidence: \(relationship.confidence)")
        }
        print("  Processing Time: \(placeholderTime)s")
        
        // Compare results
        compareRelationshipResults(mlxRelationships, placeholderRelationships)
    }
    
    private func testPerformanceComparison() async {
        print("\n⚡ Testing Performance Comparison...")
        
        let iterations = 10
        let testText = "This is a test sentence for performance comparison between MLX and Placeholder engines."
        
        // MLX performance test
        var mlxTimes: [TimeInterval] = []
        for _ in 0..<iterations {
            let startTime = Date()
            _ = mlxEngine.extractEntities(from: testText)
            let duration = Date().timeIntervalSince(startTime)
            mlxTimes.append(duration)
        }
        
        // Placeholder performance test
        var placeholderTimes: [TimeInterval] = []
        for _ in 0..<iterations {
            let startTime = Date()
            _ = placeholderEngine.extractEntities(from: testText)
            let duration = Date().timeIntervalSince(startTime)
            placeholderTimes.append(duration)
        }
        
        let mlxAverage = mlxTimes.reduce(0, +) / Double(iterations)
        let placeholderAverage = placeholderTimes.reduce(0, +) / Double(iterations)
        
        print("Average Processing Time (\(iterations) iterations):")
        print("  MLX: \(mlxAverage)s")
        print("  Placeholder: \(placeholderAverage)s")
        print("  Performance Ratio: \(mlxAverage / placeholderAverage)")
        
        if mlxAverage < placeholderAverage {
            print("🚀 MLX is \(Int((placeholderAverage / mlxAverage - 1) * 100))% faster")
        } else {
            print("⚠️  Placeholder is \(Int((mlxAverage / placeholderAverage - 1) * 100))% faster")
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateTestAudioData() -> Data {
        // Generate mock audio data for testing
        let sampleRate = 44100
        let duration = 3.0 // 3 seconds
        let sampleCount = Int(Double(sampleRate) * duration)
        
        var audioData = Data()
        for i in 0..<sampleCount {
            let sample = sin(2.0 * .pi * 440.0 * Double(i) / Double(sampleRate)) // 440 Hz sine wave
            let sampleValue = Int16(sample * 32767)
            audioData.append(Data(bytes: &sampleValue, count: MemoryLayout<Int16>.size))
        }
        
        return audioData
    }
    
    private func compareTranscriptionResults(_ mlxResult: TranscriptionResult, _ placeholderResult: TranscriptionResult) {
        print("\n📊 Transcription Comparison:")
        print("  Text Length: MLX(\(mlxResult.text.count)) vs Placeholder(\(placeholderResult.text.count))")
        print("  Confidence: MLX(\(mlxResult.confidence)) vs Placeholder(\(placeholderResult.confidence))")
        print("  Segments: MLX(\(mlxResult.segments.count)) vs Placeholder(\(placeholderResult.segments.count))")
        
        // Calculate text similarity (simple word overlap)
        let mlxWords = Set(mlxResult.text.lowercased().components(separatedBy: " "))
        let placeholderWords = Set(placeholderResult.text.lowercased().components(separatedBy: " "))
        let commonWords = mlxWords.intersection(placeholderWords)
        let similarity = Double(commonWords.count) / Double(mlxWords.union(placeholderWords).count)
        
        print("  Text Similarity: \(similarity * 100)%")
    }
    
    private func compareEntityResults(_ mlxEntities: [Entity], _ placeholderEntities: [Entity]) {
        print("\n📊 Entity Comparison:")
        print("  Count: MLX(\(mlxEntities.count)) vs Placeholder(\(placeholderEntities.count))")
        
        // Compare entity names
        let mlxNames = Set(mlxEntities.map { $0.name.lowercased() })
        let placeholderNames = Set(placeholderEntities.map { $0.name.lowercased() })
        let commonNames = mlxNames.intersection(placeholderNames)
        let similarity = Double(commonNames.count) / Double(mlxNames.union(placeholderNames).count)
        
        print("  Name Similarity: \(similarity * 100)%")
        
        // Compare average confidence
        let mlxConfidence = mlxEntities.map { $0.confidence }.reduce(0, +) / Double(mlxEntities.count)
        let placeholderConfidence = placeholderEntities.map { $0.confidence }.reduce(0, +) / Double(placeholderEntities.count)
        
        print("  Average Confidence: MLX(\(mlxConfidence)) vs Placeholder(\(placeholderConfidence))")
    }
    
    private func compareRelationshipResults(_ mlxRelationships: [Relationship], _ placeholderRelationships: [Relationship]) {
        print("\n📊 Relationship Comparison:")
        print("  Count: MLX(\(mlxRelationships.count)) vs Placeholder(\(placeholderRelationships.count))")
        
        // Compare relationship types
        let mlxTypes = Set(mlxRelationships.map { $0.predicateType })
        let placeholderTypes = Set(placeholderRelationships.map { $0.predicateType })
        let commonTypes = mlxTypes.intersection(placeholderTypes)
        let similarity = Double(commonTypes.count) / Double(mlxTypes.union(placeholderTypes).count)
        
        print("  Type Similarity: \(similarity * 100)%")
        
        // Compare average confidence
        let mlxConfidence = mlxRelationships.map { $0.confidence }.reduce(0, +) / Double(mlxRelationships.count)
        let placeholderConfidence = placeholderRelationships.map { $0.confidence }.reduce(0, +) / Double(placeholderRelationships.count)
        
        print("  Average Confidence: MLX(\(mlxConfidence)) vs Placeholder(\(placeholderConfidence))")
    }
}

// MARK: - Extension for String Multiplication

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}

// MARK: - Test Runner

func runMLXIntegrationTests() async {
    do {
        let test = try MLXIntegrationTest()
        await test.runIntegrationTests()
    } catch {
        print("❌ Failed to initialize MLX Integration Test: \(error)")
    }
}

// MARK: - Usage Example

/*
// To run the tests:
Task {
    await runMLXIntegrationTests()
}
*/