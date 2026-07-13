import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
import {
  buildOperationLogContext,
  resolveCorrelationId,
} from "../../../observability/correlation";
import { writeAdminActionLog } from "../services/admin_audit";
import {
  AdminBulkListingInputError,
  executeAdminBulkListingDeletion,
  normalizeAdminBulkListingIds,
} from "../services/admin_bulk_listing_policy";
import { toHttpsError } from "../services/errors";
import {
  extractRolesFromAuthToken,
  requireAnyRole,
} from "../services/roles";
import type { UserRole } from "../constants/enums";
import { closeOrDeleteListingForOwner } from "./listings";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function resolveActorRole(actorRoles: readonly UserRole[]): UserRole {
  return actorRoles.includes("superadmin") ? "superadmin" : "admin";
}

export const adminBulkDeleteListings = onCall(
  {
    region: PROJECT_REGION,
    enforceAppCheck: ENFORCE_APP_CHECK,
    timeoutSeconds: 300,
    memory: "512MiB",
    maxInstances: 5,
  },
  async (request) => {
    const actorId = requireAuthUid(request);
    const correlationId = resolveCorrelationId(request.data?.correlationId);
    const logContext = buildOperationLogContext({
      correlationId,
      operation: "admin_bulk_delete_listings",
      actorId,
    });
    const actorRoles = extractRolesFromAuthToken(
      request.auth?.token as Record<string, unknown> | undefined,
    );
    requireAnyRole(
      actorRoles,
      ["admin", "superadmin"],
      "Admin role required",
    );

    console.info("ADMIN_BULK_DELETE_LISTINGS_STARTED", logContext);

    try {
      const listingIds = normalizeAdminBulkListingIds(
        request.data?.listingIds,
      );
      const reason = String(request.data?.reason || "").trim().slice(0, 500);
      if (!reason) {
        throw new AdminBulkListingInputError("reason is required");
      }

      const summary = await executeAdminBulkListingDeletion({
        listingIds,
        deleteOne: async (listingId) => {
          await closeOrDeleteListingForOwner({
            actorId,
            listingId,
            reason,
            allowAdminDelete: true,
          });
        },
      });

      const adminActionId = await writeAdminActionLog({
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
    } catch (error) {
      console.error("ADMIN_BULK_DELETE_LISTINGS_FAILED", {
        ...logContext,
        errorName: error instanceof Error ? error.name : "unknown",
      });
      if (error instanceof AdminBulkListingInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw toHttpsError(error, "Unable to bulk delete listings");
    }
  },
);
