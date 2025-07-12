//
//  VoiceMemoView.swift
//  ProjectOne
//
//  Created on 7/10/25.
//

import SwiftUI
import SwiftData

struct VoiceMemoView: View {
    let modelContext: ModelContext
    
    @StateObject private var audioRecorder: AudioRecorder
    @StateObject private var audioPlayer = AudioPlayer()
    @State private var hasRequestedPermission = false
    @State private var showingNoteCreation = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Configure speech engine for automatic best-available strategy
        let speechConfig = SpeechEngineConfiguration(
            strategy: .automatic,
            enableFallback: true,
            preferredLanguage: "en-US"
        )
        
        self._audioRecorder = StateObject(wrappedValue: AudioRecorder(
            modelContext: modelContext,
            speechEngineConfiguration: speechConfig
        ))
    }
    
    var body: some View {
        LiquidGlassView {
            ScrollView {
                LazyVStack(spacing: 32) {
                    // Liquid Glass Header with Extended Background
                    LiquidGlassHeader {
                        VStack(spacing: 16) {
                            LiquidGlassIcon(
                                icon: "mic.fill",
                                size: 48,
                                color: audioRecorder.isRecording ? .red : .blue,
                                isAnimated: audioRecorder.isRecording
                            )
                            
                            VStack(spacing: 8) {
                                Text("Voice Memos")
                                    .font(.title.weight(.semibold))
                                    .foregroundStyle(.primary)
                                
                                Text("Record audio and get instant AI transcriptions")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .liquidGlassHeaderExtension(.blue.opacity(0.1))
                    
                    // Enhanced Quick Action Bar
                    LiquidGlassQuickActionBar(
                        audioRecorder: audioRecorder,
                        gemmaCore: Gemma3nCore.shared,
                        hasRequestedPermission: $hasRequestedPermission,
                        showingNoteCreation: $showingNoteCreation,
                        onAudioRecorded: { audioURL in
                            print("Audio recorded: \(audioURL)")
                        }
                    )
                    
                    // Dynamic Status Display
                    LiquidGlassStatusCard(
                        audioRecorder: audioRecorder,
                        hasRequestedPermission: hasRequestedPermission
                    )
                    
                    // Recent Recordings with Liquid Glass
                    if !audioRecorder.recordings.isEmpty {
                        LiquidGlassRecentRecordings(
                            recordings: audioRecorder.recordings,
                            audioPlayer: audioPlayer
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Voice Memos")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .liquidGlassNavigation()
        .sheet(isPresented: $showingNoteCreation) {
            LiquidGlassSheet {
                NoteCreationView()
            }
        }
    }
}

// MARK: - Enhanced Liquid Glass Components

struct LiquidGlassView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(.ultraThinMaterial)
            .containerRelativeFrame([.horizontal, .vertical])
    }
}

struct LiquidGlassHeader<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.vertical, 32)
            .padding(.horizontal, 24)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
            }
            .compositingGroup()
    }
}

struct LiquidGlassIcon: View {
    let icon: String
    let size: CGFloat
    let color: Color
    var isAnimated: Bool = false
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color.gradient)
            .symbolEffect(.variableColor.iterative, isActive: isAnimated)
            .symbolEffect(.pulse, isActive: isAnimated)
            .background {
                Circle()
                    .fill(.regularMaterial)
                    .overlay { color.opacity(0.2) }
                    .frame(width: size * 1.8, height: size * 1.8)
            }
    }
}

struct LiquidGlassQuickActionBar: View {
    let audioRecorder: AudioRecorder
    let gemmaCore: Gemma3nCore
    @Binding var hasRequestedPermission: Bool
    @Binding var showingNoteCreation: Bool
    let onAudioRecorded: (URL) -> Void
    
