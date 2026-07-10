#!/usr/bin/env node

import fs from 'node:fs/promises';

const path = 'functions/package.json';
const packageJson = JSON.parse(await fs.readFile(path, 'utf8'));

packageJson.dependencies = {
  ...packageJson.dependencies,
  '@google-cloud/speech': '^7.5.0',
  // firebase-functions 7.2.5 déclare une compatibilité jusqu'à firebase-admin 13.x.
  // Ne pas forcer npm : conserver une résolution de pairs officiellement supportée.
  'firebase-admin': '^13.10.0',
};

packageJson.overrides = {
  ...(packageJson.overrides ?? {}),
  '@grpc/grpc-js': '^1.9.16',
};

await fs.writeFile(path, `${JSON.stringify(packageJson, null, 2)}\n`, 'utf8');
console.log('dependency security upgrades: OK');
