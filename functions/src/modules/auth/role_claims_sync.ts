import admin from "../../core/firebase_admin_compat";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { COLLECTIONS } from "../../shared/constants";
import { normalizeRoles } from "../marketplace/services/roles";
import type { UserRole } from "../marketplace/constants/enums";

const ROLE_FIELDS = [
  "roles",
  "primaryRole",
  "admin",
  "superadmin",
  "moderator",
] as const;

function readRolesFromDoc(data: Record<string, unknown>): UserRole[] {
  const fromArray = normalizeRoles(data.roles);
  if (fromArray.length > 0) {
    return Array.from(new Set(["user", ...fromArray]));
  }

  const fallback: UserRole[] = ["user"];
  if (data.admin === true) fallback.push("admin");
  if (data.superadmin === true) fallback.push("superadmin");
  if (data.moderator === true) fallback.push("moderator");
  if (data.pro === true) fallback.push("pro");
  return Array.from(new Set(fallback));
}

function readPrimaryRole(
  data: Record<string, unknown>,
  roles: UserRole[],
): UserRole {
  const candidate = String(data.primaryRole || "").trim().toLowerCase();
  if (roles.includes(candidate as UserRole)) {
    return candidate as UserRole;
  }
  return roles.includes("pro") ? "pro" : roles[0] ?? "user";
}

function shallowEqualRoles(a: readonly string[], b: readonly string[]): boolean {
  if (a.length !== b.length) return false;
  const sortedA = [...a].sort();
  const sortedB = [...b].sort();
  for (let i = 0; i < sortedA.length; i += 1) {
    if (sortedA[i] !== sortedB[i]) return false;
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
export const onUserRolesChanged = onDocumentWritten(
  `${COLLECTIONS.users}/{userId}`,
  async (event) => {
    const userId = String(event.params.userId || "");
    if (!userId) return;

    const before = (event.data?.before?.data() ?? {}) as Record<string, unknown>;
    const after = (event.data?.after?.data() ?? {}) as Record<string, unknown>;

    if (!event.data?.after?.exists) {
      return;
    }

    const roleFieldChanged = ROLE_FIELDS.some(
      (field) => JSON.stringify(before[field]) !== JSON.stringify(after[field]),
    );
    if (!roleFieldChanged) {
      return;
    }

    const roles = readRolesFromDoc(after);
    const primaryRole = readPrimaryRole(after, roles);

    let existingClaims: Record<string, unknown> = {};
    try {
      const userRecord = await admin.auth().getUser(userId);
      existingClaims = userRecord.customClaims ?? {};
    } catch (error) {
      logger.warn("[onUserRolesChanged] getUser failed", { userId, error: String(error) });
      return;
    }

    const existingRoles = Array.isArray(existingClaims.roles)
      ? (existingClaims.roles as string[])
      : [];
    const existingPrimary = String(existingClaims.primaryRole || "");
    const existingAdmin = existingClaims.admin === true;
    const existingSuperadmin = existingClaims.superadmin === true;

    const desiredAdmin = roles.includes("admin");
    const desiredSuperadmin = roles.includes("superadmin");

    if (
      shallowEqualRoles(existingRoles, roles) &&
      existingPrimary === primaryRole &&
      existingAdmin === desiredAdmin &&
      existingSuperadmin === desiredSuperadmin
    ) {
      return;
    }

    try {
      await admin.auth().setCustomUserClaims(userId, {
        ...existingClaims,
        roles,
        primaryRole,
        marketplaceAccess: true,
        pro: roles.includes("pro"),
        moderator: roles.includes("moderator"),
        admin: desiredAdmin,
        superadmin: desiredSuperadmin,
      });
      logger.info("[onUserRolesChanged] claims synchronised", {
        userId,
        roles,
        primaryRole,
      });
    } catch (error) {
      logger.error("[onUserRolesChanged] setCustomUserClaims failed", {
        userId,
        error: String(error),
      });
    }
  },
);
