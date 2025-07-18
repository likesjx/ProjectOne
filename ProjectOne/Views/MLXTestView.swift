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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // MLX Status Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("MLX Framework Status")
                        .font(.headline)
                    
                    HStack {
                        Circle()
                            .fill(mlxAvailable ? .green : .red)
                            .frame(width: 12, height: 12)
                        Text(mlxAvailable ? "MLX Available" : "MLX Unavailable")
                            .font(.subheadline)
                    }
                    
                    Text(providerInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Material.regular)
                .cornerRadius(8)
                
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
                                .background(Material.regular)
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
                            .background(Material.thin)
                            .cornerRadius(6)
                            .lineLimit(2)
                        }
                    }
                }
                .padding()
                .background(Material.regular)
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("MLX Inference Test")
            .navigationBarTitleDisplayMode(.inline)
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
        let mlxProvider = MLXGemma3nE2BProvider()
        mlxAvailable = mlxProvider.isAvailable
        providerInfo = """
        Identifier: \(mlxProvider.identifier)
        Display Name: \(mlxProvider.displayName)
        Max Context: \(mlxProvider.maxContextLength) tokens
        On-Device: \(mlxProvider.isOnDevice ? "Yes" : "No")
        Personal Data: \(mlxProvider.supportsPersonalData ? "Supported" : "Not Supported")
        """
    }
    
    private func testMLXInference() {
        guard !testPrompt.isEmpty else { return }
        
        isLoading = true
        testResult = ""
        
        Task {
            do {
                let mlxProvider = MLXGemma3nE2BProvider()
                
                // Try to prepare the model
                try await mlxProvider.prepareModel()
                
                // Run inference
                let result = try await mlxProvider.generateModelResponse(testPrompt)
                
                await MainActor.run {
                    testResult = result
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    testResult = "❌ Error: \(error.localizedDescription)\n\nThis might be expected if:\n• Running in simulator (MLX needs real Apple Silicon)\n• MLX framework not available\n• Model files not present"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    MLXTestView()
}