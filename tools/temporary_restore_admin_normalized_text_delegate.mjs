import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/services/admin_access_resolver.dart';
let source = await readFile(path, 'utf8');
const before = `  String? _firstNormalizedText(Map<String, dynamic>? data, List<String> keys) =>\n      _accessPolicy.firstNormalizedText(data, keys);\n\n  DateTime? _dateTimeFromMilliseconds(dynamic value) {`;
const after = `  String? _firstNormalizedText(Map<String, dynamic>? data, List<String> keys) =>\n      _accessPolicy.firstNormalizedText(data, keys);\n\n  String? _normalizedText(dynamic value) => _accessPolicy.normalizeText(value);\n\n  DateTime? _dateTimeFromMilliseconds(dynamic value) {`;
if (!source.includes(before)) {
  throw new Error('normalized text delegate insertion point not found');
}
source = source.replace(before, after);
await writeFile(path, source, 'utf8');
console.log('admin normalized text delegate restored');
