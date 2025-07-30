//
//  MLXEmbeddingProvider.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/30/25.
//

import Foundation
import Combine
import os.log

#if canImport(MLX)
import MLX
import MLXNN
import MLXRandom
#endif

/// MLX-based embedding provider for local sentence transformer inference
@MainActor
public class MLXEmbeddingProvider: ObservableObject {
    
    // MARK: - Configuration
    
    public struct EmbeddingModelConfig {
        let modelName: String
        let modelPath: String
        let tokenizerPath: String?
        let dimension: Int
        let maxSequenceLength: Int
        let meanPooling: Bool
        let normalizeEmbeddings: Bool
        
        public init(
            modelName: String,
            modelPath: String,
            tokenizerPath: String? = nil,
            dimension: Int,
            maxSequenceLength: Int = 512,
            meanPooling: Bool = true,
            normalizeEmbeddings: Bool = true
        ) {
            self.modelName = modelName
            self.modelPath = modelPath
            self.tokenizerPath = tokenizerPath
            self.dimension = dimension
            self.maxSequenceLength = maxSequenceLength
            self.meanPooling = meanPooling
            self.normalizeEmbeddings = normalizeEmbeddings
        }
    }
    
    // MARK: - Published Properties
    
    @Published public var isModelLoaded = false
    @Published public var isGenerating = false
    @Published public var loadingProgress: Double = 0.0
    @Published public var lastError: String?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXEmbeddingProvider")
    private let _config: EmbeddingModelConfig
    
    /// Public access to the embedding model configuration
    public var config: EmbeddingModelConfig {
        return _config
    }
    
    #if canImport(MLX)
    private var model: Module?
    private var tokenizer: EmbeddingTokenizer?
    #endif
    
    // MARK: - Model Loading Status
    
    public enum LoadingStatus {
        case notLoaded
        case loading(progress: Double)
        case loaded
        case failed(String)
    }
    
    @Published public private(set) var loadingStatus: LoadingStatus = .notLoaded
    
    // MARK: - Predefined Configurations
    
    public static func miniLM_L6_v2(modelPath: String) -> MLXEmbeddingProvider {
        let config = EmbeddingModelConfig(
            modelName: "all-MiniLM-L6-v2",
            modelPath: modelPath,
            dimension: 384,
            maxSequenceLength: 512,
            meanPooling: true,
            normalizeEmbeddings: true
        )
        return MLXEmbeddingProvider(config: config)
    }
    
    public static func mpnet_base_v2(modelPath: String) -> MLXEmbeddingProvider {
        let config = EmbeddingModelConfig(
            modelName: "all-mpnet-base-v2",
            modelPath: modelPath,
            dimension: 768,
            maxSequenceLength: 512,
            meanPooling: true,
            normalizeEmbeddings: true
        )
        return MLXEmbeddingProvider(config: config)
    }
    
    public static func e5_large_multilingual(modelPath: String) -> MLXEmbeddingProvider {
        let config = EmbeddingModelConfig(
            modelName: "multilingual-e5-large",
            modelPath: modelPath,
            dimension: 1024,
            maxSequenceLength: 512,
            meanPooling: true,
            normalizeEmbeddings: true
        )
        return MLXEmbeddingProvider(config: config)
    }
    
    // MARK: - Device Support
    
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
    
    // MARK: - Initialization
    
    public init(config: EmbeddingModelConfig) {
        self._config = config
        logger.info("MLX Embedding Provider initialized with model: \(config.modelName)")
    }
    
    // MARK: - Model Management
    
