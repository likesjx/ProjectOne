Cognitive Architecture & Application Design

1. Goals
	•	Optimize cognitive performance
	•	Strengthen working memory (compensate for ADHD).
	•	Enhance fluid intelligence (counteract age-related decline).
	•	Align productivity with dopamine peaks (circadian + pharmacological windows).
	•	Bridge capture + resurfacing
	•	You already capture quickly via Drafts / Obsidian.
	•	Missing link: “bubble-up” functionality → making sure ideas resurface at the right time/state.
	•	App foundation
	•	Local-first with mlx-swift and Apple Foundation Models.
	•	Retrieval-Augmented Generation (RAG) layered with privacy routing.
	•	UI designed for ADHD-friendly interaction (hierarchy, timelines, coach cards).

⸻

2. Biological & Cognitive Stack

Supplements / Lifestyle
	•	Magnesium L-Threonate (AM) → cognition.
	•	Magnesium Breakthrough (PM) → relaxation/sleep.
	•	Omega-3 (AM/PM) → neuronal health + working memory.
	•	Creatine Monohydrate (5g+ split AM/PM) → brain energy + recovery.
	•	B-complex (AM) → neurotransmitter synthesis.
	•	Vitamin D3 (PM) → immune + mood.
	•	Tongkat Ali / Fadogia → hormonal balance, energy.
	•	Moringa / Ubiquinol → antioxidant & mitochondrial support.
	•	AG1 (alternate days) → micronutrients.
	•	Adderall (15mg AM / 10mg noon) → dopaminergic boost.
	•	CBD Gummies + Trazodone (PM) → sleep onset.
	•	Bioptimizers Sleep Breakthrough → circadian alignment.

Lifestyle Anchors
	•	Exercise (Fitbod + elliptical, evening).
	•	Piano practice (pre-workout, evening creative arc).
	•	Duolingo (short daily sessions AM/PM).
	•	Sleep target ~10:30–11:00pm, wake 6:10am.

⸻

3. Dopamine Wave Model
	•	Morning Peak (7:30–11:30am) → deep focus, working memory tasks.
	•	Midday Dip (12–2pm) → light tasks, meetings.
	•	Afternoon Boost (3–6pm) → structured work, problem-solving.
	•	Evening Creative Arc (6:30–9pm) → piano, writing, idea exploration.
	•	Wind-down (9:30pm+) → reflection, light review, sleep prep.

Implication: bubble-up items should resurface in sync with these windows.

⸻

4. Application Architecture

Existing Vertical Stack (from repo)
	•	UI Layer: Memory Dashboard, Test Runner.
	•	Privacy Layer: Analyzer, Context Filtering.
	•	RAG Engine: Retrieval, Ranking, Scoring.
	•	Agentic Layer: Orchestrator, Autonomous Ops.
	•	AI Layer: Apple Foundation Models Provider.
	•	Data Layer: SwiftData Models (STM, LTM, Episodic, Entities, Relationships).

Overlay: Horizontal Enhancements
	•	RAG Modes: LeanRAG, GraphRAG, ComoRAG, RexRAG.
	•	Mode Selector: Chooses strategy based on query, privacy, context.
	•	Composer & Validator: Ensures outputs are grounded + citation-complete.
	•	Bubble-Up Engine: Resurfaces notes/ideas in context of dopamine windows.
	•	IdeaNodes: Hierarchical projection of the knowledge graph for navigation.

⸻

5. Bubble-Up Engine

struct BubbleUpItem: Identifiable {
    let id: UUID
    let content: String
    let tags: [String]
    let createdAt: Date
    let dueWindow: DateInterval
    let contextMatch: (OrchestratorContext) -> Bool
}

	•	Items bubble up based on time (dueWindow) or state (contextMatch).
	•	Scheduled by Orchestrator using STM/LTM importance + privacy constraints.
	•	Surfaces as Coach Cards or Timeline suggestions.

⸻

6. Hierarchical Navigation (IdeaNodes)

IdeaNode Model

struct IdeaNode: Identifiable, Codable {
    let id: UUID
    let title: String
    let parentID: UUID?
    var children: [UUID]
    var relatedMemoryIDs: [UUID]
    var tags: [String]
    var createdAt: Date
}

Relationship to Graph
	•	Graph = entity relationships (network, emergent, bottom-up).
	•	IdeaNodes = hierarchical views (outline, top-down).
	•	IdeaNodes are projections of the Graph → designed for human drill-down + bubble-up.

⸻

7. Local Model Integration (mlx-swift + Gemma3n)

Current Status
	•	Gemma3n unsupported in older mlx-swift.
	•	mlx-libraries 2.25.5 + mlx-swift 0.25.6 add support for Gemma3n.

Use Cases
	•	On-device first-pass:
	•	Summarization of notes.
	•	Entity/Idea extraction.
	•	Privacy-preserving query handling.
	•	Transcription pipeline:
	•	Whisper (ASR) for raw audio → text.
	•	Gemma3n for semantic understanding:
	•	Topic classification.
	•	Entity/Idea extraction.
	•	Linking transcript chunks into IdeaNodes + Graph.

⸻

8. UI Guidelines

Surfaces
	•	Coach Cards: actionable bubble-up nudges.
	•	Dopamine Wave Timeline: events + peaks + resurfaced ideas.
	•	Hierarchy View: drill-down into IdeaNodes.
	•	macOS: OutlineGroup/tree view.
	•	iOS: Bubble tree (mind-map style).
	•	Graph Lens: raw entity relationships.
	•	Rex View: extraction + citations side-by-side.

Interaction
	•	Breadcrumbs: always show where you are in hierarchy.
	•	Swipe → promote to IdeaNode.
	•	Tap → drill into child ideas.
	•	Context-aware surfacing: only show piano branch during piano practice.

⸻

9. Data Flow Diagram

Voice / Drafts / Obsidian Capture
        ↓
  Local ASR (Whisper) → Transcript
        ↓
   Gemma3n (mlx-swift, on-device)
        ↓
 Entity Extraction → Graph Update
        ↓
 IdeaNode Creation / Linking
        ↓
 Orchestrator Schedules Bubble-Up
        ↓
 Bubble-Up Engine checks Dopamine Context
        ↓
 UI surfaces (Coach Cards, Timeline, Hierarchy)


⸻

10. Why This Matters
	•	Working Memory Support: bubble-up ensures you don’t lose threads.
	•	Fluid Intelligence: graph + hierarchy allow you to synthesize across domains.
	•	ADHD Adaptation: externalizes memory load into UI structures.
	•	Longevity: supplements, sleep, and local-first AI combine for sustainable cognitive enhancement.