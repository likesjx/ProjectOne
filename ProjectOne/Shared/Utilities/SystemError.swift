//
//  SystemError.swift
//  ProjectOne
//
//  Standardized error handling system - implements consistent error patterns
//  as recommended in the GPT-5 feedback
//

import Foundation
import os.log

/// Standardized error types for the ProjectOne system
public enum SystemError: LocalizedError, Equatable {
    case modelContainerCreationFailed(String)
    case serviceInitializationFailed(String, String)
    case providerUnavailable(String)
    case memoryOperationFailed(String, String)
    case aiProviderError(String, String)
    case networkError(String, String)
    case configurationError(String)
    case validationError(String)
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelContainerCreationFailed(let error):
            return "Failed to create model container: \(error)"
        case .serviceInitializationFailed(let service, let error):
            return "Failed to initialize \(service): \(error)"
        case .providerUnavailable(let provider):
            return "Provider \(provider) is not available"
        case .memoryOperationFailed(let operation, let error):
            return "Memory operation '\(operation)' failed: \(error)"
        case .aiProviderError(let provider, let error):
            return "AI provider '\(provider)' error: \(error)"
        case .networkError(let operation, let error):
            return "Network operation '\(operation)' failed: \(error)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .unknownError(let error):
            return "Unknown error: \(error)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .modelContainerCreationFailed:
            return "Model container creation failed"
        case .serviceInitializationFailed:
            return "Service initialization failed"
        case .providerUnavailable:
            return "Provider unavailable"
        case .memoryOperationFailed:
            return "Memory operation failed"
        case .aiProviderError:
            return "AI provider error"
        case .networkError:
            return "Network error"
        case .configurationError:
            return "Configuration error"
        case .validationError:
            return "Validation error"
        case .unknownError:
            return "Unknown error"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .modelContainerCreationFailed:
            return "Check database schema and configuration"
        case .serviceInitializationFailed:
            return "Verify service dependencies and configuration"
        case .providerUnavailable:
            return "Check provider availability and configuration"
        case .memoryOperationFailed:
            return "Verify memory system state and permissions"
        case .aiProviderError:
            return "Check AI provider configuration and network connectivity"
        case .networkError:
            return "Check network connectivity and try again"
        case .configurationError:
            return "Review and update configuration settings"
        case .validationError:
            return "Check input data and validation rules"
        case .unknownError:
            return "Contact support with error details"
        }
    }
}

/// Error logging utility
public struct ErrorLogger {
    private static let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "ErrorLogger")
    
    public static func log(_ error: SystemError, file: String = #file, function: String = #function, line: Int = #line) {
        logger.error("❌ \(error.localizedDescription) - \(file):\(line) \(function)")
        
        #if DEBUG
        print("🔴 Error: \(error.localizedDescription)")
        print("📍 Location: \(file):\(line) \(function)")
        if let reason = error.failureReason {
            print("💡 Reason: \(reason)")
        }
        if let suggestion = error.recoverySuggestion {
            print("🛠️ Suggestion: \(suggestion)")
        }
        #endif
    }
    
    public static func log(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        let systemError = SystemError.unknownError(error.localizedDescription)
        log(systemError, file: file, function: function, line: line)
    }
}

/// Error handling utilities
public extension Result {
    /// Map a Result to a SystemError if it fails
    func mapSystemError<T>(_ transform: (Success) -> T) -> Result<T, SystemError> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            if let systemError = error as? SystemError {
                return .failure(systemError)
            } else {
                return .failure(.unknownError(error.localizedDescription))
            }
        }
    }
    
    /// Handle errors with logging
    func handleError(file: String = #file, function: String = #function, line: Int = #line) -> Success? {
        switch self {
        case .success(let value):
            return value
        case .failure(let error):
            if let systemError = error as? SystemError {
                ErrorLogger.log(systemError, file: file, function: function, line: line)
            } else {
                ErrorLogger.log(error, file: file, function: function, line: line)
            }
            return nil
        }
    }
}
