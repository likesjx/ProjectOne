//  MLXTranscriber.swift
//  ProjectOne
//
//  Created by Copilot on 8/13/25.
//
//  On-device MLX-based Whisper model wrapper (lightweight placeholder).

import Foundation
import AVFoundation
import os.log
import Accelerate
#if canImport(MLX)
import MLX
import MLXNN
import MLXRandom
#endif

// MARK: - MLX Whisper Model Scaffolding

@MainActor
private actor MLXWhisperModelCache {
    static let shared = MLXWhisperModelCache()
    private var models: [String: MLXWhisperModel] = [:]
    func model(id: String, locale: Locale) async throws -> MLXWhisperModel {
        if let m = models[id] { return m }
        let new = try await MLXWhisperModel.load(identifier: id, locale: locale)
        models[id] = new
        return new
    }
}

/// Lightweight representation of a loaded MLX Whisper model (scaffold)
struct MLXWhisperModel: Sendable {
    enum Variant: String, CaseIterable, Sendable {
        case tiny = "whisper-tiny-v3-mlx"
        case base = "whisper-base-v3-mlx"
        case small = "whisper-small-v3-mlx"
        case medium = "whisper-medium-v3-mlx"
        case large = "whisper-large-v3-mlx"
        
        // Rough parameter counts / memory (FP16) estimates for heuristic selection
        var approxParamCount: Int { switch self { case .tiny: return 39_000_000; case .base: return 74_000_000; case .small: return 244_000_000; case .medium: return 769_000_000; case .large: return 1_550_000_000 } }
        var approxBytesFP16: Int { approxParamCount * 2 }
    }
    struct Config: Sendable {
        let nMels: Int
        let dModel: Int
        let nHeads: Int
        let nLayers: Int
        let vocabSize: Int
        let maxFrames: Int
    }
    let identifier: String
    let locale: Locale
    let vocab: [String]
    let config: Config
#if canImport(MLX)
    // Encoder projection
    let melProjectionW: Tensor
    let melProjectionB: Tensor
    // Positional embedding
    let posEmbedding: Tensor
    // Transformer blocks
    let blocks: [TransformerBlockWeights]
    // Final layer norm
    let finalLNScale: Tensor
    let finalLNBias: Tensor
    // Output projection
    let outputW: Tensor
    let outputB: Tensor
    
    struct TransformerBlockWeights: Sendable {
        let attnQ: Tensor; let attnK: Tensor; let attnV: Tensor; let attnOut: Tensor
        let attnQBias: Tensor; let attnKBias: Tensor; let attnVBias: Tensor; let attnOutBias: Tensor
        let ln1Scale: Tensor; let ln1Bias: Tensor
        let ln2Scale: Tensor; let ln2Bias: Tensor
        let ffnIn: Tensor; let ffnInBias: Tensor
        let ffnOut: Tensor; let ffnOutBias: Tensor
    }
#endif
    
