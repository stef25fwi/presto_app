"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getStripeClient = getStripeClient;
const stripe_1 = __importDefault(require("stripe"));
const env_1 = require("../../config/env");
let cachedClient = null;
/**
 * Lazily builds the Stripe SDK client. Must only be called from inside a
 * function handler (never at module scope) since Secret Manager values are
 * only resolved once the function actually runs.
 */
function getStripeClient() {
    if (cachedClient)
        return cachedClient;
    const secretKey = env_1.STRIPE_SECRET_KEY.value();
    if (!secretKey) {
        throw new Error("STRIPE_SECRET_KEY is not configured");
    }
    cachedClient = new stripe_1.default(secretKey, {
        apiVersion: "2026-06-24.dahlia",
    });
    return cachedClient;
}
//# sourceMappingURL=stripe_client.js.map