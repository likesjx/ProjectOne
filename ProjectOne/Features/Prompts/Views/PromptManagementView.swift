//
//  PromptManagementView.swift
//  ProjectOne
//
//  Created by Claude on 7/16/25.
//

import SwiftUI
import SwiftData

struct PromptManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var promptManager: PromptManager
    
    @State private var selectedCategory: PromptCategory?
    @State private var searchText = ""
    @State private var showingCreateSheet = false
    @State private var showingResetAlert = false
    @State private var selectedTemplate: PromptTemplate?
    
    init(modelContext: ModelContext) {
        self._promptManager = StateObject(wrappedValue: PromptManager(modelContext: modelContext))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search templates...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Material.regular)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PromptCategory.allCases, id: \.self) { category in
                            let count = promptManager.templates.filter { $0.category == category }.count
                            CategoryFilterChip(
                                category: category,
                                count: count,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = selectedCategory == category ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Templates List
                if promptManager.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading templates...")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredTemplates.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No templates found")
                            .font(.headline)
                        Text("Try adjusting your search or filters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if promptManager.templates.isEmpty {
                            Button("Create Default Templates") {
                                Task {
                                    await promptManager.loadTemplates()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredTemplates, id: \.id) { template in
                        NavigationLink(destination: PromptDetailView(template: template, promptManager: promptManager)) {
                            TemplateRow(template: template)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
                
                Spacer()
            }
            .navigationTitle("Prompt Templates")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    
                    Menu {
                        Button("Reset All to Defaults") {
                            showingResetAlert = true
                        }
                        
                        Button("Export Templates") {
                            // TODO: Implement export
                        }
                        
                        Button("Import Templates") {
                            // TODO: Implement import
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            print("🔧 [PromptManagementView] View appeared")
            print("🔧 [PromptManagementView] Debug: Templates: \(promptManager.templates.count)")
            print("🔧 [PromptManagementView] Debug: Loading: \(promptManager.isLoading)")
            print("🔧 [PromptManagementView] Debug: Error: \(promptManager.errorMessage ?? "None")")
            print("🔧 [PromptManagementView] Debug: Filtered templates: \(filteredTemplates.count)")
        }
        .task {
            print("🔧 [PromptManagementView] Starting loadTemplates task...")
            await promptManager.loadTemplates()
            print("🔧 [PromptManagementView] Task completed. Templates: \(promptManager.templates.count)")
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePromptTemplateView(promptManager: promptManager)
        }
        .alert("Reset All Templates", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                Task {
                    do {
                        try await promptManager.resetAllTemplatesToDefaults()
                    } catch {
                        print("Failed to reset templates: \(error)")
                    }
                }
            }
        } message: {
            Text("This will replace all templates with defaults. Custom templates will be lost.")
        }
    }
    
    private var filteredTemplates: [PromptTemplate] {
        var templates = promptManager.templates
        
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            templates = promptManager.searchTemplates(query: searchText)
        }
        
        return templates.sorted { $0.name < $1.name }
    }
}

struct CategoryFilterChip: View {
    let category: PromptCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.displayName)
                    .font(.caption.weight(.medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundColor(isSelected ? Color.white : Color.primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct CategoryRow: View {
    let category: PromptCategory
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: category.iconName)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(category.displayName)
            
            Spacer()
            
            Text("\(count)")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct TemplateListView: View {
    let templates: [PromptTemplate]
    @Binding var selectedTemplate: PromptTemplate?
    @Binding var searchText: String
    
    var body: some View {
        List(templates, id: \.id, selection: $selectedTemplate) { template in
            TemplateRow(template: template)
                .tag(template)
        }
        .listStyle(PlainListStyle())
    }
}

struct TemplateRow: View {
    let template: PromptTemplate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(template.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if template.isModified {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                if template.isDefault {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }
            
            Text(template.templateDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label("\(template.requiredArguments.count) required", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundColor(.red)
                
                if !template.optionalArguments.isEmpty {
                    Label("\(template.optionalArguments.count) optional", systemImage: "questionmark.circle")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                let validation = template.validateArguments()
                if validation.isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct CreatePromptTemplateView: View {
    let promptManager: PromptManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var category = PromptCategory.custom
    @State private var description = ""
    @State private var template = ""
    @State private var requiredArguments = ""
    @State private var optionalArguments = ""
    @State private var tags = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Template Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(PromptCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Template Content") {
                    TextField("Template", text: $template, axis: .vertical)
                        .lineLimit(5...15)
                        .font(.monospaced(.body)())
                }
                
                Section("Arguments") {
                    TextField("Required Arguments (comma-separated)", text: $requiredArguments)
                        .help("Example: user_query, content")
                    
                    TextField("Optional Arguments (comma-separated)", text: $optionalArguments)
                        .help("Example: context, metadata")
                }
                
                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $tags)
                        .help("Example: memory, analysis, retrieval")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTemplate()
                    }
                    .disabled(name.isEmpty || template.isEmpty || isLoading)
                }
            }
            .disabled(isLoading)
        }
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
    
    private func createTemplate() {
        isLoading = true
        errorMessage = nil
        
        let requiredArgs = requiredArguments.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let optionalArgs = optionalArguments.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let templateTags = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        Task {
            do {
                _ = try await promptManager.createTemplate(
                    name: name,
                    category: category,
                    description: description,
                    template: template,
                    requiredArguments: requiredArgs,
                    optionalArguments: optionalArgs,
                    tags: templateTags
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct PromptDetailView: View {
    let template: PromptTemplate
    let promptManager: PromptManager
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var testArguments: [String: String] = [:]
    @State private var testResult = ""
    @State private var mlxTestResult = ""
    @State private var foundationsTestResult = ""
    @State private var isTesting = false
    @EnvironmentObject private var gemmaCore: Gemma3nCore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(template.name)
                            .font(.largeTitle.bold())
                        
                        Spacer()
                        
                        HStack {
                            if template.isDefault {
                                Label("Default", systemImage: "star.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            
                            if template.isModified {
                                Label("Modified", systemImage: "pencil.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    
                    Label(template.category.displayName, systemImage: template.category.iconName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(template.templateDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Template Content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template")
                        .font(.headline)
                    
                    Text(template.template)
                        .font(.monospaced(.body)())
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Arguments
                if !template.requiredArguments.isEmpty || !template.optionalArguments.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Arguments")
                            .font(.headline)
                        
                        if !template.requiredArguments.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Required")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.red)
                                
                                ForEach(template.requiredArguments, id: \.self) { arg in
                                    HStack {
                                        Text("{\(arg)}")
                                            .font(.monospaced(.caption)())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(4)
                                        
                                        TextField("Test value", text: bindingForArgument(arg))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                        }
                        
                        if !template.optionalArguments.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Optional")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.blue)
                                
                                ForEach(template.optionalArguments, id: \.self) { arg in
                                    HStack {
                                        Text("{\(arg)}")
                                            .font(.monospaced(.caption)())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                        
                                        TextField("Test value", text: bindingForArgument(arg))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }
                        }
                        
                        VStack(spacing: 8) {
                            HStack(spacing: 12) {
                                Button("Test Template") {
                                    testTemplate()
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Test with MLX") {
                                    testTemplateWithMLX()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isTesting || !gemmaCore.isReady)
                            }
                            
                            if #available(iOS 26.0, macOS 26.0, *) {
                                Button("Test with Apple Foundation Models") {
                                    testTemplateWithFoundations()
                                }
                                .buttonStyle(.borderedProminent)
                                .foregroundColor(.green)
                                .disabled(isTesting)
                            }
                        }
                    }
                }
                
                // Test Results
                if !testResult.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Template Rendering")
                            .font(.headline)
                        
                        Text(testResult)
                            .font(.monospaced(.body)())
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // MLX Test Result
                if isTesting {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MLX Processing")
                            .font(.headline)
                        
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing with MLX Gemma3n...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // MLX Test Result (independent display)
                if !mlxTestResult.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MLX Response")
                            .font(.headline)
                        
                        Text(mlxTestResult)
                            .font(.body)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // Apple Foundation Models Test Result (independent display)
                if !foundationsTestResult.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apple Foundation Models Response")
                            .font(.headline)
                        
                        Text(foundationsTestResult)
                            .font(.body)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                // MLX Status
                if !gemmaCore.isReady {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MLX Status")
                            .font(.headline)
                        
                        if gemmaCore.isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading MLX Gemma3n model...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if let error = gemmaCore.errorMessage {
                            Text("MLX Error: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("MLX not ready")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle(template.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
                
                if !template.isDefault {
                    Button("Delete") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPromptTemplateView(template: template, promptManager: promptManager)
        }
        .alert("Delete Template", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await promptManager.deleteTemplate(template)
                    } catch {
                        print("❌ Failed to delete template: \(error)")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(template.name)'? This action cannot be undone.")
        }
    }
    
    private func bindingForArgument(_ argument: String) -> Binding<String> {
        return Binding(
            get: { testArguments[argument] ?? "" },
            set: { testArguments[argument] = $0 }
        )
    }
    
    private func testTemplate() {
        testResult = template.render(with: testArguments)
    }
    
    private func testTemplateWithMLX() {
        guard gemmaCore.isReady else {
            mlxTestResult = "MLX is not ready"
            return
        }
        
        let renderedPrompt = template.render(with: testArguments)
        
        isTesting = true
        mlxTestResult = ""
        foundationsTestResult = "" // Clear other provider result for clarity
        
        Task {
            let response = await gemmaCore.processText(renderedPrompt)
            
            await MainActor.run {
                isTesting = false
                mlxTestResult = response
            }
        }
    }
    
    @available(iOS 26.0, macOS 26.0, *)
    private func testTemplateWithFoundations() {
        let renderedPrompt = template.render(with: testArguments)
        
        isTesting = true
        foundationsTestResult = ""
        mlxTestResult = "" // Clear other provider result for clarity
        
        Task {
            do {
                let provider = AppleFoundationModelsProvider()
                try await provider.prepare()
                
                // Create a simple memory context for testing
                let memoryContext = MemoryContext(
                    userQuery: renderedPrompt,
                    containsPersonalData: false,
                    contextData: [
                        "entities": "",
                        "relationships": "",
                        "shortTermMemories": "",
                        "longTermMemories": "",
                        "episodicMemories": "",
                        "relevantNotes": ""
                    ]
                )
                
                let response = try await provider.generateResponse(
                    prompt: renderedPrompt,
                    context: memoryContext
                )
                
                await MainActor.run {
                    isTesting = false
                    foundationsTestResult = response.content
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    foundationsTestResult = "Apple Foundation Models error: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct EditPromptTemplateView: View {
    let template: PromptTemplate
    let promptManager: PromptManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var category: PromptCategory
    @State private var description: String
    @State private var templateContent: String
    @State private var requiredArguments: String
    @State private var optionalArguments: String
    @State private var tags: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(template: PromptTemplate, promptManager: PromptManager) {
        self.template = template
        self.promptManager = promptManager
        
        // Initialize state with current template values
        self._name = State(initialValue: template.name)
        self._category = State(initialValue: template.category)
        self._description = State(initialValue: template.templateDescription)
        self._templateContent = State(initialValue: template.template)
        self._requiredArguments = State(initialValue: template.requiredArguments.joined(separator: ", "))
        self._optionalArguments = State(initialValue: template.optionalArguments.joined(separator: ", "))
        self._tags = State(initialValue: template.tags.joined(separator: ", "))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Template Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(PromptCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.iconName)
                                .tag(category)
                        }
                    }
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Template Content") {
                    TextField("Template", text: $templateContent, axis: .vertical)
                        .lineLimit(5...15)
                        .font(.monospaced(.body)())
                }
                
                Section("Arguments") {
                    TextField("Required Arguments (comma-separated)", text: $requiredArguments)
                        .help("Example: user_query, content")
                    
                    TextField("Optional Arguments (comma-separated)", text: $optionalArguments)
                        .help("Example: context, metadata")
                }
                
                Section("Tags") {
                    TextField("Tags (comma-separated)", text: $tags)
                        .help("Example: memory, analysis, retrieval")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Edit Template")
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
                        saveChanges()
                    }
                    .disabled(name.isEmpty || templateContent.isEmpty || isLoading)
                }
            }
            .disabled(isLoading)
        }
    }
    
    private func saveChanges() {
        isLoading = true
        errorMessage = nil
        
        let requiredArgs = requiredArguments.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let optionalArgs = optionalArguments.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let templateTags = tags.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        Task {
            do {
                _ = try await promptManager.updateTemplate(
                    template,
                    name: name,
                    category: category,
                    description: description,
                    template: templateContent,
                    requiredArguments: requiredArgs,
                    optionalArguments: optionalArgs,
                    tags: templateTags
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let schema = Schema([PromptTemplate.self])
        let container = try! SwiftData.ModelContainer(for: schema, configurations: [config])
        
        PromptManagementView(modelContext: container.mainContext)
    } else {
        Text("Requires iOS 17.0+")
    }
}