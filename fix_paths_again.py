
import re

def execute():
    project_file_path = '/Users/jaredlikes/code/ProjectOne/ProjectOne.xcodeproj/project.pbxproj'

    path_mappings = {
        'path = ProjectOne/Agents/TextIngestionAgent.swift': 'path = ProjectOne/Features/Memory/Agents/TextIngestionAgent.swift',
        'path = ProjectOne/Services/Cognitive/CognitiveDecisionEngine.swift': 'path = ProjectOne/Features/Core/Services/Cognitive/CognitiveDecisionEngine.swift',
        'path = ProjectOne/Services/Security/APIKeyManager.swift': 'path = ProjectOne/Features/Core/Services/Security/APIKeyManager.swift',
        'path = ProjectOne/Settings/AIProviderSettings.swift': 'path = ProjectOne/Features/Settings/AIProviderSettings.swift',
        'path = ProjectOne/Settings/Views/AIProviderSettingsView.swift': 'path = ProjectOne/Features/Settings/Views/AIProviderSettingsView.swift',
        'path = ProjectOne/Views/Cognitive/CognitiveDecisionDashboard.swift': 'path = ProjectOne/Features/UI/Cognitive/CognitiveDecisionDashboard.swift',
        'path = ProjectOne/Views/Memory/MemoryContextPanel.swift': 'path = ProjectOne/Features/UI/Memory/MemoryContextPanel.swift',
        'path = ProjectOne/Views/Security/APIKeyManagementView.swift': 'path = ProjectOne/Features/UI/Security/APIKeyManagementView.swift',
        'path = ProjectOne/Views/iOS26TestView.swift': 'path = ProjectOne/Features/UI/iOS26TestView.swift',
        'path = ProjectOne/Features/Core/Common/PerformanceOptimizedService.swift': 'path = ProjectOne/Core/Common/PerformanceOptimizedService.swift',
        'path = ProjectOne/Features/Core/Common/ServiceFactory.swift': 'path = ProjectOne/Core/Common/ServiceFactory.swift',
        'path = ProjectOne/Features/Core/Common/SystemInitializationView.swift': 'path = ProjectOne/Core/Common/SystemInitializationView.swift',
        'path = ProjectOne/Features/Core/Common/UnifiedSystemManager.swift': 'path = ProjectOne/Core/Common/UnifiedSystemManager.swift',
        'path = ProjectOne/Features/Core/Common/URLHandler.swift': 'path = ProjectOne/Core/Common/URLHandler.swift',
        'path = ProjectOne/Features/Core/Navigation/ContentListView.swift': 'path = ProjectOne/Core/Navigation/ContentListView.swift',
        'path = ProjectOne/Features/Core/Navigation/ContentView.swift': 'path = ProjectOne/Core/Navigation/ContentView.swift',
        'path = ProjectOne/Features/Core/Navigation/ContentView_macOS.swift': 'path = ProjectOne/Core/Navigation/ContentView_macOS.swift',
        'path = ProjectOne/Features/Core/Navigation/QuickActionBar.swift': 'path = ProjectOne/Core/Navigation/QuickActionBar.swift',
    }

    try:
        with open(project_file_path, 'r') as f:
            content = f.read()

        for old_path, new_path in path_mappings.items():
            content = content.replace(old_path, new_path)

        with open(project_file_path, 'w') as f:
            f.write(content)

        print("Successfully updated project file with path corrections.")

    except Exception as e:
        print(f"An error occurred: {e}")

execute()
