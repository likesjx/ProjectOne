//
//  AudioRecorder.swift
//  ProjectOne
//
//  Created on 6/27/25.
//

import Foundation
@preconcurrency import AVFoundation
import SwiftUI
import Combine
import SwiftData
import Speech

// Import the transcription types from the protocol module

// During-recording validation status
public enum RecordingValidationStatus {
    case unknown
    case good
    case warning
    case error
    
    var description: String {
        switch self {
        case .unknown: return "Checking..."
        case .good: return "Recording OK"
        case .warning: return "Audio Issue"
        case .error: return "Recording Failed"
        }
    }
}

@MainActor
class AudioRecorder: NSObject, ObservableObject, @unchecked Sendable {
    var audioRecorder: AVAudioRecorder?
    
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var recordingItems: [RecordingItem] = []
    @Published var transcriptionStatus: TranscriptionStatus = .idle
    @Published var currentTranscription: TranscriptionResult?
    @Published var isTranscribing = false
    
    // Speech transcription factory
    private var speechEngineFactory: SpeechEngineFactory?
    private let modelContext: ModelContext
    private var speechEngineConfiguration: SpeechEngineConfiguration
    
    // Real-time transcription support
    @Published var realtimeTranscription = ""
    private var transcriptionTimer: Timer?
    
    // Real-time audio level monitoring
    @Published var currentAudioLevel: Float = 0.0
    @Published var averageAudioLevel: Float = 0.0
    @Published var peakAudioLevel: Float = 0.0
    @Published var isAudioDetected: Bool = false
    private var audioLevelTimer: Timer?
    private var audioLevelHistory: [Float] = []
    private let maxHistoryCount = 10
    
    // During-recording validation
    @Published var recordingValidationStatus: RecordingValidationStatus = .unknown
    @Published var recordingIssueDetected: String?
    private var consecutiveSilentIntervals = 0
    private var totalRecordingIntervals = 0
    private let maxConsecutiveSilentIntervals = 30 // 3 seconds of silence at 0.1s intervals
    
