# MLX Swift Real API Implementation Guide

## Overview

This guide documents the correct implementation of MLX Swift models based on the actual MLX Swift Examples repository. The real API uses a factory pattern with registries for both LLM and VLM models.

## Actual MLX Swift Architecture

### Required Imports (Based on MLXService.swift)
```swift
import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM
```

### Model Registry System
- **LLM Models**: Use `LLMRegistry` (e.g., `LLMRegistry.qwen3_1_7b_4bit`)
- **VLM Models**: Use `VLMRegistry` (e.g., `VLMRegistry.qwen2_5VL3BInstruct4Bit`)
- **Model Definition**: Wrapped in `LMModel` struct with name, configuration, and type

### Core Types
- **Model Container**: `ModelContainer` (main container type)
- **Model Context**: `ModelContext` (used within perform blocks)
- **Model Factory**: `LLMModelFactory.shared` or `VLMModelFactory.shared`
- **Generation**: `MLXLMCommon.generate()` for actual text generation

## Gemma-3n VLM Architecture

### Model Capabilities
- **Text Generation**: Standard language model capabilities
- **Vision Understanding**: Image analysis and description
- **Multimodal Reasoning**: Text + image combined processing
- **Cross-Modal Integration**: Understanding relationships between text and visual content

### Supported Model Variants
```swift
// Gemma-3n VLM Models (use with MLXVLM)
let models = [
    "mlx-community/gemma-3n-E2B-it-4bit",    // 2B effective, mobile-optimized
    "mlx-community/gemma-3n-E4B-it-4bit",    // 4B effective, desktop-optimized
    "mlx-community/gemma-3n-E2B-it-5bit",    // Higher quality mobile
    "mlx-community/gemma-3n-E4B-it-8bit"     // High quality desktop
]
```

## Real MLX Swift Implementation Patterns

### 1. Import Statements (Based on MLXService.swift)
```swift
import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXVLM
import os.log
```

### 2. Model Properties (Factory Pattern)
```swift
public class MLXGemma3nVLMProvider: BaseAIProvider {
    
    private var modelContainer: ModelContainer?
    private let modelCache = NSCache<NSString, ModelContainer>()
    
    // Model definition using registry system
    private let model = LMModel(
        name: "Gemma-3n E2B 4-bit",
        configuration: VLMRegistry.gemma3n_E2B_4bit, // Hypothetical registry entry
        type: .vlm
    )
}
```

### 3. Model Loading (Factory Pattern)
```swift
public override func prepareModel() async throws {
    guard isMLXSupported else {
        throw AIModelProviderError.providerUnavailable("MLX requires real Apple Silicon hardware")
    }
    
    // Check cache first
    let cacheKey = NSString(string: model.name)
    if let cachedContainer = modelCache.object(forKey: cacheKey) {
        self.modelContainer = cachedContainer
        return
    }
    
    do {
        await MainActor.run {
            modelLoadingStatus = .downloading(progress: 0.0)
            statusMessage = "Loading VLM model..."
        }
        
        // Use VLM factory for vision language models
        let factory = VLMModelFactory.shared
        
        let container = try await factory.loadContainer(
            hub: .default,
            configuration: model.configuration
        ) { progress in
            Task { @MainActor in
                self.loadingProgress = progress.fractionCompleted
            }
        }
        
        // Cache the loaded container
        modelCache.setObject(container, forKey: cacheKey)
        self.modelContainer = container
        
        await MainActor.run {
            modelLoadingStatus = .ready
            statusMessage = "MLX VLM model ready"
            isModelLoaded = true
        }
        
        logger.info("MLX VLM model loaded successfully")
        
    } catch {
        logger.error("Failed to load MLX VLM model: \(error.localizedDescription)")
        throw AIModelProviderError.modelNotLoaded
    }
}
```

### 4. Text-Only Generation (Real API Pattern)
```swift
public override func generateModelResponse(_ prompt: String) async throws -> String {
    guard let container = modelContainer else {
        throw AIModelProviderError.modelNotLoaded
    }
    
    // Convert to Chat.Message format
    let messages = [
        Chat.Message(role: .user, content: prompt)
    ]
    
    // Create UserInput
    let userInput = UserInput(
        chat: messages,
        processing: .init(resize: .init(width: 1024, height: 1024))
    )
    
    // Use the real MLX generation pattern
    return try await container.perform { (context: ModelContext) in
        let lmInput = try await context.processor.prepare(input: userInput)
        let parameters = GenerateParameters(temperature: 0.7)
        let result = try MLXLMCommon.generate(
            input: lmInput,
            parameters: parameters,
            context: context
        )
        return result.output
    }
}
```

