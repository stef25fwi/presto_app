"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PROJECT_REGION = exports.EMAIL_FROM = exports.DEFAULT_TIMEZONE = exports.DEFAULT_LOCALE = exports.EMAIL_PROVIDER_NAME = exports.EMAIL_PROVIDER_WEBHOOK_SECRET = exports.EMAIL_PROVIDER_API_KEY = void 0;
const params_1 = require("firebase-functions/params");
exports.EMAIL_PROVIDER_API_KEY = (0, params_1.defineSecret)("EMAIL_PROVIDER_API_KEY");
exports.EMAIL_PROVIDER_WEBHOOK_SECRET = (0, params_1.defineSecret)("EMAIL_PROVIDER_WEBHOOK_SECRET");
exports.EMAIL_PROVIDER_NAME = process.env.EMAIL_PROVIDER_NAME || "resend";
exports.DEFAULT_LOCALE = (process.env.DEFAULT_LOCALE || "fr");
exports.DEFAULT_TIMEZONE = process.env.DEFAULT_TIMEZONE || "Europe/Paris";
exports.EMAIL_FROM = process.env.EMAIL_FROM || "PRESTO <no-reply@presto.app>";
exports.PROJECT_REGION = process.env.FUNCTION_REGION || "europe-west1";
//# sourceMappingURL=env.js.map