#!/usr/bin/env node

import fs from 'node:fs/promises';

const path = 'functions/package.json';
const packageJson = JSON.parse(await fs.readFile(path, 'utf8'));

packageJson.dependencies = {
  ...packageJson.dependencies,
  '@google-cloud/speech': '^7.5.0',
  'firebase-admin': '^14.1.0',
};

packageJson.overrides = {
  ...(packageJson.overrides ?? {}),
  '@grpc/grpc-js': '^1.9.16',
};

await fs.writeFile(path, `${JSON.stringify(packageJson, null, 2)}\n`, 'utf8');
console.log('dependency security upgrades: OK');