    init(modelContext: ModelContext, speechEngineConfiguration: SpeechEngineConfiguration = .default) {
        print("🎤 [Performance] Initializing AudioRecorder...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Initialize transcription components
        self.modelContext = modelContext
        self.speechEngineConfiguration = speechEngineConfiguration
        self.speechEngineFactory = nil // Will be initialized lazily
        
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
    
    /// Ensure speech engine factory is initialized (lazy initialization)
    private func ensureSpeechEngineFactory() async throws {
        if speechEngineFactory == nil {
            speechEngineFactory = await SpeechEngineFactory(configuration: speechEngineConfiguration)
        }
    }
    
    func requestPermission(completion: @escaping @Sendable (Bool) -> Void) {
        print("🔐 [Debug] Starting comprehensive permission and diagnostic check")
        
        // Run microphone diagnostics first
        runMicrophoneDiagnostics()
        
        #if os(iOS)
        // Request both microphone and speech recognition permissions
        requestMicrophonePermission { [weak self] micGranted in
            guard micGranted else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            Task { @MainActor in
                self?.requestSpeechRecognitionPermission { speechGranted in
                    DispatchQueue.main.async {
                        completion(speechGranted)
                    }
                }
            }
        }
        #else
        // macOS doesn't require explicit permission request for microphone in this context
        // but still needs speech recognition permission
        Task { @MainActor in
            requestSpeechRecognitionPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
        #endif
    }
    
    private func requestMicrophonePermission(completion: @escaping @Sendable (Bool) -> Void) {
        #if os(iOS)
        AVAudioApplication.requestRecordPermission { granted in
            let status = granted ? "✅ Granted" : "❌ Denied"
            print("🎤 [AudioRecorder] Microphone permission: \(status)")
            completion(granted)
        }
        #else
        completion(true)
        #endif
    }
    
    @MainActor private func requestSpeechRecognitionPermission(completion: @escaping @Sendable (Bool) -> Void) {
        
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
        
        // Enhanced runtime permission check before starting recording
        let permissionStatus = checkRuntimePermissions()
        guard permissionStatus.canRecord else {
            print("🔐 [Error] Cannot start recording due to permission issues:")
            print("🔐 [Error] \(permissionStatus.detailMessage)")
            DispatchQueue.main.async {
                // TODO: Show user-friendly permission error message
                // self.showPermissionError(permissionStatus.detailMessage)
            }
            return
        }
        
        print("🔐 [Debug] ✅ All permissions validated, proceeding with recording setup")
        
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
        let audioFilename = documentPath.appendingPathComponent("\(Date().toString(dateFormat: "dd-MM-YY_HH-mm-ss")).wav")
        print("🎤 [Debug] Recording to: \(audioFilename.lastPathComponent)")
        
        // Use PCM format to eliminate AAC->PCM conversion issues
        // This fixes the silent audio buffer problem during transcription
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0, // Standard CD quality
            AVNumberOfChannelsKey: 1,  // Mono for speech
            AVLinearPCMBitDepthKey: 16, // 16-bit depth
            AVLinearPCMIsFloatKey: false, // Integer samples
            AVLinearPCMIsBigEndianKey: false, // Little endian
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        print("🎤 [Debug] === RECORDING CONFIGURATION ===")
        print("🎤 [Debug] Recording settings: \(settings)")
        print("🎤 [Debug] Target filename: \(audioFilename.lastPathComponent)")
        print("🎤 [Debug] Target path: \(audioFilename.path)")
        
        do {
            print("🎤 [Debug] Creating AVAudioRecorder with settings: \(settings)")
            
            // Pre-creation validation
            let validationResult = validateRecorderCreationPreconditions(url: audioFilename, settings: settings)
            if !validationResult.isValid {
                print("❌ [Error] Recorder creation validation failed: \(validationResult.error)")
                return
            }
            
            // Create the recorder
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            
            // Post-creation validation
            guard let recorder = audioRecorder else {
                print("❌ [Error] Failed to create audio recorder - nil result")
                return
            }
            
            // Comprehensive recorder validation
            let recorderValidation = validateCreatedRecorder(recorder)
            if !recorderValidation.isValid {
                print("❌ [Error] Recorder validation failed: \(recorderValidation.error)")
                audioRecorder = nil
                return
            }
            
            print("✅ [Debug] AVAudioRecorder created and validated successfully")
            print("🎤 [Debug] Recorder URL: \(recorder.url)")
            print("🎤 [Debug] Recorder format: \(recorder.format)")
            print("🎤 [Debug] Recorder settings validated: \(recorderValidation.validationDetails)")
            
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
            
            // Start enhanced real-time audio level monitoring
            startRealTimeAudioMonitoring()
            
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
        
        // Stop real-time audio monitoring
        stopRealTimeAudioMonitoring()
        
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
            print("🛑 [Debug] About to create recording item...")
            if let recordingItem = createRecordingItem(for: lastRecordingURL) {
                print("🛑 [Debug] ✅ Recording item created successfully")
                recordingItem.isTranscribing = true
                try? modelContext.save()
                print("🛑 [Debug] ✅ Model context saved, starting transcription task...")
                
                Task {
                    print("🛑 [Debug] 🚀 Transcription task started!")
                    await transcribeRecording(url: lastRecordingURL, recordingItem: recordingItem)
                    print("🛑 [Debug] ✅ Transcription task completed!")
                }
            } else {
                print("🛑 [Debug] ❌ Failed to create recording item - transcription aborted")
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
        let _ = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
        print("🎤 [Debug] =====================================")
        print("🎤 [Debug] TRANSCRIPTION PROCESS STARTED")
        print("🎤 [Debug] File: \(url.lastPathComponent)")
        print("🎤 [Debug] URL: \(url.path)")
        print("🎤 [Debug] Recording Item: \(recordingItem != nil ? "✅ Available" : "❌ Nil")")
        print("🎤 [Debug] =====================================")
        
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
            
            // Use the file format for PCM buffer creation to match recorded format
            // This ensures Int16 recorded data is read as Int16, not converted to Float32
            let audioFormat = audioFile.fileFormat
            let frameCount = UInt32(audioFile.length)
            
            print("🎤 [Debug] AVAudioFile loaded successfully")
            print("🎤 [Debug] File format: \(audioFile.fileFormat)")
            print("🎤 [Debug] Processing format: \(audioFormat)")
            print("🎤 [Debug] Processing format isStandard: \(audioFormat.isStandard)")
            print("🎤 [Debug] Processing format commonFormat: \(audioFormat.commonFormat.rawValue)")
            print("🎤 [Debug] File format == Processing format: \(audioFile.fileFormat.isEqual(audioFormat))")
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
            
            try audioFile.read(into: audioBuffer)
            print("🔍 [Debug] AVAudioFile.read() completed")
            print("🔍 [Debug] Buffer frame length after read: \(audioBuffer.frameLength)")
            
            if audioBuffer.frameLength == 0 {
                print("❌ [Error] AVAudioFile.read() produced empty buffer!")
                throw SpeechTranscriptionError.processingFailed("Audio file read produced no audio data")
            }
            
            // Validate audio content immediately after reading
            print("🔍 [Debug] === AUDIO CONTENT VALIDATION ===")
            print("🔍 [Debug] Buffer format: \(audioBuffer.format)")
            print("🔍 [Debug] Buffer common format: \(audioBuffer.format.commonFormat.rawValue)")
            
            // Check the appropriate channel data type based on the format
            if audioFormat.commonFormat == .pcmFormatInt16, let int16Data = audioBuffer.int16ChannelData {
                print("🔄 [Debug] Validating Int16 PCM data...")
                
                // Safety check for buffer bounds
                guard audioBuffer.frameLength > 0 else {
                    print("❌ [Error] Audio buffer has zero frame length")
                    throw SpeechTranscriptionError.processingFailed("Audio buffer is empty")
                }
                
                let frameCount = Int(audioBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: int16Data[0], count: frameCount))
                
                // Process samples safely
                let absValues = samples.map(abs)
                let maxValue = absValues.max() ?? 0
                let sum = absValues.reduce(Int64(0)) { $0 + Int64($1) } // Use Int64 to prevent overflow
                let avgValue = Double(sum) / Double(samples.count)
                let nonZeroSamples = samples.filter { abs($0) > 0 }.count
                let significantSamples = samples.filter { abs($0) > 100 }.count // Threshold for 16-bit audio
                
                print("🔊 [Debug] Int16 audio content validation after file read:")
                print("🔊 [Debug]   - Total samples: \(samples.count)")
                print("🔊 [Debug]   - Max value: \(maxValue)")
                print("🔊 [Debug]   - Avg value: \(avgValue)")
                let nonZeroPercentage = Float(nonZeroSamples)/Float(samples.count)*100
                let significantPercentage = Float(significantSamples)/Float(samples.count)*100
                print("🔊 [Debug]   - Non-zero samples: \(nonZeroSamples)/\(samples.count) (\(nonZeroPercentage)%)")
                print("🔊 [Debug]   - Significant samples (>100): \(significantSamples)/\(samples.count) (\(significantPercentage)%)")
                print("🔊 [Debug]   - First 10 samples: \(Array(samples.prefix(10)))")
                print("🔊 [Debug]   - Last 10 samples: \(Array(samples.suffix(10)))")
                
                if maxValue == 0 {
                    print("❌ [Error] Int16 audio buffer is completely silent after AVAudioFile.read()!")
                    print("🔍 [Debug] This indicates a format mismatch or recording issue")
                    throw SpeechTranscriptionError.processingFailed("Int16 PCM audio file contains no audible content")
                }
            } else if let channelData = audioBuffer.floatChannelData {
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
                    print("🔍 [Debug] This should not happen with PCM format - indicates recording issue")
                    print("🔍 [Debug] Raw file has \(nonZeroPercentage)% non-zero bytes but PCM read is silent")
                    
                    // Since we're now using PCM format, this suggests a recording problem
                    throw SpeechTranscriptionError.processingFailed("Recorded PCM audio file contains no audible content")
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
                    print("🎤 [Debug] About to initialize speech engine factory if needed...")
                    try await ensureSpeechEngineFactory()
                    guard let factory = speechEngineFactory else {
                        throw NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech engine factory not available"])
                    }
                    print("🎤 [Debug] About to call speechEngineFactory.transcribe()...")
                    let result = try await factory.transcribe(audio: audioData, configuration: configuration)
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
        guard let factory = speechEngineFactory else {
            return "Speech engine factory not initialized"
        }
        let status = factory.getEngineStatus()
        return status.statusMessage
    }
    
    /// Configure speech engine strategy
    func configureSpeechEngine(_ configuration: SpeechEngineConfiguration) {
        print("🎤 [AudioRecorder] Updating speech engine configuration to strategy: \(configuration.strategy.description)")
        
        // Clean up existing factory
        Task {
            if let factory = speechEngineFactory {
                await factory.cleanup()
            }
        }
        
        // Update configuration and reset factory (will be recreated lazily)  
        self.speechEngineConfiguration = configuration
        speechEngineFactory = nil
        
        print("🎤 [AudioRecorder] Speech engine configuration updated successfully")
    }
    
    /// Enhanced runtime permission checking with comprehensive validation
    private func checkRuntimePermissions() -> (canRecord: Bool, detailMessage: String) {
        print("🔐 [Permissions] === ENHANCED RUNTIME PERMISSION CHECK ===")
        
        var issues: [String] = []
        var canRecord = true
        
        // Check microphone permissions
        #if os(iOS)
        let micResult = checkiOSMicrophonePermissionDetailed()
        if !micResult.granted {
            canRecord = false
            issues.append("Microphone: \(micResult.message)")
        }
        
        // Check audio session state
        let sessionResult = checkiOSAudioSessionState()
        if !sessionResult.ready {
            canRecord = false
            issues.append("Audio Session: \(sessionResult.message)")
        }
        #else
        // Enhanced macOS permission checking
        let macResult = checkmacOSRecordingCapabilities()
        if !macResult.capable {
            canRecord = false
            issues.append("macOS: \(macResult.message)")
        }
        #endif
        
        // Check speech recognition permissions (for transcription)
        let speechResult = checkSpeechRecognitionPermissionDetailed()
        if !speechResult.granted {
            // Note: Speech recognition failure shouldn't block recording
            issues.append("Speech (transcription only): \(speechResult.message)")
        }
        
        // Check device recording capabilities
        let deviceResult = checkDeviceRecordingCapabilities()
        if !deviceResult.capable {
            canRecord = false
            issues.append("Device: \(deviceResult.message)")
        }
        
        let finalMessage = issues.isEmpty ? "All permissions validated successfully" : issues.joined(separator: "; ")
        
        print("🔐 [Permissions] Final result: canRecord=\(canRecord)")
        print("🔐 [Permissions] Details: \(finalMessage)")
        print("🔐 [Permissions] === PERMISSION CHECK COMPLETE ===")
        
        return (canRecord, finalMessage)
    }
    
    #if os(iOS)
    /// Detailed iOS microphone permission check
    private func checkiOSMicrophonePermissionDetailed() -> (granted: Bool, message: String) {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Use the newer approach - check if we can create a test recorder
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("permission_test.wav")
        let testSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]
        
        do {
            let testRecorder = try AVAudioRecorder(url: tempURL, settings: testSettings)
            if testRecorder.prepareToRecord() {
                // Clean up test file
                try? FileManager.default.removeItem(at: tempURL)
                
                if audioSession.isInputAvailable {
                    print("🔐 [iOS] Microphone permission: Granted and input available")
                    return (true, "Granted and input available")
                } else {
                    print("🔐 [iOS] Microphone permission: Granted but no input devices")
                    return (false, "Granted but no input devices available")
                }
            } else {
                print("🔐 [iOS] Microphone permission: Cannot prepare recorder")
                return (false, "Permission denied or recorder unavailable")
            }
        } catch {
            print("🔐 [iOS] Microphone permission check failed: \(error)")
            return (false, "Permission denied or system error: \(error.localizedDescription)")
        }
    }
    
    /// Check iOS audio session readiness for recording
    private func checkiOSAudioSessionState() -> (ready: Bool, message: String) {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Check if other audio is interfering
        if audioSession.isOtherAudioPlaying {
            print("🔐 [iOS] ⚠️ Other audio is playing - may interfere with recording")
        }
        
        // Check current category compatibility
        let currentCategory = audioSession.category
        print("🔐 [iOS] Current audio category: \(currentCategory.rawValue)")
        
        // Check input availability
        guard audioSession.isInputAvailable else {
            return (false, "No audio input devices available")
        }
        
        // Check input gain capabilities
        if audioSession.isInputGainSettable {
            let inputGain = audioSession.inputGain
            print("🔐 [iOS] Input gain: \(inputGain)")
            if inputGain == 0.0 {
                print("🔐 [iOS] ⚠️ Input gain is at minimum - may result in silent recording")
            }
        }
        
        return (true, "Audio session ready for recording")
    }
    #endif
    
    #if os(macOS)
    /// Enhanced macOS recording capability check
    private func checkmacOSRecordingCapabilities() -> (capable: Bool, message: String) {
        print("🔐 [macOS] Checking macOS recording capabilities")
        
        // Test audio unit creation for input capabilities
        do {
            let _ = try createTemporaryAudioUnitForPermissionCheck()
            print("🔐 [macOS] ✅ Audio unit creation successful")
            return (true, "Recording capabilities available")
        } catch {
            print("🔐 [macOS] ❌ Audio unit creation failed: \(error.localizedDescription)")
            return (false, "Audio system not available: \(error.localizedDescription)")
        }
    }
    
    /// Create temporary audio unit for permission testing
    private func createTemporaryAudioUnitForPermissionCheck() throws -> AudioUnit? {
        var audioUnit: AudioUnit?
        
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Output
        componentDescription.componentSubType = kAudioUnitSubType_HALOutput
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        
        guard let component = AudioComponentFindNext(nil, &componentDescription) else {
            throw NSError(domain: "PermissionCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio component not found"])
        }
        
        let status = AudioComponentInstanceNew(component, &audioUnit)
        guard status == noErr else {
            throw NSError(domain: "PermissionCheck", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Audio component instance creation failed"])
        }
        
        return audioUnit
    }
    #endif
    
    /// Detailed speech recognition permission check
    private func checkSpeechRecognitionPermissionDetailed() -> (granted: Bool, message: String) {
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        print("🔐 [Speech] Authorization status: \(authStatus.rawValue)")
        
        switch authStatus {
        case .authorized:
            // Check if speech recognizer is actually available
            let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
            if recognizer?.isAvailable == true {
                return (true, "Authorized and available")
            } else {
                return (false, "Authorized but recognizer not available")
            }
        case .denied:
            return (false, "Denied - Enable in Settings > Privacy & Security > Speech Recognition")
        case .restricted:
            return (false, "Restricted by device policy")
        case .notDetermined:
            return (false, "Not requested yet")
        @unknown default:
            return (false, "Unknown status (\(authStatus.rawValue))")
        }
    }
    
    /// Check basic device recording capabilities
    private func checkDeviceRecordingCapabilities() -> (capable: Bool, message: String) {
        print("🔐 [Device] Testing basic recording capabilities")
        
        let testFormat: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("permission_capability_test.wav")
        
        do {
            let testRecorder = try AVAudioRecorder(url: tempURL, settings: testFormat)
            testRecorder.isMeteringEnabled = true
            
            // Test if recorder can be prepared
            if testRecorder.prepareToRecord() {
                print("🔐 [Device] ✅ Test recorder prepared successfully")
                
                // Clean up
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try? FileManager.default.removeItem(at: tempURL)
                }
                
                return (true, "Device capable of recording")
            } else {
                return (false, "Test recorder failed to prepare")
            }
            
        } catch {
            print("🔐 [Device] ❌ Device capability test failed: \(error.localizedDescription)")
            return (false, "Cannot create recorder: \(error.localizedDescription)")
        }
    }
    
    /// Get user-friendly permission status for UI
    func getPermissionStatusForUI() -> String {
        let result = checkRuntimePermissions()
        return result.canRecord ? "✅ Ready to record" : "❌ \(result.detailMessage)"
    }
    
    // MARK: - Microphone Availability and Routing Diagnostics
    
    /// Run comprehensive microphone diagnostics
    func runMicrophoneDiagnostics() {
        print("🎤 [Diagnostics] === MICROPHONE AVAILABILITY AND ROUTING DIAGNOSTICS ===")
        
        #if os(iOS)
        diagnosticsiOSMicrophone()
        #else
        diagnosticsmacOSMicrophone()
        #endif
        
        // Common diagnostics for both platforms
        diagnosticsCommonAudioSystem()
        
        print("🎤 [Diagnostics] === MICROPHONE DIAGNOSTICS COMPLETE ===")
    }
    
    #if os(iOS)
    /// iOS-specific microphone diagnostics
    private func diagnosticsiOSMicrophone() {
        print("📱 [iOS Diagnostics] Checking iOS-specific microphone configuration")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        // Check current audio session state
        print("📱 [iOS Diagnostics] Current audio session category: \(audioSession.category.rawValue)")
        print("📱 [iOS Diagnostics] Current audio session mode: \(audioSession.mode.rawValue)")
        print("📱 [iOS Diagnostics] Audio session is active: \(audioSession.isOtherAudioPlaying)")
        
        // Check microphone availability
        print("📱 [iOS Diagnostics] Input available: \(audioSession.isInputAvailable)")
        print("📱 [iOS Diagnostics] Input gain settable: \(audioSession.isInputGainSettable)")
        
        if audioSession.isInputGainSettable {
            print("📱 [iOS Diagnostics] Current input gain: \(audioSession.inputGain)")
        }
        
        // Check sample rate and buffer duration
        print("📱 [iOS Diagnostics] Sample rate: \(audioSession.sampleRate)Hz")
        print("📱 [iOS Diagnostics] Buffer duration: \(audioSession.ioBufferDuration * 1000)ms")
        print("📱 [iOS Diagnostics] Input number of channels: \(audioSession.inputNumberOfChannels)")
        print("📱 [iOS Diagnostics] Output number of channels: \(audioSession.outputNumberOfChannels)")
        
        // Check current route
        let currentRoute = audioSession.currentRoute
        print("📱 [iOS Diagnostics] Current audio route:")
        for input in currentRoute.inputs {
            print("📱 [iOS Diagnostics]   Input: \(input.portName) (\(input.portType.rawValue))")
            print("📱 [iOS Diagnostics]   UID: \(input.uid)")
            if let dataSources = input.dataSources {
                for dataSource in dataSources {
                    print("📱 [iOS Diagnostics]     Data source: \(dataSource.dataSourceName)")
                }
            }
        }
        
        for output in currentRoute.outputs {
            print("📱 [iOS Diagnostics]   Output: \(output.portName) (\(output.portType.rawValue))")
        }
        
        // Check available inputs
        if let availableInputs = audioSession.availableInputs {
            print("📱 [iOS Diagnostics] Available inputs (\(availableInputs.count)):")
            for input in availableInputs {
                let isSelected = input == audioSession.preferredInput
                let status = isSelected ? "✅ SELECTED" : "⭕ Available"
                print("📱 [iOS Diagnostics]   \(status): \(input.portName) (\(input.portType.rawValue))")
            }
        } else {
            print("📱 [iOS Diagnostics] No available inputs found")
        }
        
        // Check record permission using modern approach
        print("📱 [iOS Diagnostics] Checking microphone permission...")
        let permissionResult = checkiOSMicrophonePermissionDetailed()
        if permissionResult.granted {
            print("📱 [iOS Diagnostics] ✅ Microphone permission: \(permissionResult.message)")
        } else {
            print("📱 [iOS Diagnostics] ❌ Microphone permission: \(permissionResult.message)")
        }
    }
    #endif
    
    #if os(macOS)
    /// macOS-specific microphone diagnostics
    private func diagnosticsmacOSMicrophone() {
        print("🖥️ [macOS Diagnostics] Checking macOS-specific microphone configuration")
        
        // Check system audio devices
        print("🖥️ [macOS Diagnostics] Checking available audio devices...")
        
        // Try to get default input device information
        do {
            // Create a temporary audio unit to check device capabilities
            let _ = try self.createTemporaryAudioUnit()
            print("🖥️ [macOS Diagnostics] ✅ Successfully created temporary audio unit")
            
            // Check input device properties
            if let inputDevices = self.getAvailableInputDevices() {
                print("🖥️ [macOS Diagnostics] Available input devices (\(inputDevices.count)):")
                for (index, device) in inputDevices.enumerated() {
                    print("🖥️ [macOS Diagnostics]   \(index + 1). \(device)")
                }
            } else {
                print("🖥️ [macOS Diagnostics] ❌ Could not retrieve input devices")
            }
            
        } catch {
            print("🖥️ [macOS Diagnostics] ❌ Failed to create audio unit: \(error.localizedDescription)")
        }
        
        // Check microphone access through privacy settings
        print("🖥️ [macOS Diagnostics] Microphone access appears to be available for audio recording")
        print("🖥️ [macOS Diagnostics] (macOS handles microphone permissions at the system level)")
    }
    
    /// Create temporary audio unit for device testing
    private func createTemporaryAudioUnit() throws -> AudioUnit? {
        var audioUnit: AudioUnit?
        
        // Define audio component description for input
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_Output
        componentDescription.componentSubType = kAudioUnitSubType_HALOutput
        componentDescription.componentManufacturer = kAudioUnitManufacturer_Apple
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        
        // Find the component
        guard let component = AudioComponentFindNext(nil, &componentDescription) else {
            throw NSError(domain: "AudioDiagnostics", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find audio component"])
        }
        
        // Create audio unit instance
        let status = AudioComponentInstanceNew(component, &audioUnit)
        guard status == noErr else {
            throw NSError(domain: "AudioDiagnostics", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Could not create audio unit instance"])
        }
        
        return audioUnit
    }
    
    /// Get available input devices on macOS using Core Audio
    private func getAvailableInputDevices() -> [String]? {
        var devices: [String] = []
        
        // Get list of all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        
        guard status == noErr else {
            print("🖥️ [macOS] ❌ Failed to get audio devices data size: \(status)")
            return ["Built-in Microphone (fallback)"]
        }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array<AudioDeviceID>(repeating: 0, count: deviceCount)
        
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        
        guard status == noErr else {
            print("🖥️ [macOS] ❌ Failed to get audio devices: \(status)")
            return ["Built-in Microphone (fallback)"]
        }
        
        print("🖥️ [macOS] Found \(deviceCount) total audio devices")
        
        // Check each device for input capabilities
        for deviceID in deviceIDs {
            if let deviceInfo = getAudioDeviceInfo(deviceID: deviceID) {
                if deviceInfo.hasInputChannels {
                    devices.append("\(deviceInfo.name) (Input: \(deviceInfo.inputChannels) channels)")
                    print("🖥️ [macOS] ✅ Input device: \(deviceInfo.name)")
                }
            }
        }
        
        if devices.isEmpty {
            print("🖥️ [macOS] ⚠️ No input devices found - using fallback")
            return ["Built-in Microphone (fallback)"]
        }
        
        return devices
    }
    
    /// Get detailed information about an audio device
    private func getAudioDeviceInfo(deviceID: AudioDeviceID) -> (name: String, hasInputChannels: Bool, inputChannels: Int)? {
        // Get device name
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else { return nil }
        
        var deviceName: CFString?
        let deviceNamePtr: UnsafeMutablePointer<CFString?> = withUnsafeMutablePointer(to: &deviceName) { $0 }
        status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, deviceNamePtr)
        guard status == noErr, let name = deviceName as String? else { return nil }
        
        // Get input stream configuration
        propertyAddress.mSelector = kAudioDevicePropertyStreamConfiguration
        propertyAddress.mScope = kAudioDevicePropertyScopeInput
        
        status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard status == noErr else { return (name, false, 0) }
        
        let _ = Int(dataSize)
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }
        
        status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPointer)
        guard status == noErr else { return (name, false, 0) }
        
        let bufferList = bufferListPointer.pointee
        var totalChannels = 0
        
        let bufferCount = Int(bufferList.mNumberBuffers)
        if bufferCount > 0 {
            let buffersPointer = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            for buffer in buffersPointer {
                totalChannels += Int(buffer.mNumberChannels)
            }
        }
        
        return (name, totalChannels > 0, totalChannels)
    }
    
    /// Enhanced macOS-specific audio input detection and validation  
    private func performMacOSAudioInputValidation() -> (hasValidInput: Bool, details: String) {
        var validationDetails: [String] = []
        
        // Check system audio hardware
        validationDetails.append("🖥️ Checking macOS audio hardware...")
        
        guard let inputDevices = getAvailableInputDevices() else {
            return (false, "No audio input devices detected")
        }
        
        validationDetails.append("Found \(inputDevices.count) input device(s)")
        
        // Test default input device functionality
        do {
            let audioUnit = try createTemporaryAudioUnit()
            validationDetails.append("✅ Audio unit creation successful")
            
            // Test basic input configuration
            if let _ = audioUnit {
                validationDetails.append("✅ Core Audio input system accessible")
            }
            
        } catch {
            validationDetails.append("❌ Audio unit creation failed: \(error.localizedDescription)")
            return (false, validationDetails.joined(separator: "; "))
        }
        
        // Validate system microphone permissions
        let micPermissionStatus = self.checkMacOSMicrophonePermissions()
        validationDetails.append("Microphone permissions: \(micPermissionStatus)")
        
        return (true, validationDetails.joined(separator: "; "))
    }
    
    /// Check macOS microphone permissions
    private func checkMacOSMicrophonePermissions() -> String {
        // On macOS, microphone permissions are handled automatically by AVAudioRecorder
        // but we can check for common permission issues
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("permission_test.wav")
        
        let testSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]
        
        do {
            let testRecorder = try AVAudioRecorder(url: tempURL, settings: testSettings)
            testRecorder.isMeteringEnabled = true
            
            // Try to prepare for recording (this will trigger permission request if needed)
            if testRecorder.prepareToRecord() {
                return "✅ Granted (AVAudioRecorder accessible)"
            } else {
                return "⚠️ Unknown (prepareToRecord failed)"
            }
        } catch {
            return "❌ Denied or Error (\(error.localizedDescription))"
        }
    }
    #endif
    
    /// Common audio system diagnostics for both platforms
    private func diagnosticsCommonAudioSystem() {
        print("🔧 [Common Diagnostics] Checking cross-platform audio system state")
        
        // Test basic AVAudioRecorder functionality
        let testFormat: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let testURL = documentPath.appendingPathComponent("diagnostic_test.wav")
        
        do {
            let testRecorder = try AVAudioRecorder(url: testURL, settings: testFormat)
            print("🔧 [Common Diagnostics] ✅ Successfully created test AVAudioRecorder")
            print("🔧 [Common Diagnostics] Test recorder URL: \(testURL.path)")
            print("🔧 [Common Diagnostics] Test recorder format: \(testFormat)")
            
            // Enable metering for testing
            testRecorder.isMeteringEnabled = true
            print("🔧 [Common Diagnostics] ✅ Metering enabled on test recorder")
            
            // Clean up test file if it exists
            if FileManager.default.fileExists(atPath: testURL.path) {
                try FileManager.default.removeItem(at: testURL)
                print("🔧 [Common Diagnostics] Cleaned up existing test file")
            }
            
        } catch {
            print("🔧 [Common Diagnostics] ❌ Failed to create test AVAudioRecorder: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("🔧 [Common Diagnostics] Error domain: \(nsError.domain), code: \(nsError.code)")
                print("🔧 [Common Diagnostics] Error userInfo: \(nsError.userInfo)")
            }
        }
        
        // Check file system permissions
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        print("🔧 [Common Diagnostics] Documents directory: \(documentsURL.path)")
        print("🔧 [Common Diagnostics] Documents directory exists: \(FileManager.default.fileExists(atPath: documentsURL.path))")
        
        // Test write permissions
        let testWriteURL = documentsURL.appendingPathComponent("write_test.txt")
        do {
            try "test".write(to: testWriteURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testWriteURL)
            print("🔧 [Common Diagnostics] ✅ File system write permissions OK")
        } catch {
            print("🔧 [Common Diagnostics] ❌ File system write test failed: \(error.localizedDescription)")
        }
    }
    
    /// Get comprehensive microphone status for display in UI
    func getMicrophoneStatus() -> String {
        var status = "🎤 Microphone System Status:\n"
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        let permissionResult = checkiOSMicrophonePermissionDetailed()
        status += "Platform: iOS\n"
        status += "Input Available: \(audioSession.isInputAvailable ? "✅" : "❌")\n"
        status += "Record Permission: \(permissionResult.granted ? "✅ Granted" : "❌ \(permissionResult.message)")\n"
        status += "Current Route Inputs: \(audioSession.currentRoute.inputs.count)\n"
        status += "Available Inputs: \(audioSession.availableInputs?.count ?? 0)\n"
        #else
        status += "Platform: macOS\n"
        status += "System Audio: Available\n"
        status += "Microphone Access: System Level\n"
        #endif
        
        status += "Audio Recorder Created: \(audioRecorder != nil ? "✅" : "❌")\n"
        status += "Currently Recording: \(isRecording ? "✅" : "❌")\n"
        
        return status
    }
    
    // MARK: - Real-Time Audio Level Monitoring
    
    /// Start comprehensive real-time audio level monitoring
    private func startRealTimeAudioMonitoring() {
        guard let recorder = audioRecorder else {
            print("🎙️ [Error] Cannot start audio monitoring - no recorder available")
            return
        }
        
        // Reset audio level tracking and validation state
        DispatchQueue.main.async {
            self.currentAudioLevel = 0.0
            self.averageAudioLevel = 0.0
            self.peakAudioLevel = 0.0
            self.isAudioDetected = false
            self.recordingValidationStatus = .unknown
            self.recordingIssueDetected = nil
        }
        audioLevelHistory.removeAll()
        consecutiveSilentIntervals = 0
        totalRecordingIntervals = 0
        
        print("🎙️ [Monitor] Starting real-time audio level monitoring")
        
        // Start high-frequency audio level monitoring (10 times per second)
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else {
                return
            }
            
            // Check if still recording - access on main actor
            Task { @MainActor in
                guard self.isRecording else {
                    // Timer invalidation - use stored reference
                    self.audioLevelTimer?.invalidate()
                    return
                }
                
                // Update audio meters
                recorder.updateMeters()
                
                // Get current levels in dBFS (decibels relative to full scale)
                let averagePowerDB = recorder.averagePower(forChannel: 0)
                let peakPowerDB = recorder.peakPower(forChannel: 0)
                
                // Convert dB to normalized level (0.0 to 1.0 scale)
                // dBFS ranges from -160 (silence) to 0 (max volume)
                let normalizedCurrent = self.dbToNormalizedLevel(averagePowerDB)
                let normalizedPeak = self.dbToNormalizedLevel(peakPowerDB)
                
                // Update history for running average
                self.audioLevelHistory.append(normalizedCurrent)
                if self.audioLevelHistory.count > self.maxHistoryCount {
                    self.audioLevelHistory.removeFirst()
                }
                
                // Calculate running average
                let runningAverage = self.audioLevelHistory.reduce(0, +) / Float(self.audioLevelHistory.count)
                
                // Determine if audio is being detected (threshold: -50 dB or about 0.003 normalized)
                let audioDetectionThreshold: Float = 0.003
                let currentlyDetectingAudio = normalizedCurrent > audioDetectionThreshold
                
                // Update published properties (already on main actor)
                self.currentAudioLevel = normalizedCurrent
                self.averageAudioLevel = runningAverage
                self.peakAudioLevel = max(self.peakAudioLevel, normalizedPeak)
                self.isAudioDetected = currentlyDetectingAudio
                
                // During-recording validation
                self.performDuringRecordingValidation(currentlyDetectingAudio: currentlyDetectingAudio, 
                                                    averagePowerDB: averagePowerDB, 
                                                    peakPowerDB: peakPowerDB,
                                                    normalizedCurrent: normalizedCurrent)
                
                // Detailed logging every second (every 10th call)
                if self.audioLevelHistory.count % 10 == 0 {
                    self.logDetailedAudioLevels(averagePowerDB: averagePowerDB, peakPowerDB: peakPowerDB, 
                                              normalizedCurrent: normalizedCurrent, runningAverage: runningAverage,
                                              isDetectingAudio: currentlyDetectingAudio)
                }
            }
        }
        
        print("🎙️ [Monitor] Real-time audio monitoring started with 0.1s intervals")
    }
    
