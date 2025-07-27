//
//  UnifiedAITestView.swift
//  ProjectOne
//
//  🎓 SWIFT LEARNING: This file demonstrates advanced SwiftUI and Swift concepts:
//  • **SwiftUI State Management**: @State, @StateObject for reactive UI
//  • **Conditional Compilation**: #if os() for cross-platform support
//  • **TaskGroups**: Structured concurrency for parallel AI testing
//  • **AsyncSequence**: Streaming async operations
//  • **Custom View Components**: Reusable UI building blocks
//  • **Cross-Platform Development**: iOS/macOS compatibility
//  • **Protocol-Oriented Programming**: TestProviderType enum behavior
//  • **Memory Management**: Weak references and lifecycle handling
//
//  Comprehensive AI provider testing interface for all available providers
//

import SwiftUI
// 🎓 SWIFT LEARNING: Conditional compilation for cross-platform development
#if os(iOS)
import UIKit
typealias UImage = UIImage    // 🎓 Type alias allows using UImage for both platforms
#elseif os(macOS)
import AppKit
typealias UImage = NSImage    // 🎓 Same interface, different underlying types
#endif

// MARK: - Data Models
// 🎓 SWIFT LEARNING: Custom data structures for UI state management

// MARK: - Provider Test Result

/// Data structure representing the result of testing an AI provider
/// 
/// 🎓 SWIFT LEARNING: Struct with computed properties and data formatting
/// • Structs are value types (copied, not referenced)
/// • Computed properties provide derived data from stored properties
/// • Used to pass test results between view components
struct ProviderTestResult {
    // 🎓 SWIFT LEARNING: Stored properties - the actual data this struct holds
    let providerName: String        // 🎓 Name of the AI provider tested
    let response: String           // 🎓 Generated response or empty if failed
    let responseTime: TimeInterval // 🎓 How long the generation took
    let success: Bool             // 🎓 Whether the test succeeded
    let error: String?            // 🎓 Optional - only set if test failed
    
    // 🎓 SWIFT LEARNING: Computed property for formatted display
    // Converts raw TimeInterval to user-friendly string
    var displayTime: String {
        String(format: "%.2fs", responseTime)  // 🎓 Format to 2 decimal places
    }
}

// MARK: - Provider Type Enumeration
// 🎓 SWIFT LEARNING: Enum with raw values, computed properties, and protocol conformance

/// Enumeration of all AI providers available for testing
/// 
/// 🎓 SWIFT LEARNING: This enum demonstrates several advanced Swift features:
/// • **Raw Values**: String literals that can be used for display
/// • **CaseIterable**: Automatically provides .allCases array
/// • **Computed Properties**: Different behavior per case (icon, color, capabilities)
/// • **Switch Statements**: Pattern matching for case-specific behavior
/// • **Protocol Conformance**: Hashable for Set<TestProviderType> usage
enum TestProviderType: String, CaseIterable {
    case mlxLLM = "MLX LLM (Text-Only)"                // 🎓 Raw value for display
    case mlxVLM = "MLX VLM (Multimodal)"
    case appleFoundationModels = "Apple Foundation Models"
    case enhancedGemma3nCore = "Enhanced Gemma3n Core"
    
    // 🎓 SWIFT LEARNING: Computed property using switch statement
    // Each provider type gets a different SF Symbol icon
    var icon: String {
        switch self {
        case .mlxLLM: return "textformat"           // 🎓 Text-only icon
        case .mlxVLM: return "photo.on.rectangle"   // 🎓 Multimodal icon
        case .appleFoundationModels: return "apple.logo"  // 🎓 Apple icon
        case .enhancedGemma3nCore: return "cpu"     // 🎓 Processing icon
        }
    }
    
    // 🎓 SWIFT LEARNING: Another computed property for UI theming
    // Each provider gets a distinctive color in the UI
    var color: Color {
        switch self {
        case .mlxLLM: return .blue      // 🎓 SwiftUI built-in colors
        case .mlxVLM: return .purple
        case .appleFoundationModels: return .green
        case .enhancedGemma3nCore: return .orange
        }
    }
    
