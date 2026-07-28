import assert from "node:assert/strict";
import test from "node:test";

import { dueQuarterHourTasks } from "./cost_schedule";

test("quarter-hour dispatcher always runs email digests", () => {
  assert.deepEqual(
    dueQuarterHourTasks(new Date("2026-07-28T12:15:00Z")),
    ["processScheduledEmailDigests"],
  );
});

test("hourly and two-hour tasks keep their original cadence", () => {
  const tasks = dueQuarterHourTasks(new Date("2026-07-28T12:00:00Z"));
  assert.ok(tasks.includes("retryFailedEmailJobs"));
  assert.ok(tasks.includes("syncEmailAnalytics"));
  assert.ok(tasks.includes("enqueueUnreadMessageReminders"));
  assert.ok(!tasks.includes("auditStripeCatalog"));
});

test("Stripe audit only runs outside minimum-cost mode", () => {
  const disabled = dueQuarterHourTasks(
    new Date("2026-07-28T12:00:00Z"),
    { stripeCatalogAuditEnabled: false },
  );
  const enabled = dueQuarterHourTasks(
    new Date("2026-07-28T12:00:00Z"),
    { stripeCatalogAuditEnabled: true },
  );
  assert.ok(!disabled.includes("auditStripeCatalog"));
  assert.ok(enabled.includes("auditStripeCatalog"));
});

test("daily cleanup and marketing tasks keep deterministic slots", () => {
  assert.ok(
    dueQuarterHourTasks(new Date("2026-07-28T02:00:00Z"))
      .includes("purgeOrphanedStorageFiles"),
  );
  assert.ok(
    dueQuarterHourTasks(new Date("2026-07-28T03:15:00Z"))
      .includes("cleanupExpiredEmailJobs"),
  );
  assert.ok(
    dueQuarterHourTasks(new Date("2026-07-28T08:30:00Z"))
      .includes("enqueueNearbyNewListingsEmails"),
  );
  assert.ok(
    dueQuarterHourTasks(new Date("2026-07-28T10:30:00Z"))
      .includes("enqueueProfileIncompleteReminderEmails"),
  );
});

test("Paris listing expiry remains aligned across daylight saving time", () => {
  const summer = dueQuarterHourTasks(new Date("2026-07-28T01:15:00Z"));
  const winter = dueQuarterHourTasks(new Date("2026-12-28T02:15:00Z"));
  assert.ok(summer.includes("expireOldListings"));
  assert.ok(winter.includes("expireOldListings"));
});
