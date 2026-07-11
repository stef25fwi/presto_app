import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/pages/consult_offers_page.dart';
const source = await readFile(path, 'utf8');
const needle = '        kMarketplaceOutlineWidth,\n';
if (!source.includes(needle)) {
  console.log('unused shown name already removed');
  process.exit(0);
}
const updated = source.replace(needle, '');
await writeFile(path, updated, 'utf8');
console.log('removed kMarketplaceOutlineWidth from consult_offers_page.dart import');
