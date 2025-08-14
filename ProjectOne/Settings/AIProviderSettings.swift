//
//  AIProviderSettings.swift
//  ProjectOne
//
//  Settings management for AI provider configurations
//  Handles API keys, provider preferences, and security
//

import Foundation
import SwiftUI
import Security
import Combine

// Import AI provider types
// Note: Using forward declarations to avoid circular imports

/// Settings manager for AI providers with secure keychain storage
@MainActor
public class AIProviderSettings: ObservableObject {
    
    // MARK: - Published Settings
    
    @Published public var enabledProviders: Set<String> = []
    @Published public var preferredProvider: String = "apple-foundation-models"
    @Published public var fallbackEnabled: Bool = true
    @Published public var privacyMode: PrivacyMode = .balanced
    
    // OpenAI Settings
    @Published public var openAIModel: String = "gpt-4o-mini"
    @Published public var openAIOrganization: String = ""
    @Published public var openAIBaseURL: String = "https://api.openai.com/v1"
    
    // OpenRouter Settings  
    @Published public var openRouterModel: String = "anthropic/claude-3-haiku:beta"
    @Published public var openRouterAppName: String = "ProjectOne"
    @Published public var openRouterAppURL: String = "https://projectone.app"
    @Published public var openRouterRoutePreference: String = "balanced"
    
    // Ollama Settings
    @Published public var ollamaBaseURL: String = "http://localhost:11434"
    @Published public var ollamaModel: String = "llama3:8b"
    @Published public var ollamaAutoDownload: Bool = true
    
    // MLX Settings
    @Published public var mlxModelPath: String = "~/mlx-models"
    @Published public var mlxModelName: String = "llama-3-8b"
    @Published public var mlxQuantization: Bool = true
    
    // MLX Audio Settings
    @Published public var mlxAudioModelPath: String = "~/mlx-models/audio"
    @Published public var mlxAudioModelName: String = "whisper-large-v3"
    @Published public var enableDirectAudioProcessing: Bool = true
    @Published public var audioQualityThreshold: Double = 0.7
    @Published public var maxAudioDuration: Double = 60.0
    
    // Anthropic Settings
    @Published public var anthropicModel: String = "claude-3-haiku-20240307"
    @Published public var anthropicBaseURL: String = "https://api.anthropic.com/v1"
    
    // General Settings
    @Published public var maxTokens: Int = 4096
    @Published public var temperature: Double = 0.7
    @Published public var requestTimeout: Double = 60.0
    @Published public var maxRetries: Int = 3
    
    // MARK: - Keychain Keys
    
    private enum KeychainKey: String, CaseIterable {
        case openAIAPIKey = "openai_api_key"
        case openRouterAPIKey = "openrouter_api_key"  
        case anthropicAPIKey = "anthropic_api_key"
        case customAPIKeys = "custom_api_keys"
        
        var service: String { "com.jaredlikes.ProjectOne.AIProviders" }
        var account: String { self.rawValue }
    }
    
    // MARK: - Privacy Mode
    
    public enum PrivacyMode: String, CaseIterable {
        case maximum = "maximum"     // Only on-device (Apple, MLX, Ollama)
        case balanced = "balanced"   // Prefer on-device, allow API with consent
        case performance = "performance" // Best performance, API allowed
        
        public var displayName: String {
            switch self {
            case .maximum: return "Maximum Privacy"
            case .balanced: return "Balanced"
            case .performance: return "Best Performance"
            }
        }
        
        public var description: String {
            switch self {
            case .maximum: return "Only on-device processing"
            case .balanced: return "Prefer on-device, allow external with consent"
            case .performance: return "Use best available model"
            }
        }
    }
    
    // MARK: - Keychain Service
    
