import assert from "node:assert/strict";
import test from "node:test";
import { HttpsError } from "firebase-functions/v2/https";
import {
  assertConversationParticipantAccess,
  buildAttachmentMessageFallbackText,
  buildProcessedConversationAttachmentPath,
  canonicalConversationId,
  computeUnreadCountAfterMessageDeletion,
  getMessagingAttachmentEntitlements,
  mergeConversationParticipants,
  resolveOfferLikeData,
  sanitizeConversationAttachments,
  shouldForkConversationThread,
} from "./callables";
import { readConversationMessageCount } from "./mirror";

test("readConversationMessageCount uses atomic counter when present", () => {
  assert.equal(readConversationMessageCount({ messageCount: 3, lastMessage: "" }), 3);
});

test("readConversationMessageCount falls back to lastMessage for legacy conversations", () => {
  assert.equal(readConversationMessageCount({ lastMessage: "Bonjour" }), 1);
  assert.equal(readConversationMessageCount({ lastMessage: "   " }), 0);
});

test("mergeConversationParticipants preserves legacy ids and injects required participants", () => {
  assert.deepEqual(
    mergeConversationParticipants(["buyer_a"], ["seller_b", "buyer_a"]),
    ["buyer_a", "seller_b"],
  );
});

test("computeUnreadCountAfterMessageDeletion decrements only unread recipients", () => {
  assert.deepEqual(
    computeUnreadCountAfterMessageDeletion({
      participants: ["buyer_a", "seller_b"],
      unreadCount: { buyer_a: 0, seller_b: 2 },
      lastReadAt: {},
      deletedSenderId: "buyer_a",
      deletedCreatedAt: new Date("2026-03-28T10:00:00.000Z"),
    }),
    { buyer_a: 0, seller_b: 1 },
  );
});

test("resolveOfferLikeData prefers listings when both sources exist", () => {
  const result = resolveOfferLikeData({
    offerData: {ownerId: "owner_offer", title: "Offre legacy"},
    listingData: {ownerId: "owner_listing", title: "Listing marketplace"},
  });

  assert.equal(result.source, "listings");
  assert.equal(result.data.ownerId, "owner_listing");
});

test("resolveOfferLikeData falls back to listings when offer is absent", () => {
  const result = resolveOfferLikeData({
    offerData: null,
    listingData: {ownerId: "owner_listing", title: "Listing marketplace"},
  });

  assert.equal(result.source, "listings");
  assert.equal(result.data.ownerId, "owner_listing");
});

test("resolveOfferLikeData falls back to legacy offers only when listing is absent", () => {
  const result = resolveOfferLikeData({
    offerData: {ownerId: "owner_offer", title: "Offre legacy"},
    listingData: null,
  });

  assert.equal(result.source, "offers");
  assert.equal(result.data.ownerId, "owner_offer");
});

test("resolveOfferLikeData throws not-found when neither source exists", () => {
  assert.throws(
    () => resolveOfferLikeData({offerData: null, listingData: null}),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "not-found");
      return true;
    },
  );
});

test("canonicalConversationId is stable and order-independent", () => {
  const left = canonicalConversationId({
    listingId: "listing_123",
    currentUserId: "buyer_a",
    otherUserId: "seller_b",
  });
  const right = canonicalConversationId({
    listingId: "listing_123",
    currentUserId: "seller_b",
    otherUserId: "buyer_a",
  });

  assert.equal(left, right);
  assert.match(left, /^conv_[a-f0-9]{32}$/);
});

test("shouldForkConversationThread returns true when a participant previously deleted the thread", () => {
  assert.equal(
    shouldForkConversationThread(["buyer_a", "seller_b"], {
      buyer_a: false,
      seller_b: true,
    }),
    true,
  );
  assert.equal(
    shouldForkConversationThread(["buyer_a", "seller_b"], {
      buyer_a: false,
      seller_b: false,
    }),
    false,
  );
});

test("sendConversationMessage refuses non participant access", () => {
  assert.throws(
    () => assertConversationParticipantAccess(["buyer_a", "seller_b"], "intruder_c"),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "permission-denied");
      assert.equal(error.message, "not allowed to access this conversation");
      return true;
    },
  );
});

test("sanitizeConversationAttachments accepts processed webp image for current conversation", () => {
  const attachments = sanitizeConversationAttachments([
    {
      type: "image",
      name: "photo.webp",
      url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fprocessed_photo.webp",
      storagePath: "messageAttachments/buyer_a/conv_1/processed_photo.webp",
      mimeType: "image/webp",
      sizeBytes: 1200,
    },
  ], "buyer_a", "conv_1");

  assert.equal(attachments.length, 1);
  const firstAttachment = attachments[0];
  assert.ok(firstAttachment);
  assert.equal(firstAttachment.type, "image");
});

test("sanitizeConversationAttachments rejects raw non-webp image uploads", () => {
  assert.throws(
    () => sanitizeConversationAttachments([
      {
        type: "image",
        name: "photo.jpg",
        url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fphoto.jpg",
        storagePath: "messageAttachments/buyer_a/conv_1/photo.jpg",
        mimeType: "image/jpeg",
        sizeBytes: 1200,
      },
    ], "buyer_a", "conv_1"),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "invalid-argument");
      assert.match(error.message, /processed as WebP/i);
      return true;
    },
  );
});

test("sanitizeConversationAttachments rejects another conversation storage path", () => {
  assert.throws(
    () => sanitizeConversationAttachments([
      {
        type: "document",
        name: "devis.pdf",
        url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_2%2Fdevis.pdf",
        storagePath: "messageAttachments/buyer_a/conv_2/devis.pdf",
        mimeType: "application/pdf",
        sizeBytes: 1200,
      },
    ], "buyer_a", "conv_1"),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "invalid-argument");
      return true;
    },
  );
});

