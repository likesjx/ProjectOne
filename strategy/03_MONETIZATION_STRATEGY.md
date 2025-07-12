# Monetization Strategy

This document outlines the monetization strategy for ProjectOne. We will employ a Freemium Subscription model designed to provide significant value to free users while offering compelling, premium features to paying subscribers. This model aligns with our privacy-first, high-performance AI architecture.

## 1. The Tiers: Basic vs. Pro

### Tier 1: ProjectOne Basic (Free)

The goal of the free tier is to attract a large user base by providing a genuinely useful tool that showcases the core functionality of the app.

-   **Core Features:**
    -   Audio Recording & Playback
    -   Transcription Service
    -   Knowledge Graph Visualization
-   **Transcription Engine:** Utilizes the standard, built-in **`AppleSpeechTranscriber`**. This engine is high-quality and has no direct operational cost for us.
-   **Usage Limits:** To encourage upgrades, the free tier will have limitations:
    -   **Transcription:** A cap on the number of transcription minutes per month (e.g., 60 minutes).
    -   **Knowledge Graph:** A limit on the number of entities and relationships that can be stored.
    -   **Syncing:** No cloud sync or backup features.

### Tier 2: ProjectOne Pro (Paid Subscription)

The Pro tier is the core revenue driver. It unlocks the full, unconstrained power of our custom-built AI systems. Pricing will be on a monthly or annual subscription basis.

-   **Key Selling Points:**

    1.  **Superior Transcription Quality & Speed:**
        *   **Feature:** Subscribers get exclusive access to our proprietary, fine-tuned speech recognition model (the output of our MLX/LangGraph pipeline). This model will be demonstrably more accurate, especially for specific domains, and will improve over time.
        *   **Implementation:** The `SpeechEngineFactory` will check for an active subscription and provide the appropriate transcription engine.

    2.  **Unlimited Usage:**
        *   **Feature:** All monthly limits on transcription minutes and knowledge graph size are removed.

    3.  **Cloud Sync & Backup:**
        *   **Feature:** Seamlessly sync all data (audio files, knowledge graph entities) across a user's devices (iPhone, iPad, Mac) using iCloud.
        *   **Implementation:** Leverage SwiftData's integration with CloudKit.

    4.  **Advanced AI Reasoning:**
        *   **Feature:** Unlock features powered by the `Gemma3nCore` reasoning engine. This includes advanced queries like summarization, trend analysis, and thematic discovery within a user's knowledge base.

    5.  **Premium Data Export:**
        *   **Feature:** Allow users to export their data in advanced formats compatible with other knowledge management tools (Obsidian, Roam Research, etc.).

## 2. Alternative Monetization

-   **Usage-Based Credits:** We may offer one-time purchases of "Power Packs" (e.g., 200 extra transcription minutes) for users who have high temporary needs but do not wish to subscribe.
-   **B2B Licensing:** A future possibility is to license the technology to teams on a per-seat subscription model, offering centralized administration and shared knowledge bases.

## 3. Strategic Advantage

This Freemium model creates a powerful flywheel effect. Free users get a great app and can contribute to our training data. This data is used to build a better model, which becomes the core value proposition of the Pro subscription. The Pro revenue, in turn, funds the development of even more advanced features.
