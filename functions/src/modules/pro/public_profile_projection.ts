import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

import { PROJECT_REGION } from "../../config/env";
import {
  buildPublicProfileProjection,
  publicProfileIdForUid,
  sourceProfileIsPublicEligible,
} from "../seo/public_profiles_core";

const PUBLIC_COLLECTION = "public_service_profiles";

export const onProProfilePublicProjection = onDocumentWritten(
  {
    document: "pro_profiles/{uid}",
    region: PROJECT_REGION,
  },
  async (event) => {
    const uid = String(event.params.uid || "");
    if (!uid) return;

    const db = getFirestore();
    const publicId = publicProfileIdForUid(uid);
    const target = db.collection(PUBLIC_COLLECTION).doc(publicId);
    const source = event.data?.after.exists ? event.data.after.data() || {} : null;

    if (!source || !sourceProfileIsPublicEligible(source)) {
      const existing = await target.get();
      if (existing.exists) {
        await target.delete();
        logger.info("public_service_profile_unpublished", { publicId });
      }
      return;
    }

    const projection = buildPublicProfileProjection(uid, source);
    const existing = await target.get();
    const publishedAt = existing.exists
      ? existing.data()?.publishedAt || FieldValue.serverTimestamp()
      : FieldValue.serverTimestamp();

    await target.set(
      {
        ...projection,
        publishedAt,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: false },
    );

    logger.info("public_service_profile_projected", {
      publicId,
      city: projection.city,
      activity: projection.activity,
    });
  },
);
