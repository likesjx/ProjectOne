//
//  WhisperKitTranscriber.swift
//  ProjectOne
//
//  Created by Claude on 7/12/25.
//

import Foundation
import AVFoundation
import os.log
import CoreML
import WhisperKit

/// WhisperKit-based speech transcription implementation using CoreML-optimized Whisper models
public class WhisperKitTranscriber: NSObject, SpeechTranscriptionProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "WhisperKitTranscriber")
    private var whisperKit: WhisperKit?
    private let locale: Locale
    private let modelSize: WhisperKitModelSize
    
    private var isInitialized = false
    
    // MARK: - Protocol Properties
    
    public let method: TranscriptionMethod = .whisperKit
    
    public var isAvailable: Bool {
        return isInitialized && whisperKit != nil
    }
    
    public var capabilities: TranscriptionCapabilities {
        return TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true, // WhisperKit runs entirely on-device
            supportedLanguages: getSupportedLanguages(),
            maxAudioDuration: 1800.0, // 30 minutes for large models
            requiresPermission: false // No microphone permission needed for processing
        )
    }
    
    // MARK: - Initialization
    
    public init(locale: Locale = Locale(identifier: "en-US"), modelSize: WhisperKitModelSize = .base) throws {
        self.locale = locale
        self.modelSize = modelSize
        super.init()
        
        logger.info("WhisperKitTranscriber initialized with locale: \(locale.identifier), model: \(modelSize.rawValue)")
    }
    
    // MARK: - Protocol Methods
    
    public func prepare() async throws {
        logger.info("Preparing WhisperKit transcriber")
        
        do {
            // Initialize WhisperKit with the specified model
            whisperKit = try await WhisperKit(
                model: modelSize.modelIdentifier,
                download: true
            )
            isInitialized = true
            
            logger.info("WhisperKit model \(self.modelSize.rawValue) prepared successfully")
        } catch {
            logger.error("Failed to prepare WhisperKit model: \(error.localizedDescription)")
            throw SpeechTranscriptionError.modelUnavailable
        }
    }
    
    public func cleanup() async {
        logger.info("Cleaning up WhisperKit transcriber")
        whisperKit = nil
        isInitialized = false
    }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool {
        // WhisperKit accepts various formats and handles conversion internally
        return audioFormat.channelCount <= 2 && audioFormat.isStandard
    }
    
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting WhisperKit batch transcription")
        
        guard let whisperKit = whisperKit else {
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Convert AudioData to format expected by WhisperKit
            let audioArray = audio.samples
            
            // Create transcription options
            let options = DecodingOptions(
                task: configuration.enableTranslation ? .translate : .transcribe,
                language: getWhisperLanguageCode(for: configuration.language ?? locale.identifier),
                temperature: 0.0,
                temperatureFallbackCount: 3,
                sampleLength: 480000, // 30 seconds at 16kHz
                usePrefillPrompt: true,
                skipSpecialTokens: true,
                withoutTimestamps: false
            )
            
            let results = try await whisperKit.transcribe(
                audioArray: audioArray,
                decodeOptions: options
            )
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("WhisperKit transcription completed in \(String(format: "%.2f", processingTime))s")
            
            // Use the first result (WhisperKit returns array)
            guard let result = results.first else {
                throw SpeechTranscriptionError.processingFailed("No transcription results returned")
            }
            
            return createTranscriptionResult(
                from: result,
                processingTime: processingTime,
                configuration: configuration
            )
            
        } catch {
            logger.error("WhisperKit transcription failed: \(error.localizedDescription)")
            throw SpeechTranscriptionError.processingFailed(error.localizedDescription)
        }
    }
    
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        logger.info("Starting WhisperKit real-time transcription")
        
        return AsyncStream { continuation in
            guard let whisperKit = whisperKit else {
                logger.error("No WhisperKit model available for real-time transcription")
                continuation.finish()
                return
            }
            
            Task {
                do {
                    var audioBuffer: [Float] = []
                    let bufferSizeSeconds: Double = 5.0 // Process in 5-second chunks
                    let sampleRate: Double = 16000.0
                    let bufferSizeFrames = Int(bufferSizeSeconds * sampleRate)
                    
                    for await audioData in audioStream {
                        // Convert and accumulate audio
                        let samples = try convertAudioDataToSamples(audioData)
                        audioBuffer.append(contentsOf: samples)
                        
                        // Process when buffer is full
                        if audioBuffer.count >= bufferSizeFrames {
                            _ = AudioData(
                                samples: Array(audioBuffer.prefix(bufferSizeFrames)),
                                format: audioData.format,
                                duration: bufferSizeSeconds
                            )
                            
                            // Transcribe chunk using WhisperKit
                            let options = DecodingOptions(
                                task: configuration.enableTranslation ? .translate : .transcribe,
                                language: getWhisperLanguageCode(for: configuration.language ?? locale.identifier),
                                temperature: 0.0,
                                temperatureFallbackCount: 1, // Faster for real-time
                                sampleLength: Int(bufferSizeFrames),
                                usePrefillPrompt: false, // Faster for real-time
                                skipSpecialTokens: true,
                                withoutTimestamps: false
                            )
                            
                            let results = try await whisperKit.transcribe(
                                audioArray: Array(audioBuffer.prefix(bufferSizeFrames)),
                                decodeOptions: options
                            )
                            
                            guard let result = results.first else { return }
                            
                            let transcriptionResult = self.createTranscriptionResult(
                                from: result,
                                processingTime: 0.0, // Real-time processing
                                configuration: configuration
                            )
                            
                            continuation.yield(transcriptionResult)
                            
                            // Keep overlap for context
                            let overlapFrames = bufferSizeFrames / 4
                            audioBuffer = Array(audioBuffer.dropFirst(bufferSizeFrames - overlapFrames))
                        }
                    }
                    
                    // Process remaining audio
                    if !audioBuffer.isEmpty && audioBuffer.count > Int(sampleRate) { // At least 1 second
                        _ = AudioData(
                            samples: audioBuffer,
                            format: AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!,
                            duration: Double(audioBuffer.count) / sampleRate
                        )
                        
                        let finalOptions = DecodingOptions(
                            task: configuration.enableTranslation ? .translate : .transcribe,
                            language: getWhisperLanguageCode(for: configuration.language ?? locale.identifier),
                            temperature: 0.0,
                            temperatureFallbackCount: 1,
                            sampleLength: audioBuffer.count,
                            usePrefillPrompt: false,
                            skipSpecialTokens: true,
                            withoutTimestamps: false
                        )
                        
                        let results = try await whisperKit.transcribe(
                            audioArray: audioBuffer,
                            decodeOptions: finalOptions
                        )
                        
                        guard let result = results.first else { return }
                        
                        let transcriptionResult = self.createTranscriptionResult(
                            from: result,
                            processingTime: 0.0,
                            configuration: configuration
                        )
                        
                        continuation.yield(transcriptionResult)
                    }
                    
                    continuation.finish()
                } catch {
                    self.logger.error("Real-time WhisperKit transcription error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func convertAudioDataToSamples(_ audioData: AudioData) throws -> [Float] {
        // For real-time processing, directly use the samples
        return audioData.samples
    }
    
    private func createTranscriptionResult(
        from result: Any,
        processingTime: TimeInterval,
        configuration: TranscriptionConfiguration
    ) -> SpeechTranscriptionResult {
        
        // Use reflection to access WhisperKit result properties safely
        let mirror = Mirror(reflecting: result)
        
        var text = ""
        var language = locale.identifier
        var segments: [SpeechTranscriptionSegment] = []
        
        // Extract text
        if let textValue = mirror.children.first(where: { $0.label == "text" })?.value as? String {
            text = textValue
        }
        
        // Extract language
        if let languageValue = mirror.children.first(where: { $0.label == "language" })?.value as? String {
            language = languageValue
        }
        
        // Extract segments
        if let segmentsValue = mirror.children.first(where: { $0.label == "segments" })?.value {
            let segmentsMirror = Mirror(reflecting: segmentsValue)
            if let segmentsArray = segmentsMirror.children.first?.value {
                let arrayMirror = Mirror(reflecting: segmentsArray)
                
                for (_, segmentValue) in arrayMirror.children {
                    let segmentMirror = Mirror(reflecting: segmentValue)
                    
                    var segmentText = ""
                    var startTime: TimeInterval = 0.0
                    var endTime: TimeInterval = 0.0
                    
                    for (label, value) in segmentMirror.children {
                        switch label {
                        case "text":
                            segmentText = value as? String ?? ""
                        case "startTime":
                            startTime = value as? TimeInterval ?? 0.0
                        case "endTime":
                            endTime = value as? TimeInterval ?? 0.0
                        default:
                            break
                        }
                    }
                    
                    segments.append(SpeechTranscriptionSegment(
                        text: segmentText,
                        startTime: startTime,
                        endTime: endTime,
                        confidence: Float(0.9) // Default confidence for WhisperKit
                    ))
                }
            }
        }
        
        return SpeechTranscriptionResult(
            text: text,
            confidence: calculateOverallConfidence(from: segments),
            segments: segments,
            processingTime: processingTime,
            method: method,
            language: language
        )
    }
    
    private func calculateOverallConfidence(from segments: [SpeechTranscriptionSegment]) -> Float {
        guard !segments.isEmpty else { return 0.0 }
        
        let totalConfidence = segments.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(segments.count)
    }
    
    private func getSupportedLanguages() -> [String] {
        // WhisperKit supports the same languages as OpenAI Whisper
        return [
            "en-US", "en-GB", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-PT", "ru-RU",
            "zh-CN", "ja-JP", "ko-KR", "ar-SA", "hi-IN", "nl-NL", "sv-SE", "da-DK",
            "no-NO", "fi-FI", "pl-PL", "tr-TR", "th-TH", "vi-VN", "uk-UA", "cs-CZ",
            "he-IL", "id-ID", "ms-MY", "sk-SK", "hr-HR", "bg-BG", "ro-RO", "sl-SI"
        ]
    }
    
    private func getWhisperLanguageCode(for languageIdentifier: String) -> String? {
        // Convert full language identifier to Whisper language code
        let languageCode = Locale(identifier: languageIdentifier).language.languageCode?.identifier ?? "en"
        
        // WhisperKit expects ISO 639-1 language codes
        switch languageCode {
        case "en": return "en"
        case "es": return "es"
        case "fr": return "fr"
        case "de": return "de"
        case "it": return "it"
        case "pt": return "pt"
        case "ru": return "ru"
        case "zh": return "zh"
        case "ja": return "ja"
        case "ko": return "ko"
        case "ar": return "ar"
        case "hi": return "hi"
        case "nl": return "nl"
        case "sv": return "sv"
        case "da": return "da"
        case "no": return "no"
        case "fi": return "fi"
        case "pl": return "pl"
        case "tr": return "tr"
        case "th": return "th"
        case "vi": return "vi"
        case "uk": return "uk"
        case "cs": return "cs"
        case "he": return "he"
        case "id": return "id"
        case "ms": return "ms"
        case "sk": return "sk"
        case "hr": return "hr"
        case "bg": return "bg"
        case "ro": return "ro"
        case "sl": return "sl"
        default: return "en" // Default to English
        }
    }
}

// MARK: - Supporting Types

/// WhisperKit model size options
public enum WhisperKitModelSize: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case largeV3 = "large-v3"
    
    var modelIdentifier: String {
        switch self {
        case .tiny: return "openai_whisper-tiny"
        case .base: return "openai_whisper-base"
        case .small: return "openai_whisper-small"
        case .medium: return "openai_whisper-medium"
        case .large: return "openai_whisper-large"
        case .largeV3: return "openai_whisper-large-v3"
        }
    }
    
    var memoryRequirement: UInt64 {
        switch self {
        case .tiny: return 150_000_000 // ~150MB
        case .base: return 300_000_000 // ~300MB
        case .small: return 900_000_000 // ~900MB
        case .medium: return 1_500_000_000 // ~1.5GB
        case .large: return 3_000_000_000 // ~3GB
        case .largeV3: return 3_000_000_000 // ~3GB
        }
    }
}

// MARK: - WhisperKit Integration Complete
// Real WhisperKit implementation is now used directly through the WhisperKit framework

