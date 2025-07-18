//
//  AppleSpeechTranscriber.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import Foundation
import Speech
import AVFoundation
import os.log

/// Apple Speech Framework implementation of speech transcription
public class AppleSpeechTranscriber: NSObject, SpeechTranscriptionProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "AppleSpeechTranscriber")
    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()
    private let locale: Locale
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var realTimeConfiguration: TranscriptionConfiguration?
    private var realTimeContinuation: AsyncStream<SpeechTranscriptionResult>.Continuation?
    
    // MARK: - Protocol Properties
    
    public let method: TranscriptionMethod = .appleSpeech
    
    public var isAvailable: Bool {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            return false
        }
        return speechRecognizer.isAvailable
    }
    
    public var capabilities: TranscriptionCapabilities {
        return TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: speechRecognizer.supportsOnDeviceRecognition,
            supportedLanguages: [locale.identifier],
            maxAudioDuration: 60.0, // Apple Speech has 60-second limit for audio buffers
            requiresPermission: true
        )
    }
    
    // MARK: - Initialization
    
    public init(locale: Locale = Locale(identifier: "en-US")) throws {
        self.locale = locale
        
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw SpeechTranscriptionError.configurationInvalid
        }
        
        self.speechRecognizer = recognizer
        super.init()
        
        speechRecognizer.delegate = self
        
        logger.info("AppleSpeechTranscriber initialized with locale: \(locale.identifier)")
        logger.info("On-device recognition supported: \(self.speechRecognizer.supportsOnDeviceRecognition)")
    }
    
    // MARK: - Protocol Methods
    
    public func prepare() async throws {
        logger.info("Preparing Apple Speech transcriber")
        
        // Request authorization if needed
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
        
        // Verify recognizer is available
        guard speechRecognizer.isAvailable else {
            logger.error("Speech recognizer not available")
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        logger.info("Apple Speech transcriber prepared successfully")
    }
    
    public func cleanup() async {
        logger.info("Cleaning up Apple Speech transcriber")
        
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        audioEngine.stop()
        
        recognitionTask = nil
        recognitionRequest = nil
        realTimeContinuation?.finish()
        realTimeContinuation = nil
    }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool {
        // Apple Speech works best with specific formats
        let supportedSampleRates: [Double] = [16000, 22050, 44100, 48000]
        let supportedChannels: [UInt32] = [1, 2]
        
        return supportedSampleRates.contains(audioFormat.sampleRate) &&
               supportedChannels.contains(audioFormat.channelCount) &&
               audioFormat.isStandard
    }
    
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting batch transcription")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        configureRequest(request, with: configuration)
        
        // Add audio data to request
        guard let audioBuffer = audio.audioBuffer as? AVAudioPCMBuffer else {
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        request.append(audioBuffer)
        request.endAudio()
        
        // Perform recognition
        let result: SpeechTranscriptionResult = try await withCheckedThrowingContinuation { continuation in
            var hasReturned = false
            
            recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                if hasReturned { return }
                
                if let error = error {
                    hasReturned = true
                    self.logger.error("Transcription failed: \(error.localizedDescription)")
                    continuation.resume(throwing: SpeechTranscriptionError.processingFailed(error.localizedDescription))
                    return
                }
                
                if let result = result, result.isFinal {
                    hasReturned = true
                    let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                    let transcriptionResult = self.createTranscriptionResult(from: result, processingTime: processingTime)
                    self.logger.info("Batch transcription completed: \(result.bestTranscription.formattedString.prefix(50))...")
                    continuation.resume(returning: transcriptionResult)
                }
            }
        }
        
        return result
    }
    
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        logger.info("Starting real-time transcription")
        
        return AsyncStream { continuation in
            self.realTimeContinuation = continuation
            self.realTimeConfiguration = configuration
            
            Task {
                do {
                    try await self.startRealTimeRecognition(configuration: configuration)
                    
                    for await audioData in audioStream {
                        try await self.processRealTimeAudio(audioData)
                    }
                    
                    await self.stopRealTimeRecognition()
                } catch {
                    self.logger.error("Real-time transcription error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func configureRequest(_ request: SFSpeechAudioBufferRecognitionRequest, with configuration: TranscriptionConfiguration) {
        request.shouldReportPartialResults = configuration.enablePartialResults
        
        if configuration.requiresOnDeviceRecognition && speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
            logger.info("Using on-device recognition")
        } else {
            request.requiresOnDeviceRecognition = false
            logger.info("Using server-based recognition")
        }
        
        // Add contextual strings if provided
        if !configuration.contextualStrings.isEmpty {
            request.contextualStrings = configuration.contextualStrings
            logger.info("Added \(configuration.contextualStrings.count) contextual strings")
        }
    }
    
    private func createTranscriptionResult(from result: SFSpeechRecognitionResult, processingTime: TimeInterval) -> SpeechTranscriptionResult {
        let segments = result.bestTranscription.segments.map { segment in
            SpeechTranscriptionSegment(
                text: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                confidence: Float(segment.confidence)
            )
        }
        
        let averageConfidence: Float
        if result.bestTranscription.segments.isEmpty {
            averageConfidence = 0.0
        } else {
            let total = result.bestTranscription.segments.map { Float($0.confidence) }.reduce(0, +)
            averageConfidence = total / Float(result.bestTranscription.segments.count)
        }
        
        return SpeechTranscriptionResult(
            text: result.bestTranscription.formattedString,
            confidence: averageConfidence,
            segments: segments,
            processingTime: processingTime,
            method: method,
            language: locale.identifier
        )
    }
    
    private func startRealTimeRecognition(configuration: TranscriptionConfiguration) async throws {
        logger.info("Starting real-time recognition session")
        
        // Cancel any existing tasks
        recognitionTask?.cancel()
        recognitionRequest = nil
        
        // Create new recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        configureRequest(request, with: configuration)
        
        recognitionRequest = request
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Real-time recognition error: \(error.localizedDescription)")
                self.realTimeContinuation?.finish()
                return
            }
            
            if let result = result {
                let processingTime = 0.0 // Real-time, so minimal processing time
                let transcriptionResult = self.createTranscriptionResult(from: result, processingTime: processingTime)
                self.realTimeContinuation?.yield(transcriptionResult)
            }
        }
        
        // Configure audio session (iOS only)
        #if canImport(UIKit)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        logger.info("Real-time audio engine started")
    }
    
    private func processRealTimeAudio(_ audioData: AudioData) async throws {
        // Audio is already being processed by the audio engine tap
        // This method is here for future enhancements or manual audio feeding
    }
    
    private func stopRealTimeRecognition() async {
        logger.info("Stopping real-time recognition")
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        #if canImport(UIKit)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #endif
        
        realTimeContinuation?.finish()
        realTimeContinuation = nil
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension AppleSpeechTranscriber: SFSpeechRecognizerDelegate {
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        logger.info("Speech recognizer availability changed: \(available)")
        
        if !available {
            // If recognizer becomes unavailable during real-time transcription, finish the stream
            realTimeContinuation?.finish()
        }
    }
}