# Swift Async/Await Concurrency Patterns for ProjectOne

> **Modern Swift concurrency patterns used in ProjectOne's AI and memory systems**

Complete guide to Swift concurrency patterns as implemented in ProjectOne, covering async/await, actors, TaskGroups, and advanced patterns used throughout the three-layer AI architecture.

## Overview

ProjectOne extensively uses Swift's modern concurrency model to achieve:
- **Non-blocking AI processing** - Generate responses without freezing UI
- **Parallel provider testing** - Test multiple AI providers simultaneously  
- **Background memory operations** - Autonomous memory consolidation
- **Streaming responses** - Real-time AI response streaming
- **Thread-safe state management** - Proper @MainActor usage for UI updates

## Table of Contents

1. [Basic Async/Await Patterns](#basic-asyncawait-patterns)
2. [Actor Patterns for Thread Safety](#actor-patterns-for-thread-safety)
3. [TaskGroup for Parallel Execution](#taskgroup-for-parallel-execution)
4. [AsyncSequence and Streaming](#asyncsequence-and-streaming)
5. [Structured Concurrency in SwiftUI](#structured-concurrency-in-swiftui)
6. [Error Handling in Async Code](#error-handling-in-async-code)
7. [Performance Optimization Patterns](#performance-optimization-patterns)
8. [ProjectOne-Specific Patterns](#projectone-specific-patterns)

---

## Basic Async/Await Patterns

### 🎓 **Learning Note: async/await Fundamentals**
```swift
// 📝 async/await replaces callback-based asynchronous code
// ✅ Instead of: completion handlers, delegate callbacks, closures
// 🎯 Benefits: Linear code flow, automatic error propagation, cancellation support

// Old callback style (avoid this):
func generateText(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Complex callback handling...
}

// Modern async/await style (use this):
func generateText(prompt: String) async throws -> String {
    // Linear, readable code flow
}
```

### Simple Async Function Pattern

```swift
// 🎓 Basic async function - used throughout ProjectOne
class MLXLLMProvider: BaseAIProvider {
    
    /// 📝 async throws function - can be awaited and propagates errors automatically
    public func loadModel(_ configuration: MLXModelConfiguration) async throws {
        // 🎯 await pauses this function until loadModel completes
        // 🧵 Thread is freed up for other work during the await
        let container = try await mlxService.loadModel(
            modelId: configuration.modelId, 
            type: .llm
        )
        
        // ✅ Code after await executes when the async operation completes
        self.modelContainer = container
        
        // 🎓 @MainActor ensures UI updates happen on main thread
        await MainActor.run {
            isReady = true
        }
    }
}
```

### Async Property Pattern

```swift
// 🎓 Async properties - computed properties that can await
extension MLXLLMProvider {
    
    /// 📝 Async property - computed asynchronously
    var modelInfo: MLXModelInfo? {
        get async {
            guard let container = modelContainer else { return nil }
            
            // 🎯 Can await inside async property getters
            let memoryUsage = await container.calculateMemoryUsage()
            
            return MLXModelInfo(
                name: container.modelId,
                memoryUsage: memoryUsage,
                isReady: container.isReady
            )
        }
    }
}

// Usage in async context:
let info = await provider.modelInfo
```

### Sequential vs Concurrent Execution

```swift
// 🎓 Sequential execution - operations happen one after another
func sequentialProcessing() async throws {
    // 📝 Each await waits for the previous one to complete
    let analysis = try await privacyAnalyzer.analyzePrivacy(query: query)     // Wait ~100ms
    let context = try await retrievalEngine.buildContext(for: query)          // Wait ~300ms  
    let response = try await aiProvider.generateResponse(prompt: query)       // Wait ~800ms
    // Total time: ~1200ms
}

// ✅ Concurrent execution - operations happen in parallel
func concurrentProcessing() async throws {
    // 🎯 async let starts operations concurrently
    async let analysis = privacyAnalyzer.analyzePrivacy(query: query)         // Start immediately
    async let context = retrievalEngine.buildContext(for: query)              // Start immediately
    
    // 📝 await waits for both to complete
    let (privacyResult, memoryContext) = try await (analysis, context)
    // Total time: ~max(100ms, 300ms) = 300ms - much faster!
    
    // Now use results for final processing
    let response = try await aiProvider.generateResponse(
        prompt: query, 
        context: memoryContext
    )
}
```

---

## Actor Patterns for Thread Safety

### 🎓 **Learning Note: Actors for Thread Safety**
```swift
// 📝 Actors automatically protect their mutable state from data races
// ✅ Instead of: Manual locking, DispatchQueue.sync, @synchronized
// 🎯 Benefits: Compile-time data race prevention, automatic synchronization

// Problem: Shared mutable state (data races possible)
class UnsafeCounter {
    private var count = 0  // ⚠️ Multiple threads can access simultaneously
    
    func increment() {
        count += 1  // 🚨 Data race! Not thread-safe
    }
}

// Solution: Actor protects mutable state
actor SafeCounter {
    private var count = 0  // ✅ Actor automatically protects this
    
    func increment() {
        count += 1  // ✅ Only one thread can access at a time
    }
    
    func getValue() -> Int {
        return count  // ✅ Safe read access
    }
}
```

### ModelContainer Actor Pattern

```swift
// 🎓 Actor for managing AI model state safely
actor ModelContainer {
    // 📝 All properties are automatically protected by the actor
    private var modelContext: ModelContext?
    private var isLoading = false
    private var lastUsed = Date()
    private var usageCount = 0
    
    /// 📝 Actor methods are async by default when called from outside
    func loadModel(modelId: String) async throws {
        // 🎯 Only one thread can execute actor methods at a time
        guard !isLoading else {
            throw ModelError.alreadyLoading
        }
        
        isLoading = true
        defer { isLoading = false }  // ✅ Cleanup guaranteed
        
        // 🧵 Expensive work - other actor calls will wait
        let context = try await MLXLMCommon.loadModel(
            configuration: .init(id: modelId)
        )
        
        self.modelContext = context
        self.lastUsed = Date()
        self.usageCount += 1
    }
    
    /// 📝 Non-isolated - can be called synchronously
    nonisolated var modelId: String {
        // 🎯 Read-only computed properties can be nonisolated
        return "current-model-id"
    }
}

// Usage:
let container = ModelContainer()
try await container.loadModel(modelId: "gemma-2-2b")  // 📝 await required for actor methods
```

### @MainActor for UI Updates

```swift
// 🎓 @MainActor ensures code runs on main thread - crucial for UI updates
@MainActor
class ConversationViewModel: ObservableObject {
    // 📝 All properties and methods run on main thread automatically
    @Published var messages: [ConversationMessage] = []
    @Published var isProcessing = false
    @Published var errorMessage: String?
    
    /// 📝 Already on main thread - can update UI properties directly
    func updateProcessingState(_ processing: Bool) {
        isProcessing = processing  // ✅ Safe UI update
    }
    
    /// 📝 Async method that stays on main thread
    func processMessage(_ content: String) async {
        isProcessing = true  // ✅ UI update on main thread
        
        do {
            // 🎯 Background work can be awaited from main thread
            let response = try await conversationManager.processMessage(
                ConversationMessage(content: content, role: .user)
            )
            
            // ✅ Back on main thread for UI updates
            messages.append(response.toMessage())
            isProcessing = false
            
        } catch {
            errorMessage = error.localizedDescription  // ✅ UI update
            isProcessing = false
        }
    }
}

// Usage in SwiftUI:
struct ConversationView: View {
    @StateObject private var viewModel = ConversationViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isProcessing {
                ProgressView("Processing...")  // ✅ UI updates automatically
            }
            
            Button("Send Message") {
                // 🎓 Task creates async context in sync environment
                Task {
                    await viewModel.processMessage("Hello AI!")
                }
            }
        }
    }
}
```

---

## TaskGroup for Parallel Execution

### 🎓 **Learning Note: TaskGroup for Parallel Work**
```swift
// 📝 TaskGroup runs multiple async tasks in parallel and collects results
// ✅ Instead of: Multiple async let bindings, manual task management
// 🎯 Benefits: Dynamic number of tasks, result collection, automatic cancellation

// Example: Testing multiple AI providers in parallel
```

### Testing Multiple AI Providers

```swift
// 🎓 Real example from ProjectOne's UnifiedAITestView
class AIProviderTester {
    
    func testAllProviders() async -> [ProviderTestResult] {
        // 📝 withTaskGroup creates a group for parallel execution
        return await withTaskGroup(of: ProviderTestResult.self) { group in
            var results: [ProviderTestResult] = []
            
            // 🎯 Add tasks to run in parallel
            group.addTask { [self] in
                await testMLXLLMProvider()     // Starts immediately
            }
            
            group.addTask { [self] in
                await testMLXVLMProvider()     // Starts immediately  
            }
            
            group.addTask { [self] in
                await testFoundationProvider() // Starts immediately
            }
            
            // 📝 Collect results as tasks complete (order not guaranteed)
            for await result in group {
                results.append(result)
            }
            
            return results
        }
        // 🎯 All tasks complete before this line executes
    }
    
    private func testMLXLLMProvider() async -> ProviderTestResult {
        let startTime = Date()
        
        do {
            let provider = MLXLLMProvider()
            try await provider.loadRecommendedModel()
            let response = try await provider.generateResponse(to: "Test prompt")
            
            return ProviderTestResult(
                providerName: "MLX LLM",
                success: true,
                duration: Date().timeIntervalSince(startTime),
                responseLength: response.count
            )
        } catch {
            return ProviderTestResult(
                providerName: "MLX LLM", 
                success: false,
                duration: Date().timeIntervalSince(startTime),
                error: error
            )
        }
    }
}
```

### Dynamic Task Creation

```swift
// 🎓 TaskGroup with dynamic number of tasks
func processMemoriesConcurrently(_ memories: [STMEntry]) async -> [ProcessedMemory] {
    // 📝 TaskGroup type matches the return type of individual tasks
    return await withTaskGroup(of: ProcessedMemory?.self) { group in
        
        // 🎯 Add one task per memory entry
        for memory in memories {
            group.addTask {
                do {
                    return try await processMemory(memory)
                } catch {
                    print("Failed to process memory: \(error)")
                    return nil  // 📝 Handle errors gracefully
                }
            }
        }
        
        // 🔄 Collect non-nil results
        var processedMemories: [ProcessedMemory] = []
        for await result in group {
            if let processed = result {
                processedMemories.append(processed)
            }
        }
        
        return processedMemories
    }
}

// Usage:
let memories = await getRecentMemories()
let processed = await processMemoriesConcurrently(memories)
print("Processed \(processed.count) of \(memories.count) memories")
```

### Error Handling in TaskGroups

```swift
// 🎓 TaskGroup with proper error handling
func robustParallelProcessing() async throws -> [String] {
    return try await withThrowingTaskGroup(of: String.self) { group in
        var results: [String] = []
        
        // 🎯 Add tasks that can throw errors
        group.addTask {
            try await riskyOperation1()
        }
        
        group.addTask {
            try await riskyOperation2() 
        }
        
        // 📝 Handle errors during collection
        do {
            for try await result in group {
                results.append(result)
            }
        } catch {
            // 🚨 If any task throws, entire group cancels
            print("Task group failed: \(error)")
            throw error
        }
        
        return results
    }
}

// Alternative: Continue on errors
func resilientParallelProcessing() async -> [String] {
    return await withTaskGroup(of: Result<String, Error>.self) { group in
        var results: [String] = []
        
        // 🎯 Wrap risky operations in Result
        group.addTask {
            do {
                let result = try await riskyOperation1()
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        
        // 📝 Handle success/failure cases
        for await result in group {
            switch result {
            case .success(let value):
                results.append(value)
            case .failure(let error):
                print("Task failed: \(error)")
                // Continue with other tasks
            }
        }
        
        return results
    }
}
```

---

## AsyncSequence and Streaming

### 🎓 **Learning Note: AsyncSequence for Streaming Data**
```swift
// 📝 AsyncSequence processes streams of data asynchronously
// ✅ Instead of: Combine publishers, callback-based streaming, delegate patterns
// 🎯 Benefits: for-await-in syntax, automatic backpressure, cancellation support

// AsyncSequence protocol:
protocol AsyncSequence {
    associatedtype Element
    func makeAsyncIterator() -> AsyncIterator
}
```

### AI Response Streaming

```swift
// 🎓 Real streaming pattern from ProjectOne's MLX providers
extension MLXLLMProvider {
    
    /// 📝 Returns AsyncThrowingStream for real-time response streaming
    func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
        // 🎯 AsyncThrowingStream creates custom async sequence
        return AsyncThrowingStream { continuation in
            
            // 📝 Task handles the streaming work
            Task {
                do {
                    guard let container = modelContainer else {
                        continuation.finish(throwing: MLXLLMError.modelNotLoaded("No model loaded"))
                        return
                    }
                    
                    // 🔄 Stream tokens from MLX model
                    for try await token in mlxService.streamGenerate(with: container, prompt: prompt) {
                        continuation.yield(token)  // 📝 Send each token to subscriber
                    }
                    
                    continuation.finish()  // ✅ Signal completion
                    
                } catch {
                    continuation.finish(throwing: error)  // 🚨 Signal error
                }
            }
        }
    }
}

// Usage in SwiftUI:
struct StreamingResponseView: View {
    @State private var streamedText = ""
    @State private var isStreaming = false
    
    private func startStreaming() {
        isStreaming = true
        streamedText = ""
        
        Task {
            do {
                // 🔄 for-await-in processes stream elements as they arrive
                for try await token in mlxProvider.streamResponse(to: "Write a story") {
                    await MainActor.run {
                        streamedText += token  // ✅ Update UI with each token
                    }
                }
                
                await MainActor.run {
                    isStreaming = false  // ✅ Streaming complete
                }
                
            } catch {
                await MainActor.run {
                    isStreaming = false
                    // Handle error...
                }
            }
        }
    }
    
    var body: some View {
        VStack {
            Text(streamedText)
                .padding()
            
            if isStreaming {
                ProgressView("Streaming response...")
            }
            
            Button("Start Streaming") {
                startStreaming()
            }
            .disabled(isStreaming)
        }
    }
}
```

### Memory Retrieval Streaming

```swift
// 🎓 Stream memory retrieval for progressive context building
extension MemoryRetrievalEngine {
    
    /// 📝 Stream memory context as it's built progressively
    func streamMemoryRetrieval(
        for query: String
    ) -> AsyncThrowingStream<MemoryContext, Error> {
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var context = MemoryContext.empty
                    
                    // 🎯 Stream STM entries first (fastest)
                    for try await stmEntry in retrieveSTMStream(query: query) {
                        context.shortTermMemories.append(stmEntry)
                        continuation.yield(context)  // 📝 Progressive update
                    }
                    
                    // 🎯 Stream LTM entries (slower)
                    for try await ltmEntry in retrieveLTMStream(query: query) {
                        context.longTermMemories.append(ltmEntry)
                        continuation.yield(context)  // 📝 Progressive update
                    }
                    
                    // 🎯 Stream entities (slowest)
                    for try await entity in retrieveEntitiesStream(query: query) {
                        context.entities.append(entity)
                        continuation.yield(context)  // 📝 Final update
                    }
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// Usage:
func buildProgressiveContext() async {
    do {
        for try await partialContext in retrievalEngine.streamMemoryRetrieval(for: query) {
            // 🎯 Update UI as context builds progressively
            await updateUIWithContext(partialContext)
            
            // 📝 Can make decisions based on partial context
            if partialContext.shortTermMemories.count >= 5 {
                print("Sufficient STM context available")
            }
        }
    } catch {
        print("Context building failed: \(error)")
    }
}
```

### Custom AsyncSequence Implementation

```swift
// 🎓 Custom AsyncSequence for batch processing
struct BatchedMemorySequence: AsyncSequence {
    typealias Element = [STMEntry]
    
    let memories: [STMEntry]
    let batchSize: Int
    
    func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(memories: memories, batchSize: batchSize)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        let memories: [STMEntry]
        let batchSize: Int
        private var currentIndex = 0
        
        mutating func next() async -> [STMEntry]? {
            guard currentIndex < memories.count else {
                return nil  // 📝 Signal end of sequence
            }
            
            // 🎯 Add artificial delay to simulate processing time
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            let endIndex = min(currentIndex + batchSize, memories.count)
            let batch = Array(memories[currentIndex..<endIndex])
            
            currentIndex = endIndex
            return batch
        }
    }
}

// Usage:
let sequence = BatchedMemorySequence(memories: allMemories, batchSize: 10)

for await batch in sequence {
    print("Processing batch of \(batch.count) memories")
    await processBatch(batch)
}
```

---

## Structured Concurrency in SwiftUI

### 🎓 **Learning Note: SwiftUI + Async/Await Integration**
```swift
// 📝 SwiftUI provides several ways to integrate with async/await:
// • .task {} modifier - runs async work when view appears
// • Task {} in button actions - creates async context
// • @State with async properties - manages async state
// • .refreshable {} - async pull-to-refresh
```

### Task Modifier Pattern

```swift
// 🎓 .task modifier for view lifecycle async work
struct AIProviderStatusView: View {
    @StateObject private var mlxProvider = MLXLLMProvider()
    @StateObject private var foundationProvider = AppleFoundationModelsProvider()
    
    @State private var systemStatus = "Initializing..."
    @State private var isHealthy = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("AI System Status")
                .font(.headline)
            
            Text(systemStatus)
                .foregroundColor(isHealthy ? .green : .orange)
            
            ProviderRow(name: "MLX LLM", isReady: mlxProvider.isReady)
            ProviderRow(name: "Foundation Models", isReady: foundationProvider.isAvailable)
        }
        .task {
            // 📝 .task runs when view appears, cancels when view disappears
            await initializeProviders()
        }
        .task(id: mlxProvider.isReady) {
            // 🎯 .task with id re-runs when dependency changes
            await updateSystemStatus()
        }
    }
    
    private func initializeProviders() async {
        systemStatus = "Loading AI providers..."
        
        // 🔄 Run provider initialization in parallel
        async let mlxSetup = setupMLXProvider()
        async let foundationSetup = setupFoundationProvider()
        
        // 📝 Wait for both to complete
        await (mlxSetup, foundationSetup)
        
        systemStatus = "Providers initialized"
        isHealthy = true
    }
    
    private func setupMLXProvider() async {
        do {
            try await mlxProvider.loadRecommendedModel()
        } catch {
            print("MLX setup failed: \(error)")
        }
    }
    
    private func setupFoundationProvider() async {
        await foundationProvider.checkAvailability()
    }
    
    private func updateSystemStatus() async {
        if mlxProvider.isReady && foundationProvider.isAvailable {
            systemStatus = "All providers ready ✅"
            isHealthy = true
        } else {
            systemStatus = "Providers loading..."
            isHealthy = false
        }
    }
}
```

### Button Action Async Pattern

```swift
// 🎓 Async work in button actions using Task
struct ConversationView: View {
    @StateObject private var conversationManager = ConversationManager()
    @State private var messageText = ""
    @State private var isProcessing = false
    @State private var messages: [ConversationMessage] = []
    
    var body: some View {
        VStack {
            List(messages) { message in
                MessageRow(message: message)
            }
            
            HStack {
                TextField("Message...", text: $messageText)
                
                Button("Send") {
                    // 🎓 Task creates async context in sync button action
                    Task {
                        await sendMessage()
                    }
                }
                .disabled(isProcessing || messageText.isEmpty)
            }
            
            if isProcessing {
                ProgressView("Processing...")
            }
        }
        .task {
            // 📝 Initialize conversation when view appears
            await conversationManager.startNewSession()
        }
    }
    
    @MainActor
    private func sendMessage() async {
        let userMessage = ConversationMessage(
            content: messageText,
            role: .user
        )
        
        // ✅ Update UI immediately (optimistic update)
        messages.append(userMessage)
        messageText = ""
        isProcessing = true
        
        do {
            // 🎯 Background AI processing
            let response = try await conversationManager.processMessage(userMessage)
            
            // ✅ Update UI with response (back on main thread)
            let assistantMessage = ConversationMessage(
                content: response.content,
                role: .assistant
            )
            messages.append(assistantMessage)
            
        } catch {
            // 🚨 Handle error gracefully
            let errorMessage = ConversationMessage(
                content: "Sorry, I couldn't process that message: \(error.localizedDescription)",
                role: .system
            )
            messages.append(errorMessage)
        }
        
        isProcessing = false
    }
}
```

### Refreshable Async Pattern

```swift
// 🎓 .refreshable for pull-to-refresh async operations
struct MemoryListView: View {
    @State private var memories: [STMEntry] = []
    @State private var isLoading = false
    @State private var lastRefresh: Date?
    
    var body: some View {
        NavigationView {
            List(memories) { memory in
                MemoryRow(memory: memory)
            }
            .navigationTitle("Recent Memories")
            .refreshable {
                // 📝 .refreshable provides async context automatically
                await refreshMemories()
            }
            .task {
                // 📝 Load initial data
                if memories.isEmpty {
                    await loadMemories()
                }
            }
            .overlay {
                if isLoading && memories.isEmpty {
                    ProgressView("Loading memories...")
                }
            }
        }
    }
    
    private func refreshMemories() async {
        lastRefresh = Date()
        
        do {
            // 🎯 Refresh from memory system
            let refreshedMemories = try await memoryEngine.getRecentMemories(
                since: lastRefresh?.addingTimeInterval(-3600) ?? Date().addingTimeInterval(-86400)
            )
            
            // ✅ Update UI on main thread
            await MainActor.run {
                memories = refreshedMemories
            }
            
        } catch {
            print("Refresh failed: \(error)")
        }
    }
    
    private func loadMemories() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let loadedMemories = try await memoryEngine.getAllMemories()
            
            await MainActor.run {
                memories = loadedMemories
            }
            
        } catch {
            print("Load failed: \(error)")
        }
    }
}
```

---

## Error Handling in Async Code

### 🎓 **Learning Note: Async Error Handling**
```swift
// 📝 Async functions can throw errors just like sync functions
// ✅ try/catch works the same way with async/await
// 🎯 Benefits: Automatic error propagation up the call stack

// Error propagation in async calls:
func level1() async throws -> String {
    throw NetworkError.connectionFailed
}

func level2() async throws -> String {
    return try await level1()  // Error automatically propagates
}

func level3() async throws -> String {
    return try await level2()  // Error continues propagating
}
```

### Structured Error Handling

```swift
// 🎓 Comprehensive error handling in ProjectOne
class ConversationManager {
    
    func processMessage(_ message: ConversationMessage) async throws -> ConversationResponse {
        do {
            // 🎯 Multiple throwing operations
            let privacyAnalysis = try await privacyAnalyzer.analyzePrivacy(
                query: message.content
            )
            
            let memoryContext = try await retrievalEngine.retrieveRelevantMemories(
                for: message.content,
                privacyLevel: privacyAnalysis.level
            )
            
            let response = try await aiProvider.generateResponse(
                prompt: message.content,
                context: memoryContext
            )
            
            return ConversationResponse(
                content: response.content,
                confidence: response.confidence,
                provider: response.modelUsed
            )
            
        } catch let error as PrivacyAnalysisError {
            // 🎯 Specific error type handling
            logger.error("Privacy analysis failed: \(error.localizedDescription)")
            throw ConversationError.privacyAnalysisFailed(error.localizedDescription)
            
        } catch let error as MemoryRetrievalError {
            logger.error("Memory retrieval failed: \(error.localizedDescription)")
            
            // 📝 Graceful degradation - continue without memory context
            let response = try await aiProvider.generateResponse(
                prompt: message.content,
                context: MemoryContext.empty
            )
            
            return ConversationResponse(
                content: response.content,
                confidence: response.confidence * 0.8, // Lower confidence
                provider: response.modelUsed
            )
            
        } catch let error as AIProviderError {
            logger.error("AI provider failed: \(error.localizedDescription)")
            
            // 🔄 Try fallback provider
            if let fallbackResponse = try? await tryFallbackProvider(message.content) {
                return fallbackResponse
            }
            
            throw ConversationError.allProvidersUnavailable
            
        } catch {
            // 🚨 Unexpected error handling
            logger.error("Unexpected error in processMessage: \(error)")
            throw ConversationError.unexpectedError(error.localizedDescription)
        }
    }
    
    private func tryFallbackProvider(_ prompt: String) async throws -> ConversationResponse {
        // Implementation of fallback logic...
        throw AIProviderError.providerUnavailable("No fallback available")
    }
}
```

### Error Recovery Patterns

```swift
// 🎓 Retry logic with exponential backoff
func robustAIGeneration(prompt: String, maxRetries: Int = 3) async throws -> String {
    var lastError: Error?
    
    for attempt in 0..<maxRetries {
        do {
            // 🎯 Try the operation
            return try await aiProvider.generateResponse(prompt: prompt)
            
        } catch let error as AIProviderError where error.isRetryable {
            lastError = error
            
            if attempt < maxRetries - 1 {
                // 📈 Exponential backoff: 1s, 2s, 4s...
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                print("Retry attempt \(attempt + 1) after \(delay)s delay")
            }
            
        } catch {
            // 🚨 Non-retryable error - fail immediately
            throw error
        }
    }
    
    // 🚨 All retries exhausted
    throw lastError ?? AIProviderError.maxRetriesExceeded
}

// Usage with graceful error handling:
func handleUserQuery(_ query: String) async -> String {
    do {
        return try await robustAIGeneration(prompt: query)
        
    } catch AIProviderError.modelNotLoaded {
        return "I'm still loading my AI model. Please try again in a moment."
        
    } catch AIProviderError.maxRetriesExceeded {
        return "I'm having trouble processing your request right now. Please try again later."
        
    } catch {
        return "I apologize, but I encountered an error: \(error.localizedDescription)"
    }
}
```

### Timeout Pattern

```swift
// 🎓 Timeout wrapper for async operations
func withTimeout<T>(
    _ operation: @escaping () async throws -> T,
    timeout: TimeInterval
) async throws -> T {
    
    return try await withThrowingTaskGroup(of: T.self) { group in
        
        // 🎯 Add the actual operation
        group.addTask {
            try await operation()
        }
        
        // 📝 Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw TimeoutError.operationTimedOut(after: timeout)
        }
        
        // 🏁 Return first completion (operation or timeout)
        let result = try await group.next()!
        group.cancelAll()  // Cancel remaining task
        return result
    }
}

// Usage:
func generateWithTimeout(_ prompt: String) async -> String {
    do {
        return try await withTimeout({
            try await aiProvider.generateResponse(prompt: prompt)
        }, timeout: 10.0)
        
    } catch TimeoutError.operationTimedOut(let duration) {
        return "Request timed out after \(duration) seconds. Please try a simpler query."
        
    } catch {
        return "Error: \(error.localizedDescription)"
    }
}
```

---

## Performance Optimization Patterns

### 🎓 **Learning Note: Async Performance Best Practices**
```swift
// 📝 Common performance issues with async/await:
// ❌ Sequential awaits when parallel is possible
// ❌ Creating too many concurrent tasks
// ❌ Not using Task.yield() in CPU-intensive work
// ❌ Blocking main thread with sync operations
```

### Task.yield() for Cooperative Cancellation

```swift
// 🎓 CPU-intensive work that yields control periodically
func processLargeMemoryDataset(_ memories: [STMEntry]) async throws -> [ProcessedMemory] {
    var processed: [ProcessedMemory] = []
    processed.reserveCapacity(memories.count)
    
    for (index, memory) in memories.enumerated() {
        // ⚡ Check for cancellation
        try Task.checkCancellation()
        
        // 🎯 Intensive processing work
        let processedMemory = await intensiveMemoryProcessing(memory)
        processed.append(processedMemory)
        
        // 🤝 Yield control every 100 items for responsiveness
        if index % 100 == 0 {
            await Task.yield()  // 📝 Let other tasks run
        }
    }
    
    return processed
}

// Supporting function:
private func intensiveMemoryProcessing(_ memory: STMEntry) async -> ProcessedMemory {
    // Simulate intensive work
    var result = memory.content
    for _ in 0..<1000 {
        result = String(result.hash)
    }
    
    return ProcessedMemory(
        id: memory.id,
        processedContent: result,
        confidence: 0.95
    )
}
```

### Concurrent Processing with Limits

```swift
// 🎓 Limited concurrency to avoid overwhelming system resources
class ConcurrentMemoryProcessor {
    private let maxConcurrentOperations = 4
    
    func processConcurrently(_ memories: [STMEntry]) async -> [ProcessedMemory] {
        // 📝 Process in batches to limit concurrency
        let batches = memories.chunked(into: maxConcurrentOperations)
        var allResults: [ProcessedMemory] = []
        
        for batch in batches {
            // 🎯 Process each batch in parallel
            let batchResults = await withTaskGroup(of: ProcessedMemory?.self) { group in
                var results: [ProcessedMemory] = []
                
                for memory in batch {
                    group.addTask {
                        do {
                            return try await self.processMemory(memory)
                        } catch {
                            print("Failed to process memory \(memory.id): \(error)")
                            return nil
                        }
                    }
                }
                
                for await result in group {
                    if let processed = result {
                        results.append(processed)
                    }
                }
                
                return results
            }
            
            allResults.append(contentsOf: batchResults)
        }
        
        return allResults
    }
    
    private func processMemory(_ memory: STMEntry) async throws -> ProcessedMemory {
        // Simulate processing time
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        return ProcessedMemory(
            id: memory.id,
            processedContent: memory.content.uppercased(),
            confidence: 0.9
        )
    }
}

// Array extension for batching:
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
```

### Lazy Loading Pattern

```swift
// 🎓 Lazy loading with async properties
class MemoryContextManager {
    private var _shortTermCache: [STMEntry]?
    private var _longTermCache: [LTMEntry]?
    private var _entityCache: [Entity]?
    
    // 📝 Lazy loading with caching
    var shortTermMemories: [STMEntry] {
        get async {
            if let cached = _shortTermCache {
                return cached  // ✅ Return cached data
            }
            
            // 🎯 Load asynchronously only when needed
            let loaded = try? await loadShortTermMemories()
            _shortTermCache = loaded ?? []
            return _shortTermCache!
        }
    }
    
    var longTermMemories: [LTMEntry] {
        get async {
            if let cached = _longTermCache {
                return cached
            }
            
            let loaded = try? await loadLongTermMemories()
            _longTermCache = loaded ?? []
            return _longTermCache!
        }
    }
    
    var entities: [Entity] {
        get async {
            if let cached = _entityCache {
                return cached
            }
            
            let loaded = try? await loadEntities()
            _entityCache = loaded ?? []
            return _entityCache!
        }
    }
    
    // 📝 Build context using lazy loading
    func buildContext(for query: String) async -> MemoryContext {
        // 🔄 Load data in parallel, leveraging caching
        async let stm = shortTermMemories
        async let ltm = longTermMemories  
        async let entities = self.entities
        
        let (shortTerm, longTerm, entityList) = await (stm, ltm, entities)
        
        return MemoryContext(
            entities: entityList,
            shortTermMemories: shortTerm,
            longTermMemories: longTerm,
            userQuery: query
        )
    }
    
    // 🔄 Cache invalidation
    func invalidateCache() {
        _shortTermCache = nil
        _longTermCache = nil
        _entityCache = nil
    }
    
    private func loadShortTermMemories() async throws -> [STMEntry] {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        return [] // Load from data store
    }
    
    private func loadLongTermMemories() async throws -> [LTMEntry] {
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        return [] // Load from data store
    }
    
    private func loadEntities() async throws -> [Entity] {
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        return [] // Load from data store
    }
}
```

---

## ProjectOne-Specific Patterns

### Multi-Provider AI Orchestration

```swift
// 🎓 Real pattern from ProjectOne's EnhancedGemma3nCore
@available(iOS 26.0, macOS 26.0, *)
class EnhancedGemma3nCore: ObservableObject {
    
    @StateObject private var mlxLLMProvider = MLXLLMProvider()
    @StateObject private var mlxVLMProvider = MLXVLMProvider()  
    @StateObject private var foundationProvider = AppleFoundationModelsProvider()
    
    // 🎯 Initialize all providers concurrently
    func setup() async {
        await withTaskGroup(of: Void.self) { group in
            
            group.addTask { [self] in
                do {
                    try await mlxLLMProvider.loadRecommendedModel()
                } catch {
                    print("MLX LLM setup failed: \(error)")
                }
            }
            
            group.addTask { [self] in
                do {
                    try await mlxVLMProvider.loadRecommendedModel()
                } catch {
                    print("MLX VLM setup failed: \(error)")
                }
            }
            
            group.addTask { [self] in
                await foundationProvider.initialize()
            }
        }
    }
    
    // 🎯 Smart provider selection based on request characteristics
    func processText(_ text: String, images: [PlatformImage] = []) async -> String {
        let selectedProvider = await selectBestProvider(for: text, images: images)
        
        do {
            switch selectedProvider {
            case .mlxLLM:
                return try await mlxLLMProvider.generateResponse(to: text)
            case .mlxVLM:
                return try await mlxVLMProvider.generateResponse(to: text, images: images)
            case .foundation:
                return try await foundationProvider.generateModelResponse(text)
            case .automatic:
                return await processWithAutomatic(text, images: images)
            }
        } catch {
            // 🔄 Fallback to alternative provider
            return await handleProviderError(error, originalText: text, images: images)
        }
    }
    
    private func selectBestProvider(
        for text: String, 
        images: [PlatformImage]
    ) async -> AIProviderType {
        
        // 🎯 Multimodal requests require VLM
        if !images.isEmpty {
            return mlxVLMProvider.isReady ? .mlxVLM : .automatic
        }
        
        // 🎯 Check privacy requirements
        let privacyAnalysis = await analyzePrivacyRequirements(text)
        if privacyAnalysis.requiresOnDevice {
            return mlxLLMProvider.isReady ? .mlxLLM : .automatic
        }
        
        // 🎯 Prefer Foundation Models for system integration
        if foundationProvider.isAvailable {
            return .foundation
        }
        
        // 🎯 Fallback to MLX
        return mlxLLMProvider.isReady ? .mlxLLM : .automatic
    }
    
    private func handleProviderError(
        _ error: Error,
        originalText: String,
        images: [PlatformImage]
    ) async -> String {
        
        print("Provider failed with error: \(error)")
        
        // 🔄 Try alternative providers
        if !images.isEmpty && mlxVLMProvider.isReady {
            do {
                return try await mlxVLMProvider.generateResponse(to: originalText, images: images)
            } catch {
                print("VLM fallback also failed: \(error)")
            }
        }
        
        if mlxLLMProvider.isReady {
            do {
                return try await mlxLLMProvider.generateResponse(to: originalText)
            } catch {
                print("LLM fallback also failed: \(error)")
            }
        }
        
        return "I'm sorry, I'm unable to process your request right now. Please try again later."
    }
    
    private func analyzePrivacyRequirements(_ text: String) async -> PrivacyAnalysis {
        // Simplified privacy analysis
        let personalIndicators = ["my", "i am", "personal", "private"]
        let containsPersonal = personalIndicators.contains { text.lowercased().contains($0) }
        
        return PrivacyAnalysis(
            level: containsPersonal ? .personal : .publicKnowledge,
            requiresOnDevice: containsPersonal,
            confidence: 0.8
        )
    }
}
```

### Autonomous Memory Operations

```swift
// 🎓 Background autonomous operations pattern
class MemoryAgentOrchestrator: ObservableObject {
    
    private var orchestrationTask: Task<Void, Never>?
    @Published var isRunning = false
    
    func startAutonomousOperations() {
        guard !isRunning else { return }
        
        isRunning = true
        
        // 🎯 Start long-running background task
        orchestrationTask = Task {
            await runOrchestrationLoop()
        }
    }
    
    func stopAutonomousOperations() async {
        orchestrationTask?.cancel()
        
        // 📝 Wait for graceful shutdown
        await orchestrationTask?.value
        
        isRunning = false
        orchestrationTask = nil
    }
    
    private func runOrchestrationLoop() async {
        while !Task.isCancelled {
            do {
                // 🔄 Periodic autonomous operations
                await performMemoryConsolidation()
                
                try await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                
                await performEntityExtraction()
                
                try await Task.sleep(nanoseconds: 600_000_000_000) // 10 minutes
                
                await performKnowledgeGraphUpdate()
                
                try await Task.sleep(nanoseconds: 1_800_000_000_000) // 30 minutes
                
            } catch {
                if Task.isCancelled {
                    break
                }
                print("Orchestration error: \(error)")
                
                // 📝 Back off on errors
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 1 minute
            }
        }
    }
    
    private func performMemoryConsolidation() async {
        print("🧠 Starting memory consolidation...")
        
        do {
            let recentMemories = try await getRecentSTMEntries()
            
            // 🎯 Process memories in small batches
            for batch in recentMemories.chunked(into: 10) {
                try Task.checkCancellation() // Check if we should stop
                
                let consolidatedMemories = try await consolidateBatch(batch)
                await saveConsolidatedMemories(consolidatedMemories)
                
                // 🤝 Yield between batches
                await Task.yield()
            }
            
            print("✅ Memory consolidation complete")
            
        } catch {
            print("❌ Memory consolidation failed: \(error)")
        }
    }
    
    private func performEntityExtraction() async {
        print("🏷️ Starting entity extraction...")
        
        // Similar pattern for entity extraction...
        
        print("✅ Entity extraction complete")
    }
    
    private func performKnowledgeGraphUpdate() async {
        print("🕸️ Starting knowledge graph update...")
        
        // Similar pattern for knowledge graph updates...
        
        print("✅ Knowledge graph update complete")
    }
    
    private func getRecentSTMEntries() async throws -> [STMEntry] {
        // Implementation...
        return []
    }
    
    private func consolidateBatch(_ batch: [STMEntry]) async throws -> [LTMEntry] {
        // Implementation...
        return []
    }
    
    private func saveConsolidatedMemories(_ memories: [LTMEntry]) async {
        // Implementation...
    }
}
```

### Conversation Streaming Pattern

```swift
// 🎓 Real-time conversation with memory integration
class ConversationManager: ObservableObject {
    
    func streamConversationResponse(
        for message: ConversationMessage
    ) -> AsyncThrowingStream<ConversationResponseChunk, Error> {
        
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    // 📝 Build context first
                    continuation.yield(ConversationResponseChunk(
                        content: "",
                        type: .contextBuilding,
                        isComplete: false
                    ))
                    
                    let memoryContext = try await buildMemoryContext(for: message.content)
                    
                    // 📝 Signal context ready
                    continuation.yield(ConversationResponseChunk(
                        content: "",
                        type: .contextReady,
                        isComplete: false
                    ))
                    
                    // 🔄 Stream AI response
                    var fullResponse = ""
                    for try await token in aiProvider.streamResponse(
                        to: message.content,
                        context: memoryContext
                    ) {
                        fullResponse += token
                        
                        continuation.yield(ConversationResponseChunk(
                            content: fullResponse,
                            type: .responseToken,
                            isComplete: false
                        ))
                    }
                    
                    // ✅ Signal completion
                    continuation.yield(ConversationResponseChunk(
                        content: fullResponse,
                        type: .responseComplete,
                        isComplete: true
                    ))
                    
                    continuation.finish()
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// Usage in SwiftUI:
struct StreamingConversationView: View {
    @State private var currentResponse = ""
    @State private var isStreaming = false
    @State private var streamingStatus = "Ready"
    
    private func startConversationStream() {
        let message = ConversationMessage(content: "Tell me about AI", role: .user)
        
        isStreaming = true
        currentResponse = ""
        
        Task {
            do {
                for try await chunk in conversationManager.streamConversationResponse(for: message) {
                    await MainActor.run {
                        switch chunk.type {
                        case .contextBuilding:
                            streamingStatus = "Building context..."
                        case .contextReady:
                            streamingStatus = "Generating response..."
                        case .responseToken:
                            currentResponse = chunk.content
                        case .responseComplete:
                            streamingStatus = "Complete"
                            isStreaming = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    streamingStatus = "Error: \(error.localizedDescription)"
                    isStreaming = false
                }
            }
        }
    }
}
```

## Summary

Swift's async/await concurrency model enables ProjectOne to deliver:

- **⚡ Responsive UI**: Non-blocking operations keep the interface smooth
- **🔄 Parallel Processing**: Multiple AI providers can work simultaneously  
- **📡 Real-time Streaming**: Live response generation and progressive context building
- **🧵 Thread Safety**: Actors and @MainActor prevent data races
- **🎯 Structured Concurrency**: TaskGroups organize complex parallel workflows
- **🚨 Robust Error Handling**: Graceful error propagation and recovery
- **⚖️ Resource Management**: Efficient memory and CPU usage patterns

### Best Practices for ProjectOne Development

1. **Use async/await over callbacks** - Cleaner code, better error handling
2. **Leverage TaskGroup for parallel work** - Test providers, process memories
3. **Stream long-running operations** - AI responses, memory retrieval
4. **Protect shared state with actors** - Model containers, caches
5. **Update UI with @MainActor** - All SwiftUI state changes
6. **Handle cancellation gracefully** - Check Task.isCancellation, use defer
7. **Implement retry logic** - Network calls, model loading
8. **Use lazy loading patterns** - Load expensive resources on demand

These patterns enable ProjectOne's sophisticated AI and memory systems to work seamlessly while maintaining excellent user experience and system performance.

---

## Navigation

- **← Back to [Guides Index](README.md)**
- **→ Swift Concepts: [SwiftConceptsGuide.md](SwiftConceptsGuide.md)**
- **→ Architecture: [Architecture](../architecture/README.md)**

---

*Last updated: 2025-07-22 - Production async/await patterns for ProjectOne AI systems*