//
//  AIProviderTestView.swift
//  ProjectOne
//
//  Test view for working MLX and Apple Intelligence implementations
//

import SwiftUI

struct AIProviderTestView: View {
    @StateObject private var mlxProvider = WorkingMLXProvider()
    @StateObject private var appleProvider = AppleIntelligenceProvider()
    
    @State private var testPrompt = "Hello! Can you tell me about the capabilities of this AI model?"
    @State private var mlxResponse = ""
    @State private var selectedModel: WorkingMLXProvider.MLXModel = .gemma2_2B
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                // MLX Provider Section
                Section(header: Text("MLX Swift Provider")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status: ") + Text(mlxProvider.isMLXSupported ? "✅ Supported" : "❌ Not Supported")
                            .foregroundColor(mlxProvider.isMLXSupported ? .green : .red)
                        
                        if mlxProvider.isMLXSupported {
                            Picker("Model", selection: $selectedModel) {
                                ForEach(WorkingMLXProvider.MLXModel.allCases, id: \.self) { model in
                                    VStack(alignment: .leading) {
                                        Text(model.displayName)
                                        Text(model.memoryRequirement).font(.caption).foregroundColor(.secondary)
                                    }
                                    .tag(model)
                                }
                            }
                            
                            if mlxProvider.isLoading {
                                VStack {
                                    ProgressView(value: mlxProvider.loadingProgress)
                                    Text("Loading model... \(Int(mlxProvider.loadingProgress * 100))%")
                                        .font(.caption)
                                }
                            } else if mlxProvider.isReady {
                                Text("✅ Model ready: \(mlxProvider.getModelInfo()?.displayName ?? "Unknown")")
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Button("Load Model") {
                                    Task {
                                        await loadMLXModel()
                                    }
                                }
                                .disabled(mlxProvider.isLoading)
                                
                                if mlxProvider.isReady {
                                    Button("Unload") {
                                        Task {
                                            await mlxProvider.unloadModel()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Apple Intelligence Section
                Section(header: Text("Apple Intelligence")) {
                    VStack(alignment: .leading, spacing: 8) {
                        let status = appleProvider.getAvailableFeatures()
                        
                        Text("Consumer Features: ") + Text(status.consumerFeaturesAvailable ? "✅ Available" : "❌ Not Available")
                            .foregroundColor(status.consumerFeaturesAvailable ? .green : .red)
                        
                        Text("Developer API: ") + Text(status.developerAPIAvailable ? "✅ Available" : "❌ Not Available")
                            .foregroundColor(status.developerAPIAvailable ? .green : .red)
                        
                        Text("Required: iOS \(status.requiredIOSVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(status.recommendedAction)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        if status.consumerFeaturesAvailable && !status.currentFeatures.isEmpty {
                            Text("Available Features:")
                                .font(.headline)
                            ForEach(status.currentFeatures, id: \.self) { feature in
                                Text("• \(feature)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Test Interface
                if mlxProvider.isReady {
                    Section(header: Text("Test MLX Model")) {
                        TextEditor(text: $testPrompt)
                            .frame(minHeight: 60)
                        
                        Button("Generate Response") {
                            Task {
                                await generateMLXResponse()
                            }
                        }
                        .disabled(testPrompt.isEmpty)
                        
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
                
                // Error Display
                if let errorMsg = mlxProvider.errorMessage {
                    Section(header: Text("Errors")) {
                        Text(errorMsg)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("AI Provider Test")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func loadMLXModel() async {
        do {
            try await mlxProvider.loadModel(selectedModel)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func generateMLXResponse() async {
        do {
            let response = try await mlxProvider.generateResponse(to: testPrompt)
            await MainActor.run {
                mlxResponse = response
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

#Preview {
    AIProviderTestView()
}