//
//  SettingsView.swift
//  ProjectOne
//
//  Created on 6/28/25.
//

import SwiftUI
import SwiftData
import Combine
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    let gemmaCore: Gemma3nCore
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var systemManager: UnifiedSystemManager
    @Query private var userProfiles: [UserSpeechProfile]
    
    @State private var showingModelDownload = false
    @State private var showingDataExport = false
    @State private var showingAbout = false
    
    // AI Settings
    @State private var delegationThreshold: Double = 0.7
    @State private var maxContextWindow: Double = 4000
    @State private var enablePersonalization = true
    @State private var enableMemoryConsolidation = true
    
    // Privacy Settings
    @State private var localProcessingOnly = true
    @State private var enableTelemetry = false
    @State private var autoDeleteOldData = false
    @State private var dataRetentionDays: Double = 90
    
    // Performance Settings
    @State private var enableBackgroundProcessing = true
    @State private var maxWorkingMemorySize: Double = 20
    @State private var enableGPUAcceleration = true
    
    var userProfile: UserSpeechProfile? {
        userProfiles.first
    }
    
    var body: some View {
        NavigationStack {
            List {
                // AI Processing Section
                Section("AI Processing") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Delegation Threshold")
                            Spacer()
                            Text("\(Int(delegationThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $delegationThreshold, in: 0.1...1.0, step: 0.1)
                            .tint(.blue)
                        
                        Text("Lower values delegate more tasks to external agents")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Context Window Size")
                            Spacer()
                            Text("\(Int(maxContextWindow)) tokens")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $maxContextWindow, in: 1000...8000, step: 500)
                            .tint(.blue)
                        
                        Text("Larger contexts provide more information but use more memory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Toggle("Enable Personalization", isOn: $enablePersonalization)
                    Toggle("Memory Consolidation", isOn: $enableMemoryConsolidation)
                }
                
                // Memory System Section
                Section("Memory System") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Working Memory Size")
                            Spacer()
                            Text("\(Int(maxWorkingMemorySize)) items")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $maxWorkingMemorySize, in: 10...50, step: 5)
                            .tint(.orange)
                        
                        Text("Maximum items in active working memory")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    NavigationLink("Memory Analytics") {
                        MemoryAnalyticsView(gemmaCore: gemmaCore)
                    }
                    
                    NavigationLink("User Speech Profile") {
                        UserProfileView(profile: userProfile)
                    }
                    
                    Button("Consolidate Memory Now") {
                        consolidateMemory()
                    }
                    .foregroundColor(.blue)
                }
                
                // Model Management Section
                Section("Model Management") {
                    NavigationLink("Download Models") {
                        ModelDownloadView()
                    }
                    
                    NavigationLink("Model Performance") {
                        ModelPerformanceView()
                    }
                    
                    Toggle("GPU Acceleration", isOn: $enableGPUAcceleration)
                    Toggle("Background Processing", isOn: $enableBackgroundProcessing)
                }
                
                // Privacy & Security Section
                Section("Privacy & Security") {
                    Toggle("Local Processing Only", isOn: $localProcessingOnly)
                    Toggle("Anonymous Telemetry", isOn: $enableTelemetry)
                    Toggle("Auto-Delete Old Data", isOn: $autoDeleteOldData)
                    
                    if autoDeleteOldData {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Retention Period")
                                Spacer()
                                Text("\(Int(dataRetentionDays)) days")
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $dataRetentionDays, in: 7...365, step: 7)
                                .tint(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Data Management Section
                Section("Data Management") {
                    Button("Export All Data") {
                        showingDataExport = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Clear All Memory") {
                        clearAllMemory()
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset User Profile") {
                        resetUserProfile()
                    }
                    .foregroundColor(.orange)
                }
                
                // Advanced Section
                Section("Advanced") {
                    NavigationLink("API Key Management") {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            APIKeyManagementView()
                        }
                    }
                    
                    NavigationLink("AI Provider Testing") {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            EnhancedAIProviderTestView()
                        } else {
                            AIProviderTestView()
                        }
                    }
                    
                    NavigationLink("Debug Console") {
                        DebugConsoleView()
                    }
                    
                    NavigationLink("System Status") {
                        SystemStatusView(gemmaCore: gemmaCore, systemManager: systemManager)
                    }
                    
                    NavigationLink("Startup Dashboard") {
                        SystemInitializationView()
                    }
                    
                    Button("About ProjectOne") {
                        showingAbout = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingDataExport) {
                DataExportView(modelContext: modelContext)
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
        }
    }
    
    private func consolidateMemory() {
        Task {
            // TODO: Implement memory consolidation
            print("Consolidating memory...")
        }
    }
    
    private func clearAllMemory() {
        // TODO: Implement clear all memory with confirmation
        print("Clearing all memory...")
    }
    
    private func resetUserProfile() {
        // TODO: Implement user profile reset with confirmation
        print("Resetting user profile...")
    }
}

