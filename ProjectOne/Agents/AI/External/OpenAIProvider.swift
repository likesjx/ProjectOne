//
//  OpenAIProvider.swift
//  ProjectOne
//
//  OpenAI API provider implementation
//

import Foundation
import os.log

/// OpenAI API provider
public class OpenAIProvider: ExternalAIProvider, @unchecked Sendable {
    
    // MARK: - Predefined Configurations
    
    public static func gpt4o(apiKey: String) -> OpenAIProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o",
            maxTokens: 4096,
            temperature: 0.7
        )
        return OpenAIProvider(configuration: config)
    }
    
    public static func gpt4oMini(apiKey: String) -> OpenAIProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-4o-mini",
            maxTokens: 4096,
            temperature: 0.7
        )
        return OpenAIProvider(configuration: config)
    }
    
    public static func gpt35Turbo(apiKey: String) -> OpenAIProvider {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://api.openai.com/v1",
            model: "gpt-3.5-turbo",
            maxTokens: 4096,
            temperature: 0.7
        )
        return OpenAIProvider(configuration: config)
    }
    
    // MARK: - Initialization
    
    public init(configuration: Configuration) {
        super.init(configuration: configuration, providerType: .openAI)
    }
    
    public convenience init(apiKey: String, model: String = "gpt-4o-mini") {
        let config = Configuration(
            apiKey: apiKey,
            baseURL: "https://api.openai.com/v1",
            model: model,
            maxTokens: 4096,
            temperature: 0.7
        )
        self.init(configuration: config)
    }
    
    // MARK: - OpenAI-Specific Features
    
    override func prepareModel() async throws {
        self.logger.info("Preparing OpenAI model: \(self.configuration.model)")
        
        guard self.configuration.apiKey != nil else {
            throw ExternalAIError.configurationInvalid("OpenAI API key required")
        }
        
        try await super.prepareModel()
    }
    
    /// Generate response with OpenAI-specific parameters
    public func generateWithFunctions(
        prompt: String,
        functions: [OpenAIFunction] = []
    ) async throws -> OpenAIFunctionResponse {
        guard case .ready = modelLoadingStatus else {
            throw ExternalAIError.modelNotReady
        }
        
        self.logger.info("Generating OpenAI response with functions")
        
        let request = OpenAIFunctionRequest(
            model: configuration.model,
            messages: [ChatMessage(role: "user", content: prompt)],
            functions: functions,
            maxTokens: configuration.maxTokens,
            temperature: configuration.temperature
        )
        
        do {
            return try await httpClient.sendFunctionRequest(request)
        } catch {
            logger.error("❌ OpenAI function generation failed: \(error.localizedDescription)")
            throw ExternalAIError.generationFailed(error.localizedDescription)
        }
    }
    
    /// Get available models from OpenAI
    public func getAvailableModels() async throws -> [OpenAIModel] {
        guard let url = URL(string: "\(configuration.baseURL)/models") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(configuration.apiKey ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ExternalAIError.networkError("Failed to fetch models")
        }
        
        let modelResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return modelResponse.data
    }
}

// MARK: - OpenAI-Specific Types

public struct OpenAIFunction: Codable {
    let name: String
    let description: String
    let parameters: [String: String] // Simplified to String values for Codable compliance
    
    public init(name: String, description: String, parameters: [String: String]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct OpenAIFunctionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let functions: [OpenAIFunction]?
    let maxTokens: Int
    let temperature: Double
    
    enum CodingKeys: String, CodingKey {
        case model, messages, functions, temperature
        case maxTokens = "max_tokens"
    }
}

public struct OpenAIFunctionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [OpenAIFunctionChoice]
    let usage: Usage?
}

public struct OpenAIFunctionChoice: Codable {
    let index: Int
    let message: OpenAIFunctionMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

public struct OpenAIFunctionMessage: Codable {
    let role: String
    let content: String?
    let functionCall: OpenAIFunctionCall?
    
    enum CodingKeys: String, CodingKey {
        case role, content
        case functionCall = "function_call"
    }
}

public struct OpenAIFunctionCall: Codable {
    let name: String
    let arguments: String
}

public struct OpenAIModel: Codable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id, object, created
        case ownedBy = "owned_by"
    }
}

public struct OpenAIModelsResponse: Codable {
    let object: String
    let data: [OpenAIModel]
}

// MARK: - HTTPClient Extension for OpenAI

extension HTTPClient {
    func sendFunctionRequest(_ request: OpenAIFunctionRequest) async throws -> OpenAIFunctionResponse {
        guard let url = URL(string: "\(configuration.baseURL)/chat/completions") else {
            throw ExternalAIError.configurationInvalid("Invalid base URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = configuration.apiKey {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw ExternalAIError.networkError("Request failed")
        }
        
        return try JSONDecoder().decode(OpenAIFunctionResponse.self, from: data)
    }
}