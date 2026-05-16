import admin from "firebase-admin";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import {
  MARKETPLACE_AUTO_APPROVE_ENABLED,
  MARKETPLACE_LISTING_DRAFT_LIMIT,
  MARKETPLACE_MAX_MEDIA_COUNT,
  PROJECT_REGION,
} from "../../../config/env";
import { COLLECTIONS } from "../../../shared/constants";
import type { ListingDoc, ListingMedia } from "../models/firestore";
import type {
  ListingStatus,
  ListingVisibility,
  ModerationAutoFlag,
  ModerationStatus,
} from "../constants/enums";
import { fetchGoogleApiJson } from "./google_api";

const SAFE_SEARCH_SCORES: Record<string, number> = {
  UNKNOWN: 0,
  VERY_UNLIKELY: 0,
  UNLIKELY: 10,
  POSSIBLE: 40,
  LIKELY: 70,
  VERY_LIKELY: 100,
};

const DEFAULT_BANNED_TERMS = ["escort", "arme", "fausse carte", "crypto miracle"];
const DEFAULT_RISKY_TERMS = ["telegram", "whatsapp", "paiement avance", "urgent cash"];

export interface ModerationConfig {
  bannedTerms: string[];
  riskyTerms: string[];
  autoApproveEnabled: boolean;
  maxMediaCount: number;
  maxDraftsPerUser: number;
}

export interface ListingRiskInput {
  ownerId: string;
  title: string;
  description: string;
  media: ListingMedia[];
  ownerSignals: {
    moderationStrikeCount: number;
    spamScore: number;
    lastRecaptchaScore?: number;
    recentListingCount: number;
    hasSimilarActiveListing: boolean;
  };
}

export interface ListingRiskEvaluation {
  safeSearchResult: Record<string, unknown>;
  autoFlags: ModerationAutoFlag[];
  riskScore: number;
  imageScanStatus: "pending" | "completed" | "failed";
  textScanStatus: "pending" | "completed" | "failed";
  moderationDecision: ModerationStatus;
  moderationReason: string;
}

interface VisionAnnotateResponse {
  responses?: Array<{
    safeSearchAnnotation?: Record<string, string>;
  }>;
}

function normalizeTerms(values: unknown, fallback: string[]): string[] {
  if (!Array.isArray(values)) {
    return fallback;
  }
  const result = values
    .map((value) => String(value || "").trim().toLowerCase())
    .filter(Boolean);
  return result.length > 0 ? Array.from(new Set(result)) : fallback;
}

function normalizeText(value: string): string {
  return value.toLowerCase().replace(/\s+/g, " ").trim();
}

function includesAnyTerm(source: string, terms: string[]): boolean {
  return terms.some((term) => source.includes(term));
}

function computeSafeSearchRisk(annotation: Record<string, string>): {
  autoFlags: ModerationAutoFlag[];
  score: number;
} {
  const autoFlags = new Set<ModerationAutoFlag>();
  let score = 0;

  const adultScore = Math.max(
    SAFE_SEARCH_SCORES[annotation.adult || "UNKNOWN"] || 0,
    SAFE_SEARCH_SCORES[annotation.racy || "UNKNOWN"] || 0,
  );
  const violenceScore = Math.max(
    SAFE_SEARCH_SCORES[annotation.violence || "UNKNOWN"] || 0,
    SAFE_SEARCH_SCORES[annotation.medical || "UNKNOWN"] || 0,
  );

  if (adultScore >= 40) autoFlags.add("adult_content");
  if (violenceScore >= 40) autoFlags.add("violent_content");

  score += Math.floor(adultScore * 0.35);
  score += Math.floor(violenceScore * 0.35);

  return {
    autoFlags: Array.from(autoFlags),
    score: Math.min(100, score),
  };
}

