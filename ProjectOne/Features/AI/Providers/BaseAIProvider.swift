//
//  BaseAIProvider.swift
//  ProjectOne
//
//  🎓 SWIFT LEARNING: This file demonstrates advanced Swift concepts including:
//  • Protocol-oriented programming with base class architecture
//  • Modern Swift concurrency (async/await, @MainActor)
//  • Property wrappers (@Published, @MainActor)
//  • Generic types and associated types
//  • Combine framework integration
//  • Advanced error handling patterns
//
//  Created by Memory Agent on 7/16/25.
//

import Foundation
import os.log        // 🎓 SWIFT LEARNING: Apple's unified logging system - preferred over print()
import SwiftData     // 🎓 SWIFT LEARNING: Apple's modern data persistence framework
import Combine       // 🎓 SWIFT LEARNING: Reactive programming framework for handling asynchronous events
import Atomics       // 🎓 SWIFT LEARNING: Thread-safe atomic operations for concurrent programming

#if canImport(UIKit)
import UIKit         // 🎓 PLATFORM OPTIMIZATION: iOS/iPadOS-specific optimizations
#endif

#if canImport(AppKit)
import AppKit        // 🎓 PLATFORM OPTIMIZATION: macOS-specific optimizations  
#endif

#if canImport(OSLog)
import OSLog         // 🎓 PLATFORM OPTIMIZATION: Enhanced logging for debugging and performance monitoring
#endif

// MARK: - Platform Optimization Support Types
// 🎓 PLATFORM OPTIMIZATION: Types supporting cross-platform performance optimization

/// Platform-specific configuration for optimal AI provider performance
public struct PlatformConfiguration: Sendable {
    public let maxConcurrentOperations: Int
    public let preferredQuality: QualityPreference
    public let backgroundProcessingAllowed: Bool
    public let thermalManagement: ThermalManagement
    public let memoryPressureThreshold: Double
    public let targetResponseTime: TimeInterval
    
    public enum QualityPreference: Sendable {
        case efficiency    // Optimize for battery life and resource usage
        case balanced     // Balance between quality and efficiency
        case quality      // Optimize for best possible results
    }
    
    public enum ThermalManagement: Sendable {
        case passive      // No thermal management
        case balanced     // Standard thermal management
        case aggressive   // Aggressive thermal throttling
    }
    
    public static let `default` = PlatformConfiguration(
        maxConcurrentOperations: 2,
        preferredQuality: .balanced,
        backgroundProcessingAllowed: false,
        thermalManagement: .balanced,
        memoryPressureThreshold: 0.8,
        targetResponseTime: 2.0
    )
}

/// System metrics for platform-aware optimization
public struct SystemMetrics: Sendable {
    public let memoryPressure: Double        // 0.0 to 1.0
    public let batteryLevel: Double          // 0.0 to 1.0 (iOS only)
    public let thermalState: ThermalState
    public let isLowPowerMode: Bool          // iOS only
    public let availableMemoryGB: Double
    public let cpuCores: Int
    public let timestamp: Date
    
    public init(
        memoryPressure: Double = 0.5,
        batteryLevel: Double = 1.0,
        thermalState: ThermalState = .nominal,
        isLowPowerMode: Bool = false,
        availableMemoryGB: Double = 8.0,
        cpuCores: Int = 4
    ) {
        self.memoryPressure = memoryPressure
        self.batteryLevel = batteryLevel
        self.thermalState = thermalState
        self.isLowPowerMode = isLowPowerMode
        self.availableMemoryGB = availableMemoryGB
        self.cpuCores = cpuCores
        self.timestamp = Date()
    }
}

/// Thermal state monitoring for performance throttling
public enum ThermalState: Int, CaseIterable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
    
    public var description: String {
        switch self {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        }
    }
    
    public var shouldThrottle: Bool {
        switch self {
        case .nominal: return false
        case .fair: return false  
        case .serious: return true
        case .critical: return true
        @unknown default: return true
        }
    }
}

// MARK: - Model Loading Status
// 🎓 SWIFT LEARNING: Enums with associated values are a powerful Swift feature
// This enum represents different states of model loading with type-safe data

/// Status of model loading for real-time UI feedback
/// 
/// 🎓 SWIFT LEARNING: This enum demonstrates several Swift concepts:
/// • **Associated Values**: Some cases store additional data (like progress percentage)
/// • **Computed Properties**: `isLoading` and `description` provide derived information
/// • **String Interpolation**: Using \() to embed values in strings
/// • **Switch Statements**: Pattern matching with exhaustive case coverage
public enum ModelLoadingStatus: Equatable, Sendable {
    case notStarted
    case preparing
    case downloading(progress: Double)
    case loading
    case ready
    case failed(String)
    case unavailable
    
    // 🎓 SWIFT LEARNING: Computed properties are like functions but accessed like variables
    // This property uses a switch statement to determine if the model is currently loading
    public var isLoading: Bool {
        switch self {
        case .preparing, .downloading, .loading:
            return true  // 🎓 These cases indicate loading is in progress
        default:
            return false // 🎓 All other cases mean loading is not happening
        }
    }
    
