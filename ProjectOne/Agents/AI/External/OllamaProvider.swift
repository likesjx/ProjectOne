//
//  OllamaProvider.swift
//  ProjectOne
//
//  Ollama local AI provider implementation
//  Supports local models through Ollama server
//

import Foundation
import os.log

/// Ollama local AI provider
public class OllamaProvider: ExternalAIProvider {
    
    // MARK: - Predefined Configurations
    
    public static func llama3_8B(baseURL: String = "http://localhost:11434") -> OllamaProvider {
        let config = Configuration(
            apiKey: nil, // Ollama doesn't require API keys
            baseURL: baseURL,
            model: "llama3:8b",
            maxTokens: 4096,
            temperature: 0.7
        )
        return OllamaProvider(configuration: config)
    }
    
    public static func llama3_70B(baseURL: String = "http://localhost:11434") -> OllamaProvider {
        let config = Configuration(
            apiKey: nil,
            baseURL: baseURL,
            model: "llama3:70b",
            maxTokens: 4096,
            temperature: 0.7
        )
        return OllamaProvider(configuration: config)
    }
    
    public static func codellama(baseURL: String = "http://localhost:11434") -> OllamaProvider {
        let config = Configuration(
            apiKey: nil,
            baseURL: baseURL,
            model: "codellama:13b",
            maxTokens: 4096,
            temperature: 0.1
        )
        return OllamaProvider(configuration: config)
    }
    
    public static func mistral(baseURL: String = "http://localhost:11434") -> OllamaProvider {
        let config = Configuration(
            apiKey: nil,
            baseURL: baseURL,
            model: "mistral:7b",
            maxTokens: 4096,
            temperature: 0.7
        )
        return OllamaProvider(configuration: config)
    }
    
    public static func phi3(baseURL: String = "http://localhost:11434") -> OllamaProvider {
        let config = Configuration(
            apiKey: nil,
            baseURL: baseURL,
            model: "phi3:mini",
            maxTokens: 4096,
            temperature: 0.7
        )
        return OllamaProvider(configuration: config)
    }
    
    // MARK: - Initialization
    
    public init(configuration: Configuration) {
        super.init(configuration: configuration, providerType: .ollama)
    }
    
    public convenience init(model: String, baseURL: String = "http://localhost:11434") {
        let config = Configuration(
            apiKey: nil,
            baseURL: baseURL,
            model: model,
            maxTokens: 4096,
            temperature: 0.7
        )
        self.init(configuration: config)
    }
    
    // MARK: - Ollama-Specific Features
    
    override func prepareModel() async throws {
        self.logger.info("Preparing Ollama model: \(self.configuration.model)")
        
        // Check if Ollama server is running
        guard try await isOllamaServerRunning() else {
            throw ExternalAIError.networkError("Ollama server not running at \(self.configuration.baseURL)")
        }
        
        // Check if model is available, pull if necessary
        if !(try await isModelAvailable()) {
            self.logger.info("Model \(self.configuration.model) not found, attempting to pull...")
            try await pullModel()
        }
        
        try await super.prepareModel()
    }
    
    override func generateModelResponse(_ prompt: String) async throws -> String {
        guard case .ready = modelLoadingStatus else {
            throw ExternalAIError.modelNotReady
        }
        
        self.logger.info("Generating Ollama response")
        
        let request = OllamaGenerateRequest(
            model: self.configuration.model,
            prompt: prompt,
            options: OllamaOptions(
                temperature: self.configuration.temperature,
                numCtx: self.configuration.maxTokens
            ),
            stream: false
        )
        
        do {
            let response = try await httpClient.sendOllamaGenerateRequest(request)
            return response.response
        } catch {
            self.logger.error("❌ Ollama generation failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
    }
    
    /// Check if Ollama server is running
    private func isOllamaServerRunning() async throws -> Bool {
        guard let url = URL(string: "\(self.configuration.baseURL)/api/version") else {
            return false
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    /// Check if model is available locally
    private func isModelAvailable() async throws -> Bool {
        let models = try await getLocalModels()
        return models.models.contains { $0.name.hasPrefix(self.configuration.model) }
    }
    
    /// Pull model from Ollama registry
    private func pullModel() async throws {
        self.logger.info("Pulling Ollama model: \(self.configuration.model)")
        
        guard let url = URL(string: "\(self.configuration.baseURL)/api/pull") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let pullRequest = OllamaPullRequest(name: self.configuration.model, stream: false)
        urlRequest.httpBody = try JSONEncoder().encode(pullRequest)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ExternalAIError.networkError("Failed to pull model: \(errorMessage)")
        }
        
        self.logger.info("✅ Successfully pulled model: \(self.configuration.model)")
    }
    
    /// Get list of local models
    public func getLocalModels() async throws -> OllamaModelsResponse {
        guard let url = URL(string: "\(self.configuration.baseURL)/api/tags") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ExternalAIError.networkError("Failed to fetch local models")
            }
            
            return try JSONDecoder().decode(OllamaModelsResponse.self, from: data)
        } catch {
            self.logger.error("❌ Failed to fetch Ollama models: \(error.localizedDescription)")
            throw ExternalAIError.networkError("Failed to fetch models: \(error.localizedDescription)")
        }
    }
    
    /// Get model information
    public func getModelInfo() async throws -> OllamaModelInfo {
        guard let url = URL(string: "\(self.configuration.baseURL)/api/show") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let showRequest = OllamaShowRequest(name: self.configuration.model)
        urlRequest.httpBody = try JSONEncoder().encode(showRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ExternalAIError.networkError("Failed to get model info")
            }
            
            return try JSONDecoder().decode(OllamaModelInfo.self, from: data)
        } catch {
            self.logger.error("❌ Failed to get Ollama model info: \(error.localizedDescription)")
            throw ExternalAIError.networkError("Failed to get model info: \(error.localizedDescription)")
        }
    }
    