### 5. Multimodal Generation (Real API Pattern)
```swift
/// Generate multimodal response with text and image input
public func generateMultimodalResponse(_ prompt: String, images: [UIImage]) async throws -> String {
    guard let container = modelContainer else {
        throw AIModelProviderError.modelNotLoaded
    }
    
    // Convert images to UserInput.Image format
    let userImages = images.compactMap { image -> UserInput.Image? in
        // Save image temporarily and create URL
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              let tempURL = saveToTempFile(data: imageData, extension: "jpg") else {
            return nil
        }
        return UserInput.Image.url(tempURL)
    }
    
    // Convert to Chat.Message format
    let messages = [
        Chat.Message(role: .user, content: prompt)
    ]
    
    // Create UserInput with images
    let userInput = UserInput(
        chat: messages,
        images: userImages,
        processing: .init(resize: .init(width: 1024, height: 1024))
    )
    
    // Use the real MLX VLM generation pattern
    return try await container.perform { (context: ModelContext) in
        let lmInput = try await context.processor.prepare(input: userInput)
        let parameters = GenerateParameters(temperature: 0.7)
        let result = try MLXLMCommon.generate(
            input: lmInput,
            parameters: parameters,
            context: context
        )
        return result.output
    }
}

private func saveToTempFile(data: Data, extension ext: String) -> URL? {
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = UUID().uuidString + "." + ext
    let fileURL = tempDir.appendingPathComponent(fileName)
    
    do {
        try data.write(to: fileURL)
        return fileURL
    } catch {
        logger.error("Failed to save temp file: \(error)")
        return nil
    }
}
```

## VLM Input Processing

### Image Input Types
```swift
// Supported image input formats
enum ImageInput {
    case ciImage(CIImage)           // Core Image
    case url(URL)                   // File URL
    case data(Data)                 // Raw image data
    case cgImage(CGImage)           // Core Graphics
}
```

### Image Preprocessing
```swift
// Example: Resize and normalize image for VLM
func preprocessImage(_ image: UIImage, targetSize: CGSize = CGSize(width: 448, height: 448)) -> CIImage? {
    guard let ciImage = CIImage(image: image) else { return nil }
    
    // Resize to model's expected input size
    let scaleX = targetSize.width / ciImage.extent.width
    let scaleY = targetSize.height / ciImage.extent.height
    let scale = min(scaleX, scaleY)
    
    return ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
}
```

### Advanced VLM Usage
```swift
// Multiple images with processing parameters
func generateWithMultipleImages(_ prompt: String, images: [UIImage]) async throws -> String {
    guard let session = vlmSession else {
        throw AIModelProviderError.modelNotLoaded
    }
    
    var input = UserInput(
        prompt: prompt,
        images: images.compactMap { image in
            guard let ciImage = CIImage(image: image) else { return nil }
            return .ciImage(ciImage)
        }
    )
    
    // Configure image processing
    input.processing.resize = .init(width: 448, height: 448)
    input.processing.normalize = true
    
    return try await session.respond(with: input)
}
```

## Error Handling and Debugging

### Common VLM Errors
```swift
enum VLMError: Error, LocalizedError {
    case modelNotVLMCompatible(String)
    case imageProcessingFailed(String)
    case multimodalInputInvalid(String)
    case visionEncodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotVLMCompatible(let model):
            return "Model \(model) is not VLM-compatible. Use MLXVLM framework."
        case .imageProcessingFailed(let reason):
            return "Image processing failed: \(reason)"
        case .multimodalInputInvalid(let reason):
            return "Invalid multimodal input: \(reason)"
        case .visionEncodingFailed(let reason):
            return "Vision encoding failed: \(reason)"
        }
    }
}
```

### Debug Logging
```swift
// Enhanced debugging for VLM operations
logger.info("Loading VLM model: \(modelId)")
logger.info("Image input size: \(image.size)")
logger.info("Prompt length: \(prompt.count) characters")
logger.info("VLM session ready: \(vlmSession != nil)")
```

## Performance Considerations

