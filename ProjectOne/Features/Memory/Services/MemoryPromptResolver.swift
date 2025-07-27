//
//  MemoryPromptResolver.swift
//  ProjectOne
//
//  Created by Claude on 7/26/25.
//

import Foundation
import os.log

/// Service for resolving appropriate prompt templates for memory operations
/// Handles dynamic template selection, context analysis, and fallback strategies
@MainActor
public class MemoryPromptResolver {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MemoryPromptResolver")
    private let promptManager: PromptManager
    
    // MARK: - Configuration
    
    public struct Configuration {
        let enableContextAdaptation: Bool
        let enablePerformanceTracking: Bool
        let fallbackToDefault: Bool
        let maxTemplateAge: TimeInterval // Maximum age for template usage tracking
        
        public static let `default` = Configuration(
            enableContextAdaptation: true,
            enablePerformanceTracking: true,
            fallbackToDefault: true,
            maxTemplateAge: 30 * 24 * 60 * 60 // 30 days
        )
    }
    
    private let configuration: Configuration
    
    // MARK: - Performance Tracking
    
    private struct TemplatePerformance {
        let templateId: UUID
        let operation: MemoryOperation
        var successCount: Int
        var failureCount: Int
        var lastUsed: Date
        var averageProcessingTime: TimeInterval
    }
    
    private var performanceMetrics: [String: TemplatePerformance] = [:]
    
    // MARK: - Initialization
    
    public init(
        promptManager: PromptManager,
        configuration: Configuration = .default
    ) {
        self.promptManager = promptManager
        self.configuration = configuration
        
        logger.info("MemoryPromptResolver initialized with configuration: contextAdaptation=\(configuration.enableContextAdaptation), performanceTracking=\(configuration.enablePerformanceTracking)")
    }
    
    // MARK: - Primary Resolution Methods
    
    /// Get the most appropriate prompt template for a memory operation
    public func getPromptFor(
        operation: MemoryOperation,
        context: MemoryOperationContext
    ) -> PromptTemplate? {
        logger.debug("Resolving prompt for operation: \(operation.description)")
        
        // 1. Get candidate templates for this operation
        let candidates = getCandidateTemplates(for: operation, context: context)
        
        guard !candidates.isEmpty else {
            logger.warning("No candidate templates found for operation: \(operation.rawValue)")
            return nil
        }
        
        // 2. Select best template based on context and performance
        let selectedTemplate = selectBestTemplate(
            from: candidates,
            operation: operation,
            context: context
        )
        
        if let template = selectedTemplate {
            logger.info("Selected template '\(template.name)' for operation \(operation.description)")
            
            // Track usage if performance tracking is enabled
            if configuration.enablePerformanceTracking {
                recordTemplateUsage(template, operation: operation)
            }
        } else {
            logger.error("Failed to select template for operation: \(operation.rawValue)")
        }
        
        return selectedTemplate
    }
    
    /// Get alternative prompt templates for A/B testing
    public func getAlternativePrompts(for operation: MemoryOperation) -> [PromptTemplate] {
        let candidates = getAllTemplatesForOperation(operation)
        return Array(candidates.dropFirst()) // Return all except the primary one
    }
    
    /// Get all templates that could be used for an operation
    public func getAllTemplatesForOperation(_ operation: MemoryOperation) -> [PromptTemplate] {
        // Start with the default template for the operation
        var candidates: [PromptTemplate] = []
        
        print("🔍 [MemoryPromptResolver] Looking for template: '\(operation.templateName)' for operation: \(operation.rawValue)")
        
        if let defaultTemplate = promptManager.getTemplate(named: operation.templateName) {
            print("✅ [MemoryPromptResolver] Found template: '\(operation.templateName)'")
            candidates.append(defaultTemplate)
        } else {
            print("❌ [MemoryPromptResolver] Template not found: '\(operation.templateName)'")
            print("📋 [MemoryPromptResolver] Available templates: \(promptManager.templates.map { $0.name })")
        }
        
        // Add any custom templates in the same category
        let operationCategory = getCategoryForOperation(operation)
        let categoryTemplates = promptManager.getTemplates(in: operationCategory)
            .filter { $0.name != operation.templateName } // Exclude the default we already added
            .filter { isTemplateCompatible($0, with: operation) }
        
        candidates.append(contentsOf: categoryTemplates)
        
        return candidates.sorted { $0.name < $1.name }
    }
    
    // MARK: - Context Analysis
    
