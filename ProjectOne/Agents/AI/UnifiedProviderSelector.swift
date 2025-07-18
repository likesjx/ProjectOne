//
//  UnifiedProviderSelector.swift
//  ProjectOne
//
//  Created for unified provider selection and management
//

import Foundation
import os.log
import Combine

/// Unified provider selector that manages all types of AI providers
/// Automatically selects the best provider based on input type, device capabilities, and requirements
public class UnifiedProviderSelector: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var textGenerationProviders: [UnifiedModelProvider] = []
    @Published public private(set) var transcriptionProviders: [UnifiedModelProvider] = []
    @Published public private(set) var visionProviders: [UnifiedModelProvider] = []
    @Published public private(set) var multimodalProviders: [UnifiedModelProvider] = []
    @Published public private(set) var remoteProviders: [UnifiedModelProvider] = []
    
    @Published public private(set) var currentProviders: [ModelType: UnifiedModelProvider] = [:]
    @Published public private(set) var providerStatus: ProviderSelectionStatus = .initializing
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "UnifiedProviderSelector")
    
    // Provider instances
    private var mlxProvider: UnifiedMLXProvider?
    private var transcriptionProvider: UnifiedTranscriptionProvider?
    private var appleFoundationProvider: UnifiedAppleFoundationProvider?
    private var remoteProvider: UnifiedRemoteProvider?
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing Unified Provider Selector")
        Task {
            await initializeProviders()
        }
    }
    
    // MARK: - Provider Selection
    
    /// Process input with automatic provider selection
    public func process(input: UnifiedModelInput, preferredType: ModelType? = nil) async throws -> UnifiedModelOutput {
        let modelType = preferredType ?? determineOptimalModelType(for: input)
        
        guard let provider = currentProviders[modelType] else {
            throw UnifiedModelProviderError.providerUnavailable("No provider available for \(modelType.displayName)")
        }
        
        return try await provider.process(input: input, modelType: modelType)
    }
    
    /// Get the best provider for a specific model type
    public func getProvider(for modelType: ModelType) -> UnifiedModelProvider? {
        return currentProviders[modelType]
    }
    
    /// Get all available providers for a model type
    public func getAvailableProviders(for modelType: ModelType) -> [UnifiedModelProvider] {
        switch modelType {
        case .textGeneration:
            return textGenerationProviders
        case .speechTranscription:
            return transcriptionProviders
        case .visionLanguage:
            return visionProviders
        case .multimodal:
            return multimodalProviders
        case .audioProcessing:
            return transcriptionProviders
        case .remote:
            return remoteProviders
        }
    }
    
    /// Manually switch to a specific provider for a model type
    public func switchToProvider(_ provider: UnifiedModelProvider, for modelType: ModelType) async throws {
        do {
            try await provider.prepare(modelTypes: [modelType])
            
            await MainActor.run {
                currentProviders[modelType] = provider
            }
            
            logger.info("Switched to provider: \(provider.displayName) for \(modelType.displayName)")
        } catch {
            logger.error("Failed to switch to provider \(provider.displayName): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Refresh all providers
    public func refreshProviders() async {
        logger.info("Refreshing all providers")
        await initializeProviders()
    }
    
    // MARK: - Provider Information
    
    /// Get comprehensive provider information
    public func getProviderInfo() -> UnifiedProviderInfo {
        let deviceCapabilities = getDeviceCapabilities()
        
        var providersByType: [ModelType: [String]] = [:]
        for (type, providers) in [
            (ModelType.textGeneration, textGenerationProviders),
            (ModelType.speechTranscription, transcriptionProviders),
            (ModelType.visionLanguage, visionProviders),
            (ModelType.multimodal, multimodalProviders),
            (ModelType.remote, remoteProviders)
        ] {
            providersByType[type] = providers.map { $0.displayName }
        }
        
        let currentProviderNames = Dictionary(uniqueKeysWithValues: 
            currentProviders.map { ($0.key, $0.value.displayName) }
        )
        
        return UnifiedProviderInfo(
            deviceCapabilities: deviceCapabilities,
            availableProviders: providersByType,
            currentProviders: currentProviderNames,
            status: providerStatus
        )
    }
    
    // MARK: - Private Implementation
    
    private func initializeProviders() async {
        await MainActor.run {
            providerStatus = .initializing
        }
        
        logger.info("Initializing all AI providers")
        
        // Initialize providers based on device capabilities
        await initializeMLXProvider()
        await initializeTranscriptionProvider()
        await initializeAppleFoundationProvider()
        await initializeRemoteProvider()
        
        // Categorize providers
        await categorizeProviders()
        
        // Select optimal providers for each type
        await selectOptimalProviders()
        
        await MainActor.run {
            providerStatus = currentProviders.isEmpty ? .unavailable : .ready
        }
        
        logger.info("Initialized \(self.currentProviders.count) provider types")
    }
    
    private func initializeMLXProvider() async {
        if await shouldUseMlxProvider() {
            logger.info("Initializing MLX provider")
            let provider = UnifiedMLXProvider()
            mlxProvider = provider
        } else {
            logger.info("MLX provider not available (simulator or incompatible hardware)")
        }
    }
    
    private func initializeTranscriptionProvider() async {
        logger.info("Initializing transcription provider")
        let provider = UnifiedTranscriptionProvider()
        transcriptionProvider = provider
    }
    
    private func initializeAppleFoundationProvider() async {
        if await shouldUseAppleFoundationProvider() {
            logger.info("Initializing Apple Foundation provider")
            let provider = UnifiedAppleFoundationProvider()
            appleFoundationProvider = provider
        } else {
            logger.info("Apple Foundation provider not available")
        }
    }
    
    private func initializeRemoteProvider() async {
        logger.info("Initializing remote provider")
        let provider = UnifiedRemoteProvider()
        remoteProvider = provider
    }
    
    private func categorizeProviders() async {
        var textProviders: [UnifiedModelProvider] = []
        var transcriptionProviders: [UnifiedModelProvider] = []
        var visionProviders: [UnifiedModelProvider] = []
        var multimodalProviders: [UnifiedModelProvider] = []
        var remoteProviders: [UnifiedModelProvider] = []
        
        // Categorize each provider
        for provider in [mlxProvider, transcriptionProvider, appleFoundationProvider, remoteProvider].compactMap({ $0 }) {
            for modelType in provider.supportedModelTypes {
                switch modelType {
                case .textGeneration:
                    textProviders.append(provider)
                case .speechTranscription, .audioProcessing:
                    transcriptionProviders.append(provider)
                case .visionLanguage:
                    visionProviders.append(provider)
                case .multimodal:
                    multimodalProviders.append(provider)
                case .remote:
                    remoteProviders.append(provider)
                }
            }
        }
        
        await MainActor.run {
            self.textGenerationProviders = Array(Set(textProviders.map { $0.identifier })).compactMap { id in
                textProviders.first { $0.identifier == id }
            }
            self.transcriptionProviders = Array(Set(transcriptionProviders.map { $0.identifier })).compactMap { id in
                transcriptionProviders.first { $0.identifier == id }
            }
            self.visionProviders = Array(Set(visionProviders.map { $0.identifier })).compactMap { id in
                visionProviders.first { $0.identifier == id }
            }
            self.multimodalProviders = Array(Set(multimodalProviders.map { $0.identifier })).compactMap { id in
                multimodalProviders.first { $0.identifier == id }
            }
            self.remoteProviders = Array(Set(remoteProviders.map { $0.identifier })).compactMap { id in
                remoteProviders.first { $0.identifier == id }
            }
        }
    }
    
    private func selectOptimalProviders() async {
        var selectedProviders: [ModelType: UnifiedModelProvider] = [:]
        
        // Select best provider for each model type
        selectedProviders[.textGeneration] = await selectBestProvider(from: textGenerationProviders, for: .textGeneration)
        selectedProviders[.speechTranscription] = await selectBestProvider(from: transcriptionProviders, for: .speechTranscription)
        selectedProviders[.visionLanguage] = await selectBestProvider(from: visionProviders, for: .visionLanguage)
        selectedProviders[.multimodal] = await selectBestProvider(from: multimodalProviders, for: .multimodal)
        selectedProviders[.remote] = await selectBestProvider(from: remoteProviders, for: .remote)
        
        // Prepare selected providers
        for (modelType, provider) in selectedProviders.compactMap({ $0.value != nil ? ($0.key, $0.value) : nil }) {
            do {
                try await provider.prepare(modelTypes: [modelType])
                logger.info("Prepared provider: \(provider.displayName) for \(modelType.displayName)")
            } catch {
                logger.warning("Failed to prepare provider \(provider.displayName): \(error.localizedDescription)")
            }
        }
        
        await MainActor.run {
            self.currentProviders = selectedProviders.compactMapValues { $0 }
        }
    }
    
    private func selectBestProvider(from providers: [UnifiedModelProvider], for modelType: ModelType) async -> UnifiedModelProvider? {
        guard !providers.isEmpty else { return nil }
        
        // Score providers based on capabilities
        var scoredProviders: [(UnifiedModelProvider, Double)] = []
        
        for provider in providers {
            var score = 0.0
            
            // Prefer on-device providers
            if provider.capabilities.isOnDevice {
                score += 10.0
            }
            
            // Prefer providers that support personal data
            if provider.capabilities.supportsPersonalData {
                score += 5.0
            }
            
            // Prefer providers with better response times
            score += max(0, 5.0 - provider.capabilities.estimatedResponseTime)
            
            // Prefer available providers
            if provider.isAvailable {
                score += 20.0
            }
            
            // Prefer healthy providers
            if provider.healthStatus.isHealthy {
                score += 15.0
            }
            
            scoredProviders.append((provider, score))
        }
        
        // Sort by score and return the best
        scoredProviders.sort { $0.1 > $1.1 }
        return scoredProviders.first?.0
    }
    
    private func determineOptimalModelType(for input: UnifiedModelInput) -> ModelType {
        // Determine model type based on input characteristics
        let hasText = input.text != nil
        let hasAudio = input.audioData != nil
        let hasImage = input.imageData != nil
        let hasVideo = input.videoData != nil
        
        let modalityCount = [hasText, hasAudio, hasImage, hasVideo].filter { $0 }.count
        
        // Multimodal if multiple modalities
        if modalityCount > 1 {
            return .multimodal
        }
        
        // Single modality
        if hasAudio && !hasText {
            return .speechTranscription
        }
        
        if hasImage && hasText {
            return .visionLanguage
        }
        
        if hasText {
            return .textGeneration
        }
        
        // Default to text generation
        return .textGeneration
    }
    
    private func shouldUseMlxProvider() async -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        #if arch(arm64)
        return true
        #else
        return false
        #endif
        #endif
    }
    
    private func shouldUseAppleFoundationProvider() async -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
        return false
    }
    
    private func getDeviceCapabilities() -> UnifiedDeviceCapabilities {
        let isSimulator: Bool
        let isAppleSilicon: Bool
        let supportsAppleIntelligence: Bool
        
        #if targetEnvironment(simulator)
        isSimulator = true
        isAppleSilicon = false
        #else
        isSimulator = false
        #if arch(arm64)
        isAppleSilicon = true
        #else
        isAppleSilicon = false
        #endif
        #endif
        
        if #available(iOS 26.0, macOS 26.0, *) {
            supportsAppleIntelligence = true
        } else {
            supportsAppleIntelligence = false
        }
        
        return UnifiedDeviceCapabilities(
            isSimulator: isSimulator,
            isAppleSilicon: isAppleSilicon,
            supportsMLX: !isSimulator && isAppleSilicon,
            supportsAppleIntelligence: supportsAppleIntelligence,
            supportsSpeechRecognition: true,
            supportsVision: true,
            supportsAudio: true
        )
    }
}