export async function loadModerationConfig(): Promise<ModerationConfig> {
  const snap = await db.collection(COLLECTIONS.appConfig).doc("marketplace").get();
  const data = (snap.data() ?? {}) as Record<string, unknown>;
  const moderation = (data.moderation ?? {}) as Record<string, unknown>;

  return {
    bannedTerms: normalizeTerms(moderation.bannedTerms, DEFAULT_BANNED_TERMS),
    riskyTerms: normalizeTerms(moderation.riskyTerms, DEFAULT_RISKY_TERMS),
    autoApproveEnabled: typeof moderation.autoApproveEnabled === "boolean"
      ? moderation.autoApproveEnabled
      : MARKETPLACE_AUTO_APPROVE_ENABLED,
    maxMediaCount: typeof moderation.maxMediaCount === "number"
      ? moderation.maxMediaCount
      : MARKETPLACE_MAX_MEDIA_COUNT,
    maxDraftsPerUser: typeof moderation.maxDraftsPerUser === "number"
      ? moderation.maxDraftsPerUser
      : MARKETPLACE_LISTING_DRAFT_LIMIT,
  };
}

export async function moderateListingMedia(media: ListingMedia[]): Promise<{
  safeSearchResult: Record<string, unknown>;
  autoFlags: ModerationAutoFlag[];
  imageScanStatus: "pending" | "completed" | "failed";
  riskScore: number;
}> {
  if (media.length === 0) {
    return {
      safeSearchResult: {},
      autoFlags: [],
      imageScanStatus: "completed",
      riskScore: 0,
    };
  }

  try {
    const bucket = admin.storage().bucket().name;
    const responses = await Promise.all(
      media.map(async (entry) => {
        const imageUri = entry.storagePath.startsWith("gs://")
          ? entry.storagePath
          : `gs://${bucket}/${entry.storagePath}`;
        const response = await fetchGoogleApiJson<VisionAnnotateResponse>({
          url: "https://vision.googleapis.com/v1/images:annotate",
          body: {
            requests: [
              {
                image: { source: { imageUri } },
                features: [{ type: "SAFE_SEARCH_DETECTION" }],
              },
            ],
          },
        });
        return response.responses?.[0]?.safeSearchAnnotation ?? {};
      }),
    );

    const aggregate: Record<string, string> = {};
    let riskScore = 0;
    const flagSet = new Set<ModerationAutoFlag>();

    for (const annotation of responses) {
      for (const [key, value] of Object.entries(annotation)) {
        const currentScore = SAFE_SEARCH_SCORES[aggregate[key] || "UNKNOWN"] || 0;
        const nextScore = SAFE_SEARCH_SCORES[value || "UNKNOWN"] || 0;
        if (nextScore >= currentScore) {
          aggregate[key] = value;
        }
      }

      const result = computeSafeSearchRisk(annotation);
      riskScore = Math.max(riskScore, result.score);
      for (const flag of result.autoFlags) {
        flagSet.add(flag);
      }
    }

    return {
      safeSearchResult: {
        provider: "google_vision_safe_search",
        region: PROJECT_REGION,
        summary: aggregate,
      },
      autoFlags: Array.from(flagSet),
      imageScanStatus: "completed",
      riskScore,
    };
  } catch (error) {
    logger.warn("marketplace_safe_search_failed", {
      error: error instanceof Error ? error.message : String(error),
      mediaCount: media.length,
    });

    return {
      safeSearchResult: {
        provider: "google_vision_safe_search",
        error: error instanceof Error ? error.message : String(error),
      },
      autoFlags: [],
      imageScanStatus: "failed",
      riskScore: 10,
    };
  }
}

