#!/usr/bin/env node

import fs from 'node:fs/promises';
import path from 'node:path';

const buildDir = path.resolve('build/web');
const maxMainBytes = Number(process.env.MAX_MAIN_DART_JS_BYTES || 12 * 1024 * 1024);
const maxTotalBytes = Number(process.env.MAX_WEB_BUILD_BYTES || 50 * 1024 * 1024);
const largestFileCount = Number(process.env.WEB_BUILD_LARGEST_FILE_COUNT || 30);

async function collectFiles(directory, root = directory) {
  const entries = await fs.readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await collectFiles(entryPath, root));
    } else if (entry.isFile()) {
      const stat = await fs.stat(entryPath);
      files.push({
        path: path.relative(root, entryPath).replaceAll(path.sep, '/'),
        bytes: stat.size,
      });
    }
  }
  return files;
}

function formatMiB(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(2)} MiB`;
}

async function main() {
  const mainPath = path.join(buildDir, 'main.dart.js');
  const mainBytes = (await fs.stat(mainPath)).size;
  const files = await collectFiles(buildDir);
  const totalBytes = files.reduce((sum, file) => sum + file.bytes, 0);
  const largest = [...files]
    .sort((left, right) => right.bytes - left.bytes)
    .slice(0, largestFileCount);

  console.log(`main.dart.js: ${formatMiB(mainBytes)} / ${formatMiB(maxMainBytes)}`);
  console.log(`build/web total: ${formatMiB(totalBytes)} / ${formatMiB(maxTotalBytes)}`);
  console.log(`Largest ${largest.length} files:`);
  for (const file of largest) {
    console.log(`  ${formatMiB(file.bytes).padStart(10)}  ${file.path}`);
  }

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
