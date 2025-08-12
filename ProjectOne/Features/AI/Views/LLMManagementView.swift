//
//  LLMManagementView.swift
//  ProjectOne
//
//  Comprehensive LLM management dashboard with provider visibility,
//  model selection, error reporting, and dynamic loading capabilities
//

import SwiftUI
import os.log

/// Main LLM management dashboard view
public struct LLMManagementView: View {
    
    @ObservedObject private var managementService: LLMManagementService
    @State private var selectedTab = 0
    @State private var showingModelPicker = false
    @State private var selectedModel: LLMModelInfo?
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "LLMManagementView")
    
    public init(managementService: LLMManagementService) {
        self.managementService = managementService
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // System Status Header
                SystemStatusHeader(
                    readiness: managementService.systemReadiness,
                    lastUpdate: managementService.lastUpdate
                )
                .padding()
                .background(Color(.systemGray6))
                
                // Tab Selection
                Picker("View", selection: $selectedTab) {
                    Text("Providers").tag(0)
                    Text("Models").tag(1)
                    Text("Activity").tag(2)
                    Text("Storage").tag(3)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                TabView(selection: $selectedTab) {
                    ProvidersView(
                        providers: managementService.providerStatuses,
                        onRefresh: managementService.refreshProviderStatuses,
                        onUnloadModel: { providerId in
                            Task {
                                await managementService.unloadModel(providerId: providerId)
                            }
                        }
                    )
                    .tag(0)
                    
                    ModelsView(
                        availableModels: managementService.availableModels,
                        onModelSelect: { model in
                            selectedModel = model
                            showingModelPicker = true
                        }
                    )
                    .tag(1)
                    
                    ActivityView(
                        attempts: managementService.initializationAttempts,
                        providers: managementService.providerStatuses
                    )
                    .tag(2)
                    
                    MLXStorageManagementView()
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("LLM Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        managementService.refreshProviderStatuses()
                    }
                }
            }
        }
        .sheet(isPresented: $showingModelPicker) {
            if let model = selectedModel {
                ModelLoadingView(
                    model: model,
                    managementService: managementService,
                    onDismiss: {
                        showingModelPicker = false
                        selectedModel = nil
                    }
                )
            }
        }
    }
}

// MARK: - System Status Header

struct SystemStatusHeader: View {
    let readiness: LLMSystemReadiness
    let lastUpdate: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(readiness.color)
                    .frame(width: 12, height: 12)
                
                Text("System Status")
                    .font(.headline)
                
                Spacer()
                
