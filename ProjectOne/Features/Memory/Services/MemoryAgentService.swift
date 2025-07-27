//
//  MemoryAgentService.swift
//  ProjectOne
//
//  Created by Memory Agent on 7/15/25.
//

import Foundation
import SwiftData
import Combine
import os.log

/// Centralized service for managing the Memory Agent system
@MainActor
public class MemoryAgentService: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryAgentService")
    
    // MARK: - Dependencies
    
    private let modelContext: ModelContext
    private var memoryAgent: MemoryAgent?
    private var orchestrator: MemoryAgentOrchestrator?
    private var integration: MemoryAgentIntegration?
    private var knowledgeGraphService: KnowledgeGraphService?
    private var textIngestionAgent: TextIngestionAgent?
    
    // MARK: - State
    
    @Published public var isRunning = false
    @Published public var isInitialized = false
    @Published public var errorMessage: String?
    @Published public var lastActivityTime: Date?
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        logger.info("Memory Agent Service initialized")
    }
    
    // MARK: - Lifecycle
    
    public func start() async throws {
        guard !isRunning else {
            print("⚠️ [MemoryAgentService] Service already running")
            logger.warning("Memory Agent Service already running")
            return
        }
        
        print("🚀 [MemoryAgentService] Starting Memory Agent Service...")
        logger.info("Starting Memory Agent Service...")
        
        do {
            // Initialize core components
            print("🔧 [MemoryAgentService] Initializing core components...")
            try await initializeComponents()
            
            // Start integration
            print("🔗 [MemoryAgentService] Starting integration...")
            try await startIntegration()
            
            // Start orchestrator
            print("🎭 [MemoryAgentService] Starting orchestrator...")
            try await startOrchestrator()
            
            isRunning = true
            isInitialized = true
            lastActivityTime = Date()
            
            print("✅ [MemoryAgentService] Memory Agent Service started successfully")
            logger.info("Memory Agent Service started successfully")
            
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [MemoryAgentService] Failed to start: \(error)")
            print("📊 [MemoryAgentService] Error details: \(error.localizedDescription)")
            logger.error("Failed to start Memory Agent Service: \(error.localizedDescription)")
            throw error
        }
    }
    
    public func stop() async {
        guard isRunning else {
            logger.warning("Memory Agent Service not running")
            return
        }
        
        logger.info("Stopping Memory Agent Service...")
        
        // Stop orchestrator
        await orchestrator?.stop()
        
        // Disconnect integration
        await integration?.disconnect()
        
        isRunning = false
        lastActivityTime = Date()
        
        logger.info("Memory Agent Service stopped")
    }
    
    // MARK: - Component Initialization
    
    private func initializeComponents() async throws {
        logger.debug("Initializing Memory Agent components...")
        
        // Initialize KnowledgeGraphService
        let kgService = KnowledgeGraphService(modelContext: modelContext)
        knowledgeGraphService = kgService
        
        // Initialize TextIngestionAgent
        textIngestionAgent = TextIngestionAgent(modelContext: modelContext)
        
        // Initialize AI providers
        let aiModelProvider = MemoryAgentModelProvider()
        
        // Initialize and register ExternalProviderFactory
        let aiProviderSettings = AIProviderSettings()
        print("🔧 [MemoryAgentService] Enabled providers: \(aiProviderSettings.getEnabledProviders())")
        
        let externalProviderFactory = ExternalProviderFactory(settings: aiProviderSettings)
        await externalProviderFactory.configureFromSettings()
        print("🔧 [MemoryAgentService] External provider factory configured")
        
        aiModelProvider.registerExternalProviderFactory(externalProviderFactory)
        print("🔧 [MemoryAgentService] External provider factory registered")
        
        // Initialize Apple Foundation Models if available
        if #available(iOS 26.0, macOS 26.0, *) {
            let appleFoundationProvider = AppleFoundationModelsProvider()
            aiModelProvider.registerAppleFoundationProvider(appleFoundationProvider)
            print("🔧 [MemoryAgentService] Apple Foundation Models provider registered")
        }
        
        // Initialize AI providers
        print("🔧 [MemoryAgentService] Starting provider initialization...")
        try await aiModelProvider.initializeProviders()
        print("🔧 [MemoryAgentService] Provider initialization completed")
        
        let memAgent = MemoryAgent(
            modelContext: modelContext, 
            knowledgeGraphService: kgService,
            aiModelProvider: aiModelProvider
        )
        memoryAgent = memAgent
        
        // Initialize MemoryAgentOrchestrator
        let privacyAnalyzer = PrivacyAnalyzer()
        orchestrator = MemoryAgentOrchestrator(
            memoryAgent: memAgent,
            privacyAnalyzer: privacyAnalyzer,
            modelContext: modelContext,
            knowledgeGraphService: kgService
        )
        
        logger.debug("Memory Agent components initialized successfully")
    }
    
    private func startIntegration() async throws {
        logger.debug("Starting Memory Agent integration...")
        
        guard let memoryAgent = memoryAgent,
              let orchestrator = orchestrator,
              let knowledgeGraphService = knowledgeGraphService,
              let textIngestionAgent = textIngestionAgent else {
            throw MemoryAgentServiceError.componentInitializationFailed("Required components")
        }
        
        // Initialize integration
        integration = MemoryAgentIntegration(
            memoryAgent: memoryAgent,
            orchestrator: orchestrator,
            knowledgeGraphService: knowledgeGraphService,
            textIngestionAgent: textIngestionAgent,
            modelContext: modelContext
        )
        
        // Start integration
        try await integration?.integrate()
        
        logger.debug("Memory Agent integration started successfully")
    }
    
    private func startOrchestrator() async throws {
        logger.debug("Starting Memory Agent orchestrator...")
        
        guard let orchestrator = orchestrator else {
            throw MemoryAgentServiceError.componentInitializationFailed("MemoryAgentOrchestrator")
        }
        
        try await orchestrator.start()
        
        logger.debug("Memory Agent orchestrator started successfully")
    }
    
    // MARK: - Public Interface
    
    public func processQuery(_ query: String) async throws -> String {
        guard isRunning, let integration = integration else {
            throw MemoryAgentServiceError.serviceNotRunning
        }
        
        let response = try await integration.processUserQuery(query)
        lastActivityTime = Date()
        
        return response.content
    }
    
    public func forceSync() async throws {
        guard isRunning, let integration = integration else {
            throw MemoryAgentServiceError.serviceNotRunning
        }
        
        try await integration.forceSync()
        lastActivityTime = Date()
        
        logger.info("Manual sync completed")
    }
    
    // MARK: - Batch Processing
    
    /// Process all unprocessed or failed items
    public func processUnprocessedItems() async throws -> BatchProcessingResult {
        guard isRunning, let integration = integration else {
            throw MemoryAgentServiceError.serviceNotRunning
        }
        
        let result = try await integration.processUnprocessedItems()
        lastActivityTime = Date()
        
        return result
    }
    
    /// Process only unprocessed notes
    public func processUnprocessedNotes() async throws -> (processed: Int, failed: Int) {
        guard isRunning, let integration = integration else {
            throw MemoryAgentServiceError.serviceNotRunning
        }
        
        let result = try await integration.processUnprocessedNotes()
        lastActivityTime = Date()
        
        return result
    }
    
    /// Process only unprocessed recordings
    public func processUnprocessedRecordings() async throws -> (processed: Int, failed: Int) {
        guard isRunning, let integration = integration else {
            throw MemoryAgentServiceError.serviceNotRunning
        }
        
        let result = try await integration.processUnprocessedRecordings()
        lastActivityTime = Date()
        
        return result
    }
    
    /// Get count of unprocessed items
    public func getUnprocessedItemsCount() throws -> UnprocessedItemsCount {
        guard isRunning, let integration = integration else {
            throw MemoryAgentServiceError.serviceNotRunning
        }
        
        return try integration.getUnprocessedItemsCount()
    }
    
    public func getStatus() -> MemoryAgentServiceStatus {
        return MemoryAgentServiceStatus(
            isRunning: isRunning,
            isInitialized: isInitialized,
            errorMessage: errorMessage,
            lastActivityTime: lastActivityTime,
            integrationStatus: integration?.getIntegrationStatus() ?? .disconnected,
            orchestratorRunning: orchestrator?.currentState == .active
        )
    }
    
    // MARK: - Health Monitoring
    
    public func performHealthCheck() async -> MemoryAgentHealthStatus {
        guard isRunning else {
            return MemoryAgentHealthStatus(
                overall: .unhealthy,
                components: [:],
                timestamp: Date()
            )
        }
        
        var components: [String: ComponentHealthStatus] = [:]
        
        // Check MemoryAgent
        components["MemoryAgent"] = memoryAgent != nil ? .healthy : .unhealthy
        
        // Check Orchestrator
        components["Orchestrator"] = (orchestrator?.currentState == .active) ? .healthy : .unhealthy
        
        // Check Integration
        let integrationStatus = integration?.getIntegrationStatus() ?? .disconnected
        components["Integration"] = integrationStatus == .connected ? .healthy : .unhealthy
        
        // Check KnowledgeGraph
        components["KnowledgeGraph"] = knowledgeGraphService != nil ? .healthy : .unhealthy
        
        // Check TextIngestion
        components["TextIngestion"] = textIngestionAgent != nil ? .healthy : .unhealthy
        
        // Determine overall health
        let unhealthyCount = components.values.filter { $0 == .unhealthy }.count
        let overall: ComponentHealthStatus = unhealthyCount == 0 ? .healthy : 
                                  unhealthyCount <= 1 ? .degraded : .unhealthy
        
        return MemoryAgentHealthStatus(
            overall: overall,
            components: components,
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Types

public enum MemoryAgentServiceError: Error, LocalizedError {
    case serviceNotRunning
    case componentInitializationFailed(String)
    case integrationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .serviceNotRunning:
            return "Memory Agent Service is not running"
        case .componentInitializationFailed(let component):
            return "Failed to initialize component: \(component)"
        case .integrationFailed(let reason):
            return "Integration failed: \(reason)"
        }
    }
}

public struct MemoryAgentServiceStatus {
    let isRunning: Bool
    let isInitialized: Bool
    let errorMessage: String?
    let lastActivityTime: Date?
    let integrationStatus: IntegrationStatus
    let orchestratorRunning: Bool
}

public enum ComponentHealthStatus {
    case healthy
    case degraded
    case unhealthy
}

public struct MemoryAgentHealthStatus {
    let overall: ComponentHealthStatus
    let components: [String: ComponentHealthStatus]
    let timestamp: Date
}