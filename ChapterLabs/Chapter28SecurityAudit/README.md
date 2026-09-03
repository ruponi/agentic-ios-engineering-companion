# Chapter 28 security audit corpus

`adversarial-corpus.json` is the six-case, reviewable input artifact. The same
typed cases live in `FieldNotesAgentLoop/SecurityAudit.swift`, where the package
tests exercise the actual tool-result, memory, export, audit, and correlation
boundaries used by the companion implementation.

The corpus is intentionally small. It does not establish model robustness,
cover every encoding, test a deployed provider, or replace external red-team
work; it records exactly which product boundary handles each included case.
