
import re

def execute():
    # Corrected and simplified path mappings
    path_mappings = {
        "ProjectOne/Agents/TextIngestionAgent.swift": "ProjectOne/Features/Memory/Agents/TextIngestionAgent.swift",
        "ProjectOne/Services/Cognitive/CognitiveDecisionEngine.swift": "ProjectOne/Features/Core/Services/Cognitive/CognitiveDecisionEngine.swift",
        "ProjectOne/Services/Security/APIKeyManager.swift": "ProjectOne/Features/Core/Services/Security/APIKeyManager.swift",
        "ProjectOne/Settings/AIProviderSettings.swift": "ProjectOne/Features/Settings/AIProviderSettings.swift",
        "ProjectOne/Settings/Views/AIProviderSettingsView.swift": "ProjectOne/Features/Settings/Views/AIProviderSettingsView.swift",
        "ProjectOne/Views/Cognitive/CognitiveDecisionDashboard.swift": "ProjectOne/Features/UI/Cognitive/CognitiveDecisionDashboard.swift",
        "ProjectOne/Views/Memory/MemoryContextPanel.swift": "ProjectOne/Features/UI/Memory/MemoryContextPanel.swift",
        "ProjectOne/Views/Security/APIKeyManagementView.swift": "ProjectOne/Features/UI/Security/APIKeyManagementView.swift",
        "ProjectOne/Views/iOS26TestView.swift": "ProjectOne/Features/UI/iOS26TestView.swift",
        "ProjectOne/Features/Core/Common/PerformanceOptimizedService.swift": "ProjectOne/Core/Common/PerformanceOptimizedService.swift",
        "ProjectOne/Features/Core/Common/ServiceFactory.swift": "ProjectOne/Core/Common/ServiceFactory.swift",
        "ProjectOne/Features/Core/Common/SystemInitializationView.swift": "ProjectOne/Core/Common/SystemInitializationView.swift",
        "ProjectOne/Features/Core/Common/UnifiedSystemManager.swift": "ProjectOne/Core/Common/UnifiedSystemManager.swift",
        "ProjectOne/Features/Core/Common/URLHandler.swift": "ProjectOne/Core/Common/URLHandler.swift",
        "ProjectOne/Features/Core/Navigation/ContentListView.swift": "ProjectOne/Core/Navigation/ContentListView.swift",
        "ProjectOne/Features/Core/Navigation/ContentView.swift": "ProjectOne/Core/Navigation/ContentView.swift",
        "ProjectOne/Features/Core/Navigation/ContentView_macOS.swift": "ProjectOne/Core/Navigation/ContentView_macOS.swift",
        "ProjectOne/Features/Core/Navigation/QuickActionBar.swift": "ProjectOne/Core/Navigation/QuickActionBar.swift",
    }

    try:
        with open("/Users/jaredlikes/code/ProjectOne/ProjectOne.xcodeproj/project.pbxproj", 'r') as f:
            content = f.read()

        # Apply path corrections
        for old_path, new_path in path_mappings.items():
            content = content.replace(old_path, new_path)

        with open("/Users/jaredlikes/code/ProjectOne/ProjectOne.xcodeproj/project.pbxproj", 'w') as f:
            f.write(content)

        print("Successfully updated project file with path corrections.")

    except Exception as e:
        print(f"An error occurred: {e}")

execute()
