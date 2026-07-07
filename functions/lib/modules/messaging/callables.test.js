"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const https_1 = require("firebase-functions/v2/https");
const callables_1 = require("./callables");
const mirror_1 = require("./mirror");
(0, node_test_1.default)("readConversationMessageCount uses atomic counter when present", () => {
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ messageCount: 3, lastMessage: "" }), 3);
});
(0, node_test_1.default)("readConversationMessageCount falls back to lastMessage for legacy conversations", () => {
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ lastMessage: "Bonjour" }), 1);
    strict_1.default.equal((0, mirror_1.readConversationMessageCount)({ lastMessage: "   " }), 0);
});
(0, node_test_1.default)("mergeConversationParticipants preserves legacy ids and injects required participants", () => {
    strict_1.default.deepEqual((0, callables_1.mergeConversationParticipants)(["buyer_a"], ["seller_b", "buyer_a"]), ["buyer_a", "seller_b"]);
});
(0, node_test_1.default)("computeUnreadCountAfterMessageDeletion decrements only unread recipients", () => {
    strict_1.default.deepEqual((0, callables_1.computeUnreadCountAfterMessageDeletion)({
        participants: ["buyer_a", "seller_b"],
        unreadCount: { buyer_a: 0, seller_b: 2 },
        lastReadAt: {},
        deletedSenderId: "buyer_a",
        deletedCreatedAt: new Date("2026-03-28T10:00:00.000Z"),
    }), { buyer_a: 0, seller_b: 1 });
});
(0, node_test_1.default)("resolveOfferLikeData prefers listings when both sources exist", () => {
    const result = (0, callables_1.resolveOfferLikeData)({
        offerData: { ownerId: "owner_offer", title: "Offre legacy" },
        listingData: { ownerId: "owner_listing", title: "Listing marketplace" },
    });
    strict_1.default.equal(result.source, "listings");
    strict_1.default.equal(result.data.ownerId, "owner_listing");
});
(0, node_test_1.default)("resolveOfferLikeData falls back to listings when offer is absent", () => {
    const result = (0, callables_1.resolveOfferLikeData)({
        offerData: null,
        listingData: { ownerId: "owner_listing", title: "Listing marketplace" },
    });
    strict_1.default.equal(result.source, "listings");
    strict_1.default.equal(result.data.ownerId, "owner_listing");
});
(0, node_test_1.default)("resolveOfferLikeData falls back to legacy offers only when listing is absent", () => {
    const result = (0, callables_1.resolveOfferLikeData)({
        offerData: { ownerId: "owner_offer", title: "Offre legacy" },
        listingData: null,
    });
    strict_1.default.equal(result.source, "offers");
    strict_1.default.equal(result.data.ownerId, "owner_offer");
});
(0, node_test_1.default)("resolveOfferLikeData throws not-found when neither source exists", () => {
    strict_1.default.throws(() => (0, callables_1.resolveOfferLikeData)({ offerData: null, listingData: null }), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "not-found");
        return true;
    });
});
(0, node_test_1.default)("canonicalConversationId is stable and order-independent", () => {
    const left = (0, callables_1.canonicalConversationId)({
        listingId: "listing_123",
        currentUserId: "buyer_a",
        otherUserId: "seller_b",
    });
    const right = (0, callables_1.canonicalConversationId)({
        listingId: "listing_123",
        currentUserId: "seller_b",
        otherUserId: "buyer_a",
    });
    strict_1.default.equal(left, right);
    strict_1.default.match(left, /^conv_[a-f0-9]{32}$/);
});
(0, node_test_1.default)("shouldForkConversationThread returns true when a participant previously deleted the thread", () => {
    strict_1.default.equal((0, callables_1.shouldForkConversationThread)(["buyer_a", "seller_b"], {
        buyer_a: false,
        seller_b: true,
    }), true);
    strict_1.default.equal((0, callables_1.shouldForkConversationThread)(["buyer_a", "seller_b"], {
        buyer_a: false,
        seller_b: false,
    }), false);
});
(0, node_test_1.default)("sendConversationMessage refuses non participant access", () => {
    strict_1.default.throws(() => (0, callables_1.assertConversationParticipantAccess)(["buyer_a", "seller_b"], "intruder_c"), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "permission-denied");
        strict_1.default.equal(error.message, "not allowed to access this conversation");
        return true;
    });
});
(0, node_test_1.default)("sanitizeConversationAttachments accepts processed webp image for current conversation", () => {
    const attachments = (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "image",
            name: "photo.webp",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fprocessed_photo.webp",
            storagePath: "messageAttachments/buyer_a/conv_1/processed_photo.webp",
            mimeType: "image/webp",
            sizeBytes: 1200,
        },
    ], "buyer_a", "conv_1");
    strict_1.default.equal(attachments.length, 1);
    const firstAttachment = attachments[0];
    strict_1.default.ok(firstAttachment);
    strict_1.default.equal(firstAttachment.type, "image");
});
(0, node_test_1.default)("sanitizeConversationAttachments rejects raw non-webp image uploads", () => {
    strict_1.default.throws(() => (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "image",
            name: "photo.jpg",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fphoto.jpg",
            storagePath: "messageAttachments/buyer_a/conv_1/photo.jpg",
            mimeType: "image/jpeg",
            sizeBytes: 1200,
        },
    ], "buyer_a", "conv_1"), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "invalid-argument");
        strict_1.default.match(error.message, /processed as WebP/i);
        return true;
    });
});
(0, node_test_1.default)("sanitizeConversationAttachments rejects another conversation storage path", () => {
    strict_1.default.throws(() => (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "document",
            name: "devis.pdf",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_2%2Fdevis.pdf",
            storagePath: "messageAttachments/buyer_a/conv_2/devis.pdf",
            mimeType: "application/pdf",
            sizeBytes: 1200,
        },
    ], "buyer_a", "conv_1"), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "invalid-argument");
        return true;
    });
});
(0, node_test_1.default)("sanitizeConversationAttachments rejects unsupported document mime type", () => {
    strict_1.default.throws(() => (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "document",
            name: "archive.zip",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Farchive.zip",
            storagePath: "messageAttachments/buyer_a/conv_1/archive.zip",
            mimeType: "application/zip",
            sizeBytes: 1200,
        },
    ], "buyer_a", "conv_1"), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "invalid-argument");
        return true;
    });
});
(0, node_test_1.default)("sanitizeConversationAttachments accepts spreadsheet document attachment", () => {
    const attachments = (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "document",
            name: "budget.xlsx",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fbudget.xlsx",
            storagePath: "messageAttachments/buyer_a/conv_1/budget.xlsx",
            mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            sizeBytes: 42000,
        },
    ], "buyer_a", "conv_1");
    strict_1.default.equal(attachments.length, 1);
    const firstAttachment = attachments[0];
    strict_1.default.ok(firstAttachment);
    strict_1.default.equal(firstAttachment.type, "document");
});
(0, node_test_1.default)("sanitizeConversationAttachments accepts audio attachment for current conversation", () => {
    const attachments = (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "audio",
            name: "note_vocale_8s.m4a",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fnote_vocale_8s.m4a",
            storagePath: "messageAttachments/buyer_a/conv_1/note_vocale_8s.m4a",
            mimeType: "audio/mp4",
            sizeBytes: 64000,
        },
    ], "buyer_a", "conv_1");
    strict_1.default.equal(attachments.length, 1);
    const firstAttachment = attachments[0];
    strict_1.default.ok(firstAttachment);
    strict_1.default.equal(firstAttachment.type, "audio");
});
(0, node_test_1.default)("buildAttachmentMessageFallbackText returns audio label for voice notes", () => {
    strict_1.default.equal((0, callables_1.buildAttachmentMessageFallbackText)({
        type: "audio",
        name: "note_vocale_8s.webm",
    }), "Note vocale");
});
(0, node_test_1.default)("sanitizeConversationAttachments rejects unsupported audio mime type", () => {
    strict_1.default.throws(() => (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "audio",
            name: "note_vocale.flac",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fnote_vocale.flac",
            storagePath: "messageAttachments/buyer_a/conv_1/note_vocale.flac",
            mimeType: "audio/flac",
            sizeBytes: 64000,
        },
    ], "buyer_a", "conv_1"), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "invalid-argument");
        return true;
    });
});
(0, node_test_1.default)("sanitizeConversationAttachments accepts mp3 audio attachment", () => {
    const attachments = (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "audio",
            name: "jingle.mp3",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fjingle.mp3",
            storagePath: "messageAttachments/buyer_a/conv_1/jingle.mp3",
            mimeType: "audio/mpeg",
            sizeBytes: 64000,
        },
    ], "buyer_a", "conv_1");
    strict_1.default.equal(attachments.length, 1);
    const firstAttachment = attachments[0];
    strict_1.default.ok(firstAttachment);
    strict_1.default.equal(firstAttachment.type, "audio");
});
(0, node_test_1.default)("sanitizeConversationAttachments accepts wav audio attachment", () => {
    const attachments = (0, callables_1.sanitizeConversationAttachments)([
        {
            type: "audio",
            name: "note.wav",
            url: "https://firebasestorage.googleapis.com/v0/b/bucket/o/messageAttachments%2Fbuyer_a%2Fconv_1%2Fnote.wav",
            storagePath: "messageAttachments/buyer_a/conv_1/note.wav",
            mimeType: "audio/wav",
            sizeBytes: 64000,
        },
    ], "buyer_a", "conv_1");
    strict_1.default.equal(attachments.length, 1);
    const firstAttachment = attachments[0];
    strict_1.default.ok(firstAttachment);
    strict_1.default.equal(firstAttachment.type, "audio");
});
(0, node_test_1.default)("getMessagingAttachmentEntitlements keeps all messaging attachments open while free access mode is active", () => {
    const entitlements = (0, callables_1.getMessagingAttachmentEntitlements)("free", true);
    strict_1.default.equal(entitlements.canSendDocuments, true);
    strict_1.default.equal(entitlements.maxPhotosPerConversation, 999);
    strict_1.default.equal(entitlements.maxAudioPerConversation, 999);
});
(0, node_test_1.default)("getMessagingAttachmentEntitlements prepares free plan messaging limits when free access mode is disabled", () => {
    const entitlements = (0, callables_1.getMessagingAttachmentEntitlements)("free", false);
    strict_1.default.equal(entitlements.canSendDocuments, false);
    strict_1.default.equal(entitlements.maxPhotosPerConversation, 1);
    strict_1.default.equal(entitlements.maxAudioPerConversation, 1);
});
(0, node_test_1.default)("getMessagingAttachmentEntitlements unlocks messaging attachments for ilipresto+", () => {
    const entitlements = (0, callables_1.getMessagingAttachmentEntitlements)("ilipresto_plus", false);
    strict_1.default.equal(entitlements.canSendDocuments, true);
    strict_1.default.equal(entitlements.maxPhotosPerConversation, 999);
    strict_1.default.equal(entitlements.maxAudioPerConversation, 999);
});
(0, node_test_1.default)("buildProcessedConversationAttachmentPath keeps photos scoped and converts to webp", () => {
    const path = (0, callables_1.buildProcessedConversationAttachmentPath)({
        uid: "buyer_a",
        conversationId: "conv_1",
        storagePath: "messageAttachments/buyer_a/conv_1/123_photo.jpg",
    });
    strict_1.default.equal(path, "messageAttachments/buyer_a/conv_1/processed_123_photo.webp");
});
(0, node_test_1.default)("buildProcessedConversationAttachmentPath rejects another user path", () => {
    strict_1.default.throws(() => (0, callables_1.buildProcessedConversationAttachmentPath)({
        uid: "buyer_a",
        conversationId: "conv_1",
        storagePath: "messageAttachments/seller_b/conv_1/123_photo.jpg",
    }), (error) => {
        strict_1.default.ok(error instanceof https_1.HttpsError);
        strict_1.default.equal(error.code, "permission-denied");
        return true;
    });
});
//# sourceMappingURL=callables.test.js.map