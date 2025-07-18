//
//  MLXTestView.swift
//  ProjectOne
//
//  Created for testing MLX Gemma3n inference
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MLXTestView: View {
    @State private var testPrompt = "Hello, how are you?"
    @State private var testResult = ""
    @State private var isLoading = false
    @State private var mlxAvailable = false
    @State private var providerInfo = ""
    @StateObject private var providerSelector = SmartAIProviderSelector()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // AI Provider Status Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Provider Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(getStatusColor())
                            .frame(width: 12, height: 12)
                        Text(getStatusText())
                            .font(.subheadline)
                    }
                    
                    Text(providerInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Model Loading Progress Section
                if let mlxProvider = getCurrentMLXProvider(), mlxProvider.loadingProgress > 0.0 && mlxProvider.loadingProgress < 1.0 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Model Loading Progress")
                            .font(.headline)
                        
                        ProgressView(value: mlxProvider.loadingProgress) {
                            Text(mlxProvider.loadingStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } currentValueLabel: {
                            Text("\(Int(mlxProvider.loadingProgress * 100))%")
                                .font(.caption)
                                .monospacedDigit()
                        }
                        .progressViewStyle(LinearProgressViewStyle())
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Provider Selection Section
                if !providerSelector.availableProviders.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Provider Selection")
                            .font(.headline)
                        
                        HStack {
                            ForEach(providerSelector.availableProviders, id: \.identifier) { provider in
                                Button(action: {
                                    Task {
                                        await providerSelector.switchToProvider(provider.identifier)
                                        checkMLXStatus()
                                    }
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(provider.identifier == providerSelector.getCurrentProvider()?.identifier ? .blue : .gray)
                                            .frame(width: 8, height: 8)
                                        Text(provider.displayName)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(provider.identifier == providerSelector.getCurrentProvider()?.identifier ? 
                                               Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Divider()
                
                // Test Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test MLX Inference")
                        .font(.headline)
                    
                    TextField("Enter test prompt", text: $testPrompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    Button(action: testMLXInference) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Testing..." : "Run MLX Test")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(testPrompt.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(testPrompt.isEmpty || isLoading)
                }
                
                // Test Results Section
                if !testResult.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MLX Inference Result")
                            .font(.headline)
                        
                        ScrollView {
                            Text(testResult)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                    }
                }
                
                Spacer()
                
                // Test Examples
                VStack(alignment: .leading, spacing: 8) {
                    Text("Example Prompts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(examplePrompts, id: \.self) { prompt in
                            Button(prompt) {
                                testPrompt = prompt
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
                            .lineLimit(2)
                        }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("MLX Inference Test")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                checkMLXStatus()
            }
        }
    }
    
    private let examplePrompts = [
        "Hello world",
        "What is AI?",
        "Explain machine learning",
        "Tell me a joke",
        "What is Swift?",
        "How does MLX work?"
    ]
    
    private func checkMLXStatus() {
        let info = providerSelector.getProviderInfo()
        mlxAvailable = providerSelector.getCurrentProvider()?.isAvailable ?? false
        
        if let provider = providerSelector.getCurrentProvider() {
            providerInfo = """
            Current Provider: \(provider.displayName)
            Identifier: \(provider.identifier)
            Max Context: \(provider.maxContextLength) tokens
            On-Device: \(provider.isOnDevice ? "Yes" : "No")
            Personal Data: \(provider.supportsPersonalData ? "Supported" : "Not Supported")
            
            Device Capabilities: \(info.deviceCapabilities.description)
            Available Providers: \(info.availableProviders.joined(separator: ", "))
            """
        } else {
            providerInfo = """
            No AI provider available
            Device Capabilities: \(info.deviceCapabilities.description)
            Status: \(info.status)
            """
        }
    }
    
    private func testMLXInference() {
        guard !testPrompt.isEmpty else { return }
        
        isLoading = true
        testResult = ""
        
        Task {
            do {
                // Use the selected provider from the provider selector
                guard let provider = providerSelector.getCurrentProvider() else {
                    await MainActor.run {
                        testResult = "❌ No AI provider available\n\nTry refreshing the provider list or check device compatibility."
                        isLoading = false
                    }
                    return
                }
                
                // Create a basic memory context for testing
                let context = MemoryContext(userQuery: testPrompt)
                
                // Generate response using the selected provider
                let response = try await provider.generateResponse(prompt: testPrompt, context: context)
                
                await MainActor.run {
                    testResult = """
                    Provider: \(provider.displayName)
                    Processing Time: \(String(format: "%.2f", response.processingTime))s
                    Confidence: \(String(format: "%.1f", response.confidence * 100))%
                    On-Device: \(response.isOnDevice ? "Yes" : "No")
                    
                    Response:
                    \(response.content)
                    """
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    testResult = """
                    ❌ Error: \(error.localizedDescription)
                    
                    This might be expected if:
                    • Running in simulator without Apple Foundation Models
                    • MLX model not yet downloaded
                    • Network connectivity issues
                    • OS version not supported
                    """
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getStatusColor() -> Color {
        switch providerSelector.providerStatus {
        case .ready:
            return .green
        case .initializing:
            return .orange
        case .unavailable:
            return .red
        case .error:
            return .red
        }
    }
    
    private func getStatusText() -> String {
        let info = providerSelector.getProviderInfo()
        
        switch providerSelector.providerStatus {
        case .ready:
            return "\(info.currentProvider) Ready"
        case .initializing:
            return "Initializing AI Providers..."
        case .unavailable:
            return "No AI Provider Available"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private func getCurrentMLXProvider() -> UnifiedMLXProvider? {
        return providerSelector.getCurrentProvider() as? UnifiedMLXProvider
    }
}

#Preview {
    MLXTestView()
}