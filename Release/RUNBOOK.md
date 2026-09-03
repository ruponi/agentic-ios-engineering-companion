# FieldNotes release runbook

Policy facts below were checked against Apple sources on 2026-08-27. This is a
release plan, not evidence that TestFlight, phased release, or App Review ran.

## Before an archive can leave the team

1. Run `./Scripts/verify` and retain its `.xcresult` plus deterministic
   traces.
2. Run the physical-device matrix: VoiceOver, Dynamic Type, Reduce Motion,
   Arabic right-to-left layout, camera and microphone permissions, lock-state
   file protection, App Group and WidgetKit timeline behavior, Low Power Mode,
   thermal pressure, and live on-device inference.
3. Exercise every deployed provider/model and the hosted backend; retain consent
   revocation, idempotency, cancellation, refusal, token, cost, and retention
   evidence.
4. Archive with distribution signing, inspect the app and widget entitlements,
   generate Xcode's privacy report, reconcile it with App Store Connect privacy
   answers, and determine the export-compliance declaration. Apple documents
   privacy manifests as target resources aggregated into an archive privacy
   report, and separately documents encryption export compliance.
5. Complete the current App Store Connect age-rating questionnaire. Apple says
   an age rating is required and an Unrated app cannot be published; the result
   depends on the submitted answers and region.

Sources checked 2026-08-27: Apple, [Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk); Apple, [Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations); Apple, [Set an app age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/).

## Beta and rollout

- Internal TestFlight group: release owner, privacy reviewer, accessibility
  reviewer, and support lead. Apple currently permits up to 100 internal testers.
- External TestFlight group: risk-selected device and locale matrix. Apple
  currently permits up to 10,000 external testers, and the first external build
  may require beta review. Builds can be tested for up to 90 days.
- Hold promotion if the deterministic route fails, a revoked grant transmits,
  an approval identity mismatches, data appears in content-free logs, migration
  blocks access without an explicit recovery screen, or evaluation gates fail.
- For an update, use Apple's 7-day phased release: 1%, 2%, 5%, 10%, 20%, 50%,
  then 100% of eligible automatic updates. Manual downloads remain possible.
  Apple currently allows a phased release to be paused for up to 30 days total.

Sources checked 2026-08-27: Apple, [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview); Apple, [Release a version update in phases](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases).

## Incident actions

| Signal | Immediate action | Evidence to retain | Resume gate |
|---|---|---|---|
| Cloud error or latency | Disable the cloud route | Correlation UUID, route, timing, provider status | Deterministic brief passes and provider probe is healthy |
| Invalid citation or unsafe proposal | Disable model route | Dataset case, prompt/model/OS versions, no note text | Ten-case safety tier passes |
| Consent after revocation | Stop rollout and cloud traffic | Consent lifecycle and cancellation trace | Revocation regression and deployed probe pass |
| Migration launch block | Pause release | Symbolicated report and seeded store copy | Same store opens in repaired build |
| Content in logs | Stop collection and rotate access | Redacted sample and affected build IDs | Privacy review confirms content-free projection |

App Review outcomes and real-user behavior must be validated by submitting the
inspected archive, retaining the review decision, and comparing beta and
production evidence with these gates.
