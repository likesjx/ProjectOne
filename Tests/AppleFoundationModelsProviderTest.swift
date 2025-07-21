//
//  AppleFoundationModelsProviderTest.swift
//  ProjectOneTests
//
//  Test the unified Apple Foundation Models Provider implementation
//

import XCTest
@testable import ProjectOne

@available(iOS 26.0, macOS 26.0, *)
class AppleFoundationModelsProviderTest: XCTestCase {
    
    var provider: AppleFoundationModelsProvider!
    
    override func setUpWithError() throws {
        provider = AppleFoundationModelsProvider()
    }
    
    override func tearDownWithError() throws {
        provider = nil
    }
    
    func testProviderBasicProperties() throws {
        // Test basic provider properties
        XCTAssertEqual(provider.identifier, "apple-foundation-models")
        XCTAssertEqual(provider.displayName, "Apple Foundation Models")
        XCTAssertEqual(provider.maxContextLength, 8192)
        XCTAssertEqual(provider.estimatedResponseTime, 0.2)
        XCTAssertTrue(provider.isOnDevice)
        XCTAssertTrue(provider.supportsPersonalData)
    }
    
    func testProviderInheritance() throws {
        // Test that provider correctly extends BaseAIProvider
        XCTAssertTrue(provider is BaseAIProvider)
        XCTAssertTrue(provider.conforms(to: AIModelProvider.self))
    }
    
    func testAvailabilityChecking() throws {
        // Test availability checking (will be false on simulators/devices without Foundation Models)
        // The provider should not crash when checking availability
        let isAvailable = provider.isAvailable
        
        // On most test environments, Foundation Models won't be available
        // This is expected behavior
        XCTAssertFalse(isAvailable, "Foundation Models should not be available in test environment")
    }
    
    func testModelLoadingStatus() throws {
        // Test that the provider has proper loading status tracking
        let status = provider.modelLoadingStatus
        
        // Should have some status (not necessarily ready in test environment)
        XCTAssertNotNil(status)
        
        // Should have a meaningful description
        XCTAssertFalse(status.description.isEmpty)
    }
    
    func testCapabilities() throws {
        // Test capabilities reporting
        let capabilities = provider.getCapabilities()
        
        XCTAssertNotNil(capabilities)
        XCTAssertEqual(capabilities.maxContextLength, 0) // Should be 0 when not available
        XCTAssertFalse(capabilities.supportsTextGeneration) // Should be false when not available
        XCTAssertFalse(capabilities.supportsGuidedGeneration) // Should be false when not available
        XCTAssertTrue(capabilities.supportedLanguages.isEmpty) // Should be empty when not available
    }
    
    func testGenerationFailsGracefullyWhenUnavailable() async throws {
        // Test that generation fails gracefully when Foundation Models is not available
        let memoryContext = MemoryContext(userQuery: "test")
        
        do {
            _ = try await provider.generateResponse(prompt: "Hello", context: memoryContext)
            XCTFail("Generation should fail when Foundation Models is not available")
        } catch {
            // Expected failure - should get a proper error
            XCTAssertTrue(error is AIModelProviderError)
            
            if case AIModelProviderError.providerUnavailable(let message) = error {
                XCTAssertFalse(message.isEmpty)
            } else {
                XCTFail("Should get providerUnavailable error")
            }
        }
    }
    
    func testGuidedGenerationFailsGracefullyWhenUnavailable() async throws {
        // Test that guided generation fails gracefully when Foundation Models is not available
        do {
            _ = try await provider.generateWithGuidance(prompt: "Test", type: SummarizedContent.self)
            XCTFail("Guided generation should fail when Foundation Models is not available")
        } catch {
            // Expected failure - should get a proper error
            XCTAssertTrue(error is AIModelProviderError)
        }
    }
    
    func testCleanupDoesNotCrash() async throws {
        // Test that cleanup doesn't crash
        await provider.cleanup()
        // Should complete without throwing
    }
    
    func testMultipleProviderInstances() throws {
        // Test that multiple provider instances can be created safely
        let provider2 = AppleFoundationModelsProvider()
        let provider3 = AppleFoundationModelsProvider()
        
        XCTAssertEqual(provider.identifier, provider2.identifier)
        XCTAssertEqual(provider2.identifier, provider3.identifier)
        
        // All should have the same basic properties
        XCTAssertEqual(provider.displayName, provider2.displayName)
        XCTAssertEqual(provider.maxContextLength, provider2.maxContextLength)
    }
}