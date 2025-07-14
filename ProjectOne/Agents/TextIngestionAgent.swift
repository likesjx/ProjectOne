
//
//  TextIngestionAgent.swift
//  ProjectOne
//
//  Created by Gemini on 7/13/2025.
//

import Foundation
import SwiftData

@MainActor
class TextIngestionAgent {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func process(note: NoteItem) async {
        print("📝 [TextIngestionAgent] Processing note ID: \(note.id)")
        
        // Create a ProcessedNote from the NoteItem
        let processedNote = ProcessedNote(
            sourceType: .text,
            originalText: note.markdownContent,
            summary: String(note.markdownContent.prefix(100))
        )
        
        // Insert into model context
        modelContext.insert(processedNote)
        
        // Save the context
        do {
            try modelContext.save()
            
            // Mark the note as processed
            note.isProcessedByMemoryAgent = true
            note.processingDate = Date()
            try modelContext.save()
            
            print("📝 [TextIngestionAgent] Successfully processed note ID \(note.id)")
        } catch {
            print("❌ [TextIngestionAgent] Failed to process note: \(error)")
        }
    }
}
