import assert from "node:assert/strict";
import test from "node:test";

function loadEnvModule(overrides: Record<string, string | undefined>) {
  const previous = new Map<string, string | undefined>();
  for (const [key, value] of Object.entries(overrides)) {
    previous.set(key, process.env[key]);
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }

  const modulePath = require.resolve("./env");
  delete require.cache[modulePath];
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const loaded = require("./env") as typeof import("./env");

  for (const [key, value] of previous.entries()) {
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }
  delete require.cache[modulePath];
  return loaded;
}

test("ENFORCE_APP_CHECK is enabled by default in production", () => {
  const env = loadEnvModule({
    GCLOUD_PROJECT: "presto-app-74abe",
    GCP_PROJECT: undefined,
    FUNCTIONS_EMULATOR: undefined,
    FIREBASE_EMULATOR_HUB: undefined,
    ENFORCE_APP_CHECK: undefined,
    APPCHECK_SAFE_MODE: undefined,
  });

  assert.equal(env.IS_PROD, true);
  assert.equal(env.IS_EMULATOR, false);
  assert.equal(env.ENFORCE_APP_CHECK, true);
});

test("ENFORCE_APP_CHECK stays disabled in emulator", () => {
  const env = loadEnvModule({
    GCLOUD_PROJECT: "presto-app-74abe",
    GCP_PROJECT: undefined,
    FUNCTIONS_EMULATOR: "true",
    FIREBASE_EMULATOR_HUB: "localhost:4400",
    ENFORCE_APP_CHECK: undefined,
    APPCHECK_SAFE_MODE: undefined,
  });

  assert.equal(env.IS_EMULATOR, true);
  assert.equal(env.ENFORCE_APP_CHECK, false);
});

test("APPCHECK_SAFE_MODE cannot disable enforcement in production", () => {
  const env = loadEnvModule({
    GCLOUD_PROJECT: "presto-app-74abe",
    GCP_PROJECT: undefined,
    FUNCTIONS_EMULATOR: undefined,
    FIREBASE_EMULATOR_HUB: undefined,
    ENFORCE_APP_CHECK: "true",
    APPCHECK_SAFE_MODE: "true",
  });

  assert.equal(env.IS_PROD, true);
  assert.equal(env.IS_EMULATOR, false);
  assert.equal(env.ENFORCE_APP_CHECK, true);
});
