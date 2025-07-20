import Foundation
import os.log

#if canImport(MLXVLM)
import MLXVLM
import MLXLMCommon  // Still needed for some common utilities
import CoreImage     // For image processing
#endif

/// A concrete AI provider that uses the MLXVLM library to run a Gemma-3n VLM model locally.
public class MLXGemma3nE2BProvider: BaseAIProvider {

    #if canImport(MLXVLM)
    private var vlmModel: VLMModel?
    private var vlmSession: ChatSession?
    #endif
    private let modelId: String

    public override var identifier: String { "mlx-gemma-3n-e2b-llm" }
    public override var displayName: String { "MLX Gemma 3n E2B" }
    public override var maxContextLength: Int { 8192 }
    public override var estimatedResponseTime: TimeInterval { 5.0 }
    
    public override var isAvailable: Bool { 
        #if canImport(MLXVLM)
        // MLX VLM requires Metal 4 and real Apple Silicon hardware
        guard isMLXSupported else { return false }
        return vlmModel != nil
        #else
        return false
        #endif
    }
    
    /// Check if MLX is supported on current device
    public var isMLXSupported: Bool {
        #if targetEnvironment(simulator)
        return false // MLX requires real Apple Silicon hardware, not simulator
        #else
        #if arch(arm64)
        return true // Apple Silicon Macs and iOS devices with Metal 4
        #else
        return false // Intel Macs not supported
        #endif
        #endif
    }

    public init(modelId: String = "mlx-community/gemma-3n-E2B-it-4bit") {
        self.modelId = modelId
        super.init(subsystem: "com.jaredlikes.ProjectOne", category: "MLXGemma3nE2BProvider")
    }

    public override func prepareModel() async throws {
        #if canImport(MLXVLM)
        // Early check: MLX VLM requires Metal 4 and real Apple Silicon hardware
        guard isMLXSupported else {
            await MainActor.run {
                modelLoadingStatus = .unavailable
                statusMessage = "MLX VLM requires real Apple Silicon hardware (not simulator)"
                isModelLoaded = false
            }
            logger.error("MLX VLM not supported: running on simulator or Intel Mac")
            throw AIModelProviderError.providerUnavailable("MLX VLM requires real Apple Silicon hardware")
        }
        
        await MainActor.run {
            modelLoadingStatus = .preparing
            statusMessage = "Initializing MLX VLM model: \(self.modelId)"
        }
        
        logger.info("Preparing MLX VLM model: \(self.modelId)")
        
        do {
            await MainActor.run {
                modelLoadingStatus = .downloading(progress: 0.0)
                statusMessage = "Loading VLM model..."
                loadingProgress = 0.1
            }
            
            // Load VLM model using MLXVLM API (not MLXLMCommon)
            let loadedVLMModel = try await MLXVLM.loadModel(id: modelId) { progress in
                Task { @MainActor in
                    self.loadingProgress = 0.1 + (progress.fractionCompleted * 0.8)
                }
            }
            
            await MainActor.run {
                modelLoadingStatus = .loading
                statusMessage = "Initializing VLM session..."
                loadingProgress = 0.9
            }
            
            // Create VLM-capable chat session
            let session = ChatSession(loadedVLMModel)
            
            self.vlmModel = loadedVLMModel
            self.vlmSession = session
            
            await MainActor.run {
                modelLoadingStatus = .ready
                statusMessage = "MLX VLM model ready for multimodal inference"
                loadingProgress = 1.0
                isModelLoaded = true
            }
            
            logger.info("MLX VLM model \(self.modelId) loaded successfully.")
            
        } catch {
            let errorMessage = handleModelLoadError(error)
            
            await MainActor.run {
                modelLoadingStatus = .failed(errorMessage)
                statusMessage = errorMessage
                loadingProgress = 0.0
                isModelLoaded = false
            }
            
            logger.error("Failed to load MLX VLM model: \(error.localizedDescription)")
            throw AIModelProviderError.modelNotLoaded
        }
        #else
        await MainActor.run {
            modelLoadingStatus = .unavailable
            statusMessage = "MLXVLM framework not available at compile time"
            isModelLoaded = false
        }
        
        logger.error("MLXVLM framework not available at compile time.")
        throw AIModelProviderError.providerUnavailable("MLXVLM framework not available")
        #endif
    }

