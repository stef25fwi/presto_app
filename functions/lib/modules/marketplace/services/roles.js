"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizeRoles = normalizeRoles;
exports.extractRolesFromAuthToken = extractRolesFromAuthToken;
exports.requireAnyRole = requireAnyRole;
exports.syncMarketplaceClaims = syncMarketplaceClaims;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("../../../core/firestore");
const constants_1 = require("../../../shared/constants");
const enums_1 = require("../constants/enums");
function normalizeRole(value) {
    return enums_1.USER_ROLES.includes(value) ? value : null;
}
function normalizeRoles(values) {
    if (!Array.isArray(values)) {
        return [];
    }
    const roles = values
        .map((value) => normalizeRole(String(value || "").trim()))
        .filter((value) => value != null);
    const unique = Array.from(new Set(roles));
    if (!unique.includes("user")) {
        unique.unshift("user");
    }
    return unique;
}
function extractRolesFromAuthToken(token) {
    if (!token) {
        return ["user"];
    }
    const rolesFromArray = normalizeRoles(token.roles);
    if (rolesFromArray.length > 0) {
        return rolesFromArray;
    }
    const fallbackRoles = ["user"];
    if (token.pro === true)
        fallbackRoles.push("pro");
    if (token.moderator === true)
        fallbackRoles.push("moderator");
    if (token.admin === true)
        fallbackRoles.push("admin");
    if (token.superadmin === true)
        fallbackRoles.push("superadmin");
    return Array.from(new Set(fallbackRoles));
}
function requireAnyRole(actorRoles, allowedRoles, message) {
    if (!actorRoles.some((role) => allowedRoles.includes(role))) {
        throw new https_1.HttpsError("permission-denied", message);
    }
}
async function syncMarketplaceClaims({ targetUserId, roles, }) {
    const normalizedRoles = Array.from(new Set(["user", ...normalizeRoles(roles)]));
    const primaryRole = normalizedRoles.includes("pro") ? "pro" : normalizedRoles[0] ?? "user";
    await firebase_admin_1.default.auth().setCustomUserClaims(targetUserId, {
        roles: normalizedRoles,
        primaryRole,
        marketplaceAccess: true,
        pro: normalizedRoles.includes("pro"),
        moderator: normalizedRoles.includes("moderator"),
        admin: normalizedRoles.includes("admin"),
        superadmin: normalizedRoles.includes("superadmin"),
    });
    await firestore_1.db.collection(constants_1.COLLECTIONS.users).doc(targetUserId).set({
        roles: normalizedRoles,
        primaryRole,
        lastRoleSyncAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
        updatedAt: firebase_admin_1.default.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
//# sourceMappingURL=roles.js.map