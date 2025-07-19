//
//  MLXTestView.swift
//  ProjectOne
//
//  Created for testing MLX Gemma3n inference
//

import SwiftUI
#if os(iOS) || os(iPadOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension ModelLoadingStatus {
    var color: Color {
        switch self {
        case .notStarted: return .gray
        case .preparing: return .orange
        case .downloading: return .blue
        case .loading: return .orange
        case .ready: return .green
        case .failed: return .red
        case .unavailable: return .red
        }
    }
    
    var systemImage: String {
        switch self {
        case .notStarted: return "questionmark.circle"
        case .preparing: return "gearshape.2"
        case .downloading: return "arrow.down.circle"
        case .loading: return "gearshape.2"
        case .ready: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .unavailable: return "xmark.circle.fill"
        }
    }
}

@available(iOS 26.0, iPadOS 26.0, macOS 26.0, *)
struct MLXTestView: View {
    @State private var testPrompt = "Hello, how are you?"
    @State private var testResult = ""
    @State private var foundationsResult = ""
    @State private var isLoadingMLX = false
    @State private var isLoadingFoundations = false
    @State private var providerInfo = ""
    @State private var showComparison = false
    @StateObject private var mlxProvider = MLXGemma3nE2BProvider()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                // MLX Status Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("MLX Framework Status")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: mlxProvider.modelLoadingStatus.systemImage)
                                .foregroundColor(mlxProvider.modelLoadingStatus.color)
                                .rotationEffect(.degrees(mlxProvider.modelLoadingStatus.isLoading ? 360 : 0))
                                .animation(
                                    mlxProvider.modelLoadingStatus.isLoading ? 
                                        .linear(duration: 2).repeatForever(autoreverses: false) : 
                                        .default, 
                                    value: mlxProvider.modelLoadingStatus
                                )
                            
