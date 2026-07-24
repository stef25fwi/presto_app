"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.guardedCreateSubscriptionCheckoutSession = void 0;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../config/env");
const callables_1 = require("./callables");
const operating_mode_guard_1 = require("./operating_mode_guard");
exports.guardedCreateSubscriptionCheckoutSession = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    secrets: env_1.STRIPE_CHECKOUT_SECRETS,
    timeoutSeconds: 30,
    minInstances: 1,
    maxInstances: 20,
    concurrency: 80,
    memory: "256MiB",
}, async (request) => {
    const userId = request.auth?.uid;
    if (!userId) {
        throw new https_1.HttpsError("unauthenticated", "Connexion requise pour s’abonner");
    }
    await (0, operating_mode_guard_1.assertCommercialBillingEnabled)(userId);
    return callables_1.createSubscriptionCheckoutSession.run(request);
});
//# sourceMappingURL=guarded_callables.js.map