//
//  MLXProviderTest.swift
//  ProjectOne
//
//  Test for unified MLX provider functionality
//

import Foundation

/// Simple test for MLX Gemma3n loading and processing
class MLXProviderTest {
    
    static func runTest() async {
        print("🧪 Starting MLX Provider Test...")
        
        let provider = UnifiedMLXProvider()
        
        // Test 1: Check availability
        print("✅ MLX Available: \(provider.isAvailable)")
        
        // Test 2: Try to prepare and load model
        do {
            print("🔄 Preparing MLX provider...")
            try await provider.prepare(modelTypes: [.multimodal])
            print("✅ MLX provider prepared successfully")
            
            // Test 3: Try processing
            print("🔄 Testing text processing...")
            let input = UnifiedModelInput(text: "Hello, can you help me test the MLX integration?")
            let output = try await provider.process(input: input, modelType: .multimodal)
            
            print("✅ Processing complete!")
            print("📝 Response: \(output.text ?? "No response")")
            print("⏱️ Processing time: \(output.processingTime ?? 0) seconds")
            print("🤖 Model used: \(output.modelUsed ?? "Unknown")")
            
        } catch {
            print("❌ MLX test failed: \(error.localizedDescription)")
        }
        
        print("🏁 MLX Provider Test completed")
    }
}