    // 🎓 SWIFT LEARNING: Computed property for capability checking
    // Determines which providers need iOS 26.0+
    var requiresIOS26: Bool {
        switch self {
        case .appleFoundationModels, .enhancedGemma3nCore: 
            return true   // 🎓 These need iOS 26+ Foundation Models
        default: 
            return false  // 🎓 MLX providers work on older iOS
        }
    }
    
    // 🎓 SWIFT LEARNING: Feature capability detection
    // Determines which providers can handle images
    var supportsImages: Bool {
        switch self {
        case .mlxVLM, .enhancedGemma3nCore: 
            return true   // 🎓 Vision-language models support images
        default: 
            return false  // 🎓 Text-only models don't support images
        }
    }
}

// MARK: - Main Test View
// 🎓 SWIFT LEARNING: SwiftUI view with complex state management

/// Main SwiftUI view for testing all AI providers
/// 
/// 🎓 SWIFT LEARNING: This view demonstrates advanced SwiftUI patterns:
/// • **@available**: Conditional API availability (requires iOS 26.0+)
/// • **@State**: Local view state that triggers UI updates when changed
/// • **@StateObject**: Creates and owns ObservableObject instances
/// • **Complex State Management**: Multiple coordinated @State properties
/// • **Set<T>**: Swift collections for unique items (selectedProviders)
/// • **Arrays**: Ordered collections for results and images
/// • **Three-Layer Architecture**: Service → Provider → Core instances
@available(iOS 26.0, macOS 26.0, *)  // 🎓 Only available on iOS 26+ for Foundation Models
struct UnifiedAITestView: View {
    
    // MARK: - UI State Properties
    // 🎓 SWIFT LEARNING: @State properties for reactive UI updates
    
    // 🎓 SWIFT LEARNING: @State creates reactive data binding
    // When these properties change, SwiftUI automatically re-renders affected UI components
    @State private var testPrompt = "Hello, how are you? Please tell me a short joke, Jared."
    @State private var selectedProviders: Set<TestProviderType> = [.mlxLLM, .appleFoundationModels]
    @State private var testResults: [ProviderTestResult] = []       // 🎓 Array of test results
    @State private var isLoading = false                           // 🎓 Overall loading state
    @State private var showComparison = false                      // 🎓 UI mode toggle
    @State private var loadingProviders: Set<TestProviderType> = [] // 🎓 Which providers are currently loading
    @State private var selectedImages: [UImage] = []               // 🎓 Images for multimodal testing
    @State private var showImagePicker = false                     // 🎓 Image picker sheet state
    
    // MARK: - AI Provider Instances
    // 🎓 SWIFT LEARNING: @StateObject for ObservableObject lifecycle management
    
