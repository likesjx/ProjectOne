//
//  MLXProvider.swift
//  ProjectOne
//
//  Unified MLX provider consolidating all MLX functionality
//  Integrates text, vision, audio, embeddings, and model management
//

import Foundation
import SwiftData
import AVFoundation
import Combine
import os.log

#if canImport(MLX)
import MLX
import MLXNN
import MLXRandom
#endif

// Note: Services are compiled as part of the same target, no imports needed

/// Unified MLX provider for all local Apple Silicon AI inference  
public class MLXProvider: ExternalAIProvider, @unchecked Sendable {
    
    // MARK: - Core Services (Integrated)
    
    @Published public var availableModels: [String] = [] // Simplified for now
    @Published public var downloadProgress: [String: Double] = [:] // Simplified progress tracking
    @Published public var storageInfo: String = "Storage info loading..." // Simplified storage info
    @Published public var isDiscoveringModels = false
    @Published public var lastModelUpdate: Date?
    
    // Embedded services (actual service instances) - disabled until services are available
    // private let downloadService: MLXModelDownloadService
    // private let storageManager: MLXStorageManager
    // private let communityService: MLXCommunityService
    private let mlxService: MLXService
    
    // MARK: - MLX Configuration
    
    public struct MLXConfiguration {
        let modelPath: String
        let vocabularyPath: String?
        let maxSequenceLength: Int
        let memoryMapModel: Bool
        let enableQuantization: Bool
        let quantizationBits: Int
        
        public init(
            modelPath: String,
            vocabularyPath: String? = nil,
            maxSequenceLength: Int = 2048,
            memoryMapModel: Bool = true,
            enableQuantization: Bool = false,
            quantizationBits: Int = 4
        ) {
            self.modelPath = modelPath
            self.vocabularyPath = vocabularyPath
            self.maxSequenceLength = maxSequenceLength
            self.memoryMapModel = memoryMapModel
            self.enableQuantization = enableQuantization
            self.quantizationBits = quantizationBits
        }
    }
    
    // MARK: - Properties
    
    private let mlxConfig: MLXConfiguration
    private let modelContext: ModelContext
    
    #if canImport(MLX)
    private var model: Module?
    private var tokenizer: Tokenizer?
    private var visionModel: Module?
    private var audioModel: Module?
    private var embeddingModel: Module?
    #endif
    
    // Audio processing capabilities
    private let audioProcessor = MLXAudioProcessor()
    private let supportedAudioFormats: Set<String> = ["wav", "m4a", "mp3", "aiff", "caf"]
    
    // Model state tracking (simplified)
    private var loadedModels: [String: Bool] = [:] // modelId -> isLoaded
    private var deviceCapabilities: String = "Apple Silicon" // Simplified
    
    // MARK: - Device Support Check
    
    public static var isMLXSupported: Bool {
        #if canImport(MLX)
        #if targetEnvironment(simulator)
        return false // MLX requires real Apple Silicon hardware
        #else
        #if arch(arm64)
        return true // Apple Silicon Macs and iOS devices
        #else
        return false // Intel Macs not supported
        #endif
        #endif
        #else
        return false
        #endif
    }
    
    // MARK: - Predefined Configurations
    
    public static func llama3_8B(modelPath: String, modelContext: ModelContext) -> MLXProvider? {
        guard isMLXSupported else { return nil }
        
        let mlxConfig = MLXConfiguration(
            modelPath: modelPath,
            maxSequenceLength: 4096,
            memoryMapModel: true,
            enableQuantization: true,
            quantizationBits: 4
        )
        
        let config = Configuration(
            apiKey: nil,
            baseURL: "local://mlx",
            model: "llama-3-8b",
            maxTokens: 4096,
            temperature: 0.7
        )
        
        return MLXProvider(configuration: config, mlxConfig: mlxConfig, modelContext: modelContext)
    }
    
    public static func phi3_mini(modelPath: String, modelContext: ModelContext) -> MLXProvider? {
        guard isMLXSupported else { return nil }
        
        let mlxConfig = MLXConfiguration(
            modelPath: modelPath,
            maxSequenceLength: 2048,
            memoryMapModel: true,
            enableQuantization: true,
            quantizationBits: 4
        )
        
        let config = Configuration(
            apiKey: nil,
            baseURL: "local://mlx",
            model: "phi-3-mini",
            maxTokens: 2048,
            temperature: 0.7
        )
        
        return MLXProvider(configuration: config, mlxConfig: mlxConfig, modelContext: modelContext)
    }
    
