//
//  SpeechEngineFactory.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
import os.log

// MARK: - Device Capabilities

/// Detects and reports device capabilities for transcription
public struct DeviceCapabilities {
    let totalMemory: UInt64
    let availableMemory: UInt64
    let hasAppleSilicon: Bool
    let supportsMLX: Bool
    let deviceModel: String
    let osVersion: String
    
    static func detect() -> DeviceCapabilities {
        let processInfo = ProcessInfo.processInfo
        
        // Detect total memory
        let totalMemory = processInfo.physicalMemory
        
        // Estimate available memory (simplified)
        let availableMemory = totalMemory - UInt64(processInfo.thermalState.rawValue * 1024 * 1024 * 100)
        
        // Check for Apple Silicon (simplified detection)
        var hasAppleSilicon = false
        var supportsMLX = false
        
        #if targetEnvironment(simulator)
        hasAppleSilicon = true // Assume simulator runs on Apple Silicon
        supportsMLX = false // MLX Metal initialization fails in simulator
        #else
        // On device, check for Apple Silicon indicators
        var size = 0
        sysctlbyname("hw.optional.arm64", nil, &size, nil, 0)
        if size > 0 {
            hasAppleSilicon = true
            supportsMLX = true
        }
        #endif
        
        // Get device information based on platform
        let deviceModel: String
        let osVersion: String
        
        #if canImport(UIKit)
        let device = UIDevice.current
        deviceModel = device.model
        osVersion = device.systemVersion
        #elseif canImport(AppKit)
        deviceModel = "Mac"
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        #else
        deviceModel = "Unknown"
        osVersion = "Unknown"
        #endif
        
        return DeviceCapabilities(
            totalMemory: totalMemory,
            availableMemory: availableMemory,
            hasAppleSilicon: hasAppleSilicon,
            supportsMLX: supportsMLX,
            deviceModel: deviceModel,
            osVersion: osVersion
        )
    }
}

// MARK: - Engine Selection Strategy

/// Strategy for selecting transcription implementation
public enum EngineSelectionStrategy {
    case automatic
    case preferApple
    case preferMLX
    case appleOnly
    case mlxOnly
    
    public var description: String {
        switch self {
        case .automatic:
            return "Automatic (best available)"
        case .preferApple:
            return "Prefer Apple Speech"
        case .preferMLX:
            return "Prefer MLX"
        case .appleOnly:
            return "Apple Speech only"
        case .mlxOnly:
            return "MLX only"
        }
    }
}

// MARK: - Status Tracking

/// Engine status with detailed information
public struct EngineStatus {
    let primary: TranscriptionMethod?
    let fallback: TranscriptionMethod?
    let isHealthy: Bool
    let lastError: Error?
    let capabilities: DeviceCapabilities
    let statusMessage: String
    
    public init(primary: TranscriptionMethod?, fallback: TranscriptionMethod?, isHealthy: Bool, lastError: Error?, capabilities: DeviceCapabilities, statusMessage: String) {
        self.primary = primary
        self.fallback = fallback
        self.isHealthy = isHealthy
        self.lastError = lastError
        self.capabilities = capabilities
        self.statusMessage = statusMessage
    }
}

/// Status change notifications
public enum EngineStatusChange {
    case primaryEngineChanged(from: TranscriptionMethod?, to: TranscriptionMethod?)
    case fallbackTriggered(from: TranscriptionMethod, to: TranscriptionMethod, reason: Error)
    case engineRecovered(method: TranscriptionMethod)
    case allEnginesFailed(lastError: Error)
}

// MARK: - Configuration

/// Configuration for the speech engine factory
public struct SpeechEngineConfiguration {
    let strategy: EngineSelectionStrategy
    let enableFallback: Bool
    let maxMemoryUsage: UInt64?
    let preferredLanguage: String?
    let logLevel: OSLogType
    
    public init(
        strategy: EngineSelectionStrategy = .automatic,
        enableFallback: Bool = true,
        maxMemoryUsage: UInt64? = nil,
        preferredLanguage: String? = nil,
        logLevel: OSLogType = .default
    ) {
        self.strategy = strategy
        self.enableFallback = enableFallback
        self.maxMemoryUsage = maxMemoryUsage
        self.preferredLanguage = preferredLanguage
        self.logLevel = logLevel
    }
    
    public static let `default` = SpeechEngineConfiguration()
}

// MARK: - Factory

