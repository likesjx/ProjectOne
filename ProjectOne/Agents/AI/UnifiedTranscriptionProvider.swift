//
//  UnifiedTranscriptionProvider.swift
//  ProjectOne
//
//  Created for unified transcription provider interface
//

import Foundation
import AVFoundation
import Speech
import os.log

/// Unified transcription provider supporting multiple transcription engines
public class UnifiedTranscriptionProvider: BaseUnifiedProvider {
    
    // MARK: - Properties
    
    public override var identifier: String { "unified-transcription-provider" }
    public override var displayName: String { "Unified Transcription Provider" }
    public override var primaryModelType: ModelType { .speechTranscription }
    public override var supportedModelTypes: [ModelType] { [.speechTranscription, .audioProcessing] }
    
    public override var capabilities: ModelCapabilities {
        return ModelCapabilities(
            supportedModalities: [.audio],
            supportedInputTypes: [.speechTranscription, .audioProcessing],
            supportedOutputTypes: [.speechTranscription, .audioProcessing],
            maxContextLength: nil, // No context limit for transcription
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: canUseOfflineRecognition,
            supportsPersonalData: true,
            isOnDevice: true,
            estimatedResponseTime: 0.5,
            memoryRequirements: 256, // ~256MB
            supportedLanguages: ["en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-PT", "ja-JP", "ko-KR", "zh-CN"],
            maxAudioDuration: 300, // 5 minutes
            requiresPermission: true,
            requiresNetwork: false
        )
    }
    
    public override var isAvailable: Bool {
        return speechRecognitionAvailable
    }
    
    // MARK: - Transcription Engines
    
    public enum TranscriptionEngine: String, CaseIterable {
        case appleSpeech = "apple-speech"
        case whisperKit = "whisper-kit"
        case mlx = "mlx-whisper"
        case speechAnalyzer = "speech-analyzer"
        
        public var displayName: String {
            switch self {
            case .appleSpeech:
                return "Apple Speech Recognition"
            case .whisperKit:
                return "WhisperKit"
            case .mlx:
                return "MLX Whisper"
            case .speechAnalyzer:
                return "Speech Analyzer"
            }
        }
        
