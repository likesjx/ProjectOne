
# Specification: Memory Hierarchy and Routing

**Status**: Finalized
**Date**: 2025-07-16

## 1. Objective

To define the architecture and logic for the AI's memory system. This document specifies the roles of the different memory banks and the AI-driven process for routing information between them. This will be the primary responsibility of the `MemoryAgent`.

## 2. Memory Hierarchy Definitions

The system will utilize a four-tiered memory hierarchy:

-   **Working Memory (WM):** The AI's "RAM." A small, fast, and volatile store for the immediate context of the *current task*. It is cleared frequently.
    -   **Purpose**: Holding temporary data for multi-step operations.
    -   **Lifespan**: Seconds to minutes; tied to a single task.

-   **Short-Term Memory (STM):** The AI's "Scratchpad." Maintains the context of the current user session.
    -   **Purpose**: Remembering the last few turns of a conversation to maintain coherent interaction.
    -   **Lifespan**: The duration of an active session.

-   **Long-Term Memory (LTM):** The AI's permanent "Knowledge Base." Stores consolidated facts, user preferences, and important entities.
    -   **Purpose**: Building a persistent, long-term understanding of the user and their world.
    -   **Lifespan**: Permanent, until explicitly updated or deleted.

-   **Episodic Memory (EM):** The AI's "Diary." A chronological log of events and experiences.
    -   **Purpose**: Creating a timeline of user interactions and linking events together.
    -   **Lifespan**: Permanent.

## 3. Information Routing Process

The `MemoryAgent` is responsible for routing all new information. The process is as follows:

1.  **Information Received**: A new piece of information (e.g., a user transcription) is received by the `AgentOrchestrator`.
2.  **Task Delegation**: The orchestrator routes the information to the `MemoryAgent` as a new task.
3.  **Context Assembly**: The `MemoryAgent` assembles a data block containing the new information, its source, timestamp, and any relevant context from the `SystemContext` (e.g., related entities from the Knowledge Graph).
4.  **Prompt Execution**: The `MemoryAgent` sends the assembled data block to the core AI model (Gemma3n) using the "Master Prompt for the Memory Management Unit" (defined below).
5.  **Response Parsing**: The `MemoryAgent` receives the structured JSON response from the AI.
6.  **Action Execution**: The agent parses the `memory_actions` array in the JSON and executes each action, using the `SystemContext` to interact with the appropriate SwiftData stores for each memory bank.

## 4. Master Prompt for the Memory Management Unit

This prompt is the core of the routing logic. It instructs the AI to act as the MMU and return a structured JSON response.

```
You are the Memory Management Unit (MMU) of a personal AI assistant. Your primary function is to analyze incoming pieces of information and decide how they should be stored across a complex, multi-layered memory system to ensure optimal context, recall, and learning.

You must process the provided input and generate a single, valid JSON object that specifies the actions to be taken.

### Memory System Architecture:

1.  **Working Memory (WM):** A small, volatile scratchpad for the immediate task at hand. Data here is temporary and has a very short lifespan. Use it for things that need to be remembered for only the next few seconds or minutes (e.g., details for an immediate, multi-step action).
2.  **Short-Term Memory (STM):** A session-based buffer that maintains conversational context. It helps track the flow of the current interaction. Data here persists for the duration of an active session and is cleared afterward. Use it to remember the last few turns of a conversation.
3.  **Long-Term Memory (LTM):** A permanent, structured knowledge base. This is for core facts, user preferences, important relationships, and verified information that should be remembered indefinitely. Writing to LTM is a significant action. Be selective.
4.  **Episodic Memory (EM):** A chronological log of events and experiences. It creates a timeline of interactions. Use it to record that something *happened* at a specific time, linking to the entities and data involved.

### Your Task:

Analyze the following data block. Based on its content, salience, and the provided context, generate a JSON object specifying which memory banks to write to.

**Input Data Block:**
- **Timestamp:** `[Timestamp of the event]`
- **Input Source:** `[Source of the data, e.g., 'user_voice_transcription', 'user_text_note', 'system_event']`
- **Input Text:** `[The raw text content of the information]`
- **Related Entities:** `[List of known entities mentioned, e.g., 'Sarah Johnson', 'Project Titan']`
- **Current Working Memory Summary:** `[A brief summary of what's in the Working Memory right now]`

### Response Format:

You MUST respond with a single, valid JSON object. Do not include any other text or explanations outside of the JSON structure.

**JSON Schema:**
{
  "analysis": "A brief, one-sentence summary of your reasoning for the routing decisions.",
  "salience_score": "A float between 0.0 and 1.0 indicating the overall importance of this information.",
  "memory_actions": [
    {
      "target_memory_bank": "WORKING | STM | LTM | EPISODIC",
      "action_type": "STORE | UPDATE | DELETE",
      "content": "The specific, distilled piece of information to be stored. This should be concise.",
      "entry_type": "For LTM only. Can be 'FACT', 'PREFERENCE', 'PROCEDURE', 'ENTITY_UPDATE'.",
      "confidence_score": "For LTM only. A float between 0.0 and 1.0.",
      "reasoning": "A brief explanation for why this specific action was chosen."
    }
  ]
}
```

## 5. Implementation Notes

-   The `MemoryAgent` will be the sole component responsible for executing this prompt.
-   The `SystemContext` must provide the `MemoryAgent` with the necessary methods to query existing memory and write to the SwiftData stores that back each memory bank.
-   Robust error handling must be implemented for parsing the AI's JSON response.
