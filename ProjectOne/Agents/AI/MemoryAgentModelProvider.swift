//
//  MemoryAgentModelProvider.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/16/25.
//

import Foundation
import os.log

/// High-level orchestrator for AI model providers that manages context,
/// provider selection, fallbacks, and response processing for the Memory Agent
public class MemoryAgentModelProvider {
    
    // MARK: - Dependencies
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryAgentModelProvider")
    private let contextManager: MemoryContextManager
    private let providerSelector: AIProviderSelector
    private let responseProcessor: ResponseProcessor
    
    // MARK: - Provider Registry
    
    private var externalProviderFactory: ExternalProviderFactory?
    private var appleFoundationProvider: AppleFoundationModelsProvider?
    private var providerHealth: [String: ProviderHealthStatus] = [:]
    
    // MARK: - Configuration
    
    public struct Configuration {
        let maxRetries: Int
        let fallbackEnabled: Bool
        let healthMonitoringEnabled: Bool
        let responseTimeoutInterval: TimeInterval
        
        public static let `default` = Configuration(
            maxRetries: 3,
            fallbackEnabled: true,
            healthMonitoringEnabled: true,
            responseTimeoutInterval: 30.0
        )
    }
    
    private let configuration: Configuration
    
    // MARK: - Initialization
    
    public init(
        configuration: Configuration = .default,
        contextManager: MemoryContextManager? = nil,
        providerSelector: AIProviderSelector? = nil,
        responseProcessor: ResponseProcessor? = nil
    ) {
        self.configuration = configuration
        self.contextManager = contextManager ?? MemoryContextManager()
        self.providerSelector = providerSelector ?? AIProviderSelector()
        self.responseProcessor = responseProcessor ?? ResponseProcessor()
        
        logger.info("MemoryAgentModelProvider initialized")
    }
    
    // MARK: - Provider Management
    
    /// Register external provider factory
    public func registerExternalProviderFactory(_ factory: ExternalProviderFactory) {
        self.externalProviderFactory = factory
        logger.info("Registered external provider factory")
    }
    
    /// Register Apple Foundation Models provider
    @available(iOS 26.0, macOS 26.0, *)
    public func registerAppleFoundationProvider(_ provider: AppleFoundationModelsProvider) {
        self.appleFoundationProvider = provider
        providerHealth["apple_foundation"] = ProviderHealthStatus(
            isHealthy: true,
            lastSuccessfulResponse: nil,
            consecutiveFailures: 0,
            averageResponseTime: 1.0, // On-device is fast
            errorRate: 0.0
        )
        logger.info("Registered Apple Foundation Models provider")
    }
    
    
    /// Initialize all registered providers
    public func initializeProviders() async throws {
        logger.info("Initializing AI providers")
        
        var hasHealthyProvider = false
        
        // Wait for Apple Foundation Models to be ready
        if #available(iOS 26.0, macOS 26.0, *), appleFoundationProvider != nil {
            logger.info("Waiting for Apple Foundation Models to be ready...")
            // Give Apple Foundation Models time to initialize
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        // Initialize external providers through factory
        if let factory = externalProviderFactory {
            await factory.configureFromSettings()
            logger.info("External providers initialized successfully")
            hasHealthyProvider = true
        }
        
        // Initialize Apple Foundation Models if available
        if #available(iOS 26.0, macOS 26.0, *), let appleProvider = appleFoundationProvider {
            do {
                try await appleProvider.prepare()
                logger.info("Apple Foundation Models initialized successfully")
                hasHealthyProvider = true
            } catch {
                logger.error("Failed to initialize Apple Foundation Models: \(error.localizedDescription)")
                providerHealth["apple_foundation"] = ProviderHealthStatus(
                    isHealthy: false,
                    lastSuccessfulResponse: nil,
                    consecutiveFailures: 1,
                    averageResponseTime: 1.0,
                    errorRate: 1.0
                )
            }
        }
        
        
        if !hasHealthyProvider {
            throw MemoryAgentError.noAIProvidersAvailable
        }
        
