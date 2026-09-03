# FieldNotes AI and privacy disclosure example

Checked against the code paths and Apple sources on 2026-08-27.

## What the product tells a person

FieldNotes searches notes on the device. When on-device intelligence is available,
the packing brief can be generated there. If it is unavailable, FieldNotes uses a
deterministic brief and keeps capture, reading, and local search available.

Cloud intelligence is optional. Before a cloud request, FieldNotes asks for
purpose-specific permission. The request can contain the packing request, an
excerpt of at most 160 characters, the source note UUID, the capability and
purpose, and prompt version `packing-brief/v1`. It does not send the whole note,
an image, derived memory without its separate grant, or approval authority.
Revoking cloud permission blocks a new route and cancels an active lease.

The content-free audit records change identifiers, the action kind, replay state,
model metadata, and a correlation identifier. It omits note text, prompt text,
tool bodies, identity, and credentials.

## App Store Connect privacy-answer basis

- On-device note and model processing is not off-device collection.
- The cloud route transmits Other User Content for App Functionality. Apple says
  data sent only to service a real-time request and not retained is not
  “collected”; this answer therefore depends on production retention evidence.
- No image or audio crosses the current cloud boundary. If a later build sends
  either, reassess Photos or Videos and Audio Data.
- The current app privacy manifest declares no tracking, no tracking domains, no
  collected data, and no required-reason API use by app code. Regenerate the
  archive privacy report and include linked SDK manifests before submission.
- A privacy policy URL is required for an iOS app. A privacy-choices URL is
  optional.

Sources checked 2026-08-27: Apple, [App privacy details on the App Store](https://developer.apple.com/app-store/app-privacy-details/), including Other User Content, Audio Data, on-device processing, and the real-time service definition; Apple, [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy), including app-level answers and privacy-policy URL requirements; Apple, [Describing data use in privacy manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests), including manifest fields and archive privacy reports.

## Review-note basis

Guideline 5.1.2(i) says personal data must not be transmitted or shared without
permission, and that sharing with third parties, including third-party AI, must
be clearly disclosed with explicit permission first. FieldNotes demonstrates the
cloud consent, its purpose, the exact bounded fields, the deterministic refusal
route, and the approval screen to the reviewer.

Source checked 2026-08-27: Apple, [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), Guideline 5.1.2(i).
