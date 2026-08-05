#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] || 'build/web');
const marker = '<script defer src="/web-vitals-rum.js"></script>';

function collectHtmlFiles(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...collectHtmlFiles(absolute));
    if (entry.isFile() && entry.name.endsWith('.html')) files.push(absolute);
  }
  return files;
}

if (!fs.existsSync(root)) {
  throw new Error(`Web build directory not found: ${root}`);
}

const rumScript = path.join(root, 'web-vitals-rum.js');
if (!fs.existsSync(rumScript)) {
  throw new Error(`RUM client missing from web build: ${rumScript}`);
}

const htmlFiles = collectHtmlFiles(root);
if (htmlFiles.length === 0) throw new Error(`No HTML files found in ${root}`);

let changed = 0;
for (const file of htmlFiles) {
  const original = fs.readFileSync(file, 'utf8');
  if (original.includes(marker)) continue;
  if (!original.includes('</head>')) {
    throw new Error(`Missing </head> in ${path.relative(root, file)}`);
  }
  const updated = original.replace('</head>', `  ${marker}\n</head>`);
  fs.writeFileSync(file, updated);
  changed += 1;
}

console.log(`Core Web Vitals RUM: ${changed} page(s) instrumented, ${htmlFiles.length} checked.`);
