@preconcurrency import AVFoundation
import Foundation
import os.log
import Speech

#if canImport(UIKit)
import UIKit
#endif

@available(iOS 26.0, macOS 26.0, *)
public class SpeechAnalyzerTranscriber: NSObject, SpeechTranscriptionProtocol {
    private let logger = Logger(subsystem: "com.projectone.speech", category: "SpeechAnalyzerTranscriber")
    private var locale: Locale
    
    // Memory safety: Strong references to prevent deallocation during async operations
    private var currentAnalyzer: SpeechAnalyzer?
    private var currentTranscriber: SpeechTranscriber?
    private var analysisTask: Task<Void, Never>?
    private let accessQueue = DispatchQueue(label: "SpeechAnalyzerTranscriber.access", qos: .userInitiated)

    public let method: TranscriptionMethod = .speechAnalyzer

    public var isAvailable: Bool {
        return true
    }

    public var capabilities: TranscriptionCapabilities {
        TranscriptionCapabilities(
            supportsRealTime: true,
            supportsBatch: true,
            supportsOffline: true,
            supportedLanguages: [locale.identifier],
            maxAudioDuration: 3600,
            requiresPermission: true
        )
    }

    public init(locale: Locale = Locale(identifier: "en-US")) {
        // Normalize locale identifier to use underscores for SpeechTranscriber compatibility
        let normalizedIdentifier = locale.identifier.replacingOccurrences(of: "-", with: "_")
        self.locale = Locale(identifier: normalizedIdentifier)
        super.init()
    }

    public func prepare() async throws {
        logger.info("🚀 Preparing SpeechAnalyzer - checking permissions and model availability")
        
        // 1. Request Speech Recognition Authorization (required for SpeechAnalyzer)
        logger.info("🔐 Checking speech recognition authorization...")
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        logger.info("Current speech recognition status: \(authStatus.rawValue)")
        
        if authStatus != .authorized {
            logger.info("🔓 Requesting speech recognition authorization...")
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
        
        // 2. Request Microphone Authorization (likely required for live transcription)
        #if canImport(UIKit)
        logger.info("🎤 Checking microphone authorization...")
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        logger.info("Current microphone status: \(micStatus.rawValue)")
        
        if micStatus != .granted {
            logger.info("🔓 Requesting microphone authorization...")
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            
            guard granted else {
                logger.error("❌ Microphone authorization denied")
                throw SpeechTranscriptionError.permissionDenied
            }
            logger.info("✅ Microphone authorization granted")
        } else {
            logger.info("✅ Microphone already authorized")
        }
        #endif
        
        // 3. Check model availability using iOS 26.0 AssetInventory
        logger.info("📦 Checking model availability for locale: \(self.locale.identifier)")
        
        do {
            // Check if the required locale is supported
            let supportedLocales = await SpeechTranscriber.supportedLocales
            let installedLocales = await SpeechTranscriber.installedLocales
            
            logger.info("Supported locales: \(supportedLocales.map { $0.identifier })")
            logger.info("Installed locales: \(installedLocales.map { $0.identifier })")
            
            // If no locales are found, this might be a simulator/setup issue
            if supportedLocales.isEmpty {
                logger.warning("⚠️ No supported locales found by SpeechTranscriber")
                logger.warning("🔍 This might be a simulator limitation or model setup issue")
                logger.warning("🚀 Attempting to proceed anyway - SpeechAnalyzer might still work")
            } else {
                // Check if our specific locale is supported
                guard supportedLocales.contains(self.locale) else {
                    logger.error("❌ Locale \(self.locale.identifier) not supported by SpeechTranscriber")
                    logger.error("📝 Available locales: \(supportedLocales.map { $0.identifier }.joined(separator: ", "))")
                    
                    // Try to find a similar locale as fallback
                    if let fallbackLocale = supportedLocales.first(where: { $0.languageCode == self.locale.languageCode }) {
                        logger.info("🔄 Found fallback locale: \(fallbackLocale.identifier)")
                        // We could update self.locale here, but let's try the original first
                    }
                    
                    throw SpeechTranscriptionError.configurationInvalid
                }
                
                if !installedLocales.contains(self.locale) {
                    logger.warning("⚠️ Locale \(self.locale.identifier) supported but not installed locally")
                    logger.warning("📡 This will require network for transcription")
                } else {
                    logger.info("✅ Locale models installed locally - offline transcription available")
                }
            }
        } catch {
            logger.error("❌ Failed to query SpeechTranscriber locales: \(error)")
            logger.warning("🚀 Attempting to proceed anyway - might work despite locale check failure")
        }
        
        logger.info("🎉 SpeechAnalyzer preparation completed successfully")
    }

    public func cleanup() async {
        logger.info("🧹 Starting SpeechAnalyzer cleanup")
        
        // Cancel any ongoing analysis task first
        analysisTask?.cancel()
        analysisTask = nil
        
        // Use dispatch queue to safely clear references
        await withCheckedContinuation { continuation in
            accessQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                // Clear strong references to prevent memory leaks
                self.currentAnalyzer = nil
                self.currentTranscriber = nil
                
                self.logger.info("✅ SpeechAnalyzer cleanup completed")
                continuation.resume()
            }
        }
    }

