# Chapter Labs

Chapter labs are small executable projects that prove one idea without adding
that experimental machinery to the canonical FieldNotes application target.

| Lab | Book topic | Purpose |
|---|---|---|
| `Chapter20AgentLoop` | From a Model Call to an Agent Loop | A provider-neutral bounded agent loop with deterministic traces and invariant tests. It also carries the Chapter 21 through 28 contracts that extend that loop: placement, Foundation Models, the consented cloud adapter, typed tool actions, personal context, multimodal and voice, and the security audit. |
| `Chapter23SecureBackend` | Cloud Intelligence and the Secure Backend | A consent-aware cloud adapter plus a small authenticated, quota-limited, idempotent backend facade. |
| `Chapter28SecurityAudit` | Security, Privacy, and Safety | A six-case reviewable adversarial corpus naming the exact product boundary each hostile input exercises, with its coverage limits stated. |
| `Chapter29Evaluation` | Evaluating Nondeterministic Behavior | A 10-case property-based golden dataset, six deterministic graders, a paired human-review fixture, and a runner that rejects an insufficiently validated model judge. |
| `Chapter30Observability` | Observability, Performance, Cost, and Change | Correlation-safe stitched traces, observed loop budgets, a deterministic responsiveness probe, and the feature flag's OFF route. |
| `Chapter33MultiAgent` | Beyond One Agent | A read-only specialist agent, shared tree budget, unchanged outer-loop invariants, and deterministic traces. |

Each lab owns its verification command and should remain runnable independently.
