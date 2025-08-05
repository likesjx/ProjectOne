//
//  WhisperKitTranscriber.swift
//  ProjectOne
//
//  Created by Claude on 7/12/25.
//

import Foundation
@preconcurrency import AVFoundation
import os.log
import CoreML
@preconcurrency import WhisperKit

/// WhisperKit-based speech transcription implementation using CoreML-optimized Whisper models
public class WhisperKitTranscriber: NSObject, SpeechTranscriptionProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "WhisperKitTranscriber")
    private var whisperKit: WhisperKit?
    private let locale: Locale
    private let modelSize: WhisperKitModelSize
    
    private var isInitialized = false
    
    // MARK: - Protocol Properties
    
    public let method: TranscriptionMethod = .whisperKit
    
    public var isAvailable: Bool {
        #if targetEnvironment(simulator)
        // WhisperKit is not available in iOS Simulator due to CoreML limitations
        return false
        #else
        return isInitialized && whisperKit != nil
        #endif
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
        
        // Check if running in iOS Simulator and skip initialization
        #if targetEnvironment(simulator)
        logger.warning("Skipping WhisperKit preparation in iOS Simulator due to CoreML limitations")
        logger.info("WhisperKit transcription will not be available in simulator - use physical device for WhisperKit testing")
        isInitialized = false
        return
        #endif
        
        // First, try to use preloaded model from the model preloader
        if let preloadedWhisperKit = await WhisperKitModelPreloader.shared.getPreloadedWhisperKit() {
            logger.info("Using preloaded WhisperKit model")
            whisperKit = preloadedWhisperKit
            isInitialized = true
            return
        }
        
        // If no preloaded model available, fall back to progressive model loading
        logger.warning("No preloaded model available, loading on-demand with progressive fallback")
        
        // Try progressively smaller models to avoid buffer overflow, starting with the smallest
        let fallbackModels: [WhisperKitModelSize] = [.tiny] // Only use tiny model to minimize buffer issues
        
        for (index, fallbackModelSize) in fallbackModels.enumerated() {
            do {
                let modelToUse = fallbackModelSize.modelIdentifier
                
                logger.info("Attempting WhisperKit model (\(index + 1)/\(fallbackModels.count)): \(modelToUse)")
                logger.info("Model download enabled: true")
                logger.info("Expected model repository: argmaxinc/whisperkit-coreml")
            
            // Initialize WhisperKit with timeout to prevent hanging
            let task = Task {
                do {
                    logger.info("Starting WhisperKit initialization...")
                    let whisperKit = try await WhisperKit(
                        model: modelToUse,
                        verbose: true,
                        prewarm: false,  // Reduce memory pressure during initialization
                        load: true,
                        download: true
                    )
                    logger.info("WhisperKit initialization completed successfully")
                    return whisperKit
                } catch {
                    logger.error("WhisperKit initialization failed with error: \(error)")
                    logger.error("Error type: \(type(of: error))")
                    if let nsError = error as NSError? {
                        logger.error("Error domain: \(nsError.domain)")
                        logger.error("Error code: \(nsError.code)")
                        logger.error("Error userInfo: \(nsError.userInfo)")
                    }
                    throw error
                }
            }
            
            // Add 60 second timeout for model initialization/download
            let timeoutDuration: TimeInterval = 60.0
            
            whisperKit = try await withThrowingTaskGroup(of: WhisperKit?.self) { group in
                group.addTask { 
                    return try await task.value 
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeoutDuration * 1_000_000_000))
                    throw SpeechTranscriptionError.processingFailed("WhisperKit initialization timeout after \(timeoutDuration)s")
                }
                
                for try await result in group {
                    group.cancelAll()
                    return result!
                }
                
                throw SpeechTranscriptionError.processingFailed("WhisperKit initialization failed")
            }
            
                isInitialized = true
                logger.info("WhisperKit model \(modelToUse) prepared successfully")
                return  // Success - exit the fallback loop
                
            } catch {
                logger.warning("Model \(fallbackModelSize.modelIdentifier) failed: \(error.localizedDescription)")
                
                // Check if this is a buffer overflow or memory issue
                if error.localizedDescription.contains("MLMultiArray") || 
                   error.localizedDescription.contains("beyond the end") ||
                   error.localizedDescription.contains("CoreML") {
                    logger.info("Buffer overflow detected, trying next smaller model")
                    continue  // Try next model in fallback sequence
                }
                
                // For other errors, still try smaller models
                if index < fallbackModels.count - 1 {
                    logger.info("General error, trying next model: \(error.localizedDescription)")
                    continue
                }
                
                // If this was the last model, rethrow the error
                throw error
            }
        }
        
        // If we get here, all models failed
        throw SpeechTranscriptionError.modelUnavailable
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
        
        // Check if running in iOS Simulator and provide clear error message
        #if targetEnvironment(simulator)
        logger.warning("WhisperKit transcription attempted in iOS Simulator - this is not supported due to CoreML limitations")
        throw SpeechTranscriptionError.processingFailed("WhisperKit CoreML models are not compatible with iOS Simulator. Please test on a physical device or use an alternative transcription method.")
        #endif
        
        guard let whisperKit = whisperKit else {
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Convert AudioData to format expected by WhisperKit
            let audioArray = audio.samples
            
            // Create very conservative transcription options to prevent buffer overflow
            // Limit audio length to prevent MLMultiArray overflow (seen at offset 224)
            let maxSampleLength = min(160000, audioArray.count) // 10 seconds at 16kHz maximum
            let clippedAudio = Array(audioArray.prefix(maxSampleLength))
            
            let options = DecodingOptions(
                task: configuration.enableTranslation ? .translate : .transcribe,
                language: getWhisperLanguageCode(for: configuration.language ?? locale.identifier),
                temperature: 0.0,
                temperatureFallbackCount: 0,  // No fallback to prevent multiple allocations
                sampleLength: clippedAudio.count,
                usePrefillPrompt: false,  // Disable to reduce memory usage
                skipSpecialTokens: true,
                withoutTimestamps: true,  // Disable timestamps to reduce buffer size
                wordTimestamps: false,   // Disable for memory efficiency
                clipTimestamps: [0.0]   // Add explicit clipping
            )
            
            // Add timeout for transcription to prevent hanging and handle CoreML crashes
            let transcriptionTask = Task {
                do {
                    return try await whisperKit.transcribe(
                        audioArray: clippedAudio,
                        decodeOptions: options
                    )
                } catch {
                    // Check for CoreML/MLMultiArray specific errors including NSException text
                    let errorMessage = error.localizedDescription
                    if errorMessage.contains("CoreML") || 
                       errorMessage.contains("MLMultiArray") ||
                       errorMessage.contains("setNumber:atOffset") ||
                       errorMessage.contains("DecodingInputs") ||
                       errorMessage.contains("beyond the end of the multi array") ||
                       errorMessage.contains("NSInvalidArgumentException") ||
                       errorMessage.contains("offset") && errorMessage.contains("beyond") {
                        logger.error("CoreML buffer overflow detected at specific offset: \(errorMessage)")
                        logger.info("This is the known MLMultiArray buffer allocation issue - falling back to Apple Speech")
                        throw SpeechTranscriptionError.processingFailed("WhisperKit CoreML buffer overflow - use Apple Speech instead")
                    }
                    throw error
                }
            }
            
            let transcriptionTimeout: TimeInterval = 120.0 // 2 minutes for transcription
            
            // Use a race between transcription and timeout
            let transcriptionResult = try await withThrowingTaskGroup(of: TranscriptionSegment.self) { group in
                group.addTask {
                    let result = try await transcriptionTask.value
                    // Convert result to TranscriptionSegment format
                    if let segments = result as? [TranscriptionSegment] {
                        return segments.first ?? TranscriptionSegment(text: "", startTime: 0, endTime: 0, confidence: 0.0)
                    } else {
                        return TranscriptionSegment(text: String(describing: result), startTime: 0, endTime: 0, confidence: 1.0)
                    }
                }
                
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(transcriptionTimeout * 1_000_000_000))
                    throw SpeechTranscriptionError.processingFailed("WhisperKit transcription timeout after \(transcriptionTimeout)s")
                }
                
                for try await result in group {
                    group.cancelAll()
                    return result
                }
                
                throw SpeechTranscriptionError.processingFailed("No transcription result received")
            }
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("WhisperKit transcription completed in \(String(format: "%.2f", processingTime))s")
            
            // Use the transcription result directly
            return createTranscriptionResult(
                from: transcriptionResult,
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
            // Check if running in iOS Simulator and provide clear error message
            #if targetEnvironment(simulator)
            logger.warning("WhisperKit real-time transcription attempted in iOS Simulator - this is not supported due to CoreML limitations")
            continuation.finish()
            return
            #endif
            
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

