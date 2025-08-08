//
//  ServiceFactory.swift
//  ProjectOne
//
//  Service factory for dependency injection - implements the dependency injection pattern
//  recommended in the GPT-5 feedback to reduce tight coupling
//

import Foundation
import SwiftData
import os.log

/// Service factory for dependency injection - reduces tight coupling in UnifiedSystemManager
@MainActor
public protocol ServiceFactory {
    func createMLXService() -> MLXService
    func createMemoryService(context: ModelContext) -> RealTimeMemoryService
    func createCognitiveEngine(context: ModelContext) -> CognitiveDecisionEngine
    func createKnowledgeGraphService(context: ModelContext) -> KnowledgeGraphService
    func createURLHandler() -> URLHandler
}

/// Default implementation of ServiceFactory
@MainActor
public class DefaultServiceFactory: ServiceFactory {
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "ServiceFactory")
    
    public init() {
        logger.info("DefaultServiceFactory initialized")
    }
    
    public func createMLXService() -> MLXService {
        logger.info("Creating MLXService")
        return MLXService()
    }
    
    public func createMemoryService(context: ModelContext) -> RealTimeMemoryService {
        logger.info("Creating RealTimeMemoryService")
        return RealTimeMemoryService(modelContext: context)
    }
    
    public func createCognitiveEngine(context: ModelContext) -> CognitiveDecisionEngine {
        logger.info("Creating CognitiveDecisionEngine")
        return CognitiveDecisionEngine(modelContext: context)
    }
    
    public func createKnowledgeGraphService(context: ModelContext) -> KnowledgeGraphService {
        logger.info("Creating KnowledgeGraphService")
        return KnowledgeGraphService(modelContext: context)
    }
    
    public func createURLHandler() -> URLHandler {
        logger.info("Creating URLHandler")
        return URLHandler()
    }
}

/// Mock service factory for testing
@MainActor
public class MockServiceFactory: ServiceFactory {
    public var mockMLXService: MLXService?
    public var mockMemoryService: RealTimeMemoryService?
    public var mockCognitiveEngine: CognitiveDecisionEngine?
    public var mockKnowledgeGraphService: KnowledgeGraphService?
    public var mockURLHandler: URLHandler?
    
    public init() {}
    
    public func createMLXService() -> MLXService {
        return mockMLXService ?? MLXService()
    }
    
    public func createMemoryService(context: ModelContext) -> RealTimeMemoryService {
        return mockMemoryService ?? RealTimeMemoryService(modelContext: context)
    }
    
    public func createCognitiveEngine(context: ModelContext) -> CognitiveDecisionEngine {
        return mockCognitiveEngine ?? CognitiveDecisionEngine(modelContext: context)
    }
    
    public func createKnowledgeGraphService(context: ModelContext) -> KnowledgeGraphService {
        return mockKnowledgeGraphService ?? KnowledgeGraphService(modelContext: context)
    }
    
    public func createURLHandler() -> URLHandler {
        return mockURLHandler ?? URLHandler()
    }
}