    /// Analyze memory context to determine template selection criteria
    private func analyzeContext(_ context: MemoryOperationContext) -> TemplateSelectionCriteria {
        var criteria = TemplateSelectionCriteria()
        
        // Personal data detection
        if context.containsPersonalData {
            criteria.requiresPrivacyFocus = true
            criteria.preferenceWeight += 0.3
        }
        
        // Content complexity analysis
        let contentLength = context.primaryContent?.count ?? 0
        if contentLength > 1000 {
            criteria.prefersDetailedAnalysis = true
            criteria.complexityWeight += 0.2
        }
        
        // Context richness
        if context.contextualData.count > 3 {
            criteria.hasRichContext = true
            criteria.contextWeight += 0.2
        }
        
        // Urgency/importance
        if context.importance > 0.8 {
            criteria.isHighImportance = true
            criteria.importanceWeight += 0.3
        }
        
        return criteria
    }
    
    // MARK: - Template Selection Logic
    
    private func getCandidateTemplates(
        for operation: MemoryOperation,
        context: MemoryOperationContext
    ) -> [PromptTemplate] {
        
        var candidates: [PromptTemplate] = []
        
        // 1. Primary template for the operation
        print("🔍 [MemoryPromptResolver] Looking for template: '\(operation.templateName)' for operation: \(operation.rawValue)")
        
        if let primaryTemplate = promptManager.getTemplate(named: operation.templateName) {
            print("✅ [MemoryPromptResolver] Found primary template: '\(operation.templateName)'")
            candidates.append(primaryTemplate)
        } else {
            print("❌ [MemoryPromptResolver] Primary template not found: '\(operation.templateName)'")
            print("📋 [MemoryPromptResolver] Available templates: \(promptManager.templates.map { $0.name })")
        }
        
        // 2. Context-adapted alternatives if enabled
        if configuration.enableContextAdaptation {
            let contextualCandidates = getContextualAlternatives(for: operation, context: context)
            candidates.append(contentsOf: contextualCandidates)
        }
        
        // 3. Performance-based alternatives if tracking is enabled
        if configuration.enablePerformanceTracking {
            let performanceCandidates = getPerformanceBasedAlternatives(for: operation)
            candidates.append(contentsOf: performanceCandidates)
        }
        
        return Array(Set(candidates)) // Remove duplicates
    }
    
    private func selectBestTemplate(
        from candidates: [PromptTemplate],
        operation: MemoryOperation,
        context: MemoryOperationContext
    ) -> PromptTemplate? {
        
        print("🎯 [MemoryPromptResolver] Selecting best template from \(candidates.count) candidates:")
        for candidate in candidates {
            print("   - \(candidate.name)")
        }
        
        guard !candidates.isEmpty else { return nil }
        
        // If only one candidate, return it
        if candidates.count == 1 {
            print("📌 [MemoryPromptResolver] Only one candidate, selecting: \(candidates.first?.name ?? "nil")")
            return candidates.first
        }
        
        // Analyze context for selection criteria
        let criteria = analyzeContext(context)
        
        // Score each template
        let scoredTemplates = candidates.map { template in
            (template: template, score: scoreTemplate(template, criteria: criteria, operation: operation))
        }
        
        // Sort by score (highest first) and return the best
        let bestTemplate = scoredTemplates
            .sorted { $0.score > $1.score }
            .first?.template
        
        return bestTemplate
    }
    
    private func scoreTemplate(
        _ template: PromptTemplate,
        criteria: TemplateSelectionCriteria,
        operation: MemoryOperation
    ) -> Double {
        var score = 0.0
        
        // Base score for being the default template
        if template.name == operation.templateName {
            score += 0.5
        }
        
        // Performance-based scoring
        if configuration.enablePerformanceTracking,
           let performance = performanceMetrics[templateKey(template, operation: operation)] {
            let successRate = Double(performance.successCount) / Double(performance.successCount + performance.failureCount)
            score += successRate * 0.3
            
            // Recency bonus
            let daysSinceLastUse = Date().timeIntervalSince(performance.lastUsed) / (24 * 60 * 60)
            if daysSinceLastUse < 7 {
                score += 0.1
            }
        }
        
        // Template quality indicators
        if template.isDefault {
            score += 0.2
        }
        
        if !template.isModified {
            score += 0.1 // Prefer unmodified templates for stability
        }
        
        // Validation score
        let validation = template.validateArguments()
        if validation.isValid {
            score += 0.2
        }
        
        // Context-specific scoring
        if criteria.requiresPrivacyFocus && template.tags.contains("privacy") {
            score += 0.3
        }
        
        if criteria.prefersDetailedAnalysis && template.template.count > 500 {
            score += 0.2
        }
        
        return score
    }
    
    // MARK: - Helper Methods
    
    private func getContextualAlternatives(
        for operation: MemoryOperation,
        context: MemoryOperationContext
    ) -> [PromptTemplate] {
        
        var alternatives: [PromptTemplate] = []
        
        // Get templates from the same category
        let category = getCategoryForOperation(operation)
        let categoryTemplates = promptManager.getTemplates(in: category)
        
        for template in categoryTemplates {
            if template.name != operation.templateName && isTemplateCompatible(template, with: operation) {
                alternatives.append(template)
            }
        }
        
        return alternatives
    }
    
