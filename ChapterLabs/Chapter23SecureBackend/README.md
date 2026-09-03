# Chapter 23 secure backend

This dependency-free Node.js 22 lab is the small backend facade used by
*Cloud Intelligence and the Secure Backend*. It accepts only the packing-brief
capability, rechecks the minimized request shape, applies an in-memory per-user
quota, retains idempotent results for the life of the process, and streams
newline-delimited JSON.

Run `./Scripts/verify` for the deterministic providers. To start the local
fixture, supply an ephemeral app-user token through `FIELDNOTES_USER_TOKEN` and
run `node server.mjs`. The repository contains no user token or model-provider
credential. `credentialGuardedProvider` shows the server-only credential
boundary; a live provider adapter and durable production stores remain
production integration work outside this local fixture.
