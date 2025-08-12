//
//  MLXCommunityService.swift
//  ProjectOne
//
//  Service for discovering and managing models from the MLX Community
//  Provides dynamic model discovery, downloading, and caching
//

import Foundation
import os.log

/// Service for interacting with MLX Community models
public class MLXCommunityService: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXCommunityService")
    
    // MARK: - Configuration
    
    private let baseURL = "https://huggingface.co/api/models"
    private let mlxCommunityFilter = "mlx-community"
    private let session = URLSession.shared
    
    // MARK: - Published State
    
    @Published public var availableModels: [MLXCommunityModel] = []
    @Published public var isLoading = false
    @Published public var lastError: Error?
    @Published public var lastUpdate: Date?
    
    // MARK: - Cache Management
    
    private let cacheDirectory: URL
    private let modelCacheKey = "mlx_community_models_cache"
    private let cacheExpirationInterval: TimeInterval = 3600 // 1 hour
    
    public init() {
        // Set up cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsPath.appendingPathComponent("MLXModels")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        logger.info("MLX Community Service initialized with cache at: \(cacheDirectory.path)")
    }
    
    // MARK: - Model Discovery
    
    /// Fetch available models from MLX Community
    public func discoverModels() async throws {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        logger.info("Starting MLX Community model discovery")
        
        do {
            // Check cache first
            if let cachedModels = loadCachedModels(), !cachedModels.isEmpty {
                logger.info("Using cached models (\(cachedModels.count) models)")
                await MainActor.run {
                    self.availableModels = cachedModels
                    self.isLoading = false
                    self.lastUpdate = Date()
                }
                
                // Continue with fresh fetch in background
                Task.detached { [weak self] in
                    try? await self?.fetchModelsFromAPI(useCache: false)
                }
                return
            }
            
            // Fetch fresh models
            await fetchModelsFromAPI(useCache: true)
            
        } catch {
            await MainActor.run {
                self.lastError = error
                self.isLoading = false
            }
            throw error
        }
    }
    
    private func fetchModelsFromAPI(useCache: Bool) async throws {
        // Build query parameters
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "author", value: mlxCommunityFilter),
            URLQueryItem(name: "pipeline_tag", value: "text-generation"),
            URLQueryItem(name: "sort", value: "downloads"),
            URLQueryItem(name: "direction", value: "-1"),
            URLQueryItem(name: "limit", value: "50")
        ]
        
        guard let url = components.url else {
            throw MLXCommunityError.invalidURL
        }
        
        logger.debug("Fetching models from: \(url.absoluteString)")
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MLXCommunityError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let models = try decoder.decode([HuggingFaceModel].self, from: data)
        let mlxModels = models.compactMap { convertToMLXModel($0) }
        
        logger.info("Discovered \(mlxModels.count) MLX Community models")
        
        await MainActor.run {
            self.availableModels = mlxModels
            self.isLoading = false
            self.lastUpdate = Date()
        }
        
        // Cache the results
        if useCache {
            cacheModels(mlxModels)
        }
    }
    
    private func convertToMLXModel(_ hfModel: HuggingFaceModel) -> MLXCommunityModel? {
        // Filter to only MLX-compatible models
        guard hfModel.id.hasPrefix("mlx-community/") else { return nil }
        
        // Extract model information
        let modelName = String(hfModel.id.dropFirst("mlx-community/".count))
        let isQuantized = modelName.contains("4bit") || modelName.contains("8bit")
        let estimatedSize = estimateModelSize(from: modelName, downloads: hfModel.downloads)
        
        return MLXCommunityModel(
            id: hfModel.id,
            name: formatModelName(modelName),
            author: "MLX Community",
            downloads: hfModel.downloads,
            likes: hfModel.likes,
            createdAt: hfModel.createdAt,
            lastModified: hfModel.lastModified,
            description: hfModel.description ?? "MLX-optimized model for efficient on-device inference",
            tags: hfModel.tags,
            isQuantized: isQuantized,
            estimatedSize: estimatedSize,
            memoryRequirement: calculateMemoryRequirement(estimatedSize),
            isCompatible: checkCompatibility(modelName),
            downloadURL: "https://huggingface.co/\(hfModel.id)",
            localPath: nil
        )
    }
    
    // MARK: - Model Information Helpers
    
    private func formatModelName(_ rawName: String) -> String {
        // Convert model names to readable format
        return rawName
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    private func estimateModelSize(from name: String, downloads: Int) -> String {
        // Estimate based on model name patterns
        if name.contains("2b") || name.contains("2B") {
            return "~1.2GB"
        } else if name.contains("3b") || name.contains("3B") {
            return "~1.8GB"
        } else if name.contains("7b") || name.contains("7B") {
            return name.contains("4bit") ? "~4GB" : "~14GB"
        } else if name.contains("8b") || name.contains("8B") {
            return name.contains("4bit") ? "~4.5GB" : "~16GB"
        } else if name.contains("13b") || name.contains("13B") {
            return name.contains("4bit") ? "~7GB" : "~26GB"
        } else if name.contains("70b") || name.contains("70B") {
            return name.contains("4bit") ? "~40GB" : "~140GB"
        }
        
        // Fallback based on popularity
        return downloads > 10000 ? "~4GB" : "~2GB"
    }
    
    private func calculateMemoryRequirement(_ size: String) -> String {
        // Extract number from size and add overhead
        let components = size.components(separatedBy: CharacterSet.decimalDigits.inverted)
        if let sizeNum = components.compactMap({ Double($0) }).first {
            let memoryGB = Int(sizeNum * 1.5) // Add 50% overhead for inference
            return "~\(memoryGB)GB"
        }
        return size
    }
    
    private func checkCompatibility(_ modelName: String) -> Bool {
        // Basic compatibility check - exclude very large models
        let incompatiblePatterns = ["70b", "65b", "175b"]
        return !incompatiblePatterns.contains { modelName.lowercased().contains($0) }
    }
    
    // MARK: - Cache Management
    
    private func loadCachedModels() -> [MLXCommunityModel]? {
        let cacheFile = cacheDirectory.appendingPathComponent("\(modelCacheKey).json")
        
        guard FileManager.default.fileExists(atPath: cacheFile.path),
              let data = try? Data(contentsOf: cacheFile) else {
            return nil
        }
        
        // Check if cache is expired
        if let attributes = try? FileManager.default.attributesOfItem(atPath: cacheFile.path),
           let modificationDate = attributes[.modificationDate] as? Date {
            if Date().timeIntervalSince(modificationDate) > cacheExpirationInterval {
                logger.debug("Model cache expired")
                return nil
            }
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([MLXCommunityModel].self, from: data)
        } catch {
            logger.error("Failed to decode cached models: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func cacheModels(_ models: [MLXCommunityModel]) {
        let cacheFile = cacheDirectory.appendingPathComponent("\(modelCacheKey).json")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(models)
            try data.write(to: cacheFile)
            logger.debug("Cached \(models.count) models to \(cacheFile.path)")
        } catch {
            logger.error("Failed to cache models: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Model Management
    
    /// Check if a model is downloaded locally
    public func isModelDownloaded(_ model: MLXCommunityModel) -> Bool {
        let modelDir = cacheDirectory.appendingPathComponent(model.id.replacingOccurrences(of: "/", with: "_"))
        return FileManager.default.fileExists(atPath: modelDir.path)
    }
    
    /// Get local path for a downloaded model
    public func getLocalPath(for model: MLXCommunityModel) -> URL? {
        let modelDir = cacheDirectory.appendingPathComponent(model.id.replacingOccurrences(of: "/", with: "_"))
        return FileManager.default.fileExists(atPath: modelDir.path) ? modelDir : nil
    }
    
    /// Get available model categories
    public func getModelCategories() -> [ModelCategory] {
        let grouped = Dictionary(grouping: availableModels) { model in
            if model.name.lowercased().contains("gemma") {
                return "Gemma Models"
            } else if model.name.lowercased().contains("llama") {
                return "Llama Models"
            } else if model.name.lowercased().contains("mistral") {
                return "Mistral Models"
            } else if model.name.lowercased().contains("phi") {
                return "Phi Models"
            } else {
                return "Other Models"
            }
        }
        
        return grouped.map { category, models in
            ModelCategory(name: category, models: models.sorted { $0.downloads > $1.downloads })
        }.sorted { $0.name < $1.name }
    }
    
    /// Filter models by search query
    public func filterModels(query: String) -> [MLXCommunityModel] {
        guard !query.isEmpty else { return availableModels }
        
        return availableModels.filter { model in
            model.name.lowercased().contains(query.lowercased()) ||
            model.description.lowercased().contains(query.lowercased()) ||
            model.tags.contains { $0.lowercased().contains(query.lowercased()) }
        }
    }
    
    /// Get recommended models for new users
    public func getRecommendedModels() -> [MLXCommunityModel] {
        return availableModels
            .filter { $0.isCompatible && $0.isQuantized }
            .sorted { $0.downloads > $1.downloads }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Supporting Types

public struct MLXCommunityModel: Identifiable, Codable, Hashable {
    public let id: String
    public let name: String
    public let author: String
    public let downloads: Int
    public let likes: Int
    public let createdAt: Date?
    public let lastModified: Date
    public let description: String
    public let tags: [String]
    public let isQuantized: Bool
    public let estimatedSize: String
    public let memoryRequirement: String
    public let isCompatible: Bool
    public let downloadURL: String
    public let localPath: String?
    
    public var isRecommended: Bool {
        return downloads > 5000 && isQuantized && isCompatible
    }
}

public struct ModelCategory: Identifiable {
    public let id = UUID()
    public let name: String
    public let models: [MLXCommunityModel]
}

private struct HuggingFaceModel: Codable {
    let id: String
    let downloads: Int
    let likes: Int
    let createdAt: Date?
    let lastModified: Date
    let description: String?
    let tags: [String]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case downloads
        case likes
        case createdAt = "created_at"
        case lastModified = "last_modified"
        case description
        case tags
    }
}

public enum MLXCommunityError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingError(String)
    case cacheError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for MLX Community API"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .cacheError(let message):
            return "Cache error: \(message)"
        }
    }
}