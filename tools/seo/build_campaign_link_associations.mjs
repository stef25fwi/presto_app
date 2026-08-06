#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

export function normalizeSha256Fingerprint(value) {
  const compact = String(value ?? '')
    .replace(/[^a-fA-F0-9]/g, '')
    .toUpperCase();
  if (!/^[A-F0-9]{64}$/.test(compact)) {
    throw new Error('Empreinte SHA-256 Android invalide.');
  }
  return compact.match(/.{2}/g).join(':');
}

export function buildAssociationPayloads({
  androidPackage,
  androidSha256,
  iosAppId,
}) {
  if (!/^[a-zA-Z][a-zA-Z0-9_.]+$/.test(androidPackage)) {
    throw new Error('Package Android invalide.');
  }
  if (!String(iosAppId).endsWith(`.${androidPackage}`)) {
    throw new Error('App ID iOS incohérent avec le bundle de l’application.');
  }

  return {
    assetlinks: [
      {
        relation: ['delegate_permission/common.handle_all_urls'],
        target: {
          namespace: 'android_app',
          package_name: androidPackage,
          sha256_cert_fingerprints: [
            normalizeSha256Fingerprint(androidSha256),
          ],
        },
      },
    ],
    appleAppSiteAssociation: {
      applinks: {
        apps: [],
        details: [
          {
            appID: iosAppId,
            paths: ['/app', '/app/*'],
          },
        ],
      },
    },
  };
}

export async function writeAssociationFiles({
  outputDir,
  androidPackage,
  androidSha256,
  iosAppId,
}) {
  const payloads = buildAssociationPayloads({
    androidPackage,
    androidSha256,
    iosAppId,
  });
  await fs.mkdir(outputDir, { recursive: true });
  await fs.writeFile(
    path.join(outputDir, 'assetlinks.json'),
    `${JSON.stringify(payloads.assetlinks, null, 2)}\n`,
  );
  await fs.writeFile(
    path.join(outputDir, 'apple-app-site-association'),
    `${JSON.stringify(payloads.appleAppSiteAssociation, null, 2)}\n`,
  );
  return payloads;
}

function arg(name, fallback = '') {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] ?? fallback : fallback;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const outputDir = arg('--output-dir', 'build/web/.well-known');
  const androidPackage = arg('--android-package', 'fr.ilipresto.app');
  const androidSha256 = arg('--android-sha256');
  const iosAppId = arg('--ios-app-id');

  await writeAssociationFiles({
    outputDir,
    androidPackage,
    androidSha256,
    iosAppId,
  });
  console.log(`Associations lot 17 générées dans ${outputDir}`);
}
