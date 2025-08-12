//
//  MLXStorageManager.swift
//  ProjectOne
//
//  Storage management service for MLX models
//  Tracks disk usage, provides cleanup capabilities, and manages storage quotas
//

import Foundation
import os.log

/// Service for managing MLX model storage and disk usage
public class MLXStorageManager: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXStorageManager")
    
    // MARK: - Published State
    
    @Published public var storageInfo: StorageInfo = StorageInfo()
    @Published public var modelStorageDetails: [String: ModelStorageDetail] = [:]
    @Published public var isCalculating = false
    @Published public var lastUpdated: Date?
    
    // MARK: - Configuration
    
    private let cacheDirectory: URL
    private let storageQuotaGB: Int64 = 50 // Default 50GB quota for MLX models
    
    // MARK: - Initialization
    
    public init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = documentsPath.appendingPathComponent("MLXModels")
        
        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        logger.info("MLX Storage Manager initialized with cache at: \(cacheDirectory.path)")
        
        // Initial storage calculation
        Task {
            await calculateStorageUsage()
        }
    }
    
    // MARK: - Storage Calculation
    
    /// Calculate total storage usage for all MLX models
    @MainActor
    public func calculateStorageUsage() async {
        isCalculating = true
        
        await Task.detached { [weak self] in
            guard let self = self else { return }
            
            let storageInfo = self.calculateStorageInfo()
            let modelDetails = await self.calculateModelStorageDetails()
            
            await MainActor.run {
                self.storageInfo = storageInfo
                self.modelStorageDetails = modelDetails
                self.isCalculating = false
                self.lastUpdated = Date()
            }
        }.value
        
        logger.info("Storage usage calculated: \(formatBytes(storageInfo.totalUsedBytes))")
    }
    
    private func calculateStorageInfo() -> StorageInfo {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [])
            
            var totalBytes: Int64 = 0
            var modelCount = 0
            var oldestModelDate: Date?
            var newestModelDate: Date?
            
            for item in contents {
                let resourceValues = try item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .contentModificationDateKey])
                
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    // This is a model directory
                    modelCount += 1
                    let modelSize = calculateDirectorySize(item)
                    totalBytes += modelSize
                    
                    if let modDate = resourceValues.contentModificationDate {
                        if oldestModelDate == nil || modDate < oldestModelDate! {
                            oldestModelDate = modDate
                        }
                        if newestModelDate == nil || modDate > newestModelDate! {
                            newestModelDate = modDate
                        }
                    }
                }
            }
            
            // Get system disk space
            let systemAttributes = try FileManager.default.attributesOfFileSystem(forPath: cacheDirectory.path)
            let totalSystemBytes = (systemAttributes[.systemSize] as? NSNumber)?.int64Value ?? 0
            let freeSystemBytes = (systemAttributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
            
            return StorageInfo(
                totalUsedBytes: totalBytes,
                totalQuotaBytes: storageQuotaGB * 1024 * 1024 * 1024,
                modelCount: modelCount,
                systemTotalBytes: totalSystemBytes,
                systemFreeBytes: freeSystemBytes,
                oldestModelDate: oldestModelDate,
                newestModelDate: newestModelDate
            )
            
        } catch {
            logger.error("Failed to calculate storage info: \(error.localizedDescription)")
            return StorageInfo()
        }
    }
    
    private func calculateModelStorageDetails() async -> [String: ModelStorageDetail] {
        var details: [String: ModelStorageDetail] = [:]
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            
            for item in contents {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
                
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    let modelId = item.lastPathComponent.replacingOccurrences(of: "_", with: "/")
                    let detail = calculateModelStorageDetail(for: item, modelId: modelId)
                    details[modelId] = detail
                }
            }
            
        } catch {
            logger.error("Failed to calculate model storage details: \(error.localizedDescription)")
        }
        
        return details
    }
    
    private func calculateModelStorageDetail(for directory: URL, modelId: String) -> ModelStorageDetail {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [])
            
            var totalBytes: Int64 = 0
            var fileCount = 0
            var lastAccessDate: Date?
            var downloadDate: Date?
            var fileBreakdown: [String: Int64] = [:]
            
            for file in contents {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .contentAccessDateKey])
                
                if let fileSize = resourceValues.fileSize {
                    totalBytes += Int64(fileSize)
                    fileCount += 1
                    
                    let fileName = file.lastPathComponent
                    fileBreakdown[fileName] = Int64(fileSize)
                }
                
                if let modDate = resourceValues.contentModificationDate {
                    if downloadDate == nil || modDate < downloadDate! {
                        downloadDate = modDate
                    }
                }
                
                if let accessDate = resourceValues.contentAccessDate {
                    if lastAccessDate == nil || accessDate > lastAccessDate! {
                        lastAccessDate = accessDate
                    }
                }
            }
            
            return ModelStorageDetail(
                modelId: modelId,
                totalBytes: totalBytes,
                fileCount: fileCount,
                downloadDate: downloadDate ?? Date(),
                lastAccessDate: lastAccessDate,
                localPath: directory,
                fileBreakdown: fileBreakdown,
                canDelete: true
            )
            
        } catch {
            logger.error("Failed to calculate storage for model \(modelId): \(error.localizedDescription)")
            return ModelStorageDetail(
                modelId: modelId,
                totalBytes: 0,
                fileCount: 0,
                downloadDate: Date(),
                lastAccessDate: nil,
                localPath: directory,
                fileBreakdown: [:],
                canDelete: true
            )
        }
    }
    
    private func calculateDirectorySize(_ directory: URL) -> Int64 {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [])
            
            return contents.reduce(0) { total, file in
                do {
                    let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                    return total + Int64(resourceValues.fileSize ?? 0)
                } catch {
                    return total
                }
            }
        } catch {
            logger.error("Failed to calculate directory size for \(directory.path): \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - Storage Management
    
    /// Delete a specific model and reclaim storage
    public func deleteModel(_ modelId: String) async throws {
        logger.info("Deleting model: \(modelId)")
        
        guard let storageDetail = modelStorageDetails[modelId] else {
            throw StorageError.modelNotFound(modelId)
        }
        
        let modelDirectory = storageDetail.localPath
        
        do {
            // Remove the entire model directory
            try FileManager.default.removeItem(at: modelDirectory)
            
            // Update storage info
            await MainActor.run {
                self.modelStorageDetails.removeValue(forKey: modelId)
                self.storageInfo.totalUsedBytes -= storageDetail.totalBytes
                self.storageInfo.modelCount -= 1
                self.lastUpdated = Date()
            }
            
            logger.info("✅ Successfully deleted model \(modelId), reclaimed \(formatBytes(storageDetail.totalBytes))")
            
        } catch {
            logger.error("❌ Failed to delete model \(modelId): \(error.localizedDescription)")
            throw StorageError.deletionFailed(modelId, error.localizedDescription)
        }
    }
    
    /// Delete multiple models in batch
    public func deleteModels(_ modelIds: [String]) async throws {
        logger.info("Batch deleting \(modelIds.count) models")
        
        var deletedBytes: Int64 = 0
        var deletedCount = 0
        var errors: [String] = []
        
        for modelId in modelIds {
            do {
                let sizeBefore = modelStorageDetails[modelId]?.totalBytes ?? 0
                try await deleteModel(modelId)
                deletedBytes += sizeBefore
                deletedCount += 1
            } catch {
                errors.append("\(modelId): \(error.localizedDescription)")
            }
        }
        
        if !errors.isEmpty {
            throw StorageError.batchDeletionPartiallyFailed(
                deleted: deletedCount,
                failed: errors.count,
                errors: errors
            )
        }
        
        logger.info("✅ Batch deletion complete: \(deletedCount) models, \(formatBytes(deletedBytes)) reclaimed")
    }
    
    /// Clean up old or unused models based on criteria
    public func cleanupOldModels(olderThan days: Int = 30) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let oldModels = modelStorageDetails.values.filter { detail in
            detail.lastAccessDate?.compare(cutoffDate) == .orderedAscending ||
            (detail.lastAccessDate == nil && detail.downloadDate.compare(cutoffDate) == .orderedAscending)
        }
        
        let modelIds = oldModels.map { $0.modelId }
        
        if !modelIds.isEmpty {
            logger.info("Cleaning up \(modelIds.count) models older than \(days) days")
            try await deleteModels(modelIds)
        }
    }
    
    /// Free up space to meet target (in bytes)
    public func freeUpSpace(targetBytes: Int64) async throws {
        logger.info("Attempting to free up \(formatBytes(targetBytes))")
        
        let currentFree = storageInfo.systemFreeBytes
        if currentFree >= targetBytes {
            logger.info("Already have sufficient free space")
            return
        }
        
        let neededBytes = targetBytes - currentFree
        
        // Sort models by last access date (oldest first) and size (largest first)
        let candidates = modelStorageDetails.values
            .filter { $0.canDelete }
            .sorted { model1, model2 in
                let date1 = model1.lastAccessDate ?? model1.downloadDate
                let date2 = model2.lastAccessDate ?? model2.downloadDate
                
                if date1 == date2 {
                    return model1.totalBytes > model2.totalBytes // Larger first if same date
                }
                return date1 < date2 // Older first
            }
        
        var bytesToDelete: Int64 = 0
        var modelsToDelete: [String] = []
        
        for candidate in candidates {
            modelsToDelete.append(candidate.modelId)
            bytesToDelete += candidate.totalBytes
            
            if bytesToDelete >= neededBytes {
                break
            }
        }
        
        if bytesToDelete < neededBytes {
            throw StorageError.insufficientSpaceToFree(needed: neededBytes, available: bytesToDelete)
        }
        
        logger.info("Will delete \(modelsToDelete.count) models to free \(formatBytes(bytesToDelete))")
        try await deleteModels(modelsToDelete)
    }
    
    // MARK: - Storage Information
    
    /// Get storage detail for a specific model
    public func getModelStorageDetail(_ modelId: String) -> ModelStorageDetail? {
        return modelStorageDetails[modelId]
    }
    
    /// Get models sorted by storage usage
    public func getModelsByStorageUsage() -> [ModelStorageDetail] {
        return modelStorageDetails.values.sorted { $0.totalBytes > $1.totalBytes }
    }
    
    /// Get models sorted by last access
    public func getModelsByLastAccess() -> [ModelStorageDetail] {
        return modelStorageDetails.values.sorted { model1, model2 in
            let date1 = model1.lastAccessDate ?? model1.downloadDate
            let date2 = model2.lastAccessDate ?? model2.downloadDate
            return date1 > date2
        }
    }
    
    /// Check if storage quota is exceeded
    public func isQuotaExceeded() -> Bool {
        return storageInfo.totalUsedBytes > storageInfo.totalQuotaBytes
    }
    
    /// Get storage warnings
    public func getStorageWarnings() -> [StorageWarning] {
        var warnings: [StorageWarning] = []
        
        let usagePercentage = Double(storageInfo.totalUsedBytes) / Double(storageInfo.totalQuotaBytes)
        
        if usagePercentage > 0.95 {
            warnings.append(.quotaNearlyExceeded)
        } else if usagePercentage > 0.8 {
            warnings.append(.quotaWarning)
        }
        
        let systemUsagePercentage = Double(storageInfo.systemTotalBytes - storageInfo.systemFreeBytes) / Double(storageInfo.systemTotalBytes)
        
        if systemUsagePercentage > 0.95 {
            warnings.append(.systemDiskFull)
        } else if systemUsagePercentage > 0.9 {
            warnings.append(.systemDiskNearFull)
        }
        
        // Check for very old models
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let oldModelCount = modelStorageDetails.values.filter { detail in
            let lastUsed = detail.lastAccessDate ?? detail.downloadDate
            return lastUsed < thirtyDaysAgo
        }.count
        
        if oldModelCount > 0 {
            warnings.append(.unusedModels(count: oldModelCount))
        }
        
        return warnings
    }
}

