import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/pages/toolbox_je_me_lance_page.dart';
let source = await readFile(path, 'utf8');
const before = `          ...items\n              .map((s) => _SelectRow(\n                    icon: Icons.work_outline,\n                    title: s,\n                    selected: _situation == s,\n                    onTap: () {\n                      setState(() => _situation = s);\n                      _onAnyFieldChanged();\n                    },\n                  ))\n              .toList(),`;
const after = `          ...items.map((s) => _SelectRow(\n                icon: Icons.work_outline,\n                title: s,\n                selected: _situation == s,\n                onTap: () {\n                  setState(() => _situation = s);\n                  _onAnyFieldChanged();\n                },\n              )),`;
if (!source.includes(before)) {
  throw new Error('spread toList block not found');
}
source = source.replace(before, after);
await writeFile(path, source, 'utf8');
console.log('unnecessary spread toList removed');
