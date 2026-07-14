"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.adminBulkDeleteListings = void 0;
const https_1 = require("firebase-functions/v2/https");
const env_1 = require("../../../config/env");
const correlation_1 = require("../../../observability/correlation");
const admin_audit_1 = require("../services/admin_audit");
const admin_bulk_listing_policy_1 = require("../services/admin_bulk_listing_policy");
const errors_1 = require("../services/errors");
const roles_1 = require("../services/roles");
const listings_1 = require("./listings");
function requireAuthUid(request) {
    const uid = String(request.auth?.uid || "").trim();
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "Authentication is required");
    }
    return uid;
}
function resolveActorRole(actorRoles) {
    return actorRoles.includes("superadmin") ? "superadmin" : "admin";
}
exports.adminBulkDeleteListings = (0, https_1.onCall)({
    region: env_1.PROJECT_REGION,
    enforceAppCheck: env_1.ENFORCE_APP_CHECK,
    timeoutSeconds: 300,
    memory: "512MiB",
    maxInstances: 5,
}, async (request) => {
    const actorId = requireAuthUid(request);
    const correlationId = (0, correlation_1.resolveCorrelationId)(request.data?.correlationId);
    const logContext = (0, correlation_1.buildOperationLogContext)({
        correlationId,
        operation: "admin_bulk_delete_listings",
        actorId,
    });
    const actorRoles = (0, roles_1.extractRolesFromAuthToken)(request.auth?.token);
    (0, roles_1.requireAnyRole)(actorRoles, ["admin", "superadmin"], "Admin role required");
    console.info("ADMIN_BULK_DELETE_LISTINGS_STARTED", logContext);
    try {
        const listingIds = (0, admin_bulk_listing_policy_1.normalizeAdminBulkListingIds)(request.data?.listingIds);
        const reason = String(request.data?.reason || "").trim().slice(0, 500);
        if (!reason) {
            throw new admin_bulk_listing_policy_1.AdminBulkListingInputError("reason is required");
        }
        const summary = await (0, admin_bulk_listing_policy_1.executeAdminBulkListingDeletion)({
            listingIds,
            deleteOne: async (listingId) => {
                await (0, listings_1.closeOrDeleteListingForOwner)({
                    actorId,
                    listingId,
                    reason,
                    allowAdminDelete: true,
                });
            },
        });
        const adminActionId = await (0, admin_audit_1.writeAdminActionLog)({
            actorId,
            actorRole: resolveActorRole(actorRoles),
            actionType: "bulk_delete_listings",
            targetType: "listing_batch",
            targetId: `bulk_${Date.now()}`,
            before: {
                listingIds,
            },
            after: {
                requestedCount: summary.requestedCount,
                succeededCount: summary.succeededCount,
                failedCount: summary.failedCount,
            },
            metadata: {
                correlationId,
                reason,
                results: summary.results,
            },
        });
        console.info("ADMIN_BULK_DELETE_LISTINGS_COMPLETED", {
            ...logContext,
            adminActionId,
            requestedCount: summary.requestedCount,
            succeededCount: summary.succeededCount,
            failedCount: summary.failedCount,
        });
        return {
            ok: summary.failedCount === 0,
            correlationId,
            adminActionId,
            ...summary,
        };
    }
    catch (error) {
        console.error("ADMIN_BULK_DELETE_LISTINGS_FAILED", {
            ...logContext,
            errorName: error instanceof Error ? error.name : "unknown",
        });
        if (error instanceof admin_bulk_listing_policy_1.AdminBulkListingInputError) {
            throw new https_1.HttpsError("invalid-argument", error.message);
        }
        throw (0, errors_1.toHttpsError)(error, "Unable to bulk delete listings");
    }
});
//# sourceMappingURL=admin_bulk_listings.js.map