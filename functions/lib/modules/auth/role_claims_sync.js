"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserRolesChanged = void 0;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const v2_1 = require("firebase-functions/v2");
const constants_1 = require("../../shared/constants");
const roles_1 = require("../marketplace/services/roles");
const ROLE_FIELDS = [
    "roles",
    "primaryRole",
    "admin",
    "superadmin",
    "moderator",
];
function readRolesFromDoc(data) {
    const fromArray = (0, roles_1.normalizeRoles)(data.roles);
    if (fromArray.length > 0) {
        return Array.from(new Set(["user", ...fromArray]));
    }
    const fallback = ["user"];
    if (data.admin === true)
        fallback.push("admin");
    if (data.superadmin === true)
        fallback.push("superadmin");
    if (data.moderator === true)
        fallback.push("moderator");
    if (data.pro === true)
        fallback.push("pro");
    return Array.from(new Set(fallback));
}
function readPrimaryRole(data, roles) {
    const candidate = String(data.primaryRole || "").trim().toLowerCase();
    if (roles.includes(candidate)) {
        return candidate;
    }
    return roles.includes("pro") ? "pro" : roles[0] ?? "user";
}
function shallowEqualRoles(a, b) {
    if (a.length !== b.length)
        return false;
    const sortedA = [...a].sort();
    const sortedB = [...b].sort();
    for (let i = 0; i < sortedA.length; i += 1) {
        if (sortedA[i] !== sortedB[i])
            return false;
    }
    return true;
}
/**
 * Synchronise les custom claims Firebase Auth lorsque le document
 * users/{uid} est écrit avec un changement de rôle. Sert de filet de
 * sécurité pour les cas où la promotion admin est faite via un script
 * Admin SDK ou la console Firebase, et non via le callable
 * applyUserRoleClaims (qui pose déjà les claims directement).
 */
exports.onUserRolesChanged = (0, firestore_1.onDocumentWritten)(`${constants_1.COLLECTIONS.users}/{userId}`, async (event) => {
    const userId = String(event.params.userId || "");
    if (!userId)
        return;
    const before = (event.data?.before?.data() ?? {});
    const after = (event.data?.after?.data() ?? {});
    if (!event.data?.after?.exists) {
        return;
    }
    const roleFieldChanged = ROLE_FIELDS.some((field) => JSON.stringify(before[field]) !== JSON.stringify(after[field]));
    if (!roleFieldChanged) {
        return;
    }
    const roles = readRolesFromDoc(after);
    const primaryRole = readPrimaryRole(after, roles);
    let existingClaims = {};
    try {
        const userRecord = await firebase_admin_1.default.auth().getUser(userId);
        existingClaims = userRecord.customClaims ?? {};
    }
    catch (error) {
        v2_1.logger.warn("[onUserRolesChanged] getUser failed", { userId, error: String(error) });
        return;
    }
    const existingRoles = Array.isArray(existingClaims.roles)
        ? existingClaims.roles
        : [];
    const existingPrimary = String(existingClaims.primaryRole || "");
    const existingAdmin = existingClaims.admin === true;
    const existingSuperadmin = existingClaims.superadmin === true;
    const desiredAdmin = roles.includes("admin");
    const desiredSuperadmin = roles.includes("superadmin");
    if (shallowEqualRoles(existingRoles, roles) &&
        existingPrimary === primaryRole &&
        existingAdmin === desiredAdmin &&
        existingSuperadmin === desiredSuperadmin) {
        return;
    }
    try {
        await firebase_admin_1.default.auth().setCustomUserClaims(userId, {
            ...existingClaims,
            roles,
            primaryRole,
            marketplaceAccess: true,
            pro: roles.includes("pro"),
            moderator: roles.includes("moderator"),
            admin: desiredAdmin,
            superadmin: desiredSuperadmin,
        });
        v2_1.logger.info("[onUserRolesChanged] claims synchronised", {
            userId,
            roles,
            primaryRole,
        });
    }
    catch (error) {
        v2_1.logger.error("[onUserRolesChanged] setCustomUserClaims failed", {
            userId,
            error: String(error),
        });
    }
});
//# sourceMappingURL=role_claims_sync.js.map