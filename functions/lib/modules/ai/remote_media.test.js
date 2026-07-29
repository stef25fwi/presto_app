"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const strict_1 = __importDefault(require("node:assert/strict"));
const node_test_1 = __importDefault(require("node:test"));
const https_1 = require("firebase-functions/v2/https");
const remote_media_1 = require("./remote_media");
const bucket = "presto-app-74abe.firebasestorage.app";
(0, node_test_1.default)("parseExactStorageUrl accepts only the exact configured bucket", () => {
    strict_1.default.deepEqual((0, remote_media_1.parseExactStorageUrl)(`https://firebasestorage.googleapis.com/v0/b/${bucket}/o/offers%2Fphoto.webp?alt=media`, bucket), { bucket, objectPath: "offers/photo.webp" });
    strict_1.default.throws(() => (0, remote_media_1.parseExactStorageUrl)("https://storage.googleapis.com/another-project/offers/photo.webp", bucket), (error) => error instanceof https_1.HttpsError && error.message === "IMAGE_BUCKET_NOT_ALLOWED");
});
(0, node_test_1.default)("downloadVerifiedRemoteImage validates redirects and actual byte size", async () => {
    const first = `https://storage.googleapis.com/${bucket}/offers/photo.webp`;
    const second = `https://${bucket}.storage.googleapis.com/offers/photo.webp`;
    const calls = [];
    const fetchImpl = async (url) => {
        const current = String(url);
        calls.push(current);
        if (current === first) {
            return new Response(null, { status: 302, headers: { location: second } });
        }
        return new Response(Buffer.from([1, 2, 3, 4]), {
            status: 200,
            headers: { "content-type": "image/webp", "content-length": "4" },
        });
    };
    const result = await (0, remote_media_1.downloadVerifiedRemoteImage)({
        url: first,
        expectedBucket: bucket,
        maxBytes: 10,
        fetchImpl: fetchImpl,
    });
    strict_1.default.equal(result.contentType, "image/webp");
    strict_1.default.equal(result.sizeBytes, 4);
    strict_1.default.equal(result.objectPath, "offers/photo.webp");
    strict_1.default.deepEqual(calls, [first, second]);
});
(0, node_test_1.default)("downloadVerifiedRemoteImage rejects a redirect to another bucket", async () => {
    const fetchImpl = async () => new Response(null, {
        status: 302,
        headers: {
            location: "https://storage.googleapis.com/evil-bucket/photo.png",
        },
    });
    await strict_1.default.rejects((0, remote_media_1.downloadVerifiedRemoteImage)({
        url: `https://storage.googleapis.com/${bucket}/photo.png`,
        expectedBucket: bucket,
        maxBytes: 10,
        fetchImpl: fetchImpl,
    }), (error) => error instanceof https_1.HttpsError && error.message === "IMAGE_BUCKET_NOT_ALLOWED");
});
//# sourceMappingURL=remote_media.test.js.map