                Text("Updated \(lastUpdate, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(readiness.displayName)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(readiness.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Providers View

struct ProvidersView: View {
    let providers: [LLMProviderStatus]
    let onRefresh: () -> Void
    let onUnloadModel: (String) -> Void
    
    var body: some View {
        List {
            ForEach(providers) { provider in
                ProviderCard(
                    provider: provider,
                    onUnload: {
                        onUnloadModel(provider.id)
                    }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            onRefresh()
        }
    }
}

struct ProviderCard: View {
    let provider: LLMProviderStatus
    let onUnload: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.name)
                        .font(.headline)
                    
                    Text(provider.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(provider.statusColor)
                        .frame(width: 8, height: 8)
                    
                    if provider.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            
            // Status
            Text(provider.statusDescription)
                .font(.subheadline)
                .foregroundColor(provider.statusColor)
            
            // Progress bar for loading
            if provider.isLoading {
                ProgressView(value: provider.loadingProgress)
                    .tint(provider.statusColor)
            }
            
            // Capabilities
            if !provider.capabilities.isEmpty {
                CapabilityTags(capabilities: provider.capabilities)
            }
            
            // Memory usage and device requirements
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory: \(provider.estimatedMemoryUsage)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !provider.isSupported {
                        Text("Requirements: \(provider.deviceRequirements)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                if provider.isReady {
                    Button("Unload", action: onUnload)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Details button
            Button(action: { showingDetails = true }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("View Details")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetails) {
            ProviderDetailView(provider: provider)
        }
    }
}

struct CapabilityTags: View {
    let capabilities: [LLMCapability]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 4) {
            ForEach(capabilities, id: \.rawValue) { capability in
                HStack(spacing: 2) {
                    Image(systemName: capability.icon)
                    Text(capability.displayName)
                }
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(4)
            }
        }
    }
}

// MARK: - Models View

struct ModelsView: View {
    let availableModels: [LLMModelInfo]
    let onModelSelect: (LLMModelInfo) -> Void
    
    var body: some View {
        List {
            Section("Text Generation Models") {
                ForEach(modelsOfType(.textGeneration)) { model in
                    ModelRow(model: model, onSelect: { onModelSelect(model) })
                }
            }
            
            Section("Multimodal Models") {
                ForEach(modelsOfType(.multimodal)) { model in
                    ModelRow(model: model, onSelect: { onModelSelect(model) })
                }
            }
            
            Section("Foundation Models") {
                ForEach(modelsOfType(.foundation)) { model in
                    ModelRow(model: model, onSelect: { onModelSelect(model) })
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func modelsOfType(_ type: LLMProviderType) -> [LLMModelInfo] {
        return availableModels.filter { $0.type == type }
    }
}

struct ModelRow: View {
    let model: LLMModelInfo
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                    
                    if model.isRecommended {
                        Text("RECOMMENDED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(3)
                    }
                    
                    if model.isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("Size: \(model.size)")
                    Text("•")
                    Text("Memory: \(model.memoryRequirement)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(model.isInstalled ? "Load" : "Download") {
                onSelect()
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(model.isInstalled ? Color.blue : Color.orange)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity View

struct ActivityView: View {
    let attempts: [LLMInitializationAttempt]
    let providers: [LLMProviderStatus]
    
    var body: some View {
        List {
            Section("Recent Activity") {
                ForEach(recentAttempts) { attempt in
                    ActivityRow(attempt: attempt)
                }
            }
            
            if !failedAttempts.isEmpty {
                Section("Failed Attempts") {
                    ForEach(failedAttempts) { attempt in
                        ActivityRow(attempt: attempt, showError: true)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var recentAttempts: [LLMInitializationAttempt] {
        return attempts
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(20)
            .map { $0 }
    }
    
    private var failedAttempts: [LLMInitializationAttempt] {
        return attempts
            .filter { $0.status == .failed }
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(10)
            .map { $0 }
    }
}

struct ActivityRow: View {
    let attempt: LLMInitializationAttempt
    let showError: Bool
    
    init(attempt: LLMInitializationAttempt, showError: Bool = false) {
        self.attempt = attempt
        self.showError = showError
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(attempt.status.color)
                    .frame(width: 8, height: 8)
                
                Text(providerName)
                    .font(.headline)
                
                Spacer()
                
                Text(attempt.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("\(attempt.status.displayName): \(attempt.modelId)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if showError, let error = attempt.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var providerName: String {
        switch attempt.providerId {
        case "mlx_llm": return "MLX LLM"
        case "mlx_vlm": return "MLX VLM"
        case "foundation": return "Foundation"
        default: return attempt.providerId
        }
    }
}

// MARK: - Detail Views

struct ProviderDetailView: View {
    let provider: LLMProviderStatus
    
    var body: some View {
        NavigationView {
            List {
                Section("Status") {
                    DetailRow("Name", provider.name)
                    DetailRow("Type", provider.type.displayName)
                    DetailRow("Status", provider.statusDescription)
                    DetailRow("Supported", provider.isSupported ? "Yes" : "No")
                    
                    if let model = provider.currentModel {
                        DetailRow("Current Model", model)
                    }
                    
                    DetailRow("Memory Usage", provider.estimatedMemoryUsage)
                    
                    if !provider.isSupported {
                        DetailRow("Requirements", provider.deviceRequirements)
                    }
                }
                
                Section("Capabilities") {
                    ForEach(provider.capabilities, id: \.rawValue) { capability in
                        HStack {
                            Image(systemName: capability.icon)
                            Text(capability.displayName)
                        }
                    }
                }
                
                if let lastAttempt = provider.lastAttempt {
                    Section("Last Attempt") {
                        DetailRow("Time", lastAttempt.timestamp.formatted())
                        DetailRow("Status", lastAttempt.status.displayName)
                        DetailRow("Model", lastAttempt.modelId)
                        
                        if let error = lastAttempt.errorMessage {
                            DetailRow("Error", error)
                        }
                    }
                }
            }
            .navigationTitle(provider.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Dismiss sheet
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Model Loading View

struct ModelLoadingView: View {
    let model: LLMModelInfo
    let managementService: LLMManagementService
    let onDismiss: () -> Void
    
    @State private var isLoading = false
    @State private var loadingError: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(model.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        InfoBox("Size", model.size)
                        InfoBox("Memory", model.memoryRequirement)
                        InfoBox("Type", model.type.displayName)
                    }
                }
                .padding()
                
                if let error = loadingError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: loadModel) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isLoading ? "Loading..." : (model.isInstalled ? "Load Model" : "Download & Load"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    
                    Button("Cancel", action: onDismiss)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("Load Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
    
    private func loadModel() {
        isLoading = true
        loadingError = nil
        
        Task {
            do {
                try await managementService.loadModel(model)
                await MainActor.run {
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    loadingError = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct InfoBox: View {
    let label: String
    let value: String
    
    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
    
    var body: some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

// MARK: - Preview

#Preview {
    // Create mock management service for preview
    let mockMLXLLM = MLXLLMProvider()
    let mockMLXVLM = MLXVLMProvider()
    let mockFoundation = AppleFoundationModelsProvider()
    
    let managementService = LLMManagementService(
        mlxLLMProvider: mockMLXLLM,
        mlxVLMProvider: mockMLXVLM,
        foundationProvider: mockFoundation
    )
    
    return LLMManagementView(managementService: managementService)
}