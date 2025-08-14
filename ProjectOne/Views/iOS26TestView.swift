//
//  iOS26TestView.swift
//  ProjectOne
//
//  Direct test for iOS 26.0+ with ExternalProviderFactory
//

import SwiftUI
import SwiftData

@available(iOS 26.0, macOS 26.0, *)
struct iOS26TestView: View {
    @StateObject private var providerFactory = ExternalProviderFactory(settings: AIProviderSettings())
    @State private var testPrompt = "Explain quantum computing in simple terms"
    @State private var response = ""
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Provider Status")
                        .font(.headline)
                    
                    let mlxProvider = providerFactory.getProvider("mlx")
                    let openAIProvider = providerFactory.getProvider("openai")
                    let mlxStatus = providerFactory.providerStatus["mlx"] ?? .notConfigured
                    
                    HStack {
                        Image(systemName: mlxProvider != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(mlxProvider != nil ? .green : .red)
                        Text("MLX Provider: \(mlxProvider?.configuration.model ?? "Not loaded")")
                    }
                    
                    HStack {
                        Image(systemName: openAIProvider != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(openAIProvider != nil ? .green : .red)
                        Text("OpenAI Provider: \(openAIProvider?.configuration.model ?? "Not configured")")
                    }
                    
                    Text("MLX Status: \(statusDescription(mlxStatus))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(10)
                
                // Input Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Prompt")
                        .font(.headline)
                    
                    TextEditor(text: $testPrompt)
                        .frame(minHeight: 80)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Test MLX") {
                        testWithProvider("mlx")
                    }
                    .disabled(providerFactory.getProvider("mlx") == nil || isProcessing)
                    
                    Button("Test OpenAI") {
                        testWithProvider("openai")
                    }
                    .disabled(providerFactory.getProvider("openai") == nil || isProcessing)
                    
                    Button("Test Best Available") {
                        testWithBestProvider()
                    }
                    .disabled(providerFactory.getAllActiveProviders().isEmpty || isProcessing)
                }
                .padding()
                
                // Response Section
                if !response.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Response")
                            .font(.headline)
                        
                        ScrollView {
                            Text(response)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("iOS 26.0+ AI Test")
        }
        .task {
            await providerFactory.configureFromSettings()
        }
        .overlay {
            if isProcessing {
                ProgressView("Processing...")
                    .padding()
                    .background(Color.primary.colorInvert())
                    .cornerRadius(8)
            }
        }
    }
    
    private func testWithProvider(_ providerId: String) {
        Task {
            await MainActor.run {
                isProcessing = true
                response = ""
            }
            
            do {
                if let provider = await providerFactory.getProvider(providerId) {
                    let result = try await provider.generateModelResponse(testPrompt)
                    await MainActor.run {
                        response = result
                    }
                } else {
                    await MainActor.run {
                        response = "Provider '\(providerId)' not available"
                    }
                }
            } catch {
                await MainActor.run {
                    response = "Error: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func testWithBestProvider() {
        Task {
            await MainActor.run {
                isProcessing = true
                response = ""
            }
            
            do {
                if let provider = await providerFactory.getBestProviderFor(.quality) {
                    let result = try await provider.generateModelResponse(testPrompt)
                    await MainActor.run {
                        response = result
                    }
                } else {
                    await MainActor.run {
                        response = "No providers available"
                    }
                }
            } catch {
                await MainActor.run {
                    response = "Error: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func statusDescription(_ status: ExternalProviderFactory.ProviderStatus) -> String {
        switch status {
        case .notConfigured:
            return "Not configured"
        case .configuring:
            return "Configuring..."
        case .ready:
            return "Ready"
        case .error(let message):
            return "Error: \(message)"
        case .unavailable(let message):
            return "Unavailable: \(message)"
        }
    }
}

#Preview {
    if #available(iOS 26.0, macOS 26.0, *) {
        iOS26TestView()
    } else {
        Text("Requires iOS 26.0+")
    }
}