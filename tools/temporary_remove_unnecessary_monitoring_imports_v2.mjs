import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/services/app_monitoring_service.dart';
let source = await readFile(path, 'utf8');
source = source
  .replace("import 'dart:ui' show PlatformDispatcher;\n", '')
  .replace("import 'package:flutter/widgets.dart';\n", '');
await writeFile(path, source, 'utf8');
console.log('unnecessary monitoring imports removed');
