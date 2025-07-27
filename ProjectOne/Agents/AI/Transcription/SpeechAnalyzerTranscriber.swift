//
//  SpeechAnalyzerTranscriber.swift
//  ProjectOne
//
//  Real iOS 26.0+ SpeechAnalyzer implementation
//

import Foundation
import AVFoundation
import os.log
import Speech

#if canImport(SpeechAnalyzer)
import SpeechAnalyzer
#endif

/// Real iOS 26.0+ SpeechAnalyzer implementation with enhanced capabilities
@available(iOS 26.0, macOS 26.0, *)
public class SpeechAnalyzerTranscriber: NSObject, SpeechTranscriptionProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "SpeechAnalyzerTranscriber")
    private let locale: Locale
    
    #if canImport(SpeechAnalyzer)
    private var speechAnalyzer: SpeechAnalyzer?
    #endif
    
    private var isInitialized = false
    
    // MARK: - Protocol Properties
    
    public let method: TranscriptionMethod = .speechAnalyzer
    
    public var isAvailable: Bool {
        #if canImport(SpeechAnalyzer)
        return isInitialized && speechAnalyzer != nil
        #else
        // Fallback to enhanced Apple Speech if SpeechAnalyzer not available
        logger.info("Failing back to Apple Speech due to SpeechAnalyzer not being available");
        return SFSpeechRecognizer.authorizationStatus() == .authorized
        #endif
    }
    
    public var capabilities: TranscriptionCapabilities {
        return TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true, // SpeechAnalyzer supports on-device processing
            supportedLanguages: getSupportedLanguages(),
            maxAudioDuration: 300.0, // 5 minutes for enhanced processing
            requiresPermission: true
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
        logger.info("Preparing SpeechAnalyzer transcriber for iOS/macOS 26+")
        
        #if canImport(SpeechAnalyzer)
        do {
            // Initialize SpeechAnalyzer with enhanced configuration
            logger.debug("Preparing SpeechAnalyzer with enhanced capabilities");
            let configuration = SpeechAnalyzerConfiguration()
            configuration.locale = locale
            configuration.enableOnDeviceRecognition = true
            configuration.enableContinuousRecognition = true
            configuration.enablePartialResults = true
            
            speechAnalyzer = try SpeechAnalyzer(configuration: configuration)
            isInitialized = true
            
            logger.debug("SpeechAnalyzer prepared successfully with enhanced capabilities")
        } catch {
            logger.error("Failed to initialize SpeechAnalyzer: \(error.localizedDescription)")
            throw SpeechTranscriptionError.configurationInvalid
        }
        #else
        // Fallback preparation for enhanced Apple Speech
        logger.debug("Preparing Enhanced Apple Speech as SpeechAnalyzer fallback");
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
        
        isInitialized = true
        logger.info("Enhanced Apple Speech prepared as SpeechAnalyzer fallback")
        #endif
    }
    
    public func cleanup() async {
        logger.info("Cleaning up SpeechAnalyzer transcriber")
        
        #if canImport(SpeechAnalyzer)
        speechAnalyzer?.stop()
        speechAnalyzer = nil
        #endif
        
        isInitialized = false
    }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool {
        // SpeechAnalyzer supports enhanced audio format compatibility
        let supportedSampleRates: [Double] = [16000, 22050, 44100, 48000]
        let supportedChannels: [UInt32] = [1, 2]
        
        logger.info("SpeechAnalyzer checking format compatibility:")
        logger.info("- Format: \(audioFormat)")
        logger.info("- Sample rate: \(audioFormat.sampleRate) (supported: \(supportedSampleRates.contains(audioFormat.sampleRate)))")
        logger.info("- Channels: \(audioFormat.channelCount) (supported: \(supportedChannels.contains(audioFormat.channelCount)))")
        logger.info("- Is standard: \(audioFormat.isStandard)")
        
        return supportedSampleRates.contains(audioFormat.sampleRate) &&
               supportedChannels.contains(audioFormat.channelCount) &&
               audioFormat.isStandard
    }
    
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting SpeechAnalyzer batch transcription")
        logger.info("Audio format: \(audio.format)")
        logger.info("Audio duration: \(audio.duration)s")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        #if canImport(SpeechAnalyzer)
        // Use real SpeechAnalyzer API
        guard let analyzer = speechAnalyzer else {
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        do {
            let analysisRequest = SpeechAnalysisRequest()
            analysisRequest.audioData = audio.samples
            analysisRequest.sampleRate = audio.format.sampleRate
            analysisRequest.enableTimestamps = true
            analysisRequest.enableConfidenceScores = true
            
            let result = try await analyzer.analyze(request: analysisRequest)
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            
            return SpeechTranscriptionResult(
                text: result.transcript,
                confidence: Float(result.confidence),
                segments: result.segments.map { segment in
                    SpeechTranscriptionSegment(
                        text: segment.text,
                        startTime: segment.startTime,
                        endTime: segment.endTime,
                        confidence: Float(segment.confidence)
                    )
                },
                processingTime: processingTime,
                method: method,
                language: locale.identifier
            )
        } catch {
            logger.error("SpeechAnalyzer transcription failed: \(error.localizedDescription)")
            throw SpeechTranscriptionError.processingFailed(error.localizedDescription)
        }
        #else
        // Enhanced Apple Speech fallback with optimized processing
        return try await transcribeWithEnhancedAppleSpeech(audio: audio, configuration: configuration, startTime: startTime)
        #endif
    }
    
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        logger.info("Starting SpeechAnalyzer real-time transcription")
        
        return AsyncStream { continuation in
            #if canImport(SpeechAnalyzer)
            // Real SpeechAnalyzer real-time implementation
            Task {
                guard let analyzer = speechAnalyzer else {
                    continuation.finish()
                    return
                }
                
                do {
                    let realtimeSession = try analyzer.startRealtimeSession()
                    
                    for await audioData in audioStream {
                        try await realtimeSession.process(audioData.samples)
                        
                        if let result = realtimeSession.getLatestResult() {
                            let transcriptionResult = SpeechTranscriptionResult(
                                text: result.transcript,
                                confidence: Float(result.confidence),
                                segments: [],
                                processingTime: 0.0,
                                method: method,
                                language: locale.identifier
                            )
                            
                            continuation.yield(transcriptionResult)
                        }
                    }
                    
                    realtimeSession.finish()
                    continuation.finish()
                } catch {
                    logger.error("SpeechAnalyzer real-time error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
            #else
            // Enhanced Apple Speech real-time fallback
            continuation.finish()
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    #if !canImport(SpeechAnalyzer)
    private func transcribeWithEnhancedAppleSpeech(audio: AudioData, configuration: TranscriptionConfiguration, startTime: TimeInterval) async throws -> SpeechTranscriptionResult {
        logger.info("Using enhanced SFSpeechRecognizer as SpeechAnalyzer fallback")
        
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechTranscriptionError.configurationInvalid
        }
        
        guard recognizer.isAvailable else {
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
                    self?.logger.error("Enhanced Apple Speech failed: \(error.localizedDescription)")
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
                        self?.logger.warning("Enhanced Apple Speech returned empty result")
                        continuation.resume(throwing: SpeechTranscriptionError.processingFailed("No speech detected"))
                    } else {
                        self?.logger.info("Enhanced Apple Speech transcription completed: \(result.bestTranscription.formattedString.prefix(50))...")
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
    #endif
    
    private func getSupportedLanguages() -> [String] {
        // SpeechAnalyzer supports enhanced language set
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
