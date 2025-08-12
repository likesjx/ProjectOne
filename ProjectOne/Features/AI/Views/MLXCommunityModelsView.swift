//
//  MLXCommunityModelsView.swift
//  ProjectOne
//
//  Enhanced view for browsing and downloading MLX Community models
//  Provides categorized model browsing, search, and download management
//

import SwiftUI
import os.log

/// Enhanced view for MLX Community models with dynamic discovery and downloading
public struct MLXCommunityModelsView: View {
    
    @ObservedObject private var communityService: MLXCommunityService
    @ObservedObject private var downloadService: MLXModelDownloadService
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var showingDownloads = false
    @State private var sortOption: ModelSortOption = .downloads
    
    private let logger = Logger(subsystem: "com.jaredlikes.ProjectOne", category: "MLXCommunityModelsView")
    
    public init(communityService: MLXCommunityService, downloadService: MLXModelDownloadService) {
        self.communityService = communityService
        self.downloadService = downloadService
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filter bar
                SearchAndFilterBar(
                    searchText: $searchText,
                    sortOption: $sortOption,
                    onRefresh: {
                        Task {
                            try? await communityService.discoverModels()
                        }
                    },
                    onShowDownloads: { showingDownloads = true }
                )
                
                if communityService.isLoading && communityService.availableModels.isEmpty {
                    LoadingView()
                } else if filteredModels.isEmpty {
                    EmptyStateView(hasModels: !communityService.availableModels.isEmpty)
                } else {
                    ModelGrid(
                        models: filteredModels,
                        downloadService: downloadService
                    )
                }
            }
            .navigationTitle("MLX Community")
            .navigationBarTitleDisplayMode(.large)
            .task {
                if communityService.availableModels.isEmpty {
                    try? await communityService.discoverModels()
                }
            }
            .sheet(isPresented: $showingDownloads) {
                DownloadsView(downloadService: downloadService)
            }
            .alert("Error", isPresented: .constant(communityService.lastError != nil)) {
                Button("OK") {
                    // Error handling could be added here
                }
            } message: {
                Text(communityService.lastError?.localizedDescription ?? "Unknown error")
            }
        }
    }
    
    private var filteredModels: [MLXCommunityModel] {
        var models = searchText.isEmpty ? communityService.availableModels : communityService.filterModels(query: searchText)
        
        // Apply sorting
        switch sortOption {
        case .downloads:
            models = models.sorted { $0.downloads > $1.downloads }
        case .likes:
            models = models.sorted { $0.likes > $1.likes }
        case .name:
            models = models.sorted { $0.name < $1.name }
        case .newest:
            models = models.sorted { $0.lastModified > $1.lastModified }
        case .size:
            models = models.sorted { $0.estimatedSize < $1.estimatedSize }
        }
        
        return models
    }
}

// MARK: - Search and Filter Bar

struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var sortOption: ModelSortOption
    let onRefresh: () -> Void
    let onShowDownloads: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search models...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Downloads") {
                    onShowDownloads()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Sort", selection: $sortOption) {
                    ForEach(ModelSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - Model Grid

struct ModelGrid: View {
    let models: [MLXCommunityModel]
    @ObservedObject var downloadService: MLXModelDownloadService
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(models) { model in
                    ModelCard(
                        model: model,
                        downloadService: downloadService
                    )
                }
            }
            .padding()
        }
    }
}

// MARK: - Model Card

struct ModelCard: View {
    let model: MLXCommunityModel
    @ObservedObject var downloadService: MLXModelDownloadService
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(model.name)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if model.isRecommended {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                }
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Stats
            HStack {
                StatItem(icon: "arrow.down.circle", value: formatCount(model.downloads))
                Spacer()
                StatItem(icon: "heart", value: formatCount(model.likes))
                Spacer()
                StatItem(icon: "internaldrive", value: model.estimatedSize)
            }
            
            // Tags
            if !model.tags.isEmpty {
                TagsView(tags: Array(model.tags.prefix(3)))
            }
            
            // Download status and actions
            DownloadActionsView(
                model: model,
                downloadService: downloadService,
                onShowDetails: { showingDetails = true }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingDetails) {
            ModelDetailView(model: model, downloadService: downloadService)
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return "\(count)"
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption2)
        }
        .foregroundColor(.secondary)
    }
}

struct TagsView: View {
    let tags: [String]
    
    var body: some View {
        HStack {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            Spacer()
        }
    }
}

// MARK: - Download Actions View

struct DownloadActionsView: View {
    let model: MLXCommunityModel
    @ObservedObject var downloadService: MLXModelDownloadService
    let onShowDetails: () -> Void
    
