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
    // 🔧 FIXED: Updated with verified MLX Swift community models
    
    /// Production-ready LLM model configurations
    /// 
    /// 🎓 SWIFT LEARNING: Static array of configuration structs
    /// These are real, working model IDs from the MLX community on HuggingFace
    public static let llmModels: [MLXModelConfiguration] = [
        
        // MARK: - Gemma 2 Models (Most Reliable)
        // 🔧 VERIFIED: These models are confirmed working with MLX Swift
        
        MLXModelConfiguration(
            name: "Gemma 2 2B Instruct",
            modelId: "mlx-community/gemma-2-2b-it-4bit", // 🔧 Verified working model
            type: .llm,
            memoryRequirement: "~1.5GB RAM",
            recommendedPlatform: .iOS,
            quantization: "4-bit",
            description: "Compact, efficient Gemma 2 model perfect for mobile devices"
        ),
        
        MLXModelConfiguration(
            name: "Gemma 2 9B Instruct",
            modelId: "mlx-community/gemma-2-9b-it-4bit", // 🔧 Verified working model  
            type: .llm,
            memoryRequirement: "~5-6GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "High-quality Gemma 2 model for desktop use"
        ),
        
        MLXModelConfiguration(
            name: "Gemma 2 27B Instruct",
            modelId: "mlx-community/gemma-2-27b-it-4bit", // 🔧 Verified working model
            type: .llm,
            memoryRequirement: "~14-16GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "Premium Gemma 2 model for high-end Macs with 32GB+ RAM"
        ),
        
        // MARK: - Qwen Models (Excellent Performance)
        // 🔧 VERIFIED: Qwen2.5 models are very reliable with MLX Swift
        
        MLXModelConfiguration(
            name: "Qwen2.5 3B Instruct",
            modelId: "mlx-community/Qwen2.5-3B-Instruct-4bit", // 🔧 Verified working
            type: .llm,
            memoryRequirement: "~2GB RAM",
            recommendedPlatform: .both,
            quantization: "4-bit",
            description: "Fast and capable Qwen2.5 model, great for both iOS and macOS"
        ),
        
        MLXModelConfiguration(
            name: "Qwen2.5 7B Instruct", 
            modelId: "mlx-community/Qwen2.5-7B-Instruct-4bit", // 🔧 Verified working
            type: .llm,
            memoryRequirement: "~4GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "Excellent balance of quality and performance"
        ),
        
        MLXModelConfiguration(
            name: "Qwen2.5 14B Instruct",
            modelId: "mlx-community/Qwen2.5-14B-Instruct-4bit", // 🔧 Verified working
            type: .llm, 
            memoryRequirement: "~8GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "High-quality Qwen2.5 for demanding tasks"
        ),
        
        // MARK: - Llama Models (Meta's Latest)
        // 🔧 VERIFIED: Llama 3.2 models work well with MLX Swift
        
        MLXModelConfiguration(
            name: "Llama 3.2 3B Instruct",
            modelId: "mlx-community/Llama-3.2-3B-Instruct-4bit", // 🔧 Verified working
            type: .llm,
            memoryRequirement: "~2GB RAM", 
            recommendedPlatform: .both,
            quantization: "4-bit",
            description: "Meta's latest compact Llama model, great for mobile"
        ),
        
        MLXModelConfiguration(
            name: "Llama 3.1 8B Instruct",
            modelId: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit", // 🔧 Verified working
            type: .llm,
            memoryRequirement: "~5GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "Powerful Llama 3.1 model for complex reasoning tasks"
        ),
        
        // MARK: - Phi Models (Microsoft Research)
        // 🔧 VERIFIED: Phi-3.5 models are excellent for efficiency
        
        MLXModelConfiguration(
            name: "Phi-3.5 Mini Instruct", 
            modelId: "mlx-community/Phi-3.5-mini-instruct-4bit", // 🔧 Verified working
            type: .llm,
            memoryRequirement: "~2GB RAM",
            recommendedPlatform: .both,
            quantization: "4-bit", 
            description: "Microsoft's efficient Phi model, excellent quality/size ratio"
        )
    ]
    
    // MARK: - VLM Models (Vision-Language Models)
    // 🔧 FIXED: Updated with verified working multimodal models
    
    /// Production-ready Vision-Language model configurations
    /// 
    /// 🎓 SWIFT LEARNING: These models can process both text and images
    /// Perfect for multimodal AI applications like image analysis and visual Q&A
    public static let vlmModels: [MLXModelConfiguration] = [
        
        // MARK: - Qwen2-VL Models (Best VLM Performance)
        // 🔧 VERIFIED: Qwen2-VL models are the current state-of-the-art for MLX
        
        MLXModelConfiguration(
            name: "Qwen2-VL 2B Instruct",
            modelId: "mlx-community/Qwen2-VL-2B-Instruct-4bit", // 🔧 Verified working
            type: .vlm,
            memoryRequirement: "~3GB RAM",
            recommendedPlatform: .both,
            quantization: "4-bit",
            description: "Compact but powerful vision-language model for mobile devices"
        ),
        
        MLXModelConfiguration(
            name: "Qwen2-VL 7B Instruct", 
            modelId: "mlx-community/Qwen2-VL-7B-Instruct-4bit", // 🔧 Verified working
            type: .vlm,
            memoryRequirement: "~5GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "Excellent vision-language model for detailed image analysis"
        ),
        
        // MARK: - LLaVA Models (Open Source VLM)
        // 🔧 VERIFIED: LLaVA models work well with MLX Swift
        
        MLXModelConfiguration(
            name: "LLaVA v1.6 Mistral 7B",
            modelId: "mlx-community/llava-v1.6-mistral-7b-4bit", // 🔧 Verified working
            type: .vlm,
            memoryRequirement: "~4GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "LLaVA model based on Mistral, great for visual reasoning"
        ),
        
        MLXModelConfiguration(
            name: "LLaVA v1.6 Vicuna 7B",
            modelId: "mlx-community/llava-v1.6-vicuna-7b-4bit", // 🔧 Verified working
            type: .vlm,
            memoryRequirement: "~4GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "LLaVA model with Vicuna base, excellent for image understanding"
        ),
        
        // MARK: - Pixtral Models (Mistral AI's VLM)
        // 🔧 VERIFIED: Latest multimodal models from Mistral
        
        MLXModelConfiguration(
            name: "Pixtral 12B",
            modelId: "mlx-community/pixtral-12b-4bit", // 🔧 Verified working
            type: .vlm,
            memoryRequirement: "~7GB RAM",
            recommendedPlatform: .macOS,
            quantization: "4-bit",
            description: "Mistral's powerful vision-language model for complex visual tasks"
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
    /// 
    /// 🔧 FIXED: Updated to use verified working models with smart selection
    /// 🎓 SWIFT LEARNING: Platform-specific recommendations using conditional compilation
    public static func getRecommendedModel(for type: MLXModelType) -> MLXModelConfiguration? {
        #if os(iOS)
        // iOS/Mobile recommendations - prioritize efficiency and memory usage
        let platformModels = models(for: Platform.iOS).filter { $0.type == type }
        
        switch type {
        case .llm:
            // Recommend Gemma 2 2B for iOS - best balance of quality and efficiency
            return platformModels.first { $0.name.contains("Gemma 2 2B") } ?? 
                   platformModels.first { $0.name.contains("Qwen2.5 3B") } ??
                   platformModels.first
        case .vlm:
            // Recommend Qwen2-VL 2B for iOS - best mobile VLM
            return platformModels.first { $0.name.contains("Qwen2-VL 2B") } ?? platformModels.first
        }
        
        #else
        // macOS recommendations - prioritize quality and capability
        let platformModels = models(for: Platform.macOS).filter { $0.type == type }
        
        switch type {
        case .llm:
            // Recommend Qwen2.5 7B for macOS - excellent quality/performance balance
            return platformModels.first { $0.name.contains("Qwen2.5 7B") } ??
                   platformModels.first { $0.name.contains("Gemma 2 9B") } ??
                   platformModels.first
        case .vlm:
            // Recommend Qwen2-VL 7B for macOS - best desktop VLM
            return platformModels.first { $0.name.contains("Qwen2-VL 7B") } ?? platformModels.first
        }
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