    // 🎓 SWIFT LEARNING: @StateObject vs @ObservedObject:
    // • @StateObject: View OWNS the object, creates it once and keeps it alive
    // • @ObservedObject: View OBSERVES object owned by someone else
    // • These create the actual AI provider instances this view will test
    @StateObject private var mlxLLMProvider = MLXLLMProvider()                      // 🎓 Text-only MLX
    @StateObject private var mlxVLMProvider = MLXVLMProvider()                      // 🎓 Multimodal MLX  
    @StateObject private var workingMLXProvider = WorkingMLXProvider()              // 🎓 Working MLX implementation
    @StateObject private var appleFoundationProvider = AppleFoundationModelsProvider() // 🎓 Apple's Foundation Models
    @StateObject private var enhancedCore = EnhancedGemma3nCore()                  // 🎓 Enhanced Gemma3n orchestrator
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Provider Selection Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select AI Providers to Test")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(TestProviderType.allCases, id: \.self) { providerType in
                                ProviderSelectionCard(
                                    providerType: providerType,
                                    isSelected: selectedProviders.contains(providerType),
                                    isAvailable: isProviderAvailable(providerType),
                                    onToggle: { toggleProvider(providerType) }
                                )
                            }
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Test Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Prompt")
                            .font(.headline)
                        
                        TextField("Enter test prompt", text: $testPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                        
                        HStack(spacing: 12) {
                            Button("Test Selected") {
                                testSelectedProviders()
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .blue))
                            .disabled(selectedProviders.isEmpty || isLoading || testPrompt.isEmpty)
                            
                            Button("Test All Available") {
                                testAllAvailableProviders()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(isLoading || testPrompt.isEmpty)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Testing \(loadingProviders.count) provider(s)...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Provider Status Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Provider Status")
                            .font(.headline)
                        
                        ProviderStatusGrid(
                            workingMLXProvider: workingMLXProvider,
                            appleFoundationProvider: appleFoundationProvider
                        )
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    // Test Results Section
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Test Results")
                                    .font(.headline)
                                Spacer()
                                Button("Clear") {
                                    testResults.removeAll()
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            
                            ForEach(testResults.indices, id: \.self) { index in
                                TestResultCard(result: testResults[index])
                            }
                        }
                        .padding()
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    // Example Prompts Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Example Prompts")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(examplePrompts, id: \.self) { prompt in
                                Button(prompt) {
                                    testPrompt = prompt
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                                .lineLimit(2)
                            }
                        }
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding()
            }
            .navigationTitle("AI Provider Testing")
            #if os(iOS) || os(iPadOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                setupProviders()
                debugProviderAvailability()
            }
        }
    }
    
    // MARK: - Example Prompts
    
    private let examplePrompts = [
        "Hello world",
        "What is AI?",
        "Explain machine learning briefly",
        "Tell me a short joke",
        "What is Swift programming?",
        "How does on-device AI work?",
        "Summarize: AI is transforming technology",
        "Generate a creative story opening"
    ]
    
    // MARK: - Helper Methods
    
    private func isProviderAvailable(_ providerType: TestProviderType) -> Bool {
        switch providerType {
        case .enhancedGemma3nCore:
            return true // Always try to test the enhanced core
        case .mlxVLM:
            return mlxVLMProvider.isSupported
        case .mlxLLM:
            // Use working MLX provider for MLX LLM testing
            return workingMLXProvider.isMLXSupported
        case .appleFoundationModels:
            return appleFoundationProvider.isAvailable
        }
    }
    
    private func toggleProvider(_ providerType: TestProviderType) {
        if selectedProviders.contains(providerType) {
            selectedProviders.remove(providerType)
        } else {
            selectedProviders.insert(providerType)
        }
    }
    
    private func setupProviders() {
        Task {
            print("🚀 Setting up AI providers...")
            
            // Setup Apple Foundation Models first (quick)
            do {
                try await appleFoundationProvider.prepareModel()
                print("✅ Apple Foundation Models ready: \(appleFoundationProvider.isAvailable)")
            } catch {
                print("❌ Apple Foundation Models failed: \(error)")
            }
            
            // Setup Enhanced Gemma3n Core (orchestrates all providers)
            await enhancedCore.setup()
            print("✅ Enhanced Gemma3n Core ready: \(enhancedCore.isReady)")
            
            // Setup Working MLX Provider for direct testing
            if workingMLXProvider.isMLXSupported {
                do {
                    let recommendedModel = workingMLXProvider.getRecommendedModel()
                    print("🔄 Loading MLX model: \(recommendedModel.displayName)")
                    try await workingMLXProvider.loadModel(recommendedModel)
                    print("✅ Working MLX Provider ready: \(workingMLXProvider.isReady)")
                } catch {
                    print("❌ Working MLX Provider failed: \(error)")
                }
            } else {
                print("❌ MLX not supported on this device (simulator or Intel Mac)")
            }
            
            // Setup MLX LLM Provider (legacy)
            if mlxLLMProvider.isSupported {
                do {
                    try await mlxLLMProvider.loadRecommendedModel()
                    print("✅ MLX LLM Provider ready: \(mlxLLMProvider.isReady)")
                } catch {
                    print("❌ MLX LLM Provider failed: \(error)")
                }
            }
            
            print("🎯 Provider setup complete!")
        }
    }
    
    private func testSelectedProviders() {
        guard !selectedProviders.isEmpty && !testPrompt.isEmpty else { return }
        testProviders(Array(selectedProviders))
    }
    
    private func testAllAvailableProviders() {
        guard !testPrompt.isEmpty else { return }
        let availableProviders = TestProviderType.allCases.filter { isProviderAvailable($0) }
        testProviders(availableProviders)
    }
    
    /// Tests multiple AI providers concurrently using TaskGroup
    /// 
    /// 🎓 SWIFT LEARNING: This method demonstrates advanced Swift concurrency:
    /// • **TaskGroup**: Structured concurrency for parallel operations
    /// • **Task**: Creates concurrent execution context  
    /// • **MainActor.run**: Thread-safe UI updates
    /// • **await**: Suspends function until async operations complete
    /// • **Concurrent Collection**: Building results from parallel operations
    private func testProviders(_ providers: [TestProviderType]) {
        // 🎓 SWIFT LEARNING: Update UI state before starting async work
        isLoading = true                        // 🎓 Show loading UI
        loadingProviders = Set(providers)       // 🎓 Track which providers are loading
        testResults.removeAll()                 // 🎓 Clear previous results
        
        // 🎓 SWIFT LEARNING: Task creates a new concurrent context
        // This prevents the UI from blocking while tests run
        Task {
            var results: [ProviderTestResult] = []  // 🎓 Collect results from parallel tests
            
            // 🎓 SWIFT LEARNING: withTaskGroup enables structured concurrency
            // This is the safe way to run multiple async operations in parallel
            await withTaskGroup(of: ProviderTestResult.self) { group in
                
                // 🎓 SWIFT LEARNING: Add a task for each provider
                // All these tasks will run concurrently (in parallel)
                for providerType in providers {
                    group.addTask {  // 🎓 Each addTask creates a parallel operation
                        await testProvider(providerType)  // 🎓 Test this provider
                    }
                }
                
                // 🎓 SWIFT LEARNING: Collect results as they complete
                // 'for await' iterates over results as they finish (not in order!)
                for await result in group {
                    results.append(result)  // 🎓 Add each completed test result
                }
            }
            
            // 🎓 SWIFT LEARNING: Update UI on main thread when all tests complete
            // MainActor.run ensures UI updates happen safely
            await MainActor.run {
                // 🎓 Sort results by response time (fastest first)
                testResults = results.sorted { $0.responseTime < $1.responseTime }
                isLoading = false           // 🎓 Hide loading UI
                loadingProviders.removeAll() // 🎓 Clear loading state
            }
        }
    }
    
    private func testProvider(_ providerType: TestProviderType) async -> ProviderTestResult {
        let startTime = Date()
        
        do {
            let response = try await generateResponse(for: providerType, prompt: testPrompt)
            let responseTime = Date().timeIntervalSince(startTime)
            
            return ProviderTestResult(
                providerName: providerType.rawValue,
                response: response,
                responseTime: responseTime,
                success: true,
                error: nil
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            
            return ProviderTestResult(
                providerName: providerType.rawValue,
                response: "",
                responseTime: responseTime,
                success: false,
                error: error.localizedDescription
            )
        }
    }
    
    private func generateResponse(for providerType: TestProviderType, prompt: String) async throws -> String {
        switch providerType {
        case .mlxLLM:
            // Use the working MLX provider since it has the real implementation
            return try await workingMLXProvider.generateResponse(to: prompt)
            
        case .mlxVLM:
            return try await mlxVLMProvider.generateResponse(to: prompt)
            
        case .appleFoundationModels:
            // Check availability and provide detailed error if not available
            guard appleFoundationProvider.isAvailable else {
                let status = appleFoundationProvider.modelLoadingStatus
                let errorMessage: String
                switch status {
                case .failed(let message):
                    errorMessage = message
                case .notStarted:
                    errorMessage = "Apple Foundation Models not initialized"
                case .preparing:
                    errorMessage = "Apple Foundation Models still preparing"
                case .downloading(let progress):
                    errorMessage = "Apple Foundation Models downloading (\(Int(progress * 100))%)"
                case .loading:
                    errorMessage = "Apple Foundation Models loading"
                case .ready:
                    errorMessage = "Model ready but marked unavailable"
                case .unavailable:
                    errorMessage = "Apple Foundation Models unavailable"
                }
                throw AIProviderError.notAvailable("Apple Foundation Models not available: \(errorMessage)")
            }
            
            // Use the existing provider instance that was already set up
            return try await appleFoundationProvider.generateModelResponse(prompt)
            
        case .enhancedGemma3nCore:
            // Use the existing core instance that was already set up
            return await enhancedCore.processText(prompt)
        }
    }
    
    // MARK: - Debug Methods
    
    private func debugProviderAvailability() {
        print("=== Provider Availability Debug ===")
        print("Target Environment: macOS")
        print("Architecture: arm64")
        
        #if targetEnvironment(simulator)
        print("❌ Running in simulator")
        #else
        print("✅ Running on real hardware")
        #endif
        
        #if arch(arm64)
        print("✅ Apple Silicon (arm64)")
        #else
        print("❌ Intel architecture")
        #endif
        
        #if canImport(MLXLMCommon)
        print("✅ MLXLMCommon framework available")
        #else
        print("❌ MLXLMCommon framework NOT available")
        #endif
        
        
        print("WorkingMLXProvider.isMLXSupported: \(workingMLXProvider.isMLXSupported)")
        print("MLXLLMProvider.isSupported: \(mlxLLMProvider.isSupported)")
        print("MLXVLMProvider.isSupported: \(mlxVLMProvider.isSupported)")
        print("AppleFoundationProvider.isAvailable: \(appleFoundationProvider.isAvailable)")
        print("====================================")
    }
}

