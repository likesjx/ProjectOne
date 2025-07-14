
//
//  NoteItem.swift
//  ProjectOne
//
//  Created by Gemini on 7/13/2025.
//

import Foundation
import SwiftData

@Model
final class NoteItem {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var markdownContent: String
    
    // Contextual Metadata
    var sourceApp: String?
    var sourceURL: String?
    
    // Processing Status
    var isProcessedByMemoryAgent: Bool = false
    var processingDate: Date?
    
    init(
        timestamp: Date,
        markdownContent: String,
        sourceApp: String? = nil,
        sourceURL: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.markdownContent = markdownContent
        self.sourceApp = sourceApp
        self.sourceURL = sourceURL
    }
}
