import { EMAIL_FROM } from "../../../config/env";
import { createEmailProvider } from "../providers/provider_factory";
import {
  EmailDispatchInput,
  EmailLogRecord,
  EmailRenderResult,
  EmailSendResult,
} from "../contracts";
import { emailTemplateRegistry } from "../templates/definitions";
import { renderHtml } from "../renderer/render_html";
import { renderText } from "../renderer/render_text";
import { EmailLogService } from "./EmailLogService";
import { EmailPreferenceService } from "./EmailPreferenceService";

function buildBrandVariables(): Record<string, string> {
  return {
    brandLogoUrl: "{{appBaseUrl}}/assets/images/logowebp.webp",
    brandLogoAlt: "e-livre resto",
    brandName: "e-livre resto",
    appBaseUrl: "https://presto.app",
  };
}

export class EmailDispatchService {
  constructor(
    private readonly logService = new EmailLogService(),
    private readonly preferenceService = new EmailPreferenceService(),
  ) {}

  renderTemplate(input: EmailDispatchInput): EmailRenderResult {
    const definition = emailTemplateRegistry[input.templateId];
    const variables = {
      ...buildBrandVariables(),
      firstName: input.recipient.firstName ?? input.variables.firstName ?? "",
      recipientFirstName: input.recipient.firstName ?? "",
      ...input.variables,
    };

    return {
      subject: renderText(definition.subject, variables),
      previewText: renderText(definition.previewText, variables),
      html: renderHtml(definition.html, variables),
      text: renderText(definition.text, variables),
    };
  }

  async sendTemplatedEmail(input: EmailDispatchInput): Promise<EmailSendResult> {
    const definition = emailTemplateRegistry[input.templateId];
    const preferences = await this.preferenceService.getCommunicationPreferences(
      input.recipient.userId,
    );

    if (!input.force && !this.preferenceService.canSendEmailType(preferences, definition.type)) {
      const skippedResult: EmailSendResult = {
        accepted: false,
        provider: "none",
        status: "skipped",
        errorCode: "preferences_blocked",
        errorMessage: "Email blocked by communication preferences",
      };

      await this.logService.logAttempt({
        eventType: definition.event,
        templateId: definition.id,
        templateCode: definition.templateCode,
        userId: input.recipient.userId ?? null,
        recipient: input.recipient.email,
        status: skippedResult.status,
        provider: skippedResult.provider,
        providerMessageId: null,
        createdAt: Date.now(),
        failedAt: Date.now(),
        errorCode: skippedResult.errorCode,
        errorMessage: skippedResult.errorMessage,
        metadata: input.metadata ?? {},
        locale: input.recipient.locale ?? preferences.locale,
        category: definition.category,
        type: definition.type,
        retryCount: 0,
      } satisfies EmailLogRecord);

      return skippedResult;
    }

    const rendered = this.renderTemplate(input);
    const provider = createEmailProvider();
    const sendResult = await provider.send({
      to: input.recipient.email,
      from: EMAIL_FROM,
      subject: rendered.subject,
      html: rendered.html,
      text: rendered.text,
      tags: [definition.id, definition.category, definition.type],
      metadata: {
        template_id: definition.id,
        event_name: definition.event,
        ...(input.metadata ?? {}),
      },
      idempotencyKey:
        input.idempotencyKey
        ?? `${definition.id}:${input.recipient.email}:${input.eventId ?? "manual"}`,
      stream: definition.type === "marketing" ? "broadcast" : "transactional",
    });

    await this.logService.logAttempt({
      eventType: definition.event,
      templateId: definition.id,
      templateCode: definition.templateCode,
      userId: input.recipient.userId ?? null,
      recipient: input.recipient.email,
      status: sendResult.status,
      provider: provider.name(),
      providerMessageId: sendResult.providerMessageId ?? null,
      createdAt: Date.now(),
      sentAt: sendResult.accepted ? Date.now() : undefined,
      failedAt: sendResult.accepted ? undefined : Date.now(),
      errorCode: sendResult.errorCode,
      errorMessage: sendResult.errorMessage,
      metadata: input.metadata ?? {},
      locale: input.recipient.locale ?? preferences.locale,
      category: definition.category,
      type: definition.type,
      retryCount: 0,
    } satisfies EmailLogRecord);

    return {
      accepted: sendResult.accepted,
      provider: provider.name(),
      providerMessageId: sendResult.providerMessageId,
      status: sendResult.accepted ? "accepted" : "rejected",
      errorCode: sendResult.errorCode,
      errorMessage: sendResult.errorMessage,
    };
  }
}