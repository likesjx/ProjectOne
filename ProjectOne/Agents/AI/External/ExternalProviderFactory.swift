//
//  ExternalProviderFactory.swift
//  ProjectOne
//
//  Factory for creating and managing external AI providers
//  Supports OpenAI, OpenRouter, Ollama, MLX, and other API-based services
//

import Foundation
import Combine
import os.log

/// Factory for creating and managing external AI providers
@MainActor
public class ExternalProviderFactory: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "ExternalProviderFactory")
    private let settings: AIProviderSettings
    
    // MARK: - Configuration Management
    
    public struct ProviderConfigurations {
        public var openAI: OpenAIConfig?
        public var openRouter: OpenRouterConfig?
        public var ollama: OllamaConfig?
        public var mlx: MLXConfig?
        public var anthropic: AnthropicConfig?
        public var custom: [String: CustomConfig]
        
        public init() {
            self.custom = [:]
        }
    }
    
    @Published public private(set) var activeProviders: [String: ExternalAIProvider] = [:]
    @Published public private(set) var providerStatus: [String: ProviderStatus] = [:]
    
    // MARK: - Provider Configuration Types
    
    public struct OpenAIConfig {
        public let apiKey: String
        public let model: String
        public let baseURL: String
        public let organizationId: String?
        
        public init(apiKey: String, model: String = "gpt-4o-mini", baseURL: String = "https://api.openai.com/v1", organizationId: String? = nil) {
            self.apiKey = apiKey
            self.model = model
            self.baseURL = baseURL
            self.organizationId = organizationId
        }
    }
    
    public struct OpenRouterConfig {
        public let apiKey: String
        public let model: String
        public let appName: String
        public let appURL: String
        public let routePreference: String
        
        public init(apiKey: String, model: String = "anthropic/claude-3-haiku:beta", appName: String = "ProjectOne", appURL: String = "https://projectone.app", routePreference: String = "balanced") {
            self.apiKey = apiKey
            self.model = model
            self.appName = appName
            self.appURL = appURL
            self.routePreference = routePreference
        }
    }
    
    public struct OllamaConfig {
        public let baseURL: String
        public let model: String
        public let autoDownload: Bool
        
        public init(baseURL: String = "http://localhost:11434", model: String = "llama3:8b", autoDownload: Bool = true) {
            self.baseURL = baseURL
            self.model = model
            self.autoDownload = autoDownload
        }
    }
    
    public struct MLXConfig {
        public let modelPath: String
        public let modelName: String
        public let vocabularyPath: String?
        public let quantization: Bool
        
        public init(modelPath: String, modelName: String, vocabularyPath: String? = nil, quantization: Bool = true) {
            self.modelPath = modelPath
            self.modelName = modelName
            self.vocabularyPath = vocabularyPath
            self.quantization = quantization
        }
    }
    
    public struct AnthropicConfig {
        public let apiKey: String
        public let model: String
        public let baseURL: String
        
        public init(apiKey: String, model: String = "claude-3-haiku-20240307", baseURL: String = "https://api.anthropic.com/v1") {
            self.apiKey = apiKey
            self.model = model
            self.baseURL = baseURL
        }
    }
    
    public struct CustomConfig {
        public let apiKey: String?
        public let baseURL: String
        public let model: String
        public let headers: [String: String]
        public let providerName: String
        
        public init(apiKey: String?, baseURL: String, model: String, headers: [String: String] = [:], providerName: String) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.model = model
            self.headers = headers
            self.providerName = providerName
        }
    }
    
    // MARK: - Provider Status
    
    public enum ProviderStatus {
        case notConfigured
        case configuring
        case ready
        case error(String)
        case unavailable(String)
    }
    
    // MARK: - Initialization
    
    public init(settings: AIProviderSettings = AIProviderSettings()) {
        self.settings = settings
    }
    
    // MARK: - Configuration Methods
    
    /// Configure all providers from settings
    public func configureFromSettings() async {
        logger.info("Configuring providers from settings")
        
        let configurations = settings.createExternalProviderConfigurations()
        
        // Configure each enabled provider
        if let config = configurations.openAI {
            await configureOpenAI(config)
        }
        
        if let config = configurations.openRouter {
            await configureOpenRouter(config)
        }
        
        if let config = configurations.ollama {
            await configureOllama(config)
        }
        
        if let config = configurations.mlx {
            await configureMLX(config)
        }
        
        if let config = configurations.anthropic {
            await configureAnthropic(config)
        }
    }
    
    public func configureOpenAI(_ config: OpenAIConfig) async {
        logger.info("Configuring OpenAI provider")
        configurations.openAI = config
        providerStatus["openai"] = .configuring
        
        do {
            let provider = createOpenAIProvider(config)
            try await provider.initialize()
            
            activeProviders["openai"] = provider
            providerStatus["openai"] = .ready
            
            logger.info("✅ OpenAI provider configured successfully")
        } catch {
            providerStatus["openai"] = .error(error.localizedDescription)
            logger.error("❌ OpenAI configuration failed: \(error.localizedDescription)")
        }
    }
    
    public func configureOpenRouter(_ config: OpenRouterConfig) async {
        logger.info("Configuring OpenRouter provider")
        configurations.openRouter = config
        providerStatus["openrouter"] = .configuring
        
        do {
            let provider = createOpenRouterProvider(config)
            try await provider.initialize()
            
            activeProviders["openrouter"] = provider
            providerStatus["openrouter"] = .ready
            
            logger.info("✅ OpenRouter provider configured successfully")
        } catch {
            providerStatus["openrouter"] = .error(error.localizedDescription)
            logger.error("❌ OpenRouter configuration failed: \(error.localizedDescription)")
        }
    }
    
    public func configureOllama(_ config: OllamaConfig) async {
        logger.info("Configuring Ollama provider")
        configurations.ollama = config
        providerStatus["ollama"] = .configuring
        
        do {
            let provider = createOllamaProvider(config)
            try await provider.initialize()
            
            activeProviders["ollama"] = provider
            providerStatus["ollama"] = .ready
            
            logger.info("✅ Ollama provider configured successfully")
        } catch {
            providerStatus["ollama"] = .error(error.localizedDescription)
            logger.error("❌ Ollama configuration failed: \(error.localizedDescription)")
        }
    }
    
    public func configureMLX(_ config: MLXConfig) async {
        logger.info("Configuring MLX provider")
        
        guard MLXProvider.isMLXSupported else {
            providerStatus["mlx"] = .unavailable("MLX requires Apple Silicon hardware")
            logger.warning("MLX not supported on this device")
            return
        }
        
        configurations.mlx = config
        providerStatus["mlx"] = .configuring
        
        do {
            let provider = createMLXProvider(config)
            try await provider.initialize()
            
            activeProviders["mlx"] = provider
            providerStatus["mlx"] = .ready
            
            logger.info("✅ MLX provider configured successfully")
        } catch {
            providerStatus["mlx"] = .error(error.localizedDescription)
            logger.error("❌ MLX configuration failed: \(error.localizedDescription)")
        }
    }
    
    public func configureAnthropic(_ config: AnthropicConfig) async {
        logger.info("Configuring Anthropic provider")
        providerStatus["anthropic"] = .configuring
        
        do {
            let provider = createAnthropicProvider(config)
            try await provider.initialize()
            
            activeProviders["anthropic"] = provider
            providerStatus["anthropic"] = .ready
            
            logger.info("✅ Anthropic provider configured successfully")
        } catch {
            providerStatus["anthropic"] = .error(error.localizedDescription)
            logger.error("❌ Anthropic configuration failed: \(error.localizedDescription)")
        }
    }
    
    public func configureCustomProvider(_ id: String, _ config: CustomConfig) async {
        logger.info("Configuring custom provider: \(id)")
        configurations.custom[id] = config
        providerStatus[id] = .configuring
        
        do {
            let provider = createCustomProvider(config)
            try await provider.initialize()
            
            activeProviders[id] = provider
            providerStatus[id] = .ready
            
            logger.info("✅ Custom provider \(id) configured successfully")
        } catch {
            providerStatus[id] = .error(error.localizedDescription)
            logger.error("❌ Custom provider \(id) configuration failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Provider Creation
    
    private func createOpenAIProvider(_ config: OpenAIConfig) -> OpenAIProvider {
        let providerConfig = ExternalAIProvider.Configuration(
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            model: config.model,
            customHeaders: config.organizationId.map { ["OpenAI-Organization": $0] } ?? [:]
        )
        return OpenAIProvider(configuration: providerConfig)
    }
    
    private func createOpenRouterProvider(_ config: OpenRouterConfig) -> OpenRouterProvider {
        let providerConfig = ExternalAIProvider.Configuration(
            apiKey: config.apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: config.model,
            customHeaders: [
                "HTTP-Referer": config.appURL,
                "X-Title": config.appName
            ]
        )
        return OpenRouterProvider(configuration: providerConfig)
    }
    
    private func createOllamaProvider(_ config: OllamaConfig) -> OllamaProvider {
        let providerConfig = ExternalAIProvider.Configuration(
            apiKey: nil,
            baseURL: config.baseURL,
            model: config.model
        )
        return OllamaProvider(configuration: providerConfig)
    }
    
    private func createMLXProvider(_ config: MLXConfig) -> MLXProvider? {
        let providerConfig = ExternalAIProvider.Configuration(
            apiKey: nil,
            baseURL: "local://mlx",
            model: config.modelName
        )
        
        let mlxConfig = MLXProvider.MLXConfiguration(
            modelPath: config.modelPath,
            vocabularyPath: config.vocabularyPath,
            enableQuantization: config.quantization
        )
        
        return MLXProvider(configuration: providerConfig, mlxConfig: mlxConfig)
    }
    
    private func createAnthropicProvider(_ config: AnthropicConfig) -> ExternalAIProvider {
        let providerConfig = ExternalAIProvider.Configuration(
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            model: config.model,
            customHeaders: ["anthropic-version": "2023-06-01"]
        )
        return ExternalAIProvider(
            configuration: providerConfig,
            providerType: .anthropic
        )
    }
    
    private func createCustomProvider(_ config: CustomConfig) -> ExternalAIProvider {
        let providerConfig = ExternalAIProvider.Configuration(
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            model: config.model,
            customHeaders: config.headers
        )
        return ExternalAIProvider(
            configuration: providerConfig,
            providerType: .custom(name: config.providerName, identifier: config.providerName.lowercased())
        )
    }
    
    // MARK: - Provider Access
    
    public func getProvider(_ id: String) -> ExternalAIProvider? {
        return activeProviders[id]
    }
    
    public func getAllActiveProviders() -> [ExternalAIProvider] {
        return Array(activeProviders.values)
    }
    
    public func getProvidersByCapability(_ capability: ProviderCapability) -> [ExternalAIProvider] {
        return activeProviders.values.compactMap { provider in
            guard hasCapability(provider, capability) else { return nil }
            return provider
        }
    }
    
    private func hasCapability(_ provider: ExternalAIProvider, _ capability: ProviderCapability) -> Bool {
        switch capability {
        case .textGeneration:
            return true // All providers support text generation
        case .codeGeneration:
            let codeModels = ["gpt-4", "claude-3", "codellama", "codegemma", "deepseek-coder"]
            return codeModels.contains { provider.configuration.model.lowercased().contains($0) }
        case .functionCalling:
            return provider is OpenAIProvider // Only OpenAI supports function calling in our implementation
        case .localInference:
            return provider is OllamaProvider || provider is MLXProvider
        case .streaming:
            return provider is OllamaProvider // Only Ollama supports streaming in our implementation
        }
    }
    
    // MARK: - Provider Management
    
    public func removeProvider(_ id: String) async {
        if let provider = activeProviders[id] {
            await provider.cleanup()
        }
        activeProviders.removeValue(forKey: id)
        providerStatus.removeValue(forKey: id)
        
        // Update settings to reflect removal
        settings.setProviderEnabled(id, enabled: false)
        
        logger.info("Removed provider: \(id)")
    }
    
    public func refreshProvider(_ id: String) async {
        guard let provider = activeProviders[id] else { return }
        
        logger.info("Refreshing provider: \(id)")
        providerStatus[id] = .configuring
        
        do {
            try await provider.initialize()
            providerStatus[id] = .ready
            logger.info("✅ Provider \(id) refreshed successfully")
        } catch {
            providerStatus[id] = .error(error.localizedDescription)
            logger.error("❌ Provider \(id) refresh failed: \(error.localizedDescription)")
        }
    }
    
    public func refreshAllProviders() async {
        logger.info("Refreshing all providers")
        
        await withTaskGroup(of: Void.self) { group in
            for id in activeProviders.keys {
                group.addTask {
                    await self.refreshProvider(id)
                }
            }
        }
        
        logger.info("All providers refreshed")
    }
    
    // MARK: - Cleanup
    
    public func cleanup() async {
        logger.info("Cleaning up all providers")
        
        await withTaskGroup(of: Void.self) { group in
            for provider in activeProviders.values {
                group.addTask {
                    await provider.cleanup()
                }
            }
        }
        
        activeProviders.removeAll()
        providerStatus.removeAll()
        settings.resetToDefaults()
        
        logger.info("All providers cleaned up")
    }
}

// MARK: - Supporting Types

public enum ProviderCapability {
    case textGeneration
    case codeGeneration
    case functionCalling
    case localInference
    case streaming
}

// MARK: - Convenience Extensions

extension ExternalProviderFactory {
    
    /// Configure providers automatically from current settings
    public func autoConfigureFromSettings() async {
        await configureFromSettings()
    }
    
    /// Get current settings instance
    public func getSettings() -> AIProviderSettings {
        return settings
    }
    
    /// Get the best available provider for a specific use case
    public func getBestProviderFor(_ useCase: UseCase) -> ExternalAIProvider? {
        switch useCase {
        case .coding:
            return getProvider("openai") ?? getProvider("anthropic") ?? getProvider("ollama")
        case .chat:
            return getProvider("openrouter") ?? getProvider("openai") ?? getProvider("ollama")
        case .privacy:
            return getProvider("ollama") ?? getProvider("mlx")
        case .speed:
            return getProvider("mlx") ?? getProvider("ollama") ?? getProvider("openai")
        case .quality:
            return getProvider("openai") ?? getProvider("openrouter") ?? getProvider("anthropic")
        }
    }
}

public enum UseCase {
    case coding
    case chat
    case privacy
    case speed
    case quality
}