import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { EmailLogRecord } from "../contracts";

export class EmailLogService {
  async logAttempt(record: EmailLogRecord): Promise<void> {
    await db.collection(COLLECTIONS.emailLogs).add({
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