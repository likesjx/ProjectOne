import SwiftUI

enum TranscriptionCorrectionType: String, CaseIterable {
    case wordReplacement = "wordReplacement"
    case punctuation = "punctuation"
    case capitalization = "capitalization"
    case vocabulary = "vocabulary"
    case grammarFix = "grammarFix"
    case contextualFix = "contextualFix"
}

struct TranscriptionCorrectionView: View {
    let originalText: String
    @Binding var correctedText: String
    let audioURL: URL?
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var correctionType: TranscriptionCorrectionType = .wordReplacement
    @State private var showingTypeSelector = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Correct Transcription")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Help improve accuracy by correcting this transcription")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Original text display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Original:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(originalText)
                        .font(.body)
                        .padding()
                        .background({
                            #if os(iOS)
                            Color(.systemGray6)
                            #else
                            Color(.windowBackgroundColor)
                            #endif
                        }())
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Corrected text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corrected:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    TextField("Enter corrected text", text: $correctedText, axis: .vertical)
                        .font(.body)
                        .padding()
                        .background({
                            #if os(iOS)
                            Color(.systemBackground)
                            #else
                            Color(.textBackgroundColor)
                            #endif
                        }())
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .lineLimit(3...10)
                }
                
                // Correction type selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("Correction Type:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        showingTypeSelector = true
                    }) {
                        HStack {
                            Text(correctionType.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background({
                            #if os(iOS)
                            Color(.systemGray6)
                            #else
                            Color(.windowBackgroundColor)
                            #endif
                        }())
                        .cornerRadius(8)
                    }
                }
                
                // Helpful tips
                CorrectionTipsCard(correctionType: correctionType)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background({
                        #if os(iOS)
                        Color(.systemGray5)
                        #else
                        Color(.controlBackgroundColor)
                        #endif
                    }())
                    .foregroundColor(.primary)
                    .cornerRadius(10)
                    
                    Button("Save Correction") {
                        onSave(originalText, correctedText)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(hasChanges ? Color.blue : {
                        #if os(iOS)
                        Color(.systemGray4)
                        #else
                        Color(.disabledControlTextColor)
                        #endif
                    }())
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!hasChanges)
                }
            }
            .padding()
            .onAppear {
                isTextFieldFocused = true
                // Auto-detect correction type
                correctionType = detectCorrectionType(original: originalText, corrected: correctedText)
            }
            .onChange(of: correctedText) { _, newValue in
                correctionType = detectCorrectionType(original: originalText, corrected: newValue)
            }
            .confirmationDialog("Select Correction Type", isPresented: $showingTypeSelector) {
                ForEach(TranscriptionCorrectionType.allCases, id: \.self) { type in
                    Button(type.displayName) {
                        correctionType = type
                    }
                }
                
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    private var hasChanges: Bool {
        !correctedText.isEmpty && correctedText != originalText
    }
    
    private func detectCorrectionType(original: String, corrected: String) -> TranscriptionCorrectionType {
        let originalWords = original.components(separatedBy: .whitespaces)
        let correctedWords = corrected.components(separatedBy: .whitespaces)
        
        if originalWords.count != correctedWords.count {
            return .grammarFix
        } else if original.lowercased() == corrected.lowercased() {
            return .capitalization
        } else if original.replacingOccurrences(of: " ", with: "") == corrected.replacingOccurrences(of: " ", with: "") {
            return .punctuation
        } else {
            return .wordReplacement
        }
    }
}

struct CorrectionTipsCard: View {
    let correctionType: TranscriptionCorrectionType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.orange)
                Text("Tips")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tipsForCorrectionType, id: \.self) { tip in
                    HStack(alignment: .top) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(tip)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var tipsForCorrectionType: [String] {
        switch correctionType {
        case .wordReplacement:
            return [
                "Replace words that were misheard",
                "Use this for vocabulary corrections",
                "Common fixes: homophones, similar-sounding words"
            ]
        case .punctuation:
            return [
                "Add missing punctuation marks",
                "Correct sentence boundaries",
                "Fix capitalization after periods"
            ]
        case .capitalization:
            return [
                "Correct proper nouns and sentence starts",
                "Fix acronyms and abbreviations",
                "Names, places, and organizations"
            ]
        case .vocabulary:
            return [
                "Teach new vocabulary words",
                "Add technical terms or jargon",
                "Personal names and references"
            ]
        case .grammarFix:
            return [
                "Fix sentence structure",
                "Correct verb tenses",
                "Add or remove words for clarity"
            ]
        case .contextualFix:
            return [
                "Fix meaning based on context",
                "Clarify ambiguous phrases",
                "Improve overall understanding"
            ]
        }
    }
}

// Extension for display names
extension TranscriptionCorrectionType {
    var displayName: String {
        switch self {
        case .wordReplacement:
            return "Word Replacement"
        case .punctuation:
            return "Punctuation"
        case .capitalization:
            return "Capitalization"
        case .vocabulary:
            return "Vocabulary"
        case .grammarFix:
            return "Grammar Fix"
        case .contextualFix:
            return "Contextual Fix"
        }
    }
}

#Preview {
    @Previewable @State var correctedText = "This is the corrected text"
    
    TranscriptionCorrectionView(
        originalText: "This is the original text",
        correctedText: $correctedText,
        audioURL: nil,
        onSave: { original, corrected in
            print("Save: \(original) -> \(corrected)")
        },
        onCancel: {
            print("Cancel")
        }
    )
}