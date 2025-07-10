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

class AudioRecorder: NSObject, ObservableObject {
    var audioRecorder: AVAudioRecorder?
    
    @Published var isRecording = false
    @Published var recordings: [URL] = []
    @Published var transcriptionStatus: TranscriptionStatus = .idle
    @Published var currentTranscription: TranscriptionResult?
    @Published var isTranscribing = false
    
    // Transcription engine
    private let transcriptionEngine: TranscriptionEngine
    private let modelContext: ModelContext
    
    // Real-time transcription support
    @Published var realtimeTranscription = ""
    private var transcriptionTimer: Timer?
    
    init(modelContext: ModelContext) {
        print("🎤 [Performance] Initializing AudioRecorder...")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Initialize transcription components
        self.modelContext = modelContext
        self.transcriptionEngine = PlaceholderEngine(modelContext: modelContext)
        
        super.init()
        
        print("📁 [Performance] Fetching existing recordings...")
        fetchRecordings()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        print("✅ [Performance] AudioRecorder initialized in \(String(format: "%.2f", endTime - startTime))s")
    }
    
    func setupRecording() {
        // Setup is done when needed in startRecording
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
        #else
        // macOS doesn't require explicit permission request for microphone in this context
        DispatchQueue.main.async {
            completion(true)
        }
        #endif
    }
    
    func startRecording() {
        print("🎤 [Debug] startRecording() called")
        
        #if os(iOS)
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            print("🎤 [Debug] Audio session configured successfully")
        } catch {
            print("Failed to set up recording session: \(error.localizedDescription)")
            return
        }
        #endif
        
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(Date().toString(dateFormat: "dd-MM-YY_HH-mm-ss")).m4a")
        print("🎤 [Debug] Recording to: \(audioFilename.lastPathComponent)")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                print("🎤 [Debug] isRecording set to true on main thread")
            }
            
            // Start real-time transcription simulation
            startRealtimeTranscriptionSimulation()
            
        } catch {
            print("Could not start recording: \(error.localizedDescription)")
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
        
        // Get the last recorded file and transcribe it
        if let lastRecordingURL = audioRecorder?.url {
            print("🛑 [Debug] Starting transcription for: \(lastRecordingURL.lastPathComponent)")
            Task {
                await transcribeRecording(url: lastRecordingURL)
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
    
    func deleteRecording(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            fetchRecordings()
        } catch {
            print("File could not be deleted: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Transcription Methods
    
    func transcribeRecording(url: URL) async {
        print("🎤 [Debug] Starting transcription process for: \(url.lastPathComponent)")
        
        await MainActor.run {
            isTranscribing = true
            transcriptionStatus = .processing
            currentTranscription = nil
        }
        
        do {
            print("🎤 [Debug] Calling transcriptionEngine.transcribe()")
            let audioData = try Data(contentsOf: url)
            let result = try await transcriptionEngine.transcribeAudio(audioData)
            print("🎤 [Debug] Transcription completed: \(result.text.prefix(50))...")
            
            await MainActor.run {
                currentTranscription = result
                transcriptionStatus = .completed
                isTranscribing = false
            }
            
            print("🎤 [Debug] Transcription result saved to currentTranscription")
            
        } catch {
            await MainActor.run {
                transcriptionStatus = .failed(error)
                isTranscribing = false
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
        return currentTranscription?.confidence ?? 0.0
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