struct ModelDownloadView: View {
    @State private var models = [
        ModelDownloadInfo(name: "Gemma 3n (2B)", size: "1.2 GB", isDownloaded: false, isDownloading: false, progress: 0.0),
        ModelDownloadInfo(name: "all-MiniLM-L6-v2", size: "80 MB", isDownloaded: false, isDownloading: false, progress: 0.0),
        ModelDownloadInfo(name: "Whisper Tiny", size: "39 MB", isDownloaded: false, isDownloading: false, progress: 0.0)
    ]
    
    var body: some View {
        List {
            ForEach(models.indices, id: \.self) { index in
                ModelDownloadRow(model: $models[index])
            }
        }
        .navigationTitle("Model Downloads")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}

struct ModelDownloadInfo {
    let name: String
    let size: String
    var isDownloaded: Bool
    var isDownloading: Bool
    var progress: Double
}

struct ModelDownloadRow: View {
    @Binding var model: ModelDownloadInfo
    @State private var downloadTimer: Timer?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                
                Text(model.size)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if model.isDownloading {
                    ProgressView(value: model.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
            
            Spacer()
            
            if model.isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else if model.isDownloading {
                Button("Cancel") {
                    downloadTimer?.invalidate()
                    downloadTimer = nil
                    model.isDownloading = false
                    model.progress = 0.0
                }
                .foregroundColor(.red)
            } else {
                Button("Download") {
                    downloadModel()
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func downloadModel() {
        model.isDownloading = true
        
        // Simulate download progress
        downloadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task { @MainActor in
                model.progress += 0.02
                
                if model.progress >= 1.0 {
                    downloadTimer?.invalidate()
                    downloadTimer = nil
                    model.isDownloading = false
                    model.isDownloaded = true
                    model.progress = 1.0
                }
            }
        }
    }
}

struct MemoryAnalyticsView: View {
    let gemmaCore: Gemma3nCore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Memory analytics and insights would be displayed here")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // TODO: Implement actual memory analytics
            }
            .padding()
        }
        .navigationTitle("Memory Analytics")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct UserProfileView: View {
    let profile: UserSpeechProfile?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let profile = profile {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speech Adaptation")
                            .font(.headline)
                        
                        Text("Adaptation Level: \(String(format: "%.0f%%", profile.adaptationLevel * 100))")
                        Text("Total Transcriptions: \(profile.totalTranscriptions)")
                        Text("Average WPM: \(String(format: "%.1f", profile.averagePace))")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preferences")
                            .font(.headline)
                        
                        let personalizationContext = profile.getPersonalizationContext()
                        Text("Expected Style: \(personalizationContext.expectedStyle.rawValue.capitalized)")
                        Text("Common Substitutions: \(personalizationContext.commonSubstitutions.count)")
                        Text("Personal References: \(personalizationContext.personalReferences.count)")
                    }
                } else {
                    Text("No user profile data available")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("User Profile")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct ModelPerformanceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Model performance metrics would be displayed here")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // TODO: Implement model performance monitoring
            }
            .padding()
        }
        .navigationTitle("Model Performance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct DebugConsoleView: View {
    @State private var logs: [String] = [
        "[INFO] Gemma3nCore initialized",
        "[DEBUG] Working memory size: 15 items",
        "[INFO] Model inference completed in 234ms",
        "[DEBUG] Entity extraction found 3 entities",
        "[INFO] Memory consolidation scheduled"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(logs, id: \.self) { log in
                    Text(log)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(logColor(for: log))
                }
            }
            .padding()
        }
        .navigationTitle("Debug Console")
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
                Button("Clear") {
                    logs.removeAll()
                }
            }
        }
    }
    
    private func logColor(for log: String) -> Color {
        if log.contains("[ERROR]") {
            return .red
        } else if log.contains("[WARN]") {
            return .orange
        } else if log.contains("[INFO]") {
            return .blue
        } else {
            return .secondary
        }
    }
}

struct SystemStatusView: View {
    let gemmaCore: Gemma3nCore
    let systemManager: UnifiedSystemManager
    
    @State private var refreshTimer: Timer?
    @State private var lastRefresh: Date = Date()
    
