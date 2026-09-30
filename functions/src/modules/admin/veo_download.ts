const API_HOST = "generativelanguage.googleapis.com";
const REDIRECT_STATUSES = new Set([301, 302, 303, 307, 308]);

function trustedUrl(value: string, first: boolean): URL {
  const url = new URL(value);
  const googleStorage = url.hostname === "storage.googleapis.com"
    || /^[a-z0-9][a-z0-9.-]*\.storage\.googleapis\.com$/.test(url.hostname);
  if (url.protocol !== "https:" || url.username || url.password || url.port
    || (url.hostname !== API_HOST && (first || !googleStorage))) {
    throw new Error("VEO_UNTRUSTED_DOWNLOAD_URL");
  }
  return url;
}

/** Validate every hop, and never forward the Gemini key to a storage host. */
export async function fetchVeoVideo(
  apiKey: string,
  videoUri: string,
  fetcher: typeof fetch = fetch,
): Promise<Response> {
  let url = trustedUrl(videoUri, true);
  for (let hop = 0; hop <= 5; hop += 1) {
    const response = await fetcher(url.toString(), {
      redirect: "manual",
      headers: url.hostname === API_HOST ? { "x-goog-api-key": apiKey } : {},
    });
    if (!REDIRECT_STATUSES.has(response.status)) return response;
    const location = response.headers.get("location");
    await response.body?.cancel();
    if (!location || hop === 5) throw new Error("VEO_INVALID_DOWNLOAD_REDIRECT");
    url = trustedUrl(new URL(location, url).toString(), false);
  }
  throw new Error("VEO_INVALID_DOWNLOAD_REDIRECT");
}