    private let keychainService = KeychainService()
    private let userDefaults = UserDefaults(suiteName: "group.com.jaredlikes.ProjectOne.AIProviders") ?? .standard
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
    }
    
    // MARK: - API Key Management
    
    public func setAPIKey(_ key: String, for provider: APIProvider) throws {
        guard !key.isEmpty else {
            try removeAPIKey(for: provider)
            return
        }
        
        let keychainKey = getKeychainKey(for: provider)
        try keychainService.store(key, forKey: keychainKey.account, service: keychainKey.service)
        
        // Add to enabled providers when key is set
        enabledProviders.insert(provider.identifier)
        saveSettings()
    }
    
    public func getAPIKey(for provider: APIProvider) -> String? {
        let keychainKey = getKeychainKey(for: provider)
        return try? keychainService.retrieve(forKey: keychainKey.account, service: keychainKey.service)
    }
    
    public func removeAPIKey(for provider: APIProvider) throws {
        let keychainKey = getKeychainKey(for: provider)
        try keychainService.remove(forKey: keychainKey.account, service: keychainKey.service)
        
        // Remove from enabled providers when key is removed
        enabledProviders.remove(provider.identifier)
        saveSettings()
    }
    
    public func hasAPIKey(for provider: APIProvider) -> Bool {
        return getAPIKey(for: provider) != nil
    }
    
    // MARK: - Custom Provider Management
    
    public func setCustomAPIKey(_ key: String, for providerId: String) throws {
        var customKeys = getCustomAPIKeys()
        
        if key.isEmpty {
            customKeys.removeValue(forKey: providerId)
        } else {
            customKeys[providerId] = key
        }
        
        let data = try JSONEncoder().encode(customKeys)
        let keyString = String(data: data, encoding: .utf8) ?? "{}"
        
        try keychainService.store(keyString, forKey: KeychainKey.customAPIKeys.account, service: KeychainKey.customAPIKeys.service)
        saveSettings()
    }
    
    public func getCustomAPIKey(for providerId: String) -> String? {
        return getCustomAPIKeys()[providerId]
    }
    
    private func getCustomAPIKeys() -> [String: String] {
        guard let keyString = try? keychainService.retrieve(forKey: KeychainKey.customAPIKeys.account, service: KeychainKey.customAPIKeys.service),
              let data = keyString.data(using: .utf8),
              let keys = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return keys
    }
    
    // MARK: - Provider Status
    
    public func isProviderEnabled(_ provider: String) -> Bool {
        return enabledProviders.contains(provider)
    }
    
    public func setProviderEnabled(_ provider: String, enabled: Bool) {
        if enabled {
            enabledProviders.insert(provider)
        } else {
            enabledProviders.remove(provider)
        }
        saveSettings()
    }
    
    public func getEnabledProviders() -> [String] {
        return Array(enabledProviders)
    }
    
    // MARK: - Configuration Generation
    
    public func createExternalProviderConfigurations() -> ExternalProviderFactory.ProviderConfigurations {
        var configs = ExternalProviderFactory.ProviderConfigurations()
        
        // OpenAI Configuration
        if isProviderEnabled("openai"), let apiKey = getAPIKey(for: .openAI) {
            configs.openAI = ExternalProviderFactory.OpenAIConfig(
                apiKey: apiKey,
                model: openAIModel,
                baseURL: openAIBaseURL,
                organizationId: openAIOrganization.isEmpty ? nil : openAIOrganization
            )
        }
        
        // OpenRouter Configuration
        if isProviderEnabled("openrouter"), let apiKey = getAPIKey(for: .openRouter) {
            configs.openRouter = ExternalProviderFactory.OpenRouterConfig(
                apiKey: apiKey,
                model: openRouterModel,
                appName: openRouterAppName,
                appURL: openRouterAppURL,
                routePreference: openRouterRoutePreference
            )
        }
        
        // Ollama Configuration  
        if isProviderEnabled("ollama") {
            configs.ollama = ExternalProviderFactory.OllamaConfig(
                baseURL: ollamaBaseURL,
                model: ollamaModel,
                autoDownload: ollamaAutoDownload
            )
        }
        
        // MLX Configuration
        if isProviderEnabled("mlx") && MLXProvider.isMLXSupported {
            configs.mlx = ExternalProviderFactory.MLXConfig(
                modelPath: NSString(string: mlxModelPath).expandingTildeInPath,
                modelName: mlxModelName,
                quantization: mlxQuantization
            )
        }
        
        // Anthropic Configuration
        if isProviderEnabled("anthropic"), let apiKey = getAPIKey(for: .anthropic) {
            configs.anthropic = ExternalProviderFactory.AnthropicConfig(
                apiKey: apiKey,
                model: anthropicModel,
                baseURL: anthropicBaseURL
            )
        }
        
        return configs
    }
    
    // MARK: - Settings Persistence
    
    private func saveSettings() {
        userDefaults.set(Array(enabledProviders), forKey: "enabledProviders")
        userDefaults.set(preferredProvider, forKey: "preferredProvider")
        userDefaults.set(fallbackEnabled, forKey: "fallbackEnabled")
        userDefaults.set(privacyMode.rawValue, forKey: "privacyMode")
        
        userDefaults.set(openAIModel, forKey: "openAIModel")
        userDefaults.set(openAIOrganization, forKey: "openAIOrganization")
        userDefaults.set(openAIBaseURL, forKey: "openAIBaseURL")
        
        userDefaults.set(openRouterModel, forKey: "openRouterModel")
        userDefaults.set(openRouterAppName, forKey: "openRouterAppName")
        userDefaults.set(openRouterAppURL, forKey: "openRouterAppURL")
        userDefaults.set(openRouterRoutePreference, forKey: "openRouterRoutePreference")
        
        userDefaults.set(ollamaBaseURL, forKey: "ollamaBaseURL")
        userDefaults.set(ollamaModel, forKey: "ollamaModel")
        userDefaults.set(ollamaAutoDownload, forKey: "ollamaAutoDownload")
        
        userDefaults.set(mlxModelPath, forKey: "mlxModelPath")
        userDefaults.set(mlxModelName, forKey: "mlxModelName")
        userDefaults.set(mlxQuantization, forKey: "mlxQuantization")
        
        userDefaults.set(mlxAudioModelPath, forKey: "mlxAudioModelPath")
        userDefaults.set(mlxAudioModelName, forKey: "mlxAudioModelName")
        userDefaults.set(enableDirectAudioProcessing, forKey: "enableDirectAudioProcessing")
        userDefaults.set(audioQualityThreshold, forKey: "audioQualityThreshold")
        userDefaults.set(maxAudioDuration, forKey: "maxAudioDuration")
        
        userDefaults.set(anthropicModel, forKey: "anthropicModel")
        userDefaults.set(anthropicBaseURL, forKey: "anthropicBaseURL")
        
        userDefaults.set(maxTokens, forKey: "maxTokens")
        userDefaults.set(temperature, forKey: "temperature")
        userDefaults.set(requestTimeout, forKey: "requestTimeout")
        userDefaults.set(maxRetries, forKey: "maxRetries")
    }
    
    private func loadSettings() {
        enabledProviders = Set(userDefaults.array(forKey: "enabledProviders") as? [String] ?? ["apple-foundation-models", "mlx"])
        preferredProvider = userDefaults.string(forKey: "preferredProvider") ?? "apple-foundation-models"
        fallbackEnabled = userDefaults.object(forKey: "fallbackEnabled") as? Bool ?? true
        privacyMode = PrivacyMode(rawValue: userDefaults.string(forKey: "privacyMode") ?? "balanced") ?? .balanced
        
        openAIModel = userDefaults.string(forKey: "openAIModel") ?? "gpt-4o-mini"
        openAIOrganization = userDefaults.string(forKey: "openAIOrganization") ?? ""
        openAIBaseURL = userDefaults.string(forKey: "openAIBaseURL") ?? "https://api.openai.com/v1"
        
        openRouterModel = userDefaults.string(forKey: "openRouterModel") ?? "anthropic/claude-3-haiku:beta"
        openRouterAppName = userDefaults.string(forKey: "openRouterAppName") ?? "ProjectOne"
        openRouterAppURL = userDefaults.string(forKey: "openRouterAppURL") ?? "https://projectone.app"
        openRouterRoutePreference = userDefaults.string(forKey: "openRouterRoutePreference") ?? "balanced"
        
        ollamaBaseURL = userDefaults.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
        ollamaModel = userDefaults.string(forKey: "ollamaModel") ?? "llama3:8b"
        ollamaAutoDownload = userDefaults.object(forKey: "ollamaAutoDownload") as? Bool ?? true
        
        mlxModelPath = userDefaults.string(forKey: "mlxModelPath") ?? "~/mlx-models"
        mlxModelName = userDefaults.string(forKey: "mlxModelName") ?? "llama-3-8b"
        mlxQuantization = userDefaults.object(forKey: "mlxQuantization") as? Bool ?? true
        
        mlxAudioModelPath = userDefaults.string(forKey: "mlxAudioModelPath") ?? "~/mlx-models/audio"
        mlxAudioModelName = userDefaults.string(forKey: "mlxAudioModelName") ?? "whisper-large-v3"
        enableDirectAudioProcessing = userDefaults.object(forKey: "enableDirectAudioProcessing") as? Bool ?? true
        audioQualityThreshold = userDefaults.object(forKey: "audioQualityThreshold") as? Double ?? 0.7
        maxAudioDuration = userDefaults.object(forKey: "maxAudioDuration") as? Double ?? 60.0
        
        anthropicModel = userDefaults.string(forKey: "anthropicModel") ?? "claude-3-haiku-20240307"
        anthropicBaseURL = userDefaults.string(forKey: "anthropicBaseURL") ?? "https://api.anthropic.com/v1"
        
        maxTokens = userDefaults.object(forKey: "maxTokens") as? Int ?? 4096
        temperature = userDefaults.object(forKey: "temperature") as? Double ?? 0.7
        requestTimeout = userDefaults.object(forKey: "requestTimeout") as? Double ?? 60.0
        maxRetries = userDefaults.object(forKey: "maxRetries") as? Int ?? 3
    }
    
    // MARK: - Helper Methods
    
    private func getKeychainKey(for provider: APIProvider) -> KeychainKey {
        switch provider {
        case .openAI: return .openAIAPIKey
        case .openRouter: return .openRouterAPIKey
        case .anthropic: return .anthropicAPIKey
        }
    }
    
    // MARK: - Reset Methods
    
    public func resetToDefaults() {
        // Clear all API keys
        for provider in APIProvider.allCases {
            try? removeAPIKey(for: provider)
        }
        
        // Clear custom keys
        try? keychainService.remove(forKey: KeychainKey.customAPIKeys.account, service: KeychainKey.customAPIKeys.service)
        
        // Reset to defaults
        enabledProviders = ["apple-foundation-models"]
        preferredProvider = "apple-foundation-models"
        fallbackEnabled = true
        privacyMode = .balanced
        
        openAIModel = "gpt-4o-mini"
        openAIOrganization = ""
        openAIBaseURL = "https://api.openai.com/v1"
        
        openRouterModel = "anthropic/claude-3-haiku:beta"
        openRouterAppName = "ProjectOne"
        openRouterAppURL = "https://projectone.app"
        openRouterRoutePreference = "balanced"
        
        ollamaBaseURL = "http://localhost:11434"
        ollamaModel = "llama3:8b"
        ollamaAutoDownload = true
        
        mlxModelPath = "~/mlx-models"
        mlxModelName = "llama-3-8b"
        mlxQuantization = true
        
        mlxAudioModelPath = "~/mlx-models/audio"
        mlxAudioModelName = "whisper-large-v3"
        enableDirectAudioProcessing = true
        audioQualityThreshold = 0.7
        maxAudioDuration = 60.0
        
        anthropicModel = "claude-3-haiku-20240307"
        anthropicBaseURL = "https://api.anthropic.com/v1"
        
        maxTokens = 4096
        temperature = 0.7
        requestTimeout = 60.0
        maxRetries = 3
        
        saveSettings()
    }
    
    public func exportSettings() -> [String: Any] {
        return [
            "enabledProviders": Array(enabledProviders),
            "preferredProvider": preferredProvider,
            "fallbackEnabled": fallbackEnabled,
            "privacyMode": privacyMode.rawValue,
            "openAIModel": openAIModel,
            "openRouterModel": openRouterModel,
            "ollamaBaseURL": ollamaBaseURL,
            "ollamaModel": ollamaModel,
            "mlxModelPath": mlxModelPath,
            "mlxModelName": mlxModelName,
            "maxTokens": maxTokens,
            "temperature": temperature
        ]
    }
}

// MARK: - Supporting Types

public enum APIProvider: String, CaseIterable {
    case openAI = "openai"
    case openRouter = "openrouter"
    case anthropic = "anthropic"
    
    public var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .openRouter: return "OpenRouter"
        case .anthropic: return "Anthropic"
        }
    }
    
    public var identifier: String {
        return self.rawValue
    }
}

// MARK: - Keychain Service

private class KeychainService {
    
    func store(_ value: String, forKey key: String, service: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    func retrieve(forKey key: String, service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return string
    }
    
    func remove(forKey key: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - Keychain Error

private enum KeychainError: Error {
    case unhandledError(status: OSStatus)
    case unexpectedPasswordData
    
    var localizedDescription: String {
        switch self {
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        case .unexpectedPasswordData:
            return "Unexpected keychain data format"
        }
    }
}