        logger.info("Provider initialization complete")
    }
    
    /// Cleanup all providers
    public func cleanup() async {
        logger.info("Cleaning up AI providers")
        
        await withTaskGroup(of: Void.self) { group in
            if let factory = externalProviderFactory {
                group.addTask {
                    await factory.cleanup()
                }
            }
            
            if #available(iOS 26.0, macOS 26.0, *), let appleProvider = appleFoundationProvider {
                group.addTask {
                    await appleProvider.cleanup()
                }
            }
        }
        
        externalProviderFactory = nil
        appleFoundationProvider = nil
        providerHealth.removeAll()
    }
    
    // MARK: - Main API
    
    /// Generate AI response with intelligent provider selection and fallback
    public func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse {
        // 1. Optimize and validate context
        let optimizedContext = try await contextManager.optimize(context)
        
        // 2. Determine selection criteria based on context
        let criteria = buildSelectionCriteria(for: optimizedContext)
        
        // 3. Generate with provider selection and fallback (with retry for model loading)
        let response = try await generateWithRetry(
            prompt: prompt,
            context: optimizedContext,
            criteria: criteria
        )
        
        // 4. Post-process response
        let processedResponse = await responseProcessor.process(response, context: optimizedContext)
        
        return processedResponse
    }
    
    /// Generate response with retry logic for model loading
    private func generateWithRetry(
        prompt: String,
        context: MemoryContext,
        criteria: ModelSelectionCriteria,
        maxRetries: Int = 3
    ) async throws -> AIModelResponse {
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                return try await generateWithFallback(
                    prompt: prompt,
                    context: context,
                    criteria: criteria
                )
            } catch {
                lastError = error
                let errorDescription = error.localizedDescription
                
                // If it's a model loading issue, wait and retry
                if errorDescription.contains("Model not loaded") || errorDescription.contains("not ready") {
                    logger.warning("Models not ready on attempt \(attempt), waiting and retrying...")
                    if attempt < maxRetries {
                        // Wait progressively longer: 3s, 6s, 9s
                        let waitTime = UInt64(attempt * 3 * 1_000_000_000)
                        try await Task.sleep(nanoseconds: waitTime)
                        continue
                    }
                } else {
                    // Other errors, don't retry
                    throw error
                }
            }
        }
        
        throw lastError ?? MemoryAgentError.noAIProvidersAvailable
    }
    
    // MARK: - Private Implementation
    
    /// Generate response with automatic fallback chain
    private func generateWithFallback(
        prompt: String,
        context: MemoryContext,
        criteria: ModelSelectionCriteria
    ) async throws -> AIModelResponse {
        var lastError: Error?
        var attemptCount = 0
        
        // Try Apple Foundation Models first (always try if available)
        if #available(iOS 26.0, macOS 26.0, *), let appleProvider = appleFoundationProvider {
            attemptCount += 1
            do {
                if !appleProvider.isAvailable {
                    throw MemoryAgentError.providerNotReady("Apple Foundation Models not ready")
                }
                
                let response = try await withTimeout(configuration.responseTimeoutInterval) {
                    return try await self.generateWithAppleFoundation(prompt: prompt, context: context, provider: appleProvider)
                }
                updateProviderHealth("apple_foundation", success: true, responseTime: response.processingTime)
                return response
            } catch {
                // Only log if it's not a retry-able error to reduce noise
                if !error.localizedDescription.contains("not ready") && !error.localizedDescription.contains("Model not loaded") {
                    logger.warning("Apple Foundation Models failed: \(error.localizedDescription)")
                }
                updateProviderHealth("apple_foundation", success: false, responseTime: nil)
                lastError = error
                
                // Continue to try other providers
            }
        }
        
        // Try external providers
        if let factory = externalProviderFactory {
            let activeProviders = factory.getAllActiveProviders()
            for provider in activeProviders {
                attemptCount += 1
                
                do {
                    let response = try await withTimeout(configuration.responseTimeoutInterval) {
                        return try await self.generateWithExternalProvider(prompt: prompt, context: context, provider: provider)
                    }
                    
                    // Update health status on success
                    updateProviderHealth(provider.identifier, success: true, responseTime: response.processingTime)
                    
                    return response
                    
                } catch {
                    // Only log if it's not a retry-able error to reduce noise
                    if !error.localizedDescription.contains("not ready") && !error.localizedDescription.contains("Model not loaded") {
                        logger.warning("Provider \(provider.identifier) failed: \(error.localizedDescription)")
                    }
                    lastError = error
                    
                    // Update health status on failure
                    updateProviderHealth(provider.identifier, success: false, responseTime: nil)
                    
                    // Stop trying if we've hit max retries or fallback is disabled
                    if attemptCount >= configuration.maxRetries || !configuration.fallbackEnabled {
                        break
                    }
                }
            }
        }
        
        
        // All providers failed
        logger.error("All AI providers failed, no fallback available")
        throw lastError ?? MemoryAgentError.noAIProvidersAvailable
    }
    
    /// Build selection criteria based on memory context
    private func buildSelectionCriteria(for context: MemoryContext) -> ModelSelectionCriteria {
        return ModelSelectionCriteria(
            requiresPersonalData: context.containsPersonalData,
            requiresOnDevice: context.containsPersonalData, // Privacy requirement
            maxResponseTime: context.containsPersonalData ? 5.0 : 2.0,
            contextSize: estimateContextSize(context),
            priority: context.containsPersonalData ? .privacy : .speed
        )
    }
    
    /// Estimate context size in tokens for provider selection
    private func estimateContextSize(_ context: MemoryContext) -> Int {
        var size = context.userQuery.count / 4 // Rough token estimate
        
        // Since contextData is generic, use a simple estimation approach
        let contextDataString = context.contextData.description
        size += contextDataString.count / 10 // Simplified token estimation
        
        return size
    }
    
    /// Update provider health metrics
    private func updateProviderHealth(
        _ providerId: String,
        success: Bool,
        responseTime: TimeInterval?
    ) {
        guard configuration.healthMonitoringEnabled else { return }
        
        var health = providerHealth[providerId] ?? ProviderHealthStatus(
            isHealthy: true,
            lastSuccessfulResponse: nil,
            consecutiveFailures: 0,
            averageResponseTime: 2.0,
            errorRate: 0.0
        )
        
        if success {
            health = ProviderHealthStatus(
                isHealthy: true,
                lastSuccessfulResponse: Date(),
                consecutiveFailures: 0,
                averageResponseTime: responseTime ?? health.averageResponseTime,
                errorRate: max(0.0, health.errorRate - 0.1) // Improve error rate
            )
        } else {
            health = ProviderHealthStatus(
                isHealthy: health.consecutiveFailures < 2, // Becomes unhealthy after 3 failures
                lastSuccessfulResponse: health.lastSuccessfulResponse,
                consecutiveFailures: health.consecutiveFailures + 1,
                averageResponseTime: health.averageResponseTime,
                errorRate: min(1.0, health.errorRate + 0.2) // Degrade error rate
            )
        }
        
        providerHealth[providerId] = health
    }
    
    /// Execute operation with timeout
    private func withTimeout<T>(
        _ timeoutInterval: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: Optional<T>.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutInterval * 1_000_000_000))
                return nil // Timeout case
            }
            
            // Return the first result (either success or timeout)
            for try await result in group {
                group.cancelAll()
                if let value = result {
                    return value
                } else {
                    throw AIModelProviderError.processingFailed("Operation timeout")
                }
            }
            
            throw AIModelProviderError.processingFailed("Operation timeout")
        }
    }
    
    // MARK: - Provider-Specific Generation Methods
    
    /// Generate response using Apple Foundation Models
    @available(iOS 26.0, macOS 26.0, *)
    private func generateWithAppleFoundation(
        prompt: String,
        context: MemoryContext,
        provider: AppleFoundationModelsProvider
    ) async throws -> AIModelResponse {
        let startTime = Date()
        let content = try await provider.generateModelResponse(prompt)
        let processingTime = Date().timeIntervalSince(startTime)
        
        return AIModelResponse(
            content: content,
            confidence: 0.9,
            processingTime: processingTime,
            modelUsed: "Apple Foundation Models",
            tokensUsed: nil,
            isOnDevice: true,
            containsPersonalData: context.containsPersonalData
        )
    }
    
    /// Generate response using external provider
    private func generateWithExternalProvider(
        prompt: String,
        context: MemoryContext,
        provider: ExternalAIProvider
    ) async throws -> AIModelResponse {
        let startTime = Date()
        let response = try await provider.generateResponse(prompt: prompt, context: context)
        let processingTime = Date().timeIntervalSince(startTime)
        
        return AIModelResponse(
            content: response.content,
            confidence: response.confidence,
            processingTime: processingTime,
            modelUsed: provider.identifier,
            tokensUsed: response.tokensUsed,
            isOnDevice: provider.isOnDevice,
            containsPersonalData: context.containsPersonalData
        )
    }
    
}

