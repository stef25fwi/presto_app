#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';

const buildDir = path.resolve('build/web');
const maxMainBytes = Number(process.env.MAX_MAIN_DART_JS_BYTES || 12 * 1024 * 1024);
const maxTotalBytes = Number(process.env.MAX_WEB_BUILD_BYTES || 50 * 1024 * 1024);

async function directorySize(directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  let total = 0;
  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      total += await directorySize(entryPath);
    } else if (entry.isFile()) {
      total += (await fs.stat(entryPath)).size;
    }
  }
  return total;
}

function formatMiB(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(2)} MiB`;
}

async function main() {
  const mainPath = path.join(buildDir, 'main.dart.js');
  const mainBytes = (await fs.stat(mainPath)).size;
  const totalBytes = await directorySize(buildDir);

  console.log(`main.dart.js: ${formatMiB(mainBytes)} / ${formatMiB(maxMainBytes)}`);
  console.log(`build/web total: ${formatMiB(totalBytes)} / ${formatMiB(maxTotalBytes)}`);

  if (mainBytes > maxMainBytes) {
    throw new Error(`main.dart.js exceeds the production budget: ${formatMiB(mainBytes)}`);
  }
  if (totalBytes > maxTotalBytes) {
    throw new Error(`build/web exceeds the production budget: ${formatMiB(totalBytes)}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
