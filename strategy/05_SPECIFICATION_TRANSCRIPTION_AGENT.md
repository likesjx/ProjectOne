# Specification: The Transcription Agent

This document specifies the design and function of the `TranscriptionAgent`, which serves as the primary entry point for all audio-to-text operations in the system.

## 1. High-Level Goal

To be the single, authoritative service for converting any audio source into a finalized text transcription. This agent's sole responsibility is the act of transcription. It is intentionally unaware of the meaning of the text or its subsequent use.

## 2. Agent Inputs & Outputs

*   **Primary Input:**
    *   `audio_source_path: String`: The absolute file path to the audio recording.
    *   `user_id: UUID`: The ID of the user, used to determine subscription status and select the appropriate engine.
    *   `source_id: UUID`: A unique identifier for the source of the transcription (e.g., a `RecordingItem` ID) to be passed through for linkage.

*   **Primary Output (on success):**
    *   `transcript: String`: The final, high-quality text transcription.
    *   `source_id: UUID`: The `source_id` that was passed in, returned for use by the next agent.

*   **Primary Output (on failure):**
    *   `error: TranscriptionError`: A structured error object (e.g., `audio_unintelligible`, `engine_failed`, `file_not_found`).

## 3. Core Workflow

The agent follows a strict, linear process:

1.  **Receive Request:** The agent is invoked with the path to an audio file and associated metadata.

2.  **Select Engine:** This is the agent's core business logic. It uses the `SpeechEngineFactory` to acquire the correct transcription engine based on the user's subscription status.
    *   **Pro User:** The factory provides an instance of the proprietary, fine-tuned `MLXSpeechTranscriber`.
    *   **Free User:** The factory provides an instance of the standard `AppleSpeechTranscriber`.

3.  **Execute Transcription:** The agent calls the `.transcribe()` method on the selected engine instance, awaiting the asynchronous result.

4.  **Handle Errors:** If the engine fails, the agent catches the specific error, logs it, and returns a structured `TranscriptionError` to the caller. It does not crash.

5.  **Dispatch to Memory Agent:** Upon successful transcription, the agent immediately invokes the `MemoryAgent`, passing its output (`transcript`, `source_id`) as the `MemoryAgent`'s input. This creates a clean handoff in the agentic chain.

## 4. Strategic Importance

This agent is a cornerstone of our application architecture for several reasons:

-   **Decoupling:** It completely abstracts the UI and other parts of the system from the complexities of the transcription process. The UI just needs to know how to call this one agent.
-   **Single Responsibility:** It adheres strictly to the Single Responsibility Principle, making the codebase cleaner, more modular, and easier to test.
-   **Standardized Entry Point:** All audio-related features (voice notes, file imports, live transcription) will use this agent, ensuring consistency and reducing code duplication.
-   **Flexibility & Scalability:** New transcription engines (e.g., a future cloud-based option) can be added or modified solely within this agent and the `SpeechEngineFactory`, requiring no changes to the rest of the application.
