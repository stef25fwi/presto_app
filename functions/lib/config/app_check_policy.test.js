"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const app_check_policy_1 = require("./app_check_policy");
(0, node_test_1.default)("désactive App Check dans les émulateurs", () => {
    strict_1.default.equal((0, app_check_policy_1.resolveAppCheckEnforcement)({
        isEmulator: true,
        isProduction: true,
        enforceValue: "true",
    }), false);
});
(0, node_test_1.default)("active App Check par défaut en production", () => {
    strict_1.default.equal((0, app_check_policy_1.resolveAppCheckEnforcement)({
        isEmulator: false,
        isProduction: true,
    }), true);
    strict_1.default.equal((0, app_check_policy_1.resolveAppCheckEnforcement)({
        isEmulator: false,
        isProduction: true,
        enforceValue: "true",
    }), true);
});
(0, node_test_1.default)("autorise uniquement une désactivation explicite en production", () => {
    strict_1.default.equal((0, app_check_policy_1.resolveAppCheckEnforcement)({
        isEmulator: false,
        isProduction: true,
        enforceValue: " false ",
    }), false);
});
(0, node_test_1.default)("exige une activation explicite hors production", () => {
    strict_1.default.equal((0, app_check_policy_1.resolveAppCheckEnforcement)({
        isEmulator: false,
        isProduction: false,
    }), false);
    strict_1.default.equal((0, app_check_policy_1.resolveAppCheckEnforcement)({
        isEmulator: false,
        isProduction: false,
        enforceValue: "TRUE",
    }), true);
});
(0, node_test_1.default)("safe mode désactive toujours App Check", () => {
    strict_1.default.equal((0, app_check_policy_1.resolveAppCheckEnforcement)({
        isEmulator: false,
        isProduction: true,
        enforceValue: "true",
        safeModeValue: "true",
    }), false);
});
//# sourceMappingURL=app_check_policy.test.js.map