    var body: some View {
        List {
            Section("System Information") {
                #if os(iOS)
                StatusRow(title: "iOS Version", value: getSystemVersion())
                StatusRow(title: "Device Model", value: getDeviceModel())
                #else
                StatusRow(title: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                StatusRow(title: "Device Model", value: "Mac")
                #endif
                StatusRow(title: "Available Memory", value: "2.1 GB") // TODO: Get actual memory
                StatusRow(title: "Storage Used", value: "45 MB") // TODO: Calculate actual storage
            }
            
            Section("AI System Status") {
                StatusRow(title: "System Health", value: systemManager.systemHealth.displayName)
                StatusRow(title: "Initialization", value: "\(Int(systemManager.initializationProgress * 100))%")
                StatusRow(title: "Current Operation", value: systemManager.currentOperation.isEmpty ? "Idle" : systemManager.currentOperation)
                StatusRow(title: "Gemma Core", value: gemmaCore.isAvailable() ? "Ready" : "Not Ready")
                if let modelInfo = gemmaCore.getActualLoadedModel() {
                    StatusRow(title: "Loaded Model", value: modelInfo.displayName)
                }
            }
            
            Section("Agent System") {
                StatusRow(title: "Active Agents", value: "\(systemManager.centralAgentRegistry?.getActiveAgentIds().count ?? 0)")
                StatusRow(title: "Registered Agents", value: "\(systemManager.centralAgentRegistry?.getActiveAgentIds().count ?? 0)")
                StatusRow(title: "Active Models", value: "\(systemManager.systemStatistics["activeModels"] as? Int ?? 0)")
                StatusRow(title: "Provider Health", value: "\((systemManager.systemStatistics["healthyProviders"] as? Int ?? 0))/\((systemManager.systemStatistics["totalProviders"] as? Int ?? 0))")
                StatusRow(title: "Memory Usage", value: formatBytes(systemManager.systemStatistics["memoryUsage"] as? Int ?? 0))
            }
            
            Section("Real-Time Agent Status") {
                if let registry = systemManager.centralAgentRegistry {
                    ForEach(registry.getActiveAgentIds(), id: \.self) { agentId in
                        AgentStatusRow(agentId: agentId, registry: registry)
                    }
                } else {
                    StatusRow(title: "Agent Registry", value: "Not Available")
                }
            }
        }
        .navigationTitle("System Status")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            lastRefresh = Date()
            startRefreshTimer()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                lastRefresh = Date()
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    #if os(iOS)
    private func getSystemVersion() -> String {
        if Thread.isMainThread {
            return UIDevice.current.systemVersion
        } else {
            return DispatchQueue.main.sync { UIDevice.current.systemVersion }
        }
    }
    
    private func getDeviceModel() -> String {
        if Thread.isMainThread {
            return UIDevice.current.model
        } else {
            return DispatchQueue.main.sync { UIDevice.current.model }
        }
    }
    #endif
}

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// Simple stub for agent registry functionality
public class CentralAgentRegistry {
    public func getActiveAgentIds() -> [String] {
        return ["TextIngestionAgent", "MemoryAgent", "CognitiveDecisionEngine"]
    }
    
    public func isAgentHealthy(_ agentId: String) -> Bool {
        return true // Stub implementation
    }
    
    public func getLastCheckTime(_ agentId: String) -> Date {
        return Date()
    }
    
    public func getAgentDetails(_ agentId: String) -> AgentDetails? {
        return AgentDetails(id: agentId, name: agentId, status: "active")
    }
    
    public func getAgentMetrics(_ agentId: String) -> [String: Any] {
        return [
            "uptime": 3600,
            "requestCount": 100,
            "errorRate": 0.01,
            "lastActivity": Date()
        ]
    }
}

public struct AgentDetails {
    let id: String
    let name: String
    let status: String
    let agent: AgentInterface
    
    init(id: String, name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
        self.agent = StubAgent()
    }
}

public struct StubAgent: AgentInterface {
    @MainActor public func performHealthCheck() async throws -> Bool {
        return true
    }
}

public protocol AgentInterface {
    @MainActor func performHealthCheck() async throws -> Bool
}

public struct AgentInstance {
    let agent: AgentInterface
}

struct AgentStatusRow: View {
    let agentId: String
    let registry: CentralAgentRegistry
    
    @State private var isHealthy: Bool = false
    @State private var lastCheck: Date = Date()
    
    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(isHealthy ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(agentId)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(isHealthy ? "Healthy" : "Unhealthy")
                    .foregroundColor(isHealthy ? .green : .red)
                    .font(.caption)
                
                let metrics = registry.getAgentMetrics(agentId)
                if let lastActivity = metrics["lastActivity"] as? Date {
                    Text("Last: \(formatTime(lastActivity))")
                        .foregroundColor(.secondary)
                        .font(.caption2)
                }
            }
        }
        .onAppear {
            checkAgentHealth()
        }
        .onReceive(Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()) { _ in
            checkAgentHealth()
        }
    }
    
    private func checkAgentHealth() {
        Task { @MainActor in
            if let agentInstance = registry.getAgentDetails(agentId) {
                do {
                    let healthResult = try await agentInstance.agent.performHealthCheck()
                    isHealthy = healthResult
                    lastCheck = Date()
                } catch {
                    isHealthy = false
                }
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// DataExportView is defined in DataExportView.swift

// ExportFormat enum is defined in DataExportView.swift

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon and name
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("ProjectOne")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("AI-Powered Knowledge Management")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "brain", title: "Gemma 3n AI", description: "Local AI processing with privacy")
                        FeatureRow(icon: "memorychip", title: "Titans Memory", description: "Advanced memory architecture")
                        FeatureRow(icon: "mic", title: "Voice Notes", description: "AI-powered transcription")
                        FeatureRow(icon: "brain.head.profile", title: "Knowledge Graph", description: "Semantic entity relationships")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Version")
                            .font(.headline)
                        
                        Text("1.0.0 (Beta)")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Built with")
                            .font(.headline)
                        
                        Text("SwiftUI, SwiftData, MLX-Swift, AVFoundation")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("About")
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
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! SwiftData.ModelContainer(for: UserSpeechProfile.self, configurations: config)
    
    SettingsView(
        gemmaCore: Gemma3nCore()
    )
    .modelContainer(container)
}