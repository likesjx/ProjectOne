//
//  AudioRecorder.swift
//  ProjectOne
//
//  Created on 6/27/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine
import SwiftData
import Speech

// Import the transcription types from the protocol module

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var recordingItems: [RecordingItem] = []
    @Published var transcriptionStatus: TranscriptionStatus = .idle
    @Published var currentTranscription: TranscriptionResult?
    @Published var isTranscribing = false
    
    // Speech transcription factory
    private var speechEngineFactory: SpeechEngineFactory
    private let modelContext: ModelContext
    
    // Real-time transcription support
    @Published var realtimeTranscription = ""
    private var transcriptionTimer: Timer?
    
    init(modelContext: ModelContext, speechEngineConfiguration: SpeechEngineConfiguration = .default) {
        print("🎤 [Performance] Initializing AudioRecorder...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Initialize transcription components
        self.modelContext = modelContext
        self.speechEngineFactory = SpeechEngineFactory(configuration: speechEngineConfiguration)
        
        super.init()
        
        print("📁 [Performance] Fetching existing recordings...")
        fetchRecordings()
        fetchRecordingItems()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let formattedTime = String(format: "%.2f", endTime - startTime)
        print("✅ [Performance] AudioRecorder initialized in \(formattedTime)s")
    }
    
    func setupRecording() {
        // Setup is done when needed in startRecording
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
        // Request both microphone and speech recognition permissions
        requestMicrophonePermission { [weak self] micGranted in
            guard micGranted else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            self?.requestSpeechRecognitionPermission { speechGranted in
                DispatchQueue.main.async {
                    completion(speechGranted)
                }
            }
        }
        #else
        // macOS doesn't require explicit permission request for microphone in this context
        // but still needs speech recognition permission
        requestSpeechRecognitionPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        #endif
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            let status = granted ? "✅ Granted" : "❌ Denied"
            print("🎤 [AudioRecorder] Microphone permission: \(status)")
            completion(granted)
        }
        #else
        completion(true)
        #endif
    }
    
    private func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            print("🎤 [AudioRecorder] Speech recognition permission: \(authStatus.rawValue)")
            
            switch authStatus {
            case .authorized:
                print("🎤 [AudioRecorder] Speech recognition: ✅ Authorized")
                completion(true)
            case .denied:
                print("🎤 [AudioRecorder] Speech recognition: ❌ Denied - User must enable in Settings")
                completion(false)
            case .restricted:
                print("🎤 [AudioRecorder] Speech recognition: 🚫 Restricted - Device policy prevents access")
                completion(false)
            case .notDetermined:
                print("🎤 [AudioRecorder] Speech recognition: ⚠️  Not determined - Permission dialog should have appeared")
                completion(false)
            @unknown default:
                print("🎤 [AudioRecorder] Speech recognition: ❓ Unknown status: \(authStatus.rawValue)")
                completion(false)
            }
        }
    }
    
    func startRecording() {
        print("🎤 [Debug] startRecording() called")
        
        #if os(iOS)
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try recordingSession.setActive(true)
            print("🎤 [Debug] iOS audio session configured successfully")
        } catch {
            print("🎤 [Error] Failed to set up iOS recording session: \(error.localizedDescription)")
            DispatchQueue.main.async {
                // TODO: Show user-friendly error message
            }
            return
        }
        #elseif os(macOS)
        // macOS doesn't require AVAudioSession setup
        print("🎤 [Debug] macOS audio session - no explicit setup required")
        #endif
        
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(Date().toString(dateFormat: "dd-MM-YY_HH-mm-ss")).m4a")
        print("🎤 [Debug] Recording to: \(audioFilename.lastPathComponent)")
        
        // Use AAC format for better cross-platform compatibility (iOS/macOS)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0, // Standard CD quality, better compatibility
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000 // 128 kbps for good quality/size balance
        ]
        
        print("🎤 [Debug] === RECORDING CONFIGURATION ===")
        print("🎤 [Debug] Recording settings: \(settings)")
        print("🎤 [Debug] Target filename: \(audioFilename.lastPathComponent)")
        print("🎤 [Debug] Target path: \(audioFilename.path)")
        
        do {
            print("🎤 [Debug] Creating AVAudioRecorder with settings: \(settings)")
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            
            // Validate recorder was created successfully
            guard let recorder = audioRecorder else {
                print("🎤 [Error] Failed to create audio recorder")
                return
            }
            
            // Enable metering for debugging
            recorder.isMeteringEnabled = true
            
            // Attempt to start recording
            let recordingStarted = recorder.record()
            print("🎤 [Debug] Recording start result: \(recordingStarted)")
            
            if !recordingStarted {
                print("🎤 [Error] Failed to start recording - recorder.record() returned false")
                return
            }
            
            DispatchQueue.main.async {
                self.isRecording = true
                print("🎤 [Debug] isRecording set to true on main thread")
            }
            
            // Monitor recording levels for debugging
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                if !self.isRecording {
                    timer.invalidate()
                    return
                }
                
                recorder.updateMeters()
                let averagePower = recorder.averagePower(forChannel: 0)
                let peakPower = recorder.peakPower(forChannel: 0)
                print("🎙️ [Debug] Recording levels - Average: \(averagePower) dB, Peak: \(peakPower) dB")
                
                if averagePower < -60.0 && peakPower < -60.0 {
                    print("⚠️ [Warning] Very low audio levels during recording - possible microphone issue")
                } else if averagePower > -30.0 {
                    print("✅ [Debug] Good audio levels detected during recording")
                }
            }
            
            // Start real-time transcription simulation
            startRealtimeTranscriptionSimulation()
            
        } catch {
            print("🎤 [Error] Could not start recording: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("🎤 [Error] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("🎤 [Error] Error userInfo: \(nsError.userInfo)")
            }
            
            DispatchQueue.main.async {
                // TODO: Show user-friendly error message in UI
            }
        }
    }
    
    func stopRecording() {
        print("🛑 [Debug] stopRecording() called")
        audioRecorder?.stop()
        
        DispatchQueue.main.async {
            self.isRecording = false
            print("🛑 [Debug] isRecording set to false on main thread")
        }
        
        // Stop real-time transcription simulation
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil
        
        // Get the last recorded file and validate it immediately
        if let lastRecordingURL = audioRecorder?.url {
            print("🛑 [Debug] === POST-RECORDING VALIDATION ===")
            print("🛑 [Debug] Recorded file URL: \(lastRecordingURL.path)")
            
            // Immediate file validation after recording stops
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { // Give recording time to finalize
                print("🔍 [Debug] === IMMEDIATE FILE VALIDATION ===")
                print("🔍 [Debug] File exists after recording: \(FileManager.default.fileExists(atPath: lastRecordingURL.path))")
                
                if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: lastRecordingURL.path) {
                    let fileSize = fileAttributes[.size] as? Int64 ?? 0
                    print("🔍 [Debug] File size immediately after recording: \(fileSize) bytes")
                    
                    if fileSize == 0 {
                        print("❌ [Error] Recording resulted in empty file!")
                    } else if fileSize < 1000 {
                        print("⚠️ [Warning] Recording resulted in very small file (\(fileSize) bytes)")
                    } else {
                        print("✅ [Debug] Recording file size looks reasonable")
                    }
                } else {
                    print("❌ [Error] Cannot read file attributes immediately after recording")
                }
                
                // Try to read raw file data immediately after recording
                do {
                    let rawData = try Data(contentsOf: lastRecordingURL)
                    print("🔍 [Debug] Raw file data size after recording: \(rawData.count) bytes")
                    
                    if rawData.count > 0 {
                        let nonZeroBytes = rawData.filter { $0 != 0 }.count
                        let percentage = Float(nonZeroBytes)/Float(rawData.count)*100
                        print("🔍 [Debug] Non-zero bytes in recorded file: \(nonZeroBytes)/\(rawData.count) (\(percentage)%)")
                        
                        if nonZeroBytes == 0 {
                            print("❌ [Error] Recorded file contains only zero bytes!")
                        } else {
                            print("✅ [Debug] Recorded file contains audio data")
                            
                            // Show first few bytes of recorded file
                            let firstBytes = Array(rawData.prefix(16))
                            let hexString = firstBytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                            print("🔍 [Debug] First 16 bytes of recorded file: \(hexString)")
                        }
                    }
                } catch {
                    print("❌ [Error] Cannot read recorded file data: \(error.localizedDescription)")
                }
                
                // Try to load with AVAudioFile immediately after recording
                do {
                    let audioFile = try AVAudioFile(forReading: lastRecordingURL)
                    print("🔍 [Debug] AVAudioFile loaded successfully after recording")
                    print("🔍 [Debug] Audio file length: \(audioFile.length) frames")
                    print("🔍 [Debug] Audio file format: \(audioFile.fileFormat)")
                    
                    if audioFile.length == 0 {
                        print("❌ [Error] AVAudioFile reports 0 frames immediately after recording!")
                    } else {
                        print("✅ [Debug] AVAudioFile contains \(audioFile.length) frames after recording")
                    }
                } catch {
                    print("❌ [Error] Cannot load recorded file with AVAudioFile: \(error.localizedDescription)")
                }
            }
            
            print("🛑 [Debug] Starting transcription for: \(lastRecordingURL.lastPathComponent)")
            
            // Create recording item for the new recording
            if let recordingItem = createRecordingItem(for: lastRecordingURL) {
                recordingItem.isTranscribing = true
                try? modelContext.save()
                
                Task {
                    await transcribeRecording(url: lastRecordingURL, recordingItem: recordingItem)
                }
            }
        }
        
        fetchRecordings()
    }
    
    func fetchRecordings() {
        recordings.removeAll()
        
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: documentDirectory, includingPropertiesForKeys: nil)
            recordings = directoryContents.filter { $0.pathExtension == "m4a" }
            recordings.sort(by: { $0.lastPathComponent > $1.lastPathComponent })
        } catch {
            print("Could not fetch recordings: \(error.localizedDescription)")
        }
    }
    
    func fetchRecordingItems() {
        do {
            let descriptor = FetchDescriptor<RecordingItem>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            recordingItems = try modelContext.fetch(descriptor)
            print("📁 [AudioRecorder] Fetched \(recordingItems.count) recording items from database")
        } catch {
            print("📁 [AudioRecorder] Failed to fetch recording items: \(error.localizedDescription)")
            recordingItems = []
        }
    }
    
    func createRecordingItem(for url: URL) -> RecordingItem? {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            let recordingItem = RecordingItem(
                filename: url.lastPathComponent,
                fileURL: url,
                fileSizeBytes: fileSize,
                duration: 0, // Will be updated after transcription
                format: url.pathExtension
            )
            
            modelContext.insert(recordingItem)
            
            do {
                try modelContext.save()
                print("💾 [AudioRecorder] Created recording item: \(url.lastPathComponent)")
                return recordingItem
            } catch {
                print("💾 [AudioRecorder] Failed to save recording item: \(error.localizedDescription)")
                return nil
            }
        } catch {
            print("📁 [AudioRecorder] Failed to get file attributes: \(error.localizedDescription)")
            return nil
        }
    }
    
    func deleteRecording(at url: URL) {
        do {
            print("🗑️ [Debug] Deleting individual recording: \(url.lastPathComponent)")
            
            // Delete file from disk
            try FileManager.default.removeItem(at: url)
            print("🗑️ [Debug] File deleted from disk successfully")
            
            // Delete from database
            if let recordingItem = recordingItems.first(where: { $0.fileURL == url }) {
                modelContext.delete(recordingItem)
                try modelContext.save()
                print("🗑️ [Debug] Recording item deleted from database")
            }
            
            fetchRecordings()
            fetchRecordingItems()
            print("🗑️ [Debug] Recording lists refreshed")
        } catch {
            print("🗑️ [Error] File could not be deleted: \(error.localizedDescription)")
        }
    }
    
    /// Clear all recordings with proper error handling
    func clearAllRecordings() {
        print("🗑️ [Debug] Starting bulk delete of all recordings")
        
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var deletedCount = 0
        var errorCount = 0
        
        // Delete all files
        for recording in recordings {
            do {
                try fileManager.removeItem(at: recording)
                deletedCount += 1
                print("🗑️ [Debug] Deleted file: \(recording.lastPathComponent)")
            } catch {
                errorCount += 1
                print("🗑️ [Error] Failed to delete file \(recording.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Delete all database entries
        for recordingItem in recordingItems {
            modelContext.delete(recordingItem)
        }
        
        do {
            try modelContext.save()
            print("🗑️ [Debug] All recording items deleted from database")
        } catch {
            print("🗑️ [Error] Failed to save database after bulk delete: \(error.localizedDescription)")
        }
        
        // Refresh lists
        fetchRecordings()
        fetchRecordingItems()
        
        print("🗑️ [Debug] Bulk delete completed: \(deletedCount) files deleted, \(errorCount) errors")
    }
    
    // MARK: - Transcription Methods
    
    func transcribeRecording(url: URL, recordingItem: RecordingItem? = nil) async {
        print("🎤 [Debug] Starting transcription process for: \(url.lastPathComponent)")
        
        await MainActor.run {
            isTranscribing = true
            transcriptionStatus = .processing
            currentTranscription = nil
        }
        
        do {
            print("🎤 [Debug] Loading audio data and creating AudioData object")
            
            // First, validate the file exists and has content
            print("🔍 [Debug] === FILE VALIDATION ===")
            print("🔍 [Debug] File path: \(url.path)")
            print("🔍 [Debug] File exists: \(FileManager.default.fileExists(atPath: url.path))")
            
            if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
                let fileSize = fileAttributes[.size] as? Int64 ?? 0
                print("🔍 [Debug] File size: \(fileSize) bytes")
                
                if fileSize == 0 {
                    print("❌ [Error] Audio file is empty (0 bytes)!")
                    throw SpeechTranscriptionError.processingFailed("Audio file is empty")
                } else if fileSize < 1000 {
                    print("⚠️ [Warning] Audio file is very small (\(fileSize) bytes) - likely silent or corrupt")
                }
            } else {
                print("❌ [Error] Cannot read file attributes")
            }
            
            // Try to read raw file data first to validate
            print("🔍 [Debug] === RAW FILE DATA VALIDATION ===")
            do {
                let rawData = try Data(contentsOf: url)
                print("🔍 [Debug] Raw file data size: \(rawData.count) bytes")
                
                if rawData.count == 0 {
                    print("❌ [Error] Raw file data is empty!")
                    throw SpeechTranscriptionError.processingFailed("Audio file contains no data")
                }
                
                // Check if file is all zeros (silent)
                let nonZeroBytes = rawData.filter { $0 != 0 }.count
                let percentage = Float(nonZeroBytes)/Float(rawData.count)*100
                print("🔍 [Debug] Non-zero bytes in file: \(nonZeroBytes)/\(rawData.count) (\(percentage)%)")
                
                if nonZeroBytes == 0 {
                    print("❌ [Error] Audio file contains only zero bytes - completely silent!")
                    throw SpeechTranscriptionError.processingFailed("Audio file is completely silent")
                } else if nonZeroBytes < rawData.count / 100 {
                    print("⚠️ [Warning] Audio file is mostly zeros (less than 1% non-zero data)")
                }
                
                // Show first few bytes for format debugging
                let firstBytes = Array(rawData.prefix(16))
                let hexString = firstBytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                print("🔍 [Debug] First 16 bytes of file: \(hexString)")
                
            } catch {
                print("❌ [Error] Failed to read raw file data: \(error.localizedDescription)")
                throw SpeechTranscriptionError.processingFailed("Cannot read audio file data")
            }
            
            // Load audio file as AVAudioFile
            print("🔍 [Debug] === AVAUDIOFILE LOADING ===")
            let audioFile = try AVAudioFile(forReading: url)
            
            // Always use the processing format for PCM buffer creation (converts AAC to PCM)
            let audioFormat = audioFile.processingFormat // This converts AAC to Float32 PCM
            let frameCount = UInt32(audioFile.length)
            
            print("🎤 [Debug] AVAudioFile loaded successfully")
            print("🎤 [Debug] File format: \(audioFile.fileFormat)")
            print("🎤 [Debug] Processing format: \(audioFormat)")
            print("🎤 [Debug] Processing format isStandard: \(audioFormat.isStandard)")
            print("🎤 [Debug] Processing format commonFormat: \(audioFormat.commonFormat.rawValue)")
            print("🎤 [Debug] Audio file length: \(audioFile.length) frames")
            print("🎤 [Debug] Frame count for buffer: \(frameCount)")
            
            if audioFile.length == 0 {
                print("❌ [Error] AVAudioFile reports 0 frames - file contains no audio data!")
                throw SpeechTranscriptionError.processingFailed("Audio file contains no audio frames")
            }
            
            guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
                print("❌ [Error] Failed to create AVAudioPCMBuffer with format: \(audioFormat)")
                throw SpeechTranscriptionError.audioFormatUnsupported
            }
            
            // Read audio file with detailed validation
            print("🔍 [Debug] === AUDIO FILE READING ===")
            print("🔍 [Debug] Reading audio file into buffer...")
            print("🔍 [Debug] Buffer capacity: \(audioBuffer.frameCapacity) frames")
            
            let bytesRead = try audioFile.read(into: audioBuffer)
            print("🔍 [Debug] AVAudioFile.read() completed")
            print("🔍 [Debug] Bytes read from file: \(bytesRead)")
            print("🔍 [Debug] Buffer frame length after read: \(audioBuffer.frameLength)")
            
            if audioBuffer.frameLength == 0 {
                print("❌ [Error] AVAudioFile.read() produced empty buffer!")
                throw SpeechTranscriptionError.processingFailed("Audio file read produced no audio data")
            }
            
            // Validate audio content immediately after reading
            print("🔍 [Debug] === AUDIO CONTENT VALIDATION ===")
            if let channelData = audioBuffer.floatChannelData {
                let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(audioBuffer.frameLength)))
                let maxAmplitude = samples.map(abs).max() ?? 0.0
                let avgAmplitude = samples.map(abs).reduce(0, +) / Float(samples.count)
                let nonZeroSamples = samples.filter { abs($0) > 0.001 }.count
                let significantSamples = samples.filter { abs($0) > 0.01 }.count
                
                print("🔊 [Debug] Audio content validation after file read:")
                print("🔊 [Debug]   - Total samples: \(samples.count)")
                print("🔊 [Debug]   - Max amplitude: \(maxAmplitude)")
                print("🔊 [Debug]   - Avg amplitude: \(avgAmplitude)")
                let nonZeroPercentage = Float(nonZeroSamples)/Float(samples.count)*100
                let significantPercentage = Float(significantSamples)/Float(samples.count)*100
                print("🔊 [Debug]   - Non-zero samples: \(nonZeroSamples)/\(samples.count) (\(nonZeroPercentage)%)")
                print("🔊 [Debug]   - Significant samples (>0.01): \(significantSamples)/\(samples.count) (\(significantPercentage)%)")
                print("🔊 [Debug]   - First 10 samples: \(Array(samples.prefix(10)))")
                print("🔊 [Debug]   - Last 10 samples: \(Array(samples.suffix(10)))")
                
                if maxAmplitude < 0.001 {
                    print("❌ [Error] Audio buffer is completely silent after AVAudioFile.read()!")
                    print("🔍 [Debug] This indicates the issue is in AVAudioFile format conversion or the source file is silent")
                    
                    // Try reading with different approach - use fileFormat instead of processingFormat
                    print("🔄 [Debug] Attempting alternative read with fileFormat...")
                    
                    guard let alternativeBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.fileFormat, frameCapacity: frameCount) else {
                        print("❌ [Debug] Cannot create buffer with fileFormat")
                        throw SpeechTranscriptionError.processingFailed("Audio file read resulted in silent buffer")
                    }
                    
                    // Reset file position and try reading with original format
                    audioFile.framePosition = 0
                    let altBytesRead = try audioFile.read(into: alternativeBuffer)
                    print("🔄 [Debug] Alternative read: \(altBytesRead) frames, buffer length: \(alternativeBuffer.frameLength)")
                    
                    // Check if alternative approach has audio content
                    if let altChannelData = alternativeBuffer.floatChannelData {
                        let altSamples = Array(UnsafeBufferPointer(start: altChannelData[0], count: Int(alternativeBuffer.frameLength)))
                        let altMaxAmplitude = altSamples.map(abs).max() ?? 0.0
                        print("🔄 [Debug] Alternative read max amplitude: \(altMaxAmplitude)")
                        
                        if altMaxAmplitude > 0.001 {
                            print("✅ [Debug] Alternative read has audio content! Issue is in processingFormat conversion")
                            // Continue with alternative buffer
                        } else {
                            print("❌ [Debug] Alternative read is also silent - source file is truly silent")
                            throw SpeechTranscriptionError.processingFailed("Audio file contains no audible content")
                        }
                    } else {
                        print("❌ [Debug] Cannot access alternative buffer channel data")
                        throw SpeechTranscriptionError.processingFailed("Audio file read resulted in silent buffer")
                    }
                }
            } else {
                print("❌ [Error] Cannot access float channel data after file read")
                
                // Try alternative channel data types
                if let int16Data = audioBuffer.int16ChannelData {
                    print("🔄 [Debug] Trying int16 channel data instead...")
                    let samples = Array(UnsafeBufferPointer(start: int16Data[0], count: Int(audioBuffer.frameLength)))
                    let maxValue = samples.map(abs).max() ?? 0
                    print("🔄 [Debug] Int16 audio max value: \(maxValue)")
                    
                    if maxValue == 0 {
                        print("❌ [Error] Int16 audio data is also silent")
                        throw SpeechTranscriptionError.processingFailed("Audio file read resulted in silent buffer")
                    }
                } else if let int32Data = audioBuffer.int32ChannelData {
                    print("🔄 [Debug] Trying int32 channel data instead...")
                    let samples = Array(UnsafeBufferPointer(start: int32Data[0], count: Int(audioBuffer.frameLength)))
                    let maxValue = samples.map(abs).max() ?? 0
                    print("🔄 [Debug] Int32 audio max value: \(maxValue)")
                    
                    if maxValue == 0 {
                        print("❌ [Error] Int32 audio data is also silent")
                        throw SpeechTranscriptionError.processingFailed("Audio file read resulted in silent buffer")
                    }
                } else {
                    print("❌ [Error] Cannot access any channel data type")
                    throw SpeechTranscriptionError.processingFailed("Cannot access audio buffer data")
                }
            }
            
            // Create AudioData object
            let duration = Double(audioFile.length) / audioFormat.sampleRate
            let audioData = AudioData(buffer: audioBuffer, format: audioFormat, duration: duration)
            
            // Create transcription configuration
            let configuration = TranscriptionConfiguration(
                language: "en-US",
                requiresOnDeviceRecognition: true,
                enablePartialResults: false
            )
            
            print("🎤 [Debug] === STARTING TRANSCRIPTION PROCESS ===")
            print("🎤 [Debug] Calling speechEngineFactory.transcribe() with timeout protection")
            
            // Add comprehensive error handling wrapper for the transcription process
            let transcriptionTask = Task {
                do {
                    print("🎤 [Debug] About to call speechEngineFactory.transcribe()...")
                    let result = try await speechEngineFactory.transcribe(audio: audioData, configuration: configuration)
                    print("🎤 [Debug] speechEngineFactory.transcribe() completed successfully")
                    return result
                } catch {
                    print("🎤 [Error] speechEngineFactory.transcribe() failed: \(error)")
                    print("🎤 [Error] Error type: \(type(of: error))")
                    if let nsError = error as NSError? {
                        print("🎤 [Error] NSError domain: \(nsError.domain), code: \(nsError.code)")
                        print("🎤 [Error] NSError userInfo: \(nsError.userInfo)")
                    }
                    throw error
                }
            }
            
            let timeoutDuration: TimeInterval = 180.0 // 3 minutes total timeout
            let result = try await withThrowingTaskGroup(of: SpeechTranscriptionResult.self) { group in
                group.addTask { 
                    print("🎤 [Debug] Starting transcription task...")
                    return try await transcriptionTask.value 
                }
                
                group.addTask {
                    print("🎤 [Debug] Starting timeout task for \(timeoutDuration)s...")
                    try await Task.sleep(nanoseconds: UInt64(timeoutDuration * 1_000_000_000))
                    print("🎤 [Error] Transcription timeout reached!")
                    throw SpeechTranscriptionError.processingFailed("Transcription timeout after \(timeoutDuration) seconds")
                }
                
                for try await result in group {
                    group.cancelAll()
                    return result
                }
                
                throw SpeechTranscriptionError.processingFailed("No transcription result received")
            }
            
            print("🎤 [Debug] Transcription completed: \(result.text.prefix(50))...")
            
            await MainActor.run {
                // Convert SpeechTranscriptionResult to legacy TranscriptionResult for compatibility
                let legacyResult = TranscriptionResult(
                    text: result.text,
                    confidence: result.confidence,
                    segments: result.segments.map { segment in
                        TranscriptionSegment(
                            text: segment.text,
                            startTime: segment.startTime,
                            endTime: segment.endTime,
                            confidence: segment.confidence
                        )
                    },
                    processingTime: result.processingTime,
                    method: result.method,
                    language: result.language ?? "en-US"
                )
                
                currentTranscription = legacyResult
                transcriptionStatus = .completed
                isTranscribing = false
                
                // Update recording item with transcription results
                if let recordingItem = recordingItem {
                    recordingItem.updateWithTranscription(legacyResult, engine: result.method.displayName)
                    
                    // Update duration from audio file
                    recordingItem.duration = duration
                    
                    // TODO: Implement entity extraction with new architecture
                    // This will be enhanced in future phases to use the protocol-based system
                    
                    do {
                        try modelContext.save()
                        print("💾 [AudioRecorder] Saved transcription from \(result.method.displayName)")
                    } catch {
                        print("💾 [AudioRecorder] Failed to save transcription data: \(error.localizedDescription)")
                    }
                    
                    fetchRecordingItems()
                }
            }
            
            print("🎤 [Debug] Transcription result saved to currentTranscription")
            
        } catch {
            await MainActor.run {
                transcriptionStatus = .failed(error)
                isTranscribing = false
                
                // Mark recording item as failed
                if let recordingItem = recordingItem {
                    recordingItem.markTranscriptionFailed(error: error.localizedDescription)
                    try? modelContext.save()
                    fetchRecordingItems()
                }
            }
            print("🎤 [Error] Transcription failed: \(error.localizedDescription)")
        }
    }
    
    func applyTranscriptionCorrection(original: String, corrected: String, audioURL: URL) async {
        // Store correction for future model training
        print("Applied correction: \(original) → \(corrected)")
        // TODO: Implement correction storage in SwiftData
    }
    
    func startRealtimeTranscriptionSimulation() {
        guard isRecording else { return }
        
        realtimeTranscription = ""
        let phrases = [
            "Starting transcription...",
            "Listening to audio...",
            "Processing speech...",
            "Converting to text...",
            "Real-time transcription active"
        ]
        
        var currentPhraseIndex = 0
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if currentPhraseIndex < phrases.count {
                    self.realtimeTranscription = phrases[currentPhraseIndex]
                    currentPhraseIndex += 1
                } else {
                    self.realtimeTranscription += " ..."
                }
            }
        }
    }
    
    func getTranscriptionConfidence(for text: String) -> Double {
        // Return confidence from last transcription result
        return Double(currentTranscription?.confidence ?? 0.0)
    }
    
    /// Get current speech engine status for diagnostics
    func getSpeechEngineStatus() -> String {
        let status = speechEngineFactory.getEngineStatus()
        return status.statusMessage
    }
    
    /// Configure speech engine strategy
    func configureSpeechEngine(_ configuration: SpeechEngineConfiguration) {
        print("🎤 [AudioRecorder] Updating speech engine configuration to strategy: \(configuration.strategy.description)")
        
        // Clean up existing factory
        Task {
            await speechEngineFactory.cleanup()
        }
        
        // Create new factory with updated configuration
        speechEngineFactory = SpeechEngineFactory(configuration: configuration)
        
        print("🎤 [AudioRecorder] Speech engine configuration updated successfully")
    }
}

// Helper extension for Date formatting
extension Date {
    func toString(dateFormat: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        return dateFormatter.string(from: self)
    }
}