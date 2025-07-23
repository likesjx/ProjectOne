# Swift Concepts Guide for ProjectOne 🎓

> **Comprehensive Swift learning guide using real examples from your AI codebase**

This guide explains essential Swift concepts using actual code from ProjectOne. Each concept is demonstrated with working examples from your AI provider architecture, making it easier to understand Swift in context.

## Table of Contents

1. [Property Wrappers](#property-wrappers)
2. [Protocol-Oriented Programming](#protocol-oriented-programming) 
3. [Async/Await Concurrency](#asyncawait-concurrency)
4. [SwiftUI State Management](#swiftui-state-management)
5. [Error Handling](#error-handling)
6. [Enums with Associated Values](#enums-with-associated-values)
7. [Generics and Type Safety](#generics-and-type-safety)
8. [Memory Management](#memory-management)
9. [Combine Framework](#combine-framework)
10. [Cross-Platform Development](#cross-platform-development)

---

## Property Wrappers

Property wrappers are one of Swift's most powerful features, providing a way to encapsulate common patterns around property storage and access.

### @Published - Reactive Data Binding

From `MLXLLMProvider.swift`:

```swift
public class MLXLLMProvider: ObservableObject {
    // 🎓 @Published creates reactive data streams
    @Published public var isReady = false
    @Published public var isLoading = false  
    @Published public var errorMessage: String?
    @Published public var loadingProgress: Double = 0.0
}
```

**What @Published does:**
- Automatically triggers UI updates when values change
- Creates a Publisher (Combine framework) behind the scenes
- Works with ObservableObject to notify SwiftUI views
- Essential for reactive SwiftUI applications

**When to use @Published:**
- UI state that needs to trigger view updates
- Data that multiple parts of your app observe
- Properties in ObservableObject classes

### @State - Local View State

From `UnifiedAITestView.swift`:

```swift
struct UnifiedAITestView: View {
    @State private var testPrompt = "Hello, how are you?"
    @State private var selectedProviders: Set<TestProviderType> = []
    @State private var testResults: [ProviderTestResult] = []
    @State private var isLoading = false
}
```

**What @State does:**
- Creates reactive local state for SwiftUI views
- Automatically triggers view re-renders when changed
- Stores state outside the view's struct (views are value types)
- Perfect for UI state like form inputs, loading states

### @StateObject vs @ObservedObject

```swift
struct UnifiedAITestView: View {
    // @StateObject - View OWNS and creates the object
    @StateObject private var mlxLLMProvider = MLXLLMProvider()
    
    // @ObservedObject - View observes object owned elsewhere  
    @ObservedObject var sharedProvider: SomeProvider
}
```

**Key differences:**
- **@StateObject**: Creates and owns the object, keeps it alive
- **@ObservedObject**: Observes object owned by parent or elsewhere
- Use @StateObject for objects this view creates
- Use @ObservedObject for objects passed from parent views

### @MainActor - Thread Safety

From `BaseAIProvider.swift`:

```swift
@MainActor
public func updateAvailability(_ available: Bool) {
    isAvailable = available
    lastUpdated = Date()
    objectWillChange.send()
}
```

**What @MainActor does:**
- Ensures method always runs on the main thread
- Crucial for UI updates (SwiftUI requires main thread)
- Prevents crashes from background thread UI access
- Can be applied to methods, classes, or properties

---

## Protocol-Oriented Programming

Swift favors protocols over class inheritance. Your codebase demonstrates both patterns.

### Current Pattern (Class-Based)

From `BaseAIProvider.swift`:

```swift
// ⚠️ Current anti-pattern using fatalError
public class BaseAIProvider: AIModelProvider, ObservableObject {
    public var identifier: String { 
        fatalError("Must override identifier") 
    }
    public var displayName: String { 
        fatalError("Must override displayName") 
    }
}
```

### Better Pattern (Protocol-Based)

**This is what we'll refactor to:**

```swift
protocol AIModelProvider {
    var identifier: String { get }
    var displayName: String { get }
    var maxContextLength: Int { get }
    
    func generateResponse(prompt: String, context: MemoryContext) async throws -> AIModelResponse
    func prepare() async throws
    func cleanup() async
}

// Default implementations for common behavior
extension AIModelProvider {
    func getModelConfidence() -> Double { 0.85 }
    
    func measureProcessingTime<T>(_ operation: () async throws -> T) async throws -> (result: T, time: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let processingTime = Date().timeIntervalSince(startTime)
        return (result, processingTime)
    }
}
```

**Benefits of protocols:**
- No forced inheritance hierarchy
- Multiple protocol conformance
- Default implementations via extensions
- Better testability and flexibility
- True Swift philosophy: "Protocol-Oriented Programming"

---

## Async/Await Concurrency

Modern Swift uses async/await for handling asynchronous operations safely.

### Basic Async Functions

From `MLXLLMProvider.swift`:

```swift
public func loadModel(_ configuration: MLXModelConfiguration) async throws {
    // Validate input
    guard configuration.type == .llm else {
        throw MLXLLMError.invalidModelType("Configuration is not for LLM model")
    }
    
    // Async work - doesn't block the caller
    let container = try await mlxService.loadModel(modelId: configuration.modelId, type: .llm)
    
    // Update UI on main thread
    await MainActor.run {
        isReady = true
        modelLoadingStatus = .ready
    }
}
```

**Key concepts:**
- `async`: Function can suspend (pause) execution
- `await`: Suspends until the operation completes
- `throws`: Function can throw errors
- `async throws`: Both asynchronous AND can throw errors

### TaskGroup - Structured Concurrency

From `UnifiedAITestView.swift`:

```swift
private func testProviders(_ providers: [TestProviderType]) {
    Task {
        var results: [ProviderTestResult] = []
        
        // Test all providers in parallel
        await withTaskGroup(of: ProviderTestResult.self) { group in
            for providerType in providers {
                group.addTask {
                    await testProvider(providerType)  // Runs in parallel
                }
            }
            
            // Collect results as they complete
            for await result in group {
                results.append(result)
            }
        }
        
        // Update UI when all complete
        await MainActor.run {
            testResults = results.sorted { $0.responseTime < $1.responseTime }
            isLoading = false
        }
    }
}
```

**TaskGroup benefits:**
- **Structured concurrency**: All tasks complete before continuing
- **Automatic cleanup**: Cancelled tasks are properly cleaned up
- **Type safety**: TaskGroup<ProviderTestResult> ensures type safety
- **Performance**: True parallelism on multi-core devices

### AsyncThrowingStream - Real-Time Data

From `MLXLLMProvider.swift`:

```swift
public func streamResponse(to prompt: String) -> AsyncThrowingStream<String, Error> {
    return AsyncThrowingStream { continuation in
        Task {
            do {
                // Stream chunks as they're generated
                for try await chunk in mlxService.streamGenerate(with: container, prompt: prompt) {
                    continuation.yield(chunk)  // Send chunk to UI
                }
                continuation.finish()  // Signal completion
            } catch {
                continuation.finish(throwing: error)  // Propagate errors
            }
        }
    }
}
```

**AsyncThrowingStream use cases:**
- Real-time AI text generation (like ChatGPT typing effect)
- Streaming data from servers
- Progress updates for long operations
- Any data that arrives over time

---

## SwiftUI State Management

SwiftUI uses a declarative paradigm where UI automatically updates when state changes.

### Reactive Data Flow

```swift
struct UnifiedAITestView: View {
    @State private var testResults: [ProviderTestResult] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // UI automatically updates when testResults changes
            ForEach(testResults.indices, id: \.self) { index in
                TestResultCard(result: testResults[index])
            }
            
            // Button state depends on isLoading
            Button("Test Providers") {
                testSelectedProviders()
            }
            .disabled(isLoading)  // Automatically updates when isLoading changes
        }
    }
}
```

### ObservableObject Integration

```swift
@StateObject private var mlxProvider = MLXLLMProvider()

// In the view body:
Text(mlxProvider.statusMessage)  // Updates when provider's @Published properties change
    .foregroundColor(mlxProvider.isReady ? .green : .red)
```

**The magic:**
1. `MLXLLMProvider` conforms to `ObservableObject`
2. Its `@Published` properties create data streams
3. SwiftUI automatically subscribes to these streams
4. When properties change, SwiftUI re-renders affected views
5. All happens automatically - no manual refresh needed!

---

## Error Handling

Swift uses typed error handling for safe, predictable error management.

### Custom Error Types

From `MLXLLMProvider.swift`:

```swift
public enum MLXLLMError: Error, LocalizedError {
    case deviceNotSupported(String)
    case modelNotLoaded(String)  
    case modelNotReady(String)
    case generationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported(let message):
            return "Device not supported: \(message)"
        case .modelNotLoaded(let message):
            return "Model not loaded: \(message)"
        case .modelNotReady(let message):
            return "Model not ready: \(message)"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        }
    }
}
```

### Error Propagation

```swift
public func generateResponse(to prompt: String) async throws -> String {
    // Guard statements throw errors for invalid state
    guard let container = modelContainer else {
        throw MLXLLMError.modelNotLoaded("No LLM model loaded")
    }
    
    guard isReady else {
        throw MLXLLMError.modelNotReady("LLM model is not ready") 
    }
    
    do {
        // Try the operation
        let response = try await mlxService.generate(with: container, prompt: prompt)
        return response
    } catch {
        // Re-throw with more context
        throw MLXLLMError.generationFailed(error.localizedDescription)
    }
}
```

### Error Handling in UI

```swift
private func testProvider(_ providerType: TestProviderType) async -> ProviderTestResult {
    do {
        let response = try await generateResponse(for: providerType, prompt: testPrompt)
        return ProviderTestResult(
            providerName: providerType.rawValue,
            response: response,
            responseTime: responseTime,
            success: true,
            error: nil
        )
    } catch {
        return ProviderTestResult(
            providerName: providerType.rawValue,
            response: "",
            responseTime: responseTime, 
            success: false,
            error: error.localizedDescription  // User-friendly error message
        )
    }
}
```

---

## Enums with Associated Values

Swift enums are incredibly powerful, supporting associated data and computed properties.

### State Management Enum

From `BaseAIProvider.swift`:

```swift
public enum ModelLoadingStatus: Equatable {
    case notStarted
    case preparing  
    case downloading(progress: Double)  // Associated value
    case loading
    case ready
    case failed(String)  // Associated value with error message
    case unavailable
    
    // Computed properties  
    public var isLoading: Bool {
        switch self {
        case .preparing, .downloading, .loading:
            return true
        default:
            return false
        }
    }
    
    public var description: String {
        switch self {
        case .notStarted: return "Not Started"
        case .preparing: return "Preparing..."
        case .downloading(let progress):  // Extract associated value
            return "Downloading \(Int(progress * 100))%"
        case .loading: return "Loading Model..."
        case .ready: return "Ready"
        case .failed(let error):  // Extract error message
            return "Failed: \(error)"
        case .unavailable: return "Unavailable"
        }
    }
}
```

### Provider Type Enum

From `UnifiedAITestView.swift`:

```swift
enum TestProviderType: String, CaseIterable {
    case mlxLLM = "MLX LLM (Text-Only)"
    case mlxVLM = "MLX VLM (Multimodal)" 
    case appleFoundationModels = "Apple Foundation Models"
    case enhancedGemma3nCore = "Enhanced Gemma3n Core"
    
    // Computed properties provide different behavior per case
    var icon: String {
        switch self {
        case .mlxLLM: return "textformat"
        case .mlxVLM: return "photo.on.rectangle"
        case .appleFoundationModels: return "apple.logo"
        case .enhancedGemma3nCore: return "cpu"
        }
    }
    
    var supportsImages: Bool {
        switch self {
        case .mlxVLM, .enhancedGemma3nCore: return true
        default: return false
        }
    }
}
```

**Enum benefits:**
- **Type safety**: Only valid cases allowed
- **Associated values**: Each case can carry different data
- **Computed properties**: Different behavior per case
- **Pattern matching**: Exhaustive switch statements
- **CaseIterable**: Automatic array of all cases

---

## Generics and Type Safety

Swift's type system prevents many runtime errors through compile-time checking.

### Generic Functions

From `BaseAIProvider.swift`:

```swift
public func measureProcessingTime<T>(_ operation: () async throws -> T) async throws -> (result: T, time: TimeInterval) {
    let startTime = Date()
    let result = try await operation()  // T can be any type
    let processingTime = Date().timeIntervalSince(startTime)
    return (result, processingTime)  // Tuple with generic type T
}

// Usage examples:
let (stringResult, time1) = try await measureProcessingTime {
    return "Hello World"  // T is String
}

let (intResult, time2) = try await measureProcessingTime {
    return 42  // T is Int
}
```

### Collection Type Safety

```swift
// Type-safe collections
@State private var selectedProviders: Set<TestProviderType> = []  // Only TestProviderType allowed
@State private var testResults: [ProviderTestResult] = []  // Only ProviderTestResult allowed

// Swift prevents type mismatches at compile time
selectedProviders.insert(.mlxLLM)  // ✅ Valid
selectedProviders.insert("invalid")  // ❌ Compile error
```

### Optional Types

```swift
@Published public var errorMessage: String?  // Optional - can be nil or String

// Safe optional handling
if let error = errorMessage {
    print("Error occurred: \(error)")  // Only executes if not nil
}

// Nil coalescing
let displayError = errorMessage ?? "No error"  // Provides default if nil
```

---

## Memory Management

Swift uses Automatic Reference Counting (ARC) for memory management.

### Strong vs Weak References

```swift
public class MLXLLMProvider: ObservableObject {
    private let mlxService = MLXService()  // Strong reference
    private var cancellables = Set<AnyCancellable>()  // Strong references to subscriptions
    
    public init() {
        // This creates a potential retain cycle:
        mlxService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)  // ✅ & creates weak reference to avoid cycle
    }
}
```

### Reference Cycles and Solutions

```swift
// ❌ This creates a retain cycle:
class BadExample {
    var closure: (() -> Void)?
    
    init() {
        closure = {
            self.doSomething()  // self captures BadExample strongly
        }
    }
}

// ✅ Break the cycle with [weak self]:
class GoodExample {
    var closure: (() -> Void)?
    
    init() {
        closure = { [weak self] in  // Weak capture
            self?.doSomething()  // Optional chaining - self might be nil
        }
    }
}
```

### @StateObject Lifecycle

```swift
struct ParentView: View {
    var body: some View {
        ChildView()  // Creates new ChildView each time ParentView re-renders
    }
}

struct ChildView: View {
    @StateObject private var provider = MLXLLMProvider()  // ✅ Survives re-renders
    @ObservedObject var provider2: MLXLLMProvider  // ❌ Would be recreated each time
}
```

---

## Combine Framework

Combine provides reactive programming patterns for handling asynchronous events.

### Publisher Chains

From `MLXLLMProvider.swift`:

```swift
public init() {
    // Publisher chain: source → transformation → destination
    mlxService.$isLoading                    // 1. Source: MLXService publishes loading state
        .receive(on: DispatchQueue.main)     // 2. Transform: Switch to main thread
        .assign(to: &$isLoading)             // 3. Destination: Assign to our @Published property
    
    mlxService.$loadingProgress
        .receive(on: DispatchQueue.main)     // Always switch to main thread for UI updates
        .assign(to: &$loadingProgress)
    
    mlxService.$errorMessage
        .receive(on: DispatchQueue.main)
        .assign(to: &$errorMessage)
}
```

### Publisher Lifecycle

```swift
private var cancellables = Set<AnyCancellable>()  // Store subscriptions

// Manual subscription management:
mlxService.$isLoading
    .sink { [weak self] isLoading in
        self?.handleLoadingChange(isLoading)
    }
    .store(in: &cancellables)  // Prevents subscription from being deallocated
```

**Key Combine concepts:**
- **Publishers**: Emit values over time (@Published creates one)
- **Subscribers**: Receive and handle published values  
- **Operators**: Transform data (receive, map, filter, etc.)
- **Cancellables**: Manage subscription lifecycle

---

## Cross-Platform Development

ProjectOne supports both iOS and macOS using conditional compilation.

### Platform-Specific Imports

From `UnifiedAITestView.swift`:

```swift
import SwiftUI
#if os(iOS)
import UIKit
typealias UImage = UIImage    // iOS uses UIImage
#elseif os(macOS) 
import AppKit
typealias UImage = NSImage    // macOS uses NSImage
#endif
```

### Platform-Specific UI

```swift
var body: some View {
    NavigationStack {
        // Shared UI code
        ScrollView {
            // ...
        }
        .navigationTitle("AI Provider Testing")
        #if os(iOS) || os(iPadOS)
        .navigationBarTitleDisplayMode(.inline)  // iOS-specific modifier
        #endif
    }
}
```

### Runtime Platform Detection

```swift
private func getCurrentPlatform() -> Platform {
    #if os(iOS)
    return .iOS
    #else
    return .macOS
    #endif
}
```

**Conditional compilation directives:**
- `#if os(iOS)` - iOS only
- `#if os(macOS)` - macOS only  
- `#if canImport(UIKit)` - When UIKit is available
- `#if arch(arm64)` - Apple Silicon only
- `#if targetEnvironment(simulator)` - Simulator vs device

---

## Next Steps

Now that you understand these Swift concepts through your actual codebase:

1. **Practice**: Modify the commented code to experiment with concepts
2. **Explore**: Look at other files in your project to find more patterns
3. **Build**: Try creating new features using these patterns
4. **Debug**: Use Xcode's debugger to see how async/await flows work
5. **Refactor**: Consider converting the BaseAIProvider class to protocols

## Additional Resources

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [SwiftUI Documentation](https://developer.apple.com/xcode/swiftui/)
- [Combine Framework](https://developer.apple.com/documentation/combine)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

*This guide is generated from your actual ProjectOne codebase, making all examples real and functional. You can find the complete, commented code in the files referenced throughout this guide.*