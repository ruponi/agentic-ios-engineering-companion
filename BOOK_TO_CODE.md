# Book-to-Code Map

Use this map after reading a chapter to move from the printed idea to running
code. The canonical application is intentionally small enough to read from end
to end.

| Topic in the book | Start here | What to inspect |
|---|---|---|
| App composition | `FieldNotes/App/` | Dependency construction, typed routes, `NavigationStack`, and item-driven sheets. |
| Capturing a note | `FieldNotes/Features/Capture/` | Observable UI state, validation, asynchronous saving, errors, and draft preservation. |
| Lists and details | `FieldNotes/Features/Notes/` | Explicit screen states, stable identity, navigation, empty/error/partial states, and previews. |
| Concurrency boundary | `FieldNotes/Services/InMemoryNoteStore.swift` | An actor-owned store behind small protocols. |
| Network boundary | `FieldNotes/Services/Networking/` | A `Sendable` client protocol, a request that records its own retry safety, transient-only retry with backoff, and NDJSON streaming. |
| Persistence and migration | `FieldNotes/Services/Persistence/` | Frozen `FieldNotesSchemaV1`, additive `FieldNotesSchemaV2`, a lightweight migration plan, and a `@ModelActor` store. |
| Offline search | `FieldNotes/Services/Persistence/NoteSearchIndex.swift` | A rebuildable inverted index: title weighting, prefix matching, every-token-must-match, deterministic ties. |
| Local-first loading | `FieldNotes/Features/Notes/NotesLoader.swift` | Saved notes emitted before the network is consulted; request failure becomes a freshness warning, never an empty list. |
| Migration evidence | `FieldNotes/Tests/FieldNotesMigrationTests.swift` | Seeds a real V1 store, reopens the same file as V2, and asserts identity and user content — not merely that a fresh container opens. |
| Reusable UI states | `FieldNotes/Shared/FieldNotesMessageView.swift` | A shared loading, empty, error, and retry presentation. |
| Unit verification | `FieldNotes/Tests/FieldNotesTests.swift` | Deterministic tests for validation, saving, reloading, and typed lookup. |
| UI and accessibility verification | `FieldNotes/UITests/FieldNotesUITests.swift` | A reader journey plus an automated accessibility audit. |
| Chapter 20 agent loop | `ChapterLabs/Chapter20AgentLoop/` | A bounded, provider-neutral loop with policies, traces, tests, and a replayable verification command. |
| Chapter 21 inference placement | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/ModelPlacement.swift` | Runtime capability routing, distinct availability failures, a deterministic fallback, and a replayable four-route trace. |
| Chapter 21 fallback UI | `FieldNotes/Shared/IntelligenceFallbackView.swift` | Different, accessibility-audited states for an ineligible device, a model that is not ready, and an OS without the framework. |
| Chapter 22 Apple Foundation Models | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/FoundationModelsAgentModel.swift` | An iOS-17-safe availability wall, a concrete `LanguageModelSession` adapter, guided proposal mapping, schema rejection, and prompt-version records. |
| Chapter 23 consented cloud adapter | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/CloudAgentModel.swift` | A purpose-bound consent grant, minimized request, cancellable NDJSON transport, unchanged proposal mapping, and provider/model run records. |
| Chapter 23 secure backend | `ChapterLabs/Chapter23SecureBackend/` | A runnable Node.js facade that authenticates, authorizes, enforces quota, refuses extra fields, replays stable idempotency keys, and records honest failover. |
| Chapter 24 typed tool actions | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/ToolContracts.swift` | Read, reversible-write, and consequential effects; pending, approved, and applied values; and the untrusted tool-result envelope. |
| Chapter 24 suspended writes | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/ActionTools.swift` | Approval-required save/tag tools, idempotent application records, preserved prior versions, real reversion, and an unregistered consequential delete. |
| Chapter 24 approval UI | `FieldNotes/Shared/WriteApprovalView.swift` | The exact typed action, source IDs, effect, and idempotency key rendered without a model-authored summary and exercised by UI accessibility tests. |
| Chapter 25 personal context lab | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/PersonalContext.swift` | Source-linked derived records, consent and retention gates, deterministic lexical retrieval, optional embedding reranking, readable export, expiry, regeneration, and deletion evidence. |
| Chapter 25 durable personal context | `FieldNotes/Services/Persistence/SwiftDataPersonalContextStore.swift` | Consent-gated derivation and reads, expiration, regeneration, export, and deletion of records by source-note UUID. |
| Chapter 25 persistence schema | `FieldNotes/Services/Persistence/FieldNotesSchemaV3.swift` | The additive personal-context model and migration checkpoint; note deletion cascades to derived context in the same model context. |
| Chapter 26 multimodal and voice contracts | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/MultimodalVoice.swift` | On-device extraction into an untrusted envelope, text-only cloud minimization, streamed speech interruption, exact typed-field readback, explicit confirmation, and voice-only capability withdrawal. |
| Chapter 26 voice fallback UI | `FieldNotes/Shared/VoiceInteractionView.swift` | A voice limitation surface with no approval button that transfers the unchanged pending action to exact on-screen review or declines it. |
| Chapter 27 amended approval contract | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/ToolContracts.swift` | An immutable amendment path that mints a new pending identity and idempotency key, preserves the original as evidence, and rejects approval of a superseded proposal. |
| Chapter 27 editable approval UI | `FieldNotes/Shared/WriteApprovalView.swift` | Private SwiftUI draft state, a visible replacement proposal identity, and exact approval of the current amended value. |
| Chapter 27 agent experience states | `FieldNotes/Shared/AgentExperienceView.swift` | On-device or consented-cloud capability expectations, progress, honest uncertainty, admitted-UUID sources, Undo from `AppliedChange`, and human escalation when reversal is unavailable. |
| Chapter 27 interface verification | `FieldNotes/UITests/FieldNotesUITests.swift` | Simulator proof that amendment replaces identity plus automated accessibility audits for editable approval and sourced uncertainty. |
| Chapter 28 adversarial corpus | `ChapterLabs/Chapter28SecurityAudit/adversarial-corpus.json` | Six reviewable probes for hostile note text, derived memory, readable export, and correlation-header leakage, with explicit coverage limits. |
| Chapter 28 security contracts | `ChapterLabs/Chapter20AgentLoop/Sources/FieldNotesAgentLoop/SecurityAudit.swift` | Derived-memory prompt admission, protected explicit-export metadata, and a note-free audit projection assembled from existing change and model-run evidence. |
| Chapter 28 platform security | `FieldNotes/Security/AgentSecurity.swift` | Keychain accessibility, complete file protection, private `os.Logger` correlation, and the durable memory prompt-envelope call site. |
| Chapter 28 backend seam | `ChapterLabs/Chapter23SecureBackend/backend.mjs` | UUID-only correlation identifiers and minimized logs that refuse caller-supplied content before it becomes telemetry. |
| Chapter 29 property dataset | `ChapterLabs/Chapter29Evaluation/Sources/Chapter29Evaluation/Resources/golden-dataset.json` | Ten fixture-backed cases that assert properties rather than blessed answer strings, including the six-case adversarial regression tier. |
| Chapter 29 graders and runner | `ChapterLabs/Chapter29Evaluation/` | Six deterministic graders, a nine-test Swift Testing suite, one honestly filled matrix cell, five paired human labels, and a runner that rejects an insufficiently validated model judge. |
| Chapter 30 device telemetry | `FieldNotes/Services/Telemetry/AgentSignposter.swift` | Content-free `OSSignposter` intervals, reduced `URLSessionTaskMetrics`, and thermal plus Low Power Mode operating inputs. |
| Chapter 30 observability lab | `ChapterLabs/Chapter30Observability/` | Correlation-safe stitched traces, observed loop budgets, first-output timing, the deterministic OFF route, prompt rollback asymmetry, and v1 deprecation evidence. |
| Chapter 30 backend metrics | `ChapterLabs/Chapter23SecureBackend/backend.mjs` | Content-free backend stage duration and request-byte evidence attached to the existing validated correlation UUID. |
| Chapter 31 integrated journey | `FieldNotes/Integration/IntegratedAgentJourney.swift` | The end-to-end capture, search, route selection, approval, and audit path with independent cloud and derived-memory consent resolved as one permission set. |
| Chapter 31 integration evidence | `FieldNotes/Tests/FieldNotesIntegrationTests.swift` | Five app-target tests: durable personal context without a shadow type, a real note body inside the loop's tool-result budget, independent consents, amendment before resume, and the stitched capture-to-audit journey. |
| Chapter 32 fault injection | `FieldNotes/Hardening/ProductionHardening.swift` | Eight injected release faults - backend, consent, model, disk, migration, connectivity, Low Power Mode, and thermal - each mapped to the degraded behavior the product must still show. |
| Chapter 32 hardening evidence | `FieldNotes/Tests/ProductionHardeningTests.swift` | Eleven tests covering the eight faults, the privacy-manifest structure, the settled App Group spelling, and single-bucket coverage of every open verification claim. |
| Chapter 32 persistence failure surface | `FieldNotes/Shared/PersistenceFailureView.swift` | The honest migration-failure screen that refuses to replace unopened notes with an empty store. |
| Chapter 32 privacy and entitlements | `FieldNotes/PrivacyInfo.xcprivacy`, `FieldNotes/FieldNotes.entitlements` | A target-resource manifest declaring no tracking, no collected data types, and no required-reason categories for current code, beside the single settled App Group. |
| Chapter 32 release documents | `Release/` | A code-derived AI and privacy disclosure plus a pre-archive release runbook. |
| Chapter 33 specialist as a tool | `ChapterLabs/Chapter33MultiAgent/Sources/BeyondOneAgent/RoutePlannerAgentTool.swift` | A read-effect specialist registered through the existing `AgentTool` contract, with a 250 ms timeout and a subset guard that stops a child enlarging its own source set. |
| Chapter 33 shared tree budget | `ChapterLabs/Chapter33MultiAgent/Sources/BeyondOneAgent/TreeTurnBudget.swift` | One actor ledger charging parent and child turns against a single finite total with typed depth and exhaustion failures. |
| Chapter 33 platform constraints | `ChapterLabs/Chapter33MultiAgent/Sources/BeyondOneAgent/PlatformConstraints.swift` | Watch, iPad, Mac, and spatial surfaces expressed as consequences for review and approval rather than as new write paths. |
| Chapter 33 multi-agent invariants | `ChapterLabs/Chapter33MultiAgent/` | Nine deterministic tests plus a replayable trace showing unchanged provenance, approval, and turn limits with a specialist registered. |

## Suggested reading path

1. Run `./Scripts/verify` from the repository root.
2. Open `FieldNotes/FieldNotes.xcodeproj` and run the `FieldNotes` scheme.
3. Follow one feature vertically: view → observable model → protocol → actor.
4. Open the matching tests and deliberately change one invariant to see the
   verification fail.
5. Run chapter labs separately when the book asks for a focused experiment.

The current `main` branch should represent the complete, runnable reference
application. When chapter-specific snapshots are published, the book can link
to immutable Git tags such as `chapter-07`, `chapter-17`, and `chapter-20`.