### Memory Usage
- **Text-only inference**: ~1.5-3GB for E2B, ~3-6GB for E4B
- **Image processing**: Additional ~200-500MB per image
- **Peak usage**: Model + image encoding + generation buffers

### Optimization Strategies
```swift
// Memory-efficient image processing
func processImageEfficiently(_ image: UIImage) -> CIImage? {
    // Resize before conversion to reduce memory footprint
    let maxDimension: CGFloat = 512
    let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
    
    if scale < 1.0 {
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage.flatMap { CIImage(image: $0) }
    }
    
    return CIImage(image: image)
}
```

## Testing VLM Implementation

### Unit Tests
```swift
func testVLMModelLoading() async throws {
    let provider = MLXGemma3nVLMProvider()
    
    // Test model loading
    try await provider.prepareModel()
    XCTAssertTrue(provider.isAvailable)
    
    // Test text generation
    let textResponse = try await provider.generateModelResponse("Hello, how are you?")
    XCTAssertFalse(textResponse.isEmpty)
    
    // Test multimodal generation
    let testImage = createTestImage() // Create a simple test image
    let multimodalResponse = try await provider.generateMultimodalResponse(
        "What do you see in this image?", 
        image: testImage
    )
    XCTAssertFalse(multimodalResponse.isEmpty)
}
```

### Integration Tests
```swift
func testVLMProviderInUnifiedSystem() async throws {
    let testView = UnifiedAITestView()
    
    // Test VLM provider availability
    let vlmProvider = testView.mlxGemma3nProvider
    XCTAssertTrue(vlmProvider.isMLXSupported)
    
    // Test multimodal capabilities
    try await vlmProvider.prepareModel()
    let response = try await vlmProvider.generateModelResponse("Describe a sunny day")
    XCTAssertFalse(response.isEmpty)
}
```

## Migration from MLXLMCommon

### Before (Incorrect - Text-Only)
```swift
// ❌ WRONG: Using MLXLMCommon for VLM
#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

private var modelContext: ModelContext?
private var chatSession: ChatSession?

// Loading with wrong API
let loadedModel = try await MLXLMCommon.loadModel(id: modelId)
let session = ChatSession(loadedModel)
```

### After (Correct - VLM)
```swift
// ✅ CORRECT: Using MLXVLM for VLM
#if canImport(MLXVLM)
import MLXVLM
import MLXLMCommon  // For utilities
import CoreImage    // For image processing
#endif

private var vlmModel: VLMModel?
private var vlmSession: ChatSession?

// Loading with correct VLM API
let loadedVLMModel = try await MLXVLM.loadModel(id: modelId)
let session = ChatSession(loadedVLMModel)  // VLM-capable session
```

## Key Differences Summary

| Aspect | MLXLMCommon (Text-only) | MLXVLM (Multimodal) |
|--------|-------------------------|----------------------|
| **Import** | `import MLXLMCommon` | `import MLXVLM` |
| **Model Loading** | `MLXLMCommon.loadModel()` | `MLXVLM.loadModel()` |
| **Model Type** | `ModelContext` | `VLMModel` |
| **Session Type** | `ChatSession(ModelContext)` | `ChatSession(VLMModel)` |
| **Text Input** | `session.respond(to: String)` | `session.respond(to: String)` |
| **Image Input** | ❌ Not supported | `session.respond(to: String, image: ImageInput)` |
| **Memory Usage** | Lower (text tokens only) | Higher (text + vision embeddings) |
| **Use Cases** | Pure text generation | Text + image understanding |
| **Models** | Llama, Gemma-2, Qwen | Gemma-3n, Qwen2-VL, LLaVA |

## Production Checklist

- [ ] Verify `MLXVLM` framework is available in project
- [ ] Update imports from `MLXLMCommon` to `MLXVLM`
- [ ] Change model properties from `ModelContext` to `VLMModel`
- [ ] Update model loading from `MLXLMCommon.loadModel()` to `MLXVLM.loadModel()`
- [ ] Add `CoreImage` import for image processing
- [ ] Implement multimodal response methods
- [ ] Test on real Apple Silicon hardware (not simulator)
- [ ] Verify memory usage with image inputs
- [ ] Test graceful fallback when MLXVLM unavailable

---

*This guide reflects the correct implementation of Gemma-3n as a Vision Language Model using MLXVLM APIs as of July 19, 2025*