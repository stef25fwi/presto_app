"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.loadMessagingModerationMode = loadMessagingModerationMode;
exports.shouldModerateSynchronouslyBeforeSend = shouldModerateSynchronouslyBeforeSend;
exports.buildPendingMessagingModeration = buildPendingMessagingModeration;
exports.resolveMessagingModerationRecord = resolveMessagingModerationRecord;
exports.evaluateMessagingModeration = evaluateMessagingModeration;
const firestore_1 = require("../../core/firestore");
const constants_1 = require("../../shared/constants");
const moderation_1 = require("../marketplace/services/moderation");
function parseMessagingModerationMode(value) {
    switch (String(value ?? "").trim().toLowerCase()) {
        case "visible_then_retract":
            return "visible_then_retract";
        case "hidden_until_validated":
            return "hidden_until_validated";
        case "hybrid":
            return "hybrid";
        default:
            return "hybrid";
    }
}
function uniqueFlags(flags) {
    return Array.from(new Set(flags));
}
function buildUserMessage({ moderationDecision, autoFlags, }) {
    if (moderationDecision === "approved") {
        return "";
    }
    if (autoFlags.includes("banned_term")) {
        return "Le message contient des termes non conformes aux CGU.";
    }
    if (autoFlags.includes("adult_content") || autoFlags.includes("violent_content")) {
        return "Une image du message semble non conforme aux CGU.";
    }
    if (moderationDecision === "manual_review") {
        return "Le message doit être vérifié avant diffusion.";
    }
    if (moderationDecision === "auto_flagged") {
        return "Le message semble sensible et nécessite un contrôle.";
    }
    return "Le message ne peut pas être envoyé dans son état actuel.";
}
async function loadMessagingModerationMode() {
    const snapshot = await firestore_1.db.collection(constants_1.COLLECTIONS.appConfig).doc("marketplace").get();
    const moderation = (snapshot.data()?.moderation ?? {});
    return parseMessagingModerationMode(moderation.messagingMode);
}
function shouldModerateSynchronouslyBeforeSend(mode) {
    return mode === "hidden_until_validated";
}
function buildPendingMessagingModeration(mode) {
    return {
        mode,
        status: "pending",
        visibility: "visible",
        moderationDecision: "approved",
        moderationReason: "pending_async_review",
        userMessage: "",
        autoFlags: [],
        riskScore: 0,
        textScanStatus: "pending",
        imageScanStatus: "pending",
    };
}
function resolveMessagingModerationRecord({ mode, moderationDecision, }) {
    if (mode === "visible_then_retract") {
        if (moderationDecision === "blocked") {
            return {
                status: "rejected",
                visibility: "hidden",
            };
        }
        return {
            status: "approved",
            visibility: "visible",
        };
    }
    if (moderationDecision === "blocked") {
        return {
            status: "rejected",
            visibility: "hidden",
        };
    }
    if (moderationDecision === "manual_review" || moderationDecision === "auto_flagged") {
        return {
            status: "manual_review",
            visibility: "hidden",
        };
    }
    return {
        status: "approved",
        visibility: "visible",
    };
}
async function evaluateMessagingModeration({ mode, text, attachments, }) {
    const config = await (0, moderation_1.loadModerationConfig)();
    const normalizedText = text.trim();
    const imageAttachments = attachments.filter((attachment) => attachment.type === "image");
    const textEvaluation = normalizedText
        ? await (0, moderation_1.evaluateListingText)({
            title: "",
            description: normalizedText,
            ownerSignals: {
                moderationStrikeCount: 0,
                spamScore: 0,
                recentListingCount: 0,
                hasSimilarActiveListing: false,
            },
            config,
        })
        : {
            autoFlags: [],
            textScanStatus: "completed",
            riskScore: 0,
            reason: "clean",
        };
    const imageEvaluation = imageAttachments.length > 0
        ? await (0, moderation_1.moderateListingMedia)(imageAttachments.map((attachment) => ({
            storagePath: attachment.storagePath,
            downloadUrl: attachment.url,
            thumbnailUrl: attachment.url,
            mimeType: attachment.mimeType,
            sizeBytes: attachment.sizeBytes,
        })))
        : {
            safeSearchResult: {},
            autoFlags: [],
            imageScanStatus: "completed",
            riskScore: 0,
        };
    const autoFlags = uniqueFlags([
        ...textEvaluation.autoFlags,
        ...imageEvaluation.autoFlags,
    ]);
    const riskScore = Math.max(textEvaluation.riskScore, imageEvaluation.riskScore);
    const decision = (0, moderation_1.computeModerationDecision)({
        riskScore,
        autoFlags,
    });
    const resolvedRecord = resolveMessagingModerationRecord({
        mode,
        moderationDecision: decision.moderationDecision,
    });
    return {
        mode,
        status: resolvedRecord.status,
        visibility: resolvedRecord.visibility,
        moderationDecision: decision.moderationDecision,
        moderationReason: decision.moderationReason,
        userMessage: buildUserMessage({
            moderationDecision: decision.moderationDecision,
            autoFlags,
        }),
        autoFlags,
        riskScore,
        textScanStatus: textEvaluation.textScanStatus,
        imageScanStatus: imageEvaluation.imageScanStatus,
    };
}
//# sourceMappingURL=moderation.js.map