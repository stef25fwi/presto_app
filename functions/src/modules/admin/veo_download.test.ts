import assert from "node:assert/strict";
import test from "node:test";
import { fetchVeoVideo } from "./veo_download";

const initial = "https://generativelanguage.googleapis.com/v1beta/files/test:download?alt=media";
test("VEO follows Google storage redirects without forwarding the API key", async () => {
  const calls: { url: string; init?: RequestInit }[] = [];
  const fetcher = (async (url, init) => {
    calls.push({ url: String(url), init });
    return calls.length === 1
      ? new Response(null, { status: 302, headers: { location: "https://storage.googleapis.com/video/test" } })
      : new Response("video", { status: 200 });
  }) as typeof fetch;
  const response = await fetchVeoVideo("synthetic-key", initial, fetcher);
  assert.equal(await response.text(), "video");
  assert.equal(new Headers(calls[0]?.init?.headers).get("x-goog-api-key"), "synthetic-key");
  assert.equal(new Headers(calls[1]?.init?.headers).get("x-goog-api-key"), null);
  assert.ok(calls.every((call) => call.init?.redirect === "manual"));
});
test("VEO rejects untrusted initial URLs before making a request", async () => {
  let calls = 0;
  const fetcher = (async () => { calls += 1; return new Response(); }) as typeof fetch;
  for (const uri of ["http://generativelanguage.googleapis.com/a", "https://169.254.169.254/a", "https://generativelanguage.googleapis.com.evil.test/a", "https://user:pass@generativelanguage.googleapis.com/a", "https://generativelanguage.googleapis.com:8443/a"]) {
    await assert.rejects(fetchVeoVideo("synthetic-key", uri, fetcher));
  }
  assert.equal(calls, 0);
});
test("VEO blocks private and foreign redirect destinations", async () => {
  for (const location of ["http://metadata.google.internal/", "https://127.0.0.1/", "https://evil.test/", "https://storage.googleapis.com.evil.test/"]) {
    let calls = 0;
    const fetcher = (async () => { calls += 1; return new Response(null, { status: 302, headers: { location } }); }) as typeof fetch;
    await assert.rejects(fetchVeoVideo("synthetic-key", initial, fetcher));
    assert.equal(calls, 1);
  }
});
test("VEO bounds redirect loops and supports relative same-origin redirects", async () => {
  let calls = 0;
  const loop = (async () => { calls += 1; return new Response(null, { status: 302, headers: { location: "/next" } }); }) as typeof fetch;
  await assert.rejects(fetchVeoVideo("synthetic-key", initial, loop));
  assert.equal(calls, 6);
});
