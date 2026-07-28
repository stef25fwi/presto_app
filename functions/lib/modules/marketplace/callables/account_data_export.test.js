"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const account_data_export_1 = require("./account_data_export");
(0, node_test_1.default)("serializeFirestoreValue passes primitives through unchanged", () => {
    strict_1.default.equal((0, account_data_export_1.serializeFirestoreValue)("hello"), "hello");
    strict_1.default.equal((0, account_data_export_1.serializeFirestoreValue)(42), 42);
    strict_1.default.equal((0, account_data_export_1.serializeFirestoreValue)(true), true);
    strict_1.default.equal((0, account_data_export_1.serializeFirestoreValue)(null), null);
    strict_1.default.equal((0, account_data_export_1.serializeFirestoreValue)(undefined), undefined);
});
(0, node_test_1.default)("serializeFirestoreValue converts Firestore Timestamp-like values to ISO strings", () => {
    const timestampLike = {
        toDate: () => new Date("2026-07-28T10:00:00.000Z"),
    };
    strict_1.default.equal((0, account_data_export_1.serializeFirestoreValue)(timestampLike), "2026-07-28T10:00:00.000Z");
});
(0, node_test_1.default)("serializeFirestoreValue recurses into arrays and nested objects", () => {
    const timestampLike = {
        toDate: () => new Date("2026-07-28T10:00:00.000Z"),
    };
    const input = {
        title: "Annonce",
        createdAt: timestampLike,
        tags: ["a", "b"],
        media: [
            { uploadedAt: timestampLike, url: "https://cdn.example/1.jpg" },
        ],
    };
    strict_1.default.deepEqual((0, account_data_export_1.serializeFirestoreValue)(input), {
        title: "Annonce",
        createdAt: "2026-07-28T10:00:00.000Z",
        tags: ["a", "b"],
        media: [
            { uploadedAt: "2026-07-28T10:00:00.000Z", url: "https://cdn.example/1.jpg" },
        ],
    });
});
//# sourceMappingURL=account_data_export.test.js.map