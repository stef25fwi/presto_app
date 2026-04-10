"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.trackUserLogin = exports.reportPasswordChanged = exports.requestEmailVerificationEmail = exports.requestLoginOtpEmail = exports.requestPasswordResetEmail = void 0;
const node_crypto_1 = require("node:crypto");
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("../../core/firestore");
const env_1 = require("../../config/env");
const constants_1 = require("../../shared/constants");
const hash_1 = require("../../utils/hash");
const ACCOUNT_CONTINUE_URL = "https://presto.app/mon-compte";
function extractFirstName(...values) {
    for (const value of values) {
        const firstName = String(value || "").trim().split(" ")[0] || "";
        if (firstName)
            return firstName;
    }
    return "";
}
function getRequestIp(request) {
    const rawRequest = request?.rawRequest;
    const forwardedFor = rawRequest?.headers?.["x-forwarded-for"];
    if (typeof forwardedFor === "string" && forwardedFor.trim()) {
        const firstForwarded = forwardedFor
            .split(",")
            .map((value) => value.trim())
            .find((value) => value.length > 0);
        return firstForwarded || "unknown";
    }
    if (Array.isArray(forwardedFor) && forwardedFor.length > 0) {
        return String(forwardedFor[0] || "").trim() || "unknown";
    }
    const directIp = String(rawRequest?.ip || rawRequest?.socket?.remoteAddress || "").trim();
    return directIp || "unknown";
}
function getRequestUserAgent(request) {
    const rawRequest = request?.rawRequest;
    const userAgent = rawRequest?.headers?.["user-agent"];
    return String(userAgent || "unknown").trim() || "unknown";
}
function buildDeviceLabel(platform, deviceType, authMethod) {
    return [platform, deviceType, authMethod].filter((value) => value.trim().length > 0).join(" / ");
}
function buildActionCodeSettings() {
    return {
        url: ACCOUNT_CONTINUE_URL,
        handleCodeInApp: false,
    };
}
exports.requestPasswordResetEmail = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const rawEmail = String(request.data?.email || "").trim().toLowerCase();
    if (!rawEmail || !rawEmail.includes("@")) {
        return { ok: true };
    }
    try {
        const userRecord = await firebase_admin_1.default.auth().getUserByEmail(rawEmail);
        const verificationLink = await firebase_admin_1.default.auth().generatePasswordResetLink(rawEmail, buildActionCodeSettings());
        const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userRecord.uid).get();
        const userData = userSnap.data() ?? {};
        const now = Date.now();
        const eventId = `evt_user_password_reset_requested_${userRecord.uid}_${now}`;
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
            event_id: eventId,
            event_name: "user.password_reset.requested",
            source_collection: constants_1.COLLECTIONS.users,
            source_id: userRecord.uid,
            recipient_user_id: userRecord.uid,
            dedupe_key: (0, hash_1.sha256)(`user.password_reset.requested:${userRecord.uid}:${Math.floor(now / (10 * 60 * 1000))}`),
            occurred_at: now,
            payload: {
                recipient_email: rawEmail,
                firstName: String(userData.displayName || userData.display_name || userRecord.displayName || "").split(" ")[0] || "",
                resetUrl: verificationLink,
            },
            status: "created",
        });
    }
    catch (error) {
        const code = error?.code || "";
        if (code === "auth/user-not-found") {
            return { ok: true };
        }
        throw new https_1.HttpsError("internal", "password reset request failed");
    }
    return { ok: true };
});
exports.requestLoginOtpEmail = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const rawEmail = String(request.data?.email || "").trim().toLowerCase();
    if (!rawEmail || !rawEmail.includes("@")) {
        return { ok: true };
    }
    try {
        const userRecord = await firebase_admin_1.default.auth().getUserByEmail(rawEmail);
        const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userRecord.uid).get();
        const userData = userSnap.data() ?? {};
        const now = Date.now();
        const expiresInMinutes = 10;
        const otpCode = String((0, node_crypto_1.randomInt)(100000, 1000000));
        const otpHash = (0, hash_1.sha256)(`${userRecord.uid}:${otpCode}`);
        const expiresAt = now + expiresInMinutes * 60 * 1000;
        const eventId = `evt_user_otp_requested_${userRecord.uid}_${Math.floor(now / (5 * 60 * 1000))}`;
        await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(userRecord.uid).set({
            emailLoginOtp: {
                code_hash: otpHash,
                expires_at: expiresAt,
                requested_at: now,
            },
            email_login_otp: {
                code_hash: otpHash,
                expires_at: expiresAt,
                requested_at: now,
            },
            updatedAt: now,
        }, { merge: true });
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
            event_id: eventId,
            event_name: "user.otp.requested",
            source_collection: constants_1.COLLECTIONS.users,
            source_id: userRecord.uid,
            recipient_user_id: userRecord.uid,
            dedupe_key: (0, hash_1.sha256)(`user.otp.requested:${userRecord.uid}:${Math.floor(now / (5 * 60 * 1000))}`),
            occurred_at: now,
            payload: {
                recipient_email: rawEmail,
                firstName: extractFirstName(userData.displayName, userData.display_name, userRecord.displayName),
                otpCode,
                expiresInMinutes,
                device: buildDeviceLabel(String(request.data?.platform || "unknown"), String(request.data?.deviceType || request.data?.platform || "unknown"), String(request.data?.authMethod || "email_otp")),
                ip: getRequestIp(request),
                helpUrl: `${ACCOUNT_CONTINUE_URL}/support`,
            },
            status: "created",
        }, { merge: true });
    }
    catch (error) {
        const code = error?.code || "";
        if (code === "auth/user-not-found") {
            return { ok: true };
        }
        throw new https_1.HttpsError("internal", "otp email request failed");
    }
    return { ok: true };
});
exports.requestEmailVerificationEmail = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const auth = request.auth;
    if (!auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    const userRecord = await firebase_admin_1.default.auth().getUser(auth.uid);
    const email = String(userRecord.email || "").trim().toLowerCase();
    if (!email) {
        throw new https_1.HttpsError("failed-precondition", "missing email");
    }
    if (userRecord.emailVerified) {
        return { ok: true, alreadyVerified: true };
    }
    const verificationUrl = await firebase_admin_1.default.auth().generateEmailVerificationLink(email, buildActionCodeSettings());
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(auth.uid).get();
    const userData = userSnap.data() ?? {};
    const now = Date.now();
    const eventId = `evt_user_email_verification_requested_${auth.uid}_${now}`;
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "user.email_verification.requested",
        source_collection: constants_1.COLLECTIONS.users,
        source_id: auth.uid,
        recipient_user_id: auth.uid,
        dedupe_key: (0, hash_1.sha256)(`user.email_verification.requested:${auth.uid}:${Math.floor(now / (10 * 60 * 1000))}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            firstName: String(userData.displayName || userData.display_name || userRecord.displayName || "").split(" ")[0] || "",
            verificationUrl,
        },
        status: "created",
    });
    return { ok: true };
});
exports.reportPasswordChanged = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const auth = request.auth;
    if (!auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    const userRecord = await firebase_admin_1.default.auth().getUser(auth.uid);
    const email = String(userRecord.email || "").trim().toLowerCase();
    if (!email) {
        throw new https_1.HttpsError("failed-precondition", "missing email");
    }
    const userSnap = await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(auth.uid).get();
    const userData = userSnap.data() ?? {};
    const now = Number(request.data?.changedAt || Date.now());
    const bucket = Math.floor(now / (60 * 60 * 1000));
    const eventId = `evt_user_password_changed_${auth.uid}_${bucket}`;
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(auth.uid).set({
        passwordChangedAt: now,
        password_changed_at: now,
        updatedAt: now,
    }, { merge: true });
    await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
        event_id: eventId,
        event_name: "user.password_changed",
        source_collection: constants_1.COLLECTIONS.users,
        source_id: auth.uid,
        recipient_user_id: auth.uid,
        dedupe_key: (0, hash_1.sha256)(`user.password_changed:${auth.uid}:${bucket}`),
        occurred_at: now,
        payload: {
            recipient_email: email,
            firstName: extractFirstName(userData.displayName, userData.display_name, userRecord.displayName),
        },
        status: "created",
    }, { merge: true });
    return { ok: true };
});
exports.trackUserLogin = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const auth = request.auth;
    if (!auth?.uid) {
        throw new https_1.HttpsError("unauthenticated", "authentication required");
    }
    const authMethod = String(request.data?.authMethod || "unknown").trim().toLowerCase();
    const platform = String(request.data?.platform || "unknown").trim().toLowerCase();
    const deviceType = String(request.data?.deviceType || platform || "unknown").trim().toLowerCase();
    const occurredAt = Number(request.data?.timestamp || Date.now());
    const ip = getRequestIp(request);
    const userAgent = getRequestUserAgent(request);
    const signature = (0, hash_1.sha256)(`${platform}|${deviceType}|${authMethod}|${userAgent}`);
    const device = buildDeviceLabel(platform, deviceType, authMethod) || "device inconnu";
    const userRef = firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(auth.uid);
    const userSnap = await userRef.get();
    const userData = userSnap.data() ?? {};
    const recipientEmail = String(userData.email || auth.token.email || "").trim().toLowerCase();
    const loginSignatures = (userData.login_signatures ?? {});
    const seenSignature = loginSignatures[signature];
    const previousSignature = String(userData.last_login_signature || "").trim();
    const previousLoginAt = Number(userData.lastLoginAt || userData.last_login_at || 0);
    const isSuspicious = Boolean(recipientEmail) && previousLoginAt > 0 && !seenSignature && previousSignature.length > 0 && previousSignature !== signature;
    await userRef.set({
        lastLoginAt: occurredAt,
        last_login_at: occurredAt,
        last_login_signature: signature,
        lastLoginIp: ip,
        last_login_ip: ip,
        lastLoginMeta: {
            authMethod,
            platform,
            deviceType,
            userAgent,
        },
        [`login_signatures.${signature}`]: {
            first_seen_at: seenSignature?.first_seen_at ?? occurredAt,
            last_seen_at: occurredAt,
            auth_method: authMethod,
            platform,
            device_type: deviceType,
            ip,
            user_agent: userAgent,
        },
        updatedAt: occurredAt,
    }, { merge: true });
    if (isSuspicious) {
        const eventId = `evt_user_login_suspicious_${auth.uid}_${signature.slice(0, 16)}`;
        await firestore_1.db.collection(constants_1.COLLECTIONS.emailEvents).doc(eventId).set({
            event_id: eventId,
            event_name: "user.login.suspicious",
            source_collection: constants_1.COLLECTIONS.users,
            source_id: auth.uid,
            recipient_user_id: auth.uid,
            dedupe_key: (0, hash_1.sha256)(`user.login.suspicious:${auth.uid}:${signature}`),
            occurred_at: occurredAt,
            payload: {
                recipient_email: recipientEmail,
                firstName: extractFirstName(userData.displayName, userData.display_name, auth.token.name),
                ip,
                device,
                secureUrl: ACCOUNT_CONTINUE_URL,
            },
            status: "created",
        }, { merge: true });
    }
    return { ok: true, suspicious: isSuspicious };
});
//# sourceMappingURL=callables.js.map