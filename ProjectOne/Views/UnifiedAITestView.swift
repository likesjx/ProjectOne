//
//  UnifiedAITestView.swift
//  ProjectOne
//
//  Comprehensive AI provider testing interface for all available providers
//

import SwiftUI
#if os(iOS) || os(iPadOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Provider Test Result

struct ProviderTestResult {
    let providerName: String
    let response: String
    let responseTime: TimeInterval
    let success: Bool
    let error: String?
    
    var displayTime: String {
        String(format: "%.2fs", responseTime)
    }
}

// MARK: - Provider Type Enumeration

enum AIProviderType: String, CaseIterable {
    case mlxGemma3n = "MLX Gemma3n"
    case workingMLX = "Working MLX"
    case realFoundationModels = "Foundation Models (Real)"
    case appleFoundationModels = "Foundation Models (Legacy)"
    case enhancedGemma3nCore = "Enhanced Gemma3n Core"
    case appleIntelligence = "Apple Intelligence"
    
    var icon: String {
        switch self {
        case .mlxGemma3n, .workingMLX: return "brain"
        case .realFoundationModels, .appleFoundationModels: return "apple.logo"
        case .enhancedGemma3nCore: return "cpu"
        case .appleIntelligence: return "sparkles"
        }
    }
    
    var color: Color {
        switch self {
        case .mlxGemma3n, .workingMLX: return .blue
        case .realFoundationModels, .appleFoundationModels: return .green
        case .enhancedGemma3nCore: return .orange
        case .appleIntelligence: return .purple
        }
    }
    
    var requiresIOS26: Bool {
        switch self {
        case .realFoundationModels, .enhancedGemma3nCore: return true
        default: return false
        }
    }
}

// MARK: - Main Test View

@available(iOS 18.0, iPadOS 18.0, macOS 15.0, *)
struct UnifiedAITestView: View {
    @State private var testPrompt = "Hello, how are you? Please tell me a short joke."
    @State private var selectedProviders: Set<AIProviderType> = [.workingMLX, .realFoundationModels]
    @State private var testResults: [ProviderTestResult] = []
    @State private var isLoading = false
    @State private var showComparison = false
    @State private var loadingProviders: Set<AIProviderType> = []
    
    // Provider instances
    @StateObject private var mlxGemma3nProvider = MLXGemma3nE2BProvider()
    @StateObject private var workingMLXProvider = WorkingMLXProvider()
    @StateObject private var appleFoundationProvider = AppleFoundationModelsProvider()
    @StateObject private var appleIntelligenceProvider = AppleIntelligenceProvider()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Provider Selection Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select AI Providers to Test")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(AIProviderType.allCases, id: \.self) { providerType in
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
                            mlxGemma3nProvider: mlxGemma3nProvider,
                            workingMLXProvider: workingMLXProvider,
                            appleFoundationProvider: appleFoundationProvider,
                            appleIntelligenceProvider: appleIntelligenceProvider
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
    