    private func getPerformanceBasedAlternatives(for operation: MemoryOperation) -> [PromptTemplate] {
        // Return templates that have performed well for this operation
        let performingTemplates = performanceMetrics.compactMap { (key, performance) -> PromptTemplate? in
            guard performance.operation == operation else { return nil }
            
            let successRate = Double(performance.successCount) / Double(performance.successCount + performance.failureCount)
            if successRate > 0.8 { // High success rate
                return promptManager.getTemplate(id: performance.templateId)
            }
            return nil
        }
        
        return performingTemplates
    }
    
    private func getCategoryForOperation(_ operation: MemoryOperation) -> PromptCategory {
        switch operation.category {
        case "consolidation":
            return .memoryConsolidation
        case "extraction":
            return .entityExtraction
        case "retrieval":
            return .memoryRetrieval
        default:
            return .analysis
        }
    }
    
    private func isTemplateCompatible(_ template: PromptTemplate, with operation: MemoryOperation) -> Bool {
        // Check if template has compatible arguments for the operation
        let requiredArgs = getRequiredArgumentsForOperation(operation)
        return requiredArgs.allSatisfy { arg in
            template.requiredArguments.contains(arg) || template.optionalArguments.contains(arg)
        }
    }
    
    private func getRequiredArgumentsForOperation(_ operation: MemoryOperation) -> [String] {
        switch operation {
        case .noteCategorizationSTMvsLTM:
            return ["content"]
        case .stmConsolidationDecision:
            return ["content", "memory_type", "importance", "access_count"]
        case .entityRelationshipExtraction:
            return ["text"]
        case .memoryRetrieval:
            return ["user_query"]
        case .memoryAnalysis:
            return ["memory_data", "analysis_type"]
        }
    }
    
    // MARK: - Performance Tracking
    
    private func recordTemplateUsage(_ template: PromptTemplate, operation: MemoryOperation) {
        let key = templateKey(template, operation: operation)
        
        if var performance = performanceMetrics[key] {
            performance.lastUsed = Date()
            performanceMetrics[key] = performance
        } else {
            performanceMetrics[key] = TemplatePerformance(
                templateId: template.id,
                operation: operation,
                successCount: 0,
                failureCount: 0,
                lastUsed: Date(),
                averageProcessingTime: 0.0
            )
        }
    }
    
    public func recordTemplateSuccess(
        _ template: PromptTemplate,
        operation: MemoryOperation,
        processingTime: TimeInterval
    ) {
        guard configuration.enablePerformanceTracking else { return }
        
        let key = templateKey(template, operation: operation)
        
        if var performance = performanceMetrics[key] {
            performance.successCount += 1
            performance.lastUsed = Date()
            
            // Update average processing time
            let totalTime = performance.averageProcessingTime * Double(performance.successCount - 1) + processingTime
            performance.averageProcessingTime = totalTime / Double(performance.successCount)
            
            performanceMetrics[key] = performance
        }
        
        logger.debug("Recorded success for template '\(template.name)' on operation \(operation.description)")
    }
    
    public func recordTemplateFailure(_ template: PromptTemplate, operation: MemoryOperation, error: Error) {
        guard configuration.enablePerformanceTracking else { return }
        
        let key = templateKey(template, operation: operation)
        
        if var performance = performanceMetrics[key] {
            performance.failureCount += 1
            performance.lastUsed = Date()
            performanceMetrics[key] = performance
        }
        
        logger.warning("Recorded failure for template '\(template.name)' on operation \(operation.description): \(error.localizedDescription)")
    }
    
    private func templateKey(_ template: PromptTemplate, operation: MemoryOperation) -> String {
        return "\(template.id.uuidString)_\(operation.rawValue)"
    }
}

// MARK: - Supporting Types

/// Context information for memory operations to guide template selection
public struct MemoryOperationContext {
    let primaryContent: String?
    let contextualData: [String: Any]
    let containsPersonalData: Bool
    let importance: Double
    let sourceType: String?
    let userPatterns: [String]?
    
    public init(
        primaryContent: String? = nil,
        contextualData: [String: Any] = [:],
        containsPersonalData: Bool = false,
        importance: Double = 0.5,
        sourceType: String? = nil,
        userPatterns: [String]? = nil
    ) {
        self.primaryContent = primaryContent
        self.contextualData = contextualData
        self.containsPersonalData = containsPersonalData
        self.importance = importance
        self.sourceType = sourceType
        self.userPatterns = userPatterns
    }
}

/// Criteria for template selection based on context analysis
private struct TemplateSelectionCriteria {
    var requiresPrivacyFocus: Bool = false
    var prefersDetailedAnalysis: Bool = false
    var hasRichContext: Bool = false
    var isHighImportance: Bool = false
    
    // Weights for scoring
    var preferenceWeight: Double = 0.0
    var complexityWeight: Double = 0.0
    var contextWeight: Double = 0.0
    var importanceWeight: Double = 0.0
}