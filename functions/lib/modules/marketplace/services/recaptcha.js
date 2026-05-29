"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.shouldRejectListingSubmissionForRecaptcha = shouldRejectListingSubmissionForRecaptcha;
exports.shouldHardRejectForRecaptcha = shouldHardRejectForRecaptcha;
exports.verifyRecaptchaAssessment = verifyRecaptchaAssessment;
const logger_1 = require("../../../core/logger");
const env_1 = require("../../../config/env");
const google_api_1 = require("./google_api");
function shouldRejectListingSubmissionForRecaptcha(result) {
    return shouldHardRejectForRecaptcha(result);
}
function shouldHardRejectForRecaptcha(result) {
    // Only hard-reject on a definitive negative verdict from a completed
    // assessment. A missing server configuration or an assessment error must
    // not block user flows — otherwise a single infra problem takes down the
    // marketplace for every user. Those cases are surfaced via logs.
    if (!result.assessed) {
        return false;
    }
    return !result.tokenValid || !result.actionMatches;
}
function shouldBypassRecaptcha() {
    return !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
}
async function verifyRecaptchaAssessment({ token, expectedAction, userId, }) {
    if (!env_1.RECAPTCHA_ENTERPRISE_SITE_KEY || !env_1.GCP_PROJECT_ID) {
        logger_1.logger.error("marketplace_recaptcha_missing_configuration", {
            expectedAction,
            userId,
            missingSiteKey: !env_1.RECAPTCHA_ENTERPRISE_SITE_KEY,
            missingProjectId: !env_1.GCP_PROJECT_ID,
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
        logger_1.logger.warn("marketplace_recaptcha_bypassed", {
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
        logger_1.logger.warn("marketplace_recaptcha_missing_token", { expectedAction, userId });
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
    const url = `https://recaptchaenterprise.googleapis.com/v1/projects/${encodeURIComponent(env_1.GCP_PROJECT_ID)}/assessments`;
    let response;
    try {
        response = await (0, google_api_1.fetchGoogleApiJson)({
            url,
            body: {
                event: {
                    token,
                    siteKey: env_1.RECAPTCHA_ENTERPRISE_SITE_KEY,
                    expectedAction,
                    userInfo: userId ? { accountId: userId } : undefined,
                },
            },
        });
    }
    catch (error) {
        logger_1.logger.warn("marketplace_recaptcha_assessment_failed", {
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
    const meetsScoreThreshold = score >= env_1.MARKETPLACE_RECAPTCHA_MIN_SCORE;
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
//# sourceMappingURL=recaptcha.js.map