//
//  AIProviderSettingsView.swift
//  ProjectOne
//
//  SwiftUI interface for AI provider configuration
//

import SwiftUI

public struct AIProviderSettingsView: View {
    @StateObject private var settings = AIProviderSettings()
    @State private var showingAPIKeySheet = false
    @State private var selectedProvider: APIProvider = .openAI
    @State private var tempAPIKey = ""
    @State private var showingResetAlert = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            Form {
                // Privacy & General Settings
                privacySection
                
                // Provider Status Overview
                providerOverviewSection
                
                // Apple On-Device Providers
                appleProvidersSection
                
                // External API Providers
                externalProvidersSection
                
                // Local Providers
                localProvidersSection
                
                // Advanced Settings
                advancedSection
                
                // Actions
                actionsSection
            }
            .navigationTitle("AI Providers")
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeyInputSheet(
                    provider: selectedProvider,
                    apiKey: $tempAPIKey,
                    settings: settings
                )
            }
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all API keys and reset settings to defaults. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section {
            Picker("Privacy Mode", selection: $settings.privacyMode) {
                ForEach(AIProviderSettings.PrivacyMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(mode)
                }
            }
            
            Toggle("Enable Fallback Providers", isOn: $settings.fallbackEnabled)
            
            Picker("Preferred Provider", selection: $settings.preferredProvider) {
                Text("Apple Foundation Models").tag("apple-foundation-models")
                Text("MLX Local").tag("mlx")
                Text("Ollama").tag("ollama")
                Text("OpenAI").tag("openai")
                Text("OpenRouter").tag("openrouter")
            }
        } header: {
            Text("Privacy & Preferences")
        } footer: {
            Text("Privacy mode controls which providers are used for sensitive data. Maximum privacy uses only on-device processing.")
        }
    }
    
    // MARK: - Provider Overview
    
    private var providerOverviewSection: some View {
        Section("Provider Status") {
            ForEach(getAllProviders(), id: \.0) { provider in
                ProviderStatusRow(
                    name: provider.0,
                    identifier: provider.1,
                    isEnabled: settings.isProviderEnabled(provider.1),
                    hasAPIKey: provider.2,
                    isAvailable: provider.3,
                    settings: settings
                )
            }
        }
    }
    
    // MARK: - Apple Providers Section
    
    private var appleProvidersSection: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Image(systemName: "apple.logo")
                        .foregroundColor(.blue)
                    Text("Apple Foundation Models")
                    Spacer()
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Text("Available")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("iOS 26.0+ Required")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Text("On-device Apple Intelligence with @Generable support")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("Enable Apple Foundation Models", isOn: Binding(
                    get: { settings.isProviderEnabled("apple-foundation-models") },
                    set: { settings.setProviderEnabled("apple-foundation-models", enabled: $0) }
                ))
            }
        } header: {
            Text("Apple On-Device Providers")
        } footer: {
            Text("Apple Foundation Models provide the highest privacy with on-device processing. Requires iOS 26.0+ and Apple Intelligence enabled.")
        }
    }
    
    // MARK: - External Providers Section
    
    private var externalProvidersSection: some View {
        Section {
            // OpenAI
            APIProviderRow(
                provider: .openAI,
                icon: "brain.head.profile",
                description: "GPT-4, GPT-4o, function calling",
                settings: settings,
                onConfigureTapped: { configureProvider(.openAI) }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Model", selection: $settings.openAIModel) {
                        Text("GPT-4o").tag("gpt-4o")
                        Text("GPT-4o Mini").tag("gpt-4o-mini")
                        Text("GPT-4 Turbo").tag("gpt-4-turbo")
                        Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
                    }
                    
                    if !settings.openAIOrganization.isEmpty {
                        TextField("Organization ID", text: $settings.openAIOrganization)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            
            // OpenRouter
            APIProviderRow(
                provider: .openRouter,
                icon: "network",
                description: "Multiple models via unified API",
                settings: settings,
                onConfigureTapped: { configureProvider(.openRouter) }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Model", selection: $settings.openRouterModel) {
                        Text("Claude 3 Sonnet").tag("anthropic/claude-3-sonnet:beta")
                        Text("Claude 3 Haiku").tag("anthropic/claude-3-haiku:beta")
                        Text("GPT-4 Turbo").tag("openai/gpt-4-turbo")
                        Text("Llama 3 70B").tag("meta-llama/llama-3-70b-instruct")
                        Text("Gemini Pro 1.5").tag("google/gemini-pro-1.5")
                    }
                    
                    Picker("Route Preference", selection: $settings.openRouterRoutePreference) {
                        Text("Fastest").tag("fastest")
                        Text("Cheapest").tag("cheapest")
                        Text("Balanced").tag("balanced")
                        Text("Quality").tag("quality")
                    }
                }
            }
            
            // Anthropic
            APIProviderRow(
                provider: .anthropic,
                icon: "a.circle",
                description: "Claude models direct API",
                settings: settings,
                onConfigureTapped: { configureProvider(.anthropic) }
            ) {
                Picker("Model", selection: $settings.anthropicModel) {
                    Text("Claude 3 Sonnet").tag("claude-3-sonnet-20240229")
                    Text("Claude 3 Haiku").tag("claude-3-haiku-20240307")
                    Text("Claude 3 Opus").tag("claude-3-opus-20240229")
                }
            }
        } header: {
            Text("External API Providers")
        } footer: {
            Text("External providers require API keys and send data to external servers. Configure privacy mode to control usage.")
        }
    }
    
    // MARK: - Local Providers Section
    
    private var localProvidersSection: some View {
        Section {
            // Ollama
            LocalProviderRow(
                name: "Ollama",
                identifier: "ollama",
                icon: "server.rack",
                description: "Local model server",
                isEnabled: settings.isProviderEnabled("ollama"),
                settings: settings
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Server URL", text: $settings.ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Model", text: $settings.ollamaModel)
                        .textFieldStyle(.roundedBorder)
                    
                    Toggle("Auto-download models", isOn: $settings.ollamaAutoDownload)
                }
            }
            
            // MLX Text
            if MLXProvider.isMLXSupported {
                LocalProviderRow(
                    name: "MLX Swift",
                    identifier: "mlx",
                    icon: "cpu",
                    description: "Apple Silicon optimized text models",
                    isEnabled: settings.isProviderEnabled("mlx"),
                    settings: settings
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Model Path", text: $settings.mlxModelPath)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Model Name", text: $settings.mlxModelName)
                            .textFieldStyle(.roundedBorder)
                        
                        Toggle("Enable quantization", isOn: $settings.mlxQuantization)
                    }
                }
                
                // MLX Audio
                LocalProviderRow(
                    name: "MLX Audio VLM",
                    identifier: "mlx-audio",
                    icon: "waveform",
                    description: "Direct audio understanding (Gemma3n VLM)",
                    isEnabled: settings.isProviderEnabled("mlx-audio"),
                    settings: settings
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Audio Model Path", text: $settings.mlxAudioModelPath)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Audio Model Name", text: $settings.mlxAudioModelName)
                            .textFieldStyle(.roundedBorder)
                        
                        Toggle("Enable Direct Audio Processing", isOn: $settings.enableDirectAudioProcessing)
                        
                        VStack(alignment: .leading) {
                            Text("Audio Quality Threshold: \(settings.audioQualityThreshold, specifier: "%.1f")")
                            Slider(value: $settings.audioQualityThreshold, in: 0.3...1.0, step: 0.1)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Max Audio Duration: \(settings.maxAudioDuration, specifier: "%.0f") seconds")
                            Slider(value: $settings.maxAudioDuration, in: 10...300, step: 10)
                        }
                    }
                }
            } else {
                HStack {
                    Image(systemName: "cpu")
                        .foregroundColor(.gray)
                    Text("MLX Swift")
                    Spacer()
                    Text("Apple Silicon Required")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        } header: {
            Text("Local Providers")
        } footer: {
            Text("Local providers run entirely on your device or local network. MLX Audio VLM can process audio directly without transcription, providing richer understanding. Requires Apple Silicon hardware.")
        }
    }
    
    // MARK: - Advanced Section
    
    private var advancedSection: some View {
        Section("Advanced Settings") {
            HStack {
                Text("Max Tokens")
                Spacer()
                TextField("4096", value: $settings.maxTokens, format: .number)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .frame(width: 80)
            }
            
            VStack(alignment: .leading) {
                Text("Temperature: \(settings.temperature, specifier: "%.1f")")
                Slider(value: $settings.temperature, in: 0...2, step: 0.1)
            }
            
            HStack {
                Text("Request Timeout")
                Spacer()
                TextField("60", value: $settings.requestTimeout, format: .number)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .frame(width: 80)
                Text("seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Max Retries")
                Spacer()
                TextField("3", value: $settings.maxRetries, format: .number)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .frame(width: 80)
            }
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        Section {
            Button("Reset All Settings") {
                showingResetAlert = true
            }
            .foregroundColor(.red)
            
            Button("Export Settings") {
                exportSettings()
            }
        } header: {
            Text("Actions")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getAllProviders() -> [(String, String, Bool, Bool)] {
        return [
            ("Apple Foundation Models", "apple-foundation-models", true, true),
            ("OpenAI", "openai", settings.hasAPIKey(for: .openAI), true),
            ("OpenRouter", "openrouter", settings.hasAPIKey(for: .openRouter), true),
            ("Anthropic", "anthropic", settings.hasAPIKey(for: .anthropic), true),
            ("Ollama", "ollama", true, true),
            ("MLX Swift", "mlx", true, MLXProvider.isMLXSupported),
            ("MLX Audio VLM", "mlx-audio", true, MLXProvider.isMLXSupported)
        ]
    }
    
    private func configureProvider(_ provider: APIProvider) {
        selectedProvider = provider
        tempAPIKey = settings.getAPIKey(for: provider) ?? ""
        showingAPIKeySheet = true
    }
    
    private func exportSettings() {
        let settings = settings.exportSettings()
        // Implement export functionality (share sheet, etc.)
    }
}

// MARK: - Supporting Views

struct APIProviderRow<Content: View>: View {
    let provider: APIProvider
    let icon: String
    let description: String
    let settings: AIProviderSettings
    let onConfigureTapped: () -> Void
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(provider.displayName)
                Spacer()
                
                if settings.hasAPIKey(for: provider) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button("Configure") {
                        onConfigureTapped()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Toggle("Enable \(provider.displayName)", isOn: Binding(
                get: { settings.isProviderEnabled(provider.identifier) },
                set: { settings.setProviderEnabled(provider.identifier, enabled: $0) }
            ))
            .disabled(!settings.hasAPIKey(for: provider))
            
            if settings.hasAPIKey(for: provider) && settings.isProviderEnabled(provider.identifier) {
                content()
            }
        }
    }
}

struct LocalProviderRow<Content: View>: View {
    let name: String
    let identifier: String
    let icon: String
    let description: String
    let isEnabled: Bool
    let settings: AIProviderSettings
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.green)
                Text(name)
                Spacer()
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Toggle("Enable \(name)", isOn: Binding(
                get: { settings.isProviderEnabled(identifier) },
                set: { settings.setProviderEnabled(identifier, enabled: $0) }
            ))
            
            if isEnabled {
                content()
            }
        }
    }
}

