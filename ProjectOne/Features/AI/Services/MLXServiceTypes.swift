//
//  MLXServiceTypes.swift
//  ProjectOne
//
//  Supporting types for MLX Service layer
//

import Foundation

/// Generation parameters for MLX models
public struct GenerateParameters {
    public let temperature: Float
    public let topP: Float?
    public let topK: Int?
    public let maxTokens: Int?
    public let repetitionPenalty: Float?
    
    public init(
        temperature: Float = 0.7,
        topP: Float? = nil,
        topK: Int? = nil,
        maxTokens: Int? = nil,
        repetitionPenalty: Float? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.maxTokens = maxTokens
        self.repetitionPenalty = repetitionPenalty
    }
}

/// Generation result wrapper
public struct GenerationResult {
    public let output: String
    public let metadata: GenerationMetadata?
    
    public init(output: String, metadata: GenerationMetadata? = nil) {
        self.output = output
        self.metadata = metadata
    }
}

/// Generation metadata
public struct GenerationMetadata {
    public let tokenCount: Int?
    public let processingTime: TimeInterval?
    public let model: String?
    
    public init(tokenCount: Int? = nil, processingTime: TimeInterval? = nil, model: String? = nil) {
        self.tokenCount = tokenCount
        self.processingTime = processingTime
        self.model = model
    }
}

/// Device capabilities information
public struct MLXDeviceCapabilities {
    public let hasAppleSilicon: Bool
    public let hasMetalSupport: Bool
    public let estimatedMemory: Double // GB
    public let platform: Platform
    
    public static var current: MLXDeviceCapabilities {
        return MLXDeviceCapabilities(
            hasAppleSilicon: checkAppleSilicon(),
            hasMetalSupport: checkMetalSupport(),
            estimatedMemory: estimateAvailableMemory(),
            platform: currentPlatform()
        )
    }
    
    private static func checkAppleSilicon() -> Bool {
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
    
    private static func checkMetalSupport() -> Bool {
        // For now, assume Metal is available on Apple Silicon
        return checkAppleSilicon()
    }
    
    private static func estimateAvailableMemory() -> Double {
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = Double(processInfo.physicalMemory) / (1024 * 1024 * 1024) // GB
        
        #if os(iOS)
        // iOS typically has less available memory due to system overhead
        return physicalMemory * 0.6
        #else
        // macOS typically has more available memory
        return physicalMemory * 0.8
        #endif
    }
    
    private static func currentPlatform() -> Platform {
        #if os(iOS)
        return .iOS
        #else
        return .macOS
        #endif
    }
}

/// Model loading state
public enum ModelLoadingState {
    case notLoaded
    case loading(progress: Double)
    case loaded
    case failed(Error)
    
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    public var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
    
    public var loadingProgress: Double {
        if case .loading(let progress) = self {
            return progress
        }
        return 0.0
    }
}

/// Provider capability information
public struct ProviderCapabilities {
    public let supportedTypes: [MLXModelType]
    public let maxMemoryUsage: Double // GB
    public let supportsStreaming: Bool
    public let supportsBatching: Bool
    public let deviceCompatibility: MLXDeviceCapabilities
    
    public init(
        supportedTypes: [MLXModelType],
        maxMemoryUsage: Double,
        supportsStreaming: Bool = true,
        supportsBatching: Bool = false,
        deviceCompatibility: MLXDeviceCapabilities
    ) {
        self.supportedTypes = supportedTypes
        self.maxMemoryUsage = maxMemoryUsage
        self.supportsStreaming = supportsStreaming
        self.supportsBatching = supportsBatching
        self.deviceCompatibility = deviceCompatibility
    }
}