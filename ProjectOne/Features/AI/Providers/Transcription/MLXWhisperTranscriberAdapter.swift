//  MLXWhisperTranscriberAdapter.swift
//  ProjectOne
//
//  Bridges the SwiftWhisperKitMLX package implementation (encoder+decoder
//  greedy pathway) to the app's SpeechTranscriptionProtocol so we can retire
//  the legacy in-target MLXTranscriber.
//
//  NOTE: This is a first pass adapter. Streaming re-invokes full batch decode
//  over accumulated audio for partials (inefficient but acceptable while
//  incremental decoder & timestamp streaming are still in development).

import Foundation
import AVFoundation
import os.log
// TODO: Re-enable SwiftWhisperKitMLX when MLX version conflicts are resolved
// import SwiftWhisperKitMLX

// TODO: Temporary placeholder type for WhisperLoadOptions
public struct WhisperLoadOptions {
    public init() {}
}

public final class MLXWhisperTranscriberAdapter: SpeechTranscriptionProtocol, @unchecked Sendable {
    public let method: TranscriptionMethod = .mlx
    private let logger = Logger(subsystem: "com.projectone.speech", category: "MLXWhisperAdapter")
    private let locale: Locale
    private let loadOptions: WhisperLoadOptions
    // TODO: Re-enable when MLX version conflicts are resolved
    // private let core = MLXWhisperTranscriber()
    private var prepared = false
    private let mutex = NSLock() // guard shared state for streaming buffer (Sendable gaps)
    
    public init(locale: Locale = .current, loadOptions: WhisperLoadOptions = WhisperLoadOptions()) {
        self.locale = locale
        self.loadOptions = loadOptions
    }
    
    public var isAvailable: Bool { prepared }
    
    public var capabilities: TranscriptionCapabilities {
        TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true,
            supportedLanguages: [locale.identifier, "en"],
            maxAudioDuration: 3600,
            requiresPermission: false
        )
    }
    
    public func prepare() async throws {
        guard !prepared else { return }
        // TODO: Re-enable when MLX version conflicts are resolved
        logger.info("MLXWhisperTranscriberAdapter temporarily disabled due to MLX version conflicts")
        throw SpeechTranscriptionError.modelUnavailable
        /*
        do {
            try await core.prepare()
            prepared = true
            logger.info("MLXWhisperTranscriberAdapter prepared underlying model")
        } catch {
            logger.error("Failed preparing MLXWhisperTranscriber: \(error.localizedDescription)")
            throw SpeechTranscriptionError.modelUnavailable
        }
        */
    }
    
    public func cleanup() async { prepared = false }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool { audioFormat.channelCount <= 2 }
    
    // MARK: - Batch
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        // TODO: Re-enable when MLX version conflicts are resolved
        throw SpeechTranscriptionError.modelUnavailable
        /*
        guard prepared else { throw SpeechTranscriptionError.modelUnavailable }
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await core.transcribe(samples: audio.samples, sampleRate: audio.sampleRate)
        let dt = CFAbsoluteTimeGetCurrent() - start
        let seg = SpeechTranscriptionSegment(text: result.text, startTime: 0, endTime: audio.duration, confidence: 0.55)
        return SpeechTranscriptionResult(text: result.text, confidence: seg.confidence, segments: [seg], processingTime: dt, method: method, language: locale.identifier)
        */
    }
    
    // MARK: - Streaming
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        // TODO: Re-enable when MLX version conflicts are resolved
        AsyncStream { continuation in
            continuation.finish()
        }
        /*
        AsyncStream { continuation in
            let cancellation = ManagedAtomic<Bool>(false)
            var buffer: [Float] = []
            var sampleRate: Double = 0
            let minChunkSeconds: Double = 2.0
            Task { [weak self] in
                guard let self else { continuation.finish(); return }
                for await chunk in audioStream {
                    if cancellation.load(ordering: .relaxed) { break }
                    if !self.prepared { break }
                    if sampleRate == 0 { sampleRate = chunk.sampleRate }
                    buffer.append(contentsOf: chunk.samples)
                    let secondsAccum = Double(buffer.count)/max(sampleRate, 1)
                    if secondsAccum >= minChunkSeconds {
                        let start = CFAbsoluteTimeGetCurrent()
                        let text: String
                        do {
                            let r = try await self.core.transcribe(samples: buffer, sampleRate: sampleRate)
                            text = r.text
                        } catch {
                            self.logger.error("Streaming decode failed: \(error.localizedDescription)")
                            continue
                        }
                        let dt = CFAbsoluteTimeGetCurrent() - start
                        let result = SpeechTranscriptionResult(text: text, confidence: 0.5, segments: [], processingTime: dt, method: self.method, language: self.locale.identifier)
                        continuation.yield(result)
                        let keepSeconds: Double = 6.0
                        let keepFrames = Int(keepSeconds * sampleRate)
                        if buffer.count > keepFrames { buffer = Array(buffer.suffix(keepFrames)) }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in cancellation.store(true, ordering: .relaxed) }
        }
        */
    }
}
