import { onCall, HttpsError } from "firebase-functions/v2/https";
import { PROJECT_REGION } from "../../../config/env";
import { writeAdminActionLog } from "../services/admin_audit";
import { extractRolesFromAuthToken, requireAnyRole, syncMarketplaceClaims } from "../services/roles";
import { toHttpsError } from "../services/errors";
import { validateRoleAssignment } from "../validators/listings";
import type { UserRole } from "../constants/enums";

function requireAuthUid(request: { auth?: { uid?: string } }): string {
  const uid = String(request.auth?.uid || "").trim();
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required");
  }
  return uid;
}

function resolveActorRole(actorRoles: readonly UserRole[]): UserRole {
  const ordered: UserRole[] = ["superadmin", "admin", "moderator", "pro", "user"];
  return ordered.find((role) => actorRoles.includes(role)) ?? "user";
}

export const applyUserRoleClaims = onCall({ region: PROJECT_REGION }, async (request) => {
  const actorId = requireAuthUid(request);
  const actorRoles = extractRolesFromAuthToken(request.auth?.token as Record<string, unknown> | undefined);
  requireAnyRole(actorRoles, ["admin", "superadmin"], "Admin role required");

  try {
    const targetUserId = String(request.data?.targetUserId || "").trim();
    const roles = validateRoleAssignment(request.data?.roles);
    const actorRole = resolveActorRole(actorRoles);

    if (!targetUserId) {
      throw new HttpsError("invalid-argument", "targetUserId is required");
    }
    if (roles.includes("superadmin") && !actorRoles.includes("superadmin")) {
      throw new HttpsError("permission-denied", "Only a superadmin can grant the superadmin role");
    }

    await syncMarketplaceClaims({
      targetUserId,
      roles,
    });

    await writeAdminActionLog({
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
  } catch (error) {
    throw toHttpsError(error, "Unable to apply user role claims");
  }
});

export const logAdminAction = onCall({ region: PROJECT_REGION }, async (request) => {
  const actorId = requireAuthUid(request);
  const actorRoles = extractRolesFromAuthToken(request.auth?.token as Record<string, unknown> | undefined);
  requireAnyRole(actorRoles, ["admin", "superadmin", "moderator"], "Moderator role required");

  try {
    const actorRole = resolveActorRole(actorRoles);
    const actionType = String(request.data?.actionType || "").trim();
    const targetType = String(request.data?.targetType || "").trim();
    const targetId = String(request.data?.targetId || "").trim();

    if (!actionType || !targetType || !targetId) {
      throw new HttpsError("invalid-argument", "actionType, targetType and targetId are required");
    }

    const adminActionId = await writeAdminActionLog({
      actorId,
      actorRole,
      actionType,
      targetType,
      targetId,
      before: request.data?.before as Record<string, unknown> | undefined,
      after: request.data?.after as Record<string, unknown> | undefined,
      metadata: request.data?.metadata as Record<string, unknown> | undefined,
    });

    return {
      ok: true,
      adminActionId,
    };
  } catch (error) {
    throw toHttpsError(error, "Unable to log admin action");
  }
});