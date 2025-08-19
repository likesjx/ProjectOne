//
//  IntelligenceSettingsView.swift
//  ProjectOne
//
//  Created by Claude on 8/19/25.
//  Settings view for Apple Intelligence integration
//

import SwiftUI

// MARK: - Intelligence Settings View

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
public struct IntelligenceSettingsView: View {
    @StateObject private var intelligenceService: AppleIntelligenceService
    @State private var showingPrivacyInfo = false
    @State private var showingCapabilityDetails = false
    @State private var selectedCapability: IntelligenceCapability?
    
    public init(intelligenceService: AppleIntelligenceService) {
        self._intelligenceService = StateObject(wrappedValue: intelligenceService)
    }
    
    public var body: some View {
        List {
            availabilitySection
            
            if intelligenceService.isAvailable {
                enablementSection
                
                if intelligenceService.isEnabled {
                    capabilitiesSection
                    privacySection
                    usageSection
                }
            } else {
                unavailableSection
            }
        }
        .navigationTitle("Apple Intelligence")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPrivacyInfo) {
            privacyInfoSheet
        }
        .sheet(item: $selectedCapability) { capability in
            capabilityDetailSheet(capability)
        }
    }
    
    // MARK: - Availability Section
    
    private var availabilitySection: some View {
        Section {
            HStack {
                Image(systemName: intelligenceService.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(intelligenceService.isAvailable ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Intelligence")
                        .font(GlassDesignSystem.Typography.headline)
                    
                    Text(intelligenceService.isAvailable ? 
                         "Available on this device" : 
                         "Not available on this device")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if intelligenceService.isAvailable {
                    intelligenceStatusBadge
                }
            }
        } footer: {
            if intelligenceService.isAvailable {
                Text("Apple Intelligence enhances your cognitive memory system with AI-powered search, insights, and content generation.")
            } else {
                Text("Apple Intelligence requires a compatible device with the latest software. Check Apple's support documentation for device compatibility.")
            }
        }
    }
    
    private var intelligenceStatusBadge: some View {
        HStack(spacing: GlassDesignSystem.Spacing.xs) {
            Circle()
                .fill(intelligenceService.isEnabled ? GlassDesignSystem.Colors.cognitiveAccent : .secondary)
                .frame(width: 8, height: 8)
                .modifier(CognitiveGlow(
                    color: GlassDesignSystem.Colors.cognitiveAccent,
                    isActive: intelligenceService.isEnabled
                ))
            
            Text(intelligenceService.isEnabled ? "Enabled" : "Disabled")
                .font(GlassDesignSystem.Typography.caption)
                .foregroundColor(intelligenceService.isEnabled ? .primary : .secondary)
        }
        .padding(.horizontal, GlassDesignSystem.Spacing.sm)
        .padding(.vertical, GlassDesignSystem.Spacing.xs)
        .background(GlassDesignSystem.Materials.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: GlassDesignSystem.CornerRadius.sm))
    }
    
    // MARK: - Enablement Section
    
    private var enablementSection: some View {
        Section {
            Toggle("Enable Apple Intelligence", isOn: Binding(
                get: { intelligenceService.isEnabled },
                set: { enabled in
                    Task {
                        if enabled {
                            await intelligenceService.enableAppleIntelligence()
                        } else {
                            await intelligenceService.disableAppleIntelligence()
                        }
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: GlassDesignSystem.Colors.cognitiveAccent))
        } footer: {
            Text("Enable Apple Intelligence to enhance your cognitive memory system with AI-powered features. This will process your data locally on your device.")
        }
    }
    
    // MARK: - Capabilities Section
    
    private var capabilitiesSection: some View {
        Section("Available Capabilities") {
            ForEach(Array(intelligenceService.capabilities), id: \.self) { capability in
                Button(action: {
                    selectedCapability = capability
                    showingCapabilityDetails = true
                }) {
                    HStack {
                        Image(systemName: capabilityIcon(capability))
                            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(capability.displayName)
                                .font(GlassDesignSystem.Typography.body)
                                .foregroundColor(.primary)
                            
                            Text(capability.description)
                                .font(GlassDesignSystem.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.tertiary)
                    }
                }
            }
        } footer: {
            Text("Tap a capability to learn more about how it enhances your cognitive memory system.")
        }
    }
    
    private func capabilityIcon(_ capability: IntelligenceCapability) -> String {
        switch capability {
        case .semanticSearch: return "magnifyingglass.circle"
        case .contentGeneration: return "doc.text.fill"
        case .knowledgeExtraction: return "link.circle"
        case .insights: return "brain.head.profile"
        case .voiceInteraction: return "mic.circle"
        }
    }
    
    // MARK: - Privacy Section
    
    private var privacySection: some View {
        Section("Privacy & Data") {
            Button(action: {
                showingPrivacyInfo = true
            }) {
                HStack {
                    Image(systemName: "hand.raised.circle")
                        .foregroundColor(.blue)
                    
                    Text("Privacy Information")
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
            }
            
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("On-Device Processing")
                        .font(GlassDesignSystem.Typography.body)
                    
                    Text("Your data is processed locally and never leaves your device")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "lock.shield")
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("End-to-End Encryption")
                        .font(GlassDesignSystem.Typography.body)
                    
                    Text("All cognitive data remains encrypted and private")
                        .font(GlassDesignSystem.Typography.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Usage Section
    
    private var usageSection: some View {
        Section("Usage Statistics") {
            HStack {
                Text("Enhanced Searches")
                Spacer()
                Text("247") // Mock data
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Generated Insights")
                Spacer()
                Text("42") // Mock data
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Content Enhancements")
                Spacer()
                Text("89") // Mock data
                    .foregroundColor(.secondary)
            }
            
            Button("Reset Usage Statistics") {
                // Reset usage stats
            }
            .foregroundColor(.red)
        } footer: {
            Text("Usage statistics are stored locally and help improve your experience.")
        }
    }
    
    // MARK: - Unavailable Section
    
    private var unavailableSection: some View {
        Section {
            VStack(spacing: GlassDesignSystem.Spacing.md) {
                Image(systemName: "brain.head.profile")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                
                Text("Apple Intelligence Unavailable")
                    .font(GlassDesignSystem.Typography.headline)
                    .multilineTextAlignment(.center)
                
                Text("Apple Intelligence requires a compatible device with the latest software. Your cognitive memory system will continue to work with traditional search and analysis.")
                    .font(GlassDesignSystem.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Check Compatibility") {
                    // Open Apple's compatibility page
                    if let url = URL(string: "https://support.apple.com/apple-intelligence") {
                        #if canImport(UIKit)
                        UIApplication.shared.open(url)
                        #elseif canImport(AppKit)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }
                .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
            }
            .padding(.vertical, GlassDesignSystem.Spacing.lg)
        }
    }
    
    // MARK: - Privacy Info Sheet
    
    private var privacyInfoSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.lg) {
                    privacyInfoSection("Data Processing", 
                                     icon: "cpu",
                                     description: "Apple Intelligence processes your cognitive memory data entirely on your device. No personal data is sent to Apple's servers.")
                    
                    privacyInfoSection("Secure Enclave", 
                                     icon: "lock.shield", 
                                     description: "Sensitive operations are performed in the Secure Enclave, ensuring your cognitive data remains private and encrypted.")
                    
                    privacyInfoSection("No Data Collection", 
                                     icon: "eye.slash", 
                                     description: "Apple and ProjectOne cannot access your cognitive memory content. All processing happens locally.")
                    
                    privacyInfoSection("User Control", 
                                     icon: "hand.raised", 
                                     description: "You have complete control over Apple Intelligence features. You can disable capabilities or turn off the entire system at any time.")
                    
                    privacyInfoSection("Transparency", 
                                     icon: "doc.text.magnifyingglass", 
                                     description: "All Apple Intelligence enhancements are clearly marked in the interface, so you always know when AI is being used.")
                }
                .padding()
            }
            .navigationTitle("Privacy Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingPrivacyInfo = false
                    }
                }
            }
        }
    }
    
    private func privacyInfoSection(_ title: String, icon: String, description: String) -> some View {
        HStack(alignment: .top, spacing: GlassDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                Text(title)
                    .font(GlassDesignSystem.Typography.headline)
                
                Text(description)
                    .font(GlassDesignSystem.Typography.body)
                    .foregroundColor(.secondary)
            }
        }
        .glassCard()
    }
    
    // MARK: - Capability Detail Sheet
    
    private func capabilityDetailSheet(_ capability: IntelligenceCapability) -> some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.lg) {
                    // Capability overview
                    VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
                        HStack {
                            Image(systemName: capabilityIcon(capability))
                                .font(.largeTitle)
                                .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
                            
                            VStack(alignment: .leading) {
                                Text(capability.displayName)
                                    .font(GlassDesignSystem.Typography.title)
                                
                                Text(capability.description)
                                    .font(GlassDesignSystem.Typography.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .glassCard()
                    
                    // Capability-specific details
                    capabilityDetails(capability)
                    
                    // Example use cases
                    useCasesSection(capability)
                }
                .padding()
            }
            .navigationTitle(capability.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedCapability = nil
                    }
                }
            }
        }
    }
    
    private func capabilityDetails(_ capability: IntelligenceCapability) -> some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("How it Works")
                .font(GlassDesignSystem.Typography.headline)
            
            Text(capabilityExplanation(capability))
                .font(GlassDesignSystem.Typography.body)
                .foregroundColor(.secondary)
        }
        .glassCard()
    }
    
    private func capabilityExplanation(_ capability: IntelligenceCapability) -> String {
        switch capability {
        case .semanticSearch:
            return "Uses advanced language models to understand the meaning behind your search queries, finding relevant entities and memories even when exact keywords don't match."
        case .contentGeneration:
            return "Generates helpful descriptions, summaries, and explanations for your entities and memories using context from your personal knowledge graph."
        case .knowledgeExtraction:
            return "Automatically identifies potential relationships between entities and suggests connections that might not be immediately obvious."
        case .insights:
            return "Analyzes patterns in your cognitive memory system to provide personalized insights and recommendations for improving your knowledge organization."
        case .voiceInteraction:
            return "Enables Siri integration for voice commands and queries, allowing you to interact with your cognitive memory system hands-free."
        }
    }
    
    private func useCasesSection(_ capability: IntelligenceCapability) -> some View {
        VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.md) {
            Text("Example Uses")
                .font(GlassDesignSystem.Typography.headline)
            
            VStack(alignment: .leading, spacing: GlassDesignSystem.Spacing.sm) {
                ForEach(useCases(capability), id: \.self) { useCase in
                    HStack(alignment: .top, spacing: GlassDesignSystem.Spacing.sm) {
                        Text("•")
                            .foregroundColor(GlassDesignSystem.Colors.cognitiveAccent)
                        
                        Text(useCase)
                            .font(GlassDesignSystem.Typography.body)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .glassCard()
    }
    
    private func useCases(_ capability: IntelligenceCapability) -> [String] {
        switch capability {
        case .semanticSearch:
            return [
                "Search for \"innovation concepts\" and find entities related to creativity and new ideas",
                "Find people associated with AI research without exact name matches",
                "Discover connections between seemingly unrelated topics"
            ]
        case .contentGeneration:
            return [
                "Generate detailed descriptions for entities with minimal information",
                "Create summaries of complex relationship networks",
                "Suggest meaningful tags and categories for new entities"
            ]
        case .knowledgeExtraction:
            return [
                "Identify that a person entity should be connected to their workplace",
                "Suggest temporal relationships between events and people",
                "Discover implicit concept hierarchies and categorizations"
            ]
        case .insights:
            return [
                "\"Your knowledge graph shows strong clustering around technology topics\"",
                "\"Consider adding more temporal context to your episodic memories\"",
                "\"These entities might benefit from additional relationship connections\""
            ]
        case .voiceInteraction:
            return [
                "\"Hey Siri, show me cognitive insights\"",
                "\"Hey Siri, search for entities related to machine learning\"",
                "\"Hey Siri, what are my most connected entities?\""
            ]
        }
    }
}

// MARK: - Preview

@available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, *)
#Preview {
    NavigationView {
        IntelligenceSettingsView(intelligenceService: AppleIntelligenceService())
    }
}