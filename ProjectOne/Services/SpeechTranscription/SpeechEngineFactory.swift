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
    case preferAppleFoundation
    case preferMLX
    case preferWhisperKit
    case appleOnly
    case appleFoundationOnly
    case mlxOnly
    case whisperKitOnly
    
    public var description: String {
        switch self {
        case .automatic:
            return "Automatic (best available)"
        case .preferApple:
            return "Prefer Apple Speech"
        case .preferAppleFoundation:
            return "Prefer Apple Foundation Models"
        case .preferMLX:
            return "Prefer MLX"
        case .preferWhisperKit:
            return "Prefer WhisperKit"
        case .appleOnly:
            return "Apple Speech only"
        case .appleFoundationOnly:
            return "Apple Foundation Models only"
        case .mlxOnly:
            return "MLX only"
        case .whisperKitOnly:
            return "WhisperKit only"
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
            return try await selectPreferredEngine(preference: .appleSpeech)
        case .preferAppleFoundation:
            return try await selectPreferredEngine(preference: .appleFoundation)
        case .preferMLX:
            return try await selectPreferredEngine(preference: .mlx)
        case .preferWhisperKit:
            return try await selectPreferredEngine(preference: .whisperKit)
        case .appleOnly:
            return try await createAppleEngine()
        case .appleFoundationOnly:
            return try await createAppleFoundationEngine()
        case .mlxOnly:
            return try await createMLXEngine()
        case .whisperKitOnly:
            return try await createWhisperKitEngine()
        }
    }
    
    private func selectOptimalEngine() async throws -> SpeechTranscriptionProtocol {
        // Score different engines based on device capabilities
        var scores: [(engine: () async throws -> SpeechTranscriptionProtocol, score: Int, name: String)] = []
        
        // Apple Speech always available as baseline
        scores.append((createAppleEngine, 50, "Apple Speech"))
        
        // In iOS Simulator, prioritize Apple Speech due to WhisperKit CoreML compatibility issues
        #if targetEnvironment(simulator)
        logger.warning("Running in iOS Simulator - prioritizing Apple Speech due to WhisperKit CoreML issues")
        
        // Still add WhisperKit but with lower score in simulator
        let whisperKitScore = 30 // Lower than Apple Speech to prefer Apple Speech
        scores.append((createWhisperKitEngine, whisperKitScore, "WhisperKit"))
        #else
        // WhisperKit gets higher score for offline capabilities and accuracy on real devices
        let whisperKitScore = calculateWhisperKitScore()
        scores.append((createWhisperKitEngine, whisperKitScore, "WhisperKit"))
        #endif
        
        // MLX gets higher score on capable devices
        if deviceCapabilities.supportsMLX {
            let mlxScore = calculateMLXScore()
            scores.append((createMLXEngine, mlxScore, "MLX"))
        }
        
        // Apple Foundation Models temporarily disabled for compilation
        // let appleFoundationScore = calculateAppleFoundationScore()
        // if appleFoundationScore > 0 {
        //     scores.append((createAppleFoundationEngine, appleFoundationScore, "Apple Foundation Models"))
        // }
        
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
    
    private func selectPreferredEngine(preference: TranscriptionMethod) async throws -> SpeechTranscriptionProtocol {
        // Try preferred engine first
        switch preference {
        case .appleFoundation:
            // Apple Foundation Models temporarily disabled for compilation
            logger.warning("Apple Foundation Models temporarily disabled, falling back to automatic selection")
        case .mlx:
            if deviceCapabilities.supportsMLX {
                do {
                    let mlxEngine = try await createMLXEngine()
                    if mlxEngine.isAvailable {
                        return mlxEngine
                    }
                } catch {
                    logger.warning("Preferred MLX engine unavailable: \(error.localizedDescription)")
                }
            }
        case .whisperKit:
            do {
                let whisperKitEngine = try await createWhisperKitEngine()
                if whisperKitEngine.isAvailable {
                    return whisperKitEngine
                }
            } catch {
                logger.warning("Preferred WhisperKit engine unavailable: \(error.localizedDescription)")
            }
        case .appleSpeech:
            // Apple Speech is the fallback, so we'll handle it below
            break
        default:
            break
        }
        
        // Fall back to Apple Speech as it's always available
        return try await createAppleEngine()
    }
    
    private func selectFallbackEngine(primary: SpeechTranscriptionProtocol?) async throws -> SpeechTranscriptionProtocol? {
        guard let primary = primary else { return nil }
        
        // If primary is Apple Foundation Models, try Apple Speech first, then WhisperKit
        if case .appleFoundation = primary.method {
            // Try Apple Speech first (most reliable fallback)
            do {
                return try await createAppleEngine()
            } catch {
                logger.info("Apple Speech fallback unavailable: \(error.localizedDescription)")
            }
            
            // Try WhisperKit as secondary fallback
            do {
                let whisperKitEngine = try await createWhisperKitEngine()
                if whisperKitEngine.isAvailable {
                    return whisperKitEngine
                }
            } catch {
                logger.info("WhisperKit fallback unavailable: \(error.localizedDescription)")
            }
        }
        
        // If primary is Apple Speech, try Apple Foundation Models first (if available), then WhisperKit, then MLX
        if case .appleSpeech = primary.method {
            // Apple Foundation Models temporarily disabled for compilation
            // if AppleFoundationModelsTranscriber.isSupported() {
            //     do {
            //         let appleFoundationEngine = try await createAppleFoundationEngine()
            //         if appleFoundationEngine.isAvailable {
            //             return appleFoundationEngine
            //         }
            //     } catch {
            //         logger.info("Apple Foundation Models fallback unavailable: \(error.localizedDescription)")
            //     }
            // }
            
            // Try WhisperKit next
            do {
                let whisperKitEngine = try await createWhisperKitEngine()
                if whisperKitEngine.isAvailable {
                    return whisperKitEngine
                }
            } catch {
                logger.info("WhisperKit fallback unavailable: \(error.localizedDescription)")
            }
            
            // Try MLX if WhisperKit failed and device supports it
            if deviceCapabilities.supportsMLX {
                do {
                    return try await createMLXEngine()
                } catch {
                    logger.info("MLX fallback unavailable: \(error.localizedDescription)")
                }
            }
        }
        
        // If primary is WhisperKit, use Apple Foundation Models first (if available), then Apple Speech
        if case .whisperKit = primary.method {
            // Apple Foundation Models temporarily disabled for compilation
            // if AppleFoundationModelsTranscriber.isSupported() {
            //     do {
            //         let appleFoundationEngine = try await createAppleFoundationEngine()
            //         if appleFoundationEngine.isAvailable {
            //             return appleFoundationEngine
            //         }
            //     } catch {
            //         logger.info("Apple Foundation Models fallback unavailable: \(error.localizedDescription)")
            //     }
            // }
            
            // Fall back to Apple Speech
            do {
                return try await createAppleEngine()
            } catch {
                logger.warning("Apple fallback unavailable: \(error.localizedDescription)")
            }
        }
        
        // If primary is MLX, use Apple Foundation Models first (if available), then WhisperKit, then Apple as fallback
        if case .mlx = primary.method {
            // Apple Foundation Models temporarily disabled for compilation
            // if AppleFoundationModelsTranscriber.isSupported() {
            //     do {
            //         let appleFoundationEngine = try await createAppleFoundationEngine()
            //         if appleFoundationEngine.isAvailable {
            //             return appleFoundationEngine
            //         }
            //     } catch {
            //         logger.info("Apple Foundation Models fallback unavailable: \(error.localizedDescription)")
            //     }
            // }
            
            // Try WhisperKit next
            do {
                let whisperKitEngine = try await createWhisperKitEngine()
                if whisperKitEngine.isAvailable {
                    return whisperKitEngine
                }
            } catch {
                logger.info("WhisperKit fallback unavailable: \(error.localizedDescription)")
            }
            
            // Fall back to Apple Speech
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
    
    private func calculateWhisperKitScore() -> Int {
        var score = 70 // Base score for WhisperKit (higher than Apple Speech for better accuracy)
        
        // Bonus for more memory (larger models available)
        if deviceCapabilities.totalMemory > 8 * 1024 * 1024 * 1024 { // 8GB+
            score += 15
        } else if deviceCapabilities.totalMemory > 4 * 1024 * 1024 * 1024 { // 4GB+
            score += 10
        }
        
        // Bonus for available memory
        if deviceCapabilities.availableMemory > 2 * 1024 * 1024 * 1024 { // 2GB+ available
            score += 10
        }
        
        // Offline capability bonus
        score += 5
        
        // Apple Silicon bonus (optimized CoreML models)
        if deviceCapabilities.hasAppleSilicon {
            score += 10
        }
        
        // Memory constraint penalty
        if let maxMemory = configuration.maxMemoryUsage,
           deviceCapabilities.availableMemory < maxMemory {
            score -= 20
        }
        
        return score
    }
    
    private func calculateAppleFoundationScore() -> Int {
        var score = 90 // High base score for Apple Foundation Models (highest quality)
        
        // Apple Foundation Models temporarily disabled for compilation
        return 0 // Temporarily disabled
        
        // Apple Intelligence device bonus
        // if AppleFoundationModelsTranscriber.isSupported() {
        //     score += 20
        // } else {
        //     return 0 // Not supported on this device
        // }
        
        // Bonus for more memory (larger models available)
        if deviceCapabilities.totalMemory > 8 * 1024 * 1024 * 1024 { // 8GB+
            score += 15
        } else if deviceCapabilities.totalMemory > 6 * 1024 * 1024 * 1024 { // 6GB+
            score += 10
        }
        
        // Apple Silicon bonus (optimized for Apple Intelligence)
        if deviceCapabilities.hasAppleSilicon {
            score += 15
        }
        
        // On-device processing bonus (privacy and speed)
        score += 10
        
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
    
    private func createWhisperKitEngine() async throws -> SpeechTranscriptionProtocol {
        logger.info("Creating WhisperKit Speech transcriber")
        
        // Determine optimal locale
        let locale: Locale
        if let preferredLanguage = configuration.preferredLanguage {
            locale = Locale(identifier: preferredLanguage)
        } else {
            locale = Locale.current
        }
        
        // Determine optimal model size based on available memory
        let modelSize = selectOptimalWhisperKitModelSize()
        
        // Create and prepare WhisperKit transcriber
        let transcriber = try WhisperKitTranscriber(locale: locale, modelSize: modelSize)
        try await transcriber.prepare()
        
        logger.info("WhisperKit Speech transcriber created successfully with model: \(modelSize.rawValue)")
        return transcriber
    }
    
    private func createAppleFoundationEngine() async throws -> SpeechTranscriptionProtocol {
        logger.info("Creating Apple Foundation Models transcriber")
        
        // Apple Foundation Models temporarily disabled for compilation
        throw SpeechTranscriptionError.modelUnavailable
        
        // Create and prepare Apple Foundation Models transcriber
        // let transcriber = AppleFoundationModelsTranscriber()
        // try await transcriber.prepare()
        
        // logger.info("Apple Foundation Models transcriber created successfully")
        // return transcriber
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
    
    private func selectOptimalWhisperKitModelSize() -> WhisperKitModelSize {
        // Always use tiny model in iOS Simulator to avoid CoreML compatibility issues
        #if targetEnvironment(simulator)
        logger.info("Using tiny model in iOS Simulator for compatibility")
        return .tiny
        #endif
        
        let availableMemory = deviceCapabilities.availableMemory
        
        // Account for memory constraints if specified
        let effectiveMemory = configuration.maxMemoryUsage.map { min(availableMemory, $0) } ?? availableMemory
        
        // Select WhisperKit model size based on available memory
        // WhisperKit models have different memory requirements than MLX models
        if effectiveMemory > 4 * 1024 * 1024 * 1024 { // 4GB+
            // Large models for high-memory devices
            return deviceCapabilities.hasAppleSilicon ? .largeV3 : .large
        } else if effectiveMemory > 2 * 1024 * 1024 * 1024 { // 2GB+
            return .medium
        } else if effectiveMemory > 1 * 1024 * 1024 * 1024 { // 1GB+
            return .small
        } else if effectiveMemory > 400 * 1024 * 1024 { // 400MB+
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