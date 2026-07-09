import assert from "node:assert/strict";
import test from "node:test";
import { resolveInternalStatus, resolvePlanForPriceId } from "./webhook";

test("resolvePlanForPriceId defaults to free when no price id or unknown price id matches", () => {
  assert.equal(resolvePlanForPriceId(undefined), "free");
  assert.equal(resolvePlanForPriceId("price_unrelated"), "free");
});

test("resolveInternalStatus maps active and trialing to active access", () => {
  assert.equal(resolveInternalStatus("active"), "active");
  assert.equal(resolveInternalStatus("trialing"), "active");
});

test("resolveInternalStatus maps past_due and unpaid to past_due", () => {
  assert.equal(resolveInternalStatus("past_due"), "past_due");
  assert.equal(resolveInternalStatus("unpaid"), "past_due");
});

test("resolveInternalStatus maps canceled and incomplete_expired to canceled", () => {
  assert.equal(resolveInternalStatus("canceled"), "canceled");
  assert.equal(resolveInternalStatus("incomplete_expired"), "canceled");
});

test("resolveInternalStatus falls back to inactive for incomplete/paused", () => {
  assert.equal(resolveInternalStatus("incomplete"), "inactive");
  assert.equal(resolveInternalStatus("paused"), "inactive");
});
