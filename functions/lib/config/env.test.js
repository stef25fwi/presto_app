"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
function loadEnvModule(overrides) {
    const previous = new Map();
    for (const [key, value] of Object.entries(overrides)) {
        previous.set(key, process.env[key]);
        if (value === undefined) {
            delete process.env[key];
        }
        else {
            process.env[key] = value;
        }
    }
    const modulePath = require.resolve("./env");
    delete require.cache[modulePath];
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const loaded = require("./env");
    for (const [key, value] of previous.entries()) {
        if (value === undefined) {
            delete process.env[key];
        }
        else {
            process.env[key] = value;
        }
    }
    delete require.cache[modulePath];
    return loaded;
}
(0, node_test_1.default)("ENFORCE_APP_CHECK is enabled by default in production", () => {
    const env = loadEnvModule({
        GCLOUD_PROJECT: "presto-app-74abe",
        GCP_PROJECT: undefined,
        FUNCTIONS_EMULATOR: undefined,
        FIREBASE_EMULATOR_HUB: undefined,
        ENFORCE_APP_CHECK: undefined,
        APPCHECK_SAFE_MODE: undefined,
    });
    strict_1.default.equal(env.IS_PROD, true);
    strict_1.default.equal(env.IS_EMULATOR, false);
    strict_1.default.equal(env.ENFORCE_APP_CHECK, true);
});
(0, node_test_1.default)("ENFORCE_APP_CHECK stays disabled in emulator", () => {
    const env = loadEnvModule({
        GCLOUD_PROJECT: "presto-app-74abe",
        GCP_PROJECT: undefined,
        FUNCTIONS_EMULATOR: "true",
        FIREBASE_EMULATOR_HUB: "localhost:4400",
        ENFORCE_APP_CHECK: undefined,
        APPCHECK_SAFE_MODE: undefined,
    });
    strict_1.default.equal(env.IS_EMULATOR, true);
    strict_1.default.equal(env.ENFORCE_APP_CHECK, false);
});
//# sourceMappingURL=env.test.js.map