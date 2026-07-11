import { readFile, writeFile } from 'node:fs/promises';

const path = 'tools/apply_prod_hardening_patches.mjs';
let source = await readFile(path, 'utf8');
const start = source.indexOf('async function patchAdminFetchOnce() {');
const end = source.indexOf('async function patchLayoutTest() {');
if (start < 0 || end <= start) {
  throw new Error('patchAdminFetchOnce function bounds not found');
}

const replacement = [
  'async function patchAdminFetchOnce() {',
  "  const path = 'lib/pages/admin_space_page.dart';",
  '  let content = await read(path);',
  '',
  '  const targets = [',
  "    '_usersStream',",
  "    '_activeUsersStream',",
  "    '_listingsStream',",
  "    '_subscriptionsStream',",
  "    '_billingInvoicesStream',",
  "    '_analyticsStream',",
  '  ];',
  '',
  '  for (const target of targets) {',
  '    const fetchOncePattern = new RegExp(',
  "      target + '\\\\s*=\\\\s*FirebaseFirestore\\\\.instance[\\\\s\\\\S]{0,500}?\\\\.get\\\\(\\\\)\\\\s*\\\\.asStream\\\\(\\\\);',",
  '    );',
  '    if (fetchOncePattern.test(content)) continue;',
  '',
  '    const realtimePattern = new RegExp(',
  "      '(' + target + '\\\\s*=\\\\s*FirebaseFirestore\\\\.instance[\\\\s\\\\S]{0,500}?)\\\\.snapshots\\\\(\\\\);',",
  '    );',
  "    const matches = [...content.matchAll(new RegExp(realtimePattern.source, 'g'))];",
  '    if (matches.length !== 1) {',
  '      throw new Error(',
  "        'admin fetch once ' +",
  '          target +',
  "          ': expected one snapshots query or an existing get().asStream(), found ' +",
  '          matches.length,',
  '      );',
  '    }',
  "    content = content.replace(realtimePattern, '$1.get().asStream();');",
  '  }',
  '',
  '  content = content',
  "    .replace(/(final logsStream =[\\s\\S]*?\\.limit\\(1000\\)\\s*)\\.snapshots\\(\\);/, '$1.get().asStream();')",
  "    .replace(/(final jobsStream =[\\s\\S]*?\\.limit\\(60\\)\\s*)\\.snapshots\\(\\);/, '$1.get().asStream();')",
  "    .replace(/(final ticketsStream =[\\s\\S]*?\\.limit\\(60\\)\\s*)\\.snapshots\\(\\);/, '$1.get().asStream();');",
  '',
  '  await write(path, content);',
  '}',
  '',
].join('\n');

source = `${source.slice(0, start)}${replacement}${source.slice(end)}`;
await writeFile(path, source, 'utf8');
console.log('admin hardening generator made format tolerant');