// MARK: - Supporting Types

public enum ProviderSelectionStatus {
    case initializing
    case ready
    case unavailable
    case error(String)
}

public struct UnifiedProviderInfo {
    let deviceCapabilities: UnifiedDeviceCapabilities
    let availableProviders: [ModelType: [String]]
    let currentProviders: [ModelType: String]
    let status: ProviderSelectionStatus
}

public struct UnifiedDeviceCapabilities {
    let isSimulator: Bool
    let isAppleSilicon: Bool
    let supportsMLX: Bool
    let supportsAppleIntelligence: Bool
    let supportsSpeechRecognition: Bool
    let supportsVision: Bool
    let supportsAudio: Bool
    
    var description: String {
        var capabilities: [String] = []
        
        if isSimulator {
            capabilities.append("iOS Simulator")
        } else {
            capabilities.append("Real Hardware")
        }
        
        if isAppleSilicon {
            capabilities.append("Apple Silicon")
        }
        
        if supportsMLX {
            capabilities.append("MLX Compatible")
        }
        
        if supportsAppleIntelligence {
            capabilities.append("Apple Intelligence")
        }
        
        if supportsSpeechRecognition {
            capabilities.append("Speech Recognition")
        }
        
        if supportsVision {
            capabilities.append("Vision Processing")
        }
        
        if supportsAudio {
            capabilities.append("Audio Processing")
        }
        
        return capabilities.joined(separator: ", ")
    }
}

