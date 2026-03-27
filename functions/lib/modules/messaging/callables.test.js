"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const callables_1 = require("./callables");
(0, node_test_1.default)("readConversationMessageCount uses atomic counter when present", () => {
    strict_1.default.equal((0, callables_1.readConversationMessageCount)({ messageCount: 3, lastMessage: "" }), 3);
});
(0, node_test_1.default)("readConversationMessageCount falls back to lastMessage for legacy conversations", () => {
    strict_1.default.equal((0, callables_1.readConversationMessageCount)({ lastMessage: "Bonjour" }), 1);
    strict_1.default.equal((0, callables_1.readConversationMessageCount)({ lastMessage: "   " }), 0);
});
//# sourceMappingURL=callables.test.js.map