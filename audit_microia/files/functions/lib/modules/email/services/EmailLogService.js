"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmailLogService = void 0;
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
class EmailLogService {
    async logAttempt(record) {
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailLogs).add({
            eventType: record.eventType,
            templateId: record.templateId,
            template_code: record.templateCode,
            recipient_user_id: record.userId ?? null,
            recipient_email: record.recipient,
            status: record.status,
            provider: record.provider,
            provider_message_id: record.providerMessageId ?? null,
            created_at: record.createdAt,
            sent_at: record.sentAt ?? null,
            failed_at: record.failedAt ?? null,
            error_code: record.errorCode ?? null,
            error_message: record.errorMessage ?? null,
            metadata: record.metadata,
            locale: record.locale,
            category: record.category,
            type: record.type,
            retry_count: record.retryCount,
        });
    }
}
exports.EmailLogService = EmailLogService;
//# sourceMappingURL=EmailLogService.js.map