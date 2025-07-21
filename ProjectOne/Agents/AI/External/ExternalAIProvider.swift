//
//  ExternalAIProvider.swift
//  ProjectOne
//
//  Base provider for external AI services (OpenAI, OpenRouter, Ollama, MLX, etc.)
//

import Foundation
import Combine
import os.log

/// Base class for external AI service providers
@MainActor
public class ExternalAIProvider: BaseAIProvider {
    
    // MARK: - Configuration
    
    public struct Configuration {
        let apiKey: String?
        let baseURL: String
        let model: String
        let maxTokens: Int
        let temperature: Double
        let timeout: TimeInterval
        let retryCount: Int
        let customHeaders: [String: String]
        
        public init(
            apiKey: String? = nil,
            baseURL: String,
            model: String,
            maxTokens: Int = 4096,
            temperature: Double = 0.7,
            timeout: TimeInterval = 60.0,
            retryCount: Int = 3,
            customHeaders: [String: String] = [:]
        ) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.model = model
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.timeout = timeout
            self.retryCount = retryCount
            self.customHeaders = customHeaders
        }
    }
    
    // MARK: - Properties
    
    internal let configuration: Configuration
    internal let httpClient: HTTPClient  
    internal let providerType: ExternalProviderType
    
    // MARK: - BaseAIProvider Implementation
    
    public override var identifier: String { providerType.identifier }
    public override var displayName: String { providerType.displayName }
    public override var maxContextLength: Int { configuration.maxTokens }
    
    // MARK: - Initialization
    
    public init(configuration: Configuration, providerType: ExternalProviderType) {
        self.configuration = configuration
        self.providerType = providerType
        self.httpClient = HTTPClient(configuration: configuration)
        
        super.init(
            subsystem: "com.jaredlikes.ProjectOne",
            category: "ExternalAIProvider"
        )
        
        logger.info("Initialized \(providerType.displayName) provider")
    }
    
    // MARK: - BaseAIProvider Implementation
    
    override func prepareModel() async throws {
        logger.info("Preparing \(providerType.displayName) model: \(configuration.model)")
        
        await MainActor.run {
            self.modelLoadingStatus = .preparing
        }
        
        // Test connectivity and model availability
        do {
            let isReady = try await testConnection()
            if isReady {
                await MainActor.run {
                    self.modelLoadingStatus = .ready
                }
                logger.info("✅ \(providerType.displayName) model ready")
            } else {
                throw ExternalAIError.modelNotAvailable(configuration.model)
            }
        } catch {
            await MainActor.run {
                self.modelLoadingStatus = .failed(error.localizedDescription)
            }
            throw error
        }
    }
    
    override func generateModelResponse(_ prompt: String) async throws -> String {
        guard case .ready = modelLoadingStatus else {
            throw ExternalAIError.modelNotReady
        }
        
        logger.info("Generating response with \(providerType.displayName)")
        
        let request = ChatRequest(
            model: configuration.model,
            messages: [ChatMessage(role: "user", content: prompt)],
            maxTokens: configuration.maxTokens,
            temperature: configuration.temperature
        )
        
        do {
            let response = try await httpClient.sendChatRequest(request)
            return response.choices.first?.message.content ?? ""
        } catch {
            logger.error("❌ \(providerType.displayName) generation failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
    }
    
    override func cleanupModel() async {
        await httpClient.cleanup()
        logger.info("\(providerType.displayName) provider cleaned up")
    }
    
    override func getModelConfidence() -> Double {
        return providerType.defaultConfidence
    }
    
    // MARK: - Connection Testing
    
    private func testConnection() async throws -> Bool {
        // Basic connectivity test - can be overridden by specific providers
        do {
            let testRequest = ChatRequest(
                model: configuration.model,
                messages: [ChatMessage(role: "user", content: "test")],
                maxTokens: 1,
                temperature: 0.0
            )
            
            _ = try await httpClient.sendChatRequest(testRequest)
            return true
        } catch {
            logger.warning("Connection test failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Supporting Types

public enum ExternalProviderType {
    case openAI
    case openRouter
    case ollama
    case anthropic
    case custom(name: String, identifier: String)
    
    public var identifier: String {
        switch self {
        case .openAI: return "openai"
        case .openRouter: return "openrouter"
        case .ollama: return "ollama"
        case .anthropic: return "anthropic"
        case .custom(_, let identifier): return identifier
        }
    }
    
    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .ollama: return "Ollama"
        case .anthropic: return "Anthropic"
        case .custom(let name, _): return name
        }
    }
    
    public var defaultConfidence: Double {
        switch self {
        case .openAI: return 0.9
        case .openRouter: return 0.85
        case .ollama: return 0.8
        case .anthropic: return 0.95
        case .custom: return 0.8
        }
    }
}

public enum ExternalAIError: Error, LocalizedError {
    case configurationInvalid(String)
    case modelNotAvailable(String)
    case modelNotReady
    case generationFailed(String)
    case networkError(String)
    case authenticationFailed
    case quotaExceeded
    case rateLimited(retryAfter: TimeInterval?)
    
    public var errorDescription: String? {
        switch self {
        case .configurationInvalid(let message):
            return "Invalid configuration: \(message)"
        case .modelNotAvailable(let model):
            return "Model not available: \(model)"
        case .modelNotReady:
            return "Model not ready"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed:
            return "Authentication failed"
        case .quotaExceeded:
            return "API quota exceeded"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Rate limited, retry after \(retry) seconds"
            } else {
                return "Rate limited"
            }
        }
    }
}

// MARK: - HTTP Client

public class HTTPClient {
    private let configuration: ExternalAIProvider.Configuration
    private let urlSession: URLSession
    
    public init(configuration: ExternalAIProvider.Configuration) {
        self.configuration = configuration
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.urlSession = URLSession(configuration: sessionConfig)
    }
    
    public func sendChatRequest(_ request: ChatRequest) async throws -> ChatResponse {
        guard let url = URL(string: "\(configuration.baseURL)/chat/completions") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication if available
        if let apiKey = configuration.apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers
        for (key, value) in configuration.customHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        // Encode request body
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw ExternalAIError.configurationInvalid("Failed to encode request: \(error.localizedDescription)")
        }
        
        // Send request with retries
        var lastError: Error?
        for attempt in 1...configuration.retryCount {
            do {
                let (data, response) = try await urlSession.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ExternalAIError.networkError("Invalid response type")
                }
                
                switch httpResponse.statusCode {
                case 200...299:
                    return try JSONDecoder().decode(ChatResponse.self, from: data)
                case 401:
                    throw ExternalAIError.authenticationFailed
                case 429:
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        .flatMap { TimeInterval($0) }
                    throw ExternalAIError.rateLimited(retryAfter: retryAfter)
                case 402, 403:
                    throw ExternalAIError.quotaExceeded
                default:
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw ExternalAIError.networkError("HTTP \(httpResponse.statusCode): \(errorMessage)")
                }
            } catch {
                lastError = error
                if attempt < configuration.retryCount {
                    let delay = min(pow(2.0, Double(attempt - 1)), 30.0) // Exponential backoff, max 30s
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? ExternalAIError.networkError("Request failed after \(configuration.retryCount) attempts")
    }
    
    public func cleanup() async {
        urlSession.invalidateAndCancel()
    }
}

// MARK: - Chat API Types

public struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int
    let temperature: Double
    let stream: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

public struct ChatMessage: Codable {
    let role: String
    let content: String
}

public struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChatChoice]
    let usage: Usage?
}

public struct ChatChoice: Codable {
    let index: Int
    let message: ChatMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

public struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}