//
//  MLXModelRegistry.swift
//  ProjectOne
//
//  Model registry for MLX configurations and metadata
//

import Foundation

/// MLX model configuration with metadata
public struct MLXModelConfiguration {
    public let name: String
    public let modelId: String
    public let type: MLXModelType
    public let memoryRequirement: String
    public let recommendedPlatform: Platform
    public let quantization: String
    public let description: String
    
    public init(
        name: String,
        modelId: String,
        type: MLXModelType,
        memoryRequirement: String,
        recommendedPlatform: Platform,
        quantization: String,
        description: String
    ) {
        self.name = name
        self.modelId = modelId
        self.type = type
        self.memoryRequirement = memoryRequirement
        self.recommendedPlatform = recommendedPlatform
        self.quantization = quantization
        self.description = description
    }
}

/// Platform targeting
public enum Platform: String, CaseIterable {
    case iOS = "ios"
    case macOS = "macos"
    case both = "both"
    
    public var displayName: String {
        switch self {
        case .iOS: return "iOS/Mobile"
        case .macOS: return "macOS/Desktop"
        case .both: return "Cross-platform"
        }
    }
}

/// MLX Model Registry with predefined configurations
public struct MLXModelRegistry {
    
    // MARK: - LLM Models
    
    public static let llmModels: [MLXModelConfiguration] = [
        // Optimal Gemma-3n variants
        MLXModelConfiguration(
            name: "Gemma-3n E2B 4-bit",
            modelId: "mlx-community/gemma-3n-E2B-it-4bit",
            type: .llm,
            memoryRequirement: "~1.7GB RAM",
            recommendedPlatform: .iOS,
            quantization: "4-bit",
            description: "iOS optimized Gemma-3n variant with 4-bit quantization"
        ),
        MLXModelConfiguration(
            name: "Gemma-3n E2B 5-bit",
            modelId: "mlx-community/gemma-3n-E2B-it-5bit",
            type: .llm,
            memoryRequirement: "~2.1GB RAM",
            recommendedPlatform: .iOS,
            quantization: "5-bit",
            description: "Balanced mobile Gemma-3n with 5-bit quantization"
        ),
        MLXModelConfiguration(
            name: "Gemma-3n E4B 5-bit",
            modelId: "mlx-community/gemma-3n-E4B-it-5bit",
            type: .llm,
            memoryRequirement: "~3-4GB RAM",
            recommendedPlatform: .macOS,
            quantization: "5-bit",
            description: "Mac optimized Gemma-3n with balanced performance"
        ),
        MLXModelConfiguration(
            name: "Gemma-3n E4B 8-bit",
            modelId: "mlx-community/gemma-3n-E4B-it-8bit",
            type: .llm,
            memoryRequirement: "~8GB RAM",
            recommendedPlatform: .macOS,
            quantization: "8-bit",
            description: "High quality Mac Gemma-3n for best performance"
        ),
        
        // Legacy models for compatibility
        MLXModelConfiguration(
            name: "Qwen3 4B",
            modelId: "mlx-community/Qwen3-4B-4bit",
            type: .llm,
            memoryRequirement: "~3GB RAM",
            recommendedPlatform: .both,
            quantization: "4-bit",
            description: "Cross-platform Qwen3 4B model"
        ),
        MLXModelConfiguration(
            name: "Gemma 2 2B",
            modelId: "mlx-community/Gemma-2-2b-it-4bit",
            type: .llm,
            memoryRequirement: "~3GB RAM",
            recommendedPlatform: .both,
            quantization: "4-bit",
            description: "Compact Gemma 2 model for general use"
        ),
        MLXModelConfiguration(
            name: "Llama 3.1 8B",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
            type: .llm,
            memoryRequirement: "~6-8GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "Large Llama 3.1 model for high-quality responses"
        )
    ]
    
    // MARK: - VLM Models
    
    public static let vlmModels: [MLXModelConfiguration] = [
        // Vision-Language Models
        MLXModelConfiguration(
            name: "Gemma-3n VLM",
            modelId: "mlx-community/gemma-3n-vlm-4bit",
            type: .vlm,
            memoryRequirement: "~4-6GB RAM",
            recommendedPlatform: .both,
            quantization: "4-bit",
            description: "Multimodal Gemma-3n for text and image understanding"
        ),
        MLXModelConfiguration(
            name: "Qwen2-VL",
            modelId: "mlx-community/Qwen2-VL-7B-Instruct-4bit",
            type: .vlm,
            memoryRequirement: "~6-8GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "Advanced vision-language model for complex multimodal tasks"
        ),
        MLXModelConfiguration(
            name: "LLaVA Next",
            modelId: "mlx-community/llava-next-7b-4bit",
            type: .vlm,
            memoryRequirement: "~5-7GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "LLaVA Next for vision-language understanding"
        )
    ]
    
    // MARK: - Convenience Methods
    
    /// Get all available models
    public static var allModels: [MLXModelConfiguration] {
        return llmModels + vlmModels
    }
    
    /// Get models by type
    public static func models(for type: MLXModelType) -> [MLXModelConfiguration] {
        switch type {
        case .llm:
            return llmModels
        case .vlm:
            return vlmModels
        }
    }
    
    /// Get models by platform
    public static func models(for platform: Platform) -> [MLXModelConfiguration] {
        return allModels.filter { model in
            model.recommendedPlatform == platform || model.recommendedPlatform == .both
        }
    }
    
    /// Get recommended model for current platform and type
    public static func getRecommendedModel(for type: MLXModelType) -> MLXModelConfiguration? {
        #if os(iOS)
        let platformModels = models(for: Platform.iOS).filter { $0.type == type }
        // Prefer balanced performance for iOS
        return platformModels.first { $0.quantization == "4-bit" } ?? platformModels.first
        #else
        let platformModels = models(for: Platform.macOS).filter { $0.type == type }
        // Prefer quality for macOS
        return platformModels.first { $0.quantization == "5-bit" } ?? platformModels.first
        #endif
    }
    
    /// Get high-performance model for current platform and type
    public static func getHighPerformanceModel(for type: MLXModelType) -> MLXModelConfiguration? {
        #if os(iOS)
        let platformModels = models(for: Platform.iOS).filter { $0.type == type }
        // Best quality available for iOS
        return platformModels.first { $0.quantization == "5-bit" } ?? platformModels.first
        #else
        let platformModels = models(for: Platform.macOS).filter { $0.type == type }
        // Highest quality for macOS
        return platformModels.first { $0.quantization == "8-bit" } ?? platformModels.first
        #endif
    }
    
    /// Get memory-efficient model for current platform and type
    public static func getMemoryEfficientModel(for type: MLXModelType) -> MLXModelConfiguration? {
        let platformModels = models(for: getCurrentPlatform()).filter { $0.type == type }
        // Lowest memory requirement
        return platformModels.min { 
            parseMemoryRequirement($0.memoryRequirement) < parseMemoryRequirement($1.memoryRequirement)
        }
    }
    
    /// Find model by ID
    public static func model(withId modelId: String) -> MLXModelConfiguration? {
        return allModels.first { $0.modelId == modelId }
    }
    
    // MARK: - Helper Methods
    
    private static func getCurrentPlatform() -> Platform {
        #if os(iOS)
        return .iOS
        #else
        return .macOS
        #endif
    }
    
    private static func parseMemoryRequirement(_ requirement: String) -> Double {
        // Parse "~1.7GB RAM" format to double
        let components = requirement.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let numbers = components.compactMap { Double($0) }
        return numbers.first ?? 0.0
    }
}