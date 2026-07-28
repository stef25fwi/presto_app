import assert from "node:assert/strict";
import test from "node:test";

import { HttpsError } from "firebase-functions/v2/https";

import {
  assertMonthlyQuotaAvailable,
  monthlyQuotaPeriod,
} from "./cost_quota";

test("monthlyQuotaPeriod uses the UTC calendar month", () => {
  assert.equal(monthlyQuotaPeriod(new Date("2026-07-31T23:59:59Z")), "2026-07");
  assert.equal(monthlyQuotaPeriod(new Date("2026-08-01T00:00:00Z")), "2026-08");
});

test("assertMonthlyQuotaAvailable returns the reserved total", () => {
  assert.equal(assertMonthlyQuotaAvailable(20, 5.2, 30), 26);
});

test("assertMonthlyQuotaAvailable rejects disabled and exhausted quotas", () => {
  assert.throws(
    () => assertMonthlyQuotaAvailable(0, 1, 0),
    (error) => error instanceof HttpsError && error.code === "resource-exhausted",
  );
  assert.throws(
    () => assertMonthlyQuotaAvailable(9, 2, 10),
    (error) => error instanceof HttpsError && error.code === "resource-exhausted",
  );
});
