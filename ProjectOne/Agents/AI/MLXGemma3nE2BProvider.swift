
import Foundation
import os.log

#if canImport(MLXLLM)
import MLXLLM
#endif

/// A concrete AI provider that uses the MLXLLM library to run a Gemma-3n model locally.
public class MLXGemma3nE2BProvider: BaseAIProvider {

    private var session: ChatSession?
    private let modelId: String

    public override var identifier: String { "mlx-gemma-3n-e2b-llm" }
    public override var displayName: String { "MLX Gemma 3n E2B (LLM)" }
    public override var isAvailable: Bool { session != nil }

    public init(modelId: String = "mlx-community/gemma-3n-E2B-it-4bit") {
        self.modelId = modelId
        super.init(subsystem: "com.jaredlikes.ProjectOne", category: "MLXGemma3nE2BProvider")
    }

    public override func prepareModel() async throws {
        #if canImport(MLXLLM)
        logger.info("Preparing MLXLLM model: \(self.modelId)")
        do {
            let model = try await MLXLLM.loadModel(id: modelId)
            self.session = ChatSession(model: model)
            logger.info("MLXLLM model \(self.modelId) loaded successfully.")
        } catch {
            logger.error("Failed to load MLXLLM model: \(error.localizedDescription)")
            throw AIModelProviderError.modelNotLoaded
        }
        #else
        logger.error("MLXLLM framework not available at compile time.")
        throw AIModelProviderError.providerUnavailable("MLXLLM framework not available")
        #endif
    }

    public override func generateModelResponse(_ prompt: String) async throws -> String {
        guard let session = session else {
            throw AIModelProviderError.modelNotLoaded
        }

        #if canImport(MLXLLM)
        do {
            let response = try await session.respond(to: prompt)
            return response
        } catch {
            logger.error("Failed to generate response from MLXLLM: \(error.localizedDescription)")
            throw AIModelProviderError.inferenceFailed(error)
        }
        #else
        throw AIModelProviderError.providerUnavailable("MLXLLM framework not available")
        #endif
    }

    public override func cleanupModel() async {
        self.session = nil
        logger.info("MLXLLM session cleaned up.")
    }
}
