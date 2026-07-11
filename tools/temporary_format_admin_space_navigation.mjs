import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/pages/admin_space_page.dart';
let source = await readFile(path, 'utf8');
const before = `                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const AdminListingsManagementPage(),
                        ),`;
const after = `                        MaterialPageRoute<void>(
                          builder: (_) => const AdminListingsManagementPage(),
                        ),`;
if (!source.includes(before)) {
  if (source.includes(after)) {
    console.log('admin navigation already formatted');
    process.exit(0);
  }
  throw new Error('admin navigation formatting anchor not found');
}
source = source.replace(before, after);
await writeFile(path, source, 'utf8');
console.log('admin navigation formatting applied');