// MARK: - Supporting Views

struct ProviderSelectionCard: View {
    let providerType: TestProviderType
    let isSelected: Bool
    let isAvailable: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: providerType.icon)
                        .foregroundColor(isAvailable ? providerType.color : .gray)
                        .font(.title2)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(providerType.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    if !isAvailable {
                        Text(providerType.requiresIOS26 ? "iOS 26.0+ required" : "Not available")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? providerType.color.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? providerType.color : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1.0 : 0.6)
    }
}

struct ProviderStatusGrid: View {
    let workingMLXProvider: WorkingMLXProvider
    let appleFoundationProvider: AppleFoundationModelsProvider
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ProviderStatusCard(
                name: "Working MLX",
                status: workingMLXProvider.isReady ? "Ready" : "Not loaded",
                isReady: workingMLXProvider.isReady,
                color: .blue
            )
            
            ProviderStatusCard(
                name: "Foundation Models",
                status: appleFoundationProvider.isAvailable ? "Available" : "Not available",
                isReady: appleFoundationProvider.isAvailable,
                color: .green
            )
        }
    }
}

struct ProviderStatusCard: View {
    let name: String
    let status: String
    let isReady: Bool
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Circle()
                    .fill(isReady ? .green : .red)
                    .frame(width: 8, height: 8)
            }
            
            Text(status)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct TestResultCard: View {
    let result: ProviderTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(result.providerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(result.displayTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.success ? .green : .red)
                        .font(.caption)
                }
            }
            
            if result.success {
                ScrollView {
                    Text(result.response)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 120)
            } else {
                Text("Error: \(result.error ?? "Unknown error")")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.8 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.secondary.opacity(configuration.isPressed ? 0.2 : 0.1))
            .foregroundColor(.primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// MARK: - Error Types

enum AIProviderError: Error, LocalizedError {
    case notAvailable(String)
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            return "Provider not available: \(reason)"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}

// MARK: - Preview

#Preview {
    if #available(iOS 26.0, macOS 26.0, *) {
        UnifiedAITestView()
    }
}
