//
//  WhisperKitModelPreloader.swift
//  ProjectOne
//
//  Created by Claude on 7/12/25.
//

import Foundation
import WhisperKit
import os.log
import Combine

/// Manages background preloading of WhisperKit models for optimal performance
@MainActor
public class WhisperKitModelPreloader: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "WhisperKitModelPreloader")
    
    @Published public var isLoading = false
    @Published public var isReady = false
    @Published public var loadingProgress: Double = 0.0
    @Published public var loadingStatus = "Initializing..."
    @Published public var lastError: Error?
    
    private var preloadedWhisperKit: WhisperKit?
    private var preloadedModelSize: WhisperKitModelSize = .tiny
    private var shouldUseAppleSpeechFallback = false
    
    // MARK: - Singleton
    
    public static let shared = WhisperKitModelPreloader()
    
    private init() {
        logger.info("WhisperKitModelPreloader initialized")
    }
    
    // MARK: - Public Methods
    
    /// Start background model preloading
    public func startPreloading() {
        guard !isLoading && !isReady else {
            logger.info("Model already loading or ready")
            return
        }
        
        logger.info("Starting background WhisperKit model preloading")
        
        Task {
            await performBackgroundLoading()
        }
    }
    
    /// Get preloaded WhisperKit instance
    public func getPreloadedWhisperKit() -> WhisperKit? {
        return preloadedWhisperKit
    }
    
    /// Get the model size that was preloaded
    public func getPreloadedModelSize() -> WhisperKitModelSize {
        return preloadedModelSize
    }
    
    /// Check if we should use Apple Speech as fallback
    public func shouldUseAppleSpeech() -> Bool {
        return shouldUseAppleSpeechFallback
    }
    
    /// Get recommended transcription strategy based on preloading results
    public func getRecommendedStrategy() -> EngineSelectionStrategy {
        if shouldUseAppleSpeechFallback {
            return .preferApple
        } else if isReady && preloadedWhisperKit != nil {
            return .preferWhisperKit
        } else {
            return .automatic
        }
    }
    
    /// Force reload with different model size
    public func reloadWithModelSize(_ modelSize: WhisperKitModelSize) {
        logger.info("Reloading with model size: \(modelSize.rawValue)")
        
        Task {
            await performBackgroundLoading(forceModelSize: modelSize)
        }
    }
    
    /// Clean up preloaded resources
    public func cleanup() {
        logger.info("Cleaning up preloaded WhisperKit resources")
        preloadedWhisperKit = nil
        shouldUseAppleSpeechFallback = false
        isReady = false
        lastError = nil
        loadingProgress = 0.0
        loadingStatus = "Cleaned up"
    }
    
    // MARK: - Private Methods
    
    private func performBackgroundLoading(forceModelSize: WhisperKitModelSize? = nil) async {
        isLoading = true
        isReady = false
        lastError = nil
        loadingProgress = 0.0
        
        do {
            // Determine optimal model size
            let modelSize = forceModelSize ?? determineOptimalModelSize()
            preloadedModelSize = modelSize
            
            updateStatus("Selecting model: \(modelSize.rawValue)")
            await Task.yield() // Allow UI updates
            
            loadingProgress = 0.1
            updateStatus("Downloading model...")
            
            // Create WhisperKit instance with timeout
            let whisperKit = try await createWhisperKitWithTimeout(modelSize: modelSize)
            
            loadingProgress = 0.9
            updateStatus("Finalizing setup...")
            
            // Store the preloaded instance
            preloadedWhisperKit = whisperKit
            
            loadingProgress = 1.0
            updateStatus("Ready")
            isReady = true
            isLoading = false
            
            logger.info("WhisperKit model \(modelSize.rawValue) preloaded successfully")
            
        } catch {
            logger.error("Failed to preload WhisperKit model: \(error.localizedDescription)")
            logger.info("Falling back to Apple Speech for transcription")
            
            // Set Apple Speech fallback flag
            shouldUseAppleSpeechFallback = true
            lastError = error
            isLoading = false
            loadingProgress = 1.0
            isReady = true // We're ready with Apple Speech fallback
            updateStatus("Ready (using Apple Speech)")
            
            // Force cleanup of any partial WhisperKit state
            preloadedWhisperKit = nil
        }
    }
    
    private func createWhisperKitWithTimeout(modelSize: WhisperKitModelSize) async throws -> WhisperKit {
        let modelIdentifier = modelSize.modelIdentifier
        
        // Use appropriate model for simulator
        let actualModelIdentifier: String
        #if targetEnvironment(simulator)
        actualModelIdentifier = "openai_whisper-tiny"
        logger.info("Using tiny model in simulator for compatibility")
        #else
        actualModelIdentifier = modelIdentifier
        #endif
        
        let loadingTask = Task {
            try await WhisperKit(
                model: actualModelIdentifier,
                download: true
            )
        }
        
        // 5 minute timeout for model download and initialization
        let timeoutDuration: TimeInterval = 300.0
        
        return try await withThrowingTaskGroup(of: WhisperKit.self) { group in
            group.addTask { 
                try await loadingTask.value
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutDuration * 1_000_000_000))
                throw SpeechTranscriptionError.processingFailed("Model preloading timeout after \(timeoutDuration)s")
            }
            
            for try await result in group {
                group.cancelAll()
                return result
            }
            
            throw SpeechTranscriptionError.processingFailed("Model preloading failed")
        }
    }
    
    private func determineOptimalModelSize() -> WhisperKitModelSize {
        // Always use tiny in simulator
        #if targetEnvironment(simulator)
        return .tiny
        #endif
        
        // Get device capabilities
        let capabilities = ModelPreloaderDeviceCapabilities.detect()
        let availableMemory = capabilities.availableMemory
        
        // Select based on available memory and device capabilities
        if availableMemory > 4 * 1024 * 1024 * 1024 { // 4GB+
            return capabilities.hasAppleSilicon ? .base : .tiny // Start conservative
        } else if availableMemory > 2 * 1024 * 1024 * 1024 { // 2GB+
            return .tiny
        } else {
            return .tiny
        }
    }
    
    private func updateStatus(_ status: String) {
        loadingStatus = status
        logger.info("Preloader status: \(status)")
    }
}

// MARK: - Device Capabilities for Model Preloader

/// Device capabilities detection for model preloader
private struct ModelPreloaderDeviceCapabilities {
    let totalMemory: UInt64
    let availableMemory: UInt64
    let hasAppleSilicon: Bool
    
    static func detect() -> ModelPreloaderDeviceCapabilities {
        let processInfo = ProcessInfo.processInfo
        let totalMemory = processInfo.physicalMemory
        let availableMemory = totalMemory - UInt64(processInfo.thermalState.rawValue * 1024 * 1024 * 100)
        
        var hasAppleSilicon = false
        #if targetEnvironment(simulator)
        hasAppleSilicon = true
        #else
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        hasAppleSilicon = size > 0
        #endif
        
        return ModelPreloaderDeviceCapabilities(
            totalMemory: totalMemory,
            availableMemory: availableMemory,
            hasAppleSilicon: hasAppleSilicon
        )
    }
}