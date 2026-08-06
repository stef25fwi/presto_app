#!/usr/bin/env node
import fs from 'node:fs/promises';
import process from 'node:process';

const statusContext = 'quality/campaign-attribution-lot17';

export async function verifyCampaignAttributionLot17({
  baseUrl,
  commitSha,
  fetchImpl = fetch,
  generatedAt = new Date(),
}) {
  const origin = new URL(baseUrl).origin;
  const assetlinksUrl = `${origin}/.well-known/assetlinks.json`;
  const appleUrl = `${origin}/.well-known/apple-app-site-association`;
  const deepLinkUrl = new URL(
    '/app/offers/lot17-smoke?utm_source=github&utm_medium=ci&utm_campaign=lot17&utm_content=deep_link',
    origin,
  ).toString();

  const checks = [];
  let android = null;
  let ios = null;

  try {
    const response = await fetchImpl(assetlinksUrl, { redirect: 'follow' });
    const contentType = response.headers.get('content-type') ?? '';
    const payload = await response.json();
    const target = Array.isArray(payload) ? payload[0]?.target : null;
    const fingerprint = target?.sha256_cert_fingerprints?.[0] ?? '';
    const ok = response.ok &&
      contentType.includes('application/json') &&
      target?.namespace === 'android_app' &&
      target?.package_name === 'fr.ilipresto.app' &&
      /^[A-F0-9]{2}(?::[A-F0-9]{2}){31}$/.test(fingerprint);
    android = {
      ok,
      url: assetlinksUrl,
      packageName: target?.package_name ?? null,
      fingerprintPresent: Boolean(fingerprint),
    };
    checks.push({ name: 'android-app-links', ok });
  } catch (error) {
    android = { ok: false, url: assetlinksUrl, error: String(error) };
    checks.push({ name: 'android-app-links', ok: false });
  }

  try {
    const response = await fetchImpl(appleUrl, { redirect: 'follow' });
    const contentType = response.headers.get('content-type') ?? '';
    const payload = await response.json();
    const detail = payload?.applinks?.details?.[0];
    const paths = Array.isArray(detail?.paths) ? detail.paths : [];
    const ok = response.ok &&
      contentType.includes('application/json') &&
      String(detail?.appID ?? '').endsWith('.fr.ilipresto.app') &&
      paths.includes('/app/*');
    ios = {
      ok,
      url: appleUrl,
      appId: detail?.appID ?? null,
      paths,
    };
    checks.push({ name: 'ios-universal-links', ok });
  } catch (error) {
    ios = { ok: false, url: appleUrl, error: String(error) };
    checks.push({ name: 'ios-universal-links', ok: false });
  }

  let web;
  try {
    const response = await fetchImpl(deepLinkUrl, { redirect: 'follow' });
    const body = await response.text();
    const ok = response.ok &&
      body.includes('flutter_bootstrap.js') &&
      response.url.includes('/app/offers/lot17-smoke');
    web = {
      ok,
      url: deepLinkUrl,
      finalUrl: response.url,
      campaignParametersPreserved:
        response.url.includes('utm_source=github') &&
        response.url.includes('utm_campaign=lot17'),
    };
    checks.push({ name: 'web-campaign-deep-link', ok });
  } catch (error) {
    web = { ok: false, url: deepLinkUrl, error: String(error) };
    checks.push({ name: 'web-campaign-deep-link', ok: false });
  }

  const available = checks.every((check) => check.ok);
  return {
    lot: 17,
    status: available ? 'available' : 'blocked',
    state: available ? 'success' : 'failure',
    statusContext,
    generatedAt: generatedAt.toISOString(),
    commitSha,
    baseUrl: origin,
    checks,
    web,
    android,
    ios,
  };
}

export function markdownFor(report) {
  const mark = (value) => value ? '✅' : '❌';
  return `# Attribution UTM et deep links — lot 17

- Statut : **${report.status}**
- SHA : \`${report.commitSha}\`
- Contexte GitHub : **${report.statusContext}**

| Plateforme | Résultat |
|---|---|
| Web UTM + deep link | ${mark(report.web?.ok)} |
| Android App Links | ${mark(report.android?.ok)} |
| iOS Universal Links | ${mark(report.ios?.ok)} |

- URL de contrôle : ${report.web?.url ?? 'indisponible'}
- Package Android : \`${report.android?.packageName ?? 'indisponible'}\`
- App ID iOS : \`${report.ios?.appId ?? 'indisponible'}\`
`;
}

function arg(name, fallback = '') {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] ?? fallback : fallback;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const baseUrl = arg('--base-url', 'https://ilipresto.fr');
  const commitSha = arg('--commit-sha', process.env.GITHUB_SHA ?? 'unknown');
  const output = arg('--output', 'build/seo/campaign-attribution-lot17-report.json');
  const markdown = arg('--markdown', 'build/seo/campaign-attribution-lot17-report.md');
  const enforce = process.argv.includes('--enforce');

  const report = await verifyCampaignAttributionLot17({ baseUrl, commitSha });
  await fs.mkdir(new URL('.', `file://${process.cwd()}/${output}`).pathname, {
    recursive: true,
  }).catch(() => {});
  await fs.mkdir(output.split('/').slice(0, -1).join('/') || '.', {
    recursive: true,
  });
  await fs.writeFile(output, `${JSON.stringify(report, null, 2)}\n`);
  await fs.writeFile(markdown, markdownFor(report));

  if (process.env.GITHUB_OUTPUT) {
    await fs.appendFile(
      process.env.GITHUB_OUTPUT,
      `state=${report.state}\ndescription=${report.status === 'available' ? 'Lot 17 Web, Android et iOS certifiés' : 'Lot 17 bloqué : association ou deep link invalide'}\n`,
    );
  }

  console.log(`Lot 17 : ${report.status}`);
  if (enforce && report.status !== 'available') process.exitCode = 1;
}