    @State private var showingTranscriptionView = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Real-time transcription with enhanced glass
            if audioRecorder.isRecording && !audioRecorder.realtimeTranscription.isEmpty {
                LiquidGlassTranscriptionCard(
                    text: audioRecorder.realtimeTranscription,
                    onTap: { showingTranscriptionView = true }
                )
                .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .bottom).combined(with: .opacity)))
            }
            
            // Action buttons in glass container
            HStack(spacing: 16) {
                // Primary record button
                LiquidGlassRecordButton(
                    audioRecorder: audioRecorder,
                    isEnabled: hasRequestedPermission || !audioRecorder.isRecording
                ) {
                    handleAudioButtonTap()
                }
                
                // Secondary actions
                if audioRecorder.currentTranscription != nil || audioRecorder.isTranscribing {
                    LiquidGlassActionButton(
                        icon: "text.bubble.fill",
                        label: "View",
                        color: .purple,
                        style: .secondary
                    ) {
                        print("🟣 [ViewButton] Tapped - opening transcription view")
                        showingTranscriptionView = true
                        print("🟣 [ViewButton] showingTranscriptionView set to: \(showingTranscriptionView)")
                    }
                }
                
                Spacer()
                
                LiquidGlassActionButton(
                    icon: "plus.circle.fill",
                    label: "Note",
                    color: .green,
                    style: .secondary
                ) {
                    print("🟢 [NoteButton] Tapped - opening note creation")
                    showingNoteCreation = true
                    print("🟢 [NoteButton] showingNoteCreation set to: \(showingNoteCreation)")
                }
            }
        }
        .padding(.horizontal, 4)
        .animation(.smooth(duration: 0.4), value: audioRecorder.isRecording)
        .animation(.smooth(duration: 0.4), value: audioRecorder.realtimeTranscription.isEmpty)
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
        if !hasRequestedPermission {
            requestMicrophonePermission()
        } else {
            if audioRecorder.isRecording {
                audioRecorder.stopRecording()
            } else {
                audioRecorder.startRecording()
            }
        }
    }
    
    private func requestMicrophonePermission() {
        print("🎤 [Permission] Requesting microphone permission...")
        audioRecorder.requestPermission { granted in
            DispatchQueue.main.async {
                print("🎤 [Permission] Permission granted: \(granted)")
                hasRequestedPermission = true
                if granted {
                    print("🎤 [Permission] Starting recording after permission granted")
                    audioRecorder.startRecording()
                } else {
                    print("🎤 [Permission] Permission denied, not starting recording")
                }
            }
        }
    }
}

struct LiquidGlassRecordButton: View {
    @ObservedObject var audioRecorder: AudioRecorder
    let isEnabled: Bool
    let action: () -> Void
    
    private var isRecording: Bool {
        audioRecorder.isRecording
    }
    
    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulsing ring when recording
                if isRecording {
                    Circle()
                        .stroke(.red.opacity(0.3), lineWidth: 2)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                }
                
                // Main button
                Circle()
                    .fill(.regularMaterial)
                    .overlay { isRecording ? Color.red.opacity(0.3) : Color.blue.opacity(0.3) }
                    .frame(width: 80, height: 80)
                    .overlay {
                        let icon = isRecording ? "stop.fill" : "mic.fill"
                        let _ = print("🔴 [RecordButton] isRecording: \(isRecording), icon: \(icon)")
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(isRecording ? .red : .blue)
                            .symbolEffect(.bounce, value: isPressed)
                    }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onAppear {
            if isRecording {
                startPulseAnimation()
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startPulseAnimation()
            } else {
                pulseScale = 1.0
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
    }
}

struct LiquidGlassActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var style: ButtonStyle = .primary
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            print("🔘 [ActionButton] \(label) button tapped!")
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                
                if style == .primary {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .foregroundStyle(color)
            .padding(.horizontal, style == .primary ? 20 : 12)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: style == .primary ? 25 : 20, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay { color.opacity(0.2) }
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct LiquidGlassStatusCard: View {
    @ObservedObject var audioRecorder: AudioRecorder
    let hasRequestedPermission: Bool
    
    private var statusInfo: (icon: String, title: String, subtitle: String, color: Color, isAnimated: Bool, showProgress: Bool) {
        if !hasRequestedPermission {
            return ("hand.tap", "Tap to Begin", "Tap the record button to get started", .blue, false, false)
        } else if audioRecorder.isRecording {
            return ("waveform", "Recording", "Recording in progress...", .red, true, false)
        } else if audioRecorder.isTranscribing {
            return ("brain", "Processing", "Generating transcription...", .blue, false, true)
        } else {
            return ("checkmark.circle", "Ready to Record", "Ready to record", .green, false, false)
        }
    }
    
    var body: some View {
        let status = statusInfo
        let _ = print("🎛️ [StatusCard] hasRequestedPermission: \(hasRequestedPermission), isRecording: \(audioRecorder.isRecording), status: \(status.title)")
        
        return HStack(spacing: 16) {
            Group {
                if status.showProgress {
                    ProgressView()
                        .tint(status.color)
                        .scaleEffect(0.9)
                } else if audioRecorder.isRecording {
                    SoundWaveVisualization(isActive: true, color: status.color)
                } else {
                    Image(systemName: status.icon)
                        .font(.system(size: 24, weight: .medium))
                        .symbolEffect(.pulse, isActive: status.isAnimated)
                }
            }
            .foregroundStyle(status.color)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(status.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(status.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .overlay { status.color.opacity(0.1) }
        }
        .animation(.smooth(duration: 0.3), value: statusInfo.title)
    }
}

struct LiquidGlassTranscriptionCard: View {
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: "waveform")
                    .foregroundStyle(.blue)
                    .font(.system(size: 18, weight: .medium))
                    .symbolEffect(.variableColor.iterative)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Transcription")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                    
                    Text(text.isEmpty ? "Listening..." : text)
                        .font(.system(size: 15))
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.blue)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay { Color.blue.opacity(0.15) }
            }
        }
        .buttonStyle(.plain)
    }
}

