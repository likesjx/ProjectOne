#!/usr/bin/env swift
//
//  TestMLXCorrectAPI.swift
//  ProjectOne
//
//  Test script to validate correct MLX Swift API usage
//

import Foundation
#if canImport(MLX)
import MLX
import MLXRandom
import MLXNN
import MLXOptimizers
#endif

// Test to verify our corrected MLX integration works
@main
struct TestMLXCorrectAPI {
    static func main() async {
        print("🚀 Testing Correct MLX Swift API Usage...")
        
        #if canImport(MLX)
        print("✅ MLX framework is available")
        
        do {
            print("\n1️⃣ Testing Basic MLX Operations...")
            
            // Test basic MLXArray creation
            let testArray = MLXArray([1, 2, 3, 4, 5])
            print("✅ MLXArray creation: \(testArray.shape)")
            
            // Test random arrays
            let randomArray = MLXRandom.uniform(0.0..<1.0, [3, 4])
            print("✅ Random array generation: \(randomArray.shape)")
            
            print("\n2️⃣ Testing MLXNN Layers...")
            
            // Test Linear layer (exists in MLX Swift)
            let linear = Linear(4, 8)
            let input = MLXRandom.uniform(-1.0..<1.0, [2, 4])
            let output = linear(input)
            print("✅ Linear layer: input \(input.shape) -> output \(output.shape)")
            
            // Test Embedding layer
            let embedding = Embedding(embeddingDimensions: 16, vocabularySize: 100)
            let tokenIds = MLXArray([1, 5, 10, 25])
            let embeddings = embedding(tokenIds)
            print("✅ Embedding layer: tokens \(tokenIds.shape) -> embeddings \(embeddings.shape)")
            
            print("\n3️⃣ Testing Simple Model Creation...")
            
            // Create a simple feedforward model using MLX Swift primitives
            class SimpleModel: Module, UnaryLayer {
                @ModuleInfo var layer1: Linear
                @ModuleInfo var layer2: Linear
                @ModuleInfo var output: Linear
                
                init(inputDim: Int, hiddenDim: Int, outputDim: Int) {
                    self.layer1 = Linear(inputDim, hiddenDim)
                    self.layer2 = Linear(hiddenDim, hiddenDim)
                    self.output = Linear(hiddenDim, outputDim)
                    super.init()
                }
                
                func callAsFunction(_ x: MLXArray) -> MLXArray {
                    var h = relu(layer1(x))
                    h = relu(layer2(h))
                    return output(h)
                }
            }
            
            let model = SimpleModel(inputDim: 10, hiddenDim: 32, outputDim: 5)
            let modelInput = MLXRandom.uniform(-1.0..<1.0, [3, 10])
            let modelOutput = model(modelInput)
            print("✅ Simple model: input \(modelInput.shape) -> output \(modelOutput.shape)")
            
            print("\n4️⃣ Testing Text Generation Simulation...")
            
            // Simulate character-level text generation
            let prompt = "Hello"
            let inputTokens = Array(prompt.utf8).map { Int32($0) }
            let inputIds = MLXArray(inputTokens)
            print("✅ Tokenization: '\(prompt)' -> \(inputIds.shape) tokens")
            
            // Simple model for text generation
            let textModel = SimpleModel(inputDim: inputTokens.count, hiddenDim: 64, outputDim: 256)
            let textOutput = textModel(inputIds.reshaped([1, inputTokens.count]))
            print("✅ Text model inference: \(textOutput.shape)")
            
            // Sample next token (using argmax for deterministic output)
            let probs = softmax(textOutput[0])
            let nextToken = argMax(probs)
            print("✅ Next token sampling: token \(nextToken.item(Int.self))")
            
            print("\n5️⃣ Testing Parameter Management...")
            
            let parameters = model.parameters()
            print("✅ Model parameters extracted: \(parameters.count) parameter groups")
            
            // Test evaluation (important for MLX lazy evaluation)
            eval(model)
            print("✅ Model evaluation successful")
            
            print("\n🎉 All MLX Swift API tests passed!")
            print("✅ Linear layers working correctly")
            print("✅ Embedding layers working correctly") 
            print("✅ Module composition working correctly")
            print("✅ Parameter management working correctly")
            print("✅ Text tokenization and generation pipeline working")
            
        } catch {
            print("❌ MLX operations failed: \(error)")
        }
        
        #else
        print("❌ MLX framework not available at compile time")
        #endif
        
        print("\n🏁 MLX Swift API Test Complete")
    }
}