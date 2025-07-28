//
//  SpeechAnalyzerTranscriber.swift
//  ProjectOne
//
//  Real iOS 26.0+ Speech framework implementation
//

import Foundation
import AVFoundation
import os.log
import Speech

/// Real iOS 26.0+ Speech framework implementation with enhanced capabilities
@available(iOS 26.0, macOS 26.0, *)
public class SpeechAnalyzerTranscriber: NSObject, SpeechTranscriptionProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "SpeechAnalyzerTranscriber")
    private let locale: Locale
    
    private let speechRecognizer: SFSpeechRecognizer?
    
    private var isInitialized = false
    
    // MARK: - Protocol Properties
    
    public let method: TranscriptionMethod = .speechAnalyzer
    
    public var isAvailable: Bool {
        return isInitialized && speechRecognizer?.isAvailable == true
    }
    
    public var capabilities: TranscriptionCapabilities {
        return TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true, // SFSpeechRecognizer supports on-device processing
            supportedLanguages: getSupportedLanguages(),
            maxAudioDuration: 300.0, // 5 minutes for enhanced processing
            requiresPermission: true
        )
    }
    
    // MARK: - Initialization
    
    public init(locale: Locale = Locale(identifier: "en-US")) throws {
        self.locale = locale
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        super.init()
        
        logger.info("SpeechAnalyzerTranscriber initialized with locale: \(locale.identifier)")
    }
    
    // MARK: - Protocol Methods
    
    public func prepare() async throws {
        logger.info("Preparing SpeechAnalyzerTranscriber for iOS/macOS 26+ using SFSpeechRecognizer")
        
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        if authStatus != .authorized {
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            
            guard status == .authorized else {
                logger.error("Speech recognition authorization denied: \(status.rawValue)")
                throw SpeechTranscriptionError.permissionDenied
            }
        }
        
        guard speechRecognizer != nil else {
            logger.error("SFSpeechRecognizer initialization failed for locale: \(locale.identifier)")
            throw SpeechTranscriptionError.configurationInvalid
        }
        
        isInitialized = true
        logger.info("SpeechAnalyzerTranscriber prepared successfully with SFSpeechRecognizer")
    }
    
    public func cleanup() async {
        logger.info("Cleaning up SpeechAnalyzerTranscriber")
        isInitialized = false
    }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool {
        // SFSpeechRecognizer supports common audio format compatibility
        let supportedSampleRates: [Double] = [16000, 22050, 44100, 48000]
        let supportedChannels: [UInt32] = [1, 2]
        
        logger.info("SpeechAnalyzerTranscriber checking format compatibility:")
        logger.info("- Format: \(audioFormat)")
        logger.info("- Sample rate: \(audioFormat.sampleRate) (supported: \(supportedSampleRates.contains(audioFormat.sampleRate)))")
        logger.info("- Channels: \(audioFormat.channelCount) (supported: \(supportedChannels.contains(audioFormat.channelCount)))")
        logger.info("- Is standard: \(audioFormat.isStandard)")
        
        return supportedSampleRates.contains(audioFormat.sampleRate) &&
               supportedChannels.contains(audioFormat.channelCount) &&
               audioFormat.isStandard
    }
    
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting batch transcription with SFSpeechRecognizer")
        logger.info("Audio format: \(audio.format)")
        logger.info("Audio duration: \(audio.duration)s")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            logger.error("SFSpeechRecognizer is not available")
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        // Use AudioProcessor for optimal format conversion
        let audioProcessor = AudioProcessor()
        let processedAudioData = try audioProcessor.preprocess(audio: audio)
        
        // Convert to optimal format for Apple Speech
        let optimalFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                          sampleRate: 16000,
                                          channels: 1,
                                          interleaved: true)!
        
        let processedAudio = AudioData(samples: processedAudioData.samples,
                                      format: audioProcessor.preferredFormat,
                                      duration: processedAudioData.duration)
        
        let convertedAudio = try audioProcessor.convert(audio: processedAudio, to: optimalFormat)
        let normalizedAudio = try audioProcessor.normalize(audio: convertedAudio)
        
        guard let audioBuffer = normalizedAudio.audioBuffer as? AVAudioPCMBuffer else {
            logger.error("Audio format unsupported for SFSpeechRecognizer")
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = configuration.enablePartialResults
        request.requiresOnDeviceRecognition = configuration.requiresOnDeviceRecognition
        
        if !configuration.contextualStrings.isEmpty {
            request.contextualStrings = configuration.contextualStrings
        }
        
        request.append(audioBuffer)
        request.endAudio()
        
        // Perform recognition with enhanced error handling
        let result: SpeechTranscriptionResult = try await withCheckedThrowingContinuation { continuation in
            var hasReturned = false
            var recognitionTask: SFSpeechRecognitionTask?
            
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                if hasReturned { return }
                
                if let error = error {
                    hasReturned = true
                    self?.logger.error("SFSpeechRecognizer failed: \(error.localizedDescription)")
                    continuation.resume(throwing: SpeechTranscriptionError.processingFailed(error.localizedDescription))
                    return
                }
                
                if let result = result, result.isFinal {
                    hasReturned = true
                    let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                    
                    let segments = result.bestTranscription.segments.map { segment in
                        SpeechTranscriptionSegment(
                            text: segment.substring,
                            startTime: segment.timestamp,
                            endTime: segment.timestamp + segment.duration,
                            confidence: Float(segment.confidence)
                        )
                    }
                    
                    let averageConfidence = segments.isEmpty ? 0.0 : segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
                    
                    let transcriptionResult = SpeechTranscriptionResult(
                        text: result.bestTranscription.formattedString,
                        confidence: averageConfidence,
                        segments: segments,
                        processingTime: processingTime,
                        method: self?.method ?? .speechAnalyzer,
                        language: self?.locale.identifier ?? "en-US"
                    )
                    
                    if transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self?.logger.warning("SFSpeechRecognizer returned empty result")
                        continuation.resume(throwing: SpeechTranscriptionError.processingFailed("No speech detected"))
                    } else {
                        self?.logger.info("SFSpeechRecognizer transcription completed: \(result.bestTranscription.formattedString.prefix(50))...")
                        continuation.resume(returning: transcriptionResult)
                    }
                }
            }
            
            // Add timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
                if !hasReturned {
                    hasReturned = true
                    recognitionTask?.cancel()
                    continuation.resume(throwing: SpeechTranscriptionError.processingFailed("Recognition timeout"))
                }
            }
        }
        
        return result
    }
    
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        logger.info("Starting real-time transcription with SFSpeechRecognizer")
        
        return AsyncStream { continuation in
            guard let recognizer = speechRecognizer, recognizer.isAvailable else {
                logger.error("SFSpeechRecognizer is not available for real-time transcription")
                continuation.finish()
                return
            }
            
            Task {
                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = configuration.enablePartialResults
                request.requiresOnDeviceRecognition = configuration.requiresOnDeviceRecognition
                
                if !configuration.contextualStrings.isEmpty {
                    request.contextualStrings = configuration.contextualStrings
                }
                
                var recognitionTask: SFSpeechRecognitionTask?
                var isFinished = false
                
                recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    if let error = error {
                        self?.logger.error("SFSpeechRecognizer real-time error: \(error.localizedDescription)")
                        if !isFinished {
                            isFinished = true
                            continuation.finish()
                        }
                        return
                    }
                    
                    if let result = result {
                        let segments = result.bestTranscription.segments.map { segment in
                            SpeechTranscriptionSegment(
                                text: segment.substring,
                                startTime: segment.timestamp,
                                endTime: segment.timestamp + segment.duration,
                                confidence: Float(segment.confidence)
                            )
                        }
                        
                        let averageConfidence = segments.isEmpty ? 0.0 : segments.map { $0.confidence }.reduce(0, +) / Float(segments.count)
                        
                        let transcriptionResult = SpeechTranscriptionResult(
                            text: result.bestTranscription.formattedString,
                            confidence: averageConfidence,
                            segments: segments,
                            processingTime: 0.0,
                            method: self?.method ?? .speechAnalyzer,
                            language: self?.locale.identifier ?? "en-US"
                        )
                        
                        continuation.yield(transcriptionResult)
                        
                        if result.isFinal {
                            if !isFinished {
                                isFinished = true
                                continuation.finish()
                            }
                        }
                    }
                }
                
                do {
                    let audioProcessor = AudioProcessor()
                    for await audioData in audioStream {
                        if isFinished {
                            break
                        }
                        
                        let processedAudioData = try audioProcessor.preprocess(audio: audioData)
                        
                        let optimalFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                          sampleRate: 16000,
                                                          channels: 1,
                                                          interleaved: true)!
                        
                        let processedAudio = AudioData(samples: processedAudioData.samples,
                                                      format: audioProcessor.preferredFormat,
                                                      duration: processedAudioData.duration)
                        
                        let convertedAudio = try audioProcessor.convert(audio: processedAudio, to: optimalFormat)
                        let normalizedAudio = try audioProcessor.normalize(audio: convertedAudio)
                        
                        guard let audioBuffer = normalizedAudio.audioBuffer as? AVAudioPCMBuffer else {
                            self.logger.error("Audio format unsupported for SFSpeechRecognizer real-time")
                            continue
                        }
                        
                        request.append(audioBuffer)
                    }
                    
                    request.endAudio()
                } catch {
                    self.logger.error("Error processing audio in real-time transcription: \(error.localizedDescription)")
                    if !isFinished {
                        isFinished = true
                        continuation.finish()
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func getSupportedLanguages() -> [String] {
        // SFSpeechRecognizer supports enhanced language set
        return [
            "en-US", "en-GB", "en-AU", "en-CA", "en-IN", "en-NZ", "en-ZA",
            "es-ES", "es-MX", "es-US", "fr-FR", "fr-CA", "de-DE", "it-IT",
            "pt-PT", "pt-BR", "ru-RU", "zh-CN", "zh-TW", "zh-HK", "ja-JP",
            "ko-KR", "ar-SA", "hi-IN", "nl-NL", "sv-SE", "da-DK", "no-NO",
            "fi-FI", "pl-PL", "tr-TR", "th-TH", "vi-VN", "uk-UA", "cs-CZ",
            "he-IL", "id-ID", "ms-MY", "sk-SK", "hr-HR", "bg-BG", "ro-RO",
            "sl-SI", "et-EE", "lv-LV", "lt-LT", "el-GR", "hu-HU", "ca-ES"
        ]
    }
}