    /// Load the embedding model from disk
    public func loadModel() async throws {
        guard Self.isMLXSupported else {
            throw EmbeddingError.unsupportedPlatform("MLX requires Apple Silicon hardware")
        }
        
        guard !isModelLoaded else {
            logger.info("Model already loaded")
            return
        }
        
        logger.info("Loading MLX embedding model: \(self._config.modelName)")
        loadingStatus = .loading(progress: 0.0)
        loadingProgress = 0.0
        lastError = nil
        
        #if canImport(MLX)
        do {
            // Check if model file exists
            guard FileManager.default.fileExists(atPath: self._config.modelPath) else {
                throw EmbeddingError.modelNotFound("Model file not found at: \(self._config.modelPath)")
            }
            
            loadingProgress = 0.2
            loadingStatus = .loading(progress: 0.2)
            
            // Load model weights (placeholder - actual implementation depends on MLX model format)
            logger.info("Loading model weights from: \(self._config.modelPath)")
            model = try await loadMLXEmbeddingModel()
            
            loadingProgress = 0.7
            loadingStatus = .loading(progress: 0.7)
            
            // Load tokenizer if available
            if let tokenizerPath = self._config.tokenizerPath {
                logger.info("Loading tokenizer from: \(tokenizerPath)")
                tokenizer = try await loadTokenizer(from: tokenizerPath)
            } else {
                // Use simple whitespace tokenizer as fallback
                tokenizer = SimpleWhitespaceTokenizer(maxLength: self._config.maxSequenceLength)
            }
            
            loadingProgress = 1.0
            loadingStatus = .loaded
            isModelLoaded = true
            
            logger.info("✅ MLX embedding model loaded successfully")
            
        } catch {
            let errorMessage = "Failed to load MLX embedding model: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            loadingStatus = .failed(errorMessage)
            lastError = errorMessage
            isModelLoaded = false
            throw EmbeddingError.modelLoadingFailed(errorMessage)
        }
        #else
        throw EmbeddingError.unsupportedPlatform("MLX framework not available")
        #endif
    }
    
    /// Unload the model and free memory
    public func unloadModel() {
        #if canImport(MLX)
        model = nil
        tokenizer = nil
        #endif
        isModelLoaded = false
        loadingStatus = .notLoaded
        loadingProgress = 0.0
        logger.info("MLX embedding model unloaded")
    }
    
    // MARK: - Embedding Generation
    
    /// Generate embedding for a single text
    public func generateEmbedding(for text: String) async throws -> [Float] {
        guard isModelLoaded else {
            throw EmbeddingError.modelNotLoaded("Model must be loaded before generating embeddings")
        }
        
        return try await generateEmbeddings(for: [text]).first ?? []
    }
    
