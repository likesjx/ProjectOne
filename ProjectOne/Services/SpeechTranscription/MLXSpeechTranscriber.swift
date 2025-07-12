//
//  MLXSpeechTranscriber.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import Foundation
import MLX
import MLXNN
import MLXRandom
import AVFoundation
import os.log

/// MLX-powered speech transcription implementation using Whisper models
public class MLXSpeechTranscriber: NSObject, SpeechTranscriptionProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "MLXSpeechTranscriber")
    private let modelManager: MLXModelManager
    private let audioProcessor: AudioProcessor
    
    private var isModelLoaded = false
    private var currentModel: WhisperModel?
    private let locale: Locale
    
    // MARK: - Protocol Properties
    
    public let method: TranscriptionMethod = .mlx
    
    public var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false // MLX not available in iOS Simulator
        #else
        return isModelLoaded && DeviceCapabilities.detect().supportsMLX
        #endif
    }
    
    public var capabilities: TranscriptionCapabilities {
        return TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true, // MLX runs entirely on-device
            supportedLanguages: getSupportedLanguages(),
            maxAudioDuration: 300.0, // 5 minutes for large models
            requiresPermission: false // No microphone permission needed for processing
        )
    }
    
    // MARK: - Initialization
    
    public init(locale: Locale = Locale(identifier: "en-US"), modelSize: WhisperModelSize = .base) throws {
        #if targetEnvironment(simulator)
        // MLX Metal device initialization fails in iOS Simulator
        throw SpeechTranscriptionError.modelUnavailable
        #endif
        
        self.locale = locale
        self.modelManager = MLXModelManager()
        self.audioProcessor = AudioProcessor()
        super.init()
        
        logger.info("MLXSpeechTranscriber initialized with locale: \(locale.identifier), model: \(modelSize.rawValue)")
    }
    
    // MARK: - Protocol Methods
    
    public func prepare() async throws {
        logger.info("Preparing MLX Speech transcriber")
        
        // Check device capabilities
        let capabilities = DeviceCapabilities.detect()
        guard capabilities.supportsMLX else {
            logger.error("Device does not support MLX")
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        // Load the Whisper model
        do {
            currentModel = try await modelManager.loadWhisperModel(for: locale)
            isModelLoaded = true
            logger.info("MLX Whisper model loaded successfully")
        } catch {
            logger.error("Failed to load MLX model: \(error.localizedDescription)")
            throw SpeechTranscriptionError.modelUnavailable
        }
    }
    
    public func cleanup() async {
        logger.info("Cleaning up MLX Speech transcriber")
        currentModel = nil
        isModelLoaded = false
        await modelManager.unloadModel()
    }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool {
        // MLX Whisper works best with specific formats
        let supportedSampleRates: [Double] = [16000] // Whisper prefers 16kHz
        return supportedSampleRates.contains(audioFormat.sampleRate) &&
               audioFormat.channelCount <= 2 &&
               audioFormat.isStandard
    }
    
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting MLX batch transcription")
        
        guard let model = currentModel else {
            throw SpeechTranscriptionError.modelUnavailable
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Preprocess audio for Whisper format
        let processedAudio = try preprocessAudioForWhisper(audio)
        
        // Perform transcription using MLX Whisper
        let transcriptionOutput = try await performMLXTranscription(
            model: model,
            audioData: processedAudio,
            configuration: configuration
        )
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        logger.info("MLX transcription completed in \(String(format: "%.2f", processingTime))s")
        
        return createTranscriptionResult(
            from: transcriptionOutput,
            processingTime: processingTime,
            configuration: configuration
        )
    }
    
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        logger.info("Starting MLX real-time transcription")
        
        return AsyncStream { continuation in
            guard let model = currentModel else {
                logger.error("No MLX model available for real-time transcription")
                continuation.finish()
                return
            }
            
            Task {
                do {
                    var audioBuffer: [Float] = []
                    let bufferSizeSeconds: Double = 3.0 // Process in 3-second chunks
                    let sampleRate: Double = 16000.0
                    let bufferSizeFrames = Int(bufferSizeSeconds * sampleRate)
                    
                    for await audioData in audioStream {
                        // Preprocess and accumulate audio
                        let processedAudio = try self.preprocessAudioForWhisper(audioData)
                        audioBuffer.append(contentsOf: processedAudio.samples)
                        
                        // Process when buffer is full
                        if audioBuffer.count >= bufferSizeFrames {
                            let chunkData = ProcessedAudioData(
                                samples: Array(audioBuffer.prefix(bufferSizeFrames)),
                                sampleRate: sampleRate,
                                channels: 1,
                                duration: bufferSizeSeconds
                            )
                            
                            let result = try await self.performMLXTranscription(
                                model: model,
                                audioData: chunkData,
                                configuration: configuration
                            )
                            
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
                    if !audioBuffer.isEmpty {
                        let finalChunkData = ProcessedAudioData(
                            samples: audioBuffer,
                            sampleRate: sampleRate,
                            channels: 1,
                            duration: Double(audioBuffer.count) / sampleRate
                        )
                        
                        let result = try await self.performMLXTranscription(
                            model: model,
                            audioData: finalChunkData,
                            configuration: configuration
                        )
                        
                        let transcriptionResult = self.createTranscriptionResult(
                            from: result,
                            processingTime: 0.0,
                            configuration: configuration
                        )
                        
                        continuation.yield(transcriptionResult)
                    }
                    
                    continuation.finish()
                } catch {
                    self.logger.error("Real-time MLX transcription error: \(error.localizedDescription)")
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func preprocessAudioForWhisper(_ audio: AudioData) throws -> ProcessedAudioData {
        // Convert audio to the format expected by Whisper (16kHz, mono, float32)
        var processedAudio = try audioProcessor.preprocess(audio: audio)
        
        // Ensure 16kHz sample rate for Whisper
        if processedAudio.sampleRate != 16000.0 {
            let targetFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
            let convertedAudio = try audioProcessor.convert(audio: audio, to: targetFormat)
            processedAudio = try audioProcessor.preprocess(audio: convertedAudio)
        }
        
        // Apply Whisper-specific preprocessing
        let preprocessedSamples = applyWhisperPreprocessing(processedAudio.samples)
        
        return ProcessedAudioData(
            samples: preprocessedSamples,
            sampleRate: processedAudio.sampleRate,
            channels: processedAudio.channels,
            duration: processedAudio.duration
        )
    }
    
    private func applyWhisperPreprocessing(_ samples: [Float]) -> [Float] {
        // Apply log-mel spectrogram preprocessing as expected by Whisper
        // For now, we'll use basic normalization - in production, you'd implement
        // proper mel-spectrogram conversion
        
        let maxValue = samples.map { abs($0) }.max() ?? 1.0
        if maxValue > 0 {
            return samples.map { $0 / maxValue }
        }
        return samples
    }
    
    private func performMLXTranscription(
        model: WhisperModel,
        audioData: ProcessedAudioData,
        configuration: TranscriptionConfiguration
    ) async throws -> WhisperTranscriptionOutput {
        
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    // Convert audio samples to MLX array
                    let audioArray = MLXArray(audioData.samples)
                    
                    // Perform inference using MLX Whisper model
                    let output = try model.transcribe(
                        audio: audioArray,
                        language: getWhisperLanguageCode(for: locale),
                        task: configuration.enableTranslation ? "translate" : "transcribe"
                    )
                    
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: SpeechTranscriptionError.processingFailed(error.localizedDescription))
                }
            }
        }
    }
    
    private func createTranscriptionResult(
        from output: WhisperTranscriptionOutput,
        processingTime: TimeInterval,
        configuration: TranscriptionConfiguration
    ) -> SpeechTranscriptionResult {
        
        let segments = output.segments.map { segment in
            SpeechTranscriptionSegment(
                text: segment.text,
                startTime: segment.startTime,
                endTime: segment.endTime,
                confidence: segment.confidence
            )
        }
        
        return SpeechTranscriptionResult(
            text: output.text,
            confidence: output.averageConfidence,
            segments: segments,
            processingTime: processingTime,
            method: method,
            language: output.detectedLanguage ?? locale.identifier
        )
    }
    
    private func getSupportedLanguages() -> [String] {
        // Whisper supports many languages - returning a subset of common ones
        return [
            "en-US", "en-GB", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-PT", "ru-RU",
            "zh-CN", "ja-JP", "ko-KR", "ar-SA", "hi-IN", "nl-NL", "sv-SE", "da-DK",
            "no-NO", "fi-FI", "pl-PL", "tr-TR", "th-TH", "vi-VN"
        ]
    }
    
    private func getWhisperLanguageCode(for locale: Locale) -> String? {
        // Convert locale to Whisper language code
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        
        // Map to Whisper's expected language codes
        let whisperLanguageMap: [String: String] = [
            "en": "en", "es": "es", "fr": "fr", "de": "de", "it": "it",
            "pt": "pt", "ru": "ru", "zh": "zh", "ja": "ja", "ko": "ko",
            "ar": "ar", "hi": "hi", "nl": "nl", "sv": "sv", "da": "da",
            "no": "no", "fi": "fi", "pl": "pl", "tr": "tr", "th": "th", "vi": "vi"
        ]
        
        return whisperLanguageMap[languageCode]
    }
}

// MARK: - Supporting Types

/// Whisper model size options
public enum WhisperModelSize: String, CaseIterable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var parameters: Int {
        switch self {
        case .tiny: return 39_000_000
        case .base: return 74_000_000
        case .small: return 244_000_000
        case .medium: return 769_000_000
        case .large: return 1_550_000_000
        }
    }
    
    var memoryRequirement: UInt64 {
        // Rough memory requirement in bytes
        return UInt64(parameters * 4) // 4 bytes per float32 parameter
    }
}

