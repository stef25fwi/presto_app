"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EmailDispatchService = void 0;
const env_1 = require("../../../config/env");
const provider_factory_1 = require("../providers/provider_factory");
const definitions_1 = require("../templates/definitions");
const render_html_1 = require("../renderer/render_html");
const render_text_1 = require("../renderer/render_text");
const EmailLogService_1 = require("./EmailLogService");
const EmailPreferenceService_1 = require("./EmailPreferenceService");
function buildBrandVariables() {
    return {
        brandLogoUrl: "{{appBaseUrl}}/assets/images/logowebp.webp",
        brandLogoAlt: "e-livre resto",
        brandName: "e-livre resto",
        appBaseUrl: "https://presto.app",
    };
}
class EmailDispatchService {
    logService;
    preferenceService;
    constructor(logService = new EmailLogService_1.EmailLogService(), preferenceService = new EmailPreferenceService_1.EmailPreferenceService()) {
        this.logService = logService;
        this.preferenceService = preferenceService;
    }
    renderTemplate(input) {
        const definition = definitions_1.emailTemplateRegistry[input.templateId];
        const variables = {
            ...buildBrandVariables(),
            firstName: input.recipient.firstName ?? input.variables.firstName ?? "",
            recipientFirstName: input.recipient.firstName ?? "",
            ...input.variables,
        };
        return {
            subject: (0, render_text_1.renderText)(definition.subject, variables),
            previewText: (0, render_text_1.renderText)(definition.previewText, variables),
            html: (0, render_html_1.renderHtml)(definition.html, variables),
            text: (0, render_text_1.renderText)(definition.text, variables),
        };
    }
    async sendTemplatedEmail(input) {
        const definition = definitions_1.emailTemplateRegistry[input.templateId];
        const preferences = await this.preferenceService.getCommunicationPreferences(input.recipient.userId);
        if (!input.force && !this.preferenceService.canSendEmailType(preferences, definition.type)) {
            const skippedResult = {
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
            });
            return skippedResult;
        }
        const rendered = this.renderTemplate(input);
        const provider = (0, provider_factory_1.createEmailProvider)();
        const sendResult = await provider.send({
            to: input.recipient.email,
            from: env_1.EMAIL_FROM,
            subject: rendered.subject,
            html: rendered.html,
            text: rendered.text,
            tags: [definition.id, definition.category, definition.type],
            metadata: {
                template_id: definition.id,
                event_name: definition.event,
                ...(input.metadata ?? {}),
            },
            idempotencyKey: input.idempotencyKey
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
        });
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
exports.EmailDispatchService = EmailDispatchService;
//# sourceMappingURL=EmailDispatchService.js.map