#!/usr/bin/env node

import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || 'build/web');
const versionPath = path.join(root, 'version.json');
let existing = {};
if (fs.existsSync(versionPath)) {
  try {
    existing = JSON.parse(fs.readFileSync(versionPath, 'utf8'));
  } catch {
    existing = {};
  }
}

let gitCommit = String(process.env.GITHUB_SHA || '').trim();
if (!gitCommit) {
  try {
    gitCommit = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
  } catch {
    gitCommit = 'local';
  }
}

const metadata = {
  ...existing,
  gitCommit,
  buildTime: new Date().toISOString(),
};
fs.mkdirSync(root, { recursive: true });
fs.writeFileSync(versionPath, `${JSON.stringify(metadata, null, 2)}\n`);
console.log(`Web release metadata stamped: ${gitCommit}`);
