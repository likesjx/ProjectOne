import Foundation
import Speech
import SwiftData
import AVFoundation

/// Apple Speech Recognition transcription engine
class AppleSpeechEngine: TranscriptionEngine {
    
    // MARK: - Properties
    
    private let modelContext: ModelContext
    private let speechRecognizer: SFSpeechRecognizer
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Initialization
    
    init(modelContext: ModelContext, locale: Locale = Locale(identifier: "en-US")) {
        self.modelContext = modelContext
        
        // Initialize speech recognizer with specified locale
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            fatalError("Speech recognizer not available for locale: \(locale.identifier)")
        }
        
        self.speechRecognizer = recognizer
        
        // Request speech recognition authorization
        requestSpeechRecognitionPermission()
    }
    
    // MARK: - Permission Handling
    
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("🎤 [AppleSpeech] Speech recognition authorized")
                case .denied:
                    print("🎤 [AppleSpeech] Speech recognition denied")
                case .restricted:
                    print("🎤 [AppleSpeech] Speech recognition restricted")
                case .notDetermined:
                    print("🎤 [AppleSpeech] Speech recognition not determined")
                @unknown default:
                    print("🎤 [AppleSpeech] Unknown authorization status")
                }
            }
        }
    }
    
    // MARK: - TranscriptionEngine Protocol
    
    func transcribeAudio(_ audioData: Data) async throws -> TranscriptionResult {
        print("🎤 [AppleSpeech] Starting transcription of \(audioData.count) bytes")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Check if speech recognition is available
        guard speechRecognizer.isAvailable else {
            throw TranscriptionError.speechRecognitionUnavailable
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.speechRecognitionUnauthorized
        }
        
        // Create temporary audio file for recognition
        let tempURL = try createTemporaryAudioFile(from: audioData)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // Perform speech recognition
        let result = try await performSpeechRecognition(audioURL: tempURL)
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        print("🎤 [AppleSpeech] Transcription completed in \(String(format: "%.2f", processingTime))s")
        
        return TranscriptionResult(
            text: result.bestTranscription.formattedString,
            confidence: calculateConfidence(from: result),
            segments: createSegments(from: result),
            processingTime: processingTime,
            language: speechRecognizer.locale.identifier
        )
    }
    
    func extractEntities(from text: String) -> [Entity] {
        // Use the sophisticated entity extraction from PlaceholderEngine
        // This can be enhanced with NLP frameworks in the future
        let placeholderEngine = PlaceholderEngine(modelContext: modelContext)
        return placeholderEngine.extractEntities(from: text)
    }
    
    func detectRelationships(entities: [Entity], text: String) -> [Relationship] {
        // Use the relationship detection from PlaceholderEngine
        // This can be enhanced with NLP frameworks in the future
        let placeholderEngine = PlaceholderEngine(modelContext: modelContext)
        return placeholderEngine.detectRelationships(entities: entities, text: text)
    }
    
    // MARK: - Private Methods
    
    private func createTemporaryAudioFile(from audioData: Data) throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        
        try audioData.write(to: tempURL)
        return tempURL
    }
    
    private func performSpeechRecognition(audioURL: URL) async throws -> SFSpeechRecognitionResult {
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            request.taskHint = .dictation
            
            // Set up recognition task
            speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let result = result, result.isFinal else {
                    return
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    private func calculateConfidence(from result: SFSpeechRecognitionResult) -> Double {
        let segments = result.bestTranscription.segments
        guard !segments.isEmpty else { return 0.0 }
        
        let totalConfidence = segments.reduce(0.0) { total, segment in
            total + Double(segment.confidence)
        }
        
        return totalConfidence / Double(segments.count)
    }
    
    private func createSegments(from result: SFSpeechRecognitionResult) -> [TranscriptionSegment] {
        return result.bestTranscription.segments.map { segment in
            TranscriptionSegment(
                text: segment.substring,
                confidence: Double(segment.confidence),
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration,
                isComplete: true
            )
        }
    }
    
    // MARK: - Real-time Transcription (Future Feature)
    
    func startRealTimeTranscription(completion: @escaping (String) -> Void) throws {
        guard speechRecognizer.isAvailable else {
            throw TranscriptionError.speechRecognitionUnavailable
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.speechRecognitionUnauthorized
        }
        
        // Stop any existing real-time transcription
        stopRealTimeTranscription()
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw TranscriptionError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Set up audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    completion(result.bestTranscription.formattedString)
                }
            }
            
            if error != nil || result?.isFinal == true {
                self.stopRealTimeTranscription()
            }
        }
    }
    
    func stopRealTimeTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

// MARK: - Engine Capabilities

extension AppleSpeechEngine {
    static let capabilities = EngineCapabilities(
        supportsRealTimeTranscription: true,
        supportsEntityExtraction: true,
        supportsRelationshipDetection: true,
        supportsSpeakerDiarization: false,
        supportsLanguageDetection: true,
        maxAudioDuration: 60 // Apple Speech has a 1-minute limit per request
    )
}

// MARK: - Error Types

enum TranscriptionError: LocalizedError {
    case speechRecognitionUnavailable
    case speechRecognitionUnauthorized
    case unableToCreateRequest
    case audioProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device"
        case .speechRecognitionUnauthorized:
            return "Speech recognition permission has not been granted"
        case .unableToCreateRequest:
            return "Unable to create speech recognition request"
        case .audioProcessingFailed:
            return "Failed to process audio for speech recognition"
        }
    }
}