// MARK: - Memory Context Manager

/// Manages memory context optimization and validation
public class MemoryContextManager {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryContextManager")
    
    public init() {}
    
    /// Optimize memory context for AI processing
    public func optimize(_ context: MemoryContext) async throws -> MemoryContext {
        var optimizedContext = context
        
        // 1. Privacy filtering
        if context.containsPersonalData {
            optimizedContext = try await filterSensitiveData(optimizedContext)
        }
        
        // 2. Context size optimization
        optimizedContext = try await optimizeContextSize(optimizedContext)
        
        // 3. Relevance ranking
        optimizedContext = try await rankByRelevance(optimizedContext)
        
        return optimizedContext
    }
    
    private func filterSensitiveData(_ context: MemoryContext) async throws -> MemoryContext {
        // Implement privacy filtering logic
        // For now, return as-is since we handle personal data appropriately
        return context
    }
    
    private func optimizeContextSize(_ context: MemoryContext) async throws -> MemoryContext {
        // Limit memory items to prevent context overflow
        let maxLTM = 3
        let maxSTM = 5
        let maxEntities = 5
        let maxNotes = 3
        
        return MemoryContext(
            timestamp: context.timestamp,
            userQuery: context.userQuery,
            containsPersonalData: context.containsPersonalData,
            contextData: [
                "entities": Array(context.entities.prefix(maxEntities)),
                "relationships": context.relationships,
                "shortTermMemories": Array(context.shortTermMemories.prefix(maxSTM)),
                "longTermMemories": Array(context.longTermMemories.prefix(maxLTM)),
                "episodicMemories": context.episodicMemories,
                "relevantNotes": Array(context.relevantNotes.prefix(maxNotes))
            ]
        )
    }
    
