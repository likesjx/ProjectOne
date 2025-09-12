//
//  EmbeddingAdapterProtocols.swift
//  ProjectOne
//
//  Created by Claude on 9/10/25.
//  Adapter protocols to bridge SwiftData models with EmbeddingCapable system
//

import Foundation
import SwiftData

// MARK: - SwiftData Embedding Adapter

/// Protocol for SwiftData models that can participate in embedding operations
/// This protocol accommodates SwiftData's limitations (no Sendable, Data storage)
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public protocol SwiftDataEmbeddingCapable: PersistentModel {
    /// Raw embedding data stored as Data for SwiftData compatibility
    var embedding: Data? { get set }
    
    /// Model version used to generate the embedding
    var embeddingModelVersion: String? { get set }
    
    /// Timestamp when embedding was generated
    var embeddingGeneratedAt: Date? { get set }
    
    /// Text content to be used for embedding generation
    var embeddingText: String { get }
    
    /// Check if this model has a valid embedding
    var hasEmbedding: Bool { get }
    
    /// Set embedding data from float array
    func setEmbedding(_ embeddingVector: [Float], modelVersion: String)
    
    /// Get embedding as float array for calculations
    func getEmbedding() -> [Float]?
    
    /// Check if embedding needs regeneration
    func needsEmbeddingUpdate(currentModelVersion: String, maxAge: TimeInterval) -> Bool
}

// MARK: - Embedding Adapter Bridge

/// Bridge that converts SwiftDataEmbeddingCapable to EmbeddingCapable for the embedding service
@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@MainActor
public final class EmbeddingCapableAdapter: EmbeddingCapable {
    private let model: any SwiftDataEmbeddingCapable
    
    public init(wrapping model: any SwiftDataEmbeddingCapable) {
        self.model = model
    }
    
    // MARK: - EmbeddingCapable Implementation
    
    public var embedding: [Float]? {
        get { model.getEmbedding() }
        set { 
            if let embeddingArray = newValue {
                model.setEmbedding(embeddingArray, modelVersion: embeddingModelVersion ?? "unknown")
            } else {
                model.embedding = nil
                model.embeddingModelVersion = nil
                model.embeddingGeneratedAt = nil
            }
        }
    }
    
    public var embeddingTimestamp: Date? {
        get { model.embeddingGeneratedAt }
        set { model.embeddingGeneratedAt = newValue }
    }
    
    public var embeddingModelVersion: String? {
        get { model.embeddingModelVersion }
        set { model.embeddingModelVersion = newValue }
    }
    
    public var needsEmbedding: Bool {
        return !model.hasEmbedding || model.needsEmbeddingUpdate(
            currentModelVersion: embeddingModelVersion ?? "",
            maxAge: 7 * 24 * 3600
        )
    }
    
    public var embeddingText: String {
        return model.embeddingText
    }
    
    public func getEmbedding() -> [Float]? {
        return model.getEmbedding()
    }
    
    public func setEmbedding(_ embedding: [Float]) async {
        model.setEmbedding(embedding, modelVersion: embeddingModelVersion ?? "current")
    }
    
    public func shouldRegenerateEmbedding(maxAge: TimeInterval) -> Bool {
        return model.needsEmbeddingUpdate(
            currentModelVersion: embeddingModelVersion ?? "",
            maxAge: maxAge
        )
    }
    
    /// Access the underlying SwiftData model
    public var underlyingModel: any SwiftDataEmbeddingCapable {
        return model
    }
}

// MARK: - Utility Extensions

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension EmbeddingGenerationService {
    /// Generate embedding for a SwiftData model using adapter pattern
    @MainActor
    public func generateEmbedding<T>(for model: T) async throws -> [Float] where T: SwiftDataEmbeddingCapable {
        let adapter = EmbeddingCapableAdapter(wrapping: model)
        return try await generateEmbedding(for: adapter)
    }
    
    /// Create adapters for a collection of SwiftData models
    @MainActor
    public func createAdapters<T>(for models: [T]) -> [EmbeddingCapableAdapter] where T: SwiftDataEmbeddingCapable {
        return models.map { EmbeddingCapableAdapter(wrapping: $0) }
    }
}

// MARK: - EmbeddingUtils Extensions for SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
extension EmbeddingUtils {
    /// Convert embedding float array to Data for SwiftData storage
    public static func embeddingToData(_ embedding: [Float]) -> Data {
        return embedding.withUnsafeBytes { Data($0) }
    }
    
    /// Convert Data back to embedding float array for calculations
    public static func dataToEmbedding(_ data: Data) -> [Float] {
        return data.withUnsafeBytes { bytes in
            let floatBuffer = bytes.bindMemory(to: Float.self)
            return Array(floatBuffer)
        }
    }
}