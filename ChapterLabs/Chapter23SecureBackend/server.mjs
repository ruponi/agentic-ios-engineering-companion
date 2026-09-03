import { randomBytes } from "node:crypto";
import {
  createBackend,
  fixedTokenAuthenticator,
  fixtureProvider,
  providerPool,
} from "./backend.mjs";

const userToken = process.env.FIELDNOTES_USER_TOKEN;
if (!userToken) {
  console.error("Set FIELDNOTES_USER_TOKEN to an app-user token before starting the fixture.");
  process.exit(64);
}

const port = Number(process.env.PORT ?? 8787);
const server = createBackend({
  authenticate: fixedTokenAuthenticator(userToken),
  providers: providerPool([
    fixtureProvider({ identifier: "fixture-primary", modelIdentifier: "fixture-model-a" }),
  ]),
  logger: (record) => console.log(JSON.stringify(record)),
});

server.listen(port, "127.0.0.1", () => {
  console.log(`FieldNotes backend fixture listening on http://127.0.0.1:${port}`);
  console.log(`Correlation seed: ${randomBytes(4).toString("hex")}`);
});
