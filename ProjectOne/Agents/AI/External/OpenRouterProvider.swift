//
//  OpenRouterProvider.swift
//  ProjectOne
//
//  OpenRouter API provider implementation
//  Supports multiple models from different providers through a unified API
//

import Foundation
import os.log

/// OpenRouter API provider - unified access to multiple AI models
public class OpenRouterProvider: ExternalAIProvider, @unchecked Sendable {
    
    // MARK: - Predefined Configurations
    
    public static func claude3Sonnet(apiKey: String) -> OpenRouterProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: "anthropic/claude-3-sonnet:beta",
            maxTokens: 4096,
            temperature: 0.7,
            customHeaders: [
                "HTTP-Referer": "https://projectone.app",
                "X-Title": "ProjectOne"
            ]
        )
        return OpenRouterProvider(configuration: config)
    }
    
    public static func claude3Haiku(apiKey: String) -> OpenRouterProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: "anthropic/claude-3-haiku:beta",
            maxTokens: 4096,
            temperature: 0.7,
            customHeaders: [
                "HTTP-Referer": "https://projectone.app",
                "X-Title": "ProjectOne"
            ]
        )
        return OpenRouterProvider(configuration: config)
    }
    
    public static func gpt4Turbo(apiKey: String) -> OpenRouterProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: "openai/gpt-4-turbo",
            maxTokens: 4096,
            temperature: 0.7,
            customHeaders: [
                "HTTP-Referer": "https://projectone.app",
                "X-Title": "ProjectOne"
            ]
        )
        return OpenRouterProvider(configuration: config)
    }
    
    public static func geminiPro(apiKey: String) -> OpenRouterProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: "google/gemini-pro-1.5",
            maxTokens: 4096,
            temperature: 0.7,
            customHeaders: [
                "HTTP-Referer": "https://projectone.app",
                "X-Title": "ProjectOne"
            ]
        )
        return OpenRouterProvider(configuration: config)
    }
    
    public static func llama3_70B(apiKey: String) -> OpenRouterProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: "meta-llama/llama-3-70b-instruct",
            maxTokens: 4096,
            temperature: 0.7,
            customHeaders: [
                "HTTP-Referer": "https://projectone.app",
                "X-Title": "ProjectOne"
            ]
        )
        return OpenRouterProvider(configuration: config)
    }
    
    // MARK: - Initialization
    
    public init(configuration: Configuration) {
        super.init(configuration: configuration, providerType: .openRouter)
    }
    
    public convenience init(apiKey: String, model: String = "anthropic/claude-3-haiku:beta") {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: model,
            maxTokens: 4096,
            temperature: 0.7,
            customHeaders: [
                "HTTP-Referer": "https://projectone.app",
                "X-Title": "ProjectOne"
            ]
        )
        self.init(configuration: config)
    }
    
    // MARK: - OpenRouter-Specific Features
    
    override func prepareModel() async throws {
        self.logger.info("Preparing OpenRouter model: \(self.configuration.model)")
        
        guard self.configuration.apiKey != nil else {
            throw ExternalAIError.configurationInvalid("OpenRouter API key required")
        }
        
        try await super.prepareModel()
    }
    
    /// Get available models from OpenRouter
    public func getAvailableModels() async throws -> [OpenRouterModel] {
        guard let url = URL(string: "\(self.configuration.baseURL)/models") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(self.configuration.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        
        // Add OpenRouter-specific headers
        for (key, value) in self.configuration.customHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ExternalAIError.networkError("Failed to fetch models")
            }
            
            let modelResponse = try JSONDecoder().decode(OpenRouterModelsResponse.self, from: data)
            return modelResponse.data
        } catch {
            self.logger.error("❌ Failed to fetch OpenRouter models: \(error.localizedDescription)")
            throw ExternalAIError.networkError("Failed to fetch models: \(error.localizedDescription)")
        }
    }
    
    /// Get usage statistics
    public func getUsageStats() async throws -> OpenRouterUsage {
        guard let url = URL(string: "\(self.configuration.baseURL)/auth/key") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(self.configuration.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        
        // Add OpenRouter-specific headers
        for (key, value) in self.configuration.customHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ExternalAIError.networkError("Failed to fetch usage stats")
            }
            
            return try JSONDecoder().decode(OpenRouterUsage.self, from: data)
        } catch {
            self.logger.error("❌ Failed to fetch OpenRouter usage: \(error.localizedDescription)")
            throw ExternalAIError.networkError("Failed to fetch usage: \(error.localizedDescription)")
        }
    }
    
    /// Generate response with model preferences
    public func generateWithPreferences(
        prompt: String,
        fallbackModels: [String] = [],
        routePreference: RoutePreference = .balanced
    ) async throws -> String {
        guard case .ready = self.modelLoadingStatus else {
            throw ExternalAIError.modelNotReady
        }
        
        self.logger.info("Generating OpenRouter response with preferences")
        
        let request = OpenRouterRequest(
            model: self.configuration.model,
            messages: [ChatMessage(role: "user", content: prompt)],
            maxTokens: self.configuration.maxTokens,
            temperature: self.configuration.temperature,
            route: routePreference.rawValue,
            fallbacks: fallbackModels
        )
        
        do {
            let response = try await self.httpClient.sendOpenRouterRequest(request)
            return response.choices.first?.message.content ?? ""
        } catch {
            self.logger.error("❌ OpenRouter generation failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
    }
}

// MARK: - OpenRouter-Specific Types

public struct OpenRouterModel: Codable {
    let id: String
    let name: String
    let description: String?
    let contextLength: Int
    let pricing: ModelPricing
    let topProvider: Provider?
    let perRequestLimits: RequestLimits?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, pricing
        case contextLength = "context_length"
        case topProvider = "top_provider"
        case perRequestLimits = "per_request_limits"
    }
}

public struct ModelPricing: Codable {
    let prompt: String
    let completion: String
    let image: String?
}

public struct Provider: Codable {
    let contextLength: Int
    let maxCompletionTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case contextLength = "context_length"
        case maxCompletionTokens = "max_completion_tokens"
    }
}

public struct RequestLimits: Codable {
    let promptTokens: Int?
    let completionTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
    }
}

public struct OpenRouterModelsResponse: Codable {
    let data: [OpenRouterModel]
}

public struct OpenRouterUsage: Codable {
    let data: UsageData
}

public struct UsageData: Codable {
    let label: String
    let usage: Double
    let limit: Double?
    let isUnlimited: Bool
    
    enum CodingKeys: String, CodingKey {
        case label, usage, limit
        case isUnlimited = "is_unlimited"
    }
}

public struct OpenRouterRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let maxTokens: Int
    let temperature: Double
    let route: String?
    let fallbacks: [String]?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, route, fallbacks
        case maxTokens = "max_tokens"
    }
}

public enum RoutePreference: String, CaseIterable {
    case fastest = "fastest"
    case cheapest = "cheapest" 
    case balanced = "balanced"
    case quality = "quality"
}

// MARK: - HTTPClient Extension for OpenRouter

extension HTTPClient {
    func sendOpenRouterRequest(_ request: OpenRouterRequest) async throws -> ChatResponse {
        guard let url = URL(string: "\(self.configuration.baseURL)/chat/completions") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = self.configuration.apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Add custom headers (including OpenRouter-specific ones)
        for (key, value) in self.configuration.customHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await self.urlSession.data(for: urlRequest)
        
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
    }
}