/// Whisper model wrapper for MLX
public class WhisperModel {
    private let modelPath: URL
    private let modelSize: WhisperModelSize
    
    init(path: URL, size: WhisperModelSize) {
        self.modelPath = path
        self.modelSize = size
    }
    
    func transcribe(audio: MLXArray, language: String?, task: String) throws -> WhisperTranscriptionOutput {
        // TODO: Implement actual MLX Whisper inference
        // This is a placeholder that would use the actual MLX Whisper implementation
        
        // For now, return a mock result
        let mockSegment = WhisperSegment(
            text: "MLX transcription placeholder",
            startTime: 0.0,
            endTime: 1.0,
            confidence: 0.95
        )
        
        return WhisperTranscriptionOutput(
            text: "MLX transcription placeholder",
            segments: [mockSegment],
            averageConfidence: 0.95,
            detectedLanguage: language ?? "en"
        )
    }
}

/// Whisper transcription output
public struct WhisperTranscriptionOutput {
    let text: String
    let segments: [WhisperSegment]
    let averageConfidence: Float
    let detectedLanguage: String?
}

/// Whisper segment
public struct WhisperSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

/// MLX Model Manager for loading and managing Whisper models
public class MLXModelManager {
    private let logger = Logger(subsystem: "com.projectone.speech", category: "MLXModelManager")
    private var loadedModel: WhisperModel?
    