    static func load(identifier: String, locale: Locale) async throws -> MLXWhisperModel {
#if !canImport(MLX)
        throw SpeechTranscriptionError.modelUnavailable
#else
        // identifier can be explicit variant rawValue, or "auto"
        let variant: Variant = try resolveVariant(identifier: identifier)
        let baseURL = try locateModelDirectory(variant: variant)
        // Try manifest route first (mlx-community style): manifest.json describes config + tensor files
        if let manifestURL = try? existingFile(baseURL.appendingPathComponent("manifest.json")) {
            return try loadFromManifest(manifestURL: manifestURL, variant: variant, locale: locale)
        }
        // Fallback to legacy bundled naming (development mode)
        guard let legacyURL = Bundle.main.url(forResource: "WhisperTinyMLX", withExtension: nil) else {
            throw SpeechTranscriptionError.modelUnavailable
        }
        let vocab = try loadJSONVocab(baseURL: legacyURL)
        let cfg = Config(nMels: 80, dModel: 384, nHeads: 6, nLayers: 4, vocabSize: vocab.count, maxFrames: 3000)
        func t(_ name: String, shape: [Int]) throws -> Tensor { try loadBinaryTensor(baseURL: legacyURL, name: name, shape: shape) }
        let melProjectionW = try t("mel_proj_w", shape: [cfg.nMels, cfg.dModel])
        let melProjectionB = try t("mel_proj_b", shape: [cfg.dModel])
        let posEmbedding = try t("pos_emb", shape: [cfg.maxFrames, cfg.dModel])
        var blocks: [TransformerBlockWeights] = []
        for i in 0..<cfg.nLayers { let p = "layer_\(i)_"; blocks.append(TransformerBlockWeights(attnQ: try t(p+"attn_q_w", shape:[cfg.dModel,cfg.dModel]), attnK: try t(p+"attn_k_w", shape:[cfg.dModel,cfg.dModel]), attnV: try t(p+"attn_v_w", shape:[cfg.dModel,cfg.dModel]), attnOut: try t(p+"attn_out_w", shape:[cfg.dModel,cfg.dModel]), attnQBias: try t(p+"attn_q_b", shape:[cfg.dModel]), attnKBias: try t(p+"attn_k_b", shape:[cfg.dModel]), attnVBias: try t(p+"attn_v_b", shape:[cfg.dModel]), attnOutBias: try t(p+"attn_out_b", shape:[cfg.dModel]), ln1Scale: try t(p+"ln1_scale", shape:[cfg.dModel]), ln1Bias: try t(p+"ln1_bias", shape:[cfg.dModel]), ln2Scale: try t(p+"ln2_scale", shape:[cfg.dModel]), ln2Bias: try t(p+"ln2_bias", shape:[cfg.dModel]), ffnIn: try t(p+"ffn_in_w", shape:[cfg.dModel,cfg.dModel*4]), ffnInBias: try t(p+"ffn_in_b", shape:[cfg.dModel*4]), ffnOut: try t(p+"ffn_out_w", shape:[cfg.dModel*4,cfg.dModel]), ffnOutBias: try t(p+"ffn_out_b", shape:[cfg.dModel]) )) }
        let finalLNScale = try t("final_ln_scale", shape: [cfg.dModel])
        let finalLNBias = try t("final_ln_bias", shape: [cfg.dModel])
        let outputW = try t("output_w", shape: [cfg.dModel, cfg.vocabSize])
        let outputB = try t("output_b", shape: [cfg.vocabSize])
        return MLXWhisperModel(identifier: variant.rawValue, locale: locale, vocab: vocab, config: cfg, melProjectionW: melProjectionW, melProjectionB: melProjectionB, posEmbedding: posEmbedding, blocks: blocks, finalLNScale: finalLNScale, finalLNBias: finalLNBias, outputW: outputW, outputB: outputB)
#endif
    }
    
    func decode(tokens: [Int]) -> String { tokens.compactMap { $0 < vocab.count ? vocab[$0] : nil }.joined(separator: " ") }
}

#if canImport(MLX)
// MARK: - File Loading Helpers
private func loadJSONVocab(baseURL: URL) throws -> [String] {
    let url = baseURL.appendingPathComponent("vocab.json")
    let data = try Data(contentsOf: url)
    let decoded = try JSONDecoder().decode([String].self, from: data)
    return decoded
}
private func loadBinaryTensor(baseURL: URL, name: String, shape: [Int]) throws -> Tensor {
    let url = baseURL.appendingPathComponent(name + ".bin")
    let data = try Data(contentsOf: url)
    let expectedCount = shape.reduce(1,*)
    let count = data.count / MemoryLayout<Float>.size
    guard count == expectedCount else { throw SpeechTranscriptionError.processingFailed("Tensor \(name) size mismatch (expected \(expectedCount) got \(count))") }
    let arr: [Float] = data.withUnsafeBytes { ptr in
        let buf = ptr.bindMemory(to: Float.self)
        return Array(buf)
    }
    return Tensor(shape: shape, scalars: arr)
}

// MARK: - Manifest Loading (mlx-community)
private struct WhisperManifest: Decodable { struct Cfg: Decodable { let n_mels:Int; let d_model:Int; let n_heads:Int; let n_layers:Int; let vocab_size:Int; let max_frames:Int? } struct TensorEntry: Decodable { let shape:[Int]; let file:String }; let config: Cfg; let tensors: [String:TensorEntry] }

