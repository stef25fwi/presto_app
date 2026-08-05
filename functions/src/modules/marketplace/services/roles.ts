import admin from "../../../core/firebase_admin_compat";
import { HttpsError } from "firebase-functions/v2/https";
import { db } from "../../../core/firestore";
import { COLLECTIONS } from "../../../shared/constants";
import { USER_ROLES, type UserRole } from "../constants/enums";

function normalizeRole(value: unknown): UserRole | null {
  return USER_ROLES.includes(value as UserRole) ? value as UserRole : null;
}

export function normalizeRoles(values: unknown): UserRole[] {
  if (!Array.isArray(values)) {
    return [];
  }

  const roles = values
    .map((value) => normalizeRole(String(value || "").trim()))
    .filter((value): value is UserRole => value != null);

  const unique = Array.from(new Set(roles));
  if (!unique.includes("user")) {
    unique.unshift("user");
  }
  return unique;
}

export function extractRolesFromAuthToken(token: Record<string, unknown> | undefined): UserRole[] {
  if (!token) {
    return ["user"];
  }

  const rolesFromArray = normalizeRoles(token.roles);
  if (rolesFromArray.length > 0) {
    return rolesFromArray;
  }

  const fallbackRoles: UserRole[] = ["user"];
  if (token.pro === true) fallbackRoles.push("pro");
  if (token.moderator === true) fallbackRoles.push("moderator");
  if (token.admin === true) fallbackRoles.push("admin");
  if (token.superadmin === true) fallbackRoles.push("superadmin");
  return Array.from(new Set(fallbackRoles));
}

export function requireAnyRole(actorRoles: readonly UserRole[], allowedRoles: readonly UserRole[], message: string): void {
  if (!actorRoles.some((role) => allowedRoles.includes(role))) {
    throw new HttpsError("permission-denied", message);
  }
}

export async function syncMarketplaceClaims({
  targetUserId,
  roles,
}: {
  targetUserId: string;
  roles: UserRole[];
}): Promise<void> {
  const normalizedRoles = Array.from(new Set(["user", ...normalizeRoles(roles)]));
  const primaryRole = normalizedRoles.includes("pro") ? "pro" : normalizedRoles[0] ?? "user";

  await admin.auth().setCustomUserClaims(targetUserId, {
    roles: normalizedRoles,
    primaryRole,
    marketplaceAccess: true,
    pro: normalizedRoles.includes("pro"),
    moderator: normalizedRoles.includes("moderator"),
    admin: normalizedRoles.includes("admin"),
    superadmin: normalizedRoles.includes("superadmin"),
  });

  await db.collection(COLLECTIONS.users).doc(targetUserId).set({
    roles: normalizedRoles,
    primaryRole,
    lastRoleSyncAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}