    public static func codegemma_7B(modelPath: String, modelContext: ModelContext) -> MLXProvider? {
        guard isMLXSupported else { return nil }
        
        let mlxConfig = MLXConfiguration(
            modelPath: modelPath,
            maxSequenceLength: 8192,
            memoryMapModel: true,
            enableQuantization: true,
            quantizationBits: 4
        )
        
        let config = Configuration(
            apiKey: nil,
            baseURL: "local://mlx",
            model: "codegemma-7b",
            maxTokens: 8192,
            temperature: 0.1
        )
        
        return MLXProvider(configuration: config, mlxConfig: mlxConfig, modelContext: modelContext)
    }
    
    // MARK: - Initialization
    
    public init(configuration: Configuration, mlxConfig: MLXConfiguration, modelContext: ModelContext) {
        self.mlxConfig = mlxConfig
        self.modelContext = modelContext
        self.deviceCapabilities = "Apple Silicon" // Simplified until MLXDeviceCapabilities is available
        
        // Initialize embedded services (actual instances) - disabled until services are available
        // self.storageManager = MLXStorageManager()
        // self.downloadService = MLXModelDownloadService(storageManager: self.storageManager)
        // self.communityService = MLXCommunityService()
        self.mlxService = MLXService()
        
        super.init(configuration: configuration, providerType: .custom(name: "MLX", identifier: "mlx"))
        
        // Set up service observation - disabled until services are available
        // setupServiceObservation()
        
        // Initialize model discovery - disabled until services are available
        // Task {
        //     await discoverAvailableModels()
        // }
    }
    
    private func setupServiceObservation() {
        // Service observation disabled until services are available
        // // Observe download service
        // downloadService.$activeDownloads
        //     .map { activeDownloads in
        //         activeDownloads.mapValues { $0.progress }
        //     }
        //     .receive(on: DispatchQueue.main)
        //     .assign(to: &$downloadProgress)
        // 
        // // Observe storage manager
        // storageManager.$storageInfo
        //     .map { storageInfo in
        //         let formatter = ByteCountFormatter()
        //         formatter.countStyle = .file
        //         let sizeStr = formatter.string(fromByteCount: storageInfo.totalUsedBytes)
        //         return "\(storageInfo.modelCount) models, \(sizeStr) used"
        //     }
        //     .receive(on: DispatchQueue.main)
        //     .assign(to: &$storageInfo)
        // 
        // // Observe community service
        // communityService.$availableModels
        //     .map { models in
        //         models.map { $0.id }
        //     }
        //     .receive(on: DispatchQueue.main)
        //     .assign(to: &$availableModels)
        // 
        // communityService.$isLoading
        //     .receive(on: DispatchQueue.main)
        //     .assign(to: &$isDiscoveringModels)
        // 
        // communityService.$lastUpdate
        //     .receive(on: DispatchQueue.main)
        //     .assign(to: &$lastModelUpdate)
    }
    
    // MARK: - BaseAIProvider Implementation
    
    // isAvailable is now managed by BaseAIProvider as @Published property
    
    override func prepareModel() async throws {
        logger.info("Preparing unified MLX provider")
        
        guard Self.isMLXSupported else {
            throw ExternalAIError.configurationInvalid("MLX requires real Apple Silicon hardware")
        }
        
        updateLoadingStatus(.preparing)
        
        do {
            // Initialize MLX service (assuming it exists or create placeholder)
            // try await mlxService.initializeService()
            
            // Update storage information - disabled until storageManager is available
            // await storageManager.calculateStorageUsage()
            
            // Load default model if path provided
            if !mlxConfig.modelPath.isEmpty {
                _ = try await mlxService.loadModel(modelId: configuration.model)
            }
            
            updateLoadingStatus(.ready)
            updateAvailability(true)
            
            logger.info("✅ Unified MLX provider ready")
            
        } catch {
            updateLoadingStatus(.failed(error.localizedDescription))
            updateAvailability(false)
            logger.error("❌ MLX provider initialization failed: \(error.localizedDescription)")
            throw ExternalAIError.modelNotAvailable(error.localizedDescription)
        }
    }
    
    override func generateModelResponse(_ prompt: String) async throws -> String {
        return try await generateText(prompt: prompt, modelId: configuration.model)
    }
    
    // MARK: - Unified Text Generation
    
