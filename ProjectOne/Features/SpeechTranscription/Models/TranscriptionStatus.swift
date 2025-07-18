import Foundation

enum TranscriptionStatus: Equatable {
    case idle
    case processing
    case completed
    case failed(Error)
    
    static func == (lhs: TranscriptionStatus, rhs: TranscriptionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.processing, .processing):
            return true
        case (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}