    public func canProcess(audioFormat: AVAudioFormat) -> Bool {
        return true
    }

    public func transcribe(audio: AudioData, configuration: TranscriptionConfiguration) async throws -> SpeechTranscriptionResult {
        logger.info("Starting SpeechAnalyzer batch transcription")
        
        let startTime = Date()
        let useLocale: Locale
        if let configLanguage = configuration.language {
            // Normalize locale identifier for SpeechTranscriber compatibility
            let normalizedIdentifier = configLanguage.replacingOccurrences(of: "-", with: "_")
            useLocale = Locale(identifier: normalizedIdentifier)
        } else {
            useLocale = self.locale
        }

        // Always create fresh analyzer for each transcription (SpeechAnalyzer can only be used once)
        logger.info("Creating fresh SpeechAnalyzer for transcription with locale: \(useLocale.identifier)")
        
        // Use memory-safe creation within access queue
        let (freshTranscriber, freshAnalyzer): (SpeechTranscriber, SpeechAnalyzer) = try await withCheckedThrowingContinuation { continuation in
            accessQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SpeechTranscriptionError.processingFailed("SpeechAnalyzerTranscriber was deallocated"))
                    return
                }
                
                do {
                    self.logger.info("🔧 Creating SpeechTranscriber with locale: \(useLocale.identifier)")
                    
                    let transcriber = SpeechTranscriber(locale: useLocale, preset: .transcription)
                    self.logger.info("✅ SpeechTranscriber created successfully")
                    self.logger.info("📡 SpeechTranscriber properties:")
                    self.logger.info("  - Target locale: \(useLocale.identifier)")
                    self.logger.info("  - Preset: .transcription")
                    
                    self.logger.info("🔧 Creating SpeechAnalyzer with SpeechTranscriber module...")
                    let analyzer = SpeechAnalyzer(modules: [transcriber])
                    self.logger.info("✅ SpeechAnalyzer created successfully")
                    self.logger.info("📡 SpeechAnalyzer configured with \(1) module(s)")
                    
                    // Store strong references to prevent deallocation
                    self.currentTranscriber = transcriber
                    self.currentAnalyzer = analyzer
                    
                    continuation.resume(returning: (transcriber, analyzer))
                } catch {
                    self.logger.error("❌ Failed to create SpeechAnalyzer components: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Use standard 16kHz format optimal for speech recognition
        let optimalFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, 
                                        sampleRate: 16000, 
                                        channels: 1, 
                                        interleaved: true)!
        logger.info("Using standard optimal format for SpeechAnalyzer: \(optimalFormat)")
        logger.info("Current audio format: \(audio.format)")
        
        // Configure audio session for SpeechAnalyzer (platform-specific)
        #if canImport(UIKit)
        logger.info("🎧 Configuring iOS audio session for SpeechAnalyzer...")
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .allowBluetooth])
            try audioSession.setActive(true)
            logger.info("✅ iOS audio session configured and activated")
            logger.info("📡 iOS audio session details:")
            logger.info("  - Category: \(audioSession.category.rawValue)")
            logger.info("  - Mode: \(audioSession.mode.rawValue)")
            logger.info("  - Sample rate: \(audioSession.sampleRate)Hz")
            logger.info("  - Input available: \(audioSession.isInputAvailable)")
            logger.info("  - Input gain settable: \(audioSession.isInputGainSettable)")
        } catch {
            logger.warning("⚠️ Failed to configure iOS audio session: \(error)")
            logger.warning("Continuing anyway - SpeechAnalyzer might still work...")
        }
        #else
        logger.info("🎧 Running on macOS - audio session configuration not required")
        logger.info("📡 macOS audio system should handle microphone access automatically")
        #endif
        
        // Prepare the fresh analyzer with optimal format context
        do {
            try await freshAnalyzer.prepareToAnalyze(in: optimalFormat)
            logger.info("✅ Fresh SpeechAnalyzer created and prepared successfully with optimal format")
        } catch {
            logger.error("❌ Failed to prepare SpeechAnalyzer: \(error)")
            if let nsError = error as NSError? {
                logger.error("Prepare NSError domain: \(nsError.domain), code: \(nsError.code)")
                logger.error("Prepare NSError userInfo: \(nsError.userInfo)")
            }
            throw SpeechTranscriptionError.processingFailed("Failed to prepare SpeechAnalyzer: \(error.localizedDescription)")
        }

        // Validate and convert audio buffer
        guard let audioBuffer = audio.audioBuffer as? AVAudioPCMBuffer else {
            logger.error("Audio buffer is not AVAudioPCMBuffer, type: \(type(of: audio.audioBuffer))")
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        logger.info("🔍 Original audio buffer analysis:")
        logger.info("  - Frame length: \(audioBuffer.frameLength)")
        logger.info("  - Format: \(audioBuffer.format)")
        
        // Validate original audio content
        if let originalChannelData = audioBuffer.floatChannelData {
            let originalSamples = Array(UnsafeBufferPointer(start: originalChannelData[0], count: Int(audioBuffer.frameLength)))
            let originalMax = originalSamples.map(abs).max() ?? 0.0
            let originalNonZero = originalSamples.filter { abs($0) > 0.001 }.count
            logger.info("🔊 Original audio content:")
            logger.info("  - Max amplitude: \(originalMax)")
            logger.info("  - Non-zero samples: \(originalNonZero)/\(originalSamples.count)")
            logger.info("  - First 5 samples: \(Array(originalSamples.prefix(5)))")
            
            if originalMax < 0.001 {
                logger.error("❌ Original audio buffer is already silent!")
                throw SpeechTranscriptionError.processingFailed("Original audio contains no content")
            }
        } else if let originalInt16Data = audioBuffer.int16ChannelData {
            let originalSamples = Array(UnsafeBufferPointer(start: originalInt16Data[0], count: Int(audioBuffer.frameLength)))
            let originalMax = originalSamples.map(abs).max() ?? 0
            logger.info("🔊 Original int16 audio content: max=\(originalMax)")
            
            if originalMax == 0 {
                logger.error("❌ Original int16 audio buffer is already silent!")
                throw SpeechTranscriptionError.processingFailed("Original audio contains no content")
            }
        } else {
            logger.warning("⚠️ Cannot validate original audio content - no accessible channel data")
        }
        
        // Validate format compatibility
        guard canProcess(audioFormat: audioBuffer.format) else {
            logger.error("Audio format not compatible with SpeechAnalyzer")
            throw SpeechTranscriptionError.audioFormatUnsupported
        }
        
        // Check for empty buffer
        if audioBuffer.frameLength == 0 {
            logger.warning("Audio buffer is empty (frameLength = 0)")
            throw SpeechTranscriptionError.processingFailed("Audio buffer is empty")
        }

        // Convert to optimal format determined by SpeechAnalyzer
        logger.info("Converting audio to optimal format for SpeechAnalyzer")
        let optimalBuffer: AVAudioPCMBuffer
        
        if audioBuffer.format.isEqual(optimalFormat) {
            // Already in optimal format
            optimalBuffer = audioBuffer
            logger.info("Audio already in optimal format")
        } else {
            // Convert to optimal format using framework guidance
            logger.info("Converting from \(audioBuffer.format) to optimal \(optimalFormat)")
            
            guard let converter = AVAudioConverter(from: audioBuffer.format, to: optimalFormat) else {
                logger.error("Failed to create audio converter for optimal format")
                throw SpeechTranscriptionError.processingFailed("Failed to create audio converter for optimal format")
            }
            
            let outputFrameCount = AVAudioFrameCount(Double(audioBuffer.frameLength) * optimalFormat.sampleRate / audioBuffer.format.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: optimalFormat, frameCapacity: outputFrameCount) else {
                logger.error("Failed to create output buffer for optimal format")
                throw SpeechTranscriptionError.processingFailed("Failed to create output buffer for optimal format")
            }
            
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = AVAudioConverterInputStatus.haveData
                return audioBuffer
            }
            
            // Validate converted audio content immediately
            logger.info("🔍 Post-conversion validation:")
            if let convertedChannelData = convertedBuffer.floatChannelData {
                let convertedSamples = Array(UnsafeBufferPointer(start: convertedChannelData[0], count: Int(convertedBuffer.frameLength)))
                let convertedMax = convertedSamples.map(abs).max() ?? 0.0
                let convertedNonZero = convertedSamples.filter { abs($0) > 0.001 }.count
                logger.info("🔊 Converted float audio content:")
                logger.info("  - Max amplitude: \(convertedMax)")
                logger.info("  - Non-zero samples: \(convertedNonZero)/\(convertedSamples.count)")
                logger.info("  - First 5 samples: \(Array(convertedSamples.prefix(5)))")
                
                if convertedMax < 0.001 {
                    logger.error("❌ Audio conversion resulted in silent buffer!")
                }
            } else if let convertedInt16Data = convertedBuffer.int16ChannelData {
                let convertedSamples = Array(UnsafeBufferPointer(start: convertedInt16Data[0], count: Int(convertedBuffer.frameLength)))
                let convertedMax = convertedSamples.map(abs).max() ?? 0
                let convertedNonZero = convertedSamples.filter { abs($0) > 0 }.count
                logger.info("🔊 Converted int16 audio content:")
                logger.info("  - Max value: \(convertedMax)")
                logger.info("  - Non-zero samples: \(convertedNonZero)/\(convertedSamples.count)")
                logger.info("  - First 5 samples: \(Array(convertedSamples.prefix(5)))")
                
                if convertedMax == 0 {
                    logger.error("❌ Audio conversion resulted in silent int16 buffer!")
                }
            } else {
                logger.error("❌ Cannot validate converted audio - no accessible channel data")
            }
            
            if let error = error {
                logger.error("Audio conversion to optimal format failed: \(error.localizedDescription)")
                throw SpeechTranscriptionError.processingFailed("Audio conversion to optimal format failed: \(error.localizedDescription)")
            }
            
            optimalBuffer = convertedBuffer
            logger.info("Successfully converted to optimal format")
            logger.info("Original: \(audioBuffer.frameLength) frames -> Converted: \(optimalBuffer.frameLength) frames")
        }

        // Validate audio buffer content before creating input stream
        logger.info("🔍 Validating audio buffer content before SpeechAnalyzer processing")
        
        #if os(macOS)
        logger.info("🍎 macOS-specific audio buffer analysis")
        #else
        logger.info("📱 iOS-specific audio buffer analysis")
        #endif
        
        if let channelData = optimalBuffer.floatChannelData {
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(optimalBuffer.frameLength)))
            let maxAmplitude = samples.map(abs).max() ?? 0.0
            let avgAmplitude = samples.map(abs).reduce(0, +) / Float(samples.count)
            let nonZeroSamples = samples.filter { abs($0) > 0.001 }.count
            let significantSamples = samples.filter { abs($0) > 0.01 }.count // Higher threshold for speech
            
            logger.info("📊 Audio buffer analysis:")
            #if os(macOS)
            logger.info("  - Platform: macOS")
            #else
            logger.info("  - Platform: iOS")
            #endif
            logger.info("  - Frame length: \(optimalBuffer.frameLength)")
            logger.info("  - Channel count: \(optimalBuffer.format.channelCount)")
            logger.info("  - Sample rate: \(optimalBuffer.format.sampleRate)Hz")
            logger.info("  - Format: \(optimalBuffer.format.commonFormat.rawValue)")
            logger.info("  - Max amplitude: \(maxAmplitude)")
            logger.info("  - Avg amplitude: \(avgAmplitude)")
            logger.info("  - Non-zero samples: \(nonZeroSamples)/\(samples.count) (\(Float(nonZeroSamples)/Float(samples.count)*100)%)")
            logger.info("  - Significant samples (>0.01): \(significantSamples)/\(samples.count) (\(Float(significantSamples)/Float(samples.count)*100)%)")
            logger.info("  - First 10 samples: \(Array(samples.prefix(10)))")
            logger.info("  - Last 10 samples: \(Array(samples.suffix(10)))")
            
            // More lenient check for macOS in case the audio is quieter
            let silenceThreshold: Float = 0.0001 // Very low threshold
            if maxAmplitude < silenceThreshold {
                logger.warning("⚠️ Audio buffer appears to be completely silent (max: \(maxAmplitude))")
                #if os(macOS)
                logger.warning("🍎 macOS: This might be normal if audio is very quiet - continuing anyway")
                #else
                throw SpeechTranscriptionError.processingFailed("Audio buffer contains no meaningful audio data")
                #endif
            }
            
            if nonZeroSamples < samples.count / 20 { // More lenient threshold
                logger.warning("⚠️ Audio buffer is mostly silence (less than 5% non-zero samples)")
                #if os(macOS)
                logger.warning("🍎 macOS: Continuing with potentially quiet audio")
                #endif
            }
        } else {
            logger.error("❌ Cannot access float channel data for audio validation")
            
            // Try alternative channel data access
            if let int16Data = optimalBuffer.int16ChannelData {
                logger.info("🔄 Trying int16 channel data instead...")
                let samples = Array(UnsafeBufferPointer(start: int16Data[0], count: Int(optimalBuffer.frameLength)))
                let maxValue = samples.map(abs).max() ?? 0
                logger.info("📊 Int16 audio analysis: max=\(maxValue), samples=\(samples.count)")
            }
        }
        
        logger.info("Creating input stream for SpeechAnalyzer with optimal format buffer")
        let inputStream = AsyncStream<AnalyzerInput> { continuation in
            logger.info("📤 Yielding AnalyzerInput with buffer: \(optimalBuffer.frameLength) frames")
            
            let analyzerInput = AnalyzerInput(buffer: optimalBuffer)
            logger.info("✅ AnalyzerInput created successfully")
            
            continuation.yield(analyzerInput)
            logger.info("📤 AnalyzerInput yielded to stream")
            
            continuation.finish()
            logger.info("✅ Input stream finished")
        }

        do {
            logger.info("Starting fresh SpeechAnalyzer processing")
            
            // Add try-catch around the start operation for better diagnostics
            logger.info("🚀 Starting SpeechAnalyzer with input stream...")
            
            do {
                try await freshAnalyzer.start(inputSequence: inputStream)
                logger.info("✅ SpeechAnalyzer.start() completed successfully")
                
                // Give a moment for the analyzer to begin processing
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                logger.info("🔍 SpeechAnalyzer should now be processing audio...")
                
            } catch {
                logger.error("❌ SpeechAnalyzer.start() failed: \(error)")
                logger.error("Start error type: \(type(of: error))")
                if let nsError = error as NSError? {
                    logger.error("Start NSError domain: \(nsError.domain), code: \(nsError.code)")
                    logger.error("Start NSError userInfo: \(nsError.userInfo)")
                }
                throw error
            }
            
            // Wait for results with timeout and memory safety
            let timeoutDuration: TimeInterval = 30.0
            
            // Store analysis task to prevent deallocation
            let result: SpeechTranscriptionResult = try await withCheckedThrowingContinuation { continuation in
                let analysisTask = Task { [weak self] in
                    guard let self = self else {
                        continuation.resume(throwing: SpeechTranscriptionError.processingFailed("SpeechAnalyzerTranscriber was deallocated during transcription"))
                        return
                    }
                    
                    do {
                        let result = try await withThrowingTaskGroup(of: SpeechTranscriptionResult.self) { group in
                            
                            // Task 1: Wait for transcription results with strong reference capture
                            group.addTask { [freshTranscriber, logger = self.logger] in
                                // Wait for final result by iterating through results
                                logger.info("🎯 Starting to monitor SpeechTranscriber results stream")
                                logger.info("📡 SpeechTranscriber details:")
                                logger.info("  - Target locale: \(useLocale.identifier)")
                                logger.info("  - Preset: .transcription")
                                
                                do {
                                    var resultCount = 0
                                    logger.info("🔄 Starting to iterate over SpeechTranscriber results...")
                                    
                                    for try await result in freshTranscriber.results {
                                        // Check if task was cancelled
                                        try Task.checkCancellation()
                                        
                                        resultCount += 1
                                        let resultText = "\(result.text)"
                                        logger.info("📨 Received result #\(resultCount): isFinal=\(result.isFinal), text='\(String(resultText.prefix(50)))...'")
                                        
                                        if result.isFinal {
                                            let processingTime = Date().timeIntervalSince(startTime)
                                            
                                            // Extract confidence - SpeechTranscriber.Result may not have segments property
                                            let confidence: Float = 0.8 // Default confidence for SpeechAnalyzer
                                            
                                            let resultText = "\(result.text)"
                                            logger.info("SpeechAnalyzer transcription completed: '\(String(resultText.prefix(50)))...'")
                                            logger.info("Confidence: \(confidence), Processing time: \(processingTime)s")
                                            
                                            return await MainActor.run {
                                                SpeechTranscriptionResult(
                                                    text: resultText,
                                                    confidence: confidence,
                                                    processingTime: processingTime,
                                                    method: .speechAnalyzer,
                                                    language: useLocale.identifier
                                                )
                                            }
                                        }
                                    }
                                    
                                    // If we get here, the stream ended without final result
                                    logger.warning("⚠️ Results stream ended without final result (received \(resultCount) partial results)")
                                    logger.warning("🔍 Possible causes:")
                                    logger.warning("  - Audio doesn't contain recognizable speech")
                                    logger.warning("  - SpeechTranscriber configuration issue")
                                    logger.warning("  - Audio format not properly supported")
                                    logger.warning("  - Insufficient audio duration for processing")
                                    throw SpeechTranscriptionError.processingFailed("No final transcription result received (got \(resultCount) partial results)")
                                    
                                } catch is CancellationError {
                                    logger.info("🚫 Results monitoring was cancelled")
                                    throw SpeechTranscriptionError.processingFailed("Transcription was cancelled")
                                } catch {
                                    logger.error("Error monitoring results stream: \(error)")
                                    throw error
                                }
                            }
                            
                            // Task 2: Timeout handler
                            group.addTask {
                                try await Task.sleep(nanoseconds: UInt64(timeoutDuration * 1_000_000_000))
                                throw SpeechTranscriptionError.processingFailed("SpeechAnalyzer transcription timeout after \(timeoutDuration)s")
                            }
                            
                            // Return first completed result, cancel others
                            for try await result in group {
                                group.cancelAll()
                                return result
                            }
                            
                            // This should never be reached
                            throw SpeechTranscriptionError.processingFailed("Unexpected transcription completion")
                        }
                        
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                
                // Store task reference to prevent deallocation
                self.analysisTask = analysisTask
            }
            
            return result
            
        } catch {
            logger.error("SpeechAnalyzer transcription failed: \(error)")
            logger.error("Error type: \(type(of: error))")
            logger.error("Error localized description: \(error.localizedDescription)")
            
            // Enhanced error diagnostics
            if let nsError = error as NSError? {
                logger.error("NSError domain: \(nsError.domain)")
                logger.error("NSError code: \(nsError.code)")
                logger.error("NSError userInfo: \(nsError.userInfo)")
            }
            
            // Check for specific SpeechAnalyzer errors
            let errorMessage = error.localizedDescription
            if errorMessage.contains("Speech") || errorMessage.contains("Analyzer") {
                throw SpeechTranscriptionError.processingFailed("SpeechAnalyzer error: \(errorMessage)")
            }
            
            // Log more context about the failure state
            logger.error("Failed with locale: \(useLocale.identifier)")
            logger.error("Audio buffer format when failed: \(optimalBuffer.format)")
            logger.error("Audio buffer frame length when failed: \(optimalBuffer.frameLength)")
            
            throw error
        }
    }

    public func transcribeRealTime(audioStream: AsyncStream<AudioData>, configuration: TranscriptionConfiguration) -> AsyncStream<SpeechTranscriptionResult> {
        logger.info("Starting SpeechAnalyzer real-time transcription")
        
        return AsyncStream<SpeechTranscriptionResult> { continuation in
            Task {
                let useLocale: Locale
                if let configLanguage = configuration.language {
                    // Normalize locale identifier for SpeechTranscriber compatibility
                    let normalizedIdentifier = configLanguage.replacingOccurrences(of: "-", with: "_")
                    useLocale = Locale(identifier: normalizedIdentifier)
                } else {
                    useLocale = self.locale
                }
                
                do {
                    // Always create fresh analyzer for real-time transcription
                    logger.info("Creating fresh SpeechAnalyzer for real-time transcription with locale: \(useLocale.identifier)")
                    
                    let freshTranscriber = SpeechTranscriber(locale: useLocale, preset: .transcription)
                    let freshAnalyzer = SpeechAnalyzer(modules: [freshTranscriber])
                    
                    // Use standard optimal format for real-time transcription
                    let optimalFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, 
                                                    sampleRate: 16000, 
                                                    channels: 1, 
                                                    interleaved: true)!
                    logger.info("Real-time optimal format: \(optimalFormat)")
                    
                    // Prepare the fresh analyzer with optimal format
                    try await freshAnalyzer.prepareToAnalyze(in: optimalFormat)
                    logger.info("Fresh SpeechAnalyzer for real-time created and prepared successfully with optimal format")
                    
                    // Create input stream for real-time audio with optimal format conversion
                    let inputStream = AsyncStream<AnalyzerInput> { inputContinuation in
                        Task {
                            for await audioData in audioStream {
                                guard let audioBuffer = audioData.audioBuffer as? AVAudioPCMBuffer else {
                                    logger.warning("Skipping non-PCM audio buffer in real-time stream")
                                    continue
                                }
                                
                                // Validate format compatibility
                                guard canProcess(audioFormat: audioBuffer.format) else {
                                    logger.warning("Skipping incompatible audio format in real-time stream")
                                    continue
                                }
                                
                                // Convert to optimal format for SpeechAnalyzer
                                let processedBuffer: AVAudioPCMBuffer
                                if audioBuffer.format.isEqual(optimalFormat) {
                                    processedBuffer = audioBuffer
                                } else {
                                    // Convert to optimal format
                                    guard let converter = AVAudioConverter(from: audioBuffer.format, to: optimalFormat) else {
                                        logger.warning("Failed to create converter for real-time audio, skipping")
                                        continue
                                    }
                                    
                                    let outputFrameCount = AVAudioFrameCount(Double(audioBuffer.frameLength) * optimalFormat.sampleRate / audioBuffer.format.sampleRate)
                                    guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: optimalFormat, frameCapacity: outputFrameCount) else {
                                        logger.warning("Failed to create buffer for real-time audio conversion, skipping")
                                        continue
                                    }
                                    
                                    var error: NSError?
                                    converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                                        outStatus.pointee = AVAudioConverterInputStatus.haveData
                                        return audioBuffer
                                    }
                                    
                                    if error != nil {
                                        logger.warning("Real-time audio conversion to optimal format failed, skipping")
                                        continue
                                    }
                                    
                                    processedBuffer = convertedBuffer
                                }
                                
                                logger.debug("Yielding real-time optimal format audio buffer: \(processedBuffer.frameLength) frames")
                                inputContinuation.yield(AnalyzerInput(buffer: processedBuffer))
                            }
                            inputContinuation.finish()
                        }
                    }
                    
                    // Start fresh analyzer with real-time input
                    try await freshAnalyzer.start(inputSequence: inputStream)
                    
                    // Monitor transcriber results and yield them in a separate task
                    Task {
                        do {
                            for try await result in freshTranscriber.results {
                                if Task.isCancelled { break }
                                
                                // Extract confidence - SpeechTranscriber.Result may not have segments property
                                let confidence: Float = 0.8 // Default confidence for SpeechAnalyzer
                                
                                let resultText = "\(result.text)"
                                let transcriptionResult = await MainActor.run {
                                    SpeechTranscriptionResult(
                                        text: resultText,
                                        confidence: confidence,
                                        processingTime: 0.0, // Real-time, minimal processing time
                                        method: .speechAnalyzer,
                                        language: useLocale.identifier
                                    )
                                }
                                
                                logger.debug("Yielding real-time result: '\(resultText.prefix(30))...', isFinal: \(result.isFinal)")
                                continuation.yield(transcriptionResult)
                            }
                        } catch {
                            logger.error("Error monitoring transcriber results: \(error.localizedDescription)")
                        }
                    }
                    
                } catch {
                    logger.error("Real-time SpeechAnalyzer transcription error: \(error.localizedDescription)")
                }
                
                logger.info("SpeechAnalyzer real-time transcription completed")
                continuation.finish()
            }
        }
    }
}