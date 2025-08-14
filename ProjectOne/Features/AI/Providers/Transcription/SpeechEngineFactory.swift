//
//  SpeechEngineFactory.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
import os.log
// TODO: Re-enable SwiftWhisperKitMLX when MLX version conflicts are resolved
// import SwiftWhisperKitMLX

actor CancelToken {
    private var cancelled = false
    func cancel() { cancelled = true }
    func isCancelled() -> Bool { cancelled }
}

// MARK: - Device Capabilities

/// Detects and reports device capabilities for transcription
public struct DeviceCapabilities {
    let totalMemory: UInt64
    let availableMemory: UInt64
    let hasAppleSilicon: Bool
    let supportsMLX: Bool
    let deviceModel: String
    let osVersion: String
    
    static func detect() async -> DeviceCapabilities {
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
        // Use MainActor.run to safely access main actor properties
        let deviceInfo = await MainActor.run {
            (model: UIDevice.current.model, version: UIDevice.current.systemVersion)
        }
        deviceModel = deviceInfo.model
        osVersion = deviceInfo.version
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
public enum EngineSelectionStrategy: Sendable {
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
public struct SpeechEngineConfiguration: Sendable {
    // Core
    let strategy: EngineSelectionStrategy
    let enableFallback: Bool
    let maxMemoryUsage: UInt64?
    let preferredLanguage: String?
    let logLevel: OSLogType
    // Quality & retry tuning
    let tuning: SpeechEngineTuning
    // Circuit breaker / health scoring
    let failureThreshold: Int          // consecutive failures before opening circuit
    let circuitOpenSeconds: TimeInterval
    let healthPenaltyPerFailure: Int   // score penalty per recorded failure
    let reopenPenalty: Int             // flat penalty when circuit just re-opened
    // Feature flags (NEW)
    let enableWhisperKit: Bool
    let enableMLX: Bool
    // Real-time behavior
    let allowMidStreamFallback: Bool
    
    public init(
        strategy: EngineSelectionStrategy = .appleOnly,
        enableFallback: Bool = false,
        maxMemoryUsage: UInt64? = nil,
        preferredLanguage: String? = nil,
        logLevel: OSLogType = .default,
        tuning: SpeechEngineTuning = SpeechEngineTuning(),
        failureThreshold: Int = 3,
        circuitOpenSeconds: TimeInterval = 60,
        healthPenaltyPerFailure: Int = 5,
    reopenPenalty: Int = 15,
    enableWhisperKit: Bool = false,
    enableMLX: Bool = false,
    allowMidStreamFallback: Bool = true
    ) {
        self.strategy = strategy
        self.enableFallback = enableFallback
        self.maxMemoryUsage = maxMemoryUsage
        self.preferredLanguage = preferredLanguage
        self.logLevel = logLevel
        self.tuning = tuning
        self.failureThreshold = max(1, failureThreshold)
        self.circuitOpenSeconds = max(5, circuitOpenSeconds)
        self.healthPenaltyPerFailure = max(0, healthPenaltyPerFailure)
        self.reopenPenalty = max(0, reopenPenalty)
    self.enableWhisperKit = enableWhisperKit
    self.enableMLX = enableMLX
    self.allowMidStreamFallback = allowMidStreamFallback
    }
    
    @MainActor public static let `default` = SpeechEngineConfiguration(strategy: .appleOnly, enableFallback: false)
}

// MARK: - Tuning

/// Fine-grained tuning parameters for transcription quality & retry behavior
public struct SpeechEngineTuning: Sendable, Equatable {
    public let maxRetries: Int                 // primary retries (attempts including first)
    public let backoffBaseMillis: Int          // linear backoff base (attempt * base)
    public let minConfidence: Float            // minimum acceptable confidence
    public let minTextLength: Int              // minimum non-whitespace characters
    public let minUniqueChars: Int             // diversity threshold for longer strings
    public let maxDominantCharRatio: Double    // reject if one char dominates beyond ratio
    
    public init(
        maxRetries: Int = 3,
        backoffBaseMillis: Int = 500,
        minConfidence: Float = 0.30,
        minTextLength: Int = 3,
        minUniqueChars: Int = 3,
        maxDominantCharRatio: Double = 0.85
    ) {
        self.maxRetries = max(0, maxRetries)
        self.backoffBaseMillis = max(50, backoffBaseMillis)
        self.minConfidence = max(0, min(minConfidence, 1))
        self.minTextLength = max(1, minTextLength)
        self.minUniqueChars = max(1, minUniqueChars)
        self.maxDominantCharRatio = max(0.0, min(maxDominantCharRatio, 1.0))
    }
}

// MARK: - Factory

/// Factory for creating and managing speech transcription implementations
@MainActor
public class SpeechEngineFactory {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "SpeechEngineFactory")
    private var configuration: SpeechEngineConfiguration
    private var deviceCapabilities: DeviceCapabilities
    
    private var currentEngine: SpeechTranscriptionProtocol?
    private var fallbackEngine: SpeechTranscriptionProtocol?
    private var lastError: Error?
    
    // Engine health tracking (dynamic scoring / circuit breaker)
    private struct EngineHealth {
        var failures: Int = 0
        var lastFailure: Date?
        var openUntil: Date?            // if in future → circuit open
        var hasRecovered: Bool = true
    }
    private var engineHealth: [TranscriptionMethod: EngineHealth] = [:]
    private var statusChangeHandler: ((EngineStatusChange) -> Void)?
    
    // MARK: - Initialization
    
    public init(configuration: SpeechEngineConfiguration = .default) async {
        self.configuration = configuration
        self.deviceCapabilities = await DeviceCapabilities.detect()
        
        logger.info("SpeechEngineFactory initialized with strategy: \(configuration.strategy.description)")
        logger.info("Device capabilities: Memory: \(self.deviceCapabilities.totalMemory / 1024 / 1024)MB, Apple Silicon: \(self.deviceCapabilities.hasAppleSilicon), MLX Support: \(self.deviceCapabilities.supportsMLX)")
        // Opportunistic background preload of preferred engine(s)
        Task { [weak self] in
            await self?.preloadInitialEngines()
        }
    }
    
    /// Internal designated initializer for sync creation
    private init(__emptySync capabilities: DeviceCapabilities) {
        self.configuration = .default
        self.deviceCapabilities = capabilities
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
        // Capture configuration to avoid data races
        let capturedConfiguration = configuration
        
        logger.info("🎤 [SpeechEngineFactory] === STARTING TRANSCRIPTION REQUEST ===")
        logger.info("🎤 [SpeechEngineFactory] Audio duration: \(audio.duration)s, format: \(audio.format)")
        logger.info("🎤 [SpeechEngineFactory] Configuration: language=\(capturedConfiguration.language ?? "default"), onDevice=\(capturedConfiguration.requiresOnDeviceRecognition)")
        
    var lastError: Error?
    let maxRetries = self.configuration.tuning.maxRetries
    if maxRetries == 0 { logger.info("Retries disabled (maxRetries=0)") }
        
        // Try primary engine with retries
        for attempt in 1...max(1, maxRetries) {
            do {
                logger.info("🎤 [SpeechEngineFactory] === ATTEMPT \(attempt)/\(maxRetries) ===")
                
                logger.info("🎤 [SpeechEngineFactory] Getting transcription engine...")
                let engine = try await getTranscriptionEngine()
                logger.info("🎤 [SpeechEngineFactory] ✅ Got engine: \(engine.method.displayName)")
                logger.info("🎤 [SpeechEngineFactory] Engine available: \(engine.isAvailable)")
                
                logger.info("🎤 [SpeechEngineFactory] Starting transcription with \(engine.method.displayName) (attempt \(attempt)/\(maxRetries))")
                
                do {
                    let result = try await engine.transcribe(audio: audio, configuration: capturedConfiguration)
                    logger.info("🎤 [SpeechEngineFactory] ✅ Transcription completed with \(engine.method.displayName)")
                    
                    // Validate result quality
                    if isResultValid(result) {
                        logger.info("🎤 [SpeechEngineFactory] ✅ Result validation passed")
                        logger.info("🎤 [SpeechEngineFactory] Final result: '\(String(result.text.prefix(50)))...', confidence: \(result.confidence)")
                        
                        // Clear any previous error and notify of recovery if needed
                        if lastError != nil {
                            notifyStatusChange(.engineRecovered(method: engine.method))
                            lastError = nil
                            recordEngineSuccess(engine.method)
                        } else {
                            recordEngineSuccess(engine.method)
                        }
                        
                        return result
                    } else {
                        logger.warning("🎤 [SpeechEngineFactory] ❌ Low quality result from \(engine.method.displayName), retrying...")
                        lastError = SpeechTranscriptionError.lowQualityResult
                        recordEngineFailure(engine.method)
                        continue
                    }
                } catch {
                    logger.error("🎤 [SpeechEngineFactory] ❌ Engine \(engine.method.displayName) transcription failed: \(error)")
                    logger.error("🎤 [SpeechEngineFactory] Error type: \(type(of: error))")
                    if let nsError = error as NSError? {
                        logger.error("🎤 [SpeechEngineFactory] NSError domain: \(nsError.domain), code: \(nsError.code)")
                    }
                    recordEngineFailure(engine.method)
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
                    let delayMs = self.configuration.tuning.backoffBaseMillis * attempt
                    logger.info("Backoff for \(delayMs)ms before next attempt")
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
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
                let result = try await fallback.transcribe(audio: audio, configuration: capturedConfiguration)
                if isResultValid(result) {
                    recordEngineSuccess(fallback.method)
                    logger.info("Fallback transcription successful with \(fallback.method.displayName)")
                    return result
                } else {
                    recordEngineFailure(fallback.method)
                    logger.warning("Low quality result from fallback \(fallback.method.displayName)")
                }
            } catch {
                recordEngineFailure(fallback.method)
                logger.error("Fallback transcription also failed: \(error.localizedDescription)")
                lastError = error
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
        logger.info("🧹 Starting SpeechEngineFactory cleanup")
        
        // Safely cleanup engines
        if let engine = currentEngine {
            await engine.cleanup()
            logger.info("✅ Current engine cleanup completed")
        }
        
        if let fallback = fallbackEngine {
            await fallback.cleanup()
            logger.info("✅ Fallback engine cleanup completed")
        }
        
        // Clear references
        currentEngine = nil
        fallbackEngine = nil
        lastError = nil
        
        logger.info("✅ SpeechEngineFactory cleanup completed")
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
        let candidates = rankCandidateEngines()
        logger.info("Dynamic engine scoring:")
        for c in candidates { logger.info("  • \(c.name) score=\(c.effectiveScore) base=\(c.baseScore) penalty=\(c.baseScore - c.effectiveScore)") }
        for candidate in candidates {
            guard candidate.effectiveScore > 0 else { continue }
            if candidate.skipReason != nil { continue }
            do {
                logger.info("Attempting \(candidate.name)")
                let engine = try await candidate.builder()
                if engine.isAvailable { logger.info("✅ Using \(candidate.name)"); return engine } else { logger.warning("⚠️ \(candidate.name) built but not available"); if let m = candidate.methodHint { recordEngineFailure(m) } }
            } catch {
                logger.warning("❌ Failed creating \(candidate.name): \(error.localizedDescription)")
                if let method = candidate.methodHint { recordEngineFailure(method) }
            }
        }
        throw SpeechTranscriptionError.modelUnavailable
    }

    // Candidate representation for dynamic scoring
    private struct EngineCandidate {
        let name: String
        let methodHint: TranscriptionMethod?
        let baseScore: Int
        let effectiveScore: Int
        let builder: () async throws -> SpeechTranscriptionProtocol
        let skipReason: String?
    }

    private func rankCandidateEngines() -> [EngineCandidate] {
        var list: [EngineCandidate] = []
        // Build base candidates
        if #available(iOS 26.0, macOS 26.0, *) {
            list.append(makeCandidate(name: "SpeechAnalyzer", method: .speechAnalyzer, base: baseScore(for: .speechAnalyzer), builder: { try await self.createSpeechAnalyzerEngine() }))
        } else {
            list.append(makeCandidate(name: "Apple Speech", method: .appleSpeech, base: baseScore(for: .appleSpeech), builder: { try await self.createAppleEngine() }))
        }
        // MLX (on-device Whisper style) engine option
        if configuration.enableMLX && deviceCapabilities.supportsMLX {
            list.append(makeCandidate(name: "MLX Whisper", method: .mlx, base: baseScore(for: .mlx), builder: { try await self.createMLXEngine() }))
        }
        // WhisperKit engine option (guarded by flag)
        if configuration.enableWhisperKit {
            list.append(makeCandidate(name: "WhisperKit", method: .whisperKit, base: baseScore(for: .whisperKit), builder: { try await self.createWhisperKitEngine() }))
        }
        // Strategy filtering (whisperKit disabled currently)
        switch configuration.strategy {
        case .appleOnly:
            list = list.filter { $0.methodHint == .appleSpeech || $0.methodHint == .speechAnalyzer }
        case .whisperKitOnly:
            list = list.filter { $0.methodHint == .whisperKit }
        case .preferApple, .preferWhisperKit, .automatic:
            break
        }
        // Apply health penalties & circuit state
        let now = Date()
        var scored: [EngineCandidate] = []
        for c in list {
            guard let method = c.methodHint else { scored.append(c); continue }
            let health = engineHealth[method]
            var skipReason: String?
            var effective = c.baseScore
            if let h = health {
                if let openUntil = h.openUntil, openUntil > now { skipReason = "circuit open until \(openUntil)"; effective = 0 }
                else {
                    if let openUntil = h.openUntil, openUntil <= now, h.failures >= configuration.failureThreshold { effective -= configuration.reopenPenalty }
                    effective -= (h.failures * configuration.healthPenaltyPerFailure)
                }
            }
            effective = max(0, effective)
            scored.append(EngineCandidate(name: c.name, methodHint: c.methodHint, baseScore: c.baseScore, effectiveScore: effective, builder: c.builder, skipReason: skipReason))
        }
        return scored.sorted { $0.effectiveScore > $1.effectiveScore }
    }

    private func makeCandidate(name: String, method: TranscriptionMethod, base: Int, builder: @escaping () async throws -> SpeechTranscriptionProtocol) -> EngineCandidate {
        EngineCandidate(name: name, methodHint: method, baseScore: base, effectiveScore: base, builder: builder, skipReason: nil)
    }

    private func baseScore(for method: TranscriptionMethod) -> Int {
        var score: Int
        switch method {
        case .speechAnalyzer: score = 100
        case .appleSpeech: score = 80
    case .whisperKit: score = 70 // raise relative when enabled
    case .mlx: score = 65
        case .hybrid: score = 50
        }
        // Device bonuses
        let memGB = Double(deviceCapabilities.totalMemory) / 1024.0 / 1024.0 / 1024.0
        if memGB >= 8 { score += 10 } else if memGB >= 6 { score += 5 }
        if deviceCapabilities.hasAppleSilicon { score += 5 }
        // Strategy bias
        switch configuration.strategy {
        case .preferApple, .appleOnly: if method == .appleSpeech || method == .speechAnalyzer { score += 10 }
    case .preferWhisperKit: if method == .whisperKit { score += 20 }
        case .automatic, .whisperKitOnly: break
        }
        return score
    }

    // MARK: - Health Recording
    private func recordEngineFailure(_ method: TranscriptionMethod) {
        var h = engineHealth[method] ?? EngineHealth()
        h.failures += 1
        h.lastFailure = Date()
        h.hasRecovered = false
        if h.failures >= configuration.failureThreshold { h.openUntil = Date().addingTimeInterval(configuration.circuitOpenSeconds); logger.warning("🚫 Circuit opened for \(method.displayName) until \(h.openUntil!) (failures=\(h.failures))") }
        engineHealth[method] = h
    }
    private func recordEngineSuccess(_ method: TranscriptionMethod) {
        var h = engineHealth[method] ?? EngineHealth()
        if h.failures > 0 { logger.info("✅ Engine \(method.displayName) recovered (previous failures=\(h.failures))") }
        h.failures = 0
        h.openUntil = nil
        h.hasRecovered = true
        engineHealth[method] = h
    }
    public func getHealthDiagnostics() -> [String: Any] {
        var dict: [String: Any] = [:]
        for (method, h) in engineHealth { dict[method.displayName] = ["failures": h.failures, "lastFailure": h.lastFailure?.timeIntervalSince1970 as Any, "openUntil": h.openUntil?.timeIntervalSince1970 as Any, "hasRecovered": h.hasRecovered] }
        return dict
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
        guard primary != nil else { return nil }
        
        // WhisperKit fallback DISABLED due to MLMultiArray buffer overflow crashes
        logger.warning("Fallback engines disabled - using Apple Speech only to prevent crashes")
        
        // No fallback engines to prevent WhisperKit crashes
        // Apple Speech is reliable and should not need fallback
        return nil
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
        let transcriber = AppleSpeechTranscriber()
        try await transcriber.prepare()
        
        logger.info("Apple Speech transcriber created successfully")
        return transcriber
    }
    
    
    // MARK: - Fallback Helper Methods
    
    /// Validate transcription result quality
    private func isResultValid(_ result: SpeechTranscriptionResult) -> Bool {
        let t = configuration.tuning
        guard result.confidence >= t.minConfidence else { return false }
        let trimmed = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= t.minTextLength else { return false }
        if trimmed.count >= t.minTextLength * 2 {
            let uniqueCount = Set(trimmed).count
            if uniqueCount < t.minUniqueChars { return false }
            let freq = trimmed.reduce(into: [:]) { $0[$1, default: 0] += 1 }
            if let maxCount = freq.values.max(), trimmed.count > 5 {
                let ratio = Double(maxCount) / Double(trimmed.count)
                if ratio > t.maxDominantCharRatio { return false }
            }
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
            let transcriber = SpeechAnalyzerTranscriber(locale: locale)
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
                        let fallbackTranscriber = AppleSpeechTranscriber()
                        logger.info("✅ AppleSpeechTranscriber created, preparing...")
                        try await fallbackTranscriber.prepare()
                        logger.info("✅ Fallback to Apple Speech Recognition successful")
                        return fallbackTranscriber
                    } catch {
                        logger.error("❌ Fallback to Apple Speech also failed: \(error.localizedDescription)")
                        // Try one more time with absolute fallback to en-US
                        logger.info("🔄 Last resort: trying absolute fallback to en-US")
                        let absoluteFallback = AppleSpeechTranscriber()
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
                    
                    let fallbackTranscriber = AppleSpeechTranscriber()
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
                        let absoluteFallback = AppleSpeechTranscriber()
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

// MARK: - Async Singleton Access

@MainActor
public enum SpeechEngineFactoryShared {
    private static var cachedTask: Task<SpeechEngineFactory, Never>?
    private static var lastConfig: SpeechEngineConfiguration = .default
    
    public static func instance(configuration: SpeechEngineConfiguration = .default) async -> SpeechEngineFactory {
        if let task = cachedTask {
            let factory = await task.value
            if configChanged(from: lastConfig, to: configuration) {
                await factory.reconfigure(with: configuration)
                lastConfig = configuration
            }
            return factory
        }
        lastConfig = configuration
        let task = Task { @MainActor () -> SpeechEngineFactory in
            return await SpeechEngineFactory(configuration: configuration)
        }
        cachedTask = task
        return await task.value
    }
    
    public static func reconfigure(_ configuration: SpeechEngineConfiguration) async {
        let factory = await instance() // ensure creation
        if configChanged(from: lastConfig, to: configuration) {
            await factory.reconfigure(with: configuration)
            lastConfig = configuration
        }
    }
    
    public static func resetForTests() {
        cachedTask?.cancel()
        cachedTask = nil
    }
    
    private static func configChanged(from old: SpeechEngineConfiguration, to new: SpeechEngineConfiguration) -> Bool {
        return old.strategy != new.strategy ||
        old.enableFallback != new.enableFallback ||
        old.maxMemoryUsage != new.maxMemoryUsage ||
        old.preferredLanguage != new.preferredLanguage ||
        old.logLevel != new.logLevel ||
        old.tuning != new.tuning ||
        old.failureThreshold != new.failureThreshold ||
        old.circuitOpenSeconds != new.circuitOpenSeconds ||
        old.healthPenaltyPerFailure != new.healthPenaltyPerFailure ||
        old.reopenPenalty != new.reopenPenalty
    }
}

// Async reconfiguration
extension SpeechEngineFactory {
    public func reconfigure(with newConfiguration: SpeechEngineConfiguration) async {
        logger.info("Reconfiguring SpeechEngineFactory from \(self.configuration.strategy.description) to \(newConfiguration.strategy.description)")
        await cleanup()
        self.configuration = newConfiguration
        statusChangeHandler?(.primaryEngineChanged(from: self.currentEngine?.method, to: nil))
        logger.info("SpeechEngineFactory reconfiguration completed")
    }
}

// MARK: - Real-Time Unified API

extension SpeechEngineFactory {
    public struct RealTimeTranscriptionHandle: Sendable {
        public let results: AsyncStream<SpeechTranscriptionResult>
        private let cancelToken: CancelToken
        
        internal init(results: AsyncStream<SpeechTranscriptionResult>, cancelToken: CancelToken) {
            self.results = results
            self.cancelToken = cancelToken
        }
        public func cancel() {
            Task {
                await cancelToken.cancel()
            }
        }
    }
    
    /// Start a unified real-time transcription session. Automatically selects best engine and can optionally fall back mid-stream.
    public func startRealTimeTranscription(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) async throws -> RealTimeTranscriptionHandle {
        // Acquire (or build) engine
        let engine = try await getTranscriptionEngine()
        let allowFallback = configuration.requiresOnDeviceRecognition ? false : self.configuration.allowMidStreamFallback
        let tuning = self.configuration.tuning
        let cancelToken = CancelToken()
        
        // Wrap underlying stream with quality monitoring & optional fallback
        let stream = AsyncStream<SpeechTranscriptionResult> { continuation in
            // Start primary engine stream in a Task
            let task = Task { [weak self] in
                guard let self else { continuation.finish(); return }
                var activeEngine: SpeechTranscriptionProtocol = engine
                var primaryFailed = false
                outerLoop: while true {
                    let partialStream = activeEngine.transcribeRealTime(audioStream: audioStream, configuration: configuration)
                    for await partial in partialStream {
                        if await cancelToken.isCancelled() { break outerLoop }
                        continuation.yield(partial)
                        // Lightweight validation for partials: only apply high-level spam / repetition filters on longer partials
                        if partial.text.count > tuning.minTextLength * 4 {
                            if !self.isResultValid(partial) {
                                // Treat as quality degradation; attempt engine switch if allowed
                                if allowFallback, let switched = await self.tryMidStreamFallback(current: activeEngine) {
                                    activeEngine = switched
                                    continue outerLoop
                                }
                            }
                        }
                    }
                    // If stream ended normally, break
                    break outerLoop
                }
                if primaryFailed && allowFallback == false {
                    continuation.finish()
                } else if await cancelToken.isCancelled() {
                    continuation.finish()
                } else {
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                Task {
                    await cancelToken.cancel()
                }
                task.cancel()
            }
        }
        return RealTimeTranscriptionHandle(results: stream, cancelToken: cancelToken)
    }
    
    private func tryMidStreamFallback(current: SpeechTranscriptionProtocol) async -> SpeechTranscriptionProtocol? {
        guard configuration.allowMidStreamFallback else { return nil }
        do {
            if let fb = try await getFallbackEngine() { return fb }
            // If no predefined fallback, attempt next candidate manually
            let ranked = rankCandidateEngines().filter { $0.methodHint != current.method }
            for cand in ranked {
                do {
                    let eng = try await cand.builder()
                    if eng.isAvailable { return eng }
                } catch { continue }
            }
        } catch { return nil }
        return nil
    }
}

// MARK: - Optional Engine Implementations (Placeholders)

extension SpeechEngineFactory {
    /// Placeholder MLX engine creation. Replace with concrete implementation when MLX transcription integrated.
    fileprivate func createMLXEngine() async throws -> SpeechTranscriptionProtocol {
        guard deviceCapabilities.supportsMLX else { throw SpeechTranscriptionError.modelUnavailable }
        let locale = Locale(identifier: configuration.preferredLanguage ?? Locale.current.identifier)
        let adapter = MLXWhisperTranscriberAdapter(locale: locale, loadOptions: WhisperLoadOptions())
        try await adapter.prepare()
        return adapter
    }
    fileprivate func createWhisperKitEngine() async throws -> SpeechTranscriptionProtocol {
        #if targetEnvironment(simulator)
        throw SpeechTranscriptionError.insufficientResources("WhisperKit not supported in simulator")
        #else
        let locale = Locale(identifier: configuration.preferredLanguage ?? Locale.current.identifier)
        let transcriber = try WhisperKitTranscriber(locale: locale, modelSize: .tiny)
        try await transcriber.prepare()
        return transcriber
        #endif
    }
}

// MARK: - Preloading
extension SpeechEngineFactory {
    private func preloadInitialEngines() async {
        // Determine a small set of probable engines to warm
        var attempted: [TranscriptionMethod] = []
        func warm(_ builder: () async throws -> SpeechTranscriptionProtocol, method: TranscriptionMethod) async {
            do {
                let engine = try await builder()
                attempted.append(method)
                logger.info("Preloaded engine: \(engine.method.displayName)")
            } catch {
                logger.debug("Skip preload \(method.displayName): \(error.localizedDescription)")
            }
        }
        switch configuration.strategy {
        case .appleOnly, .preferApple, .automatic:
            if #available(iOS 26.0, macOS 26.0, *) {
                await warm({ try await self.createSpeechAnalyzerEngine() }, method: .speechAnalyzer)
            } else {
                await warm({ try await self.createAppleEngine() }, method: .appleSpeech)
            }
        case .preferWhisperKit, .whisperKitOnly:
            if configuration.enableWhisperKit { await warm({ try await self.createWhisperKitEngine() }, method: .whisperKit) }
        }
        if configuration.enableMLX { await warm({ try await self.createMLXEngine() }, method: .mlx) }
        logger.info("Engine preload attempted: \(attempted.map{ $0.displayName }.joined(separator: ", "))")
    }
}

// MARK: - MLXWhisperTranscriberAdapter Stub
// Note: Real implementation is now in MLXWhisperTranscriberAdapter.swift
