export type CostScheduledTaskName =
  | "processScheduledEmailDigests"
  | "retryFailedEmailJobs"
  | "syncEmailAnalytics"
  | "enqueueExpiringListingEmails"
  | "enqueueFourHourExpiryPushNotifications"
  | "syncMessagingAnalytics"
  | "enqueueUnreadMessageReminders"
  | "auditStripeCatalog"
  | "purgeOrphanedStorageFiles"
  | "purgeAbandonedListingDrafts"
  | "cleanupExpiredEmailJobs"
  | "publishMaturedReviewsV2"
  | "purgeOldEmailWebhooks"
  | "purgeOldEmailLogs"
  | "enqueueNearbyNewListingsEmails"
  | "enqueueMarketingOnboardingEmails"
  | "enqueueReactivation30DaysEmails"
  | "enqueueFirstListingNotPublishedReminders"
  | "enqueueProfileIncompleteReminderEmails"
  | "expireOldListings";

interface ClockParts {
  utcHour: number;
  utcMinute: number;
  parisHour: number;
  parisMinute: number;
}

function parisClock(date: Date): { hour: number; minute: number } {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Paris",
    hourCycle: "h23",
    hour: "2-digit",
    minute: "2-digit",
  }).formatToParts(date);
  const value = (type: string) =>
    Number(parts.find((part) => part.type === type)?.value ?? 0);
  return { hour: value("hour"), minute: value("minute") };
}

export function costScheduleClock(date: Date): ClockParts {
  const paris = parisClock(date);
  return {
    utcHour: date.getUTCHours(),
    utcMinute: date.getUTCMinutes(),
    parisHour: paris.hour,
    parisMinute: paris.minute,
  };
}

export function dueQuarterHourTasks(
  date: Date,
  options: { stripeCatalogAuditEnabled?: boolean } = {},
): CostScheduledTaskName[] {
  const clock = costScheduleClock(date);
  const tasks: CostScheduledTaskName[] = ["processScheduledEmailDigests"];

  if (clock.utcMinute % 30 === 0) {
    tasks.push("retryFailedEmailJobs");
  }

  if (clock.utcMinute === 0) {
    tasks.push(
      "syncEmailAnalytics",
      "enqueueExpiringListingEmails",
      "enqueueFourHourExpiryPushNotifications",
      "syncMessagingAnalytics",
    );
    if (clock.utcHour % 2 === 0) {
      tasks.push("enqueueUnreadMessageReminders");
    }
    if (options.stripeCatalogAuditEnabled && clock.utcHour % 6 === 0) {
      tasks.push("auditStripeCatalog");
    }
  }

  if (clock.utcHour === 2 && clock.utcMinute === 0) {
    tasks.push("purgeOrphanedStorageFiles");
  }
  if (clock.utcHour === 3 && clock.utcMinute === 0) {
    tasks.push("purgeAbandonedListingDrafts");
  }
  if (clock.utcHour === 3 && clock.utcMinute === 15) {
    tasks.push("cleanupExpiredEmailJobs", "publishMaturedReviewsV2");
  }
  if (clock.utcHour === 4 && clock.utcMinute === 0) {
    tasks.push("purgeOldEmailWebhooks");
  }
  if (clock.utcHour === 4 && clock.utcMinute === 30) {
    tasks.push("purgeOldEmailLogs");
  }
  if (clock.utcHour === 8 && clock.utcMinute === 30) {
    tasks.push("enqueueNearbyNewListingsEmails");
  }
  if (clock.utcHour === 9 && clock.utcMinute === 0) {
    tasks.push("enqueueMarketingOnboardingEmails");
  }
  if (clock.utcHour === 9 && clock.utcMinute === 30) {
    tasks.push("enqueueReactivation30DaysEmails");
  }
  if (clock.utcHour === 10 && clock.utcMinute === 0) {
    tasks.push("enqueueFirstListingNotPublishedReminders");
  }
  if (clock.utcHour === 10 && clock.utcMinute === 30) {
    tasks.push("enqueueProfileIncompleteReminderEmails");
  }

  // L'ancien job tournait à 03:10 Europe/Paris. Le dispatcher par quarts
  // d'heure l'exécute à 03:15, soit cinq minutes plus tard.
  if (clock.parisHour === 3 && clock.parisMinute === 15) {
    tasks.push("expireOldListings");
  }

  return [...new Set(tasks)];
}
