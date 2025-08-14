//
//  MLXStorageManagementView.swift
//  ProjectOne
//
//  Storage management UI for MLX models
//  Provides storage overview, model details, and cleanup capabilities
//

import SwiftUI
import os.log

/// Comprehensive storage management UI for MLX models with loading controls
public struct MLXStorageManagementView: View {
    
    @StateObject private var storageManager = MLXStorageManager()
    @StateObject private var downloadService = MLXModelDownloadService()
    @State private var selectedModels: Set<String> = []
    @State private var sortOption: SortOption = .size
    @State private var showingDeleteConfirmation = false
    @State private var showingCleanupAlert = false
    @State private var showingCommunityModels = false
    @State private var cleanupDays = 30
    @State private var isRefreshing = false
    @State private var loadedModels: Set<String> = []
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXStorageManagementView")
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Storage overview header
                StorageOverviewCard(storageInfo: storageManager.storageInfo)
                    .padding(.horizontal)
                    .padding(.top)
                
                // Warnings section
                if !storageManager.getStorageWarnings().isEmpty {
                    StorageWarningsView(warnings: storageManager.getStorageWarnings()) {
                        Task {
                            await handleStorageWarnings()
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Model list with loading controls
                ModelStorageListView(
                    models: sortedModels,
                    selectedModels: $selectedModels,
                    sortOption: $sortOption,
                    loadedModels: $loadedModels,
                    onDelete: { modelIds in
                        Task {
                            await deleteModels(modelIds)
                        }
                    },
                    onLoad: { modelId in
                        Task {
                            await loadModel(modelId)
                        }
                    },
                    onUnload: { modelId in
                        Task {
                            await unloadModel(modelId)
                        }
                    }
                )
            }
            .navigationTitle("MLX Model Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await refreshStorage()
                        }
                    }
                    .disabled(isRefreshing)
                    
                    if !selectedModels.isEmpty {
                        Button("Delete Selected") {
                            showingDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button("Browse Models") {
                        showingCommunityModels = true
                    }
                    
                    Menu("Cleanup") {
                        Button("Clean 30+ day old models") {
                            cleanupDays = 30
                            showingCleanupAlert = true
                        }
                        
                        Button("Clean 60+ day old models") {
                            cleanupDays = 60
                            showingCleanupAlert = true
                        }
                        
                        Button("Clean 90+ day old models") {
                            cleanupDays = 90
                            showingCleanupAlert = true
                        }
                    }
                }
            }
        }
        .alert("Delete Selected Models", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteModels(Array(selectedModels))
                }
            }
        } message: {
            Text("This will permanently delete \(selectedModels.count) model(s) and free up storage space.")
        }
        .alert("Cleanup Old Models", isPresented: $showingCleanupAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                Task {
                    await cleanupOldModels(days: cleanupDays)
                }
            }
        } message: {
            Text("This will delete models older than \(cleanupDays) days to free up storage space.")
        }
        .task {
            await storageManager.calculateStorageUsage()
        }
        .sheet(isPresented: $showingCommunityModels) {
            MLXCommunityModelsView(
                communityService: MLXCommunityService(),
                downloadService: downloadService
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var sortedModels: [ModelStorageDetail] {
        switch sortOption {
        case .size:
            return storageManager.getModelsByStorageUsage()
        case .lastAccess:
            return storageManager.getModelsByLastAccess()
        case .name:
            return storageManager.modelStorageDetails.values.sorted { $0.modelId < $1.modelId }
        }
    }
    
    // MARK: - Actions
    
    private func refreshStorage() async {
        isRefreshing = true
        await storageManager.calculateStorageUsage()
        isRefreshing = false
    }
    
    private func deleteModels(_ modelIds: [String]) async {
        do {
            try await storageManager.deleteModels(modelIds)
            selectedModels.removeAll()
            logger.info("Successfully deleted \(modelIds.count) models")
        } catch {
            logger.error("Failed to delete models: \(error.localizedDescription)")
        }
    }
    
    private func cleanupOldModels(days: Int) async {
        do {
            try await storageManager.cleanupOldModels(olderThan: days)
            logger.info("Successfully cleaned up models older than \(days) days")
        } catch {
            logger.error("Failed to cleanup old models: \(error.localizedDescription)")
        }
    }
    
    private func handleStorageWarnings() async {
        let warnings = storageManager.getStorageWarnings()
        
        // Auto-handle actionable warnings
        for warning in warnings {
            if warning.actionable {
                switch warning {
                case .unusedModels:
                    try? await storageManager.cleanupOldModels(olderThan: 30)
                case .quotaNearlyExceeded:
                    // Free up 5GB of space
                    try? await storageManager.freeUpSpace(targetBytes: 5 * 1024 * 1024 * 1024)
                default:
                    break
                }
            }
        }
        
        await storageManager.calculateStorageUsage()
    }
    
    private func loadModel(_ modelId: String) async {
        do {
            // Simulate model loading - in real implementation, this would interface with MLX
            logger.info("Loading model: \(modelId)")
            
            await MainActor.run {
                loadedModels.insert(modelId)
            }
            
            logger.info("✅ Successfully loaded model: \(modelId)")
        } catch {
            logger.error("❌ Failed to load model \(modelId): \(error.localizedDescription)")
        }
    }
    
    private func unloadModel(_ modelId: String) async {
        logger.info("Unloading model: \(modelId)")
        
        await MainActor.run {
            loadedModels.remove(modelId)
        }
        
        logger.info("✅ Successfully unloaded model: \(modelId)")
    }
    
    public enum SortOption: String, CaseIterable {
        case size = "Size"
        case lastAccess = "Last Access"
        case name = "Name"
        
        public var displayName: String { rawValue }
    }
}

// MARK: - Storage Overview Card

struct StorageOverviewCard: View {
    let storageInfo: StorageInfo
    
    var body: some View {
        VStack(spacing: 16) {
            // Usage ring and stats
            HStack(spacing: 24) {
                // Usage ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: storageInfo.usagePercentage)
                        .stroke(usageColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: storageInfo.usagePercentage)
                    
                    VStack(spacing: 2) {
                        Text("\(Int(storageInfo.usagePercentage * 100))%")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Used")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("MLX Models")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(storageInfo.modelCount) models")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Used:")
                        Spacer()
                        Text(formatBytes(storageInfo.totalUsedBytes))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Text("Available:")
                        Spacer()
                        Text(formatBytes(storageInfo.remainingBytes))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    
                    HStack {
                        Text("Quota:")
                        Spacer()
                        Text(formatBytes(storageInfo.totalQuotaBytes))
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var usageColor: Color {
        if storageInfo.usagePercentage > 0.9 {
            return .red
        } else if storageInfo.usagePercentage > 0.7 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Storage Warnings View

struct StorageWarningsView: View {
    let warnings: [StorageWarning]
    let onResolve: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(warnings, id: \.message) { warning in
                HStack {
                    Image(systemName: warningIcon(for: warning.severity))
                        .foregroundColor(Color(warning.severity.color))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.message)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if warning.actionable {
                        Button("Fix") {
                            onResolve()
                        }
                        .font(.caption)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(warning.severity.color).opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func warningIcon(for severity: WarningSeverity) -> String {
        switch severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.triangle"
        case .medium: return "info.circle"
        case .low: return "info.circle"
        }
    }
}

// MARK: - Model Storage List View

struct ModelStorageListView: View {
    let models: [ModelStorageDetail]
    @Binding var selectedModels: Set<String>
    @Binding var sortOption: MLXStorageManagementView.SortOption
    @Binding var loadedModels: Set<String>
    let onDelete: ([String]) -> Void
    let onLoad: (String) -> Void
    let onUnload: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Sort picker
            HStack {
                Text("Sort by:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(MLXStorageManagementView.SortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                if !selectedModels.isEmpty {
                    Text("\(selectedModels.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Model list
            List {
                ForEach(models, id: \.modelId) { model in
                    ModelStorageRow(
                        model: model,
                        isSelected: selectedModels.contains(model.modelId),
                        isLoaded: loadedModels.contains(model.modelId),
                        onToggleSelection: {
                            toggleSelection(for: model.modelId)
                        },
                        onDelete: {
                            onDelete([model.modelId])
                        },
                        onLoad: {
                            onLoad(model.modelId)
                        },
                        onUnload: {
                            onUnload(model.modelId)
                        }
                    )
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private func toggleSelection(for modelId: String) {
        if selectedModels.contains(modelId) {
            selectedModels.remove(modelId)
        } else {
            selectedModels.insert(modelId)
        }
    }
}

// MARK: - Model Storage Row

struct ModelStorageRow: View {
    let model: ModelStorageDetail
    let isSelected: Bool
    let isLoaded: Bool
    let onToggleSelection: () -> Void
    let onDelete: () -> Void
    let onLoad: () -> Void
    let onUnload: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .buttonStyle(BorderlessButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.modelId)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if isLoaded {
                        Image(systemName: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text(model.formattedSize)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Label("\(model.fileCount) files", systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let days = model.daysSinceLastAccess {
                        Text("Used \(days) days ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Downloaded \(model.daysSinceDownload) days ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status indicators
                HStack(spacing: 8) {
                    if model.isRecent {
                        Label("Recent", systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if model.isOld {
                        Label("Old", systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
            }
            
            // Loading controls
            HStack(spacing: 8) {
                if isLoaded {
                    Button("Unload") {
                        onUnload()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                } else {
                    Button("Load") {
                        onLoad()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    MLXStorageManagementView()
}