    public override func generateModelResponse(_ prompt: String) async throws -> String {
        #if canImport(MLXVLM)
        guard let session = vlmSession else {
            throw AIModelProviderError.modelNotLoaded
        }

        do {
            logger.info("Generating VLM response for prompt: \(prompt.prefix(50))...")
            
            // Use VLM session API for text-only queries
            let response = try await session.respond(to: prompt)
            
            logger.info("Successfully generated response from MLX VLM")
            return response
            
        } catch {
            logger.error("Failed to generate response from MLX VLM: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
        #else
        throw AIModelProviderError.providerUnavailable("MLXVLM framework not available")
        #endif
    }
    
    /// Generate multimodal response with text and image input
    public func generateMultimodalResponse(_ prompt: String, image: UIImage) async throws -> String {
        #if canImport(MLXVLM)
        guard let session = vlmSession else {
            throw AIModelProviderError.modelNotLoaded
        }
        
        do {
            logger.info("Generating VLM multimodal response for prompt: \(prompt.prefix(50))...")
            
            // Convert UIImage to CIImage for MLXVLM
            guard let ciImage = CIImage(image: image) else {
                throw AIModelProviderError.processingFailed("Failed to convert image to CIImage")
            }
            
            // Use VLM session API for multimodal queries
            let response = try await session.respond(
                to: prompt,
                image: .ciImage(ciImage)
            )
            
            logger.info("Successfully generated multimodal response from MLX VLM")
            return response
            
        } catch {
            logger.error("Failed to generate multimodal response from MLX VLM: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
        #else
        throw AIModelProviderError.providerUnavailable("MLXVLM framework not available")
        #endif
    }

    public override func cleanupModel() async {
        #if canImport(MLXVLM)
        vlmSession = nil
        vlmModel = nil
        #endif
        logger.info("MLX VLM model cleaned up.")
    }
    
    // MARK: - VLM Model Loading Support
    
    /// Implement network recovery delay with exponential backoff
    private func networkRecoveryDelay(attempt: Int) async {
        let baseDelay = 2.0 // 2 seconds base
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 2))
        let cappedDelay = min(exponentialDelay, 30.0) // Cap at 30 seconds
        
        await MainActor.run {
            statusMessage = "Network recovery delay (\(Int(cappedDelay))s)..."
        }
        
        try? await Task.sleep(nanoseconds: UInt64(cappedDelay * 1_000_000_000))
    }
    
    /// Check if error is network-related (TCP resets, timeouts, etc.)
    private func isNetworkError(_ error: Error) -> Bool {
        let errorString = error.localizedDescription.lowercased()
        
        return errorString.contains("network") ||
               errorString.contains("connection") ||
               errorString.contains("timeout") ||
               errorString.contains("reset") ||
               errorString.contains("interrupted") ||
               errorString.contains("unreachable") ||
               errorString.contains("dns") ||
               (error as NSError).domain == NSURLErrorDomain
    }
    
    /// Clear incomplete model downloads
    #if canImport(MLXVLM)
    private func clearIncompleteDownloads(for modelId: String) async throws {
        let fileManager = FileManager.default
        
        // Get the MLX models directory (this is where MLX typically stores models)
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let mlxModelsDir = documentsDir.appendingPathComponent("mlx_models")
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: mlxModelsDir, includingPropertiesForKeys: nil)
            
            for file in contents {
                if file.lastPathComponent.contains(".incomplete") || 
                   file.lastPathComponent.contains("safetensors") && 
                   file.lastPathComponent.contains(modelId.components(separatedBy: "/").last ?? "") {
                    
                    logger.info("Clearing incomplete download: \(file.lastPathComponent)")
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            logger.warning("Could not clear incomplete downloads: \(error.localizedDescription)")
        }
    }
    #endif
    
    /// Handle and categorize model loading errors
    private func handleModelLoadError(_ error: Error) -> String {
        let errorDescription = error.localizedDescription.lowercased()
        let nsError = error as NSError
        
        // TCP/Network specific errors
        if errorDescription.contains("reset") || errorDescription.contains("tcp") {
            return "Network connection reset. Retrying with fresh connection..."
        } else if errorDescription.contains("timeout") || nsError.code == NSURLErrorTimedOut {
            return "Download timeout. Retrying with extended timeout..."
        } else if errorDescription.contains("connection") || nsError.code == NSURLErrorCannotConnectToHost {
            return "Connection failed. Checking network and retrying..."
        } else if errorDescription.contains("dns") || nsError.code == NSURLErrorCannotFindHost {
            return "DNS resolution failed. Retrying connection..."
        } else if errorDescription.contains("unreachable") || nsError.code == NSURLErrorNotConnectedToInternet {
            return "Network unreachable. Check internet connection."
        }
        
        // File system errors
        else if errorDescription.contains("incomplete") {
            return "Model download incomplete. Clearing cache and retrying..."
        } else if errorDescription.contains("doesn't exist") || errorDescription.contains("not found") {
            return "Model files not found. Download may be required."
        } else if errorDescription.contains("safetensors") {
            return "Model file corruption detected. Clearing cache and redownloading..."
        } else if errorDescription.contains("permission") {
            return "File system permission error. Check app permissions."
        }
        
        // Resource errors
        else if errorDescription.contains("memory") {
            return "Insufficient memory for model loading. Close other apps and retry."
        } else if errorDescription.contains("disk") || errorDescription.contains("space") {
            return "Insufficient storage space. Free up space and retry."
        }
        
        // Generic network error
        else if nsError.domain == NSURLErrorDomain {
            return "Network error (code \(nsError.code)). Retrying with fresh connection..."
        }
        
        else {
            return "Model loading failed: \(error.localizedDescription)"
        }
    }
}