"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyRecaptchaAssessment = verifyRecaptchaAssessment;
const logger_1 = require("../../../core/logger");
const env_1 = require("../../../config/env");
const google_api_1 = require("./google_api");
function shouldBypassRecaptcha() {
    return !env_1.RECAPTCHA_ENTERPRISE_SITE_KEY || !env_1.GCP_PROJECT_ID || !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
}
async function verifyRecaptchaAssessment({ token, expectedAction, userId, }) {
    if (shouldBypassRecaptcha()) {
        logger_1.logger.warn("marketplace_recaptcha_bypassed", {
            expectedAction,
            userId,
            bypassReason: !env_1.RECAPTCHA_ENTERPRISE_SITE_KEY ? "missing_site_key" : "emulator_or_missing_project",
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
    const url = `https://recaptchaenterprise.googleapis.com/v1/projects/${encodeURIComponent(env_1.GCP_PROJECT_ID)}/assessments`;
    const response = await (0, google_api_1.fetchGoogleApiJson)({
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
    const valid = response.tokenProperties?.valid === true;
    const action = String(response.tokenProperties?.action || "").trim();
    const score = Number(response.riskAnalysis?.score || 0);
    const reasons = response.riskAnalysis?.reasons ?? [];
    const allowed = valid && action === expectedAction && score >= env_1.MARKETPLACE_RECAPTCHA_MIN_SCORE;
    return {
        allowed,
        score,
        reasons,
        action,
    };
}
//# sourceMappingURL=recaptcha.js.map