    /// Generate response with streaming support
    public func generateStreaming(_ prompt: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = OllamaGenerateRequest(
                        model: self.configuration.model,
                        prompt: prompt,
                        options: OllamaOptions(
                            temperature: self.configuration.temperature,
                            numCtx: self.configuration.maxTokens
                        ),
                        stream: true
                    )
                    
                    let stream = try await httpClient.sendOllamaStreamingRequest(request)
                    
                    for try await chunk in stream {
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Ollama-Specific Types

public struct OllamaGenerateRequest: Codable {
    let model: String
    let prompt: String
    let options: OllamaOptions?
    let stream: Bool
}

public struct OllamaOptions: Codable {
    let temperature: Double?
    let numCtx: Int?
    let topK: Int?
    let topP: Double?
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case numCtx = "num_ctx"
        case topK = "top_k"
        case topP = "top_p"
    }
    
    public init(temperature: Double? = nil, numCtx: Int? = nil, topK: Int? = nil, topP: Double? = nil) {
        self.temperature = temperature
        self.numCtx = numCtx
        self.topK = topK
        self.topP = topP
    }
}

public struct OllamaGenerateResponse: Codable {
    let model: String
    let createdAt: String
    let response: String
    let done: Bool
    let context: [Int]?
    let totalDuration: Int?
    let loadDuration: Int?
    let promptEvalCount: Int?
    let promptEvalDuration: Int?
    let evalCount: Int?
    let evalDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case model, response, done, context
        case createdAt = "created_at"
        case totalDuration = "total_duration"
        case loadDuration = "load_duration"
        case promptEvalCount = "prompt_eval_count"
        case promptEvalDuration = "prompt_eval_duration"
        case evalCount = "eval_count"
        case evalDuration = "eval_duration"
    }
}

public struct OllamaModelsResponse: Codable {
    let models: [OllamaModel]
}

public struct OllamaModel: Codable {
    let name: String
    let modifiedAt: String
    let size: Int
    let digest: String
    let details: OllamaModelDetails?
    
    enum CodingKeys: String, CodingKey {
        case name, size, digest, details
        case modifiedAt = "modified_at"
    }
}

public struct OllamaModelDetails: Codable {
    let format: String
    let family: String
    let families: [String]?
    let parameterSize: String
    let quantizationLevel: String
    
    enum CodingKeys: String, CodingKey {
        case format, family, families
        case parameterSize = "parameter_size"
        case quantizationLevel = "quantization_level"
    }
}

public struct OllamaPullRequest: Codable {
    let name: String
    let stream: Bool
}

public struct OllamaShowRequest: Codable {
    let name: String
}

public struct OllamaModelInfo: Codable {
    let modelfile: String
    let parameters: String
    let template: String
    let details: OllamaModelDetails
}

// MARK: - HTTPClient Extension for Ollama

extension HTTPClient {
    func sendOllamaGenerateRequest(_ request: OllamaGenerateRequest) async throws -> OllamaGenerateResponse {
        guard let url = URL(string: "\(self.configuration.baseURL)/api/generate") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ExternalAIError.networkError("Request failed: \(errorMessage)")
        }
        
        return try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
    }
    
    func sendOllamaStreamingRequest(_ request: OllamaGenerateRequest) async throws -> AsyncThrowingStream<String, Error> {
        guard let url = URL(string: "\(self.configuration.baseURL)/api/generate") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (asyncBytes, response) = try await urlSession.bytes(for: urlRequest)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          200...299 ~= httpResponse.statusCode else {
                        continuation.finish(throwing: ExternalAIError.networkError("Request failed"))
                        return
                    }
                    
                    for try await line in asyncBytes.lines {
                        guard !line.isEmpty,
                              let data = line.data(using: .utf8),
                              let response = try? JSONDecoder().decode(OllamaGenerateResponse.self, from: data) else {
                            continue
                        }
                        
                        continuation.yield(response.response)
                        
                        if response.done {
                            break
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}