struct ProviderStatusRow: View {
    let name: String
    let identifier: String
    let isEnabled: Bool
    let hasAPIKey: Bool
    let isAvailable: Bool
    let settings: AIProviderSettings
    
    var body: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading) {
                Text(name)
                    .font(.subheadline)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isEnabled {
                Text("Enabled")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Text("Disabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusIcon: some View {
        Group {
            if !isAvailable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var statusText: String {
        if !isAvailable {
            return "Not available on this device"
        } else if identifier == "apple-foundation-models" {
            return isEnabled ? "On-device processing" : "Disabled"
        } else if ["openai", "openrouter", "anthropic"].contains(identifier) {
            return hasAPIKey ? (isEnabled ? "API configured" : "Configured but disabled") : "API key required"
        } else {
            return isEnabled ? "Local processing" : "Disabled"
        }
    }
}

// MARK: - API Key Input Sheet

struct APIKeyInputSheet: View {
    let provider: APIProvider
    @Binding var apiKey: String
    let settings: AIProviderSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                    
                    if !apiKey.isEmpty {
                        Button("Test Connection") {
                            testConnection()
                        }
                        .buttonStyle(.bordered)
                    }
                } header: {
                    Text("\(provider.displayName) Configuration")
                } footer: {
                    Text("Your API key is stored securely in the keychain and never leaves your device except when making API requests.")
                }
                
                Section("Instructions") {
                    instructionsForProvider(provider)
                }
            }
            .navigationTitle("API Key")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Connection Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func instructionsForProvider(_ provider: APIProvider) -> some View {
        Group {
            switch provider {
            case .openAI:
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Visit platform.openai.com/api-keys")
                    Text("2. Create a new API key")
                    Text("3. Copy and paste the key above")
                }
            case .openRouter:
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Visit openrouter.ai/keys")
                    Text("2. Create a new API key")
                    Text("3. Add credits to your account")
                    Text("4. Copy and paste the key above")
                }
            case .anthropic:
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Visit console.anthropic.com")
                    Text("2. Go to API Keys section")
                    Text("3. Create a new API key")
                    Text("4. Copy and paste the key above")
                }
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private func testConnection() {
        // Implement API key validation
        // This would make a test request to verify the key works
    }
    
    private func saveAPIKey() {
        do {
            try settings.setAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), for: provider)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

#Preview {
    AIProviderSettingsView()
}