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
    case preferWhisperKit
    case appleOnly
    case whisperKitOnly
    
    public var description: String {
        switch self {
        case .automatic:
            return "Automatic (best available)"
        case .preferApple:
            return "Prefer Apple Speech"
        case .preferWhisperKit:
            return "Prefer WhisperKit"
        case .appleOnly:
            return "Apple Speech only"
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
        strategy: EngineSelectionStrategy = .appleOnly,
        enableFallback: Bool = false,
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
    
    public static let `default` = SpeechEngineConfiguration(strategy: .appleOnly, enableFallback: false)
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
        logger.info("🎤 [SpeechEngineFactory] === STARTING TRANSCRIPTION REQUEST ===")
        logger.info("🎤 [SpeechEngineFactory] Audio duration: \(audio.duration)s, format: \(audio.format)")
        logger.info("🎤 [SpeechEngineFactory] Configuration: language=\(configuration.language ?? "default"), onDevice=\(configuration.requiresOnDeviceRecognition)")
        
        var lastError: Error?
        let maxRetries = 3
        
        // Try primary engine with retries
        for attempt in 1...maxRetries {
            do {
                logger.info("🎤 [SpeechEngineFactory] === ATTEMPT \(attempt)/\(maxRetries) ===")
                
                logger.info("🎤 [SpeechEngineFactory] Getting transcription engine...")
                let engine = try await getTranscriptionEngine()
                logger.info("🎤 [SpeechEngineFactory] ✅ Got engine: \(engine.method.displayName)")
                logger.info("🎤 [SpeechEngineFactory] Engine available: \(engine.isAvailable)")
                
                logger.info("🎤 [SpeechEngineFactory] Starting transcription with \(engine.method.displayName) (attempt \(attempt)/\(maxRetries))")
                
                do {
                    let result = try await engine.transcribe(audio: audio, configuration: configuration)
                    logger.info("🎤 [SpeechEngineFactory] ✅ Transcription completed with \(engine.method.displayName)")
                    
                    // Validate result quality
                    if isResultValid(result) {
                        logger.info("🎤 [SpeechEngineFactory] ✅ Result validation passed")
                        logger.info("🎤 [SpeechEngineFactory] Final result: '\(String(result.text.prefix(50)))...', confidence: \(result.confidence)")
                        
                        // Clear any previous error and notify of recovery if needed
                        if lastError != nil {
                            notifyStatusChange(.engineRecovered(method: engine.method))
                            lastError = nil
                        }
                        
                        return result
                    } else {
                        logger.warning("🎤 [SpeechEngineFactory] ❌ Low quality result from \(engine.method.displayName), retrying...")
                        lastError = SpeechTranscriptionError.lowQualityResult
                        continue
                    }
                } catch {
                    logger.error("🎤 [SpeechEngineFactory] ❌ Engine \(engine.method.displayName) transcription failed: \(error)")
                    logger.error("🎤 [SpeechEngineFactory] Error type: \(type(of: error))")
                    if let nsError = error as NSError? {
                        logger.error("🎤 [SpeechEngineFactory] NSError domain: \(nsError.domain), code: \(nsError.code)")
                    }
                    throw error // Re-throw to be caught by outer catch
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
        case .preferWhisperKit:
            // WhisperKit DISABLED due to crashes - fall back to Apple Speech
            logger.warning("WhisperKit disabled due to crashes, using Apple Speech instead")
            if #available(iOS 26.0, macOS 26.0, *) {
                return try await createSpeechAnalyzerEngine()
            } else {
                return try await createAppleEngine()
            }
        case .appleOnly:
            // Use SpeechAnalyzer on iOS/macOS 26+, Apple Speech on older versions
            if #available(iOS 26.0, macOS 26.0, *) {
                return try await createSpeechAnalyzerEngine()
            } else {
                return try await createAppleEngine()
            }
        case .whisperKitOnly:
            // WhisperKit DISABLED due to crashes - fall back to Apple Speech
            logger.error("WhisperKit disabled due to crashes, cannot use whisperKitOnly strategy")
            if #available(iOS 26.0, macOS 26.0, *) {
                return try await createSpeechAnalyzerEngine()
            } else {
                return try await createAppleEngine()
            }
        }
    }
    
    private func selectOptimalEngine() async throws -> SpeechTranscriptionProtocol {
        // Score different engines based on device capabilities
        var scores: [(engine: () async throws -> SpeechTranscriptionProtocol, score: Int, name: String)] = []
        
        // Apple Speech (SpeechAnalyzer) gets highest priority for iOS 26.0+ and macOS 26.0+
        if #available(iOS 26.0, macOS 26.0, *) {
            scores.append((createSpeechAnalyzerEngine, 100, "Apple SpeechAnalyzer"))
            logger.info("SpeechAnalyzer available on iOS/macOS 26.0+ - only option")
        } else {
            // Fall back to traditional Apple Speech for older versions
            scores.append((createAppleEngine, 90, "Apple Speech"))
            logger.info("Apple Speech - only option for older OS versions")
        }
        
        // WhisperKit DISABLED due to MLMultiArray buffer overflow crashes
        logger.warning("WhisperKit disabled due to MLMultiArray buffer overflow issues - using Apple Speech only")
        
        
        // Sort by score and try engines in order
        scores.sort { $0.score > $1.score }
        
        logger.info("Engine selection order (by score):")
        for (_, score, name) in scores {
            logger.info("  - \(name): \(score)")
        }
        
        for (engineFactory, score, name) in scores {
            do {
                logger.info("Attempting to create \(name) (score: \(score))")
                let engine = try await engineFactory()
                if engine.isAvailable {
                    logger.info("✅ Selected \(name) with score \(score)")
                    return engine
                } else {
                    logger.warning("⚠️ \(name) created but not available")
                }
            } catch {
                logger.warning("❌ Failed to create \(name): \(error.localizedDescription)")
            }
        }
        
        throw SpeechTranscriptionError.modelUnavailable
    }
    
    private func selectPreferredEngine(preference: TranscriptionMethod) async throws -> SpeechTranscriptionProtocol {
        // Try preferred engine first
        switch preference {
        case .speechAnalyzer:
            if #available(iOS 26.0, macOS 26.0, *) {
                do {
                    let speechAnalyzerEngine = try await createSpeechAnalyzerEngine()
                    if speechAnalyzerEngine.isAvailable {
                        return speechAnalyzerEngine
                    }
                } catch {
                    logger.warning("Preferred SpeechAnalyzer engine unavailable: \(error.localizedDescription)")
                }
            } else {
                logger.warning("SpeechAnalyzer requires iOS 26.0+ or macOS 26.0+")
            }
        case .whisperKit:
            // WhisperKit DISABLED due to crashes
            logger.warning("WhisperKit disabled due to crashes, falling back to Apple Speech")
        case .appleSpeech:
            // For prefer Apple strategy, try SpeechAnalyzer first on iOS/macOS 26+, then Apple Speech
            if #available(iOS 26.0, macOS 26.0, *) {
                do {
                    let speechAnalyzerEngine = try await createSpeechAnalyzerEngine()
                    if speechAnalyzerEngine.isAvailable {
                        logger.info("Using SpeechAnalyzer for Apple Speech preference on iOS/macOS 26+")
                        return speechAnalyzerEngine
                    }
                } catch {
                    logger.warning("SpeechAnalyzer unavailable, falling back to Apple Speech: \(error.localizedDescription)")
                }
            }
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
        
        // WhisperKit fallback DISABLED due to MLMultiArray buffer overflow crashes
        logger.warning("Fallback engines disabled - using Apple Speech only to prevent crashes")
        
        // No fallback engines to prevent WhisperKit crashes
        // Apple Speech is reliable and should not need fallback
        return nil
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
    
    /// Create SpeechAnalyzer engine for iOS 26.0+ with automatic fallback
    @available(iOS 26.0, macOS 26.0, *)
    private func createSpeechAnalyzerEngine() async throws -> SpeechTranscriptionProtocol {
        logger.info("🎤 [SpeechEngineFactory] === CREATING SPEECHANALYZER ENGINE ===")
        logger.info("🎤 [SpeechEngineFactory] Attempting to create Apple SpeechAnalyzer transcription engine for iOS/macOS 26+")
        
        // Determine optimal locale
        let locale: Locale
        if let preferredLanguage = configuration.preferredLanguage {
            locale = Locale(identifier: preferredLanguage)
            logger.info("🎤 [SpeechEngineFactory] Using preferred language: \(preferredLanguage)")
        } else {
            locale = Locale.current
            logger.info("🎤 [SpeechEngineFactory] Using current locale: \(locale.identifier)")
        }
        
        do {
            // Try to create SpeechAnalyzer first
            logger.info("🎤 [SpeechEngineFactory] Checking SpeechAnalyzer model availability for locale: \(locale.identifier)")
            
            logger.info("🎤 [SpeechEngineFactory] Creating SpeechAnalyzerTranscriber...")
            let transcriber = try SpeechAnalyzerTranscriber(locale: locale)
            logger.info("🎤 [SpeechEngineFactory] ✅ SpeechAnalyzerTranscriber created, now preparing...")
            
            try await transcriber.prepare()
            logger.info("🎤 [SpeechEngineFactory] ✅ SpeechAnalyzerTranscriber preparation completed")
            
            logger.info("🎤 [SpeechEngineFactory] ✅ SpeechAnalyzer created successfully for iOS/macOS 26+")
            return transcriber
            
        } catch {
            logger.warning("🎤 [SpeechEngineFactory] ❌ SpeechAnalyzer failed to initialize: \(error.localizedDescription)")
            logger.warning("🎤 [SpeechEngineFactory] Error type: \(type(of: error))")
            
            // Check if this is a model availability or locale support error
            let errorMessage = error.localizedDescription
            let isModelError = errorMessage.contains("Model not available") || 
                             errorMessage.contains("OfflineTranscription") ||
                             errorMessage.contains("SFSpeechErrorDomain") ||
                             errorMessage.contains("SpeechTranscriber initialized with unsupported locale") ||
                             errorMessage.contains("unallocated locales") ||
                             errorMessage.contains("Currently allocated locales are []")
            
            // Also check NSError domain and code for SpeechAnalyzer errors
            if let nsError = error as NSError? {
                logger.info("🔍 Error domain: \(nsError.domain), code: \(nsError.code)")
                
                // SFSpeechErrorDomain code 4 is unsupported locale
                if nsError.domain == "SFSpeechErrorDomain" && nsError.code == 4 {
                    logger.info("🔄 SpeechAnalyzer locale unsupported (SFSpeechErrorDomain code 4), falling back to Apple Speech Recognition")
                    
                    // Convert locale back to standard format for Apple Speech (underscores -> hyphens)
                    let standardLocaleIdentifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
                    let standardLocale = Locale(identifier: standardLocaleIdentifier)
                    logger.info("🔄 Converting locale from '\(locale.identifier)' to '\(standardLocale.identifier)' for Apple Speech")
                    
                    // Fall back to traditional Apple Speech with error handling
                    do {
                        logger.info("🔧 Creating AppleSpeechTranscriber for fallback...")
                        let fallbackTranscriber = try AppleSpeechTranscriber(locale: standardLocale)
                        logger.info("✅ AppleSpeechTranscriber created, preparing...")
                        try await fallbackTranscriber.prepare()
                        logger.info("✅ Fallback to Apple Speech Recognition successful")
                        return fallbackTranscriber
                    } catch {
                        logger.error("❌ Fallback to Apple Speech also failed: \(error.localizedDescription)")
                        // Try one more time with absolute fallback to en-US
                        logger.info("🔄 Last resort: trying absolute fallback to en-US")
                        let absoluteFallback = try AppleSpeechTranscriber(locale: Locale(identifier: "en-US"))
                        try await absoluteFallback.prepare()
                        logger.info("✅ Absolute fallback to en-US successful")
                        return absoluteFallback
                    }
                }
            }
            
            if isModelError {
                logger.info("🔄 SpeechAnalyzer model/locale unavailable, falling back to Apple Speech Recognition")
                
                // Convert locale back to standard format for Apple Speech (underscores -> hyphens)
                let standardLocaleIdentifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
                let standardLocale = Locale(identifier: standardLocaleIdentifier)
                logger.info("🔄 Converting locale from '\(locale.identifier)' to '\(standardLocale.identifier)' for Apple Speech")
                
                // Fall back to traditional Apple Speech with error handling
                do {
                    logger.info("🎤 [SpeechEngineFactory] 🔧 === FALLBACK TO APPLE SPEECH ===")
                    logger.info("🎤 [SpeechEngineFactory] Creating AppleSpeechTranscriber for fallback with locale: \(standardLocale.identifier)")
                    
                    let fallbackTranscriber = try AppleSpeechTranscriber(locale: standardLocale)
                    logger.info("🎤 [SpeechEngineFactory] ✅ AppleSpeechTranscriber created, now preparing...")
                    
                    try await fallbackTranscriber.prepare()
                    logger.info("🎤 [SpeechEngineFactory] ✅ AppleSpeechTranscriber preparation completed")
                    logger.info("🎤 [SpeechEngineFactory] ✅ Fallback to Apple Speech Recognition successful")
                    return fallbackTranscriber
                } catch {
                    logger.error("🎤 [SpeechEngineFactory] ❌ Fallback to Apple Speech also failed: \(error.localizedDescription)")
                    logger.error("🎤 [SpeechEngineFactory] Apple Speech fallback error type: \(type(of: error))")
                    // Try one more time with absolute fallback to en-US
                    logger.info("🎤 [SpeechEngineFactory] 🔄 Last resort: trying absolute fallback to en-US")
                    
                    do {
                        let absoluteFallback = try AppleSpeechTranscriber(locale: Locale(identifier: "en-US"))
                        logger.info("🎤 [SpeechEngineFactory] ✅ Absolute fallback transcriber created, preparing...")
                        try await absoluteFallback.prepare()
                        logger.info("🎤 [SpeechEngineFactory] ✅ Absolute fallback to en-US successful")
                        return absoluteFallback
                    } catch {
                        logger.error("🎤 [SpeechEngineFactory] ❌ Even absolute fallback failed: \(error.localizedDescription)")
                        throw error
                    }
                }
                
            } else {
                // For other errors, rethrow
                logger.error("💥 SpeechAnalyzer failed with non-model error, rethrowing")
                throw error
            }
        }
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