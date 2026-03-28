import { GoogleAuth } from "google-auth-library";

const GOOGLE_API_SCOPES = ["https://www.googleapis.com/auth/cloud-platform"];
const auth = new GoogleAuth({ scopes: GOOGLE_API_SCOPES });

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