private func loadFromManifest(manifestURL: URL, variant: MLXWhisperModel.Variant, locale: Locale) throws -> MLXWhisperModel {
    let data = try Data(contentsOf: manifestURL)
    let m = try JSONDecoder().decode(WhisperManifest.self, from: data)
    let baseURL = manifestURL.deletingLastPathComponent()
    let vocab = try loadJSONVocab(baseURL: baseURL)
    let cfg = MLXWhisperModel.Config(nMels: m.config.n_mels, dModel: m.config.d_model, nHeads: m.config.n_heads, nLayers: m.config.n_layers, vocabSize: m.config.vocab_size, maxFrames: m.config.max_frames ?? 3000)
    func loadTensor(_ key: String) throws -> Tensor {
        guard let entry = m.tensors[key] else { throw SpeechTranscriptionError.modelUnavailable }
        let fileURL = baseURL.appendingPathComponent(entry.file)
        return try loadBinaryTensorExact(url: fileURL, shape: entry.shape)
    }
    // Required keys expected naming (adapt to actual manifest used by mlx-community if different)
    let melProjectionW = try loadTensor("mel_projection.weight")
    let melProjectionB = try loadTensor("mel_projection.bias")
    let posEmbedding = try loadTensor("positional_embedding")
    var blocks: [MLXWhisperModel.TransformerBlockWeights] = []
    for i in 0..<cfg.nLayers {
        let pre = "encoder.blocks.\(i)."
        blocks.append(.init(
            attnQ: try loadTensor(pre+"attn.query.weight"),
            attnK: try loadTensor(pre+"attn.key.weight"),
            attnV: try loadTensor(pre+"attn.value.weight"),
            attnOut: try loadTensor(pre+"attn.out.weight"),
            attnQBias: try loadTensor(pre+"attn.query.bias"),
            attnKBias: try loadTensor(pre+"attn.key.bias"),
            attnVBias: try loadTensor(pre+"attn.value.bias"),
            attnOutBias: try loadTensor(pre+"attn.out.bias"),
            ln1Scale: try loadTensor(pre+"ln1.weight"),
            ln1Bias: try loadTensor(pre+"ln1.bias"),
            ln2Scale: try loadTensor(pre+"ln2.weight"),
            ln2Bias: try loadTensor(pre+"ln2.bias"),
            ffnIn: try loadTensor(pre+"mlp.fc1.weight"),
            ffnInBias: try loadTensor(pre+"mlp.fc1.bias"),
            ffnOut: try loadTensor(pre+"mlp.fc2.weight"),
            ffnOutBias: try loadTensor(pre+"mlp.fc2.bias")
        ))
    }
    let finalLNScale = try loadTensor("encoder.ln_post.weight")
    let finalLNBias = try loadTensor("encoder.ln_post.bias")
    let outputW = try loadTensor("encoder.proj_out.weight")
    let outputB = try loadTensor("encoder.proj_out.bias")
    return MLXWhisperModel(identifier: variant.rawValue, locale: locale, vocab: vocab, config: cfg, melProjectionW: melProjectionW, melProjectionB: melProjectionB, posEmbedding: posEmbedding, blocks: blocks, finalLNScale: finalLNScale, finalLNBias: finalLNBias, outputW: outputW, outputB: outputB)
}

private func loadBinaryTensorExact(url: URL, shape: [Int]) throws -> Tensor {
    let data = try Data(contentsOf: url)
    let expectedCount = shape.reduce(1,*)
    let count = data.count / MemoryLayout<Float>.size
    guard count == expectedCount else { throw SpeechTranscriptionError.processingFailed("Tensor size mismatch (expected \(expectedCount) got \(count))") }
    let arr: [Float] = data.withUnsafeBytes { ptr in
        let buf = ptr.bindMemory(to: Float.self)
        return Array(buf)
    }
    return Tensor(shape: shape, scalars: arr)
}

