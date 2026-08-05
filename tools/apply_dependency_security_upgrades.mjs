#!/usr/bin/env node

import fs from 'node:fs/promises';

const path = 'functions/package.json';
const packageJson = JSON.parse(await fs.readFile(path, 'utf8'));

packageJson.dependencies = {
  ...packageJson.dependencies,
  '@google-cloud/speech': '^7.5.0',
  // firebase-functions 7.3.x et le lockfile validé utilisent Firebase Admin 14.
  // Garder le garde-fou aligné sur la migration modulaire testée, sans rétrogradation.
  'firebase-admin': '^14.2.0',
};

packageJson.overrides = {
  ...(packageJson.overrides ?? {}),
  '@grpc/grpc-js': '^1.9.16',
};

await fs.writeFile(path, `${JSON.stringify(packageJson, null, 2)}\n`, 'utf8');
console.log('dependency security upgrades: OK');