    var body: some View {
        HStack {
            Button("Details") {
                onShowDetails()
            }
            .font(.caption)
            .foregroundColor(.blue)
            
            Spacer()
            
            if downloadService.isModelDownloaded(model.id) {
                Text("Downloaded")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                
            } else if let progress = downloadService.getDownloadProgress(model.id) {
                VStack(spacing: 2) {
                    HStack {
                        Text("\(Int(progress.progress * 100))%")
                            .font(.caption2)
                        
                        Button("Cancel") {
                            downloadService.cancelDownload(model.id)
                        }
                        .font(.caption2)
                        .foregroundColor(.red)
                    }
                    
                    ProgressView(value: progress.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .frame(width: 60)
                }
                
            } else {
                Button("Download") {
                    Task {
                        try? await downloadService.downloadModel(model)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
        }
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Discovering MLX Community models...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let hasModels: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(hasModels ? "No models match your search" : "No models available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if hasModels {
                Text("Try adjusting your search terms")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Pull to refresh to discover models")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Downloads View

struct DownloadsView: View {
    @ObservedObject var downloadService: MLXModelDownloadService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !downloadService.activeDownloads.isEmpty {
                    Section("Active Downloads") {
                        ForEach(Array(downloadService.activeDownloads.values), id: \.id) { progress in
                            DownloadProgressRow(progress: progress, downloadService: downloadService)
                        }
                    }
                }
                
                if !downloadService.completedDownloads.isEmpty {
                    Section("Completed") {
                        ForEach(Array(downloadService.completedDownloads), id: \.self) { modelId in
                            CompletedDownloadRow(
                                modelId: modelId,
                                downloadService: downloadService
                            )
                        }
                    }
                }
                
                if !downloadService.failedDownloads.isEmpty {
                    Section("Failed") {
                        ForEach(Array(downloadService.failedDownloads.keys), id: \.self) { modelId in
                            FailedDownloadRow(
                                modelId: modelId,
                                error: downloadService.failedDownloads[modelId] ?? "Unknown error",
                                downloadService: downloadService
                            )
                        }
                    }
                }
                
                if downloadService.activeDownloads.isEmpty && 
                   downloadService.completedDownloads.isEmpty && 
                   downloadService.failedDownloads.isEmpty {
                    Section {
                        Text("No downloads yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Downloads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DownloadProgressRow: View {
    let progress: ModelDownloadProgress
    @ObservedObject var downloadService: MLXModelDownloadService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.modelName)
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    downloadService.cancelDownload(progress.modelId)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            HStack {
                Text(progress.formattedProgress)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let timeRemaining = progress.formattedTimeRemaining {
                    Text(timeRemaining)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ProgressView(value: progress.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding(.vertical, 4)
    }
}

struct CompletedDownloadRow: View {
    let modelId: String
    @ObservedObject var downloadService: MLXModelDownloadService
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(modelId)
                    .font(.headline)
                Text("Downloaded")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button("Delete") {
                showingDeleteAlert = true
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .alert("Delete Model", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                try? downloadService.deleteModel(modelId)
            }
        } message: {
            Text("Are you sure you want to delete this model? This action cannot be undone.")
        }
    }
}

struct FailedDownloadRow: View {
    let modelId: String
    let error: String
    @ObservedObject var downloadService: MLXModelDownloadService
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(modelId)
                .font(.headline)
            Text("Failed: \(error)")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}

// MARK: - Model Detail View

struct ModelDetailView: View {
    let model: MLXCommunityModel
    @ObservedObject var downloadService: MLXModelDownloadService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(model.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(model.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Stats
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        DetailStatCard("Downloads", formatCount(model.downloads))
                        DetailStatCard("Likes", formatCount(model.likes))
                        DetailStatCard("Size", model.estimatedSize)
                    }
                    
                    // Tags
                    if !model.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(model.tags.prefix(12), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // Technical details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Technical Details")
                            .font(.headline)
                        
                        DetailRow("Model ID", model.id)
                        DetailRow("Author", model.author)
                        DetailRow("Memory Requirement", model.memoryRequirement)
                        DetailRow("Quantized", model.isQuantized ? "Yes" : "No")
                        DetailRow("Compatible", model.isCompatible ? "Yes" : "No")
                        DetailRow("Last Updated", formatDate(model.lastModified))
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    DownloadButton(model: model, downloadService: downloadService)
                }
            }
        }
    }
    
    private func formatCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct DetailStatCard: View {
    let title: String
    let value: String
    
    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
        .padding(.vertical, 2)
    }
}

struct DownloadButton: View {
    let model: MLXCommunityModel
    @ObservedObject var downloadService: MLXModelDownloadService
    
    var body: some View {
        if downloadService.isModelDownloaded(model.id) {
            Button("Downloaded") {
                // Could show options to delete or reinstall
            }
            .foregroundColor(.green)
            .disabled(true)
            
        } else if let progress = downloadService.getDownloadProgress(model.id) {
            VStack {
                Text("\(Int(progress.progress * 100))%")
                    .font(.caption)
                Button("Cancel") {
                    downloadService.cancelDownload(model.id)
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
        } else {
            Button("Download") {
                Task {
                    try? await downloadService.downloadModel(model)
                }
            }
        }
    }
}

// MARK: - Supporting Types

public enum ModelSortOption: String, CaseIterable {
    case downloads = "downloads"
    case likes = "likes"
    case name = "name"
    case newest = "newest"
    case size = "size"
    
    public var displayName: String {
        switch self {
        case .downloads: return "Downloads"
        case .likes: return "Likes"
        case .name: return "Name"
        case .newest: return "Newest"
        case .size: return "Size"
        }
    }
}

// MARK: - Preview

#Preview {
    let communityService = MLXCommunityService()
    let downloadService = MLXModelDownloadService()
    
    return MLXCommunityModelsView(
        communityService: communityService,
        downloadService: downloadService
    )
}