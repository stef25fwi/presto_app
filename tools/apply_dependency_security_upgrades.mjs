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
  // Seules racines réellement porteuses d'un avis de sécurité dans l'arbre
  // Functions : tout le reste (gaxios, google-gax, glob, rimraf, minimatch,
  // teeny-request, retry-request, @google-cloud/*) n'était signalé que par
  // propagation transitive de ces deux paquets.
  // brace-expansion <=5.0.7 : DoS par expansion non bornée (OOM).
  // uuid <11.1.1 : absence de contrôle de bornes du buffer en v3/v5/v6.
  // Les deux versions cibles exposent CJS et ESM : aucun consommateur cassé.
  'brace-expansion': '^5.0.8',
  uuid: '^11.1.1',
};

await fs.writeFile(path, `${JSON.stringify(packageJson, null, 2)}\n`, 'utf8');
console.log('dependency security upgrades: OK');
