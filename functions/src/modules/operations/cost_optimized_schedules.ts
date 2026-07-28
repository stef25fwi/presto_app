import { onSchedule } from "firebase-functions/v2/scheduler";

import { COST_POLICY } from "../../config/cost_policy";
import {
  CostScheduledTaskName,
  dueQuarterHourTasks,
} from "../../config/cost_schedule";
import {
  PROJECT_REGION,
  STRIPE_CHECKOUT_SECRETS,
} from "../../config/env";
import { logger } from "../../core/logger";
import {
  auditStripeCatalog,
} from "../billing/callables";
import {
  cleanupExpiredEmailJobs,
  processScheduledEmailDigests,
  retryFailedEmailJobs,
} from "../email/queue/triggers";
import {
  purgeOldEmailLogs,
  purgeOldEmailWebhooks,
  syncEmailAnalytics,
} from "../email/scheduled";
import {
  enqueueExpiringListingEmails,
  enqueueFirstListingNotPublishedReminders,
  enqueueFourHourExpiryPushNotifications,
} from "../listings/scheduled";
import {
  enqueueMarketingOnboardingEmails,
  enqueueNearbyNewListingsEmails,
  enqueueProfileIncompleteReminderEmails,
  enqueueReactivation30DaysEmails,
} from "../marketing/scheduled";
import {
  expireOldListings,
  publishApprovedListings,
} from "../marketplace/scheduled/listings";
import {
  purgeAbandonedListingDrafts,
  purgeOrphanedStorageFiles,
} from "../marketplace/scheduled/storage_cleanup";
import { publishMaturedReviewsV2 } from "../marketplace/callables/reviews_v2";
import {
  enqueueUnreadMessageReminders,
  syncMessagingAnalytics,
} from "../messaging/scheduled";

interface RunnableSchedule {
  run: (event: unknown) => void | Promise<void>;
}

const TASKS: Record<CostScheduledTaskName, RunnableSchedule> = {
  processScheduledEmailDigests,
  retryFailedEmailJobs,
  syncEmailAnalytics,
  enqueueExpiringListingEmails,
  enqueueFourHourExpiryPushNotifications,
  syncMessagingAnalytics,
  enqueueUnreadMessageReminders,
  auditStripeCatalog,
  purgeOrphanedStorageFiles,
  purgeAbandonedListingDrafts,
  cleanupExpiredEmailJobs,
  publishMaturedReviewsV2,
  purgeOldEmailWebhooks,
  purgeOldEmailLogs,
  enqueueNearbyNewListingsEmails,
  enqueueMarketingOnboardingEmails,
  enqueueReactivation30DaysEmails,
  enqueueFirstListingNotPublishedReminders,
  enqueueProfileIncompleteReminderEmails,
  expireOldListings,
};

async function runTasks(
  names: CostScheduledTaskName[],
  event: unknown,
): Promise<void> {
  const failures: Array<{ task: string; error: string }> = [];

  for (const name of names) {
    try {
      await TASKS[name].run(event);
    } catch (error) {
      failures.push({
        task: name,
        error: error instanceof Error ? error.message : String(error),
      });
      logger.error("cost_optimized_schedule_task_failed", {
        task: name,
        error,
      });
    }
  }

  if (failures.length > 0) {
    throw new Error(
      `Scheduled maintenance failed: ${failures
        .map((failure) => failure.task)
        .join(", ")}`,
    );
  }
}

export const runCostOptimizedMinuteTasks = onSchedule({
  region: PROJECT_REGION,
  schedule: "every minute",
  timeZone: "UTC",
  timeoutSeconds: 120,
  memory: "256MiB",
  retryCount: 1,
}, async (event) => {
  await publishApprovedListings.run(event);
});

export const runCostOptimizedQuarterHourTasks = onSchedule({
  region: PROJECT_REGION,
  schedule: "every 15 minutes",
  timeZone: "UTC",
  timeoutSeconds: 540,
  memory: "1GiB",
  retryCount: 1,
  secrets: STRIPE_CHECKOUT_SECRETS,
}, async (event) => {
  const scheduleTime = new Date(event.scheduleTime);
  const referenceTime = Number.isNaN(scheduleTime.valueOf())
    ? new Date()
    : scheduleTime;
  const due = dueQuarterHourTasks(referenceTime, {
    stripeCatalogAuditEnabled: COST_POLICY.stripeCatalogAuditEnabled,
  });
  await runTasks(due, event);
});
