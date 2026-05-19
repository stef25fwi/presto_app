import { logger } from "../../../core/logger";
import {
  GCP_PROJECT_ID,
  MARKETPLACE_RECAPTCHA_MIN_SCORE,
  RECAPTCHA_ENTERPRISE_SITE_KEY,
} from "../../../config/env";
import type { RecaptchaAction } from "../constants/enums";
import { fetchGoogleApiJson } from "./google_api";

interface RecaptchaAssessmentResponse {
  tokenProperties?: {
    valid?: boolean;
    invalidReason?: string;
    action?: string;
  };
  riskAnalysis?: {
    score?: number;
    reasons?: string[];
  };
}

export interface RecaptchaVerificationResult {
  allowed: boolean;
  score: number;
  reasons: string[];
  action: string;
  tokenValid: boolean;
  actionMatches: boolean;
  meetsScoreThreshold: boolean;
  // True only when Google actually returned an assessment. False when the
  // server is misconfigured, no token was supplied, or the assessment call
  // failed — i.e. when we could not get a verdict at all.
  assessed: boolean;
}

export function shouldRejectListingSubmissionForRecaptcha(
  result: RecaptchaVerificationResult,
): boolean {
  // Only hard-reject on a definitive negative verdict from a completed
  // assessment. A missing server configuration or an assessment error must
  // not block publication — otherwise a single infra problem takes down the
  // whole publish pipeline for every user. Those cases are surfaced via logs.
  if (!result.assessed) {
    return false;
  }
  return !result.tokenValid || !result.actionMatches;
}

function shouldBypassRecaptcha(): boolean {
  return !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
}

export async function verifyRecaptchaAssessment({
  token,
  expectedAction,
  userId,
}: {
  token?: string;
  expectedAction: RecaptchaAction;
  userId?: string;
}): Promise<RecaptchaVerificationResult> {
  if (!RECAPTCHA_ENTERPRISE_SITE_KEY || !GCP_PROJECT_ID) {
    logger.error("marketplace_recaptcha_missing_configuration", {
      expectedAction,
      userId,
      missingSiteKey: !RECAPTCHA_ENTERPRISE_SITE_KEY,
      missingProjectId: !GCP_PROJECT_ID,
    });
    return {
      allowed: false,
      score: 0,
      reasons: ["MISSING_RECAPTCHA_CONFIGURATION"],
      action: expectedAction,
      tokenValid: false,
      actionMatches: false,
      meetsScoreThreshold: false,
      assessed: false,
    };
  }

  if (shouldBypassRecaptcha()) {
    logger.warn("marketplace_recaptcha_bypassed", {
      expectedAction,
      userId,
      bypassReason: "emulator",
    });
    return {
      allowed: true,
      score: 1,
      reasons: ["BYPASS"],
      action: expectedAction,
      tokenValid: true,
      actionMatches: true,
      meetsScoreThreshold: true,
      assessed: true,
    };
  }

  if (!token) {
    logger.warn("marketplace_recaptcha_missing_token", { expectedAction, userId });
    return {
      allowed: false,
      score: 0,
      reasons: ["MISSING_TOKEN"],
      action: expectedAction,
      tokenValid: false,
      actionMatches: false,
      meetsScoreThreshold: false,
      assessed: false,
    };
  }

  const url = `https://recaptchaenterprise.googleapis.com/v1/projects/${encodeURIComponent(GCP_PROJECT_ID)}/assessments`;
  let response: RecaptchaAssessmentResponse;
  try {
    response = await fetchGoogleApiJson<RecaptchaAssessmentResponse>({
      url,
      body: {
        event: {
          token,
          siteKey: RECAPTCHA_ENTERPRISE_SITE_KEY,
          expectedAction,
          userInfo: userId ? { accountId: userId } : undefined,
        },
      },
    });
  } catch (error) {
    logger.warn("marketplace_recaptcha_assessment_failed", {
      expectedAction,
      userId,
      error: error instanceof Error ? error.message : String(error),
    });
    return {
      allowed: false,
      score: 0,
      reasons: ["ASSESSMENT_ERROR"],
      action: expectedAction,
      tokenValid: false,
      actionMatches: false,
      meetsScoreThreshold: false,
      assessed: false,
    };
  }

  const valid = response.tokenProperties?.valid === true;
  const action = String(response.tokenProperties?.action || "").trim();
  const score = Number(response.riskAnalysis?.score || 0);
  const reasons = response.riskAnalysis?.reasons ?? [];
  const actionMatches = action === expectedAction;
  const meetsScoreThreshold = score >= MARKETPLACE_RECAPTCHA_MIN_SCORE;
  const allowed = valid && actionMatches && meetsScoreThreshold;

  return {
    allowed,
    score,
    reasons,
    action,
    tokenValid: valid,
    actionMatches,
    meetsScoreThreshold,
    assessed: true,
  };
}