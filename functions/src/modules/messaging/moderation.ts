import { db } from "../../core/firestore";
import { COLLECTIONS } from "../../shared/constants";
import type { ModerationAutoFlag, ModerationStatus } from "../marketplace/constants/enums";
import type { ListingMedia } from "../marketplace/models/firestore";
import {
  computeModerationDecision,
  evaluateListingText,
  loadModerationConfig,
  moderateListingMedia,
} from "../marketplace/services/moderation";

export type MessagingModerationMode =
  | "visible_then_retract"
  | "hidden_until_validated"
  | "hybrid";

export type MessagingModerationRecordStatus =
  | "pending"
  | "approved"
  | "manual_review"
  | "rejected";

export type MessagingModerationVisibility = "visible" | "hidden";

export interface MessagingAttachmentLike {
  type: "image" | "document" | "audio";
  name: string;
  url: string;
  storagePath: string;
  mimeType: string;
  sizeBytes: number;
}

export interface MessagingModerationEvaluation {
  mode: MessagingModerationMode;
  status: MessagingModerationRecordStatus;
  visibility: MessagingModerationVisibility;
  moderationDecision: ModerationStatus;
  moderationReason: string;
  userMessage: string;
  autoFlags: ModerationAutoFlag[];
  riskScore: number;
  textScanStatus: "pending" | "completed" | "failed";
  imageScanStatus: "pending" | "completed" | "failed";
}

function parseMessagingModerationMode(value: unknown): MessagingModerationMode {
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

function uniqueFlags(flags: ModerationAutoFlag[]): ModerationAutoFlag[] {
  return Array.from(new Set(flags));
}

function buildUserMessage({
  moderationDecision,
  autoFlags,
}: {
  moderationDecision: ModerationStatus;
  autoFlags: ModerationAutoFlag[];
}): string {
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

export async function loadMessagingModerationMode(): Promise<MessagingModerationMode> {
  const snapshot = await db.collection(COLLECTIONS.appConfig).doc("marketplace").get();
  const moderation = (snapshot.data()?.moderation ?? {}) as Record<string, unknown>;
  return parseMessagingModerationMode(moderation.messagingMode);
}

export function shouldModerateSynchronouslyBeforeSend(
  mode: MessagingModerationMode,
): boolean {
  return mode === "hidden_until_validated";
}

export function buildPendingMessagingModeration(
  mode: MessagingModerationMode,
): MessagingModerationEvaluation {
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

export function resolveMessagingModerationRecord({
  mode,
  moderationDecision,
}: {
  mode: MessagingModerationMode;
  moderationDecision: ModerationStatus;
}): Pick<MessagingModerationEvaluation, "status" | "visibility"> {
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

export async function evaluateMessagingModeration({
  mode,
  text,
  attachments,
}: {
  mode: MessagingModerationMode;
  text: string;
  attachments: MessagingAttachmentLike[];
}): Promise<MessagingModerationEvaluation> {
  const config = await loadModerationConfig();
  const normalizedText = text.trim();
  const imageAttachments = attachments.filter((attachment) => attachment.type === "image");

  const textEvaluation = normalizedText
    ? await evaluateListingText({
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
      autoFlags: [] as ModerationAutoFlag[],
      textScanStatus: "completed" as const,
      riskScore: 0,
      reason: "clean",
    };

  const imageEvaluation = imageAttachments.length > 0
    ? await moderateListingMedia(imageAttachments.map<ListingMedia>((attachment) => ({
      storagePath: attachment.storagePath,
      downloadUrl: attachment.url,
      thumbnailUrl: attachment.url,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
    })))
    : {
      safeSearchResult: {},
      autoFlags: [] as ModerationAutoFlag[],
      imageScanStatus: "completed" as const,
      riskScore: 0,
    };

  const autoFlags = uniqueFlags([
    ...textEvaluation.autoFlags,
    ...imageEvaluation.autoFlags,
  ]);
  const riskScore = Math.max(textEvaluation.riskScore, imageEvaluation.riskScore);
  const decision = computeModerationDecision({
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