    private func rankByRelevance(_ context: MemoryContext) async throws -> MemoryContext {
        // Sort memories and entities by relevance to query
        // For now, keep existing order (could implement scoring later)
        return context
    }
}

// MARK: - AI Provider Selector

/// Selects optimal AI providers based on criteria and health status
public class AIProviderSelector {
    
    public init() {}
    
    /// Select and order providers based on criteria and health
    public func selectProviders(
        from providers: [AIModelProvider],
        criteria: ModelSelectionCriteria,
        healthStatus: [String: ProviderHealthStatus]
    ) -> [AIModelProvider] {
        
        return providers
            .filter { provider in
                // Filter by basic requirements
                if criteria.requiresPersonalData && !provider.supportsPersonalData {
                    return false
                }
                if criteria.requiresOnDevice && !provider.isOnDevice {
                    return false
                }
                return provider.isAvailable
            }
            .filter { provider in
                // Filter by health status
                let health = healthStatus[provider.identifier]
                return health?.isHealthy ?? true && !(health?.shouldFallback ?? false)
            }
            .sorted { provider1, provider2 in
                // Sort by preference (lower response time preferred)
                let health1 = healthStatus[provider1.identifier]
                let health2 = healthStatus[provider2.identifier]
                
                // Prefer providers with better health
                let responseTime1 = health1?.averageResponseTime ?? provider1.estimatedResponseTime
                let responseTime2 = health2?.averageResponseTime ?? provider2.estimatedResponseTime
                
                return responseTime1 < responseTime2
            }
    }
}

// MARK: - Response Processor

/// Post-processes AI responses for consistency and quality
public class ResponseProcessor {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "ResponseProcessor")
    
    public init() {}
    
    /// Process and clean AI response
    public func process(_ response: AIModelResponse, context: MemoryContext) async -> AIModelResponse {
        let cleanedContent = cleanResponse(response.content)
        
        return AIModelResponse(
            content: cleanedContent,
            confidence: response.confidence,
            processingTime: response.processingTime,
            modelUsed: response.modelUsed,
            tokensUsed: response.tokensUsed,
            isOnDevice: response.isOnDevice,
            containsPersonalData: response.containsPersonalData
        )
    }
    
    private func cleanResponse(_ content: String) -> String {
        var cleaned = content
        
        // Remove common AI artifacts
        cleaned = cleaned.replacingOccurrences(of: "<|im_start|>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "<|im_end|>", with: "")
        cleaned = cleaned.replacingOccurrences(of: "assistant\n", with: "")
        
        // Clean up extra whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
}

// MARK: - Extended Error Types

// MARK: - Helper Extensions

extension AIModelProviderError {
    static let operationTimeout = AIModelProviderError.processingFailed("Operation timeout")
}