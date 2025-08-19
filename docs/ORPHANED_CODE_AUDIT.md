# Orphaned Code Audit

Date: 2025-08-19  
Branch: `feature/gemini-arch-refactor`

This document records the current (static) analysis of potentially orphaned / legacy / unused code so future cleanup work can proceed methodically and safely.

## Purpose
Identify code that is (a) not instantiated, (b) only referenced by other unused subsystems, or (c) only present in documentation, tests, or ad‑hoc harnesses—so we can: reduce cognitive load, shrink build times, and clarify the active architecture.

## Definitions
| Term | Meaning |
|------|---------|
| High‑confidence orphan | No construction / usage outside its own file (or only by other orphaned symbols). Safe to archive/remove after quick confirmation. |
| Medium‑confidence orphan | Only referenced by a legacy/experimental cluster or tests; may have pending planned integration. Confirm before removal. |
| Low‑confidence / contextual | Only in tests, previews, or docs; may still be valuable for examples or manual QA. |

Assumptions: No dynamic reflection / name-based loading for these symbols; SwiftUI navigation does not implicitly instantiate them unless a path reference exists (not detected in simple grep). If reflection or `@_dynamicReplacement` patterns are added later, re-run a deeper index store analysis.

## Active Core (Baseline – DO NOT REMOVE)
Representative symbols confirmed to be part of the currently used runtime paths:
- `RealTimeMemoryService`
- `MemoryAgentRAGEngine`
- `PrivacyAnalyzer`
- Current Memory UI components (e.g., creation/context views) that inject or observe the above services

## High-Confidence Orphans
These appear unused beyond their own definitions and/or a closed orphan cluster:
- Services / Pipelines:
  - `EntityLinkingService`
  - `EmbeddingMigrationService`
  - `ThoughtExtractionService`
  - `EmbeddingGenerationService` (referenced only as optional / commented injection)
- Cognitive Control Loop cluster (no instantiation sites):
  - `CognitiveControlLoop`
  - `CognitiveReasoningEngine`
  - `MemoryProbeEngine`
  - `MemoryFusionEngine`
  - `MemoryConsolidationEngine`
- Legacy Memory Agent subsystem:
  - `MemoryAgentService`
  - `MemoryAgentOrchestrator`
  - `MemoryAgentIntegration`
- Misc UI / Demo:
  - `AgentSystem` view (demo wrapper)
- Root-level ad-hoc scripts / harnesses outside `Tests/` (consider archiving):
  - `batch_processing_example.swift`
  - `test_gemma3n.swift`
  - `real_gemma3n_test.swift`
  - `simple_transcription_test.swift`
  - `simple_test.swift`
  - `Gemma3nVLMTest.swift`
  - `integrated_test.swift`
  - `ThoughtPipelineTest.swift`

## Medium-Confidence Orphans
Likely unused because their hosting subsystem is not active, but double-check before removal:
- Legacy agent objects:
  - `MemoryAgent`
  - `AudioMemoryAgent`
  - `TextIngestionAgent`
- Prompt templating & resolution:
  - `MemoryPromptResolver`
  - `MemoryTemplateNames`
- Analytics / Dashboards:
  - `MemoryAnalyticsService` (if dashboard view not reachable in user navigation)
  - Cognitive Memory Dashboard (`CognitiveMemoryDashboard`, `CognitiveMemoryDashboardViewModel`)
- Knowledge Graph / Experimental UI cluster (entity graph views) – verify if any navigation path exists.

## Low-Confidence / Contextual (Retain Unless Purging Examples)
- Root-level *test-like* harness files (manual QA convenience)
- Example / specification code blocks in `docs/`
- `SwiftWhisperKitMLX/` (independent package – assess separately)
- Utility services that may be indirectly resolved (API key, model download) – not yet classified as orphaned.

## Recommended Cleanup Strategy
1. **Archive Phase (Safe Move)**  
   Create `ProjectOne/Legacy/` and move all High‑confidence orphan groups there; remove them from the main target (uncheck target membership in Xcode / adjust `Package.swift` if modular later). Commit.
2. **Build & Test**  
   Run full test suite and manual smoke of core memory flows.
3. **Prune Phase**  
   After 1–2 weeks with no regressions, delete archived files (history preserved in git).
4. **Medium Review**  
   For each Medium orphan cluster, verify with product/architecture goals: keep (actively plan integration) or archive & prune.
5. **Documentation Update**  
   Add `LEGACY_MEMORY_AGENT.md` summarizing why the old Memory Agent architecture was superseded.
6. **Guard Rails**  
   Add a CI script to flag newly added symbols with zero external references after N days.

## Quick Reference Script (Static Reference Count)
Zsh script to list symbols (classes/structs) and count external references:
```bash
#!/usr/bin/env zsh
root="ProjectOne/ProjectOne"
print "Symbol,File,ExternalRefs"
# Extract unique class/struct names
grep -RhoE '^(public |final |open )?(actor|class|struct) [A-Za-z_][A-Za-z0-9_]+' $root | awk '{print $NF}' | sort -u | while read sym; do
  # Find defining file (first match)
  defFile=$(grep -RIl "(class|struct|actor) $sym\b" $root | head -1)
  # Count occurrences outside definition file
  refs=$(grep -R "\b${sym}\b" $root | grep -v "$defFile" | wc -l | tr -d ' ')
  print "$sym,$defFile,$refs"
done | sort
```
Usage:
```bash
chmod +x scripts/orphan_scan.sh
./scripts/orphan_scan.sh > orphan_report.csv
```
Then manually whitelist known dynamic / protocol types.

## Incremental Removal Checklist
- [ ] Move high-confidence orphan sources to `Legacy/`
- [ ] Remove their references from build settings / PBXProj
- [ ] Run tests (unit + integration)
- [ ] Manual smoke: launch app, core memory creation, retrieval, privacy analysis
- [ ] Delete archived files after probation
- [ ] Add CI orphan detection script
- [ ] Create `LEGACY_MEMORY_AGENT.md`
- [ ] Decide fate of medium-confidence clusters

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Hidden dynamic navigation triggers a view | Launch app & traverse all menus after archiving. |
| Tests rely on now-archived helpers | Run full suite immediately after move; restore selectively. |
| Future roadmap expects cognitive loop components | Document rationale + restore from history if revived. |

## Future Enhancements
- Integrate `indexstore-db` for precise symbol usage (less false positives).
- Add GitHub Action to fail PR if new zero-reference symbol persists > 14 days.
- Annotate intentionally isolated experimental modules with `// @isolated-experimental` marker to avoid false positive.

## Summary
The codebase contains a legacy memory agent + cognitive loop subsystem and multiple embedding/analytics services not wired into the current real-time memory pathway. Archiving them will streamline ongoing refactors while keeping a clean history for future retrieval.

---
Generated via static inspection; re-run after major architectural changes.
