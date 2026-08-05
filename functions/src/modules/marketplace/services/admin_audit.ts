import admin from "../../../core/firebase_admin_compat";
import { db } from "../../../core/firestore";
import { logger } from "../../../core/logger";
import { COLLECTIONS } from "../../../shared/constants";
import type { UserRole } from "../constants/enums";

export async function writeAdminActionLog({
  actorId,
  actorRole,
  actionType,
  targetType,
  targetId,
  before,
  after,
  metadata,
}: {
  actorId: string;
  actorRole: UserRole;
  actionType: string;
  targetType: string;
  targetId: string;
  before?: Record<string, unknown>;
  after?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
}): Promise<string> {
  const ref = db.collection(COLLECTIONS.adminActions).doc();
  await ref.set({
    id: ref.id,
    actorId,
    actorRole,
    actionType,
    targetType,
    targetId,
    before: before ?? null,
    after: after ?? null,
    metadata: metadata ?? {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("marketplace_admin_action_logged", {
    adminActionId: ref.id,
    actorId,
    actorRole,
    actionType,
    targetType,
    targetId,
  });

  return ref.id;
}