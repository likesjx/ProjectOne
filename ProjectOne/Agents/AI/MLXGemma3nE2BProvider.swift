
import Foundation
import os.log
import Combine

#if canImport(MLXLLM) && canImport(MLXVLM) && ENABLE_LEGACY_PROVIDER
import MLXLLM
import MLXVLM
import MLXLMCommon
import MLX
import Hub
import Foundation

/// Custom ModelContainer that can handle gemma3n by patching the config.json file
private class Gemma3nModelContainer {
    static func loadContainer(
        hub: HubApi,
        configuration: ModelConfiguration,
        progressHandler: @escaping (Progress) -> Void
    ) async throws -> ModelContainer {
        // First download the model to get the files locally
        let modelDirectory = try await downloadModel(
            hub: hub, 
            configuration: configuration, 
            progressHandler: progressHandler
        )
        
        // Check if this is a gemma3n model that needs patching
        let configPath = modelDirectory.appending(component: "config.json")
        
        if let configData = try? Data(contentsOf: configPath),
           let configJSON = try? JSONSerialization.jsonObject(with: configData) as? [String: Any],
           let modelType = configJSON["model_type"] as? String,
           modelType == "gemma3n" {
            
            // Create a patched config with model_type changed to "gemma3"
            var patchedConfig = configJSON
            patchedConfig["model_type"] = "gemma3"
            
            // Write the patched config back
            let patchedData = try JSONSerialization.data(withJSONObject: patchedConfig, options: [])
            try patchedData.write(to: configPath)
            
            // Now try to load with the standard VLMModelFactory
            return try await VLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: configuration,
                progressHandler: progressHandler
            )
        } else {
            // Not a gemma3n model, use standard factory
            return try await VLMModelFactory.shared.loadContainer(
                hub: hub,
                configuration: configuration,
                progressHandler: progressHandler
            )
        }
    }
}

/// Helper function to download model (mimics VLMModelFactory internal behavior)
private func downloadModel(
    hub: HubApi,
    configuration: ModelConfiguration,
    progressHandler: @escaping (Progress) -> Void
) async throws -> URL {
    switch configuration.id {
    case .id(let id, let revision):
        let repo = Hub.Repo(id: id)
        return hub.localRepoLocation(repo)
    case .directory(let directory):
        return directory
    }
}
#endif

/// A concrete AI provider that uses the MLXLLM library to run a Gemma-3n model locally.
/// Note: This provider is temporarily disabled while migrating to the unified provider system
#if ENABLE_LEGACY_PROVIDER
public class MLXGemma3nE2BProvider: BaseAIProvider, ObservableObject {

    private var modelContainer: ModelContainer?
    private let modelConfiguration: ModelConfiguration
    
    /// Current model loading progress (0.0 to 1.0)
    @Published public var loadingProgress: Double = 0.0
    
    /// Current loading status message
    @Published public var loadingStatus: String = ""

    public override var identifier: String { "mlx-gemma-3n-e2b-vlm" }
    public override var displayName: String { "MLX Gemma 3n E2B (VLM)" }
    public override var isAvailable: Bool { 
        // MLX requires real Apple Silicon hardware, not simulators
        #if targetEnvironment(simulator)
        return false
        #else
        return modelContainer != nil
        #endif
    }

    public init(modelId: String = "mlx-community/gemma-3n-E2B-it-lm-bf16") {
        // Use the Gemma 3n E2B multimodal VLM model
        // This model has "model_type": "gemma3n" and requires custom registry support
        self.modelConfiguration = ModelConfiguration(
            id: modelId,
            defaultPrompt: "Hello, how are you?",
            extraEOSTokens: ["<end_of_turn>"]
        )
        super.init(subsystem: "com.jaredlikes.ProjectOne", category: "MLXGemma3nE2BProvider")
    }

