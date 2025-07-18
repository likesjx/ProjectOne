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
            logger.warning("Memory Agent Service already running")
            return
        }
        
        logger.info("Starting Memory Agent Service...")
        
        do {
            // Initialize core components
            try await initializeComponents()
            
            // Start integration
            try await startIntegration()
            
            // Start orchestrator
            try await startOrchestrator()
            
            isRunning = true
            isInitialized = true
            lastActivityTime = Date()
            
            logger.info("Memory Agent Service started successfully")
            
        } catch {
            errorMessage = error.localizedDescription
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
        
        // Initialize MemoryAgent
        let memAgent = MemoryAgent(modelContext: modelContext, knowledgeGraphService: kgService)
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