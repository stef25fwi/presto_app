"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const state_1 = require("./state");
(0, node_test_1.default)("readConversationFlagMap normalizes boolean maps", () => {
    const flags = (0, state_1.readConversationFlagMap)({
        archivedBy: {
            a: true,
            b: false,
            c: "yes",
        },
    }, "archivedBy");
    strict_1.default.deepEqual(flags, {
        a: true,
        b: false,
        c: false,
    });
});
(0, node_test_1.default)("computeConversationStatus returns open when nobody archived or blocked", () => {
    const status = (0, state_1.computeConversationStatus)(["a", "b"], { a: false, b: false }, { a: false, b: false });
    strict_1.default.equal(status, "open");
});
(0, node_test_1.default)("computeConversationStatus returns archived when all participants archived", () => {
    const status = (0, state_1.computeConversationStatus)(["a", "b"], { a: true, b: true }, { a: false, b: false });
    strict_1.default.equal(status, "archived");
});
(0, node_test_1.default)("computeConversationStatus returns closed when any participant blocked", () => {
    const status = (0, state_1.computeConversationStatus)(["a", "b"], { a: true, b: true }, { a: false, b: true });
    strict_1.default.equal(status, "closed");
    strict_1.default.equal((0, state_1.isConversationBlocked)({ blockedBy: { a: false, b: true } }), true);
});
(0, node_test_1.default)("isConversationFlagEnabledForUser reads participant-specific flags", () => {
    const data = {
        blockedBy: {
            a: false,
            b: true,
        },
    };
    strict_1.default.equal((0, state_1.isConversationFlagEnabledForUser)(data, "blockedBy", "a"), false);
    strict_1.default.equal((0, state_1.isConversationFlagEnabledForUser)(data, "blockedBy", "b"), true);
});
(0, node_test_1.default)("isConversationFlagEnabledForUser also supports deletedBy", () => {
    const data = {
        deletedBy: {
            a: true,
            b: false,
        },
    };
    strict_1.default.equal((0, state_1.isConversationFlagEnabledForUser)(data, "deletedBy", "a"), true);
    strict_1.default.equal((0, state_1.isConversationFlagEnabledForUser)(data, "deletedBy", "b"), false);
});
//# sourceMappingURL=state.test.js.map