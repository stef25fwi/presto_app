import assert from "node:assert/strict";
import admin from "firebase-admin";

const projectId = process.env.GCLOUD_PROJECT || process.env.GCLOUD_PROJECT_ID || "presto-app-74abe";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const functionsHost = process.env.FUNCTIONS_EMULATOR_HOST || "127.0.0.1:5001";
const region = process.env.FUNCTION_REGION || "europe-west1";

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  throw new Error("reviews_v2_emulator_e2e.mjs must run inside Firebase emulators:exec");
}

if (admin.apps.length === 0) {
  admin.initializeApp({ projectId });
}
const db = admin.firestore();

const unique = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
const password = "ReviewsV2-Test-2026!";

async function createEmulatorUser(label) {
  const email = `reviews-v2-${label}-${unique}@example.test`;
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    },
  );
  const body = await response.json();
  assert.equal(response.ok, true, `auth signUp failed: ${JSON.stringify(body)}`);
  return { uid: body.localId, email, idToken: body.idToken };
}

async function callable(name, idToken, data, { expectErrorStatus } = {}) {
  const response = await fetch(
    `http://${functionsHost}/${projectId}/${region}/${name}`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({ data }),
    },
  );
  const body = await response.json();
  if (expectErrorStatus) {
    assert.equal(response.ok, false, `${name} unexpectedly succeeded`);
    assert.equal(
      String(body?.error?.status || ""),
      expectErrorStatus,
      `${name} error mismatch: ${JSON.stringify(body)}`,
    );
    return body;
  }
  assert.equal(response.ok, true, `${name} failed: ${JSON.stringify(body)}`);
  assert.ok(body.result || body.data, `${name} returned no callable result`);
  return body.result || body.data;
}

function reviewIdFor(offerId, reviewerId, reviewedUserId, reviewedRole) {
  return [offerId, reviewerId, reviewedUserId, reviewedRole]
    .map((part) => encodeURIComponent(String(part).replaceAll("/", "_")))
    .join("__");
}