    /// Generate embeddings for multiple texts in batch
    public func generateEmbeddings(for texts: [String]) async throws -> [[Float]] {
        guard isModelLoaded else {
            throw EmbeddingError.modelNotLoaded("Model must be loaded before generating embeddings")
        }
        
        guard !texts.isEmpty else {
            return []
        }
        
        logger.info("Generating embeddings for \(texts.count) texts")
        isGenerating = true
        
        defer {
            isGenerating = false
        }
        
        #if canImport(MLX)
        guard let model = model, let tokenizer = tokenizer else {
            throw EmbeddingError.modelNotLoaded("Model or tokenizer not available")
        }
        
        do {
            var embeddings: [[Float]] = []
            
            // Process in batches to manage memory
            let batchSize = 8
            for i in stride(from: 0, to: texts.count, by: batchSize) {
                let endIndex = min(i + batchSize, texts.count)
                let batch = Array(texts[i..<endIndex])
                
                let batchEmbeddings = try await processBatch(batch, model: model, tokenizer: tokenizer)
                embeddings.append(contentsOf: batchEmbeddings)
                
                // Small delay to prevent overwhelming the system
                if i + batchSize < texts.count {
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
            }
            
            logger.info("✅ Generated \(embeddings.count) embeddings")
            return embeddings
            
        } catch {
            logger.error("❌ Failed to generate embeddings: \(error.localizedDescription)")
            throw EmbeddingError.generationFailed(error.localizedDescription)
        }
        #else
        throw EmbeddingError.unsupportedPlatform("MLX framework not available")
        #endif
    }
    
    // MARK: - Private Implementation
    
    #if canImport(MLX)
    
    private func loadMLXEmbeddingModel() async throws -> Module {
        // This is a placeholder for the actual MLX model loading
        // The real implementation would depend on the specific MLX embedding model format
        
        // For sentence transformers converted to MLX, this would typically involve:
        // 1. Loading the model weights from safetensors or MLX format
        // 2. Constructing the transformer architecture
        // 3. Loading the weights into the model
        
        // Example structure for BERT-based sentence transformer:
        // let weights = try MLX.loadSafetensors(url: URL(fileURLWithPath: config.modelPath))
        // let model = try BertEmbeddingModel(weights: weights, config: transformerConfig)
        
        throw EmbeddingError.notImplemented("MLX embedding model loading not yet implemented - requires actual MLX sentence transformer support")
    }
    
    private func loadTokenizer(from path: String) async throws -> EmbeddingTokenizer {
        // Load tokenizer from file (typically a tokenizer.json file)
        // This would use the HuggingFace tokenizers format
        throw EmbeddingError.notImplemented("Advanced tokenizer loading not yet implemented")
    }
    
    private func processBatch(_ texts: [String], model: Module, tokenizer: EmbeddingTokenizer) async throws -> [[Float]] {
        var embeddings: [[Float]] = []
        
        for text in texts {
            // Tokenize text
            let tokens = try tokenizer.encode(text)
            let truncatedTokens = Array(tokens.prefix(_config.maxSequenceLength))
            
            // Convert to MLX arrays and run through model
            let embedding = try await runInference(tokens: truncatedTokens, model: model)
            embeddings.append(embedding)
        }
        
        return embeddings
    }
    
    private func runInference(tokens: [Int], model: Module) async throws -> [Float] {
        // This is where the actual MLX inference would happen
        // 1. Convert tokens to MLX array
        // 2. Run forward pass through the transformer
        // 3. Apply mean pooling
        // 4. Normalize if configured
        
        // Placeholder implementation:
        throw EmbeddingError.notImplemented("MLX inference not yet implemented - requires actual transformer model")
    }
    
    #endif
    
    // MARK: - Model Repository
    
    /// Get information about available embedding models
    public static func getAvailableModels(in directory: String = "~/mlx-embeddings") -> [EmbeddingModelInfo] {
        let expandedPath = NSString(string: directory).expandingTildeInPath
        
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: expandedPath) else {
            return []
        }
        
        return contents.compactMap { filename in
            guard filename.hasSuffix(".safetensors") || filename.contains("embedding") else {
                return nil
            }
            
            let fullPath = "\(expandedPath)/\(filename)"
            let attributes = try? FileManager.default.attributesOfItem(atPath: fullPath)
            let size = attributes?[.size] as? Int64 ?? 0
            
            // Try to determine model type from filename
            let modelType: EmbeddingModelType
            if filename.contains("minilm") {
                modelType = .miniLM
            } else if filename.contains("mpnet") {
                modelType = .mpnet
            } else if filename.contains("e5") {
                modelType = .e5Large
            } else {
                modelType = .unknown
            }
            
            return EmbeddingModelInfo(
                name: filename,
                path: fullPath,
                size: size,
                modelType: modelType,
                dimension: modelType.dimension
            )
        }
    }
    
    /// Download an embedding model from HuggingFace MLX community
    public static func downloadModel(
        modelType: EmbeddingModelType,
        to directory: String = "~/mlx-embeddings"
    ) async throws -> String {
        let expandedPath = NSString(string: directory).expandingTildeInPath
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)
        
        let repo = modelType.huggingFaceMLXRepo
        let filename = "model.safetensors"
        let url = URL(string: "https://huggingface.co/\(repo)/resolve/main/\(filename)")!
        let destinationPath = "\(expandedPath)/\(modelType.rawValue).safetensors"
        
