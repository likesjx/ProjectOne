//
//  PromptEditView.swift
//  ProjectOne
//
//  Created by Claude on 7/16/25.
//

import SwiftUI
import SwiftData

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
struct PromptEditView: View {
    var template: PromptTemplate
    @ObservedObject var promptManager: PromptManager
    
    @State private var editedTemplate: String
    @State private var showingPreview = false
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showingDeleteAlert = false
    @State private var showingDuplicateDialog = false
    @State private var duplicateName = ""
    @State private var validationResult: PromptValidationResult
    
    init(template: PromptTemplate, promptManager: PromptManager) {
        self.template = template
        self.promptManager = promptManager
        self._editedTemplate = State(initialValue: template.template)
        self._validationResult = State(initialValue: template.validateArguments())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Template info
                    templateInfoSection
                    
                    // Arguments section
                    argumentsSection
                    
                    // Validation section
                    validationSection
                    
                    // Template editor
                    templateEditorSection
                    
                    // Preview section
                    if showingPreview {
                        previewSection
                    }
                }
                .padding()
            }
        }
        }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Cancel") {
                        cancelEditing()
                    }
                    
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving || !validationResult.isValid)
                } else {
                    Menu {
                        Button("Edit Template", systemImage: "pencil") {
                            startEditing()
                        }
                        
                        Button("Duplicate", systemImage: "doc.on.doc") {
                            duplicateName = "\(template.name) Copy"
                            showingDuplicateDialog = true
                        }
                        
                        if template.canReset {
                            Button("Reset to Default", systemImage: "arrow.clockwise") {
                                resetToDefault()
                            }
                        }
                        
                        Divider()
                        
                        if !template.isDefault {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                showingDeleteAlert = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(showingPreview ? "Hide Preview" : "Show Preview") {
                    showingPreview.toggle()
                }
            }
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .alert("Delete Template", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTemplate()
            }
        } message: {
            Text("Are you sure you want to delete '\(template.name)'? This action cannot be undone.")
        }
        .alert("Duplicate Template", isPresented: $showingDuplicateDialog) {
            TextField("Name", text: $duplicateName)
            Button("Cancel", role: .cancel) { }
            Button("Duplicate") {
                duplicateTemplate()
            }
        } message: {
            Text("Enter a name for the duplicate template")
        }
        .onChange(of: editedTemplate) { _, newValue in
            if isEditing {
                // Create a temporary template to validate
                let tempTemplate = PromptTemplate(
                    name: template.name,
                    category: template.category,
                    description: template.templateDescription,
                    template: newValue,
                    requiredArguments: template.requiredArguments,
                    optionalArguments: template.optionalArguments
                )
                validationResult = tempTemplate.validateArguments()
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: template.category.iconName)
                        .foregroundColor(.accentColor)
                    
                    Text(template.category.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if template.isModified {
                        Label("Modified", systemImage: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if template.isDefault {
                        Label("Default", systemImage: "star.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(template.templateDescription)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("v\(template.version)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(template.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
    }
    
    // MARK: - Template Info Section
    
    private var templateInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template Information")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                InfoRow(label: "Name", value: template.name)
                InfoRow(label: "Category", value: template.category.displayName)
                InfoRow(label: "Created", value: template.createdAt.formatted(date: .abbreviated, time: .shortened))
                InfoRow(label: "Updated", value: template.updatedAt.formatted(date: .abbreviated, time: .shortened))
                
                if !template.tags.isEmpty {
                    HStack {
                        Text("Tags:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(template.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Arguments Section
    
    private var argumentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arguments")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                // Required Arguments
                if !template.requiredArguments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Required Arguments")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                            ForEach(template.requiredArguments, id: \.self) { arg in
                                ArgumentBadge(argument: arg, isRequired: true, isFound: validationResult.foundArguments.contains(arg))
                            }
                        }
                    }
                }
                
                // Optional Arguments
                if !template.optionalArguments.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional Arguments")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                            ForEach(template.optionalArguments, id: \.self) { arg in
                                ArgumentBadge(argument: arg, isRequired: false, isFound: validationResult.foundArguments.contains(arg))
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Validation Section
    
    private var validationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Validation")
                    .font(.headline)
                
                Spacer()
                
                if validationResult.isValid {
                    Label("Valid", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Invalid", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            if !validationResult.isValid {
                VStack(alignment: .leading, spacing: 4) {
                    if !validationResult.missingRequiredArguments.isEmpty {
                        ErrorMessage(
                            icon: "exclamationmark.triangle.fill",
                            message: "Missing required arguments: \(validationResult.missingRequiredArguments.joined(separator: ", "))",
                            color: .red
                        )
                    }
                    
                    if !validationResult.undefinedArguments.isEmpty {
                        ErrorMessage(
                            icon: "questionmark.circle.fill",
                            message: "Undefined arguments: \(validationResult.undefinedArguments.joined(separator: ", "))",
                            color: .orange
                        )
                    }
                    
                    if !validationResult.extraArguments.isEmpty {
                        ErrorMessage(
                            icon: "info.circle.fill",
                            message: "Extra arguments: \(validationResult.extraArguments.joined(separator: ", "))",
                            color: .blue
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Template Editor Section
    
    private var templateEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Template Content")
                .font(.headline)
            
            if isEditing {
                TextEditor(text: $editedTemplate)
                    .font(.monospaced(.body)())
                    .frame(minHeight: 300)
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(validationResult.isValid ? Color.green : Color.red, lineWidth: 1)
                    )
            } else {
                ScrollView {
                    Text(template.template)
                        .font(.monospaced(.body)())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 400)
            }
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
            
            ScrollView {
                Text(template.renderPreview())
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 200)
        }
    }
    
    // MARK: - Actions
    
    private func startEditing() {
        isEditing = true
        editedTemplate = template.template
    }
    
    private func cancelEditing() {
        isEditing = false
        editedTemplate = template.template
        validationResult = template.validateArguments()
    }
    
    private func saveChanges() {
        guard validationResult.isValid else { return }
        
        isSaving = true
        
        Task {
            do {
                try await promptManager.updateTemplate(template, newContent: editedTemplate)
                
                await MainActor.run {
                    isEditing = false
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func resetToDefault() {
        Task {
            try await promptManager.resetTemplateToDefault(template)
            editedTemplate = template.template
            validationResult = template.validateArguments()
        }
    }
    
    private func deleteTemplate() {
        Task {
            try await promptManager.deleteTemplate(template)
        }
    }
    
    private func duplicateTemplate() {
        guard !duplicateName.isEmpty else { return }
        
        Task {
            try await promptManager.duplicateTemplate(template, newName: duplicateName)
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct ArgumentBadge: View {
    let argument: String
    let isRequired: Bool
    let isFound: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if isFound {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Image(systemName: isRequired ? "exclamationmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundColor(isRequired ? .red : .secondary)
            }
            
            Text("{\(argument)}")
                .font(.caption)
                .monospaced()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(isFound ? Color.green.opacity(0.1) : (isRequired ? Color.red.opacity(0.1) : Color.secondary.opacity(0.1)))
        .foregroundColor(isFound ? .green : (isRequired ? .red : .secondary))
        .cornerRadius(4)
    }
}

struct ErrorMessage: View {
    let icon: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            
            Text(message)
                .font(.caption)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

#Preview {
    if #available(iOS 19.0, macOS 16.0, tvOS 19.0, watchOS 12.0, *) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([PromptTemplate.self])
        let container = try! ModelContainer(for: schema, configurations: [config])
        let promptManager = PromptManager(modelContext: container.mainContext)
        
        let template = PromptTemplate(
            name: "Test Template",
            category: .memoryRetrieval,
            description: "A test template for preview",
            template: "Hello {name}, you have {count} messages.",
            requiredArguments: ["name", "count"],
            optionalArguments: ["greeting"],
            tags: ["test", "preview"]
        )
        
        return PromptEditView(template: template, promptManager: promptManager)
    } else {
        return Text("Requires iOS 19.0+")
    }
}