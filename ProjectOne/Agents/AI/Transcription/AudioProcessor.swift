//
//  AudioProcessor.swift
//  ProjectOne
//
//  Created by Claude on 7/11/25.
//

import Foundation
@preconcurrency import AVFoundation
import Accelerate
import os.log

/// Audio processing utilities for speech transcription
public class AudioProcessor: AudioProcessingProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.projectone.speech", category: "AudioProcessor")
    
    public let supportedFormats: [AVAudioFormat]
    public let preferredFormat: AVAudioFormat
    
    // MARK: - Initialization
    
    public init() {
        // Define supported formats for speech recognition
        let formats = [
            AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!, // Standard speech recognition
            AVAudioFormat(standardFormatWithSampleRate: 22050, channels: 1)!, // High quality mono
            AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!, // CD quality mono
            AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!, // Professional mono
            AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!, // CD quality stereo
            AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!  // Professional stereo
        ]
        
        self.supportedFormats = formats
        self.preferredFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)! // Optimal for speech
        
        logger.info("AudioProcessor initialized with \(self.supportedFormats.count) supported formats")
    }
    
    // MARK: - AudioProcessingProtocol Methods
    
    public func preprocess(audio: AudioData) throws -> ProcessedAudioData {
        logger.debug("Preprocessing audio data")
        
        guard let pcmBuffer = audio.audioBuffer as? AVAudioPCMBuffer else {
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        guard let channelData = pcmBuffer.floatChannelData else {
            throw SpeechTranscriptionError.processingFailed("No channel data available")
        }
        
        let frameLength = Int(pcmBuffer.frameLength)
        let channelCount = Int(pcmBuffer.format.channelCount)
        
        var samples: [Float] = []
        
        // Convert to mono if necessary and extract samples
        if channelCount == 1 {
            // Mono audio - direct copy
            let channel = channelData[0]
            samples = Array(UnsafeBufferPointer(start: channel, count: frameLength))
        } else {
            // Stereo or multi-channel - convert to mono by averaging
            samples = Array(repeating: 0.0, count: frameLength)
            
            for frame in 0..<frameLength {
                var sum: Float = 0.0
                for channel in 0..<channelCount {
                    sum += channelData[channel][frame]
                }
                samples[frame] = sum / Float(channelCount)
            }
        }
        
        // Apply basic noise reduction and normalization
        let processedSamples = try applyAudioEnhancements(samples: samples)
        
        return ProcessedAudioData(
            samples: processedSamples,
            sampleRate: audio.format.sampleRate,
            channels: 1, // Always output mono for speech recognition
            duration: audio.duration
        )
    }
    
    public func normalize(audio: AudioData) throws -> AudioData {
        logger.debug("Normalizing audio levels")
        
        guard let pcmBuffer = audio.audioBuffer as? AVAudioPCMBuffer else {
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        // Create a copy of the buffer for normalization
        guard let normalizedBuffer = AVAudioPCMBuffer(pcmFormat: pcmBuffer.format, frameCapacity: pcmBuffer.frameCapacity) else {
            throw SpeechTranscriptionError.processingFailed("Failed to create normalized buffer")
        }
        
        normalizedBuffer.frameLength = pcmBuffer.frameLength
        
        guard let sourceChannelData = pcmBuffer.floatChannelData,
              let destChannelData = normalizedBuffer.floatChannelData else {
            throw SpeechTranscriptionError.processingFailed("Failed to access channel data")
        }
        
        let frameLength = Int(pcmBuffer.frameLength)
        let channelCount = Int(pcmBuffer.format.channelCount)
        
        // Find peak amplitude across all channels
        var peak: Float = 0.0
        for channel in 0..<channelCount {
            var channelPeak: Float = 0.0
            vDSP_maxmgv(sourceChannelData[channel], 1, &channelPeak, vDSP_Length(frameLength))
            peak = max(peak, channelPeak)
        }
        
        // Calculate normalization factor (target peak of 0.8 to avoid clipping)
        let targetPeak: Float = 0.8
        var normalizationFactor = peak > 0 ? targetPeak / peak : 1.0
        
        // Apply normalization to all channels
        for channel in 0..<channelCount {
            vDSP_vsmul(
                sourceChannelData[channel], 1,
                &normalizationFactor,
                destChannelData[channel], 1,
                vDSP_Length(frameLength)
            )
        }
        
        logger.debug("Audio normalized with factor: \(normalizationFactor)")
        
        return AudioData(
            buffer: normalizedBuffer,
            format: pcmBuffer.format,
            duration: audio.duration
        )
    }
    
    public func convert(audio: AudioData, to format: AVAudioFormat) throws -> AudioData {
        logger.debug("Converting audio from \(audio.format.sampleRate)Hz to \(format.sampleRate)Hz")
        
        guard let inputBuffer = audio.audioBuffer as? AVAudioPCMBuffer else {
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        // If formats are the same, return original
        if audio.format.isEqual(format) {
            return audio
        }
        
        // Create audio converter
        guard let converter = AVAudioConverter(from: audio.format, to: format) else {
            throw SpeechTranscriptionError.processingFailed("Failed to create audio converter")
        }
        
        // Calculate output buffer size
        let inputFrameCount = inputBuffer.frameLength
        let outputFrameCount = AVAudioFrameCount(Double(inputFrameCount) * format.sampleRate / audio.format.sampleRate)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCount) else {
            throw SpeechTranscriptionError.processingFailed("Failed to create output buffer")
        }
        
        // Perform conversion
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }
        
        if let error = error {
            throw SpeechTranscriptionError.processingFailed("Audio conversion failed: \(error.localizedDescription)")
        }
        
        let newDuration = Double(outputBuffer.frameLength) / format.sampleRate
        
        logger.debug("Audio converted successfully: \(inputFrameCount) -> \(outputBuffer.frameLength) frames")
        
        return AudioData(
            buffer: outputBuffer,
            format: format,
            duration: newDuration
        )
    }
    
    // MARK: - Private Methods
    
    private func applyAudioEnhancements(samples: [Float]) throws -> [Float] {
        var enhancedSamples = samples
        
        // Apply high-pass filter to remove low-frequency noise
        enhancedSamples = try applyHighPassFilter(samples: enhancedSamples, cutoffFrequency: 80.0)
        
        // Apply dynamic range compression for consistent levels
        enhancedSamples = try applyCompression(samples: enhancedSamples)
        
        // Apply gentle noise gate to remove very quiet background noise
        enhancedSamples = try applyNoiseGate(samples: enhancedSamples, threshold: -60.0)
        
        return enhancedSamples
    }
    
    private func applyHighPassFilter(samples: [Float], cutoffFrequency: Float) throws -> [Float] {
        // Simple high-pass filter implementation
        // In a production app, you might use vDSP or Accelerate framework for better performance
        
        let sampleRate: Float = 16000.0 // Assuming 16kHz sample rate
        let rc = 1.0 / (cutoffFrequency * 2.0 * Float.pi)
        let dt = 1.0 / sampleRate
        let alpha = rc / (rc + dt)
        
        var filteredSamples = Array(repeating: Float(0.0), count: samples.count)
        var previousInput: Float = 0.0
        var previousOutput: Float = 0.0
        
        for i in 0..<samples.count {
            let currentInput = samples[i]
            let currentOutput = alpha * (previousOutput + currentInput - previousInput)
            filteredSamples[i] = currentOutput
            
            previousInput = currentInput
            previousOutput = currentOutput
        }
        
        return filteredSamples
    }
    
    private func applyCompression(samples: [Float]) throws -> [Float] {
        // Simple dynamic range compression
        let threshold: Float = 0.7
        let ratio: Float = 4.0 // 4:1 compression ratio
        
        return samples.map { sample in
            let absValue = abs(sample)
            if absValue > threshold {
                let excess = absValue - threshold
                let compressedExcess = excess / ratio
                let newAbsValue = threshold + compressedExcess
                return sample < 0 ? -newAbsValue : newAbsValue
            }
            return sample
        }
    }
    
    private func applyNoiseGate(samples: [Float], threshold: Float) throws -> [Float] {
        // Convert dB threshold to linear scale
        let linearThreshold = pow(10.0, threshold / 20.0)
        
        return samples.map { sample in
            return abs(sample) > linearThreshold ? sample : 0.0
        }
    }
}