struct LiquidGlassRecentRecordings: View {
    let recordings: [URL]
    let recordingItems: [RecordingItem]
    let audioPlayer: AudioPlayer
    
    private func findRecordingItem(for url: URL) -> RecordingItem? {
        return recordingItems.first { $0.fileURL == url }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Recordings")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(recordings.prefix(5), id: \.self) { recording in
                    LiquidGlassRecordingRow(
                        recording: recording,
                        audioPlayer: audioPlayer,
                        recordingItem: findRecordingItem(for: recording)
                    )
                }
            }
        }
    }
}

struct LiquidGlassRecordingRow: View {
    let recording: URL
    let audioPlayer: AudioPlayer
    let recordingItem: RecordingItem?
    
    @State private var isHovered = false
    
    var isCurrentlyPlaying: Bool {
        audioPlayer.currentURL == recording && audioPlayer.isPlaying
    }
    
    var isCurrentlyLoaded: Bool {
        audioPlayer.currentURL == recording
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Main recording info and controls
            HStack(spacing: 16) {
                Image(systemName: isCurrentlyPlaying ? "waveform.circle.fill" : "waveform.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isCurrentlyLoaded ? .blue : .secondary)
                    .symbolEffect(.variableColor.iterative, isActive: isCurrentlyPlaying)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatRecordingName(recording.lastPathComponent))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        Text(formatRecordingDate(from: recording.lastPathComponent))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if isCurrentlyLoaded && audioPlayer.duration > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(audioPlayer.formattedDuration)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 12) {
                    if isCurrentlyLoaded && audioPlayer.duration > 0 {
                        Text(audioPlayer.formattedCurrentTime)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        handlePlaybackTap()
                    } label: {
                        Image(systemName: playbackButtonIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.blue)
                            .symbolEffect(.bounce, value: isCurrentlyPlaying)
                    }
                    .disabled(audioPlayer.isLoaded && !isCurrentlyLoaded && audioPlayer.isPlaying)
                }
            }
            
            // Transcription text if available
            if let transcription = recordingItem?.transcriptionText, !transcription.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "text.bubble")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Transcription")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if let confidence = recordingItem?.transcriptionConfidence, confidence > 0 {
                            Text("\(Int(confidence * 100))%")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    
                    Text(transcription)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(4)
                }
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
            
            // Progress bar when playing current recording
            if isCurrentlyLoaded && audioPlayer.duration > 0 {
                VStack(spacing: 8) {
                    ProgressView(value: audioPlayer.playbackProgress)
                        .tint(.blue)
                        .background(.secondary.opacity(0.3))
                        .scaleEffect(y: 0.5)
                    
                    HStack {
                        Text("0:00")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                        
                        Text(audioPlayer.formattedDuration)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .overlay { 
                    if isCurrentlyLoaded {
                        Color.blue.opacity(0.1)
                    } else {
                        Color.primary.opacity(0.05)
                    }
                }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.smooth(duration: 0.3), value: isCurrentlyLoaded)
        .animation(.smooth(duration: 0.3), value: isCurrentlyPlaying)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var playbackButtonIcon: String {
        if isCurrentlyPlaying {
            return "pause.circle.fill"
        } else if isCurrentlyLoaded {
            return "play.circle.fill"
        } else {
            return "play.circle"
        }
    }
    
    private func handlePlaybackTap() {
        if isCurrentlyLoaded {
            audioPlayer.togglePlayback()
        } else {
            audioPlayer.loadAudio(from: recording)
            audioPlayer.play()
        }
    }
    
    private func formatRecordingName(_ filename: String) -> String {
        // Remove file extension
        let nameWithoutExtension = filename.replacingOccurrences(of: ".m4a", with: "")
        
        // Try to parse as date format (dd-MM-YY_HH-mm-ss)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yy_HH-mm-ss"
        
        if let date = dateFormatter.date(from: nameWithoutExtension) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .none
            displayFormatter.timeStyle = .short
            return "Recording \(displayFormatter.string(from: date))"
        }
        
        return nameWithoutExtension
    }
    
    private func formatRecordingDate(from filename: String) -> String {
        let nameWithoutExtension = filename.replacingOccurrences(of: ".m4a", with: "")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yy_HH-mm-ss"
        
        if let date = dateFormatter.date(from: nameWithoutExtension) {
            let now = Date()
            let calendar = Calendar.current
            
            if calendar.isDate(date, inSameDayAs: now) {
                return "Today"
            } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
                return "Yesterday"
            } else {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .short
                return displayFormatter.string(from: date)
            }
        }
        
        return "Unknown date"
    }
}