    /// Stop real-time audio level monitoring
    private func stopRealTimeAudioMonitoring() {
        print("🎙️ [Monitor] Stopping real-time audio level monitoring")
        
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        // Reset to neutral state
        DispatchQueue.main.async {
            self.currentAudioLevel = 0.0
            self.averageAudioLevel = 0.0
            self.peakAudioLevel = 0.0
            self.isAudioDetected = false
        }
        
        audioLevelHistory.removeAll()
        print("🎙️ [Monitor] Audio level monitoring stopped and state reset")
    }
    
    /// Perform during-recording validation to detect issues early
    private func performDuringRecordingValidation(currentlyDetectingAudio: Bool, 
                                                averagePowerDB: Float, 
                                                peakPowerDB: Float,
                                                normalizedCurrent: Float) {
        totalRecordingIntervals += 1
        
        // Track consecutive silent intervals
        if currentlyDetectingAudio {
            consecutiveSilentIntervals = 0
        } else {
            consecutiveSilentIntervals += 1
        }
        
        // Determine validation status based on audio characteristics
        let validationResult = evaluateRecordingQuality(
            totalIntervals: totalRecordingIntervals,
            consecutiveSilent: consecutiveSilentIntervals,
            averagePowerDB: averagePowerDB,
            peakPowerDB: peakPowerDB,
            normalizedCurrent: normalizedCurrent
        )
        
        // Update UI if status changed
        DispatchQueue.main.async {
            if self.recordingValidationStatus != validationResult.status {
                self.recordingValidationStatus = validationResult.status
                self.recordingIssueDetected = validationResult.issue
                
                // Log status changes
                print("📊 [Validation] Status: \(validationResult.status.description)")
                if let issue = validationResult.issue {
                    print("⚠️ [Validation] Issue: \(issue)")
                }
            }
        }
    }
    
