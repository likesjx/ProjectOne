//
//  EnhancedAIProviderTestView.swift
//  ProjectOne
//
//  Comprehensive AI provider testing interface with support for all providers
//  Includes local (MLX, Apple Foundation), external (OpenAI, Ollama, OpenRouter)
//

import SwiftUI
import Combine
import SwiftData

@available(iOS 26.0, macOS 26.0, *)
struct EnhancedAIProviderTestView: View {
    
    // MARK: - State Management
    
    @State private var testPrompt = "Hello! Can you tell me about yourself and your capabilities?"
    @State private var selectedProviders: Set<AIProviderType> = [.mlx, .appleFoundation]
    @State private var testResults: [AITestResult] = []
    @State private var isLoading = false
    @State private var loadingProviders: Set<AIProviderType> = []
    // Provider instances
    @StateObject private var mlxProvider: MLXProvider
    @StateObject private var appleFoundationProvider = AppleFoundationModelsProvider()
    @StateObject private var ollamaProvider = OllamaProvider(model: "llama3:8b")
    @StateObject private var openAIProvider = OpenAIProvider.gpt4o(apiKey: "")
    @StateObject private var openRouterProvider = OpenRouterProvider.claude3Sonnet(apiKey: "")
    
    init() {
        // Initialize MLXProvider with proper configuration
        let config = ExternalAIProvider.Configuration(
            apiKey: nil,
            baseURL: "local://mlx",
            model: "mlx-community/Meta-Llama-3-8B-Instruct-4bit"
        )
        let mlxConfig = MLXProvider.MLXConfiguration(
            modelPath: "",
            maxSequenceLength: 2048
        )
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let swiftDataContainer = try! SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = ModelContext(swiftDataContainer)
        let provider = MLXProvider(configuration: config, mlxConfig: mlxConfig, modelContext: modelContext)
        _mlxProvider = StateObject(wrappedValue: provider)
    }
    
    // API Key Manager
    @StateObject private var apiKeyManager = APIKeyManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // Header Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Provider Testing Suite")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Test and compare different AI providers available in ProjectOne. Select providers below and run comparative tests.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    // Provider Selection Grid
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Select Providers")
                                .font(.headline)
                            Spacer()
                            NavigationLink("Manage API Keys") {
                                APIKeyManagementView()
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(AIProviderType.allCases, id: \.self) { providerType in
                                ProviderCard(
                                    providerType: providerType,
                                    isSelected: selectedProviders.contains(providerType),
                                    isAvailable: isProviderAvailable(providerType),
                                    isLoading: loadingProviders.contains(providerType),
                                    onToggle: { toggleProvider(providerType) }
                                )
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    // Test Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Test Prompt")
                            .font(.headline)
                        
                        TextEditor(text: $testPrompt)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        
                        HStack(spacing: 12) {
                            Button("Test Selected Providers") {
                                testSelectedProviders()
                            }
                            .buttonStyle(EnhancedPrimaryButtonStyle(color: .blue))
                            .disabled(selectedProviders.isEmpty || isLoading || testPrompt.isEmpty)
                            
                            Button("Test All Available") {
                                testAllAvailableProviders()
                            }
                            .buttonStyle(EnhancedSecondaryButtonStyle())
                            .disabled(isLoading || testPrompt.isEmpty)
                        }
                        
                        // Quick Prompts
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(quickPrompts, id: \.self) { prompt in
                                    Button(prompt.prefix(30) + "...") {
                                        testPrompt = prompt
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Testing \(loadingProviders.count) provider(s)...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
                    // Provider Status Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Provider Status")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            StatusCard(name: "MLX Provider", isReady: {
                                if case .ready = mlxProvider.modelLoadingStatus {
                                    return true
                                } else {
                                    return false
                                }
                            }(), color: .blue)
                            StatusCard(name: "Apple Foundation", isReady: appleFoundationProvider.isAvailable, color: .green)
                            StatusCard(name: "Ollama", isReady: isOllamaConfigured, color: .orange)
                            StatusCard(name: "OpenAI", isReady: isOpenAIConfigured, color: .purple)
                            StatusCard(name: "OpenRouter", isReady: isOpenRouterConfigured, color: .pink)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    
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
                            
                            ForEach(testResults.sorted { $0.responseTime < $1.responseTime }, id: \.id) { result in
                                EnhancedTestResultCard(result: result)
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("AI Provider Testing")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                setupProviders()
            }
        }
    }
    
