import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { afterEach, test } from "node:test";
import {
  createBackend,
  fixedTokenAuthenticator,
  fixtureProvider,
  providerPool,
} from "../backend.mjs";

const servers = [];
afterEach(async () => {
  await Promise.all(servers.splice(0).map((server) => new Promise((resolve) => server.close(resolve))));
});

test("authenticates, minimizes, streams, and replays one billed operation", async () => {
  const token = randomBytes(24).toString("hex");
  let providerCalls = 0;
  const logs = [];
  const server = await start({
    authenticate: fixedTokenAuthenticator(token),
    providers: providerPool([
      fixtureProvider({
        identifier: "fixture-primary",
        modelIdentifier: "fixture-model-a",
        onGenerate: () => { providerCalls += 1; },
      }),
    ]),
    logger: (record) => logs.push(record),
  });

  const headers = requestHeaders(token, "stable-operation-1", "00000000-0000-4000-8000-000000000001");
  const first = await fetch(endpoint(server), { method: "POST", headers, body: JSON.stringify(payload()) });
  const firstBody = await first.text();
  const replay = await fetch(endpoint(server), { method: "POST", headers, body: JSON.stringify(payload()) });

  assert.equal(first.status, 200);
  assert.equal(replay.status, 200);
  assert.equal(await replay.text(), firstBody);
  assert.equal(providerCalls, 1);
  assert.match(firstBody, /"kind":"progress"/);
  assert.match(firstBody, /"kind":"proposal"/);
  assert.deepEqual(Object.keys(logs[0]).sort(), [
    "correlationIdentifier", "durationMilliseconds", "modelIdentifier", "outcome",
    "providerIdentifier", "requestByteCount", "stage",
  ]);
  assert.equal(logs[0].stage, "backend.completed");
  assert.equal(Number.isInteger(logs[0].durationMilliseconds), true);
  assert.equal(logs[0].requestByteCount > 0, true);
  assert.equal(logs[1].outcome, "replayed");
});

test("refuses an undeclared full-note field before a provider sees it", async () => {
  const token = randomBytes(24).toString("hex");
  let providerCalls = 0;
  const server = await start({
    authenticate: fixedTokenAuthenticator(token),
    providers: providerPool([
      fixtureProvider({
        identifier: "fixture-primary",
        modelIdentifier: "fixture-model-a",
        onGenerate: () => { providerCalls += 1; },
      }),
    ]),
  });

  const response = await fetch(endpoint(server), {
    method: "POST",
    headers: requestHeaders(token, "operation-2", "00000000-0000-4000-8000-000000000002"),
    body: JSON.stringify({ ...payload(), fullNote: "must not cross" }),
  });

  assert.equal(response.status, 400);
  assert.match(await response.text(), /field not allowed: fullNote/);
  assert.equal(providerCalls, 0);
});

test("records the provider and model that actually answered after failover", async () => {
  const token = randomBytes(24).toString("hex");
  const server = await start({
    authenticate: fixedTokenAuthenticator(token),
    providers: providerPool([
      fixtureProvider({ identifier: "fixture-primary", modelIdentifier: "fixture-model-a", fail: true }),
      fixtureProvider({ identifier: "fixture-secondary", modelIdentifier: "fixture-model-b" }),
    ]),
  });

  const response = await fetch(endpoint(server), {
    method: "POST",
    headers: requestHeaders(token, "operation-3", "00000000-0000-4000-8000-000000000003"),
    body: JSON.stringify(payload()),
  });
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(body, /"providerIdentifier":"fixture-secondary"/);
  assert.match(body, /"modelIdentifier":"fixture-model-b"/);
});

test("refuses reuse of an idempotency key for a different payload", async () => {
  const token = randomBytes(24).toString("hex");
  const server = await start({
    authenticate: fixedTokenAuthenticator(token),
    providers: providerPool([
      fixtureProvider({ identifier: "fixture-primary", modelIdentifier: "fixture-model-a" }),
    ]),
  });
  const headers = requestHeaders(token, "same-key", "00000000-0000-4000-8000-000000000006");

  const first = await fetch(endpoint(server), {
    method: "POST", headers, body: JSON.stringify(payload()),
  });
  const second = await fetch(endpoint(server), {
    method: "POST", headers, body: JSON.stringify({ ...payload(), request: "Different request" }),
  });

  assert.equal(first.status, 200);
  assert.equal(second.status, 409);
});

