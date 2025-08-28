//
//  InitializationCoordinator.swift
//  ProjectOne
//
//  Created by Claude Code on 12/8/2025.
//  A robust initialization coordinator that's immune to SwiftUI view lifecycle cancellations
//

import SwiftUI
import SwiftData
import Foundation
import Combine
import os.log

// MARK: - Initialization Coordinator

/// A robust initialization coordinator that's immune to SwiftUI view lifecycle cancellations
@MainActor
public class InitializationCoordinator: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "InitializationCoordinator")
    
    // MARK: - Published State
    
    @Published public private(set) var systemManager: UnifiedSystemManager?
    @Published public private(set) var isInitializing = false
    @Published public private(set) var initializationProgress: Double = 0.0
    @Published public private(set) var initializationStatus = "Ready to initialize"
    @Published public private(set) var initializationError: String?
    
    // MARK: - Private State
    
    private var initializationTask: Task<Void, Never>?
    private var initializationAttempts = 0
    private let maxRetries = 3
    private var hasInitialized = false
    
    public init() {}
    
    // MARK: - Initialization Management
    
    /// Start initialization if not already started or completed
    public func ensureInitialized(modelContainer: ModelContainer) {
        // Prevent multiple concurrent initializations
        guard !isInitializing && !hasInitialized else {
            logger.info("Initialization already in progress or completed")
            return
        }
        
        // Cancel any existing task (cleanup)
        initializationTask?.cancel()
        
        logger.info("Starting cancellation-resistant initialization")
        
        // Create a detached task that won't be cancelled by SwiftUI
        initializationTask = Task.detached { [weak self] in
            await self?.performInitialization(modelContainer: modelContainer)
        }
    }
    
    /// Perform the actual initialization with retry logic
    private func performInitialization(modelContainer: ModelContainer) async {
        await MainActor.run {
            isInitializing = true
            initializationProgress = 0.0
            initializationStatus = "Starting system initialization..."
            initializationError = nil
        }
        
        logger.info("Beginning initialization attempt \(initializationAttempts + 1)")
        
        do {
            // Create the system manager with dependency injection
            await MainActor.run {
                initializationStatus = "Creating system manager..."
                initializationProgress = 0.1
            }
            
            let serviceFactory = DefaultServiceFactory()
            let configuration = UnifiedSystemManager.Configuration.default
            let manager = UnifiedSystemManager(
                modelContext: modelContainer.mainContext,
                configuration: configuration,
                serviceFactory: serviceFactory
            )
            
            // Update progress
            await MainActor.run {
                initializationStatus = "Initializing system components..."
                initializationProgress = 0.3
            }
            
            // Initialize the system with timeout protection
            try await withTimeout(seconds: 30.0) {
                await manager.initializeSystem()
                
                // Verify initialization succeeded
                guard manager.isInitialized else {
                    throw InitializationError.initializationFailed("System manager reports not initialized")
                }
            }
            
            await MainActor.run {
                self.systemManager = manager
                self.initializationProgress = 1.0
                self.initializationStatus = "System ready"
                self.isInitializing = false
                self.hasInitialized = true
            }
            logger.info("✅ System initialization completed successfully")
            
        } catch {
            await handleInitializationError(error, modelContainer: modelContainer)
        }
    }
    
    /// Handle initialization errors with retry logic
    private func handleInitializationError(_ error: Error, modelContainer: ModelContainer) async {
        initializationAttempts += 1
        
        let shouldRetry = initializationAttempts < maxRetries && 
                         (error is CancellationError || error is InitializationError)
        
        if shouldRetry {
            logger.info("Initialization failed, retrying in 1 second (attempt \(initializationAttempts))")
            
            await MainActor.run {
                initializationStatus = "Retrying initialization..."
                initializationProgress = 0.0
            }
            
            // Wait before retry
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Retry with exponential backoff
            await performInitialization(modelContainer: modelContainer)
            
        } else {
            // Max retries reached or unrecoverable error
            await MainActor.run {
                self.isInitializing = false
                self.initializationError = error.localizedDescription
                self.initializationStatus = "Initialization failed"
            }
            
            logger.error("❌ System initialization failed after \(initializationAttempts) attempts: \(error.localizedDescription)")
        }
    }
    
    /// Reset the coordinator for a fresh initialization
    public func reset() {
        logger.info("Resetting initialization coordinator")
        
        initializationTask?.cancel()
        initializationTask = nil
        initializationAttempts = 0
        hasInitialized = false
        
        systemManager = nil
        isInitializing = false
        initializationProgress = 0.0
        initializationStatus = "Ready to initialize"
        initializationError = nil
    }
    
    /// Force restart the system
    public func restart(modelContainer: ModelContainer) {
        logger.info("Restarting system initialization")
        reset()
        ensureInitialized(modelContainer: modelContainer)
    }
}

// MARK: - Supporting Types

public enum InitializationError: Error, LocalizedError {
    case cancelled
    case timeout
    case initializationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Initialization was cancelled"
        case .timeout:
            return "Initialization timed out"
        case .initializationFailed(let message):
            return "Initialization failed: \(message)"
        }
    }
}

// MARK: - Timeout Helper

private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the main operation
        group.addTask {
            return try await operation()
        }
        
        // Add the timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw InitializationError.timeout
        }
        
        // Return the first result
        let result = try await group.next()
        group.cancelAll()
        return result!
    }
}