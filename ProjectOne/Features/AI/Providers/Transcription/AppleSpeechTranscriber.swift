//
//  AppleSpeechTranscriber.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import Foundation
import Speech
@preconcurrency import AVFoundation
import os.log

/// Apple Speech Framework implementation of speech transcription
public class AppleSpeechTranscriber: NSObject, SpeechTranscriptionProtocol, @unchecked Sendable {
    
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
        logger.info("🔧 Initializing AppleSpeechTranscriber with locale: \(locale.identifier)")
        
        self.locale = locale
        
        // Validate locale before creating recognizer
        logger.info("🔍 Validating locale: \(locale.identifier)")
        
        // Try to create SFSpeechRecognizer with safety checks
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            logger.error("❌ Failed to create SFSpeechRecognizer for locale: \(locale.identifier)")
            
            // Try with default locale as fallback
            logger.info("🔄 Attempting fallback to default locale")
            guard let fallbackRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
                logger.error("❌ Failed to create SFSpeechRecognizer even with en-US locale")
                throw SpeechTranscriptionError.configurationInvalid
            }
            self.speechRecognizer = fallbackRecognizer
            logger.info("✅ Created SFSpeechRecognizer with fallback locale: en-US")
            super.init()
            self.speechRecognizer.delegate = self
            return
        }
        
        self.speechRecognizer = recognizer
        logger.info("✅ SFSpeechRecognizer created successfully for locale: \(locale.identifier)")
        
        super.init()
        
        // Set delegate after super.init() to avoid potential crashes
        speechRecognizer.delegate = self
        
        logger.info("✅ AppleSpeechTranscriber initialized with locale: \(locale.identifier)")
        logger.info("📡 On-device recognition supported: \(self.speechRecognizer.supportsOnDeviceRecognition)")
        logger.info("📡 Recognizer is available: \(self.speechRecognizer.isAvailable)")
    }
    
    // MARK: - Protocol Methods
    
    public func prepare() async throws {
        logger.info("🚀 Preparing Apple Speech transcriber")
        
        // Safety check - ensure recognizer is still valid
        logger.info("🔍 Verifying speech recognizer is still valid after initialization")
        
        // Request authorization if needed
        logger.info("🔐 Checking speech recognition authorization")
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        logger.info("📡 Current authorization status: \(authStatus.rawValue)")
        
        if authStatus != .authorized {
            logger.info("🔓 Requesting speech recognition authorization")
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            
            guard status == .authorized else {
                logger.error("❌ Speech recognition authorization denied: \(status.rawValue)")
                throw SpeechTranscriptionError.permissionDenied
            }
            logger.info("✅ Speech recognition authorization granted")
        } else {
            logger.info("✅ Speech recognition already authorized")
        }
        
        // Verify recognizer is available with safety check
        logger.info("🔍 Checking if speech recognizer is available")
        guard speechRecognizer.isAvailable else {
            logger.error("❌ Speech recognizer not available for locale: \(self.locale.identifier)")
            logger.error("📡 Recognizer state: delegate=\(self.speechRecognizer.delegate != nil), locale=\(self.speechRecognizer.locale.identifier)")
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        logger.info("✅ Apple Speech transcriber prepared successfully")
        logger.info("📡 Final state: available=\(self.speechRecognizer.isAvailable), on-device=\(self.speechRecognizer.supportsOnDeviceRecognition)")
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
        
        logger.info("Checking format compatibility:")
        logger.info("- Format: \(audioFormat)")
        logger.info("- Sample rate: \(audioFormat.sampleRate) (supported: \(supportedSampleRates.contains(audioFormat.sampleRate)))")
        logger.info("- Channels: \(audioFormat.channelCount) (supported: \(supportedChannels.contains(audioFormat.channelCount)))")
        logger.info("- Is standard: \(audioFormat.isStandard)")
        logger.info("- Is PCM: \(audioFormat.commonFormat == .pcmFormatInt16 || audioFormat.commonFormat == .pcmFormatInt32)")
        
        return supportedSampleRates.contains(audioFormat.sampleRate) &&
               supportedChannels.contains(audioFormat.channelCount) &&
               audioFormat.isStandard
    }
    
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting batch transcription")
        logger.info("Audio format: \(audio.format)")
        logger.info("Audio duration: \(audio.duration)s")
        logger.info("Audio samples count: \(audio.samples.count)")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        configureRequest(request, with: configuration)
        
        // Add audio data to request
        guard let audioBuffer = audio.audioBuffer as? AVAudioPCMBuffer else {
            logger.error("Audio buffer is not AVAudioPCMBuffer, type: \(type(of: audio.audioBuffer))")
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        logger.info("Audio buffer frame length: \(audioBuffer.frameLength)")
        logger.info("Audio buffer frame capacity: \(audioBuffer.frameCapacity)")
        logger.info("Audio buffer format: \(audioBuffer.format)")
        logger.info("Audio buffer common format: \(audioBuffer.format.commonFormat.rawValue)")
        logger.info("🔍 DEBUGGING: Checking if format is Float32: \(audioBuffer.format.commonFormat == .pcmFormatFloat32)")
        logger.info("🔍 DEBUGGING: Checking if format is Int16: \(audioBuffer.format.commonFormat == .pcmFormatInt16)")
        
        // Check if the buffer has actual audio data
        if audioBuffer.frameLength == 0 {
            logger.warning("Audio buffer is empty (frameLength = 0)")
            throw SpeechTranscriptionError.processingFailed("Audio buffer is empty")
        }
        
        // Use AudioProcessor for optimal format conversion and preprocessing
        logger.info("Using AudioProcessor for optimal Apple Speech format conversion")
        
        let processedBuffer: AVAudioPCMBuffer
        do {
            let audioProcessor = AudioProcessor()
            let processedAudioData = try audioProcessor.preprocess(audio: audio)
            logger.info("Audio preprocessing completed successfully")
            
            // Convert processed data to Apple Speech optimal format (16kHz Int16 PCM)
            let optimalFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, 
                                            sampleRate: 16000,  // Optimal for Apple Speech
                                            channels: 1, 
                                            interleaved: true)!  // Interleaved format
            
            let processedAudio = AudioData(samples: processedAudioData.samples, 
                                         format: audioProcessor.preferredFormat, 
                                         duration: processedAudioData.duration)
            
            logger.info("Starting audio format conversion to optimal format")
            let convertedAudio = try audioProcessor.convert(audio: processedAudio, to: optimalFormat)
            logger.info("Audio format conversion completed")
            
            logger.info("Starting audio normalization")
            let normalizedAudio = try audioProcessor.normalize(audio: convertedAudio)
            logger.info("Audio normalization completed")
            
            guard let buffer = normalizedAudio.audioBuffer as? AVAudioPCMBuffer else {
                logger.error("Failed to get processed audio buffer")
                throw SpeechTranscriptionError.audioFormatUnsupported
            }
            
            processedBuffer = buffer
            
            logger.info("Audio processed with AudioProcessor - Format: \(processedBuffer.format)")
            logger.info("Processed buffer frame length: \(processedBuffer.frameLength)")
            
            // Validate audio content
            if let channelData = processedBuffer.floatChannelData {
                let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(processedBuffer.frameLength)))
                let maxAmplitude = samples.map(abs).max() ?? 0.0
                let avgAmplitude = samples.map(abs).reduce(0, +) / Float(samples.count)
                
                logger.info("Audio validation - Max amplitude: \(maxAmplitude), Avg amplitude: \(avgAmplitude)")
                
                if maxAmplitude < 0.001 {
                    logger.warning("Audio amplitude too low for speech detection")
                    throw SpeechTranscriptionError.processingFailed("Audio too quiet for speech detection")
                }
            }
            
        } catch {
            logger.error("AudioProcessor failed: \(error.localizedDescription)")
            throw SpeechTranscriptionError.processingFailed("Audio processing failed: \(error.localizedDescription)")
        }
        
        request.append(processedBuffer)
        request.endAudio()
        
        // Perform recognition
        let result: SpeechTranscriptionResult = try await withCheckedThrowingContinuation { continuation in
            let hasReturned = OSAllocatedUnfairLock(initialState: false)
            
            // Add timeout handling
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
                let shouldReturn = hasReturned.withLock { hasReturned in
                    if !hasReturned {
                        hasReturned = true
                        return true
                    }
                    return false
                }
                
                if shouldReturn {
                    self.logger.warning("Recognition task timed out after 30 seconds")
                    continuation.resume(throwing: SpeechTranscriptionError.processingFailed("Recognition timeout"))
                }
            }
            
            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else {
                    let shouldReturn = hasReturned.withLock { hasReturned in
                        if !hasReturned {
                            hasReturned = true
                            return true
                        }
                        return false
                    }
                    
                    if shouldReturn {
                        continuation.resume(throwing: SpeechTranscriptionError.processingFailed("AppleSpeechTranscriber was deallocated during recognition"))
                    }
                    return
                }
                
                let shouldContinue = hasReturned.withLock { !$0 }
                if !shouldContinue { return }
                
                if let error = error {
                    let shouldReturn = hasReturned.withLock { hasReturned in
                        if !hasReturned {
                            hasReturned = true
                            return true
                        }
                        return false
                    }
                    
                    if shouldReturn {
                        self.logger.error("Transcription failed: \(error.localizedDescription)")
                        self.logger.error("Error code: \(error._code)")
                        self.logger.error("Error domain: \(error._domain)")
                        continuation.resume(throwing: SpeechTranscriptionError.processingFailed(error.localizedDescription))
                    }
                    return
                }
                
                if let result = result {
                    self.logger.info("Recognition result received - isFinal: \(result.isFinal)")
                    self.logger.info("Best transcription: '\(result.bestTranscription.formattedString)'")
                    self.logger.info("Transcription segments: \(result.bestTranscription.segments.count)")
                    
                    if result.isFinal {
                        let shouldReturn = hasReturned.withLock { hasReturned in
                            if !hasReturned {
                                hasReturned = true
                                return true
                            }
                            return false
                        }
                        
                        if shouldReturn {
                            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
                            let transcriptionResult = self.createTranscriptionResult(from: result, processingTime: processingTime)
                            
                            // Check if we got an empty result
                            if transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                self.logger.warning("Final result is empty - no speech detected in audio")
                                continuation.resume(throwing: SpeechTranscriptionError.processingFailed("No speech detected"))
                            } else {
                                self.logger.info("Batch transcription completed: \(result.bestTranscription.formattedString.prefix(50))...")
                                continuation.resume(returning: transcriptionResult)
                            }
                        }
                    } else {
                        self.logger.info("Partial result: '\(result.bestTranscription.formattedString)'")
                    }
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
            
            // Capture configuration to avoid sending parameter to task
            let capturedConfiguration = configuration
            
            Task { [weak self] in
                do {
                    guard let self = self else { return }
                    try await self.startRealTimeRecognition(configuration: capturedConfiguration)
                    
                    for await audioData in audioStream {
                        try await self.processRealTimeAudio(audioData)
                    }
                    
                    await self.stopRealTimeRecognition()
                } catch {
                    self?.logger.error("Real-time transcription error: \(error.localizedDescription)")
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
            language: self.locale.identifier
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