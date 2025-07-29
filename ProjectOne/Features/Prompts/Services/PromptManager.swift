//
//  PromptManager.swift
//  ProjectOne
//
//  Created by Claude on 7/16/25.
//

import Foundation
import SwiftData
import Combine
import os.log

@MainActor
public class PromptManager: ObservableObject {
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "PromptManager")
    private let modelContext: ModelContext
    
    @Published public var templates: [PromptTemplate] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    // MARK: - Initialization
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        print("🔧 [PromptManager] Initializing PromptManager...")
        
        Task {
            await loadTemplates()
        }
    }
    
    // MARK: - Template Management
    
    public func loadTemplates() async {
        print("🔧 [PromptManager] Loading templates...")
        isLoading = true
        errorMessage = nil
        
        do {
            let descriptor = FetchDescriptor<PromptTemplate>(sortBy: [SortDescriptor(\.name)])
            let storedTemplates = try modelContext.fetch(descriptor)
            print("🔧 [PromptManager] Found \(storedTemplates.count) stored templates")
            
            if storedTemplates.isEmpty {
                print("🔧 [PromptManager] No templates found, creating defaults...")
                // First time setup - create default templates
                await createDefaultTemplates()
            } else {
                templates = storedTemplates
                print("🔧 [PromptManager] Loaded \(templates.count) templates")
                
                // Check if we need to add missing memory templates
                let hasMemoryTemplates = templates.contains { $0.name == "note-categorization-stm-ltm" }
                if !hasMemoryTemplates {
                    print("🔧 [PromptManager] Missing memory templates, adding them...")
                    await addMissingMemoryTemplates()
                }
            }
            
        } catch {
            print("❌ [PromptManager] Failed to load templates: \(error)")
            logger.error("Failed to load templates: \(error)")
            errorMessage = "Failed to load templates: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    public func createTemplate(
        name: String,
        category: PromptCategory,
        description: String,
        template: String,
        requiredArguments: [String] = [],
        optionalArguments: [String] = [],
        tags: [String] = []
    ) async throws -> PromptTemplate {
        
        let newTemplate = PromptTemplate(
            name: name,
            category: category,
            description: description,
            template: template,
            requiredArguments: requiredArguments,
            optionalArguments: optionalArguments,
            isDefault: false,
            tags: tags
        )
        
        modelContext.insert(newTemplate)
        try modelContext.save()
        
        await loadTemplates()
        
        logger.info("Created new template: \(name)")
        return newTemplate
    }
    
    public func updateTemplate(_ template: PromptTemplate, newContent: String) async throws {
        template.updateTemplate(newContent)
        try modelContext.save()
        
        await loadTemplates()
        
        logger.info("Updated template: \(template.name)")
    }
    
    public func updateTemplate(
        _ template: PromptTemplate,
        name: String,
        category: PromptCategory,
        description: String,
        template templateContent: String,
        requiredArguments: [String],
        optionalArguments: [String],
        tags: [String]
    ) async throws -> PromptTemplate {
        // Update all template properties
        template.name = name
        template.category = category
        template.templateDescription = description
        template.template = templateContent
        template.requiredArguments = requiredArguments
        template.optionalArguments = optionalArguments
        template.tags = tags
        template.updatedAt = Date()
        
        // Validate the updated template
        let validation = template.validateArguments()
        if !validation.isValid {
            throw PromptManagerError.invalidTemplate(validation.errors.first ?? "Template validation failed")
        }
        
        try modelContext.save()
        await loadTemplates()
        
        logger.info("Updated template: \(name)")
        return template
    }
    
    public func deleteTemplate(_ template: PromptTemplate) async throws {
        guard !template.isDefault else {
            throw PromptManagerError.cannotDeleteDefaultTemplate
        }
        
        modelContext.delete(template)
        try modelContext.save()
        
        await loadTemplates()
        
        logger.info("Deleted template: \(template.name)")
    }
    
    public func resetTemplateToDefault(_ template: PromptTemplate) async throws {
        guard template.canReset else {
            throw PromptManagerError.cannotResetTemplate
        }
        
        template.resetToDefault()
        try modelContext.save()
        
        await loadTemplates()
        
        logger.info("Reset template to default: \(template.name)")
    }
    
    public func duplicateTemplate(_ template: PromptTemplate, newName: String) async throws -> PromptTemplate {
        let duplicate = PromptTemplate(
            name: newName,
            category: template.category,
            description: "\(template.templateDescription) (Copy)",
            template: template.template,
            requiredArguments: template.requiredArguments,
            optionalArguments: template.optionalArguments,
            isDefault: false,
            tags: template.tags
        )
        
        modelContext.insert(duplicate)
        try modelContext.save()
        
        await loadTemplates()
        
        logger.info("Duplicated template: \(template.name) -> \(newName)")
        return duplicate
    }
    
    // MARK: - Template Retrieval
    
    public func getTemplate(named name: String) -> PromptTemplate? {
        return templates.first { $0.name == name }
    }
    
    public func getTemplate(id: UUID) -> PromptTemplate? {
        return templates.first { $0.id == id }
    }
    
    public func getTemplates(in category: PromptCategory) -> [PromptTemplate] {
        return templates.filter { $0.category == category }
    }
    
    public func searchTemplates(query: String) -> [PromptTemplate] {
        let lowercaseQuery = query.lowercased()
        return templates.filter { template in
            template.name.lowercased().contains(lowercaseQuery) ||
            template.templateDescription.lowercased().contains(lowercaseQuery) ||
            template.template.lowercased().contains(lowercaseQuery) ||
            template.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    // MARK: - Template Rendering
    
    public func renderTemplate(named name: String, with arguments: [String: Any]) -> String? {
        guard let template = getTemplate(named: name) else {
            logger.warning("Template not found: \(name)")
            return nil
        }
        
        let validation = template.validateArguments()
        if !validation.isValid {
            logger.warning("Template validation failed for '\(name)': \(validation.errorMessage ?? "Unknown error")")
        }
        
        return template.render(with: arguments)
    }
    
    public func renderTemplate(_ template: PromptTemplate, with arguments: [String: Any]) -> String {
        return template.render(with: arguments)
    }
    
    // MARK: - Validation
    
    public func validateTemplate(_ template: PromptTemplate) -> PromptValidationResult {
        return template.validateArguments()
    }
    
    public func validateAllTemplates() -> [UUID: PromptValidationResult] {
        var results: [UUID: PromptValidationResult] = [:]
        
        for template in templates {
            results[template.id] = template.validateArguments()
        }
        
        return results
    }
    
    // MARK: - Missing Template Management
    
    private func addMissingMemoryTemplates() async {
        let memoryTemplates = [
            PromptTemplate(
                name: "note-categorization-stm-ltm",
                category: .memoryConsolidation,
                description: "Analyze note content to determine STM vs LTM classification",
                template: """
                Analyze this note and determine its importance and longevity. 
                Consider: personal relevance, factual content, actionability, temporal relevance, and long-term value.
                
                ## Note Content:
                {content}
                
                ## Context (optional):
                {context}
                
                ## User Patterns (optional):
                {user_patterns}
                
                ## Metadata:
                {metadata}
                
                Evaluate the content based on:
                1. **Personal Relevance**: Is this personally meaningful to the user?
                2. **Factual Content**: Does this contain important facts or knowledge?
                3. **Actionability**: Does this require future action or reference?
                4. **Temporal Relevance**: Is this time-sensitive or enduring?
                5. **Uniqueness**: Is this unique information or easily recreated?
                
                Respond with either:
                - "LONG_TERM: <brief reasoning>" if this should be preserved as important information
                - "SHORT_TERM: <brief reasoning>" if this is temporary or less important
                """,
                requiredArguments: ["content"],
                optionalArguments: ["context", "user_patterns", "metadata"],
                isDefault: true,
                tags: ["memory", "categorization", "stm", "ltm"]
            ),
            
            PromptTemplate(
                name: "stm-consolidation-decision",
                category: .memoryConsolidation,
                description: "Decide whether STM entries should be promoted or expired",
                template: """
                Analyze these short-term memory entries and decide their fate based on relevance, patterns, and retention policy.
                
                ## STM Entries:
                {stm_entries}
                
                ## User Context:
                {user_context}
                
                ## Recent Activity:
                {recent_activity}
                
                ## Retention Policy:
                {retention_policy}
                
                For each entry, decide:
                1. **PROMOTE to LTM**: If valuable for long-term retention
                2. **EXPIRE**: If no longer relevant or valuable
                
                Consider:
                - Cross-references with other memories
                - User behavioral patterns
                - Information decay vs. value
                - Storage optimization
                
                Respond with JSON format:
                {
                  "decisions": [
                    {"entry_id": "uuid", "action": "PROMOTE|EXPIRE", "reasoning": "brief explanation"}
                  ]
                }
                """,
                requiredArguments: ["stm_entries"],
                optionalArguments: ["user_context", "recent_activity", "retention_policy"],
                isDefault: true,
                tags: ["memory", "consolidation", "stm", "promotion"]
            ),
            
            PromptTemplate(
                name: "entity-relationship-extraction",
                category: .entityExtraction,
                description: "Extract entities and relationships for memory graph building",
                template: """
                Extract entities and relationships from this content to build the user's knowledge graph.
                
                ## Content:
                {content}
                
                ## Existing Entities (for reference):
                {existing_entities}
                
                ## Context:
                {context}
                
                Extract:
                1. **Entities**: People, places, concepts, objects, events
                2. **Relationships**: How entities connect to each other
                3. **Attributes**: Important properties of entities
                
                Return JSON format:
                {
                  "entities": [
                    {"name": "EntityName", "type": "person|place|concept|event|object", "attributes": {"key": "value"}}
                  ],
                  "relationships": [
                    {"from": "Entity1", "to": "Entity2", "type": "relationship_type", "strength": 0.1-1.0}
                  ]
                }
                
                Focus on meaningful, persistent entities that enhance the user's knowledge graph.
                """,
                requiredArguments: ["content"],
                optionalArguments: ["existing_entities", "context"],
                isDefault: true,
                tags: ["entities", "relationships", "knowledge-graph", "extraction"]
            )
        ]
        
        for template in memoryTemplates {
            // Check if template already exists
            let exists = templates.contains { $0.name == template.name }
            if !exists {
                modelContext.insert(template)
                print("🆕 [PromptManager] Added missing template: \(template.name)")
            }
        }
        
        do {
            try modelContext.save()
            await loadTemplates() // Reload to pick up new templates
            print("✅ [PromptManager] Memory templates added successfully")
        } catch {
            print("❌ [PromptManager] Failed to save memory templates: \(error)")
            logger.error("Failed to save memory templates: \(error)")
        }
    }
    
    // MARK: - Default Templates
    
    private func createDefaultTemplates() async {
        logger.info("Creating default templates...")
        
        let defaultTemplates = [
            // Memory Retrieval Templates
            PromptTemplate(
                name: "memory-synthesis",
                category: .memoryRetrieval,
                description: "Synthesize relevant memories for user queries",
                template: """
                You are a helpful AI assistant with access to the user's personal memory system. Based on the following memories and context, provide a comprehensive and helpful response.

                ## Long-term Memories:
                {long_term_memories}

                ## Short-term Memories:
                {short_term_memories}

                ## Episodic Memories:
                {episodic_memories}

                ## Entities:
                {entities}

                ## Relevant Notes:
                {relevant_notes}

                ## User Query:
                {user_query}

                Please provide a helpful response using the available context. If the memories don't contain enough information to fully answer the query, acknowledge what you can answer and what information might be missing.
                """,
                requiredArguments: ["user_query"],
                optionalArguments: ["long_term_memories", "short_term_memories", "episodic_memories", "entities", "relevant_notes"],
                isDefault: true,
                tags: ["memory", "synthesis", "query"]
            ),
            
            PromptTemplate(
                name: "fact-based-information",
                category: .memoryRetrieval,
                description: "Retrieve specific factual information from memory",
                template: """
                Based on the user's stored memories, provide factual information to answer their query.

                ## Long-term Memories:
                {long_term_memories}

                ## Short-term Memories:
                {short_term_memories}

                ## Relevant Notes:
                {relevant_notes}

                ## User Query:
                {user_query}

                Focus on providing accurate, factual information from the stored memories. If the information is not available in the memories, clearly state that.
                """,
                requiredArguments: ["user_query"],
                optionalArguments: ["long_term_memories", "short_term_memories", "relevant_notes"],
                isDefault: true,
                tags: ["facts", "information", "retrieval"]
            ),
            
            // Memory Consolidation Templates
            PromptTemplate(
                name: "memory-consolidation",
                category: .memoryConsolidation,
                description: "Analyze short-term memory for consolidation to long-term memory",
                template: """
                Analyze this short-term memory and determine if it should be preserved as a long-term memory or can be expired.
                Consider: importance, uniqueness, personal relevance, factual content.

                ## Memory Content:
                {content}

                ## Memory Type:
                {memory_type}

                ## Importance Score:
                {importance}

                ## Access Count:
                {access_count}

                ## Context:
                {context}

                Respond with either "PROMOTE_TO_LTM: <summary>" or "EXPIRE".
                If promoting, provide a concise summary of why this memory should be preserved.
                """,
                requiredArguments: ["content", "memory_type", "importance", "access_count"],
                optionalArguments: ["context"],
                isDefault: true,
                tags: ["consolidation", "memory", "analysis"]
            ),
            
            // Entity Extraction Templates
            PromptTemplate(
                name: "entity-extraction",
                category: .entityExtraction,
                description: "Extract entities and relationships from text",
                template: """
                Extract entities and relationships from this text. Return a JSON response with:
                {
                    "entities": [{"name": "EntityName", "type": "person|place|organization|concept|other", "description": "brief description"}],
                    "relationships": [{"entity1": "Name1", "entity2": "Name2", "type": "relationship_type", "description": "description"}]
                }

                ## Text to analyze:
                {text}

                ## Context (optional):
                {context}

                Focus on extracting meaningful entities and their relationships. Be precise and avoid duplicates.
                """,
                requiredArguments: ["text"],
                optionalArguments: ["context"],
                isDefault: true,
                tags: ["entities", "extraction", "relationships"]
            ),
            
            // Conversation Templates
            PromptTemplate(
                name: "casual-conversation",
                category: .conversation,
                description: "Engage in casual conversation with memory context",
                template: """
                You are having a casual conversation with the user. Use their personal context to make the conversation more engaging and relevant.

                ## Personal Context:
                {personal_context}

                ## Recent Memories:
                {recent_memories}

                ## User Message:
                {user_message}

                Respond in a friendly, conversational tone. Reference relevant memories when appropriate to show you remember previous conversations.
                """,
                requiredArguments: ["user_message"],
                optionalArguments: ["personal_context", "recent_memories"],
                isDefault: true,
                tags: ["conversation", "casual", "friendly"]
            ),
            
            // Analysis Templates
            PromptTemplate(
                name: "memory-analysis",
                category: .analysis,
                description: "Analyze memory patterns and provide insights",
                template: """
                Analyze the user's memory patterns and provide insights about their interests, habits, and important information.

                ## Memory Data:
                {memory_data}

                ## Time Range:
                {time_range}

                ## Analysis Type:
                {analysis_type}

                Provide thoughtful analysis while respecting privacy. Focus on helpful insights that could benefit the user.
                """,
                requiredArguments: ["memory_data", "analysis_type"],
                optionalArguments: ["time_range"],
                isDefault: true,
                tags: ["analysis", "patterns", "insights"]
            ),
            
            // System Templates
            PromptTemplate(
                name: "system-status",
                category: .system,
                description: "Provide system status and diagnostics",
                template: """
                Provide a system status report based on the following information:

                ## System Metrics:
                {system_metrics}

                ## Memory Statistics:
                {memory_statistics}

                ## Performance Data:
                {performance_data}

                ## Issues (if any):
                {issues}

                Generate a clear, informative status report that highlights important information and any concerns.
                """,
                requiredArguments: ["system_metrics"],
                optionalArguments: ["memory_statistics", "performance_data", "issues"],
                isDefault: true,
                tags: ["system", "status", "diagnostics"]
            ),
            
            // Memory System Decision Templates
            PromptTemplate(
                name: "note-categorization-stm-ltm",
                category: .memoryConsolidation,
                description: "Analyze note content to determine STM vs LTM classification",
                template: """
                Analyze this note and determine its importance and longevity. 
                Consider: personal relevance, factual content, actionability, temporal relevance, and long-term value.
                
                ## Note Content:
                {content}
                
                ## Context (optional):
                {context}
                
                ## User Patterns (optional):
                {user_patterns}
                
                ## Metadata:
                {metadata}
                
                Evaluate the content based on:
                1. **Personal Relevance**: Is this personally meaningful to the user?
                2. **Factual Content**: Does this contain important facts or knowledge?
                3. **Actionability**: Does this require future action or reference?
                4. **Temporal Relevance**: Is this time-sensitive or enduring?
                5. **Uniqueness**: Is this unique information or easily recreated?
                
                Respond with either:
                - "LONG_TERM: <brief reasoning>" if this should be preserved as important information
                - "SHORT_TERM: <brief reasoning>" if this is temporary or less important
                """,
                requiredArguments: ["content"],
                optionalArguments: ["context", "user_patterns", "metadata"],
                isDefault: true,
                tags: ["memory", "categorization", "decision", "stm", "ltm"]
            ),
            
            PromptTemplate(
                name: "stm-consolidation-decision",
                category: .memoryConsolidation,
                description: "Analyze short-term memory for consolidation to long-term memory",
                template: """
                Analyze this short-term memory and determine if it should be preserved as a long-term memory or can be expired.
                Consider: importance, uniqueness, personal relevance, factual content, and access patterns.

                ## Memory Content:
                {content}

                ## Memory Type:
                {memory_type}

                ## Importance Score:
                {importance}

                ## Access Count:
                {access_count}

                ## Time Since Creation:
                {age_hours} hours

                ## Context Tags:
                {context_tags}

                ## Related Entities:
                {related_entities}

                ## Emotional Weight:
                {emotional_weight}

                Evaluation Criteria:
                1. **Importance**: High importance scores (>0.7) suggest long-term value
                2. **Access Patterns**: Frequently accessed memories (>3 times) show ongoing relevance
                3. **Uniqueness**: Unique information that would be hard to recreate
                4. **Personal Relevance**: Memories tied to personal entities or experiences
                5. **Factual Content**: Objective facts and knowledge worth preserving
                6. **Emotional Significance**: Emotionally weighted memories often have lasting value

                Respond with either:
                - "PROMOTE_TO_LTM: <concise summary of why this memory should be preserved>"
                - "EXPIRE: <brief explanation of why this can be forgotten>"
                """,
                requiredArguments: ["content", "memory_type", "importance", "access_count"],
                optionalArguments: ["age_hours", "context_tags", "related_entities", "emotional_weight"],
                isDefault: true,
                tags: ["consolidation", "memory", "analysis", "promotion", "stm", "ltm"]
            ),
            
            PromptTemplate(
                name: "entity-relationship-extraction",
                category: .entityExtraction,
                description: "Extract entities and relationships from text with structured JSON output",
                template: """
                Extract entities and relationships from the provided text. Focus on meaningful entities that represent people, places, organizations, concepts, or other significant items mentioned.

                ## Text to Analyze:
                {text}

                ## Context (optional):
                {context}

                ## Source Type:
                {source_type}

                Guidelines:
                1. **Entities**: Extract meaningful nouns and noun phrases
                2. **Types**: Classify as person, place, organization, concept, event, or other
                3. **Relationships**: Identify how entities relate to each other
                4. **Precision**: Be accurate and avoid duplicates
                5. **Relevance**: Focus on entities that add meaningful context

                Return a valid JSON response in exactly this format:
                {
                    "entities": [
                        {
                            "name": "EntityName",
                            "type": "person|place|organization|concept|event|other",
                            "description": "Brief description of the entity",
                            "confidence": 0.9
                        }
                    ],
                    "relationships": [
                        {
                            "entity1": "EntityName1",
                            "entity2": "EntityName2",
                            "type": "relationship_type",
                            "description": "Description of the relationship",
                            "confidence": 0.8
                        }
                    ]
                }

                Entity Types:
                - **person**: Individual people, characters, authors
                - **place**: Locations, cities, countries, buildings
                - **organization**: Companies, institutions, groups
                - **concept**: Ideas, theories, methodologies, topics
                - **event**: Meetings, conferences, incidents, dates
                - **other**: Any other significant entities

                Common Relationship Types:
                - works_for, located_in, part_of, created_by, mentions, relates_to, depends_on, influences
                """,
                requiredArguments: ["text"],
                optionalArguments: ["context", "source_type"],
                isDefault: true,
                tags: ["entities", "extraction", "relationships", "json", "nlp"]
            )
        ]
        
        // Insert all default templates
        for template in defaultTemplates {
            // Set the defaultTemplate property for reset functionality
            template.defaultTemplate = template.template
            modelContext.insert(template)
        }
        
        do {
            try modelContext.save()
            await loadTemplates()
            logger.info("Created \(defaultTemplates.count) default templates")
        } catch {
            logger.error("Failed to save default templates: \(error)")
            errorMessage = "Failed to create default templates: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Reset All Templates
    
    public func resetAllTemplatesToDefaults() async throws {
        logger.info("Resetting all templates to defaults...")
        
        // Delete all existing templates
        let descriptor = FetchDescriptor<PromptTemplate>()
        let existingTemplates = try modelContext.fetch(descriptor)
        
        for template in existingTemplates {
            modelContext.delete(template)
        }
        
        try modelContext.save()
        
        // Recreate default templates
        await createDefaultTemplates()
        
        logger.info("Reset all templates to defaults")
    }
}

// MARK: - Error Types

public enum PromptManagerError: Error, LocalizedError {
    case templateNotFound(String)
    case cannotDeleteDefaultTemplate
    case cannotResetTemplate
    case validationFailed(String)
    case templateAlreadyExists(String)
    case invalidTemplate(String)
    
    public var errorDescription: String? {
        switch self {
        case .templateNotFound(let name):
            return "Template not found: \(name)"
        case .cannotDeleteDefaultTemplate:
            return "Cannot delete default template"
        case .cannotResetTemplate:
            return "Cannot reset template - no default available"
        case .validationFailed(let message):
            return "Template validation failed: \(message)"
        case .templateAlreadyExists(let name):
            return "Template already exists: \(name)"
        case .invalidTemplate(let message):
            return "Invalid template: \(message)"
        }
    }
}