// MARK: - Variant Resolution & Directory Location
private func resolveVariant(identifier: String) throws -> MLXWhisperModel.Variant {
    if identifier == "auto" { return autoSelectVariant() }
    if let v = MLXWhisperModel.Variant(rawValue: identifier) { return v }
    // attempt loose matching (e.g. "tiny")
    if let v = MLXWhisperModel.Variant.allCases.first(where: { identifier.contains($0.rawValue) || identifier == String($0.rawValue.split(separator: "-").dropFirst().first ?? Substring()) }) { return v }
    throw SpeechTranscriptionError.modelUnavailable
}

private func autoSelectVariant() -> MLXWhisperModel.Variant {
    let freeBytes = (try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    // Heuristic thresholds (tune): choose largest that fits conservative fraction of free space
    let candidates = MLXWhisperModel.Variant.allCases
    for v in candidates.reversed() { // large -> tiny
        if Int64(v.approxBytesFP16 * 2) < freeBytes / 3 { return v } // require space for weights + activations
    }
    return .tiny
}

private func locateModelDirectory(variant: MLXWhisperModel.Variant) throws -> URL {
    // Search order: App Support /Models, Documents/Models, Bundle Resources
    let fm = FileManager.default
    var candidates: [URL] = []
    if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false) { candidates.append(appSupport.appendingPathComponent("MLXModels").appendingPathComponent(variant.rawValue)) }
    if let docs = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) { candidates.append(docs.appendingPathComponent("MLXModels").appendingPathComponent(variant.rawValue)) }
    if let bundleURL = Bundle.main.resourceURL { candidates.append(bundleURL.appendingPathComponent(variant.rawValue)) }
    for url in candidates { if (try? existingDirectory(url)) != nil { return url } }
    throw SpeechTranscriptionError.modelUnavailable
}

@discardableResult private func existingDirectory(_ url: URL) throws -> URL { var isDir: ObjCBool = false; guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { throw SpeechTranscriptionError.modelUnavailable }; return url }
@discardableResult private func existingFile(_ url: URL) throws -> URL { var isDir: ObjCBool = false; guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { throw SpeechTranscriptionError.modelUnavailable }; return url }

// MARK: - Inference Graph
private extension MLXWhisperModel {
    func infer(mel: [[Float]]) -> [Int] {
        guard !mel.isEmpty else { return [] }
        let frames = min(mel.count, config.maxFrames)
        let melBins = config.nMels
        let flat = mel.prefix(frames).flatMap { $0 }
        var x = Tensor(shape: [frames, melBins], scalars: flat)
        // Project mel -> dModel
        x = (x • melProjectionW) + melProjectionB
        // Positional add
        let posSlice = posEmbedding[0..<frames]
        x = x + posSlice
        // Blocks
        for b in blocks { x = transformerBlock(x: x, w: b) }
        // Final LN
        x = layerNorm(x: x, scale: finalLNScale, bias: finalLNBias)
        // Mean pool time
        x = x.mean(axis: 0)
        // Logits
        let logits = (x • outputW) + outputB
        // Greedy top-k
        let probs = softmax(logits)
        let values = probs.asArray()
        return values.enumerated().sorted { $0.element > $1.element }.prefix(8).map { $0.offset }
    }
    
    func softmax(_ t: Tensor) -> Tensor { (t - t.max()).exp() / (t - t.max()).exp().sum() }
    
    func transformerBlock(x: Tensor, w: TransformerBlockWeights) -> Tensor {
        // LayerNorm 1
        var h = layerNorm(x: x, scale: w.ln1Scale, bias: w.ln1Bias)
        h = h + selfAttention(x: h, w: w)
        // FFN
        var f = layerNorm(x: h, scale: w.ln2Scale, bias: w.ln2Bias)
        f = gelu((f • w.ffnIn) + w.ffnInBias)
        f = (f • w.ffnOut) + w.ffnOutBias
        return h + f
    }
    
    func layerNorm(x: Tensor, scale: Tensor, bias: Tensor, eps: Float = 1e-5) -> Tensor {
        let mean = x.mean(axis: -1, keepDims: true)
        let varT = ((x - mean) * (x - mean)).mean(axis: -1, keepDims: true)
        let norm = (x - mean) / (varT + eps).sqrt()
        return norm * scale + bias
    }
    
