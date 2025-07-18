# Feature-Based Architecture Refactoring Plan

This document outlines the plan to refactor the project from a type-based directory structure (e.g., `Views`, `Models`, `Services`) to a feature-based structure. This change will improve code discoverability, scalability, and make the codebase easier to maintain for both human and AI developers.

## Rationale

The current structure groups files by their type. As the project grows, this leads to large, unwieldy folders and makes it difficult to see all the components of a single feature at a glance.

By reorganizing into feature-specific modules, we achieve:

*   **High Cohesion:** All code related to a single feature (UI, logic, data models) is co-located.
*   **Low Coupling:** Dependencies between features become explicit and easier to manage.
*   **Improved Discoverability:** Finding all files for a feature like "Knowledge Graph" is as simple as navigating to the `Features/KnowledgeGraph` directory.
*   **Enhanced Maintainability:** This logical grouping simplifies the process for any developer (human or AI) to localize and apply updates efficiently.

## Target Directory Structure

The proposed high-level structure is as follows:

```
ProjectOne/
├───Application/
│   ├───ProjectOneApp.swift
│   ├───AppCommands.swift
│   └───Info.plist
│
├───Features/
│   ├───KnowledgeGraph/
│   │   ├───Views/
│   │   │   ├───KnowledgeGraphView.swift
│   │   │   └───EntityNodeView.swift
│   │   ├───Services/
│   │   │   └───KnowledgeGraphService.swift
│   │   └───Models/
│   │       ├───Entity.swift
│   │       └───Relationship.swift
│   │
│   ├───VoiceMemos/
│   │   ├───Views/
│   │   │   └───VoiceMemoView.swift
│   │   ├───Services/
│   │   │   ├───AudioRecorder.swift
│   │   │   └───AudioPlayer.swift
│   │   └───Models/
│   │       └───RecordingItem.swift
│   │
│   └───(Other features...)
│
├───Core/
│   ├───AI/
│   │   ├───Providers/
│   │   └───Agents/
│   │
│   ├───Data/
│   │   └───(Core SwiftData Models)
│   │
│   ├───UI/
│   │   └───(Reusable UI components)
│   │
│   └───Utilities/
│       └───(Shared helpers)
│
└───Tests/
    ├───FeatureTests/
    │   └───KnowledgeGraphTests/
    └───CoreTests/
        └───AITests/
```

## Refactoring Steps & Commands

Execute these commands from the root of the project (`/Users/jaredlikes/code/ProjectOne`).

### 1. Create Base Directories

First, create the foundational directories for the new structure.

```bash
mkdir -p ProjectOne/Application
mkdir -p ProjectOne/Features
mkdir -p ProjectOne/Core/AI/Providers
mkdir -p ProjectOne/Core/AI/Agents
mkdir -p ProjectOne/Core/Data
mkdir -p ProjectOne/Core/UI
mkdir -p ProjectOne/Core/Utilities
mkdir -p Tests/FeatureTests
mkdir -p Tests/CoreTests
```

### 2. Refactor "KnowledgeGraph" Feature

This is the first feature to be migrated.

**Create feature-specific directories:**
```bash
mkdir -p ProjectOne/Features/KnowledgeGraph/Views
mkdir -p ProjectOne/Features/KnowledgeGraph/Services
mkdir -p ProjectOne/Features/KnowledgeGraph/Models
```

**Move the files:**
```bash
git mv ProjectOne/Views/KnowledgeGraphView.swift ProjectOne/Features/KnowledgeGraph/Views/
git mv ProjectOne/Views/EntityNodeView.swift ProjectOne/Features/KnowledgeGraph/Views/
git mv ProjectOne/Services/KnowledgeGraphService.swift ProjectOne/Features/KnowledgeGraph/Services/
git mv ProjectOne/Models/Entity.swift ProjectOne/Features/KnowledgeGraph/Models/
git mv ProjectOne/Models/Relationship.swift ProjectOne/Features/KnowledgeGraph/Models/
```

### 3. Refactor "VoiceMemos" Feature

**Create feature-specific directories:**
```bash
mkdir -p ProjectOne/Features/VoiceMemos/Views
mkdir -p ProjectOne/Features/VoiceMemos/Services
mkdir -p ProjectOne/Features/VoiceMemos/Models
```

**Move the files:**
```bash
git mv ProjectOne/Views/VoiceMemoView.swift ProjectOne/Features/VoiceMemos/Views/
git mv ProjectOne/AudioRecorder.swift ProjectOne/Features/VoiceMemos/Services/
git mv ProjectOne/AudioPlayer.swift ProjectOne/Features/VoiceMemos/Services/
git mv ProjectOne/Models/RecordingItem.swift ProjectOne/Features/VoiceMemos/Models/
```

*(Further features would be documented here in the same manner)*

## Recommended Merge Strategy

To avoid complex merge conflicts with ongoing work, follow these steps:

1.  **Commit Current Work:** Ensure all your current refactoring work on your development branch (e.g., `claude-refactor`) is complete and committed.
2.  **Create a New Branch:** Create a dedicated branch for this architectural refactoring from your development branch.
    ```bash
    git checkout -b feature/architecture-refactor
    ```
3.  **Execute the Plan:** Run the `mkdir` and `git mv` commands outlined above on this new branch.
4.  **Update Xcode Project:** After moving the files, you will need to open the project in Xcode and update the file locations in the project navigator to reflect the new on-disk structure. Xcode should detect the moves, but it's good to verify.
5.  **Commit Changes:** Commit the refactoring to the `feature/architecture-refactor` branch.
    ```bash
    git add .
    git commit -m "refactor: Reorganize project into feature-based structure"
    ```
6.  **Merge:** You can now merge this branch back into your primary development branch. The merge should be clean as it only contains file moves.

    ```bash
    git checkout claude-refactor
    git merge feature/architecture-refactor
    ```

This isolated approach ensures that the structural changes are applied in a single, clean step, minimizing disruption.
