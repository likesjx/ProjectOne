//
//  APIKeyManagementView.swift
//  ProjectOne
//
//  User interface for securely managing API keys for external AI providers
//  Integrates with APIKeyManager for secure keychain storage
//

import SwiftUI

@available(iOS 26.0, macOS 26.0, *)
struct APIKeyManagementView: View {
    
    // MARK: - State Management
    
    @StateObject private var keyManager = APIKeyManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var openAIKey = ""
    @State private var openRouterKey = ""
    @State private var ollamaBaseURL = "http://localhost:11434"
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    
    @State private var isLoading = false
    @State private var secureFieldVisibility: [APIKeyManager.Provider: Bool] = [:]
    
    var body: some View {
        NavigationStack {
            Form {
                headerSection
                openAISection
                openRouterSection  
                ollamaSection
                securitySection
                statusSection
            }
            .navigationTitle("API Key Management")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadExistingCredentials()
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        Section {
            Text("Securely manage API keys and configurations for external AI providers. All credentials are encrypted and stored in your device's keychain.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        }
    }
    
    private var openAISection: some View {
        Section("OpenAI") {
            ProviderKeyField(
                key: $openAIKey,
                provider: .openAI,
                isVisible: secureFieldVisibility[.openAI] == true,
                onToggleVisibility: { toggleVisibility(.openAI) }
            )
            
            Text("Format: sk-...")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ProviderActionButtons(
                provider: .openAI,
                keyManager: keyManager,
                isLoading: isLoading,
                onSave: saveOpenAIKey,
                onRemove: removeOpenAIKey
            )
        }
    }
    
    private var openRouterSection: some View {
        Section("OpenRouter") {
            ProviderKeyField(
                key: $openRouterKey,
                provider: .openRouter,
                isVisible: secureFieldVisibility[.openRouter] == true,
                onToggleVisibility: { toggleVisibility(.openRouter) }
            )
            
            Text("Format: sk-or-...")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ProviderActionButtons(
                provider: .openRouter,
                keyManager: keyManager,
                isLoading: isLoading,
                onSave: saveOpenRouterKey,
                onRemove: removeOpenRouterKey
            )
        }
    }
    
    private var ollamaSection: some View {
        Section("Ollama") {
            TextField("Base URL", text: $ollamaBaseURL)
                .textContentType(.URL)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            
            Text("Default: http://localhost:11434")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ProviderActionButtons(
                provider: .ollama,
                keyManager: keyManager,
                isLoading: isLoading,
                onSave: saveOllamaURL,
                onRemove: removeOllamaURL
            )
        }
    }
    
    private var securitySection: some View {
        Section("Security") {
            SecurityFeatureRow(
                icon: "lock.shield",
                color: .green,
                title: "Keychain Protected",
                description: "All API keys are encrypted and stored securely in your device's keychain."
            )
            
            SecurityFeatureRow(
                icon: "iphone.and.arrow.forward",
                color: .blue,
                title: "Device-Only Storage",
                description: "Credentials never leave your device and are not synced to cloud services."
            )
        }
    }
    
    private var statusSection: some View {
        Section("Provider Status") {
            ForEach(APIKeyManager.Provider.allCases, id: \.self) { provider in
                HStack {
                    Text(provider.displayName)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    StatusIndicator(isConfigured: keyManager.configurationStatus[provider] ?? false)
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    struct StatusIndicator: View {
        let isConfigured: Bool
        
        var body: some View {
            HStack(spacing: 4) {
                Circle()
                    .fill(isConfigured ? .green : .red)
                    .frame(width: 8, height: 8)
                
                Text(isConfigured ? "Configured" : "Not configured")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    struct ProviderKeyField: View {
        @Binding var key: String
        let provider: APIKeyManager.Provider
        let isVisible: Bool
        let onToggleVisibility: () -> Void
        
        var body: some View {
            HStack {
                if isVisible {
                    TextField("API Key", text: $key)
                        .textContentType(.password)
                } else {
                    SecureField("API Key", text: $key)
                        .textContentType(.password)
                }
                
                Button(action: onToggleVisibility) {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    struct ProviderActionButtons: View {
        let provider: APIKeyManager.Provider
        let keyManager: APIKeyManager
        let isLoading: Bool
        let onSave: () -> Void
        let onRemove: () -> Void
        
        var body: some View {
            HStack {
                StatusIndicator(isConfigured: keyManager.configurationStatus[provider] ?? false)
                
                Spacer()
                
                Button("Save", action: onSave)
                    .disabled(isLoading)
                
                if keyManager.configurationStatus[provider] == true {
                    Button("Remove", role: .destructive, action: onRemove)
                        .disabled(isLoading)
                }
            }
        }
    }
    
    struct SecurityFeatureRow: View {
        let icon: String
        let color: Color
        let title: String
        let description: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleVisibility(_ provider: APIKeyManager.Provider) {
        secureFieldVisibility[provider] = !(secureFieldVisibility[provider] ?? false)
    }
    
    private func saveOpenAIKey() {
        guard keyManager.validateAPIKey(openAIKey, for: .openAI) else {
            showAlert(title: "Invalid API Key", message: "OpenAI API keys should start with 'sk-' and be at least 20 characters long.")
            return
        }
        
        saveCredential {
            try keyManager.storeAPIKey(openAIKey, for: .openAI)
            openAIKey = "" // Clear the field for security
        }
    }
    
    private func saveOpenRouterKey() {
        guard keyManager.validateAPIKey(openRouterKey, for: .openRouter) else {
            showAlert(title: "Invalid API Key", message: "OpenRouter API keys should start with 'sk-or-' and be at least 20 characters long.")
            return
        }
        
        saveCredential {
            try keyManager.storeAPIKey(openRouterKey, for: .openRouter)
            openRouterKey = "" // Clear the field for security
        }
    }
    
    private func saveOllamaURL() {
        guard keyManager.validateBaseURL(ollamaBaseURL) else {
            showAlert(title: "Invalid URL", message: "Please enter a valid HTTP or HTTPS URL.")
            return
        }
        
        saveCredential {
            try keyManager.storeBaseURL(ollamaBaseURL, for: .ollama)
        }
    }
    
    private func removeOpenAIKey() {
        removeCredential {
            try keyManager.removeAPIKey(for: .openAI)
        }
    }
    
    private func removeOpenRouterKey() {
        removeCredential {
            try keyManager.removeAPIKey(for: .openRouter)
        }
    }
    
    private func removeOllamaURL() {
        removeCredential {
            try keyManager.removeBaseURL(for: .ollama)
        }
    }
    
    private func saveCredential(_ action: @escaping () throws -> Void) {
        isLoading = true
        
        Task {
            do {
                try action()
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "Success", message: "Credentials saved securely.")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func removeCredential(_ action: @escaping () throws -> Void) {
        isLoading = true
        
        Task {
            do {
                try action()
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "Success", message: "Credentials removed successfully.")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
    
    private func loadExistingCredentials() {
        // Load base URL for Ollama if it exists
        if let url = try? keyManager.getBaseURL(for: .ollama) {
            ollamaBaseURL = url
        }
        
        // Don't load API keys for security - user must re-enter them
        // This prevents accidental exposure in UI
    }
}

// MARK: - Preview
#Preview {
    if #available(iOS 26.0, macOS 26.0, *) {
        APIKeyManagementView()
    }
}