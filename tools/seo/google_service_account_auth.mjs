import crypto from 'node:crypto';

function base64Url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replace(/=+$/u, '');
}

function parseServiceAccount(raw) {
  if (!raw || !raw.trim()) {
    throw new Error(
      'Google authentication is missing: provide a short-lived access token or service account JSON.',
    );
  }

  let credentials;
  try {
    credentials = JSON.parse(raw);
  } catch {
    throw new Error('Google service account JSON is invalid.');
  }

  const clientEmail = String(credentials.client_email ?? '').trim();
  const privateKey = String(credentials.private_key ?? '').replaceAll('\\n', '\n');
  const privateKeyId = String(credentials.private_key_id ?? '').trim();
  if (!clientEmail || !privateKey.includes('BEGIN PRIVATE KEY')) {
    throw new Error('Google service account credentials are incomplete.');
  }

  return { clientEmail, privateKey, privateKeyId };
}

export async function getGoogleAccessToken({
  directAccessToken = '',
  serviceAccountJson = '',
  scopes,
}) {
  const shortLivedToken = String(directAccessToken).trim();
  if (shortLivedToken) return shortLivedToken;

  const { clientEmail, privateKey, privateKeyId } = parseServiceAccount(
    serviceAccountJson,
  );
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'RS256',
    typ: 'JWT',
    ...(privateKeyId ? { kid: privateKeyId } : {}),
  };
  const claims = {
    iss: clientEmail,
    scope: scopes.join(' '),
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };
  const signingInput = `${base64Url(JSON.stringify(header))}.${base64Url(
    JSON.stringify(claims),
  )}`;
  const signature = crypto
    .createSign('RSA-SHA256')
    .update(signingInput)
    .sign(privateKey);
  const assertion = `${signingInput}.${base64Url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.access_token) {
    const message = payload.error_description ?? payload.error ?? response.statusText;
    throw new Error(`Google OAuth token request failed: ${message}`);
  }
  return payload.access_token;
}