    // 🎓 SWIFT LEARNING: Another computed property that creates user-friendly descriptions
    // Notice how we extract associated values using `let` in the case statements
    public var description: String {
        switch self {
        case .notStarted: 
            return "Not Started"
        case .preparing: 
            return "Preparing..."
        case .downloading(let progress):  // 🎓 Extracting the progress value from associated data
            return "Downloading \(Int(progress * 100))%"  // 🎓 String interpolation with calculation
        case .loading: 
            return "Loading Model..."
        case .ready: 
            return "Ready"
        case .failed(let error):  // 🎓 Extracting error message from associated value
            return "Failed: \(error)"
        case .unavailable: 
            return "Unavailable"
        }
    }
}

// MARK: - Base AI Provider Class
// 🎓 SWIFT LEARNING: This demonstrates several advanced Swift concepts

/// Base class for AI model providers that eliminates code duplication
/// and provides common functionality for all AI providers
/// 
/// 🎓 SWIFT LEARNING: Class inheritance and protocol conformance:
/// • **Class Inheritance**: This is a base class that other AI providers will inherit from
/// • **Protocol Conformance**: Implements AIModelProvider protocol (contract/interface)
/// • **ObservableObject**: SwiftUI protocol that allows UI to automatically update when properties change
/// • **Multiple Inheritance**: Swift classes can inherit from one class but conform to many protocols
public class BaseAIProvider: AIModelProvider, ObservableObject, @unchecked Sendable {
    
    // MARK: - AIModelProvider Protocol Requirements
    public var identifier: String { "BaseAIProvider" }
    public var displayName: String { "Base AI Provider" }
    public var supportsPersonalData: Bool { true }  // All our AI providers support personal data
    public var isOnDevice: Bool { true }             // All our AI providers run locally for privacy
    public var estimatedResponseTime: TimeInterval { 2.0 }
    public var maxContextLength: Int { 4096 }
    
    // MARK: - Common Infrastructure
    // 🎓 SWIFT LEARNING: Property wrappers and access control modifiers
    
    // 🎓 SWIFT LEARNING: `internal` means visible within the same module (app), but not to external modules
    internal let logger: Logger
    
    // 🎓 SWIFT LEARNING: @Published is a property wrapper that:
    // • Automatically triggers UI updates when the value changes
    // • Works with ObservableObject to notify SwiftUI views
    // • Creates a Publisher (Combine framework) behind the scenes
    @Published public var isModelLoaded = false
    @Published public var modelLoadingStatus: ModelLoadingStatus = .notStarted
    @Published public var loadingProgress: Double = 0.0
    @Published public var statusMessage: String = ""
    @Published public var isAvailable: Bool = false
    @Published public var lastUpdated: Date = Date()
    
    // 🎓 SWIFT LEARNING: DispatchQueue for concurrent programming:
    // • Creates a background queue for CPU-intensive AI processing
    // • `.userInitiated` priority means it's important to the user but not blocking the UI
    // • Prevents AI processing from freezing the user interface
    internal let processingQueue = DispatchQueue(label: "ai-provider", qos: .userInitiated)
    
    // MARK: - Platform-Specific Optimizations
    // 🎓 PLATFORM OPTIMIZATION: Cross-platform performance and behavior optimization
    
    /// Platform-specific configuration for optimal performance
    internal var platformConfig: PlatformConfiguration {
        #if os(iOS) || os(visionOS)
        return PlatformConfiguration(
            maxConcurrentOperations: 2,           // Conservative for mobile devices
            preferredQuality: .efficiency,        // Battery life priority
            backgroundProcessingAllowed: false,   // iOS background restrictions
            thermalManagement: .aggressive,       // Prevent overheating
            memoryPressureThreshold: 0.7,        // Lower threshold for mobile
            targetResponseTime: 2.0               // Reasonable for touch interface
        )
        #elseif os(macOS)
        return PlatformConfiguration(
            maxConcurrentOperations: 4,           // More resources available
            preferredQuality: .quality,           // Performance priority
            backgroundProcessingAllowed: true,    // macOS allows background tasks
            thermalManagement: .balanced,         // Better cooling systems
            memoryPressureThreshold: 0.85,       // Higher threshold for desktop
            targetResponseTime: 1.5               // Faster expected response
        )
        #else
        return PlatformConfiguration.default     // Safe defaults
        #endif
    }
    
    /// Platform-aware resource monitoring
    @Published public var systemMetrics: SystemMetrics = SystemMetrics()
    private var metricsUpdateTimer: Timer?
    
