import SwiftUI
import SwiftData

struct TranscriptionDisplayView: View {
    let audioRecorder: AudioRecorder
    let gemmaCore: Gemma3nCore
    @Binding var isPresented: Bool
    
    @State private var showingCorrection = false
    @State private var correctedText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Transcription Status
                    if audioRecorder.isTranscribing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Transcribing audio...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let transcription = audioRecorder.currentTranscription {
                        // Transcription Content
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Transcription")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text(transcription.text)
                                .font(.body)
                                .padding()
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                                .textSelection(.enabled)
                            
                            // Action Buttons
                            HStack(spacing: 16) {
                                Button(action: {
                                    correctedText = transcription.text
                                    showingCorrection = true
                                }) {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Correct")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    copyToClipboard(transcription.text)
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.doc")
                                        Text("Copy")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                    } else {
                        // No transcription available
                        VStack(spacing: 12) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            
                            Text("No transcription available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Start recording to generate transcription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .padding()
            }
            .navigationTitle("Transcription")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: {
                    #if os(iOS)
                    .navigationBarTrailing
                    #else
                    .automatic
                    #endif
                }()) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingCorrection) {
                if let transcription = audioRecorder.currentTranscription {
                    TranscriptionCorrectionView(
                        originalText: transcription.text,
                        correctedText: $correctedText,
                        audioURL: nil,
                        onSave: { original, corrected in
                            // Handle transcription correction
                            print("Transcription corrected: \(original) -> \(corrected)")
                            showingCorrection = false
                        },
                        onCancel: {
                            showingCorrection = false
                        }
                    )
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #endif
    }
}

#Preview {
    @Previewable @State var isPresented = true
    @Previewable @State var modelContainer = try! ModelContainer(for: Entity.self, Relationship.self)
    
    TranscriptionDisplayView(
        audioRecorder: AudioRecorder(modelContext: modelContainer.mainContext),
        gemmaCore: Gemma3nCore.shared,
        isPresented: $isPresented
    )
}