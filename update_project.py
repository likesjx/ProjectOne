import os
import re

project_file_path = '/Users/jaredlikes/code/ProjectOne/ProjectOne.xcodeproj/project.pbxproj'

# This is a simplified representation of the file moves.
# A more robust solution would involve a more comprehensive mapping.
file_moves = {
    '"ProjectOne/Agents/TextIngestionAgent.swift"': '"ProjectOne/Features/Memory/Agents/TextIngestionAgent.swift"',
    '"ProjectOne/Services/Cognitive/CognitiveDecisionEngine.swift"': '"ProjectOne/Features/Core/Services/Cognitive/CognitiveDecisionEngine.swift"',
    '"ProjectOne/Services/Security/APIKeyManager.swift"': '"ProjectOne/Features/Core/Services/Security/APIKeyManager.swift"',
    '"ProjectOne/Settings/AIProviderSettings.swift"': '"ProjectOne/Features/Settings/AIProviderSettings.swift"',
    '"ProjectOne/Settings/Views/AIProviderSettingsView.swift"': '"ProjectOne/Features/Settings/Views/AIProviderSettingsView.swift"',
    '"ProjectOne/Views/Cognitive/CognitiveDecisionDashboard.swift"': '"ProjectOne/Features/UI/Cognitive/CognitiveDecisionDashboard.swift"',
    '"ProjectOne/Views/Memory/MemoryContextPanel.swift"': '"ProjectOne/Features/UI/Memory/MemoryContextPanel.swift"',
    '"ProjectOne/Views/Security/APIKeyManagementView.swift"': '"ProjectOne/Features/UI/Security/APIKeyManagementView.swift"',
    '"ProjectOne/Views/iOS26TestView.swift"': '"ProjectOne/Features/UI/iOS26TestView.swift"',
    '"ProjectOne/Features/Core/Common/PerformanceOptimizedService.swift"': '"ProjectOne/Core/Common/PerformanceOptimizedService.swift"',
    '"ProjectOne/Features/Core/Common/ServiceFactory.swift"': '"ProjectOne/Core/Common/ServiceFactory.swift"',
    '"ProjectOne/Features/Core/Common/SystemInitializationView.swift"': '"ProjectOne/Core/Common/SystemInitializationView.swift"',
    '"ProjectOne/Features/Core/Common/UnifiedSystemManager.swift"': '"ProjectOne/Core/Common/UnifiedSystemManager.swift"',
    '"ProjectOne/Features/Core/Common/URLHandler.swift"': '"ProjectOne/Core/Common/URLHandler.swift"',
    '"ProjectOne/Features/Core/Navigation/ContentListView.swift"': '"ProjectOne/Core/Navigation/ContentListView.swift"',
    '"ProjectOne/Features/Core/Navigation/ContentView.swift"': '"ProjectOne/Core/Navigation/ContentView.swift"',
    '"ProjectOne/Features/Core/Navigation/ContentView_macOS.swift"': '"ProjectOne/Core/Navigation/ContentView_macOS.swift"',
    '"ProjectOne/Features/Core/Navigation/QuickActionBar.swift"': '"ProjectOne/Core/Navigation/QuickActionBar.swift"',
}

def update_project_file():
    with open(project_file_path, 'r') as f:
        content = f.read()

    for old_path, new_path in file_moves.items():
        content = content.replace(old_path, new_path)

    with open(project_file_path, 'w') as f:
        f.write(content)
    print("Successfully updated project file with more specific path corrections.")

if __name__ == '__main__':
    update_project_file()