                            Text(mlxProvider.modelLoadingStatus.description)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        if mlxProvider.modelLoadingStatus.isLoading {
                            ProgressView(value: mlxProvider.loadingProgress)
                                .frame(width: 60)
                        }
                    }
                    
                    Text(mlxProvider.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                    
                    // Retry button for failed model loading
                    if case .failed = mlxProvider.modelLoadingStatus {
                        Button("Retry Model Loading") {
                            retryMLXModel()
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                    }
                    
                    if !providerInfo.isEmpty {
                        Text(providerInfo)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .opacity(0.7)
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Divider()
                
                // Test Input Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test MLX Inference")
                        .font(.headline)
                    
                    TextField("Enter test prompt", text: $testPrompt, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: testMLXInference) {
                                HStack {
                                    if isLoadingMLX {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoadingMLX ? "Testing..." : "Test MLX")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .glassEffect(.regular.tint(Color.blue.opacity(0.3)).interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundColor(.white)
                            }
                            .disabled(testPrompt.isEmpty || isLoadingMLX || isLoadingFoundations)
                            
                            Button(action: testFoundationsInference) {
                                HStack {
                                    if isLoadingFoundations {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoadingFoundations ? "Testing..." : "Test Foundations")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .glassEffect(.regular.tint(Color.green.opacity(0.3)).interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .foregroundColor(.white)
                            }
                            .disabled(testPrompt.isEmpty || isLoadingMLX || isLoadingFoundations)
                        }
                        
                        Button(action: testBothAndCompare) {
                            HStack {
                                if isLoadingMLX || isLoadingFoundations {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text((isLoadingMLX || isLoadingFoundations) ? "Comparing..." : "Compare Both Models")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .glassEffect(.regular.tint(Color.orange.opacity(0.3)).interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundColor(.white)
                        }
                        .disabled(testPrompt.isEmpty || isLoadingMLX || isLoadingFoundations)
                    }
                }
                
                // Test Results Section
                if showComparison && (!testResult.isEmpty || !foundationsResult.isEmpty) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Model Comparison")
                            .font(.headline)
                        
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "brain")
                                        .foregroundColor(.blue)
                                    Text("MLX Gemma 3n")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                ScrollView {
                                    Text(testResult.isEmpty ? "No response" : testResult)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .glassEffect(.regular.tint(Color.blue.opacity(0.1)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .frame(maxHeight: 200)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "apple.logo")
                                        .foregroundColor(.green)
                                    Text("Foundation Models")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                ScrollView {
                                    Text(foundationsResult.isEmpty ? "No response" : foundationsResult)
                                        .font(.system(.caption, design: .monospaced))
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .glassEffect(.regular.tint(Color.green.opacity(0.1)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .frame(maxHeight: 200)
                            }
                        }
                    }
                } else if !testResult.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.blue)
                            Text("MLX Inference Result")
                                .font(.headline)
                        }
                        
                        ScrollView {
                            Text(testResult)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular.tint(Color.blue.opacity(0.1)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .frame(maxHeight: 300)
                    }
                } else if !foundationsResult.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .foregroundColor(.green)
                            Text("Foundation Models Result")
                                .font(.headline)
                        }
                        
                        ScrollView {
                            Text(foundationsResult)
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular.tint(Color.green.opacity(0.1)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                            .glassEffect(.regular.tint(Color.blue.opacity(0.1)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .lineLimit(2)
                        }
                    }
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding()
            .navigationTitle("MLX Inference Test")
            #if os(iOS) || os(iPadOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                setupProviderInfo()
                prepareMLXModel()
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
    
    private func setupProviderInfo() {
        providerInfo = """
        Identifier: \(mlxProvider.identifier)
        Display Name: \(mlxProvider.displayName)
        Max Context: \(mlxProvider.maxContextLength) tokens
        On-Device: \(mlxProvider.isOnDevice ? "Yes" : "No")
        Personal Data: \(mlxProvider.supportsPersonalData ? "Supported" : "Not Supported")
        """
    }
    
    private func prepareMLXModel() {
        Task {
            do {
                try await mlxProvider.prepareModel()
            } catch {
                // Error is already handled by the provider's published state
                print("Model preparation failed: \(error)")
            }
        }
    }
    
    private func retryMLXModel() {
        Task {
            do {
                // Reset the provider state before retrying
                await MainActor.run {
                    mlxProvider.isModelLoaded = false
                    mlxProvider.modelLoadingStatus = .notStarted
                    mlxProvider.statusMessage = ""
                    mlxProvider.loadingProgress = 0.0
                }
                
                try await mlxProvider.prepareModel()
            } catch {
                print("Model retry failed: \(error)")
            }
        }
    }
    
    private func testMLXInference() {
        guard !testPrompt.isEmpty else { return }
        
        isLoadingMLX = true
        testResult = ""
        showComparison = false
        
        Task {
            do {
                // Use the observed provider instance
                let result = try await mlxProvider.generateModelResponse(testPrompt)
                
                await MainActor.run {
                    testResult = result
                    isLoadingMLX = false
                }
                
            } catch {
                await MainActor.run {
                    testResult = "❌ Error: \(error.localizedDescription)\n\nThis might be expected if:\n• Running in simulator (MLX needs real Apple Silicon)\n• MLX framework not available\n• Model files not present"
                    isLoadingMLX = false
                }
            }
        }
    }
    
    private func testFoundationsInference() {
        guard !testPrompt.isEmpty else { return }
        
        isLoadingFoundations = true
        foundationsResult = ""
        showComparison = false
        
        Task {
            do {
                let provider = AppleFoundationModelsProvider()
                try await provider.prepare()
                
                // Create a simple memory context for testing
                let memoryContext = MemoryContext(
                    entities: [],
                    relationships: [],
                    shortTermMemories: [],
                    longTermMemories: [],
                    episodicMemories: [],
                    relevantNotes: [],
                    userQuery: testPrompt,
                    containsPersonalData: false
                )
                
                let response = try await provider.generateResponse(
                    prompt: testPrompt,
                    context: memoryContext
                )
                
                await MainActor.run {
                    foundationsResult = response.content
                    isLoadingFoundations = false
                }
                
            } catch {
                await MainActor.run {
                    foundationsResult = "❌ Error: \(error.localizedDescription)\n\nThis might be expected if:\n• iOS 26.0+ required\n• Apple Intelligence not available\n• Device not compatible"
                    isLoadingFoundations = false
                }
            }
        }
    }
    
    private func testBothAndCompare() {
        guard !testPrompt.isEmpty else { return }
        
        isLoadingMLX = true
        isLoadingFoundations = true
        testResult = ""
        foundationsResult = ""
        showComparison = true
        
        Task {
            // Run both tests concurrently
            async let mlxTask: Void = {
                do {
                    let result = try await mlxProvider.generateModelResponse(testPrompt)
                    await MainActor.run {
                        testResult = result
                        isLoadingMLX = false
                    }
                } catch {
                    await MainActor.run {
                        testResult = "❌ MLX Error: \(error.localizedDescription)"
                        isLoadingMLX = false
                    }
                }
            }()
            
            async let foundationsTask: Void = {
                do {
                    let provider = AppleFoundationModelsProvider()
                    try await provider.prepare()
                    
                    let memoryContext = MemoryContext(
                        entities: [],
                        relationships: [],
                        shortTermMemories: [],
                        longTermMemories: [],
                        episodicMemories: [],
                        relevantNotes: [],
                        userQuery: testPrompt,
                        containsPersonalData: false
                    )
                    
                    let response = try await provider.generateResponse(
                        prompt: testPrompt,
                        context: memoryContext
                    )
                    
                    await MainActor.run {
                        foundationsResult = response.content
                        isLoadingFoundations = false
                    }
                } catch {
                    await MainActor.run {
                        foundationsResult = "❌ Foundations Error: \(error.localizedDescription)"
                        isLoadingFoundations = false
                    }
                }
            }()
            
            // Wait for both to complete
            await mlxTask
            await foundationsTask
        }
    }
}

#Preview {
    if #available(iOS 26.0, iPadOS 26.0, macOS 26.0, *) {
        MLXTestView()
    }
}