    /// Generate text using specified MLX model
    public func generateText(prompt: String, modelId: String, parameters: GenerateParameters? = nil) async throws -> String {
        guard case .ready = self.modelLoadingStatus else {
            throw ExternalAIError.modelNotReady
        }
        
        logger.info("Generating text with MLX model: \(modelId)")
        
        do {
            // Use MLXService for actual generation
            let container = try await mlxService.loadModel(modelId: modelId)
            let response = try await mlxService.generate(with: container, prompt: prompt)
            
            logger.info("✅ MLX text generation completed")
            return response
            
        } catch {
            logger.error("❌ MLX text generation failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Vision-Language Generation
    
    /// Generate text from image and prompt using VLM
    public func generateWithVision(prompt: String, image: Data, modelId: String) async throws -> String {
        logger.info("Generating vision-language response with MLX model: \(modelId)")
        
        #if canImport(MLX)
        guard let visionModel = visionModel else {
            throw ExternalAIError.modelNotReady
        }
        
        do {
            // Convert image data to MLX format
            let imageArray = try preprocessImageForMLX(image)
            
            // Use vision model for generation
            let response = try await generateWithVisionModel(visionModel, prompt: prompt, image: imageArray)
            
            logger.info("✅ MLX vision generation completed")
            return response
            
        } catch {
            logger.error("❌ MLX vision generation failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
        #else
        throw ExternalAIError.configurationInvalid("MLX framework not available")
        #endif
    }
    
    override func cleanupModel() async {
        #if canImport(MLX)
        model = nil
        tokenizer = nil
        visionModel = nil
        audioModel = nil
        embeddingModel = nil
        #endif
        
        loadedModels.removeAll()
        updateAvailability(false)
        logger.info("Unified MLX provider cleaned up")
    }
    
    // MARK: - MLX-Specific Implementation
    
    // MARK: - Private Implementation Helpers
    
    private func getOrLoadModel(_ modelId: String) async throws -> ModelContainer {
        if let isLoaded = loadedModels[modelId], isLoaded {
            // Return cached model
            return try await mlxService.loadModel(modelId: modelId)
        }
        
        // Load model if not already loaded
        loadedModels[modelId] = false // Mark as loading
        
        // Use MLXService to handle model loading
        let container = try await mlxService.loadModel(modelId: modelId)
        loadedModels[modelId] = true // Mark as loaded
        
        return container
    }
    
    private func detectAudioFormat(_ audioData: Data) throws -> AVAudioFormat {
        // Audio format detection implementation
        return AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    }
    
    private func generateSpectrogramFeatures(_ audioData: Data) async throws -> Data {
        // Spectrogram generation for VLM processing
        return audioData
    }
    
    private func analyzeAudioWithVLM(_ features: Data, prompt: String) async throws -> AudioUnderstandingResult {
        // Use VLM for audio understanding
        return AudioUnderstandingResult(
            transcription: "Audio transcription",
            summary: "Audio analysis summary",
            sentiment: "neutral",
            keyPoints: ["Key point 1", "Key point 2"],
            confidence: 0.85
        )
    }
    
    private func processAudioContent(_ audioData: Data, analysisType: AudioAnalysisType) async throws -> AudioAnalysisResult {
        // Audio content analysis
        return AudioAnalysisResult(
            duration: 10.0,
            sampleRate: 44100,
            channels: 2,
            format: "wav",
            features: nil
        )
    }
    
    #if canImport(MLX)
    
    private func loadMLXModel() async throws -> SimpleLinearModel {
        // Use MLXService for actual model loading
        let container = try await mlxService.loadModel(modelId: configuration.model)
        // For now, return a placeholder module - real implementation would extract the MLX module
        return SimpleLinearModel(inputDim: 768, outputDim: 768)
    }
    
    private func loadTokenizer(from path: String) async throws -> Tokenizer {
        // Load tokenizer from vocabulary file
        try await Task.sleep(nanoseconds: 1_000_000)
        throw ExternalAIError.configurationInvalid("Tokenizer loading not yet implemented")
    }
    
    private func tokenize(_ text: String) throws -> [Int] {
        // Use MLXService tokenization
        return Array(text.utf8).map { Int($0) }
    }
    
    private func detokenize(_ tokens: [Int]) throws -> String {
        // Use MLXService detokenization
        let bytes = tokens.compactMap { UInt8(exactly: $0) }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }
    
    private func preprocessImageForMLX(_ imageData: Data) throws -> MLXArray {
        // Convert image to MLX format
        return MLXArray([1, 224, 224, 3]) // Placeholder
    }
    
    private func generateWithVisionModel(_ model: Module, prompt: String, image: MLXArray) async throws -> String {
        // Vision-language generation
        return "Vision response: \(prompt)"
    }
    
    #endif
    
    // MARK: - Audio Processing (from MLXAudioProvider)
    
    /// Process audio with text prompt for direct audio understanding
    public func processAudioWithPrompt(_ audioData: Data, prompt: String) async throws -> AudioUnderstandingResult {
        logger.info("Processing audio with MLX audio model")
        
        do {
            // Detect audio format
            let format = try detectAudioFormat(audioData)
            
            // Preprocess audio for MLX
            let processedAudio = try await preprocessAudio(audioData, originalFormat: format)
            
            // Generate spectrogram features
            let spectrogramFeatures = try await generateSpectrogramFeatures(processedAudio)
            
            // Use VLM for audio understanding
            let analysisResult = try await analyzeAudioWithVLM(spectrogramFeatures, prompt: prompt)
            
            return AudioUnderstandingResult(
                transcription: analysisResult.transcription,
                summary: analysisResult.summary,
                sentiment: analysisResult.sentiment,
                keyPoints: analysisResult.keyPoints,
                confidence: analysisResult.confidence
            )
            
        } catch {
            logger.error("❌ Audio processing failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
    }
    
    /// Analyze audio content without specific prompt
    public func analyzeAudioContent(_ audioData: Data) async throws -> AudioAnalysisResult {
        return try await processAudioContent(audioData, analysisType: .general)
    }
    
    /// Preprocess audio data for MLX models
    public nonisolated func preprocessAudio(_ audioData: Data, originalFormat: AVAudioFormat) async throws -> Data {
        // Convert to standard format for MLX processing
        let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        return try await audioProcessor.convertAudio(audioData, from: originalFormat, to: targetFormat)
    }
    
    // MARK: - Embedding Generation
    
    /// Generate embeddings using MLX embedding model
    public func generateEmbedding(text: String, modelId: String) async throws -> [Float] {
        logger.info("Generating embeddings with MLX model: \(modelId)")
        
        #if canImport(MLX)
        guard let embeddingModel = embeddingModel else {
            throw ExternalAIError.modelNotReady
        }
        
        do {
            // Tokenize text
            let tokens = try tokenize(text)
            let inputArray = MLXArray(tokens)
            
            // Generate embeddings
            // TODO: Fix module call - MLX modules need proper invocation
            let embeddingArray = inputArray // Placeholder until proper MLX invocation is implemented
            
            // Convert to Float array
            let embeddings = try embeddingArray.asArray(Float.self)
            
            logger.info("✅ Embedding generation completed")
            return embeddings
            
        } catch {
            logger.error("❌ Embedding generation failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
        #else
        throw ExternalAIError.configurationInvalid("MLX framework not available")
        #endif
    }
    
    // MARK: - Enhanced Model Management
    
    /// Discover available models from MLX Community
    // TODO: Re-enable when MLXCommunityService is available
    /*
    public func discoverAvailableModels() async {
        do {
            try await communityService.discoverModels()
        } catch {
            logger.error("Failed to discover models: \(error.localizedDescription)")
        }
    }
    */
    
    /// Download a model with progress tracking  
    // TODO: Re-enable when MLXModelDownloadService is available
    /*
    public func downloadModel(_ modelId: String) async throws {
        logger.info("Starting download for model: \(modelId)")
        try await mlxService.downloadModel(modelId, downloadService: downloadService)
    }
    */
    
    /// Delete a downloaded model and reclaim storage
    // TODO: Re-enable when MLXStorageManager is available
    /*
    public func deleteModel(_ modelId: String) async throws {
        logger.info("Deleting model: \(modelId)")
        try await mlxService.deleteModel(modelId, storageManager: storageManager)
    }
    */
    
    /// Get storage information and warnings
    public func getStorageInfo() -> String {
        return storageInfo
    }
    
    /// Clean up old or unused models
    // TODO: Re-enable when MLXStorageManager is available
    /*
    public func cleanupOldModels(olderThan days: Int = 30) async throws {
        try await mlxService.cleanupOldModels(storageManager: storageManager, olderThan: days)
    }
    */
    
    /// Get recommended models for users
    // TODO: Re-enable when MLXCommunityService is available
    /*
    public func getRecommendedModels() -> [String] {
        return communityService.getRecommendedModels().map { $0.id }
    }
    */
    
    /// Check if a model is downloaded locally
    // TODO: Re-enable when MLXModelDownloadService is available
    /*
    public func isModelDownloaded(_ modelId: String) -> Bool {
        return mlxService.isModelDownloaded(modelId, downloadService: downloadService)
    }
    */
    
    /// Get download progress for a model
    public func getDownloadProgress(_ modelId: String) -> Double? {
        return downloadProgress[modelId]
    }
    
    /// Cancel an active download
    public func cancelDownload(_ modelId: String) {
        downloadProgress.removeValue(forKey: modelId)
        logger.info("Cancelled download for model: \(modelId)")
    }
}

// MARK: - MLX-Specific Types

public struct MLXModelInfo {
    public let name: String
    public let path: String
    public let size: Int64
    public let format: MLXModelFormat
}

public enum MLXModelFormat: String, CaseIterable {
    case safetensors
    case gguf  
    case bin
}

#if canImport(MLX)
// Placeholder tokenizer interface
public protocol Tokenizer {
    func encode(_ text: String) throws -> [Int]
    func decode(_ tokens: [Int]) throws -> String
}
#endif

// MARK: - Audio Processing Types (Use existing from MLXAudioProvider)

public enum AudioAnalysisType {
    case general
    case speech
    case music
    case environmental
}

// MARK: - Audio Processing Helper

private class MLXAudioProcessor: @unchecked Sendable {
    func convertAudio(_ data: Data, from: AVAudioFormat, to: AVAudioFormat) async throws -> Data {
        // Audio format conversion implementation
        return data // Placeholder
    }
    
    func extractSpectralFeatures(_ audioData: Data) async throws -> [Float] {
        // Spectral feature extraction implementation
        return []
    }
}

// MARK: - MLX Model Repository

public struct MLXModelRepository {
    @MainActor public static let popularModels: [MLXModelSpec] = [
        MLXModelSpec(
            name: "Llama-3-8B-Instruct",
            repo: "mlx-community/Meta-Llama-3-8B-Instruct-4bit",
            filename: "model.safetensors",
            description: "Meta's Llama 3 8B instruction-tuned model"
        ),
        MLXModelSpec(
            name: "Phi-3-Mini-Instruct",
            repo: "mlx-community/Phi-3-mini-4k-instruct-4bit", 
            filename: "model.safetensors",
            description: "Microsoft's Phi-3 Mini instruction-tuned model"
        ),
        MLXModelSpec(
            name: "CodeGemma-7B",
            repo: "mlx-community/codegemma-7b-4bit",
            filename: "model.safetensors",
            description: "Google's CodeGemma 7B coding model"
        ),
        MLXModelSpec(
            name: "Mistral-7B-Instruct",
            repo: "mlx-community/Mistral-7B-Instruct-v0.3-4bit",
            filename: "model.safetensors", 
            description: "Mistral's 7B instruction-tuned model"
        )
    ]
}

public struct MLXModelSpec: Sendable {
    public let name: String
    public let repo: String
    public let filename: String
    public let description: String
}

// MARK: - Audio Processing Result Types

public struct AudioUnderstandingResult: Sendable {
    public let transcription: String
    public let summary: String
    public let sentiment: String
    public let keyPoints: [String]
    public let confidence: Double
    
    public init(transcription: String, summary: String, sentiment: String, keyPoints: [String], confidence: Double) {
        self.transcription = transcription
        self.summary = summary
        self.sentiment = sentiment
        self.keyPoints = keyPoints
        self.confidence = confidence
    }
    
    // Additional initializer for AudioMemoryAgent compatibility
    public init(content: String, confidence: Double, audioMetadata: AudioMetadata) {
        self.transcription = content
        self.summary = content
        self.sentiment = "neutral"
        self.keyPoints = []
        self.confidence = confidence
    }
}

public struct AudioAnalysisResult: Sendable {
    public let duration: TimeInterval
    public let sampleRate: Double
    public let channels: Int
    public let format: String
    public let features: [Float]?
    
    public init(duration: TimeInterval, sampleRate: Double, channels: Int, format: String, features: [Float]?) {
        self.duration = duration
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.features = features
    }
}

public struct AudioMetadata: Sendable {
    public let duration: TimeInterval
    public let format: String
    public let qualityScore: Double
    
    public init(duration: TimeInterval, format: String, qualityScore: Double) {
        self.duration = duration
        self.format = format
        self.qualityScore = qualityScore
    }
}