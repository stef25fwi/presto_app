"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.renderTemplate = renderTemplate;
exports.sendTransactionalEmail = sendTransactionalEmail;
exports.sendMarketingEmail = sendMarketingEmail;
exports.sendDigestEmail = sendDigestEmail;
exports.suppressRecipient = suppressRecipient;
exports.handleWebhook = handleWebhook;
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const provider_factory_1 = require("./providers/provider_factory");
const render_html_1 = require("./renderer/render_html");
const render_text_1 = require("./renderer/render_text");
function renderTemplate(input) {
    return {
        subject: input.subject,
        html: (0, render_html_1.renderHtml)(input.html, input.data),
        text: (0, render_text_1.renderText)(input.text, input.data),
    };
}
async function sendTransactionalEmail(jobId) {
    await firestore_1.db.collection(constants_1.COLLECTIONS.audits).add({ action: "email.send_transactional", job_id: jobId, created_at: Date.now() });
}
async function sendMarketingEmail(jobId) {
    await firestore_1.db.collection(constants_1.COLLECTIONS.audits).add({ action: "email.send_marketing", job_id: jobId, created_at: Date.now() });
}
async function sendDigestEmail(jobId) {
    await firestore_1.db.collection(constants_1.COLLECTIONS.audits).add({ action: "email.send_digest", job_id: jobId, created_at: Date.now() });
}
async function suppressRecipient(email, reason) {
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailSuppressions).doc(email).set({
        email,
        reason,
        source: "system",
        active: true,
        created_at: Date.now(),
    }, { merge: true });
}
async function handleWebhook(rawBody) {
    const provider = (0, provider_factory_1.createEmailProvider)();
    const events = provider.parseWebhook(rawBody);
    await firestore_1.db.collection(constants_1.COLLECTIONS.audits).add({
        action: "email.webhook.parsed",
        provider: provider.name(),
        count: events.length,
        created_at: Date.now(),
    });
}
//# sourceMappingURL=service.js.map