/// Factory for creating and managing speech transcription implementations
public class SpeechEngineFactory {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "SpeechEngineFactory")
    private let configuration: SpeechEngineConfiguration
    private let deviceCapabilities: DeviceCapabilities
    
    private var currentEngine: SpeechTranscriptionProtocol?
    private var fallbackEngine: SpeechTranscriptionProtocol?
    private var lastError: Error?
    private var statusChangeHandler: ((EngineStatusChange) -> Void)?
    
    // MARK: - Initialization
    
    public init(configuration: SpeechEngineConfiguration = .default) {
        self.configuration = configuration
        self.deviceCapabilities = DeviceCapabilities.detect()
        
        logger.info("SpeechEngineFactory initialized with strategy: \(configuration.strategy.description)")
        logger.info("Device capabilities: Memory: \(self.deviceCapabilities.totalMemory / 1024 / 1024)MB, Apple Silicon: \(self.deviceCapabilities.hasAppleSilicon), MLX Support: \(self.deviceCapabilities.supportsMLX)")
    }
    
    // MARK: - Public Methods
    
    /// Get the optimal transcription engine based on configuration and capabilities
    public func getTranscriptionEngine() async throws -> SpeechTranscriptionProtocol {
        if let currentEngine = currentEngine, currentEngine.isAvailable {
            return currentEngine
        }
        
        let previousPrimary = currentEngine?.method
        let selectedEngine = try await selectEngine()
        let newPrimary = selectedEngine.method
        
        // Notify of engine change if different
        if previousPrimary != newPrimary {
            notifyStatusChange(.primaryEngineChanged(from: previousPrimary, to: newPrimary))
        }
        
        currentEngine = selectedEngine
        
        // Set up fallback if enabled
        if configuration.enableFallback {
            fallbackEngine = try await selectFallbackEngine(primary: selectedEngine)
        }
        
        return selectedEngine
    }
    
    /// Get fallback engine if primary fails
    public func getFallbackEngine() async throws -> SpeechTranscriptionProtocol? {
        if let fallbackEngine = fallbackEngine, fallbackEngine.isAvailable {
            return fallbackEngine
        }
        
        if configuration.enableFallback {
            fallbackEngine = try await selectFallbackEngine(primary: currentEngine)
        }
        
        return fallbackEngine
    }
    
    /// Perform transcription with automatic fallback and retry logic
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        var lastError: Error?
        let maxRetries = 3
        
        // Try primary engine with retries
        for attempt in 1...maxRetries {
            do {
                let engine = try await getTranscriptionEngine()
                logger.info("Attempting transcription with \(engine.method.displayName) (attempt \(attempt)/\(maxRetries))")
                
                let result = try await engine.transcribe(audio: audio, configuration: configuration)
                
                // Validate result quality
                if isResultValid(result) {
                    logger.info("Transcription successful with \(engine.method.displayName)")
                    
                    // Clear any previous error and notify of recovery if needed
                    if lastError != nil {
                        notifyStatusChange(.engineRecovered(method: engine.method))
                        lastError = nil
                    }
                    
                    return result
                } else {
                    logger.warning("Low quality result from \(engine.method.displayName), retrying...")
                    lastError = SpeechTranscriptionError.lowQualityResult
                    continue
                }
                
            } catch {
                lastError = error
                logger.warning("Primary transcription failed (attempt \(attempt)/\(maxRetries)): \(error.localizedDescription)")
                
                // For certain errors, don't retry
                if !shouldRetry(error: error) {
                    break
                }
                
                // Wait before retry
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(attempt * 500_000_000)) // 0.5s, 1s, 1.5s delays
                }
            }
        }
        
        // Try fallback engine if primary failed
        if self.configuration.enableFallback, let fallback = try await getFallbackEngine() {
            logger.info("Primary engine exhausted, falling back to \(fallback.method.displayName)")
            
            // Notify of fallback trigger
            if let primaryEngine = currentEngine {
                notifyStatusChange(.fallbackTriggered(from: primaryEngine.method, to: fallback.method, reason: lastError ?? SpeechTranscriptionError.processingFailed("Primary engine failed")))
            }
            
            do {
                let result = try await fallback.transcribe(audio: audio, configuration: configuration)
                
                if isResultValid(result) {
                    logger.info("Fallback transcription successful with \(fallback.method.displayName)")
                    return result
                } else {
                    logger.warning("Low quality result from fallback \(fallback.method.displayName)")
                }
                
            } catch {
                logger.error("Fallback transcription also failed: \(error.localizedDescription)")
                lastError = error
                
                // Notify that all engines failed
                notifyStatusChange(.allEnginesFailed(lastError: error))
            }
        }
        
        // If we get here, both primary and fallback failed
        throw lastError ?? SpeechTranscriptionError.processingFailed("All transcription engines failed")
    }
    
    /// Get current engine status with enhanced information
    public func getEngineStatus() -> EngineStatus {
        let primaryMethod = currentEngine?.method
        let fallbackMethod = fallbackEngine?.method
        let isHealthy = (currentEngine?.isAvailable ?? false) || (fallbackEngine?.isAvailable ?? false)
        
        let statusMessage: String
        if let primary = primaryMethod {
            if currentEngine?.isAvailable == true {
                statusMessage = "Primary engine \(primary.displayName) ready"
            } else if let fallback = fallbackMethod, fallbackEngine?.isAvailable == true {
                statusMessage = "Using fallback engine \(fallback.displayName)"
            } else {
                statusMessage = "No engines available"
            }
        } else {
            statusMessage = "Engines not initialized"
        }
        
        return EngineStatus(
            primary: primaryMethod,
            fallback: fallbackMethod,
            isHealthy: isHealthy,
            lastError: lastError,
            capabilities: deviceCapabilities,
            statusMessage: statusMessage
        )
    }
    
    /// Set status change notification handler
    public func setStatusChangeHandler(_ handler: @escaping (EngineStatusChange) -> Void) {
        statusChangeHandler = handler
    }
    
    /// Notify status change observers
    private func notifyStatusChange(_ change: EngineStatusChange) {
        statusChangeHandler?(change)
    }
    
    /// Cleanup resources
    public func cleanup() async {
        await currentEngine?.cleanup()
        await fallbackEngine?.cleanup()
        currentEngine = nil
        fallbackEngine = nil
    }
    
    // MARK: - Private Methods
    
    private func selectEngine() async throws -> SpeechTranscriptionProtocol {
        switch configuration.strategy {
        case .automatic:
            return try await selectOptimalEngine()
        case .preferApple:
            return try await selectPreferredEngine(preferMLX: false)
        case .preferMLX:
            return try await selectPreferredEngine(preferMLX: true)
        case .appleOnly:
            return try await createAppleEngine()
        case .mlxOnly:
            return try await createMLXEngine()
        }
    }
    
    private func selectOptimalEngine() async throws -> SpeechTranscriptionProtocol {
        // Score different engines based on device capabilities
        var scores: [(engine: () async throws -> SpeechTranscriptionProtocol, score: Int, name: String)] = []
        
        // Apple Speech always available as baseline
        scores.append((createAppleEngine, 50, "Apple Speech"))
        
        // MLX gets higher score on capable devices
        if deviceCapabilities.supportsMLX {
            let mlxScore = calculateMLXScore()
            scores.append((createMLXEngine, mlxScore, "MLX"))
        }
        
        // TODO: Add Apple Foundation models when available
        
        // Sort by score and try engines in order
        scores.sort { $0.score > $1.score }
        
        for (engineFactory, score, name) in scores {
            do {
                let engine = try await engineFactory()
                if engine.isAvailable {
                    logger.info("Selected \(name) with score \(score)")
                    return engine
                }
            } catch {
                logger.warning("Failed to create \(name): \(error.localizedDescription)")
            }
        }
        
        throw SpeechTranscriptionError.modelUnavailable
    }
    
    private func selectPreferredEngine(preferMLX: Bool) async throws -> SpeechTranscriptionProtocol {
        if preferMLX && deviceCapabilities.supportsMLX {
            do {
                let mlxEngine = try await createMLXEngine()
                if mlxEngine.isAvailable {
                    return mlxEngine
                }
            } catch {
                logger.warning("Preferred MLX engine unavailable: \(error.localizedDescription)")
            }
        }
        
        // Fall back to Apple
        return try await createAppleEngine()
    }
    
    private func selectFallbackEngine(primary: SpeechTranscriptionProtocol?) async throws -> SpeechTranscriptionProtocol? {
        guard let primary = primary else { return nil }
        
        // If primary is Apple, try MLX as fallback
        if case .appleSpeech = primary.method, deviceCapabilities.supportsMLX {
            do {
                return try await createMLXEngine()
            } catch {
                logger.info("MLX fallback unavailable: \(error.localizedDescription)")
            }
        }
        
        // If primary is MLX, use Apple as fallback
        if case .mlx = primary.method {
            do {
                return try await createAppleEngine()
            } catch {
                logger.warning("Apple fallback unavailable: \(error.localizedDescription)")
            }
        }
        
        return nil
    }
    
    private func calculateMLXScore() -> Int {
        var score = 60 // Base score for MLX
        
        // Bonus for more memory
        if deviceCapabilities.totalMemory > 8 * 1024 * 1024 * 1024 { // 8GB+
            score += 20
        } else if deviceCapabilities.totalMemory > 4 * 1024 * 1024 * 1024 { // 4GB+
            score += 10
        }
        
        // Bonus for available memory
        if deviceCapabilities.availableMemory > 2 * 1024 * 1024 * 1024 { // 2GB+ available
            score += 10
        }
        
        // Memory constraint penalty
        if let maxMemory = configuration.maxMemoryUsage, 
           deviceCapabilities.availableMemory < maxMemory {
            score -= 30
        }
        
        return score
    }
    
    private func createAppleEngine() async throws -> SpeechTranscriptionProtocol {
        logger.info("Creating Apple Speech transcriber")
        
        // Determine optimal locale
        let locale: Locale
        if let preferredLanguage = configuration.preferredLanguage {
            locale = Locale(identifier: preferredLanguage)
        } else {
            locale = Locale.current
        }
        
        // Create and prepare Apple Speech transcriber
        let transcriber = try AppleSpeechTranscriber(locale: locale)
        try await transcriber.prepare()
        
        logger.info("Apple Speech transcriber created successfully")
        return transcriber
    }
    
    private func createMLXEngine() async throws -> SpeechTranscriptionProtocol {
        logger.info("Creating MLX Speech transcriber")
        
        // Safety check: MLX not supported in iOS Simulator
        #if targetEnvironment(simulator)
        logger.warning("MLX not supported in iOS Simulator environment")
        throw SpeechTranscriptionError.modelUnavailable
        #endif
        
        // Additional device capability check
        guard deviceCapabilities.supportsMLX else {
            logger.warning("MLX not supported on this device")
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        // Determine optimal locale
        let locale: Locale
        if let preferredLanguage = configuration.preferredLanguage {
            locale = Locale(identifier: preferredLanguage)
        } else {
            locale = Locale.current
        }
        
        // Determine optimal model size based on available memory
        let modelSize = selectOptimalMLXModelSize()
        
        // Create and prepare MLX transcriber
        let transcriber = try MLXSpeechTranscriber(locale: locale, modelSize: modelSize)
        try await transcriber.prepare()
        
        logger.info("MLX Speech transcriber created successfully with model: \(modelSize.rawValue)")
        return transcriber
    }
    
    private func selectOptimalMLXModelSize() -> WhisperModelSize {
        let availableMemory = deviceCapabilities.availableMemory
        
        // Select model size based on available memory
        if availableMemory > 6 * 1024 * 1024 * 1024 { // 6GB+
            return .large
        } else if availableMemory > 3 * 1024 * 1024 * 1024 { // 3GB+
            return .medium
        } else if availableMemory > 1 * 1024 * 1024 * 1024 { // 1GB+
            return .small
        } else if availableMemory > 500 * 1024 * 1024 { // 500MB+
            return .base
        } else {
            return .tiny
        }
    }
    
    // MARK: - Fallback Helper Methods
    
    /// Validate transcription result quality
    private func isResultValid(_ result: SpeechTranscriptionResult) -> Bool {
        // Check minimum confidence threshold
        if result.confidence < 0.3 {
            return false
        }
        
        // Check for empty or very short results
        if result.text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            return false
        }
        
        // Check for too many repetitive characters (indicates poor quality)
        let cleanText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueCharacters = Set(cleanText)
        if cleanText.count > 10 && uniqueCharacters.count < 3 {
            return false
        }
        
        return true
    }
    
    /// Determine if error should trigger retry
    private func shouldRetry(error: Error) -> Bool {
        // Don't retry for these types of errors
        if let speechError = error as? SpeechTranscriptionError {
            switch speechError {
            case .permissionDenied, .configurationInvalid, .audioFormatUnsupported:
                return false
            case .modelUnavailable, .processingFailed, .lowQualityResult, .insufficientResources, .networkRequired, .fallbackRequired:
                return true
            }
        }
        
        // For other errors, allow retry
        return true
    }
}

// MARK: - Singleton Access

extension SpeechEngineFactory {
    
    /// Shared instance with default configuration
    public static let shared = SpeechEngineFactory()
    
    /// Configure the shared instance
    public static func configure(with configuration: SpeechEngineConfiguration) {
        // In a real implementation, we'd need to handle reconfiguration
        // For now, this is a placeholder
        fatalError("Reconfiguration not yet implemented - create new instance instead")
    }
}