export async function evaluateListingText({
  title,
  description,
  ownerSignals,
  config,
}: {
  title: string;
  description: string;
  ownerSignals: ListingRiskInput["ownerSignals"];
  config: ModerationConfig;
}): Promise<{
  autoFlags: ModerationAutoFlag[];
  textScanStatus: "pending" | "completed" | "failed";
  riskScore: number;
  reason: string;
}> {
  const text = normalizeText(`${title} ${description}`);
  const autoFlags = new Set<ModerationAutoFlag>();
  let riskScore = 0;
  const reasons: string[] = [];

  if (includesAnyTerm(text, config.bannedTerms)) {
    autoFlags.add("banned_term");
    riskScore += 65;
    reasons.push("banned_terms_detected");
  }

  if (includesAnyTerm(text, config.riskyTerms)) {
    autoFlags.add("suspicious_text");
    riskScore += 25;
    reasons.push("risky_terms_detected");
  }

  const spamIndicators = ["http://", "https://", "@@", "100%", "!!!"].filter((entry) => text.includes(entry));
  if (spamIndicators.length >= 2) {
    autoFlags.add("spam_pattern");
    riskScore += 20;
    reasons.push("spam_markers_detected");
  }

  if (ownerSignals.hasSimilarActiveListing) {
    autoFlags.add("duplicate_listing");
    riskScore += 20;
    reasons.push("similar_active_listing_detected");
  }

  if (ownerSignals.recentListingCount >= 5) {
    autoFlags.add("too_many_posts");
    riskScore += 20;
    reasons.push("posting_velocity_high");
  }

  if (ownerSignals.spamScore >= 60 || ownerSignals.moderationStrikeCount >= 3) {
    autoFlags.add("risky_user");
    riskScore += 20;
    reasons.push("risky_user_profile");
  }

  if (ownerSignals.lastRecaptchaScore != null && ownerSignals.lastRecaptchaScore < 0.3) {
    riskScore += 15;
    reasons.push("low_recaptcha_score");
  }

  return {
    autoFlags: Array.from(autoFlags),
    textScanStatus: "completed",
    riskScore: Math.min(100, riskScore),
    reason: reasons.join(",") || "clean",
  };
}

export function computeModerationDecision({
  riskScore,
  autoFlags,
}: {
  riskScore: number;
  autoFlags: ModerationAutoFlag[];
}): {
  moderationDecision: ModerationStatus;
  moderationReason: string;
} {
  const severeFlags = new Set<ModerationAutoFlag>(["adult_content", "violent_content", "banned_term"]);
  if (autoFlags.some((flag) => severeFlags.has(flag)) && riskScore >= 70) {
    return {
      moderationDecision: "blocked",
      moderationReason: "high_risk_content_detected",
    };
  }

  if (riskScore >= 55 || autoFlags.includes("duplicate_listing") || autoFlags.includes("too_many_posts")) {
    return {
      moderationDecision: "manual_review",
      moderationReason: "manual_review_required",
    };
  }

  if (riskScore >= 35) {
    return {
      moderationDecision: "auto_flagged",
      moderationReason: "auto_flags_detected",
    };
  }

  return {
    moderationDecision: "approved",
    moderationReason: "approved_automatically",
  };
}

export async function evaluateListingRisk(input: ListingRiskInput): Promise<ListingRiskEvaluation> {
  const config = await loadModerationConfig();
  const [mediaReview, textReview] = await Promise.all([
    moderateListingMedia(input.media),
    evaluateListingText({
      title: input.title,
      description: input.description,
      ownerSignals: input.ownerSignals,
      config,
    }),
  ]);

  const flagSet = new Set<ModerationAutoFlag>([
    ...mediaReview.autoFlags,
    ...textReview.autoFlags,
  ]);
  const riskScore = Math.min(100, mediaReview.riskScore + textReview.riskScore);
  const decision = computeModerationDecision({
    riskScore,
    autoFlags: Array.from(flagSet),
  });

  return {
    safeSearchResult: mediaReview.safeSearchResult,
    autoFlags: Array.from(flagSet),
    riskScore,
    imageScanStatus: mediaReview.imageScanStatus,
    textScanStatus: textReview.textScanStatus,
    moderationDecision: decision.moderationDecision,
    moderationReason: decision.moderationReason,
  };
}

