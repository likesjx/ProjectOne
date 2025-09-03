import Foundation
import os.log

public enum AppErrorEvent {
    case modelContainerCreationFailed(String)
    case generic(String)
}

public enum ErrorLogger {
    private static let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "ErrorLogger")
    
    public static func log(_ event: AppErrorEvent) {
        switch event {
        case .modelContainerCreationFailed(let message):
            logger.error("ModelContainer creation failed: \(message)")
        case .generic(let message):
            logger.error("\(message)")
        }
    }
}
