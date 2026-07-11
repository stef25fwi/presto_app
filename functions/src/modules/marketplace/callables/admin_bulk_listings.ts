import { HttpsError, onCall } from "firebase-functions/v2/https";
import { ENFORCE_APP_CHECK, PROJECT_REGION } from "../../../config/env";
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
    const actorRoles = extractRolesFromAuthToken(
      request.auth?.token as Record<string, unknown> | undefined,
    );
    requireAnyRole(
      actorRoles,
      ["admin", "superadmin"],
      "Admin role required",
    );

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
          reason,
          results: summary.results,
        },
      });

      return {
        ok: summary.failedCount === 0,
        adminActionId,
        ...summary,
      };
    } catch (error) {
      if (error instanceof AdminBulkListingInputError) {
        throw new HttpsError("invalid-argument", error.message);
      }
      throw toHttpsError(error, "Unable to bulk delete listings");
    }
  },
);
