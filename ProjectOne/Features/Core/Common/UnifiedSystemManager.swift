//
//  UnifiedSystemManager.swift
//  ProjectOne
//
//  Centralized system coordinator for managing all major components
//  Updated to use dependency injection pattern as recommended in GPT-5 feedback
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import os.log

/// Centralized system manager that coordinates all major components
@MainActor
public class UnifiedSystemManager: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "UnifiedSystemManager")
    
    // MARK: - Core Dependencies
    
    private let modelContext: ModelContext
    private let configuration: Configuration
    private let serviceFactory: ServiceFactory
    
    // MARK: - Published State
    
    @Published public var isInitialized = false
    @Published public var initializationProgress: Double = 0.0
    @Published public var initializationStatus = "Initializing..."
    @Published public var hasErrors = false
    @Published public var errorMessage: String?
    @Published public var currentOperation: String = "Ready"
    
    // MARK: - Services
    
    @Published public var mlxService: MLXService?
    @Published public var memoryService: RealTimeMemoryService?
    @Published public var cognitiveEngine: CognitiveDecisionEngine?
    @Published public var centralAgentRegistry: CentralAgentRegistry?
    
    // MARK: - System Statistics
    
    public var systemStatistics: [String: Any] {
        return [
            "uptime": Date().timeIntervalSince1970,
            "memoryUsage": 100.0,
            "cpuUsage": 25.0,
            "activeServices": 3
        ]
    }
    
    // MARK: - Configuration
    
    public struct Configuration: Sendable {
        let enableMLX: Bool
        let enableMemoryServices: Bool
        let initializationTimeout: TimeInterval
        
        public static let `default` = Configuration(
            enableMLX: true,
            enableMemoryServices: true,
            initializationTimeout: 30.0
        )
    }
    
    // MARK: - Initialization
    
    public init(
        modelContext: ModelContext, 
        configuration: Configuration = .default,
        serviceFactory: ServiceFactory = DefaultServiceFactory()
    ) {
        self.modelContext = modelContext
        self.configuration = configuration
        self.serviceFactory = serviceFactory
        
        logger.info("UnifiedSystemManager initialized with dependency injection")
    }
    
    // MARK: - System Lifecycle
    
    /// Initialize all system components using dependency injection
    public func initializeSystem() async {
        logger.info("Starting system initialization with dependency injection")
        
        initializationProgress = 0.0
        initializationStatus = "Starting system initialization..."
        hasErrors = false
        errorMessage = nil
        
        do {
            // Initialize MLX Service using factory
            if configuration.enableMLX {
                initializationStatus = "Initializing MLX Service..."
                initializationProgress = 0.2
                
                let mlx = serviceFactory.createMLXService()
                self.mlxService = mlx
                logger.info("✅ MLX Service initialized via factory")
            }
            
            // Initialize Memory Services using factory
            if configuration.enableMemoryServices {
                initializationStatus = "Initializing Memory Services..."
                initializationProgress = 0.6
                
                let memory = serviceFactory.createMemoryService(context: modelContext)
                self.memoryService = memory
                logger.info("✅ Memory Service initialized via factory")
            }
            
            // Initialize Cognitive Decision Engine using factory
            initializationStatus = "Initializing Cognitive Engine..."
            initializationProgress = 0.8
            
            let cognitive = serviceFactory.createCognitiveEngine(context: modelContext)
            self.cognitiveEngine = cognitive
            logger.info("✅ Cognitive Decision Engine initialized via factory")
            
            // Initialize Central Agent Registry
            let registry = CentralAgentRegistry()
            self.centralAgentRegistry = registry
            logger.info("✅ Central Agent Registry initialized")
            
            // Final setup
            initializationStatus = "Finalizing initialization..."
            initializationProgress = 0.9
            
            // Allow UI to update
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            initializationProgress = 1.0
            initializationStatus = "System ready"
            isInitialized = true
            
            logger.info("✅ System initialization completed successfully with dependency injection")
            
        } catch {
            hasErrors = true
            errorMessage = error.localizedDescription
            initializationStatus = "Initialization failed"
            logger.error("❌ System initialization failed: \(error.localizedDescription)")
        }
    }
    
    /// Restart the system
    public func restartSystem() async {
        logger.info("Restarting system")
        
        isInitialized = false
        mlxService = nil
        memoryService = nil
        cognitiveEngine = nil
        
        await initializeSystem()
    }
    
    /// Shutdown the system gracefully
    public func shutdown() async {
        logger.info("Shutting down system")
        
        isInitialized = false
        mlxService = nil
        memoryService = nil
        cognitiveEngine = nil
        
        initializationStatus = "System shutdown"
        initializationProgress = 0.0
    }
    
    // MARK: - System Health
    
    /// Check overall system health
    public var systemHealth: SystemHealth {
        if hasErrors {
            return .error(errorMessage ?? "Unknown error")
        }
        
        if !isInitialized {
            return .initializing
        }
        
        // Check component health
        var healthyComponents = 0
        var totalComponents = 0
        
        if configuration.enableMLX {
            totalComponents += 1
            if mlxService != nil {
                healthyComponents += 1
            }
        }
        
        if configuration.enableMemoryServices {
            totalComponents += 1
            if memoryService != nil {
                healthyComponents += 1
            }
        }
        
        if healthyComponents == totalComponents {
            return .healthy
        } else {
            return .degraded("Some components unavailable")
        }
    }
    
    /// Get system information
    public var systemInfo: SystemInfo {
        return SystemInfo(
            isInitialized: isInitialized,
            initializationProgress: initializationProgress,
            status: initializationStatus,
            health: systemHealth,
            mlxAvailable: mlxService != nil,
            memoryServiceAvailable: memoryService != nil,
            modelContextAvailable: true
        )
    }
}

// MARK: - Supporting Types

public enum SystemHealth {
    case healthy
    case initializing
    case degraded(String)
    case error(String)
    
    public var displayName: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .initializing:
            return "Initializing"
        case .degraded(let message):
            return "Degraded: \(message)"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    public var isHealthy: Bool {
        if case .healthy = self {
            return true
        }
        return false
    }
}

public struct SystemInfo {
    public let isInitialized: Bool
    public let initializationProgress: Double
    public let status: String
    public let health: SystemHealth
    public let mlxAvailable: Bool
    public let memoryServiceAvailable: Bool
    public let modelContextAvailable: Bool
    public let timestamp: Date = Date()
    
    public var healthDescription: String {
        return health.displayName
    }
}