    /// Evaluate recording quality and return validation status
    private func evaluateRecordingQuality(totalIntervals: Int, 
                                        consecutiveSilent: Int, 
                                        averagePowerDB: Float, 
                                        peakPowerDB: Float,
                                        normalizedCurrent: Float) -> (status: RecordingValidationStatus, issue: String?) {
        
        // Early recording phase (first 2 seconds) - be more lenient
        if totalIntervals < 20 {
            return (.unknown, nil)
        }
        
        // Critical errors
        if averagePowerDB < -160.0 && peakPowerDB < -160.0 {
            return (.error, "No microphone input detected")
        }
        
        if consecutiveSilent >= maxConsecutiveSilentIntervals {
            return (.error, "Extended silence detected - check microphone")
        }
        
        // Warning conditions
        if consecutiveSilent >= maxConsecutiveSilentIntervals / 2 {
            return (.warning, "Low audio levels - speak closer to microphone")
        }
        
        if averagePowerDB < -50.0 && peakPowerDB < -45.0 {
            return (.warning, "Very quiet audio - check microphone volume")
        }
        
        if averagePowerDB > -6.0 {
            return (.warning, "Audio levels very high - risk of clipping")
        }
        
        // Good recording conditions
        if normalizedCurrent > 0.01 && averagePowerDB > -40.0 {
            return (.good, nil)
        }
        
        // Default case - still determining
        return (.unknown, nil)
    }
    
