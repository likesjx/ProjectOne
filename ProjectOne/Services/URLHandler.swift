//
//  URLHandler.swift
//  ProjectOne
//
//  Created on 7/13/25.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class URLHandler: ObservableObject {
    @Published var pendingNote: String?
    @Published var showingImportedNote: Bool = false
    
    func handleURL(_ url: URL, with modelContext: ModelContext) async {
        print("🔗 [URLHandler] Received URL: \(url)")
        
        // Parse the URL to extract note content
        guard let noteContent = extractNoteContent(from: url) else {
            print("❌ [URLHandler] Failed to extract note content from URL")
            return
        }
        
        print("📝 [URLHandler] Extracted note content: \(noteContent.prefix(100))...")
        
        // Create and save the note
        let note = ProcessedNote(
            sourceType: .external,
            originalText: noteContent,
            summary: generateQuickSummary(from: noteContent),
            topics: extractTopics(from: noteContent)
        )
        
        modelContext.insert(note)
        
        do {
            try modelContext.save()
            print("✅ [URLHandler] Successfully saved imported note")
            
            // Set up to show notification or navigate to notes
            pendingNote = noteContent
            showingImportedNote = true
        } catch {
            print("❌ [URLHandler] Failed to save note: \(error)")
        }
    }
    
    private func extractNoteContent(from url: URL) -> String? {
        // Handle different URL schemes and formats
        
        // Drafts URL scheme: drafts5://x-callback-url/create?text=Hello%20World
        if url.scheme == "projectone" {
            return extractFromProjectOneURL(url)
        }
        
        // Drafts x-callback-url format
        if url.host == "x-callback-url" && url.path.contains("create") {
            return extractFromDraftsXCallback(url)
        }
        
        // Direct text parameter
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            
            // Look for common parameter names
            for item in queryItems {
                switch item.name.lowercased() {
                case "text", "content", "note", "body":
                    return item.value?.removingPercentEncoding
                default:
                    continue
                }
            }
        }
        
        return nil
    }
    
    private func extractFromProjectOneURL(_ url: URL) -> String? {
        // projectone://note?text=Hello%20World
        // projectone://import?content=My%20Note%20Content
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        for item in queryItems {
            switch item.name.lowercased() {
            case "text", "content", "note", "body":
                return item.value?.removingPercentEncoding
            default:
                continue
            }
        }
        
        return nil
    }
    
    private func extractFromDraftsXCallback(_ url: URL) -> String? {
        // drafts5://x-callback-url/create?text=Hello%20World
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        for item in queryItems {
            if item.name == "text" {
                return item.value?.removingPercentEncoding
            }
        }
        
        return nil
    }
    
    private func generateQuickSummary(from text: String) -> String {
        // Extract first meaningful line as summary
        let lines = text.components(separatedBy: .newlines)
        let meaningfulLines = lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed.hasPrefix("#") ? nil : trimmed
        }
        
        return meaningfulLines.first?.prefix(100).description ?? "Imported note"
    }
    
    private func extractTopics(from text: String) -> [String] {
        // Simple topic extraction from markdown headers and hashtags
        let lines = text.components(separatedBy: .newlines)
        var topics: [String] = []
        
        // Extract markdown headers
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("#") {
                let header = String(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
                if !header.isEmpty {
                    topics.append(header)
                }
            }
        }
        
        // Extract hashtags
        let hashtagPattern = #"#(\w+)"#
        if let regex = try? NSRegularExpression(pattern: hashtagPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    topics.append(String(text[range]))
                }
            }
        }
        
        return Array(Set(topics)) // Remove duplicates
    }
}

// MARK: - URL Scheme Constants

extension URLHandler {
    static let customScheme = "projectone"
    
    static func createImportURL(with text: String) -> URL? {
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        
        return URL(string: "\(customScheme)://note?text=\(encodedText)")
    }
    
    static func createDraftsAction() -> String {
        // Creates a Drafts action that can send notes to ProjectOne
        let baseURL = "\(customScheme)://note"
        let actionScript = """
        drafts5://x-callback-url/runAction?action=Send%20to%20ProjectOne&text=[[draft]]&x-success=\(baseURL)?text=[[draft]]
        """
        
        return actionScript
    }
}