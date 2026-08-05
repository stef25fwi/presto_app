import admin from "../../core/firebase_admin_compat";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../../core/firestore";

const SYSTEM_AGENT_UID = "system_agent_authorizations";
const SYSTEM_AGENT_NAME = "Centre d’autorisation des agents";

function isSuperAdmin(data: Record<string, unknown>): boolean {
  const roles = data.roles;
  return data.superadmin === true ||
    data.superAdmin === true ||
    data.isSuperadmin === true ||
    data.role === "superadmin" ||
    data.primaryRole === "superadmin" ||
    (Array.isArray(roles) && roles.includes("superadmin")) ||
    (!!roles && typeof roles === "object" &&
      ((roles as Record<string, unknown>).superadmin === true ||
       (roles as Record<string, unknown>).superAdmin === true));
}

async function superAdminIds(): Promise<string[]> {
  const snapshot = await db.collection("users").get();
  return snapshot.docs
    .filter((doc) => isSuperAdmin(doc.data() as Record<string, unknown>))
    .map((doc) => doc.id);
}

function riskLabel(value: unknown): string {
  switch (String(value || "medium")) {
    case "critical": return "critique";
    case "high": return "élevé";
    case "low": return "faible";
    default: return "moyen";
  }
}

async function publishAuthorizationMessage(
  requestId: string,
  request: Record<string, unknown>,
  kind: "requested" | "decided",
): Promise<void> {
  const recipients = await superAdminIds();
  if (recipients.length === 0) return;

  const now = admin.firestore.FieldValue.serverTimestamp();
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
    const conversationRef = db.collection("conversations").doc(conversationId);
    const messageRef = conversationRef.collection("messages").doc(`${requestId}_${kind}_${status}`);
    const unreadIncrement = kind === "requested" ? 1 : 0;

    await db.runTransaction(async (transaction) => {
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
          [superAdminUid]: admin.firestore.FieldValue.increment(unreadIncrement),
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

export const onAgentAuthorizationRequested = onDocumentCreated(
  "agent_authorization_requests/{requestId}",
  async (event) => {
    const request = event.data?.data() as Record<string, unknown> | undefined;
    if (!request || String(request.status || "pending") !== "pending") return;
    await publishAuthorizationMessage(String(event.params.requestId), request, "requested");
  },
);

export const onAgentAuthorizationDecision = onDocumentUpdated(
  "agent_authorization_requests/{requestId}",
  async (event) => {
    const before = event.data?.before.data() as Record<string, unknown> | undefined;
    const after = event.data?.after.data() as Record<string, unknown> | undefined;
    if (!before || !after || before.status === after.status) return;
    await publishAuthorizationMessage(String(event.params.requestId), after, "decided");
  },
);
