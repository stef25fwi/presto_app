"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const registry_1 = require("./registry");
(0, node_test_1.default)("default fallback content exists for every registered template", () => {
    for (const template of registry_1.templateRegistry) {
        const content = (0, registry_1.getDefaultTemplateContent)(template.template_code, "fr");
        strict_1.default.ok(content.html.includes("PRESTO"), template.template_code);
        strict_1.default.ok(content.text.includes("PRESTO"), template.template_code);
    }
});
(0, node_test_1.default)("required variable validation reports missing variables", () => {
    const missing = (0, registry_1.listMissingRequiredVariables)("tpl_transactional_support_reply_v1", {
        firstName: "Nina",
        ticketNumber: "SUP-42",
    });
    strict_1.default.deepEqual(missing, ["replyUrl"]);
});
(0, node_test_1.default)("required variable validation ignores populated variables", () => {
    const missing = (0, registry_1.listMissingRequiredVariables)("tpl_product_saved_search_match_found_v1", {
        searchName: "Plombier",
        matchCount: 3,
        resultsUrl: "https://ilipresto.fr/searches/1",
    });
    strict_1.default.deepEqual(missing, []);
});
//# sourceMappingURL=registry.test.js.map