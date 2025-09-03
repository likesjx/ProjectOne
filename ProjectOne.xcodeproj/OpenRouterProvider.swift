import Foundation

public final class OpenRouterProvider: ExternalAIProvider {
    public convenience init(apiKey: String, model: String = "anthropic/claude-3-haiku:beta") {
        let config = ExternalAIProvider.Configuration(
            apiKey: apiKey,
            baseURL: "https://openrouter.ai/api/v1",
            model: model
        )
        self.init(configuration: config, providerType: .openRouter)
    }
    
    // Convenience factory used by APIKeyManager
    public static func claude3Sonnet(apiKey: String) -> OpenRouterProvider {
        return OpenRouterProvider(apiKey: apiKey, model: "anthropic/claude-3-sonnet")
    }
}
