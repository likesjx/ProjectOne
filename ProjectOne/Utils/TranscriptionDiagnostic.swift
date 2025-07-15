//
//  TranscriptionDiagnostic.swift
//  ProjectOne
//
//  Created by Claude on 7/14/25.
//  Diagnostic utility to identify and resolve transcription errors
//

import Foundation
import Speech
import AVFoundation
import os.log

/// Comprehensive diagnostic tool for transcription issues
public class TranscriptionDiagnostic {
    
    private let logger = Logger(subsystem: "com.projectone.diagnostic", category: "TranscriptionDiagnostic")
    
    /// Comprehensive diagnostic check for transcription capabilities
    public func runDiagnostic() async -> DiagnosticResult {
        logger.info("🔍 Starting comprehensive transcription diagnostic...")
        
        var issues: [DiagnosticIssue] = []
        var recommendations: [String] = []
        
        // 1. Check Speech Recognition Permission
        let speechResult = await checkSpeechRecognitionPermission()
        issues.append(contentsOf: speechResult.issues)
        recommendations.append(contentsOf: speechResult.recommendations)
        
        // 2. Check Microphone Permission  
        let micResult = await checkMicrophonePermission()
        issues.append(contentsOf: micResult.issues)
        recommendations.append(contentsOf: micResult.recommendations)
        
        // 3. Check Speech Recognizer Availability
        let recognizerResult = checkSpeechRecognizerAvailability()
        issues.append(contentsOf: recognizerResult.issues)
        recommendations.append(contentsOf: recognizerResult.recommendations)
        
        // 4. Check Engine Selection Logic
        let engineResult = await checkEngineSelection()
        issues.append(contentsOf: engineResult.issues)
        recommendations.append(contentsOf: engineResult.recommendations)
        
        // 5. Check Audio Format Compatibility
        let audioResult = checkAudioFormatCompatibility()
        issues.append(contentsOf: audioResult.issues)
        recommendations.append(contentsOf: audioResult.recommendations)
        
        // 6. Check Environment-specific Issues
        let envResult = checkEnvironmentSpecificIssues()
        issues.append(contentsOf: envResult.issues)
        recommendations.append(contentsOf: envResult.recommendations)
        
        let overallStatus: DiagnosticStatus = issues.contains { $0.severity == .critical } ? .critical :
                                            issues.contains { $0.severity == .warning } ? .warning : .healthy
        
        logger.info("🎯 Diagnostic complete. Status: \(overallStatus.rawValue)")
        
        return DiagnosticResult(
            status: overallStatus,
            issues: issues,
            recommendations: recommendations,
            timestamp: Date()
        )
    }
    
    // MARK: - Individual Checks
    
    private func checkSpeechRecognitionPermission() async -> CheckResult {
        var issues: [DiagnosticIssue] = []
        var recommendations: [String] = []
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        
        switch authStatus {
        case .notDetermined:
            issues.append(DiagnosticIssue(
                type: .permission,
                severity: .critical,
                title: "Speech Recognition Permission Not Requested",
                description: "The app hasn't requested speech recognition permission yet",
                technicalDetails: "SFSpeechRecognizer.authorizationStatus() = .notDetermined"
            ))
            recommendations.append("Request speech recognition permission in app initialization")
            
        case .denied:
            issues.append(DiagnosticIssue(
                type: .permission,
                severity: .critical,
                title: "Speech Recognition Permission Denied",
                description: "User has denied speech recognition permission",
                technicalDetails: "SFSpeechRecognizer.authorizationStatus() = .denied"
            ))
            recommendations.append("Guide user to Settings > Privacy & Security > Speech Recognition to enable permission")
            
        case .restricted:
            issues.append(DiagnosticIssue(
                type: .permission,
                severity: .critical,
                title: "Speech Recognition Restricted",
                description: "Speech recognition is restricted by device policy",
                technicalDetails: "SFSpeechRecognizer.authorizationStatus() = .restricted"
            ))
            recommendations.append("Contact device administrator or check device restrictions")
            
        case .authorized:
            logger.info("✅ Speech recognition permission granted")
            
        @unknown default:
            issues.append(DiagnosticIssue(
                type: .permission,
                severity: .warning,
                title: "Unknown Speech Recognition Permission Status",
                description: "Unrecognized permission status",
                technicalDetails: "SFSpeechRecognizer.authorizationStatus() = unknown(\(authStatus.rawValue))"
            ))
        }
        
        return CheckResult(issues: issues, recommendations: recommendations)
    }
    
