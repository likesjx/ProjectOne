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
    
    private var providers: [AIModelProvider] = []
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
    
    /// Register an AI provider with the orchestrator
    public func registerProvider(_ provider: AIModelProvider) {
        providers.append(provider)
        providerHealth[provider.identifier] = ProviderHealthStatus(
            isHealthy: true,
            lastSuccessfulOperation: nil,
            consecutiveFailures: 0,
            averageResponseTime: provider.estimatedResponseTime,
            errorRate: 0.0
        )
        logger.info("Registered provider: \(provider.identifier)")
    }
    
    /// Initialize all registered providers
    public func initializeProviders() async throws {
        logger.info("Initializing \(self.providers.count) AI providers")
        
        var initializationErrors: [Error] = []
        
        for provider in providers {
            do {
                try await provider.prepare()
                logger.info("Provider \(provider.identifier) initialized successfully")
            } catch {
                logger.error("Failed to initialize provider \(provider.identifier): \(error.localizedDescription)")
                initializationErrors.append(error)
                
                // Mark provider as unhealthy
                providerHealth[provider.identifier] = ProviderHealthStatus(
                    isHealthy: false,
                    lastSuccessfulOperation: nil,
                    consecutiveFailures: 1,
                    averageResponseTime: provider.estimatedResponseTime,
                    errorRate: 1.0
                )
            }
        }
        
        // Check if we have any healthy providers
        let healthyProviders = providers.filter { provider in
            provider.isAvailable && (providerHealth[provider.identifier]?.isHealthy ?? false)
        }
        
        if healthyProviders.isEmpty {
            throw MemoryAgentError.noAIProvidersAvailable
        }
        
        logger.info("Initialization complete: \(healthyProviders.count)/\(self.providers.count) providers available")
    }
    
    /// Cleanup all providers
    public func cleanup() async {
        logger.info("Cleaning up AI providers")
        
        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    await provider.cleanup()
                }
            }
        }
        
        providers.removeAll()
        providerHealth.removeAll()
    }
    
    // MARK: - Main API
    
    /// Generate AI response with intelligent provider selection and fallback
    public func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse {
        logger.debug("Generating response for prompt: \(prompt.prefix(50))...")
        
        // 1. Optimize and validate context
        let optimizedContext = try await contextManager.optimize(context)
        
        // 2. Determine selection criteria based on context
        let criteria = buildSelectionCriteria(for: optimizedContext)
        
        // 3. Generate with provider selection and fallback
        let response = try await generateWithFallback(
            prompt: prompt,
            context: optimizedContext,
            criteria: criteria
        )
        
        // 4. Post-process response
        let processedResponse = await responseProcessor.process(response, context: optimizedContext)
        
        logger.info("Response generated successfully using \(processedResponse.modelUsed)")
        return processedResponse
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
        
        // Get ordered list of providers based on criteria
        let candidateProviders = providerSelector.selectProviders(
            from: providers,
            criteria: criteria,
            healthStatus: providerHealth
        )
        
        guard !candidateProviders.isEmpty else {
            throw MemoryAgentError.noAvailableProvider
        }
        
        // Try each provider in order
        for provider in candidateProviders {
            attemptCount += 1
            
            do {
                logger.debug("Attempting generation with provider: \(provider.identifier) (attempt \(attemptCount))")
                
                let response = try await withTimeout(configuration.responseTimeoutInterval) {
                    try await provider.generateResponse(prompt: prompt, context: context)
                }
                
                // Update health status on success
                updateProviderHealth(provider.identifier, success: true, responseTime: response.processingTime)
                
                return response
                
            } catch {
                logger.warning("Provider \(provider.identifier) failed: \(error.localizedDescription)")
                lastError = error
                
                // Update health status on failure
                updateProviderHealth(provider.identifier, success: false, responseTime: nil)
                
                // Stop trying if we've hit max retries or fallback is disabled
                if attemptCount >= configuration.maxRetries || !configuration.fallbackEnabled {
                    break
                }
            }
        }
        
        // All providers failed
        throw lastError ?? MemoryAgentError.noAvailableProvider
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
        
        size += context.longTermMemories.reduce(0) { $0 + $1.content.count / 4 }
        size += context.shortTermMemories.reduce(0) { $0 + $1.content.count / 4 }
        size += context.entities.reduce(0) { $0 + ($1.name.count + ($1.entityDescription?.count ?? 0)) / 4 }
        size += context.relevantNotes.reduce(0) { $0 + $1.originalText.count / 4 }
        
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
            lastSuccessfulOperation: nil,
            consecutiveFailures: 0,
            averageResponseTime: 2.0,
            errorRate: 0.0
        )
        
        if success {
            health = ProviderHealthStatus(
                isHealthy: true,
                lastSuccessfulOperation: Date(),
                consecutiveFailures: 0,
                averageResponseTime: responseTime ?? health.averageResponseTime,
                errorRate: max(0.0, health.errorRate - 0.1) // Improve error rate
            )
        } else {
            health = ProviderHealthStatus(
                isHealthy: health.consecutiveFailures < 2, // Becomes unhealthy after 3 failures
                lastSuccessfulOperation: health.lastSuccessfulOperation,
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
}

// MARK: - Memory Context Manager

/// Manages memory context optimization and validation
public class MemoryContextManager {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryContextManager")
    
    public init() {}
    
    /// Optimize memory context for AI processing
    public func optimize(_ context: MemoryContext) async throws -> MemoryContext {
        logger.debug("Optimizing memory context")
        
        var optimizedContext = context
        
        // 1. Privacy filtering
        if context.containsPersonalData {
            optimizedContext = try await filterSensitiveData(optimizedContext)
        }
        
        // 2. Context size optimization
        optimizedContext = try await optimizeContextSize(optimizedContext)
        
        // 3. Relevance ranking
        optimizedContext = try await rankByRelevance(optimizedContext)
        
        logger.debug("Context optimization complete")
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
            entities: Array(context.entities.prefix(maxEntities)),
            relationships: context.relationships,
            shortTermMemories: Array(context.shortTermMemories.prefix(maxSTM)),
            longTermMemories: Array(context.longTermMemories.prefix(maxLTM)),
            episodicMemories: context.episodicMemories,
            relevantNotes: Array(context.relevantNotes.prefix(maxNotes)),
            timestamp: context.timestamp,
            userQuery: context.userQuery,
            containsPersonalData: context.containsPersonalData
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
        logger.debug("Post-processing AI response")
        
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