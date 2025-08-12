//
//  MLXModelDownloadService.swift
//  ProjectOne
//
//  Service for downloading and managing MLX community models
//  Handles model downloading, progress tracking, and local storage
//

import Foundation
import os.log

/// Service for downloading and managing MLX models
public class MLXModelDownloadService: NSObject, ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXModelDownloadService")
    
    // MARK: - Published State
    
    @Published public var activeDownloads: [String: ModelDownloadProgress] = [:]
    @Published public var downloadQueue: [MLXCommunityModel] = []
    @Published public var completedDownloads: Set<String> = []
    @Published public var failedDownloads: [String: String] = [:] // modelId -> error message
    
    // MARK: - Configuration
    
    private let maxConcurrentDownloads = 2
    private let downloadTimeout: TimeInterval = 3600 // 1 hour
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = downloadTimeout
        config.timeoutIntervalForResource = downloadTimeout
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    // MARK: - Storage
    
    private let cacheDirectory: URL
    private let manifestFileName = "model_manifest.json"
    private let storageManager: MLXStorageManager
    
    // MARK: - Internal State
    
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var downloadManifests: [String: ModelManifest] = [:]
    
    public init(storageManager: MLXStorageManager = MLXStorageManager()) {
        // Set up cache directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsPath.appendingPathComponent("MLXModels")
        self.storageManager = storageManager
        
        super.init()
        
        // Create cache directory if needed
        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            logger.info("Model cache directory: \(cacheDirectory.path)")
        } catch {
            logger.error("Failed to create cache directory: \(error.localizedDescription)")
        }
        
        // Load existing downloads
        loadDownloadState()
    }
    
    // MARK: - Public API
    
    /// Start downloading a model
    public func downloadModel(_ model: MLXCommunityModel) async throws {
        let modelId = model.id
        
        // Check if already downloaded
        if isModelDownloaded(modelId) {
            logger.info("Model \(modelId) already downloaded")
            return
        }
        
        // Check if already downloading
        if activeDownloads[modelId] != nil {
            logger.info("Model \(modelId) already downloading")
            return
        }
        
        logger.info("Starting download for model: \(modelId)")
        
        // Create download progress tracker
        let progress = ModelDownloadProgress(
            modelId: modelId,
            modelName: model.name,
            totalSize: 0,
            downloadedSize: 0,
            progress: 0.0,
            status: .preparing,
            startTime: Date(),
            estimatedTimeRemaining: nil
        )
        
        await MainActor.run {
            activeDownloads[modelId] = progress
        }
        
        do {
            // Get the actual download URLs from HuggingFace
            let downloadUrls = try await getHuggingFaceDownloadUrls(for: model)
            
            // Create model directory
            let modelDir = cacheDirectory.appendingPathComponent(modelId.replacingOccurrences(of: "/", with: "_"))
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
            
            // Create manifest
            let manifest = ModelManifest(
                modelId: modelId,
                modelName: model.name,
                downloadUrls: downloadUrls,
                localPath: modelDir,
                downloadDate: Date(),
                totalSize: 0 // Will be updated during download
            )
            
            downloadManifests[modelId] = manifest
            
            // Start downloading files
            try await downloadModelFiles(model, manifest: manifest, to: modelDir)
            
            // Mark as completed
            await MainActor.run {
                self.activeDownloads.removeValue(forKey: modelId)
                self.completedDownloads.insert(modelId)
                self.failedDownloads.removeValue(forKey: modelId)
            }
            
            // Save manifest
            saveManifest(manifest, to: modelDir)
            saveDownloadState()
            
            // Update storage manager
            await storageManager.calculateStorageUsage()
            
            logger.info("✅ Successfully downloaded model: \(modelId)")
            
        } catch {
            logger.error("❌ Failed to download model \(modelId): \(error.localizedDescription)")
            
            await MainActor.run {
                self.activeDownloads.removeValue(forKey: modelId)
                self.failedDownloads[modelId] = error.localizedDescription
            }
            
            // Clean up partial download
            cleanupPartialDownload(modelId)
            throw error
        }
    }
    
    /// Cancel a model download
    public func cancelDownload(_ modelId: String) {
        logger.info("Cancelling download for model: \(modelId)")
        
        downloadTasks[modelId]?.cancel()
        downloadTasks.removeValue(forKey: modelId)
        
        activeDownloads.removeValue(forKey: modelId)
        cleanupPartialDownload(modelId)
    }
    
    /// Check if a model is downloaded
    public func isModelDownloaded(_ modelId: String) -> Bool {
        let modelDir = cacheDirectory.appendingPathComponent(modelId.replacingOccurrences(of: "/", with: "_"))
        let manifestFile = modelDir.appendingPathComponent(manifestFileName)
        return FileManager.default.fileExists(atPath: manifestFile.path)
    }
    
    /// Get local path for a downloaded model
    public func getModelPath(_ modelId: String) -> URL? {
        guard isModelDownloaded(modelId) else { return nil }
        return cacheDirectory.appendingPathComponent(modelId.replacingOccurrences(of: "/", with: "_"))
    }
    
    /// Delete a downloaded model
    public func deleteModel(_ modelId: String) async throws {
        try await storageManager.deleteModel(modelId)
        completedDownloads.remove(modelId)
        saveDownloadState()
        logger.info("Deleted model: \(modelId)")
    }
    
    /// Get download progress for a model
    public func getDownloadProgress(_ modelId: String) -> ModelDownloadProgress? {
        return activeDownloads[modelId]
    }
    
    // MARK: - Private Implementation
    
    private func getHuggingFaceDownloadUrls(for model: MLXCommunityModel) async throws -> [String] {
        // For now, return basic URLs - in a real implementation, you'd query the HuggingFace API
        // to get the actual file list for the model repository
        
        let baseUrl = "https://huggingface.co/\(model.id)/resolve/main"
        
        // Common MLX model files
        let commonFiles = [
            "config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "model.safetensors",
            "special_tokens_map.json"
        ]
        
        return commonFiles.map { "\(baseUrl)/\(fileName)" }
    }
    
    private func downloadModelFiles(_ model: MLXCommunityModel, manifest: ModelManifest, to directory: URL) async throws {
        let modelId = model.id
        
        await MainActor.run {
            activeDownloads[modelId]?.status = .downloading
        }
        
        // Download each file
        for (index, urlString) in manifest.downloadUrls.enumerated() {
            guard let url = URL(string: urlString) else {
                throw ModelDownloadError.invalidURL(urlString)
            }
            
            let fileName = url.lastPathComponent
            let destinationUrl = directory.appendingPathComponent(fileName)
            
            logger.debug("Downloading file \(index + 1)/\(manifest.downloadUrls.count): \(fileName)")
            
            try await downloadFile(from: url, to: destinationUrl, modelId: modelId)
        }
        
        await MainActor.run {
            activeDownloads[modelId]?.status = .completed
        }
    }
    
    private func downloadFile(from url: URL, to destination: URL, modelId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { tempUrl, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let tempUrl = tempUrl else {
                    continuation.resume(throwing: ModelDownloadError.downloadFailed("No temporary file"))
                    return
                }
                
                do {
                    // Move file to final destination
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.moveItem(at: tempUrl, to: destination)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            
            downloadTasks[modelId] = task
            task.resume()
        }
    }
    
    private func cleanupPartialDownload(_ modelId: String) {
        let modelDir = cacheDirectory.appendingPathComponent(modelId.replacingOccurrences(of: "/", with: "_"))
        try? FileManager.default.removeItem(at: modelDir)
    }
    
    private func saveManifest(_ manifest: ModelManifest, to directory: URL) {
        let manifestFile = directory.appendingPathComponent(manifestFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(manifest)
            try data.write(to: manifestFile)
        } catch {
            logger.error("Failed to save manifest: \(error.localizedDescription)")
        }
    }
    
    private func loadDownloadState() {
        // Scan cache directory for existing models
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for modelDir in contents where modelDir.hasDirectoryPath {
                let manifestFile = modelDir.appendingPathComponent(manifestFileName)
                
                if FileManager.default.fileExists(atPath: manifestFile.path) {
                    // Extract model ID from directory name
                    let dirName = modelDir.lastPathComponent
                    let modelId = dirName.replacingOccurrences(of: "_", with: "/")
                    completedDownloads.insert(modelId)
                }
            }
            
            logger.info("Found \(completedDownloads.count) previously downloaded models")
            
        } catch {
            logger.error("Failed to load download state: \(error.localizedDescription)")
        }
    }
    
    private func saveDownloadState() {
        // State is automatically persisted through file system
        // Could add additional metadata persistence here if needed
    }
}

