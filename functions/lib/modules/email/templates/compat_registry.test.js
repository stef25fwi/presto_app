"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const compat_registry_1 = require("./compat_registry");
(0, node_test_1.default)("compat registry exposes modular templates to the worker", () => {
    const meta = (0, compat_registry_1.getCompatTemplateMeta)("tpl_transactional_payment_confirmed_v2");
    strict_1.default.ok(meta);
    strict_1.default.equal(meta?.channel, "transactionnel");
    strict_1.default.equal(meta?.category, "billing");
    strict_1.default.ok(compat_registry_1.compatTemplateRegistry.some((item) => item.template_code === "tpl_transactional_payment_confirmed_v2"));
});
(0, node_test_1.default)("compat registry returns modular fallback content", () => {
    const content = (0, compat_registry_1.getCompatDefaultTemplateContent)("tpl_transactional_account_welcome_v2", "fr");
    strict_1.default.match(content.html, /brandLogoUrl/);
    strict_1.default.match(content.text, /e-livre resto/);
});
(0, node_test_1.default)("compat registry validates required variables for modular templates", () => {
    const missing = (0, compat_registry_1.listCompatMissingRequiredVariables)("tpl_transactional_account_deletion_requested_v1", {
        firstName: "Nina",
    });
    strict_1.default.deepEqual(missing, ["deletionDate", "cancelDeletionUrl"]);
});
//# sourceMappingURL=compat_registry.test.js.map