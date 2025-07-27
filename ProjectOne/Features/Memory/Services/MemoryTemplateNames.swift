//
//  MemoryTemplateNames.swift
//  ProjectOne
//
//  Created by Claude on 7/26/25.
//

import Foundation

/// Template name constants for memory system operations
/// These constants ensure type safety and prevent typos when referencing prompt templates
public struct MemoryTemplateNames {
    
    // MARK: - Memory Decision Templates
    
    /// Template for determining if a note should be stored as STM or LTM
    public static let noteCategorizationSTMLTM = "note-categorization-stm-ltm"
    
    /// Template for deciding whether to promote STM to LTM or expire it
    public static let stmConsolidationDecision = "stm-consolidation-decision"
    
    /// Template for extracting entities and relationships from text
    public static let entityRelationshipExtraction = "entity-relationship-extraction"
    
    // MARK: - Existing Memory Templates
    
    /// General memory consolidation template
    public static let memoryConsolidation = "memory-consolidation"
    
    /// Entity extraction template
    public static let entityExtraction = "entity-extraction"
    
    /// Memory synthesis template for query responses
    public static let memorySynthesis = "memory-synthesis"
    
    /// Fact-based information retrieval template
    public static let factBasedInformation = "fact-based-information"
    
    /// Memory analysis template
    public static let memoryAnalysis = "memory-analysis"
    
    // MARK: - Validation
    
    /// All memory-related template names for validation
    public static let allMemoryTemplates: [String] = [
        noteCategorizationSTMLTM,
        stmConsolidationDecision,
        entityRelationshipExtraction,
        memoryConsolidation,
        entityExtraction,
        memorySynthesis,
        factBasedInformation,
        memoryAnalysis
    ]
    
    /// Check if a template name is memory-related
    public static func isMemoryTemplate(_ name: String) -> Bool {
        return allMemoryTemplates.contains(name)
    }
}

/// Memory operation types that correspond to specific templates
public enum MemoryOperation: String, CaseIterable {
    case noteCategorizationSTMvsLTM = "note_categorization_stm_ltm"
    case stmConsolidationDecision = "stm_consolidation_decision"
    case entityRelationshipExtraction = "entity_relationship_extraction"
    case memoryRetrieval = "memory_retrieval"
    case memoryAnalysis = "memory_analysis"
    
    /// Get the corresponding template name for this operation
    public var templateName: String {
        switch self {
        case .noteCategorizationSTMvsLTM:
            return MemoryTemplateNames.noteCategorizationSTMLTM
        case .stmConsolidationDecision:
            return MemoryTemplateNames.stmConsolidationDecision
        case .entityRelationshipExtraction:
            return MemoryTemplateNames.entityRelationshipExtraction
        case .memoryRetrieval:
            return MemoryTemplateNames.memorySynthesis
        case .memoryAnalysis:
            return MemoryTemplateNames.memoryAnalysis
        }
    }
    
    /// Human-readable description of the operation
    public var description: String {
        switch self {
        case .noteCategorizationSTMvsLTM:
            return "Note Categorization (STM vs LTM)"
        case .stmConsolidationDecision:
            return "STM Consolidation Decision"
        case .entityRelationshipExtraction:
            return "Entity & Relationship Extraction"
        case .memoryRetrieval:
            return "Memory Retrieval & Synthesis"
        case .memoryAnalysis:
            return "Memory Analysis"
        }
    }
    
    /// Category of the operation for grouping
    public var category: String {
        switch self {
        case .noteCategorizationSTMvsLTM, .stmConsolidationDecision:
            return "consolidation"
        case .entityRelationshipExtraction:
            return "extraction"
        case .memoryRetrieval, .memoryAnalysis:
            return "retrieval"
        }
    }
}