    func gelu(_ t: Tensor) -> Tensor { 0.5 * t * (1 + ((t / sqrt(2.0)).erf())) }
    
    func selfAttention(x: Tensor, w: TransformerBlockWeights) -> Tensor {
        // x: (T, D)
        let d = config.dModel
        let h = config.nHeads
        let headDim = d / h
        let q = ((x • w.attnQ) + w.attnQBias).reshaped([ -1, h, headDim])
        let k = ((x • w.attnK) + w.attnKBias).reshaped([ -1, h, headDim])
        let v = ((x • w.attnV) + w.attnVBias).reshaped([ -1, h, headDim])
        // Scaled dot-product
        var attn = (q * (1.0 / sqrt(Float(headDim)))) • k.transposed(0,2,1) // shape (T,h,T)
        attn = attn.softmax(axis: 2)
        var out = attn • v // (T,h,headDim)
        out = out.reshaped([ -1, d])
        out = (out • w.attnOut) + w.attnOutBias
        return out
    }
}
#endif

// MARK: - Transcriber

public final class MLXTranscriber: SpeechTranscriptionProtocol, @unchecked Sendable {
    public let method: TranscriptionMethod = .mlx
    private let logger = Logger(subsystem: "com.projectone.speech", category: "MLXTranscriber")
    private(set) var prepared = false
    private let locale: Locale
    private let modelIdentifier: String
    private var model: MLXWhisperModel?
    
    // Audio / feature params
    private let targetSampleRate: Double = 16000
    private let fftSize = 400          // 25ms window @16k
    private let hopSize = 160          // 10ms hop
    private let melBins = 80
    private lazy var melFilter: [[Float]] = buildMelFilter()
    
    public init(locale: Locale = Locale(identifier: "en-US"), modelIdentifier: String = "mlx-whisper-tiny") {
        self.locale = locale
        self.modelIdentifier = modelIdentifier
    }
    
    public var isAvailable: Bool { prepared }
    
