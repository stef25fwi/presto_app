import 'package:flutter/foundation.dart';

String _normalizeRuntimeActionValue(Object? value) {
  final text =
      (value ?? 'null').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return 'empty';
  if (text.length <= 96) return text;
  return '${text.substring(0, 93)}...';
}

void logRuntimeAction({
  required String area,
  required String action,
  Map<String, Object?> details = const <String, Object?>{},
}) {
  if (!kDebugMode) return;

  final buffer = StringBuffer('[Runtime][$area][$action]');
  for (final entry in details.entries) {
    buffer.write(' ${entry.key}=${_normalizeRuntimeActionValue(entry.value)}');
  }

  debugPrint(buffer.toString());
}
