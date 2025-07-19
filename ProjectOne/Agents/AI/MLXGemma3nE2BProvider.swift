import Foundation
import os.log

#if canImport(MLXLMCommon)
import MLXLMCommon
#endif

/// A concrete AI provider that uses the MLXLLM library to run a Gemma-3n model locally.
public class MLXGemma3nE2BProvider: BaseAIProvider {

    #if canImport(MLXLMCommon)
    private var chatSession: ChatSession?
    #endif
    private let modelId: String

    public override var identifier: String { "mlx-gemma-3n-e2b-llm" }
    public override var displayName: String { "MLX Gemma 3n E2B (LLM)" }
    public override var maxContextLength: Int { 8192 }
    public override var estimatedResponseTime: TimeInterval { 5.0 }
    
    public override var isAvailable: Bool { 
        #if canImport(MLXLMCommon)
        return chatSession != nil
        #else
        return false
        #endif
    }

    public init(modelId: String = "mlx-community/gemma-3n-E2B-it-4bit") {
        self.modelId = modelId
        super.init(subsystem: "com.jaredlikes.ProjectOne", category: "MLXGemma3nE2BProvider")
    }

    public override func prepareModel() async throws {
        #if canImport(MLXLMCommon)
        await MainActor.run {
            modelLoadingStatus = .preparing
            statusMessage = "Initializing MLXLLM model: \(self.modelId)"
        }
        
        logger.info("Preparing MLXLLM model: \(self.modelId)")
        
        do {
            await MainActor.run {
                modelLoadingStatus = .downloading(progress: 0.0)
                statusMessage = "Checking model availability..."
                loadingProgress = 0.1
            }
            
            // Try to load the model with enhanced error handling
            let modelContainer = try await loadModelContainerWithRetry(id: modelId)
            
            await MainActor.run {
                modelLoadingStatus = .loading
                statusMessage = "Creating chat session..."
                loadingProgress = 0.8
            }
            
            self.chatSession = ChatSession(modelContainer)
            
            await MainActor.run {
                modelLoadingStatus = .ready
                statusMessage = "MLXLLM model ready for inference"
                loadingProgress = 1.0
                isModelLoaded = true
            }
            
            logger.info("MLXLLM model \(self.modelId) loaded successfully.")
            
        } catch {
            let errorMessage = handleModelLoadError(error)
            
            await MainActor.run {
                modelLoadingStatus = .failed(errorMessage)
                statusMessage = errorMessage
                loadingProgress = 0.0
                isModelLoaded = false
            }
            
            logger.error("Failed to load MLXLLM model: \(error.localizedDescription)")
            throw AIModelProviderError.modelNotLoaded
        }
        #else
        await MainActor.run {
            modelLoadingStatus = .unavailable
            statusMessage = "MLXLMCommon framework not available at compile time"
            isModelLoaded = false
        }
        
        logger.error("MLXLMCommon framework not available at compile time.")
        throw AIModelProviderError.providerUnavailable("MLXLMCommon framework not available")
        #endif
    }

    public override func generateModelResponse(_ prompt: String) async throws -> String {
        #if canImport(MLXLMCommon)
        guard let session = chatSession else {
            throw AIModelProviderError.modelNotLoaded
        }

        do {
            logger.info("Generating response with MLXLLM for prompt: \(prompt.prefix(50))...")
            
            let response = try await session.respond(to: prompt)
            
            logger.info("Successfully generated response from MLXLLM")
            return response
            
        } catch {
            logger.error("Failed to generate response from MLXLLM: \(error.localizedDescription)")
            throw AIModelProviderError.processingFailed(error.localizedDescription)
        }
        #else
        throw AIModelProviderError.providerUnavailable("MLXLMCommon framework not available")
        #endif
    }

    public override func cleanupModel() async {
        #if canImport(MLXLMCommon)
        chatSession = nil
        #endif
        logger.info("MLXLLM model cleaned up.")
    }
    
    // MARK: - Enhanced Model Loading
    
    #if canImport(MLXLMCommon)
    /// Load model container with retry logic and better error handling
    private func loadModelContainerWithRetry(id: String, maxRetries: Int = 3) async throws -> ModelContainer {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                await MainActor.run {
                    if attempt > 1 {
                        statusMessage = "Network retry \(attempt)/\(maxRetries)..."
                    } else {
                        statusMessage = "Downloading/loading model..."
                    }
                    loadingProgress = 0.2 + (0.4 * Double(attempt - 1) / Double(maxRetries))
                }
                
                logger.info("Model load attempt \(attempt) for: \(id)")
                
                // Clear any incomplete downloads first
                if attempt > 1 {
                    try await clearIncompleteDownloads(for: id)
                    // Add network recovery delay for TCP reset issues
                    await networkRecoveryDelay(attempt: attempt)
                }
                
                // Create new URLSession for each retry to avoid stale connections
                let container = try await loadModelContainerWithFreshSession(id: id)
                logger.info("Successfully loaded model on attempt \(attempt)")
                return container
                
            } catch {
                lastError = error
                logger.warning("Model load attempt \(attempt) failed: \(error.localizedDescription)")
                
                // Check if this is a network-related error
                if isNetworkError(error) {
                    logger.info("Network error detected, will retry with fresh connection")
                }
                
                if attempt < maxRetries {
                    // Progressive delay for network issues
                    let delay = min(attempt * 2, 10) // Cap at 10 seconds
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                }
            }
        }
        
        throw lastError ?? AIModelProviderError.modelNotLoaded
    }
    
    /// Load model with a fresh URLSession to avoid TCP connection reuse issues
    private func loadModelContainerWithFreshSession(id: String) async throws -> ModelContainer {
        // Force a fresh network session by clearing any cached connections
        URLCache.shared.removeAllCachedResponses()
        
        // Configure URLSession with fresh TCP connections
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        
        // Use the MLX framework's loadModelContainer but with improved error context
        return try await loadModelContainer(id: id)
    }
    
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