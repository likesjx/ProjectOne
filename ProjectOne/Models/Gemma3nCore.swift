import Foundation
import SwiftUI
import Combine

/// Placeholder for Gemma3nCore until proper implementation
class Gemma3nCore: ObservableObject {
    static let shared = Gemma3nCore()
    
    private init() {}
    
    // Placeholder methods for compatibility
    func processText(_ text: String) -> String {
        return text
    }
    
    func isAvailable() -> Bool {
        return false
    }
}