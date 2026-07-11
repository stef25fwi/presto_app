import { readFile, writeFile } from 'node:fs/promises';

// Second push: the temporary workflow now already exists on the branch.
const path = 'lib/pages/toolbox_je_me_lance_page.dart';
let source = await readFile(path, 'utf8');
const before = `          ...items
              .map((s) => _SelectRow(
                    icon: Icons.work_outline,
                    title: s,
                    selected: _situation == s,
                    onTap: () {
                      setState(() => _situation = s);
                      _onAnyFieldChanged();
                    },
                  ))
              .toList(),`;
const after = `          ...items.map((s) => _SelectRow(
                icon: Icons.work_outline,
                title: s,
                selected: _situation == s,
                onTap: () {
                  setState(() => _situation = s);
                  _onAnyFieldChanged();
                },
              )),`;
if (!source.includes(before)) {
  throw new Error('spread toList block not found');
}
source = source.replace(before, after);
await writeFile(path, source, 'utf8');
console.log('unnecessary spread toList removed');
