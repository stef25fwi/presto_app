"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.monitorServerEvent = monitorServerEvent;
const logger = __importStar(require("firebase-functions/logger"));
const firestore_1 = require("firebase-admin/firestore");
async function monitorServerEvent(params) {
    const payload = {
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        createdAtClient: new Date().toISOString(),
        level: params.level,
        scope: params.scope,
        action: params.action,
        message: params.message ?? null,
        userId: params.userId ?? "server",
        platform: "firebase_functions",
        data: cleanData(params.data ?? {}),
    };
    if (params.level === "error" || params.level === "critical") {
        logger.error(`[MONITORING][${params.scope}][${params.action}]`, payload);
    }
    else if (params.level === "warning") {
        logger.warn(`[MONITORING][${params.scope}][${params.action}]`, payload);
    }
    else {
        logger.info(`[MONITORING][${params.scope}][${params.action}]`, payload);
    }
    await (0, firestore_1.getFirestore)().collection("app_monitoring_events").add(payload);
}
function cleanData(data) {
    const blocked = [
        "password",
        "token",
        "secret",
        "authorization",
        "stripeSecret",
        "apiKey",
        "card",
        "iban",
    ];
    const out = {};
    for (const [key, value] of Object.entries(data)) {
        const lower = key.toLowerCase();
        if (blocked.some((blockedKey) => lower.includes(blockedKey))) {
            out[key] = "[redacted]";
            continue;
        }
        const text = typeof value === "string" ? value : JSON.stringify(value);
        out[key] = text && text.length > 800
            ? `${text.substring(0, 800)}...[truncated]`
            : value;
    }
    return out;
}
//# sourceMappingURL=monitoring.js.map