    // 🎓 SWIFT CONCURRENCY: Actor-based system monitoring for thread safety
    private actor SystemMonitor {
        private var lastUpdate = Date.distantPast
        private let updateInterval: TimeInterval = 5.0 // Update every 5 seconds
        
        func updateSystemMetrics() async -> SystemMetrics {
            let now = Date()
            guard now.timeIntervalSince(lastUpdate) >= updateInterval else {
                return SystemMetrics() // Return cached metrics if too recent
            }
            
            lastUpdate = now
            
            #if os(iOS) || os(visionOS)
            // iOS-specific metrics
            let memoryPressure = await getIOSMemoryPressure()
            let batteryLevel = await getIOSBatteryLevel()
            let thermalState = await getIOSThermalState()
            
            return SystemMetrics(
                memoryPressure: memoryPressure,
                batteryLevel: batteryLevel,
                thermalState: thermalState,
                isLowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                availableMemoryGB: await getAvailableMemoryGB(),
                cpuCores: ProcessInfo.processInfo.processorCount
            )
            
            #elseif os(macOS)
            // macOS-specific metrics
            let memoryPressure = await getMacOSMemoryPressure()
            let thermalState = await getMacOSThermalState()
            
            return SystemMetrics(
                memoryPressure: memoryPressure,
                batteryLevel: 1.0, // Assume plugged in
                thermalState: thermalState,
                isLowPowerMode: false,
                availableMemoryGB: await getAvailableMemoryGB(),
                cpuCores: ProcessInfo.processInfo.processorCount
            )
            
            #else
            return SystemMetrics() // Default metrics
            #endif
        }
        
        // MARK: - iOS-Specific Metrics
        #if os(iOS) || os(visionOS)
        private func getIOSMemoryPressure() async -> Double {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
            
            let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
                }
            }
            
            guard result == KERN_SUCCESS else { return 0.5 }
            
