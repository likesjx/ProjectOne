//
//  AudioPlayer.swift
//  ProjectOne
//
//  Created on 7/11/25.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentURL: URL?
    @Published var playbackProgress: Double = 0
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    deinit {
        // Note: Cannot call MainActor methods from deinit
        // stopPlayback() should be called manually before deallocation
        // Timer cleanup is handled in stopPlayback() method which should be called before deallocation
    }
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
        #endif
    }
    
    func loadAudio(from url: URL) {
        stopPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            currentURL = url
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            playbackProgress = 0
            
            print("🎵 [AudioPlayer] Loaded audio: \(url.lastPathComponent), duration: \(duration)s")
        } catch {
            print("🎵 [AudioPlayer] Failed to load audio: \(error.localizedDescription)")
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        
        player.play()
        isPlaying = true
        startProgressTimer()
        
        print("🎵 [AudioPlayer] Started playback")
    }
    
    func pause() {
        guard let player = audioPlayer else { return }
        
        player.pause()
        isPlaying = false
        stopProgressTimer()
        
        print("🎵 [AudioPlayer] Paused playback")
    }
    
    func stop() {
        stopPlayback()
        seek(to: 0)
        
        print("🎵 [AudioPlayer] Stopped playback")
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        
        let clampedTime = max(0, min(time, duration))
        player.currentTime = clampedTime
        currentTime = clampedTime
        updateProgress()
        
        print("🎵 [AudioPlayer] Seeked to: \(clampedTime)s")
    }
    
    func seekToProgress(_ progress: Double) {
        let time = progress * duration
        seek(to: time)
    }
    
    private func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = false
        stopProgressTimer()
    }
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Use DispatchQueue.main.async to ensure main actor context for updateProgress()
            DispatchQueue.main.async {
                self?.updateProgress()
            }
        }
        // Ensure timer runs on main RunLoop to avoid dispatch queue assertion failures
        if let timer = progressTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        currentTime = player.currentTime
        playbackProgress = duration > 0 ? currentTime / duration : 0
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    var formattedDuration: String {
        formatTime(duration)
    }
    
    var isLoaded: Bool {
        audioPlayer != nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayer: @preconcurrency AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Since AudioPlayer is @MainActor, delegate methods are already on main thread
        self.isPlaying = false
        self.currentTime = 0
        self.playbackProgress = 0
        self.stopProgressTimer()
        
        print("🎵 [AudioPlayer] Finished playing")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        // Since AudioPlayer is @MainActor, delegate methods are already on main thread
        self.isPlaying = false
        self.stopProgressTimer()
        
        if let error = error {
            print("🎵 [AudioPlayer] Decode error: \(error.localizedDescription)")
        }
    }
}