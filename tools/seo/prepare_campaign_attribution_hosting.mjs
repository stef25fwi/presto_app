#!/usr/bin/env node
import fs from 'node:fs/promises';
import process from 'node:process';

const associationHeaders = [
  {
    source: '/.well-known/assetlinks.json',
    headers: [
      { key: 'Content-Type', value: 'application/json; charset=utf-8' },
      { key: 'Cache-Control', value: 'public, max-age=3600' },
    ],
  },
  {
    source: '/.well-known/apple-app-site-association',
    headers: [
      { key: 'Content-Type', value: 'application/json; charset=utf-8' },
      { key: 'Cache-Control', value: 'public, max-age=3600' },
    ],
  },
];

export function prepareCampaignAttributionHosting(config) {
  const hosting = Array.isArray(config.hosting) ? config.hosting : [config.hosting];
  if (hosting.length === 0 || hosting.some((entry) => !entry)) {
    throw new Error('Configuration Firebase Hosting absente.');
  }

  for (const target of hosting) {
    const headers = Array.isArray(target.headers) ? target.headers : [];
    const withoutAssociations = headers.filter(
      (entry) => !associationHeaders.some((item) => item.source === entry.source),
    );
    target.headers = [...withoutAssociations, ...associationHeaders];
  }
  return config;
}

export async function prepareHostingFile(filePath = 'firebase.json') {
  const raw = await fs.readFile(filePath, 'utf8');
  const config = prepareCampaignAttributionHosting(JSON.parse(raw));
  await fs.writeFile(filePath, `${JSON.stringify(config, null, 2)}\n`);
  return config;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const index = process.argv.indexOf('--config');
  const filePath = index >= 0 ? process.argv[index + 1] : 'firebase.json';
  await prepareHostingFile(filePath);
  console.log(`Firebase Hosting préparé pour le lot 17 : ${filePath}`);
}
