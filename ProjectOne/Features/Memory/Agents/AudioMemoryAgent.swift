//
//  AudioMemoryAgent.swift
//  ProjectOne
//
//  Enhanced memory agent with direct audio understanding via MLX VLM
//  Bypasses transcription for richer audio context and meaning
//

import Foundation
import SwiftData
import os.log
import Combine
import AVFoundation

/// Memory agent with native audio understanding capabilities
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@MainActor
public class AudioMemoryAgent: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "AudioMemoryAgent")
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private let retrievalEngine: MemoryRetrievalEngine
    private let knowledgeGraphService: KnowledgeGraphService
    private let mlxAudioProvider: MLXAudioProvider
    private let fallbackMemoryAgent: MemoryAgent
    
    // MARK: - State
    
    @Published public var isInitialized = false
    @Published public var processingAudio = false
    @Published public var lastAudioResponse: AudioUnderstandingResult?
    @Published public var errorMessage: String?
    
    // MARK: - Configuration
    
    public struct AudioConfiguration: Sendable {
        let enableDirectAudioProcessing: Bool
        let fallbackToTranscription: Bool
        let maxAudioDuration: TimeInterval
        let audioQualityThreshold: Double
        let enableEmotionalAnalysis: Bool
        let enableSpeakerAnalysis: Bool
        
        public static let `default` = AudioConfiguration(
            enableDirectAudioProcessing: true,
            fallbackToTranscription: true,
            maxAudioDuration: 60.0,
            audioQualityThreshold: 0.7,
            enableEmotionalAnalysis: true,
            enableSpeakerAnalysis: true
        )
    }
    
    private let configuration: AudioConfiguration
    
    // MARK: - Initialization
    
    public init(
        modelContext: ModelContext,
        knowledgeGraphService: KnowledgeGraphService,
        mlxAudioProvider: MLXAudioProvider,
        fallbackMemoryAgent: MemoryAgent,
        configuration: AudioConfiguration = .default
    ) {
        self.modelContext = modelContext
        self.knowledgeGraphService = knowledgeGraphService
        self.mlxAudioProvider = mlxAudioProvider
        self.fallbackMemoryAgent = fallbackMemoryAgent
        self.retrievalEngine = MemoryRetrievalEngine(modelContext: modelContext)
        self.configuration = configuration
        
        logger.info("Audio Memory Agent initializing...")
    }
    
    // MARK: - Lifecycle
    
    public func initialize() async throws {
        logger.info("Starting Audio Memory Agent initialization")
        
        // Initialize MLX Audio provider
        if configuration.enableDirectAudioProcessing {
            try await mlxAudioProvider.prepare()
        }
        
        // Initialize fallback memory agent
        try await fallbackMemoryAgent.initialize()
        
        isInitialized = true
        logger.info("Audio Memory Agent initialization completed")
    }
    
    public func shutdown() async {
        logger.info("Shutting down Audio Memory Agent")
        
        await mlxAudioProvider.cleanup()
        await fallbackMemoryAgent.shutdown()
        
        isInitialized = false
        logger.info("Audio Memory Agent shutdown completed")
    }
    
    // MARK: - Primary Audio Interface
    
    /// Process audio with direct VLM understanding
    public func processAudioMemory(_ audioData: Data, context: String = "") async throws -> AudioMemoryResult {
        guard isInitialized else {
            throw AudioMemoryError.notInitialized
        }
        
        logger.info("Processing audio memory with direct VLM understanding")
        processingAudio = true
        errorMessage = nil
        
        defer {
            processingAudio = false
        }
        
        do {
            // Step 1: Analyze audio quality and decide processing approach
            let shouldUseDirectProcessing = try await shouldProcessDirectly(audioData)
            
            let result: AudioMemoryResult
            
            if shouldUseDirectProcessing && configuration.enableDirectAudioProcessing {
                // Use direct MLX VLM processing
                result = try await processAudioDirectly(audioData, context: context)
            } else if configuration.fallbackToTranscription {
                // Fall back to traditional transcription + text processing
                result = try await processAudioWithTranscription(audioData, context: context)
            } else {
                throw AudioMemoryError.processingMethodUnavailable
            }
            
            // Step 2: Store audio memory with rich context
            try await storeAudioMemory(result, audioData: audioData)
            
            lastAudioResponse = result.understandingResult
            logger.info("Audio memory processed successfully")
            
            return result
            
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Audio memory processing failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Process real-time audio stream
    public func processAudioStream(_ audioStream: AsyncStream<Data>, context: String = "") -> AsyncThrowingStream<AudioMemoryResult, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await audioChunk in audioStream {
                        let result = try await processAudioMemory(audioChunk, context: context)
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Query memories with audio context understanding
    public func queryWithAudioContext(_ query: String, relatedAudio: Data? = nil) async throws -> AudioMemoryResponse {
        logger.info("Querying memories with audio context")
        
        // Retrieve relevant audio memories
        let audioMemories = try await retrieveAudioMemories(for: query)
        
        var audioContext: AudioUnderstandingResult?
        if let audioData = relatedAudio {
            // Analyze the query audio for additional context
            audioContext = try await mlxAudioProvider.processAudioWithPrompt(audioData, prompt: query)
        }
        
        // Generate response considering audio context
        let response = try await generateAudioContextualResponse(
            query: query,
            audioMemories: audioMemories,
            audioContext: audioContext
        )
        
        return response
    }
    
    // MARK: - Direct Audio Processing
    
    private func processAudioDirectly(_ audioData: Data, context: String) async throws -> AudioMemoryResult {
        logger.info("Processing audio directly with MLX VLM")
        
        // Create comprehensive prompt for VLM understanding
        let prompt = createAudioAnalysisPrompt(context: context)
        
        // Process with MLX Audio VLM
        let understandingResult = try await mlxAudioProvider.processAudioWithPrompt(audioData, prompt: prompt)
        
        // Analyze audio characteristics if enabled
        var analysisResult: AudioAnalysisResult?
        if configuration.enableEmotionalAnalysis || configuration.enableSpeakerAnalysis {
            analysisResult = try await mlxAudioProvider.analyzeAudioContent(audioData)
        }
        
        // Extract entities and concepts from the understanding
        let entities = try await extractEntitiesFromAudioUnderstanding(understandingResult)
        let concepts = try await extractConceptsFromAudioUnderstanding(understandingResult)
        
        return AudioMemoryResult(
            understandingResult: understandingResult,
            analysisResult: analysisResult,
            extractedEntities: entities,
            extractedConcepts: concepts,
            processingMethod: .directVLM,
            confidence: understandingResult.confidence
        )
    }
    
    private func processAudioWithTranscription(_ audioData: Data, context: String) async throws -> AudioMemoryResult {
        logger.info("Processing audio with transcription fallback")
        
        // Use traditional transcription + text processing via fallback agent
        let _ = MemoryIngestData(
            type: .transcription,
            content: nil, // Will be generated by transcription
            confidence: 0.8,
            metadata: ["audio_fallback": true, "context": context]
        )
        
        // Process through fallback memory agent (placeholder for transcription)
        // In real implementation, this would transcribe audio first
        let textResponse = try await fallbackMemoryAgent.processQuery("Process this audio content: \(context)")
        
        // Convert to audio memory result format
        let understandingResult = AudioUnderstandingResult(
            content: textResponse.content,
            confidence: textResponse.confidence,
            audioMetadata: AudioMetadata(
                duration: estimateAudioDuration(audioData),
                sampleRate: 44100,
                channels: 1,
                format: "transcription",
                qualityScore: 0.8
            ),
            processingTime: 0.5
        )
        
        return AudioMemoryResult(
            understandingResult: understandingResult,
            analysisResult: nil,
            extractedEntities: [],
            extractedConcepts: [],
            processingMethod: .transcriptionFallback,
            confidence: textResponse.confidence
        )
    }
    
    // MARK: - Audio Quality Analysis
    
    private func shouldProcessDirectly(_ audioData: Data) async throws -> Bool {
        // Analyze audio quality to determine optimal processing method
        let qualityMetrics = analyzeAudioQuality(audioData)
        
        let shouldUseDirect = 
            qualityMetrics.qualityScore >= configuration.audioQualityThreshold &&
            qualityMetrics.duration <= configuration.maxAudioDuration &&
            mlxAudioProvider.isAvailable
        
        logger.info("Audio quality analysis: score=\(qualityMetrics.qualityScore), duration=\(qualityMetrics.duration), use_direct=\(shouldUseDirect)")
        
        return shouldUseDirect
    }
    
    private func analyzeAudioQuality(_ audioData: Data) -> AudioQualityMetrics {
        // Simple quality analysis - could be enhanced with signal processing
        let estimatedDuration = estimateAudioDuration(audioData)
        let estimatedQuality = min(1.0, max(0.3, Double(audioData.count) / 1_000_000.0)) // Simple heuristic
        
        return AudioQualityMetrics(
            qualityScore: estimatedQuality,
            duration: estimatedDuration,
            noiseLevel: 0.3,
            clarity: estimatedQuality
        )
    }
    
    private func estimateAudioDuration(_ audioData: Data) -> TimeInterval {
        // Simple duration estimation - would be more accurate with audio format parsing
        return Double(audioData.count) / (44100.0 * 2.0) // Assume 44.1kHz 16-bit
    }
    
    // MARK: - Memory Storage
    
    private func storeAudioMemory(_ result: AudioMemoryResult, audioData: Data) async throws {
        logger.info("Storing audio memory with rich context")
        
        // Create STM entry with audio context in tags and metadata
        let audioSTM = STMEntry(
            content: result.understandingResult.content,
            memoryType: .episodic,
            importance: result.confidence,
            sourceNoteId: nil,
            relatedEntities: result.extractedEntities.map { $0.id },
            emotionalWeight: result.analysisResult?.emotionalTone != nil ? Double(result.analysisResult!.emotionalTone.rawValue.count) / 10.0 : 0.0,
            contextTags: generateContextTags(from: result) + ["audio_processed", result.processingMethod.rawValue]
        )
        
        modelContext.insert(audioSTM)
        try modelContext.save()
        
        // Create knowledge graph connections
        try await createAudioKnowledgeConnections(result)
        
        logger.info("Audio memory stored successfully")
    }
    
    private func generateContextTags(from result: AudioMemoryResult) -> [String] {
        var tags = ["audio_memory", result.processingMethod.rawValue]
        
        if let analysis = result.analysisResult {
            tags.append("emotional_\(analysis.emotionalTone.rawValue)")
            tags.append(contentsOf: analysis.contentCategories)
        }
        
        tags.append(contentsOf: result.extractedConcepts)
        
        return tags
    }
    
    // MARK: - Entity and Concept Extraction
    
    private func extractEntitiesFromAudioUnderstanding(_ understanding: AudioUnderstandingResult) async throws -> [Entity] {
        // Extract entities from the VLM understanding of audio
        // This could use the understanding content or additional VLM analysis
        
        // Placeholder - would use the audio understanding to identify entities
        return []
    }
    
    private func extractConceptsFromAudioUnderstanding(_ understanding: AudioUnderstandingResult) async throws -> [String] {
        // Extract concepts and themes from audio understanding
        
        // Simple keyword extraction from understanding content
        let words = understanding.content.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 4 }
            .filter { !["the", "and", "but", "for", "with", "from"].contains($0) }
        
        return Array(Set(words.prefix(10)))
    }
    
    private func createAudioKnowledgeConnections(_ result: AudioMemoryResult) async throws {
        // Create knowledge graph connections based on audio understanding
        // This would link audio concepts to existing knowledge
        
        logger.info("Creating audio knowledge graph connections")
    }
    
    // MARK: - Audio Memory Retrieval
    
    private func retrieveAudioMemories(for query: String) async throws -> [STMEntry] {
        // Retrieve audio memories relevant to the query (identified by context tags)
        let descriptor = FetchDescriptor<STMEntry>(
            predicate: #Predicate { entry in
                entry.contextTags.contains("audio_processed") &&
                (entry.content.localizedStandardContains(query) ||
                 entry.contextTags.contains { $0.localizedStandardContains(query) })
            },
            sortBy: [SortDescriptor<STMEntry>(\.importance, order: .reverse)]
        )
        
        return try modelContext.fetch(descriptor)
    }
    
    private func generateAudioContextualResponse(
        query: String,
        audioMemories: [STMEntry],
        audioContext: AudioUnderstandingResult?
    ) async throws -> AudioMemoryResponse {
        
        // Generate response considering audio context and memories
        let contextualPrompt = createContextualPrompt(query: query, memories: audioMemories, audioContext: audioContext)
        
        // Use the appropriate provider based on audio context
        let response: String
        if audioContext != nil {
            // Use audio-aware generation if we have audio context
            response = try await mlxAudioProvider.processAudioWithPrompt(Data(), prompt: contextualPrompt).content
        } else {
            // Fall back to text generation
            response = try await fallbackMemoryAgent.processQuery(contextualPrompt).content
        }
        
        return AudioMemoryResponse(
            content: response,
            audioMemoriesUsed: audioMemories,
            audioContext: audioContext,
            confidence: audioContext?.confidence ?? 0.8
        )
    }
    
    // MARK: - Prompt Generation
    
    private func createAudioAnalysisPrompt(context: String) -> String {
        return """
        Analyze this audio comprehensively, understanding not just the words but the full context:
        
        Context: \(context)
        
        Please provide:
        1. The main content and meaning
        2. Emotional tone and speaker characteristics  
        3. Key concepts, entities, and themes
        4. Contextual significance and implications
        5. Any relevant memories or connections this might trigger
        
        Focus on deep understanding beyond just transcription.
        """
    }
    
    private func createContextualPrompt(query: String, memories: [STMEntry], audioContext: AudioUnderstandingResult?) -> String {
        var prompt = "Query: \(query)\n\nRelevant Audio Memories:\n"
        
        for memory in memories.prefix(5) {
            prompt += "- \(memory.content)\n"
        }
        
        if let audioCtx = audioContext {
            prompt += "\nCurrent Audio Context:\n\(audioCtx.content)\n"
        }
        
        prompt += "\nProvide a comprehensive response considering all audio context and memories."
        
        return prompt
    }
}

