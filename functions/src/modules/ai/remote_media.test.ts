import assert from "node:assert/strict";
import test from "node:test";

import { HttpsError } from "firebase-functions/v2/https";
import {
  downloadVerifiedRemoteImage,
  parseExactStorageUrl,
} from "./remote_media";

const bucket = "presto-app-74abe.firebasestorage.app";

test("parseExactStorageUrl accepts only the exact configured bucket", () => {
  assert.deepEqual(
    parseExactStorageUrl(
      `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/offers%2Fphoto.webp?alt=media`,
      bucket,
    ),
    { bucket, objectPath: "offers/photo.webp" },
  );
  assert.throws(
    () =>
      parseExactStorageUrl(
        "https://storage.googleapis.com/another-project/offers/photo.webp",
        bucket,
      ),
    (error: unknown) =>
      error instanceof HttpsError && error.message === "IMAGE_BUCKET_NOT_ALLOWED",
  );
});

test("downloadVerifiedRemoteImage validates redirects and actual byte size", async () => {
  const first = `https://storage.googleapis.com/${bucket}/offers/photo.webp`;
  const second = `https://${bucket}.storage.googleapis.com/offers/photo.webp`;
  const calls: string[] = [];
  const fetchImpl = async (url: string | URL | Request): Promise<Response> => {
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

  const result = await downloadVerifiedRemoteImage({
    url: first,
    expectedBucket: bucket,
    maxBytes: 10,
    fetchImpl: fetchImpl as typeof fetch,
  });

  assert.equal(result.contentType, "image/webp");
  assert.equal(result.sizeBytes, 4);
  assert.equal(result.objectPath, "offers/photo.webp");
  assert.deepEqual(calls, [first, second]);
});

test("downloadVerifiedRemoteImage rejects a redirect to another bucket", async () => {
  const fetchImpl = async (): Promise<Response> =>
    new Response(null, {
      status: 302,
      headers: {
        location: "https://storage.googleapis.com/evil-bucket/photo.png",
      },
    });

  await assert.rejects(
    downloadVerifiedRemoteImage({
      url: `https://storage.googleapis.com/${bucket}/photo.png`,
      expectedBucket: bucket,
      maxBytes: 10,
      fetchImpl: fetchImpl as typeof fetch,
    }),
    (error: unknown) =>
      error instanceof HttpsError && error.message === "IMAGE_BUCKET_NOT_ALLOWED",
  );
});
