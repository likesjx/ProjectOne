import Foundation
import AVFoundation
import Speech

class AppleSpeechTranscriber: SpeechTranscriptionProtocol, @unchecked Sendable {
    private let logger = AppleSpeechLogger()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    func prepare() throws {
        logger.info("[AppleSpeechTranscriber] prepare() started")
        do {
            speechRecognizer = SFSpeechRecognizer()
            guard speechRecognizer != nil else {
                throw TranscriberError.unavailable
            }
        } catch {
            logger.error("Prepare failed: \(error.localizedDescription)")
            throw error
        }
    }

    func cleanup() {
        logger.info("[AppleSpeechTranscriber] cleanup() started")
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }

    func canProcess(audioFormat: AVAudioFormat) -> Bool {
        logger.info("[AppleSpeechTranscriber] canProcess(audioFormat:) called with format: \(audioFormat)")
        return speechRecognizer?.supportsOnDeviceRecognition ?? false
    }

    func transcribe(audio: AVAudioPCMBuffer, configuration: AppleTranscriptionConfiguration) throws -> String {
        logger.info("[AppleSpeechTranscriber] transcribe(audio:configuration:) started")
        do {
            logger.info("Creating recognition request")
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = configuration.shouldReportPartialResults

            logger.info("Processing audio buffer")
            let convertedBuffer = try convertBufferIfNeeded(buffer: audio)

            logger.info("Normalizing audio format")
            let normalizedBuffer = try normalizeBuffer(buffer: convertedBuffer)

            logger.info("Adding audio buffer to request")
            request.append(normalizedBuffer)

            logger.info("Starting recognition task")
            var transcription = ""
            var recognitionError: Error?

            let semaphore = DispatchSemaphore(value: 0)
            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [self] result, error in
                if let error = error {
                    self.logger.error("Recognition error: \(error.localizedDescription)")
                    recognitionError = error
                    semaphore.signal()
                    return
                }
                self.logger.info("Recognition result received")
                if let result = result, result.isFinal {
                    transcription = result.bestTranscription.formattedString
                    semaphore.signal()
                }
            }
            semaphore.wait()

            if let error = recognitionError {
                throw error
            }

            return transcription
        } catch {
            logger.error("Transcribe failed: \(error.localizedDescription)")
            throw error
        }
    }

    func transcribeRealTime(audioStream: AVAudioInputNode, configuration: AppleTranscriptionConfiguration) throws {
        logger.info("[AppleSpeechTranscriber] transcribeRealTime(audioStream:configuration:) started")
        try startRealTimeRecognition(configuration: configuration)
    }

    func startRealTimeRecognition(configuration: AppleTranscriptionConfiguration) throws {
        logger.info("[AppleSpeechTranscriber] startRealTimeRecognition(configuration:) started")
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = configuration.shouldReportPartialResults

        guard let recognitionRequest = recognitionRequest else {
            throw TranscriberError.unavailable
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            if let error = error {
                self?.logger.error("Recognition error: \(error.localizedDescription)")
            } else if let result = result {
                self?.logger.info("Recognition result received")
                // Handle partial/final results here
            }
        }
    }

    func stopRealTimeRecognition() {
        logger.info("[AppleSpeechTranscriber] stopRealTimeRecognition() started")
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func convertBufferIfNeeded(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        // Conversion logic here
        return buffer
    }

    private func normalizeBuffer(buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        // Normalization logic here
        return buffer
    }
    
    // MARK: - SpeechTranscriptionProtocol Implementation
    
    var isAvailable: Bool {
        return speechRecognizer?.isAvailable ?? false
    }
    
    var capabilities: TranscriptionCapabilities {
        return TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: speechRecognizer?.supportsOnDeviceRecognition ?? false,
            supportedLanguages: [speechRecognizer?.locale.identifier ?? "en-US"],
            maxAudioDuration: 60,
            requiresPermission: true
        )
    }
    
    var method: TranscriptionMethod {
        return .appleSpeech
    }
    
    func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        // Convert AudioData to the format expected by this implementation
        guard let buffer = audio.audioBuffer as? AVAudioPCMBuffer else {
            throw TranscriberError.unavailable
        }
        
        let appleConfig = AppleTranscriptionConfiguration(shouldReportPartialResults: false)
        let text = try transcribe(audio: buffer, configuration: appleConfig)
        
        return SpeechTranscriptionResult(
            text: text,
            confidence: 0.8,
            segments: [],
            processingTime: 0,
            method: .appleSpeech,
            language: speechRecognizer?.locale.identifier ?? "en-US"
        )
    }
    
    func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        // Return empty stream for now - real implementation would process the stream
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
    
    func cleanup() async {
        // Call the existing cleanup method
        logger.info("[AppleSpeechTranscriber] cleanup() started")
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}

struct AppleTranscriptionConfiguration {
    let shouldReportPartialResults: Bool
}

enum TranscriberError: Error {
    case unavailable
}

class AppleSpeechLogger: @unchecked Sendable {
    func info(_ message: String) {
        print("INFO: \(message)")
    }
    func error(_ message: String) {
        print("ERROR: \(message)")
    }
    func debug(_ message: String) {
        print("DEBUG: \(message)")
    }
}