async function expectFirestoreRuleDenied({ method, path, idToken, body }) {
  const response = await fetch(
    `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents/${path}`,
    {
      method,
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${idToken}`,
      },
      body: body == null ? undefined : JSON.stringify(body),
    },
  );
  assert.equal(
    response.ok,
    false,
    `${method} ${path} should have been denied by Firestore rules`,
  );
  assert.ok(
    response.status === 403 || response.status === 401,
    `expected permission denial, got HTTP ${response.status}`,
  );
}

async function main() {
  const requester = await createEmulatorUser("requester");
  const provider = await createEmulatorUser("provider");
  const offerId = `review-e2e-offer-${unique}`;
  const conversationId = `review-e2e-conversation-${unique}`;

  await Promise.all([
    db.collection("users").doc(requester.uid).set({
      uid: requester.uid,
      email: requester.email,
      pseudo: "Annonceur E2E",
      city: "Pointe-à-Pitre",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
    db.collection("users").doc(provider.uid).set({
      uid: provider.uid,
      email: provider.email,
      pseudo: "Prestataire E2E",
      city: "Les Abymes",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }),
  ]);

  await db.collection("listings").doc(offerId).set({
    id: offerId,
    ownerId: requester.uid,
    title: "Mission E2E notation réciproque",
    status: "active",
    visibility: "public",
    reviewRequested: true,
    reviewSubmitted: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await db.collection("conversations").doc(conversationId).set({
    offerId,
    listingId: offerId,
    participantIds: [requester.uid, provider.uid],
    participants: [requester.uid, provider.uid],
    participantNames: {
      [requester.uid]: "Annonceur E2E",
      [provider.uid]: "Prestataire E2E",
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // 1. « Noter plus tard » is a real queue item and can be dismissed explicitly.
  let requesterTasks = await callable("getPendingReviewTasksV2", requester.idToken, {});
  assert.ok(
    requesterTasks.tasks.some((task) => task.type === "rate_later" && task.offerId === offerId),
    "rate_later task missing",
  );
  await callable("dismissPendingReviewTaskV2", requester.idToken, { offerId });
  requesterTasks = await callable("getPendingReviewTasksV2", requester.idToken, {});
  assert.equal(
    requesterTasks.tasks.some((task) => task.type === "rate_later" && task.offerId === offerId),
    false,
    "dismissed rate_later task still visible",
  );
  await db.collection("listings").doc(offerId).set({
    reviewRequested: true,
    reviewSubmitted: false,
    reviewDismissed: false,
  }, { merge: true });

  // 2. V2 responder eligibility excludes only real existing V1/V2 reviews.
  const eligible = await callable("getEligibleRespondersForReviewV2", requester.idToken, { offerId });
  assert.ok(
    eligible.responders.some((entry) => entry.userId === provider.uid),
    "provider should be eligible before first review",
  );

  // 3. Requester -> provider creates a pending reciprocal review and actionable notification.
  const first = await callable("submitMutualVerifiedReviewComplete", requester.idToken, {
    offerId,
    reviewedUserId: provider.uid,
    reviewerRole: "requester",
    reviewedRole: "provider",
    criteria: {
      communication: 5,
      punctuality: 4,
      quality: 5,
      courtesy: 5,
    },
    comment: "Très bonne prestation pour le scénario E2E.",
    confirmationChecked: true,
  });
  assert.equal(first.status, "pending_peer_review");

  const requesterReviewId = reviewIdFor(offerId, requester.uid, provider.uid, "provider");
  const requesterReview = await db.collection("reviews").doc(requesterReviewId).get();
  assert.equal(requesterReview.exists, true);
  assert.equal(requesterReview.data().status, "pending_peer_review");

  const eligibleAfter = await callable("getEligibleRespondersForReviewV2", requester.idToken, { offerId });
  assert.equal(
    eligibleAfter.responders.some((entry) => entry.userId === provider.uid),
    false,
    "V2-reviewed provider must not reappear in eligible responders",
  );

  let providerTasks = await callable("getPendingReviewTasksV2", provider.idToken, {});
  assert.ok(
    providerTasks.tasks.some((task) =>
      task.type === "reciprocal"
      && task.offerId === offerId
      && task.reviewedUserId === requester.uid),
    "provider reciprocal task missing",
  );

  const notificationSnap = await db.collection("notifications")
    .where("userId", "==", provider.uid)
    .get();
  assert.ok(
    notificationSnap.docs.some((doc) => doc.data().routeName === "/account/mes-avis"),
    "review action notification must route to /account/mes-avis",
  );

  // 4. Simulate moderator correction request, then author correction/resubmission.
  await db.collection("reviews").doc(requesterReviewId).set({
    status: "pending_moderation",
    visibleOnProfile: false,
    correctionRequested: true,
    correctionMessage: "Reformulez le commentaire sans donnée sensible.",
  }, { merge: true });
  requesterTasks = await callable("getPendingReviewTasksV2", requester.idToken, {});
  assert.ok(
    requesterTasks.tasks.some((task) =>
      task.type === "correction" && task.reviewId === requesterReviewId),
    "correction task missing",
  );
  const revised = await callable("reviseReviewV2", requester.idToken, {
    reviewId: requesterReviewId,
    comment: "Prestation réalisée correctement, échanges clairs et ponctuels.",
  });
  assert.equal(revised.status, "pending_peer_review");

  // 5. Provider -> requester publishes BOTH reviews and returns the real final status.
  providerTasks = await callable("getPendingReviewTasksV2", provider.idToken, {});
  assert.ok(
    providerTasks.tasks.some((task) => task.type === "reciprocal" && task.offerId === offerId),
    "reciprocal task should return after correction",
  );
  const reciprocal = await callable("submitMutualVerifiedReviewComplete", provider.idToken, {
    offerId,
    reviewedUserId: requester.uid,
    reviewerRole: "provider",
    reviewedRole: "requester",
    criteria: {
      communication: 5,
      punctuality: 5,
      clarity: 5,
      courtesy: 5,
      paymentRespect: 5,
    },
    comment: "Annonceur clair, fiable et respectueux.",
    confirmationChecked: true,
  });
  assert.equal(reciprocal.status, "published", "callable must return actual published status");

  const providerReviewId = reviewIdFor(offerId, provider.uid, requester.uid, "requester");
  const [finalRequesterReview, finalProviderReview] = await Promise.all([
    db.collection("reviews").doc(requesterReviewId).get(),
    db.collection("reviews").doc(providerReviewId).get(),
  ]);
  assert.equal(finalRequesterReview.data().status, "published");
  assert.equal(finalProviderReview.data().status, "published");
  assert.equal(finalRequesterReview.data().visibleOnProfile, true);
  assert.equal(finalProviderReview.data().visibleOnProfile, true);

  providerTasks = await callable("getPendingReviewTasksV2", provider.idToken, {});
  assert.equal(
    providerTasks.tasks.some((task) => task.type === "reciprocal" && task.offerId === offerId),
    false,
    "completed reciprocal task must disappear",
  );

  // 6. Duplicate review is rejected server-side.
  await callable(
    "submitMutualVerifiedReviewComplete",
    requester.idToken,
    {
      offerId,
      reviewedUserId: provider.uid,
      reviewerRole: "requester",
      reviewedRole: "provider",
      criteria: { communication: 5, punctuality: 5, quality: 5 },
      comment: "duplicate",
      confirmationChecked: true,
    },
    { expectErrorStatus: "ALREADY_EXISTS" },
  );

  // 7. Secure score is calculated for both roles and stored in server-only collection.
  const [providerScore, requesterScore] = await Promise.all([
    callable("getUserTrustScoreV2Complete", provider.idToken, { userId: provider.uid }),
    callable("getUserTrustScoreV2Complete", requester.idToken, { userId: requester.uid }),
  ]);
  assert.equal(providerScore.trustScoreV2.provider.reviewsCount, 1);
  assert.equal(requesterScore.trustScoreV2.requester.reviewsCount, 1);
  assert.equal(providerScore.canonicalStorage, "user_trust_scores_v2");

  const [providerCanonical, requesterCanonical] = await Promise.all([
    db.collection("user_trust_scores_v2").doc(provider.uid).get(),
    db.collection("user_trust_scores_v2").doc(requester.uid).get(),
  ]);
  assert.equal(providerCanonical.exists, true);
  assert.equal(requesterCanonical.exists, true);

  // 8. Firestore rules protect both the canonical collection and trustScoreV2 user field.
  await expectFirestoreRuleDenied({
    method: "GET",
    path: `user_trust_scores_v2/${provider.uid}`,
    idToken: provider.idToken,
  });
  await expectFirestoreRuleDenied({
    method: "PATCH",
    path: `users/${provider.uid}?updateMask.fieldPaths=trustScoreV2`,
    idToken: provider.idToken,
    body: {
      fields: {
        trustScoreV2: {
          mapValue: {
            fields: {
              global: {
                mapValue: {
                  fields: {
                    score100: { integerValue: "100" },
                  },
                },
              },
            },
          },
        },
      },
    },
  });

  console.log(JSON.stringify({
    ok: true,
    offerId,
    conversationId,
    requesterReviewId,
    providerReviewId,
    requesterFinalStatus: finalRequesterReview.data().status,
    providerFinalStatus: finalProviderReview.data().status,
    providerScore100: providerScore.trustScoreV2.global.score100,
    requesterScore100: requesterScore.trustScoreV2.global.score100,
  }, null, 2));
}

main().catch((error) => {
  console.error("REVIEWS_V2_EMULATOR_E2E_FAILED", error);
  process.exitCode = 1;
});