    /// Validate preconditions before creating AVAudioRecorder
    private func validateRecorderCreationPreconditions(url: URL, settings: [String: Any]) -> (isValid: Bool, error: String) {
        // Validate URL and path
        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            return (false, "Recording directory does not exist: \(directory.path)")
        }
        
        // Check if file already exists and is writable
        if FileManager.default.fileExists(atPath: url.path) {
            if !FileManager.default.isWritableFile(atPath: url.path) {
                return (false, "Cannot overwrite existing file - not writable: \(url.path)")
            }
        } else {
            // Check if directory is writable
            if !FileManager.default.isWritableFile(atPath: directory.path) {
                return (false, "Recording directory is not writable: \(directory.path)")
            }
        }
        
        // Validate settings format
        guard let formatID = settings[AVFormatIDKey] as? Int else {
            return (false, "Missing or invalid AVFormatIDKey in settings")
        }
        
        guard let sampleRate = settings[AVSampleRateKey] as? Double else {
            return (false, "Missing or invalid AVSampleRateKey in settings")
        }
        
        guard let channels = settings[AVNumberOfChannelsKey] as? Int else {
            return (false, "Missing or invalid AVNumberOfChannelsKey in settings")
        }
        
        // Validate format-specific settings for PCM
        if formatID == Int(kAudioFormatLinearPCM) {
            guard let bitDepth = settings[AVLinearPCMBitDepthKey] as? Int else {
                return (false, "Missing AVLinearPCMBitDepthKey for PCM format")
            }
            
            guard let isFloat = settings[AVLinearPCMIsFloatKey] as? Bool else {
                return (false, "Missing AVLinearPCMIsFloatKey for PCM format")
            }
            
            guard let isBigEndian = settings[AVLinearPCMIsBigEndianKey] as? Bool else {
                return (false, "Missing AVLinearPCMIsBigEndianKey for PCM format")
            }
            
            print("✅ [Validation] PCM format settings validated: \(bitDepth)-bit, float: \(isFloat), bigEndian: \(isBigEndian)")
        }
        
