//
//  AIProviderSelector.swift
//  ProjectOne
//
//  Created for intelligent AI provider selection
//

import Foundation
import os.log
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Intelligent AI provider selector that automatically chooses the best available provider
/// based on device capabilities, platform, and availability
public class SmartAIProviderSelector: ObservableObject {
    
    // MARK: - Properties
    
    @Published public private(set) var currentProvider: BaseAIProvider?
    @Published public private(set) var availableProviders: [BaseAIProvider] = []
    @Published public private(set) var providerStatus: ProviderSelectionStatus = .initializing
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "AIProviderSelector")
    
    // Provider instances
    private var mlxProvider: UnifiedMLXProvider?
    private var appleFoundationProvider: AppleFoundationModelsProvider?
    
    // MARK: - Initialization
    
    public init() {
        logger.info("Initializing AI Provider Selector")
        Task {
            await initializeProviders()
        }
    }
    
    // MARK: - Provider Selection Logic
    
    /// Initializes all available providers and selects the best one
    private func initializeProviders() async {
        await MainActor.run {
            providerStatus = .initializing
        }
        
        logger.info("Initializing AI providers for device capabilities")
        
        // Initialize providers based on platform and capabilities
        await initializePlatformProviders()
        
        // Select the best available provider
        await selectOptimalProvider()
        
        await MainActor.run {
            providerStatus = currentProvider != nil ? .ready : .unavailable
        }
    }
    
    /// Initialize providers based on platform capabilities
    private func initializePlatformProviders() async {
        var providers: [BaseAIProvider] = []
        
        // 1. Try MLX Gemma3n Provider (real Apple Silicon hardware only)
        // Note: Temporarily disabled during migration to unified provider system
        /*
        if await shouldUseMlxProvider() {
            logger.info("Device supports MLX - initializing MLX Gemma3n provider")
            let mlxProvider = UnifiedMLXProvider()
            self.mlxProvider = mlxProvider
            providers.append(mlxProvider)
        } else {
            logger.info("Device does not support MLX (simulator or incompatible hardware)")
        }
        */
        
        // 2. Try Apple Foundation Models Provider (iOS 18.1+, macOS 15.1+)
        if await shouldUseAppleFoundationProvider() {
            logger.info("Device supports Apple Foundation Models - initializing provider")
            if #available(iOS 26.0, macOS 26.0, *) {
                let foundationProvider = AppleFoundationModelsProvider()
                appleFoundationProvider = foundationProvider
                providers.append(foundationProvider)
            }
        } else {
            logger.info("Device does not support Apple Foundation Models")
        }
        
        await MainActor.run {
            availableProviders = providers
        }
        
        logger.info("Initialized \(providers.count) AI providers")
    }
    
    /// Determines if MLX provider should be used
    private func shouldUseMlxProvider() async -> Bool {
        #if targetEnvironment(simulator)
        return false // MLX requires real hardware
        #else
        // Check if we're on Apple Silicon
        #if arch(arm64)
        return true
        #else
        return false // MLX requires Apple Silicon
        #endif
        #endif
    }
    
    /// Determines if Apple Foundation Models provider should be used
    private func shouldUseAppleFoundationProvider() async -> Bool {
        if #available(iOS 26.0, macOS 26.0, *) {
            return true
        }
        return false
    }
    
    /// Select the optimal provider based on capabilities and availability
    private func selectOptimalProvider() async {
        let providers = await MainActor.run { availableProviders }
        
        // Try each provider in order of preference
        for provider in providers {
            do {
                // Test if provider can be prepared
                logger.info("Testing provider: \(provider.displayName)")
                try await provider.prepare()
                
                if provider.isAvailable {
                    logger.info("Selected provider: \(provider.displayName)")
                    await MainActor.run {
                        currentProvider = provider
                    }
                    return
                }
            } catch {
                logger.warning("Provider \(provider.displayName) failed to initialize: \(error.localizedDescription)")
            }
        }
        
        logger.error("No AI providers available")
    }
    
    // MARK: - Public Interface
    
    /// Get the current best provider
    public func getCurrentProvider() -> BaseAIProvider? {
        return currentProvider
    }
    
    /// Force refresh provider selection
    public func refreshProviders() async {
        logger.info("Refreshing provider selection")
        await initializeProviders()
    }
    
    /// Get provider selection information
    public func getProviderInfo() -> ProviderSelectionInfo {
        let current = currentProvider
        let available = availableProviders
        
        return ProviderSelectionInfo(
            currentProvider: current?.displayName ?? "None",
            currentProviderType: getProviderType(current),
            availableProviders: available.map { $0.displayName },
            deviceCapabilities: getDeviceCapabilities(),
            status: providerStatus
        )
    }
    
    /// Manually switch to a specific provider (for testing)
    public func switchToProvider(_ identifier: String) async {
        let providers = await MainActor.run { availableProviders }
        
        if let provider = providers.first(where: { $0.identifier == identifier }) {
            do {
                try await provider.prepare()
                if provider.isAvailable {
                    await MainActor.run {
                        currentProvider = provider
                        providerStatus = .ready
                    }
                    logger.info("Manually switched to provider: \(provider.displayName)")
                }
            } catch {
                logger.error("Failed to switch to provider \(identifier): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getProviderType(_ provider: BaseAIProvider?) -> ProviderType {
        guard let provider = provider else { return .none }
        
        switch provider.identifier {
        case "mlx-gemma-3n-e2b-vlm":
            return .mlxGemma3n
        case "apple-foundation-models":
            return .appleFoundation
        default:
            return .other
        }
    }
    
    private func getDeviceCapabilities() -> AIDeviceCapabilities {
        let isSimulator: Bool
        let isAppleSilicon: Bool
        let supportsAppleIntelligence: Bool
        
        #if targetEnvironment(simulator)
        isSimulator = true
        isAppleSilicon = false // Simulator doesn't expose Apple Silicon directly
        #else
        isSimulator = false
        #if arch(arm64)
        isAppleSilicon = true
        #else
        isAppleSilicon = false
        #endif
        #endif
        
        if #available(iOS 26.0, macOS 26.0, *) {
            supportsAppleIntelligence = true
        } else {
            supportsAppleIntelligence = false
        }
        
        return AIDeviceCapabilities(
            isSimulator: isSimulator,
            isAppleSilicon: isAppleSilicon,
            supportsMLX: !isSimulator && isAppleSilicon,
            supportsAppleIntelligence: supportsAppleIntelligence
        )
    }
}

// MARK: - Supporting Types


public enum ProviderType {
    case none
    case mlxGemma3n
    case appleFoundation
    case other
}

public struct ProviderSelectionInfo {
    let currentProvider: String
    let currentProviderType: ProviderType
    let availableProviders: [String]
    let deviceCapabilities: AIDeviceCapabilities
    let status: ProviderSelectionStatus
}

public struct AIDeviceCapabilities {
    let isSimulator: Bool
    let isAppleSilicon: Bool
    let supportsMLX: Bool
    let supportsAppleIntelligence: Bool
    
    var description: String {
        var capabilities: [String] = []
        
        if isSimulator {
            capabilities.append("iOS Simulator")
        } else {
            capabilities.append("Real Hardware")
        }
        
        if isAppleSilicon {
            capabilities.append("Apple Silicon")
        }
        
        if supportsMLX {
            capabilities.append("MLX Compatible")
        }
        
        if supportsAppleIntelligence {
            capabilities.append("Apple Intelligence")
        }
        
        return capabilities.joined(separator: ", ")
    }
}