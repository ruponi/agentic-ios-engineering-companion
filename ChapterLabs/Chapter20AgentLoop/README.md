# FieldNotes Chapter 20 Agent Loop

This provider-neutral Swift package is the executable fixture for “From a Model
Call to an Agent Loop.” It adapts the established Chapter 10 `NoteSearchIndex`
behavior into one read-only `searchNotes` seam; it does not create a second
durable store.

The scripted model makes successful, repeated-call, invalid-output, recovery,
turn-limit, and cancellation branches deterministic. No live model, provider
credential, network dependency, write tool, durable memory, or UI is present.

Run the complete check from this directory:

```sh
./Scripts/verify
```

The script builds under Swift 6 strict concurrency, runs the test suite,
regenerates the successful and repeated-call traces, and rejects trace drift.
