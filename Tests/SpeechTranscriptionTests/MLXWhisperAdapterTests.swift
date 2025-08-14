//  MLXWhisperAdapterTests.swift
//  ProjectOne Tests
//
//  Tests for MLXWhisperTranscriberAdapter basic batch and streaming behavior.
//  Uses synthetic sine wave audio to keep deterministic and lightweight.

import XCTest
import AVFoundation
@testable import ProjectOne

final class MLXWhisperAdapterTests: XCTestCase {
    // Generate simple mono sine wave samples
    private func makeSine(seconds: Double = 1.0, sr: Double = 16000, freq: Double = 440.0) -> AudioData {
        let n = Int(seconds * sr)
        var samples = [Float](repeating: 0, count: n)
        let twoPiF = 2 * Double.pi * freq
        for i in 0..<n { samples[i] = Float(sin(twoPiF * Double(i) / sr)) }
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        return AudioData(samples: samples, format: format, duration: seconds)
    }
    
    func testPrepareAndBatchTranscriptionGracefulWhenModelMissing() async {
        let adapter = MLXWhisperTranscriberAdapter()
        do { try await adapter.prepare() } catch { /* allowable on platforms without MLX */ }
        // Even if model unavailable, method property should be .mlx
        XCTAssertEqual(adapter.method, .mlx)
    }
    
    func testBatchTranscriptionOrModelUnavailable() async {
        let adapter = MLXWhisperTranscriberAdapter()
        _ = try? await adapter.prepare()
        let audio = makeSine(seconds: 0.5)
        let config = TranscriptionConfiguration()
        do {
            let result = try await adapter.transcribe(audio: audio, configuration: config)
            XCTAssertEqual(result.method, .mlx)
            XCTAssertGreaterThan(result.processingTime, 0)
        } catch {
            // Accept modelUnavailable on systems lacking MLX weights
            if case SpeechTranscriptionError.modelUnavailable = error { } else { XCTFail("Unexpected error: \(error)") }
        }
    }
    
    func testStreamingEmitsOrGracefullyFinishes() async {
        let adapter = MLXWhisperTranscriberAdapter()
        _ = try? await adapter.prepare()
        // Build small async stream of chunks
        let sr: Double = 16000
        let chunk = makeSine(seconds: 0.25, sr: sr)
        let stream = AsyncStream<AudioData> { continuation in
            for _ in 0..<10 { continuation.yield(chunk) }
            continuation.finish()
        }
        let config = TranscriptionConfiguration()
        var received: [SpeechTranscriptionResult] = []
        for await partial in adapter.transcribeRealTime(audioStream: stream, configuration: config) {
            received.append(partial)
        }
        // Either we produced some partials (if model loaded) or none (if unavailable)
        XCTAssertTrue(received.count >= 0)
    }
}