// MARK: - Convenience Extensions

extension UnifiedProviderSelector {
    
    /// Process text input
    public func processText(_ text: String, context: MemoryContext? = nil) async throws -> UnifiedModelOutput {
        let input = UnifiedModelInput.text(text, context: context)
        return try await process(input: input, preferredType: .textGeneration)
    }
    
    /// Process audio input
    public func processAudio(_ audioData: AudioData) async throws -> UnifiedModelOutput {
        let input = UnifiedModelInput.audio(audioData)
        return try await process(input: input, preferredType: .speechTranscription)
    }
    
    /// Process image with text
    public func processImage(_ imageData: Data, with text: String? = nil, context: MemoryContext? = nil) async throws -> UnifiedModelOutput {
        let input = UnifiedModelInput.multimodal(text: text, imageData: imageData, context: context)
        return try await process(input: input, preferredType: .visionLanguage)
    }
    
    /// Process multimodal input
    public func processMultimodal(
        text: String? = nil,
        audioData: AudioData? = nil,
        imageData: Data? = nil,
        context: MemoryContext? = nil
    ) async throws -> UnifiedModelOutput {
        let input = UnifiedModelInput.multimodal(
            text: text,
            audioData: audioData,
            imageData: imageData,
            context: context
        )
        return try await process(input: input, preferredType: .multimodal)
    }
}