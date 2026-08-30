import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

import {
  buildAssociationPayloads,
  normalizeSha256Fingerprint,
  writeAssociationFiles,
} from './build_campaign_link_associations.mjs';
import {
  buildBlockedLot17Report,
  markdownForBlockedLot17,
} from './campaign_attribution_lot17_blocker_report.mjs';
import {
  prepareCampaignAttributionHosting,
} from './prepare_campaign_attribution_hosting.mjs';
import {
  markdownFor,
  verifyCampaignAttributionLot17,
} from './verify_campaign_attribution_lot17.mjs';

const rawFingerprint = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
const fingerprint = normalizeSha256Fingerprint(rawFingerprint);
assert.equal(fingerprint.split(':').length, 32);

const payloads = buildAssociationPayloads({
  androidPackage: 'fr.ilipresto.app',
  androidSha256: rawFingerprint,
  iosAppId: 'ABCDE12345.fr.ilipresto.app',
});
assert.equal(payloads.assetlinks[0].target.package_name, 'fr.ilipresto.app');
assert.deepEqual(
  payloads.appleAppSiteAssociation.applinks.details[0].paths,
  ['/app', '/app/*'],
);

const blockedReport = buildBlockedLot17Report({
  commitSha: 'b'.repeat(40),
  blocker: 'ios_team_id_missing',
  description: 'Configurer IOS_TEAM_ID.',
  generatedAt: new Date('2026-08-09T06:00:00Z'),
});
assert.equal(blockedReport.status, 'blocked');
assert.equal(blockedReport.state, 'failure');
assert.equal(blockedReport.blocker, 'ios_team_id_missing');
assert.match(markdownForBlockedLot17(blockedReport), /ios_team_id_missing/u);

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lot17-'));
await writeAssociationFiles({
  outputDir: tempDir,
  androidPackage: 'fr.ilipresto.app',
  androidSha256: rawFingerprint,
  iosAppId: 'ABCDE12345.fr.ilipresto.app',
});
assert.ok(fs.existsSync(path.join(tempDir, 'assetlinks.json')));
assert.ok(fs.existsSync(path.join(tempDir, 'apple-app-site-association')));

const hosting = prepareCampaignAttributionHosting({
  hosting: [
    { target: 'production', headers: [] },
    { target: 'mirror', headers: [] },
  ],
});
for (const target of hosting.hosting) {
  assert.ok(target.headers.some((entry) => entry.source === '/.well-known/assetlinks.json'));
  assert.ok(target.headers.some((entry) => entry.source === '/.well-known/apple-app-site-association'));
}

function response(body, { url, contentType = 'application/json; charset=utf-8' }) {
  return new Response(typeof body === 'string' ? body : JSON.stringify(body), {
    status: 200,
    headers: { 'content-type': contentType },
  });
}

const report = await verifyCampaignAttributionLot17({
  baseUrl: 'https://ilipresto.fr',
  commitSha: 'a'.repeat(40),
  generatedAt: new Date('2026-08-06T12:00:00Z'),
  fetchImpl: async (url) => {
    if (url.endsWith('/.well-known/assetlinks.json')) {
      return response(payloads.assetlinks, { url });
    }
    if (url.endsWith('/.well-known/apple-app-site-association')) {
      return response(payloads.appleAppSiteAssociation, { url });
    }
    return {
      ok: true,
      url,
      text: async () => '<html><script src="flutter_bootstrap.js"></script></html>',
    };
  },
});
assert.equal(report.status, 'available');
assert.equal(report.statusContext, 'quality/campaign-attribution-lot17');
assert.match(markdownFor(report), /Android App Links \| ✅/u);

const attribution = fs.readFileSync(
  'lib/services/campaign_attribution_service.dart',
  'utf8',
);
for (const marker of [
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'campaign_attribution_first_v1',
  'campaign_attribution_last_v1',
  'campaign_landing',
  'deep_link_open',
  'retentionDuration = Duration(days: 90)',
  'canUseAnalytics',
]) {
  assert.match(attribution, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'u'));
}
assert.doesNotMatch(attribution, /key\('gclid'\)/u);

const routeParser = fs.readFileSync('lib/services/app_route_parser.dart', 'utf8');
assert.match(routeParser, /effectiveCampaignUri/u);
assert.match(routeParser, /observeRoute/u);

const analytics = fs.readFileSync('lib/services/product_analytics_service.dart', 'utf8');
assert.match(analytics, /parametersForProductEvent/u);

const androidManifest = fs.readFileSync(
  'android/app/src/main/AndroidManifest.xml',
  'utf8',
);
assert.match(androidManifest, /android:autoVerify="true"/u);
assert.match(androidManifest, /android:host="ilipresto\.fr"/u);
assert.match(androidManifest, /android:pathPrefix="\/app"/u);
assert.match(androidManifest, /android:scheme="ilipresto"/u);

const entitlements = fs.readFileSync('ios/Runner/Runner.entitlements', 'utf8');
assert.match(entitlements, /applinks:ilipresto\.fr/u);

const workflow = fs.readFileSync(
  '.github/workflows/campaign-attribution-lot17.yml',
  'utf8',
);
for (const marker of [
  'Validate and Deploy Firebase',
  'KEYSTORE_B64',
  'IOS_TEAM_ID',
  'vars.IOS_TEAM_ID',
  'IOS_PROVISIONING_PROFILE_B64',
  'openssl smime -inform der -verify -noverify',
  "profile.get('TeamIdentifier')",
  'RESOLVED_IOS_TEAM_ID',
  'campaign_attribution_lot17_blocker_report.mjs',
  'ios_team_id_missing',
  'build_campaign_link_associations.mjs',
  'prepare_campaign_attribution_hosting.mjs',
  'verify_campaign_attribution_lot17.mjs',
  'retention-days: 90',
  'quality/campaign-attribution-lot17',
]) {
  assert.match(workflow, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'u'));
}
assert.doesNotMatch(
  workflow,
  /for name in KEYSTORE_B64 KEYSTORE_PASSWORD KEY_ALIAS IOS_TEAM_ID/u,
);

const registry = JSON.parse(
  fs.readFileSync('quality/seo_acquisition_readiness.json', 'utf8'),
);
for (const id of ['campaign_attribution', 'deep_links_campaigns']) {
  const control = registry.controls.find((item) => item.id === id);
  assert.ok(control, `${id} control must exist`);
  assert.ok(['pending', 'complete'].includes(control.status));
  assert.match(control.evidence, /lot 17|Lot 17/u);
  if (control.status === 'complete') {
    assert.match(control.evidence, /quality\/campaign-attribution-lot17/u);
    assert.match(control.evidence, /Web, Android et iOS/u);
  }
}

console.log('Campaign attribution lot 17 contract: OK');
