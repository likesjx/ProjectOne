//
//  PromptTemplate.swift
//  ProjectOne
//
//  Created by Claude on 7/16/25.
//

import Foundation
import SwiftData

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
@Model
public final class PromptTemplate {
    public var id: UUID
    public var name: String
    public var category: PromptCategory
    public var templateDescription: String
    public var template: String
    public var requiredArguments: [String]
    public var optionalArguments: [String]
    public var isDefault: Bool
    public var isModified: Bool
    public var version: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var tags: [String]
    
    // Default template storage (not persisted)
    public var defaultTemplate: String?
    
    init(
        name: String,
        category: PromptCategory,
        description: String,
        template: String,
        requiredArguments: [String] = [],
        optionalArguments: [String] = [],
        isDefault: Bool = false,
        tags: [String] = [],
        defaultTemplate: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.templateDescription = description
        self.template = template
        self.requiredArguments = requiredArguments
        self.optionalArguments = optionalArguments
        self.isDefault = isDefault
        self.isModified = false
        self.version = 1
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tags = tags
        self.defaultTemplate = defaultTemplate
    }
    
    // MARK: - Template Management
    
    public func updateTemplate(_ newTemplate: String) {
        guard newTemplate != template else { return }
        template = newTemplate
        isModified = !isDefault || (defaultTemplate != nil && newTemplate != defaultTemplate!)
        version += 1
        updatedAt = Date()
    }
    
    public func resetToDefault() {
        guard let defaultTemplate = defaultTemplate else { return }
        template = defaultTemplate
        isModified = false
        version += 1
        updatedAt = Date()
    }
    
    public var canReset: Bool {
        return defaultTemplate != nil && isModified
    }
    
    // MARK: - Argument Validation
    
    public func validateArguments() -> PromptValidationResult {
        let foundArguments = extractArgumentsFromTemplate()
        
        // Check for missing required arguments
        let missingRequired = requiredArguments.filter { !foundArguments.contains($0) }
        
        // Check for extra arguments not in required or optional
        let allowedArguments = Set(requiredArguments + optionalArguments)
        let extraArguments = foundArguments.filter { !allowedArguments.contains($0) }
        
        // Check for undefined arguments (arguments in template but not declared)
        let undefinedArguments = foundArguments.filter { arg in
            !requiredArguments.contains(arg) && !optionalArguments.contains(arg)
        }
        
        let isValid = missingRequired.isEmpty && extraArguments.isEmpty && undefinedArguments.isEmpty
        
        return PromptValidationResult(
            isValid: isValid,
            missingRequiredArguments: missingRequired,
            extraArguments: extraArguments,
            undefinedArguments: undefinedArguments,
            foundArguments: foundArguments
        )
    }
    
    private func extractArgumentsFromTemplate() -> [String] {
        let pattern = #"\{([^}]+)\}"#
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: template, options: [], range: NSRange(location: 0, length: template.utf16.count))
        
        return matches.compactMap { match in
            if let range = Range(match.range(at: 1), in: template) {
                return String(template[range])
            }
            return nil
        }
    }
    
    // MARK: - Template Rendering
    
    public func render(with arguments: [String: Any]) -> String {
        var rendered = template
        
        for (key, value) in arguments {
            let placeholder = "{\(key)}"
            let valueString = String(describing: value)
            rendered = rendered.replacingOccurrences(of: placeholder, with: valueString)
        }
        
        return rendered
    }
    
    public func renderPreview(maxLength: Int = 200) -> String {
        let sampleArguments = createSampleArguments()
        let rendered = render(with: sampleArguments)
        
        if rendered.count > maxLength {
            return String(rendered.prefix(maxLength)) + "..."
        }
        return rendered
    }
    
    private func createSampleArguments() -> [String: Any] {
        var sampleArgs: [String: Any] = [:]
        
        for arg in requiredArguments {
            sampleArgs[arg] = "[Sample \(arg)]"
        }
        
        for arg in optionalArguments {
            sampleArgs[arg] = "[Sample \(arg)]"
        }
        
        return sampleArgs
    }
}

// MARK: - Supporting Types

public enum PromptCategory: String, Codable, CaseIterable {
    case memoryRetrieval = "memory_retrieval"
    case memoryConsolidation = "memory_consolidation"
    case entityExtraction = "entity_extraction"
    case summarization = "summarization"
    case questionAnswering = "question_answering"
    case conversation = "conversation"
    case analysis = "analysis"
    case planning = "planning"
    case creative = "creative"
    case system = "system"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .memoryRetrieval: return "Memory Retrieval"
        case .memoryConsolidation: return "Memory Consolidation"
        case .entityExtraction: return "Entity Extraction"
        case .summarization: return "Summarization"
        case .questionAnswering: return "Question Answering"
        case .conversation: return "Conversation"
        case .analysis: return "Analysis"
        case .planning: return "Planning"
        case .creative: return "Creative"
        case .system: return "System"
        case .custom: return "Custom"
        }
    }
    
    public var iconName: String {
        switch self {
        case .memoryRetrieval: return "brain.head.profile"
        case .memoryConsolidation: return "archivebox"
        case .entityExtraction: return "rectangle.3.group"
        case .summarization: return "doc.text"
        case .questionAnswering: return "questionmark.circle"
        case .conversation: return "bubble.left.and.bubble.right"
        case .analysis: return "chart.bar"
        case .planning: return "list.bullet.clipboard"
        case .creative: return "paintbrush"
        case .system: return "gear"
        case .custom: return "wrench.and.screwdriver"
        }
    }
}

public struct PromptValidationResult {
    public let isValid: Bool
    public let missingRequiredArguments: [String]
    public let extraArguments: [String]
    public let undefinedArguments: [String]
    public let foundArguments: [String]
    
    public var errors: [String] {
        var errorList: [String] = []
        
        if !missingRequiredArguments.isEmpty {
            errorList.append("Missing required arguments: \(missingRequiredArguments.joined(separator: ", "))")
        }
        
        if !extraArguments.isEmpty {
            errorList.append("Extra arguments found: \(extraArguments.joined(separator: ", "))")
        }
        
        if !undefinedArguments.isEmpty {
            errorList.append("Undefined arguments: \(undefinedArguments.joined(separator: ", "))")
        }
        
        return errorList
    }
    
    public var errorMessage: String? {
        guard !isValid else { return nil }
        
        var errors: [String] = []
        
        if !missingRequiredArguments.isEmpty {
            errors.append("Missing required arguments: \(missingRequiredArguments.joined(separator: ", "))")
        }
        
        if !extraArguments.isEmpty {
            errors.append("Extra arguments found: \(extraArguments.joined(separator: ", "))")
        }
        
        if !undefinedArguments.isEmpty {
            errors.append("Undefined arguments: \(undefinedArguments.joined(separator: ", "))")
        }
        
        return errors.joined(separator: "\n")
    }
}