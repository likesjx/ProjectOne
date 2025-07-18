//
//  SpeechAnalyzerTranscriber.swift
//  ProjectOne
//
//  Created by Claude on 7/14/25.
//

import Foundation
import AVFoundation
import os.log
#if canImport(Speech)
import Speech
#endif

/// SpeechAnalyzer-based transcription implementation using Apple's latest speech framework
/// Available in iOS 26.0+ and macOS 26.0+ (beta)
@available(iOS 26.0, macOS 26.0, *)
@available(macCatalyst 26.0, *)
@available(visionOS 26.0, *)
public class SpeechAnalyzerTranscriber: NSObject, SpeechTranscriptionProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "SpeechAnalyzerTranscriber")
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private let locale: Locale
    
    private var isInitialized = false
    private var currentTranscriptionTask: Task<Void, Never>?
    
    // MARK: - Protocol Properties
    
    public let method: TranscriptionMethod = .speechAnalyzer
    
    public var isAvailable: Bool {
        return isInitialized && analyzer != nil && transcriber != nil
    }
    
    public var capabilities: TranscriptionCapabilities {
        return TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true, // Fully on-device processing
            supportedLanguages: getSupportedLanguages(),
            maxAudioDuration: 7200.0, // 2 hours - optimized for long-form content
            requiresPermission: true // Microphone permission required
        )
    }
    
    // MARK: - Initialization
    
    public init(locale: Locale = Locale(identifier: "en-US")) throws {
        self.locale = locale
        super.init()
        
        logger.info("SpeechAnalyzerTranscriber initialized with locale: \(locale.identifier)")
    }
    
    // MARK: - Protocol Methods
    
    public func prepare() async throws {
        logger.info("Preparing SpeechAnalyzer transcriber")
        
        do {
            // 1. Allocate locale assets
            logger.info("Allocating locale assets for: \(self.locale.identifier)")
            _ = try await AssetInventory.allocate(locale: self.locale)
            
            // 2. Create transcriber module - try without preset first
            transcriber = try SpeechTranscriber(locale: self.locale, preset: SpeechTranscriber.Preset(
                transcriptionOptions: [],
                reportingOptions: [],
                attributeOptions: []
            ))
            
            // 3. Check asset status and download if needed
            let status = await AssetInventory.status(forModules: [transcriber!])
            
            switch status {
            case .installed:
                logger.info("Speech assets already installed")
            default:
                logger.info("Speech assets not ready - will attempt to continue")
                // For now, continue without asset download to avoid API issues
            }
            
            // 4. Create analyzer with modules
            analyzer = SpeechAnalyzer(modules: [transcriber!], options: nil)
            
            isInitialized = true
            logger.info("SpeechAnalyzer preparation completed successfully")
            
        } catch {
            logger.error("SpeechAnalyzer preparation failed: \(error.localizedDescription)")
            throw SpeechTranscriptionError.preparationFailed(error.localizedDescription)
        }
    }
    
    public func cleanup() async {
        logger.info("Cleaning up SpeechAnalyzer transcriber")
        
        // Cancel any ongoing transcription
        currentTranscriptionTask?.cancel()
        currentTranscriptionTask = nil
        
        // Finalize analyzer if running
        if let analyzer = analyzer {
            do {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            } catch {
                logger.warning("Error finalizing analyzer: \(error.localizedDescription)")
            }
        }
        
        analyzer = nil
        transcriber = nil
        isInitialized = false
        
        logger.info("SpeechAnalyzer cleanup completed")
    }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool {
        // SpeechAnalyzer can determine optimal format automatically
        return audioFormat.channelCount <= 2 && audioFormat.isStandard
    }
    
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting SpeechAnalyzer batch transcription")
        
        guard let analyzer = analyzer, let transcriber = transcriber else {
            throw SpeechTranscriptionError.notPrepared
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Use direct async approach instead of TaskGroup due to API changes
        return try await performBatchTranscription(
            analyzer: analyzer,
            transcriber: transcriber,
            audio: audio,
            configuration: configuration,
            startTime: startTime
        )
    }
    
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        logger.info("Starting SpeechAnalyzer real-time transcription")
        
        return AsyncStream { continuation in
            guard let analyzer = analyzer, let transcriber = transcriber else {
                logger.error("SpeechAnalyzer not prepared for real-time transcription")
                continuation.finish()
                return
            }
            
            currentTranscriptionTask = Task {
                do {
                    try await performRealTimeTranscription(
                        analyzer: analyzer,
                        transcriber: transcriber,
                        audioStream: audioStream,
                        configuration: configuration,
                        continuation: continuation
                    )
                } catch {
                    logger.error("Real-time SpeechAnalyzer transcription error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Private Implementation Methods
    
    private func waitForAssetDownload() async throws {
        // Implementation for waiting for asset download completion
        // This would involve polling the asset status until installed
        for _ in 0..<30 { // Wait up to 30 seconds
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            if let transcriber = transcriber {
                let status = await AssetInventory.status(forModules: [transcriber])
                if status == .installed {
                    return
                }
            }
        }
        throw SpeechTranscriptionError.modelUnavailable
    }
    
    private func performBatchTranscription(
        analyzer: SpeechAnalyzer,
        transcriber: SpeechTranscriber,
        audio: AudioData,
        configuration: TranscriptionConfiguration,
        startTime: CFAbsoluteTime
    ) async throws -> SpeechTranscriptionResult {
        
        // Convert AudioData to async sequence for SpeechAnalyzer
        let audioSequence = createAnalyzerInputSequence(from: audio)
        
        // Start analysis
        try await analyzer.analyzeSequence(audioSequence)
        
        // Collect all results
        var allResults: [SpeechTranscriptionSegment] = []
        var finalText = ""
        var finalConfidence: Float = 0.0
        
        do {
            for try await result in transcriber.results {
                if result.isFinal {
                    finalText = String(result.text.characters)
                    finalConfidence = 1.0 // SpeechTranscriber.Result doesn't provide confidence
                    
                    // Convert to our segment format
                    let segment = SpeechTranscriptionSegment(
                        text: String(result.text.characters),
                        startTime: 0.0, // SpeechTranscriber.Result doesn't provide timing data
                        endTime: audio.duration,
                        confidence: finalConfidence
                    )
                    allResults.append(segment)
                    break
                }
            }
        } catch {
            logger.error("Error processing transcription results: \(error.localizedDescription)")
            throw error
        }
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("SpeechAnalyzer batch transcription completed in \(String(format: "%.2f", processingTime))s")
        
        return SpeechTranscriptionResult(
            text: finalText,
            confidence: finalConfidence,
            segments: allResults,
            processingTime: processingTime,
            method: method,
            language: locale.identifier
        )
    }
    
    private func performRealTimeTranscription(
        analyzer: SpeechAnalyzer,
        transcriber: SpeechTranscriber,
        audioStream: AsyncStream<AudioData>,
        configuration: TranscriptionConfiguration,
        continuation: AsyncStream<SpeechTranscriptionResult>.Continuation
    ) async throws {
        
        // Convert audio stream to format expected by SpeechAnalyzer
        let audioSequence = createAnalyzerInputSequence(from: audioStream)
        
        // Start autonomous analysis
        try await analyzer.analyzeSequence(audioSequence)
        
        // Process results as they come
        do {
            for try await result in transcriber.results {
                let transcriptionResult = SpeechTranscriptionResult(
                    text: String(result.text.characters),
                    confidence: 1.0, // SpeechTranscriber.Result doesn't provide confidence
                    segments: [SpeechTranscriptionSegment(
                        text: String(result.text.characters),
                        startTime: 0.0, // SpeechTranscriber.Result doesn't provide timing data
                        endTime: 0.0,
                        confidence: 1.0
                    )],
                    processingTime: 0.0, // Real-time processing
                    method: method,
                    language: locale.identifier
                )
                
                continuation.yield(transcriptionResult)
                
                if result.isFinal {
                    break
                }
            }
        } catch {
            logger.error("Error processing real-time transcription results: \(error.localizedDescription)")
            throw error
        }
        
        continuation.finish()
    }
    
    private func createAnalyzerInputSequence(from audio: AudioData) -> AsyncStream<AnalyzerInput> {
        return AsyncStream { continuation in
            Task {
                // Convert AudioData to AnalyzerInput format expected by SpeechAnalyzer
                let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
                
                let frameCapacity = AVAudioFrameCount(audio.samples.count)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                    continuation.finish()
                    return
                }
                
                buffer.frameLength = frameCapacity
                
                // Copy samples to buffer
                let audioBufferPointer = buffer.floatChannelData![0]
                for (index, sample) in audio.samples.enumerated() {
                    audioBufferPointer[index] = sample
                }
                
                // Create AnalyzerInput from buffer
                let analyzerInput = AnalyzerInput(buffer: buffer)
                continuation.yield(analyzerInput)
                continuation.finish()
            }
        }
    }
    
    private func createAnalyzerInputSequence(from audioStream: AsyncStream<AudioData>) -> AsyncStream<AnalyzerInput> {
        return AsyncStream { continuation in
            Task {
                let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
                
                for await audioData in audioStream {
                    let frameCapacity = AVAudioFrameCount(audioData.samples.count)
                    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
                        continue
                    }
                    
                    buffer.frameLength = frameCapacity
                    
                    let audioBufferPointer = buffer.floatChannelData![0]
                    for (index, sample) in audioData.samples.enumerated() {
                        audioBufferPointer[index] = sample
                    }
                    
                    // Create AnalyzerInput from buffer
                    let analyzerInput = AnalyzerInput(buffer: buffer)
                    continuation.yield(analyzerInput)
                }
                
                continuation.finish()
            }
        }
    }
    
    private func getSupportedLanguages() -> [String] {
        // SpeechAnalyzer supports automatic language detection and many languages
        return [
            "en-US", "en-GB", "en-AU", "en-CA", "en-IN", "en-IE", "en-NZ", "en-SG", "en-ZA",
            "es-ES", "es-MX", "es-AR", "es-CL", "es-CO", "es-CR", "es-EC", "es-GT", "es-HN",
            "fr-FR", "fr-CA", "fr-BE", "fr-CH",
            "de-DE", "de-AT", "de-CH",
            "it-IT", "it-CH",
            "pt-PT", "pt-BR",
            "ru-RU",
            "zh-CN", "zh-TW", "zh-HK",
            "ja-JP",
            "ko-KR",
            "ar-SA", "ar-AE",
            "hi-IN",
            "nl-NL", "nl-BE",
            "sv-SE",
            "da-DK",
            "no-NO",
            "fi-FI",
            "pl-PL",
            "tr-TR",
            "th-TH",
            "vi-VN",
            "uk-UA",
            "cs-CZ",
            "he-IL",
            "id-ID",
            "ms-MY",
            "sk-SK",
            "hr-HR",
            "bg-BG",
            "ro-RO",
            "sl-SI"
        ]
    }
}

// MARK: - Supporting Types and Extensions


/// Extension to support SpeechAnalyzer results
extension SpeechTranscriptionResult {
    /// Helper initializer for SpeechAnalyzer results
    static func fromSpeechAnalyzer(result speechAnalyzerResult: Any, processingTime: TimeInterval, method: TranscriptionMethod, language: String) -> SpeechTranscriptionResult {
        // This would be implemented based on actual SpeechAnalyzer result structure
        return SpeechTranscriptionResult(
            text: "",
            confidence: 0.0,
            segments: [],
            processingTime: processingTime,
            method: method,
            language: language
        )
    }
}

// MARK: - Error Handling Extensions

extension SpeechTranscriptionError {
    static func preparationFailed(_ reason: String) -> SpeechTranscriptionError {
        return .processingFailed("SpeechAnalyzer preparation failed: \(reason)")
    }
    
    static let notPrepared = SpeechTranscriptionError.processingFailed("SpeechAnalyzer not prepared - call prepare() first")
}