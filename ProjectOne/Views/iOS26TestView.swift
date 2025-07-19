//
//  iOS26TestView.swift
//  ProjectOne
//
//  Direct test for iOS 26.0+ with real MLX and Foundation Models
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct iOS26TestView: View {
    @StateObject private var enhancedCore = EnhancedGemma3nCore()
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
                    
                    let status = enhancedCore.getProviderStatus()
                    
                    HStack {
                        Image(systemName: status.mlxAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(status.mlxAvailable ? .green : .red)
                        Text("MLX Swift: \(status.mlxModel ?? "Not loaded")")
                    }
                    
                    HStack {
                        Image(systemName: status.foundationAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(status.foundationAvailable ? .green : .red)
                        Text("Foundation Models: \(status.foundationStatus)")
                    }
                    
                    Text("Active: \(status.activeProvider)")
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
                        testWithProvider(.mlx)
                    }
                    .disabled(!enhancedCore.getProviderStatus().mlxAvailable || isProcessing)
                    
                    Button("Test Foundation") {
                        testWithProvider(.foundation)
                    }
                    .disabled(!enhancedCore.getProviderStatus().foundationAvailable || isProcessing)
                    
                    Button("Test Auto") {
                        testWithProvider(.automatic)
                    }
                    .disabled(!enhancedCore.isReady || isProcessing)
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
            await enhancedCore.setup()
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
    
    private func testWithProvider(_ provider: EnhancedGemma3nCore.AIProviderType) {
        Task {
            isProcessing = true
            response = ""
            
            let result = await enhancedCore.processText(testPrompt, forceProvider: provider)
            
            await MainActor.run {
                response = result
                isProcessing = false
            }
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