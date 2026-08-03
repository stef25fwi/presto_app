#!/usr/bin/env node

import process from 'node:process';
import { GoogleAuth } from 'google-auth-library';

const projectId = process.env.PROJECT_ID || 'presto-app-74abe';
const endpoint =
  `https://firebaseremoteconfig.googleapis.com/v1/projects/${projectId}/remoteConfig`;
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/firebase.remoteconfig'],
});

async function request(method, { body, etag, validateOnly = false } = {}) {
  const client = await auth.getClient();
  const token = await client.getAccessToken();
  const url = validateOnly ? `${endpoint}?validateOnly=true` : endpoint;
  const response = await fetch(url, {
    method,
    headers: {
      authorization: `Bearer ${token.token}`,
      accept: 'application/json',
      ...(body ? { 'content-type': 'application/json; UTF-8' } : {}),
      ...(etag ? { 'if-match': etag } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await response.text();
  const payload = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(
      `${method} Remote Config failed (${response.status}): ${text}`,
    );
  }
  return {
    payload,
    etag: response.headers.get('etag'),
  };
}

function setDefaultValue(template, key, value) {
  template.parameters ??= {};
  template.parameters[key] ??= {};
  template.parameters[key].defaultValue = { value: String(value) };
}

function readDefaultValue(template, key) {
  return String(template.parameters?.[key]?.defaultValue?.value ?? '');
}

async function putTemplate(template, etag, { validateOnly = false } = {}) {
  const clean = structuredClone(template);
  delete clean.version;
  return request('PUT', { body: clean, etag, validateOnly });
}

async function main() {
  const initial = await request('GET');
  if (!initial.etag || !initial.payload) {
    throw new Error('Remote Config template or ETag is missing');
  }

  const original = structuredClone(initial.payload);
  const rollback = structuredClone(initial.payload);
  setDefaultValue(rollback, 'micro_ia_v2_enabled', 'false');
  setDefaultValue(rollback, 'micro_ia_v2_rollout_percent', '0');
  setDefaultValue(rollback, 'micro_ia_v1_fallback_enabled', 'true');

  await putTemplate(rollback, initial.etag, { validateOnly: true });

  let rollbackPublished = false;
  try {
    await putTemplate(rollback, initial.etag);
    rollbackPublished = true;

    const observed = await request('GET');
    const actual = {
      micro_ia_v2_enabled: readDefaultValue(
        observed.payload,
        'micro_ia_v2_enabled',
      ),
      micro_ia_v2_rollout_percent: readDefaultValue(
        observed.payload,
        'micro_ia_v2_rollout_percent',
      ),
      micro_ia_v1_fallback_enabled: readDefaultValue(
        observed.payload,
        'micro_ia_v1_fallback_enabled',
      ),
    };
    const expected = {
      micro_ia_v2_enabled: 'false',
      micro_ia_v2_rollout_percent: '0',
      micro_ia_v1_fallback_enabled: 'true',
    };
    if (JSON.stringify(actual) !== JSON.stringify(expected)) {
      throw new Error(
        `Rollback values not observed: ${JSON.stringify({ expected, actual })}`,
      );
    }

    console.log(
      JSON.stringify(
        {
          ok: true,
          projectId,
          rollbackObserved: actual,
          originalValues: {
            micro_ia_v2_enabled: readDefaultValue(
              original,
              'micro_ia_v2_enabled',
            ),
            micro_ia_v2_rollout_percent: readDefaultValue(
              original,
              'micro_ia_v2_rollout_percent',
            ),
            micro_ia_v1_fallback_enabled: readDefaultValue(
              original,
              'micro_ia_v1_fallback_enabled',
            ),
          },
        },
        null,
        2,
      ),
    );
  } finally {
    if (rollbackPublished) {
      const latest = await request('GET');
      if (!latest.etag) throw new Error('Restore ETag is missing');
      await putTemplate(original, latest.etag, { validateOnly: true });
      await putTemplate(original, latest.etag);

      const restored = await request('GET');
      for (const key of [
        'micro_ia_v2_enabled',
        'micro_ia_v2_rollout_percent',
        'micro_ia_v1_fallback_enabled',
      ]) {
        if (readDefaultValue(restored.payload, key) !== readDefaultValue(original, key)) {
          throw new Error(`Remote Config restoration failed for ${key}`);
        }
      }
    }
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack || error.message : String(error));
  process.exitCode = 1;
});
