"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.syncEmailAnalytics = exports.purgeOldEmailLogs = exports.purgeOldEmailWebhooks = exports.handleEmailProviderWebhook = exports.cleanupExpiredEmailJobs = exports.retryFailedEmailJobs = exports.processScheduledEmailDigests = exports.processEmailJobTrigger = exports.enqueueEmailJobsFromEventTrigger = exports.onBillingInvoiceUpdated = exports.onSubscriptionUpdated = exports.onReportCreated = exports.onSupportTicketReplied = exports.onSupportTicketCreated = exports.enqueueUnreadMessageReminders = exports.onMessageCreated = exports.enqueueExpiringListingEmails = exports.onListingPublished = exports.onUserCreated = void 0;
const v2_1 = require("firebase-functions/v2");
const env_1 = require("./config/env");
(0, v2_1.setGlobalOptions)({
    secrets: env_1.EMAIL_PROVIDER_SECRETS,
});
var triggers_1 = require("./modules/auth/triggers");
Object.defineProperty(exports, "onUserCreated", { enumerable: true, get: function () { return triggers_1.onUserCreated; } });
var triggers_2 = require("./modules/listings/triggers");
Object.defineProperty(exports, "onListingPublished", { enumerable: true, get: function () { return triggers_2.onListingPublished; } });
var scheduled_1 = require("./modules/listings/scheduled");
Object.defineProperty(exports, "enqueueExpiringListingEmails", { enumerable: true, get: function () { return scheduled_1.enqueueExpiringListingEmails; } });
var triggers_3 = require("./modules/messaging/triggers");
Object.defineProperty(exports, "onMessageCreated", { enumerable: true, get: function () { return triggers_3.onMessageCreated; } });
var scheduled_2 = require("./modules/messaging/scheduled");
Object.defineProperty(exports, "enqueueUnreadMessageReminders", { enumerable: true, get: function () { return scheduled_2.enqueueUnreadMessageReminders; } });
var triggers_4 = require("./modules/support/triggers");
Object.defineProperty(exports, "onSupportTicketCreated", { enumerable: true, get: function () { return triggers_4.onSupportTicketCreated; } });
Object.defineProperty(exports, "onSupportTicketReplied", { enumerable: true, get: function () { return triggers_4.onSupportTicketReplied; } });
var triggers_5 = require("./modules/moderation/triggers");
Object.defineProperty(exports, "onReportCreated", { enumerable: true, get: function () { return triggers_5.onReportCreated; } });
var triggers_6 = require("./modules/billing/triggers");
Object.defineProperty(exports, "onSubscriptionUpdated", { enumerable: true, get: function () { return triggers_6.onSubscriptionUpdated; } });
Object.defineProperty(exports, "onBillingInvoiceUpdated", { enumerable: true, get: function () { return triggers_6.onBillingInvoiceUpdated; } });
var triggers_7 = require("./modules/email/queue/triggers");
Object.defineProperty(exports, "enqueueEmailJobsFromEventTrigger", { enumerable: true, get: function () { return triggers_7.enqueueEmailJobsFromEventTrigger; } });
Object.defineProperty(exports, "processEmailJobTrigger", { enumerable: true, get: function () { return triggers_7.processEmailJobTrigger; } });
Object.defineProperty(exports, "processScheduledEmailDigests", { enumerable: true, get: function () { return triggers_7.processScheduledEmailDigests; } });
Object.defineProperty(exports, "retryFailedEmailJobs", { enumerable: true, get: function () { return triggers_7.retryFailedEmailJobs; } });
Object.defineProperty(exports, "cleanupExpiredEmailJobs", { enumerable: true, get: function () { return triggers_7.cleanupExpiredEmailJobs; } });
var handler_1 = require("./modules/email/webhooks/handler");
Object.defineProperty(exports, "handleEmailProviderWebhook", { enumerable: true, get: function () { return handler_1.handleEmailProviderWebhook; } });
var scheduled_3 = require("./modules/email/scheduled");
Object.defineProperty(exports, "purgeOldEmailWebhooks", { enumerable: true, get: function () { return scheduled_3.purgeOldEmailWebhooks; } });
Object.defineProperty(exports, "purgeOldEmailLogs", { enumerable: true, get: function () { return scheduled_3.purgeOldEmailLogs; } });
Object.defineProperty(exports, "syncEmailAnalytics", { enumerable: true, get: function () { return scheduled_3.syncEmailAnalytics; } });
//# sourceMappingURL=index.js.map