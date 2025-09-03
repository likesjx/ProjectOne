import Foundation

public final class OllamaProvider: ExternalAIProvider {
    public convenience init(model: String = "llama3:8b", baseURL: String = "http://localhost:11434") {
        let config = ExternalAIProvider.Configuration(
            apiKey: nil,
            baseURL: baseURL,
            model: model
        )
        self.init(configuration: config, providerType: .ollama)
    }
}