// MARK: - URLSessionDownloadDelegate

extension MLXModelDownloadService: URLSessionDownloadDelegate {
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        // Find the model ID for this task
        guard let modelId = downloadTasks.first(where: { $0.value == downloadTask })?.key else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        DispatchQueue.main.async {
            self.activeDownloads[modelId]?.totalSize = totalBytesExpectedToWrite
            self.activeDownloads[modelId]?.downloadedSize = totalBytesWritten
            self.activeDownloads[modelId]?.progress = progress
            
            // Calculate estimated time remaining
            if let startTime = self.activeDownloads[modelId]?.startTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if progress > 0.01 { // Avoid division by zero
                    let estimatedTotal = elapsed / progress
                    self.activeDownloads[modelId]?.estimatedTimeRemaining = estimatedTotal - elapsed
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // File handling is done in the downloadFile method
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Error handling is done in the downloadFile method
        
        // Clean up task reference
        if let modelId = downloadTasks.first(where: { $0.value == task })?.key {
            downloadTasks.removeValue(forKey: modelId)
        }
    }
}

// MARK: - Supporting Types

public struct ModelDownloadProgress: Identifiable {
    public let id = UUID()
    public let modelId: String
    public let modelName: String
    public var totalSize: Int64
    public var downloadedSize: Int64
    public var progress: Double
    public var status: DownloadStatus
    public let startTime: Date
    public var estimatedTimeRemaining: TimeInterval?
    
    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
    
    public var formattedProgress: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let downloaded = formatter.string(fromByteCount: downloadedSize)
        let total = formatter.string(fromByteCount: totalSize)
        return "\(downloaded) / \(total)"
    }
    
    public var formattedTimeRemaining: String? {
        guard let remaining = estimatedTimeRemaining, remaining > 0 else { return nil }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter.string(from: remaining)
    }
}

public enum DownloadStatus {
    case preparing
    case downloading
    case completed
    case failed(String)
    case cancelled
    
    public var displayName: String {
        switch self {
        case .preparing:
            return "Preparing..."
        case .downloading:
            return "Downloading"
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error)"
        case .cancelled:
            return "Cancelled"
        }
    }
}

private struct ModelManifest: Codable {
    let modelId: String
    let modelName: String
    let downloadUrls: [String]
    let localPath: URL
    let downloadDate: Date
    let totalSize: Int64
}

public enum ModelDownloadError: Error, LocalizedError {
    case invalidURL(String)
    case downloadFailed(String)
    case fileSystemError(String)
    case manifestError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .fileSystemError(let error):
            return "File system error: \(error)"
        case .manifestError(let error):
            return "Manifest error: \(error)"
        }
    }
}