// MARK: - Supporting Types

public struct StorageInfo {
    public var totalUsedBytes: Int64 = 0
    public var totalQuotaBytes: Int64 = 0
    public var modelCount: Int = 0
    public var systemTotalBytes: Int64 = 0
    public var systemFreeBytes: Int64 = 0
    public var oldestModelDate: Date?
    public var newestModelDate: Date?
    
    public var usagePercentage: Double {
        guard totalQuotaBytes > 0 else { return 0 }
        return Double(totalUsedBytes) / Double(totalQuotaBytes)
    }
    
    public var remainingBytes: Int64 {
        return max(0, totalQuotaBytes - totalUsedBytes)
    }
    
    public var systemUsagePercentage: Double {
        guard systemTotalBytes > 0 else { return 0 }
        return Double(systemTotalBytes - systemFreeBytes) / Double(systemTotalBytes)
    }
}

public struct ModelStorageDetail {
    public let modelId: String
    public let totalBytes: Int64
    public let fileCount: Int
    public let downloadDate: Date
    public let lastAccessDate: Date?
    public let localPath: URL
    public let fileBreakdown: [String: Int64]
    public let canDelete: Bool
    
    public var formattedSize: String {
        return formatBytes(totalBytes)
    }
    
    public var daysSinceDownload: Int {
        return Calendar.current.dateComponents([.day], from: downloadDate, to: Date()).day ?? 0
    }
    
