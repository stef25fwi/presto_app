"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const scheduled_1 = require("./scheduled");
(0, node_test_1.default)("countRecentPublishedListingRecords counts published canonical listings within the window", () => {
    strict_1.default.equal((0, scheduled_1.countRecentPublishedListingRecords)([
        { status: "published", publishedAt: 1_760_000_000_000 },
        { status: "active", createdAt: 1_760_000_100_000 },
        { status: "draft", publishedAt: 1_760_000_200_000 },
    ], 1_759_999_999_999), 2);
});
(0, node_test_1.default)("countRecentPublishedListingRecords ignores records older than the cutoff", () => {
    strict_1.default.equal((0, scheduled_1.countRecentPublishedListingRecords)([
        { status: "published", publishedAt: 1_759_000_000_000 },
        { status: "active", createdAt: 1_758_000_000_000 },
    ], 1_760_000_000_000), 0);
});
(0, node_test_1.default)("countRecentPublishedListingRecords ignores non published statuses", () => {
    strict_1.default.equal((0, scheduled_1.countRecentPublishedListingRecords)([
        { status: "pending", publishedAt: 1_760_000_000_000 },
        { status: "draft", createdAt: 1_760_000_100_000 },
        { isActive: true, createdAt: 1_760_000_200_000 },
    ], 1_759_999_999_999), 0);
});
//# sourceMappingURL=scheduled.test.js.map