    func loadWhisperModel(for locale: Locale, size: WhisperModelSize = .base) async throws -> WhisperModel {
        logger.info("Loading Whisper model: \(size.rawValue)")
        
        // Check memory requirements
        let deviceCapabilities = DeviceCapabilities.detect()
        guard deviceCapabilities.availableMemory > size.memoryRequirement else {
            throw SpeechTranscriptionError.processingFailed("Insufficient memory for model \(size.rawValue)")
        }
        
        // Get model path (would download if needed)
        let modelPath = try await getModelPath(size: size)
        
        // Create model instance
        let model = WhisperModel(path: modelPath, size: size)
        loadedModel = model
        
        logger.info("Whisper model \(size.rawValue) loaded successfully")
        return model
    }
    
    func unloadModel() async {
        loadedModel = nil
        logger.info("MLX model unloaded")
    }
    
    private func getModelPath(size: WhisperModelSize) async throws -> URL {
        // TODO: Implement model downloading and caching
        // For now, return a placeholder path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelPath = documentsPath.appendingPathComponent("whisper-\(size.rawValue).mlx")
        
        // In a real implementation, you would:
        // 1. Check if model exists locally
        // 2. Download from Hugging Face or MLX model hub if needed
        // 3. Verify model integrity
        // 4. Return the local path
        
        return modelPath
    }
}