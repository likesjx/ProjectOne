//
//  URLHandler.swift
//  ProjectOne
//
//  Handles URL-based note imports and external app integration
//

import Foundation
import SwiftUI
import SwiftData
import os.log

@MainActor
public class URLHandler: ObservableObject {
    @Published public var pendingNote: String?
    @Published public var showingImportedNote: Bool = false
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "URLHandler")
    
    public init() {}
    
    public func handleURL(_ url: URL, with context: ModelContext) async {
        logger.info("🔗 [URLHandler] Received URL: \(url)")
        
        guard let noteContent = extractNoteContent(from: url) else {
            logger.error("❌ [URLHandler] Failed to extract note content from URL")
            return
        }
        
        logger.info("📝 [URLHandler] Extracted note content: \(noteContent.prefix(100))...")
        
        do {
            let processedNote = ProcessedNote(
                sourceType: .external,
                originalText: noteContent
            )
            
            context.insert(processedNote)
            try context.save()
            
            await MainActor.run {
                self.pendingNote = noteContent
                self.showingImportedNote = true
            }
            
            logger.info("✅ [URLHandler] Successfully saved imported note")
            
        } catch {
            logger.error("❌ [URLHandler] Failed to save note: \(error)")
        }
    }
    
    private func extractNoteContent(from url: URL) -> String? {
        // Handle different URL schemes
        switch url.scheme {
        case "projectone":
            return handleProjectOneURL(url)
        case "file":
            return handleFileURL(url)
        default:
            return handleGenericURL(url)
        }
    }
    
    private func handleProjectOneURL(_ url: URL) -> String? {
        // Handle projectone:// scheme URLs
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let noteParam = components.queryItems?.first(where: { $0.name == "note" })?.value else {
            return nil
        }
        
        return noteParam.removingPercentEncoding
    }
    
    private func handleFileURL(_ url: URL) -> String? {
        // Handle file:// URLs (local files)
        do {
            let data = try Data(contentsOf: url)
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("❌ [URLHandler] Failed to read file: \(error)")
            return nil
        }
    }
    
    private func handleGenericURL(_ url: URL) -> String? {
        // Handle generic URLs (web pages, etc.)
        // For now, just return the URL as content
        return "Imported from: \(url.absoluteString)"
    }
}

// MARK: - URL Handling Extensions

extension URLHandler {
    /// Register URL schemes for the app
    public static func registerURLSchemes() {
        // This would typically be done in Info.plist
        // For now, we'll handle it programmatically
    }
    
    /// Handle deep links and universal links
    public func handleDeepLink(_ url: URL) async {
        // Create a temporary context for deep links
        let schema = Schema([ProcessedNote.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        await handleURL(url, with: container.mainContext)
    }
    
    /// Handle universal links
    public func handleUniversalLink(_ url: URL) async {
        // Create a temporary context for universal links
        let schema = Schema([ProcessedNote.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! SwiftData.ModelContainer(for: schema, configurations: [modelConfiguration])
        await handleURL(url, with: container.mainContext)
    }
}