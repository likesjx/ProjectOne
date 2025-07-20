import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

/// View for managing data export and import operations
struct DataExportView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var exportService: DataExportService
    @State private var selectedExportType: ExportType = .memoryAnalytics
    @State private var selectedFormat: ExportFormat = .json
    @State private var selectedTimeRange: ExportTimeRange = .all
    @State private var showingImportPicker = false
    @State private var showingExportResult = false
    @State private var showingImportResult = false
    @State private var exportResultURL: URL?
    @State private var importResultMessage: String = ""
    @State private var showingTimeRangePicker = false
    
    init(modelContext: ModelContext) {
        self._exportService = StateObject(wrappedValue: DataExportService(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Export Section
                    exportSection
                    
                    // Import Section
                    importSection
                    
                    // Export History
                    if let lastURL = exportService.lastExportURL {
                        exportHistorySection(url: lastURL)
                    }
                    
                    // Import History
                    if let lastResult = exportService.lastImportResult {
                        importHistorySection(result: lastResult)
                    }
                }
                .padding()
            }
            .navigationTitle("Data Management")
            .sheet(isPresented: $showingImportPicker) {
                importDocumentPicker
            }
            .alert("Export Complete", isPresented: $showingExportResult) {
                Button("Share") {
                    if let url = exportResultURL {
                        shareFile(url: url)
                    }
                }
                Button("OK") { }
            } message: {
                Text("Data exported successfully. You can share the file or save it to Files app.")
            }
            .alert("Import Result", isPresented: $showingImportResult) {
                Button("OK") { }
            } message: {
                Text(importResultMessage)
            }
        }
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Export Type Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Export Type", selection: $selectedExportType) {
                    ForEach(ExportType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Format Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Export Format", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Label(format.displayName, systemImage: format.systemImageName).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Time Range Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Range")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Button(action: { showingTimeRangePicker = true }) {
                    HStack {
                        Text(selectedTimeRange.displayName)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray))
                    .cornerRadius(8)
                }
                .sheet(isPresented: $showingTimeRangePicker) {
                    timeRangePickerView
                }
            }
            
            // Export Progress
            if exportService.isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportService.exportProgress)
                    Text("Exporting data... \(Int(exportService.exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Export Button
            Button(action: performExport) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Data")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(exportService.isExporting ? Color.gray : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(exportService.isExporting)
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import previously exported ProjectOne data. Duplicate entries will be skipped automatically.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Import Progress
            if exportService.isImporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportService.importProgress)
                    Text("Importing data... \(Int(exportService.importProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Import Button
            Button(action: { showingImportPicker = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import Data")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(exportService.isImporting ? Color.gray : Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(exportService.isImporting)
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - History Sections
    
    private func exportHistorySection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Export")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Exported: \(url.creationDate?.formatted() ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let size = url.fileSize {
                        Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Share") {
                    shareFile(url: url)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func importHistorySection(result: ImportResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Import")
                .font(.title3)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Type: \(result.type.displayName)")
                    .font(.subheadline)
                
                HStack {
                    Text("Imported: \(result.importedCount)")
                        .foregroundColor(.green)
                    
                    if result.skippedCount > 0 {
                        Text("Skipped: \(result.skippedCount)")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
                
                if let metadata = result.metadata {
                    Text("Source: \(metadata.appVersion) on \(metadata.platform)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Time Range Picker
    
    private var timeRangePickerView: some View {
        NavigationView {
            List {
                ForEach(ExportTimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        selectedTimeRange = range
                        showingTimeRangePicker = false
                    }) {
                        HStack {
                            Text(range.displayName)
                            Spacer()
                            if selectedTimeRange == range {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Time Range")
            .toolbar {
                ToolbarItem(placement: {
                    #if os(iOS)
                    .navigationBarTrailing
                    #else
                    .automatic
                    #endif
                }()) {
                    Button("Cancel") {
                        showingTimeRangePicker = false
                    }
                }
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
    
    // MARK: - Document Picker
    
    private var importDocumentPicker: some View {
        DocumentPicker(allowedContentTypes: [.json]) { url in
            Task {
                do {
                    let result = try await exportService.importData(from: url)
                    await MainActor.run {
                        importResultMessage = "Successfully imported \(result.importedCount) items. \(result.skippedCount) duplicates were skipped."
                        showingImportResult = true
                    }
                } catch {
                    await MainActor.run {
                        importResultMessage = "Import failed: \(error.localizedDescription)"
                        showingImportResult = true
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performExport() {
        Task {
            do {
                let url: URL
                
                switch selectedExportType {
                case .memoryAnalytics:
                    if selectedFormat == .json {
                        url = try await exportService.exportMemoryAnalytics(timeRange: selectedTimeRange.dateInterval)
                    } else {
                        url = try await exportService.exportToCSV(dataType: .memoryAnalytics)
                    }
                    
                case .consolidationEvents:
                    if selectedFormat == .json {
                        url = try await exportService.exportConsolidationEvents(timeRange: selectedTimeRange.dateInterval)
                    } else {
                        url = try await exportService.exportToCSV(dataType: .consolidationEvents)
                    }
                    
                case .completeSystem:
                    url = try await exportService.exportCompleteSystemData()
                    
                case .performanceMetrics:
                    url = try await exportService.exportToCSV(dataType: .performanceMetrics)
                }
                
                await MainActor.run {
                    exportResultURL = url
                    showingExportResult = true
                }
                
            } catch {
                print("Export failed: \(error)")
                // TODO: Show error alert
            }
        }
    }
    
    private func shareFile(url: URL) {
        #if os(iOS)
        let activityController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
        #else
        // On macOS, copy file to desktop or show in Finder
        print("File exported to: \(url.path)")
        #endif
    }
}

// MARK: - Supporting Types

enum ExportType: String, CaseIterable {
    case memoryAnalytics = "memory_analytics"
    case consolidationEvents = "consolidation_events"
    case performanceMetrics = "performance_metrics"
    case completeSystem = "complete_system"
    
    var displayName: String {
        switch self {
        case .memoryAnalytics:
            return "Memory Analytics"
        case .consolidationEvents:
            return "Consolidation Events"
        case .performanceMetrics:
            return "Performance Metrics"
        case .completeSystem:
            return "Complete System"
        }
    }
}

enum ExportFormat: String, CaseIterable {
    case json = "json"
    case csv = "csv"
    case markdown = "markdown"
    
    var displayName: String {
        switch self {
        case .json:
            return "JSON"
        case .csv:
            return "CSV"
        case .markdown:
            return "Markdown"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .json:
            return "doc.text"
        case .csv:
            return "tablecells"
        case .markdown:
            return "doc.richtext"
        }
    }
}

// Extended TimeRange for export functionality
enum ExportTimeRange: String, CaseIterable {
    case all = "all"
    case lastMonth = "30d"
    case lastWeek = "7d"
    case last24Hours = "24h"
    case lastHour = "1h"
    
    var displayName: String {
        switch self {
        case .all:
            return "All Time"
        case .lastMonth:
            return "Last Month"
        case .lastWeek:
            return "Last Week"
        case .last24Hours:
            return "Last 24 Hours"
        case .lastHour:
            return "Last Hour"
        }
    }
    
    var dateInterval: DateInterval? {
        switch self {
        case .all:
            return nil // Return nil for "all time"
        case .lastHour:
            let end = Date()
            let start = end.addingTimeInterval(-3600)
            return DateInterval(start: start, end: end)
        case .last24Hours:
            let end = Date()
            let start = end.addingTimeInterval(-86400)
            return DateInterval(start: start, end: end)
        case .lastWeek:
            let end = Date()
            let start = end.addingTimeInterval(-604800)
            return DateInterval(start: start, end: end)
        case .lastMonth:
            let end = Date()
            let start = end.addingTimeInterval(-2592000)
            return DateInterval(start: start, end: end)
        }
    }
}

extension ImportDataType {
    var displayName: String {
        switch self {
        case .memoryAnalytics:
            return "Memory Analytics"
        case .consolidationEvents:
            return "Consolidation Events"
        case .completeSystem:
            return "Complete System"
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: View {
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void
    @State private var isPresented = false
    
    var body: some View {
        Button("Import") {
            #if canImport(AppKit)
            showOpenPanel()
            #else
            isPresented = true
            #endif
        }
        #if !canImport(AppKit)
        .fileImporter(
            isPresented: $isPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    onDocumentPicked(url)
                }
            case .failure(let error):
                print("File import failed: \(error)")
            }
        }
        #endif
    }
    
    #if canImport(AppKit)
    private func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedContentTypes
        
        if panel.runModal() == .OK, let url = panel.url {
            onDocumentPicked(url)
        }
    }
    #endif
}

// MARK: - URL Extensions

extension URL {
    var creationDate: Date? {
        try? resourceValues(forKeys: [.creationDateKey]).creationDate
    }
    
    var fileSize: Int? {
        try? resourceValues(forKeys: [.fileSizeKey]).fileSize
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        DataExportView(modelContext: ModelContext(try! SwiftData.ModelContainer(for: MemoryAnalytics.self)))
    }
}