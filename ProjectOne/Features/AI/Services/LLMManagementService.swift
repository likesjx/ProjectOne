//
//  LLMManagementService.swift
//  ProjectOne
//
//  Central service for managing LLM providers, models, and their states
//  Provides comprehensive visibility and dynamic model loading capabilities
//

import Foundation
import SwiftUI
import Combine
import os.log

/// Central service for LLM management and monitoring
@MainActor
public class LLMManagementService: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "LLMManagementService")
    
    // MARK: - Published State
    
    @Published public var providerStatuses: [LLMProviderStatus] = []
    @Published public var availableModels: [LLMModelInfo] = []
    @Published public var activeProviders: [String] = []
    @Published public var initializationAttempts: [LLMInitializationAttempt] = []
    @Published public var systemReadiness: LLMSystemReadiness = .initializing
    @Published public var lastUpdate = Date()
    
    // MARK: - Dependencies
    
    private let mlxLLMProvider: MLXLLMProvider
    private let mlxVLMProvider: MLXVLMProvider
    private let foundationProvider: AppleFoundationModelsProvider
    private let mlxCommunityService = MLXCommunityService()
    private let modelValidator = MLXModelValidator.shared
    
    // MARK: - State Management
    
    private var cancellables = Set<AnyCancellable>()
    private var providerObservers: [String: AnyCancellable] = [:]
    
    // MARK: - Initialization
    
    public init(
        mlxLLMProvider: MLXLLMProvider,
        mlxVLMProvider: MLXVLMProvider,
        foundationProvider: AppleFoundationModelsProvider
    ) {
        self.mlxLLMProvider = mlxLLMProvider
        self.mlxVLMProvider = mlxVLMProvider
        self.foundationProvider = foundationProvider
        
        setupProviderObservation()
        loadAvailableModels()
        updateProviderStatuses()
        
        // Start discovering community models in background
        Task {
            try? await mlxCommunityService.discoverModels()
        }
        
        logger.info("LLM Management Service initialized")
    }
    
    // MARK: - Provider Observation
    
    private func setupProviderObservation() {
        // Observe MLX LLM Provider
        providerObservers["mlx_llm"] = mlxLLMProvider.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateProviderStatuses()
            }
        
        // Observe MLX VLM Provider
        providerObservers["mlx_vlm"] = mlxVLMProvider.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateProviderStatuses()
            }
        
        // Observe Foundation Provider
        providerObservers["foundation"] = foundationProvider.objectWillChange
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateProviderStatuses()
            }
    }
    
    private func updateProviderStatuses() {
        let statuses = [
            createMLXLLMStatus(),
            createMLXVLMStatus(),
            createFoundationStatus()
        ]
        
        providerStatuses = statuses
        activeProviders = statuses.filter { $0.isReady }.map { $0.id }
        systemReadiness = determineSystemReadiness(from: statuses)
        lastUpdate = Date()
        
        logger.debug("Updated provider statuses: \(activeProviders.count)/\(statuses.count) ready")
    }
    
    private func createMLXLLMStatus() -> LLMProviderStatus {
        return LLMProviderStatus(
            id: "mlx_llm",
            name: "MLX Language Model",
            type: .textGeneration,
            isSupported: mlxLLMProvider.isSupported,
            isReady: mlxLLMProvider.isReady,
            isLoading: mlxLLMProvider.isLoading,
            loadingProgress: mlxLLMProvider.loadingProgress,
            errorMessage: mlxLLMProvider.errorMessage,
            currentModel: getCurrentMLXLLMModel(),
            capabilities: [.textGeneration, .conversational, .onDevice],
            deviceRequirements: "Apple Silicon required",
            estimatedMemoryUsage: getMLXLLMMemoryUsage(),
            lastAttempt: getLastAttempt(for: "mlx_llm")
        )
    }
    
    private func createMLXVLMStatus() -> LLMProviderStatus {
        return LLMProviderStatus(
            id: "mlx_vlm",
            name: "MLX Vision-Language Model",
            type: .multimodal,
            isSupported: mlxVLMProvider.isSupported,
            isReady: mlxVLMProvider.isReady,
            isLoading: mlxVLMProvider.isLoading,
            loadingProgress: mlxVLMProvider.loadingProgress,
            errorMessage: mlxVLMProvider.errorMessage,
            currentModel: getCurrentMLXVLMModel(),
            capabilities: [.textGeneration, .imageUnderstanding, .multimodal, .onDevice],
            deviceRequirements: "Apple Silicon required",
            estimatedMemoryUsage: getMLXVLMMemoryUsage(),
            lastAttempt: getLastAttempt(for: "mlx_vlm")
        )
    }
    
    private func createFoundationStatus() -> LLMProviderStatus {
        return LLMProviderStatus(
            id: "foundation",
            name: "Apple Foundation Models",
            type: .foundation,
            isSupported: true, // Available on iOS 26.0+
            isReady: foundationProvider.isAvailable,
            isLoading: foundationProvider.modelLoadingStatus == .preparing || foundationProvider.modelLoadingStatus == .loading,
            loadingProgress: getFoundationLoadingProgress(),
            errorMessage: getFoundationError(),
            currentModel: "Apple Intelligence",
            capabilities: [.textGeneration, .structuredGeneration, .systemIntegration, .onDevice, .private],
            deviceRequirements: "iOS 26.0+, Apple Intelligence enabled",
            estimatedMemoryUsage: "System managed",
            lastAttempt: getLastAttempt(for: "foundation")
        )
    }
    
    // MARK: - Model Information Helpers
    
    private func getCurrentMLXLLMModel() -> String? {
        return mlxLLMProvider.getModelInfo()?.displayName
    }
    
    private func getCurrentMLXVLMModel() -> String? {
        return mlxVLMProvider.getModelInfo()?.displayName
    }
    
    private func getMLXLLMMemoryUsage() -> String {
        return mlxLLMProvider.isReady ? "~2-4GB" : "Not loaded"
    }
    
    private func getMLXVLMMemoryUsage() -> String {
        return mlxVLMProvider.isReady ? "~4-8GB" : "Not loaded"
    }
    
    private func getFoundationLoadingProgress() -> Double {
        switch foundationProvider.modelLoadingStatus {
        case .downloading(let progress):
            return progress
        case .ready:
            return 1.0
        case .preparing, .loading:
            return 0.5
        default:
            return 0.0
        }
    }
    
    private func getFoundationError() -> String? {
        switch foundationProvider.modelLoadingStatus {
        case .failed(let error):
            return error
        case .unavailable:
            return "Apple Intelligence not available"
        default:
            return nil
        }
    }
    
    private func getLastAttempt(for providerId: String) -> LLMInitializationAttempt? {
        return initializationAttempts
            .filter { $0.providerId == providerId }
            .max(by: { $0.timestamp < $1.timestamp })
    }
    
    private func determineSystemReadiness(from statuses: [LLMProviderStatus]) -> LLMSystemReadiness {
        let readyCount = statuses.filter { $0.isReady }.count
        let loadingCount = statuses.filter { $0.isLoading }.count
        let errorCount = statuses.filter { $0.errorMessage != nil }.count
        
        if readyCount > 0 {
            if loadingCount > 0 {
                return .partiallyReady(readyCount: readyCount, totalCount: statuses.count)
            } else {
                return .ready(providerCount: readyCount)
            }
        } else if loadingCount > 0 {
            return .initializing
        } else if errorCount > 0 {
            return .failed(errorCount: errorCount)
        } else {
            return .notStarted
        }
    }
    
    // MARK: - Model Discovery and Loading
    
    private func loadAvailableModels() {
        // Start with foundation models and basic MLX models
        var models: [LLMModelInfo] = [
            // Foundation Models
            LLMModelInfo(
                id: "apple-intelligence",
                name: "Apple Intelligence",
                provider: "foundation",
                type: .foundation,
                size: "System managed",
                memoryRequirement: "System managed",
                isRecommended: true,
                isInstalled: true,
                downloadURL: nil,
                description: "Apple's on-device AI system with privacy-first design"
            )
        ]
        
        // Add community models if available with validation
        for communityModel in mlxCommunityService.availableModels {
            let providerType: LLMProviderType = communityModel.name.lowercased().contains("llava") ? .multimodal : .textGeneration
            let provider = providerType == .multimodal ? "mlx_vlm" : "mlx_llm"
            
            // Validate model compatibility
            let validationResult = modelValidator.validateModel(communityModel)
            let isRecommended = validationResult.shouldRecommend && communityModel.isRecommended
            
            let modelInfo = LLMModelInfo(
                id: communityModel.id,
                name: communityModel.name,
                provider: provider,
                type: providerType,
                size: communityModel.estimatedSize,
                memoryRequirement: communityModel.memoryRequirement,
                isRecommended: isRecommended,
                isInstalled: mlxCommunityService.isModelDownloaded(communityModel),
                downloadURL: communityModel.downloadURL,
                description: communityModel.description
            )
            models.append(modelInfo)
        }
        
        availableModels = models
        logger.info("Loaded \(availableModels.count) available models (\(mlxCommunityService.availableModels.count) from community)")
    }
    
    /// Refresh available models from MLX Community
    public func refreshCommunityModels() async {
        do {
            try await mlxCommunityService.discoverModels()
            loadAvailableModels() // Reload with new community models
        } catch {
            logger.error("Failed to refresh community models: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API
    
    public func recordInitializationAttempt(_ attempt: LLMInitializationAttempt) {
        initializationAttempts.append(attempt)
        
        // Keep only recent attempts (last 50)
        if initializationAttempts.count > 50 {
            initializationAttempts = Array(initializationAttempts.suffix(50))
        }
        
        updateProviderStatuses()
    }
    
    public func loadModel(_ modelInfo: LLMModelInfo) async throws {
        let attempt = LLMInitializationAttempt(
            id: UUID(),
            providerId: modelInfo.provider,
            modelId: modelInfo.id,
            timestamp: Date(),
            status: .started,
            errorMessage: nil
        )
        
        recordInitializationAttempt(attempt)
        
        do {
            switch modelInfo.provider {
            case "mlx_llm":
                // Create configuration from model info
                let config = MLXModelConfiguration(
                    modelId: modelInfo.id,
                    name: modelInfo.name,
                    type: .llm,
                    downloadURL: modelInfo.downloadURL
                )
                try await mlxLLMProvider.loadModel(config)
                
            case "mlx_vlm":
                let config = MLXModelConfiguration(
                    modelId: modelInfo.id,
                    name: modelInfo.name,
                    type: .vlm,
                    downloadURL: modelInfo.downloadURL
                )
                try await mlxVLMProvider.loadModel(config)
                
            case "foundation":
                try await foundationProvider.prepare()
                
            default:
                throw LLMManagementError.unknownProvider(modelInfo.provider)
            }
            
            let successAttempt = LLMInitializationAttempt(
                id: UUID(),
                providerId: modelInfo.provider,
                modelId: modelInfo.id,
                timestamp: Date(),
                status: .succeeded,
                errorMessage: nil
            )
            recordInitializationAttempt(successAttempt)
            
        } catch {
            let failedAttempt = LLMInitializationAttempt(
                id: UUID(),
                providerId: modelInfo.provider,
                modelId: modelInfo.id,
                timestamp: Date(),
                status: .failed,
                errorMessage: error.localizedDescription
            )
            recordInitializationAttempt(failedAttempt)
            throw error
        }
    }
    
    public func unloadModel(providerId: String) async {
        switch providerId {
        case "mlx_llm":
            await mlxLLMProvider.unloadModel()
        case "mlx_vlm":
            await mlxVLMProvider.unloadModel()
        default:
            logger.warning("Cannot unload model for provider: \(providerId)")
        }
        
        updateProviderStatuses()
    }
    
    public func refreshProviderStatuses() {
        updateProviderStatuses()
    }
    
    public func getProviderStatus(id: String) -> LLMProviderStatus? {
        return providerStatuses.first { $0.id == id }
    }
    
    public func getRecentAttempts(for providerId: String, limit: Int = 10) -> [LLMInitializationAttempt] {
        return initializationAttempts
            .filter { $0.providerId == providerId }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(limit)
            .map { $0 }
    }
    
    /// Get system information for compatibility checking
    public func getSystemInfo() -> MLXModelValidator.SystemInfo {
        return modelValidator.getSystemInfo()
    }
    
    /// Validate a specific model for compatibility
    public func validateModel(_ modelId: String) -> MLXModelValidator.ValidationResult? {
        // Find the community model
        guard let communityModel = mlxCommunityService.availableModels.first(where: { $0.id == modelId }) else {
            return nil
        }
        
        return modelValidator.validateModel(communityModel)
    }
    
    /// Get recommended models based on system compatibility
    public func getRecommendedModels() -> [LLMModelInfo] {
        let communityModels = mlxCommunityService.availableModels
        let recommendedCommunityModels = modelValidator.getRecommendedModels(communityModels)
        
        var recommended: [LLMModelInfo] = []
        
        // Add foundation model if supported
        let systemInfo = modelValidator.getSystemInfo()
        if systemInfo.mlxSupported {
            recommended.append(LLMModelInfo(
                id: "apple-intelligence",
                name: "Apple Intelligence",
                provider: "foundation",
                type: .foundation,
                size: "System managed",
                memoryRequirement: "System managed",
                isRecommended: true,
                isInstalled: true,
                downloadURL: nil,
                description: "Apple's on-device AI system with privacy-first design"
            ))
        }
        
        // Add recommended community models
        for communityModel in recommendedCommunityModels.prefix(5) {
            let providerType: LLMProviderType = communityModel.name.lowercased().contains("llava") ? .multimodal : .textGeneration
            let provider = providerType == .multimodal ? "mlx_vlm" : "mlx_llm"
            
            recommended.append(LLMModelInfo(
                id: communityModel.id,
                name: communityModel.name,
                provider: provider,
                type: providerType,
                size: communityModel.estimatedSize,
                memoryRequirement: communityModel.memoryRequirement,
                isRecommended: true,
                isInstalled: mlxCommunityService.isModelDownloaded(communityModel),
                downloadURL: communityModel.downloadURL,
                description: communityModel.description
            ))
        }
        
        return recommended
    }
}

// MARK: - Supporting Types

public struct LLMProviderStatus: Identifiable {
    public let id: String
    public let name: String
    public let type: LLMProviderType
    public let isSupported: Bool
    public let isReady: Bool
    public let isLoading: Bool
    public let loadingProgress: Double
    public let errorMessage: String?
    public let currentModel: String?
    public let capabilities: [LLMCapability]
    public let deviceRequirements: String
    public let estimatedMemoryUsage: String
    public let lastAttempt: LLMInitializationAttempt?
    
    public var statusDescription: String {
        if let error = errorMessage {
            return "Error: \(error)"
        } else if isLoading {
            return "Loading... (\(Int(loadingProgress * 100))%)"
        } else if isReady {
            return "Ready (\(currentModel ?? "Unknown model"))"
        } else if !isSupported {
            return "Not supported (\(deviceRequirements))"
        } else {
            return "Not initialized"
        }
    }
    
    public var statusColor: Color {
        if errorMessage != nil {
            return .red
        } else if isReady {
            return .green
        } else if isLoading {
            return .orange
        } else {
            return .gray
        }
    }
}

public enum LLMProviderType: String, CaseIterable {
    case textGeneration = "text"
    case multimodal = "multimodal"
    case foundation = "foundation"
    
    public var displayName: String {
        switch self {
        case .textGeneration: return "Text Generation"
        case .multimodal: return "Multimodal"
        case .foundation: return "Foundation Models"
        }
    }
}

public enum LLMCapability: String, CaseIterable {
    case textGeneration = "text_generation"
    case imageUnderstanding = "image_understanding"
    case multimodal = "multimodal"
    case structuredGeneration = "structured_generation"
    case conversational = "conversational"
    case systemIntegration = "system_integration"
    case onDevice = "on_device"
    case private = "private"
    
    public var displayName: String {
        switch self {
        case .textGeneration: return "Text Generation"
        case .imageUnderstanding: return "Image Understanding"
        case .multimodal: return "Multimodal"
        case .structuredGeneration: return "Structured Generation"
        case .conversational: return "Conversational"
        case .systemIntegration: return "System Integration"
        case .onDevice: return "On-Device"
        case .private: return "Privacy-First"
        }
    }
    
    public var icon: String {
        switch self {
        case .textGeneration: return "text.cursor"
        case .imageUnderstanding: return "eye"
        case .multimodal: return "photo.on.rectangle"
        case .structuredGeneration: return "list.bullet.rectangle"
        case .conversational: return "bubble.left.and.bubble.right"
        case .systemIntegration: return "gearshape.2"
        case .onDevice: return "iphone"
        case .private: return "lock.shield"
        }
    }
}

public struct LLMModelInfo: Identifiable {
    public let id: String
    public let name: String
    public let provider: String
    public let type: LLMProviderType
    public let size: String
    public let memoryRequirement: String
    public let isRecommended: Bool
    public let isInstalled: Bool
    public let downloadURL: String?
    public let description: String
}

public struct LLMInitializationAttempt: Identifiable {
    public let id: UUID
    public let providerId: String
    public let modelId: String
    public let timestamp: Date
    public let status: LLMInitializationStatus
    public let errorMessage: String?
}

public enum LLMInitializationStatus: String, CaseIterable {
    case started = "started"
    case succeeded = "succeeded"
    case failed = "failed"
    
    public var displayName: String {
        switch self {
        case .started: return "Started"
        case .succeeded: return "Succeeded"
        case .failed: return "Failed"
        }
    }
    
    public var color: Color {
        switch self {
        case .started: return .orange
        case .succeeded: return .green
        case .failed: return .red
        }
    }
}

public enum LLMSystemReadiness {
    case notStarted
    case initializing
    case partiallyReady(readyCount: Int, totalCount: Int)
    case ready(providerCount: Int)
    case failed(errorCount: Int)
    
    public var displayName: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .initializing:
            return "Initializing..."
        case .partiallyReady(let ready, let total):
            return "Partially Ready (\(ready)/\(total))"
        case .ready(let count):
            return "Ready (\(count) provider\(count == 1 ? "" : "s"))"
        case .failed(let errors):
            return "Failed (\(errors) error\(errors == 1 ? "" : "s"))"
        }
    }
    
    public var color: Color {
        switch self {
        case .notStarted, .failed:
            return .red
        case .initializing:
            return .orange
        case .partiallyReady:
            return .yellow
        case .ready:
            return .green
        }
    }
    
    public var isReady: Bool {
        switch self {
        case .ready, .partiallyReady:
            return true
        default:
            return false
        }
    }
}

public enum LLMManagementError: Error, LocalizedError {
    case unknownProvider(String)
    case modelNotFound(String)
    case downloadFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .unknownProvider(let provider):
            return "Unknown provider: \(provider)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}