    public var daysSinceLastAccess: Int? {
        guard let lastAccess = lastAccessDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastAccess, to: Date()).day ?? 0
    }
    
    public var isRecent: Bool {
        return daysSinceDownload < 7
    }
    
    public var isOld: Bool {
        return daysSinceLastAccess ?? daysSinceDownload > 30
    }
}

public enum StorageWarning {
    case quotaWarning
    case quotaNearlyExceeded
    case systemDiskNearFull
    case systemDiskFull
    case unusedModels(count: Int)
    
    public var message: String {
        switch self {
        case .quotaWarning:
            return "MLX model storage is 80% full"
        case .quotaNearlyExceeded:
            return "MLX model storage is 95% full"
        case .systemDiskNearFull:
            return "System disk is 90% full"
        case .systemDiskFull:
            return "System disk is 95% full"
        case .unusedModels(let count):
            return "\(count) model\(count == 1 ? "" : "s") haven't been used in 30 days"
        }
    }
    
    public var severity: WarningSeverity {
        switch self {
        case .quotaNearlyExceeded, .systemDiskFull:
            return .critical
        case .quotaWarning, .systemDiskNearFull:
            return .high
        case .unusedModels:
            return .medium
        }
    }
    
    public var actionable: Bool {
        switch self {
        case .unusedModels, .quotaWarning, .quotaNearlyExceeded:
            return true
        case .systemDiskNearFull, .systemDiskFull:
            return false // System-wide issue
        }
    }
}

