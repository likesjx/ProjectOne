# ADR 002: Agentic Framework and Hybrid AI Strategy

**Status**: Proposed
**Date**: 2025-07-10

## Context

To evolve ProjectOne from a passive knowledge management system into a proactive, intelligent personal agent, the architecture must be expanded. The system needs to integrate with new data sources (e.g., HealthKit), perform more complex reasoning, and access both personal and general-purpose knowledge. This requires a formal agentic framework and a clear strategy for leveraging both on-device and remote AI models.

## Decision

We will adopt a formal **Perception-Reasoning-Action** agent framework. The core of this framework will be a **Hybrid AI Strategy**, utilizing the on-device `Gemma3nCore` as an intelligent router that directs tasks to the most appropriate tool, which may be internal (on-device) or external (remote API).

### 1. Agentic Framework

*   **Perception Layer**: The agent will ingest data from multiple sources:
    *   Voice transcripts (from the fine-tuned Whisper STT model).
    *   HealthKit data (with explicit user permission).
    *   The existing Knowledge Graph (the agent's memory).

*   **Reasoning Layer (`Gemma3nCore`)**: The on-device Gemma model will act as the central **reasoning and routing engine**. Its primary responsibilities are:
    *   **Intent Recognition**: Analyzing user requests to understand the goal.
    *   **Data Fusion**: Correlating data from different sources (e.g., linking a stressful event in a transcript to poor sleep data from HealthKit).
    *   **Tool Selection**: Generating a structured plan (e.g., in JSON) that specifies which tool(s) to use to fulfill the request.

*   **Action Layer (Toolbox)**: A collection of functions implemented in Swift that the agent can invoke. The toolbox will include:
    *   `updateKnowledgeGraph(data)`: For managing internal memory.
    *   `queryKnowledgeGraph(query)`: For retrieving internal memories.
    *   `generateHealthReport()`: For creating summaries from HealthKit and graph data.
    *   `postUserNotification(text, actions)`: For proactive suggestions.
    *   **`externalQASearch(query)`**: A dedicated tool to call a remote, cloud-based LLM for general knowledge questions.

### 2. Hybrid AI Strategy

The agent will seamlessly switch between two types of AI models based on the task's requirements:

*   **On-Device Expert (`Gemma3nCore`)**: 
    *   **Scope**: All personal data, including transcripts, HealthKit info, and the knowledge graph.
    *   **Function**: Handles all queries related to the user's personal life. Acts as the primary router for all incoming requests.
    *   **Characteristics**: Private, fast, offline-capable.

*   **Remote Expert (`externalQASearch` tool)**:
    *   **Scope**: General-purpose knowledge, creative tasks, complex reasoning beyond the on-device model's capabilities.
    *   **Function**: Answers questions that are not about the user's personal data.
    *   **Characteristics**: Extremely powerful, requires internet, involves cost, has privacy implications.

### 3. Privacy and Transparency

*   **The Golden Rule**: The system will be designed to **never** send personal, private data from the knowledge graph or HealthKit to a remote LLM API. The `Gemma3nCore` router is responsible for enforcing this boundary.
*   **User Transparency**: The UI will provide a clear, subtle indicator when a query is being answered by the remote expert, ensuring the user is aware that a request is being sent over the internet.

## Consequences

### Benefits
*   **Massively Expanded Capability**: The agent can answer a near-infinite range of questions, combining personal context with world knowledge.
*   **Proactive Assistance**: The framework enables the agent to make intelligent connections and offer helpful suggestions (e.g., health and wellness tips based on logged data).
*   **Privacy-Preserving by Design**: Personal data remains on-device by default, providing the benefits of a personal AI without sacrificing privacy.
*   **Scalability**: New capabilities can be added simply by creating new "tools" for the agent to use.

### Trade-offs
*   **Complexity**: This is a more complex architecture than a simple text-processor pipeline.
*   **Privacy Risk Management**: Strict engineering discipline is required to maintain the boundary between on-device and remote data.
*   **Cost & Dependency**: The remote expert tool introduces API costs and a dependency on an internet connection and third-party services.
