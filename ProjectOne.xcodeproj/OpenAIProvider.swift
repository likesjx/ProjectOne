import Foundation

public final class OpenAIProvider: ExternalAIProvider {
    public convenience init(apiKey: String, model: String = "gpt-4o-mini", baseURL: String = "https://api.openai.com/v1") {
        let config = ExternalAIProvider.Configuration(
            apiKey: apiKey,
            baseURL: baseURL,
            model: model
        )
        self.init(configuration: config, providerType: .openAI)
    }
    
    // Convenience factory used by APIKeyManager
    public static func gpt4o(apiKey: String) -> OpenAIProvider {
        return OpenAIProvider(apiKey: apiKey, model: "gpt-4o-mini")
    }
}
