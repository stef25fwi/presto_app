"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onAgentAuthorizationDecision = exports.onAgentAuthorizationRequested = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const firestore_2 = require("../../core/firestore");
const SYSTEM_AGENT_UID = "system_agent_authorizations";
const SYSTEM_AGENT_NAME = "Centre d’autorisation des agents";
function isSuperAdmin(data) {
    const roles = data.roles;
    return data.superadmin === true ||
        data.superAdmin === true ||
        data.isSuperadmin === true ||
        data.role === "superadmin" ||
        data.primaryRole === "superadmin" ||
        (Array.isArray(roles) && roles.includes("superadmin")) ||
        (!!roles && typeof roles === "object" &&
            (roles.superadmin === true ||
                roles.superAdmin === true));
}
async function superAdminIds() {
    const snapshot = await firestore_2.db.collection("users").get();
    return snapshot.docs
        .filter((doc) => isSuperAdmin(doc.data()))
        .map((doc) => doc.id);
}
function riskLabel(value) {
    switch (String(value || "medium")) {
        case "critical": return "critique";
        case "high": return "élevé";
        case "low": return "faible";
        default: return "moyen";
    }
}
async function publishAuthorizationMessage(requestId, request, kind) {
    const recipients = await superAdminIds();
    if (recipients.length === 0)
        return;
    const now = firebase_admin_1.default.firestore.FieldValue.serverTimestamp();
    const title = String(request.title || "Demande d’autorisation").trim();
    const agentLabel = String(request.agentLabel || request.agentId || "Agent").trim();
    const status = String(request.status || "pending").trim();
    const comment = String(request.decisionComment || "").trim();
    const text = kind === "requested"
        ? `🔐 ${agentLabel} demande une autorisation (${riskLabel(request.risk)}). ${title}`
        : status === "approved"
            ? `✅ Autorisation accordée : ${title}${comment ? ` — ${comment}` : ""}`
            : status === "rejected"
                ? `⛔ Autorisation refusée : ${title}${comment ? ` — ${comment}` : ""}`
                : `ℹ️ Mise à jour de la demande : ${title} (${status})`;
    await Promise.all(recipients.map(async (superAdminUid) => {
        const conversationId = `agent_authorizations_${superAdminUid}`;
        const conversationRef = firestore_2.db.collection("conversations").doc(conversationId);
        const messageRef = conversationRef.collection("messages").doc(`${requestId}_${kind}_${status}`);
        const unreadIncrement = kind === "requested" ? 1 : 0;
        await firestore_2.db.runTransaction(async (transaction) => {
            transaction.set(conversationRef, {
                type: "system_agent_authorization",
                systemConversation: true,
                title: SYSTEM_AGENT_NAME,
                participants: [SYSTEM_AGENT_UID, superAdminUid],
                participantIds: [SYSTEM_AGENT_UID, superAdminUid],
                participant_ids: [SYSTEM_AGENT_UID, superAdminUid],
                userIds: [SYSTEM_AGENT_UID, superAdminUid],
                memberIds: [SYSTEM_AGENT_UID, superAdminUid],
                participantNames: {
                    [SYSTEM_AGENT_UID]: SYSTEM_AGENT_NAME,
                    [superAdminUid]: "Superadmin",
                },
                status: "active",
                lastMessage: text,
                lastSenderId: SYSTEM_AGENT_UID,
                lastSenderName: SYSTEM_AGENT_NAME,
                lastMessageAt: now,
                updatedAt: now,
                createdAt: now,
                unreadCount: {
                    [superAdminUid]: firebase_admin_1.default.firestore.FieldValue.increment(unreadIncrement),
                    [SYSTEM_AGENT_UID]: 0,
                },
                adminWatchlisted: true,
            }, { merge: true });
            transaction.set(messageRef, {
                senderId: SYSTEM_AGENT_UID,
                senderName: SYSTEM_AGENT_NAME,
                text,
                body: text,
                type: "agent_authorization",
                createdAt: now,
                updatedAt: now,
                isFirstMessage: false,
                createdVia: "agent_authorization_trigger",
                moderation: {
                    mode: "trusted_system",
                    status: "approved",
                    visibility: "visible",
                },
                metadata: {
                    requestId,
                    authorizationStatus: status,
                    risk: String(request.risk || "medium"),
                    actionType: String(request.actionType || ""),
                    routeName: `/admin/agents/authorizations?requestId=${encodeURIComponent(requestId)}`,
                    requiresAction: status === "pending",
                },
            }, { merge: false });
        });
    }));
}
exports.onAgentAuthorizationRequested = (0, firestore_1.onDocumentCreated)("agent_authorization_requests/{requestId}", async (event) => {
    const request = event.data?.data();
    if (!request || String(request.status || "pending") !== "pending")
        return;
    await publishAuthorizationMessage(String(event.params.requestId), request, "requested");
});
exports.onAgentAuthorizationDecision = (0, firestore_1.onDocumentUpdated)("agent_authorization_requests/{requestId}", async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status)
        return;
    await publishAuthorizationMessage(String(event.params.requestId), after, "decided");
});
//# sourceMappingURL=authorization_messaging.js.map