import assert from "node:assert/strict";
import test from "node:test";
import { digestTestables } from "./triggers";

test("digest window daily: primary and catch-up windows", () => {
  const primary = digestTestables.shouldEmitDigest("daily", {
    year: 2026,
    month: 3,
    day: 21,
    weekday: 6,
    hour: 8,
    minute: 10,
  });
  assert.equal(primary.emit, true);
  assert.equal(primary.catchup, false);

  const catchup = digestTestables.shouldEmitDigest("daily", {
    year: 2026,
    month: 3,
    day: 21,
    weekday: 6,
    hour: 10,
    minute: 30,
  });
  assert.equal(catchup.emit, true);
  assert.equal(catchup.catchup, true);

  const outside = digestTestables.shouldEmitDigest("daily", {
    year: 2026,
    month: 3,
    day: 21,
    weekday: 6,
    hour: 21,
    minute: 1,
  });
  assert.equal(outside.emit, false);
});

test("digest window weekly: only local monday", () => {
  const monday = digestTestables.shouldEmitDigest("weekly", {
    year: 2026,
    month: 3,
    day: 23,
    weekday: 1,
    hour: 9,
    minute: 0,
  });
  assert.equal(monday.emit, true);
  assert.equal(monday.catchup, true);

  const tuesday = digestTestables.shouldEmitDigest("weekly", {
    year: 2026,
    month: 3,
    day: 24,
    weekday: 2,
    hour: 9,
    minute: 0,
  });
  assert.equal(tuesday.emit, false);
});

test("digest cap per user matchCount", () => {
  const low = digestTestables.capDigestMatchCount(42);
  assert.deepEqual(low, { matchCount: 42, rawMatchCount: 42, capped: false });

  const high = digestTestables.capDigestMatchCount(999);
  assert.equal(high.rawMatchCount, 999);
  assert.equal(high.capped, true);
  assert.equal(high.matchCount <= high.rawMatchCount, true);
});

test("digest key helpers are deterministic", () => {
  const p = { year: 2026, month: 3, day: 21, weekday: 6, hour: 8, minute: 0 };
  assert.equal(digestTestables.localDayKey(p), "2026-03-21");
  assert.equal(digestTestables.localWeekKey(p), "W-2026-03-21");
});