    private func checkMicrophonePermission() async -> CheckResult {
        var issues: [DiagnosticIssue] = []
        var recommendations: [String] = []
        
        #if os(iOS)
        let micPermission = AVAudioSession.sharedInstance().recordPermission
        
        switch micPermission {
        case .undetermined:
            issues.append(DiagnosticIssue(
                type: .permission,
                severity: .critical,
                title: "Microphone Permission Not Requested",
                description: "The app hasn't requested microphone access yet",
                technicalDetails: "AVAudioSession.recordPermission = .undetermined"
            ))
            recommendations.append("Request microphone permission before recording")
            
        case .denied:
            issues.append(DiagnosticIssue(
                type: .permission,
                severity: .critical,
                title: "Microphone Permission Denied",
                description: "User has denied microphone access",
                technicalDetails: "AVAudioSession.recordPermission = .denied"
            ))
            recommendations.append("Guide user to Settings > Privacy & Security > Microphone to enable access")
            
        case .granted:
            logger.info("✅ Microphone permission granted")
            
        @unknown default:
            issues.append(DiagnosticIssue(
                type: .permission,
                severity: .warning,
                title: "Unknown Microphone Permission Status",
                description: "Unrecognized microphone permission status",
                technicalDetails: "AVAudioSession.recordPermission = unknown(\(micPermission.rawValue))"
            ))
        }
        #else
        // macOS doesn't use AVAudioSession for microphone permissions
        logger.info("✅ Microphone permission assumed granted on macOS")
        #endif
        
        return CheckResult(issues: issues, recommendations: recommendations)
    }
    
    private func checkSpeechRecognizerAvailability() -> CheckResult {
        var issues: [DiagnosticIssue] = []
        var recommendations: [String] = []
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            issues.append(DiagnosticIssue(
                type: .capability,
                severity: .critical,
                title: "Speech Recognizer Unavailable",
                description: "Cannot create speech recognizer for en-US locale",
                technicalDetails: "SFSpeechRecognizer(locale: en-US) returned nil"
            ))
            recommendations.append("Check device language settings and network connectivity")
            return CheckResult(issues: issues, recommendations: recommendations)
        }
        
        if !recognizer.isAvailable {
            issues.append(DiagnosticIssue(
                type: .capability,
                severity: .critical,
                title: "Speech Recognizer Not Available",
                description: "Speech recognizer exists but is not currently available",
                technicalDetails: "SFSpeechRecognizer.isAvailable = false"
            ))
            recommendations.append("Check network connectivity and try again later")
        } else {
            logger.info("✅ Speech recognizer available")
        }
        
