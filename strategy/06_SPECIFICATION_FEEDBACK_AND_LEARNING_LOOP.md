# Specification: Feedback and Learning Loop

This document details the architecture for a closed-loop feedback system that enables the `MemoryAgent` to learn from user interactions, leading to both short-term personalization and long-term model improvement.

## 1. Core Principle: Learning from Confirmation

Our system will not only propose actions but will actively learn from the user's acceptance or rejection of those proposals. This transforms the agent from a static tool into a dynamic system that adapts to the user.

## 2. System Components

### A. Data Models for Learning

To capture the necessary data, we will introduce two new SwiftData models:

1.  **`AgentActionFeedback`**: Records the outcome of every proposed "next best action."
    *   `original_transcript`: The text that led to the decision.
    *   `original_context`: A JSON blob of the contextual metadata (time, location, etc.).
    *   `proposed_agent`: The name of the agent the LLM suggested (e.g., `TaskCreationAgent`).
    *   `llm_confidence`: The confidence score the LLM provided.
    *   `user_confirmed`: A boolean indicating the user's final choice (`true` for confirm, `false` for cancel).

2.  **`UserActionPreference`**: Stores a user's explicit consent for autonomous actions.
    *   `agent_name`: The agent for which the preference applies.
    *   `autonomous_execution_allowed`: A boolean set to `true` if the user agrees to let this agent run without confirmation.

### B. Refined `MemoryAgent` Workflow

The agent's decision-making process is updated to incorporate learning:

1.  **Query LLM:** The agent gets a proposed action, including a `confidence_score`.
2.  **Check for User Consent:** Before evaluating confidence, the agent first checks the `UserActionPreference` store. If the user has already approved autonomous execution for the proposed agent, the agent executes the action directly and logs the event as `user_confirmed: true`.
3.  **Confidence-Based Routing:** If no user preference exists, the agent uses the `confidence_score` to decide whether to execute the action autonomously (>0.9 confidence) or send a confirmation prompt to the UI.
4.  **Capture Explicit Feedback:** When the UI receives a user decision (`Confirm` or `Cancel`), it calls a dedicated function, `MemoryAgent.log_feedback()`, which creates a new `AgentActionFeedback` record with the full context of the decision and the user's choice.

## 3. The Two Learning Loops

The captured feedback data fuels two distinct improvement pathways:

### A. Short-Term Personalization (On-Device)

-   **Mechanism:** A background process on the user's device analyzes the `AgentActionFeedback` history.
-   **Trigger:** If it detects a pattern (e.g., the user confirms `TaskCreationAgent` suggestions >95% of the time), it will trigger a UI prompt.
-   **Prompt:** "I've noticed you always approve new tasks. Would you like me to create them for you automatically in the future?"
-   **Outcome:** If the user agrees, the system creates a `UserActionPreference` record, making the agent's behavior immediately more efficient and personalized for that user.

### B. Long-Term Model Improvement (Global)

-   **Mechanism:** This is a core part of our MLOps pipeline.
-   **Data Export:** The `DataExportService` is updated to periodically bundle and upload the `AgentActionFeedback` data to our secure backend.
-   **Fine-Tuning:** Our server-side LangGraph agent uses this rich dataset for Reinforcement Learning from Human Feedback (RLHF). The goal is to fine-tune our `gemma3n` model to become more accurate in its `agent_name` selection and `confidence_score` prediction.
-   **Outcome:** A globally improved model is deployed to all users, enhancing the agent's baseline intelligence.

This dual-loop system ensures that the application feels like it's getting smarter for the individual user instantly, while also contributing to a more powerful core model for the entire user base over time.
