# AGENTIC iOS ENGINEERING — Companion

*Build, Test, Secure and Ship AI-Powered Apps with SwiftUI, Foundation Models and Coding Agents*

By Ruslan Ponomarenko

This directory is the reader-facing code companion for the book. It contains a
running FieldNotes iOS application and small chapter laboratories whose results
can be reproduced independently.

## What readers should open

- `FieldNotes/FieldNotes.xcodeproj` — the canonical application, evolving with
  the book.
- `ChapterLabs/` — focused experiments that are intentionally kept outside the
  application target.
- `BOOK_TO_CODE.md` — a reader map from book topics to executable examples.
- `Scripts/verify` — the supported verification entry point.

This repository contains only the reader-facing application, chapter labs, and
their verification material.

## Requirements

- macOS with Xcode 26 or newer.
- An installed iOS Simulator runtime compatible with the selected Xcode.

## Chapter coverage

Runnable now: app composition, capture, lists and detail, the network boundary,
SwiftData persistence with a seeded V1-to-V2 migration test, offline search, and
the Chapter 20 agent loop with its Chapter 21 placement gate.

Not yet in the companion: the Apple-platform integration chapter (App Intents,
widget, camera and dictation). Those need additional targets and entitlements
and are tracked as pending.

The application currently targets iOS 17 and uses Swift 6 with complete strict
concurrency checking.

## Build and test

From this directory:

```sh
./Scripts/build
./Scripts/verify
```

`Scripts/verify` tests the app, then verifies every included chapter lab. It uses
the first booted iPhone Simulator by its unambiguous UDID.
Boot an iPhone simulator in Xcode first, or select another installed simulator
explicitly:

```sh
FIELDNOTES_DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0' ./Scripts/verify
```

## Repository policy

- The canonical app should remain runnable after every chapter increment.
- A chapter lab proves one idea and must not silently become application code.
- Generated build products, DerivedData, `.xcresult`, and Instruments traces are
  not committed. Small textual evidence and expected outputs may be committed.
- Examples shown in the book should point to a stable tag or release of this
  companion repository.

The example code is available under the MIT License; see `LICENSE`. The checked-in
bundle identifiers intentionally use the `com.example` namespace. Replace them
with identifiers you own before signing and installing the app on a device.
