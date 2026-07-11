import { readFile, writeFile } from 'node:fs/promises';

const path = 'tools/apply_prod_hardening_patches.mjs';
let source = await readFile(path, 'utf8');
const before = `  content = replaceOnce(\n    content,\n    "import 'package:flutter/widgets.dart';\\n",\n    "import 'package:flutter/widgets.dart';\\n\\nimport 'firebase_functions_region.dart';\\n",\n    'monitoring callable import',\n  );`;
const after = `  content = replaceOnce(\n    content,\n    "import 'package:flutter/widgets.dart';\\n",\n    '',\n    'monitoring unnecessary widgets import',\n  );\n  if (!content.includes("import 'firebase_functions_region.dart';")) {\n    content = replaceOnce(\n      content,\n      "import 'package:flutter/foundation.dart';\\n",\n      "import 'package:flutter/foundation.dart';\\n\\nimport 'firebase_functions_region.dart';\\n",\n      'monitoring callable import',\n    );\n  }`;
if (!source.includes(before)) {
  throw new Error('monitoring generator block not found');
}
source = source.replace(before, after);
await writeFile(path, source, 'utf8');
console.log('monitoring hardening generator updated');