test("enforces the per-user quota without logging note content", async () => {
  const token = randomBytes(24).toString("hex");
  const logs = [];
  const server = await start({
    authenticate: fixedTokenAuthenticator(token),
    providers: providerPool([
      fixtureProvider({ identifier: "fixture-primary", modelIdentifier: "fixture-model-a" }),
    ]),
    dailyQuota: 1,
    logger: (record) => logs.push(record),
  });

  const first = await fetch(endpoint(server), {
    method: "POST",
    headers: requestHeaders(token, "quota-1", "00000000-0000-4000-8000-000000000004"),
    body: JSON.stringify(payload()),
  });
  const second = await fetch(endpoint(server), {
    method: "POST",
    headers: requestHeaders(token, "quota-2", "00000000-0000-4000-8000-000000000005"),
    body: JSON.stringify(payload()),
  });

  assert.equal(first.status, 200);
  assert.equal(second.status, 429);
  assert.equal(JSON.stringify(logs).includes("Rain shell"), false);
});

test("refuses a content-bearing correlation identifier without logging it", async () => {
  const token = randomBytes(24).toString("hex");
  const logs = [];
  const server = await start({
    authenticate: fixedTokenAuthenticator(token),
    providers: providerPool([
      fixtureProvider({ identifier: "fixture-primary", modelIdentifier: "fixture-model-a" }),
    ]),
    logger: (record) => logs.push(record),
  });
  const hostileIdentifier = "note=Private health appointment";

  const response = await fetch(endpoint(server), {
    method: "POST",
    headers: requestHeaders(token, "bad-correlation", hostileIdentifier),
    body: JSON.stringify(payload()),
  });

  assert.equal(response.status, 400);
  assert.equal(JSON.stringify(logs).includes(hostileIdentifier), false);
  assert.equal(logs[0].correlationIdentifier, undefined);
});

test("emits content-free stage metrics for one correlation identifier", async () => {
  const token = randomBytes(24).toString("hex");
  const logs = [];
  const correlationIdentifier = "00000000-0000-4000-8000-000000000007";
  const server = await start({
    authenticate: fixedTokenAuthenticator(token),
    providers: providerPool([
      fixtureProvider({ identifier: "fixture-primary", modelIdentifier: "fixture-model-a" }),
    ]),
    logger: (record) => logs.push(record),
  });

  const response = await fetch(endpoint(server), {
    method: "POST",
    headers: requestHeaders(token, "telemetry-1", correlationIdentifier),
    body: JSON.stringify(payload()),
  });

  assert.equal(response.status, 200);
  assert.equal(logs[0].correlationIdentifier, correlationIdentifier);
  assert.equal(logs[0].stage, "backend.completed");
  assert.equal(logs[0].requestByteCount > 0, true);
  assert.equal(logs[0].durationMilliseconds >= 0, true);
  assert.equal("request" in logs[0], false);
  assert.equal("selectedExcerpt" in logs[0], false);
});

async function start(options) {
  const server = createBackend(options);
  servers.push(server);
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return server;
}

function endpoint(server) {
  return `http://127.0.0.1:${server.address().port}/v1/packing-proposals`;
}

function requestHeaders(token, idempotencyKey, correlationIdentifier) {
  return {
    "authorization": `Bearer ${token}`,
    "content-type": "application/json",
    "idempotency-key": idempotencyKey,
    "x-correlation-id": correlationIdentifier,
  };
}

function payload() {
  return {
    capability: "packing-brief",
    purpose: "packingBrief",
    request: "Prepare a short packing brief.",
    selectedExcerpt: "Pack a rain shell, rail pass, and notebook.",
    sourceNoteID: "11111111-1111-1111-1111-111111111111",
    promptVersion: "packing-brief/v1",
  };
}