    // MARK: - Quick Prompts
    
    private let quickPrompts = [
        "Hello! Can you tell me about yourself and your capabilities?",
        "Explain quantum computing in simple terms",
        "Write a short creative story about AI",
        "What are the benefits of on-device AI processing?",
        "Compare Swift and Python programming languages",
        "Explain the concept of machine learning",
        "What is the future of artificial intelligence?",
        "Describe how neural networks work"
    ]
    
    // MARK: - Computed Properties
    
    private var isOllamaConfigured: Bool {
        apiKeyManager.isConfigured(.ollama)
    }
    
    private var isOpenAIConfigured: Bool {
        apiKeyManager.isConfigured(.openAI)
    }
    
    private var isOpenRouterConfigured: Bool {
        apiKeyManager.isConfigured(.openRouter)
    }
    
    // MARK: - Helper Methods
    
    private func isProviderAvailable(_ providerType: AIProviderType) -> Bool {
        switch providerType {
        case .mlx:
            return MLXProvider.isMLXSupported
        case .appleFoundation:
            return appleFoundationProvider.isAvailable
        case .ollama:
            return isOllamaConfigured
        case .openAI:
            return isOpenAIConfigured
        case .openRouter:
            return isOpenRouterConfigured
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
            // Setup Apple Foundation Models
            try? await appleFoundationProvider.prepareModel()
            
            // Setup MLX Provider if supported
            if MLXProvider.isMLXSupported {
                try? await mlxProvider.prepareModel()
            }
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
        
        Task {
            var results: [AITestResult] = []
            
            await withTaskGroup(of: AITestResult.self) { group in
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
                testResults = results
                isLoading = false
                loadingProviders.removeAll()
            }
        }
    }
    
    private func testProvider(_ providerType: AIProviderType) async -> AITestResult {
        let startTime = Date()
        
        do {
            let response = try await generateResponse(for: providerType, prompt: testPrompt)
            let responseTime = Date().timeIntervalSince(startTime)
            
            return AITestResult(
                id: UUID(),
                providerType: providerType,
                response: response,
                responseTime: responseTime,
                success: true,
                error: nil
            )
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            
            return AITestResult(
                id: UUID(),
                providerType: providerType,
                response: "",
                responseTime: responseTime,
                success: false,
                error: error.localizedDescription
            )
        }
    }
    
    private func generateResponse(for providerType: AIProviderType, prompt: String) async throws -> String {
        switch providerType {
        case .mlx:
            let context = MemoryContext(userQuery: prompt)
            let response = try await mlxProvider.generateResponse(prompt: prompt, context: context)
            return response.content
            
        case .appleFoundation:
            guard appleFoundationProvider.isAvailable else {
                throw AITestError.providerNotAvailable("Apple Foundation Models not available")
            }
            return try await appleFoundationProvider.generateModelResponse(prompt)
            
        case .ollama:
            guard isOllamaConfigured else {
                throw AITestError.providerNotAvailable("Ollama not configured")
            }
            // Create a new provider with stored configuration
            guard let tempOllamaProvider = try apiKeyManager.createOllamaProvider() else {
                throw AITestError.providerNotAvailable("Ollama configuration not found")
            }
            try await tempOllamaProvider.prepareModel()
            return try await tempOllamaProvider.generateModelResponse(prompt)
            
        case .openAI:
            guard isOpenAIConfigured else {
                throw AITestError.providerNotAvailable("OpenAI API key not configured")
            }
            // Create a new provider with stored credentials
            guard let tempOpenAIProvider = try apiKeyManager.createOpenAIProvider() else {
                throw AITestError.providerNotAvailable("OpenAI API key not found")
            }
            try await tempOpenAIProvider.prepareModel()
            return try await tempOpenAIProvider.generateModelResponse(prompt)
            
        case .openRouter:
            guard isOpenRouterConfigured else {
                throw AITestError.providerNotAvailable("OpenRouter API key not configured")
            }
            // Create a new provider with stored credentials
            guard let tempOpenRouterProvider = try apiKeyManager.createOpenRouterProvider() else {
                throw AITestError.providerNotAvailable("OpenRouter API key not found")
            }
            try await tempOpenRouterProvider.prepareModel()
            return try await tempOpenRouterProvider.generateModelResponse(prompt)
        }
    }
}

// MARK: - Data Models

enum AIProviderType: String, CaseIterable {
    case mlx = "MLX Provider"
    case appleFoundation = "Apple Foundation Models"
    case ollama = "Ollama"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    
    var icon: String {
        switch self {
        case .mlx: return "cpu.fill"
        case .appleFoundation: return "apple.logo"
        case .ollama: return "server.rack"
        case .openAI: return "cloud.fill"
        case .openRouter: return "network"
        }
    }
    
