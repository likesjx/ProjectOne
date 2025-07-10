# ADR 001: Core Technology Strategy

**Status**: Proposed
**Date**: 2025-07-10

## Context

As ProjectOne moves into its next phase of development, key architectural decisions are required to align with the cutting edge of Apple's ecosystem while ensuring the system remains powerful, customizable, and maintainable. This document outlines the chosen technologies for the user interface, the core AI reasoning engine, and the speech processing pipeline.

The primary goals are:
1.  To adopt a modern, native "Glass UI" aesthetic.
2.  To select an AI/ML framework that offers both high performance and deep customization.
3.  To define a clear strategy for Speech-to-Text (STT) and Text-to-Speech (TTS).
4.  To ensure the architecture leverages the latest GPU acceleration capabilities (Metal 4).

## Decision

We have decided on a hybrid approach that combines the strengths of Apple's native frameworks for UI and standard services with the power of a flexible, open-source AI framework for the core reasoning engine.

1.  **User Interface (UI): "Glass UI" with SwiftUI**
    *   We will adopt the translucent, layered "Glass UI" aesthetic prominent in visionOS and macOS Sequoia.
    *   **Implementation**: This will be achieved using standard SwiftUI modifiers like `.background(.regularMaterial)` and the new `.glassBackgroundEffect()` where appropriate.

2.  **AI Reasoning Engine: MLX + Gemma-family LLM**
    *   The core reasoning engine (`Gemma3nCore`) will be powered by a Gemma-family Large Language Model.
    *   **Implementation**: The model will be run on-device using Apple's **MLX framework**. This provides direct access to Metal 4 optimizations and gives us full control over model selection, prompt engineering, and future fine-tuning. This approach is favored over Apple's Foundation Models API to allow for greater customization and power.

3.  **Speech-to-Text (STT): Phased Approach with On-Device Fine-Tuning**
    *   **Phase 1 (Initial Implementation)**: Integrate Apple's native `Speech` framework (`SFSpeechRecognizer`) to quickly enable a baseline transcription feature.
    *   **Phase 2 (Core Feature)**: Replace the native framework with a pre-trained **OpenAI Whisper model**, running on-device via MLX. This provides state-of-the-art accuracy out-of-the-box. The model file will be bundled with the app or downloaded on first launch.
    *   **Phase 3 (Personalization via Fine-Tuning)**: To create a truly personal transcription experience, we will implement an on-device fine-tuning workflow.
        *   **Data Collection**: A "Voice Training" feature will be created. It will prompt the user to record short, specific sentences to build a small, high-quality dataset of `(audio, text)` pairs.
        *   **Fine-Tuning Process**: Using MLX, a training process will be run entirely on the user's device. This process will load the pre-trained Whisper model and use the personal dataset to adjust the model's parameters.
        *   **Result**: The output will be a new, personalized model file (e.g., `whisper-small-finetuned-user.mlmodel`) that is an expert in the user's voice, vocabulary, and accent. This model will then be used for all subsequent transcriptions.

4.  **Text-to-Speech (TTS): Native Framework for Agent Output**
    *   All functionality for making the device speak text aloud (Text-to-Speech) will be implemented using Apple's standard **`AVSpeechSynthesizer`** from the `AVFoundation` framework.
    *   **Clarification**: This framework is the "mouth" of the system (Text -> Speech) and is distinct from the "ears" (`SFSpeechRecognizer`, which handles Speech -> Text).
    *   **Reasoning**: Using this standard API is the correct, forward-compatible way to access all of Apple's latest TTS engine improvements, including new beta features like Personal Voice, without requiring future code changes.

5.  **GPU Acceleration: Metal 4 via MLX**
    *   We will not write any direct Metal code. By using **MLX** as our AI framework, we inherently leverage the performance and efficiency of Metal 4 for all model-related computations.

## Consequences

### Benefits
*   **Control & Power**: The MLX + Gemma stack gives us maximum control over the core AI, allowing for a deeply integrated and specialized knowledge system.
*   **Future-Proof UI**: Adopting the Glass UI ensures the application feels modern and native on the latest Apple operating systems.
*   **State-of-the-Art Transcription**: The phased approach to STT allows for rapid initial development while paving the way for a world-class, personalizable transcription engine.
*   **Maintainability**: By using native frameworks for UI (SwiftUI) and TTS (`AVSpeechSynthesizer`), we reduce dependencies and ensure long-term compatibility.
*   **Performance**: The use of MLX ensures all AI workloads are highly optimized for Apple Silicon GPUs.

### Trade-offs
*   **Increased Complexity**: The MLX stack is more complex to implement and maintain than using Apple's black-box Foundation Models API. This is a deliberate trade-off for the power and control it provides.
*   **Phased Rollout**: The full vision for the STT engine requires a multi-phase implementation, delaying the availability of the final, fine-tuned model.

---