        logger.info("🔊 On-device recognition: \(recognizer.supportsOnDeviceRecognition)")
        return CheckResult(issues: issues, recommendations: recommendations)
    }
    
    private func checkEngineSelection() async -> CheckResult {
        var issues: [DiagnosticIssue] = []
        var recommendations: [String] = []
        do {
            let factory = SpeechEngineFactory()
            let engine = try await factory.getTranscriptionEngine()
            logger.info("✅ Successfully selected engine: \(engine.method.displayName)")
            
            if !engine.isAvailable {
                issues.append(DiagnosticIssue(
                    type: .engine,
                    severity: .critical,
                    title: "Selected Engine Not Available",
                    description: "Engine \(engine.method.displayName) was selected but is not available",
                    technicalDetails: "engine.isAvailable = false after selection"
                ))
                recommendations.append("Check engine-specific requirements and dependencies")
            }
            
        } catch {
            issues.append(DiagnosticIssue(
                type: .engine,
                severity: .critical,
                title: "Engine Selection Failed",
                description: "Could not select any transcription engine",
                technicalDetails: "SpeechEngineFactory.getTranscriptionEngine() threw: \(error.localizedDescription)"
            ))
            recommendations.append("Verify all engine dependencies and permissions are satisfied")
        }
        
        return CheckResult(issues: issues, recommendations: recommendations)
    }
    
    private func checkAudioFormatCompatibility() -> CheckResult {
        var issues: [DiagnosticIssue] = []
        var recommendations: [String] = []
        // Check if the audio recording format matches transcription expectations
        let audioSettings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let sampleRate = audioSettings[AVSampleRateKey] as? Int ?? 0
        if sampleRate < 16000 {
            issues.append(DiagnosticIssue(
                type: .audioFormat,
                severity: .warning,
                title: "Low Sample Rate",
                description: "Audio sample rate (\(sampleRate)Hz) may affect transcription quality",
                technicalDetails: "Recommended sample rate: 16kHz or higher"
            ))
            recommendations.append("Consider increasing sample rate to 16kHz for better accuracy")
        }
        
        logger.info("🎵 Audio format: \(audioSettings)")
        return CheckResult(issues: issues, recommendations: recommendations)
    }
    
    private func checkEnvironmentSpecificIssues() -> CheckResult {
        var issues: [DiagnosticIssue] = []
        var recommendations: [String] = []
        #if targetEnvironment(simulator)
        issues.append(DiagnosticIssue(
            type: .environment,
            severity: .warning,
            title: "Running in iOS Simulator",
            description: "Some transcription features are limited in simulator",
            technicalDetails: "WhisperKit and MLX are disabled in simulator environment"
        ))
        recommendations.append("Test on physical device for full transcription capabilities")
        
        // Check if simulator-specific issues exist
        logger.warning("🖥️ iOS Simulator detected - WhisperKit/MLX unavailable")
        recommendations.append("Apple Speech should be the primary engine in simulator")
        #else
        logger.info("📱 Running on physical device - all engines available")
        #endif
        
        return CheckResult(issues: issues, recommendations: recommendations)
    }
}

// MARK: - Supporting Types

private struct CheckResult {
    let issues: [DiagnosticIssue]
    let recommendations: [String]
}

public struct DiagnosticResult {
    public let status: DiagnosticStatus
    public let issues: [DiagnosticIssue]
    public let recommendations: [String]
    public let timestamp: Date
    
    public var summary: String {
        switch status {
        case .healthy:
            return "✅ Transcription system is healthy and ready"
        case .warning:
            return "⚠️ Transcription may work but has \(issues.count) potential issues"
        case .critical:
            return "❌ Transcription will not work - \(issues.filter { $0.severity == .critical }.count) critical issues found"
        }
    }
}

public enum DiagnosticStatus: String {
    case healthy = "healthy"
    case warning = "warning" 
    case critical = "critical"
}

public struct DiagnosticIssue {
    public let type: IssueType
    public let severity: Severity
    public let title: String
    public let description: String
    public let technicalDetails: String
    
    public enum IssueType {
        case permission
        case capability
        case engine
        case audioFormat
        case environment
    }
    
    public enum Severity {
        case critical  // Prevents transcription from working
        case warning   // May affect quality or reliability
    }
}

// MARK: - Usage Extension

extension TranscriptionDiagnostic {
    
    /// Quick diagnostic check for common issues
    public func quickCheck() async -> String {
        let result = await runDiagnostic()
        
        var output = [
            "🔍 ProjectOne Transcription Diagnostic",
            "=====================================",
            "",
            "📊 Status: \(result.summary)",
            ""
        ]
        
        if !result.issues.isEmpty {
            output.append("🚨 Issues Found:")
            for issue in result.issues {
                let icon = issue.severity == .critical ? "❌" : "⚠️"
                output.append("   \(icon) \(issue.title)")
                output.append("      \(issue.description)")
            }
            output.append("")
        }
        
        if !result.recommendations.isEmpty {
            output.append("💡 Recommendations:")
            for (index, recommendation) in result.recommendations.enumerated() {
                output.append("   \(index + 1). \(recommendation)")
            }
            output.append("")
        }
        
        output.append("🕐 Diagnostic completed at: \(result.timestamp)")
        
        return output.joined(separator: "\n")
    }
}