export function finalizeListingPublication({
  evaluation,
  now,
  autoApproveEnabled,
  autoPublishAfter,
}: {
  evaluation: ListingRiskEvaluation;
  now: FirebaseFirestore.FieldValue;
  autoApproveEnabled?: boolean;
  autoPublishAfter?: FirebaseFirestore.Timestamp | null;
}): Pick<ListingDoc, "status" | "moderationStatus" | "visibility" | "publishedAt" | "riskScore" | "autoPublishAfter"> {
  const allowAutoApproval = autoApproveEnabled ?? MARKETPLACE_AUTO_APPROVE_ENABLED;

  if (evaluation.moderationDecision === "approved" && allowAutoApproval && autoPublishAfter) {
    return {
      status: "pending",
      moderationStatus: "approved",
      visibility: "private",
      publishedAt: null,
      autoPublishAfter,
      riskScore: evaluation.riskScore,
    };
  }

  if (evaluation.moderationDecision === "approved" && allowAutoApproval) {
    return {
      status: "active",
      moderationStatus: "approved",
      visibility: "public",
      publishedAt: now,
      autoPublishAfter: null,
      riskScore: evaluation.riskScore,
    };
  }

  if (evaluation.moderationDecision === "approved") {
    return {
      status: "pending",
      moderationStatus: "pending",
      visibility: "private",
      publishedAt: null,
      autoPublishAfter: null,
      riskScore: evaluation.riskScore,
    };
  }

  if (evaluation.moderationDecision === "blocked") {
    return {
      status: "rejected",
      moderationStatus: "blocked",
      visibility: "hidden",
      publishedAt: null,
      autoPublishAfter: null,
      riskScore: evaluation.riskScore,
    };
  }

  const moderationStatus: ModerationStatus = evaluation.moderationDecision === "auto_flagged"
    ? "auto_flagged"
    : "manual_review";
  const status: ListingStatus = evaluation.moderationDecision === "rejected" ? "rejected" : "pending";
  const visibility: ListingVisibility = evaluation.moderationDecision === "rejected" ? "hidden" : "private";

  return {
    status,
    moderationStatus,
    visibility,
    publishedAt: null,
    autoPublishAfter: null,
    riskScore: evaluation.riskScore,
  };
}

export async function persistModerationResult({
  listingId,
  ownerId,
  evaluation,
  autoApproveEnabled,
  autoPublishAfter,
}: {
  listingId: string;
  ownerId: string;
  evaluation: ListingRiskEvaluation;
  autoApproveEnabled?: boolean;
  autoPublishAfter?: FirebaseFirestore.Timestamp | null;
}): Promise<Pick<ListingDoc, "status" | "moderationStatus" | "visibility" | "publishedAt" | "riskScore" | "autoPublishAfter">> {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const listingPatch = finalizeListingPublication({
    evaluation,
    now,
    autoApproveEnabled,
    autoPublishAfter,
  });

  await Promise.all([
    db.collection(COLLECTIONS.listingModeration).doc(listingId).set({
      id: listingId,
      listingId,
      ownerId,
      safeSearchResult: evaluation.safeSearchResult,
      autoFlags: evaluation.autoFlags,
      moderationDecision: evaluation.moderationDecision,
      moderationReason: evaluation.moderationReason,
      source: "automatic",
      imageScanStatus: evaluation.imageScanStatus,
      textScanStatus: evaluation.textScanStatus,
      riskScore: evaluation.riskScore,
      createdAt: now,
      updatedAt: now,
    }, { merge: true }),
    db.collection(COLLECTIONS.listings).doc(listingId).set({
      moderationStatus: listingPatch.moderationStatus,
      status: listingPatch.status,
      visibility: listingPatch.visibility,
      publishedAt: listingPatch.publishedAt,
      autoPublishAfter: listingPatch.autoPublishAfter ?? null,
      riskScore: listingPatch.riskScore,
      updatedAt: now,
    }, { merge: true }),
  ]);

  return listingPatch;
}