    public override func prepareModel() async throws {
        // Check if running on simulator first
        #if targetEnvironment(simulator)
        await MainActor.run {
            loadingProgress = 0.0
            loadingStatus = "MLX requires real Apple Silicon hardware"
        }
        logger.error("MLX framework requires real Apple Silicon hardware, not simulator")
        throw AIModelProviderError.providerUnavailable("MLX requires real Apple Silicon hardware (not simulator)")
        #endif
        
        #if canImport(MLXLLM) && canImport(MLXVLM)
        logger.info("Preparing Gemma3 VLM model")
        
        await MainActor.run {
            loadingProgress = 0.0
            loadingStatus = "Starting model preparation..."
        }
        
        do {
            // Since this is a multimodal model with gemma3n type, we need to patch the config
            // to use "gemma3" instead of "gemma3n" for VLMModelFactory compatibility
            logger.info("Using Gemma3n-compatible VLM model loader")
            
            // Load the model using our custom container that can handle gemma3n
            self.modelContainer = try await Gemma3nModelContainer.loadContainer(
                hub: HubApi(), 
                configuration: modelConfiguration,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.handleModelProgress(progress)
                    }
                }
            )
            
            await MainActor.run {
                loadingProgress = 1.0
                loadingStatus = "Model ready"
            }
            
            logger.info("Gemma3 VLM model loaded successfully.")
        } catch {
            await MainActor.run {
                loadingProgress = 0.0
                loadingStatus = "Failed to load model"
            }
            logger.error("Failed to load Gemma3 VLM model: \(error.localizedDescription)")
            throw AIModelProviderError.modelNotLoaded
        }
        #else
        logger.error("MLXLLM and MLXVLM frameworks not available at compile time.")
        throw AIModelProviderError.providerUnavailable("MLXLLM and MLXVLM frameworks not available")
        #endif
    }

    public override func generateModelResponse(_ prompt: String) async throws -> String {
        #if targetEnvironment(simulator)
        throw AIModelProviderError.providerUnavailable("MLX requires real Apple Silicon hardware (not simulator)")
        #endif
        
        guard let modelContainer = modelContainer else {
            throw AIModelProviderError.modelNotLoaded
        }

        #if canImport(MLXLLM) && canImport(MLXVLM)
        do {
            // Create chat messages for the prompt
            let messages = [Chat.Message(role: .user, content: prompt)]
            let userInput = UserInput(chat: messages, processing: .init())
            
            // Generate response using the model container
            var result = ""
            let stream = try await modelContainer.perform { (context: ModelContext) in
                let lmInput = try await context.processor.prepare(input: userInput)
                let parameters = GenerateParameters(temperature: 0.6, topP: 0.9)
                
                return try MLXLMCommon.generate(
                    input: lmInput, parameters: parameters, context: context)
            }
            
            // Collect all tokens from the stream
            for try await generation in stream {
                switch generation {
                case .chunk(let chunk):
                    result += chunk
                case .info(_):
                    // Ignore info for now
                    break
                case .toolCall(_):
                    // Ignore tool calls for now
                    break
                }
            }
            
            return result
        } catch {
            logger.error("Failed to generate response from Gemma3 VLM: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
        #else
        throw AIModelProviderError.providerUnavailable("MLXLLM and MLXVLM frameworks not available")
        #endif
    }

    public override func cleanupModel() async {
        self.modelContainer = nil
        await MainActor.run {
            self.loadingProgress = 0.0
            self.loadingStatus = ""
        }
        logger.info("Gemma3 VLM model container cleaned up.")
    }
    
    // MARK: - Progress Handling
    
    @MainActor
    private func handleModelProgress(_ progress: Progress) {
        loadingProgress = progress.fractionCompleted
        
        // Update status based on progress
        if progress.isIndeterminate {
            loadingStatus = "Preparing model..."
        } else if progress.fractionCompleted < 0.1 {
            loadingStatus = "Initializing download..."
        } else if progress.fractionCompleted < 1.0 {
            let progressPercent = Int(progress.fractionCompleted * 100)
            let totalMB = progress.totalUnitCount > 0 ? Int(progress.totalUnitCount / 1_000_000) : 0
            let completedMB = Int(progress.completedUnitCount / 1_000_000)
            
            if totalMB > 0 {
                loadingStatus = "Downloading model: \(progressPercent)% (\(completedMB)/\(totalMB) MB)"
            } else {
                loadingStatus = "Downloading model: \(progressPercent)%"
            }
        } else {
            loadingStatus = "Finalizing model..."
        }
        
        logger.debug("Model loading progress: \(Int(progress.fractionCompleted * 100))% - \(self.loadingStatus)")
    }
}
#endif