// MARK: - Supporting Types

public struct AudioMemoryResult: @unchecked Sendable {
    public let understandingResult: AudioUnderstandingResult
    public let analysisResult: AudioAnalysisResult?
    public let extractedEntities: [Entity]
    public let extractedConcepts: [String]
    public let processingMethod: ProcessingMethod
    public let confidence: Double
}

public struct AudioMemoryResponse {
    public let content: String
    public let audioMemoriesUsed: [STMEntry]
    public let audioContext: AudioUnderstandingResult?
    public let confidence: Double
}

public struct AudioQualityMetrics {
    public let qualityScore: Double
    public let duration: TimeInterval
    public let noiseLevel: Double
    public let clarity: Double
}

public enum ProcessingMethod: String, Sendable {
    case directVLM = "direct_vlm"
    case transcriptionFallback = "transcription_fallback"
}

public enum AudioMemoryError: Error, LocalizedError {
    case notInitialized
    case processingMethodUnavailable
    case audioQualityTooLow
    case durationTooLong
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Audio Memory Agent not initialized"
        case .processingMethodUnavailable:
            return "No audio processing method available"
        case .audioQualityTooLow:
            return "Audio quality too low for processing"
        case .durationTooLong:
            return "Audio duration exceeds maximum allowed"
        }
    }
}

// MARK: - Enhanced Memory Models
// Note: Using regular STMEntry with audio context stored in contextTags for SwiftData compatibility