        // Download model file
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        try FileManager.default.moveItem(at: tempURL, to: URL(fileURLWithPath: destinationPath))
        
        return destinationPath
    }
}

// MARK: - Supporting Types

public enum EmbeddingError: LocalizedError {
    case unsupportedPlatform(String)
    case modelNotFound(String)
    case modelLoadingFailed(String)
    case modelNotLoaded(String)
    case generationFailed(String)
    case notImplemented(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform(let message),
             .modelNotFound(let message),
             .modelLoadingFailed(let message),
             .modelNotLoaded(let message),
             .generationFailed(let message),
             .notImplemented(let message):
            return message
        }
    }
}

public struct EmbeddingModelInfo {
    public let name: String
    public let path: String
    public let size: Int64
    public let modelType: EmbeddingModelType
    public let dimension: Int
}

public enum EmbeddingModelType: String, CaseIterable {
    case miniLM = "all-MiniLM-L6-v2"
    case mpnet = "all-mpnet-base-v2"
    case e5Large = "multilingual-e5-large"
    case unknown = "unknown"
    
    public var dimension: Int {
        switch self {
        case .miniLM: return 384
        case .mpnet: return 768
        case .e5Large: return 1024
        case .unknown: return 0
        }
    }
    
    public var displayName: String {
        switch self {
        case .miniLM: return "MiniLM-L6-v2 (384d, fast)"
        case .mpnet: return "MPNet-base-v2 (768d, high quality)"
        case .e5Large: return "E5-Large (1024d, multilingual)"
        case .unknown: return "Unknown Model"
        }
    }
    
    public var huggingFaceMLXRepo: String {
        switch self {
        case .miniLM: return "mlx-community/all-MiniLM-L6-v2"
        case .mpnet: return "mlx-community/all-mpnet-base-v2"
        case .e5Large: return "mlx-community/multilingual-e5-large"
        case .unknown: return ""
        }
    }
}

// MARK: - Tokenizer Protocol

#if canImport(MLX)
public protocol EmbeddingTokenizer {
    func encode(_ text: String) throws -> [Int]
    func decode(_ tokens: [Int]) throws -> String
}

/// Simple whitespace tokenizer as fallback
public class SimpleWhitespaceTokenizer: EmbeddingTokenizer {
    private let maxLength: Int
    private let vocabulary: [String: Int]
    private let reverseVocabulary: [Int: String]
    
    public init(maxLength: Int) {
        self.maxLength = maxLength
        
        // Create a simple vocabulary from common English words and characters
        let commonTokens = [
            "[PAD]", "[UNK]", "[CLS]", "[SEP]", "[MASK]",
            "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by"
        ]
        
        var vocab: [String: Int] = [:]
        var reverseVocab: [Int: String] = [:]
        
        for (index, token) in commonTokens.enumerated() {
            vocab[token] = index
            reverseVocab[index] = token
        }
        
        self.vocabulary = vocab
        self.reverseVocabulary = reverseVocab
    }
    
    public func encode(_ text: String) throws -> [Int] {
        let words = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var tokens: [Int] = [vocabulary["[CLS]"] ?? 2] // Start with CLS token
        
        for word in words.prefix(maxLength - 2) { // Reserve space for CLS and SEP
            let tokenId = vocabulary[word] ?? vocabulary["[UNK]"] ?? 1
            tokens.append(tokenId)
        }
        
        tokens.append(vocabulary["[SEP]"] ?? 3) // End with SEP token
        
        // Pad to consistent length if needed
        while tokens.count < min(maxLength, 64) {
            tokens.append(vocabulary["[PAD]"] ?? 0)
        }
        
        return tokens
    }
    
    public func decode(_ tokens: [Int]) throws -> String {
        return tokens.compactMap { reverseVocabulary[$0] }
            .filter { !["[PAD]", "[CLS]", "[SEP]"].contains($0) }
            .joined(separator: " ")
    }
}
#endif