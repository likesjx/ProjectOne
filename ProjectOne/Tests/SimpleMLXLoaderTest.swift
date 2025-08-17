//
//  SimpleMLXLoaderTest.swift
//  ProjectOne
//
//  Test the new SingletonMLXLoader functionality
//

import Foundation
import SwiftUI

/// Simple test for MLX loader functionality
struct SimpleMLXLoaderTest: View {
    @StateObject private var loader = SingletonMLXLoader.shared
    @State private var testResults: [String] = []
    @State private var isTesting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MLX Loader Test")
                .font(.title)
                .padding()
            
            if loader.isMLXSupported {
                Text("✅ MLX Supported on this device")
                    .foregroundColor(.green)
            } else {
                Text("❌ MLX Not Supported (Simulator or Intel)")
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status:")
                    .font(.headline)
                
                Text("Model: \(loader.currentModel ?? "None")")
                Text("Ready: \(loader.isModelReady ? "Yes" : "No")")
                Text("Loading: \(loader.isLoading ? "Yes" : "No")")
                
                if loader.isLoading {
                    ProgressView(value: loader.loadingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text("Progress: \(Int(loader.loadingProgress * 100))%")
                        .font(.caption)
                }
                
                if let error = loader.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            Button("Test Model Loading") {
                testModelLoading()
            }
            .disabled(isTesting || loader.isLoading)
            
            Button("Test Text Generation") {
                testTextGeneration()
            }
            .disabled(isTesting || !loader.isModelReady)
            
            Button("Test Audio Processing") {
                testAudioProcessing()
            }
            .disabled(isTesting || !loader.isModelReady)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                        Text(result)
                            .font(.caption)
                            .padding(4)
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color.black.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
    
    private func testModelLoading() {
        isTesting = true
        addTestResult("🧪 Starting model loading test...")
        
        Task {
            do {
                let model = loader.getRecommendedModel()
                addTestResult("📱 Recommended model: \(model)")
                
                try await loader.loadModel(model)
                addTestResult("✅ Model loaded successfully!")
                
            } catch {
                addTestResult("❌ Model loading failed: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isTesting = false
            }
        }
    }
    
    private func testTextGeneration() {
        isTesting = true
        addTestResult("🧪 Starting text generation test...")
        
        Task {
            do {
                let prompt = "Hello, this is a test prompt for the Gemma3n model."
                addTestResult("📝 Prompt: \(prompt)")
                
                let response = try await loader.generateText(prompt, maxTokens: 100)
                addTestResult("✅ Generated: \(response.prefix(100))...")
                
            } catch {
                addTestResult("❌ Text generation failed: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isTesting = false
            }
        }
    }
    
    private func testAudioProcessing() {
        isTesting = true
        addTestResult("🧪 Starting audio processing test...")
        
        Task {
            do {
                // Create mock audio data
                let mockAudioData = Data(repeating: 0x42, count: 1024)
                addTestResult("🎵 Created mock audio data: \(mockAudioData.count) bytes")
                
                let response = try await loader.processAudio(mockAudioData)
                addTestResult("✅ Audio processed: \(response.prefix(100))...")
                
            } catch {
                addTestResult("❌ Audio processing failed: \(error.localizedDescription)")
            }
            
            await MainActor.run {
                isTesting = false
            }
        }
    }
    
    private func addTestResult(_ message: String) {
        let timestamp = DateFormatter().string(from: Date())
        let formattedMessage = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            testResults.append(formattedMessage)
        }
    }
}

#Preview {
    SimpleMLXLoaderTest()
}