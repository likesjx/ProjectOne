# Specification: Text Input and Share Extension

This document specifies the architecture for capturing text-based notes, both from within the application and from external applications via a system Share Extension.

## 1. Core Principle: A Unified Entry Point for Text

To ensure architectural consistency, all text-based inputs will be processed through a single, dedicated agent. This creates a parallel workflow to our `TranscriptionAgent` and maintains a clean, decoupled system where the `MemoryAgent` is the central processing hub for all content, regardless of its source.

## 2. The `TextIngestionAgent`

We will create a new agent, the `TextIngestionAgent`, to serve as this unified entry point.

-   **High-Level Goal:** To receive text from any source, perform light pre-processing, and dispatch it to the `MemoryAgent` with rich contextual metadata.
-   **Workflow:**
    1.  **Receive Input:** The agent is invoked with `text_content` (plain text or Markdown) and a `source_metadata` dictionary.
    2.  **Pre-process (Optional):** The agent can be extended to perform source-specific cleaning. For example, if given a URL, it could fetch the page content to extract the core text, removing boilerplate HTML.
    3.  **Dispatch:** The agent's primary role is to immediately call the `MemoryAgent`, passing the cleaned text and the complete `source_metadata` object.

## 3. Feature Components

### A. In-App Note Editor

-   **UI:** A dedicated view within the app for creating and editing notes.
-   **Format:** The editor will support **Markdown** as the primary input format. This provides structure (headings, lists, links) that is highly valuable for LLM processing.
-   **Workflow:** When the user saves a note, the UI calls the `TextIngestionAgent`, providing the Markdown content and the standard contextual metadata (timestamp, location, etc.).

### B. System Share Extension

-   **Component:** An App Extension that registers ProjectOne as a share target for text and URLs across the operating system.
-   **UI:** When activated, the extension will present a simple UI displaying the shared content (e.g., selected text from a webpage) and allow the user to add a comment before saving.
-   **Workflow:** Upon saving, the Share Extension calls the `TextIngestionAgent`.

## 4. The Power of Contextual Metadata

The `TextIngestionAgent` is responsible for packaging context that is specific to text-based sources. This metadata is critical for creating a rich, interconnected knowledge graph.

-   **From In-App Editor:** `metadata = {"timestamp": Date(), "location_name": "..."}`
-   **From Safari Share:** `metadata = {"source_app": "Safari", "source_url": "https://...", "page_title": "..."}`
-   **From Mail Share:** `metadata = {"source_app": "Mail", "subject": "...", "sender": "..."}`

## 5. `MemoryAgent` Integration

The `MemoryAgent` is already designed to handle a generic `metadata` object. It will seamlessly incorporate this new, rich context into its prompts to the `gemma3n` model. This allows the LLM to automatically link memories to their source URLs, email subjects, and more, dramatically increasing the value and connectivity of the user's knowledge graph.

This architecture ensures that whether a piece of information originates from the user's voice, their own writing, or something they've read, it is processed with the same intelligence and integrated into a single, unified knowledge base.