        // Validate reasonable values
        if sampleRate < 8000 || sampleRate > 192000 {
            return (false, "Invalid sample rate: \(sampleRate). Must be between 8000-192000 Hz")
        }
        
        if channels < 1 || channels > 2 {
            return (false, "Invalid channel count: \(channels). Must be 1 or 2")
        }
        
        print("✅ [Validation] Recorder creation preconditions validated")
        return (true, "")
    }
    
    /// Validate created AVAudioRecorder
    private func validateCreatedRecorder(_ recorder: AVAudioRecorder) -> (isValid: Bool, error: String, validationDetails: String) {
        var details: [String] = []
        
        // Validate URL matches expected
        details.append("URL: \(recorder.url.lastPathComponent)")
        
        // Validate format was applied correctly
        let format = recorder.format
        details.append("Format: \(format)")
        details.append("Sample Rate: \(format.sampleRate)Hz")
        details.append("Channels: \(format.channelCount)")
        details.append("Common Format: \(format.commonFormat.rawValue)")
        
        // Check if format is valid (AVAudioRecorder format may not be immediately available)
        // Since preconditions passed, we'll be lenient about format reporting
        if format.sampleRate > 0 && format.channelCount > 0 {
            details.append("✅ Format has valid sample rate and channels")
        } else {
            details.append("⚠️ Format not immediately available (common on macOS) - will use settings")
            // This is actually normal behavior on macOS - the recorder will work with our settings
        }
        
        // Validate basic recorder functionality
        if !recorder.isRecording {
            details.append("Status: Ready to record")
        } else {
            return (false, "Recorder already in recording state", details.joined(separator: ", "))
        }
        
        // Test if metering can be enabled
        recorder.isMeteringEnabled = true
        if recorder.isMeteringEnabled {
            details.append("Metering: Enabled")
        } else {
            return (false, "Failed to enable audio metering", details.joined(separator: ", "))
        }
        
        // Validate file system access
        let testPath = recorder.url.path
        if !FileManager.default.isWritableFile(atPath: testPath.replacingOccurrences(of: recorder.url.lastPathComponent, with: "")) {
            return (false, "No write access to recording directory", details.joined(separator: ", "))
        }
        
        details.append("File Access: Validated")
        
        print("✅ [Validation] AVAudioRecorder validation completed successfully")
        return (true, "", details.joined(separator: ", "))
    }
    
    /// Convert dBFS to normalized level (0.0 to 1.0)
    private func dbToNormalizedLevel(_ dbValue: Float) -> Float {
        // dBFS ranges from -160 (silence) to 0 (max volume)
        // Convert to 0.0-1.0 scale with logarithmic scaling
        let minDB: Float = -60.0  // Treat anything below -60dB as silence
        let maxDB: Float = 0.0    // Maximum level
        
        // Clamp the value
        let clampedDB = max(minDB, min(maxDB, dbValue))
        
        // Convert to linear scale (0.0 to 1.0)
        let normalized = (clampedDB - minDB) / (maxDB - minDB)
        
        return max(0.0, min(1.0, normalized))
    }
    
    /// Log detailed audio level information
    private func logDetailedAudioLevels(averagePowerDB: Float, peakPowerDB: Float, 
                                       normalizedCurrent: Float, runningAverage: Float,
                                       isDetectingAudio: Bool) {
        let audioStatus = isDetectingAudio ? "🎵 AUDIO DETECTED" : "🔇 SILENCE"
        let levelDescription = self.getAudioLevelDescription(normalizedCurrent)
        
        print("🎙️ [Monitor] \(audioStatus) - \(levelDescription)")
        print("🎙️ [Monitor] Current: \(String(format: "%.3f", normalizedCurrent)) (\(String(format: "%.1f", averagePowerDB))dB)")
        print("🎙️ [Monitor] Average: \(String(format: "%.3f", runningAverage)), Peak: \(String(format: "%.3f", peakAudioLevel))")
        
        // Diagnostic warnings
        if averagePowerDB < -50.0 && peakPowerDB < -50.0 {
            print("⚠️ [Monitor] Very low audio levels - check microphone connection/permissions")
        } else if averagePowerDB > -10.0 {
            print("🔊 [Monitor] Very high audio levels - possible clipping/distortion risk")
        } else if isDetectingAudio {
            print("✅ [Monitor] Good audio levels detected")
        }
    }
    
    /// Get human-readable description of audio level
    private func getAudioLevelDescription(_ level: Float) -> String {
        switch level {
        case 0.0..<0.003:
            return "Silent"
        case 0.003..<0.01:
            return "Very Quiet"
        case 0.01..<0.05:
            return "Quiet"
        case 0.05..<0.2:
            return "Normal"
        case 0.2..<0.5:
            return "Loud"
        case 0.5..<0.8:
            return "Very Loud"
        case 0.8...1.0:
            return "Maximum"
        default:
            return "Unknown"
        }
    }
    
    /// Get current audio monitoring status for diagnostics
    func getAudioMonitoringStatus() -> String {
        let status = """
        🎙️ Audio Monitoring Status:
        - Current Level: \(String(format: "%.3f", currentAudioLevel)) (\(getAudioLevelDescription(currentAudioLevel)))
        - Average Level: \(String(format: "%.3f", averageAudioLevel))
        - Peak Level: \(String(format: "%.3f", peakAudioLevel))
        - Audio Detected: \(isAudioDetected ? "YES" : "NO")
        - History Count: \(audioLevelHistory.count)/\(maxHistoryCount)
        - Monitoring Active: \(audioLevelTimer != nil ? "YES" : "NO")
        """
        return status
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