"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const scheduled_1 = require("./scheduled");
(0, node_test_1.default)("hasPublishedListingRecords accepts canonical published listings", () => {
    strict_1.default.equal((0, scheduled_1.hasPublishedListingRecords)([
        { status: "draft" },
        { status: "published" },
    ]), true);
});
(0, node_test_1.default)("hasPublishedListingRecords accepts active legacy-like records", () => {
    strict_1.default.equal((0, scheduled_1.hasPublishedListingRecords)([
        { status: "inactive" },
        { isActive: true },
    ]), true);
});
(0, node_test_1.default)("hasPublishedListingRecords rejects non published records", () => {
    strict_1.default.equal((0, scheduled_1.hasPublishedListingRecords)([
        { status: "draft" },
        { status: "pending" },
    ]), false);
});
//# sourceMappingURL=scheduled.test.js.map