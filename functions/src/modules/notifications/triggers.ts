import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { refreshUnreadNotificationCount } from "./counters";

export const onNotificationCreated = onDocumentCreated("notifications/{notificationId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const userId = String(data.userId || "").trim();
  if (!userId) return;

  await refreshUnreadNotificationCount(userId);
});

export const onNotificationUpdated = onDocumentUpdated("notifications/{notificationId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after) return;

  const userIds = new Set<string>();
  for (const raw of [before?.userId, after.userId]) {
    const userId = String(raw || "").trim();
    if (userId) userIds.add(userId);
  }

  await Promise.all(Array.from(userIds, (userId) => refreshUnreadNotificationCount(userId)));
});