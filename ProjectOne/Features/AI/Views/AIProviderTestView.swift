//
//  AIProviderTestView.swift
//  ProjectOne
//
//  Test view for working MLX and Apple Intelligence implementations
//

import SwiftUI
import SwiftData

struct AIProviderTestView: View {
    @StateObject private var mlxProvider: MLXProvider
    @StateObject private var appleProvider: AppleFoundationModelsProvider
    
    @State private var testPrompt = "Hello! Can you tell me about the capabilities of this AI model?"
    @State private var mlxResponse = ""
    @State private var selectedModel: String = "mlx-community/Meta-Llama-3-8B-Instruct-4bit"
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init() {
        // Initialize the StateObject properly in the init method to avoid lifecycle issues
        let appleProvider = AppleFoundationModelsProvider()
        _appleProvider = StateObject(wrappedValue: appleProvider)
        
        // Initialize MLXProvider with default configuration
        let config = ExternalAIProvider.Configuration(
            apiKey: nil,
            baseURL: "local://mlx",
            model: "mlx-community/Meta-Llama-3-8B-Instruct-4bit",
            maxTokens: 2048,
            temperature: 0.7
        )
        let mlxConfig = MLXProvider.MLXConfiguration(
            modelPath: "",
            maxSequenceLength: 2048
        )
        // Note: This would need a ModelContext - for testing, create a temporary one
        let schema = Schema([])
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let swiftDataContainer = try! SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        let modelContext = ModelContext(swiftDataContainer)
        let provider = MLXProvider(configuration: config, mlxConfig: mlxConfig, modelContext: modelContext)
        _mlxProvider = StateObject(wrappedValue: provider)
    }
    
    var body: some View {
        NavigationView {
            Form {
                mlxProviderSection
                appleIntelligenceSection
                guidanceSection
                testInterfaceSection
                errorSection
            }
            .navigationTitle("AI Provider Test")
            .onAppear {
                Task {
                    await initializeProviders()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var mlxProviderSection: some View {
        Section(header: Text("MLX Swift Provider")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status: \(MLXProvider.isMLXSupported ? "✅ Supported" : "❌ Not Supported")")
                    .foregroundColor(MLXProvider.isMLXSupported ? .green : .red)
                
                if MLXProvider.isMLXSupported {
                    mlxModelPicker
                    mlxLoadingStatus
                    mlxActionButtons
                }
            }
        }
    }
    
    private var mlxModelPicker: some View {
        Picker("Model", selection: $selectedModel) {
            ForEach(MLXModelRepository.popularModels, id: \.repo) { model in
                VStack(alignment: .leading) {
                    Text(model.name)
                    Text(model.repo).font(.caption).foregroundColor(.secondary)
                }
                .tag(model.repo)
            }
        }
    }
    
    @ViewBuilder
    private var mlxLoadingStatus: some View {
        if mlxProvider.isAvailable {
            Text("✅ Model ready: \(selectedModel)")
                .foregroundColor(.green)
        } else {
            Text("❌ Model not loaded")
                .foregroundColor(.orange)
        }
    }
    
    private var mlxActionButtons: some View {
        HStack {
            Button("Load Model") {
                Task {
                    await loadMLXModel()
                }
            }
            .disabled(!MLXProvider.isMLXSupported)
            
            if mlxProvider.isAvailable {
                Button("Unload") {
                    Task {
                        await mlxProvider.cleanup()
                    }
                }
            }
        }
    }
    
    private var appleIntelligenceSection: some View {
        Section(header: Text("Apple Intelligence")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status: \(appleProvider.isAvailable ? "✅ Available" : "❌ Not Available")")
                    .foregroundColor(appleProvider.isAvailable ? .green : .red)
                
                Text("Provider: \(appleProvider.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Max Context: \(appleProvider.maxContextLength) tokens")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Est. Response Time: \(appleProvider.estimatedResponseTime, specifier: "%.1f")s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !appleProvider.isAvailable {
                    Text("Requires iOS 26.0+ and Apple Intelligence enabled")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                if appleProvider.isAvailable {
                    Button("Test Apple Foundation Models") {
                        Task {
                            await testAppleFoundationModels()
                        }
                    }
                    .disabled(testPrompt.isEmpty)
                }
            }
        }
    }
    
    private var guidanceSection: some View {
        Section(header: Text("Usage Instructions")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("📋 To test inference:")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text("**For MLX Models:**")
                    .font(.subheadline)
                Text("1. Select a model in the MLX section above")
                Text("2. Click 'Load Model' and wait for completion")
                Text("3. Test interface will appear below")
                
                Text("**For Apple Foundation Models:**")
                    .font(.subheadline)
                Text("• Requires iOS 26.0+ and Apple Intelligence enabled")
                Text("• If available, test button appears above")
                
                Text("**Current Status:**")
                    .font(.subheadline)
                Text("MLX Ready: \(mlxProvider.isAvailable ? "✅" : "❌")")
                Text("Apple Available: \(appleProvider.isAvailable ? "✅" : "❌")")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var testInterfaceSection: some View {
        if mlxProvider.isAvailable || appleProvider.isAvailable {
            Section(header: Text("AI Inference Testing")) {
                TextEditor(text: $testPrompt)
                    .frame(minHeight: 60)
                
                HStack {
                    if mlxProvider.isAvailable {
                        Button("Test MLX") {
                            Task {
                                await generateMLXResponse()
                            }
                        }
                        .disabled(testPrompt.isEmpty)
                        .buttonStyle(.bordered)
                    }
                    
                    if appleProvider.isAvailable {
                        Button("Test Apple FM") {
                            Task {
                                await testAppleFoundationModels()
                            }
                        }
                        .disabled(testPrompt.isEmpty)
                        .buttonStyle(.bordered)
                    }
                }
                
                if !mlxResponse.isEmpty {
                    Text("Response:")
                        .font(.headline)
                    Text(mlxResponse)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if showingError && !errorMessage.isEmpty {
            Section(header: Text("Errors")) {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Lifecycle
    
    private func initializeProviders() async {
        // Initialize providers silently - providers automatically check availability on init
    }
    
    // MARK: - Actions
    
    private func loadMLXModel() async {
        do {
            try await mlxProvider.prepareModel()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func generateMLXResponse() async {
        do {
            // Create a basic memory context for MLX provider
            let memoryContext = MemoryContext(
                userQuery: testPrompt,
                containsPersonalData: false,
                contextData: [:]
            )
            
            let response = try await mlxProvider.generateResponse(prompt: testPrompt, context: memoryContext)
            await MainActor.run {
                mlxResponse = response.content
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func testAppleFoundationModels() async {
        do {
            // Test Apple Foundation Models using the BaseAIProvider interface
            let memoryContext = MemoryContext(
                userQuery: testPrompt,
                containsPersonalData: false,
                contextData: [
                    "entities": "0",
                    "relationships": "0",
                    "shortTermMemories": "0",
                    "longTermMemories": "0",
                    "episodicMemories": "0",
                    "relevantNotes": "0"
                ]
            )
            
            let response = try await appleProvider.generateResponse(prompt: testPrompt, context: memoryContext)
            await MainActor.run {
                mlxResponse = response.content // Reuse the same response field for simplicity
            }
        } catch {
            await MainActor.run {
                errorMessage = "Apple Foundation Models Error: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

#Preview {
    AIProviderTestView()
}