// MARK: - Utility Extensions

extension AudioProcessor {
    
    /// Check if a format is optimal for speech recognition
    public func isOptimalForSpeech(_ format: AVAudioFormat) -> Bool {
        // Speech recognition works best with:
        // - Sample rates between 16kHz and 48kHz
        // - Mono or stereo
        // - PCM format
        
        let optimalSampleRates: [Double] = [16000, 22050, 44100, 48000]
        
        return optimalSampleRates.contains(format.sampleRate) &&
               format.channelCount <= 2 &&
               format.isStandard
    }
    
    /// Get the recommended format for the given input format
    public func getRecommendedFormat(for inputFormat: AVAudioFormat) -> AVAudioFormat {
        // If input is already optimal, return it
        if isOptimalForSpeech(inputFormat) {
            return inputFormat
        }
        
        // Choose optimal sample rate
        let targetSampleRate: Double
        if inputFormat.sampleRate < 16000 {
            targetSampleRate = 16000
        } else if inputFormat.sampleRate > 48000 {
            targetSampleRate = 48000
        } else {
            // Find the closest optimal rate
            let optimalRates: [Double] = [16000, 22050, 44100, 48000]
            targetSampleRate = optimalRates.min { abs($0 - inputFormat.sampleRate) < abs($1 - inputFormat.sampleRate) } ?? 16000
        }
        
        // Prefer mono for speech recognition
        let targetChannels: UInt32 = min(inputFormat.channelCount, 1)
        
        return AVAudioFormat(standardFormatWithSampleRate: targetSampleRate, channels: targetChannels)!
    }
}