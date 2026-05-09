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
    };
  }

  if (!token) {
    return {
      allowed: false,
      score: 0,
      reasons: ["MISSING_TOKEN"],
      action: expectedAction,
    };
  }

  const url = `https://recaptchaenterprise.googleapis.com/v1/projects/${encodeURIComponent(GCP_PROJECT_ID)}/assessments`;
  const response = await fetchGoogleApiJson<RecaptchaAssessmentResponse>({
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

  const valid = response.tokenProperties?.valid === true;
  const action = String(response.tokenProperties?.action || "").trim();
  const score = Number(response.riskAnalysis?.score || 0);
  const reasons = response.riskAnalysis?.reasons ?? [];
  const allowed = valid && action === expectedAction && score >= MARKETPLACE_RECAPTCHA_MIN_SCORE;

  return {
    allowed,
    score,
    reasons,
    action,
  };
}