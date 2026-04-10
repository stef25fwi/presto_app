"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.logAdminAction = exports.applyUserRoleClaims = void 0;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const admin_audit_1 = require("../services/admin_audit");
const roles_1 = require("../services/roles");
const errors_1 = require("../services/errors");
const listings_1 = require("../validators/listings");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function resolveActorRole(actorRoles) {
    const ordered = ["superadmin", "admin", "moderator", "pro", "user"];
    return ordered.find((role) => actorRoles.includes(role)) ?? "user";
}
exports.applyUserRoleClaims = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    (0, roles_1.requireAnyRole)(actorRoles, ["admin", "superadmin"], "Admin role required");
    try {
        const targetUserId = String(request.data?.targetUserId || "").trim();
        const roles = (0, listings_1.validateRoleAssignment)(request.data?.roles);
        const actorRole = resolveActorRole(actorRoles);
        if (!targetUserId) {
            throw new https_1.HttpsError("invalid-argument", "targetUserId is required");
        }
        if (roles.includes("superadmin") && !actorRoles.includes("superadmin")) {
            throw new https_1.HttpsError("permission-denied", "Only a superadmin can grant the superadmin role");
        }
        await (0, roles_1.syncMarketplaceClaims)({
            targetUserId,
            roles,
        });
        await (0, admin_audit_1.writeAdminActionLog)({
            actorId,
            actorRole,
            actionType: "apply_user_role_claims",
            targetType: "user",
            targetId: targetUserId,
            after: {
                roles,
            },
            metadata: {
                reason: String(request.data?.reason || "").trim() || null,
            },
        });
        return {
            ok: true,
            targetUserId,
            roles,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to apply user role claims");
    }
});
exports.logAdminAction = (0, https_1.onCall)({ region: env_1.PROJECT_REGION, enforceAppCheck: env_1.ENFORCE_APP_CHECK }, async (request) => {
    const actorId = requireAuthUid(request);
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    (0, roles_1.requireAnyRole)(actorRoles, ["admin", "superadmin", "moderator"], "Moderator role required");
    try {
        const actorRole = resolveActorRole(actorRoles);
        const actionType = String(request.data?.actionType || "").trim();
        const targetType = String(request.data?.targetType || "").trim();
        const targetId = String(request.data?.targetId || "").trim();
        if (!actionType || !targetType || !targetId) {
            throw new https_1.HttpsError("invalid-argument", "actionType, targetType and targetId are required");
        }
        const adminActionId = await (0, admin_audit_1.writeAdminActionLog)({
            actorId,
            actorRole,
            actionType,
            targetType,
            targetId,
            before: request.data?.before,
            after: request.data?.after,
            metadata: request.data?.metadata,
        });
        return {
            ok: true,
            adminActionId,
        };
    }
    catch (error) {
        throw (0, errors_1.toHttpsError)(error, "Unable to log admin action");
    }
});
//# sourceMappingURL=admin.js.map