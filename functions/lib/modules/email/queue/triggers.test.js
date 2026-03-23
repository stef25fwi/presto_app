"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const triggers_1 = require("./triggers");
(0, node_test_1.default)("digest window daily: primary and catch-up windows", () => {
    const primary = triggers_1.digestTestables.shouldEmitDigest("daily", {
        year: 2026,
        month: 3,
        day: 21,
        weekday: 6,
        hour: 8,
        minute: 10,
    });
    strict_1.default.equal(primary.emit, true);
    strict_1.default.equal(primary.catchup, false);
    const catchup = triggers_1.digestTestables.shouldEmitDigest("daily", {
        year: 2026,
        month: 3,
        day: 21,
        weekday: 6,
        hour: 10,
        minute: 30,
    });
    strict_1.default.equal(catchup.emit, true);
    strict_1.default.equal(catchup.catchup, true);
    const outside = triggers_1.digestTestables.shouldEmitDigest("daily", {
        year: 2026,
        month: 3,
        day: 21,
        weekday: 6,
        hour: 21,
        minute: 1,
    });
    strict_1.default.equal(outside.emit, false);
});
(0, node_test_1.default)("digest window weekly: only local monday", () => {
    const monday = triggers_1.digestTestables.shouldEmitDigest("weekly", {
        year: 2026,
        month: 3,
        day: 23,
        weekday: 1,
        hour: 9,
        minute: 0,
    });
    strict_1.default.equal(monday.emit, true);
    strict_1.default.equal(monday.catchup, true);
    const tuesday = triggers_1.digestTestables.shouldEmitDigest("weekly", {
        year: 2026,
        month: 3,
        day: 24,
        weekday: 2,
        hour: 9,
        minute: 0,
    });
    strict_1.default.equal(tuesday.emit, false);
});
(0, node_test_1.default)("digest cap per user matchCount", () => {
    const low = triggers_1.digestTestables.capDigestMatchCount(42);
    strict_1.default.deepEqual(low, { matchCount: 42, rawMatchCount: 42, capped: false });
    const high = triggers_1.digestTestables.capDigestMatchCount(999);
    strict_1.default.equal(high.rawMatchCount, 999);
    strict_1.default.equal(high.capped, true);
    strict_1.default.equal(high.matchCount <= high.rawMatchCount, true);
});
(0, node_test_1.default)("digest key helpers are deterministic", () => {
    const p = { year: 2026, month: 3, day: 21, weekday: 6, hour: 8, minute: 0 };
    strict_1.default.equal(triggers_1.digestTestables.localDayKey(p), "2026-03-21");
    strict_1.default.equal(triggers_1.digestTestables.localWeekKey(p), "W-2026-03-21");
});
//# sourceMappingURL=triggers.test.js.map