public enum WarningSeverity {
    case critical, high, medium, low
    
    public var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }
}

public enum StorageError: Error, LocalizedError {
    case modelNotFound(String)
    case deletionFailed(String, String)
    case batchDeletionPartiallyFailed(deleted: Int, failed: Int, errors: [String])
    case insufficientSpaceToFree(needed: Int64, available: Int64)
    case calculationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let modelId):
            return "Model not found: \(modelId)"
        case .deletionFailed(let modelId, let reason):
            return "Failed to delete \(modelId): \(reason)"
        case .batchDeletionPartiallyFailed(let deleted, let failed, let errors):
            return "Batch deletion partially failed: \(deleted) deleted, \(failed) failed. Errors: \(errors.joined(separator: ", "))"
        case .insufficientSpaceToFree(let needed, let available):
            return "Cannot free enough space: need \(formatBytes(needed)), can only free \(formatBytes(available))"
        case .calculationFailed(let reason):
            return "Storage calculation failed: \(reason)"
        }
    }
}

// MARK: - Utility Functions

public func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    formatter.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
    formatter.includesUnit = true
    formatter.isAdaptive = true
    return formatter.string(fromByteCount: bytes)
}

public func formatBytesShort(_ bytes: Int64) -> String {
    if bytes >= 1024 * 1024 * 1024 {
        return String(format: "%.1fGB", Double(bytes) / (1024 * 1024 * 1024))
    } else if bytes >= 1024 * 1024 {
        return String(format: "%.1fMB", Double(bytes) / (1024 * 1024))
    } else if bytes >= 1024 {
        return String(format: "%.1fKB", Double(bytes) / 1024)
    } else {
        return "\(bytes)B"
    }
}