        public var isAvailable: Bool {
            switch self {
            case .appleSpeech:
                return SFSpeechRecognizer.authorizationStatus() == .authorized
            case .whisperKit:
                return false // Placeholder - would check WhisperKit availability
            case .mlx:
                return false // Placeholder - would check MLX availability
            case .speechAnalyzer:
                return true // Always available as fallback
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    private var currentEngine: TranscriptionEngine = .appleSpeech
    private var speechRecognitionAvailable: Bool = false
    private var canUseOfflineRecognition: Bool = false
    
    // MARK: - Initialization
    
    public init() {
        super.init(
            subsystem: "com.jaredlikes.ProjectOne",
            category: "UnifiedTranscriptionProvider"
        )
        
        setupSpeechRecognition()
        logger.info("Initialized Unified Transcription Provider")
    }
    
    // MARK: - UnifiedModelProvider Implementation
    
    public override func process(input: UnifiedModelInput, modelType: ModelType?) async throws -> UnifiedModelOutput {
        let targetType = modelType ?? primaryModelType
        
        guard targetType == .speechTranscription || targetType == .audioProcessing else {
            throw UnifiedModelProviderError.modelTypeNotSupported(targetType)
        }
        
        guard let audioData = input.audioData else {
            throw UnifiedModelProviderError.inputValidationFailed("Audio data required for transcription")
        }
        
        // Process based on selected engine
        switch currentEngine {
        case .appleSpeech:
            return try await processWithAppleSpeech(audioData: audioData, input: input)
        case .whisperKit:
            return try await processWithWhisperKit(audioData: audioData, input: input)
        case .mlx:
            return try await processWithMLXWhisper(audioData: audioData, input: input)
        case .speechAnalyzer:
            return try await processWithSpeechAnalyzer(audioData: audioData, input: input)
        }
    }
    
    public override func prepare(modelTypes: [ModelType]?) async throws {
        logger.info("Preparing transcription provider")
        
        // Set up audio session
        try setupAudioSession()
        
        // Request permissions
        try await requestPermissions()
        
        // Select best available engine
        currentEngine = selectBestEngine()
        
        logger.info("Transcription provider prepared with engine: \(self.currentEngine.displayName)")
    }
    
    public override func cleanup(modelTypes: [ModelType]?) async {
        logger.info("Cleaning up transcription provider")
        
        // Stop any ongoing recognition
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        
        logger.info("Transcription provider cleanup complete")
    }
    
    // MARK: - Model Management
    
    public override func loadModel(name: String, type: ModelType) async throws {
        guard type == .speechTranscription else {
            throw UnifiedModelProviderError.modelTypeNotSupported(type)
        }
        
        // Set the transcription engine
        if let engine = TranscriptionEngine(rawValue: name) {
            currentEngine = engine
            logger.info("Switched to transcription engine: \(engine.displayName)")
        } else {
            throw UnifiedModelProviderError.modelNotLoaded(name, type)
        }
        
        try await super.loadModel(name: name, type: type)
    }
    
    public override func getAvailableModels(for modelType: ModelType) -> [String] {
        guard modelType == .speechTranscription else { return [] }
        
        return TranscriptionEngine.allCases
            .filter { $0.isAvailable }
            .map { $0.rawValue }
    }
    
    // MARK: - Real-time Processing
    
    public override func processStream(inputStream: AsyncStream<UnifiedModelInput>, modelType: ModelType?) -> AsyncStream<UnifiedModelOutput> {
        return AsyncStream { continuation in
            Task {
                do {
                    try await startRealtimeTranscription { result in
                        let output = UnifiedModelOutput(
                            text: result.text,
                            transcriptionResult: result,
                            confidence: Double(result.confidence),
                            processingTime: result.processingTime,
                            modelUsed: self.currentEngine.displayName,
                            metadata: [
                                "engine": self.currentEngine.rawValue,
                                "is_final": result.segments.last?.confidence ?? 0 > 0.8,
                                "language": result.language ?? "unknown"
                            ]
                        )
                        continuation.yield(output)
                    }
                } catch {
                    logger.error("Real-time transcription failed: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupSpeechRecognition() {
        // Check availability
        speechRecognitionAvailable = SFSpeechRecognizer.authorizationStatus() != .denied
        
        // Set up speech recognizer
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        canUseOfflineRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        
        logger.info("Speech recognition available: \(self.speechRecognitionAvailable)")
        logger.info("Offline recognition available: \(self.canUseOfflineRecognition)")
    }
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func requestPermissions() async throws {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            throw UnifiedModelProviderError.permissionDenied("Speech recognition permission denied")
        }
        
        // Request microphone permission
        let microphoneStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard microphoneStatus else {
            throw UnifiedModelProviderError.permissionDenied("Microphone permission denied")
        }
    }
    
    private func selectBestEngine() -> TranscriptionEngine {
        // Prioritize based on availability and capability
        for engine in [TranscriptionEngine.appleSpeech, .whisperKit, .mlx, .speechAnalyzer] {
            if engine.isAvailable {
                return engine
            }
        }
        return .speechAnalyzer // Fallback
    }
    
    private func processWithAppleSpeech(audioData: AudioData, input: UnifiedModelInput) async throws -> UnifiedModelOutput {
        guard let recognizer = speechRecognizer else {
            throw UnifiedModelProviderError.modelNotLoaded("apple-speech", .speechTranscription)
        }
        
        let startTime = Date()
        
        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = canUseOfflineRecognition
        
        // Convert audio data to PCM buffer
        guard let audioBuffer = audioData.audioBuffer as? AVAudioPCMBuffer else {
            throw UnifiedModelProviderError.audioFormatUnsupported("Invalid audio buffer format")
        }
        
        request.append(audioBuffer)
        request.endAudio()
        
        // Perform recognition
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result, result.isFinal {
                    continuation.resume(returning: result)
                }
            }
        }
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Create segments
        let segments = result.transcriptions.first?.segments.map { segment in
            SpeechTranscriptionSegment(
                text: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                confidence: segment.confidence
            )
        } ?? []
        
        // Create transcription result
        let transcriptionResult = SpeechTranscriptionResult(
            text: result.bestTranscription.formattedString,
            confidence: 0.9, // Placeholder confidence
            segments: segments,
            processingTime: processingTime,
            method: .appleSpeech,
            language: "en-US"
        )
        
        return createTranscriptionOutput(
            transcriptionResult: transcriptionResult,
            processingTime: processingTime,
            metadata: [
                "engine": "apple-speech",
                "on_device": canUseOfflineRecognition,
                "segments_count": segments.count
            ]
        )
    }
    
    private func processWithWhisperKit(audioData: AudioData, input: UnifiedModelInput) async throws -> UnifiedModelOutput {
        // Placeholder for WhisperKit implementation
        let startTime = Date()
        
        // Simulate processing
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let transcriptionResult = SpeechTranscriptionResult(
            text: "[WhisperKit] This is a placeholder transcription result. In a real implementation, this would be processed using WhisperKit for high-quality offline speech recognition.",
            confidence: 0.85,
            segments: [],
            processingTime: processingTime,
            method: .whisperKit,
            language: "en"
        )
        
        return createTranscriptionOutput(
            transcriptionResult: transcriptionResult,
            processingTime: processingTime,
            metadata: [
                "engine": "whisper-kit",
                "on_device": true,
                "model_size": "small"
            ]
        )
    }
    
    private func processWithMLXWhisper(audioData: AudioData, input: UnifiedModelInput) async throws -> UnifiedModelOutput {
        // Placeholder for MLX Whisper implementation
        let startTime = Date()
        
        // Simulate processing
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let transcriptionResult = SpeechTranscriptionResult(
            text: "[MLX Whisper] This is a placeholder transcription result. In a real implementation, this would be processed using MLX Whisper for Apple Silicon optimized speech recognition.",
            confidence: 0.90,
            segments: [],
            processingTime: processingTime,
            method: .mlx,
            language: "en"
        )
        
        return createTranscriptionOutput(
            transcriptionResult: transcriptionResult,
            processingTime: processingTime,
            metadata: [
                "engine": "mlx-whisper",
                "on_device": true,
                "apple_silicon": true
            ]
        )
    }
    
    private func processWithSpeechAnalyzer(audioData: AudioData, input: UnifiedModelInput) async throws -> UnifiedModelOutput {
        // Placeholder for speech analyzer implementation
        let startTime = Date()
        
        // Simulate processing
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let processingTime = Date().timeIntervalSince(startTime)
        
        let transcriptionResult = SpeechTranscriptionResult(
            text: "[Speech Analyzer] This is a placeholder transcription result. In a real implementation, this would be processed using a fallback speech analysis engine.",
            confidence: 0.70,
            segments: [],
            processingTime: processingTime,
            method: .speechAnalyzer,
            language: "en"
        )
        
        return createTranscriptionOutput(
            transcriptionResult: transcriptionResult,
            processingTime: processingTime,
            metadata: [
                "engine": "speech-analyzer",
                "on_device": true,
                "fallback": true
            ]
        )
    }
    
    private func startRealtimeTranscription(onResult: @escaping (SpeechTranscriptionResult) -> Void) async throws {
        guard let recognizer = speechRecognizer else {
            throw UnifiedModelProviderError.modelNotLoaded("apple-speech", .speechTranscription)
        }
        
        // Set up audio engine
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine!.inputNode
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = canUseOfflineRecognition
        
        // Set up audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start recognition
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                let transcriptionResult = SpeechTranscriptionResult(
                    text: result.bestTranscription.formattedString,
                    confidence: 0.9, // Placeholder confidence
                    segments: [],
                    processingTime: 0.0,
                    method: .appleSpeech,
                    language: "en-US"
                )
                onResult(transcriptionResult)
            }
        }
        
        // Start audio engine
        audioEngine?.prepare()
        try audioEngine?.start()
    }
}