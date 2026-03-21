"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.processEmailJob = processEmailJob;
const firestore_1 = require("../../../core/firestore");
const logger_1 = require("../../../core/logger");
const constants_1 = require("../../../shared/constants");
const provider_factory_1 = require("../providers/provider_factory");
const dead_letter_1 = require("./dead_letter");
const retry_1 = require("./retry");
const env_1 = require("../../../config/env");
const loader_1 = require("../templates/loader");
const registry_1 = require("../templates/registry");
const render_html_1 = require("../renderer/render_html");
const render_text_1 = require("../renderer/render_text");
async function resolveTemplate(templateCode, locale, payload) {
    // 1. Essai depuis Firestore (versions dynamiques)
    const loaded = await (0, loader_1.loadActiveTemplateVersion)(templateCode, locale);
    if (loaded) {
        return {
            subject: (0, render_text_1.renderText)(loaded.subject, payload),
            html: (0, render_html_1.renderHtml)(loaded.html, payload),
            text: (0, render_text_1.renderText)(loaded.text, payload),
        };
    }
    // 2. Fallback sur le registre statique
    const meta = (0, registry_1.getTemplateMeta)(templateCode);
    const subject = meta?.default_subject_fr ?? `PRESTO — ${templateCode}`;
    const preheader = meta?.default_preheader_fr ?? "";
    const vars = payload;
    const firstName = vars.firstName ?? "";
    const htmlBody = (0, render_html_1.renderHtml)(`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>{{subject}}</title></head>` +
        `<body style="font-family:sans-serif;max-width:600px;margin:auto;padding:24px">` +
        `<h2 style="color:#F97316">PRESTO</h2>` +
        `${firstName ? `<p>Bonjour {{firstName}},</p>` : ""}` +
        `<p style="font-size:16px">{{preheader}}</p>` +
        `<hr><p style="color:#6B7280;font-size:12px">` +
        `Vous recevez cet e-mail car vous êtes inscrit(e) sur PRESTO. ` +
        `<a href="https://presto.app/unsubscribe">Se désabonner</a></p></body></html>`, { ...payload, subject, preheader });
    const textBody = (0, render_text_1.renderText)(`PRESTO\n\n${firstName ? "Bonjour {{firstName}},\n\n" : ""}${preheader}\n\n---\nPRESTŌ`, {
        ...payload,
        subject,
        preheader,
    });
    return { subject, html: htmlBody, text: textBody };
}
async function processEmailJob(jobId) {
    const ref = firestore_1.db.collection(constants_1.COLLECTIONS.emailJobs).doc(jobId);
    const snap = await ref.get();
    if (!snap.exists)
        return;
    const job = snap.data();
    if (job.status !== "queued" && job.status !== "scheduled")
        return;
    if (Date.now() < job.send_at)
        return;
    await ref.set({ status: "processing", updated_at: Date.now() }, { merge: true });
    // Charger et rendre le template
    let subject;
    let html;
    let text;
    try {
        // Récupérer le payload stocké dans l'event source
        const eventSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(job.event_id).get();
        const eventPayload = eventSnap.data()?.payload ?? {};
        const rendered = await resolveTemplate(job.template_code, job.locale, eventPayload);
        subject = rendered.subject;
        html = rendered.html;
        text = rendered.text;
    }
    catch (err) {
        logger_1.logger.warn("email_job_template_render_failed", { jobId, error: String(err) });
        subject = `PRESTO — ${job.template_code}`;
        html = `<p>PRESTO — ${job.template_code}</p>`;
        text = `PRESTO — ${job.template_code}`;
    }
    const provider = (0, provider_factory_1.createEmailProvider)();
    const sendResult = await provider.send({
        to: job.recipient_email,
        from: env_1.EMAIL_FROM,
        subject,
        html,
        text,
        tags: [job.template_code, job.channel],
        metadata: {
            job_id: job.job_id,
            event_id: job.event_id,
        },
        idempotencyKey: job.idempotency_key,
        stream: job.channel === "marketing" ? "broadcast" : "transactional",
    });
    if (sendResult.accepted) {
        await ref.set({
            status: "sent",
            updated_at: Date.now(),
            provider_message_id: sendResult.providerMessageId,
        }, { merge: true });
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailLogs).add({
            job_id: job.job_id,
            provider: provider.name(),
            provider_message_id: sendResult.providerMessageId || null,
            status: "sent",
            created_at: Date.now(),
        });
        logger_1.logger.info("email_job_sent", { jobId: job.job_id, providerMessageId: sendResult.providerMessageId });
        return;
    }
    const nextAttempts = job.attempts + 1;
    if (nextAttempts >= job.max_attempts) {
        await (0, dead_letter_1.moveJobToDeadLetter)(job.job_id, sendResult.errorCode || "provider_rejected");
        return;
    }
    const delayMs = (0, retry_1.computeRetryDelayMs)(nextAttempts - 1);
    await ref.set({
        status: "scheduled",
        attempts: nextAttempts,
        send_at: Date.now() + delayMs,
        last_error_code: sendResult.errorCode || "provider_rejected",
        last_error_message: sendResult.errorMessage || "provider rejected request",
        updated_at: Date.now(),
    }, { merge: true });
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailLogs).add({
        job_id: job.job_id,
        provider: provider.name(),
        status: "failed",
        error_code: sendResult.errorCode || "provider_rejected",
        error_message: sendResult.errorMessage || "provider rejected request",
        created_at: Date.now(),
    });
    logger_1.logger.warn("email_job_retry_scheduled", { jobId: job.job_id, attempts: nextAttempts, delayMs });
}
//# sourceMappingURL=worker.js.map