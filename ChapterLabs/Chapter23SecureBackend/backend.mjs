import { createServer as createHTTPServer } from "node:http";
import { createHash, timingSafeEqual } from "node:crypto";

const ALLOWED_KEYS = new Set([
  "capability",
  "purpose",
  "request",
  "selectedExcerpt",
  "sourceNoteID",
  "promptVersion",
]);

export function fixedTokenAuthenticator(expectedToken) {
  const expected = Buffer.from(expectedToken);
  return async (authorization) => {
    const supplied = Buffer.from(authorization?.replace(/^Bearer /, "") ?? "");
    if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
      return null;
    }
    return { userID: "reader-fixture", capabilities: new Set(["packing-brief"]) };
  };
}

export function credentialGuardedProvider({ identifier, modelIdentifier, credential, generate }) {
  if (!credential) throw new Error(`Missing server-side credential for ${identifier}`);
  return { identifier, modelIdentifier, generate };
}

export function fixtureProvider({ identifier, modelIdentifier, fail = false, onGenerate = () => {} }) {
  return {
    identifier,
    modelIdentifier,
    async generate(payload) {
      onGenerate();
      if (fail) throw new Error("fixture provider unavailable");
      if (!payload.selectedExcerpt) {
        return {
          action: "searchNotes",
          callID: "cloud-call-1",
          query: "Kyoto",
        };
      }
      return {
        action: "finish",
        title: "Kyoto packing brief",
        items: ["Rain shell", "Rail pass", "Notebook"],
        sourceNoteIDs: [payload.sourceNoteID],
      };
    },
  };
}

export function providerPool(providers) {
  return {
    async generate(payload) {
      let lastError;
      for (const provider of providers) {
        try {
          const proposal = await provider.generate(payload);
          return {
            proposal,
            providerIdentifier: provider.identifier,
            modelIdentifier: provider.modelIdentifier,
          };
        } catch (error) {
          lastError = error;
        }
      }
      throw lastError ?? new Error("No provider configured");
    },
  };
}

export function createBackend({ authenticate, providers, dailyQuota = 3, logger = () => {}, now = () => new Date() }) {
  const idempotency = new Map();
  const usage = new Map();

  return createHTTPServer(async (request, response) => {
    const startedAt = performance.now();
    const correlationIdentifier = request.headers["x-correlation-id"];
    const idempotencyKey = request.headers["idempotency-key"];
    const safeCorrelationIdentifier = isUUID(correlationIdentifier)
      ? correlationIdentifier.toLowerCase()
      : undefined;
    const log = (fields) => logger({
      ...(safeCorrelationIdentifier ? { correlationIdentifier: safeCorrelationIdentifier } : {}),
      ...fields,
    });

    try {
      if (request.method !== "POST" || request.url !== "/v1/packing-proposals") {
        return refuse(response, 404, "unsupported route");
      }
      if (typeof correlationIdentifier !== "string" || typeof idempotencyKey !== "string") {
        return refuse(response, 400, "missing request identifiers");
      }
      if (!safeCorrelationIdentifier) {
        throw badRequest("correlation identifier must be a UUID");
      }

      const identity = await authenticate(request.headers.authorization);
      if (!identity) return refuse(response, 401, "authentication required");
      if (!identity.capabilities.has("packing-brief")) {
        return refuse(response, 403, "capability not authorized");
      }

      const decodedRequest = await readJSON(request);
      const payload = validatePayload(decodedRequest.value);
      const payloadDigest = createHash("sha256")
        .update(JSON.stringify(payload))
        .digest("hex");
      const replayKey = `${identity.userID}:${idempotencyKey}`;
      const prior = idempotency.get(replayKey);
      if (prior) {
        if (prior.payloadDigest !== payloadDigest) {
          return refuse(response, 409, "idempotency key reused with different payload");
        }
        log({ outcome: "replayed" });
        return writeNDJSON(response, prior.lines);
      }

      const day = now().toISOString().slice(0, 10);
      const quotaKey = `${identity.userID}:${day}`;
      const used = usage.get(quotaKey) ?? 0;
      if (used >= dailyQuota) return refuse(response, 429, "daily quota reached");
      usage.set(quotaKey, used + 1);

      const result = await providers.generate(payload);
      const lines = [
        {
          kind: "progress",
          message: "Assembling brief",
          correlationIdentifier,
        },
        {
          kind: "proposal",
          proposal: result.proposal,
          providerIdentifier: result.providerIdentifier,
          modelIdentifier: result.modelIdentifier,
          correlationIdentifier,
        },
      ];
      idempotency.set(replayKey, { payloadDigest, lines });
      log({
        stage: "backend.completed",
        durationMilliseconds: Math.max(0, Math.round(performance.now() - startedAt)),
        requestByteCount: decodedRequest.byteCount,
        providerIdentifier: result.providerIdentifier,
        modelIdentifier: result.modelIdentifier,
        outcome: "completed",
      });
      return writeNDJSON(response, lines);
    } catch (error) {
      log({ outcome: "refused", reason: error.message });
      return refuse(response, error.statusCode ?? 500, error.statusCode ? error.message : "provider unavailable");
    }
  });
}

function isUUID(value) {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

function validatePayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw badRequest("JSON object required");
  }
  for (const key of Object.keys(payload)) {
    if (!ALLOWED_KEYS.has(key)) throw badRequest(`field not allowed: ${key}`);
  }
  if (payload.capability !== "packing-brief" || payload.purpose !== "packingBrief") {
    throw badRequest("unsupported capability or purpose");
  }
  if (typeof payload.request !== "string" || payload.request.length > 500) {
    throw badRequest("request is missing or too large");
  }
  if (payload.selectedExcerpt != null &&
      (typeof payload.selectedExcerpt !== "string" || payload.selectedExcerpt.length > 240)) {
    throw badRequest("selected excerpt is too large");
  }
  if (payload.sourceNoteID != null && typeof payload.sourceNoteID !== "string") {
    throw badRequest("source note identifier is invalid");
  }
  if (typeof payload.promptVersion !== "string") throw badRequest("prompt version required");
  return payload;
}

async function readJSON(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > 16_384) throw badRequest("request body too large");
    chunks.push(chunk);
  }
  try {
    return {
      value: JSON.parse(Buffer.concat(chunks).toString("utf8")),
      byteCount: size,
    };
  } catch {
    throw badRequest("invalid JSON");
  }
}

function writeNDJSON(response, lines) {
  response.writeHead(200, { "content-type": "application/x-ndjson" });
  for (const line of lines) response.write(`${JSON.stringify(line)}\n`);
  response.end();
}

function refuse(response, statusCode, message) {
  response.writeHead(statusCode, { "content-type": "application/json" });
  response.end(JSON.stringify({ error: message }));
}

function badRequest(message) {
  return Object.assign(new Error(message), { statusCode: 400 });
}
