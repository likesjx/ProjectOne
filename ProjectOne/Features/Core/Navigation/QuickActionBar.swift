//
//  QuickActionBar.swift
//  ProjectOne
//
//  Created on 6/28/25.
//

import SwiftUI
import AVFoundation
import SwiftData

struct QuickActionBar: View {
    let audioRecorder: AudioRecorder
    let gemmaCore: EnhancedGemma3nCore
    @Binding var hasRequestedPermission: Bool
    @Binding var showingNoteCreation: Bool
    let onAudioRecorded: (URL) -> Void
    
    @State private var showingTranscriptionView = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Real-time transcription preview (when recording)
            if audioRecorder.isRecording && !audioRecorder.realtimeTranscription.isEmpty {
                RealtimeTranscriptionPreview(
                    text: audioRecorder.realtimeTranscription,
                    onTap: {
                        showingTranscriptionView = true
                    }
                )
            }
            
            // Main action buttons
            HStack(spacing: 16) {
                // Audio recording button
                Button(action: handleAudioButtonTap) {
                    HStack {
                        Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(audioRecorder.isRecording ? .red : .blue)
                        
                        if !audioRecorder.isRecording {
                            Text("Record")
                                .font(.system(size: 14, weight: .medium))
                        } else {
                            Text("Stop")
                                .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(audioRecorder.isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                            .stroke(audioRecorder.isRecording ? Color.red : Color.blue, lineWidth: 1)
                    )
                }
                .disabled(audioRecorder.isRecording && !hasRequestedPermission)
                
                // Transcription view button (when transcription is available)
                if audioRecorder.currentTranscription != nil || audioRecorder.isTranscribing {
                    Button(action: {
                        showingTranscriptionView = true
                    }) {
                        HStack {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                            
                            Text("View")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.purple.opacity(0.1))
                                .stroke(Color.purple, lineWidth: 1)
                        )
                    }
                }
                
                Spacer()
                
                // Quick text note button
                Button(action: {
                    showingNoteCreation = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        
                        Text("Note")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green.opacity(0.1))
                            .stroke(Color.green, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal)
        #if os(iOS)
        .fullScreenCover(isPresented: $showingTranscriptionView) {
            TranscriptionDisplayView(
                audioRecorder: audioRecorder,
                gemmaCore: gemmaCore,
                isPresented: $showingTranscriptionView
            )
        }
        #else
        .sheet(isPresented: $showingTranscriptionView) {
            TranscriptionDisplayView(
                audioRecorder: audioRecorder,
                gemmaCore: gemmaCore,
                isPresented: $showingTranscriptionView
            )
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: .audioRecordingFinished)) { notification in
            if let audioURL = notification.object as? URL {
                onAudioRecorded(audioURL)
            }
        }
    }
    
    private func handleAudioButtonTap() {
        print("🎯 [Debug] Audio button tapped. hasRequestedPermission: \(hasRequestedPermission), isRecording: \(audioRecorder.isRecording)")
        
        if !hasRequestedPermission {
            print("🎯 [Debug] Requesting microphone permission")
            requestMicrophonePermission()
        } else {
            if audioRecorder.isRecording {
                print("🎯 [Debug] Stopping recording")
                audioRecorder.stopRecording()
            } else {
                print("🎯 [Debug] Starting recording")
                audioRecorder.startRecording()
            }
        }
    }
    
    private func requestMicrophonePermission() {
        audioRecorder.requestPermission { granted in
            DispatchQueue.main.async {
                hasRequestedPermission = true
                if granted {
                    audioRecorder.startRecording()
                }
            }
        }
    }
}

struct RealtimeTranscriptionPreview: View {
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text(text.isEmpty ? "Listening..." : text)
                    .font(.caption)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.blue)
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension Notification.Name {
    static let audioRecordingFinished = Notification.Name("audioRecordingFinished")
}

#Preview {
    @Previewable @State var modelContainer = try! SwiftData.ModelContainer(for: Entity.self, Relationship.self)
    QuickActionBar(
        audioRecorder: AudioRecorder(modelContext: modelContainer.mainContext),
        gemmaCore: EnhancedGemma3nCore(),
        hasRequestedPermission: .constant(true),
        showingNoteCreation: .constant(false),
        onAudioRecorded: { _ in }
    )
}