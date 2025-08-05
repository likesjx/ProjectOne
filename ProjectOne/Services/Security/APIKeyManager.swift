//
//  APIKeyManager.swift
//  ProjectOne
//
//  Secure API key management system for external AI providers
//  Uses iOS/macOS Keychain for secure storage with encryption
//

import Foundation
import Security
import os.log

/// Secure API key management for external AI providers
@MainActor
public class APIKeyManager: ObservableObject {
    
    // MARK: - Types
    
    public enum Provider: String, CaseIterable {
        case openAI = "openai"
        case openRouter = "openrouter"
        case ollama = "ollama"
        
        var displayName: String {
            switch self {
            case .openAI: return "OpenAI"
            case .openRouter: return "OpenRouter"
            case .ollama: return "Ollama"
            }
        }
        
        var keychainKey: String {
            return "com.projectone.apikey.\(rawValue)"
        }
        
        var urlKey: String {
            return "com.projectone.baseurl.\(rawValue)"
        }
    }
    
    public enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case invalidData
        case unexpectedPasswordData
        case unhandledError(status: OSStatus)
        
        public var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "API key not found"
            case .invalidData:
                return "Invalid keychain data"
            case .unexpectedPasswordData:
                return "Unexpected password data format"
            case .unhandledError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "ProjectOne", category: "APIKeyManager")
    
    @Published public var availableProviders: Set<Provider> = []
    @Published public var configurationStatus: [Provider: Bool] = [:]
    
    // MARK: - Singleton
    
    public static let shared = APIKeyManager()
    
    private init() {
        loadConfigurationStatus()
    }
    
    // MARK: - Public API
    
    /// Store an API key securely in the keychain
    public func storeAPIKey(_ key: String, for provider: Provider) throws {
        guard !key.isEmpty else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.keychainKey,
            kSecValueData as String: key.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to update existing item first
        let updateStatus = SecItemUpdate(
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrAccount as String: provider.keychainKey] as CFDictionary,
            [kSecValueData as String: key.data(using: .utf8)!] as CFDictionary
        )
        
        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, create new one
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                logger.error("❌ Failed to store API key for \(provider.displayName): \(status)")
                throw KeychainError.unhandledError(status: status)
            }
        } else if updateStatus != errSecSuccess {
            logger.error("❌ Failed to update API key for \(provider.displayName): \(updateStatus)")
            throw KeychainError.unhandledError(status: updateStatus)
        }
        
        logger.info("✅ Successfully stored API key for \(provider.displayName)")
        updateConfigurationStatus()
    }
    
    /// Store a base URL securely in the keychain (for Ollama)
    public func storeBaseURL(_ url: String, for provider: Provider) throws {
        guard !url.isEmpty else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.urlKey,
            kSecValueData as String: url.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to update existing item first
        let updateStatus = SecItemUpdate(
            [kSecClass as String: kSecClassGenericPassword,
             kSecAttrAccount as String: provider.urlKey] as CFDictionary,
            [kSecValueData as String: url.data(using: .utf8)!] as CFDictionary
        )
        
        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, create new one
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                logger.error("❌ Failed to store base URL for \(provider.displayName): \(status)")
                throw KeychainError.unhandledError(status: status)
            }
        } else if updateStatus != errSecSuccess {
            logger.error("❌ Failed to update base URL for \(provider.displayName): \(updateStatus)")
            throw KeychainError.unhandledError(status: updateStatus)
        }
        
        logger.info("✅ Successfully stored base URL for \(provider.displayName)")
        updateConfigurationStatus()
    }
    
    /// Retrieve an API key from the keychain
    public func getAPIKey(for provider: Provider) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            logger.error("❌ Failed to retrieve API key for \(provider.displayName): \(status)")
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = dataTypeRef as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return key
    }
    
    /// Retrieve a base URL from the keychain
    public func getBaseURL(for provider: Provider) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.urlKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            logger.error("❌ Failed to retrieve base URL for \(provider.displayName): \(status)")
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = dataTypeRef as? Data,
              let url = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedPasswordData
        }
        
        return url
    }
    
    /// Remove an API key from the keychain
    public func removeAPIKey(for provider: Provider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.keychainKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("❌ Failed to remove API key for \(provider.displayName): \(status)")
            throw KeychainError.unhandledError(status: status)
        }
        
        logger.info("✅ Successfully removed API key for \(provider.displayName)")
        updateConfigurationStatus()
    }
    
    /// Remove a base URL from the keychain
    public func removeBaseURL(for provider: Provider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: provider.urlKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("❌ Failed to remove base URL for \(provider.displayName): \(status)")
            throw KeychainError.unhandledError(status: status)
        }
        
        logger.info("✅ Successfully removed base URL for \(provider.displayName)")
        updateConfigurationStatus()
    }
    
    /// Check if a provider is configured with valid credentials
    public func isConfigured(_ provider: Provider) -> Bool {
        switch provider {
        case .openAI, .openRouter:
            return (try? getAPIKey(for: provider)) != nil
        case .ollama:
            return (try? getBaseURL(for: provider)) != nil
        }
    }
    
    /// Get all configured providers
    public func getConfiguredProviders() -> Set<Provider> {
        return Set(Provider.allCases.filter { isConfigured($0) })
    }
    
    /// Validate an API key format (basic validation)
    public func validateAPIKey(_ key: String, for provider: Provider) -> Bool {
        guard !key.isEmpty else { return false }
        
        switch provider {
        case .openAI:
            return key.hasPrefix("sk-") && key.count > 20
        case .openRouter:
            return key.hasPrefix("sk-or-") && key.count > 20
        case .ollama:
            return true // Ollama doesn't use API keys, only base URL
        }
    }
    
    /// Validate a base URL format
    public func validateBaseURL(_ url: String) -> Bool {
        guard !url.isEmpty else { return false }
        return URL(string: url) != nil && (url.hasPrefix("http://") || url.hasPrefix("https://"))
    }
    
    // MARK: - Private Methods
    
    private func loadConfigurationStatus() {
        for provider in Provider.allCases {
            configurationStatus[provider] = isConfigured(provider)
        }
        availableProviders = getConfiguredProviders()
    }
    
    private func updateConfigurationStatus() {
        loadConfigurationStatus()
    }
    
    // MARK: - Convenience Methods for AI Providers
    
    /// Create an OpenAI provider with stored credentials
    public func createOpenAIProvider() throws -> OpenAIProvider? {
        guard let apiKey = try getAPIKey(for: .openAI) else {
            return nil
        }
        return OpenAIProvider.gpt4o(apiKey: apiKey)
    }
    
    /// Create an OpenRouter provider with stored credentials
    public func createOpenRouterProvider() throws -> OpenRouterProvider? {
        guard let apiKey = try getAPIKey(for: .openRouter) else {
            return nil
        }
        return OpenRouterProvider.claude3Sonnet(apiKey: apiKey)
    }
    
    /// Create an Ollama provider with stored configuration
    public func createOllamaProvider() throws -> OllamaProvider? {
        guard let _ = try getBaseURL(for: .ollama) else {
            return nil
        }
        // Note: OllamaProvider would need to be updated to accept baseURL parameter
        // For now, we create a default provider and assume it will be configured separately
        return OllamaProvider(model: "llama3:8b")
    }
}

// MARK: - Extension for UserDefaults fallback (non-sensitive data)

extension APIKeyManager {
    
    /// Store non-sensitive configuration in UserDefaults
    private func storeConfiguration<T>(_ value: T, forKey key: String) where T: Codable {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    /// Retrieve non-sensitive configuration from UserDefaults
    private func getConfiguration<T>(_ type: T.Type, forKey key: String) -> T? where T: Codable {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}