test("sanitizeConversationAttachments rejects unsupported document mime type", () => {
  assert.throws(
    () => sanitizeConversationAttachments([
      {
        type: "document",
        name: "archive.zip",
        url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Farchive.zip",
        storagePath: "messageAttachments/buyer_a/conv_1/archive.zip",
        mimeType: "application/zip",
        sizeBytes: 1200,
      },
    ], "buyer_a", "conv_1"),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "invalid-argument");
      return true;
    },
  );
});

test("sanitizeConversationAttachments accepts spreadsheet document attachment", () => {
  const attachments = sanitizeConversationAttachments([
    {
      type: "document",
      name: "budget.xlsx",
      url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fbudget.xlsx",
      storagePath: "messageAttachments/buyer_a/conv_1/budget.xlsx",
      mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      sizeBytes: 42000,
    },
  ], "buyer_a", "conv_1");

  assert.equal(attachments.length, 1);
  const firstAttachment = attachments[0];
  assert.ok(firstAttachment);
  assert.equal(firstAttachment.type, "document");
});

test("sanitizeConversationAttachments accepts audio attachment for current conversation", () => {
  const attachments = sanitizeConversationAttachments([
    {
      type: "audio",
      name: "note_vocale_8s.m4a",
      url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fnote_vocale_8s.m4a",
      storagePath: "messageAttachments/buyer_a/conv_1/note_vocale_8s.m4a",
      mimeType: "audio/mp4",
      sizeBytes: 64000,
    },
  ], "buyer_a", "conv_1");

  assert.equal(attachments.length, 1);
  const firstAttachment = attachments[0];
  assert.ok(firstAttachment);
  assert.equal(firstAttachment.type, "audio");
});

test("buildAttachmentMessageFallbackText returns audio label for voice notes", () => {
  assert.equal(
    buildAttachmentMessageFallbackText({
      type: "audio",
      name: "note_vocale_8s.webm",
    }),
    "Note vocale",
  );
});

test("sanitizeConversationAttachments rejects unsupported audio mime type", () => {
  assert.throws(
    () => sanitizeConversationAttachments([
      {
        type: "audio",
        name: "note_vocale.flac",
        url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fnote_vocale.flac",
        storagePath: "messageAttachments/buyer_a/conv_1/note_vocale.flac",
        mimeType: "audio/flac",
        sizeBytes: 64000,
      },
    ], "buyer_a", "conv_1"),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "invalid-argument");
      return true;
    },
  );
});

test("sanitizeConversationAttachments accepts mp3 audio attachment", () => {
  const attachments = sanitizeConversationAttachments([
    {
      type: "audio",
      name: "jingle.mp3",
      url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fjingle.mp3",
      storagePath: "messageAttachments/buyer_a/conv_1/jingle.mp3",
      mimeType: "audio/mpeg",
      sizeBytes: 64000,
    },
  ], "buyer_a", "conv_1");

  assert.equal(attachments.length, 1);
  const firstAttachment = attachments[0];
  assert.ok(firstAttachment);
  assert.equal(firstAttachment.type, "audio");
});

test("sanitizeConversationAttachments accepts wav audio attachment", () => {
  const attachments = sanitizeConversationAttachments([
    {
      type: "audio",
      name: "note.wav",
      url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fnote.wav",
      storagePath: "messageAttachments/buyer_a/conv_1/note.wav",
      mimeType: "audio/wav",
      sizeBytes: 64000,
    },
  ], "buyer_a", "conv_1");

  assert.equal(attachments.length, 1);
  const firstAttachment = attachments[0];
  assert.ok(firstAttachment);
  assert.equal(firstAttachment.type, "audio");
});

test("getMessagingAttachmentEntitlements keeps all messaging attachments open while free access mode is active", () => {
  const entitlements = getMessagingAttachmentEntitlements("free", true);

  assert.equal(entitlements.canSendDocuments, true);
  assert.equal(entitlements.maxPhotosPerConversation, 999);
  assert.equal(entitlements.maxAudioPerConversation, 999);
});

test("getMessagingAttachmentEntitlements prepares free plan messaging limits when free access mode is disabled", () => {
  const entitlements = getMessagingAttachmentEntitlements("free", false);

  assert.equal(entitlements.canSendDocuments, false);
  assert.equal(entitlements.maxPhotosPerConversation, 1);
  assert.equal(entitlements.maxAudioPerConversation, 1);
});

test("getMessagingAttachmentEntitlements unlocks messaging attachments for ilipresto+", () => {
  const entitlements = getMessagingAttachmentEntitlements("ilipresto_plus", false);

  assert.equal(entitlements.canSendDocuments, true);
  assert.equal(entitlements.maxPhotosPerConversation, 999);
  assert.equal(entitlements.maxAudioPerConversation, 999);
});

test("buildProcessedConversationAttachmentPath keeps photos scoped and converts to webp", () => {
  const path = buildProcessedConversationAttachmentPath({
    uid: "buyer_a",
    conversationId: "conv_1",
    storagePath: "messageAttachments/buyer_a/conv_1/123_photo.jpg",
  });

  assert.equal(path, "messageAttachments/buyer_a/conv_1/processed_123_photo.webp");
});

test("buildProcessedConversationAttachmentPath rejects another user path", () => {
  assert.throws(
    () => buildProcessedConversationAttachmentPath({
      uid: "buyer_a",
      conversationId: "conv_1",
      storagePath: "messageAttachments/seller_b/conv_1/123_photo.jpg",
    }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal(error.code, "permission-denied");
      return true;
    },
  );
});