    private func isProviderAvailable(_ providerType: AIProviderType) -> Bool {
        switch providerType {
        case .realFoundationModels, .enhancedGemma3nCore:
            if #available(iOS 26.0, iPadOS 26.0, macOS 26.0, *) {
                return true
            } else {
                return false
            }
        case .workingMLX, .mlxGemma3n:
            return workingMLXProvider.isMLXSupported
        case .appleFoundationModels:
            return appleFoundationProvider.isAvailable
        case .appleIntelligence:
            return appleIntelligenceProvider.supportsAppleIntelligence
        }
    }
    
    private func toggleProvider(_ providerType: AIProviderType) {
        if selectedProviders.contains(providerType) {
            selectedProviders.remove(providerType)
        } else {
            selectedProviders.insert(providerType)
        }
    }
    
    private func setupProviders() {
        Task {
            // Prepare MLX providers
            if workingMLXProvider.isMLXSupported {
                do {
                    let recommendedModel = workingMLXProvider.getRecommendedModel()
                    try await workingMLXProvider.loadModel(recommendedModel)
                } catch {
                    print("Failed to setup Working MLX Provider: \(error)")
                }
            }
            
            // Apple Foundation Models provider initializes automatically
            // No additional setup needed
        }
    }
    
    private func testSelectedProviders() {
        guard !selectedProviders.isEmpty && !testPrompt.isEmpty else { return }
        testProviders(Array(selectedProviders))
    }
    
    private func testAllAvailableProviders() {
        guard !testPrompt.isEmpty else { return }
        let availableProviders = AIProviderType.allCases.filter { isProviderAvailable($0) }
        testProviders(availableProviders)
    }
    
    private func testProviders(_ providers: [AIProviderType]) {
        isLoading = true
        loadingProviders = Set(providers)
        testResults.removeAll()
        
        Task {
            var results: [ProviderTestResult] = []
            
            // Test providers concurrently
            await withTaskGroup(of: ProviderTestResult.self) { group in
                for providerType in providers {
                    group.addTask {
                        await testProvider(providerType)
                    }
                }
                
                for await result in group {
                    results.append(result)
                }
            }
            
            await MainActor.run {
                testResults = results.sorted { $0.responseTime < $1.responseTime }
                isLoading = false
                loadingProviders.removeAll()
            }
        }
    }
    
    private func testProvider(_ providerType: AIProviderType) async -> ProviderTestResult {
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
    
    private func generateResponse(for providerType: AIProviderType, prompt: String) async throws -> String {
        switch providerType {
        case .mlxGemma3n:
            return try await mlxGemma3nProvider.generateModelResponse(prompt)
            
        case .workingMLX:
            return try await workingMLXProvider.generateResponse(to: prompt)
            
        case .realFoundationModels:
            if #available(iOS 26.0, iPadOS 26.0, macOS 26.0, *) {
                let provider = RealFoundationModelsProvider()
                return try await provider.generateText(prompt: prompt)
            } else {
                throw AIProviderError.notAvailable("iOS 26.0+ required")
            }
            
        case .enhancedGemma3nCore:
            if #available(iOS 26.0, iPadOS 26.0, macOS 26.0, *) {
                let core = EnhancedGemma3nCore()
                await core.setup()
                return await core.processText(prompt)
            } else {
                throw AIProviderError.notAvailable("iOS 26.0+ required")
            }
            
        case .appleFoundationModels:
            return try await appleFoundationProvider.generateModelResponse(prompt)
            
        case .appleIntelligence:
            if #available(iOS 26.0, iPadOS 26.0, macOS 26.0, *) {
                return try await appleIntelligenceProvider.generateText(prompt: prompt)
            } else {
                let features = appleIntelligenceProvider.getAvailableFeatures()
                return "Apple Intelligence consumer features: \(features.currentFeatures.joined(separator: ", "))"
            }
        }
    }
}

// MARK: - Supporting Views

struct ProviderSelectionCard: View {
    let providerType: AIProviderType
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
    let mlxGemma3nProvider: MLXGemma3nE2BProvider
    let workingMLXProvider: WorkingMLXProvider
    let appleFoundationProvider: AppleFoundationModelsProvider
    let appleIntelligenceProvider: AppleIntelligenceProvider
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ProviderStatusCard(
                name: "MLX Gemma3n",
                status: mlxGemma3nProvider.modelLoadingStatus.description,
                isReady: mlxGemma3nProvider.isModelLoaded,
                color: .blue
            )
            
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
            
            ProviderStatusCard(
                name: "Apple Intelligence",
                status: appleIntelligenceProvider.isAvailable ? "Available" : "Not available",
                isReady: appleIntelligenceProvider.isAvailable,
                color: .purple
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
    if #available(iOS 18.0, iPadOS 18.0, macOS 15.0, *) {
        UnifiedAITestView()
    }
}