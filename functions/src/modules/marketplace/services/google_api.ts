import { GoogleAuth } from "google-auth-library";

const GOOGLE_API_SCOPES = ["https://www.googleapis.com/auth/cloud-platform"];
const auth = new GoogleAuth({ scopes: GOOGLE_API_SCOPES });

/**
 * Hôtes Google autorisés. Cet helper attache un jeton OAuth de portée
 * `cloud-platform` : une URL qui échapperait à cette liste enverrait un jeton
 * très privilégié à un hôte tiers. Les appelants actuels n'utilisent que des
 * hôtes littéraux, mais la signature accepte une URL arbitraire — la liste
 * blanche ferme cette classe de bug (SSRF avec exfiltration de jeton) avant
 * qu'un futur appelant ne l'ouvre.
 */
const ALLOWED_GOOGLE_API_HOSTS = new Set([
  "vision.googleapis.com",
  "recaptchaenterprise.googleapis.com",
]);

export function assertAllowedGoogleApiUrl(url: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error(`Google API URL invalide : ${url}`);
  }
  if (parsed.protocol !== "https:") {
    throw new Error(`Google API URL non chiffrée : ${parsed.protocol}`);
  }
  if (!ALLOWED_GOOGLE_API_HOSTS.has(parsed.hostname)) {
    throw new Error(`Hôte Google API non autorisé : ${parsed.hostname}`);
  }
  return parsed;
}

async function getAccessToken(): Promise<string> {
  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();
  const token = typeof accessToken === "string" ? accessToken : accessToken?.token;
  if (!token) {
    throw new Error("Unable to obtain Google API access token");
  }
  return token;
}

export async function fetchGoogleApiJson<TResponse>({
  url,
  method = "POST",
  body,
}: {
  url: string;
  method?: "GET" | "POST" | "PATCH";
  body?: unknown;
}): Promise<TResponse> {
  assertAllowedGoogleApiUrl(url);
  const token = await getAccessToken();
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Google API request failed: ${response.status} ${response.statusText}`);
  }

  return await response.json() as TResponse;
}