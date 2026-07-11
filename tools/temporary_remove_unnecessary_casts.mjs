import { readFile, writeFile } from 'node:fs/promises';

const replacements = [
  {
    path: 'lib/features/account/signed_out_account_fallback.dart',
    before: `.clamp(420.0, double.infinity) as double;`,
    after: `.clamp(420.0, double.infinity);`,
  },
  {
    path: 'lib/pages/fiche_pro_page.dart',
    before: `(results[0] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};`,
    after: `results[0].data() ?? {};`,
  },
  {
    path: 'lib/pages/fiche_pro_page.dart',
    before: `(results[1] as DocumentSnapshot<Map<String, dynamic>>).data() ?? {};`,
    after: `results[1].data() ?? {};`,
  },
  {
    path: 'tools/convert_communes_by_dept.dart',
    before: `final map = decoded as Map<String, dynamic>;`,
    after: `final map = decoded;`,
  },
];

for (const replacement of replacements) {
  const source = await readFile(replacement.path, 'utf8');
  if (!source.includes(replacement.before)) {
    if (source.includes(replacement.after)) continue;
    throw new Error(`cast anchor not found in ${replacement.path}`);
  }
  await writeFile(
    replacement.path,
    source.replace(replacement.before, replacement.after),
    'utf8',
  );
}

console.log('removed 4 unnecessary casts');