struct LiquidGlassSheet<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        NavigationStack {
            content
                .background(.regularMaterial)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(24)
        }
    }
}

struct NoteCreationView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Create Note")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            
            // Note creation form would go here
            Text("Note creation interface")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - View Extensions

extension View {
    func liquidGlassHeaderExtension(_ color: Color) -> some View {
        self
            .background {
                // Extended background that blurs under other content
                Rectangle()
                    .fill(.regularMaterial)
                    .overlay { color }
                    .ignoresSafeArea(.container, edges: .horizontal)
                    .frame(height: 200)
                    .offset(y: -50)
                    .blur(radius: 20, opaque: false)
            }
    }
    
    func liquidGlassNavigation() -> some View {
        self
#if os(iOS)
            .toolbarBackground(.regularMaterial, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            #endif
    }
}

// MARK: - Legacy Components (Updated)

struct StatusGlassPanel: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    var isAnimated: Bool = false
    var showProgress: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            if showProgress {
                ProgressView()
                    .tint(color)
                    .scaleEffect(0.9)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, isActive: isAnimated)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassEffect(.regular.tint(color.opacity(0.1)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct GlassQuickActionBar: View {
    let audioRecorder: AudioRecorder
    let gemmaCore: Gemma3nCore
    @Binding var hasRequestedPermission: Bool
    @Binding var showingNoteCreation: Bool
    let onAudioRecorded: (URL) -> Void
    
    @State private var showingTranscriptionView = false
    
    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 16) {
                // Real-time transcription preview with glass effect
                if audioRecorder.isRecording && !audioRecorder.realtimeTranscription.isEmpty {
                    GlassTranscriptionPreview(
                        text: audioRecorder.realtimeTranscription,
                        onTap: { showingTranscriptionView = true }
                    )
                }
                
                // Main action buttons with Glass effects
                HStack(spacing: 20) {
                    // Audio recording button
                    GlassButton(
                        icon: audioRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill",
                        label: audioRecorder.isRecording ? "Stop" : "Record",
                        color: audioRecorder.isRecording ? .red : .blue,
                        isRecording: audioRecorder.isRecording
                    ) {
                        handleAudioButtonTap()
                    }
                    .disabled(audioRecorder.isRecording && !hasRequestedPermission)
                    
                    // Transcription view button
                    if audioRecorder.currentTranscription != nil || audioRecorder.isTranscribing {
                        GlassButton(
                            icon: "text.bubble.fill",
                            label: "View",
                            color: .purple
                        ) {
                            showingTranscriptionView = true
                        }
                    }
                    
                    Spacer()
                    
                    // Quick text note button
                    GlassButton(
                        icon: "plus.circle.fill",
                        label: "Note",
                        color: .green
                    ) {
                        showingNoteCreation = true
                    }
                }
            }
        }
        .padding(.horizontal, 4)
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
        if !hasRequestedPermission {
            requestMicrophonePermission()
        } else {
            if audioRecorder.isRecording {
                audioRecorder.stopRecording()
            } else {
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

struct GlassButton: View {
    let icon: String
    let label: String
    let color: Color
    var isRecording: Bool = false
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                    .symbolEffect(.bounce, value: isPressed)
                
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(color.opacity(0.2)).interactive(), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

struct GlassTranscriptionPreview: View {
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .foregroundStyle(.blue)
                    .font(.system(size: 16, weight: .medium))
                    .symbolEffect(.variableColor.iterative)
                
                Text(text.isEmpty ? "Listening..." : text)
                    .font(.system(size: 15))
                    .foregroundStyle(text.isEmpty ? .secondary : .primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.blue)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular.tint(.blue.opacity(0.1)).interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SoundWaveVisualization: View {
    let isActive: Bool
    let color: Color
    
    @State private var animationValues: [Double] = Array(repeating: 0.3, count: 5)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.gradient)
                    .frame(width: 3, height: 24 * animationValues[index])
                    .animation(
                        .easeInOut(duration: Double.random(in: 0.3...0.8))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: animationValues[index]
                    )
            }
        }
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in 0..<animationValues.count {
            animationValues[i] = Double.random(in: 0.4...1.0)
        }
        
        // Continue updating values while active
        if isActive {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.isActive {
                    self.startAnimation()
                }
            }
        }
    }
    
    private func stopAnimation() {
        for i in 0..<animationValues.count {
            animationValues[i] = 0.3
        }
    }
}

#Preview {
    @Previewable @State var modelContainer = try! ModelContainer(for: Entity.self, Relationship.self)
    NavigationView {
        VoiceMemoView(modelContext: modelContainer.mainContext)
    }
}