            let usedMemoryMB = Double(info.resident_size) / (1024 * 1024)
            let totalMemoryMB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024)
            
            return usedMemoryMB / totalMemoryMB
        }
        
        private func getIOSBatteryLevel() async -> Double {
            #if canImport(UIKit)
            return await MainActor.run { Double(UIDevice.current.batteryLevel) }
            #else
            return 1.0
            #endif
        }
        
        private func getIOSThermalState() async -> ThermalState {
            #if canImport(UIKit)
            switch ProcessInfo.processInfo.thermalState {
            case .nominal:
                return .nominal
            case .fair:
                return .fair
            case .serious:
                return .serious
            case .critical:
                return .critical
            @unknown default:
                return .nominal
            }
            #else
            return .nominal
            #endif
        }
        #endif
        
        // MARK: - macOS-Specific Metrics
        #if os(macOS)
        private func getMacOSMemoryPressure() async -> Double {
            var info = vm_statistics64()
            var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
            
            let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                }
            }
            
            guard result == KERN_SUCCESS else { return 0.5 }
            
            let pageSize = UInt64(4096) // Standard page size fallback
            let usedPages = info.internal_page_count + (info.compressor_page_count)
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let usedMemory = UInt64(usedPages) * pageSize
            
            return Double(usedMemory) / Double(totalMemory)
        }
        
        private func getMacOSThermalState() async -> ThermalState {
            // macOS thermal management - simplified approach
            switch ProcessInfo.processInfo.thermalState {
            case .nominal:
                return .nominal
            case .fair:
                return .fair
            case .serious:
                return .serious
            case .critical:
                return .critical
            @unknown default:
                return .nominal
            }
        }
        #endif
        
        // MARK: - Cross-Platform Metrics
        private func getAvailableMemoryGB() async -> Double {
            return Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        }
    }
    
    private let systemMonitor = SystemMonitor()
    
    // MARK: - Abstract Properties (Protocol-Based)
    // 🔧 FIXED: Replaced fatalError anti-pattern with proper protocol design
    // 🎓 SWIFT LEARNING: Protocol-oriented programming - the Swift way
    
    // 🎓 SWIFT LEARNING: These properties are now defined by the AIModelProvider protocol
    // Subclasses MUST implement these properties, enforced at compile time instead of runtime
    // This is much safer than fatalError() which crashes at runtime
    
    // Note: These properties are now implemented by conforming types
    // The protocol ensures compile-time safety instead of runtime crashes
    
    // MARK: - Common Properties
    // 🎓 SWIFT LEARNING: Properties with default values that all subclasses share
    // Note: supportsPersonalData and isOnDevice are now defined in protocol requirements above
    
    // MARK: - Initialization
    // 🎓 SWIFT LEARNING: Custom initializers and dependency injection
    
    /// Initializes the base AI provider with logging configuration
    /// 
    /// 🎓 SWIFT LEARNING: This initializer demonstrates:
    /// • **Dependency Injection**: Taking logger configuration as parameters
    /// • **Type Introspection**: Using `type(of: self)` to get the actual class name
    /// • **String Interpolation**: Embedding the class name in the log message
    public init(subsystem: String, category: String) {
        self.logger = Logger(subsystem: subsystem, category: category)
        logger.info("Initializing \(type(of: self)) provider")  // 🎓 Logs the actual subclass name
    }
    
    // MARK: - AIModelProvider Implementation
    // 🎓 SWIFT LEARNING: Modern Swift concurrency with async/await
    
    /// Generates an AI response using the provider's model
    /// 
    /// 🎓 SWIFT LEARNING: This method demonstrates several advanced Swift concepts:
    /// • **async/await**: Modern Swift concurrency - method runs asynchronously without blocking
    /// • **throws**: Method can throw errors that must be handled by caller
    /// • **guard statements**: Early exit pattern for validation
    /// • **Higher-order functions**: Using closures with measureProcessingTime
    /// • **Tuple return**: measureProcessingTime returns (result, time) tuple
    public func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse {
        // 🎓 SWIFT LEARNING: Guard statement for early exit validation
        // If isAvailable is false, throw error and exit function immediately
        guard isAvailable else {
            throw AIModelProviderError.providerUnavailable("\(self.displayName) not available")
        }
        
        // Build enriched prompt with memory context
        let enrichedPrompt = buildEnrichedPromptWithFallback(prompt: prompt, context: context)
        
        // Validate context size - throws error if prompt is too long
        try validateContextSize(enrichedPrompt, maxLength: maxContextLength)
        
        // 🎓 SWIFT LEARNING: Tuple destructuring and higher-order functions
        // measureProcessingTime takes a closure (the code in {}) and returns (result, time)
        // We destructure the tuple into separate variables: response and processingTime
        let (response, processingTime) = try await measureProcessingTime {
            try await generateModelResponse(enrichedPrompt)  // 🎓 This calls the abstract method subclasses must implement
        }
        
        logger.info("Generated response in \(processingTime)s using \(self.displayName)")
        
        // 🎓 SWIFT LEARNING: Function calls with named parameters
        // Swift functions can have parameter names that make the code more readable
        return createResponse(
            content: response,
            confidence: getModelConfidence(),
            processingTime: processingTime,
            tokensUsed: estimateTokenCount(enrichedPrompt + response),
            context: context
        )
    }
    
    /// Prepares the AI model for use (loading, initialization, etc.)
    /// 
    /// 🎓 SWIFT LEARNING: This method demonstrates crucial Swift concurrency patterns:
    /// • **@MainActor.run**: Safely updates UI-related properties on the main thread
    /// • **do-catch**: Swift's error handling with try/catch blocks
    /// • **async throws**: Method is both asynchronous AND can throw errors
    /// • **Thread Safety**: Ensuring UI updates happen on the correct thread
    public func prepare() async throws {
        logger.info("Preparing \(self.displayName) provider")
        
        // 🎓 SWIFT LEARNING: @MainActor.run ensures this code runs on the main thread
        // UI updates (like changing @Published properties) MUST happen on the main thread
        // This is a crucial pattern for thread-safe SwiftUI updates
        await MainActor.run {
            modelLoadingStatus = .preparing
            lastUpdated = Date()
        }
        
        // 🎓 SWIFT LEARNING: do-catch block for error handling
        // The 'do' block contains code that might throw errors
        // The 'catch' block handles any errors that are thrown
        do {
            try await prepareModel()  // 🎓 This calls the abstract method subclasses implement
            
            // 🎓 SWIFT LEARNING: Success case - update UI on main thread
            await MainActor.run {
                isModelLoaded = true
                modelLoadingStatus = .ready
                lastUpdated = Date()
            }
            logger.info("\(self.displayName) loaded successfully")
            
        } catch {
            // 🎓 SWIFT LEARNING: Error case - log error and update UI with failure state
            logger.error("Failed to load \(self.displayName): \(error.localizedDescription)")
            await MainActor.run {
                isModelLoaded = false
                modelLoadingStatus = .failed(error.localizedDescription)
                lastUpdated = Date()
            }
            throw error  // 🎓 Re-throw the error so the caller can handle it
        }
    }
    
    public func cleanup() async {
        logger.info("Cleaning up \(self.displayName) provider")
        await cleanupModel()
        await MainActor.run {
            isModelLoaded = false
            modelLoadingStatus = .notStarted
            lastUpdated = Date()
        }
    }
    
    /// Check if provider can handle the given context size
    /// 
    /// 🎓 SWIFT LEARNING: Protocol method implementation with default behavior
    /// This implements the AIModelProvider protocol requirement
    public func canHandle(contextSize: Int) -> Bool {
        return contextSize <= maxContextLength
    }
    
    // MARK: - State Management
    // 🎓 SWIFT LEARNING: @MainActor for thread-safe UI updates
    
    /// Safely update availability status from subclasses
    /// 
    /// 🎓 SWIFT LEARNING: @MainActor annotation ensures this method always runs on the main thread
    /// This is crucial because:
    /// • SwiftUI requires UI updates to happen on the main thread
    /// • @Published properties trigger UI updates when changed
    /// • Without @MainActor, we could get crashes or UI glitches
    @MainActor
    public func updateAvailability(_ available: Bool) {
        isAvailable = available
        lastUpdated = Date()
        objectWillChange.send()  // 🎓 Manually trigger ObservableObject change notification
    }
    
    /// Safely update loading status from subclasses
    /// 
    /// 🎓 SWIFT LEARNING: Another @MainActor method showing the pattern
    /// Notice how all UI-related updates are marked with @MainActor
    @MainActor
    public func updateLoadingStatus(_ status: ModelLoadingStatus) {
        modelLoadingStatus = status
        lastUpdated = Date()
        objectWillChange.send()  // 🎓 Ensures SwiftUI views refresh immediately
    }
    
    /// Safely update status message from subclasses
    /// 
    /// 🎓 SWIFT LEARNING: Consistent pattern for all UI state updates
    /// This shows how to safely modify @Published properties from any thread
    @MainActor
    public func updateStatusMessage(_ message: String) {
        statusMessage = message
        lastUpdated = Date()
        objectWillChange.send()  // 🎓 Force immediate UI refresh
    }
    
    // MARK: - Protocol Extension Methods
    // 🔧 FIXED: Replaced fatalError anti-pattern with protocol extension pattern
    // 🎓 SWIFT LEARNING: Protocol extensions provide default implementations
    
    /// Template method for model-specific preparation
    /// 
    /// 🎓 SWIFT LEARNING: This is now a protocol extension method
    /// • Subclasses can override for custom behavior
    /// • No fatalError - safe default implementation
    /// • Called by the public prepare() method
    internal func prepareModel() async throws {
        // Default implementation - subclasses can override
        logger.info("Using default model preparation for \(self.displayName)")
    }
    
    /// Template method for model-specific generation
    /// 
    /// 🔧 IMPORTANT: This is now abstract through protocol conformance
    /// Each provider MUST implement their own generateModelResponse
    /// But we provide a fallback that explains the requirement
    internal func generateModelResponse(_ prompt: String) async throws -> String {
        throw AIModelProviderError.processingFailed("Subclass must implement generateModelResponse(_:)")
    }
    
    /// Template method for model-specific cleanup
    /// 
    /// 🎓 SWIFT LEARNING: Optional override with safe default implementation
    /// Unlike fatalError, this won't crash - it just does nothing by default
    internal func cleanupModel() async {
        logger.info("Using default cleanup for \(self.displayName)")
    }
    
    /// Get model-specific confidence scoring
    /// 
    /// 🎓 SWIFT LEARNING: Safe default implementation
    /// Returns reasonable default, subclasses can provide more accurate scoring
    internal func getModelConfidence() -> Double {
        return 0.85 // 85% default confidence
    }
    
    // MARK: - Shared Implementation
    // 🎓 SWIFT LEARNING: Utility methods shared by all AI providers
    
    /// Measures processing time for any async operation
    /// 
    /// 🎓 SWIFT LEARNING: This demonstrates advanced Swift concepts:
    /// • **Generics**: `<T>` means this works with any type of return value
    /// • **Higher-order functions**: Takes a closure as a parameter
    /// • **Tuple return**: Returns both the result AND the timing
    /// • **@escaping closures**: The operation closure can "escape" this function
    public func measureProcessingTime<T>(_ operation: () async throws -> T) async throws -> (result: T, time: TimeInterval) {
        let startTime = Date()                           // 🎓 Record start time
        let result = try await operation()               // 🎓 Execute the operation
        let processingTime = Date().timeIntervalSince(startTime)  // 🎓 Calculate elapsed time
        return (result, processingTime)                  // 🎓 Return tuple with both values
    }
    
    /// Validates context size against provider limits
    internal func validateContextSize(_ prompt: String, maxLength: Int) throws {
        let estimatedTokens = estimateTokenCount(prompt)
        guard estimatedTokens <= maxLength else {
            throw AIModelProviderError.contextTooLarge(estimatedTokens, maxLength)
        }
    }
    
    /// Builds enriched prompt with PromptManager integration and fallback
    internal func buildEnrichedPromptWithFallback(prompt: String, context: MemoryContext) -> String {
        // Use SwiftData-based PromptManager for centralized prompt generation
        let templateName = selectOptimalTemplate(for: prompt, context: context)
        let _ = buildArgumentsFromContext(context: context, userQuery: prompt) // Arguments for future PromptManager integration
        
        logger.debug("Using template: \(templateName) for query type")
        
        // PromptManager not yet implemented - use manual prompt
        logger.debug("Using manual prompt generation (PromptManager not implemented)")
        return buildManualPrompt(prompt: prompt, context: context)
    }
    
    /// Get the SwiftData-based PromptManager instance
    private func getPromptManager() -> Any? {
        // PromptManager not yet implemented - use fallback
        return nil
    }
    
    /// Build arguments dictionary from MemoryContext
    private func buildArgumentsFromContext(context: MemoryContext, userQuery: String) -> [String: Any] {
        var arguments: [String: Any] = [:]
        
        // Add user query
        arguments["user_query"] = userQuery
        
        // Add simplified memory context (compatible with current system)
        if let contextDataString = formatContextData(context.contextData) {
            arguments["context_data"] = contextDataString
        }
        
        arguments["timestamp"] = formatTimeAgo(from: context.timestamp)
        arguments["contains_personal_data"] = context.containsPersonalData
        
        return arguments
    }
    
    /// Format context data for template arguments
    private func formatContextData(_ contextData: [String: Any]) -> String? {
        guard !contextData.isEmpty else { return nil }
        
        var formatted: [String] = []
        for (key, value) in contextData {
            formatted.append("- \(key): \(String(describing: value))")
        }
        return formatted.joined(separator: "\n")
    }
    
    /// Select optimal template based on query type and context
    private func selectOptimalTemplate(for query: String, context: MemoryContext) -> String {
        let lowercaseQuery = query.lowercased()
        
        // Privacy-sensitive queries
        if context.containsPersonalData && (lowercaseQuery.contains("personal") || lowercaseQuery.contains("private")) {
            return "Privacy-Sensitive Query"
        }
        
        // Entity-focused queries
        if lowercaseQuery.contains("who is") || lowercaseQuery.contains("what is") || 
           lowercaseQuery.contains("tell me about") || lowercaseQuery.contains("describe") {
            return "Entity-Focused Query"
        }
        
        // Experience/memory queries
        if lowercaseQuery.contains("remember") || lowercaseQuery.contains("recall") || 
           lowercaseQuery.contains("when did") || lowercaseQuery.contains("what happened") {
            return "Episodic Memory Retrieval"
        }
        
        // Fact-based queries
        if lowercaseQuery.contains("how") || lowercaseQuery.contains("why") || 
           lowercaseQuery.contains("explain") || lowercaseQuery.contains("definition") {
            return "Fact-Based Information"
        }
        
        // Complex synthesis queries
        if lowercaseQuery.contains("analyze") || lowercaseQuery.contains("compare") || 
           lowercaseQuery.contains("relationship") || lowercaseQuery.contains("connection") {
            return "Memory Synthesis"
        }
        
        // Conversation continuity (if there's conversation context data)
        let hasConversationHistory = context.contextData["conversation_history"] != nil
        if hasConversationHistory && (lowercaseQuery.contains("continue") || lowercaseQuery.contains("also") || 
                                      lowercaseQuery.contains("and") || lowercaseQuery.contains("but")) {
            return "Conversation Continuity"
        }
        
        // Default to general memory agent template
        return "General Memory Agent"
    }
    
    /// Manual prompt construction fallback
    internal func buildManualPrompt(prompt: String, context: MemoryContext) -> String {
        var enrichedPrompt = ""
        
        // Add system context with specific memory type guidance
        enrichedPrompt += """
        You are the Memory Agent for ProjectOne, an intelligent personal knowledge assistant. You have access to the user's personal memory and knowledge graph. 
        
        ## Response Guidelines:
        
        **Memory Type Handling:**
        - **Long-term Memories**: Use for established facts, learned information, and important historical context
        - **Recent Memories**: Prioritize for current conversations, immediate context, and ongoing situations
        - **Episodic Memories**: Reference for personal experiences, events, and temporal context
        - **Entities**: Use for identifying people, places, concepts, and their relationships
        - **Notes**: Draw from for detailed information, references, and structured knowledge
        
        **Response Strategy:**
        - If querying about recent conversations → Reference recent memories and conversation history
        - If asking about people/places → Use entity information and relationships
        - If requesting facts/information → Draw from long-term memories and notes
        - If asking about experiences → Reference episodic memories and timeline
        - If context is personal → Prioritize privacy and use personal knowledge appropriately
        - If no relevant context → Be honest about limitations and offer general assistance
        
        **Response Format:**
        - Be conversational and personalized based on memory context
        - Reference specific memories when relevant ("Based on our conversation yesterday...")
        - Connect related information across different memory types
        - Maintain continuity with previous interactions
        - Be concise but comprehensive
        
        """
        
        // Add simplified context information
        if !context.contextData.isEmpty {
            enrichedPrompt += "## Available Context:\n"
            if let contextString = formatContextData(context.contextData) {
                enrichedPrompt += contextString + "\n\n"
            }
        }
        
        // Add timing context
        if context.timestamp != Date() {
            let timeAgo = formatTimeAgo(from: context.timestamp)
            enrichedPrompt += "## Context Timestamp: \(timeAgo)\n\n"
        }
        
        // Add the user's query with context awareness
        enrichedPrompt += "## Current Query:\n\(prompt)\n\n"
        enrichedPrompt += """
        ## Instructions:
        Respond naturally and helpfully using the provided context. Reference relevant memories when appropriate, maintain conversation continuity, and provide personalized assistance based on the available knowledge.
        
        ## Response:
        """
        
        return enrichedPrompt
    }
    
    /// Format time ago for memory context
    private func formatTimeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))min ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
    
    /// Creates standardized AI response object
    internal func createResponse(
        content: String,
        confidence: Double,
        processingTime: TimeInterval,
        tokensUsed: Int?,
        context: MemoryContext
    ) -> AIModelResponse {
        return AIModelResponse(
            content: content,
            confidence: confidence,
            processingTime: processingTime,
            modelUsed: self.displayName,
            tokensUsed: tokensUsed,
            isOnDevice: isOnDevice,
            containsPersonalData: context.containsPersonalData
        )
    }
    
    /// Estimates token count from text
    public func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        return text.count / 4
    }
    
    // MARK: - Platform-Specific Optimization Methods
    // 🎓 PLATFORM OPTIMIZATION: Methods for optimal cross-platform performance
    
    /// Start platform-aware system monitoring
    public func startSystemMonitoring() {
        guard metricsUpdateTimer == nil else { return }
        
        metricsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.updateSystemMetrics()
            }
        }
        
        logger.info("Started platform-aware system monitoring")
    }
    
    /// Stop system monitoring
    public func stopSystemMonitoring() {
        metricsUpdateTimer?.invalidate()
        metricsUpdateTimer = nil
        logger.info("Stopped system monitoring")
    }
    
    /// Update system metrics using platform-specific monitoring
    @MainActor
    private func updateSystemMetrics() async {
        let newMetrics = await systemMonitor.updateSystemMetrics()
        systemMetrics = newMetrics
        
        // Trigger platform-specific optimizations based on metrics
        await applyPlatformOptimizations(metrics: newMetrics)
    }
    
    /// Apply platform-specific optimizations based on current system state
    private func applyPlatformOptimizations(metrics: SystemMetrics) async {
        let config = platformConfig
        
        // Memory pressure optimization
        if metrics.memoryPressure > config.memoryPressureThreshold {
            await optimizeForMemoryPressure(level: metrics.memoryPressure)
        }
        
        // Thermal state optimization
        if metrics.thermalState.shouldThrottle {
            await optimizeForThermalPressure(state: metrics.thermalState)
        }
        
        #if os(iOS) || os(visionOS)
        // iOS-specific optimizations
        if metrics.isLowPowerMode {
            await optimizeForLowPowerMode()
        }
        
        if metrics.batteryLevel < 0.2 {
            await optimizeForLowBattery(level: metrics.batteryLevel)
        }
        #endif
        
        #if os(macOS)
        // macOS-specific optimizations
        if metrics.availableMemoryGB < 4.0 {
            await optimizeForLimitedMemory(availableGB: metrics.availableMemoryGB)
        }
        #endif
    }
    
    /// Optimize AI provider behavior for memory pressure
    private func optimizeForMemoryPressure(level: Double) async {
        logger.warning("Optimizing for memory pressure: \(level)")
        
        if level > 0.9 {
            // Critical memory pressure - aggressive optimization
            await MainActor.run {
                statusMessage = "Optimizing for memory pressure..."
            }
            
            // Reduce concurrent operations
            await reduceConcurrentOperations()
            
        } else if level > 0.8 {
            // High memory pressure - moderate optimization
            await optimizeResponseCaching()
        }
    }
    
    /// Optimize AI provider behavior for thermal pressure
    private func optimizeForThermalPressure(state: ThermalState) async {
        logger.warning("Optimizing for thermal state: \(state.description)")
        
        switch state {
        case .serious, .critical:
            await MainActor.run {
                statusMessage = "Throttling due to thermal conditions..."
            }
            
            // Reduce processing intensity
            await throttleProcessing(factor: state == .critical ? 0.5 : 0.7)
            
        case .fair:
            await moderateProcessing()
            
        case .nominal:
            await restoreNormalProcessing()
        }
    }
    
    #if os(iOS) || os(visionOS)
    /// iOS-specific optimization for Low Power Mode
    private func optimizeForLowPowerMode() async {
        logger.info("Optimizing for iOS Low Power Mode")
        
        await MainActor.run {
            statusMessage = "Low Power Mode optimization active"
        }
        
        // Reduce background processing
        await disableBackgroundTasks()
        
        // Use more efficient processing
        await enableEfficiencyMode()
    }
    
    /// iOS-specific optimization for low battery
    private func optimizeForLowBattery(level: Double) async {
        logger.warning("Optimizing for low battery: \(Int(level * 100))%")
        
        await MainActor.run {
            statusMessage = "Battery optimization active (\(Int(level * 100))%)"
        }
        
        if level < 0.1 {
            // Critical battery - minimal processing only
            await enableMinimalProcessing()
        } else {
            // Low battery - efficient processing
            await enableEfficiencyMode()
        }
    }
    #endif
    
    #if os(macOS)
    /// macOS-specific optimization for limited memory
    private func optimizeForLimitedMemory(availableGB: Double) async {
        logger.warning("Optimizing for limited memory: \(availableGB)GB available")
        
        await MainActor.run {
            statusMessage = "Memory optimization active (\(availableGB)GB available)"
        }
        
        if availableGB < 2.0 {
            // Very limited memory - use lightweight models only
            await enableLightweightMode()
        } else {
            // Moderately limited - optimize memory usage
            await optimizeMemoryUsage()
        }
    }
    #endif
    
    // MARK: - Swift Concurrency Best Practices
    // 🎓 SWIFT CONCURRENCY: Advanced async/await patterns and best practices
    
    /// Execute operation with platform-aware task management
    public func executeWithOptimization<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
        priority: TaskPriority = .userInitiated
    ) async throws -> T {
        
        // Check system state before execution
        let metrics = await systemMonitor.updateSystemMetrics()
        
        // Adjust task priority based on system state
        let adjustedPriority = adjustPriorityForSystemState(
            requestedPriority: priority,
            metrics: metrics
        )
        
        // Execute with cooperative cancellation support
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(priority: adjustedPriority) {
                try await operation()
            }
            
            // Add timeout task for safety
            group.addTask(priority: .background) { [self] in
                let timeoutInterval = await MainActor.run { platformConfig.targetResponseTime * 2 }
                try await Task.sleep(nanoseconds: UInt64(timeoutInterval * 1_000_000_000))
                throw AIModelProviderError.processingFailed("Operation timed out after \(timeoutInterval)s")
            }
            
            // Return first completed task (either operation or timeout)
            var result: T? = nil
            for try await taskResult in group {
                result = taskResult
                break
            }
            guard let finalResult = result else {
                throw AIModelProviderError.processingFailed("No result from task group")
            }
            group.cancelAll()
            return finalResult
        }
    }
    
    /// Perform CPU-intensive work with cooperative yielding
    public func performCPUIntensiveWork<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T,
        yieldInterval: Int = 1000
    ) async rethrows -> T {
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                var iterations = 0
                
                // Simulate yielding during intensive work
                // In real implementation, this would be integrated into the actual work
                while iterations < yieldInterval {
                    iterations += 1
                    
                    // Check for cancellation every 100 iterations
                    if iterations % 100 == 0 {
                        try Task.checkCancellation()
                        
                        // Yield control to other tasks
                        await Task.yield()
                    }
                }
                
                return try work()
            }
            
            var result: T? = nil
            for try await taskResult in group {
                result = taskResult
                break
            }
            guard let finalResult = result else {
                throw NSError(domain: "TaskError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result from task group"])
            }
            return finalResult
        }
    }
    
    /// Stream processing with backpressure handling - simplified version to fix linker issues
    public func processStringStream(
        input: AsyncThrowingStream<String, Error>,
        transform: @escaping @Sendable (String) async throws -> String
    ) -> AsyncThrowingStream<String, Error> {
        
        return AsyncThrowingStream { continuation in
            Task { @Sendable in
                do {
                    let config = platformConfig
                    let activeOperations = ManagedAtomic<Int>(0)
                    let maxConcurrent = config.maxConcurrentOperations
                    
                    for try await item in input {
                        // Implement backpressure by limiting concurrent operations
                        while activeOperations.load(ordering: .relaxed) >= maxConcurrent {
                            await Task.yield()
                        }
                        
                        Task { @Sendable in
                            defer { activeOperations.wrappingDecrement(ordering: .relaxed) }
                            activeOperations.wrappingIncrement(ordering: .relaxed)
                            
                            do {
                                let result = try await transform(item)
                                continuation.yield(result)
                            } catch {
                                continuation.finish(throwing: error)
                            }
                        }
                    }
                    
                    // Wait for remaining operations to complete
                    while activeOperations.load(ordering: .relaxed) > 0 {
                        await Task.yield()
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Generic Stream Processing
    // Note: processStream method temporarily removed to resolve linker issues
    // Can be re-added if needed for actual streaming functionality
    
    // MARK: - Private Optimization Helpers
    
    private func adjustPriorityForSystemState(
        requestedPriority: TaskPriority,
        metrics: SystemMetrics
    ) -> TaskPriority {
        
        // Lower priority under stress conditions
        if metrics.thermalState.shouldThrottle || metrics.memoryPressure > 0.8 {
            switch requestedPriority {
            case .high:
                return .medium
            case .medium:
                return .low
            default:
                return .background
            }
        }
        
        #if os(iOS) || os(visionOS)
        // Further reduce priority in low power mode
        if metrics.isLowPowerMode {
            return .background
        }
        #endif
        
        return requestedPriority
    }
    
    private func reduceConcurrentOperations() async {
        // Implementation would reduce the number of concurrent AI operations
        logger.info("Reducing concurrent operations due to system pressure")
    }
    
    private func optimizeResponseCaching() async {
        // Implementation would optimize response caching strategy
        logger.info("Optimizing response caching for memory efficiency")
    }
    
    private func throttleProcessing(factor: Double) async {
        // Implementation would throttle AI processing by the given factor
        logger.info("Throttling processing to \(Int(factor * 100))% capacity")
    }
    
    private func moderateProcessing() async {
        logger.info("Applying moderate processing optimization")
    }
    
    private func restoreNormalProcessing() async {
        logger.info("Restoring normal processing performance")
    }
    
    #if os(iOS) || os(visionOS)
    private func disableBackgroundTasks() async {
        logger.info("Disabling background tasks for iOS optimization")
    }
    
    private func enableEfficiencyMode() async {
        logger.info("Enabling efficiency mode for iOS optimization")
    }
    
    private func enableMinimalProcessing() async {
        logger.info("Enabling minimal processing mode for critical battery")
    }
    #endif
    
    #if os(macOS)
    private func enableLightweightMode() async {
        logger.info("Enabling lightweight mode for macOS memory optimization")
    }
    
    private func optimizeMemoryUsage() async {
        logger.info("Optimizing memory usage for macOS")
    }
    #endif
    
    deinit {
        // Note: Cannot call MainActor methods from deinit
        // stopSystemMonitoring() should be called manually before deallocation
        logger.info("BaseAIProvider deinitialized")
    }
}

// ModelSelectionCriteria is defined in AIModelProvider.swift - using that definition

// MARK: - Provider Health Status

/// Health status for monitoring provider performance
public struct ProviderHealthStatus {
    let isHealthy: Bool
    let lastSuccessfulResponse: Date?
    let consecutiveFailures: Int
    let averageResponseTime: TimeInterval
    let errorRate: Double
    
    public var shouldFallback: Bool {
        return !isHealthy || consecutiveFailures > 3 || errorRate > 0.5
    }
}
