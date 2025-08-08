//
//  EmbeddingUtils.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/30/25.
//

import Foundation
import Accelerate
import os.log

/// Utilities for vector embeddings and similarity calculations
public class EmbeddingUtils {
    
    private static let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "EmbeddingUtils")
    
    // MARK: - Vector Operations
    
    /// Calculate cosine similarity between two embedding vectors
    /// Returns a value between -1.0 and 1.0, where 1.0 means identical vectors
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else {
            logger.warning("Cannot compute cosine similarity: vectors have different dimensions or are empty")
            return 0.0
        }
        
        // Use Accelerate framework for optimized vector operations
        let n = vDSP_Length(a.count)
        var dotProduct: Float = 0.0
        var magnitudeA: Float = 0.0
        var magnitudeB: Float = 0.0
        
        // Calculate dot product
        vDSP_dotpr(a, 1, b, 1, &dotProduct, n)
        
        // Calculate magnitudes
        var aSquared = [Float](repeating: 0.0, count: a.count)
        var bSquared = [Float](repeating: 0.0, count: b.count)
        
        vDSP_vsq(a, 1, &aSquared, 1, n)
        vDSP_vsq(b, 1, &bSquared, 1, n)
        
        vDSP_sve(aSquared, 1, &magnitudeA, n)
        vDSP_sve(bSquared, 1, &magnitudeB, n)
        
        magnitudeA = sqrt(magnitudeA)
        magnitudeB = sqrt(magnitudeB)
        
        // Avoid division by zero
        guard magnitudeA > 0 && magnitudeB > 0 else {
            logger.warning("Cannot compute cosine similarity: one or both vectors have zero magnitude")
            return 0.0
        }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    /// Calculate cosine similarities between a query vector and multiple candidate vectors
    /// Returns array of similarities in the same order as candidates
    public static func batchCosineSimilarity(query: [Float], candidates: [[Float]]) -> [Float] {
        return candidates.map { candidate in
            cosineSimilarity(query, candidate)
        }
    }
    
    /// Normalize a vector to unit length (L2 normalization)
    public static func normalizeVector(_ vector: [Float]) -> [Float] {
        let n = vDSP_Length(vector.count)
        var magnitude: Float = 0.0
        var squared = [Float](repeating: 0.0, count: vector.count)
        
        // Calculate magnitude
        vDSP_vsq(vector, 1, &squared, 1, n)
        vDSP_sve(squared, 1, &magnitude, n)
        magnitude = sqrt(magnitude)
        
        guard magnitude > 0 else {
            logger.warning("Cannot normalize vector: magnitude is zero")
            return vector
        }
        
        // Normalize
        var normalized = [Float](repeating: 0.0, count: vector.count)
        vDSP_vsdiv(vector, 1, &magnitude, &normalized, 1, n)
        
        return normalized
    }
    
    // MARK: - Data Conversion
    
    /// Convert embedding vector to Data for SwiftData storage
    public static func embeddingToData(_ embedding: [Float]) -> Data {
        return embedding.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }
    
    /// Convert Data back to embedding vector for calculations
    public static func dataToEmbedding(_ data: Data) -> [Float] {
        return data.withUnsafeBytes { bytes in
            Array(bytes.bindMemory(to: Float.self))
        }
    }
    
    /// Validate that data represents a valid embedding of expected dimension
    public static func validateEmbeddingData(_ data: Data, expectedDimension: Int) -> Bool {
        let actualDimension = data.count / MemoryLayout<Float>.size
        return actualDimension == expectedDimension
    }
    
    // MARK: - Similarity Search
    
    /// Find the most similar embeddings to a query vector
    /// Returns tuples of (index, similarity_score) sorted by similarity descending
    public static func findMostSimilar(
        query: [Float],
        embeddings: [[Float]],
        topK: Int = 10,
        threshold: Float = 0.0
    ) -> [(index: Int, similarity: Float)] {
        
        let similarities = batchCosineSimilarity(query: query, candidates: embeddings)
        
        let indexedSimilarities = similarities.enumerated().compactMap { (index, similarity) in
            similarity >= threshold ? (index: index, similarity: similarity) : nil
        }
        
        return Array(indexedSimilarities
            .sorted { $0.similarity > $1.similarity }
            .prefix(topK))
    }
    
    /// Calculate semantic similarity score between two text embeddings
    /// Returns a normalized score between 0.0 and 1.0
    public static func semanticSimilarityScore(_ embedding1: [Float], _ embedding2: [Float]) -> Float {
        let cosineSim = cosineSimilarity(embedding1, embedding2)
        // Convert from [-1, 1] to [0, 1] range
        return (cosineSim + 1.0) / 2.0
    }
    
    // MARK: - Memory Type Extensions
    
    /// Calculate average embedding from a collection of embeddings
    /// Useful for creating cluster centroids or topic embeddings
    public static func averageEmbedding(_ embeddings: [[Float]]) -> [Float]? {
        guard !embeddings.isEmpty else { return nil }
        guard let firstEmbedding = embeddings.first else { return nil }
        
        let dimension = firstEmbedding.count
        var result = [Float](repeating: 0.0, count: dimension)
        
        // Sum all embeddings
        for embedding in embeddings {
            guard embedding.count == dimension else {
                logger.error("Inconsistent embedding dimensions in average calculation")
                return nil
            }
            
            for i in 0..<dimension {
                result[i] += embedding[i]
            }
        }
        
        // Divide by count to get average
        let count = Float(embeddings.count)
        for i in 0..<dimension {
            result[i] /= count
        }
        
        return result
    }
    
    /// Calculate embedding diversity score (average pairwise distance)
    /// Higher scores indicate more diverse/varied content
    public static func embeddingDiversityScore(_ embeddings: [[Float]]) -> Float {
        guard embeddings.count > 1 else { return 0.0 }
        
        var totalSimilarity: Float = 0.0
        var pairCount = 0
        
        for i in 0..<embeddings.count {
            for j in (i+1)..<embeddings.count {
                let similarity = cosineSimilarity(embeddings[i], embeddings[j])
                totalSimilarity += similarity
                pairCount += 1
            }
        }
        
        let averageSimilarity = totalSimilarity / Float(pairCount)
        // Return diversity as 1 - average_similarity
        return 1.0 - averageSimilarity
    }
}