    var color: Color {
        switch self {
        case .mlx: return .blue
        case .appleFoundation: return .green
        case .ollama: return .orange
        case .openAI: return .purple
        case .openRouter: return .pink
        }
    }
    
    var description: String {
        switch self {
        case .mlx: return "Unified MLX models on Apple Silicon"
        case .appleFoundation: return "Apple's on-device Foundation Models"
        case .ollama: return "Local Ollama server models"
        case .openAI: return "OpenAI GPT models via API"
        case .openRouter: return "Multiple models via OpenRouter API"
        }
    }
}

struct AITestResult {
    let id: UUID
    let providerType: AIProviderType
    let response: String
    let responseTime: TimeInterval
    let success: Bool
    let error: String?
    
    var displayTime: String {
        String(format: "%.2fs", responseTime)
    }
}

enum AITestError: Error, LocalizedError {
    case providerNotAvailable(String)
    case configurationMissing(String)
    
    var errorDescription: String? {
        switch self {
        case .providerNotAvailable(let reason):
            return "Provider not available: \(reason)"
        case .configurationMissing(let reason):
            return "Configuration missing: \(reason)"
        }
    }
}

// MARK: - Supporting Views

struct ProviderCard: View {
    let providerType: AIProviderType
    let isSelected: Bool
    let isAvailable: Bool
    let isLoading: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: providerType.icon)
                        .foregroundColor(isAvailable ? providerType.color : .gray)
                        .font(.title2)
                    
                    Spacer()
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if isSelected {
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
                    
                    Text(providerType.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    if !isAvailable {
                        Text("Not configured")
                            .font(.caption2)
                            .foregroundColor(.orange)
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

struct StatusCard: View {
    let name: String
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
            
            Text(isReady ? "Ready" : "Not ready")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct EnhancedTestResultCard: View {
    let result: AITestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: result.providerType.icon)
                        .foregroundColor(result.providerType.color)
                        .font(.caption)
                    
                    Text(result.providerType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
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
                        .font(.system(.caption, design: .default))
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
        .background(result.providerType.color.opacity(0.05))
        .cornerRadius(12)
    }
}


// MARK: - Button Styles

struct EnhancedPrimaryButtonStyle: ButtonStyle {
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

struct EnhancedSecondaryButtonStyle: ButtonStyle {
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

// MARK: - Preview

#Preview {
    if #available(iOS 26.0, macOS 26.0, *) {
        EnhancedAIProviderTestView()
    }
}