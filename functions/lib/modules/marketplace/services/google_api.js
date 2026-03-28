"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchGoogleApiJson = fetchGoogleApiJson;
const google_auth_library_1 = require("google-auth-library");
const GOOGLE_API_SCOPES = ["https://www.googleapis.com/auth/cloud-platform"];
const auth = new google_auth_library_1.GoogleAuth({ scopes: GOOGLE_API_SCOPES });
async function getAccessToken() {
    const client = await auth.getClient();
    const accessToken = await client.getAccessToken();
    const token = typeof accessToken === "string" ? accessToken : accessToken?.token;
    if (!token) {
        throw new Error("Unable to obtain Google API access token");
    }
    return token;
}
async function fetchGoogleApiJson({ url, method = "POST", body, }) {
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
    return await response.json();
}
//# sourceMappingURL=google_api.js.map