// MARK: - Embedding Quality Metrics

extension EmbeddingUtils {
    
    /// Validate embedding quality and detect potential issues
    public struct EmbeddingQualityReport {
        public let isValid: Bool
        public let dimension: Int
        public let magnitude: Float
        public let hasNaN: Bool
        public let hasInfinite: Bool
        public let isNormalized: Bool
        public let qualityScore: Float // 0.0 to 1.0
        
        public var issues: [String] {
            var problems: [String] = []
            if hasNaN { problems.append("Contains NaN values") }
            if hasInfinite { problems.append("Contains infinite values") }
            if magnitude < 0.01 { problems.append("Very low magnitude (nearly zero vector)") }
            if magnitude > 100.0 { problems.append("Unusually high magnitude") }
            if qualityScore < 0.5 { problems.append("Low quality score") }
            return problems
        }
    }
    
    /// Analyze embedding quality and detect issues
    public static func analyzeEmbeddingQuality(_ embedding: [Float]) -> EmbeddingQualityReport {
        let dimension = embedding.count
        var hasNaN = false
        var hasInfinite = false
        var sumOfSquares: Float = 0.0
        
        for value in embedding {
            if value.isNaN {
                hasNaN = true
            } else if value.isInfinite {
                hasInfinite = true
            } else {
                sumOfSquares += value * value
            }
        }
        
        let magnitude = sqrt(sumOfSquares)
        let isNormalized = abs(magnitude - 1.0) < 0.01
        
        // Calculate quality score
        var qualityScore: Float = 1.0
        if hasNaN || hasInfinite { qualityScore = 0.0 }
        else if magnitude < 0.01 { qualityScore = 0.1 }
        else if magnitude > 100.0 { qualityScore = 0.3 }
        else if dimension < 50 { qualityScore = 0.5 }
        else { qualityScore = min(1.0, magnitude / 2.0) }
        
        return EmbeddingQualityReport(
            isValid: !hasNaN && !hasInfinite && magnitude > 0.01,
            dimension: dimension,
            magnitude: magnitude,
            hasNaN: hasNaN,
            hasInfinite: hasInfinite,
            isNormalized: isNormalized,
            qualityScore: qualityScore
        )
    }
}

// MARK: - Constants

extension EmbeddingUtils {
    
    /// Standard embedding dimensions for common models
    public enum EmbeddingDimension: Int, CaseIterable {
        case miniLM = 384      // all-MiniLM-L6-v2
        case mpnet = 768       // all-mpnet-base-v2
        case e5Large = 1024    // multilingual-e5-large
        case openAI = 1536     // text-embedding-3-small
        case openAILarge = 3072 // text-embedding-3-large
        
        public var displayName: String {
            switch self {
            case .miniLM: return "MiniLM (384d)"
            case .mpnet: return "MPNet (768d)"
            case .e5Large: return "E5-Large (1024d)"
            case .openAI: return "OpenAI Small (1536d)"
            case .openAILarge: return "OpenAI Large (3072d)"
            }
        }
        
        public var modelName: String {
            switch self {
            case .miniLM: return "all-MiniLM-L6-v2"
            case .mpnet: return "all-mpnet-base-v2"
            case .e5Large: return "multilingual-e5-large"
            case .openAI: return "text-embedding-3-small"
            case .openAILarge: return "text-embedding-3-large"
            }
        }
        
        public var bytesPerEmbedding: Int {
            return rawValue * MemoryLayout<Float>.size
        }
    }
}