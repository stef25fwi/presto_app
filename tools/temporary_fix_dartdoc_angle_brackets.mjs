import { readFile, writeFile } from 'node:fs/promises';

const cityPath = 'bin/convert_cities_by_dept.dart';
let citySource = await readFile(cityPath, 'utf8');
citySource = citySource.replace(
  '/// Sortie : assets/data/cities/cities_<dept>.json',
  '/// Sortie : `assets/data/cities/cities_<dept>.json`',
);
await writeFile(cityPath, citySource, 'utf8');

const tradePath = 'lib/data/trade_category_lookup.dart';
let tradeSource = await readFile(tradePath, 'utf8');
tradeSource = tradeSource.replace(
  '/// sous la forme { "metier": "<metierId>", "confidence": 0.0-1.0 }.',
  '/// sous la forme { "metier": "&lt;metierId&gt;", "confidence": 0.0-1.0 }.',
);
await writeFile(tradePath, tradeSource, 'utf8');

console.log('Dartdoc angle brackets escaped');