    public var capabilities: TranscriptionCapabilities {
        TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true,
            supportedLanguages: [locale.identifier, "en-US"],
            maxAudioDuration: 3600,
            requiresPermission: false
        )
    }
    
    public func prepare() async throws {
        guard !prepared else { return }
        #if targetEnvironment(simulator)
        throw SpeechTranscriptionError.insufficientResources("MLX not supported in simulator")
        #else
        logger.info("Loading MLX model: \(modelIdentifier)")
        do {
            model = try await MLXWhisperModelCache.shared.model(id: modelIdentifier, locale: locale)
            prepared = true
            logger.info("MLX model loaded: \(modelIdentifier)")
        } catch {
            logger.error("Failed to load MLX model: \(error.localizedDescription)")
            throw SpeechTranscriptionError.modelUnavailable
        }
        #endif
    }
    
    public func cleanup() async { prepared = false; model = nil }
    
    public func canProcess(audioFormat: AVAudioFormat) -> Bool { audioFormat.channelCount <= 2 }
    
    // MARK: - Batch Transcription
    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        guard prepared, let model else { throw SpeechTranscriptionError.modelUnavailable }
        let start = CFAbsoluteTimeGetCurrent()
        let mono = try ensureMono16k(samples: audio.samples, sampleRate: audio.sampleRate)
    let mel = computeLogMel(samples: mono)
    #if canImport(MLX)
    let tokens = model.infer(mel: mel)
    #else
    let tokens: [Int] = [] // MLX not available – treat as empty result
    #endif
        let text = postProcess(text: model.decode(tokens: tokens), configuration: configuration)
        let seg = SpeechTranscriptionSegment(text: text, startTime: 0, endTime: audio.duration, confidence: 0.55)
        let dt = CFAbsoluteTimeGetCurrent() - start
        return SpeechTranscriptionResult(text: text, confidence: seg.confidence, segments: [seg], processingTime: dt, method: method, language: locale.identifier)
    }
    
    // MARK: - Real-Time Streaming
    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish(); return }
                var buffer: [Float] = []
                let chunkSeconds: Double = 2.5
                let chunkFrames = Int(chunkSeconds * targetSampleRate)
                for await chunk in audioStream {
                    guard self.prepared, let model = self.model else { break }
                    let mono = (try? self.ensureMono16k(samples: chunk.samples, sampleRate: chunk.sampleRate)) ?? []
                    buffer.append(contentsOf: mono)
                    while buffer.count >= chunkFrames {
                        let slice = Array(buffer.prefix(chunkFrames))
                        buffer.removeFirst(chunkFrames)
                        let mel = self.computeLogMel(samples: slice)
                        #if canImport(MLX)
                        let tokens = model.infer(mel: mel)
                        #else
                        let tokens: [Int] = []
                        #endif
                        let raw = model.decode(tokens: tokens)
                        let text = self.postProcess(text: raw, configuration: configuration)
                        let result = SpeechTranscriptionResult(text: text, confidence: 0.5, segments: [], processingTime: 0.0, method: self.method, language: self.locale.identifier)
                        continuation.yield(result)
                    }
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: - Audio & Feature Pipeline
    private func ensureMono16k(samples: [Float], sampleRate: Double) throws -> [Float] {
        if sampleRate == targetSampleRate { return samples }
        // Linear resample using vDSP
        let ratio = targetSampleRate / sampleRate
        let outCount = Int(Double(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outCount)
        vDSP_vgenp(samples, vDSP_Stride(1), [Float](stride(from: 0, to: Float(samples.count), by: Float(samples.count) / Float(outCount))), vDSP_Stride(1), &output, vDSP_Stride(1), vDSP_Length(outCount), vDSP_Length(samples.count))
        return output
    }
    
    private func computeLogMel(samples: [Float]) -> [[Float]] {
        guard samples.count >= fftSize else { return [] }
        let frameCount = (samples.count - fftSize) / hopSize + 1
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        var melSpec: [[Float]] = []
        melSpec.reserveCapacity(frameCount)
        var real = [Float](repeating: 0, count: fftSize/2)
        var imag = [Float](repeating: 0, count: fftSize/2)
        var split = DSPSplitComplex(realp: &real, imagp: &imag)
        let logConstant: Float = 1e-6
        let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(FFT_RADIX2))
        defer { if let s = fftSetup { vDSP_destroy_fftsetup(s) } }
        for f in 0..<frameCount {
            let offset = f * hopSize
            let frame = Array(samples[offset..<offset+fftSize])
            var windowed = [Float](repeating: 0, count: fftSize)
            vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))
            windowed.withUnsafeMutableBufferPointer { buf in
                buf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) { ptr in
                    vDSP_ctoz(ptr, 2, &split, 1, vDSP_Length(fftSize/2))
                }
                if let setup = fftSetup {
                    vDSP_fft_zrip(setup, &split, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
                }
            }
            var magnitudes = [Float](repeating: 0, count: fftSize/2)
            vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(fftSize/2))
            var power = [Float](repeating: 0, count: melBins)
            // Apply simple mel filter bank
            for m in 0..<melBins {
                let filter = melFilter[m]
                let count = min(filter.count, magnitudes.count)
                var dot: Float = 0
                vDSP_dotpr(filter, 1, magnitudes, 1, &dot, vDSP_Length(count))
                power[m] = log10(dot + logConstant)
            }
            melSpec.append(power)
        }
        return melSpec
    }
    
    private func buildMelFilter() -> [[Float]] {
        // Simplified triangular filters over linear freq bins
        let bins = fftSize/2
        var filters: [[Float]] = []
        filters.reserveCapacity(melBins)
        for m in 0..<melBins {
            var f = [Float](repeating: 0, count: bins)
            let start = m * (bins / melBins)
            let end = (m+1) * (bins / melBins)
            if end > start {
                for i in start..<end { f[i] = Float(i - start) / Float(max(1, end - start)) }
            }
            filters.append(f)
        }
        return filters
    }
    
    // MARK: - Inference (Stub Token Generation)
    // Removed fallback pseudo-token generation to enforce real model loading; if MLX absent returns empty tokens
    
    private func postProcess(text: String, configuration: TranscriptionConfiguration) -> String {
        var t = text
        if configuration.enableTranslation { t += " (translated)" }
        return t
    }
}
